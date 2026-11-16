# ==============================================================================
# Día 09 — Urban-rural | Póster Cartográfico
# La frontera que devora el bosque: 50 años de expansión metropolitana (1975–2025)
#
# Requiere: data/processed/day09_urban_rural_dataset.rds
# Autor:    Fernando Dorantes Nieto (@FerDoranNie)
# ==============================================================================

user_lib <- "C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3"
if (dir.exists(user_lib) && !(user_lib %in% .libPaths())) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(patchwork)
  library(scales)
  library(ragg)
  library(biscale)
})

sf_use_s2(FALSE)

dir.create("outputs/high_res", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/gallery",  showWarnings = FALSE, recursive = TRUE)

t0 <- Sys.time()
msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n")
msg("Generando Póster Cartográfico Día 09: Urban-rural...")

# ------------------------------------------------------------------------------
# 1. Cargar Datos Procesados
# ------------------------------------------------------------------------------
d <- readRDS("data/processed/day09_urban_rural_dataset.rds")

metros        <- d$metros
df_metrics    <- d$df_metrics
grid_biv      <- d$grid_biv
metro_boxes   <- d$metro_boxes
mx_lcc        <- d$mx_lcc
mx_border_lcc <- d$mx_border_lcc

# ------------------------------------------------------------------------------
# 2. Paleta Editorial Atlas Enmarcado
# ------------------------------------------------------------------------------
PAPEL    <- "#F7F4EB"  # Crema cálido editorial
TINTA    <- "#0F172A"  # Pizarra oscura profunda
TINTA2   <- "#334155"  # Pizarra media
GRIS_TXT <- "#475569"  # Gris editorial para subtítulos y notas
OCEANO   <- "#DCE6F2"  # Azul atlas pálido
MARCO    <- "#94A3B8"  # Borde fino lámina de atlas
RETICULA <- "#CBD5E1"  # Retícula sutil

# Paleta bivariada 3x3 seleccionada ("DkBlue2")
# 1-1 = baja urbanización, baja cobertura forestal (árido/neutro)
# 1-3 = baja urbanización, alta cobertura forestal (selvas y bosques prístinos)
# 3-1 = alta urbanización, baja cobertura forestal (centros urbanos consolidados)
# 3-3 = ALTA URBANIZACIÓN + ALTA COBERTURA FORESTAL (LA FRONTERA ACTIVA)
PALETA_BIV <- "DkBlue2"

FUENTE_BASE  <- "Georgia"
FUENTE_MONO  <- "sans"

# ------------------------------------------------------------------------------
# 3. Panel A: Mapa Nacional Bivariado (México en EPSG:6372 LCC)
# ------------------------------------------------------------------------------
msg("Construyendo Panel A: Mapa Nacional Bivariado...")

# Centroides y etiquetas de los 6 recuadros metropolitanos
metro_cents <- st_centroid(metro_boxes) %>%
  bind_cols(as.data.frame(st_coordinates(st_centroid(metro_boxes)))) %>%
  mutate(
    num = row_number(),
    label_num = paste0(" ", num, " "),
    tag = paste0(num, ". ", nombre)
  )

# Ajuste fino de posiciones de etiquetas en el mapa nacional
metro_cents$nudge_x <- c(80000, 110000, -110000, 90000, 110000, 90000)
metro_cents$nudge_y <- c(-70000, 60000, -60000, 60000, -60000, -80000)

p_nacional <- ggplot() +
  # Fondo oceánico enmarcado
  geom_sf(data = mx_border_lcc, fill = OCEANO, color = NA) +
  # Malla hexagonal bivariada
  geom_sf(data = grid_biv, aes(fill = bi_class), color = NA, linewidth = 0) +
  bi_scale_fill(pal = PALETA_BIV, dim = 3, guide = "none") +
  # Límites estatales sutiles
  geom_sf(data = mx_lcc, fill = NA, color = "#64748B", linewidth = 0.25, alpha = 0.45) +
  # Costa y frontera nacional
  geom_sf(data = mx_border_lcc, fill = NA, color = TINTA, linewidth = 0.65) +
  # Recuadros de las 6 Zonas Metropolitanas
  geom_sf(data = metro_boxes, fill = NA, color = "#DC2626", linewidth = 0.95, linetype = "solid") +
  # Puntos indicadores numerados sobre cada metrópoli
  geom_point(data = metro_cents, aes(x = X, y = Y), color = "#DC2626", size = 4.2) +
  geom_point(data = metro_cents, aes(x = X, y = Y), color = "#FFFFFF", size = 2.4) +
  geom_text(
    data = metro_cents,
    aes(x = X + nudge_x, y = Y + nudge_y, label = tag),
    family = FUENTE_BASE, fontface = "bold", size = 3.6, color = TINTA,
    check_overlap = TRUE
  ) +
  coord_sf(crs = 6372, expand = FALSE) +
  theme_void(base_family = FUENTE_BASE) +
  theme(
    panel.background = element_rect(fill = OCEANO, color = MARCO, linewidth = 0.7),
    plot.background  = element_rect(fill = PAPEL, color = NA),
    plot.margin      = margin(4, 10, 4, 10)
  )

# Leyenda romboidal bivariada (biscale diamond)
legend_biv <- bi_legend(
  pal = PALETA_BIV,
  dim = 3,
  xlab = "Presión Urbana  ",
  ylab = "Cobertura Natural  ",
  size = 7.5
) +
  theme_void(base_family = FUENTE_BASE) +
  theme(
    plot.background  = element_rect(fill = alpha(PAPEL, 0.95), color = MARCO, linewidth = 0.4),
    panel.background = element_rect(fill = NA, color = NA),
    text             = element_text(color = TINTA, size = 7.5, family = FUENTE_BASE),
    plot.margin      = margin(8, 8, 8, 8)
  )

# Incrustar la leyenda sobre el Golfo de México / Pacífico en el mapa nacional
p_nacional_completo <- p_nacional +
  inset_element(
    legend_biv,
    left   = 0.03,
    bottom = 0.05,
    right  = 0.32,
    top    = 0.38,
    align_to = "panel"
  )

# ------------------------------------------------------------------------------
# 4. Panel B: 6 Acercamientos Metropolitanos de Alta Resolución
# ------------------------------------------------------------------------------
msg("Construyendo Panel B: 6 Facetas Metropolitanas...")

insets_list <- list()

for (i in seq_along(metros)) {
  m_id <- names(metros)[i]
  m    <- metros[[m_id]]
  met  <- df_metrics %>% filter(id == m_id)
  
  # Cargar rásters procesados de la metrópoli
  r1975_path <- file.path("data/processed/day09_metros", paste0(m_id, "_ghsl_1975.tif"))
  r2025_path <- file.path("data/processed/day09_metros", paste0(m_id, "_ghsl_2025.tif"))
  usv_path   <- file.path("data/processed/day09_metros", paste0(m_id, "_usv.tif"))
  
  r1975 <- rast(r1975_path)
  r2025 <- rast(r2025_path)
  usv   <- rast(usv_path)
  
  # Resamplear USV al ráster 2025 para graficación unificada
  usv_r <- resample(usv, r2025, method = "near")
  
  # Clasificación de capas para ggplot:
  # Fondo ecológico / agrícola
  df_usv <- as.data.frame(usv_r, xy = TRUE)
  names(df_usv)[3] <- "cls"
  df_usv$categoria <- factor(
    case_when(
      df_usv$cls %in% c(1, 2) ~ "Bosque / Selva / Matorral",
      df_usv$cls == 3         ~ "Suelo Agrícola / Rural",
      df_usv$cls == 4         ~ "Cuerpos de Agua",
      TRUE                    ~ "Área Desprovista / Abierta"
    ),
    levels = c("Bosque / Selva / Matorral", "Suelo Agrícola / Rural", "Cuerpos de Agua", "Área Desprovista / Abierta")
  )
  
  # Huella urbana 1975 (GHS_BUILT_S >= 500 m2)
  df_u75 <- as.data.frame(r1975, xy = TRUE)
  names(df_u75)[3] <- "val"
  df_u75 <- df_u75 %>% filter(val >= 500)
  
  # Nueva expansión 1975 -> 2025
  df_u25 <- as.data.frame(r2025, xy = TRUE)
  names(df_u25)[3] <- "val"
  df_u25 <- df_u25 %>% filter(val >= 500)
  
  # Identificar celdas de nueva expansión (presentes en 2025 pero no en 1975)
  # Uniendo por coordenadas aproximadas o por máscara directa
  r_exp <- (r2025 >= 500) == 1 & ((r1975 < 500) | is.na(r1975))
  df_exp <- as.data.frame(r_exp, xy = TRUE)
  names(df_exp)[3] <- "is_exp"
  df_exp <- df_exp %>% filter(is_exp == 1)
  
  # Texto de métricas para el subtítulo del inset
  txt_kpi <- sprintf(
    "1975: %s km² → 2025: %s km² (+%s%%)\nBosque/Selva devorado: %s km² | Agrícola: %s km²",
    format(met$area_1975_km2, big.mark = ","),
    format(met$area_2025_km2, big.mark = ","),
    format(met$crecimiento_pct, big.mark = ","),
    format(met$bosque_devorado_km2, big.mark = ","),
    format(met$agricola_devorado_km2, big.mark = ",")
  )
  
  # Construcción del mapa del inset
  p_inset <- ggplot() +
    # 1. Fondo ecológico y rural (USV)
    geom_raster(data = df_usv, aes(x = x, y = y, fill = categoria)) +
    scale_fill_manual(
      values = c(
        "Bosque / Selva / Matorral"    = "#1B4332",  # Verde bosque oscuro
        "Suelo Agrícola / Rural"       = "#E9DFC8",  # Crema ocre agrícola suave
        "Cuerpos de Agua"              = "#A5C4D4",  # Azul lacustre
        "Área Desprovista / Abierta"   = "#D3CCC1"
      ),
      guide = "none"
    ) +
    # 2. Nueva expansión 1975–2025 (Frente que devora: Coral/carmín vibrante)
    geom_tile(data = df_exp, aes(x = x, y = y), fill = "#EF4444", alpha = 0.90) +
    # 3. Mancha urbana consolidada en 1975 (Pizarra grafito)
    geom_tile(data = df_u75, aes(x = x, y = y), fill = "#1E293B", alpha = 0.95) +
    coord_equal(expand = FALSE) +
    labs(
      title = paste0(i, ". ", m$nombre, " (", m$subtitulo, ")"),
      subtitle = paste0(m$ecosistema, "\n", txt_kpi)
    ) +
    theme_void(base_family = FUENTE_BASE) +
    theme(
      plot.title = element_text(
        size = 11, face = "bold", color = TINTA, margin = margin(t = 4, b = 2)
      ),
      plot.subtitle = element_text(
        size = 8.2, color = TINTA2, lineheight = 1.15, margin = margin(b = 4)
      ),
      panel.border = element_rect(color = MARCO, fill = NA, linewidth = 0.6),
      plot.background = element_rect(fill = PAPEL, color = NA),
      plot.margin = margin(6, 6, 6, 6)
    )
  
  insets_list[[m_id]] <- p_inset
}

# Organizar los 6 insets en cuadrícula 3 x 2 con patchwork
p_insets_grid <- (insets_list[[1]] | insets_list[[2]] | insets_list[[3]]) /
                 (insets_list[[4]] | insets_list[[5]] | insets_list[[6]])

# ------------------------------------------------------------------------------
# 5. Encabezado, Leyenda Inferior y Pie de Figura Oficial
# ------------------------------------------------------------------------------
msg("Ensamblando póster cartográfico completo...")

# Banner de encabezado
header_plot <- ggplot() +
  annotate(
    "text", x = 0, y = 1.05,
    label = "30DAYMAPCHALLENGE 2026  ·  DÍA 09: URBAN-RURAL  ·  EJE: MÉXICO",
    family = FUENTE_BASE, fontface = "bold", size = 3.6, color = "#B91C1C", hjust = 0
  ) +
  annotate(
    "text", x = 0, y = 0.68,
    label = "LA FRONTERA QUE DEVORA EL BOSQUE",
    family = FUENTE_BASE, fontface = "bold", size = 8.2, color = TINTA, hjust = 0
  ) +
  annotate(
    "text", x = 0, y = 0.32,
    label = "50 años de expansión metropolitana sobre ecosistemas y tierras rurales en México (1975–2025)",
    family = FUENTE_BASE, fontface = "italic", size = 4.6, color = TINTA2, hjust = 0
  ) +
  annotate(
    "text", x = 0, y = -0.04,
    label = paste0(
      "La transición urbano-rural en México no es una línea estática, sino una onda expansiva que en medio siglo ha multiplicado la huella construida de las metrópolis.\n",
      "El mapa nacional muestra la fricción bivariada 3×3 entre la presión urbana y la cobertura vegetal circundante; los acercamientos detallan la absorción de bosques y tierras agrícolas en 6 regiones clave."
    ),
    family = FUENTE_BASE, size = 3.3, color = GRIS_TXT, hjust = 0, lineheight = 1.25
  ) +
  xlim(0, 1) + ylim(-0.30, 1.25) +
  theme_void() +
  theme(plot.margin = margin(8, 14, 2, 14))

# Mini leyenda de capas para las facetas metropolitanas
legend_facets_plot <- ggplot() +
  annotate("rect", xmin = 0.02, xmax = 0.05, ymin = 0.2, ymax = 0.8, fill = "#1E293B", color = NA) +
  annotate("text", x = 0.065, y = 0.5, label = "Huella Urbana Histórica (1975)", family = FUENTE_BASE, size = 3.3, color = TINTA, hjust = 0) +
  annotate("rect", xmin = 0.28, xmax = 0.31, ymin = 0.2, ymax = 0.8, fill = "#EF4444", color = NA) +
  annotate("text", x = 0.325, y = 0.5, label = "Frente de Expansión (1975 → 2025)", family = FUENTE_BASE, size = 3.3, color = TINTA, fontface = "bold", hjust = 0) +
  annotate("rect", xmin = 0.59, xmax = 0.62, ymin = 0.2, ymax = 0.8, fill = "#1B4332", color = NA) +
  annotate("text", x = 0.635, y = 0.5, label = "Bosque / Selva / Matorral", family = FUENTE_BASE, size = 3.3, color = TINTA, hjust = 0) +
  annotate("rect", xmin = 0.82, xmax = 0.85, ymin = 0.2, ymax = 0.8, fill = "#E9DFC8", color = "#CBD5E1") +
  annotate("text", x = 0.865, y = 0.5, label = "Suelo Agrícola / Rural", family = FUENTE_BASE, size = 3.3, color = TINTA, hjust = 0) +
  xlim(0, 1) + ylim(0, 1) +
  theme_void() +
  theme(plot.margin = margin(2, 14, 4, 14))

# Pie de figura oficial
caption_plot <- ggplot() +
  annotate(
    "text", x = 0, y = 0.5,
    label = paste0(
      "#30DayMapChallenge 2026 | Día 09: Urban-rural\n",
      "Datos: Global Human Settlement Layer (GHSL JRC R2023A, Built Surface 1975–2025) e INEGI Uso del Suelo y Vegetación (Serie VII) | Gráfico: Fernando Dorantes Nieto (@FerDoranNie)"
    ),
    family = FUENTE_BASE, size = 3.0, color = GRIS_TXT, hjust = 0, lineheight = 1.25
  ) +
  xlim(0, 1) + ylim(0, 1) +
  theme_void() +
  theme(plot.margin = margin(2, 14, 8, 14))

# Ensamble final con patchwork
poster_final <- (header_plot / p_nacional_completo / legend_facets_plot / p_insets_grid / caption_plot) +
  plot_layout(heights = c(0.12, 0.44, 0.03, 0.36, 0.05)) &
  theme(plot.background = element_rect(fill = PAPEL, color = NA))

# ------------------------------------------------------------------------------
# 6. Exportación en Alta Resolución y Galería
# ------------------------------------------------------------------------------
OUT_HIGH <- "outputs/high_res/day09_urban_rural_frontera_bosque.png"
OUT_GAL  <- "outputs/gallery/day09_urban_rural_frontera_bosque.png"

msg("Guardando póster en alta resolución (300 dpi): ", OUT_HIGH)
agg_png(
  filename = OUT_HIGH,
  width    = 15,
  height   = 19,
  units    = "in",
  res      = 300
)
print(poster_final)
dev.off()

msg("Guardando versión optimizada para galería (150 dpi): ", OUT_GAL)
agg_png(
  filename = OUT_GAL,
  width    = 15,
  height   = 19,
  units    = "in",
  res      = 150
)
print(poster_final)
dev.off()

msg("¡Póster estático completado exitosamente en ", format(round(Sys.time() - t0, 1)), "!")
