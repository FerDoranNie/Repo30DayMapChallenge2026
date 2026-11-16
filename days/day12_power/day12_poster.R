# ==============================================================================
# Día 12 — Power | Póster Cartográfico Editorial
# "¿El Poniente siempre es más rico? Geografía cardinal del poder
#  socioeconómico en las metrópolis de México"
#
# Requiere: data/processed/day12_power_ageb_cardinal.rds
# Salidas:  outputs/high_res/day12_power_poniente_rico.png (300 dpi)
#           outputs/gallery/day12_power_poniente_rico.png  (150 dpi)
# Autor:    Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

user_lib <- "C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3"
if (dir.exists(user_lib) && !(user_lib %in% .libPaths())) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(sf)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(patchwork)
  library(scales)
  library(ragg)
})

sf_use_s2(FALSE)
source("utils/theme_map2026.R")

msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n")
msg("Cargando dataset procesado Día 12: Power...")

ds <- readRDS("data/processed/day12_power_ageb_cardinal.rds")
ageb_metros     <- ds$ageb_metros
mun_metros      <- ds$mun_metros
centers_df      <- ds$centers_df
octant_summary  <- ds$octant_summary
city_summary    <- ds$city_summary
profile_we_zmvm <- ds$profile_we_zmvm
pca_var_exp     <- ds$pca_var_exp

# ==============================================================================
# Paleta Editorial Atlas Enmarcado (AGENTS.md + README Día 12)
# ==============================================================================
CREAM     <- "#F7F4EB"
OCEAN     <- "#DCE6F2"
STONE     <- "#E5E0D5"
PANEL     <- "#FBF9F3"
INK       <- "#0F172A"
SLATE     <- "#334155"
MUTED     <- "#475569"
BORDER    <- "#94A3B8"
GRID_COL  <- "#CBD5E1"

# Paleta divergente de Poder Socioeconómico (IPS Percentil 0–100)
IPS_PAL <- c(
  "#7C2D12", # 0   - Marginación severa / periferia vulnerable
  "#C2410C", # 18  - Terracota profundo
  "#FB923C", # 35  - Ocre cálido
  "#E2E8F0", # 50  - Mediana urbana nacional (piedra neutra)
  "#38BDF8", # 68  - Azul cielo medio-alto
  "#0284C7", # 84  - Azul cobalto alto
  "#1E3A8A"  # 100 - Índigo real (polos de poder económico)
)

VERDICT_COLS <- c(
  "Confirma: Poniente / SW" = "#1D4ED8",
  "Excepción: Norte / NE"   = "#059669",
  "Inversión: Oriente / SE" = "#C2410C",
  "Mixto / Transicional"    = "#7C3AED"
)

# Función auxiliar para crear círculo en coord_fixed
make_circle <- function(r, n = 180) {
  ang <- seq(0, 2 * pi, length.out = n)
  tibble(x = r * sin(ang), y = r * cos(ang))
}

# ==============================================================================
# PANEL A1: Mapa Protagonista del Valle de México (Zócalo ±30 km)
# ==============================================================================
msg("Construyendo Panel A: Valle de México (Mapa, Rosa Polar y Transecto W->E)...")

zmvm_c   <- centers_df |> filter(metro_id == "zmvm")
zmvm_sum <- city_summary |> filter(metro_id == "zmvm")
zmvm_ageb <- ageb_metros |> filter(metro_id == "zmvm", valid_ips)
zmvm_mun  <- mun_metros  |> filter(metro_id == "zmvm")

cx0 <- zmvm_c$cx_m[1]
cy0 <- zmvm_c$cy_m[1]
xlim_zm <- c(cx0 - 28000, cx0 + 32000)
ylim_zm <- c(cy0 - 26000, cy0 + 34000)

# Vector resultante en metros para flecha sobre el mapa (longitud visual 20 km)
vec_rad_zm <- zmvm_sum$vec_azimut * pi / 180
arr_zm_x   <- cx0 + 19500 * sin(vec_rad_zm)
arr_zm_y   <- cy0 + 19500 * cos(vec_rad_zm)

# Anotaciones urbanas clave del Valle de México
zm_labels <- tibble::tribble(
  ~dx_km, ~dy_km, ~label, ~col,
  -17.5,  -8.2,  "Santa Fe / Bosques\n(Poniente · Polo élite)", "#1E3A8A",
  -11.5,   4.8,  "Polanco / Lomas", "#1E3A8A",
   -3.8, -11.5,  "Benito Juárez /\nPedregal (Sur)", "#1E3A8A",
   15.5,  -8.2,  "Iztapalapa / Neza /\nChimalhuacán (Oriente)", "#7C2D12",
   13.5,  17.0,  "Ecatepec /\nCoacalco (NE)", "#7C2D12"
) |>
  mutate(x = cx0 + dx_km * 1000, y = cy0 + dy_km * 1000)

pA_map <- ggplot() +
  geom_sf(data = zmvm_mun, fill = STONE, color = GRID_COL, linewidth = 0.25) +
  geom_sf(data = zmvm_ageb, aes(fill = IPS_pct), color = NA) +
  geom_sf(data = zmvm_mun, fill = NA, color = alpha(SLATE, 0.35), linewidth = 0.24) +
  # Cruz cardinal sobre el Zócalo
  geom_vline(xintercept = cx0, linetype = "dashed", color = alpha(INK, 0.55), linewidth = 0.42) +
  geom_hline(yintercept = cy0, linetype = "dashed", color = alpha(INK, 0.55), linewidth = 0.42) +
  # Vector resultante de poder socioeconómico
  annotate(
    "segment", x = cx0, y = cy0, xend = arr_zm_x, yend = arr_zm_y,
    color = "#FACC15", linewidth = 2.0,
    arrow = arrow(length = unit(0.28, "cm"), type = "closed")
  ) +
  annotate(
    "segment", x = cx0, y = cy0, xend = arr_zm_x, yend = arr_zm_y,
    color = "#1E3A8A", linewidth = 1.05,
    arrow = arrow(length = unit(0.25, "cm"), type = "closed")
  ) +
  # Zócalo
  annotate("point", x = cx0, y = cy0, shape = 21, size = 3.6, fill = "#FACC15", color = INK, stroke = 0.8) +
  # Etiquetas cardinales en los bordes
  annotate("label", x = cx0, y = ylim_zm[2] - 1800, label = "N",
           size = 2.4, fontface = "bold", fill = alpha(PANEL, 0.90), color = INK, label.size = 0.2) +
  annotate("label", x = cx0, y = ylim_zm[1] + 1800, label = "S",
           size = 2.4, fontface = "bold", fill = alpha(PANEL, 0.90), color = INK, label.size = 0.2) +
  annotate("label", x = xlim_zm[1] + 5200, y = cy0, label = "W · PONIENTE",
           size = 2.15, fontface = "bold", fill = "#DBEAFE", color = "#1E3A8A", label.size = 0.25) +
  annotate("label", x = xlim_zm[2] - 4800, y = cy0, label = "E · ORIENTE",
           size = 2.15, fontface = "bold", fill = "#FFEDD5", color = "#9A3412", label.size = 0.25) +
  # Etiquetas de polos urbanos
  geom_label(
    data = zm_labels,
    aes(x = x, y = y, label = label, color = col),
    fill = alpha(PANEL, 0.92), size = 2.05, fontface = "bold",
    lineheight = 0.95, label.size = 0.22, label.padding = unit(0.18, "lines"),
    show.legend = FALSE
  ) +
  scale_color_identity() +
  scale_fill_gradientn(colours = IPS_PAL, limits = c(0, 100), guide = "none") +
  coord_sf(crs = 6372, xlim = xlim_zm, ylim = ylim_zm, expand = FALSE) +
  labs(
    title = "A. Valle de México: Fractura Poniente–Oriente",
    subtitle = sprintf(
      "20.5M hab. · 5,352 AGEB | Vector: %s (%.0f°, R=%.2f) | ΔW–E: +%.1f pts (+%.2f años escolaridad)",
      zmvm_sum$vec_octant, zmvm_sum$vec_azimut, zmvm_sum$segregacion_R,
      zmvm_sum$gap_we_pct, zmvm_sum$gap_we_graproes
    )
  ) +
  theme_map2026(base_size = 9.5) +
  theme(
    panel.background = element_rect(fill = OCEAN, color = BORDER, linewidth = 0.6),
    plot.title.position = "plot",
    plot.title = element_text(size = 11.0, face = "bold", margin = margin(t = 2, b = 2)),
    plot.subtitle = element_text(size = 7.4, color = SLATE, margin = margin(b = 4)),
    plot.margin = margin(4, 5, 4, 6)
  )

# ==============================================================================
# PANEL A2: Rosa de los Vientos Socioeconómica del Valle de México
# ==============================================================================
zmvm_oct <- octant_summary |> filter(metro_id == "zmvm")

pA_rose <- ggplot(zmvm_oct, aes(x = azimut_oct, y = ips_pct_mean, fill = ips_pct_mean)) +
  geom_hline(yintercept = c(25, 50, 75), color = GRID_COL, linetype = "dashed", linewidth = 0.3) +
  geom_col(width = 41, color = INK, linewidth = 0.25, alpha = 0.92) +
  geom_text(
    aes(y = ips_pct_mean + 7.5, label = sprintf("%.0f", ips_pct_mean)),
    size = 2.25, fontface = "bold", color = INK
  ) +
  # Flecha del vector resultante en la rosa
  annotate(
    "segment", x = zmvm_sum$vec_azimut, y = 0, xend = zmvm_sum$vec_azimut, yend = 66,
    color = "#FACC15", linewidth = 1.6,
    arrow = arrow(length = unit(0.20, "cm"), type = "closed")
  ) +
  annotate(
    "segment", x = zmvm_sum$vec_azimut, y = 0, xend = zmvm_sum$vec_azimut, yend = 66,
    color = "#1E3A8A", linewidth = 0.85,
    arrow = arrow(length = unit(0.18, "cm"), type = "closed")
  ) +
  scale_fill_gradientn(colours = IPS_PAL, limits = c(0, 100), guide = "none") +
  scale_x_continuous(
    limits = c(-22.5, 337.5),
    breaks = seq(0, 315, by = 45),
    labels = c("N", "NE", "E", "SE", "S", "SW", "W", "NW")
  ) +
  scale_y_continuous(limits = c(0, 78)) +
  coord_polar(theta = "x", start = -22.5 * pi / 180) +
  labs(
    title = "Rosa Cardinal del Poder (ZMVM)",
    subtitle = "IPS medio por octante (0–100)"
  ) +
  theme_minimal(base_size = 8.5) +
  theme(
    plot.background  = element_rect(fill = PANEL, color = BORDER, linewidth = 0.45),
    panel.background = element_rect(fill = PANEL, color = NA),
    panel.grid.major.x = element_line(color = alpha(BORDER, 0.35), linewidth = 0.25),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    axis.title = element_blank(),
    axis.text.y = element_blank(),
    axis.text.x = element_text(size = 7.4, face = "bold", color = INK),
    plot.title = element_text(size = 9.0, face = "bold", color = INK, hjust = 0.5, margin = margin(t = 4, b = 1)),
    plot.subtitle = element_text(size = 6.9, color = MUTED, hjust = 0.5, margin = margin(b = 2)),
    plot.margin = margin(4, 4, 2, 4)
  )

# ==============================================================================
# PANEL A3: Perfil Longitudinal Oeste -> Este (Transecto ±30 km del Zócalo)
# ==============================================================================
pA_prof <- ggplot(profile_we_zmvm, aes(x = bin_x, y = ips_pct_w)) +
  annotate("rect", xmin = -Inf, xmax = 0, ymin = -Inf, ymax = Inf, fill = "#DBEAFE", alpha = 0.40) +
  annotate("rect", xmin = 0, xmax = Inf, ymin = -Inf, ymax = Inf, fill = "#FFEDD5", alpha = 0.45) +
  geom_vline(xintercept = 0, linetype = "dashed", color = INK, linewidth = 0.4) +
  geom_hline(yintercept = 50, linetype = "dotted", color = MUTED, linewidth = 0.35) +
  geom_area(fill = "#0284C7", alpha = 0.18) +
  geom_line(color = INK, linewidth = 0.85) +
  geom_point(aes(fill = ips_pct_w), shape = 21, size = 2.3, color = INK, stroke = 0.35) +
  annotate("text", x = -15, y = 76, label = "PONIENTE\n(Santa Fe / Lomas)",
           size = 2.05, fontface = "bold", color = "#1E3A8A", lineheight = 0.95) +
  annotate("text", x = 15, y = 76, label = "ORIENTE\n(Iztapalapa / Neza)",
           size = 2.05, fontface = "bold", color = "#9A3412", lineheight = 0.95) +
  annotate("text", x = 0.8, y = 21, label = "Zócalo\n(0 km)",
           size = 1.9, hjust = 0, fontface = "bold", color = SLATE, lineheight = 0.9) +
  scale_fill_gradientn(colours = IPS_PAL, limits = c(0, 100), guide = "none") +
  scale_x_continuous(breaks = seq(-24, 24, by = 12), labels = function(x) paste0(x, " km")) +
  scale_y_continuous(limits = c(15, 86), breaks = c(25, 50, 75)) +
  labs(
    title = "Perfil Longitudinal Oeste → Este",
    subtitle = "IPS medio en banda ±18 km sobre el Zócalo",
    x = NULL, y = "IPS (0–100)"
  ) +
  theme_minimal(base_size = 8.2) +
  theme(
    plot.background = element_rect(fill = PANEL, color = BORDER, linewidth = 0.45),
    panel.background = element_rect(fill = PANEL, color = NA),
    panel.grid.major = element_line(color = "#E7E1D2", linewidth = 0.22),
    panel.grid.minor = element_blank(),
    axis.text = element_text(size = 6.7, color = SLATE),
    axis.title.y = element_text(size = 7.0, face = "bold", color = INK),
    plot.title = element_text(size = 8.8, face = "bold", color = INK, hjust = 0.5, margin = margin(t = 4, b = 1)),
    plot.subtitle = element_text(size = 6.7, color = MUTED, hjust = 0.5, margin = margin(b = 2)),
    plot.margin = margin(3, 6, 4, 4)
  )

pA_full <- pA_map + (pA_rose / pA_prof + plot_layout(heights = c(1.12, 1.0))) +
  plot_layout(widths = c(1.62, 1.0))

# ==============================================================================
# PANEL B: Brújula Nacional Comparativa de los Polos de Poder (11 Metrópolis)
# ==============================================================================
msg("Construyendo Panel B: Brújula Nacional de las 11 Metrópolis...")

compass_df <- city_summary |>
  mutate(
    rad = vec_azimut * pi / 180,
    vx_plot = segregacion_R * sin(rad),
    vy_plot = segregacion_R * cos(rad),
    short_name = case_when(
      metro_id == "zmvm" ~ "Valle de México",
      metro_id == "pue"  ~ "Puebla–Tlax.",
      metro_id == "slp"  ~ "San Luis Potosí",
      metro_id == "jrz"  ~ "Cd. Juárez",
      TRUE               ~ metro_nombre
    )
  )

# Posiciones limpias de etiquetas para evitar colisiones alrededor del origen y entre sí
lbl_offsets <- tibble::tribble(
  ~metro_id, ~lx,    ~ly,
  "mer",      0.20,   0.485,
  "leo",      0.28,   0.235,
  "jrz",      0.41,   0.045,
  "tol",      0.29,  -0.320,
  "pue",     -0.27,  -0.345,
  "qro",     -0.06,  -0.280,
  "slp",     -0.35,  -0.175,
  "zmvm",    -0.42,  -0.065,
  "gdl",     -0.37,   0.285,
  "tij",     -0.21,   0.185,
  "mty",      0.19,  -0.115
)

compass_df <- compass_df |> left_join(lbl_offsets, by = "metro_id")

ring_15 <- make_circle(0.15)
ring_30 <- make_circle(0.30)
ring_45 <- make_circle(0.45)

spokes <- tibble(ang = seq(0, 315, by = 45)) |>
  mutate(
    xend = 0.48 * sin(ang * pi / 180),
    yend = 0.48 * cos(ang * pi / 180),
    lbl  = c("N (0°)", "NE", "E\nOriente", "SE", "S (180°)", "SW", "W\nPoniente", "NW"),
    lx   = 0.555 * sin(ang * pi / 180),
    ly   = 0.555 * cos(ang * pi / 180)
  )

pB <- ggplot() +
  # Semicírculo Poniente vs Oriente sutil en el fondo
  annotate("rect", xmin = -0.60, xmax = 0, ymin = -0.58, ymax = 0.58, fill = "#EFF6FF", alpha = 0.55) +
  annotate("rect", xmin = 0, xmax = 0.60, ymin = -0.58, ymax = 0.58, fill = "#FFF7ED", alpha = 0.55) +
  geom_path(data = ring_15, aes(x = x, y = y), color = GRID_COL, linetype = "dotted", linewidth = 0.35) +
  geom_path(data = ring_30, aes(x = x, y = y), color = GRID_COL, linetype = "dashed", linewidth = 0.40) +
  geom_path(data = ring_45, aes(x = x, y = y), color = BORDER,   linetype = "solid",  linewidth = 0.45) +
  geom_segment(data = spokes, aes(x = 0, y = 0, xend = xend, yend = yend),
               color = alpha(BORDER, 0.55), linewidth = 0.3) +
  # Etiquetas de intensidad de segregación R
  annotate("text", x = 0.015, y = 0.162, label = "R=0.15", size = 1.9, color = MUTED, hjust = 0) +
  annotate("text", x = 0.015, y = 0.312, label = "R=0.30", size = 1.9, color = MUTED, hjust = 0) +
  annotate("text", x = 0.015, y = 0.462, label = "R=0.45", size = 1.9, color = MUTED, hjust = 0) +
  # Ejes cardinales externos
  geom_text(data = spokes, aes(x = lx, y = ly, label = lbl),
            size = 2.35, fontface = "bold", color = SLATE, lineheight = 0.9) +
  # Líneas guías hacia etiquetas
  geom_segment(
    data = compass_df,
    aes(x = vx_plot, y = vy_plot, xend = lx, yend = ly, color = regla_poniente),
    linetype = "dotted", linewidth = 0.35, alpha = 0.75, show.legend = FALSE
  ) +
  # Vectores resultantes desde el origen (0,0)
  geom_segment(
    data = compass_df,
    aes(x = 0, y = 0, xend = vx_plot, yend = vy_plot, color = regla_poniente),
    linewidth = 1.05,
    arrow = arrow(length = unit(0.18, "cm"), type = "closed")
  ) +
  geom_point(
    data = compass_df,
    aes(x = vx_plot, y = vy_plot, fill = regla_poniente, size = pob_total),
    shape = 21, color = INK, stroke = 0.45
  ) +
  geom_label(
    data = compass_df,
    aes(x = lx, y = ly, label = sprintf("%s\n(%s · R=%.2f)", short_name, vec_octant, segregacion_R),
        color = regla_poniente),
    fill = alpha(PANEL, 0.92), size = 1.98, fontface = "bold", lineheight = 0.92,
    label.size = 0.22, label.padding = unit(0.15, "lines"), show.legend = FALSE
  ) +
  annotate("point", x = 0, y = 0, size = 2.2, color = INK) +
  scale_color_manual(values = VERDICT_COLS, name = "Veredicto empírico") +
  scale_fill_manual(values = VERDICT_COLS, name = "Veredicto empírico") +
  scale_size_continuous(range = c(2.4, 5.4), guide = "none") +
  coord_fixed(xlim = c(-0.62, 0.62), ylim = c(-0.59, 0.61), expand = FALSE) +
  labs(
    title = "B. Brújula Nacional del Poder Socioeconómico",
    subtitle = "Dirección azimutal e intensidad de segregación (R) de los polos de élite en 11 metrópolis"
  ) +
  theme_map2026(base_size = 9.5) +
  theme(
    panel.background = element_rect(fill = PANEL, color = BORDER, linewidth = 0.6),
    plot.title = element_text(size = 11.4, face = "bold", margin = margin(t = 2, b = 2)),
    plot.subtitle = element_text(size = 7.5, color = SLATE, margin = margin(b = 4)),
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.text = element_text(size = 6.9, face = "bold", color = INK),
    legend.key.size = unit(0.30, "cm"),
    legend.margin = margin(t = 1, b = 1),
    plot.margin = margin(4, 6, 4, 6)
  ) +
  guides(
    color = guide_legend(nrow = 2, override.aes = list(linewidth = 1.2)),
    fill  = guide_legend(nrow = 2)
  )

# ==============================================================================
# PANEL C: Cuadrícula Comparativa de las 10 Metrópolis Restantes (5 × 2)
# ==============================================================================
msg("Construyendo Panel C: 10 Zonas Metropolitanas con mini-rosa polar...")

# Orden narrativo:
# Fila 1: Polos Poniente/SW y Policéntrico Sierra Madre
# Fila 2: Costa/Frontera y Grandes Excepciones/Inversiones
panel_c_specs <- tibble::tribble(
  ~metro_id, ~idx, ~xmin, ~xmax, ~ymin, ~ymax, ~rose_corner, ~verdict_short, ~gap_mode,
  "gdl", 1L, -25, 25, -25, 25, "NE", "Confirma: NW / Poniente", "WE",
  "pue", 2L, -22, 20, -18, 24, "NE", "Confirma: SW / Poniente", "WE",
  "slp", 3L, -13, 15, -14, 14, "SW", "Confirma: SW / Poniente", "WE",
  "qro", 4L, -15, 18, -15, 18, "SE", "Confirma: Poniente / Sur", "WE",
  "mty", 5L, -28, 28, -28, 28, "SW", "Policéntrica (W + SE)", "WE",
  "tij", 6L, -10, 24, -27,  5, "SE", "Costa W / Muro Norte", "WE",
  "leo", 7L, -12, 18, -16, 14, "NE", "Excepción: Norte / NE", "WE",
  "mer", 8L, -18, 18, -15, 21, "NE", "Excepción: Norte (R=0.47)", "NS",
  "tol", 9L, -15, 20, -12, 18, "NW", "Inversión: SE (Metepec)", "WE",
  "jrz",10L, -11, 19, -23,  5, "NE", "Inversión: Oriente", "WE"
)

build_city_card <- function(spec_row) {
  m_id <- spec_row$metro_id
  c_info <- centers_df |> filter(metro_id == m_id)
  c_sum  <- city_summary |> filter(metro_id == m_id)
  c_oct  <- octant_summary |> filter(metro_id == m_id)
  c_ageb <- ageb_metros |> filter(metro_id == m_id, valid_ips)
  c_mun  <- mun_metros  |> filter(metro_id == m_id)

  cx <- c_info$cx_m[1]
  cy <- c_info$cy_m[1]
  xlim_c <- c(cx + spec_row$xmin * 1000, cx + spec_row$xmax * 1000)
  ylim_c <- c(cy + spec_row$ymin * 1000, cy + spec_row$ymax * 1000)

  # Longitud de flecha proporcional al cuadro (~30% del ancho)
  span_m <- min(diff(xlim_c), diff(ylim_c))
  arr_len_m <- span_m * 0.30
  rad <- c_sum$vec_azimut * pi / 180
  ax <- cx + arr_len_m * sin(rad)
  ay <- cy + arr_len_m * cos(rad)

  v_col <- VERDICT_COLS[[c_sum$regla_poniente]]
  gap_str <- if (spec_row$gap_mode == "NS") {
    sprintf("ΔN–S: %+.1f pts", c_sum$gap_ns_pct)
  } else {
    sprintf("ΔW–E: %+.1f pts", c_sum$gap_we_pct)
  }

  # Mapa principal de la metrópoli
  p_map <- ggplot() +
    geom_sf(data = c_mun, fill = STONE, color = GRID_COL, linewidth = 0.20) +
    geom_sf(data = c_ageb, aes(fill = IPS_pct), color = NA) +
    geom_sf(data = c_mun, fill = NA, color = alpha(SLATE, 0.32), linewidth = 0.20) +
    geom_vline(xintercept = cx, linetype = "dashed", color = alpha(INK, 0.50), linewidth = 0.32) +
    geom_hline(yintercept = cy, linetype = "dashed", color = alpha(INK, 0.50), linewidth = 0.32) +
    annotate(
      "segment", x = cx, y = cy, xend = ax, yend = ay,
      color = "#FACC15", linewidth = 1.65,
      arrow = arrow(length = unit(0.18, "cm"), type = "closed")
    ) +
    annotate(
      "segment", x = cx, y = cy, xend = ax, yend = ay,
      color = v_col, linewidth = 0.85,
      arrow = arrow(length = unit(0.16, "cm"), type = "closed")
    ) +
    annotate("point", x = cx, y = cy, shape = 21, size = 2.2, fill = "#FACC15", color = INK, stroke = 0.6) +
    scale_fill_gradientn(colours = IPS_PAL, limits = c(0, 100), guide = "none") +
    coord_sf(crs = 6372, xlim = xlim_c, ylim = ylim_c, expand = FALSE) +
    labs(
      title = sprintf("%d. %s (%.2fM hab.)", spec_row$idx, c_info$metro_nombre, c_sum$pob_total / 1e6),
      subtitle = sprintf(
        "Polo: %s (%.0f°) · %s | %s",
        c_sum$vec_octant, c_sum$vec_azimut, gap_str, spec_row$verdict_short
      )
    ) +
    theme_map2026(base_size = 8.0) +
    theme(
      panel.background = element_rect(fill = OCEAN, color = BORDER, linewidth = 0.5),
      plot.title.position = "plot",
      plot.title = element_text(size = 8.7, face = "bold", color = INK, margin = margin(t = 2, b = 1)),
      plot.subtitle = element_text(size = 6.3, face = "bold", color = v_col, margin = margin(b = 3)),
      plot.margin = margin(3, 5, 3, 5)
    )

  # Mini-rosa polar de 8 octantes
  p_mini <- ggplot(c_oct, aes(x = azimut_oct, y = ips_pct_mean, fill = ips_pct_mean)) +
    geom_col(width = 41, color = INK, linewidth = 0.16, alpha = 0.92) +
    scale_fill_gradientn(colours = IPS_PAL, limits = c(0, 100), guide = "none") +
    scale_x_continuous(
      limits = c(-22.5, 337.5),
      breaks = c(0, 90, 180, 270),
      labels = c("N", "E", "S", "W")
    ) +
    scale_y_continuous(limits = c(0, 92)) +
    coord_polar(theta = "x", start = -22.5 * pi / 180) +
    theme_void() +
    theme(
      plot.background  = element_rect(fill = alpha(PANEL, 0.88), color = BORDER, linewidth = 0.35),
      panel.background = element_rect(fill = NA, color = NA),
      axis.text.x = element_text(size = 5.0, face = "bold", color = INK, margin = margin(0,0,0,0)),
      plot.margin = margin(1, 1, 1, 1)
    )

  # Coordenadas normalizadas de la mini-rosa según la esquina más despejada
  pos <- switch(
    spec_row$rose_corner,
    "NE" = list(l = 0.65, b = 0.62, r = 0.98, t = 0.98),
    "NW" = list(l = 0.02, b = 0.62, r = 0.35, t = 0.98),
    "SE" = list(l = 0.65, b = 0.02, r = 0.98, t = 0.38),
    "SW" = list(l = 0.02, b = 0.02, r = 0.35, t = 0.38)
  )

  p_map + inset_element(p_mini, left = pos$l, bottom = pos$b, right = pos$r, top = pos$t, align_to = "panel")
}

cards <- lapply(seq_len(nrow(panel_c_specs)), function(i) build_city_card(panel_c_specs[i, ]))

pC_grid <- (cards[[1]] | cards[[2]] | cards[[3]] | cards[[4]] | cards[[5]]) /
           (cards[[6]] | cards[[7]] | cards[[8]] | cards[[9]] | cards[[10]])

# ==============================================================================
# BARRA DE LEYENDA COMPARTIDA (IPS 0–100)
# ==============================================================================
legend_df <- tibble(x = seq(0, 100, length.out = 200), y = 1)
p_legend <- ggplot(legend_df, aes(x = x, y = y, fill = x)) +
  geom_tile(height = 0.55) +
  annotate("rect", xmin = 0, xmax = 100, ymin = 0.725, ymax = 1.275, fill = NA, color = INK, linewidth = 0.35) +
  scale_fill_gradientn(colours = IPS_PAL, limits = c(0, 100), guide = "none") +
  scale_x_continuous(
    breaks = c(5, 25, 50, 75, 95),
    labels = c(
      "0–10 · Periferias vulnerables\n(menor escolaridad y activos)",
      "25 · Medio-bajo",
      "50 · Mediana urbana\nnacional",
      "75 · Medio-alto",
      "90–100 · Polos de poder\n(élites metropolitanas)"
    ),
    expand = c(0.01, 0.01)
  ) +
  annotate("text", x = 50, y = 1.62,
           label = sprintf("ÍNDICE DE PODER SOCIOECONÓMICO (IPS · PERCENTIL 0–100) — PCA 1er Componente (%.1f%% var. explicada; r = %.2f vs. CONAPO IMN 2020)",
                           100 * pca_var_exp, 0.84),
           size = 2.65, fontface = "bold", color = INK) +
  coord_cartesian(ylim = c(0.65, 1.95), clip = "off") +
  theme_void() +
  theme(
    plot.background = element_rect(fill = CREAM, color = NA),
    axis.text.x = element_text(size = 7.0, face = "bold", color = SLATE, lineheight = 0.95, margin = margin(t = 2)),
    plot.margin = margin(2, 95, 4, 95)
  )

# ==============================================================================
# ENSAMBLAJE FINAL DEL PÓSTER (18.0 × 13.8 in)
# ==============================================================================
msg("Ensamblando póster final...")

top_row <- (pA_full | pB) + plot_layout(widths = c(1.68, 1.0))

n_ageb_tot <- sum(ageb_metros$valid_ips, na.rm = TRUE)
pob_tot_m  <- sum(ageb_metros$POBTOT[ageb_metros$valid_ips], na.rm = TRUE) / 1e6

poster <- (top_row / p_legend / pC_grid) +
  plot_layout(heights = c(1.12, 0.14, 1.18)) +
  plot_annotation(
    title = "¿El Poniente siempre es más rico? Geografía cardinal del poder socioeconómico en México",
    subtitle = sprintf(
      paste0(
        "Análisis de %s AGEB urbanas (%.1f millones de habitantes) en las 11 principales Zonas Metropolitanas. ",
        "La hipótesis del «Poniente rico» se confirma en ciudades de piedemonte occidental (CDMX, Guadalajara, Puebla, SLP),\n",
        "pero se rompe por completo en Mérida y León (Norte rico), Toluca (Sureste: Metepec) y se invierte en Ciudad Juárez (Oriente rico: −32.3 pts W–E contra la frontera del Río Bravo)."
      ),
      format(n_ageb_tot, big.mark = ","), pob_tot_m
    ),
    caption = paste0(
      "#30DayMapChallenge 2026 | Día 12: Power — Datos: INEGI Censo de Población y Vivienda 2020 (AGEB) & CONAPO Índice de Marginación Urbana | ",
      "Gráfico: Fernando Dorantes Nieto (@FerDoranNie)"
    ),
    theme = theme(
      plot.background = element_rect(fill = CREAM, color = NA),
      plot.title = element_text(size = 18.2, face = "bold", color = INK, hjust = 0.5, margin = margin(t = 8, b = 3)),
      plot.subtitle = element_text(size = 9.4, color = SLATE, hjust = 0.5, lineheight = 1.20, margin = margin(b = 6)),
      plot.caption = element_text(size = 7.6, color = MUTED, hjust = 0, margin = margin(t = 6, b = 4)),
      plot.margin = margin(8, 10, 6, 10)
    )
  ) &
  theme(plot.background = element_rect(fill = CREAM, color = NA))

dir.create("outputs/high_res", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/gallery",  recursive = TRUE, showWarnings = FALSE)

out_hi  <- "outputs/high_res/day12_power_poniente_rico.png"
out_gal <- "outputs/gallery/day12_power_poniente_rico.png"

agg_png(out_hi, width = 18.0, height = 13.8, units = "in", res = 300, background = CREAM)
print(poster)
dev.off()

agg_png(out_gal, width = 18.0, height = 13.8, units = "in", res = 150, background = CREAM)
print(poster)
dev.off()

msg("Exportación finalizada:")
msg(sprintf(" - Alta resolución (300 dpi): %s (%.2f MB)", out_hi,  file.info(out_hi)$size / 1e6))
msg(sprintf(" - Galería README  (150 dpi): %s (%.2f MB)", out_gal, file.info(out_gal)$size / 1e6))
