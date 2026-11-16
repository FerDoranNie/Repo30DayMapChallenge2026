# ==============================================================================
# Día 12 — Power | Pipeline de Datos Espaciales y Socioeconómicos
# "¿El Poniente siempre es más rico? Geografía cardinal del poder y la
#  desigualdad socioeconómica en las metrópolis de México"
#
# Fuentes 100% oficiales:
#   1. INEGI — Censo de Población y Vivienda 2020 (AGEB Urbana, CPV2020)
#   2. CONAPO — Índice de Marginación Urbana por AGEB 2020 (IMU_2020)
#   3. INEGI — Marco Geoestadístico Nacional 2020 (Polígonos AGEB y Municipios)
#
# Salida: data/processed/day12_power_ageb_cardinal.rds
# Autor:  Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

user_lib <- "C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3"
if (dir.exists(user_lib) && !(user_lib %in% .libPaths())) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(stringr)
  library(data.table)
  library(readxl)
})

sf_use_s2(FALSE)
dir.create("data/raw/day12", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n")
msg("Iniciando pipeline Día 12: Power (AGEBs Urbanas de México 2020)...")

# ------------------------------------------------------------------------------
# 1. Definición oficial de las Zonas Metropolitanas y Centros Históricos
#    (Claves CVE_ENT + CVE_MUN verificadas en catálogo INEGI 2020)
# ------------------------------------------------------------------------------
metros_spec <- list(
  zmvm = list(
    id = "zmvm",
    nombre = "Valle de México",
    subtitulo = "CDMX y EdoMéx",
    centro_nombre = "Zócalo CDMX",
    lon = -99.1332, lat = 19.4326,
    frame_km = 34,
    ents = c("09", "15"),
    muns = c(
      # Todas las 16 alcaldías de CDMX (09)
      sprintf("09%03d", 2:17),
      # Municipios metropolitanos del Estado de México (15)
      paste0("15", c(
        "002","011","013","020","023","024","025","028","029","030",
        "031","033","035","037","039","044","053","057","058","059",
        "060","069","070","081","091","092","095","099","100","104",
        "108","109","120","121","122","125"
      ))
    )
  ),
  mty = list(
    id = "mty",
    nombre = "Monterrey",
    subtitulo = "Nuevo León",
    centro_nombre = "Macroplaza",
    lon = -100.3099, lat = 25.6692,
    frame_km = 26,
    ents = c("19"),
    muns = paste0("19", c(
      "001","006","009","010","012","018","019","021","025","026",
      "031","039","041","045","046","047","048","049"
    ))
  ),
  gdl = list(
    id = "gdl",
    nombre = "Guadalajara",
    subtitulo = "Jalisco",
    centro_nombre = "Catedral GDL",
    lon = -103.3475, lat = 20.6767,
    frame_km = 24,
    ents = c("14"),
    muns = paste0("14", c(
      "002","039","044","051","070","097","098","101","120","124"
    ))
  ),
  pue = list(
    id = "pue",
    nombre = "Puebla–Tlaxcala",
    subtitulo = "Puebla y Tlaxcala",
    centro_nombre = "Zócalo Puebla",
    lon = -98.1982, lat = 19.0436,
    frame_km = 22,
    ents = c("21", "29"),
    muns = c(
      paste0("21", c("015","034","041","074","090","106","114","119","132","136","140","148","181")),
      paste0("29", c("017","019","022","025","027","028","029","041","042","044","058","059"))
    )
  ),
  slp = list(
    id = "slp",
    nombre = "San Luis Potosí",
    subtitulo = "San Luis Potosí",
    centro_nombre = "Plaza de Armas",
    lon = -100.9765, lat = 22.1516,
    frame_km = 16,
    ents = c("24"),
    muns = paste0("24", c("009","028","035"))
  ),
  qro = list(
    id = "qro",
    nombre = "Querétaro",
    subtitulo = "Querétaro",
    centro_nombre = "Plaza de Armas",
    lon = -100.3928, lat = 20.5931,
    frame_km = 18,
    ents = c("22"),
    muns = paste0("22", c("006","008","011","014"))
  ),
  leo = list(
    id = "leo",
    nombre = "León",
    subtitulo = "Guanajuato",
    centro_nombre = "Plaza Principal",
    lon = -101.6826, lat = 21.1221,
    frame_km = 16,
    ents = c("11"),
    muns = paste0("11", c("020","037"))
  ),
  mer = list(
    id = "mer",
    nombre = "Mérida",
    subtitulo = "Yucatán",
    centro_nombre = "Plaza Grande",
    lon = -89.6237, lat = 20.9670,
    frame_km = 20,
    ents = c("31"),
    muns = paste0("31", c("002","013","020","038","039","041","050","059","063","090","095","100","101"))
  ),
  tij = list(
    id = "tij",
    nombre = "Tijuana",
    subtitulo = "Baja California",
    centro_nombre = "Centro Tijuana",
    lon = -117.0382, lat = 32.5335,
    frame_km = 22,
    ents = c("02"),
    muns = paste0("02", c("003","004","005"))
  ),
  jrz = list(
    id = "jrz",
    nombre = "Ciudad Juárez",
    subtitulo = "Chihuahua",
    centro_nombre = "Centro Juárez",
    lon = -106.4869, lat = 31.7393,
    frame_km = 18,
    ents = c("08"),
    muns = c("08037")
  ),
  tol = list(
    id = "tol",
    nombre = "Toluca",
    subtitulo = "Estado de México",
    centro_nombre = "Plaza de los Mártires",
    lon = -99.6557, lat = 19.2925,
    frame_km = 18,
    ents = c("15"),
    muns = paste0("15", c("005","051","054","062","067","076","106","118"))
  )
)

# ------------------------------------------------------------------------------
# 2. Lectura de CONAPO IMU 2020 (50,790 AGEB urbanas nacionales)
# ------------------------------------------------------------------------------
msg("Leyendo Índice de Marginación Urbana CONAPO 2020 (IMU_2020.xls)...")
imu_raw <- read_excel("data/raw/day12/IMU_2020.xls", sheet = "IMU_2020") |>
  transmute(
    CVEGEO   = str_pad(as.character(CVE_AGEB), 13, pad = "0"),
    POB_IMU  = as.numeric(POB_TOTAL),
    SBASC    = as.numeric(SBASC),
    OVHAC    = as.numeric(OVHAC),
    OVSINT   = as.numeric(OVSINT),
    IM_2020  = as.numeric(IM_2020),
    GM_2020  = as.character(GM_2020),
    IMN_2020 = as.numeric(IMN_2020)
  )
msg("  IMU_2020 filas:", nrow(imu_raw))

# ------------------------------------------------------------------------------
# 3. Lectura de AGEBs (Shapefiles Marco Geoestadístico 2020) y Censo 2020 (CSV)
# ------------------------------------------------------------------------------
all_ents <- sort(unique(unlist(lapply(metros_spec, `[[`, "ents"))))
all_muns <- unique(unlist(lapply(metros_spec, `[[`, "muns")))

parse_num <- function(x) {
  x <- as.character(x)
  x[x %in% c("*", "N/D", "", "NA")] <- NA_character_
  suppressWarnings(as.numeric(x))
}

read_state_agebs <- function(ent) {
  msg("Cargando entidad ", ent, "...")
  shp_path <- list.files(
    paste0("data/raw/day12/ent_", ent),
    pattern = paste0("^", ent, "a\\.shp$"),
    recursive = TRUE, full.names = TRUE
  )[1]
  mun_path <- list.files(
    paste0("data/raw/day12/ent_", ent),
    pattern = paste0("^", ent, "mun\\.shp$"),
    recursive = TRUE, full.names = TRUE
  )[1]
  csv_path <- list.files(
    paste0("data/raw/day12/ent_", ent),
    pattern = paste0("conjunto_de_datos_ageb_urbana_", ent, "_cpv2020\\.csv$"),
    recursive = TRUE, full.names = TRUE
  )[1]

  shp <- st_read(shp_path, quiet = TRUE) |>
    st_transform(6372) |>
    mutate(
      CVEGEO = as.character(CVEGEO),
      CVEMUN = paste0(str_pad(CVE_ENT, 2, pad = "0"), str_pad(CVE_MUN, 3, pad = "0"))
    ) |>
    filter(CVEMUN %in% all_muns)

  mun_shp <- st_read(mun_path, quiet = TRUE) |>
    st_transform(6372) |>
    mutate(CVEMUN = paste0(str_pad(CVE_ENT, 2, pad = "0"), str_pad(CVE_MUN, 3, pad = "0"))) |>
    filter(CVEMUN %in% all_muns)

  cols_keep <- c(
    "ENTIDAD", "MUN", "LOC", "AGEB", "MZA",
    "POBTOT", "GRAPROES", "TVIVPARHAB",
    "VPH_AUTOM", "VPH_PC", "VPH_INTER", "VPH_3YMASC", "VPH_REFRI"
  )
  dt <- fread(
    csv_path,
    select = cols_keep,
    colClasses = list(character = c("ENTIDAD", "MUN", "LOC", "AGEB", "MZA")),
    showProgress = FALSE
  )
  dt_ageb <- dt[MZA == "000" & AGEB != "0000"]
  dt_ageb[, CVEGEO := paste0(
    str_pad(ENTIDAD, 2, pad = "0"),
    str_pad(MUN, 3, pad = "0"),
    str_pad(LOC, 4, pad = "0"),
    str_pad(AGEB, 4, pad = "0")
  )]

  cen_df <- as_tibble(dt_ageb) |>
    transmute(
      CVEGEO,
      POBTOT     = parse_num(POBTOT),
      GRAPROES   = parse_num(GRAPROES),
      TVIVPARHAB = parse_num(TVIVPARHAB),
      VPH_AUTOM  = parse_num(VPH_AUTOM),
      VPH_PC     = parse_num(VPH_PC),
      VPH_INTER  = parse_num(VPH_INTER),
      VPH_3YMASC = parse_num(VPH_3YMASC)
    )

  joined <- shp |>
    left_join(cen_df, by = "CVEGEO") |>
    left_join(imu_raw, by = "CVEGEO")

  list(ageb = joined, mun = mun_shp)
}

state_data <- lapply(all_ents, read_state_agebs)
names(state_data) <- all_ents

ageb_all <- bind_rows(lapply(state_data, `[[`, "ageb"))
mun_all  <- bind_rows(lapply(state_data, `[[`, "mun"))

msg("Total de polígonos AGEB cargados en municipios metropolitanos:", nrow(ageb_all))

# ------------------------------------------------------------------------------
# 4. Asignación a Metrópolis, Cálculo de Métricas y Coordenadas Cardinales
# ------------------------------------------------------------------------------
assign_octant <- function(az) {
  # 0° = N, 90° = E, 180° = S, 270° = W
  cut(
    (az + 22.5) %% 360,
    breaks = seq(0, 360, by = 45),
    labels = c("N", "NE", "E", "SE", "S", "SW", "W", "NW"),
    include.lowest = TRUE, right = FALSE
  ) |> as.character()
}

metro_ageb_list <- list()
metro_mun_list  <- list()
metro_centers_list <- list()

for (m_id in names(metros_spec)) {
  sp <- metros_spec[[m_id]]
  c_pt <- st_sfc(st_point(c(sp$lon, sp$lat)), crs = 4326) |>
    st_transform(6372)
  c_xy <- st_coordinates(c_pt)

  sub_ageb <- ageb_all |>
    filter(CVEMUN %in% sp$muns) |>
    st_make_valid()

  pts <- st_point_on_surface(sub_ageb)
  xy  <- st_coordinates(pts)

  sub_ageb <- sub_ageb |>
    mutate(
      metro_id      = sp$id,
      metro_nombre  = sp$nombre,
      metro_sub     = sp$subtitulo,
      centro_nombre = sp$centro_nombre,
      cx_m          = c_xy[1, 1],
      cy_m          = c_xy[1, 2],
      dx_km         = (xy[, 1] - c_xy[1, 1]) / 1000,
      dy_km         = (xy[, 2] - c_xy[1, 2]) / 1000,
      dist_km       = sqrt(dx_km^2 + dy_km^2),
      azimut_deg    = (atan2(dx_km, dy_km) * 180 / pi) %% 360,
      octant        = assign_octant(azimut_deg),
      hemisferio_we = case_when(
        azimut_deg >= 202.5 & azimut_deg <= 337.5 ~ "Poniente (W/SW/NW)",
        azimut_deg >= 22.5  & azimut_deg <= 157.5 ~ "Oriente (E/NE/SE)",
        TRUE                                      ~ "Eje N–S"
      ),
      hemisferio_ns = case_when(
        azimut_deg <= 67.5 | azimut_deg >= 292.5  ~ "Norte (N/NE/NW)",
        azimut_deg >= 112.5 & azimut_deg <= 247.5 ~ "Sur (S/SE/SW)",
        TRUE                                      ~ "Eje E–W"
      ),
      pct_autom = ifelse(!is.na(TVIVPARHAB) & TVIVPARHAB >= 15, 100 * VPH_AUTOM  / TVIVPARHAB, NA_real_),
      pct_pc    = ifelse(!is.na(TVIVPARHAB) & TVIVPARHAB >= 15, 100 * VPH_PC     / TVIVPARHAB, NA_real_),
      pct_inter = ifelse(!is.na(TVIVPARHAB) & TVIVPARHAB >= 15, 100 * VPH_INTER  / TVIVPARHAB, NA_real_),
      pct_3ymas = ifelse(!is.na(TVIVPARHAB) & TVIVPARHAB >= 15, 100 * VPH_3YMASC / TVIVPARHAB, NA_real_),
      # Validar cobertura completa de las 5 variables censales
      valid_ips = !is.na(POBTOT) & POBTOT >= 50 & !is.na(TVIVPARHAB) & TVIVPARHAB >= 15 &
                  is.finite(GRAPROES) & is.finite(pct_autom) & is.finite(pct_pc) &
                  is.finite(pct_inter) & is.finite(pct_3ymas)
    )

  metro_ageb_list[[m_id]] <- sub_ageb
  metro_mun_list[[m_id]]  <- mun_all |>
    filter(CVEMUN %in% sp$muns) |>
    mutate(metro_id = sp$id, metro_nombre = sp$nombre)
  metro_centers_list[[m_id]] <- tibble(
    metro_id = sp$id,
    metro_nombre = sp$nombre,
    metro_sub = sp$subtitulo,
    centro_nombre = sp$centro_nombre,
    lon = sp$lon, lat = sp$lat,
    cx_m = c_xy[1, 1], cy_m = c_xy[1, 2],
    frame_km = sp$frame_km
  )
}

ageb_metros <- bind_rows(metro_ageb_list)
mun_metros  <- bind_rows(metro_mun_list)
centers_df  <- bind_rows(metro_centers_list)

# ------------------------------------------------------------------------------
# 5. Cálculo del Índice de Poder Socioeconómico (IPS) vía PCA
# ------------------------------------------------------------------------------
msg("Calculando Índice de Poder Socioeconómico (IPS) mediante PCA...")

# Imputar IMN_2020 faltante puntual con regresión o usar las 5 variables censales + IMN cuando exista;
# verificamos cobertura primero
valid_rows <- ageb_metros |>
  st_drop_geometry() |>
  filter(valid_ips)

msg("  AGEBs válidas (POBTOT >= 50, TVIVPARHAB >= 15):", nrow(valid_rows),
    "de", nrow(ageb_metros),
    "| Con IMN_2020:", sum(!is.na(valid_rows$IMN_2020)))

# Para PCA nacional consistente en 100% de las AGEBs válidas, usamos las 5 variables censales directas
# de INEGI (todas disponibles al 100% en valid_rows) + correlación con IMN_2020 como validación externa
pca_mat <- valid_rows |>
  select(GRAPROES, pct_autom, pct_pc, pct_inter, pct_3ymas) |>
  as.matrix()

pca_fit <- prcomp(pca_mat, center = TRUE, scale. = TRUE)
var_exp <- (pca_fit$sdev^2 / sum(pca_fit$sdev^2))[1]
pc1 <- pca_fit$x[, 1]
if (cor(pc1, valid_rows$GRAPROES) < 0) pc1 <- -pc1

msg(sprintf("  Varianza explicada por PC1 (IPS): %.1f%%", 100 * var_exp))
msg(sprintf("  Correlación IPS vs IMN_2020 (CONAPO): r = %.3f",
            cor(pc1, valid_rows$IMN_2020, use = "complete.obs")))

# Estandarizar IPS global (Z-score y Percentil 0-100 nacional urbano)
ips_mean_g <- mean(pc1)
ips_sd_g   <- sd(pc1)

valid_keys <- valid_rows |>
  mutate(
    IPS_raw = pc1,
    IPS_z   = (pc1 - ips_mean_g) / ips_sd_g,
    IPS_pct = 100 * percent_rank(pc1)
  ) |>
  select(metro_id, CVEGEO, IPS_raw, IPS_z, IPS_pct)

# Estandarizar también IPS intra-ciudad (ponderado por población) para comparar dirección pura
ageb_metros <- ageb_metros |>
  left_join(valid_keys, by = c("metro_id", "CVEGEO")) |>
  group_by(metro_id) |>
  mutate(
    city_ips_mean_w = weighted.mean(IPS_z, w = POBTOT, na.rm = TRUE),
    city_ips_sd_w   = sqrt(sum(POBTOT * (IPS_z - city_ips_mean_w)^2, na.rm = TRUE) /
                           sum(POBTOT[!is.na(IPS_z)], na.rm = TRUE)),
    IPS_city_z      = (IPS_z - city_ips_mean_w) / city_ips_sd_w,
    IPS_city_pct    = 100 * percent_rank(IPS_z)
  ) |>
  ungroup()

# ------------------------------------------------------------------------------
# 6. Resumen por Octante Cardinal y Vector Resultante por Metrópoli
# ------------------------------------------------------------------------------
msg("Calculando rosa cardinal (8 octantes) y vector resultante de poder...")

oct_levels <- c("N", "NE", "E", "SE", "S", "SW", "W", "NW")
oct_angles <- c(N = 0, NE = 45, E = 90, SE = 135, S = 180, SW = 225, W = 270, NW = 315)

octant_summary <- ageb_metros |>
  st_drop_geometry() |>
  filter(valid_ips, dist_km >= 0.5) |>
  group_by(metro_id, metro_nombre, octant) |>
  summarise(
    n_ageb       = n(),
    pob_octant   = sum(POBTOT, na.rm = TRUE),
    ips_pct_mean = weighted.mean(IPS_pct, w = POBTOT, na.rm = TRUE),
    ips_z_mean   = weighted.mean(IPS_z,   w = POBTOT, na.rm = TRUE),
    ips_city_z   = weighted.mean(IPS_city_z, w = POBTOT, na.rm = TRUE),
    graproes_w   = weighted.mean(GRAPROES, w = POBTOT, na.rm = TRUE),
    autom_w      = weighted.mean(pct_autom, w = TVIVPARHAB, na.rm = TRUE),
    inter_w      = weighted.mean(pct_inter, w = TVIVPARHAB, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    octant = factor(octant, levels = oct_levels),
    azimut_oct = unname(oct_angles[as.character(octant)])
  )

city_summary <- ageb_metros |>
  st_drop_geometry() |>
  filter(valid_ips, dist_km >= 0.5) |>
  group_by(metro_id, metro_nombre, metro_sub, centro_nombre) |>
  summarise(
    n_ageb          = n(),
    pob_total       = sum(POBTOT, na.rm = TRUE),
    graproes_city   = weighted.mean(GRAPROES, w = POBTOT, na.rm = TRUE),
    autom_city      = weighted.mean(pct_autom, w = TVIVPARHAB, na.rm = TRUE),
    ips_pct_city    = weighted.mean(IPS_pct, w = POBTOT, na.rm = TRUE),
    # Vector resultante ponderado por población y exceso de poder sobre la media local
    vx = {
      w <- POBTOT * (IPS_z - weighted.mean(IPS_z, w = POBTOT))
      sum(w * sin(azimut_deg * pi / 180)) / sum(abs(w))
    },
    vy = {
      w <- POBTOT * (IPS_z - weighted.mean(IPS_z, w = POBTOT))
      sum(w * cos(azimut_deg * pi / 180)) / sum(abs(w))
    },
    # Brecha Poniente (W/SW/NW) vs Oriente (E/NE/SE)
    ips_pct_w = weighted.mean(IPS_pct[hemisferio_we == "Poniente (W/SW/NW)"],
                              w = POBTOT[hemisferio_we == "Poniente (W/SW/NW)"], na.rm = TRUE),
    ips_pct_e = weighted.mean(IPS_pct[hemisferio_we == "Oriente (E/NE/SE)"],
                              w = POBTOT[hemisferio_we == "Oriente (E/NE/SE)"], na.rm = TRUE),
    graproes_w = weighted.mean(GRAPROES[hemisferio_we == "Poniente (W/SW/NW)"],
                               w = POBTOT[hemisferio_we == "Poniente (W/SW/NW)"], na.rm = TRUE),
    graproes_e = weighted.mean(GRAPROES[hemisferio_we == "Oriente (E/NE/SE)"],
                               w = POBTOT[hemisferio_we == "Oriente (E/NE/SE)"], na.rm = TRUE),
    autom_w = weighted.mean(pct_autom[hemisferio_we == "Poniente (W/SW/NW)"],
                            w = TVIVPARHAB[hemisferio_we == "Poniente (W/SW/NW)"], na.rm = TRUE),
    autom_e = weighted.mean(pct_autom[hemisferio_we == "Oriente (E/NE/SE)"],
                            w = TVIVPARHAB[hemisferio_we == "Oriente (E/NE/SE)"], na.rm = TRUE),
    # Brecha Norte (N/NE/NW) vs Sur (S/SE/SW)
    ips_pct_n = weighted.mean(IPS_pct[hemisferio_ns == "Norte (N/NE/NW)"],
                              w = POBTOT[hemisferio_ns == "Norte (N/NE/NW)"], na.rm = TRUE),
    ips_pct_s = weighted.mean(IPS_pct[hemisferio_ns == "Sur (S/SE/SW)"],
                              w = POBTOT[hemisferio_ns == "Sur (S/SE/SW)"], na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    vec_azimut      = (atan2(vx, vy) * 180 / pi) %% 360,
    vec_octant      = assign_octant(vec_azimut),
    segregacion_R   = sqrt(vx^2 + vy^2),
    gap_we_pct      = ips_pct_w - ips_pct_e,
    gap_we_graproes = graproes_w - graproes_e,
    gap_we_autom    = autom_w - autom_e,
    gap_ns_pct      = ips_pct_n - ips_pct_s
  )

# Añadir sector más rico y más vulnerable por ciudad
oct_extremes <- octant_summary |>
  group_by(metro_id) |>
  summarise(
    oct_rico = as.character(octant[which.max(ips_pct_mean)]),
    ips_rico = max(ips_pct_mean),
    oct_pob  = as.character(octant[which.min(ips_pct_mean)]),
    ips_pob  = min(ips_pct_mean),
    gap_max_oct = ips_rico - ips_pob,
    .groups = "drop"
  )

city_summary <- city_summary |>
  left_join(oct_extremes, by = "metro_id") |>
  mutate(
    regla_poniente = case_when(
      vec_octant %in% c("W", "SW", "NW") & gap_we_pct > 4 ~ "Confirma: Poniente / SW",
      vec_octant %in% c("N", "NE")                        ~ "Excepción: Norte / NE",
      vec_octant %in% c("E", "SE")                        ~ "Inversión: Oriente / SE",
      TRUE                                                ~ "Mixto / Transicional"
    )
  ) |>
  arrange(desc(pob_total))

# ------------------------------------------------------------------------------
# 7. Perfil Longitudinal Oeste -> Este del Valle de México (Transecto Zócalo)
# ------------------------------------------------------------------------------
profile_we_zmvm <- ageb_metros |>
  st_drop_geometry() |>
  filter(metro_id == "zmvm", valid_ips, abs(dy_km) <= 18, dx_km >= -30, dx_km <= 30) |>
  mutate(bin_x = round(dx_km / 2) * 2) |>
  group_by(bin_x) |>
  summarise(
    n_ageb     = n(),
    pob        = sum(POBTOT, na.rm = TRUE),
    ips_pct_w  = weighted.mean(IPS_pct, w = POBTOT, na.rm = TRUE),
    graproes_w = weighted.mean(GRAPROES, w = POBTOT, na.rm = TRUE),
    autom_w    = weighted.mean(pct_autom, w = TVIVPARHAB, na.rm = TRUE),
    .groups = "drop"
  ) |>
  filter(n_ageb >= 5)

# Imprimir resumen diagnóstico completo
cat("\n================= RESUMEN METROPOLITANO (DAY 12: POWER) =================\n")
print(
  city_summary |>
    select(metro_id, metro_nombre, pob_total, vec_octant, vec_azimut, segregacion_R,
           oct_rico, oct_pob, gap_we_pct, gap_we_graproes, gap_ns_pct, regla_poniente),
  n = 20, width = 160
)

# Guardar RDS completo
out_rds <- "data/processed/day12_power_ageb_cardinal.rds"
saveRDS(
  list(
    ageb_metros     = ageb_metros,
    mun_metros      = mun_metros,
    centers_df      = centers_df,
    octant_summary  = octant_summary,
    city_summary    = city_summary,
    profile_we_zmvm = profile_we_zmvm,
    pca_var_exp     = var_exp
  ),
  out_rds
)
msg("Pipeline completado. Dataset guardado en: ", out_rds)
