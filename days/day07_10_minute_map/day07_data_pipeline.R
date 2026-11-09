# ==============================================================================
# Día 07 — 10 minute map (Pipeline de Datos)
# "Los primeros 10 minutos del Cenozoico: El impacto de Chicxulub y el Anillo de Cenotes"
#
# Fuentes reales integradas:
#   1. Inventario SGM / CINVESTAV (Secretaría de Desarrollo Sustentable de Yucatán):
#      7,876 cenotes georreferenciados en el estado de Yucatán.
#   2. Inventario Espeleológico de la Península de Yucatán (QRSS / YCS, Peter Sprouse):
#      4,642 cenotes, cuevas y sistemas sumergidos en Quintana Roo, Yucatán y Campeche
#      con datos de profundidad (m) y desarrollo horizontal explorado (m).
#   3. Polígono oficial de la Reserva Estatal Geohidrológica del Anillo de Cenotes (SDS Yucatán).
#   4. Zonas hidrogeológicas de flujo subterráneo (Recarga, Tránsito y Descarga — CONAGUA/INEGI).
#   5. Límites estatales y costeros (Natural Earth / CONABIO).
#
# Salida: data/processed/day07_dataset.rds
# Autor:  Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(tidyr)
})

sf_use_s2(FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

cat("[1/5] Cargando capas geoespaciales base y cenotes...\n")
mx_states <- st_read("data/raw/day01/mexico_states.geojson", quiet = TRUE) |> st_make_valid()
world_ne  <- st_read("data/raw/day04/ne_50m_admin_0_countries.geojson", quiet = TRUE) |> st_make_valid()

sds_raw <- st_read("data/raw/day07/cenotes_yucatan_sds.geojson", quiet = TRUE)
oc_raw  <- st_read("data/raw/day07/oc_cenotes_0218.geojson", quiet = TRUE)
anp_raw <- st_read("data/raw/day07/anillo_cenotes_anp.geojson", quiet = TRUE) |> st_make_valid()
flu_raw <- st_read("data/raw/day07/flujos_subterraneos.geojson", quiet = TRUE) |> st_make_valid()

# Polígono de la Península de Yucatán (Yucatán, Quintana Roo, Campeche)
yuc_states <- mx_states |>
  filter(grepl("Yucat|Quintana|Campeche", name, ignore.case = TRUE))
yuc_union <- st_union(yuc_states) |> st_make_valid()

# ==============================================================================
# 2. Centro Geofísico del Cráter de Chicxulub y Anillos Estructurales
#    (Hildebrand et al. 1991; Gulick et al. 2019; Morgan et al. 2016)
#    Centro en Chicxulub Puerto: 21.30° N, -89.52° W
# ==============================================================================
cat("[2/5] Calculando geometría radial respecto al epicentro de Chicxulub...\n")
chicx_lon <- -89.52
chicx_lat <-  21.30
center_wgs <- st_sfc(st_point(c(chicx_lon, chicx_lat)), crs = 4326)
center_m   <- st_transform(center_wgs, 6372)

# Unificar puntos de cenotes evitando duplicados exactos (<100 m entre SGM y QRSS/YCS)
sds_pts <- sds_raw |>
  mutate(
    source_db = ifelse(DESCRIPCIO == "CINVESTAV", "CINVESTAV", "SGM"),
    name_clean = paste0("Cenote ", CLAVE),
    depth_m = NA_real_,
    length_m = NA_real_,
    state_name = "Yucatán"
  ) |>
  select(name_clean, source_db, state_name, depth_m, length_m)

oc_pts <- oc_raw |>
  mutate(
    source_db = "QRSS / YCS",
    name_clean = trimws(NAME),
    depth_m = suppressWarnings(as.numeric(DEPTH)),
    length_m = suppressWarnings(as.numeric(LENGTH)),
    depth_m = ifelse(!is.na(depth_m) & depth_m > 0, depth_m, NA_real_),
    length_m = ifelse(!is.na(length_m) & length_m > 0, length_m, NA_real_),
    state_name = case_when(
      grepl("Quintana", STATE, ignore.case = TRUE) ~ "Quintana Roo",
      grepl("Yucat", STATE, ignore.case = TRUE) ~ "Yucatán",
      grepl("Campeche", STATE, ignore.case = TRUE) ~ "Campeche",
      TRUE ~ "Península"
    )
  ) |>
  select(name_clean, source_db, state_name, depth_m, length_m)

# Filtrar puntos de SGM que estén a más de 120 m de un punto QRSS/YCS (para conservar atributos de profundidad de QRSS/YCS)
sds_m <- st_transform(sds_pts, 6372)
oc_m  <- st_transform(oc_pts, 6372)

nn_dist <- st_distance(sds_m, oc_m)
min_d <- apply(nn_dist, 1, min)
sds_unique_m <- sds_m[min_d > 120, ]

all_cenotes_m <- bind_rows(oc_m, sds_unique_m)
all_cenotes_m$dist_km <- as.numeric(st_distance(all_cenotes_m, center_m)) / 1000

# Filtrar a la Península de Yucatán continental/insular (dist_km < 420)
all_cenotes_m <- all_cenotes_m |> filter(dist_km <= 420)
all_cenotes   <- st_transform(all_cenotes_m, 4326)
coords_c      <- st_coordinates(all_cenotes)
all_cenotes$lon <- coords_c[, 1]
all_cenotes$lat <- coords_c[, 2]

# Clasificar cada cenote por provincia morfoestructural respecto a Chicxulub
all_cenotes <- all_cenotes |>
  mutate(
    provincia = case_when(
      dist_km < 70 ~ "1. Cuenca Interna (<70 km)",
      dist_km >= 70 & dist_km <= 105 & lon < -88.45 ~ "2. Anillo de Cenotes (70–105 km)",
      lon >= -88.0 & lat < 21.0 ~ "4. Corredor Holbox–Tulum (Caribe)",
      TRUE ~ "3. Karst de Plataforma e Interior"
    )
  )

cat("Total cenotes combinados (sin duplicados <120m):", nrow(all_cenotes), "\n")
print(table(all_cenotes$provincia))

# ==============================================================================
# 3. Perfil Radial de Densidad Terrestre (0 a 260 km en anillos de 5 km)
#    Calculamos el área emergida real de cada anillo concéntrico para obtener
#    densidad verdadera (cenotes por 100 km² de tierra firme)
# ==============================================================================
cat("[3/5] Calculando densidad radial normalizada por superficie terrestre emergida...\n")
yuc_land_m <- st_transform(yuc_union, 6372)

radii_breaks <- seq(0, 260, by = 5)
radial_rows <- list()

for (i in seq_len(length(radii_breaks) - 1)) {
  r_in  <- radii_breaks[i]
  r_out <- radii_breaks[i + 1]
  r_mid <- (r_in + r_out) / 2

  buf_out <- st_buffer(center_m, r_out * 1000)
  if (r_in == 0) {
    ring_geom <- buf_out
  } else {
    buf_in <- st_buffer(center_m, r_in * 1000)
    ring_geom <- st_difference(buf_out, buf_in)
  }

  ring_land <- suppressWarnings(st_intersection(ring_geom, yuc_land_m))
  area_km2  <- if (length(ring_land) > 0) sum(as.numeric(st_area(ring_land))) / 1e6 else 0

  # Conteo en todos los cenotes y en Yucatán (SGM/CINVESTAV + YCS)
  n_all <- sum(all_cenotes$dist_km > r_in & all_cenotes$dist_km <= r_out)
  n_sds <- sum(sds_m$dist_km <- as.numeric(st_distance(sds_m, center_m)) / 1000 > r_in &
               (as.numeric(st_distance(sds_m, center_m)) / 1000) <= r_out)

  radial_rows[[i]] <- tibble(
    r_in = r_in, r_out = r_out, r_mid = r_mid,
    area_land_km2 = area_km2,
    n_cenotes = n_all,
    density_per_100km2 = ifelse(area_km2 > 25, 100 * n_all / area_km2, NA_real_)
  )
}
radial_profile <- bind_rows(radial_rows)

cat("\nResumen del perfil radial (primeros 25 anillos):\n")
print(as.data.frame(radial_profile |> select(r_in, r_out, area_land_km2, n_cenotes, density_per_100km2) |> head(25)))

# ==============================================================================
# 4. Ráster de Densidad Espacial de Cenotes en la Península (terra, 0.04°)
# ==============================================================================
cat("[4/5] Generando malla ráster de densidad kárstica...\n")
ext_yuc <- ext(-90.8, -86.6, 18.8, 21.7)
r_tmpl  <- rast(ext_yuc, resolution = 0.035, crs = "EPSG:4326")
pts_vect <- vect(all_cenotes)

r_count <- rasterize(pts_vect, r_tmpl, fun = "count", background = 0)
# Suavizado focal gaussiano para superficie continua + máscara de tierra
w_gauss <- focalMat(r_count, d = 0.07, type = "Gauss")
r_smooth <- focal(r_count, w = w_gauss, fun = "sum", na.rm = TRUE)
r_smooth <- mask(r_smooth, vect(yuc_states))

# Convertir a km² aproximados (celda 0.035° ~ 14.1 km²)
cell_area_km2 <- 14.1
rast_df <- as.data.frame(r_smooth, xy = TRUE, na.rm = TRUE)
names(rast_df)[3] <- "cenotes_smooth"
rast_df$dens_100km2 <- (rast_df$cenotes_smooth / cell_area_km2) * 100

# ==============================================================================
# 5. Anillos de Impacto de Chicxulub (para Panel A y Panel B)
# ==============================================================================
cat("[5/5] Construyendo anillos estructurales y ondas de los primeros 10 minutos...\n")

make_ring_sf <- function(radii_km, labels, center_sfc = center_wgs) {
  c_m <- st_transform(center_sfc, 6372)
  geoms <- lapply(radii_km, function(r) {
    st_boundary(st_buffer(c_m, r * 1000))
  })
  st_sf(
    radius_km = radii_km,
    label = labels,
    geometry = do.call(c, geoms),
    crs = 6372
  ) |> st_transform(4326)
}

# Anillos estructurales del cráter en Yucatán (Panel A)
crater_rings_sf <- make_ring_sf(
  radii_km = c(42, 88, 130),
  labels = c(
    "Anillo de Pico (r = 42 km · colapso t = 3–4 min)",
    "Anillo de Cenotes / Borde del Cráter (r = 88 km · t = 6–10 min)",
    "Zona Exterior de Fracturas Concéntricas (r = 130 km)"
  )
)

# Anillos de propagación durante los primeros 10 minutos en Mesoamérica y el Caribe (Panel B)
#Proyección acimutal equidistante centrada en Chicxulub para círculos verdaderos a escala continental
crs_aeqd <- sprintf("+proj=aeqd +lat_0=%f +lon_0=%f +datum=WGS84 +units=m", chicx_lat, chicx_lon)
center_aeqd <- st_transform(center_wgs, crs_aeqd)

ten_min_specs <- tibble::tribble(
  ~step_id, ~time_label, ~r_km,  ~proceso,
  1L, "t = 10 s",   45,   "Cavidad transitoria (prof. 30 km) y bola de fuego",
  2L, "t = 1 min",  100,  "Colapso gravitacional y formación del Anillo de Cenotes (r ~ 88 km)",
  3L, "t = 2 min",  420,  "Frente destructivo de onda S (3.5 km/s) y megatsunami inicial",
  4L, "t = 5 min",  1050, "Cortina balística de eyección e ignición térmica en Mesoamérica",
  5L, "t = 10 min", 2100, "Onda sísmica superficial (M~11) y lluvia de esférulas (r = 2,100 km)"
)

ten_min_polys <- lapply(ten_min_specs$r_km, function(r) {
  st_buffer(center_aeqd, r * 1000) |> st_transform(4326)
})
ten_min_lines <- lapply(ten_min_specs$r_km, function(r) {
  st_boundary(st_buffer(center_aeqd, r * 1000)) |> st_transform(4326)
})

ten_min_sf <- ten_min_specs |>
  mutate(geometry = do.call(c, ten_min_lines)) |>
  st_as_sf(crs = 4326)

ten_min_poly_sf <- ten_min_specs |>
  mutate(geometry = do.call(c, ten_min_polys)) |>
  st_as_sf(crs = 4326)

# Guardar todo en data/processed/day07_dataset.rds
dataset <- list(
  mx_states       = mx_states,
  yuc_states      = yuc_states,
  yuc_union       = yuc_union,
  world_ne        = world_ne,
  anp_anillo      = anp_raw,
  flujos_sub      = flu_raw,
  all_cenotes     = all_cenotes,
  radial_profile  = radial_profile,
  rast_df         = rast_df,
  crater_rings_sf = crater_rings_sf,
  ten_min_sf      = ten_min_sf,
  ten_min_poly_sf = ten_min_poly_sf,
  chicx_center    = c(lon = chicx_lon, lat = chicx_lat)
)

saveRDS(dataset, "data/processed/day07_dataset.rds")
cat("\n¡Pipeline del Día 07 completado! Guardado en data/processed/day07_dataset.rds\n")
