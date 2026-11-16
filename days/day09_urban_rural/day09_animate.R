# ==============================================================================
# Día 09 — Urban-rural | Animación Multitemporal (1975–2025)
# La frontera que devora el bosque: 50 años de expansión en 6 metrópolis mexicanas
#
# Requiere: data/processed/day09_urban_rural_dataset.rds y data/processed/day09_metros/
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
  library(ragg)
  library(gifski)
  library(av)
})

sf_use_s2(FALSE)

dir.create("outputs/gallery", showWarnings = FALSE, recursive = TRUE)
dir_frames <- file.path(tempdir(), "day09_frames")
dir.create(dir_frames, showWarnings = FALSE, recursive = TRUE)

t0 <- Sys.time()
msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n")
msg("Iniciando generación de animación multitemporal Día 09...")

# ------------------------------------------------------------------------------
# 1. Cargar Datos y Metadatos
# ------------------------------------------------------------------------------
d <- readRDS("data/processed/day09_urban_rural_dataset.rds")

metros     <- d$metros
df_metrics <- d$df_metrics
EPOCHS     <- d$epochs  # c(1975, 1985, 1995, 2005, 2015, 2025)

# Paleta Estilo Atlas
PAPEL    <- "#F7F4EB"
TINTA    <- "#0F172A"
TINTA2   <- "#334155"
GRIS_TXT <- "#475569"
MARCO    <- "#94A3B8"
FUENTE   <- "Georgia"

# Cargar capas base (USV) y series temporales para las 6 metrópolis
msg("Preprocesando datos espaciales para los fotogramas de animación...")

metro_data <- list()

for (i in seq_along(metros)) {
  m_id <- names(metros)[i]
  m    <- metros[[m_id]]
  met  <- df_metrics %>% filter(id == m_id)
  
  usv_path <- file.path("data/processed/day09_metros", paste0(m_id, "_usv.tif"))
  usv <- rast(usv_path)
  
  # Cargar primer ráster para referencia espacial
  r_ref <- rast(file.path("data/processed/day09_metros", paste0(m_id, "_ghsl_2025.tif")))
  usv_r <- resample(usv, r_ref, method = "near")
  
  df_usv <- as.data.frame(usv_r, xy = TRUE)
  names(df_usv)[3] <- "cls"
  df_usv$categoria <- factor(
    case_when(
      df_usv$cls %in% c(1, 2) ~ "Bosque / Selva / Matorral",
      df_usv$cls == 3         ~ "Suelo Agrícola / Rural",
      df_usv$cls == 4         ~ "Cuerpos de Agua",
      TRUE                    ~ "Área Desprovista"
    ),
    levels = c("Bosque / Selva / Matorral", "Suelo Agrícola / Rural", "Cuerpos de Agua", "Área Desprovista")
  )
  
  # Cargar cada época como data.frame de celdas urbanas
  epoch_dfs <- list()
  area_km2_epoch <- list()
  
  cell_area_km2 <- as.numeric(mean(values(cellSize(r_ref, unit = "m") / 1e6), na.rm = TRUE))
  
  for (ep in EPOCHS) {
    r_ep <- rast(file.path("data/processed/day09_metros", paste0(m_id, "_ghsl_", ep, ".tif")))
    df_ep <- as.data.frame(r_ep, xy = TRUE)
    names(df_ep)[3] <- "val"
    df_ep_urb <- df_ep %>% filter(val >= 500)
    epoch_dfs[[as.character(ep)]] <- df_ep_urb
    area_km2_epoch[[as.character(ep)]] <- round(nrow(df_ep_urb) * cell_area_km2, 1)
  }
  
  metro_data[[m_id]] <- list(
    m = m,
    num = i,
    df_usv = df_usv,
    epochs = epoch_dfs,
    areas = area_km2_epoch,
    area_1975 = area_km2_epoch[["1975"]]
  )
}

# ------------------------------------------------------------------------------
# 2. Renderizado de cada Fotograma (Cuadrícula 3x2 por Época)
# ------------------------------------------------------------------------------
msg("Renderizando fotogramas...")

# Definir la secuencia de fotogramas con pausas al inicio y final
# Repetir 1975 al inicio (3 fotogramas) y 2025 al final (6 fotogramas)
frame_sequence <- c(
  rep(1975, 3),
  1985, 1985,
  1995, 1995,
  2005, 2005,
  2015, 2015,
  rep(2025, 6)
)

frame_files <- character(length(frame_sequence))

for (f_idx in seq_along(frame_sequence)) {
  current_year <- frame_sequence[f_idx]
  msg("Fotograma ", sprintf("%02d/%02d", f_idx, length(frame_sequence)), " — Año: ", current_year)
  
  # Construir los 6 paneles para este fotograma
  panels <- list()
  
  for (m_id in names(metro_data)) {
    md   <- metro_data[[m_id]]
    m    <- md$m
    i    <- md$num
    df_u <- md$epochs[[as.character(current_year)]]
    
    # Huella histórica consolidada (de 1975)
    df_u75 <- md$epochs[["1975"]]
    
    # Frente nuevo expandido hasta este año (excluyendo el núcleo de 1975 si año > 1975)
    area_act <- md$areas[[as.character(current_year)]]
    area_75  <- md$area_1975
    pct_crec <- round(((area_act - area_75) / max(1, area_75)) * 100, 1)
    
    txt_badge <- if (current_year == 1975) {
      sprintf("AÑO: %d | Superficie: %s km² (Línea base)", current_year, format(area_act, big.mark = ","))
    } else {
      sprintf("AÑO: %d | Superficie: %s km² (+%s%% desde 1975)", current_year, format(area_act, big.mark = ","), format(pct_crec, big.mark = ","))
    }
    
    p_sub <- ggplot() +
      # Fondo ecológico y rural
      geom_raster(data = md$df_usv, aes(x = x, y = y, fill = categoria)) +
      scale_fill_manual(
        values = c(
          "Bosque / Selva / Matorral" = "#1B4332",
          "Suelo Agrícola / Rural"    = "#E9DFC8",
          "Cuerpos de Agua"           = "#A5C4D4",
          "Área Desprovista"          = "#D3CCC1"
        ),
        guide = "none"
      ) +
      # Expansión urbana acumulada hasta el año actual (Carmín / Fuego)
      geom_tile(data = df_u, aes(x = x, y = y), fill = "#EF4444", alpha = 0.90) +
      # Núcleo urbano histórico original de 1975 (Pizarra grafito)
      geom_tile(data = df_u75, aes(x = x, y = y), fill = "#1E293B", alpha = 0.95) +
      coord_equal(expand = FALSE) +
      labs(
        title = paste0(i, ". ", m$nombre, " (", m$subtitulo, ")"),
        subtitle = paste0(m$ecosistema, "\n", txt_badge)
      ) +
      theme_void(base_family = FUENTE) +
      theme(
        plot.title = element_text(size = 11, face = "bold", color = TINTA, margin = margin(t = 3, b = 2)),
        plot.subtitle = element_text(size = 8.4, color = TINTA2, lineheight = 1.15, margin = margin(b = 4)),
        panel.border = element_rect(color = MARCO, fill = NA, linewidth = 0.6),
        plot.background = element_rect(fill = PAPEL, color = NA),
        plot.margin = margin(5, 5, 5, 5)
      )
    
    panels[[m_id]] <- p_sub
  }
  
  # Encabezado animado con el año gigante
  header_anim <- ggplot() +
    annotate(
      "text", x = 0, y = 1.05,
      label = "30DAYMAPCHALLENGE 2026  ·  DÍA 09: URBAN-RURAL  ·  EVOLUCIÓN MULTITEMPORAL",
      family = FUENTE, fontface = "bold", size = 3.6, color = "#B91C1C", hjust = 0
    ) +
    annotate(
      "text", x = 0, y = 0.65,
      label = "LA FRONTERA QUE DEVORA EL BOSQUE",
      family = FUENTE, fontface = "bold", size = 8.5, color = TINTA, hjust = 0
    ) +
    annotate(
      "text", x = 0, y = 0.28,
      label = "50 años de expansión metropolitana sobre ecosistemas y tierras rurales (1975–2025)",
      family = FUENTE, fontface = "italic", size = 4.6, color = TINTA2, hjust = 0
    ) +
    # Badge con el año actual en grande
    annotate(
      "rect", xmin = 0.82, xmax = 0.99, ymin = 0.25, ymax = 1.10,
      fill = "#EF4444", color = TINTA, linewidth = 0.6
    ) +
    annotate(
      "text", x = 0.905, y = 0.68,
      label = as.character(current_year),
      family = FUENTE, fontface = "bold", size = 9.0, color = "#FFFFFF", hjust = 0.5
    ) +
    xlim(0, 1) + ylim(0, 1.25) +
    theme_void() +
    theme(plot.margin = margin(8, 14, 4, 14))
  
  # Barra de leyenda
  legend_anim <- ggplot() +
    annotate("rect", xmin = 0.02, xmax = 0.05, ymin = 0.2, ymax = 0.8, fill = "#1E293B", color = NA) +
    annotate("text", x = 0.065, y = 0.5, label = "Huella Urbana 1975", family = FUENTE, size = 3.4, color = TINTA, hjust = 0) +
    annotate("rect", xmin = 0.28, xmax = 0.31, ymin = 0.2, ymax = 0.8, fill = "#EF4444", color = NA) +
    annotate("text", x = 0.325, y = 0.5, label = paste0("Frente de Expansión Urbana (1975 → ", current_year, ")"), family = FUENTE, size = 3.4, color = TINTA, fontface = "bold", hjust = 0) +
    annotate("rect", xmin = 0.62, xmax = 0.65, ymin = 0.2, ymax = 0.8, fill = "#1B4332", color = NA) +
    annotate("text", x = 0.665, y = 0.5, label = "Bosque / Selva / Matorral", family = FUENTE, size = 3.4, color = TINTA, hjust = 0) +
    annotate("rect", xmin = 0.83, xmax = 0.86, ymin = 0.2, ymax = 0.8, fill = "#E9DFC8", color = "#CBD5E1") +
    annotate("text", x = 0.875, y = 0.5, label = "Suelo Agrícola / Rural", family = FUENTE, size = 3.4, color = TINTA, hjust = 0) +
    xlim(0, 1) + ylim(0, 1) +
    theme_void() +
    theme(plot.margin = margin(2, 14, 4, 14))
  
  # Pie de figura
  caption_anim <- ggplot() +
    annotate(
      "text", x = 0, y = 0.5,
      label = "#30DayMapChallenge 2026 | Día 09: Urban-rural — Datos: Global Human Settlement Layer (GHSL JRC) & INEGI USV | Gráfico: Fernando Dorantes Nieto (@FerDoranNie)",
      family = FUENTE, size = 3.0, color = GRIS_TXT, hjust = 0
    ) +
    xlim(0, 1) + ylim(0, 1) +
    theme_void() +
    theme(plot.margin = margin(2, 14, 6, 14))
  
  grid_panels <- (panels[[1]] | panels[[2]] | panels[[3]]) /
                 (panels[[4]] | panels[[5]] | panels[[6]])
  
  frame_plot <- (header_anim / legend_anim / grid_panels / caption_anim) +
    plot_layout(heights = c(0.12, 0.04, 0.80, 0.04)) &
    theme(plot.background = element_rect(fill = PAPEL, color = NA))
  
  frame_path <- file.path(dir_frames, sprintf("frame_%03d.png", f_idx))
  frame_files[f_idx] <- frame_path
  
  agg_png(
    filename = frame_path,
    width    = 15,
    height   = 14,
    units    = "in",
    res      = 120
  )
  print(frame_plot)
  dev.off()
}

# ------------------------------------------------------------------------------
# 3. Ensamblado en GIF y MP4
# ------------------------------------------------------------------------------
GIF_OUT <- "outputs/gallery/day09_urban_rural_expansion.gif"
MP4_OUT <- "outputs/gallery/day09_urban_rural_expansion.mp4"

msg("Generando GIF animado optimizado: ", GIF_OUT)
gifski(
  png_files = frame_files,
  gif_file  = GIF_OUT,
  width     = 1800,
  height    = 1680,
  delay     = 0.65,
  loop      = TRUE
)
msg("Tamaño del GIF generado: ", format(round(file.info(GIF_OUT)$size / 1e6, 2)), " MB")

msg("Generando video MP4 de alta definición: ", MP4_OUT)
av_encode_video(
  input  = frame_files,
  output = MP4_OUT,
  framerate = 2
)
msg("Tamaño del MP4 generado: ", format(round(file.info(MP4_OUT)$size / 1e6, 2)), " MB")

msg("¡Animación completada exitosamente en ", format(round(Sys.time() - t0, 1)), "!")
