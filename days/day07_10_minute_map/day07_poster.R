# ==============================================================================
# Día 07 — 10 minute map (Póster Cartográfico)
# "Los primeros 10 minutos del Cenozoico: El impacto de Chicxulub y el Anillo de Cenotes"
#
# Requiere: days/day07_10_minute_map/day07_data_pipeline.R
#           (genera data/processed/day07_dataset.rds)
# Salidas:  outputs/high_res/day07_10_minute_map_chicxulub_cenotes.png
#           outputs/gallery/day07_10_minute_map_chicxulub_cenotes.png
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

sf_use_s2(FALSE)
source("utils/theme_map2026.R")

# Paleta editorial base (Regla de Diseño — Estilo Atlas Enmarcado)
CREAM  <- "#F7F4EB"
OCEAN  <- "#DCE6F2"
PANEL  <- "#FBF9F3"
SLATE_LAND <- "#1B283B"
SLATE_ALT  <- "#263852"
INK    <- "#0F172A"
SLATE  <- "#334155"
MUTED  <- "#475569"
BORDER <- "#94A3B8"
DEEP   <- "#162235"

# Colores por provincia morfoestructural de cenotes
PROV_COLS <- c(
  "1. Cuenca Interna (<70 km)"        = "#F59E0B",
  "2. Anillo de Cenotes (70–105 km)"  = "#00F5D4",
  "3. Karst de Plataforma e Interior" = "#38BDF8",
  "4. Corredor Holbox–Tulum (Caribe)" = "#F472B6"
)

ds <- readRDS("data/processed/day07_dataset.rds")
mx_states       <- ds$mx_states
yuc_states      <- ds$yuc_states
yuc_union       <- ds$yuc_union
world_ne        <- ds$world_ne
anp_anillo      <- ds$anp_anillo
all_cenotes     <- ds$all_cenotes
rast_df         <- ds$rast_df
crater_rings_sf <- ds$crater_rings_sf
ten_min_sf      <- ds$ten_min_sf
ten_min_poly_sf <- ds$ten_min_poly_sf
chicx_center    <- ds$chicx_center

# ==============================================================================
# PANEL A: Mapa Principal — La Cicatriz de Chicxulub y los 11,878 Cenotes
#          de la Península de Yucatán
# ==============================================================================

# Etiquetas en el sector noreste de los 3 anillos estructurales (libres de la cartela oeste)
ring_labels_df <- tibble::tribble(
  ~lon,    ~lat,   ~txt,                                                ~col,
  -89.18,  21.58,  "Anillo de Pico (r = 42 km · t = 3 min)",            "#FBBF24",
  -88.95,  21.95,  "Anillo de Cenotes / Borde (r = 88 km · t = 8 min)", "#00F5D4",
  -88.35,  22.18,  "Fracturas Exteriores (r = 130 km)",                 "#E2E8F0"
)

# 6 Hitos numerados sobre el mapa
hitos_a <- tibble::tribble(
  ~id, ~lon,     ~lat,    ~titulo,                                ~detalle,
  1L,  -89.520,  21.300,  "1. Epicentro Chicxulub Puerto (t = 0 s)", "Cuenca interna sellada (<70 km): solo 1.9 cenotes/100 km²",
  2L,  -89.588,  20.587,  "2. Cenote Sabak-Ha y Actún Chulul",      "Los más profundos de Yucatán (147 m y 123 m) en la falla (r = 80 km)",
  3L,  -88.878,  20.910,  "3. Cenote Xkolac y Descarga Dzilam",     "Tiro vertical de 121 m de prof. en el brazo oriente del Anillo",
  4L,  -88.202,  20.690,  "4. Enjambre Kárstico de Valladolid",     "Máxima densidad superficial (>45 cenotes/100 km²) y Cenote Ucil (118 m)",
  5L,  -87.391,  20.324,  "5. Sistema Sac Actun / Dos Ojos",        "La cueva inundada más larga del mundo (363 km) y The Pit (119 m)",
  6L,  -87.485,  20.160,  "6. Sistema Ox Bel Ha (Tulum)",           "170 km de galerías sumergidas controladas por la haloclina caribeña"
)

# Cartela numerada en la esquina superior izquierda (Golfo de México)
cartela_a <- hitos_a |>
  mutate(
    x_pt = -92.18,
    y_pt = seq(22.02, 20.26, length.out = n())
  )

pts_df <- all_cenotes |>
  st_drop_geometry() |>
  filter(!is.na(lon), !is.na(lat))

pA <- ggplot() +
  # Países vecinos y resto de México
  geom_sf(data = world_ne, fill = "#CBD5E1", color = "#94A3B8", linewidth = 0.30) +
  geom_sf(data = mx_states, fill = "#263852", color = "#435B7D", linewidth = 0.28) +
  # Península de Yucatán en azul petróleo profundo para alto contraste de los puntos luminosos
  geom_sf(data = yuc_states, fill = SLATE_LAND, color = "#475569", linewidth = 0.42) +
  # Sombra suave de densidad ráster debajo de los puntos
  geom_raster(
    data = rast_df |> filter(dens_100km2 > 2),
    aes(x = x, y = y, alpha = pmin(dens_100km2, 55)),
    fill = "#0EA5E9", interpolate = TRUE, show.legend = FALSE
  ) +
  scale_alpha_continuous(range = c(0.03, 0.28)) +
  # Polígono oficial de la Reserva Estatal Geohidrológica del Anillo de Cenotes
  geom_sf(
    data = anp_anillo,
    fill = alpha("#00F5D4", 0.14), color = "#00F5D4",
    linewidth = 0.65, linetype = "solid"
  ) +
  # Los 11,878 cenotes y cavernas coloreados por provincia morfoestructural
  geom_point(
    data = pts_df,
    aes(x = lon, y = lat, color = provincia),
    size = 0.55, alpha = 0.72, shape = 16
  ) +
  # Destello adicional en los cenotes profundos (>50 m)
  geom_point(
    data = pts_df |> filter(!is.na(depth_m) & depth_m >= 50),
    aes(x = lon, y = lat),
    shape = 21, size = 2.6, fill = "#FEF08A", color = "#CA8A04", stroke = 0.50
  ) +
  # Anillos estructurales concéntricos del cráter de Chicxulub (r = 42, 88 y 130 km)
  geom_sf(
    data = crater_rings_sf |> filter(radius_km == 42),
    color = "#FBBF24", linewidth = 0.75, linetype = "dashed"
  ) +
  geom_sf(
    data = crater_rings_sf |> filter(radius_km == 88),
    color = "#00F5D4", linewidth = 0.95, linetype = "longdash"
  ) +
  geom_sf(
    data = crater_rings_sf |> filter(radius_km == 130),
    color = alpha("#E2E8F0", 0.75), linewidth = 0.55, linetype = "dotted"
  ) +
  # Fronteras estatales encima para referencia limpia
  geom_sf(data = yuc_states, fill = NA, color = alpha("#94A3B8", 0.48), linewidth = 0.35) +
  # Diana del epicentro en Chicxulub Puerto
  annotate(
    "point", x = chicx_center["lon"], y = chicx_center["lat"],
    shape = 21, size = 7.8, fill = alpha("#EF4444", 0.30), color = "#FCA5A5", stroke = 0.9
  ) +
  # Etiquetas de los anillos estructurales en el sector noreste (mar)
  geom_label(
    data = ring_labels_df,
    aes(x = lon, y = lat, label = txt),
    hjust = 0,
    fill = alpha("#0F172A", 0.88), color = ring_labels_df$col,
    size = 2.65, fontface = "bold", label.size = 0.30,
    label.padding = unit(0.22, "lines")
  ) +
  # Puntos numerados (1-6)
  geom_point(
    data = hitos_a, aes(x = lon, y = lat),
    shape = 21, size = 6.0, fill = ifelse(hitos_a$id == 1, "#DC2626", "#0F172A"),
    color = "#F8FAFC", stroke = 0.85
  ) +
  geom_text(
    data = hitos_a, aes(x = lon, y = lat, label = id),
    color = "#F8FAFC", size = 3.05, fontface = "bold"
  ) +
  # Cartela explicativa en el Golfo de México occidental (sin tocar los anillos)
  annotate(
    "rect", xmin = -92.34, xmax = -89.94, ymin = 19.98, ymax = 22.34,
    fill = alpha(PANEL, 0.95), color = BORDER, linewidth = 0.50
  ) +
  annotate(
    "text", x = -92.25, y = 22.21,
    label = "HITOS GEOLÓGICOS Y ESPELEOLÓGICOS",
    hjust = 0, size = 2.85, fontface = "bold", color = INK
  ) +
  geom_point(
    data = cartela_a, aes(x = x_pt, y = y_pt),
    shape = 21, size = 4.5, fill = ifelse(cartela_a$id == 1, "#DC2626", "#0F172A"),
    color = "#F8FAFC", stroke = 0.40
  ) +
  geom_text(
    data = cartela_a, aes(x = x_pt, y = y_pt, label = id),
    color = "#F8FAFC", size = 2.45, fontface = "bold"
  ) +
  geom_text(
    data = cartela_a, aes(x = x_pt + 0.11, y = y_pt + 0.06, label = titulo),
    hjust = 0, size = 2.52, fontface = "bold", color = INK
  ) +
  geom_text(
    data = cartela_a, aes(x = x_pt + 0.11, y = y_pt - 0.08, label = detalle),
    hjust = 0, size = 2.18, color = SLATE
  ) +
  # Caja de síntesis estadística en la esquina inferior izquierda (Bahía de Campeche)
  annotate(
    "label", x = -92.30, y = 19.36, hjust = 0,
    label = paste0(
      "Inventario Integrado: 11,878 cenotes y cuevas\n",
      "• SGM / CINVESTAV (Yucatán): 7,876 cenotes\n",
      "• QRSS / YCS (Península): 4,642 sistemas\n",
      "• Puntos amarillos: cenotes profundos (>50 m a 147 m)\n",
      "• Polígono cian: Reserva Estatal Anillo de Cenotes"
    ),
    fill = alpha(PANEL, 0.94), color = INK, size = 2.55, fontface = "bold",
    label.size = 0.40, label.padding = unit(0.38, "lines"), lineheight = 1.15
  ) +
  scale_color_manual(
    values = PROV_COLS,
    name = "Provincia morfoestructural (distancia al epicentro de Chicxulub)"
  ) +
  coord_sf(xlim = c(-92.42, -86.48), ylim = c(18.85, 22.42), expand = FALSE) +
  labs(
    title = "A. La Cicatriz Gravitacional de Chicxulub y los 11,878 Cenotes de la Península de Yucatán",
    subtitle = paste0(
      "El colapso del cráter en los primeros 10 minutos tras el impacto (hace 66 Ma) creó una cuenca interna sellada (<70 km: 1.9 cenotes/100 km²) rodeada por el sistema\n",
      "de fallas del Anillo de Cenotes (r = 70–105 km: 30.1 cenotes/100 km²), mientras que las fracturas orientales albergan las cavernas sumergidas más largas del planeta"
    )
  ) +
  theme_map2026(base_size = 11) +
  theme(
    panel.background = element_rect(fill = OCEAN, color = BORDER, linewidth = 0.65),
    plot.title = element_text(size = 14.2, face = "bold", hjust = 0.5, margin = margin(t = 4, b = 3)),
    plot.subtitle = element_text(size = 8.9, color = SLATE, hjust = 0.5, lineheight = 1.18, margin = margin(b = 6)),
    legend.position = "bottom",
    legend.title = element_text(size = 8.8, face = "bold", color = INK),
    legend.text = element_text(size = 8.2, color = SLATE),
    legend.margin = margin(t = 2, b = 2),
    plot.margin = margin(4, 6, 4, 6)
  ) +
  guides(
    color = guide_legend(
      title.position = "top", title.hjust = 0.5,
      nrow = 1, byrow = TRUE,
      override.aes = list(size = 3.8, alpha = 1)
    )
  )

# ==============================================================================
# PANEL B: Cronología Espacial de los Primeros 10 Minutos (Escala Mesoamérica
#          y Gran Caribe: t = 10 s a t = 10 min)
# ==============================================================================

ring_cols_b <- c(
  "t = 10 s"   = "#FEF08A",
  "t = 1 min"  = "#FBBF24",
  "t = 2 min"  = "#F97316",
  "t = 5 min"  = "#EF4444",
  "t = 10 min" = "#991B1B"
)

# Etiquetas sobre los arcos de tiempo en Panel B (100% dentro del encuadre)
time_callouts_b <- tibble::tribble(
  ~lon,   ~lat,  ~label,                                                                              ~col,
  -89.52, 19.65, "t = 10 s–1 min (r = 45–100 km)\nCavidad de 30 km, rebote central y falla del Anillo", "#FEF08A",
  -92.80, 23.35, "t = 2 min (r = 420 km)\nOnda S destructiva (3.5 km/s) y megatsunami (>100 m)",      "#FDBA74",
  -99.40, 25.40, "t = 5 min (r = 1,050 km)\nCortina balística de eyección e ignición en Mesoamérica", "#FCA5A5",
  -83.20, 29.85, "t = 10 min (r = 2,100 km)\nCráter final congelado; sismo M~11 y esférulas de Texas a Colombia", "#FECACA"
)

cities_ref_b <- tibble::tribble(
  ~lon,    ~lat,  ~name,
  -99.13,  19.43, "Valle de México\n(onda P: 2.5 min · S: 4.3 min)",
  -82.36,  23.11, "Cuba / Proto-Caribe\n(megatsunami y eyección: 3–5 min)",
  -95.36,  29.76, "Costa del Golfo / Texas\n(frente sísmico y tektitas: 6–8 min)"
)

pB <- ggplot() +
  geom_sf(data = world_ne, fill = SLATE_LAND, color = "#435B7D", linewidth = 0.28) +
  geom_sf(data = mx_states, fill = SLATE_ALT, color = "#435B7D", linewidth = 0.22) +
  # Rellenos concéntricos semitransparentes de mayor a menor radio
  geom_sf(
    data = ten_min_poly_sf |> arrange(desc(r_km)),
    aes(fill = factor(time_label, levels = c("t = 10 s", "t = 1 min", "t = 2 min", "t = 5 min", "t = 10 min"))),
    alpha = 0.16, color = NA
  ) +
  # Contornos concéntricos de propagación
  geom_sf(
    data = ten_min_sf,
    aes(color = factor(time_label, levels = c("t = 10 s", "t = 1 min", "t = 2 min", "t = 5 min", "t = 10 min"))),
    linewidth = 0.90, linetype = "solid"
  ) +
  # Punto de impacto
  annotate(
    "point", x = chicx_center["lon"], y = chicx_center["lat"],
    shape = 21, size = 5.6, fill = "#FEF08A", color = "#DC2626", stroke = 1.1
  ) +
  # Puntos de referencia continental
  geom_point(
    data = cities_ref_b, aes(x = lon, y = lat),
    shape = 21, size = 3.0, fill = "#F8FAFC", color = "#0F172A", stroke = 0.45
  ) +
  geom_text(
    data = cities_ref_b, aes(x = lon, y = lat - 0.90, label = name),
    color = "#E2E8F0", size = 2.55, fontface = "italic", lineheight = 0.98
  ) +
  # Etiquetas de cada frente temporal
  geom_label(
    data = time_callouts_b,
    aes(x = lon, y = lat, label = label),
    fill = alpha("#0F172A", 0.88), color = time_callouts_b$col,
    size = 2.60, fontface = "bold", lineheight = 1.06,
    label.size = 0.30, label.padding = unit(0.25, "lines")
  ) +
  scale_color_manual(
    values = ring_cols_b,
    name = "Frente de expansión en los primeros 10 minutos (600 s)"
  ) +
  scale_fill_manual(
    values = ring_cols_b,
    guide = "none"
  ) +
  # Mismo aspect ratio (1.664) que el Panel A para alineación lateral exacta
  coord_sf(xlim = c(-107.6, -71.9), ylim = c(10.8, 32.25), expand = FALSE) +
  labs(
    title = "B. Los Primeros 10 Minutos del Cenozoico: De la Bola de Fuego al Colapso Cortical (t = 0 a 600 s)",
    subtitle = paste0(
      "Mientras en el centro (r < 100 km) la corteza rebotaba como un fluido para esculpir el Anillo de Cenotes en menos de 600 segundos,\n",
      "las ondas sísmicas (M ~ 11, v = 3.5–6.0 km/s) y la cortina balística de esférulas incandescentes envolvieron todo el Golfo de México y Mesoamérica"
    )
  ) +
  theme_map2026(base_size = 11) +
  theme(
    panel.background = element_rect(fill = "#131C2E", color = BORDER, linewidth = 0.65),
    plot.title = element_text(size = 14.2, face = "bold", hjust = 0.5, margin = margin(t = 6, b = 3)),
    plot.subtitle = element_text(size = 8.9, color = SLATE, hjust = 0.5, lineheight = 1.18, margin = margin(b = 6)),
    legend.position = "bottom",
    legend.title = element_text(size = 8.8, face = "bold", color = INK),
    legend.text = element_text(size = 8.2, color = SLATE),
    legend.margin = margin(t = 2, b = 2),
    plot.margin = margin(4, 6, 4, 6)
  ) +
  guides(
    color = guide_legend(
      title.position = "top", title.hjust = 0.5,
      nrow = 1, override.aes = list(linewidth = 2.4)
    )
  )

# ==============================================================================
# ENSAMBLAJE DEL PÓSTER CARTOGRÁFICO (SOLO PANEL A Y PANEL B)
# ==============================================================================
poster <- (pA / pB) +
  plot_layout(heights = c(1.04, 1.00)) +
  plot_annotation(
    title = "LOS PRIMEROS 10 MINUTOS DEL CENOZOICO: CHICXULUB Y EL ANILLO DE CENOTES",
    subtitle = paste0(
      "En los primeros 600 segundos tras el impacto del asteroide de Chicxulub (hace 66 Ma), el colapso gravitacional de la corteza esculpió un cráter de 180 km\n",
      "cuyo borde enterrado multiplica hoy por 15.8× la densidad de cenotes (de 1.9 a 30.1 por 100 km²) y concentra los tiros verticales más profundos de Yucatán"
    ),
    caption = map_caption(
      7, "10 minute map",
      paste0(
        "Servicio Geológico Mexicano (SGM) y CINVESTAV vía SDS Yucatán (7,876 cenotes); Quintana Roo Speleological Survey (QRSS) y Yucatán Cave Survey (YCS, 4,642 cenotes y cavernas\n",
        "con datos de profundidad y longitud; total integrado sin duplicados: 11,878 registros). Geofísica del impacto: Hildebrand et al. (1991), Collins et al. (2005), Morgan et al. (2016) y Gulick et al. (2019)."
      )
    ),
    theme = theme(
      plot.background = element_rect(fill = CREAM, color = NA),
      plot.title = element_text(
        size = 18.2, face = "bold", color = INK, hjust = 0.5,
        margin = margin(t = 10, b = 4)
      ),
      plot.subtitle = element_text(
        size = 9.8, color = SLATE, hjust = 0.5, lineheight = 1.22,
        margin = margin(b = 6)
      ),
      plot.caption = element_text(
        size = 8.0, color = MUTED, hjust = 0.5, lineheight = 1.25,
        margin = margin(t = 8, b = 6)
      ),
      plot.margin = margin(8, 10, 8, 10)
    )
  ) &
  theme(plot.background = element_rect(fill = CREAM, color = NA))

dir.create("outputs/high_res", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/gallery", recursive = TRUE, showWarnings = FALSE)

out_high    <- "outputs/high_res/day07_10_minute_map_chicxulub_cenotes.png"
out_gallery <- "outputs/gallery/day07_10_minute_map_chicxulub_cenotes.png"

if (file.exists(out_high)) unlink(out_high)
if (file.exists(out_gallery)) unlink(out_gallery)

ggsave(out_high, poster, width = 12.0, height = 15.6, dpi = 300, bg = CREAM, device = grDevices::png)
ggsave(out_gallery, poster, width = 12.0, height = 15.6, dpi = 120, bg = CREAM, limitsize = FALSE, device = grDevices::png)

cat("¡Póster del Día 07 (Paneles A y B) exportado exitosamente!\n")
cat(" - Alta resolución:", out_high, "\n")
cat(" - Galería README: ", out_gallery, "\n")
