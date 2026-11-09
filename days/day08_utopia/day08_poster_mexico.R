# ============================================================================
# Día 08 — Utopia | Versión alterna: México
# Póster cartográfico del estado de conservación de las ecorregiones mexicanas
#
# Requiere: data/processed/day08_mexico.rds (day08_mexico_pipeline.R)
# Autor:    Fernando Dorantes Nieto (@FerDoranNie)
# ============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
suppressPackageStartupMessages({
  library(sf)
  library(ggplot2)
  library(dplyr)
  library(patchwork)
  library(scales)
  library(ragg)
})
sf_use_s2(FALSE)

dir.create("outputs/high_res", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/gallery",  showWarnings = FALSE, recursive = TRUE)

d <- readRDS("data/processed/day08_mexico.rds")
mex     <- d$mex
eco_mx  <- d$eco_mx
kpi     <- d$kpi

PAPEL    <- "#F7F4EB"
TINTA    <- "#0F172A"
GRIS     <- "#475569"
GRIS2    <- "#334155"
OCEANO   <- "#DCE6F2"
MARCO    <- "#94A3B8"
RETICULA <- "#B8C7D9"
FUENTE   <- "Georgia"

COLORES <- c(
  "Ya alcanzó la mitad protegida" = "#0E5C46",
  "Aún puede alcanzar la mitad"   = "#4FA97B",
  "Restauración posible"          = "#E3A33C",
  "En peligro"                    = "#A6503C"
)

fmt1 <- function(x) formatC(x, format = "f", digits = 1,
                            decimal.mark = ",", big.mark = ".")
fmt2 <- function(x) formatC(x, format = "f", digits = 2,
                            decimal.mark = ",", big.mark = ".")
fmt0 <- function(x) formatC(round(x), format = "d",
                            decimal.mark = ",", big.mark = ".")

# Caja del mapa: un pequeño respiro de océano alrededor del país
bb <- st_bbox(mex)
dx <- diff(bb[c("xmin", "xmax")]); dy <- diff(bb[c("ymin", "ymax")])
xlim <- c(bb["xmin"] - 0.10 * dx, bb["xmax"] + 0.10 * dx)
ylim <- c(bb["ymin"] - 0.02 * dy, bb["ymax"] + 0.02 * dy)

# ---------------------------------------------------------------------------
# 1. Título
# ---------------------------------------------------------------------------
p_titulo <- ggplot() +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE, clip = "off") +
  annotate("text", x = 0, y = 0.95, hjust = 0, vjust = 1,
           label = "#30DAYMAPCHALLENGE 2026   ·   DÍA 08   ·   UTOPIA",
           size = 3.0, colour = GRIS, family = FUENTE, fontface = "bold") +
  annotate("text", x = 0, y = 0.66, hjust = 0, vjust = 1,
           label = "MÉXICO 30×30",
           size = 11.5, colour = TINTA, family = FUENTE, fontface = "bold") +
  annotate("text", x = 0, y = 0.18, hjust = 0, vjust = 1,
           label = "Lo que el país aún puede conservar",
           size = 3.4, colour = GRIS2, family = FUENTE, fontface = "italic") +
  annotate("text", x = 1, y = 0.26, hjust = 1, vjust = 1,
           label = paste0(fmt2(kpi$total_km2 / 1e6), " Mkm²   ·   ",
                          kpi$n_eco, " ecorregiones   ·   ", kpi$n_biomas, " biomas"),
           size = 2.8, colour = GRIS, family = FUENTE) +
  annotate("segment", x = 0, xend = 1, y = 0.02, yend = 0.02,
           colour = MARCO, linewidth = 0.3) +
  theme_void(base_family = FUENTE) +
  theme(plot.background = element_rect(fill = PAPEL, colour = NA),
        plot.margin = margin(0, 0, 0, 0))

# ---------------------------------------------------------------------------
# 2. Mapa
# ---------------------------------------------------------------------------
ret <- st_graticule(lat = seq(15, 35, by = 5), lon = seq(-125, -80, by = 5))
ret <- st_transform(ret, 6372)

mares <- data.frame(
  lon = c(-116.0, -92.5, -84.2),
  lat = c(24.0, 25.5, 18.5),
  etiqueta = c("OCÉANO PACÍFICO", "GOLFO DE MÉXICO", "MAR CARIBE"),
  hj = c(0.5, 0.5, 1)
) %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4326) %>%
  st_transform(6372)

bx <- xlim[1] + 0.06 * diff(xlim)
by <- ylim[1] + 0.07 * diff(ylim)
nx <- xlim[2] - 0.06 * diff(xlim)
ny <- ylim[2] - 0.07 * diff(ylim)

p_mapa <- ggplot() +
  geom_sf(data = ret, colour = RETICULA, linewidth = 0.18, alpha = 0.8,
          inherit.aes = FALSE) +
  geom_sf(data = mex, fill = "#E5E0D5", colour = NA, inherit.aes = FALSE) +
  geom_sf(data = eco_mx, aes(fill = nivel), colour = NA,
          linewidth = 0.0, inherit.aes = FALSE) +
  geom_sf(data = mex, fill = NA, colour = "#162235", linewidth = 0.75,
          inherit.aes = FALSE) +
  geom_sf_text(data = mares, aes(label = etiqueta, hjust = hj), size = 2.7,
               colour = "#64748B", family = FUENTE, fontface = "italic",
               inherit.aes = FALSE) +
  # barra de escala 500 km
  annotate("segment", x = bx, xend = bx + 5e5, y = by, yend = by,
           colour = TINTA, linewidth = 0.7) +
  annotate("segment", x = c(bx, bx + 5e5), xend = c(bx, bx + 5e5),
           y = by - 2e4, yend = by + 2e4, colour = TINTA, linewidth = 0.5) +
  annotate("text", x = bx + 2.5e5, y = by + 6e4, label = "500 km",
           size = 2.3, colour = GRIS2, family = FUENTE) +
  # norte
  annotate("segment", x = nx, xend = nx, y = ny - 1.3e5, yend = ny - 1e4,
           arrow = arrow(length = unit(2.2, "mm"), type = "closed"),
           colour = TINTA, linewidth = 0.5) +
  annotate("text", x = nx, y = ny + 3e4, label = "N",
           size = 2.6, colour = TINTA, family = FUENTE, fontface = "bold") +
  scale_fill_manual(values = COLORES, name = NULL, drop = FALSE) +
  coord_sf(crs = 6372, xlim = xlim, ylim = ylim, expand = FALSE, datum = NA) +
  theme_void(base_family = FUENTE) +
  theme(
    panel.background = element_rect(fill = OCEANO, colour = NA),
    panel.border     = element_rect(fill = NA, colour = MARCO, linewidth = 0.5),
    legend.position  = "none",
    plot.background  = element_rect(fill = PAPEL, colour = NA),
    plot.margin      = margin(2, 0, 0, 0)
  )

# ---------------------------------------------------------------------------
# 3. Franja de indicadores (también funciona como leyenda)
# ---------------------------------------------------------------------------
stats <- data.frame(
  x = c(0.012, 0.262, 0.512, 0.762),
  pct = paste0(c(fmt1(kpi$pct_santuario), fmt1(kpi$pct_alcanzar),
          fmt1(100 * kpi$area_recuperar / kpi$total_km2), fmt1(kpi$pct_peligro)), "%"),
  area = c(kpi$area_santuario, kpi$area_alcanzar, kpi$area_recuperar, kpi$area_peligro),
  etiqueta = c("Ya alcanzó la mitad\nprotegida", "Aún puede alcanzar\nla mitad",
               "Restauración\nposible", "En peligro"),
  color = unname(COLORES)
)

p_stats <- ggplot(stats) +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE, clip = "off") +
  geom_point(aes(x = x, y = 0.80), shape = 22, size = 7.2,
             fill = stats$color, colour = stats$color) +
  geom_text(aes(x = x + 0.045, y = 0.82, label = pct), hjust = 0, vjust = 1,
            size = 7.0, colour = TINTA, family = FUENTE, fontface = "bold") +
  geom_text(aes(x = x + 0.045, y = 0.47, label = etiqueta), hjust = 0, vjust = 1,
            size = 2.5, colour = TINTA, family = FUENTE, lineheight = 1.05) +
  geom_text(aes(x = x + 0.045, y = 0.24, label = paste0(fmt0(area), " km²")),
            hjust = 0, vjust = 1, size = 2.2, colour = GRIS, family = FUENTE) +
  geom_segment(data = stats[2:4, ], aes(x = x - 0.025, xend = x - 0.025,
                                        y = 0.08, yend = 0.92),
               colour = "#D6CFBF", linewidth = 0.35) +
  theme_void(base_family = FUENTE) +
  theme(plot.background = element_rect(fill = PAPEL, colour = NA),
        plot.margin = margin(2, 0, 4, 0))

# ---------------------------------------------------------------------------
# 4. Composición
# ---------------------------------------------------------------------------
poster <- p_titulo / p_mapa / p_stats +
  plot_layout(heights = c(1.00, 8.40, 1.35)) +
  plot_annotation(
    caption = paste0(
      "#30DayMapChallenge 2026  |  Día 08: Utopia — versión México   —   ",
      "Datos: RESOLVE Ecoregions 2017 (Dinerstein et al., BioScience) recortadas al polígono nacional   ·   ",
      "Proyección LCC México (EPSG:6372)\n",
      "La superficie de las ecorregiones (1,94 Mkm²) difiere del polígono oficial por vacíos costeros.   ",
      "Gráfico: Fernando Dorantes Nieto (@FerDoranNie)"
    ),
    theme = theme(
      plot.background = element_rect(fill = PAPEL, colour = NA),
      plot.caption    = element_text(family = FUENTE, size = 5.6, colour = GRIS,
                                     hjust = 0, lineheight = 1.25),
      plot.margin     = margin(8, 20, 6, 20)
    )
  )

ggsave("outputs/high_res/day08_utopia_mexico.png", poster,
       width = 16, height = 11, units = "in", dpi = 300,
       device = agg_png, bg = PAPEL)

ggsave("outputs/gallery/day08_utopia_mexico.png", poster,
       width = 16, height = 11, units = "in", dpi = 150,
       device = agg_png, bg = PAPEL)

cat("Póster México generado:\n",
    " - outputs/high_res/day08_utopia_mexico.png\n",
    " - outputs/gallery/day08_utopia_mexico.png\n")
