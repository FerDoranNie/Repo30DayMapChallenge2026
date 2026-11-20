# ==============================================================================
# Día 19: Senses: Smell — Paisaje Olfativo Urbano de la Ciudad de México
# Script 04: Póster cartográfico estilo Atlas Enmarcado (ggplot2 + patchwork + ragg)
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))

suppressPackageStartupMessages({
  library(ggplot2)
  library(sf)
  library(data.table)
  library(patchwork)
  library(scales)
  library(ragg)
})

source("utils/theme_map2026.R")

sf_use_s2(FALSE)

fix_utf8 <- function(x) {
  out <- x
  bad <- !validUTF8(out)
  if (any(bad)) {
    out[bad] <- iconv(out[bad], from = "latin1", to = "UTF-8")
  }
  out
}

cat("1. Cargando datos espaciales y tablas...\n")
sp <- readRDS("data/processed/day19_spatial.rds")
alc <- sp$alc
alc_dt <- sp$alc_dt
edomex <- sp$edomex
cdmx_union <- sp$cdmx_union
hex_final <- sp$hex_final
retc_pts <- sp$retc_pts

alc$NOMGEO <- fix_utf8(alc$NOMGEO)
alc_dt[, NOMGEO := fix_utf8(NOMGEO)]

subs_dt <- fread("data/processed/day19_substances.csv", encoding = "UTF-8")
cats_dt <- fread("data/processed/day19_categories.csv", encoding = "UTF-8")

# Ordenar factor de categorías olfativas
olf_levels <- c(
  "Aroma gastronómico intenso (pan, café, tacos)",
  "Aroma cotidiano moderado",
  "Oasis floral (viveros y mercados)",
  "Paisaje mixto (transición)",
  "Dominio de solventes, combustibles e industria",
  "Suelo de conservación / baja densidad"
)
hex_final$olfato_cat <- factor(hex_final$olfato_cat, levels = olf_levels)

pal_olf <- c(
  "Aroma gastronómico intenso (pan, café, tacos)"  = "#D97706",
  "Aroma cotidiano moderado"                       = "#F4B96A",
  "Oasis floral (viveros y mercados)"              = "#2D6A4F",
  "Paisaje mixto (transición)"                     = "#94A3B8",
  "Dominio de solventes, combustibles e industria" = "#881337",
  "Suelo de conservación / baja densidad"          = "#E8E3D8"
)

# Bounding box elegante alrededor de CDMX
bb <- st_bbox(alc)
pad_x <- (bb["xmax"] - bb["xmin"]) * 0.14
pad_y <- (bb["ymax"] - bb["ymin"]) * 0.06
xlim_m <- c(bb["xmin"] - pad_x, bb["xmax"] + pad_x)
ylim_m <- c(bb["ymin"] - pad_y, bb["ymax"] + pad_y)

# Centroides de alcaldías seleccionadas para etiquetas limpias
alc_cent <- st_centroid(alc)
alc_coords <- as.data.table(st_coordinates(alc_cent))
alc_coords[, NOMGEO := alc$NOMGEO]
alc_labels_sel <- alc_coords[NOMGEO %in% c(
  "Cuauhtémoc", "Azcapotzalco", "Gustavo A. Madero", "Iztapalapa",
  "Xochimilco", "Coyoacán", "Benito Juárez", "Miguel Hidalgo",
  "Tlalpan", "Milpa Alta", "Álvaro Obregón"
)]
alc_labels_sel[, short_name := fifelse(
  NOMGEO == "Gustavo A. Madero", "G. A. Madero",
  fifelse(NOMGEO == "Álvaro Obregón", "Á. Obregón", NOMGEO)
)]

# Top 3 focos RETC para anotación en el mapa
retc_top <- retc_pts[order(-retc_pts$ton_voc), ][1:3, ]
retc_top_xy <- as.data.table(st_coordinates(retc_top))
retc_top_xy[, label := c(
  "Foco químico Xochimilco\n674.6 t/año (Estireno, Clorobenceno)",
  "Corredor G. A. Madero\n103.6 t/año en alcaldía",
  "Zona Vallejo–Azcapotzalco\n93.0 t/año en alcaldía"
)]
retc_top_xy[, tx := c(X[1] + 11000, X[2] + 9500, X[3] - 11500)]
retc_top_xy[, ty := c(Y[1] + 3200, Y[2] + 3500, Y[3] + 4500)]

# ==============================================================================
# PANEL A: Mapa Principal (Grilla Hexagonal + RETC 2024)
# ==============================================================================
cat("2. Construyendo Panel A (Mapa principal)...\n")
p_map <- ggplot() +
  # Contexto del Estado de México / Valle de México
  {if (!is.null(edomex)) geom_sf(data = edomex, fill = "#ECE8DE", color = "#CFC9BC", linewidth = 0.25)} +
  # Hexágonos olfativos de CDMX
  geom_sf(data = hex_final, aes(fill = olfato_cat), color = "#F7F4EB", linewidth = 0.08) +
  # Contornos de alcaldías
  geom_sf(data = alc, fill = NA, color = "#334155", linewidth = 0.35, alpha = 0.85) +
  geom_sf(data = cdmx_union, fill = NA, color = "#0F172A", linewidth = 0.7) +
  # Establecimientos RETC 2024 con emisiones COV/olorosas al aire
  geom_sf(
    data = retc_pts,
    aes(size = ton_voc),
    shape = 21, fill = "#BE123C", color = "#FFFBEB", stroke = 0.6, alpha = 0.88
  ) +
  scale_fill_manual(
    values = pal_olf,
    name = "Firma olfativa dominante (hexágonos de 750 m)",
    guide = guide_legend(ncol = 2, title.position = "top", override.aes = list(linewidth = 0.2))
  ) +
  scale_size_continuous(
    name = "Emisión RETC 2024 (ton/año COVs)",
    range = c(2.0, 8.5),
    breaks = c(5, 50, 200, 600),
    guide = guide_legend(nrow = 1, title.position = "top")
  ) +
  # Etiquetas de alcaldías clave
  geom_label(
    data = alc_labels_sel,
    aes(x = X, y = Y, label = short_name),
    size = 2.45, fontface = "bold", color = "#0F172A",
    fill = alpha("#F7F4EB", 0.72), label.size = 0,
    label.padding = unit(0.12, "lines")
  ) +
  # Anotaciones de focos RETC
  geom_segment(
    data = retc_top_xy,
    aes(x = tx, y = ty, xend = X, yend = Y),
    color = "#881337", linewidth = 0.45,
    arrow = arrow(length = unit(0.11, "cm"), type = "closed")
  ) +
  geom_label(
    data = retc_top_xy,
    aes(x = tx, y = ty, label = label),
    size = 2.35, lineheight = 1.05, fontface = "bold",
    fill = alpha("#FFFBEB", 0.92), color = "#881337",
    label.size = 0.25, label.padding = unit(0.18, "lines")
  ) +
  coord_sf(xlim = xlim_m, ylim = ylim_m, expand = FALSE) +
  labs(
    title = "A. Geografía del olfato urbano: aromas cotidianos vs. emisiones industriales",
    subtitle = "Contraste entre 44,663 comercios de comida, pan, café y flores (DENUE) y 5,489 talleres + 25 plantas RETC"
  ) +
  theme_map2026(base_size = 10) +
  theme(
    panel.background = element_rect(fill = "#E5E0D5", color = "#94A3B8", linewidth = 0.6),
    plot.title = element_text(size = 11.5, face = "bold", margin = margin(b = 2)),
    plot.subtitle = element_text(size = 8.6, color = "#475569", margin = margin(b = 6)),
    legend.position = "bottom",
    legend.box = "vertical",
    legend.spacing.y = unit(0.15, "cm"),
    legend.key.size = unit(0.38, "cm"),
    legend.title = element_text(size = 8.2, face = "bold", color = "#1E293B"),
    legend.text = element_text(size = 7.6, color = "#334155"),
    plot.margin = margin(6, 8, 6, 6)
  )

# ==============================================================================
# PANEL B: Densidad Aromática vs. Carga de Solventes por Alcaldía
# ==============================================================================
cat("3. Construyendo Panel B (Alcaldías)...\n")
alc_plot <- copy(alc_dt)
alc_plot[, NOMGEO := fifelse(
  NOMGEO == "La Magdalena Contreras", "Magdalena Contreras",
  fifelse(NOMGEO == "Cuajimalpa de Morelos", "Cuajimalpa",
  fifelse(NOMGEO == "Gustavo A. Madero", "G. A. Madero", NOMGEO))
)]
alc_plot <- alc_plot[order(dens_arom_km2)]
alc_plot[, NOMGEO := factor(NOMGEO, levels = NOMGEO)]

p_alc <- ggplot(alc_plot) +
  geom_segment(
    aes(x = 0, xend = dens_arom_km2, y = NOMGEO, yend = NOMGEO),
    color = "#CBD5E1", linewidth = 0.7
  ) +
  geom_point(
    aes(x = dens_arom_km2, y = NOMGEO),
    color = "#D97706", size = 2.8
  ) +
  geom_point(
    aes(x = dens_solv_km2 * 5, y = NOMGEO),
    color = "#881337", shape = 17, size = 2.1, alpha = 0.85
  ) +
  geom_text(
    aes(x = dens_arom_km2, y = NOMGEO, label = sprintf("%.0f", dens_arom_km2)),
    hjust = -0.35, size = 2.4, color = "#92400E", fontface = "bold"
  ) +
  scale_x_continuous(limits = c(0, 160), expand = c(0, 0)) +
  labs(
    title = "B. Densidad olfativa por alcaldía (estab. / km²)",
    subtitle = "Círculos ámbar: aromas cotidianos | Triángulos vino: solventes/combustibles (×5)",
    x = NULL, y = NULL
  ) +
  theme_minimal(base_size = 9) +
  theme(
    plot.background = element_rect(fill = "#F7F4EB", color = NA),
    panel.background = element_rect(fill = "#F7F4EB", color = NA),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(color = "#E2E8F0", linewidth = 0.35),
    axis.text.y = element_text(size = 7.8, color = "#1E293B", face = "bold"),
    axis.text.x = element_text(size = 7.3, color = "#475569"),
    plot.title = element_text(size = 10, face = "bold", color = "#0F172A", margin = margin(b = 2)),
    plot.subtitle = element_text(size = 7.6, color = "#475569", margin = margin(b = 4)),
    plot.margin = margin(6, 10, 6, 8)
  )

# ==============================================================================
# PANEL C: Anatomía Química del Aire (RETC 2024 CDMX)
# ==============================================================================
cat("4. Construyendo Panel C (Sustancias RETC)...\n")
subs_top <- subs_dt[1:8]
subs_top[, short_sub := fcase(
  grepl("Estireno", SUSTANCIA), "Estireno",
  grepl("Clorobenceno", SUSTANCIA), "Clorobenceno",
  grepl("Xileno", SUSTANCIA), "Xileno (isómeros)",
  grepl("Arsénico", SUSTANCIA), "Arsénico (humos)",
  default = NA_character_
)]
subs_top[is.na(short_sub), short_sub := SUSTANCIA]
subs_top <- subs_top[order(emision_ton)]
subs_top[, short_sub := factor(short_sub, levels = short_sub)]

p_subs <- ggplot(subs_top, aes(x = emision_ton, y = short_sub)) +
  geom_col(fill = "#881337", width = 0.65, alpha = 0.9) +
  geom_text(
    aes(label = sprintf("%.1f t · %s", emision_ton, nota_olfativa)),
    hjust = -0.05, size = 2.45, color = "#334155"
  ) +
  scale_x_continuous(limits = c(0, 480), expand = c(0, 0)) +
  labs(
    title = "C. Anatomía química del aire: COVs y tóxicos (RETC 2024)",
    subtitle = "Toneladas/año emitidas al aire en CDMX (excluye GEI inodoros) y nota olfativa",
    x = NULL, y = NULL
  ) +
  theme_minimal(base_size = 9) +
  theme(
    plot.background = element_rect(fill = "#F7F4EB", color = NA),
    panel.background = element_rect(fill = "#F7F4EB", color = NA),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(color = "#E2E8F0", linewidth = 0.35),
    axis.text.y = element_text(size = 7.8, color = "#1E293B", face = "bold"),
    axis.text.x = element_text(size = 7.3, color = "#475569"),
    plot.title = element_text(size = 10, face = "bold", color = "#0F172A", margin = margin(b = 2)),
    plot.subtitle = element_text(size = 7.6, color = "#475569", margin = margin(b = 4)),
    plot.margin = margin(6, 10, 6, 8)
  )

# ==============================================================================
# PANEL D: Gremios del Olfato Urbano (DENUE CDMX)
# ==============================================================================
cat("5. Construyendo Panel D (Gremios DENUE)...\n")
cats_plot <- copy(cats_dt)[order(n_establecimientos)]
cats_plot[, subcat := factor(subcat, levels = subcat)]
pal_polo <- c(
  "Aroma Cotidiano"          = "#D97706",
  "Aroma Floral"             = "#2D6A4F",
  "Solventes y Combustibles" = "#881337"
)

p_cats <- ggplot(cats_plot, aes(x = n_establecimientos, y = subcat, fill = polo)) +
  geom_col(width = 0.65, alpha = 0.92) +
  geom_text(
    aes(label = comma(n_establecimientos)),
    hjust = -0.15, size = 2.55, fontface = "bold", color = "#1E293B"
  ) +
  scale_fill_manual(values = pal_polo, guide = "none") +
  scale_x_continuous(limits = c(0, 24000), labels = comma, expand = c(0, 0)) +
  labs(
    title = "D. Gremios del paisaje olfativo (DENUE CDMX: 50,152 estab.)",
    subtitle = "Número de unidades económicas activas por perfil sensorial",
    x = NULL, y = NULL
  ) +
  theme_minimal(base_size = 9) +
  theme(
    plot.background = element_rect(fill = "#F7F4EB", color = NA),
    panel.background = element_rect(fill = "#F7F4EB", color = NA),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(color = "#E2E8F0", linewidth = 0.35),
    axis.text.y = element_text(size = 7.8, color = "#1E293B", face = "bold"),
    axis.text.x = element_text(size = 7.3, color = "#475569"),
    plot.title = element_text(size = 10, face = "bold", color = "#0F172A", margin = margin(b = 2)),
    plot.subtitle = element_text(size = 7.6, color = "#475569", margin = margin(b = 4)),
    plot.margin = margin(6, 10, 6, 8)
  )

# ==============================================================================
# COMPOSICIÓN FINAL DEL PÓSTER
# ==============================================================================
cat("6. Ensamblando póster final con patchwork...\n")
right_col <- p_alc / p_subs / p_cats + plot_layout(heights = c(1.15, 0.95, 0.85))

poster <- (p_map | right_col) +
  plot_layout(widths = c(1.38, 1.0)) +
  plot_annotation(
    title = "¿A qué huele la Ciudad de México? El paisaje olfativo urbano",
    subtitle = "Del comal, el pan recién horneado y las flores al thinner, el estireno y los hidrocarburos: 50,152 comercios DENUE y 940.6 ton/año de COVs en RETC 2024",
    caption = map_caption(19, "Senses: Smell", "INEGI DENUE (CDMX) & SEMARNAT RETC Verificado / Gasolineras 2024"),
    theme = theme(
      plot.background = element_rect(fill = "#F7F4EB", color = NA),
      plot.title = element_text(size = 19, face = "bold", color = "#0F172A", margin = margin(t = 8, b = 4)),
      plot.subtitle = element_text(size = 10.5, color = "#334155", margin = margin(b = 10)),
      plot.caption = element_text(size = 8.2, color = "#475569", hjust = 0, margin = margin(t = 8, b = 4)),
      plot.margin = margin(14, 16, 12, 16)
    )
  )

dir.create("outputs/high_res", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/gallery", recursive = TRUE, showWarnings = FALSE)

out_hi <- "outputs/high_res/day19_senses_smell_paisaje_olfativo.png"
out_gal <- "outputs/gallery/day19_senses_smell_paisaje_olfativo.png"

cat("7. Exportando imágenes (300 dpi y 150 dpi)...\n")
ragg::agg_png(out_hi, width = 16.5, height = 10.5, units = "in", res = 300, background = "#F7F4EB")
print(poster)
dev.off()

ragg::agg_png(out_gal, width = 16.5, height = 10.5, units = "in", res = 150, background = "#F7F4EB")
print(poster)
dev.off()

cat(sprintf("Listo!\n  High-res: %s\n  Gallery:  %s\n", out_hi, out_gal))
