# ==============================================================================
# Día 15 — Inside out | Pipeline de datos
# "El Valle de México al revés: topografía invertida y vaso lacustre"
#
# Entradas:  data/raw/day15/Copernicus_DSM_COG_10_N19_00_W1{00,99}_00_DEM.tif
#            data/processed/day12_power_ageb_cardinal.rds  (municipios ZMVM)
# Salidas:   data/processed/day15_inside_out.rds
#            data/processed/day15_dem_30m.tif
#            data/processed/day15_hillshade.tif
#            data/processed/day15_dem_inv_30m.tif
#            data/processed/day15_hillshade_inv.tif
# Autor:     Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

user_lib <- "C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3"
if (dir.exists(user_lib) && !(user_lib %in% .libPaths())) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(terra)
  library(sf)
  library(dplyr)
  library(tidyr)
})

sf_use_s2(FALSE)
msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n")

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)

# ------------------------------------------------------------------------------
# 1. Mosaico del DEM y recorte al Valle de México
# ------------------------------------------------------------------------------
msg("Leyendo mosaicos Copernicus GLO-30...")
tiles <- c(
  "data/raw/day15/Copernicus_DSM_COG_10_N19_00_W100_00_DEM.tif",
  "data/raw/day15/Copernicus_DSM_COG_10_N19_00_W099_00_DEM.tif"
)
dem_raw <- terra::vrt(tiles)

# Municipios de la ZMVM (52) desde el acervo del Día 12
mun <- readRDS("data/processed/day12_power_ageb_cardinal.rds")$mun_metros
zmvm <- mun |> filter(metro_id == "zmvm")
zmvm_4326 <- st_transform(zmvm, 4326)

# Ventana del Valle de México: cuenca cerrada + sierras que la encierran.
# Se excluyen deliberadamente los volcanes (Popocatépetl, Iztaccíhuatl, Malinche)
# para que la inversión de relieve se lea a escala de cuenca.
bbox_zm <- st_bbox(zmvm_4326)
ext_4326 <- terra::ext(-99.44, -98.70, 19.08, 19.76)
msg("Recortando DEM al Valle de México...")
dem_ll <- terra::crop(dem_raw, ext_4326)

# Proyección métrica oficial de México (Cónica Conforme de Lambert)
dem <- terra::project(dem_ll, "EPSG:6372", method = "bilinear", res = 30)
names(dem) <- "elev"
msg(sprintf("DEM: %d x %d celdas (%.1f m)", ncol(dem), nrow(dem), res(dem)[1]))

terra::writeRaster(dem, "data/processed/day15_dem_30m.tif", overwrite = TRUE)

# ------------------------------------------------------------------------------
# 2. Relieve sombreado (normal e invertido)
# ------------------------------------------------------------------------------
msg("Calculando relieves sombreados...")
hs_normal <- terra::shade(
  terra::terrain(dem, "slope", unit = "radians"),
  terra::terrain(dem, "aspect", unit = "radians"),
  angle = 40, direction = 315, normalize = TRUE
)
names(hs_normal) <- "hillshade"

# Topografía invertida: el vaso lacustre se convierte en la cumbre
rng <- terra::global(dem, range, na.rm = TRUE)
zmin <- rng[1, 1]
zmax <- rng[1, 2]
msg(sprintf("Rango altitudinal: %.0f-%.0f m s.n.m.", zmin, zmax))

dem_inv <- (zmin + zmax) - dem
names(dem_inv) <- "elev_inv"

hs_inv <- terra::shade(
  terra::terrain(dem_inv, "slope", unit = "radians"),
  terra::terrain(dem_inv, "aspect", unit = "radians"),
  angle = 40, direction = 315, normalize = TRUE
)
names(hs_inv) <- "hillshade_inv"

terra::writeRaster(hs_normal, "data/processed/day15_hillshade.tif", overwrite = TRUE)
terra::writeRaster(hs_inv, "data/processed/day15_hillshade_inv.tif", overwrite = TRUE)
terra::writeRaster(dem_inv, "data/processed/day15_dem_inv_30m.tif", overwrite = TRUE)

# ------------------------------------------------------------------------------
# 3. Vaso lacustre histórico (cota <= 2,245 m)
# ------------------------------------------------------------------------------
msg("Delineando el vaso lacustre histórico...")
COTA <- 2245
lago_ras <- dem <= COTA

# El vaso histórico: toda la superficie bajo la cota de los lagos (2,245 m).
# En esta ventana no hay otras depresiones a esa altitud, de modo que la máscara
# equivale al conjunto de vasos lacustres del Valle de México (Texcoco,
# Xochimilco, Chalco, Xaltocan y Zumpango).
lago_ras <- terra::ifel(dem <= COTA, 1, NA)
names(lago_ras) <- "vaso"
msg(sprintf("Superficie bajo la cota %d m: %.1f km²", COTA,
            terra::global(!is.na(lago_ras), sum, na.rm = TRUE)[1, 1] * 900 / 1e6))

lago_pol <- terra::as.polygons(lago_ras, dissolve = TRUE) |>
  st_as_sf() |>
  st_make_valid() |>
  st_transform(4326)

# Área del vaso y del tejido urbano dentro del vaso
zmvm_m <- st_transform(zmvm, 6372)
lago_m <- st_transform(lago_pol, 6372)
area_lago_total <- sum(as.numeric(st_area(lago_m))) / 1e6
area_zmvm       <- sum(as.numeric(st_area(zmvm_m))) / 1e6
area_zmvm_lago  <- sum(as.numeric(st_area(st_intersection(zmvm_m, lago_m)))) / 1e6

# Cota mínima = fondo del vaso (señal del hundimiento)
zocalo <- st_sfc(st_point(c(-99.1332, 19.4326)), crs = 4326) |> st_transform(6372)

# ------------------------------------------------------------------------------
# 3b. Población que vive sobre el vaso lacustre (AGEB urbanas, censo 2020)
# ------------------------------------------------------------------------------
msg("Estimando la población asentada sobre el vaso lacustre...")
ageb <- readRDS("data/processed/day12_power_ageb_cardinal.rds")$ageb_metros |>
  filter(metro_id == "zmvm") |>
  st_transform(6372) |>
  mutate(area_ageb = as.numeric(st_area(geometry)))

inter <- st_intersection(ageb[, c("CVEGEO", "POBTOT", "area_ageb")], lago_m) |>
  mutate(area_int = as.numeric(st_area(geometry))) |>
  st_drop_geometry() |>
  group_by(CVEGEO, POBTOT, area_ageb) |>
  summarise(area_int = sum(area_int), .groups = "drop")

pob_tab <- ageb |>
  st_drop_geometry() |>
  select(CVEGEO, POBTOT, area_ageb) |>
  left_join(inter, by = c("CVEGEO", "POBTOT", "area_ageb")) |>
  mutate(
    area_int = tidyr::replace_na(area_int, 0),
    frac     = pmin(1, area_int / area_ageb),
    pob_vaso = POBTOT * frac
  )

pob_vaso  <- sum(pob_tab$pob_vaso, na.rm = TRUE)
pob_total <- sum(pob_tab$POBTOT, na.rm = TRUE)
msg(sprintf("Población sobre el vaso: %.0f de %.0f (%.1f%%)",
            pob_vaso, pob_total, 100 * pob_vaso / pob_total))

# Población y centroide ponderado por municipio (para las esferas del mapa)
msg("Agregando población por municipio...")
cent <- st_centroid(ageb)
ageb_xy <- ageb |>
  st_drop_geometry() |>
  mutate(cx = st_coordinates(cent)[, 1], cy = st_coordinates(cent)[, 2])

mun_pob <- ageb_xy |>
  group_by(CVEMUN) |>
  summarise(
    pob = sum(POBTOT, na.rm = TRUE),
    x   = weighted.mean(cx, POBTOT, na.rm = TRUE),
    y   = weighted.mean(cy, POBTOT, na.rm = TRUE),
    .groups = "drop"
  ) |>
  left_join(
    mun |> st_drop_geometry() |> select(CVEMUN, NOMGEO) |> distinct(),
    by = "CVEMUN"
  ) |>
  filter(!is.na(NOMGEO)) |>
  arrange(desc(pob)) |>
  mutate(x = x, y = y) |>
  st_as_sf(coords = c("x", "y"), crs = 6372)
msg(sprintf("Municipios con población: %d | mayor: %s (%s hab.)",
            nrow(mun_pob), mun_pob$NOMGEO[1], format(mun_pob$pob[1], big.mark = ",")))

# ------------------------------------------------------------------------------
# 4. Estadísticas y curva hipsométrica
# ------------------------------------------------------------------------------
msg("Calculando estadísticas y curva hipsométrica...")
vals <- terra::values(dem, mat = FALSE)
vals <- vals[!is.na(vals)]
pct <- quantile(vals, c(0, .01, .05, .25, .5, .75, .95, .99, 1), names = FALSE)

curva <- tibble::tibble(
  cota = seq(zmin, zmax, by = 25)
) |>
  rowwise() |>
  mutate(area_km2 = sum(vals <= cota) * (30 * 30) / 1e6) |>
  ungroup()

stats <- tibble::tibble(
  dem_min = round(min(vals)),
  dem_max = round(max(vals)),
  dem_p01 = round(pct[2]),
  dem_p50 = round(pct[5]),
  dem_p99 = round(pct[8]),
  area_estudio_km2 = round(sum(!is.na(vals)) * 900 / 1e6, 1),
  area_lago_km2 = round(area_lago_total, 1),
  area_zmvm_km2 = round(area_zmvm, 1),
  area_zmvm_en_lago_km2 = round(area_zmvm_lago, 1),
  pct_zmvm_en_lago = round(100 * area_zmvm_lago / area_zmvm, 1),
  desnivel_valle = round(max(vals) - min(vals)),
  pob_vaso = round(pob_vaso),
  pob_zmvm = round(pob_total),
  pct_pob_vaso = round(100 * pob_vaso / pob_total, 1)
)

# ------------------------------------------------------------------------------
# 5. Transecto W-E por el paralelo del Zócalo
# ------------------------------------------------------------------------------
msg("Extrayendo transecto poniente-oriente...")
p_w <- st_sfc(st_point(c(-99.42, 19.40)), crs = 4326) |> st_transform(6372)
p_e <- st_sfc(st_point(c(-98.84, 19.44)), crs = 4326) |> st_transform(6372)
trans <- st_segmentize(st_linestring(rbind(st_coordinates(p_w), st_coordinates(p_e))),
                       dfMaxLength = 250)
trans_sf <- st_sf(geometry = st_sfc(trans, crs = 6372))
perfil <- terra::extract(dem, terra::vect(trans_sf), xy = TRUE)
perfil_sf <- perfil |>
  st_as_sf(coords = c("x", "y"), crs = 6372)
perfil_sf$dist_km <- as.numeric(st_distance(perfil_sf[1, ], perfil_sf)) / 1000
perfil_sf$lon <- st_coordinates(st_transform(perfil_sf, 4326))[, 1]
perfil_sf <- perfil_sf |> arrange(dist_km)

# ------------------------------------------------------------------------------
# 6. Guardar
# ------------------------------------------------------------------------------
out <- list(
  zmvm = zmvm,
  mun_pob = mun_pob,
  lago = lago_pol,
  lago_m = lago_m,
  stats = stats,
  curva = curva,
  perfil = perfil_sf,
  zocalo = zocalo,
  zmin = zmin,
  zmax = zmax,
  cota_lago = COTA,
  bbox = st_bbox(dem)
)
saveRDS(out, "data/processed/day15_inside_out.rds")

msg(sprintf("Vaso lacustre: %.1f km² | ZMVM: %.1f km² (%.1f%% sobre el vaso)",
            area_lago_total, area_zmvm, stats$pct_zmvm_en_lago))
msg(sprintf("Altitud %d-%d m | desnivel %d m", stats$dem_min, stats$dem_max,
            stats$desnivel_valle))
msg("Pipeline Día 15 completo.")
print(stats)
