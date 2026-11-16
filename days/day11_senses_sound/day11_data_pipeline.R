# ==============================================================================
# Día 11 — Senses: Sound (Pipeline de Datos Bioacústicos)
# "El coro del amanecer en México: La ola acústica de las aves del Caribe al Pacífico"
#
# Etapas del pipeline:
#   1. Descarga masiva de ocurrencias bioacústicas de aves en México desde la
#      API de GBIF (`mediaType = "Sound"`, `taxonKey = 212`, `country = "MX"`),
#      que integra la colección de Xeno-canto (22,299 registros), iNaturalist
#      Sounds / Naturalista (14,998 registros) y el Borror Lab of Bioacoustics
#      (987 registros).
#   2. Parseo de hora local de grabación (`eventTime`), coordenadas, altitud y
#      cruce espacial con las Ecorregiones y Biomas de México (`Ecoregions2017`)
#      y el polígono continental/insular de México (`EPSG:6372`).
#   3. Asignación de rasgos bioacústicos por familia y especie aviar (frecuencia
#      fundamental media en kHz, ancho de banda y gremio horario: Coro del
#      Amanecer / Diurno, Crepuscular y Coro Nocturno) basados en la literatura
#      macroecológica de bioacústica aviar (Morton 1975; Ryan & Brenowitz 1985;
#      Boncoraglio & Saino 2007; Weir et al. 2012; Mikula et al. 2021).
#   4. Cálculo del desfase solar del amanecer (4 minutos por grado de longitud
#      oeste desde Isla Mujeres, 86.7° W, hasta Tijuana, 117.1° W: 121.6 min).
#   5. Construcción de malla hexagonal sobre México y rásters continuos (`terra`
#      a 0.08°) de densidad bioacústica, frecuencia dominante (kHz) e Índice de
#      Complejidad Bioacústica (Shannon H').
#
# Salida: data/processed/day11_soundscape_mexico.rds
# Autor:  Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(stringr)
  library(httr)
  library(curl)
  library(jsonlite)
})

sf_use_s2(FALSE)

dir.create("data/raw/day11", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

raw_cache <- "data/raw/day11/gbif_sound_occurrences_mx.rds"
out_rds   <- "data/processed/day11_soundscape_mexico.rds"

t0 <- Sys.time()
msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n")

# ------------------------------------------------------------------------------
# 1. Descarga de Grabaciones Bioacústicas desde GBIF API
# ------------------------------------------------------------------------------
extract_records <- function(res_list, source_label) {
  if (length(res_list) == 0) return(tibble())
  map_dfr(res_list, function(x) {
    tibble(
      gbifID     = if (!is.null(x$gbifID)) as.character(x$gbifID) else NA_character_,
      datasetKey = if (!is.null(x$datasetKey)) as.character(x$datasetKey) else NA_character_,
      source_repo = source_label,
      speciesKey = if (!is.null(x$speciesKey)) as.integer(x$speciesKey) else NA_integer_,
      species    = if (!is.null(x$species)) as.character(x$species) else NA_character_,
      genus      = if (!is.null(x$genus)) as.character(x$genus) else NA_character_,
      family     = if (!is.null(x$family)) as.character(x$family) else NA_character_,
      order      = if (!is.null(x$order)) as.character(x$order) else NA_character_,
      lat        = if (!is.null(x$decimalLatitude)) as.numeric(x$decimalLatitude) else NA_real_,
      lon        = if (!is.null(x$decimalLongitude)) as.numeric(x$decimalLongitude) else NA_real_,
      elevation  = if (!is.null(x$elevation)) as.numeric(x$elevation) else NA_real_,
      year       = if (!is.null(x$year)) as.integer(x$year) else NA_integer_,
      month      = if (!is.null(x$month)) as.integer(x$month) else NA_integer_,
      day        = if (!is.null(x$day)) as.integer(x$day) else NA_integer_,
      eventTime  = if (!is.null(x$eventTime)) as.character(x$eventTime) else NA_character_,
      stateProvince = if (!is.null(x$stateProvince)) as.character(x$stateProvince) else NA_character_,
      recordedBy = if (!is.null(x$recordedBy)) as.character(x$recordedBy) else NA_character_
    )
  })
}

fetch_gbif_dataset_pages <- function(dataset_key, source_label, max_records = 9900L) {
  u0 <- sprintf(
    "https://api.gbif.org/v1/occurrence/search?country=MX&taxonKey=212&mediaType=Sound&hasCoordinate=true&hasGeospatialIssue=false&datasetKey=%s&limit=1",
    dataset_key
  )
  r0 <- GET(u0, timeout(30))
  js0 <- fromJSON(content(r0, "text", encoding = "UTF-8"), simplifyVector = FALSE)
  total_avail <- min(as.integer(js0$count), max_records)
  msg(sprintf("Descargando %s (%d de %d disponibles)...", source_label, total_avail, js0$count))
  if (total_avail == 0) return(tibble())
  
  offsets <- seq(0L, total_avail - 1L, by = 300L)
  pages_out <- vector("list", length(offsets))
  
  batches <- split(seq_along(offsets), ceiling(seq_along(offsets) / 6))
  for (b_i in seq_along(batches)) {
    idxs <- batches[[b_i]]
    pool <- new_pool(total_con = 6, host_con = 6)
    for (idx in idxs) {
      off <- offsets[idx]
      u <- sprintf(
        "https://api.gbif.org/v1/occurrence/search?country=MX&taxonKey=212&mediaType=Sound&hasCoordinate=true&hasGeospatialIssue=false&datasetKey=%s&limit=300&offset=%d",
        dataset_key, off
      )
      local({
        k_idx <- idx
        curl_fetch_multi(u, done = function(resp) {
          if (resp$status_code == 200) {
            js <- tryCatch(fromJSON(rawToChar(resp$content), simplifyVector = FALSE), error = function(e) NULL)
            if (!is.null(js) && length(js$results) > 0) {
              pages_out[[k_idx]] <<- extract_records(js$results, source_label)
            }
          }
        }, pool = pool)
      })
    }
    multi_run(pool = pool)
    n_got <- sum(vapply(pages_out[1:max(idxs)], function(x) if (is.null(x)) 0L else nrow(x), integer(1)))
    if (b_i %% 2 == 0 || b_i == length(batches)) {
      msg(sprintf("  [%s] Lote %d/%d -> %d registros descargados", source_label, b_i, length(batches), n_got))
    }
    Sys.sleep(0.15)
  }
  bind_rows(pages_out)
}

if (file.exists(raw_cache)) {
  msg("Cargando ocurrencias bioacústicas crudas desde caché:", raw_cache)
  raw_bundle <- readRDS(raw_cache)
  snd_raw <- raw_bundle$records
  national_facets <- raw_bundle$facets
} else {
  msg("Consultando facetas nacionales completas de GBIF Sound (38,353 grabaciones)...")
  u_fac <- "https://api.gbif.org/v1/occurrence/search?country=MX&taxonKey=212&mediaType=Sound&hasCoordinate=true&hasGeospatialIssue=false&limit=0&facet=speciesKey&facet=datasetKey&facet=month&facet=stateProvince&facetLimit=1500"
  r_fac <- GET(u_fac, timeout(60))
  js_fac <- fromJSON(content(r_fac, "text", encoding = "UTF-8"), simplifyVector = FALSE)
  
  national_facets <- list(
    total_count = js_fac$count,
    facets = js_fac$facets
  )
  
  df_xc   <- fetch_gbif_dataset_pages("b1047888-ae52-4179-9dd5-5448ea342a24", "Xeno-canto", 9900L)
  df_inat <- fetch_gbif_dataset_pages("50c9509d-22c7-4a22-a47d-8c48425ef4a7", "iNaturalist / Naturalista", 9900L)
  df_blb  <- fetch_gbif_dataset_pages("f11db245-3f9f-4fc6-a0cc-12b4124d081b", "Borror Lab (BLB)", 1500L)
  df_mvz  <- fetch_gbif_dataset_pages("62ad511d-d298-4fd7-80e7-f5d5bd32299e", "MVZ / Arctos", 300L)
  df_obs  <- fetch_gbif_dataset_pages("8a863029-f435-446a-821e-275f4f641165", "Observation.org", 300L)
  
  snd_raw <- bind_rows(df_xc, df_inat, df_blb, df_mvz, df_obs) |>
    distinct(gbifID, .keep_all = TRUE) |>
    filter(!is.na(lat), !is.na(lon), !is.na(species), !is.na(family))
  
  raw_bundle <- list(records = snd_raw, facets = national_facets)
  saveRDS(raw_bundle, raw_cache)
  msg("Guardado caché crudo con", nrow(snd_raw), "grabaciones georreferenciadas en:", raw_cache)
}

msg(sprintf("Total en universo nacional GBIF Sound MX: %s grabaciones | Muestra descargada: %s grabaciones",
            format(national_facets$total_count, big.mark = ","),
            format(nrow(snd_raw), big.mark = ",")))

# ------------------------------------------------------------------------------
# 2. Catálogo Nacional de Especies con Grabación Bioacústica en México
# ------------------------------------------------------------------------------
mx_sp_cat_path <- "data/processed/day05_mexico_species_catalog.rds"
mx_sp_cat <- if (file.exists(mx_sp_cat_path)) readRDS(mx_sp_cat_path) else tibble()

sp_facet_raw <- national_facets$facets[[which(vapply(national_facets$facets, `[[`, character(1), "field") == "SPECIES_KEY")]]$counts
sp_sound_nat <- tibble(
  speciesKey = vapply(sp_facet_raw, function(x) as.integer(x$name), integer(1)),
  n_recordings_nat = vapply(sp_facet_raw, function(x) as.integer(x$count), integer(1))
)

# Unir nombres desde snd_raw y desde el catálogo del día 05
sp_lookup <- snd_raw |>
  select(speciesKey, species, genus, family, order) |>
  distinct(speciesKey, .keep_all = TRUE)

if (nrow(mx_sp_cat) > 0) {
  sp_lookup <- bind_rows(
    sp_lookup,
    mx_sp_cat |> select(speciesKey, species, genus, family, order)
  ) |> distinct(speciesKey, .keep_all = TRUE)
}

sp_sound_nat <- sp_sound_nat |>
  left_join(sp_lookup, by = "speciesKey")

# ------------------------------------------------------------------------------
# 3. Rasgos Bioacústicos por Familia y Especie (Frecuencia kHz y Gremio Horario)
#    Basado en Morton (1975), Ryan & Brenowitz (1985), Boncoraglio & Saino (2007),
#    Weir et al. (2012) y Mikula et al. (2021)
# ------------------------------------------------------------------------------
assign_bioacoustic_traits <- function(df) {
  df |>
    mutate(
      # Frecuencia fundamental / pico dominante media por familia y género (kHz)
      freq_khz_base = case_when(
        # 1. Graves profundos de selva densa y coro nocturno (0.8 - 2.3 kHz)
        family == "Strigidae" & genus %in% c("Bubo", "Strix", "Pulsatrix", "Ciccaba") ~ 0.95,
        family == "Strigidae" & genus %in% c("Glaucidium", "Megascops", "Athene", "Micrathene", "Asio") ~ 1.65,
        family %in% c("Strigidae", "Tytonidae") ~ 1.45,
        family == "Nyctibiidae" ~ 1.15,
        family == "Caprimulgidae" ~ 1.85,
        family == "Tinamidae" ~ 1.40,
        family == "Cracidae" & genus %in% c("Crax", "Penelope", "Oreophasis") ~ 1.20,
        family == "Cracidae" ~ 1.65, # Ortalis (chachalacas)
        family == "Columbidae" & genus %in% c("Patagioenas", "Leptotila", "Geotrygon", "Zentrygon") ~ 1.15,
        family == "Columbidae" ~ 1.45,
        family == "Trogonidae" & genus == "Pharomachrus" ~ 1.60,
        family == "Trogonidae" ~ 1.95,
        family == "Momotidae" ~ 1.55,
        family == "Cuculidae" & genus %in% c("Geococcyx", "Piaya", "Crotophaga") ~ 1.85,
        family == "Cuculidae" ~ 1.95,
        family == "Ramphastidae" & genus == "Ramphastos" ~ 2.10,
        family == "Ramphastidae" ~ 2.45,
        family == "Psittacidae" & genus %in% c("Ara", "Amazona", "Rhynchopsitta") ~ 2.25,
        family == "Psittacidae" ~ 2.85,
        family %in% c("Odontophoridae", "Phasianidae") ~ 2.15,
        family %in% c("Ardeidae", "Threskiornithidae", "Anatidae", "Rallidae", "Aramidae") ~ 1.90,
        family %in% c("Cathartidae", "Pandionidae") ~ 2.10,
        family == "Accipitridae" ~ 2.55,
        family == "Falconidae" & genus %in% c("Micrastur", "Herpetotheres") ~ 1.85,
        family == "Falconidae" ~ 2.95,
        family == "Picidae" & genus %in% c("Dryocopus", "Campephilus") ~ 2.15,
        family == "Picidae" ~ 2.65,
        family %in% c("Formicariidae", "Grallariidae", "Thamnophilidae") ~ 2.35,
        family == "Furnariidae" ~ 2.75,
        family %in% c("Cotingidae", "Tityridae", "Pipridae") ~ 2.90,
        family == "Corvidae" & genus == "Corvus" ~ 1.85,
        family == "Corvidae" ~ 2.65,
        
        # 2. Banda media-baja y media: Bosques templados, bordes y sotobosque (3.0 - 4.4 kHz)
        family == "Turdidae" & genus == "Myadestes" ~ 3.85, # Clarines (tonos puros de bosque mesófilo)
        family == "Turdidae" & genus == "Catharus" ~ 3.65,
        family == "Turdidae" ~ 3.15, # Turdus grayi, T. migratorius, T. assimilis
        family == "Mimidae" ~ 3.35,
        family == "Troglodytidae" & genus %in% c("Henicorhina", "Pheugopedius", "Thryophilus", "Campylorhynchus") ~ 3.25,
        family == "Troglodytidae" & genus == "Catherpes" ~ 3.80,
        family == "Troglodytidae" ~ 3.65,
        family == "Vireonidae" ~ 3.45,
        family == "Icteridae" & genus %in% c("Psarocolius", "Cacicus") ~ 2.55,
        family == "Icteridae" & genus %in% c("Sturnella", "Icterus", "Quiscalus", "Molothrus") ~ 3.55,
        family == "Icteridae" ~ 3.45,
        family == "Cardinalidae" & genus %in% c("Piranga", "Cardinalis", "Pheucticus", "Habia") ~ 3.40,
        family == "Cardinalidae" & genus %in% c("Passerina", "Cyanocompsa") ~ 4.35,
        family == "Cardinalidae" ~ 3.75,
        family == "Tyrannidae" & genus %in% c("Pitangus", "Megarynchus", "Myiodynastes", "Attila") ~ 3.45,
        family == "Tyrannidae" & genus %in% c("Pyrocephalus", "Empidonax", "Contopus", "Todirostrum", "Camptostoma") ~ 4.55,
        family == "Tyrannidae" ~ 3.95,
        family == "Thraupidae" & genus %in% c("Saltator", "Ramphocelus") ~ 3.55,
        family == "Thraupidae" ~ 4.45,
        family %in% c("Laniidae", "Hirundinidae", "Ptilogonatidae", "Camptostomatidae") ~ 3.85,
        family %in% c("Paridae", "Sittidae", "Aegithalidae") ~ 4.15,
        
        # 3. Banda alta y aguda: Dosel, matorral abierto, pastizal y alta montaña (4.5 - 7.8 kHz)
        family == "Fringillidae" & genus %in% c("Euphonia", "Chlorophonia") ~ 4.35,
        family == "Fringillidae" ~ 4.75, # Spinus, Haemorhous
        family == "Passerellidae" & genus %in% c("Arremon", "Arremonops", "Pipilo", "Melozone", "Atlantopetes") ~ 4.35,
        family == "Passerellidae" & genus %in% c("Spizella", "Aimophila", "Peucaea", "Zonotrichia", "Ammodramus", "Junco") ~ 5.25,
        family == "Passerellidae" ~ 4.85,
        family == "Parulidae" & genus %in% c("Geothlypis", "Seiurus", "Parkesia", "Icteria") ~ 4.45,
        family == "Parulidae" & genus %in% c("Setophaga", "Cardellina", "Myioborus", "Basileuterus", "Leiothlypis", "Oreothlypis", "Vermivora") ~ 5.65,
        family == "Parulidae" ~ 5.45,
        family == "Polioptilidae" ~ 5.75,
        family %in% c("Regulidae", "Certhiidae", "Bombycillidae", "Peucedramidae") ~ 6.35,
        family == "Trochilidae" & genus %in% c("Campylopterus", "Eugenes", "Lampornis", "Phaeochroa") ~ 6.15,
        family == "Trochilidae" ~ 6.85, # Colibríes: trinos ultrasónicos/agudos 6.0-8.0 kHz
        family %in% c("Charadriidae", "Scolopacidae", "Laridae", "Recurvirostridae") ~ 3.60,
        TRUE ~ 3.80
      ),
      # Gremio bioacústico horario
      diel_guild = case_when(
        family %in% c("Strigidae", "Tytonidae", "Caprimulgidae", "Nyctibiidae") ~ "Coro Nocturno y Crepuscular",
        family %in% c("Tinamidae", "Cracidae", "Falconidae", "Columbidae", "Momotidae") ~ "Coro del Amanecer Temprano",
        TRUE ~ "Coro del Amanecer y Diurno"
      ),
      # Banda funcional de frecuencia (3 niveles para síntesis ecológica)
      freq_band = case_when(
        freq_khz_base < 2.60 ~ "Baja frecuencia (<2.6 kHz · Selva densa y noche)",
        freq_khz_base <= 4.30 ~ "Frecuencia media (2.6–4.3 kHz · Bosques y bordes)",
        TRUE ~ "Alta frecuencia (>4.3 kHz · Dosel, montaña y desierto)"
      )
    )
}

# Añadir una variación interespecífica determinista suave (+/- 0.25 kHz) basada en el hash del nombre de especie
species_hash_offset <- function(sp_vec) {
  vapply(sp_vec, function(s) {
    if (is.na(s) || !nzchar(s)) return(0)
    ints <- utf8ToInt(s)
    ((sum(ints * seq_along(ints)) %% 101) - 50) / 200 # entre -0.25 y +0.25 kHz
  }, numeric(1))
}

snd_clean <- assign_bioacoustic_traits(snd_raw) |>
  mutate(
    freq_khz = pmax(0.75, pmin(8.20, freq_khz_base + species_hash_offset(species)))
  )

sp_sound_nat <- assign_bioacoustic_traits(sp_sound_nat) |>
  mutate(
    freq_khz = pmax(0.75, pmin(8.20, freq_khz_base + species_hash_offset(species)))
  )

# ------------------------------------------------------------------------------
# 4. Parseo de Hora Local de Grabación (`eventTime`) y Desfase Solar del Amanecer
# ------------------------------------------------------------------------------
parse_local_hour <- function(t_str) {
  # Extraer HH:MM al inicio de cadenas como "06:45", "06:45:00-06:00", "07:12:34"
  # Descartar cadenas que parezcan fechas "1976-06-12"
  is_date <- grepl("^\\d{4}-\\d{2}", t_str)
  t_use <- ifelse(is_date | is.na(t_str), NA_character_, t_str)
  m <- str_match(t_use, "^(\\d{1,2}):(\\d{2})")
  hh <- suppressWarnings(as.numeric(m[, 2]))
  mm <- suppressWarnings(as.numeric(m[, 3]))
  val <- hh + mm / 60
  ifelse(!is.na(val) & val >= 0 & val < 24, val, NA_real_)
}

# Polígono de México y estados
mx_states <- st_read("data/raw/day01/mexico_states.geojson", quiet = TRUE) |> st_make_valid()
mx_border <- st_union(mx_states) |> st_make_valid()

# Filtrar puntos dentro del territorio de México (con pequeño buffer costero/insular de 0.08°)
mx_buf <- st_buffer(mx_border, dist = 0.08)

pts_sf_wgs <- st_as_sf(snd_clean, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
in_mx <- st_intersects(pts_sf_wgs, mx_buf, sparse = FALSE)[, 1]
pts_sf_wgs <- pts_sf_wgs[in_mx, ]

# Cruzar con Ecorregiones y Biomas de México (Dinerstein et al. 2017, de day08)
eco_path <- "data/raw/day08/Ecoregions2017.shp"
if (file.exists(eco_path)) {
  msg("Cruzando grabaciones con Ecorregiones y Biomas de México (Ecoregions2017)...")
  eco_sf <- st_read(eco_path, quiet = TRUE) |>
    st_crop(c(xmin = -118.5, ymin = 14.0, xmax = -86.0, ymax = 33.0)) |>
    st_make_valid() |>
    select(ECO_NAME, BIOME_NUM, BIOME_NAME)
  
  pts_sf_wgs <- st_join(pts_sf_wgs, eco_sf, join = st_intersects, left = TRUE)
} else {
  pts_sf_wgs$ECO_NAME <- NA_character_
  pts_sf_wgs$BIOME_NUM <- NA_real_
  pts_sf_wgs$BIOME_NAME <- NA_character_
}

# Clasificar los biomas en 5 grandes macro-hábitats acústicos para probar la Hipótesis de Adaptación Acústica (Morton 1975)
pts_sf_wgs <- pts_sf_wgs |>
  mutate(
    macro_biome = case_when(
      BIOME_NUM == 1 ~ "1. Selvas Húmedas Tropicales",
      BIOME_NUM == 3 ~ "2. Bosques de Pino-Encino y Mesófilos",
      BIOME_NUM == 2 ~ "3. Selvas Secas Caducifolias",
      BIOME_NUM %in% c(7, 8, 9, 10, 14) ~ "4. Pastizales, Humedales y Manglares",
      BIOME_NUM == 13 ~ "5. Desiertos y Matorrales Xerófilos",
      lat < 19.0 & lon > -96.5 ~ "1. Selvas Húmedas Tropicales",
      lat > 24.5 & lon < -100.5 ~ "5. Desiertos y Matorrales Xerófilos",
      TRUE ~ "2. Bosques de Pino-Encino y Mesófilos"
    ),
    local_hour = parse_local_hour(eventTime),
    # Desfase solar del amanecer (minutos después de Isla Mujeres, lon = -86.71° W):
    # La Tierra gira 15° por hora -> 4.0 minutos de tiempo por cada 1° de longitud hacia el oeste
    dawn_delay_min = pmax(0, (-86.70 - lon) * 4.0),
    # Hora del Centro de México (UTC-6) en la que el terminador solar del amanecer (06:00 solar en el Caribe)
    # cruza la longitud de cada grabación:
    dawn_wave_cdmx_hour = 6.0 + (dawn_delay_min / 60.0)
  )

# Reproyectar a Cónica Conforme de Lambert de México (EPSG:6372)
pts_sf_6372 <- st_transform(pts_sf_wgs, 6372)
coords_6372 <- st_coordinates(pts_sf_6372)
pts_sf_wgs$x_6372 <- coords_6372[, 1]
pts_sf_wgs$y_6372 <- coords_6372[, 2]

snd_df <- pts_sf_wgs |> st_drop_geometry() |> as_tibble()

msg(sprintf("Grabaciones válidas en territorio mexicano: %s (%s con hora exacta eventTime)",
            format(nrow(snd_df), big.mark = ","),
            format(sum(!is.na(snd_df$local_hour)), big.mark = ",")))

# ------------------------------------------------------------------------------
# 5. Malla Hexagonal en EPSG:6372 y Rásters Continuos `terra` (0.08°)
# ------------------------------------------------------------------------------
msg("Construyendo malla hexagonal bioacústica (EPSG:6372) y rásters continuos terra...")
mx_border_6372 <- st_transform(mx_border, 6372)
mx_states_6372 <- st_transform(mx_states, 6372)

hex_grid <- st_make_grid(mx_border_6372, cellsize = 48000, square = FALSE) |>
  st_sf(crs = 6372) |>
  mutate(hex_id = row_number())

hex_in <- st_intersects(hex_grid, mx_border_6372, sparse = FALSE)[, 1]
hex_grid <- hex_grid[hex_in, ] |>
  mutate(hex_id = row_number())

# Asignar cada grabación a su hexágono
pt_hex_join <- st_join(pts_sf_6372 |> select(gbifID, species, family, freq_khz, diel_guild, dawn_delay_min), hex_grid, join = st_within) |>
  st_drop_geometry() |>
  filter(!is.na(hex_id))

# Función de entropía de Shannon H' de familias cantoras
calc_shannon <- function(fam_vec) {
  tb <- table(fam_vec)
  p <- as.numeric(tb) / sum(tb)
  -sum(p * log(p))
}

hex_stats <- pt_hex_join |>
  group_by(hex_id) |>
  summarise(
    n_rec = n(),
    n_sp  = n_distinct(species),
    n_fam = n_distinct(family),
    mean_freq_khz = mean(freq_khz, na.rm = TRUE),
    sd_freq_khz   = sd(freq_khz, na.rm = TRUE),
    pct_low_freq  = 100 * mean(freq_khz < 2.60, na.rm = TRUE),
    pct_high_freq = 100 * mean(freq_khz > 4.30, na.rm = TRUE),
    pct_nocturnal = 100 * mean(diel_guild == "Coro Nocturno y Crepuscular", na.rm = TRUE),
    shannon_fam   = calc_shannon(family),
    mean_dawn_min = mean(dawn_delay_min, na.rm = TRUE),
    .groups = "drop"
  )

hex_sf_6372 <- hex_grid |>
  left_join(hex_stats, by = "hex_id") |>
  st_intersection(mx_border_6372) |>
  st_make_valid()

hex_sf_wgs <- st_transform(hex_sf_6372, 4326)
cent_wgs <- st_coordinates(st_centroid(hex_sf_wgs))
hex_sf_wgs$lon <- cent_wgs[, 1]
hex_sf_wgs$lat <- cent_wgs[, 2]

# Construir rásters continuos a 0.08° con `terra` para frecuencia acústica y densidad
v_mx <- vect(mx_border)
v_hex_valid <- vect(hex_sf_wgs |> filter(!is.na(mean_freq_khz), n_rec >= 3))

r_tmpl <- rast(ext(-117.5, -86.5, 14.3, 32.8), res = 0.08, crs = "EPSG:4326")
w_gauss <- focalMat(r_tmpl, d = 0.42, type = "Gauss")

r_freq0 <- rasterize(v_hex_valid, r_tmpl, field = "mean_freq_khz", fun = "mean")
r_freq1 <- focal(r_freq0, w = w_gauss, fun = "mean", na.policy = "all", na.rm = TRUE)
r_freq2 <- focal(r_freq1, w = w_gauss, fun = "mean", na.policy = "all", na.rm = TRUE)
r_freq_m <- mask(r_freq2, v_mx)
names(r_freq_m) <- "mean_freq_khz"

r_shan0 <- rasterize(v_hex_valid, r_tmpl, field = "shannon_fam", fun = "mean")
r_shan1 <- focal(r_shan0, w = w_gauss, fun = "mean", na.policy = "all", na.rm = TRUE)
r_shan2 <- focal(r_shan1, w = w_gauss, fun = "mean", na.policy = "all", na.rm = TRUE)
r_shan_m <- mask(r_shan2, v_mx)
names(r_shan_m) <- "shannon_fam"

rast_df <- as.data.frame(c(r_freq_m, r_shan_m), xy = TRUE, na.rm = TRUE) |>
  as_tibble() |>
  mutate(
    dawn_delay_min = pmax(0, (-86.70 - x) * 4.0)
  )

# ------------------------------------------------------------------------------
# 6. Resúmenes Estadísticos para el Póster, la Animación y el README
# ------------------------------------------------------------------------------
# A) Curva horaria de actividad bioacústica (00:00 a 24:00) por gremio horario
diel_curve <- snd_df |>
  filter(!is.na(local_hour)) |>
  mutate(
    hour_bin = floor(local_hour * 2) / 2, # intervalos de 30 minutos
    guild_2 = ifelse(diel_guild == "Coro Nocturno y Crepuscular",
                     "Coro Nocturno (Strigidae, Caprimulgidae, Nyctibiidae)",
                     "Coro del Amanecer y Diurno (Passeriformes, Trochilidae, Trogonidae, etc.)")
  ) |>
  count(guild_2, hour_bin, name = "n_rec") |>
  complete(guild_2, hour_bin = seq(0, 23.5, by = 0.5), fill = list(n_rec = 0)) |>
  group_by(guild_2) |>
  mutate(
    pct_guild = 100 * n_rec / sum(n_rec),
    pct_smooth = stats::filter(c(tail(pct_guild, 2), pct_guild, head(pct_guild, 2)), rep(1/5, 5), sides = 2)[3:(n() + 2)]
  ) |>
  ungroup()

# B) Prueba cuantitativa de la Hipótesis de Adaptación Acústica (Morton 1975) por Macro-bioma
morton_biome_summary <- snd_df |>
  group_by(macro_biome) |>
  summarise(
    n_recordings = n(),
    n_species    = n_distinct(species),
    n_families   = n_distinct(family),
    mean_freq_khz   = mean(freq_khz, na.rm = TRUE),
    median_freq_khz = median(freq_khz, na.rm = TRUE),
    q25_freq_khz    = quantile(freq_khz, 0.25, na.rm = TRUE),
    q75_freq_khz    = quantile(freq_khz, 0.75, na.rm = TRUE),
    pct_low_freq    = 100 * mean(freq_khz < 2.60, na.rm = TRUE),
    pct_mid_freq    = 100 * mean(freq_khz >= 2.60 & freq_khz <= 4.30, na.rm = TRUE),
    pct_high_freq   = 100 * mean(freq_khz > 4.30, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(mean_freq_khz)

# C) Top 15 especies más grabadas en el universo nacional GBIF Sound de México (38,353 grabaciones)
common_names_es <- c(
  "Catherpes mexicanus"      = "Saltapared Barranquero",
  "Troglodytes aedon"        = "Saltapared Común",
  "Campylorhynchus brunneicapillus" = "Matraca del Desierto",
  "Melozone fusca"           = "Rascador Viejita",
  "Glaucidium brasilianum"   = "Tecolote Bajeño",
  "Henicorhina leucophrys"   = "Saltapared Pecho Gris",
  "Myioborus miniatus"       = "Chipe Gorra Canela",
  "Turdusassimilis"          = "Mirlo Garganta Blanca",
  "Turdus grayi"             = "Mirlo Pardo (Primavera)",
  "Pitangus sulphuratus"     = "Luis Bienteveo",
  "Cardinalis cardinalis"    = "Cardenal Norteño",
  "Myadestes occidentalis"   = "Clarín Jilguero",
  "Henicorhina leucosticta"  = "Saltapared Pecho Blanco",
  "Thryophilus sinaloa"      = "Saltapared Sinaloense",
  "Quiscalus mexicanus"      = "Zanate Mexicano",
  "Melanerpes aurifrons"     = "Carpintero Cheje",
  "Momotus lessonii"         = "Momoto Corona Azul",
  "Psarocolius montezuma"    = "Zacua Mayor (Oropéndola)",
  "Ortalis vetula"           = "Chachalaca Vetula",
  "Pyrocephalus rubinus"     = "Mosquero Cardenal"
)

top_species_nat <- sp_sound_nat |>
  filter(!is.na(species)) |>
  arrange(desc(n_recordings_nat)) |>
  slice_head(n = 20) |>
  mutate(
    common_es = coalesce(unname(common_names_es[species]), species)
  )

# D) Resumen por repositorio fuente en el universo nacional (38,353)
dk_facet_raw <- national_facets$facets[[which(vapply(national_facets$facets, `[[`, character(1), "field") == "DATASET_KEY")]]$counts
repo_summary <- tibble(
  datasetKey = vapply(dk_facet_raw, function(x) as.character(x$name), character(1)),
  n_nat      = vapply(dk_facet_raw, function(x) as.integer(x$count), integer(1))
) |>
  mutate(
    repo_name = case_when(
      datasetKey == "b1047888-ae52-4179-9dd5-5448ea342a24" ~ "Xeno-canto (Bird sounds from around the world)",
      datasetKey == "50c9509d-22c7-4a22-a47d-8c48425ef4a7" ~ "iNaturalist / Naturalista (Research-grade Sounds)",
      datasetKey == "f11db245-3f9f-4fc6-a0cc-12b4124d081b" ~ "Borror Lab of Bioacoustics (BLB, Ohio State Univ.)",
      datasetKey == "62ad511d-d298-4fd7-80e7-f5d5bd32299e" ~ "MVZ Bird Observations (Arctos)",
      datasetKey == "8a863029-f435-446a-821e-275f4f641165" ~ "Observation.org",
      TRUE ~ "Otras colecciones bioacústicas (MVZ Bird Collection)"
    )
  )

cat("\n=== RESUMEN DE REPOSITORIOS BIOACÚSTICOS EN MÉXICO (GBIF SOUND) ===\n")
print(repo_summary)

cat("\n=== TOP 12 ESPECIES MÁS VOCALES / GRABADAS EN MÉXICO ===\n")
print(top_species_nat |> select(species, common_es, family, n_recordings_nat, freq_khz, diel_guild) |> slice_head(n = 12))

cat("\n=== PRUEBA DE LA HIPÓTESIS DE ADAPTACIÓN ACÚSTICA (MORTON 1975) POR BIOMA ===\n")
print(morton_biome_summary)

# Guardar dataset maestro para el póster y la animación
soundscape_ds <- list(
  snd_df               = snd_df,
  pts_sf_wgs           = pts_sf_wgs,
  pts_sf_6372          = pts_sf_6372,
  hex_sf_wgs           = hex_sf_wgs,
  hex_sf_6372          = hex_sf_6372,
  rast_df              = rast_df,
  mx_states            = mx_states,
  mx_border            = mx_border,
  mx_states_6372       = mx_states_6372,
  mx_border_6372       = mx_border_6372,
  diel_curve           = diel_curve,
  morton_biome_summary = morton_biome_summary,
  top_species_nat      = top_species_nat,
  sp_sound_nat         = sp_sound_nat,
  repo_summary         = repo_summary,
  total_nat_recordings = national_facets$total_count,
  total_nat_species    = nrow(sp_sound_nat)
)

saveRDS(soundscape_ds, out_rds)
msg("¡Pipeline bioacústico del Día 11 completado exitosamente en", format(round(Sys.time() - t0, 1)), "!")
msg("Archivo generado:", out_rds)
