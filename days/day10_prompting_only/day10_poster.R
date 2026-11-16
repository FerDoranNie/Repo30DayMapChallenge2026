# ==============================================================================
# Día 10 — Prompting only: El Bestiario y Herbario Toponímico de México
# Póster Cartográfico de Síntesis Biogeográfica de ~300,000 Localidades
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
cat(" [DÍA 10 - PÓSTER] Generando póster cartográfico editorial...\n")
cat("======================================================================\n\n")

# Paleta base del estilo Atlas Enmarcado
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
hex_grid   <- ds$hex_grid
conteos_g  <- ds$conteos_grupo
conteos_d  <- ds$conteos_dominio
tot_cat    <- ds$total_catalogo
tot_bio    <- ds$total_bio

# Límites cartográficos en EPSG:6372 con margen
bbox_mx <- st_bbox(mx_union)
xlims   <- c(bbox_mx["xmin"] - 30000, bbox_mx["xmax"] + 30000)
ylims   <- c(bbox_mx["ymin"] - 30000, bbox_mx["ymax"] + 30000)

# Data frame para etiquetas cartográficas con cajas de fondo de alto contraste
df_labels <- data.frame(
  x = c(1750000, 2400000, 3600000, 2480000),
  y = c(2050000, 2300000, 1780000, 1420000),
  label = c(
    "SIERRA MADRE OCCIDENTAL\nCinturón templado: Pino, Ocote y Encino",
    "DESIERTO CHIHUAHUENSE\nReino árido: Mezquite, Nopal y Coyote",
    "PENÍNSULA DE YUCATÁN\nTrópico húmedo: Ceiba (Yaxché) y Jaguar",
    "EL BAJÍO Y EJE NEOVOLCÁNICO\nSabinos de ribera, Frutales y Venados"
  ),
  border_col = c("#10B981", "#F59E0B", "#06B6D4", "#3B82F6")
)

# ------------------------------------------------------------------------------
# 2. Panel A: Mapa Principal de los 5 Dominios Ecoculturales
# ------------------------------------------------------------------------------
cat("[2/4] Construyendo Panel A: Mapa General de México...\n")

p_main <- ggplot() +
  # Fondo continental de México
  geom_sf(data = mx_states, fill = SLATE_LAND, color = SLATE_DIV, linewidth = 0.35) +
  geom_sf(data = mx_union, fill = NA, color = "#64748B", linewidth = 0.75) +
  # Puntos de localidades biológicas
  geom_sf(
    data = locs_sf,
    aes(color = dominio_ecocultural),
    size = 0.70,
    alpha = 0.78,
    shape = 16
  ) +
  # Etiquetas biogeográficas enmarcadas legibles
  geom_label(
    data = df_labels,
    aes(x = x, y = y, label = label),
    fill = alpha("#0F172A", 0.85),
    color = "#F8FAFC",
    size = 2.6,
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
    legend.title = element_text(size = 9.5, face = "bold", color = INK),
    legend.text = element_text(size = 8.2, color = SLATE),
    legend.key = element_blank(),
    legend.background = element_rect(fill = alpha(CREAM, 0.9), color = NA),
    plot.margin = margin(4, 6, 4, 6)
  ) +
  guides(color = guide_legend(override.aes = list(size = 3.5, alpha = 1), nrow = 2))

# ------------------------------------------------------------------------------
# 3. Panel B: Múltiplos Pequeños (8 Taxa Emblemáticos: 4 Flora vs 4 Fauna)
# ------------------------------------------------------------------------------
cat("[3/4] Construyendo Panel B: Cuadrícula de Pequeños Múltiplos (8 Taxa)...\n")

taxa_spec <- list(
  # Flora
  list(id = "pino_ocote",        tit = "Pino y Ocote (Pinus / Quercus)", col = "#10B981", tag = "FLORA | Sierras Templadas"),
  list(id = "mezquite_huizache", tit = "Mezquite y Huizache (Prosopis)", col = "#F59E0B", tag = "FLORA | Cuencas Áridas y Bajío"),
  list(id = "cactaceas",         tit = "Nopal y Maguey (Opuntia / Agave)", col = "#84CC16", tag = "FLORA | Altiplano Semiárido"),
  list(id = "selva_tropical",    tit = "Ceiba y Palma (Ceiba / Arecaceae)", col = "#06B6D4", tag = "FLORA | Trópico y Selva Húmeda"),
  # Fauna
  list(id = "coyote",            tit = "El Coyote (Canis latrans)", col = "#F97316", tag = "FAUNA | Matorral y Mesetas"),
  list(id = "venado",            tit = "El Venado (Mazatl / Odocoileus)", col = "#EAB308", tag = "FAUNA | Bosques y Serranías"),
  list(id = "felinos",           tit = "El Jaguar y Tigre (Panthera onca)", col = "#EF4444", tag = "FAUNA | Selvas del Sur y Golfo"),
  list(id = "aves",              tit = "Águila, Gavilán y Aves (Cuauhtli)", col = "#A855F7", tag = "FAUNA | Valles y Alturas")
)

mini_plots <- list()

for (i in seq_along(taxa_spec)) {
  tx <- taxa_spec[[i]]
  sub_pts <- locs_sf |> filter(grupo_id == tx$id)
  n_pts   <- nrow(sub_pts)
  
  p_sub <- ggplot() +
    geom_sf(data = mx_states, fill = SLATE_LAND, color = "#2A3C54", linewidth = 0.15) +
    geom_sf(data = mx_union, fill = NA, color = "#475569", linewidth = 0.4) +
    geom_sf(data = sub_pts, color = tx$col, size = 0.52, alpha = 0.88, shape = 16) +
    coord_sf(xlim = xlims, ylim = ylims, expand = FALSE) +
    labs(
      title = tx$tit,
      subtitle = sprintf("%s  •  N = %s localidades", tx$tag, comma(n_pts))
    ) +
    theme_void() +
    theme(
      plot.background = element_rect(fill = CREAM, color = NA),
      panel.background = element_rect(fill = OCEAN, color = BORDER, linewidth = 0.4),
      plot.title = element_text(size = 8.5, face = "bold", color = INK, margin = margin(t = 3, b = 1), hjust = 0),
      plot.subtitle = element_text(size = 7.0, color = MUTED, margin = margin(b = 3), hjust = 0),
      plot.margin = margin(2, 3, 2, 3)
    )
  
  mini_plots[[i]] <- p_sub
}

# Organizar los 8 múltiplos en matriz de 2 filas x 4 columnas
p_multiples <- (mini_plots[[1]] | mini_plots[[2]] | mini_plots[[3]] | mini_plots[[4]]) /
               (mini_plots[[5]] | mini_plots[[6]] | mini_plots[[7]] | mini_plots[[8]])

# ------------------------------------------------------------------------------
# 4. Panel C: Barras Estadísticas y Tarjeta Informativa
# ------------------------------------------------------------------------------
cat("[4/4] Construyendo Panel C: Gráfico de Barras y Tarjeta de Síntesis...\n")

df_bars <- conteos_g |>
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
    reino_color = if_else(reino == "Flora", "#059669", "#E11D48")
  )

p_barras <- ggplot(df_bars, aes(x = n_localidades, y = reorder(grupo_clean, n_localidades), fill = reino)) +
  geom_col(width = 0.72, alpha = 0.9) +
  geom_text(
    aes(label = comma(n_localidades)),
    hjust = -0.15,
    size = 2.8,
    fontface = "bold",
    color = SLATE
  ) +
  scale_fill_manual(
    values = c("Fauna" = "#F43F5E", "Flora" = "#10B981"),
    name = "Reino:"
  ) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.22)), labels = comma) +
  labs(
    title = "Toponimia Biológica Nacional por Taxón",
    subtitle = "Número de pueblos, rancherías y ejidos con nombres de fauna y flora (INEGI)",
    x = "Localidades registradas",
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
    plot.title = element_text(size = 9.5, face = "bold", color = INK, margin = margin(b = 2)),
    plot.subtitle = element_text(size = 7.5, color = MUTED, margin = margin(b = 6)),
    legend.position = "right",
    legend.title = element_text(size = 7.5, face = "bold"),
    legend.text = element_text(size = 7.0),
    plot.margin = margin(4, 6, 4, 6)
  )

# Tarjeta de Síntesis y Hallazgos Cartográficos
p_card <- ggplot() +
  annotate(
    "rect", xmin = 0, xmax = 1, ymin = 0, ymax = 1,
    fill = "#F1EEDB", color = BORDER, linewidth = 0.5
  ) +
  annotate(
    "text", x = 0.04, y = 0.88,
    label = "💡 HALLAZGOS Y MEMORIA BIOGEOGRÁFICA",
    hjust = 0, size = 3.6, fontface = "bold", color = INK
  ) +
  annotate(
    "text", x = 0.04, y = 0.48,
    label = paste0(
      "• Catálogo analizado: 296,814 localidades urbanas y rurales (AGEEML - INEGI).\n",
      "• Localidades biológicas identificadas: 16,667 asentamientos (5.6% nacional).\n",
      "• Dominancia vegetal: 78.1% aluden a flora nativa vs. 21.9% a fauna silvestre.\n",
      "• Calco de biomas: Los topónimos reconstruyen espontáneamente los grandes\n",
      "  ecosistemas de México: la Sierra Madre del Ocote, el Altiplano del Nopal,\n",
      "  el Matorral del Mezquite y la Huasteca/Península de la Ceiba sagrada.\n",
      "• Reto Prompting only: Clasificador léxico, espacial y póster 100% sintetizados por IA."
    ),
    hjust = 0, size = 2.5, color = SLATE, lineheight = 1.3
  ) +
  xlim(0, 1) + ylim(0, 1) +
  theme_void() +
  theme(plot.margin = margin(4, 4, 4, 4))

p_bottom <- p_barras + p_card + plot_layout(widths = c(1.4, 1))

# ------------------------------------------------------------------------------
# 5. Ensamblado del Póster Completo con Patchwork
# ------------------------------------------------------------------------------
cat("[5/5] Ensamblando y exportando póster final...\n")

poster <- (
  p_main /
  p_multiples /
  p_bottom
) +
  plot_layout(heights = c(1.35, 1.15, 0.75)) +
  plot_annotation(
    title = "EL BESTIARIO Y HERBARIO TOPONÍMICO DE MÉXICO",
    subtitle = paste0(
      "La huella de la fauna silvestre y la flora nativa en los nombres de 16,667 pueblos, rancherías y ejidos ",
      "(Catálogo Nacional de Localidades AGEEML — INEGI, 296,814 registros)"
    ),
    caption = map_caption(
      10, "Prompting only",
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
        margin = margin(b = 8)
      ),
      plot.caption = element_text(
        size = 7.8, color = MUTED, hjust = 0.5, lineheight = 1.25,
        margin = margin(t = 10, b = 6)
      ),
      plot.margin = margin(12, 14, 12, 14)
    )
  ) &
  theme(plot.background = element_rect(fill = CREAM, color = NA))

dir.create("outputs/high_res", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/gallery", recursive = TRUE, showWarnings = FALSE)

out_high    <- "outputs/high_res/day10_prompting_only_toponimos.png"
out_gallery <- "outputs/gallery/day10_prompting_only_toponimos.png"

if (file.exists(out_high)) unlink(out_high)
if (file.exists(out_gallery)) unlink(out_gallery)

# Exportar versiones en alta resolución (300 dpi) y galería (150 dpi)
cat("  -> Guardando versión en alta resolución (300 dpi)...\n")
ggsave(out_high, poster, width = 14.5, height = 18.5, dpi = 300, bg = CREAM, device = grDevices::png)

cat("  -> Guardando versión para galería (150 dpi)...\n")
ggsave(out_gallery, poster, width = 14.5, height = 18.5, dpi = 150, bg = CREAM, limitsize = FALSE, device = grDevices::png)

cat("\n[ÉXITO TOTAL] Póster del Día 10 exportado correctamente:\n")
cat(" - Alta resolución:", out_high, "(Tamaño:", round(file.size(out_high) / 1024^2, 2), "MB)\n")
cat(" - Galería web:     ", out_gallery, "(Tamaño:", round(file.size(out_gallery) / 1024^2, 2), "MB)\n")
