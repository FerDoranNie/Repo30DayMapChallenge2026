# ==============================================================================
# Día 09 — Urban-rural | Pipeline de Datos
# La frontera que devora el bosque: 50 años de expansión metropolitana (1975–2025)
#
# Fuentes:
#   1. Global Human Settlement Layer (GHSL - JRC European Commission, R2023A)
#      GHS-BUILT-S a 3ss (~90m) y 30ss (~900m) para cortes 1975–2025
#   2. INEGI — Uso del Suelo y Vegetación (USV Serie VII, 1:250,000)
#   3. Marco Geoestadístico / Estados de México
#
# Autor: Fernando Dorantes Nieto (@FerDoranNie)
# ==============================================================================

user_lib <- "C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3"
if (dir.exists(user_lib) && !(user_lib %in% .libPaths())) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(tidyr)
  library(httr)
  library(biscale)
})

sf_use_s2(FALSE)

DIR_RAW   <- "data/raw/day09"
DIR_PROC  <- "data/processed"
DIR_METRO <- "data/processed/day09_metros"
dir.create(DIR_RAW,   recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_PROC,  recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_METRO, recursive = TRUE, showWarnings = FALSE)

t0 <- Sys.time()
msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n")

msg("Iniciando pipeline de datos para Día 09: Urban-rural...")

# ------------------------------------------------------------------------------
# 1. Definición de las 6 Regiones Metropolitanas
# ------------------------------------------------------------------------------
metros <- list(
  cdmx = list(
    id = "cdmx",
    nombre = "Valle de México",
    subtitulo = "CDMX–Edomex",
    ecosistema = "Bosque templado de montaña y antiguo lecho lacustre",
    bbox = c(xmin = -99.40, xmax = -98.88, ymin = 19.18, ymax = 19.70),
    tiles = c("R7_C9")
  ),
  mty = list(
    id = "mty",
    nombre = "Monterrey",
    subtitulo = "Nuevo León",
    ecosistema = "Piedemonte de la Sierra Madre y matorral submontano",
    bbox = c(xmin = -100.56, xmax = -100.06, ymin = 25.46, ymax = 25.96),
    tiles = c("R7_C8", "R7_C9")
  ),
  gdl = list(
    id = "gdl",
    nombre = "Guadalajara",
    subtitulo = "Jalisco",
    ecosistema = "Bosque La Primavera y valles agrícolas periurbanos",
    bbox = c(xmin = -103.60, xmax = -103.10, ymin = 20.45, ymax = 20.95),
    tiles = c("R7_C8")
  ),
  mer = list(
    id = "mer",
    nombre = "Mérida",
    subtitulo = "Yucatán",
    ecosistema = "Selva baja caducifolia kárstica y sabana",
    bbox = c(xmin = -89.85, xmax = -89.40, ymin = 20.80, ymax = 21.25),
    tiles = c("R7_C10")
  ),
  cun = list(
    id = "cun",
    nombre = "Cancún – Riviera Maya",
    subtitulo = "Quintana Roo",
    ecosistema = "Selva mediana subperennifolia y manglares costeros",
    bbox = c(xmin = -87.05, xmax = -86.65, ymin = 20.85, ymax = 21.30),
    tiles = c("R7_C10")
  ),
  pue = list(
    id = "pue",
    nombre = "Puebla – Tlaxcala",
    subtitulo = "Puebla y Tlaxcala",
    ecosistema = "Valles agrícolas y faldas del volcán La Malinche",
    bbox = c(xmin = -98.42, xmax = -97.98, ymin = 18.90, ymax = 19.34),
    tiles = c("R8_C9", "R7_C9")
  )
)

EPOCHS <- c(1975, 1985, 1995, 2005, 2015, 2025)

# ------------------------------------------------------------------------------
# 2. Descarga y recorte de GHSL 3ss (~90m) para las 6 Zonas Metropolitanas
# ------------------------------------------------------------------------------
msg("Descargando / verificando teselas GHSL 3ss...")

# Identificar teselas únicas requeridas
tiles_needed <- unique(unlist(lapply(metros, function(m) m$tiles)))
msg("Teselas requeridas:", paste(tiles_needed, collapse = ", "))

download_ghsl_tile <- function(epoch, tile) {
  zip_name <- paste0("GHS_BUILT_S_E", epoch, "_GLOBE_R2023A_4326_3ss_V1_0_", tile, ".zip")
  tif_name <- paste0("GHS_BUILT_S_E", epoch, "_GLOBE_R2023A_4326_3ss_V1_0_", tile, ".tif")
  zip_path <- file.path(DIR_RAW, zip_name)
  tif_path <- file.path(DIR_RAW, tif_name)
  
  if (file.exists(tif_path)) return(tif_path)
  
  url <- paste0(
    "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_BUILT_S_GLOBE_R2023A/GHS_BUILT_S_E",
    epoch, "_GLOBE_R2023A_4326_3ss/V1-0/tiles/", zip_name
  )
  
  if (!file.exists(zip_path)) {
    msg("Descargando: ", zip_name)
    dl_status <- tryCatch({
      download.file(url, zip_path, mode = "wb", quiet = TRUE)
      0
    }, error = function(e) 1)
    if (dl_status != 0 || file.info(zip_path)$size < 1000) {
      stop("Fallo al descargar: ", url)
    }
  }
  
  unzip(zip_path, files = tif_name, exdir = DIR_RAW)
  if (file.exists(zip_path)) unlink(zip_path) # Limpiar zip para ahorrar espacio
  return(tif_path)
}

# Descargar todas las teselas y recortar por metrópoli
metro_rasters <- list()

for (m_id in names(metros)) {
  m <- metros[[m_id]]
  msg("Procesando metrópoli: ", m$nombre, " (", m$subtitulo, ")...")
  b <- ext(m$bbox["xmin"], m$bbox["xmax"], m$bbox["ymin"], m$bbox["ymax"])
  
  metro_rasters[[m_id]] <- list()
  
  for (ep in EPOCHS) {
    tif_paths <- sapply(m$tiles, function(tl) download_ghsl_tile(ep, tl))
    
    if (length(tif_paths) == 1) {
      r_raw <- rast(tif_paths[[1]])
      r_crop <- crop(r_raw, b)
    } else {
      # Mosaico de teselas si la metrópoli cruza frontera de teselas
      r_list <- unname(lapply(tif_paths, rast))
      r_merged <- merge(sprc(r_list))
      r_crop <- crop(r_merged, b)
    }
    
    metro_rasters[[m_id]][[as.character(ep)]] <- r_crop
    tif_metro_ep <- file.path(DIR_METRO, paste0(m_id, "_ghsl_", ep, ".tif"))
    writeRaster(r_crop, tif_metro_ep, overwrite = TRUE)
  }
}

# ------------------------------------------------------------------------------
# 3. Integración con USV INEGI (Fondo Ecológico y Agrícola)
# ------------------------------------------------------------------------------
msg("Cargando y recortando Uso de Suelo y Vegetación INEGI Serie VII...")
usv_full <- rast("data/processed/day03_usv250s7gw_clases.tif")

metro_ecology <- list()
metro_metrics <- list()

for (m_id in names(metros)) {
  m <- metros[[m_id]]
  b <- ext(m$bbox["xmin"], m$bbox["xmax"], m$bbox["ymin"], m$bbox["ymax"])
  
  # Recorte de USV a la metrópoli
  usv_crop <- crop(usv_full, b)
  
  # Raster de 1975 y 2025
  r1975 <- metro_rasters[[m_id]][["1975"]]
  r2025 <- metro_rasters[[m_id]][["2025"]]
  
  # Resamplear USV a la resolución de GHSL para análisis pixel a pixel
  usv_resam <- resample(usv_crop, r2025, method = "near")
  
  # Umbral urbano: GHS_BUILT_S es superficie construida en m2 por celda (~90m x 90m = ~8,100 m2)
  # Un umbral de >= 500 m2 construidos define presencia urbana clara
  urb_1975 <- r1975 >= 500
  urb_2025 <- r2025 >= 500
  
  # Nueva expansión 1975 -> 2025
  expansion_75_25 <- urb_2025 == 1 & (urb_1975 == 0 | is.na(urb_1975))
  
  # Cálculo de área de celda exacta en km2
  cell_area_km2 <- (cellSize(r2025, unit = "m") / 1e6)
  
  area_urb_1975_km2 <- as.numeric(global(urb_1975 * cell_area_km2, "sum", na.rm = TRUE))
  area_urb_2025_km2 <- as.numeric(global(urb_2025 * cell_area_km2, "sum", na.rm = TRUE))
  area_exp_km2      <- as.numeric(global(expansion_75_25 * cell_area_km2, "sum", na.rm = TRUE))
  crecimiento_pct   <- ((area_urb_2025_km2 - area_urb_1975_km2) / max(1, area_urb_1975_km2)) * 100
  
  # ¿Qué tipo de suelo devoró la expansión?
  # Clases USV: 1 = Primaria (bosque/selva), 2 = Secundaria (regeneración), 3 = Antrópico/Agrícola, 4 = Agua, 5 = Sin veg
  usv_vals <- values(usv_resam)
  exp_vals <- values(expansion_75_25)
  
  bosque_devorado_km2 <- sum((usv_vals %in% c(1, 2)) & (exp_vals == 1), na.rm = TRUE) * mean(values(cell_area_km2), na.rm = TRUE)
  agricola_devorado_km2 <- sum((usv_vals == 3) & (exp_vals == 1), na.rm = TRUE) * mean(values(cell_area_km2), na.rm = TRUE)
  
  # Serie temporal de crecimiento por década
  serie_temporal <- tibble(
    year = EPOCHS,
    km2 = sapply(EPOCHS, function(ep) {
      r_ep <- metro_rasters[[m_id]][[as.character(ep)]]
      u_ep <- r_ep >= 500
      as.numeric(global(u_ep * cell_area_km2, "sum", na.rm = TRUE))
    })
  )
  serie_temporal$pct_vs_1975 <- ((serie_temporal$km2 - serie_temporal$km2[1]) / max(1, serie_temporal$km2[1])) * 100
  
  metro_metrics[[m_id]] <- tibble(
    id = m_id,
    nombre = m$nombre,
    subtitulo = m$subtitulo,
    ecosistema = m$ecosistema,
    area_1975_km2 = round(area_urb_1975_km2, 1),
    area_2025_km2 = round(area_urb_2025_km2, 1),
    crecimiento_km2 = round(area_exp_km2, 1),
    crecimiento_pct = round(crecimiento_pct, 1),
    bosque_devorado_km2 = round(bosque_devorado_km2, 1),
    agricola_devorado_km2 = round(agricola_devorado_km2, 1),
    serie = list(serie_temporal)
  )
  
  # Guardar GeoTIFFs de ecología y expansión para esta metrópoli
  writeRaster(usv_crop, file.path(DIR_METRO, paste0(m_id, "_usv.tif")), overwrite = TRUE)
  writeRaster(expansion_75_25, file.path(DIR_METRO, paste0(m_id, "_expansion_75_25.tif")), overwrite = TRUE)
  
  metro_ecology[[m_id]] <- list(
    usv_path = file.path(DIR_METRO, paste0(m_id, "_usv.tif")),
    exp_path = file.path(DIR_METRO, paste0(m_id, "_expansion_75_25.tif"))
  )
}

df_metrics <- bind_rows(metro_metrics)
msg("Resumen cuantitativo por metrópoli:")
print(df_metrics %>% select(nombre, area_1975_km2, area_2025_km2, crecimiento_pct, bosque_devorado_km2, agricola_devorado_km2))

# ------------------------------------------------------------------------------
# 4. Construcción del Mapa Nacional Bivariado (Presión Urbana vs Cobertura Natural)
# ------------------------------------------------------------------------------
msg("Construyendo matriz bivariada nacional 3x3...")

# Cargar límites de México
mx_states <- st_read("data/raw/day01/mexico_states.geojson", quiet = TRUE) %>%
  st_make_valid()
mx_border <- st_union(mx_states)

# Proyectar a Cónica Conforme de Lambert oficial (EPSG:6372)
mx_lcc <- st_transform(mx_states, 6372)
mx_border_lcc <- st_union(mx_lcc)

# Descargar teselas nacionales GHSL 30ss (~900m) para 1975 y 2025
tiles_nat <- c("R6_C7", "R6_C8", "R7_C7", "R7_C8", "R7_C9", "R7_C10", "R8_C8", "R8_C9", "R8_C10")

download_ghsl_30ss <- function(epoch, tile) {
  zip_name <- paste0("GHS_BUILT_S_E", epoch, "_GLOBE_R2023A_4326_30ss_V1_0_", tile, ".zip")
  tif_name <- paste0("GHS_BUILT_S_E", epoch, "_GLOBE_R2023A_4326_30ss_V1_0_", tile, ".tif")
  zip_path <- file.path(DIR_RAW, zip_name)
  tif_path <- file.path(DIR_RAW, tif_name)
  
  if (file.exists(tif_path)) return(tif_path)
  
  url <- paste0(
    "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_BUILT_S_GLOBE_R2023A/GHS_BUILT_S_E",
    epoch, "_GLOBE_R2023A_4326_30ss/V1-0/tiles/", zip_name
  )
  
  if (!file.exists(zip_path)) {
    dl_status <- tryCatch({
      download.file(url, zip_path, mode = "wb", quiet = TRUE)
      0
    }, error = function(e) 1)
  }
  
  if (file.exists(zip_path)) {
    unzip(zip_path, files = tif_name, exdir = DIR_RAW)
    unlink(zip_path)
  }
  return(tif_path)
}

msg("Descargando teselas 30ss nacionales...")
tifs_nat_1975 <- sapply(tiles_nat, function(tl) download_ghsl_30ss(1975, tl))
tifs_nat_2025 <- sapply(tiles_nat, function(tl) download_ghsl_30ss(2025, tl))

r_nat_1975 <- merge(sprc(unname(lapply(tifs_nat_1975, rast))))
r_nat_2025 <- merge(sprc(unname(lapply(tifs_nat_2025, rast))))

# Recortar al marco de México en EPSG:4326
ext_mx <- ext(mx_states)
r_nat_1975 <- crop(r_nat_1975, ext_mx)
r_nat_2025 <- crop(r_nat_2025, ext_mx)

# Crear malla regular hexagonal de 12 km sobre México en EPSG:6372
msg("Creando malla hexagonal nacional de 12 km...")
grid_nat <- st_make_grid(mx_lcc, cellsize = 12000, square = FALSE) %>%
  st_sf() %>%
  mutate(cell_id = row_number())

# Filtrar sólo celdas que tocan el territorio nacional
grid_nat <- grid_nat[st_intersects(grid_nat, mx_border_lcc, sparse = FALSE), ]
msg("Total de celdas hexagonales nacionales:", nrow(grid_nat))

# Reproyectar centroides de la malla a 4326 para extraer estadísticas rápidas
grid_cents_4326 <- st_transform(st_centroid(grid_nat), 4326)

msg("Extrayendo estadísticas zonales de urbanización y cobertura natural...")
pts_vect <- vect(grid_cents_4326)

# Para capturar la densidad acumulada en la escala del hexágono (~10-12 km):
# Agregamos los rásters 30ss (~900m) por un factor de 10 (~9 km)
r_agg_2025 <- aggregate(r_nat_2025, fact = 10, fun = "sum", na.rm = TRUE)
r_agg_1975 <- aggregate(r_nat_1975, fact = 10, fun = "sum", na.rm = TRUE)

# Cobertura natural a partir de USV (~250m) agregada por factor de 30 (~7.5 km)
r_nat_mask <- usv_full %in% c(1, 2)
r_agg_nat  <- aggregate(r_nat_mask, fact = 30, fun = "mean", na.rm = TRUE)

vals_2025 <- terra::extract(r_agg_2025, pts_vect)[, 2]
vals_1975 <- terra::extract(r_agg_1975, pts_vect)[, 2]
vals_nat  <- terra::extract(r_agg_nat,  pts_vect)[, 2]

grid_nat$urb_2025      <- ifelse(is.na(vals_2025), 0, vals_2025)
grid_nat$urb_1975      <- ifelse(is.na(vals_1975), 0, vals_1975)
grid_nat$urb_crec      <- pmax(0, grid_nat$urb_2025 - grid_nat$urb_1975)
grid_nat$cobertura_nat <- ifelse(is.na(vals_nat), 0, vals_nat)

# Clasificación bivariada 3x3:
# Eje X: Presión / Crecimiento urbano
# Eje Y: Cobertura forestal / natural circundante
msg("Calculando clases bivariadas 3x3...")
grid_biv <- bi_class(
  grid_nat,
  x = urb_2025,
  y = cobertura_nat,
  style = "quantile",
  dim = 3
)

# ------------------------------------------------------------------------------
# 5. Geometrías de los recuadros de las 6 metrópolis para el mapa nacional
# ------------------------------------------------------------------------------
metro_boxes_list <- list()
for (m in metros) {
  bb <- st_bbox(c(
    xmin = as.numeric(m$bbox["xmin"]),
    ymin = as.numeric(m$bbox["ymin"]),
    xmax = as.numeric(m$bbox["xmax"]),
    ymax = as.numeric(m$bbox["ymax"])
  ), crs = st_crs(4326))
  
  poly <- st_as_sfc(bb)
  df_box <- st_sf(
    id = m$id,
    nombre = m$nombre,
    subtitulo = m$subtitulo,
    geometry = poly
  )
  metro_boxes_list[[m$id]] <- df_box
}
metro_boxes <- bind_rows(metro_boxes_list) %>% st_transform(6372)

# ------------------------------------------------------------------------------
# 6. Guardado del Dataset Completo
# ------------------------------------------------------------------------------
dataset_path <- file.path(DIR_PROC, "day09_urban_rural_dataset.rds")
msg("Guardando dataset procesado en: ", dataset_path)

saveRDS(
  list(
    metros = metros,
    metro_ecology = metro_ecology,
    df_metrics = df_metrics,
    grid_biv = grid_biv,
    metro_boxes = metro_boxes,
    mx_lcc = mx_lcc,
    mx_border_lcc = mx_border_lcc,
    epochs = EPOCHS
  ),
  dataset_path
)

msg("¡Pipeline finalizado exitosamente en ", format(round(Sys.time() - t0, 1)), "!")
