# ==============================================================================
# Día 15 — Serie metropolitana | Pipeline de datos para 4 zonas metropolitanas
# Valle de México · Monterrey · Guadalajara · Puebla
#
# Salidas: data/processed/day15_serie/<id>.rds  y  <id>_dem.tif
# Autor:   Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

user_lib <- "C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3"
if (dir.exists(user_lib) && !(user_lib %in% .libPaths())) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(terra); library(sf); library(dplyr); library(tidyr)
})
sf_use_s2(FALSE)
msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n")

dir.create("data/processed/day15_serie", showWarnings = FALSE, recursive = TRUE)

CIUDADES <- list(
  cdmx = list(
    nombre = "Valle de México", corto = "Ciudad de México", metro = "zmvm",
    win = c(-99.44, -98.70, 19.08, 19.76),
    tiles = c("Copernicus_DSM_COG_10_N19_00_W100_00_DEM",
              "Copernicus_DSM_COG_10_N19_00_W099_00_DEM")
  ),
  mty = list(
    nombre = "Monterrey", corto = "Monterrey", metro = "mty",
    win = c(-100.686, -99.946, 25.346, 26.026),
    tiles = c("Copernicus_DSM_COG_30_N25_00_W101_00_DEM",
              "Copernicus_DSM_COG_30_N25_00_W100_00_DEM",
              "Copernicus_DSM_COG_30_N26_00_W101_00_DEM",
              "Copernicus_DSM_COG_30_N26_00_W100_00_DEM")
  ),
  gdl = list(
    nombre = "Guadalajara", corto = "Guadalajara", metro = "gdl",
    win = c(-103.72, -102.98, 20.33, 21.01),
    tiles = c("Copernicus_DSM_COG_30_N20_00_W104_00_DEM",
              "Copernicus_DSM_COG_30_N20_00_W103_00_DEM",
              "Copernicus_DSM_COG_30_N21_00_W104_00_DEM",
              "Copernicus_DSM_COG_30_N21_00_W103_00_DEM")
  ),
  pue = list(
    nombre = "Puebla", corto = "Puebla", metro = "pue",
    win = c(-98.57, -97.83, 18.70, 19.38),
    tiles = c("Copernicus_DSM_COG_30_N18_00_W099_00_DEM",
              "Copernicus_DSM_COG_30_N18_00_W098_00_DEM",
              "Copernicus_DSM_COG_30_N19_00_W099_00_DEM",
              "Copernicus_DSM_COG_30_N19_00_W098_00_DEM")
  )
)

mun_all  <- readRDS("data/processed/day12_power_ageb_cardinal.rds")$mun_metros
ageb_all <- readRDS("data/processed/day12_power_ageb_cardinal.rds")$ageb_metros

for (id in names(CIUDADES)) {
  cfg <- CIUDADES[[id]]
  msg("== ", cfg$nombre, " ==")

  rutas <- file.path("data/raw/day15", paste0(cfg$tiles, ".tif"))
  stopifnot(all(file.exists(rutas)))

  dem_raw <- terra::vrt(rutas)
  dem_ll  <- terra::crop(dem_raw, terra::ext(cfg$win))
  dem     <- terra::project(dem_ll, "EPSG:6372", method = "bilinear", res = 90)
  names(dem) <- "elev"

  # Rango altitudinal de la ventana
  rng <- terra::global(dem, range, na.rm = TRUE)
  zmin <- rng[1, 1]; zmax <- rng[1, 2]
  msg(sprintf("DEM %d x %d · %.0f-%.0f m", ncol(dem), nrow(dem), zmin, zmax))

  f_tif <- file.path("data/processed/day15_serie", paste0(id, "_dem.tif"))
  terra::writeRaster(dem, f_tif, overwrite = TRUE)

  # Municipios y población
  mun <- mun_all |> filter(metro_id == cfg$metro) |> st_transform(6372)
  ageb <- ageb_all |> filter(metro_id == cfg$metro) |> st_transform(6372) |>
    mutate(area_ageb = as.numeric(st_area(geometry)))

  cent <- st_centroid(ageb)
  ageb_xy <- ageb |> st_drop_geometry() |>
    mutate(cx = st_coordinates(cent)[, 1], cy = st_coordinates(cent)[, 2])

  mun_pob <- ageb_xy |>
    group_by(CVEMUN) |>
    summarise(pob = sum(POBTOT, na.rm = TRUE),
              x = weighted.mean(cx, POBTOT, na.rm = TRUE),
              y = weighted.mean(cy, POBTOT, na.rm = TRUE), .groups = "drop") |>
    left_join(mun |> st_drop_geometry() |> select(CVEMUN, NOMGEO) |> distinct(),
              by = "CVEMUN") |>
    filter(!is.na(NOMGEO)) |>
    arrange(desc(pob)) |>
    st_as_sf(coords = c("x", "y"), crs = 6372)

  stats <- tibble(
    ciudad = cfg$nombre,
    dem_min = round(zmin), dem_max = round(zmax),
    desnivel = round(zmax - zmin),
    area_km2 = round(sum(as.numeric(st_area(mun))) / 1e6, 1),
    n_mun = nrow(mun),
    pob = round(sum(ageb$POBTOT, na.rm = TRUE))
  )

  saveRDS(list(cfg = cfg, dem = f_tif, mun = mun, mun_pob = mun_pob,
               stats = stats, zmin = zmin, zmax = zmax,
               win = cfg$win, bbox = st_bbox(dem)),
          file.path("data/processed/day15_serie", paste0(id, ".rds")))
  msg(sprintf("%s: %d municipios · %.0f km² · %.0f M hab · %.0f m de desnivel",
              cfg$nombre, stats$n_mun, stats$area_km2, stats$pob / 1e6, stats$desnivel))
}

msg("Serie lista.")
