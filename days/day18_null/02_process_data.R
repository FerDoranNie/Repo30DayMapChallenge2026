# ==============================================================================
# Día 18: NULL — Terra Incognita Biológica
# Procesamiento de NDVI (VIIRS 2024), densidad GBIF (MVT z=3) y Biomas (WWF 2017)
# sobre una grilla global de áreas iguales (Equal Earth, 50 x 50 km).
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))

suppressPackageStartupMessages({
  library(terra)
  library(sf)
  library(data.table)
  library(jsonlite)
})

sf_use_s2(FALSE)

crs_eqearth <- "+proj=eqearth +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

cat("1. Cargando y calculando NDVI máximo estacional (VIIRS 2024)...\n")
nc_files <- list.files("data/raw/day18", pattern = "\\.nc$", full.names = TRUE)
stopifnot(length(nc_files) >= 1)

ndvi_layers <- lapply(nc_files, function(f) {
  r <- rast(f)[["NDVI"]]
  # Limpiar valores fuera de rango físico
  r[r < -0.1 | r > 1.0] <- NA
  r
})
ndvi_stack <- rast(ndvi_layers)
ndvi_max_wgs <- max(ndvi_stack, na.rm = TRUE)
names(ndvi_max_wgs) <- "ndvi_max"

cat("2. Creando grilla plantilla Equal Earth (50 km x 50 km)...\n")
# Extensión global en Equal Earth (~ -17.2M a +17.2M en X, -8.4M a +8.4M en Y)
world_sf <- st_read("data/raw/day04/ne_50m_admin_0_countries.geojson", quiet = TRUE)
world_no_ata <- world_sf[world_sf$ISO_A3 != "ATA" & world_sf$ADMIN != "Antarctica", ]
world_eq <- st_transform(st_make_valid(world_no_ata), crs_eqearth)

bb <- st_bbox(world_eq)
tmpl <- rast(
  xmin = floor(bb["xmin"] / 50000) * 50000,
  xmax = ceiling(bb["xmax"] / 50000) * 50000,
  ymin = floor(bb["ymin"] / 50000) * 50000,
  ymax = ceiling(bb["ymax"] / 50000) * 50000,
  res = 50000,
  crs = crs_eqearth
)

cat("3. Proyectando NDVI máximo a Equal Earth 50 km...\n")
ndvi_eq <- project(ndvi_max_wgs, tmpl, method = "bilinear")

cat("4. Leyendo tiles MVT de GBIF (z=3, EPSG:4326)...\n")
mvt_files <- list.files("data/raw/day18/gbif_mvt", pattern = "\\.mvt$", full.names = TRUE)
cat(sprintf("   Encontrados %d tiles MVT con datos.\n", length(mvt_files)))

tile_w <- 360 / 16
tile_h <- 180 / 8

gbif_list <- lapply(mvt_files, function(f) {
  bn <- basename(f)
  m <- regmatches(bn, regexec("gbif_z3_([0-9]+)_([0-9]+)\\.mvt", bn))[[1]]
  tx <- as.integer(m[2])
  ty <- as.integer(m[3])

  lon_min <- -180 + tx * tile_w
  lat_min <- 90 - (ty + 1) * tile_h

  x <- tryCatch(st_read(paste0("MVT:", f), quiet = TRUE), error = function(e) NULL)
  if (is.null(x) || nrow(x) == 0) return(NULL)

  cent <- suppressWarnings(st_coordinates(st_centroid(st_geometry(x))))
  data.table(
    lon = lon_min + (cent[, 1] / 4096) * tile_w,
    lat = lat_min + (cent[, 2] / 4096) * tile_h,
    total = as.numeric(x$total)
  )
})

gbif_dt <- rbindlist(gbif_list)
cat(sprintf("   Total celdas MVT leídas: %s | Registros acumulados: %s\n",
            format(nrow(gbif_dt), big.mark = ","),
            format(sum(gbif_dt$total, na.rm = TRUE), big.mark = ",")))

gbif_vect <- vect(gbif_dt, geom = c("lon", "lat"), crs = "EPSG:4326")
gbif_vect_eq <- project(gbif_vect, crs_eqearth)
gbif_eq <- rasterize(gbif_vect_eq, tmpl, field = "total", fun = "sum", background = 0)
names(gbif_eq) <- "gbif_count"

cat("5. Enmascarando tierra firme (sin Antártida) y asignando Biomas...\n")
land_mask <- rasterize(vect(world_eq[, "ADMIN"]), tmpl, field = 1)
names(land_mask) <- "is_land"

# Extraer tabla de celdas terrestres
grid_stack <- c(land_mask, ndvi_eq, gbif_eq)
df <- as.data.table(as.data.frame(grid_stack, xy = TRUE, na.rm = FALSE))
df <- df[is_land == 1 & !is.na(ndvi_max)]

# Extraer Bioma de Ecoregions2017 usando rasterización rápida en WGS84 (0.25°)
cat("   Cruzando con Ecoregions2017 (WWF)...\n")
pts_eq <- vect(df[, .(x, y)], geom = c("x", "y"), crs = crs_eqearth)
pts_wgs <- project(pts_eq, "EPSG:4326")
eco <- vect("data/raw/day08/Ecoregions2017.shp")[, c("BIOME_NUM", "BIOME_NAME")]
eco_df <- unique(as.data.table(as.data.frame(eco)))
eco_df <- eco_df[!duplicated(BIOME_NUM)]

r_wgs_tmpl <- rast(xmin = -180, xmax = 180, ymin = -90, ymax = 90, res = 0.25, crs = "EPSG:4326")
r_biome <- rasterize(eco, r_wgs_tmpl, field = "BIOME_NUM")
biome_vals <- extract(r_biome, pts_wgs)[, 2]
df[, biome_num := biome_vals]
df <- merge(df, eco_df, by.x = "biome_num", by.y = "BIOME_NUM", all.x = TRUE, sort = FALSE)
setnames(df, "BIOME_NAME", "biome_name")

# Extraer continente/país vía rasterización rápida en WGS84
cat("   Asignando países y continentes...\n")
world_vect <- vect(world_no_ata[, c("ADMIN", "CONTINENT")])
world_vect$cid <- seq_len(nrow(world_vect))
r_country <- rasterize(world_vect, r_wgs_tmpl, field = "cid")
cid_vals <- extract(r_country, pts_wgs)[, 2]
df[, country := world_vect$ADMIN[cid_vals]]
df[, continent := world_vect$CONTINENT[cid_vals]]

# Clasificación de vegetación y estado NULL en GBIF
df[, veg_class := fifelse(ndvi_max >= 0.55, "Alta vegetación (NDVI ≥ 0.55)", "Vegetación baja/moderada")]
df[, gbif_status := fcase(
  gbif_count == 0, "NULL (0 registros)",
  gbif_count <= 50, "Crítico (1–50)",
  gbif_count <= 500, "Moderado (51–500)",
  default = "Alto (> 500)"
)]

df[, map_class := fcase(
  ndvi_max >= 0.55 & gbif_count == 0, "Terra Incognita (Alta veg. + NULL)",
  ndvi_max >= 0.55 & gbif_count <= 50, "Submuestreado (Alta veg. + 1–50)",
  ndvi_max >= 0.55 & gbif_count > 50, "Muestreado (Alta veg. + >50)",
  ndvi_max < 0.55 & gbif_count == 0, "Baja veg. + NULL",
  default = "Baja veg. + con datos"
)]

# Resumen estadístico
n_land <- nrow(df)
n_high_veg <- df[ndvi_max >= 0.55, .N]
n_terra_inc <- df[ndvi_max >= 0.55 & gbif_count == 0, .N]
pct_terra_inc <- 100 * n_terra_inc / n_high_veg
area_terra_inc_km2 <- n_terra_inc * 2500 # cada celda = 50km x 50km = 2,500 km2

biome_summary <- df[ndvi_max >= 0.55 & !is.na(biome_name) & biome_name != "N/A", .(
  total_cells = .N,
  null_cells = sum(gbif_count == 0),
  low_cells = sum(gbif_count <= 50),
  pct_null = 100 * mean(gbif_count == 0),
  area_null_km2 = sum(gbif_count == 0) * 2500
), by = biome_name][total_cells >= 20][order(-pct_null)]

summary_list <- list(
  total_land_cells = n_land,
  high_veg_cells = n_high_veg,
  terra_incognita_cells = n_terra_inc,
  pct_high_veg_null = round(pct_terra_inc, 2),
  area_terra_incognita_km2 = area_terra_inc_km2,
  total_null_land_cells = df[gbif_count == 0, .N],
  pct_land_null = round(100 * df[gbif_count == 0, .N] / n_land, 2)
)

print(summary_list)
print(biome_summary)

saveRDS(df, "data/processed/day18_null_grid.rds")
fwrite(biome_summary, "data/processed/day18_biome_summary.csv")
write_json(summary_list, "data/processed/day18_summary.json", auto_unbox = TRUE, pretty = TRUE)

cat("Listo: data/processed/day18_null_grid.rds guardado.\n")
