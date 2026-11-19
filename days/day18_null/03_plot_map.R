# ==============================================================================
# Día 18: NULL — Terra Incognita Biológica
# Póster cartográfico estilo Atlas Enmarcado (Equal Earth, 50 x 50 km)
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))

suppressPackageStartupMessages({
  library(ggplot2)
  library(sf)
  library(data.table)
  library(patchwork)
  library(scales)
  library(jsonlite)
})

source("utils/theme_map2026.R")

sf_use_s2(FALSE)
crs_eqearth <- "+proj=eqearth +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

cat("Cargando datos procesados...\n")
df <- readRDS("data/processed/day18_null_grid.rds")
biome_sum <- fread("data/processed/day18_biome_summary.csv")
stats_json <- fromJSON("data/processed/day18_summary.json")

# Preparar factor ordenado para el mapa principal
df[, plot_cat := fcase(
  ndvi_max >= 0.55 & gbif_count == 0,   "Terra Incognita: Alta veg. + NULL (0 reg.)",
  ndvi_max >= 0.55 & gbif_count <= 50,  "Crítico: Alta veg. + 1–50 reg.",
  ndvi_max >= 0.55 & gbif_count > 50,   "Muestreado: Alta veg. + >50 reg.",
  ndvi_max < 0.55  & gbif_count == 0,   "Baja vegetación + NULL",
  default = "Baja vegetación + con datos"
)]

df[, plot_cat := factor(plot_cat, levels = c(
  "Terra Incognita: Alta veg. + NULL (0 reg.)",
  "Crítico: Alta veg. + 1–50 reg.",
  "Muestreado: Alta veg. + >50 reg.",
  "Baja vegetación + con datos",
  "Baja vegetación + NULL"
))]

# Paleta editorial sobre papel crema (#F7F4EB) y océano (#DCE6F2)
pal_map <- c(
  "Terra Incognita: Alta veg. + NULL (0 reg.)" = "#C81D25", # Bermellón atlas
  "Crítico: Alta veg. + 1–50 reg."             = "#E07A22", # Ámbar quemado
  "Muestreado: Alta veg. + >50 reg."           = "#2D6A4F", # Verde bosque
  "Baja vegetación + con datos"                = "#93A8BC", # Azul pizarra suave (distinto al mar #DCE6F2)
  "Baja vegetación + NULL"                     = "#E6E0D3"  # Arena claro
)

# Cargar costas/países y gratícula en Equal Earth
world_sf <- st_read("data/raw/day04/ne_50m_admin_0_countries.geojson", quiet = TRUE)
world_no_ata <- world_sf[world_sf$ISO_A3 != "ATA" & world_sf$ADMIN != "Antarctica", ]
world_eq <- st_transform(st_make_valid(world_no_ata), crs_eqearth)

# Esfera / marco exterior Equal Earth para el océano
grat_wgs <- st_graticule(lat = seq(-60, 80, by = 30), lon = seq(-180, 180, by = 30))
grat_eq <- st_transform(grat_wgs, crs_eqearth)

# Puntos de anotación geográfica en WGS84 -> Equal Earth
ann_pts <- st_as_sf(
  data.frame(
    lon = c(-64.5, 27.5, 122.0, -76.0),
    lat = c(-4.5, 6.5, 64.0, 56.0),
    tx  = c(-108.0, -14.0, 152.0, -130.0),
    ty  = c(-22.0, -16.0, 77.0, 75.0),
    label = c(
      "Amazonía (Brasil)\n27 celdas NULL · 67,500 km²",
      "Sudd y África Central\n(Sudán del Sur, RCA, RDC)\n34 celdas NULL · 85,000 km²",
      "Taiga de Siberia Oriental\n41 celdas NULL · 102,500 km²",
      "Escudo Boreal (Canadá)\n4 celdas NULL · 10,000 km²"
    )
  ),
  coords = c("lon", "lat"), crs = 4326
)
ann_eq <- st_transform(ann_pts, crs_eqearth)
ann_coords <- as.data.frame(st_coordinates(ann_eq))

ann_txt_sf <- st_as_sf(
  data.frame(lon = ann_pts$tx, lat = ann_pts$ty),
  coords = c("lon", "lat"), crs = 4326
)
ann_txt_eq <- as.data.frame(st_coordinates(st_transform(ann_txt_sf, crs_eqearth)))

ann_df <- data.frame(
  x = ann_coords$X,
  y = ann_coords$Y,
  tx = ann_txt_eq$X,
  ty = ann_txt_eq$Y,
  label = ann_pts$label
)

# ==============================================================================
# PANEL A: Mapa Global Equal Earth
# ==============================================================================
p_map <- ggplot() +
  geom_sf(data = grat_eq, color = "#B8CAE0", linewidth = 0.25, alpha = 0.6) +
  geom_tile(
    data = df,
    aes(x = x, y = y, fill = plot_cat),
    width = 50000, height = 50000
  ) +
  # Resaltar ligeramente las celdas NULL absolutas de alta vegetación para nitidez
  geom_tile(
    data = df[plot_cat == "Terra Incognita: Alta veg. + NULL (0 reg.)"],
    aes(x = x, y = y),
    fill = "#C81D25", color = "#7A0D12", linewidth = 0.2,
    width = 54000, height = 54000
  ) +
  geom_sf(data = world_eq, fill = NA, color = "#475569", linewidth = 0.16, alpha = 0.55) +
  # Flechas y etiquetas de focos Terra Incognita
  geom_segment(
    data = ann_df,
    aes(x = tx, y = ty, xend = x, yend = y),
    color = "#0F172A", linewidth = 0.45,
    arrow = arrow(length = unit(0.12, "cm"), type = "closed")
  ) +
  geom_label(
    data = ann_df,
    aes(x = tx, y = ty, label = label),
    size = 2.6, lineheight = 0.95, fontface = "bold",
    fill = alpha("#F7F4EB", 0.92), color = "#0F172A",
    label.size = 0.25, label.padding = unit(0.22, "lines")
  ) +
  scale_fill_manual(values = pal_map, name = "Estado en grilla de 50 × 50 km (2,500 km²):") +
  coord_sf(crs = crs_eqearth, expand = FALSE) +
  guides(fill = guide_legend(nrow = 2, byrow = TRUE, override.aes = list(color = "#334155", linewidth = 0.2))) +
  theme_map2026(base_size = 11) +
  theme(
    legend.position = "bottom",
    legend.background = element_rect(fill = "#F7F4EB", color = NA),
    legend.key = element_rect(color = NA),
    legend.key.size = unit(0.45, "cm"),
    legend.text = element_text(size = 8.5, color = "#1E293B"),
    legend.title = element_text(size = 9, face = "bold", color = "#0F172A"),
    plot.margin = margin(4, 10, 4, 10)
  )

# ==============================================================================
# PANEL B: Biomas con mayor vacío de muestreo (NULL + Crítico)
# ==============================================================================
biome_plot <- copy(biome_sum)
biome_plot[, pct_crit_only := 100 * (low_cells - null_cells) / total_cells]
biome_plot[, pct_total_gap := pct_null + pct_crit_only]
biome_top <- biome_plot[order(-pct_total_gap)][1:6]

# Nombres cortos en español para legibilidad editorial
biome_es <- c(
  "Boreal Forests/Taiga" = "Bosques Boreales / Taiga",
  "Tundra" = "Tundra (alta vegetación estacional)",
  "Flooded Grasslands & Savannas" = "Pastizales y Sabanas Inundables",
  "Tropical & Subtropical Grasslands, Savannas & Shrublands" = "Sabanas y Matorrales Tropicales",
  "Tropical & Subtropical Moist Broadleaf Forests" = "Selvas Húmedas Tropicales",
  "Temperate Grasslands, Savannas & Shrublands" = "Pastizales Templados",
  "Temperate Conifer Forests" = "Bosques Templados de Coníferas",
  "Tropical & Subtropical Dry Broadleaf Forests" = "Selvas Secas Tropicales"
)
biome_top[, label_es := fifelse(biome_name %in% names(biome_es), biome_es[biome_name], biome_name)]

biome_long <- melt(
  biome_top,
  id.vars = c("label_es", "pct_total_gap", "total_cells"),
  measure.vars = c("pct_null", "pct_crit_only"),
  variable.name = "tipo", value.name = "pct"
)
biome_long[, tipo_lbl := fifelse(tipo == "pct_null", "NULL (0 registros)", "Crítico (1–50 reg.)")]
biome_long[, label_es := reorder(label_es, pct_total_gap)]

p_biomes <- ggplot(biome_long, aes(x = pct, y = label_es, fill = tipo_lbl)) +
  geom_col(width = 0.68, color = "#F7F4EB", linewidth = 0.2) +
  geom_text(
    data = biome_top,
    aes(x = pct_total_gap + 0.8, y = reorder(label_es, pct_total_gap),
        label = sprintf("%.1f%%", pct_total_gap)),
    inherit.aes = FALSE, hjust = 0, size = 2.8, fontface = "bold", color = "#0F172A"
  ) +
  scale_fill_manual(
    values = c("NULL (0 registros)" = "#C81D25", "Crítico (1–50 reg.)" = "#E07A22"),
    name = NULL
  ) +
  scale_x_continuous(limits = c(0, 47), expand = c(0, 0), labels = function(x) paste0(x, "%")) +
  labs(
    title = "Biomas de alta vegetación más desiertos en GBIF",
    subtitle = "% de celdas de 2,500 km² (NDVI ≥ 0.55) en estado NULL o crítico",
    x = NULL, y = NULL
  ) +
  theme_minimal(base_size = 9.5) +
  theme(
    plot.background = element_rect(fill = "#F7F4EB", color = NA),
    panel.background = element_rect(fill = "#EFECE1", color = "#CBD5E1", linewidth = 0.4),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(color = "#D8D2C5", linewidth = 0.3),
    plot.title = element_text(face = "bold", size = 10.5, color = "#0F172A"),
    plot.subtitle = element_text(size = 8.2, color = "#475569", margin = margin(b = 6)),
    axis.text.y = element_text(size = 8.2, color = "#1E293B", face = "bold"),
    axis.text.x = element_text(size = 7.8, color = "#475569"),
    legend.position = c(0.76, 0.22),
    legend.background = element_rect(fill = alpha("#F7F4EB", 0.9), color = "#CBD5E1", linewidth = 0.25),
    legend.key.size = unit(0.35, "cm"),
    legend.text = element_text(size = 7.5),
    plot.margin = margin(6, 10, 6, 10)
  )

# ==============================================================================
# PANEL C: La Paradoja del Muestreo (NDVI vs. Densidad GBIF)
# ==============================================================================
set.seed(2026)
df_samp <- df[sample(.N, min(.N, 12000))]
df_samp[, log_gbif := log10(gbif_count + 1)]

p_scatter <- ggplot() +
  # Zona de alta vegetación
  annotate("rect", xmin = 0.55, xmax = 0.95, ymin = -0.15, ymax = 0.22,
           fill = alpha("#C81D25", 0.14), color = "#C81D25", linetype = "dashed", linewidth = 0.35) +
  geom_vline(xintercept = 0.55, linetype = "dotted", color = "#1E293B", linewidth = 0.5) +
  geom_point(
    data = df_samp,
    aes(x = ndvi_max, y = log_gbif, color = plot_cat),
    alpha = 0.38, size = 0.65
  ) +
  geom_smooth(
    data = df_samp,
    aes(x = ndvi_max, y = log_gbif),
    method = "gam", formula = y ~ s(x, bs = "cs"),
    color = "#0F172A", fill = alpha("#0F172A", 0.15), linewidth = 0.75
  ) +
  annotate(
    "label", x = 0.77, y = 0.48,
    label = "Zona NULL (0 reg.)", size = 2.5, fontface = "bold", color = "#9B1117",
    fill = alpha("#F7F4EB", 0.88), label.size = 0.2, label.padding = unit(0.15, "lines")
  ) +
  annotate(
    "label", x = 0.56, y = 7.05, hjust = 0,
    label = "Umbral alta vegetación (NDVI ≥ 0.55)", size = 2.45, fontface = "bold", color = "#1E293B",
    fill = alpha("#EFECE1", 0.88), label.size = 0, label.padding = unit(0.15, "lines")
  ) +
  scale_color_manual(values = pal_map, guide = "none") +
  scale_x_continuous(limits = c(-0.02, 0.96), breaks = seq(0, 0.9, 0.3)) +
  scale_y_continuous(
    limits = c(-0.2, 7.5),
    breaks = c(0, 2, 4, 6),
    labels = c("0\n(NULL)", "10²", "10⁴", "10⁶")
  ) +
  labs(
    title = "La paradoja del muestreo global",
    subtitle = "Mayor vigor vegetal (NDVI) no garantiza cobertura en GBIF",
    x = "NDVI máximo estacional (VIIRS 2024)",
    y = "Registros GBIF / celda (escala log)"
  ) +
  theme_minimal(base_size = 9.5) +
  theme(
    plot.background = element_rect(fill = "#F7F4EB", color = NA),
    panel.background = element_rect(fill = "#EFECE1", color = "#CBD5E1", linewidth = 0.4),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "#D8D2C5", linewidth = 0.3),
    plot.title = element_text(face = "bold", size = 10.5, color = "#0F172A"),
    plot.subtitle = element_text(size = 8.2, color = "#475569", margin = margin(b = 6)),
    axis.title = element_text(size = 8.2, color = "#334155"),
    axis.text = element_text(size = 7.8, color = "#475569"),
    plot.margin = margin(6, 10, 6, 10)
  )

# ==============================================================================
# ENSAMBLAJE FINAL DEL PÓSTER
# ==============================================================================
bottom_row <- (p_biomes | p_scatter) + plot_layout(widths = c(1.15, 1))

poster <- p_map / bottom_row +
  plot_layout(heights = c(2.25, 1.0)) +
  plot_annotation(
    title = "TERRA INCOGNITA BIOLÓGICA: EL MAPA DEL NULL",
    subtitle = paste0(
      "Celdas terrestres de 2,500 km² con alta vegetación (NDVI ≥ 0.55) frente a 3,574.9 millones de registros en GBIF · ",
      "277,500 km² tienen 0 registros (NULL) y 5.96 millones de km² (13.1%) están críticamente submuestreados (≤ 50 reg.)"
    ),
    caption = map_caption(
      18,
      "NULL",
      "GBIF Map Density API (2026) · NOAA NCEI VIIRS-Land NDVI (2024) · WWF Ecoregions 2017 · Natural Earth"
    ),
    theme = theme(
      plot.background = element_rect(fill = "#F7F4EB", color = NA),
      plot.title = element_text(
        face = "bold", size = 20, color = "#0F172A",
        margin = margin(t = 10, b = 4)
      ),
      plot.subtitle = element_text(
        size = 10.5, color = "#334155",
        margin = margin(b = 8)
      ),
      plot.caption = element_text(
        size = 8.2, color = "#475569", hjust = 0,
        margin = margin(t = 8, b = 6)
      ),
      plot.margin = margin(12, 14, 10, 14)
    )
  )

dir.create("outputs/high_res", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/gallery", recursive = TRUE, showWarnings = FALSE)

out_hr <- "outputs/high_res/day18_null_terra_incognita.png"
out_gal <- "outputs/gallery/day18_null_terra_incognita.png"

cat("Exportando alta resolución...\n")
ggsave(out_hr, poster, width = 16, height = 10.8, dpi = 300, bg = "#F7F4EB")

cat("Exportando versión galería...\n")
ggsave(out_gal, poster, width = 16, height = 10.8, dpi = 140, bg = "#F7F4EB")

cat("¡Listo! Mapas guardados en:\n -", out_hr, "\n -", out_gal, "\n")
