# ==============================================================================
# Día 10 — Prompting only: El Bestiario y Herbario Toponímico de México
# Versión de Alto Detalle: Mapa General Ampliado + Desglose Estadístico Inferior
#
# Autor: Fernando Dorantes Nieto (@FerDoranNie)
# Reto: #30DayMapChallenge 2026 — 10 de noviembre de 2026
# Fuente: Catálogo Único de Localidades (AGEEML - INEGI)
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
suppressPackageStartupMessages({
  library(sf)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(patchwork)
  library(scales)
})

sf_use_s2(FALSE)
source("utils/theme_map2026.R")

cat("======================================================================\n")
cat(" [DÍA 10 - VERSIÓN DETALLE] Generando póster ampliado de toponimias...\n")
cat("======================================================================\n\n")

# Paleta editorial base (Estilo Atlas Enmarcado)
CREAM      <- "#F7F4EB"
OCEAN      <- "#DCE6F2"
BORDER     <- "#94A3B8"
SLATE_LAND <- "#1E293B"
SLATE_DIV  <- "#334155"
INK        <- "#0F172A"
SLATE      <- "#334155"
MUTED      <- "#475569"
WHITE      <- "#FFFFFF"

# Paleta temática de los 5 Dominios Ecoculturales
DOM_COLS <- c(
  "Bosque de Montaña (Pino, Ocote, Encino)"              = "#10B981", # Verde esmeralda
  "Desierto y Semidesierto (Mezquite, Nopal, Maguey)"   = "#F59E0B", # Ámbar dorado
  "Selva Tropical y Costa (Ceiba, Cedro, Palma)"        = "#06B6D4", # Turquesa cian
  "Riberas, Sabinos y Frutales Nativos"                 = "#3B82F6", # Azul zafiro
  "Bestiario Silvestre (Coyote, Venado, Jaguar, Águila)" = "#F43F5E"  # Rosa coral vibrante
)

cat("[1/4] Cargando dataset procesado...\n")
ds <- readRDS("data/processed/day10_toponimos_biologicos.rds")
locs_sf    <- ds$localidades_bio
mx_states  <- ds$mx_states
mx_union   <- ds$mx_union
conteos_g  <- ds$conteos_grupo
conteos_d  <- ds$conteos_dominio
tot_cat    <- ds$total_catalogo
tot_bio    <- ds$total_bio

# Límites cartográficos en EPSG:6372 con margen
bbox_mx <- st_bbox(mx_union)
xlims   <- c(bbox_mx["xmin"] - 35000, bbox_mx["xmax"] + 35000)
ylims   <- c(bbox_mx["ymin"] - 35000, bbox_mx["ymax"] + 35000)

# Etiquetas biogeográficas estratégicas con coordenadas EPSG:6372
df_labels <- data.frame(
  x = c(1700000, 2600000, 2350000, 1400000, 3600000, 2500000, 2200000),
  y = c(2100000, 2050000, 2350000, 2450000, 1800000, 1400000, 1150000),
  label = c(
    "SIERRA MADRE OCCIDENTAL\nBosques templados: Pino, Ocote y Encino",
    "SIERRA MADRE ORIENTAL\nTransición serrana y bosque mesófilo",
    "DESIERTO CHIHUAHUENSE\nReino árido: Mezquite, Nopal y Coyote",
    "DESIERTO SONORENSE Y PENÍNSULA\nCardones, Sahuaros y Pitayas",
    "PENÍNSULA DE YUCATÁN\nSelva Maya: Ceiba sagrada (Yaxché) y Tigre",
    "EL BAJÍO Y EJE NEOVOLCÁNICO\nRiberas de Sabinos, Huizaches y Venados",
    "SIERRA MADRE DEL SUR\nSelvas secas, Frutales nativos y Jaguares"
  )
)

# ------------------------------------------------------------------------------
# 2. Panel A: Mapa General Ampliado de México a Gran Detalle
# ------------------------------------------------------------------------------
cat("[2/4] Construyendo Panel Superior: Gran Mapa de México...\n")

p_main <- ggplot() +
  # Fondo continental con división estatal
  geom_sf(data = mx_states, fill = SLATE_LAND, color = SLATE_DIV, linewidth = 0.38) +
  geom_sf(data = mx_union, fill = NA, color = "#64748B", linewidth = 0.85) +
  # Puntos de localidades biológicas (con mayor tamaño para resaltar agrupaciones)
  geom_sf(
    data = locs_sf,
    aes(color = dominio_ecocultural),
    size = 0.80,
    alpha = 0.82,
    shape = 16
  ) +
  # Etiquetas de provincias biogeográficas con cajas enmarcadas
  geom_label(
    data = df_labels,
    aes(x = x, y = y, label = label),
    fill = alpha("#0F172A", 0.85),
    color = "#F8FAFC",
    size = 2.65,
    fontface = "bold",
    lineheight = 0.95,
    label.padding = unit(0.35, "lines"),
    label.r = unit(0.2, "lines"),
    label.size = 0.4
  ) +
  coord_sf(xlim = xlims, ylim = ylims, expand = FALSE) +
  scale_color_manual(values = DOM_COLS, name = "Dominio Ecocultural:") +
  theme_map2026(bg_color = CREAM, panel_color = OCEAN, border_color = BORDER, text_color = INK) +
  theme(
    legend.position = "top",
    legend.direction = "horizontal",
    legend.box = "horizontal",
    legend.title = element_text(size = 10, face = "bold", color = INK),
    legend.text = element_text(size = 8.8, color = SLATE),
    legend.key = element_blank(),
    legend.background = element_rect(fill = alpha(CREAM, 0.95), color = NA),
    plot.margin = margin(2, 6, 4, 6)
  ) +
  guides(color = guide_legend(override.aes = list(size = 4, alpha = 1), nrow = 2))

# ------------------------------------------------------------------------------
# 3. Panel B: Paneles Inferiores de Desglose Estadístico
# ------------------------------------------------------------------------------
cat("[3/4] Construyendo Paneles Inferiores: Barras por Taxón, Top Nombres y Síntesis...\n")

# B1: Gráfico de Barras por Grupo Taxonómico (12 grupos)
df_bars_taxa <- conteos_g |>
  mutate(
    grupo_clean = case_when(
      grupo_id == "selva_tropical"    ~ "Ceiba, Cedro y Palma (Selva)",
      grupo_id == "frutales_nativos"  ~ "Capulín, Tejocote y Zapote (Frutales)",
      grupo_id == "pino_ocote"        ~ "Pino, Ocote y Encino (Bosque)",
      grupo_id == "sabino_sauce"      ~ "Sabino, Sauce y Álamo (Ríos)",
      grupo_id == "mezquite_huizache" ~ "Mezquite y Huizache (Matorral)",
      grupo_id == "aves"              ~ "Águila, Gavilán y Aves (Rapaces)",
      grupo_id == "cactaceas"         ~ "Nopal, Tuna y Maguey (Cactáceas)",
      grupo_id == "fauna_menor"       ~ "Fauna Menor (Conejo, Armadillo)",
      grupo_id == "felinos"           ~ "Jaguar, Tigre y Puma (Felinos)",
      grupo_id == "coyote"            ~ "Coyote (Canis latrans)",
      grupo_id == "venado"            ~ "Venado y Ciervo (Mazatl)",
      grupo_id == "serpientes"        ~ "Víbora y Serpiente (Coatl)"
    ),
    pct_total = round(100 * n_localidades / tot_bio, 1),
    label_bar = sprintf("%s (%s%%)", comma(n_localidades), pct_total)
  )

p_barras_taxa <- ggplot(df_bars_taxa, aes(x = n_localidades, y = reorder(grupo_clean, n_localidades), fill = reino)) +
  geom_col(width = 0.72, alpha = 0.92) +
  geom_text(
    aes(label = label_bar),
    hjust = -0.10,
    size = 2.65,
    fontface = "bold",
    color = SLATE
  ) +
  scale_fill_manual(
    values = c("Fauna" = "#F43F5E", "Flora" = "#10B981"),
    name = "Reino:"
  ) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.28)), labels = comma) +
  labs(
    title = "Toponimia Biológica por Grupo Taxonómico",
    subtitle = "16,667 localidades identificadas en el catálogo AGEEML (INEGI)",
    x = "Número de localidades",
    y = NULL
  ) +
  theme_minimal(base_size = 8.5) +
  theme(
    plot.background = element_rect(fill = CREAM, color = NA),
    panel.background = element_rect(fill = CREAM, color = NA),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = "#CBD5E1", linewidth = 0.3),
    panel.grid.minor = element_blank(),
    axis.text.y = element_text(size = 7.5, color = INK, face = "bold"),
    axis.text.x = element_text(size = 7.0, color = MUTED),
    axis.title.x = element_text(size = 7.5, color = MUTED, margin = margin(t = 4)),
    plot.title = element_text(size = 9.2, face = "bold", color = INK, margin = margin(b = 2)),
    plot.subtitle = element_text(size = 7.2, color = MUTED, margin = margin(b = 5)),
    legend.position = "top",
    legend.direction = "horizontal",
    legend.title = element_text(size = 7.5, face = "bold"),
    legend.text = element_text(size = 7.2),
    plot.margin = margin(3, 5, 3, 5)
  )

# B2: Top 10 de Topónimos Más Repetidos en México
df_top_names <- as.data.frame(st_drop_geometry(locs_sf)) |>
  group_by(NOM_LOC, reino) |>
  summarise(n = n(), .groups = "drop") |>
  arrange(desc(n)) |>
  head(10) |>
  mutate(
    nombre_label = sprintf("%s (%s)", NOM_LOC, reino)
  )

p_top_nombres <- ggplot(df_top_names, aes(x = n, y = reorder(nombre_label, n), fill = reino)) +
  geom_col(width = 0.72, alpha = 0.92) +
  geom_text(
    aes(label = comma(n)),
    hjust = -0.15,
    size = 2.7,
    fontface = "bold",
    color = SLATE
  ) +
  scale_fill_manual(
    values = c("Fauna" = "#F43F5E", "Flora" = "#10B981"),
    guide = "none"
  ) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.25)), labels = comma) +
  labs(
    title = "Top 10 Nombres Más Repetidos",
    subtitle = "Frecuencia exacta del nombre en el territorio",
    x = "Número de pueblos / ejidos",
    y = NULL
  ) +
  theme_minimal(base_size = 8.5) +
  theme(
    plot.background = element_rect(fill = CREAM, color = NA),
    panel.background = element_rect(fill = CREAM, color = NA),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = "#CBD5E1", linewidth = 0.3),
    panel.grid.minor = element_blank(),
    axis.text.y = element_text(size = 7.5, color = INK, face = "bold"),
    axis.text.x = element_text(size = 7.0, color = MUTED),
    axis.title.x = element_text(size = 7.5, color = MUTED, margin = margin(t = 4)),
    plot.title = element_text(size = 9.2, face = "bold", color = INK, margin = margin(b = 2)),
    plot.subtitle = element_text(size = 7.2, color = MUTED, margin = margin(b = 5)),
    plot.margin = margin(3, 5, 3, 5)
  )

# B3: Tarjeta Editorial de Síntesis y Hallazgos
p_card_info <- ggplot() +
  annotate(
    "rect", xmin = 0, xmax = 1, ymin = 0, ymax = 1,
    fill = "#F1EEDB", color = BORDER, linewidth = 0.5
  ) +
  annotate(
    "text", x = 0.05, y = 0.90,
    label = "💡 MEMORIA ECOLÓGICA DEL TERRITORIO",
    hjust = 0, size = 3.5, fontface = "bold", color = INK
  ) +
  annotate(
    "text", x = 0.05, y = 0.48,
    label = paste0(
      "• 296,814 localidades urbanas y rurales analizadas (AGEEML - INEGI).\n",
      "• 16,667 asentamientos (5.6% nacional) preservan memoria biocultural.\n",
      "• 78.1% aluden a flora nativa vs. 21.9% a fauna silvestre.\n",
      "• Concordancia biogeográfica: Los nombres calcan los biomas reales\n",
      "  sin necesidad de satélites: la Sierra Madre del Ocote, el Altiplano\n",
      "  del Nopal, el Matorral del Mezquite y la Selva Maya de la Ceiba.\n",
      "• Reto Prompting only: Clasificador léxico-espacial y cartografía\n",
      "  sintetizados 100% mediante prompts a IA sin edición manual."
    ),
    hjust = 0, size = 2.45, color = SLATE, lineheight = 1.28
  ) +
  xlim(0, 1) + ylim(0, 1) +
  theme_void() +
  theme(plot.margin = margin(3, 4, 3, 4))

# Disposición inferior en 3 columnas
p_bottom <- p_barras_taxa + p_top_nombres + p_card_info +
  plot_layout(widths = c(1.4, 1.0, 1.2))

# ------------------------------------------------------------------------------
# 4. Ensamblado del Póster Detallado y Exportación
# ------------------------------------------------------------------------------
cat("[4/4] Ensamblando y exportando póster versión detalle...\n")

poster_detalle <- (
  p_main /
  p_bottom
) +
  plot_layout(heights = c(2.6, 1.0)) +
  plot_annotation(
    title = "EL BESTIARIO Y HERBARIO TOPONÍMICO DE MÉXICO",
    subtitle = paste0(
      "Distribución de 16,667 pueblos, rancherías y ejidos con nombres de fauna silvestre y flora nativa ",
      "(Catálogo Nacional de Localidades AGEEML — INEGI, 296,814 registros)"
    ),
    caption = map_caption(
      10, "Prompting only (Versión Detalle)",
      paste0(
        "Instituto Nacional de Estadística y Geografía (INEGI) — Catálogo Único de Localidades (AGEEML 2025);\n",
        "Marco Geoestadístico Nacional / Natural Earth. Proyección oficial: México ITRF2008 / Conforme Cónica de Lambert (EPSG:6372).\n",
        "Reto 'Prompting only': Diseñado, clasificado y mapeado íntegramente mediante prompts al modelo sin edición manual de código."
      )
    ),
    theme = theme(
      plot.background = element_rect(fill = CREAM, color = NA),
      plot.title = element_text(
        size = 20, face = "bold", color = INK, hjust = 0.5,
        margin = margin(t = 12, b = 4)
      ),
      plot.subtitle = element_text(
        size = 10.5, color = SLATE, hjust = 0.5, lineheight = 1.25,
        margin = margin(b = 6)
      ),
      plot.caption = element_text(
        size = 7.8, color = MUTED, hjust = 0.5, lineheight = 1.25,
        margin = margin(t = 8, b = 6)
      ),
      plot.margin = margin(12, 14, 12, 14)
    )
  ) &
  theme(plot.background = element_rect(fill = CREAM, color = NA))

out_high    <- "outputs/high_res/day10_prompting_only_detalle.png"
out_gallery <- "outputs/gallery/day10_prompting_only_detalle.png"

if (file.exists(out_high)) unlink(out_high)
if (file.exists(out_gallery)) unlink(out_gallery)

cat("  -> Guardando versión en alta resolución (300 dpi)...\n")
ggsave(out_high, poster_detalle, width = 16.5, height = 13.0, dpi = 300, bg = CREAM, device = grDevices::png)

cat("  -> Guardando versión para galería (150 dpi)...\n")
ggsave(out_gallery, poster_detalle, width = 16.5, height = 13.0, dpi = 150, bg = CREAM, limitsize = FALSE, device = grDevices::png)

cat("\n[ÉXITO TOTAL] Póster versión detalle exportado correctamente:\n")
cat(" - Alta resolución:", out_high, "(Tamaño:", round(file.size(out_high) / 1024^2, 2), "MB)\n")
cat(" - Galería web:     ", out_gallery, "(Tamaño:", round(file.size(out_gallery) / 1024^2, 2), "MB)\n")
