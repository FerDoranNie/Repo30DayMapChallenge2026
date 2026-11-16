# ==============================================================================
# Día 11 — Senses: Sound (Póster Cartográfico Editorial)
# "El coro del amanecer en México: La ola acústica de las aves del Caribe al Pacífico"
#
# Requiere: data/processed/day11_soundscape_mexico.rds
# Salidas:  outputs/high_res/day11_senses_sound_coro_amanecer.png (300 dpi)
#           outputs/gallery/day11_senses_sound_coro_amanecer.png  (150 dpi)
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
})

sf_use_s2(FALSE)
source("utils/theme_map2026.R")

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

# Paleta Bioacústica de Frecuencias (kHz):
# Graves profundos (<2.2 kHz: púrpura/violeta) -> Medios (3.0-4.2 kHz: turquesa/esmeralda) -> Agudos (>4.8 kHz: ámbar/oro solar)
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

snd_df      <- ds$snd_df
hex_sf_wgs  <- ds$hex_sf_wgs
mx_states   <- ds$mx_states
mx_border   <- ds$mx_border
diel_curve  <- ds$diel_curve
morton_df   <- ds$morton_biome_summary
top_sp      <- ds$top_species_nat

# ==============================================================================
# PANEL A: Mapa Nacional del Paisaje Bioacústico y la Ola del Amanecer
# ==============================================================================
hex_valid <- hex_sf_wgs |>
  filter(!is.na(mean_freq_khz), n_rec >= 1) |>
  mutate(
    freq_clipped = pmin(5.6, pmax(1.5, mean_freq_khz))
  )

pts_plot <- snd_df |>
  mutate(freq_clipped = pmin(5.6, pmax(1.5, freq_khz))) |>
  arrange(freq_clipped)

# Isócronas del amanecer cada 15 minutos desde Isla Mujeres (-86.70° W)
isochrones_df <- tibble(
  delay_min = seq(0, 120, by = 15),
  lon       = -86.70 - (seq(0, 120, by = 15) / 4.0)
) |>
  mutate(
    hora_cdmx = sprintf("%02d:%02d", 6 + (delay_min %/% 60), delay_min %% 60),
    lbl_top   = sprintf("+%d min\n(%s h)", delay_min, hora_cdmx)
  )

# 6 Polos Bioacústicos de México
hotspots_sound <- tibble::tribble(
  ~id, ~lon,    ~lat,   ~titulo,                                      ~detalle,
  1L,  -87.05,  20.65,  "1. Costa Maya y Cozumel (+0 a +8 min)",      "Primer canto (06:00 h) · Momotos y chipes (3.4 kHz)",
  2L,  -91.15,  16.55,  "2. Selva Lacandona y Chimalapas (+18 min)",  "Graves profundos (2.8–3.2 kHz): Tinamidae y Cracidae",
  3L,  -96.95,  19.15,  "3. Bosque Mesófilo de Veracruz (+41 min)",   "Máx. riqueza: 196 spp./celda (Clarín Jilguero, 4.1 kHz)",
  4L,  -99.20,  19.35,  "4. Eje Neovolcánico y Valle de México (+50m)","Pinzones, colibríes (6.8 kHz) y mirlos en cañadas",
  5L, -105.75,  23.75,  "5. Cañones Sierra Madre Occidental (+76 min)","Eco en barrancas: Saltapared Barranquero (3.8 kHz)",
  6L, -111.50,  29.30,  "6. Desierto Sonorense y Baja Cal. (+100 min)","Frente árido: Matraca del Desierto y gorriones (4.5 kHz)"
)

cartela_a <- hotspots_sound |>
  mutate(
    x_pt = -117.55,
    y_pt = seq(19.05, 14.70, length.out = n())
  )

pA <- ggplot() +
  geom_sf(data = mx_border, fill = "#94A3B8", color = NA, alpha = 0.35) +
  geom_sf(data = mx_border, fill = NAVY_D, color = NAVY_D, linewidth = 0.6) +
  geom_sf(data = mx_states, fill = NAVY, color = DIV_ST, linewidth = 0.22) +
  geom_sf(
    data = hex_valid,
    aes(fill = freq_clipped),
    color = alpha("#0F172A", 0.35),
    linewidth = 0.12,
    alpha = 0.88
  ) +
  geom_point(
    data = pts_plot,
    aes(x = lon, y = lat, color = freq_clipped),
    size = 0.42, alpha = 0.38, show.legend = FALSE
  ) +
  geom_sf(data = mx_states, fill = NA, color = alpha("#E2E8F0", 0.25), linewidth = 0.16) +
  geom_sf(data = mx_border, fill = NA, color = "#0F172A", linewidth = 0.55) +
  # Isócronas del amanecer cada 15 minutos
  geom_vline(
    data = isochrones_df,
    aes(xintercept = lon),
    linetype = "dashed", color = alpha("#0F172A", 0.42), linewidth = 0.32
  ) +
  geom_label(
    data = isochrones_df,
    aes(x = lon, y = 32.18, label = lbl_top),
    fill = alpha(PANEL, 0.92), color = INK, size = 1.98, fontface = "bold",
    label.size = 0.25, label.padding = unit(0.16, "lines"), lineheight = 0.94
  ) +
  # Flecha superior indicando dirección de la Ola del Amanecer (Este -> Oeste)
  annotate(
    "segment", x = -88.2, xend = -115.0, y = 31.08, yend = 31.08,
    colour = "#B45309", linewidth = 0.65,
    arrow = arrow(length = unit(0.22, "cm"), type = "closed")
  ) +
  annotate(
    "label", x = -101.6, y = 31.08,
    label = "◀── DIRECCIÓN DE LA OLA SOLAR DEL AMANECER (3,200 km · 4 min por cada 1° de longitud oeste) ──",
    fill = "#FEF3C7", color = "#92400E", size = 2.20, fontface = "bold",
    label.size = 0.25, label.padding = unit(0.18, "lines")
  ) +
  # Marcadores numerados de los 6 Polos Bioacústicos
  geom_point(
    data = hotspots_sound, aes(x = lon, y = lat),
    shape = 21, size = 5.4, fill = "#F59E0B", color = "#0F172A", stroke = 0.8
  ) +
  geom_text(
    data = hotspots_sound, aes(x = lon, y = lat, label = id),
    color = "#0F172A", size = 2.75, fontface = "bold"
  ) +
  # Cartela inferior izquierda compacta en el Pacífico (libre del contorno de México)
  annotate(
    "rect", xmin = -118.05, xmax = -105.75, ymin = 14.22, ymax = 19.95,
    fill = alpha(PANEL, 0.95), color = BORDER, linewidth = 0.40
  ) +
  annotate(
    "text", x = -117.75, y = 19.58,
    label = "POLOS BIOACÚSTICOS DEL AMANECER",
    hjust = 0, size = 2.15, fontface = "bold", color = INK
  ) +
  geom_point(
    data = cartela_a, aes(x = x_pt, y = y_pt),
    shape = 21, size = 3.3, fill = "#F59E0B", color = "#0F172A", stroke = 0.40
  ) +
  geom_text(
    data = cartela_a, aes(x = x_pt, y = y_pt, label = id),
    color = "#0F172A", size = 1.85, fontface = "bold"
  ) +
  geom_text(
    data = cartela_a, aes(x = x_pt + 0.40, y = y_pt + 0.14, label = titulo),
    hjust = 0, size = 1.92, fontface = "bold", color = INK
  ) +
  geom_text(
    data = cartela_a, aes(x = x_pt + 0.40, y = y_pt - 0.16, label = detalle),
    hjust = 0, size = 1.68, color = SLATE
  ) +
  # Recuadro de síntesis compacto en el Golfo de México (sin tocar Tamaulipas/Veracruz/Yucatán)
  annotate(
    "label", x = -91.85, y = 25.35,
    label = paste0(
      "GBIF Sound México: 38,353 grabaciones\n",
      "Muestra: 20,756 cantos · 882 spp. · 86 fam.\n",
      "Desfase Caribe → Pacífico: 2 h 02 min"
    ),
    fill = alpha(PANEL, 0.93), color = INK, size = 2.02, fontface = "bold",
    label.size = 0.30, label.padding = unit(0.30, "lines"), lineheight = 1.10
  ) +
  scale_fill_gradientn(
    colours = FREQ_PALETTE,
    limits = c(1.5, 5.6),
    breaks = c(1.6, 2.4, 3.2, 4.0, 4.7, 5.5),
    labels = c(
      "1.6 kHz\n(Búhos/Selva)",
      "2.4 kHz\n(Trogones)",
      "3.2 kHz\n(Mirlos/Matracas)",
      "4.0 kHz\n(Clarines/Tiranos)",
      "4.7 kHz\n(Pinzones)",
      "5.5+ kHz\n(Chipes/Colibríes)"
    ),
    name = "Frecuencia Fundamental Dominante del Ensamblaje Aviar (kHz)"
  ) +
  scale_color_gradientn(colours = FREQ_PALETTE, limits = c(1.5, 5.6), guide = "none") +
  coord_sf(xlim = c(-118.4, -85.8), ylim = c(14.1, 32.9), expand = FALSE) +
  labs(
    title = "A. Geografía Bioacústica de México e Isócronas de la Ola Solar del Amanecer",
    subtitle = paste0(
      "Frecuencia acústica media por hexágono (48 km, EPSG:6372) y 20,756 grabaciones puntuales superpuestas a las isócronas solares\n",
      "cada 15 minutos desde Isla Mujeres (86.7° W, +0 min) hasta Tijuana (117.1° W, +121.6 min)"
    )
  ) +
  theme_map2026(base_size = 10.5) +
  theme(
    panel.background = element_rect(fill = OCEAN, color = BORDER, linewidth = 0.6),
    plot.title = element_text(size = 13.6, face = "bold", margin = margin(t = 4, b = 3)),
    plot.subtitle = element_text(size = 8.2, color = SLATE, lineheight = 1.15, margin = margin(b = 6)),
    legend.position = "bottom",
    legend.title = element_text(size = 7.8, face = "bold", color = INK),
    legend.text = element_text(size = 6.8, color = SLATE),
    legend.margin = margin(t = 2, b = 2),
    plot.margin = margin(6, 8, 4, 8)
  ) +
  guides(
    fill = guide_colorbar(
      title.position = "top", title.hjust = 0.5,
      barwidth = unit(12.2, "cm"), barheight = unit(0.32, "cm"),
      frame.colour = INK, ticks.colour = INK
    )
  )

# ==============================================================================
# PANEL B: El Reloj Bioacústico — Pulso Horario del Coro del Amanecer vs. Coro Nocturno
# ==============================================================================
diel_plot_df <- diel_curve |>
  mutate(
    g_short = ifelse(
      grepl("Nocturno", guild_2),
      "Coro Nocturno y Crepuscular (Strigidae, Caprimulgidae, Nyctibiidae)",
      "Coro del Amanecer y Diurno (Passeriformes, Trochilidae, Trogonidae, etc.)"
    )
  )

DIEL_COLS <- c(
  "Coro del Amanecer y Diurno (Passeriformes, Trochilidae, Trogonidae, etc.)" = "#D97706",
  "Coro Nocturno y Crepuscular (Strigidae, Caprimulgidae, Nyctibiidae)"       = "#4F46E5"
)

pB <- ggplot(diel_plot_df, aes(x = hour_bin, y = pct_smooth, fill = g_short, color = g_short)) +
  annotate(
    "rect", xmin = 5.5, xmax = 9.5, ymin = 0, ymax = 10.2,
    fill = "#FEF3C7", alpha = 0.75
  ) +
  annotate(
    "rect", xmin = 0, xmax = 5.5, ymin = 0, ymax = 10.2,
    fill = "#EDE9FE", alpha = 0.45
  ) +
  annotate(
    "rect", xmin = 19.0, xmax = 23.5, ymin = 0, ymax = 10.2,
    fill = "#EDE9FE", alpha = 0.45
  ) +
  geom_vline(xintercept = c(5.5, 9.5, 19.0), linetype = "dashed", color = "#64748B", linewidth = 0.35) +
  geom_area(position = "identity", alpha = 0.28, linewidth = 0.95) +
  annotate(
    "text", x = 7.7, y = 9.42,
    label = "EXPLOSIÓN DEL CORO DEL AMANECER\n(06:00–09:30 h · 54.8% de los cantos diurnos)",
    size = 2.28, fontface = "bold", color = "#B45309", lineheight = 1.05
  ) +
  annotate(
    "text", x = 20.6, y = 7.45,
    label = "PULSO CREPUSCULAR\nY NOCTURNO (19:00–22:00 h)\nTecolotes, búhos y tapacaminos",
    size = 2.12, fontface = "bold", color = "#4338CA", lineheight = 1.05
  ) +
  annotate(
    "text", x = 2.7, y = 6.10,
    label = "PULSO DE ALBA\n(04:30–06:00 h)\nBúhos antes del sol",
    size = 2.12, fontface = "bold", color = "#4338CA", lineheight = 1.05
  ) +
  scale_fill_manual(values = DIEL_COLS, name = "Gremio bioacústico horario") +
  scale_color_manual(values = DIEL_COLS, name = "Gremio bioacústico horario") +
  scale_x_continuous(
    breaks = seq(0, 23, by = 2),
    labels = function(x) sprintf("%02d:00", x),
    limits = c(0, 23.5), expand = c(0.01, 0.01)
  ) +
  scale_y_continuous(
    breaks = seq(0, 10, by = 2),
    labels = function(x) paste0(x, "%"),
    limits = c(0, 10.3), expand = c(0, 0)
  ) +
  labs(
    title = "B. El Reloj Bioacústico: Ritmo Circadiano (19,356 cantos con hora)",
    subtitle = paste0(
      "Relevo acústico entre el Coro Nocturno (picos a las 05:30 y 19:30 h)\n",
      "y la explosión matutina del Coro del Amanecer (pico entre las 07:30 y 08:30 h)"
    ),
    x = "Hora solar local de grabación en campo (00:00 a 23:30 h)",
    y = "% de grabaciones del gremio (por media hora)"
  ) +
  theme_map2026(base_size = 9.5) +
  theme(
    panel.background = element_rect(fill = PANEL, color = BORDER, linewidth = 0.5),
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.text = element_text(size = 7.2, face = "bold", color = INK),
    legend.key.size = unit(0.34, "cm"),
    plot.title = element_text(size = 11.4, face = "bold", margin = margin(t = 4, b = 2)),
    plot.subtitle = element_text(size = 7.5, color = SLATE, lineheight = 1.14, margin = margin(b = 5)),
    axis.text = element_text(size = 7.2, color = SLATE),
    axis.title.x = element_text(size = 7.9, face = "bold", color = INK, margin = margin(t = 4)),
    axis.title.y = element_text(size = 7.9, face = "bold", color = INK, angle = 90, margin = margin(r = 5)),
    panel.grid.major = element_line(color = "#E7E1D2", linewidth = 0.25),
    plot.margin = margin(5, 10, 4, 8)
  ) +
  guides(fill = guide_legend(ncol = 1), color = guide_legend(ncol = 1))

# ==============================================================================
# PANEL C: Prueba Cuantitativa de la Hipótesis de Adaptación Acústica (Morton, 1975)
# ==============================================================================
morton_long <- morton_df |>
  mutate(
    biome_clean = factor(
      macro_biome,
      levels = rev(c(
        "1. Selvas Húmedas Tropicales",
        "3. Selvas Secas Caducifolias",
        "4. Pastizales, Humedales y Manglares",
        "5. Desiertos y Matorrales Xerófilos",
        "2. Bosques de Pino-Encino y Mesófilos"
      )),
      labels = rev(c(
        "1. Selvas Húmedas Tropicales\n(follaje denso · 3.21 kHz · n = 2,556)",
        "2. Selvas Secas Caducifolias\n(estacional · 3.45 kHz · n = 6,365)",
        "3. Pastizales y Humedales\n(abierto · 3.70 kHz · n = 1,086)",
        "4. Desiertos y Matorrales Xerófilos\n(árido abierto · 3.79 kHz · n = 5,177)",
        "5. Bosques de Pino-Encino y Montaña\n(dosel/montaña · 3.92 kHz · n = 5,572)"
      ))
    )
  ) |>
  select(biome_clean,
         `Baja frecuencia (<2.6 kHz: graves que evitan dispersión por follaje)` = pct_low_freq,
         `Frecuencia media (2.6–4.3 kHz: mirlos, matracas, tiranos)` = pct_mid_freq,
         `Alta frecuencia (>4.3 kHz: chipes, gorriones, colibríes)` = pct_high_freq) |>
  pivot_longer(
    cols = -biome_clean,
    names_to = "band",
    values_to = "pct"
  ) |>
  mutate(
    band = factor(band, levels = c(
      "Alta frecuencia (>4.3 kHz: chipes, gorriones, colibríes)",
      "Frecuencia media (2.6–4.3 kHz: mirlos, matracas, tiranos)",
      "Baja frecuencia (<2.6 kHz: graves que evitan dispersión por follaje)"
    ))
  )

BAND_COLS <- c(
  "Baja frecuencia (<2.6 kHz: graves que evitan dispersión por follaje)" = "#5B21B6",
  "Frecuencia media (2.6–4.3 kHz: mirlos, matracas, tiranos)"            = "#0D9488",
  "Alta frecuencia (>4.3 kHz: chipes, gorriones, colibríes)"             = "#F59E0B"
)

pC <- ggplot(morton_long, aes(x = pct, y = biome_clean, fill = band)) +
  geom_col(width = 0.68, color = "#F8FAFC", linewidth = 0.35, alpha = 0.92) +
  geom_text(
    aes(label = sprintf("%.1f%%", pct)),
    position = position_stack(vjust = 0.5),
    color = "#FFFFFF", size = 2.40, fontface = "bold"
  ) +
  scale_fill_manual(
    values = BAND_COLS,
    breaks = c(
      "Baja frecuencia (<2.6 kHz: graves que evitan dispersión por follaje)",
      "Frecuencia media (2.6–4.3 kHz: mirlos, matracas, tiranos)",
      "Alta frecuencia (>4.3 kHz: chipes, gorriones, colibríes)"
    ),
    name = "Banda bioacústica"
  ) +
  scale_x_continuous(
    breaks = seq(0, 100, by = 20),
    labels = function(x) paste0(x, "%"),
    expand = c(0, 0)
  ) +
  labs(
    title = "C. Hipótesis de Adaptación Acústica (Morton, 1975) por Bioma",
    subtitle = paste0(
      "En selvas húmedas densas los cantos graves (<2.6 kHz) duplican su proporción (30.9%)\n",
      "frente a los bosques montanos (15.5%) y los desiertos abiertos (16.3%)"
    ),
    x = "Composición porcentual de las grabaciones por banda de frecuencia (%)",
    y = NULL
  ) +
  theme_map2026(base_size = 9.5) +
  theme(
    panel.background = element_rect(fill = PANEL, color = BORDER, linewidth = 0.5),
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.text = element_text(size = 7.0, color = INK),
    legend.key.size = unit(0.32, "cm"),
    plot.title = element_text(size = 11.4, face = "bold", margin = margin(t = 4, b = 2)),
    plot.subtitle = element_text(size = 7.5, color = SLATE, lineheight = 1.14, margin = margin(b = 5)),
    axis.text.x = element_text(size = 7.2, color = SLATE),
    axis.text.y = element_text(size = 7.3, face = "bold", color = INK, hjust = 1),
    axis.title.x = element_text(size = 7.9, face = "bold", color = INK, margin = margin(t = 4)),
    plot.margin = margin(5, 10, 4, 8)
  ) +
  guides(fill = guide_legend(ncol = 1))

# ==============================================================================
# PANEL D: Los 12 Solistas del Paisaje Sonoro Mexicano (Top Especies Grabadas)
# ==============================================================================
es_names_top12 <- c(
  "Quiscalus mexicanus"      = "Zanate Mexicano",
  "Setophaga petechia"       = "Chipe Amarillo",
  "Myadestes occidentalis"   = "Clarín Jilguero",
  "Haemorhous mexicanus"     = "Pinzón Mexicano",
  "Passer domesticus"        = "Gorrión Doméstico",
  "Melanotis caerulescens"   = "Mulato Azul (Endémico)",
  "Pitangus sulphuratus"     = "Luis Bienteveo",
  "Thryomanes bewickii"      = "Saltapared Cola Larga",
  "Catharus aurantiirostris" = "Zorzal Pico Naranja",
  "Turdus rufopalliatus"     = "Mirlo Dorso Rufo (Endémico)",
  "Glaucidium brasilianum"   = "Tecolote Bajeño (Nocturno)",
  "Zenaida asiatica"         = "Paloma Ala Blanca"
)

top12_df <- top_sp |>
  slice_head(n = 12) |>
  mutate(
    nom_es = unname(es_names_top12[species]),
    label_y = sprintf("%s (%s)", nom_es, species),
    label_y = factor(label_y, levels = rev(label_y)),
    freq_clipped = pmin(5.6, pmax(1.5, freq_khz))
  )

pD <- ggplot(top12_df, aes(x = n_recordings_nat, y = label_y, fill = freq_clipped)) +
  geom_col(width = 0.70, color = "#0F172A", linewidth = 0.28, alpha = 0.92) +
  geom_text(
    aes(label = sprintf("%s grab.  ·  %.1f kHz (%s)", comma(n_recordings_nat), freq_khz, family)),
    hjust = -0.04, size = 2.28, fontface = "bold", color = INK
  ) +
  scale_fill_gradientn(colours = FREQ_PALETTE, limits = c(1.5, 5.6), guide = "none") +
  scale_x_continuous(
    limits = c(0, 1080),
    breaks = seq(0, 800, by = 200),
    expand = c(0, 0)
  ) +
  labs(
    title = "D. Los 12 Solistas Más Grabados de México (38,353 registros en GBIF Sound)",
    subtitle = "Número total de grabaciones bioacústicas por especie, coloreadas por su frecuencia fundamental (kHz)",
    x = "Grabaciones bioacústicas en México (Xeno-canto + iNaturalist / Naturalista + BLB)",
    y = NULL
  ) +
  theme_map2026(base_size = 9.5) +
  theme(
    panel.background = element_rect(fill = PANEL, color = BORDER, linewidth = 0.5),
    plot.title = element_text(size = 11.6, face = "bold", margin = margin(t = 4, b = 2)),
    plot.subtitle = element_text(size = 7.5, color = SLATE, margin = margin(b = 5)),
    axis.text.x = element_text(size = 7.2, color = SLATE),
    axis.text.y = element_text(size = 7.3, face = "bold", color = INK, hjust = 1),
    axis.title.x = element_text(size = 7.9, face = "bold", color = INK, margin = margin(t = 4)),
    panel.grid.major.x = element_line(color = "#E7E1D2", linewidth = 0.25),
    plot.margin = margin(5, 10, 4, 8)
  )

# ==============================================================================
# ENSAMBLAJE DEL PÓSTER EDITORIAL (18 x 13.8 pulgadas)
# ==============================================================================
col_izq <- pA / pD + plot_layout(heights = c(1.42, 0.85))
col_der <- pB / pC + plot_layout(heights = c(1.12, 1.15))

poster <- (col_izq | col_der) +
  plot_layout(widths = c(1.48, 1.05)) +
  plot_annotation(
    title = "EL CORO DEL AMANECER EN MÉXICO: LA OLA ACÚSTICA DEL CARIBE AL PACÍFICO",
    subtitle = paste0(
      "Cómo 2 horas y 02 minutos de rotación terrestre despiertan sucesivamente a 882 especies de aves a lo largo de 3,200 km, y cómo la estructura\n",
      "de los ecosistemas modela la frecuencia de sus cantos desde los graves profundos de la selva maya hasta los trinos agudos de montaña y desierto"
    ),
    caption = paste0(
      "#30DayMapChallenge 2026 | Día 11: Senses: Sound — Datos: Xeno-canto (22,299), iNaturalist / Naturalista Sounds (14,998) & Borror Lab of Bioacoustics (987) vía GBIF (38,353 grabaciones; 20,756 analizadas en detalle) + Ecoregions2017\n",
      "Metodología: Isócronas solares (4 min/° lon oeste), malla hexagonal EPSG:6372 (48 km) y prueba de la Hipótesis de Adaptación Acústica (Morton, 1975) | Gráfico: Fernando Dorantes Nieto (@FerDoranNie)"
    ),
    theme = theme(
      plot.background = element_rect(fill = CREAM, color = NA),
      plot.title = element_text(
        size = 19.8, face = "bold", color = INK, hjust = 0.5,
        margin = margin(t = 10, b = 4)
      ),
      plot.subtitle = element_text(
        size = 10.3, color = SLATE, hjust = 0.5, lineheight = 1.22,
        margin = margin(b = 8)
      ),
      plot.caption = element_text(
        size = 7.8, color = MUTED, hjust = 0, lineheight = 1.25,
        margin = margin(t = 8, b = 8)
      ),
      plot.margin = margin(8, 12, 8, 12)
    )
  ) &
  theme(plot.background = element_rect(fill = CREAM, color = NA))

dir.create("outputs/high_res", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/gallery", recursive = TRUE, showWarnings = FALSE)

out_high    <- "outputs/high_res/day11_senses_sound_coro_amanecer.png"
out_gallery <- "outputs/gallery/day11_senses_sound_coro_amanecer.png"

agg_png(out_high, width = 18.0, height = 13.8, units = "in", res = 300, background = CREAM)
print(poster)
dev.off()

agg_png(out_gallery, width = 18.0, height = 13.8, units = "in", res = 150, background = CREAM)
print(poster)
dev.off()

# ==============================================================================
# EXPORTACIÓN DE LAS 4 SUBGRÁFICAS COMO LÁMINAS INDIVIDUALES EXTRAS
# (Alta resolución 300 dpi en outputs/high_res/ y 150 dpi en outputs/gallery/)
# ==============================================================================
caption_std <- paste0(
  "#30DayMapChallenge 2026 | Día 11: Senses: Sound\n",
  "Datos: Xeno-canto (22,299), iNaturalist / Naturalista Sounds (14,998) & Borror Lab (987) vía GBIF (38,353 grabaciones) + Ecoregions2017 | Gráfico: Fernando Dorantes Nieto (@FerDoranNie)"
)

style_standalone <- function(p, title_size = 15.0, sub_size = 9.5) {
  p +
    labs(caption = caption_std) +
    theme(
      plot.background = element_rect(fill = CREAM, color = NA),
      plot.title = element_text(size = title_size, face = "bold", color = INK, hjust = 0, margin = margin(t = 8, b = 4)),
      plot.subtitle = element_text(size = sub_size, color = SLATE, hjust = 0, lineheight = 1.18, margin = margin(b = 8)),
      plot.caption = element_text(size = 7.6, color = MUTED, hjust = 0, lineheight = 1.25, margin = margin(t = 10, b = 4)),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      plot.margin = margin(12, 16, 10, 16)
    )
}

save_sub <- function(plot_obj, filename_base, w, h) {
  f_hi  <- file.path("outputs/high_res", paste0(filename_base, ".png"))
  f_gal <- file.path("outputs/gallery",  paste0(filename_base, ".png"))
  
  agg_png(f_hi, width = w, height = h, units = "in", res = 300, background = CREAM)
  print(plot_obj)
  dev.off()
  
  agg_png(f_gal, width = w, height = h, units = "in", res = 150, background = CREAM)
  print(plot_obj)
  dev.off()
  
  cat(sprintf(" - Subgráfica %s exportada (300 dpi: %.2f MB | 150 dpi: %.2f MB)\n",
              filename_base, file.info(f_hi)$size / 1e6, file.info(f_gal)$size / 1e6))
}

pA_solo <- style_standalone(pA, title_size = 16.0, sub_size = 9.8)
pB_solo <- style_standalone(pB, title_size = 14.5, sub_size = 9.4)
pC_solo <- style_standalone(pC, title_size = 14.5, sub_size = 9.4)
pD_solo <- style_standalone(pD, title_size = 14.5, sub_size = 9.4)

cat("\nExportando las 4 subgráficas en archivos individuales...\n")
save_sub(pA_solo, "day11_panelA_mapa_bioacustico",    w = 12.5, h = 9.2)
save_sub(pB_solo, "day11_panelB_reloj_circadiano",    w = 10.5, h = 7.2)
save_sub(pC_solo, "day11_panelC_hipotesis_morton",    w = 10.5, h = 7.2)
save_sub(pD_solo, "day11_panelD_top12_solistas",      w = 10.8, h = 7.2)

cat("\n¡Póster y 4 subgráficas individuales del Día 11 exportados exitosamente!\n")
cat(" - Alta resolución (300 dpi):", out_high, sprintf("(%.2f MB)\n", file.info(out_high)$size / 1e6))
cat(" - Galería README  (150 dpi):", out_gallery, sprintf("(%.2f MB)\n", file.info(out_gallery)$size / 1e6))
