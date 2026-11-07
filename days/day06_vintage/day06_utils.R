# ==============================================================================
# Día 06 — Vintage: utilidades para rutas de naturalistas
# Autor: Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(lubridate)
})

# ------------------------------------------------------------------------------
# Paleta y tema
# ------------------------------------------------------------------------------

VINTAGE <- list(
  paper   = "#F3E9D2",
  paper_2 = "#E8D9BC",
  ocean   = "#D9E2E6",
  land    = "#E6D6B8",
  border  = "#8C7A5E",
  ink     = "#2B2118",
  muted   = "#6B5B4A",
  grid    = "#B9A88A",
  ghost   = "#8A6A4F"
)

NAT_COLORS <- c(
  "Charles Darwin"        = "#8C3B2E",
  "Alexander von Humboldt" = "#2F5D50",
  "Alfred Russel Wallace" = "#8A6A2A",
  "Helia Bravo Hollis"    = "#6D3B4E"
)

NAT_SHORT <- c(
  "Charles Darwin"         = "DARWIN",
  "Alexander von Humboldt" = "HUMBOLDT",
  "Alfred Russel Wallace"  = "WALLACE",
  "Helia Bravo Hollis"     = "BRAVO"
)

NAT_PROFESION <- c(
  "Charles Darwin"         = "Naturalista",
  "Alexander von Humboldt" = "Naturalista y geógrafo",
  "Alfred Russel Wallace"  = "Naturalista y biogeógrafo",
  "Helia Bravo Hollis"     = "Botánica y cactóloga"
)

theme_vintage <- function(base_size = 11, family = "Georgia") {
  theme_void(base_family = family, base_size = base_size) +
    theme(
      plot.background   = element_rect(fill = VINTAGE$paper, color = NA),
      panel.background  = element_rect(fill = VINTAGE$ocean, color = VINTAGE$border, linewidth = 0.4),
      panel.border      = element_rect(fill = NA, color = VINTAGE$border, linewidth = 0.4),
      strip.background  = element_rect(fill = VINTAGE$paper_2, color = VINTAGE$border, linewidth = 0.3),
      strip.text        = element_text(family = family, face = "bold", size = base_size * 0.8,
                                       color = VINTAGE$ink, margin = margin(4, 4, 4, 4)),
      plot.title        = element_text(family = family, face = "bold", size = base_size * 1.6,
                                       color = VINTAGE$ink, hjust = 0, margin = margin(4, 0, 2, 0)),
      plot.subtitle     = element_text(family = family, face = "italic", size = base_size * 0.95,
                                       color = VINTAGE$muted, hjust = 0, margin = margin(0, 0, 8, 0)),
      plot.caption      = element_text(family = family, size = base_size * 0.62,
                                       color = VINTAGE$muted, hjust = 0, margin = margin(8, 0, 0, 0)),
      legend.position   = "none",
      plot.margin       = margin(10, 10, 8, 10)
    )
}

# ------------------------------------------------------------------------------
# Fechas flexibles: "1831-12-27", "1831-12", "1831"
# ------------------------------------------------------------------------------

parse_flex_date <- function(x) {
  x <- trimws(as.character(x))
  out <- as.Date(rep(NA_character_, length(x)))
  ok <- !is.na(x)
  full <- ok & grepl("^\\d{4}-\\d{2}-\\d{2}$", x)
  ym   <- ok & grepl("^\\d{4}-\\d{2}$", x)
  yr   <- ok & grepl("^\\d{4}$", x)
  if (any(full)) out[full] <- as.Date(x[full])
  if (any(ym))   out[ym]   <- as.Date(paste0(x[ym], "-15"))
  if (any(yr))   out[yr]   <- as.Date(paste0(x[yr], "-07-01"))
  out
}

# ------------------------------------------------------------------------------
# Waypoints: ordena, vuelve monótonos los intervalos y calcula la pista densa
# ------------------------------------------------------------------------------

prepare_waypoints <- function(df) {
  wp <- df |>
    mutate(
      start = parse_flex_date(fecha_llegada),
      end   = parse_flex_date(fecha_salida)
    ) |>
    filter(!is.na(lat), !is.na(lon), !is.na(start)) |>
    arrange(start)

  wp$end[is.na(wp$end)] <- wp$start[is.na(wp$end)]
  wp$end <- pmax(wp$end, wp$start)
  # Las estancias pueden solaparse (excursiones desde una base): se conservan
  # y position_at() prioriza la llegada más reciente.
  wp
}

# Posición a lo largo de la ruta en un instante t (Date)
position_at <- function(wp, t) {
  n <- nrow(wp)
  if (t <= wp$start[1]) {
    return(list(lon = wp$lon[1], lat = wp$lat[1], lugar = wp$lugar[1]))
  }
  if (t >= max(wp$end)) {
    i <- which.max(wp$end)
    return(list(lon = wp$lon[i], lat = wp$lat[i], lugar = wp$lugar[i]))
  }

  # 1) ¿hay estancia activa? Gana la de llegada más reciente (excursión)
  active <- which(wp$start <= t & wp$end >= t)
  if (length(active) > 0) {
    i <- active[which.max(wp$start[active])]
    return(list(lon = wp$lon[i], lat = wp$lat[i], lugar = wp$lugar[i]))
  }

  # 2) tramo de tránsito entre la última salida y la siguiente llegada
  prev <- max(which(wp$start <= t))
  nxt <- prev + 1
  if (nxt <= n) {
    f <- as.numeric(t - wp$end[prev]) / as.numeric(wp$start[nxt] - wp$end[prev])
    f <- min(max(f, 0), 1)
    lon2 <- wp$lon[nxt]
    if (lon2 - wp$lon[prev] > 180)  lon2 <- lon2 - 360
    if (lon2 - wp$lon[prev] < -180) lon2 <- lon2 + 360
    lon <- wp$lon[prev] + f * (lon2 - wp$lon[prev])
    lon <- ((lon + 180) %% 360) - 180
    return(list(
      lon = lon,
      lat = wp$lat[prev] + f * (wp$lat[nxt] - wp$lat[prev]),
      lugar = wp$lugar[nxt]
    ))
  }
  list(lon = wp$lon[n], lat = wp$lat[n], lugar = wp$lugar[n])
}

# Pista densa con separación constante (días) y t normalizado 0-1
build_track <- function(wp, step_days = 4) {
  times <- seq(min(wp$start), max(wp$end), by = paste(step_days, "days"))
  if (length(times) < 2) times <- c(min(wp$start), min(wp$start) + 1)
  pos <- lapply(times, function(t) as_tibble(position_at(wp, t)))
  track <- bind_rows(pos)
  track$fecha <- times
  track |>
    mutate(
      year = year(fecha),
      t    = as.numeric(fecha - min(fecha)) / as.numeric(max(fecha) - min(fecha))
    ) |>
    select(fecha, lon, lat, lugar, year, t)
}

# ------------------------------------------------------------------------------
# Corte en el antimeridiano para no cruzar el mapa entero
# ------------------------------------------------------------------------------

split_antimeridian <- function(path) {
  if (nrow(path) < 2) return(path)
  out <- path[0, ]
  for (i in seq_len(nrow(path) - 1)) {
    a <- path[i, ]
    b <- path[i + 1, ]
    out <- bind_rows(out, a)
    d <- b$lon - a$lon
    if (!is.na(d) && abs(d) > 180) {
      # punto de cruce en el borde ±180 y corte con NA
      lon_edge <- if (d > 0) -180 else 180
      lon_b <- b$lon + if (d > 0) 360 else -360
      f <- (lon_edge - a$lon) / (lon_b - a$lon)
      lat_edge <- a$lat + f * (b$lat - a$lat)
      edge_a <- a; edge_a$lon <- lon_edge; edge_a$lat <- lat_edge
      edge_b <- a; edge_b$lon <- -lon_edge; edge_b$lat <- lat_edge
      na_row <- a; na_row$lon <- NA_real_; na_row$lat <- NA_real_
      out <- bind_rows(out, edge_a, na_row, edge_b)
    }
  }
  bind_rows(out, path[nrow(path), ])
}

# ------------------------------------------------------------------------------
# Corte de la pista en tramos: los traslados no se dibujan y cada tramo
# continuo se dibuja como un grupo independiente (evita líneas entre continentes)
# ------------------------------------------------------------------------------

segment_path <- function(d) {
  if (!"traslado" %in% names(d)) d$traslado <- FALSE
  d$traslado[is.na(d$traslado)] <- FALSE
  brk <- d$traslado | is.na(d$lon) | is.na(d$lat)
  d$seg <- cumsum(brk)
  d[!brk, , drop = FALSE]
}

# ------------------------------------------------------------------------------
# Fotogramas: pista acumulada + cabeza + año
# ------------------------------------------------------------------------------

build_frames <- function(track, n_frames = 110, max_path = 140) {
  cuts <- seq(0, 1, length.out = n_frames)
  path_list <- vector("list", n_frames)
  head_list <- vector("list", n_frames)

  for (k in seq_len(n_frames)) {
    p <- cuts[k]
    idx <- which(track$t <= p)
    if (length(idx) < 2) idx <- c(1, 1)
    path <- track[idx, intersect(c("lon", "lat", "traslado"), names(track))]
    path$frame <- k
    if (nrow(path) > max_path) {
      keep <- unique(round(seq(1, nrow(path), length.out = max_path)))
      path <- path[keep, ]
    }
    path <- split_antimeridian(path)
    path_list[[k]] <- path

    lon_h <- approx(track$t, track$lon, p, rule = 2)$y
    lat_h <- approx(track$t, track$lat, p, rule = 2)$y
    yr_h  <- approx(track$t, track$year, p, rule = 2)$y
    head_list[[k]] <- tibble(
      frame = k, lon = lon_h, lat = lat_h, year = round(yr_h),
      lugar = track$lugar[max(idx)]
    )
  }

  list(
    path = bind_rows(path_list),
    head = bind_rows(head_list)
  )
}
