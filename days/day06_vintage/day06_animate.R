# ==============================================================================
# Día 06 — Vintage: animaciones de rutas de naturalistas
# "Cuatro naturalistas, cuatro rutas" — Darwin, Humboldt, Wallace y Bravo
#
# Requiere: days/day06_vintage/day06_data_pipeline.R
# Salidas:  outputs/high_res/day06_darwin.gif
#           outputs/high_res/day06_humboldt.gif
#           outputs/high_res/day06_humboldt_mexico.gif
#           outputs/high_res/day06_wallace.gif
#           outputs/high_res/day06_bravo.gif
#           outputs/high_res/day06_naturalistas_facetas.gif
#
# Uso: Rscript days/day06_vintage/day06_animate.R [all|darwin|humboldt|mexico|wallace|bravo|facetas]
# Autor: Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
source("days/day06_vintage/day06_utils.R")
suppressPackageStartupMessages({
  library(sf)
  library(gifski)
  library(purrr)
  library(patchwork)
})
sf_use_s2(FALSE)

args <- commandArgs(trailingOnly = TRUE)
target <- if (length(args) == 0) "all" else tolower(args[1])
preview <- identical(Sys.getenv("DAY06_PREVIEW"), "1")

dir.create("outputs/high_res", recursive = TRUE, showWarnings = FALSE)

ds <- readRDS("data/processed/day06_naturalistas.rds")
path_df   <- ds$frames_path
head_df   <- ds$frames_head
visited   <- ds$visited_cum
waypoints <- ds$waypoints
meta      <- ds$meta
N_TOTAL   <- ds$n_frames

world  <- st_read("data/raw/day02/ne_110m_admin_0_countries.geojson", quiet = TRUE)
states <- st_read("data/raw/day01/mexico_states.geojson", quiet = TRUE)

crs_robin <- "+proj=robin +lon_0=0 +datum=WGS84 +units=m +no_defs"
crs_mx    <- "+proj=lcc +lat_1=17.5 +lat_2=29.5 +lat_0=23 +lon_0=-102 +datum=WGS84 +units=m +no_defs"

bboxes <- list(
  "Charles Darwin"         = c(xmin = -180, ymin = -58, xmax = 180, ymax = 74),
  "Alexander von Humboldt" = c(xmin = -128, ymin = -25, xmax = 10, ymax = 56),
  "Alfred Russel Wallace"  = c(xmin = -82, ymin = -13, xmax = 156, ymax = 36),
  "Helia Bravo Hollis"     = c(xmin = -118.5, ymin = 14, xmax = -86, ymax = 33)
)

anchors <- purrr::imap_dfr(bboxes, function(bb, nat) {
  dx <- bb["xmax"] - bb["xmin"]
  dy <- bb["ymax"] - bb["ymin"]
  tibble(
    naturalista = nat,
    x_year  = bb["xmin"] + 0.03 * dx,
    y_year  = bb["ymin"] + 0.09 * dy,
    x_place = bb["xmax"] - 0.03 * dx,
    y_place = bb["ymin"] + 0.09 * dy
  )
})

head_df <- head_df |>
  left_join(anchors, by = "naturalista") |>
  mutate(
    lugar_corto = ifelse(nchar(lugar) > 32, paste0(substr(lugar, 1, 30), "…"), lugar)
  )

caption_txt <- paste0(
  "#30DayMapChallenge 2026 · Día 06: Vintage — Cuatro naturalistas, cuatro rutas\n",
  "Fuentes: Darwin Online · Minguet (UNAM) · Wallace Online · GBIF (Helia Bravo Hollis) | ",
  "Fernando Dorantes Nieto (@FerDoranNie)"
)

# ------------------------------------------------------------------------------
# Capas base (cacheadas)
# ------------------------------------------------------------------------------

base_cache <- new.env()

get_base <- function(nat, bb, con_estados = FALSE) {
  key <- paste0(nat, "_", con_estados)
  if (!is.null(base_cache[[key]])) return(base_cache[[key]])
  w <- st_crop(world, st_bbox(bb, crs = 4326))
  capas <- list(
    geom_sf(data = w, fill = VINTAGE$land, color = VINTAGE$border, linewidth = 0.18)
  )
  if (con_estados) {
    s <- st_crop(states, st_bbox(bb, crs = 4326))
    capas <- append(capas, list(
      geom_sf(data = s, fill = NA, color = VINTAGE$border, linewidth = 0.22)
    ))
  }
  base_cache[[key]] <- capas
  capas
}

frame_lbl <- function(k) sprintf("%03d", k)

# ------------------------------------------------------------------------------
# Gráfico de un naturalista en un fotograma
# ------------------------------------------------------------------------------

plot_nat <- function(nat, k) {
  bb  <- bboxes[[nat]]
  col <- NAT_COLORS[[nat]]
  con_estados <- nat == "Helia Bravo Hollis"
  crs <- if (con_estados) crs_mx else crs_robin

  d_path <- dplyr::filter(path_df, naturalista == nat, frame == k)
  d_head <- dplyr::filter(head_df, naturalista == nat, frame == k)
  d_head_pt <- dplyr::filter(d_head, lon >= bb["xmin"], lon <= bb["xmax"],
                             lat >= bb["ymin"], lat <= bb["ymax"])
  d_vis  <- dplyr::filter(visited, naturalista == nat, frame == k,
                          !lugar %in% c("Londres", "Liverpool"))
  d_start <- dplyr::filter(waypoints, naturalista == nat,
                           !lugar %in% c("Londres", "Liverpool")) |> slice(1)

  capas <- get_base(nat, bb, con_estados)

  if (nat != "Helia Bravo Hollis") {
    d_path <- segment_path(d_path)
    capas <- c(capas, list(
      geom_path(data = d_path,
                aes(lon, lat, group = seg), color = col, linewidth = 1.2,
                lineend = "round", alpha = 0.28),
      geom_path(data = d_path,
                aes(lon, lat, group = seg), color = col, linewidth = 0.45, lineend = "round")
    ))
  }

  capas <- c(capas, list(
    geom_point(data = d_vis, aes(lon, lat), color = col,
               size = if (con_estados) 1.15 else 0.55,
               alpha = if (con_estados) 0.75 else 0.45),
    geom_point(data = d_start, aes(lon, lat), shape = 21,
               fill = VINTAGE$paper, color = col, size = 2.2),
    geom_point(data = d_head_pt, aes(lon, lat), color = VINTAGE$paper, size = 3.2),
    geom_point(data = d_head_pt, aes(lon, lat), color = col, size = 1.7),
    geom_text(data = d_head,
              aes(x_year, y_year, label = paste0(year, " · ", lugar_corto)),
              family = "Georgia", fontface = "italic", size = 5.0,
              color = VINTAGE$ink, hjust = 0)
  ))

  subtitulo <- switch(
    nat,
    "Charles Darwin"         = "HMS Beagle · vuelta al mundo por el hemisferio sur",
    "Alexander von Humboldt" = "Expedición americana · del Orinoco al virreinato de Nueva España",
    "Alfred Russel Wallace"  = "Amazonía y archipiélago malayo",
    "Helia Bravo Hollis"     = "Expediciones de colecta de cactáceas · 103 localidades de herbario"
  )

  ggplot() +
    capas +
    coord_sf(crs = crs, default_crs = 4326, expand = FALSE) +
    labs(
      title = paste0(toupper(nat), " · ", NAT_PROFESION[[nat]]),
      subtitle = paste0(meta$periodo[meta$naturalista == nat], " · ", subtitulo),
      caption = caption_txt
    ) +
    theme_vintage(base_size = 11) +
    theme(
      plot.title = element_text(size = 13, face = "bold"),
      plot.subtitle = element_text(size = 10, color = "#475569"),
      plot.caption = element_text(size = 6.4)
    )
}

# ------------------------------------------------------------------------------
# Humboldt en Nueva España (detalle 1803–1804)
# ------------------------------------------------------------------------------

mexico_waypoints <- function() {
  waypoints |>
    dplyr::filter(
      naturalista == "Alexander von Humboldt",
      start >= as.Date("1803-03-01"),
      start <= as.Date("1804-03-07")
    ) |>
    prepare_waypoints()
}

plot_mexico <- function(k, tr, fr) {
  bb  <- c(xmin = -106.5, ymin = 15.2, xmax = -93.0, ymax = 24.2)
  col <- NAT_COLORS[["Alexander von Humboldt"]]
  d_path <- dplyr::filter(fr$path, frame == k)
  d_head <- dplyr::filter(fr$head, frame == k)
  d_vis  <- dplyr::filter(fr$visited, frame == k)

  ciudades <- tibble::tribble(
    ~lon, ~lat, ~nombre,
    -99.13, 19.43, "Ciudad de México",
    -99.82, 16.85, "Acapulco",
    -99.61, 18.56, "Taxco",
    -101.26, 21.02, "Guanajuato",
    -98.20, 19.04, "Puebla",
    -96.13, 19.17, "Veracruz",
    -96.72, 17.07, "Oaxaca"
  )

  ggplot() +
    get_base("humboldt_mexico", bb, TRUE) +
    geom_path(data = d_path, aes(lon, lat), color = col,
              linewidth = 1.1, alpha = 0.28, lineend = "round") +
    geom_path(data = d_path, aes(lon, lat), color = col,
              linewidth = 0.5, lineend = "round") +
    geom_point(data = d_vis, aes(lon, lat), color = col, size = 0.8, alpha = 0.6) +
    geom_point(data = d_head, aes(lon, lat), color = VINTAGE$paper, size = 3.4) +
    geom_point(data = d_head, aes(lon, lat), color = col, size = 1.8) +
    geom_text(data = ciudades, aes(lon, lat, label = nombre), family = "Georgia",
              fontface = "italic", size = 2.5, color = VINTAGE$muted, vjust = -0.5) +
    geom_text(data = d_head, aes(-105.8, 16.1, label = year), family = "Georgia",
              fontface = "italic", size = 7, color = VINTAGE$ink, hjust = 0) +
    coord_sf(crs = crs_mx, default_crs = 4326, expand = FALSE) +
    labs(
      title = "ALEXANDER VON HUMBOLDT · NATURALISTA Y GEÓGRAFO",
      subtitle = "En Nueva España, 1803–1804 · de Acapulco a Veracruz: minas, volcanes y el Ensayo político",
      caption = caption_txt
    ) +
    theme_vintage(base_size = 11) +
    theme(
      plot.title = element_text(size = 13, face = "bold"),
      plot.subtitle = element_text(size = 10, color = "#475569"),
      plot.caption = element_text(size = 6.4)
    )
}

# ------------------------------------------------------------------------------
# Panel de cuatro facetas sincronizadas
# ------------------------------------------------------------------------------

facet_levels <- c("Charles Darwin", "Alexander von Humboldt",
                  "Alfred Russel Wallace", "Helia Bravo Hollis")

facet_panel <- function(nat, k) {
  bb  <- bboxes[[nat]]
  col <- NAT_COLORS[[nat]]
  con_estados <- nat == "Helia Bravo Hollis"
  crs <- if (con_estados) crs_mx else crs_robin

  d_path <- dplyr::filter(path_df, naturalista == nat, frame == k)
  d_path$traslado[is.na(d_path$traslado)] <- FALSE
  d_head <- dplyr::filter(head_df, naturalista == nat, frame == k)
  dx <- bb["xmax"] - bb["xmin"]; dy <- bb["ymax"] - bb["ymin"]
  d_head$x_year <- bb["xmin"] + 0.09 * dx
  d_head$y_year <- bb["ymin"] + 0.12 * dy
  d_head_pt <- dplyr::filter(d_head, lon >= bb["xmin"], lon <= bb["xmax"],
                             lat >= bb["ymin"], lat <= bb["ymax"])
  d_vis  <- dplyr::filter(visited, naturalista == nat, frame == k,
                          !lugar %in% c("Londres", "Liverpool"))
  d_start <- dplyr::filter(waypoints, naturalista == nat,
                           !lugar %in% c("Londres", "Liverpool")) |> slice(1)

  capas <- get_base(nat, bb, con_estados)

  if (!con_estados) {
    d_path <- segment_path(d_path)
    capas <- c(capas, list(
      geom_path(data = d_path, aes(lon, lat, group = seg),
                color = col, linewidth = 0.9, alpha = 0.3, lineend = "round"),
      geom_path(data = d_path, aes(lon, lat, group = seg),
                color = col, linewidth = 0.35, lineend = "round")
    ))
  }

  capas <- c(capas, list(
    geom_point(data = d_vis, aes(lon, lat), color = col,
               size = if (con_estados) 0.85 else 0.4,
               alpha = if (con_estados) 0.75 else 0.45),
    geom_point(data = d_start, aes(lon, lat), shape = 21,
               fill = VINTAGE$paper, color = col, size = 1.5),
    geom_point(data = d_head_pt, aes(lon, lat), color = VINTAGE$paper, size = 2.4),
    geom_point(data = d_head_pt, aes(lon, lat), color = col, size = 1.3),
    geom_text(data = d_head,
              aes(x_year, y_year, label = paste0(year, " · ", lugar_corto)),
              family = "Georgia", fontface = "italic", size = 3.6,
              color = VINTAGE$ink, hjust = 0)
  ))

  ggplot() +
    capas +
    coord_sf(crs = crs, default_crs = 4326, expand = FALSE) +
    labs(
      title = toupper(nat),
      subtitle = paste0(NAT_PROFESION[[nat]], " · ",
                        meta$periodo[meta$naturalista == nat])
    ) +
    theme_vintage(base_size = 8.5) +
    theme(
      plot.title = element_text(size = 10.5, face = "bold", margin = margin(2, 0, 0, 0)),
      plot.subtitle = element_text(size = 8.2, face = "italic", color = "#475569",
                                   margin = margin(0, 0, 4, 0)),
      plot.margin = margin(8, 5, 3, 5)
    )
}

plot_facetas <- function(k) {
  ps <- lapply(facet_levels, function(n) facet_panel(n, k))

  cartela <- ggplot() +
    annotate("text", x = 0.02, y = 0.97, hjust = 0, vjust = 1,
             label = "CUATRO VIAJES · 182 AÑOS",
             family = "Georgia", fontface = "bold", size = 5.4, color = VINTAGE$ink) +
    annotate("text", x = 0.02, y = 0.84, hjust = 0, vjust = 1,
             label = "Darwin 1831–1836 · 43 paradas\nHumboldt 1799–1804 · 44 paradas\nWallace 1848–1862 · 45 paradas\nBravo 1931–1981 · 103 localidades",
             family = "Georgia", fontface = "italic", size = 4.2,
             color = VINTAGE$muted, lineheight = 1.25) +
    annotate("text", x = 0.02, y = 0.38, hjust = 0, vjust = 1,
             label = "METODOLOGÍA",
             family = "Georgia", fontface = "bold", size = 4.4, color = VINTAGE$ink) +
    annotate("text", x = 0.02, y = 0.30, hjust = 0, vjust = 1,
             label = "Itinerarios fechados, pista temporal acumulativa,\nproyección Robinson y tramos esquemáticos.",
             family = "Georgia", fontface = "italic", size = 4.3,
             color = VINTAGE$muted, lineheight = 1.2) +
    annotate("text", x = 0.02, y = 0.03, hjust = 0, vjust = 0,
             label = "Línea continua: ruta de expedición · vacío: traslado a Europa no dibujado",
             family = "Georgia", size = 3.0, color = VINTAGE$muted) +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) +
    theme_void() +
    theme(
      panel.background = element_rect(fill = VINTAGE$ocean, color = VINTAGE$border, linewidth = 0.4),
      plot.background = element_rect(fill = VINTAGE$paper, color = NA),
      plot.margin = margin(8, 5, 3, 5)
    )

  (ps[[1]] | ps[[2]]) / ps[[3]] / (ps[[4]] | cartela) +
    patchwork::plot_layout(heights = c(1.05, 0.75, 1.2)) +
    patchwork::plot_annotation(
      title = "CUATRO NATURALISTAS, CUATRO RUTAS",
      subtitle = "Darwin · Humboldt · Wallace · Bravo — un siglo y medio de exploración naturalista",
      caption = caption_txt,
      theme = theme(
        plot.background = element_rect(fill = VINTAGE$paper, color = NA),
        plot.title = element_text(family = "Georgia", face = "bold", size = 17,
                                  color = VINTAGE$ink),
        plot.subtitle = element_text(family = "Georgia", face = "italic", size = 9.5,
                                     color = VINTAGE$muted),
        plot.caption = element_text(family = "Georgia", size = 6.2,
                                    color = VINTAGE$muted, hjust = 0)
      )
    )
}

# ------------------------------------------------------------------------------
# Render: PNG por fotograma + GIF con gifski
# ------------------------------------------------------------------------------

render_gif <- function(plot_fun, file, width, height, fps = 12, ids = NULL) {
  if (is.null(ids)) {
    ids <- round(seq(1, N_TOTAL, length.out = if (preview) 12 else 100))
  }
  dir <- if (preview) {
    file.path("days/day06_vintage/_preview", tools::file_path_sans_ext(basename(file)))
  } else {
    file.path(tempdir(), paste0("day06_", tools::file_path_sans_ext(basename(file))))
  }
  unlink(dir, recursive = TRUE)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  message("Renderizando ", basename(file), ": ", length(ids), " fotogramas…")
  for (i in seq_along(ids)) {
    p <- plot_fun(ids[i])
    ggsave(
      filename = file.path(dir, sprintf("f%04d.png", i)),
      plot = p, width = width / 100, height = height / 100, dpi = 100,
      bg = VINTAGE$paper, device = ragg::agg_png
    )
    if (i %% 20 == 0) message("  ", i, "/", length(ids))
  }

  files <- sort(list.files(dir, pattern = "\\.png$", full.names = TRUE))
  if (preview) {
    message("  preview: ", dir)
    return(invisible(NULL))
  }
  files <- c(files, rep(tail(files, 1), 12))  # pausa final
  gifski::gifski(files, gif_file = file, width = width, height = height, delay = 1 / fps, loop = TRUE, progress = FALSE)
  message("  → ", file, " (", round(file.size(file) / 1e6, 2), " MB)")
  unlink(dir, recursive = TRUE)
  invisible(NULL)
}

# ------------------------------------------------------------------------------
# Ejecución
# ------------------------------------------------------------------------------

if (target %in% c("all", "darwin")) {
  render_gif(function(k) plot_nat("Charles Darwin", k),
             "outputs/high_res/day06_darwin.gif", 1200, 700)
}

if (target %in% c("all", "humboldt")) {
  render_gif(function(k) plot_nat("Alexander von Humboldt", k),
             "outputs/high_res/day06_humboldt.gif", 1150, 760)
}

if (target %in% c("all", "mexico")) {
  wp_mx <- mexico_waypoints()
  tr_mx <- build_track(wp_mx, step_days = 3)
  fr_mx <- build_frames(tr_mx, n_frames = 100, max_path = 160)
  fr_mx$path$naturalista <- "Alexander von Humboldt"
  fr_mx$head$naturalista <- "Alexander von Humboldt"
  fr_mx$visited <- tr_mx |>
    mutate(frame = round(t * 99) + 1) |>
    select(frame, lon, lat, lugar)
  ids_mx <- round(seq(1, 100, length.out = if (preview) 12 else 100))
  render_gif(
    function(k) {
      kk <- min(k, 100)
      d_path <- dplyr::filter(fr_mx$path, frame == kk)
      d_head <- dplyr::filter(fr_mx$head, frame == kk)
      d_vis  <- dplyr::filter(fr_mx$visited, frame <= kk)
      bb  <- c(xmin = -106.5, ymin = 15.2, xmax = -93.0, ymax = 24.2)
      col <- NAT_COLORS[["Alexander von Humboldt"]]
      ciudades <- tibble::tribble(
        ~lon, ~lat, ~nombre,
        -99.13, 19.43, "Ciudad de México", -99.82, 16.85, "Acapulco",
        -99.61, 18.56, "Taxco", -101.26, 21.02, "Guanajuato",
        -98.20, 19.04, "Puebla", -96.13, 19.17, "Veracruz",
        -96.72, 17.07, "Oaxaca"
      )
      ggplot() +
        get_base("humboldt_mexico", bb, TRUE) +
        geom_path(data = d_path, aes(lon, lat), color = col,
                  linewidth = 1.15, alpha = 0.28, lineend = "round") +
        geom_path(data = d_path, aes(lon, lat), color = col,
                  linewidth = 0.5, lineend = "round") +
        geom_point(data = d_vis, aes(lon, lat), color = col, size = 0.8, alpha = 0.6) +
        geom_point(data = d_head, aes(lon, lat), color = VINTAGE$paper, size = 3.4) +
        geom_point(data = d_head, aes(lon, lat), color = col, size = 1.8) +
        geom_text(data = ciudades, aes(lon, lat, label = nombre), family = "Georgia",
                  fontface = "italic", size = 2.5, color = VINTAGE$muted, vjust = -0.5) +
        geom_text(data = d_head, aes(-105.8, 16.1, label = year), family = "Georgia",
                  fontface = "italic", size = 7, color = VINTAGE$ink, hjust = 0) +
        coord_sf(crs = crs_mx, default_crs = 4326, expand = FALSE) +
        labs(
          title = "HUMBOLDT EN NUEVA ESPAÑA · 1803–1804",
          subtitle = "De Acapulco a Veracruz: minas, volcanes y el Ensayo político sobre el reino de la Nueva España",
          caption = caption_txt
        ) +
        theme_vintage(base_size = 11) +
        theme(plot.title = element_text(size = 13, face = "bold"),
              plot.subtitle = element_text(size = 10, color = "#475569"),
              plot.caption = element_text(size = 6.4))
    },
    "outputs/high_res/day06_humboldt_mexico.gif", 1000, 740,
    ids = ids_mx
  )
}

if (target %in% c("all", "wallace")) {
  render_gif(function(k) plot_nat("Alfred Russel Wallace", k),
             "outputs/high_res/day06_wallace.gif", 1300, 640)
}

if (target %in% c("all", "bravo")) {
  render_gif(function(k) plot_nat("Helia Bravo Hollis", k),
             "outputs/high_res/day06_bravo.gif", 1000, 740)
}

if (target %in% c("all", "facetas")) {
  render_gif(plot_facetas, "outputs/high_res/day06_naturalistas_facetas.gif", 1300, 1000, fps = 12)
}

