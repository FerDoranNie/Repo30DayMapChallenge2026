# ==============================================================================
# Día 06 — Vintage: pipeline de datos
# "Cuatro naturalistas, cuatro rutas" — itinerarios fechados y georreferenciados
#
# Entradas:  data/raw/day06/darwin_beagle.csv
#            data/raw/day06/humboldt_americas.csv
#            data/raw/day06/wallace_expediciones.csv
#            data/processed/day06_bravo.rds  (generado por day06_bravo_gbif.R)
# Salidas:   data/processed/day06_naturalistas.rds
#
# Autor: Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))

source("days/day06_vintage/day06_utils.R")
suppressPackageStartupMessages({
  library(lubridate)
  library(purrr)
})

RAW <- "data/raw/day06"

# ------------------------------------------------------------------------------
# 1. Itinerarios históricos (CSV curados)
# ------------------------------------------------------------------------------

read_itin <- function(file, naturalista, region) {
  if (!file.exists(file)) {
    alt <- file.path("days/day06_vintage/itinerarios", basename(file))
    if (file.exists(alt)) {
      file <- alt
    } else {
      warning("Aún no existe: ", file, " — se omite por ahora.")
      return(NULL)
    }
  }
  x <- read.csv(file, stringsAsFactors = FALSE, fileEncoding = "UTF-8",
                check.names = FALSE)
  names(x) <- tolower(trimws(names(x)))
  x$naturalista <- naturalista
  x$region <- region
  x
}

darwin   <- read_itin(file.path(RAW, "darwin_beagle.csv"), "Charles Darwin", "mundo")
humboldt <- read_itin(file.path(RAW, "humboldt_americas.csv"), "Alexander von Humboldt", "americas")
wallace  <- read_itin(file.path(RAW, "wallace_expediciones.csv"), "Alfred Russel Wallace", "mundo")

historico <- bind_rows(darwin, humboldt, wallace)
if (nrow(historico) > 0) {
  historico <- historico |> mutate(across(c(lat, lon), as.numeric))
} else {
  historico <- NULL
}

# ------------------------------------------------------------------------------
# 2. Helia Bravo Hollis: registros de herbario GBIF (1931-1981)
# ------------------------------------------------------------------------------

bravo_raw <- readRDS("data/processed/day06_bravo.rds")

bravo <- bravo_raw |>
  mutate(
    fecha = suppressWarnings(as.Date(substr(eventDate, 1, 10))),
    year  = as.integer(ifelse(is.na(year), format(fecha, "%Y"), year)),
    month = as.integer(ifelse(is.na(month), format(fecha, "%m"), month)),
    day   = as.integer(ifelse(is.na(day), 15L, day)),
    fecha = ifelse(
      is.na(fecha),
      as.Date(sprintf("%d-%02d-%02d", year, month, day)),
      fecha
    ),
    fecha = as.Date(fecha, origin = "1970-01-01"),
    estado = sub(" de .*$", "", stateProvince),
    estado = tools::toTitleCase(tolower(estado)),
    estado = dplyr::recode(estado,
      "Mexico" = "México", "Michoacan" = "Michoacán",
      "San Luis Potosi" = "San Luis Potosí", "Nuevo Leon" = "Nuevo León",
      .default = estado
    ),
    lugar = estado
  ) |>
  filter(
    !is.na(fecha), !is.na(decimalLatitude), !is.na(decimalLongitude),
    countryCode == "MX",
    decimalLatitude > 14, decimalLatitude < 33,
    decimalLongitude > -118, decimalLongitude < -86
  ) |>
  arrange(fecha) |>
  distinct(fecha, round_lat = round(decimalLatitude, 3),
           round_lon = round(decimalLongitude, 3), .keep_all = TRUE) |>
  transmute(
    naturalista = "Helia Bravo Hollis",
    region = "mexico",
    lugar,
    pais = "México",
    lat = decimalLatitude,
    lon = decimalLongitude,
    fecha_llegada = as.character(fecha),
    fecha_salida  = as.character(fecha),
    fuente_url = "https://www.gbif.org/occurrence/search?recordedBy=Helia%20Bravo%20Hollis",
    nota = paste0(scientificName, " · ", stateProvince)
  )

message("Bravo: ", nrow(bravo), " localidades fechadas (", min(bravo$fecha_llegada),
        " a ", max(bravo$fecha_llegada), ")")

# ------------------------------------------------------------------------------
# 3. Waypoints y pistas
# ------------------------------------------------------------------------------

waypoints <- bind_rows(historico, bravo) |>
  mutate(across(c(lat, lon), as.numeric)) |>
  group_by(naturalista) |>
  group_split() |>
  map(prepare_waypoints) |>
  bind_rows()

build_track_ordinal <- function(wp, max_gap = 45, per_leg = 14) {
  wp <- wp |> arrange(start)
  n <- nrow(wp)
  dd <- c(0, pmin(pmax(as.numeric(diff(wp$start), units = "days"), 1), max_gap))
  tt <- cumsum(dd); tt <- tt / max(tt)

  rows <- vector("list", n * 2)
  j <- 0
  for (i in seq_len(n)) {
    j <- j + 1
    rows[[j]] <- tibble(lon = wp$lon[i], lat = wp$lat[i], lugar = wp$lugar[i],
                        fecha = wp$start[i], t = tt[i])
    if (i < n) {
      f <- seq(0, 1, length.out = per_leg + 2)[-c(1, per_leg + 2)]
      j <- j + 1
      rows[[j]] <- tibble(
        lon = wp$lon[i] + f * (wp$lon[i + 1] - wp$lon[i]),
        lat = wp$lat[i] + f * (wp$lat[i + 1] - wp$lat[i]),
        lugar = wp$lugar[i + 1],
        fecha = wp$start[i] + round(f * dd[i + 1]),
        t = tt[i] + f * (tt[i + 1] - tt[i])
      )
    }
  }
  bind_rows(rows) |>
    arrange(t) |>
    mutate(year = lubridate::year(fecha))
}

tracks <- waypoints |>
  group_by(naturalista) |>
  group_split() |>
  map(function(wp) {
    nat <- wp$naturalista[1]
    tr <- if (nat == "Helia Bravo Hollis") build_track_ordinal(wp) else build_track(wp, 5)
    tr$naturalista <- nat
    tr
  }) |>
  bind_rows()

# Tramos de traslado intercontinental (sólo Wallace: ida/vuelta a Europa)
flag_transfer <- function(tr, wp, set) {
  tr$traslado <- FALSE
  if (nrow(wp) < 2) return(tr)
  for (i in seq_len(nrow(wp) - 1)) {
    idx <- tr$fecha > wp$end[i] & tr$fecha <= wp$start[i + 1]
    if (wp$lugar[i] %in% set || wp$lugar[i + 1] %in% set) tr$traslado[idx] <- TRUE
  }
  tr
}

tracks <- tracks |>
  group_by(naturalista) |>
  group_modify(function(tr, key) {
    wp <- dplyr::filter(waypoints, naturalista == key$naturalista)
    tr <- flag_transfer(tr, wp, c("Londres", "Liverpool"))
    # Las propias paradas en Europa también cortan la línea
    tr$traslado <- tr$traslado | tr$lugar %in% c("Londres", "Liverpool")
    tr
  }) |>
  ungroup()

# ------------------------------------------------------------------------------
# 4. Fotogramas por naturalista
# ------------------------------------------------------------------------------

N_FRAMES <- 120

frames <- tracks |>
  group_by(naturalista) |>
  group_split() |>
  map(function(tr) {
    fr <- build_frames(tr, n_frames = N_FRAMES, max_path = 150)
    fr$path$naturalista <- tr$naturalista[1]
    fr$head$naturalista <- tr$naturalista[1]
    fr
  })

frame_path <- map(frames, "path") |> bind_rows()
frame_head <- map(frames, "head") |> bind_rows()

# puntos de paso ya visitados (sólo paradas reales, no la pista interpolada)
visited <- waypoints |>
  group_by(naturalista) |>
  group_split() |>
  map(function(wp) {
    nat <- wp$naturalista[1]
    if (nat == "Helia Bravo Hollis") {
      dd <- c(0, pmin(pmax(as.numeric(diff(wp$start), units = "days"), 1), 45))
      tt <- cumsum(dd); tt <- tt / max(tt)
    } else {
      tt <- as.numeric(wp$start - min(wp$start)) /
        as.numeric(max(wp$start) - min(wp$start))
    }
    tibble(
      naturalista = nat,
      frame = round(tt * (N_FRAMES - 1)) + 1,
      lon = wp$lon, lat = wp$lat, lugar = wp$lugar
    )
  }) |>
  bind_rows()

visited_cum <- visited |>
  group_by(naturalista) |>
  group_modify(function(d, key) {
    map_dfr(seq_len(N_FRAMES), function(k) {
      d[d$frame <= k, c("lon", "lat", "lugar")] |>
        mutate(frame = k)
    })
  }) |>
  ungroup()

meta <- tibble(
  naturalista = names(NAT_COLORS),
  corto = unname(NAT_SHORT[names(NAT_COLORS)]),
  color = unname(NAT_COLORS[names(NAT_COLORS)]),
  periodo = c("1831–1836", "1799–1804", "1848–1862", "1931–1981"),
  region = c("mundo", "americas", "mundo", "mexico")
)

saveRDS(
  list(
    waypoints = waypoints,
    tracks = tracks,
    frames_path = frame_path,
    frames_head = frame_head,
    visited = visited,
    visited_cum = visited_cum,
    meta = meta,
    n_frames = N_FRAMES
  ),
  "data/processed/day06_naturalistas.rds"
)

message("Listo: ", nrow(frame_path), " filas de pista, ",
        nrow(frame_head), " cabezas, ", nrow(waypoints), " waypoints.")
