# ==============================================================================
# Día 05 — Senses: Sight (Póster Cartográfico)
# "Ecología del plumaje: Riqueza cromática e iridiscencia aviar en México"
#
# Requiere: days/day05_senses_sight/day05_data_pipeline.R
#           (genera data/processed/day05_dataset.rds y day05_rasters.tif)
# Salidas:  outputs/high_res/day05_senses_sight_plumaje.png
#           outputs/gallery/day05_senses_sight_plumaje.png
# Autor:    Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(patchwork)
  library(scales)
})

source("utils/theme_map2026.R")

# Paleta editorial base (Regla de Diseño — Estilo Atlas Enmarcado)
CREAM  <- "#F7F4EB"
OCEAN  <- "#DCE6F2"
PANEL  <- "#FBF9F3"
INK    <- "#0F172A"
SLATE  <- "#334155"
MUTED  <- "#475569"
BORDER <- "#94A3B8"
DEEP   <- "#162235"

# Colores distintivos de los 4 gremios biofísicos del plumaje
GUILD_COLS <- c(
  "Iridiscente y UV"                   = "#00A896",
  "Azul estructural y psitacofulvinas" = "#2563EB",
  "Carotenoides (rojo/amarillo)"       = "#E11D48",
  "Melaninas (críptico/terrestre)"     = "#8B6F4E"
)

ds <- readRDS("data/processed/day05_dataset.rds")
rast_df    <- ds$rast_df
mx_states  <- ds$mx_states
mx_border  <- ds$mx_border
grid_sf    <- ds$grid_sf
mx_species <- ds$mx_species
curves_df  <- ds$spectral_curves

# Total de registros terrestres y especies terrestres evaluadas
terr_sp <- mx_species |> filter(is_terrestrial)
n_terr_sp  <- nrow(terr_sp)
n_terr_rec <- sum(terr_sp$n_records_mx, na.rm = TRUE)

# ==============================================================================
# PANEL A: Mapa Ráster Principal (`terra` 0.08°) — Índice de Riqueza Cromática
#          e Iridiscencia Aviar (ICRI) en México
# ==============================================================================

hotspots_pts <- tibble::tribble(
  ~id, ~lon,    ~lat,   ~titulo,                              ~detalle,
  1L,  -91.1,   16.35,  "1. Selva Lacandona y Chimalapas",    "56.9% spp. vívidas · 26.2% estructurales (Quetzal, Guacamaya Roja)",
  2L,  -96.4,   18.45,  "2. Altas Montañas y Los Tuxtlas",    "Récord: 56–66 spp. iridiscentes/celda (colibríes, trogones, momotos)",
  3L,  -99.8,   17.45,  "3. Sierra Madre del Sur (Gro./Oax.)","15.0% del ensamblaje con plumaje iridiscente (Eupherusa, Cyanolyca)",
  4L,  -88.7,   19.20,  "4. Selva Maya e Isla Cozumel",       "23.2% plumaje estructural (Guajolote Ocelado, Esmeralda de Cozumel)",
  5L, -105.8,   24.40,  "5. Cañones Sierra Madre Occidental", "Corredor boreal de iridiscencia: 14.8% (Trogón Orejón, Chara Pinta)",
  6L, -112.8,   30.80,  "6. Gran Desierto de Altar y Mapimí", "Polo melánico: 85–88% spp. crípticas (Regla de Gloger / aridez)"
)

cartela_df <- hotspots_pts |>
  mutate(
    x_pt = -117.0,
    y_pt = seq(20.15, 15.15, length.out = n())
  )

icri_palette <- c(
  "#CBB693", # 0-15: Desierto melánico (arena/ocre)
  "#A3B18A", # 25: Transición semiárida
  "#34A0A4", # 45: Subtropical / meseta
  "#0077B6", # 65: Bosques templados y cañones húmedos
  "#5E3C99", # 82: Vertientes húmedas y bosque mesófilo
  "#B5179E", # 92: Selvas altas perennifolias
  "#F72585"  # 100: Núcleos de máxima iridiscencia y riqueza cromática
)

pA <- ggplot() +
  geom_sf(data = mx_border, fill = "#94A3B8", color = NA, alpha = 0.35) +
  geom_raster(data = rast_df, aes(x = x, y = y, fill = icri), interpolate = TRUE) +
  geom_contour(
    data = rast_df, aes(x = x, y = y, z = icri),
    breaks = c(40, 65, 85), color = alpha("#FFFFFF", 0.38), linewidth = 0.25
  ) +
  geom_sf(data = mx_states, fill = NA, color = alpha("#F8FAFC", 0.42), linewidth = 0.22) +
  geom_sf(data = mx_border, fill = NA, color = DEEP, linewidth = 0.50) +
  geom_hline(yintercept = 23.436, linetype = "dashed", color = alpha(DEEP, 0.45), linewidth = 0.32) +
  annotate("text", x = -87.1, y = 23.82, label = "Trópico de Cáncer (23.4° N)",
           hjust = 1, size = 2.45, color = SLATE, fontface = "italic") +
  geom_point(
    data = hotspots_pts, aes(x = lon, y = lat),
    shape = 21, size = 5.4, fill = "#0F172A", color = "#F8FAFC", stroke = 0.7
  ) +
  geom_text(
    data = hotspots_pts, aes(x = lon, y = lat, label = id),
    color = "#F8FAFC", size = 2.7, fontface = "bold"
  ) +
  annotate(
    "rect", xmin = -117.7, xmax = -103.5, ymin = 14.35, ymax = 21.35,
    fill = alpha(PANEL, 0.94), color = BORDER, linewidth = 0.45
  ) +
  annotate(
    "text", x = -117.3, y = 20.88,
    label = "POLOS ÓPTICOS DE LA AVIFAUNA MEXICANA",
    hjust = 0, size = 2.65, fontface = "bold", color = INK
  ) +
  geom_point(
    data = cartela_df, aes(x = x_pt, y = y_pt),
    shape = 21, size = 4.0, fill = "#0F172A", color = "#F8FAFC", stroke = 0.4
  ) +
  geom_text(
    data = cartela_df, aes(x = x_pt, y = y_pt, label = id),
    color = "#F8FAFC", size = 2.15, fontface = "bold"
  ) +
  geom_text(
    data = cartela_df, aes(x = x_pt + 0.48, y = y_pt + 0.16, label = titulo),
    hjust = 0, size = 2.35, fontface = "bold", color = INK
  ) +
  geom_text(
    data = cartela_df, aes(x = x_pt + 0.48, y = y_pt - 0.20, label = detalle),
    hjust = 0, size = 2.02, color = SLATE
  ) +
  annotate(
    "label", x = -91.8, y = 25.7,
    label = sprintf(
      "Ráster terra (0.08° · 603 celdas GBIF)\n%s spp. terrestres · %s M de registros\nCorrelación latitudinal: r = -0.75",
      comma(n_terr_sp), sprintf("%.1f", n_terr_rec / 1e6)
    ),
    fill = alpha(PANEL, 0.92), color = INK, size = 2.45, fontface = "bold",
    label.size = 0.35, label.padding = unit(0.38, "lines"), lineheight = 1.12
  ) +
  scale_fill_gradientn(
    colours = icri_palette,
    limits = c(0, 100),
    breaks = c(0, 25, 50, 75, 100),
    labels = c("0\n(Melánico/Árido)", "25", "50\n(Transición)", "75", "100\n(Máx. Iridiscencia)"),
    name = "Índice de Riqueza Cromática e Iridiscencia (ICRI, 0–100)"
  ) +
  coord_sf(xlim = c(-118.0, -86.2), ylim = c(14.1, 32.9), expand = FALSE) +
  labs(
    title = "A. Geografía del Esplendor Óptico e Iridiscencia Aviar en México",
    subtitle = paste0(
      "Superficie ráster continua (terra, 0.08°) que integra la proporción de especies con plumaje estructural iridiscente,\n",
      "azul estructural, pigmentos carotenoides y croma espectral medio del ensamblaje (300–700 nm)"
    )
  ) +
  theme_map2026(base_size = 10.5) +
  theme(
    panel.background = element_rect(fill = OCEAN, color = BORDER, linewidth = 0.6),
    plot.title = element_text(size = 14.2, face = "bold", margin = margin(t = 4, b = 3)),
    plot.subtitle = element_text(size = 8.4, color = SLATE, lineheight = 1.15, margin = margin(b = 6)),
    legend.position = "bottom",
    legend.title = element_text(size = 8.4, face = "bold", color = INK),
    legend.text = element_text(size = 7.5, color = SLATE),
    legend.margin = margin(t = 2, b = 2),
    plot.margin = margin(6, 8, 4, 8)
  ) +
  guides(
    fill = guide_colorbar(
      title.position = "top", title.hjust = 0.5,
      barwidth = unit(13, "cm"), barheight = unit(0.38, "cm"),
      frame.colour = DEEP, ticks.colour = DEEP
    )
  )

# ==============================================================================
# PANEL B: Mosaico 2x2 de Rásters `terra` por Gremio Biofísico de Coloración
# ==============================================================================
make_guild_map <- function(var_name, title_txt, sub_txt, pal_cols, brks) {
  df_sub <- rast_df |> select(x, y, val = all_of(var_name))
  ggplot() +
    geom_raster(data = df_sub, aes(x = x, y = y, fill = val), interpolate = TRUE) +
    geom_sf(data = mx_states, fill = NA, color = alpha("#FFFFFF", 0.28), linewidth = 0.12) +
    geom_sf(data = mx_border, fill = NA, color = DEEP, linewidth = 0.32) +
    scale_fill_gradientn(
      colours = pal_cols,
      breaks = brks,
      labels = function(x) paste0(round(x, 0), "%"),
      name = "% del ensamblaje"
    ) +
    coord_sf(xlim = c(-117.8, -86.4), ylim = c(14.2, 32.8), expand = FALSE) +
    labs(title = title_txt, subtitle = sub_txt) +
    theme_map2026(base_size = 8.5) +
    theme(
      panel.background = element_rect(fill = OCEAN, color = BORDER, linewidth = 0.45),
      plot.title = element_text(size = 9.4, face = "bold", color = INK, margin = margin(t = 2, b = 1)),
      plot.subtitle = element_text(size = 6.9, color = SLATE, lineheight = 1.12, margin = margin(b = 3)),
      legend.position = "bottom",
      legend.title = element_blank(),
      legend.text = element_text(size = 6.8, color = SLATE),
      legend.margin = margin(t = 0, b = 1),
      plot.margin = margin(3, 5, 3, 5)
    ) +
    guides(
      fill = guide_colorbar(
        barwidth = unit(4.6, "cm"), barheight = unit(0.24, "cm"),
        frame.colour = DEEP, ticks.colour = DEEP
      )
    )
}

pB1 <- make_guild_map(
  "pct_irid",
  "B1. Iridiscencia estructural y UV",
  "Nanocristales de melanina (Trochilidae, Trogonidae)\nMáx: 16.2% del ensamblaje · Latitud: r = -0.63",
  c("#E2E8F0", "#99D8C9", "#2CA25F", "#006D2C", "#4A1486"),
  c(4, 8, 12, 15)
)

pB2 <- make_guild_map(
  "pct_blue",
  "B2. Azul estructural y psitacofulvinas",
  "Matriz esponjosa β-queratina (Psittacidae, Corvidae)\nMáx: 13.8% del ensamblaje · Latitud: r = -0.64",
  c("#E2E8F0", "#9ECAE1", "#3182BD", "#08519C", "#08306B"),
  c(2, 5, 8, 12)
)

pB3 <- make_guild_map(
  "pct_carot",
  "B3. Pigmentación por carotenoides",
  "Cetocarotenoides y xantofilas (Thraupidae, Cardinalidae)\nMáx: 41.9% del ensamblaje · Latitud: r = -0.35",
  c("#F1EEF6", "#FDBB84", "#EF6548", "#D7301F", "#7F0000"),
  c(18, 23, 28, 34)
)

pB4 <- make_guild_map(
  "pct_melan",
  "B4. Dominancia melánica (Regla de Gloger)",
  "Eumelanina y feomelanina (Mimidae, Passerellidae)\nMáx: 88.0% del ensamblaje · Latitud: r = +0.68",
  c("#F7F4EB", "#D8C3A5", "#B08968", "#7F5539", "#3D2314"),
  c(48, 58, 68, 80)
)

pB_grid <- (pB1 | pB2) / (pB3 | pB4)

# ==============================================================================
# PANEL C: Física del Plumaje y Visión Tetracromática Aviar (300–700 nm)
# ==============================================================================

spec_bar <- tibble(
  xmin = seq(300, 695, by = 5),
  xmax = seq(305, 700, by = 5)
) |>
  mutate(
    wl = (xmin + xmax) / 2,
    hex = case_when(
      wl < 380 ~ "#6D28D9",
      wl < 435 ~ "#4F46E5",
      wl < 485 ~ "#0284C7",
      wl < 515 ~ "#0D9488",
      wl < 560 ~ "#16A34A",
      wl < 585 ~ "#EAB308",
      wl < 620 ~ "#EA580C",
      TRUE     ~ "#DC2626"
    )
  )

cones_df <- tibble::tribble(
  ~wl,  ~label,                    ~col,
  370,  "Cono UV/V · SWS1 (370 nm)", "#6D28D9",
  445,  "Cono Azul · SWS2 (445 nm)", "#1D4ED8",
  508,  "Cono Verde · MWS (508 nm)", "#047857",
  565,  "Cono Rojo · LWS (565 nm)",  "#B91C1C"
)

curve_labels <- tibble::tribble(
  ~guild,                                ~x,  ~y,    ~label,
  "Carotenoides (rojo/amarillo)",        634, 26.8,  "Carotenoides (n = 4,061)\nEscalón rojo-naranja (550–700 nm)",
  "Azul estructural y psitacofulvinas",  428, 22.2,  "Azul estructural / psitacofulvinas (n = 1,595)\nPico UV-azul por dispersión coherente",
  "Iridiscente y UV",                    575, 20.6,  "Iridiscente y UV (n = 295)\nInterferencia en melanosomas",
  "Melaninas (críptico/terrestre)",      625, 11.2,  "Melaninas (n = 7,416) · Absorción acromática (<10%)"
)

pC <- ggplot(curves_df, aes(x = wavelength)) +
  # Banda sombreada del canal Ultravioleta (300–400 nm)
  annotate(
    "rect", xmin = 300, xmax = 400, ymin = 0, ymax = 36,
    fill = "#EDE9FE", alpha = 0.78
  ) +
  annotate(
    "text", x = 334, y = 31.8,
    label = "CANAL UV\n(300–400 nm)\nVisión aviar\n(Invisible al\nhumano)",
    size = 2.2, fontface = "bold", color = "#5B21B6", lineheight = 1.05
  ) +
  geom_vline(xintercept = 400, linetype = "dashed", color = "#7C3AED", linewidth = 0.4) +
  # Marcas de los 4 conos retinianos aviares leyendo hacia abajo desde el borde superior
  geom_vline(data = cones_df, aes(xintercept = wl), linetype = "dotted",
             color = cones_df$col, linewidth = 0.38, alpha = 0.80) +
  geom_text(
    data = cones_df, aes(x = wl + 4.5, y = 35.4, label = label),
    color = cones_df$col, size = 2.05, hjust = 1, angle = 90, fontface = "bold.italic"
  ) +
  # Bandas intercuartílicas (Q25–Q75) y curvas medianas de reflectancia
  geom_ribbon(
    aes(ymin = r_q25, ymax = r_q75, fill = guild),
    alpha = 0.16, color = NA
  ) +
  geom_line(aes(y = r_median, color = guild), linewidth = 1.05) +
  # Barra cromática inferior del espectro 300-700 nm
  geom_rect(
    data = spec_bar,
    aes(xmin = xmin, xmax = xmax, ymin = -1.8, ymax = -0.3),
    fill = spec_bar$hex, inherit.aes = FALSE
  ) +
  # Etiquetas directas de cada curva
  geom_text(
    data = curve_labels,
    aes(x = x, y = y, label = label, color = guild),
    size = 2.30, fontface = "bold", lineheight = 1.05, show.legend = FALSE
  ) +
  scale_color_manual(values = GUILD_COLS, name = "Gremio biofísico") +
  scale_fill_manual(values = GUILD_COLS, guide = "none") +
  scale_x_continuous(
    breaks = seq(300, 700, by = 50),
    labels = function(x) paste0(x, " nm"),
    limits = c(300, 700), expand = c(0.01, 0.01)
  ) +
  scale_y_continuous(
    breaks = seq(0, 35, by = 5),
    labels = function(x) paste0(x, "%"),
    limits = c(-2.0, 36.5), expand = c(0, 0)
  ) +
  labs(
    title = "C. Física de la Visión Aviar: Reflectancia Espectral (300–700 nm)",
    subtitle = "Mediana e IQR de 13,367 espectros clasificados (de 31,650 en BirdColorBase) y sensibilidad de los 4 conos retinianos",
    x = "Longitud de onda (λ, nanómetros: Ultravioleta 300–400 nm y Visible 400–700 nm)",
    y = "Reflectancia espectral (%)"
  ) +
  theme_map2026(base_size = 9.5) +
  theme(
    panel.background = element_rect(fill = PANEL, color = BORDER, linewidth = 0.5),
    legend.position = "none",
    plot.title = element_text(size = 12.2, face = "bold", margin = margin(t = 4, b = 2)),
    plot.subtitle = element_text(size = 7.7, color = SLATE, margin = margin(b = 6)),
    axis.text = element_text(size = 7.5, color = SLATE),
    axis.title.x = element_text(size = 8.1, face = "bold", color = INK, margin = margin(t = 5)),
    axis.title.y = element_text(size = 8.1, face = "bold", color = INK, angle = 90, margin = margin(r = 6)),
    panel.grid.major = element_line(color = "#E7E1D2", linewidth = 0.25),
    plot.margin = margin(6, 10, 6, 8)
  )

# ==============================================================================
# PANEL D: El Espectro Latitudinal de México (14.5° N a 32.5° N)
# ==============================================================================

lat_profile <- grid_sf |>
  st_drop_geometry() |>
  filter(!is.na(icri), n_sp_total >= 15) |>
  mutate(lat_band = round(lat * 1.25) / 1.25) |>
  group_by(lat_band) |>
  summarise(
    n_cells = n(),
    Iridiscente  = mean(pct_irid, na.rm = TRUE),
    Azul         = mean(pct_blue, na.rm = TRUE),
    Carotenoides = mean(pct_carot, na.rm = TRUE),
    Melaninas    = mean(pct_melan, na.rm = TRUE),
    vivid_tot    = mean(pct_vivid_total, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    s = Iridiscente + Azul + Carotenoides + Melaninas,
    `Iridiscente y UV`                   = 100 * Iridiscente / s,
    `Azul estructural y psitacofulvinas` = 100 * Azul / s,
    `Carotenoides (rojo/amarillo)`       = 100 * Carotenoides / s,
    `Melaninas (críptico/terrestre)`     = 100 * Melaninas / s
  ) |>
  select(lat_band, `Iridiscente y UV`, `Azul estructural y psitacofulvinas`,
         `Carotenoides (rojo/amarillo)`, `Melaninas (críptico/terrestre)`, vivid_tot) |>
  pivot_longer(
    cols = c("Iridiscente y UV", "Azul estructural y psitacofulvinas",
             "Carotenoides (rojo/amarillo)", "Melaninas (críptico/terrestre)"),
    names_to = "guild", values_to = "pct"
  ) |>
  mutate(
    guild = factor(guild, levels = c(
      "Melaninas (críptico/terrestre)",
      "Carotenoides (rojo/amarillo)",
      "Azul estructural y psitacofulvinas",
      "Iridiscente y UV"
    ))
  )

landmarks_lat <- tibble::tribble(
  ~lat,   ~label,
  16.2,   "Selva Lacandona / Istmo (16.2° N)",
  19.4,   "Eje Neovolcánico (19.4° N)",
  23.4,   "Trópico de Cáncer (23.4° N)",
  29.5,   "Desiertos del Norte (29.5° N)"
)

pD <- ggplot(lat_profile, aes(x = lat_band, y = pct, fill = guild)) +
  geom_area(position = "stack", alpha = 0.90, color = "#F8FAFC", linewidth = 0.25) +
  geom_vline(
    data = landmarks_lat, aes(xintercept = lat),
    linetype = "dashed", color = alpha("#0F172A", 0.55), linewidth = 0.35
  ) +
  geom_text(
    data = landmarks_lat, aes(x = lat + 0.22, y = 98, label = label),
    inherit.aes = FALSE, angle = 90, hjust = 1, vjust = 0,
    size = 2.15, fontface = "bold", color = "#F8FAFC"
  ) +
  annotate("text", x = 16.8, y = 6.2,  label = "Iridiscente y UV (12–15% en el sur → 4% en desiertos)",
           color = "#FFFFFF", size = 2.30, fontface = "bold", hjust = 0) +
  annotate("text", x = 16.8, y = 16.8, label = "Azul estructural y psitacofulvinas (9–14% → 2%)",
           color = "#FFFFFF", size = 2.25, fontface = "bold", hjust = 0) +
  annotate("text", x = 16.8, y = 33.5, label = "Pigmentación por Carotenoides (26–30% del ensamblaje)",
           color = "#FFFFFF", size = 2.30, fontface = "bold", hjust = 0) +
  annotate("text", x = 26.4, y = 65.0, label = "Pigmentación por Melaninas\n(47% en selvas húmedas → 78% en desiertos)",
           color = "#FFFFFF", size = 2.45, fontface = "bold", hjust = 0.5, lineheight = 1.08) +
  scale_fill_manual(
    values = GUILD_COLS,
    breaks = c(
      "Iridiscente y UV",
      "Azul estructural y psitacofulvinas",
      "Carotenoides (rojo/amarillo)",
      "Melaninas (críptico/terrestre)"
    ),
    name = "Gremio biofísico del plumaje"
  ) +
  scale_x_continuous(
    breaks = seq(15, 32, by = 2),
    labels = function(x) paste0(x, "° N"),
    expand = c(0, 0)
  ) +
  scale_y_continuous(
    breaks = seq(0, 100, by = 20),
    labels = function(x) paste0(x, "%"),
    expand = c(0, 0)
  ) +
  labs(
    title = "D. El Gradiente Latitudinal (14.5° N → 32.5° N): Trópico vs. Desierto",
    subtitle = paste0(
      "Composición media del ensamblaje aviar por banda latitudinal:\n",
      "las especies vívidas (estructurales + carotenoides) caen de 53% en el sur a 22% en el norte"
    ),
    x = "Latitud Norte (de Chiapas y la Selva Maya hacia Baja California y el Desierto Chihuahuense)",
    y = "Composición del ensamblaje (%)"
  ) +
  theme_map2026(base_size = 9.5) +
  theme(
    panel.background = element_rect(fill = PANEL, color = BORDER, linewidth = 0.5),
    legend.position = "bottom",
    legend.title = element_text(size = 8.0, face = "bold", color = INK),
    legend.text = element_text(size = 7.3, color = SLATE),
    legend.key.size = unit(0.36, "cm"),
    plot.title = element_text(size = 12.2, face = "bold", margin = margin(t = 4, b = 2)),
    plot.subtitle = element_text(size = 7.7, color = SLATE, lineheight = 1.14, margin = margin(b = 6)),
    axis.text = element_text(size = 7.5, color = SLATE),
    axis.title.x = element_text(size = 8.1, face = "bold", color = INK, margin = margin(t = 5)),
    axis.title.y = element_text(size = 8.1, face = "bold", color = INK, angle = 90, margin = margin(r = 6)),
    plot.margin = margin(6, 10, 6, 8)
  ) +
  guides(fill = guide_legend(nrow = 2, byrow = TRUE))

# ==============================================================================
# ENSAMBLAJE DEL PÓSTER CARTOGRÁFICO
# ==============================================================================
col_izq <- pA / pB_grid + plot_layout(heights = c(1.20, 1.02))
col_der <- pC / pD      + plot_layout(heights = c(1.08, 1.14))

poster <- (col_izq | col_der) +
  plot_layout(widths = c(1.48, 1.04)) +
  plot_annotation(
    title = "ECOLOGÍA DEL PLUMAJE: RIQUEZA CROMÁTICA E IRIDISCENCIA AVIAR EN MÉXICO",
    subtitle = paste0(
      "Cómo la visión tetracromática aviar (300–700 nm, incluyendo el canal UV) y los cuatro mecanismos biofísicos de coloración del plumaje\n",
      "se distribuyen desde las selvas húmedas y bosques mesófilos del sur-sureste hasta los desiertos xerófilos del norte"
    ),
    caption = map_caption(
      5, "Senses: Sight",
      paste0(
        "GBIF Occurrence API (15.1 M de registros georreferenciados de 916 especies de aves terrestres en 603 celdas sobre México) y BirdColorBase (31,650 espectros de reflectancia 300–700 nm;\n",
        "Dale et al. 2015, Stoddard & Prum 2011, Maia et al., Eaton et al., Dunning & Endler). Rásters continuos generados con terra (resolución 0.08°)."
      )
    ),
    theme = theme(
      plot.background = element_rect(fill = CREAM, color = NA),
      plot.title = element_text(
        size = 20.5, face = "bold", color = INK, hjust = 0.5,
        margin = margin(t = 10, b = 4)
      ),
      plot.subtitle = element_text(
        size = 10.6, color = SLATE, hjust = 0.5, lineheight = 1.22,
        margin = margin(b = 8)
      ),
      plot.caption = element_text(
        size = 8.0, color = MUTED, hjust = 0, lineheight = 1.25,
        margin = margin(t = 8, b = 8)
      ),
      plot.margin = margin(8, 12, 8, 12)
    )
  ) &
  theme(plot.background = element_rect(fill = CREAM, color = NA))

dir.create("outputs/high_res", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/gallery", recursive = TRUE, showWarnings = FALSE)

out_high    <- "outputs/high_res/day05_senses_sight_plumaje.png"
out_gallery <- "outputs/gallery/day05_senses_sight_plumaje.png"

ggsave(out_high, poster, width = 18.0, height = 13.4, dpi = 300, bg = CREAM)
ggsave(out_gallery, poster, width = 18.0, height = 13.4, dpi = 115, bg = CREAM, limitsize = FALSE)

cat("¡Póster del Día 05 exportado exitosamente!\n")
cat(" - Alta resolución:", out_high, "\n")
cat(" - Galería README: ", out_gallery, "\n")
