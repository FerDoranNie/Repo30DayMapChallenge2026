# ==============================================================================
# Día 06 — Vintage: póster estático "Cuatro naturalistas, cuatro rutas"
#
# Requiere: days/day06_vintage/day06_data_pipeline.R
# Salidas:  outputs/high_res/day06_vintage_naturalistas.png  (300 dpi)
#           outputs/gallery/day06_vintage_naturalistas.png   (1600 px)
#
# Autor: Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
source("days/day06_vintage/day06_utils.R")
suppressPackageStartupMessages({
  library(sf)
  library(patchwork)
  library(ggrepel)
})
sf_use_s2(FALSE)

dir.create("outputs/high_res", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/gallery", recursive = TRUE, showWarnings = FALSE)

ds <- readRDS("data/processed/day06_naturalistas.rds")
tracks <- ds$tracks
waypoints <- ds$waypoints
meta <- ds$meta

world  <- st_read("data/raw/day04/ne_50m_admin_0_countries.geojson", quiet = TRUE)
states <- st_read("data/raw/day01/mexico_states.geojson", quiet = TRUE)

crs_robin <- "+proj=robin +lon_0=0 +datum=WGS84 +units=m +no_defs"
crs_mx    <- "+proj=lcc +lat_1=17.5 +lat_2=29.5 +lat_0=23 +lon_0=-102 +datum=WGS84 +units=m +no_defs"

bboxes <- list(
  "Charles Darwin"         = c(xmin = -180, ymin = -58, xmax = 180, ymax = 74),
  "Alexander von Humboldt" = c(xmin = -128, ymin = -25, xmax = 10, ymax = 56),
  "Alfred Russel Wallace"  = c(xmin = -82, ymin = -13, xmax = 156, ymax = 36),
  "Helia Bravo Hollis"     = c(xmin = -118.5, ymin = 14, xmax = -86, ymax = 33)
)

etiquetas_clave <- list(
  "Charles Darwin"         = c("Plymouth (Plymouth Sound)", "Tierra del Fuego (bahía Buen Suceso)",
                               "Puerto Baquerizo Moreno (San Cristóbal)", "Sídney (Port Jackson)", "Falmouth"),
  "Alexander von Humboldt" = c("Cumaná", "Quito", "Chimborazo", "Ciudad de México"),
  "Alfred Russel Wallace"  = c("Belém (Pará)", "Manaus (Barra do Rio Negro)", "Ternate",
                               "Dorey (Nueva Guinea)", "Singapur"),
  "Helia Bravo Hollis"     = c("Baja California", "México", "Veracruz", "Oaxaca")
)

poster_panel <- function(nat) {
  bb  <- bboxes[[nat]]
  col <- NAT_COLORS[[nat]]
  con_estados <- nat == "Helia Bravo Hollis"
  crs <- if (con_estados) crs_mx else crs_robin

  wp <- dplyr::filter(waypoints, naturalista == nat,
                      !lugar %in% c("Londres", "Liverpool"))
  tr <- dplyr::filter(tracks, naturalista == nat) |>
    dplyr::select(lon, lat, traslado)
  tr <- split_antimeridian(tr)
  tr <- segment_path(tr)

  w <- st_crop(world, st_bbox(bb, crs = 4326))
  capas <- list(geom_sf(data = w, fill = VINTAGE$land, color = VINTAGE$border, linewidth = 0.25))
  if (con_estados) {
    capas <- append(capas, list(
      geom_sf(data = st_crop(states, st_bbox(bb, crs = 4326)),
              fill = NA, color = VINTAGE$border, linewidth = 0.3)
    ))
  }

  if (!con_estados) {
    capas <- c(capas, list(
      geom_path(data = tr, aes(lon, lat, group = seg), color = col,
                linewidth = 1.7, alpha = 0.25, lineend = "round"),
      geom_path(data = tr, aes(lon, lat, group = seg), color = col,
                linewidth = 0.65, lineend = "round")
    ))
  }

  capas <- c(capas, list(
    geom_point(data = wp, aes(lon, lat), color = col,
               size = if (con_estados) 1.9 else 0.9,
               alpha = if (con_estados) 0.8 else 0.55),
    geom_point(data = dplyr::filter(wp, lugar %in% etiquetas_clave[[nat]]),
               aes(lon, lat), color = VINTAGE$paper, size = 3.6),
    geom_point(data = dplyr::filter(wp, lugar %in% etiquetas_clave[[nat]]),
               aes(lon, lat), color = col, size = 2.0),
    geom_text_repel(
      data = dplyr::filter(wp, lugar %in% etiquetas_clave[[nat]]) |>
        dplyr::distinct(lugar, .keep_all = TRUE),
      aes(lon, lat, label = lugar),
      family = "Georgia", fontface = "italic", size = 3.1,
      color = VINTAGE$ink, bg.color = VINTAGE$paper, bg.r = 0.12,
      min.segment.length = 0, segment.color = VINTAGE$muted,
      segment.size = 0.25, max.overlaps = 20, box.padding = 0.5
    )
  ))

  subtitulo <- switch(
    nat,
    "Charles Darwin"         = "HMS Beagle · 43 paradas documentadas",
    "Alexander von Humboldt" = "Expedición americana · 44 paradas",
    "Alfred Russel Wallace"  = "Amazonía y archipiélago malayo · 45 paradas",
    "Helia Bravo Hollis"     = "Cactáceas de México · 103 localidades"
  )

  ggplot() +
    capas +
    coord_sf(crs = crs, default_crs = 4326, expand = FALSE) +
    labs(title = paste0(toupper(nat), " · ", NAT_PROFESION[[nat]]),
         subtitle = paste0(meta$periodo[meta$naturalista == nat], " · ", subtitulo)) +
    theme_vintage(base_size = 10) +
    theme(
      plot.title = element_text(size = 11, face = "bold", margin = margin(2, 0, 1, 0)),
      plot.subtitle = element_text(size = 8, color = "#475569",
                                   margin = margin(0, 0, 4, 0)),
      plot.margin = margin(3, 4, 3, 4),
      panel.border = element_rect(fill = NA, color = VINTAGE$border, linewidth = 0.5)
    )
}

# ------------------------------------------------------------------------------
# Cabecera y cronología
# ------------------------------------------------------------------------------

cabecera <- ggplot() +
  annotate("text", x = 0, y = 0.78, hjust = 0, vjust = 1,
           label = "CUATRO NATURALISTAS, CUATRO RUTAS",
           family = "Georgia", face = "bold", size = 7.2, color = VINTAGE$ink) +
  annotate("text", x = 0, y = 0.46, hjust = 0, vjust = 1,
           label = "Un siglo y medio de exploración naturalista en el mundo y en México",
           family = "Georgia", fontface = "italic", size = 3.4, color = VINTAGE$muted) +
  annotate("segment", x = 0, xend = 1, y = 0.22, yend = 0.22,
           color = VINTAGE$border, linewidth = 0.6) +
  annotate("text", x = 1, y = 0.10, hjust = 1, vjust = 0,
           label = "Darwin · Humboldt · Wallace · Bravo",
           family = "Georgia", size = 2.8, color = VINTAGE$muted) +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) +
  theme_void() +
  theme(plot.background = element_rect(fill = VINTAGE$paper, color = NA),
        plot.margin = margin(4, 6, 0, 6))

cronologia <- function() {
  per <- tibble(
    naturalista = factor(names(NAT_COLORS), levels = rev(names(NAT_COLORS))),
    ini = c(1831, 1799, 1848, 1931),
    fin = c(1836, 1804, 1862, 1981)
  )
  ggplot(per) +
    geom_segment(aes(x = ini, xend = fin, y = naturalista, yend = naturalista,
                     color = naturalista),
                 linewidth = 3.2, lineend = "round", alpha = 0.85) +
    geom_text(aes(x = ini - 2, y = naturalista, label = ini),
              family = "Georgia", size = 2.2, color = VINTAGE$muted, hjust = 1) +
    geom_text(aes(x = fin + 3, y = naturalista, label = fin),
              family = "Georgia", size = 2.2, color = VINTAGE$muted, hjust = 0) +
    scale_color_manual(values = NAT_COLORS, guide = "none") +
    scale_x_continuous(limits = c(1785, 1995), breaks = seq(1800, 1980, 30)) +
    labs(title = "CRONOLOGÍA DE LAS EXPEDICIONES",
         x = NULL, y = NULL) +
    theme_vintage(base_size = 8) +
    theme(
      plot.title = element_text(size = 8, face = "bold", margin = margin(2, 0, 4, 0)),
      axis.text.x = element_text(family = "Georgia", size = 6, color = VINTAGE$muted),
      axis.text.y = element_text(family = "Georgia", face = "italic", size = 6.5,
                                 color = VINTAGE$ink),
      panel.background = element_rect(fill = VINTAGE$paper, color = VINTAGE$border,
                                      linewidth = 0.5),
      panel.grid.major.x = element_line(color = VINTAGE$grid, linewidth = 0.15),
      panel.grid.major.y = element_blank(),
      axis.ticks = element_blank(),
      plot.margin = margin(3, 6, 3, 6)
    )
}

# ------------------------------------------------------------------------------
# Composición
# ------------------------------------------------------------------------------

p_darwin   <- poster_panel("Charles Darwin")
p_humboldt <- poster_panel("Alexander von Humboldt")
p_wallace  <- poster_panel("Alfred Russel Wallace")
p_bravo    <- poster_panel("Helia Bravo Hollis")

poster <- cabecera /
  (p_darwin | p_humboldt) /
  (p_wallace | p_bravo) /
  cronologia() +
  patchwork::plot_layout(heights = c(0.2, 0.92, 1.0, 0.22)) +
  patchwork::plot_annotation(
    caption = paste0(
      "#30DayMapChallenge 2026 · Día 06: Vintage — Cuatro naturalistas, cuatro rutas\n",
      "Datos: Darwin Online · Minguet, Alejandro de Humboldt (UNAM) · Wallace Online · ",
      "GBIF Occurrence API (Helia Bravo Hollis) | ",
      "Fernando Dorantes Nieto (@FerDoranNie)"
    ),
    theme = theme(
      plot.background = element_rect(fill = VINTAGE$paper, color = NA),
      plot.caption = element_text(family = "Georgia", size = 3.4,
                                  color = VINTAGE$muted, hjust = 0,
                                  margin = margin(6, 8, 8, 8))
    )
  )

ggsave("outputs/high_res/day06_vintage_naturalistas.png", poster,
       width = 16, height = 13, dpi = 300, bg = VINTAGE$paper, device = ragg::agg_png,
       limitsize = FALSE)
ggsave("outputs/gallery/day06_vintage_naturalistas.png", poster,
       width = 16, height = 13, dpi = 100, bg = VINTAGE$paper, device = ragg::agg_png,
       limitsize = FALSE)

message("Póster listo.")
