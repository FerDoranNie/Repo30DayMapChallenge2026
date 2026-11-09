# ============================================================================
# Día 08 — Utopia | Póster cartográfico
# Planeta 30x30: ecorregiones y megacorredores biológicos
#
# Requiere: data/processed/day08_dataset.rds (day08_data_pipeline.R)
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

d <- readRDS("data/processed/day08_dataset.rds")
eco       <- d$eco
barras    <- d$biomas
totales   <- d$totales_bioma
corredores<- d$corredores
nodos     <- d$nodos
etiquetas <- d$etiquetas
kpi       <- d$kpi

# ---------------------------------------------------------------------------
# Paleta y tipografía
# ---------------------------------------------------------------------------
PAPEL    <- "#F7F4EB"
TINTA    <- "#0F172A"
GRIS     <- "#475569"
GRIS2    <- "#334155"
OCEANO   <- "#DCE6F2"
MARCO    <- "#94A3B8"
RETICULA <- "#B8C7D9"

COLORES <- c(
  "Ya alcanzó la mitad protegida" = "#0E5C46",
  "Aún puede alcanzar la mitad"   = "#4FA97B",
  "Restauración posible"          = "#E3A33C",
  "En peligro"                    = "#A6503C"
)
COLORES_LEYENDA <- c(
  "Ya alcanzó la mitad\nprotegida" = "#0E5C46",
  "Aún puede alcanzar\nla mitad"   = "#4FA97B",
  "Restauración\nposible"          = "#E3A33C",
  "En peligro"                     = "#A6503C"
)
ETIQUETAS <- c(
  "Ya alcanzó la mitad",
  "Aún puede alcanzar la mitad",
  "Restauración posible",
  "En peligro"
)

FUENTE <- "Georgia"

tema <- theme_void(base_family = FUENTE) +
  theme(
    plot.background  = element_rect(fill = PAPEL, colour = NA),
    panel.background = element_rect(fill = PAPEL, colour = NA),
    text             = element_text(colour = TINTA),
    plot.margin      = margin(0, 0, 0, 0)
  )

fmt1 <- function(x) formatC(x, format = "f", digits = 1,
                            decimal.mark = ",", big.mark = ".")
fmt0 <- function(x) formatC(round(x), format = "d",
                            decimal.mark = ",", big.mark = ".")
mkm2 <- function(x) fmt1(x / 1e6)

# ---------------------------------------------------------------------------
# 1. Bloque de título
# ---------------------------------------------------------------------------
p_titulo <- ggplot() +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), clip = "off") +
  annotate("text", x = 0, y = 0.97, hjust = 0, vjust = 1,
           label = "#30DAYMAPCHALLENGE 2026   ·   DÍA 08",
           size = 3.0, colour = GRIS, family = FUENTE, fontface = "bold") +
  annotate("text", x = 0, y = 0.72, hjust = 0, vjust = 1,
           label = "PLANETA 30×30",
           size = 10.6, colour = TINTA, family = FUENTE, fontface = "bold") +
  annotate("text", x = 0, y = 0.30, hjust = 0, vjust = 1,
           label = paste0(
             "El estado de conservación de las ", kpi$n_eco,
             " ecorregiones terrestres y la red de megacorredores que aún podemos salvar"
           ),
           size = 2.95, colour = GRIS2, family = FUENTE) +
  annotate("text", x = 0, y = 0.12, hjust = 0, vjust = 1,
           label = paste0(
             "Meta 30×30: ", mkm2(kpi$meta30_km2), " Mkm²   ·   Half-Earth (50%): ",
             mkm2(kpi$meta50_km2), " Mkm²   ·   Superficie analizada: ",
             mkm2(kpi$total_km2), " Mkm²"
           ),
           size = 2.55, colour = GRIS, family = FUENTE, fontface = "italic") +
  annotate("text", x = 1, y = 0.90, hjust = 1, vjust = 1,
           label = "U T O P I A", size = 4.6, colour = "#0E5C46",
           family = FUENTE, fontface = "bold") +
  tema

# ---------------------------------------------------------------------------
# 2. Franja de indicadores
# ---------------------------------------------------------------------------
kpi_df <- data.frame(
  x = c(0.00, 0.265, 0.53, 0.795),
  valor = c(
    mkm2(kpi$area_santuario),
    mkm2(kpi$area_alcanzar),
    mkm2(kpi$area_peligro),
    as.character(kpi$n_corredores)
  ),
  unidad = c("Mkm²", "Mkm²", "Mkm²", "corredores"),
  dx = c(0.043, 0.060, 0.060, 0.030),
  etiqueta = c(
    "en ecorregiones que ya\nalcanzaron la mitad protegida",
    "aún conservan hábitat para\nalcanzar la mitad protegida",
    "en ecorregiones\nen peligro",
    paste0(fmt0(kpi$red_km), " km de red\nesquemática")
  )
)

p_kpi <- ggplot(kpi_df) +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), clip = "off") +
  geom_text(aes(x, 0.47, label = valor), hjust = 0, vjust = 0,
            size = 7.2, colour = TINTA, family = FUENTE, fontface = "bold") +
  geom_text(aes(x + dx, 0.47, label = unidad), hjust = 0, vjust = 0,
            size = 3.0, colour = TINTA, family = FUENTE) +
  geom_text(aes(x, 0.31, label = etiqueta), hjust = 0, vjust = 1,
            size = 2.5, colour = GRIS2, family = FUENTE, lineheight = 1.05) +
  geom_segment(aes(x = x - 0.022, xend = x - 0.022, y = 0.08, yend = 0.88),
               colour = "#D6CFBF", linewidth = 0.35) +
  tema

# ---------------------------------------------------------------------------
# 3. Mapa principal
# ---------------------------------------------------------------------------
ret <- st_graticule(lat = seq(-40, 80, by = 20), lon = seq(-180, 180, by = 30))
ret <- st_transform(ret, 8857)

# desplazamiento manual de los números 4 y 5 para que no se encimen en África
etiquetas <- etiquetas %>%
  mutate(
    x = x + ifelse(corredor == 4, -6.0e5, ifelse(corredor == 5, 4.5e5, 0)),
    y = y + ifelse(corredor == 4, -3.0e5, ifelse(corredor == 5, 3.5e5, 0))
  )

p_mapa <- ggplot() +
  geom_sf(data = ret, colour = RETICULA, linewidth = 0.18, alpha = 0.75,
          inherit.aes = FALSE) +
  geom_sf(data = eco, aes(fill = nivel), colour = NA, inherit.aes = FALSE) +
  # halo de los corredores
  geom_sf(data = corredores, colour = "#FFF4D6", linewidth = 3.6, alpha = 0.55,
          lineend = "round", inherit.aes = FALSE) +
  geom_sf(data = corredores, colour = "#F59E0B", linewidth = 2.1, alpha = 0.55,
          lineend = "round", inherit.aes = FALSE) +
  geom_sf(data = corredores, colour = "#1F2937", linewidth = 0.75,
          lineend = "round", inherit.aes = FALSE) +
  geom_sf(data = nodos, shape = 21, size = 1.35, fill = PAPEL,
          colour = "#1F2937", stroke = 0.4, inherit.aes = FALSE) +
  geom_point(data = etiquetas, aes(x = x, y = y), shape = 21, size = 5.9,
             fill = PAPEL, colour = "#1F2937", stroke = 0.55) +
  geom_text(data = etiquetas, aes(x = x, y = y, label = corredor),
            size = 2.45, colour = TINTA, family = FUENTE, fontface = "bold") +
  annotate("text", x = 17.1e6, y = -6.75e6, hjust = 1, vjust = 0,
           label = "Proyección Equal Earth (EPSG:8857)",
           size = 2.15, colour = GRIS, family = FUENTE, fontface = "italic") +
  scale_fill_manual(
    values = COLORES,
    labels = ETIQUETAS,
    name = "Estado de conservación", drop = FALSE
  ) +
  coord_sf(crs = 8857, xlim = c(-17.3e6, 17.3e6), ylim = c(-6.95e6, 8.45e6),
           expand = FALSE, datum = NA) +
  theme_void(base_family = FUENTE) +
  theme(
    panel.background = element_rect(fill = OCEANO, colour = NA),
    panel.border     = element_rect(fill = NA, colour = MARCO, linewidth = 0.5),
    legend.position      = c(0.018, 0.05),
    legend.justification = c(0, 0),
    legend.background    = element_rect(fill = alpha(PAPEL, 0.93),
                                        colour = MARCO, linewidth = 0.3),
    legend.title    = element_text(size = 5.6, face = "bold", family = FUENTE,
                                   colour = TINTA),
    legend.text     = element_text(size = 5.4, family = FUENTE, colour = GRIS2),
    legend.key.size = unit(3.0, "mm"),
    legend.spacing.y = unit(0.9, "mm"),
    legend.margin   = margin(3, 5, 3, 4),
    plot.background = element_rect(fill = PAPEL, colour = NA),
    plot.margin     = margin(4, 0, 0, 0)
  )

# ---------------------------------------------------------------------------
# 4. Barras por bioma
# ---------------------------------------------------------------------------
barras <- barras %>%
  group_by(bioma_es) %>%
  mutate(share = area_km2 / sum(area_km2)) %>%
  ungroup()

etiq_total <- totales %>%
  mutate(x = 1.015, etiqueta = paste0(mkm2(total_km2), " Mkm²"))

p_barras <- ggplot(barras, aes(x = share, y = bioma_es, fill = nivel)) +
  geom_col(position = position_stack(reverse = TRUE), width = 0.74) +
  geom_vline(xintercept = 0.5, linetype = "22", colour = TINTA,
             linewidth = 0.35, alpha = 0.65) +
  geom_text(data = etiq_total, aes(x = x, y = bioma_es, label = etiqueta),
            hjust = 0, size = 2.3, colour = GRIS, family = FUENTE,
            inherit.aes = FALSE) +
  scale_fill_manual(values = COLORES, labels = ETIQUETAS,
                    name = NULL, drop = FALSE) +
  scale_x_continuous(labels = percent_format(accuracy = 1),
                     breaks = c(0, 0.25, 0.5, 0.75, 1),
                     expand = c(0, 0)) +
  coord_cartesian(xlim = c(0, 1), clip = "off") +
  labs(
    title = "EL REPARTO DE CADA BIOMA",
    subtitle = "Proporción de la superficie de cada bioma según su estado de conservación",
    caption = "Línea punteada: 50% de la superficie del bioma (meta Half-Earth)."
  ) +
  guides(fill = guide_legend(nrow = 1, byrow = TRUE,
                             keywidth = unit(4, "mm"), keyheight = unit(3, "mm"))) +
  theme_minimal(base_family = FUENTE) +
  theme(
    plot.background  = element_rect(fill = PAPEL, colour = NA),
    panel.background = element_rect(fill = PAPEL, colour = NA),
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_line(colour = "#E4DDCB", linewidth = 0.3),
    axis.title        = element_blank(),
    axis.text.y       = element_text(size = 5.9, colour = TINTA),
    axis.text.x       = element_text(size = 5.6, colour = GRIS),
    axis.ticks        = element_blank(),
    plot.title        = element_text(size = 7.4, face = "bold", colour = TINTA),
    plot.subtitle     = element_text(size = 5.7, colour = GRIS, margin = margin(b = 4)),
    plot.caption      = element_text(size = 4.9, colour = GRIS, hjust = 0,
                                     margin = margin(t = 3), face = "italic"),
    legend.position   = "bottom",
    legend.text       = element_text(size = 5.4, colour = GRIS2),
    legend.key.height = unit(2.8, "mm"),
    legend.margin     = margin(t = 1),
    plot.margin       = margin(6, 58, 0, 0)
  )

# ---------------------------------------------------------------------------
# 5. Índice de megacorredores
# ---------------------------------------------------------------------------
red_df <- corredores %>%
  st_drop_geometry() %>%
  mutate(
    y = rev(seq_len(n())),
    num = sprintf("%02d", corredor),
    largo = paste0(fmt0(largo_km), " km")
  )

p_red <- ggplot(red_df) +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 12), clip = "off") +
  geom_text(aes(x = 0.00, y = y, label = num), hjust = 0, vjust = 1,
            size = 2.7, colour = "#B45309", family = FUENTE, fontface = "bold") +
  geom_text(aes(x = 0.075, y = y, label = nombre), hjust = 0, vjust = 1,
            size = 2.45, colour = TINTA, family = FUENTE) +
  geom_text(aes(x = 1.00, y = y, label = largo), hjust = 1, vjust = 1,
            size = 2.35, colour = GRIS, family = FUENTE) +
  annotate("text", x = 0, y = 11.85, hjust = 0, vjust = 1,
           label = "DIEZ MEGACORREDORES",
           size = 3.0, colour = TINTA, family = FUENTE, fontface = "bold") +
  annotate("text", x = 0, y = 11.35, hjust = 0, vjust = 1,
           label = "Trazos esquemáticos entre núcleos silvestres",
           size = 2.25, colour = GRIS, family = FUENTE, fontface = "italic") +
  annotate("text", x = 0, y = 0.25, hjust = 0, vjust = 1,
           label = paste0("Red total: ", fmt0(kpi$red_km), " km"),
           size = 2.4, colour = GRIS2, family = FUENTE, fontface = "bold") +
  theme_void(base_family = FUENTE) +
  theme(
    plot.background = element_rect(fill = PAPEL, colour = NA),
    plot.margin     = margin(6, 0, 0, 12)
  )

# ---------------------------------------------------------------------------
# 6. Composición del póster
# ---------------------------------------------------------------------------
fila_inferior <- p_barras + p_red + plot_layout(widths = c(1.62, 1))

poster <- p_titulo / p_kpi / p_mapa / fila_inferior +
  plot_layout(heights = c(1.15, 0.95, 5.90, 2.95)) +
  plot_annotation(
    caption = paste0(
      "#30DayMapChallenge 2026  |  Día 08: Utopia   —   Datos: RESOLVE Ecoregions 2017 (Dinerstein et al., BioScience)   ·   ",
      "Superficie calculada en proyección Equal Earth (EPSG:8857); se excluyen Antártida y roca/hielo.\n",
      "Gráfico: Fernando Dorantes Nieto (@FerDoranNie)"
    ),
    theme = theme(
      plot.background = element_rect(fill = PAPEL, colour = NA),
      plot.caption    = element_text(family = FUENTE, size = 5.7, colour = GRIS,
                                     hjust = 0, lineheight = 1.25),
      plot.margin     = margin(10, 20, 6, 20)
    )
  )

# ---------------------------------------------------------------------------
# 7. Exportación
# ---------------------------------------------------------------------------
ggsave("outputs/high_res/day08_utopia_planeta_30x30.png", poster,
       width = 16, height = 11, units = "in", dpi = 300,
       device = agg_png, bg = PAPEL)

ggsave("outputs/gallery/day08_utopia_planeta_30x30.png", poster,
       width = 16, height = 11, units = "in", dpi = 150,
       device = agg_png, bg = PAPEL)

cat("Póster generado:\n",
    " - outputs/high_res/day08_utopia_planeta_30x30.png\n",
    " - outputs/gallery/day08_utopia_planeta_30x30.png\n")
