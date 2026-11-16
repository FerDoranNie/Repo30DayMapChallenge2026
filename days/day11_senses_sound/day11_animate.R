# ==============================================================================
# Día 11 — Senses: Sound (Animación de la Ola Acústica del Amanecer)
# "El coro del amanecer en México: La ola acústica de las aves del Caribe al Pacífico"
#
# Requiere: data/processed/day11_soundscape_mexico.rds
# Salidas:  outputs/gallery/day11_senses_sound_amanecer.gif
#           outputs/gallery/day11_senses_sound_amanecer.mp4
# Autor:    Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
suppressPackageStartupMessages({
  library(sf)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(patchwork)
  library(scales)
  library(ragg)
  library(gifski)
  library(av)
})

sf_use_s2(FALSE)
source("utils/theme_map2026.R")

t0 <- Sys.time()
msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n")
msg("Iniciando renderizado de la animación bioacústica del Día 11...")

# Paleta Editorial — Estilo Atlas Enmarcado (AGENTS.md)
CREAM  <- "#F7F4EB"
OCEAN  <- "#DCE6F2"
PANEL  <- "#FBF9F3"
INK    <- "#0F172A"
SLATE  <- "#334155"
MUTED  <- "#475569"
BORDER <- "#94A3B8"
NAVY   <- "#24344D"
NAVY_D <- "#162235"
DIV_ST <- "#435B7D"

FREQ_PALETTE <- c(
  "#4C1D95", # 1.2 kHz - Graves profundos (búhos, crácidos, palomas, trogones)
  "#6D28D9", # 2.0 kHz - Graves de sotobosque
  "#2563EB", # 2.7 kHz - Medios-graves (momotos, tucanes, trepatroncos)
  "#06B6D4", # 3.3 kHz - Medios puros (mirlos, matracas, cuitlacoches)
  "#10B981", # 3.9 kHz - Medios-altos (clarines, tiranos, ictéridos)
  "#F59E0B", # 4.7 kHz - Agudos (pinzones, gorriones, pirangas)
  "#FDE047"  # 5.8+ kHz - Ultra-agudos (chipes/parúlidos y colibríes)
)

ds <- readRDS("data/processed/day11_soundscape_mexico.rds")
snd_df     <- ds$snd_df
hex_sf_wgs <- ds$hex_sf_wgs
mx_states  <- ds$mx_states
mx_border  <- ds$mx_border

hex_valid <- hex_sf_wgs |>
  filter(!is.na(mean_freq_khz), n_rec >= 1) |>
  mutate(
    freq_clipped = pmin(5.6, pmax(1.5, mean_freq_khz))
  )

# Preparar muestra estratificada de sitios vocales (~3,500 nodos espaciales únicos)
# para que las ondas concéntricas se dibujen con nitidez sin saturar la memoria
set.seed(20261111)
vocal_nodes <- snd_df |>
  mutate(
    lon_r = round(lon, 2),
    lat_r = round(lat, 2),
    freq_clipped = pmin(5.6, pmax(1.5, freq_khz))
  ) |>
  group_by(lon_r, lat_r) |>
  summarise(
    lon = mean(lon),
    lat = mean(lat),
    n_rec_loc = n(),
    species_top = first(species),
    family_top  = first(family),
    freq_khz    = mean(freq_khz, na.rm = TRUE),
    freq_clipped = mean(freq_clipped, na.rm = TRUE),
    is_nocturnal = any(diel_guild == "Coro Nocturno y Crepuscular"),
    dawn_delay_min = mean(dawn_delay_min, na.rm = TRUE),
    .groups = "drop"
  )

msg("Nodos bioacústicos únicos preparados para animación:", nrow(vocal_nodes))

# Definir 16 bandas de frecuencia (de 1.0 a 7.0 kHz) para el ecualizador / espectrograma inferior
freq_breaks <- seq(0.8, 7.2, length.out = 17)
freq_mids   <- 0.5 * (freq_breaks[-1] + freq_breaks[-length(freq_breaks)])
snd_df$f_bin <- cut(pmin(7.1, pmax(0.85, snd_df$freq_khz)), breaks = freq_breaks, labels = FALSE, include.lowest = TRUE)

# Regiones que el frente del amanecer va despertando según el minuto solar (t_min)
get_region_stage <- function(t_min) {
  if (t_min < 0) {
    list(
      region = "Noche Pre-Alba en todo México (Coro Nocturno activo)",
      especies = "Tecolote Bajeño (Glaucidium brasilianum), Búho Café (Ciccaba virgata), Tapacaminos (Nyctidromus albicollis)"
    )
  } else if (t_min <= 15) {
    list(
      region = "1. Caribe Mexicano, Cozumel y Selva Maya Oriental (Quintana Roo y Yucatán)",
      especies = "Momoto Corona Azul (Momotus lessonii), Chara Yucateca (Cyanocorax yucatanicus), Chipe Amarillo (Setophaga petechia)"
    )
  } else if (t_min <= 35) {
    list(
      region = "2. Selva Lacandona, Campeche, Tabasco y Los Chimalapas (Chiapas / Istmo)",
      especies = "Tinamú Mayor (Tinamus major, 1.4 kHz), Hocofaisán (Crax rubra), Trogón Violáceo y Mirlo Pardo (Turdus grayi)"
    )
  } else if (t_min <= 52) {
    list(
      region = "3. Bosque Mesófilo de Veracruz, Sierra Norte de Oaxaca y Eje Neovolcánico Oriental",
      especies = "Clarín Jilguero (Myadestes occidentalis, 4.1 kHz), Zacua Mayor (Psarocolius montezuma), Chipe Gorra Canela"
    )
  } else if (t_min <= 72) {
    list(
      region = "4. Valle de México, Bajío, Sierra Madre del Sur y Sierra Madre Oriental (Nuevo León / Tamaulipas)",
      especies = "Pinzón Mexicano (Haemorhous mexicanus, 4.5 kHz), Mulato Azul (Melanotis caerulescens), Colibrí Berilo (6.8 kHz)"
    )
  } else if (t_min <= 95) {
    list(
      region = "5. Cañones de la Sierra Madre Occidental, Costa de Jalisco–Sinaloa y Desierto Chihuahuense",
      especies = "Saltapared Barranquero (Catherpes mexicanus, 3.8 kHz), Mirlo Dorso Rufo (Turdus rufopalliatus), Rascador Viejita"
    )
  } else {
    list(
      region = "6. Desierto Sonorense, Golfo de California y Península de Baja California (Tijuana / Ensenada)",
      especies = "Matraca del Desierto (Campylorhynchus brunneicapillus, 3.3 kHz), Colibrí Pico Ancho y Gorriones Áridos (5.2 kHz)"
    )
  }
}

# Secuencia temporal de la animación:
# t_min va desde -12 min (05:48 AM CDMX, antes de tocar Isla Mujeres)
# hasta +132 min (08:12 AM CDMX, cuando el sol ya cubrió Tijuana en +121.6 min).
# Usamos 76 pasos + 8 cuadros de pausa al final = 84 fotogramas a 12 fps (~7.0 segundos)
t_seq_main <- seq(-12, 132, length.out = 76)
t_sequence <- c(rep(-12, 3), t_seq_main, rep(132, 7))
n_frames   <- length(t_sequence)

dir_frames <- file.path(tempdir(), "day11_sound_frames")
unlink(dir_frames, recursive = TRUE)
dir.create(dir_frames, recursive = TRUE, showWarnings = FALSE)

# Capas base fijas de estados y frontera para acelerar el loop
isochrones_bg <- tibble(
  delay_min = seq(0, 120, by = 15),
  lon       = -86.70 - (seq(0, 120, by = 15) / 4.0)
) |>
  mutate(
    lbl = sprintf("+%d min", delay_min)
  )

frame_files <- character(n_frames)

for (i in seq_len(n_frames)) {
  t_now <- t_sequence[i]
  # Longitud exacta del terminador solar en este minuto:
  lon_term <- -86.70 - (t_now / 4.0)
  
  # Reloj hora del Centro de México (06:00 h corresponde a t_now = 0 en Isla Mujeres)
  total_min_cdmx <- round(6 * 60 + t_now)
  hh_cdmx <- (total_min_cdmx %/% 60) %% 24
  mm_cdmx <- total_min_cdmx %% 60
  clock_str <- sprintf("%02d:%02d h (UTC-6)", hh_cdmx, mm_cdmx)
  delay_str <- if (t_now < 0) sprintf("Alba %+d min", round(t_now)) else sprintf("+%03d min desde el Caribe", round(min(122, t_now)))
  
  stage_info <- get_region_stage(t_now)
  
  # 1. Hexágonos ya iluminados por el sol (dawn_delay_min <= t_now + 4)
  hex_lit <- hex_valid |> filter(mean_dawn_min <= t_now + 3)
  
  # 2. Nodos ya despiertos (estela acumulada)
  nodes_awake <- vocal_nodes |> filter(dawn_delay_min <= t_now)
  
  # 3. Nodos resonando activamente en el frente del amanecer (entre t_now - 18 y t_now + 2 min)
  #    Emiten ondas concéntricas expansivas cuyo radio crece con (t_now - dawn_delay_min)
  nodes_ring <- vocal_nodes |>
    mutate(age = t_now - dawn_delay_min) |>
    filter(age >= -1.5, age <= 18.0) |>
    mutate(
      ring_progress = pmax(0, age / 18.0),
      ring_size     = 1.8 + 8.5 * ring_progress,
      ring_alpha    = pmax(0.08, (1 - ring_progress)^1.35 * 0.85)
    )
  
  # 4. Nodos del Coro Nocturno activos en la zona oscura al oeste del terminador (lon < lon_term)
  nodes_night <- vocal_nodes |>
    filter(is_nocturnal, dawn_delay_min > t_now)
  
  # Conteo acumulado de grabaciones y especies despertadas hasta t_now
  rec_awake_df <- snd_df |> filter(dawn_delay_min <= t_now)
  n_rec_awake  <- nrow(rec_awake_df)
  n_sp_awake   <- n_distinct(rec_awake_df$species)
  pct_awake    <- round(100 * n_rec_awake / nrow(snd_df), 1)
  
  # Construir el mapa del fotograma
  p_map <- ggplot() +
    geom_sf(data = mx_border, fill = NAVY_D, color = NAVY_D, linewidth = 0.5) +
    geom_sf(data = mx_states, fill = NAVY, color = DIV_ST, linewidth = 0.20) +
    # Hexágonos ya alcanzados por la ola del amanecer
    geom_sf(
      data = hex_lit,
      aes(fill = freq_clipped),
      color = alpha("#0F172A", 0.30),
      linewidth = 0.10,
      alpha = 0.65,
      show.legend = FALSE
    ) +
    # Sombra nocturna sobre la región aún en penumbra (al oeste del terminador solar)
    annotate(
      "rect",
      xmin = -118.4, xmax = max(-118.4, min(-85.8, lon_term)),
      ymin = 14.1, ymax = 32.9,
      fill = "#090E1A", alpha = 0.52
    ) +
    # Banda dorada crepuscular en el frente exacto del terminador solar (ancho ~3.5°)
    annotate(
      "rect",
      xmin = max(-118.4, min(-85.8, lon_term - 1.8)),
      xmax = max(-118.4, min(-85.8, lon_term + 1.8)),
      ymin = 14.1, ymax = 32.9,
      fill = "#F59E0B", alpha = 0.16
    ) +
    # Isócronas cada 15 minutos
    geom_vline(
      data = isochrones_bg, aes(xintercept = lon),
      linetype = "dotted", color = alpha("#475569", 0.50), linewidth = 0.30
    ) +
    geom_text(
      data = isochrones_bg, aes(x = lon, y = 32.45, label = lbl),
      size = 2.4, fontface = "bold", color = SLATE
    ) +
    # Pulsos violáceos del Coro Nocturno en la zona aún oscura
    geom_point(
      data = nodes_night,
      aes(x = lon, y = lat),
      color = "#818CF8", size = 1.35, alpha = 0.65
    ) +
    # Estela de puntos ya despiertos
    geom_point(
      data = nodes_awake,
      aes(x = lon, y = lat, color = freq_clipped),
      size = 0.85, alpha = 0.65, show.legend = FALSE
    ) +
    # Ondas acústicas concéntricas expansivas en el frente del amanecer
    geom_point(
      data = nodes_ring,
      aes(x = lon, y = lat, color = freq_clipped, size = ring_size, alpha = ring_alpha),
      shape = 21, fill = NA, stroke = 0.95, show.legend = FALSE
    ) +
    geom_point(
      data = nodes_ring |> filter(ring_progress < 0.35),
      aes(x = lon, y = lat, color = freq_clipped),
      size = 1.9, alpha = 0.95, show.legend = FALSE
    ) +
    # Línea brillante del Terminador Solar del Amanecer
    geom_vline(
      xintercept = max(-118.2, min(-86.0, lon_term)),
      color = "#F59E0B", linewidth = 1.15, alpha = 0.92
    ) +
    # Etiqueta móvil del Terminador Solar
    annotate(
      "label",
      x = max(-115.5, min(-88.5, lon_term)),
      y = 14.85,
      label = sprintf("☀ FRENTE SOLAR: %.1f° W (%s)", abs(max(-117.2, min(-86.7, lon_term))), clock_str),
      fill = "#FEF3C7", color = "#92400E", size = 2.85, fontface = "bold",
      label.size = 0.35
    ) +
    # Cartela inferior izquierda con métricas en vivo
    annotate(
      "rect", xmin = -117.9, xmax = -101.8, ymin = 15.65, ymax = 21.45,
      fill = alpha(PANEL, 0.94), color = BORDER, linewidth = 0.45
    ) +
    annotate(
      "text", x = -117.4, y = 20.85,
      label = "ESTADO EN VIVO DE LA OLA ACÚSTICA",
      hjust = 0, size = 2.85, fontface = "bold", color = INK
    ) +
    annotate(
      "text", x = -117.4, y = 19.75,
      label = sprintf("• Reloj (Centro de México): %s  |  %s", clock_str, delay_str),
      hjust = 0, size = 2.55, fontface = "bold", color = "#B45309"
    ) +
    annotate(
      "text", x = -117.4, y = 18.75,
      label = sprintf("• Aves despertadas: %s especies  |  %s grabaciones (%s%%)",
                      comma(n_sp_awake), comma(n_rec_awake), pct_awake),
      hjust = 0, size = 2.50, fontface = "bold", color = INK
    ) +
    annotate(
      "text", x = -117.4, y = 17.65,
      label = paste0("• Región en resonancia: ", stage_info$region),
      hjust = 0, size = 2.30, fontface = "bold", color = SLATE
    ) +
    annotate(
      "text", x = -117.4, y = 16.50,
      label = paste0("• Solistas activos: ", stage_info$especies),
      hjust = 0, size = 2.15, fontface = "italic", color = MUTED
    ) +
    scale_fill_gradientn(colours = FREQ_PALETTE, limits = c(1.5, 5.6)) +
    scale_color_gradientn(colours = FREQ_PALETTE, limits = c(1.5, 5.6)) +
    scale_size_identity() +
    scale_alpha_identity() +
    coord_sf(xlim = c(-118.4, -85.8), ylim = c(14.1, 32.9), expand = FALSE) +
    theme_map2026(base_size = 10) +
    theme(
      panel.background = element_rect(fill = OCEAN, color = BORDER, linewidth = 0.6),
      plot.margin = margin(2, 10, 2, 10)
    )
  
  # 5. Panel Inferior: Ecualizador / Espectrograma Bioacústico en Vivo (1.0 a 7.0 kHz)
  #    Calcula la energía acústica en cada una de las 16 bandas de frecuencia en la ventana activa
  win_df <- snd_df |>
    mutate(age = t_now - dawn_delay_min) |>
    filter(
      (age >= -2 & age <= 20) |
        (diel_guild == "Coro Nocturno y Crepuscular" & age < -2 & age >= -35)
    )
  
  eq_counts <- win_df |>
    count(f_bin, name = "n_active") |>
    right_join(tibble(f_bin = 1:16, freq_mid = freq_mids), by = "f_bin") |>
    mutate(
      n_active = replace_na(n_active, 0L),
      # Energía normalizada (0 a 100) con pequeño pulso armónico para fluidez visual
      energy = pmin(100, 12 * sqrt(n_active) + ifelse(n_active > 0, 6 * abs(sin(i * 0.45 + f_bin * 0.7)), 2.5)),
      freq_clipped = pmin(5.6, pmax(1.5, freq_mid))
    )
  
  p_eq <- ggplot(eq_counts, aes(x = freq_mid, y = energy, fill = freq_clipped)) +
    geom_col(width = 0.34, color = "#0F172A", linewidth = 0.25, alpha = 0.92) +
    scale_fill_gradientn(
      colours = FREQ_PALETTE,
      limits = c(1.5, 5.6),
      breaks = c(1.6, 2.6, 3.6, 4.6, 5.5),
      labels = c("1.6 kHz (Graves: Búhos/Selva)", "2.6 kHz", "3.6 kHz (Mirlos/Matracas)", "4.6 kHz", "5.5+ kHz (Agudos: Chipes/Colibríes)"),
      name = "Frecuencia Fundamental (kHz)"
    ) +
    scale_x_continuous(
      breaks = seq(1, 7, by = 0.5),
      labels = function(x) sprintf("%.1f kHz", x),
      limits = c(0.7, 7.3), expand = c(0.01, 0.01)
    ) +
    scale_y_continuous(
      limits = c(0, 105),
      breaks = c(0, 50, 100),
      labels = c("0%", "50%", "100%"),
      expand = c(0, 0)
    ) +
    labs(
      title = "ESPECTROGRAMA / ECUALIZADOR EN VIVO DEL FRENTE DEL AMANECER (1.0 – 7.0 kHz)",
      x = "Banda de Frecuencia Fundamental (kHz): Graves de Selva y Noche (Izquierda) ───▶ Agudos de Montaña, Dosel y Desierto (Derecha)",
      y = "Intensidad"
    ) +
    theme_map2026(base_size = 9) +
    theme(
      panel.background = element_rect(fill = NAVY_D, color = BORDER, linewidth = 0.5),
      plot.title = element_text(size = 9.8, face = "bold", color = INK, margin = margin(t = 2, b = 2)),
      axis.text.x = element_text(size = 7.5, face = "bold", color = INK),
      axis.text.y = element_text(size = 7.0, color = SLATE),
      axis.title.x = element_text(size = 8.0, face = "bold", color = INK, margin = margin(t = 3)),
      axis.title.y = element_text(size = 7.8, face = "bold", color = INK, angle = 90, margin = margin(r = 4)),
      panel.grid.major.y = element_line(color = alpha("#94A3B8", 0.22), linewidth = 0.25),
      legend.position = "bottom",
      legend.title = element_text(size = 7.8, face = "bold", color = INK),
      legend.text = element_text(size = 7.0, color = SLATE),
      legend.margin = margin(t = 1, b = 1),
      plot.margin = margin(2, 10, 2, 10)
    ) +
    guides(
      fill = guide_colorbar(
        title.position = "left", title.vjust = 0.8,
        barwidth = unit(11, "cm"), barheight = unit(0.32, "cm"),
        frame.colour = INK, ticks.colour = INK
      )
    )
  
  frame_comp <- (p_map / p_eq) +
    plot_layout(heights = c(3.25, 1.0)) +
    plot_annotation(
      title = "EL CORO DEL AMANECER EN MÉXICO: LA OLA ACÚSTICA DEL CARIBE AL PACÍFICO",
      subtitle = "Avance real del terminador solar (3,200 km en 2 h 02 min) despertando 38,353 grabaciones de cantos de 882 especies de aves",
      caption = "#30DayMapChallenge 2026 | Día 11: Senses: Sound — Datos: Xeno-canto, iNaturalist / Naturalista & Borror Lab vía GBIF | Gráfico: Fernando Dorantes Nieto (@FerDoranNie)",
      theme = theme(
        plot.background = element_rect(fill = CREAM, color = NA),
        plot.title = element_text(size = 15.5, face = "bold", color = INK, hjust = 0.5, margin = margin(t = 6, b = 2)),
        plot.subtitle = element_text(size = 9.2, color = SLATE, hjust = 0.5, margin = margin(b = 4)),
        plot.caption = element_text(size = 7.2, color = MUTED, hjust = 0, margin = margin(t = 4, b = 4)),
        plot.margin = margin(4, 8, 4, 8)
      )
    ) &
    theme(plot.background = element_rect(fill = CREAM, color = NA))
  
  f_path <- file.path(dir_frames, sprintf("frame_%03d.png", i))
  frame_files[i] <- f_path
  
  agg_png(f_path, width = 14.0, height = 10.5, units = "in", res = 100, background = CREAM)
  print(frame_comp)
  dev.off()
  
  if (i %% 12 == 0 || i == n_frames) {
    msg(sprintf("  Fotograma %02d/%02d renderizado (%s)", i, n_frames, clock_str))
  }
}

dir.create("outputs/gallery", recursive = TRUE, showWarnings = FALSE)
gif_out <- "outputs/gallery/day11_senses_sound_amanecer.gif"
mp4_out <- "outputs/gallery/day11_senses_sound_amanecer.mp4"

msg("Ensamblando animación GIF con gifski:", gif_out)
gifski(
  png_files = frame_files,
  gif_file  = gif_out,
  width     = 1400,
  height    = 1050,
  delay     = 1 / 12,
  loop      = TRUE,
  progress  = FALSE
)
msg(sprintf("GIF generado: %s (%.2f MB)", gif_out, file.info(gif_out)$size / 1e6))

msg("Codificando video MP4 con av:", mp4_out)
av_encode_video(
  input     = frame_files,
  output    = mp4_out,
  framerate = 12,
  verbose   = FALSE
)
msg(sprintf("MP4 generado: %s (%.2f MB)", mp4_out, file.info(mp4_out)$size / 1e6))
msg("¡Animación del Día 11 completada exitosamente en", format(round(Sys.time() - t0, 1)), "!")
