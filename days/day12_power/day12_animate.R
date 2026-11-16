# ==============================================================================
# Día 12 — Power | Animación Escena a Escena de las Metrópolis de México
# "¿El Poniente siempre es más rico? Geografía cardinal del poder socioeconómico"
#
# Genera:
#   - outputs/gallery/day12_power_ciudades_tour.gif (animación fluida para web/README)
#   - outputs/gallery/day12_power_ciudades_tour.mp4 (video HD para reproductor y redes)
#
# Autor: Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

user_lib <- "C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3"
if (dir.exists(user_lib) && !(user_lib %in% .libPaths())) {
  .libPaths(c(user_lib, .libPaths()))
}

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

msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n")
msg("Iniciando script de animación escena por escena para Día 12: Power...")

# ------------------------------------------------------------------------------
# 1. Cargar Datos Procesados
# ------------------------------------------------------------------------------
ds <- readRDS("data/processed/day12_power_ageb_cardinal.rds")
ageb_metros     <- ds$ageb_metros
mun_metros      <- ds$mun_metros
centers_df      <- ds$centers_df
octant_summary  <- ds$octant_summary
city_summary    <- ds$city_summary
profile_we_zmvm <- ds$profile_we_zmvm
pca_var_exp     <- ds$pca_var_exp

# Paleta Editorial
CREAM    <- "#F7F4EB"
OCEAN    <- "#DCE6F2"
STONE    <- "#E5E0D5"
PANEL    <- "#FBF9F3"
INK      <- "#0F172A"
SLATE    <- "#334155"
MUTED    <- "#475569"
BORDER   <- "#94A3B8"
GRID_COL <- "#CBD5E1"

IPS_PAL <- c(
  "#7C2D12", # 0   - Marginación severa / periferia vulnerable
  "#C2410C", # 18  - Terracota profundo
  "#FB923C", # 35  - Ocre cálido
  "#E2E8F0", # 50  - Mediana urbana nacional (piedra neutra)
  "#38BDF8", # 68  - Azul cielo medio-alto
  "#0284C7", # 84  - Azul cobalto alto
  "#1E3A8A"  # 100 - Índigo real (polos de poder económico)
)

VERDICT_COLS <- c(
  "Confirma: Poniente / SW" = "#1D4ED8",
  "Excepción: Norte / NE"   = "#059669",
  "Inversión: Oriente / SE" = "#C2410C",
  "Mixto / Transicional"    = "#7C3AED"
)

# ------------------------------------------------------------------------------
# 2. Especificaciones de las 11 Escenas Urbanas + Cuadro de Encuadre
# ------------------------------------------------------------------------------
scenes_info <- list(
  zmvm = list(
    idx = 1,
    id = "zmvm",
    nombre = "Valle de México",
    sub = "CDMX y Estado de México",
    xmin = -28, xmax = 32, ymin = -26, ymax = 34,
    veredicto = "Confirma: Poniente / SW",
    veredicto_txt = "CONFIRMA EL AXIOMA: PONIENTE RICO",
    veredicto_col = "#1D4ED8",
    polo_txt = "Poniente (257°) · R = 0.29",
    kpi_we = "+18.2 pts IPS (+1.23 años escolaridad)",
    kpi_ns = "-2.2 pts (equilibrio Norte-Sur)",
    rico_txt = "Sur (62.0) y Surponiente (61.5) · Pedregal / Santa Fe",
    pob_txt = "Oriente (31.9) · Iztapalapa / Neza / Chimalhuacán",
    nota = "El caso arquetípico: las élites coloniales y modernas ocuparon el piedemonte alto y templado de Chapultepec, Polanco, Lomas e Interlomas; el antiguo lecho lacustre salitroso concentró la autoconstrucción obrera."
  ),
  gdl = list(
    idx = 2,
    id = "gdl",
    nombre = "Guadalajara",
    sub = "Jalisco (Zapopan, Tlaquepaque, Tonalá, etc.)",
    xmin = -25, xmax = 25, ymin = -25, ymax = 25,
    veredicto = "Confirma: Poniente / SW",
    veredicto_txt = "CONFIRMA EL AXIOMA: NORPONIENTE RICO",
    veredicto_col = "#1D4ED8",
    polo_txt = "Norponiente (304°) · R = 0.34",
    kpi_we = "+19.3 pts IPS (+1.68 años escolaridad)",
    kpi_ns = "+12.8 pts (fuerte sesgo norte)",
    rico_txt = "Norponiente (67.5) y Poniente (66.8) · Zapopan / Puerta de Hierro",
    pob_txt = "Sur (37.6) y Oriente (45.3) · Tonalá / El Salto",
    nota = "El corredor de poder se expandió hacia Zapopan y el bosque de La Primavera. El Oriente (Calzada Independencia hacia Tonalá) marca la histórica división obrero-industrial tapatía."
  ),
  pue = list(
    idx = 3,
    id = "pue",
    nombre = "Puebla–Tlaxcala",
    sub = "Puebla y Tlaxcala (Cholula, Cuautlancingo, etc.)",
    xmin = -22, xmax = 20, ymin = -18, ymax = 24,
    veredicto = "Confirma: Poniente / SW",
    veredicto_txt = "CONFIRMA EL AXIOMA: SURPONIENTE RICO",
    veredicto_col = "#1D4ED8",
    polo_txt = "Surponiente (211°) · R = 0.31",
    kpi_we = "+11.2 pts IPS (+0.84 años escolaridad)",
    kpi_ns = "-21.2 pts (sur adinerado vs norte vulnerable)",
    rico_txt = "Poniente (56.8) y Surponiente (52.9) · Angelópolis / Cholula",
    pob_txt = "Noreste (25.8) y Norte (27.1) · Faldas de La Malinche",
    nota = "La megazona de Angelópolis y San Andrés Cholula absorbió los desarrollos de mayor plusvalía al Surponiente, mientras el norte fabril y el sur de Tlaxcala registran mayor rezago."
  ),
  slp = list(
    idx = 4,
    id = "slp",
    nombre = "San Luis Potosí",
    sub = "San Luis Potosí y Soledad de Graciano Sánchez",
    xmin = -13, xmax = 15, ymin = -14, ymax = 14,
    veredicto = "Confirma: Poniente / SW",
    veredicto_txt = "CONFIRMA EL AXIOMA: PONIENTE MÁXIMO",
    veredicto_col = "#1D4ED8",
    polo_txt = "Surponiente (246°) · R = 0.28",
    kpi_we = "+15.3 pts IPS (+1.63 años escolaridad)",
    kpi_ns = "-7.3 pts",
    rico_txt = "Poniente (87.4) · Lomas / Pedregal (14.2 años de escolaridad)",
    pob_txt = "Norte (35.1) · Periferia norte / Soledad",
    nota = "El Poniente potosino (Lomas, Club de Golf, Pedregal) exhibe el promedio de escolaridad más alto de toda la muestra nacional (14.2 años), contrastando con el norte popular."
  ),
  qro = list(
    idx = 5,
    id = "qro",
    nombre = "Querétaro",
    sub = "Querétaro, Corregidora, El Marqués y Huimilpan",
    xmin = -15, xmax = 18, ymin = -15, ymax = 18,
    veredicto = "Confirma: Poniente / SW",
    veredicto_txt = "PONIENTE Y SURESTE (POLOS COMPARTIDOS)",
    veredicto_col = "#1D4ED8",
    polo_txt = "Surponiente (204°) · R = 0.19",
    kpi_we = "+4.9 pts IPS (-0.04 años escolaridad)",
    kpi_ns = "-11.0 pts",
    rico_txt = "Surponiente (76.2) y Sureste (75.5) · Corregidora / El Campanario",
    pob_txt = "Norte (51.7) · Santa Rosa Jáuregui / periferia norte",
    nota = "Querétaro combina un polo poniente/surponiente (Corregidora) con un polo nororiente/sureste (El Campanario, Zibatá, Milenio), con el sector norte como polo de mayor vulnerabilidad."
  ),
  mty = list(
    idx = 6,
    id = "mty",
    nombre = "Monterrey",
    sub = "Nuevo León (San Pedro, Guadalupe, San Nicolás, etc.)",
    xmin = -28, xmax = 28, ymin = -28, ymax = 28,
    veredicto = "Mixto / Transicional",
    veredicto_txt = "POLICÉNTRICA: SIERRA MADRE (W + SE)",
    veredicto_col = "#7C3AED",
    polo_txt = "Sur / Sierra Madre (189°) · R = 0.05",
    kpi_we = "-2.6 pts IPS (+0.00 años escolaridad)",
    kpi_ns = "-9.6 pts",
    rico_txt = "Poniente (66.0) y Sureste (65.4) · San Pedro / Valle Alto",
    pob_txt = "Norponiente (48.6) y Oriente (51.1) · García / Escobedo / Juárez",
    nota = "Monterrey no se divide por un meridiano simple: las élites siguen los cañones y piedemontes frescos de la Sierra Madre Oriental (San Pedro Garza García al W/SW y Carretera Nacional al SE)."
  ),
  tij = list(
    idx = 7,
    id = "tij",
    nombre = "Tijuana",
    sub = "Baja California (Tijuana, Rosarito y Tecate)",
    xmin = -10, xmax = 24, ymin = -27, ymax = 5,
    veredicto = "Mixto / Transicional",
    veredicto_txt = "COSTA DEL PACÍFICO (W) / MURO NORTE",
    veredicto_col = "#7C3AED",
    polo_txt = "Poniente (275°) · R = 0.04",
    kpi_we = "+3.5 pts IPS (+0.14 años escolaridad)",
    kpi_ns = "-50.2 pts (truncada al norte por la frontera con EE.UU.)",
    rico_txt = "Poniente (63.2) y Sur (55.5) · Playas de Tijuana / Chapultepec",
    pob_txt = "Surponiente (46.2) y Oriente (51.2) · Zona Este / cañones",
    nota = "Metrópoli truncada hacia el Norte por la valla fronteriza de San Diego. El poder adquisitivo busca la franja costera del Pacífico (Playas) y las lomas de Chapultepec y Zona Río."
  ),
  leo = list(
    idx = 8,
    id = "leo",
    nombre = "León",
    sub = "Guanajuato (León y Silao de la Victoria)",
    xmin = -12, xmax = 18, ymin = -16, ymax = 14,
    veredicto = "Excepción: Norte / NE",
    veredicto_txt = "EXCEPCIÓN: EL NORTE ES RICO",
    veredicto_col = "#059669",
    polo_txt = "Noreste (58°) · R = 0.14",
    kpi_we = "-9.5 pts IPS (-0.55 años escolaridad)",
    kpi_ns = "+0.9 pts",
    rico_txt = "Norte (50.0) y Sureste (52.9 en León) · Campestre / El Molino",
    pob_txt = "Sur (25.4) y Poniente (29.1) · Las Joyas (periferia occidental)",
    nota = "León rompe la regla: el Poniente es el sector más vulnerable debido a la expansión popular sobre los cerros de Las Joyas; las élites residen en el piedemonte septentrional."
  ),
  mer = list(
    idx = 9,
    id = "mer",
    nombre = "Mérida",
    sub = "Yucatán (Mérida, Kanasín, Umán, Progreso, etc.)",
    xmin = -18, xmax = 18, ymin = -15, ymax = 21,
    veredicto = "Excepción: Norte / NE",
    veredicto_txt = "MÁXIMA EXCEPCIÓN: EL NORTE ES RICO (R = 0.47)",
    veredicto_col = "#059669",
    polo_txt = "Norte (360.0°) · Intensidad máxima R = 0.47",
    kpi_we = "+1.4 pts IPS (+0.22 años escolaridad)",
    kpi_ns = "+41.6 pts IPS (mayor brecha cardinal del país)",
    rico_txt = "Noreste (69.6) y Norponiente (68.4) · Montebello / Altabrisa",
    pob_txt = "Sur (21.6) y Sureste (25.8) · Kanasín / periferia sur",
    nota = "En Mérida, la segregación es vertical y absoluta: el Norte hacia el mar de Progreso concentra hospitales privados, centros comerciales y mansiones; el Sur concentra la precariedad."
  ),
  tol = list(
    idx = 10,
    id = "tol",
    nombre = "Toluca",
    sub = "Estado de México (Toluca, Metepec, Lerma, etc.)",
    xmin = -15, xmax = 20, ymin = -12, ymax = 18,
    veredicto = "Inversión: Oriente / SE",
    veredicto_txt = "INVERSIÓN: EL SURESTE ES RICO (METEPEC)",
    veredicto_col = "#C2410C",
    polo_txt = "Sureste (147°) · R = 0.31",
    kpi_we = "-9.7 pts IPS (-0.61 años escolaridad)",
    kpi_ns = "-25.1 pts (sur rico vs norte vulnerable)",
    rico_txt = "Sureste (65.5) · Metepec (Polo de élite)",
    pob_txt = "Norte (20.3) · Otzolotepec / Almoloya / norte fabril",
    nota = "Toluca invierte el Poniente: su suburbio residencial de alta plusvalía es Metepec al Sureste, rumbo a la salida a CDMX, mientras el norte árido-industrial presenta alta marginación."
  ),
  jrz = list(
    idx = 11,
    id = "jrz",
    nombre = "Ciudad Juárez",
    sub = "Chihuahua (Municipio de Juárez)",
    xmin = -11, xmax = 19, ymin = -23, ymax = 5,
    veredicto = "Inversión: Oriente / SE",
    veredicto_txt = "INVERSIÓN TOTAL: EL ORIENTE ES RICO",
    veredicto_col = "#C2410C",
    polo_txt = "Oriente (86°) · R = 0.31",
    kpi_we = "-32.3 pts IPS (-2.07 años escolaridad)",
    kpi_ns = "-25.1 pts",
    rico_txt = "Oriente (84.4) · Campos Elíseos / Consulado (13.1 años escol.)",
    pob_txt = "Poniente (21.4) · Anapra / Sierra de Juárez (8.5 años escol.)",
    nota = "El reflejo invertido del Valle de México: la élite vive en el Oriente junto a los puentes hacia El Paso, Texas; en el Poniente, sobre la árida Sierra de Juárez, se asienta la precariedad de Anapra."
  )
)

# ------------------------------------------------------------------------------
# 3. Función de Renderizado de la Escena de Introducción (Brújula Nacional)
# ------------------------------------------------------------------------------
render_intro_scene <- function() {
  # Panel B (Brújula Nacional)
  compass_df <- city_summary |>
    mutate(
      rad = vec_azimut * pi / 180,
      vx_plot = segregacion_R * sin(rad),
      vy_plot = segregacion_R * cos(rad),
      short_name = case_when(
        metro_id == "zmvm" ~ "Valle de México",
        metro_id == "pue"  ~ "Puebla–Tlax.",
        metro_id == "slp"  ~ "San Luis Potosí",
        metro_id == "jrz"  ~ "Cd. Juárez",
        TRUE               ~ metro_nombre
      )
    )

  lbl_offsets <- tibble::tribble(
    ~metro_id, ~lx,    ~ly,
    "mer",      0.20,   0.485,
    "leo",      0.28,   0.235,
    "jrz",      0.41,   0.045,
    "tol",      0.29,  -0.320,
    "pue",     -0.27,  -0.345,
    "qro",     -0.06,  -0.280,
    "slp",     -0.35,  -0.175,
    "zmvm",    -0.42,  -0.065,
    "gdl",     -0.37,   0.285,
    "tij",     -0.21,   0.185,
    "mty",      0.19,  -0.115
  )
  compass_df <- compass_df |> left_join(lbl_offsets, by = "metro_id")

  make_circle <- function(r, n = 180) {
    ang <- seq(0, 2 * pi, length.out = n)
    tibble(x = r * sin(ang), y = r * cos(ang))
  }
  ring_15 <- make_circle(0.15)
  ring_30 <- make_circle(0.30)
  ring_45 <- make_circle(0.45)

  spokes <- tibble(ang = seq(0, 315, by = 45)) |>
    mutate(
      xend = 0.48 * sin(ang * pi / 180),
      yend = 0.48 * cos(ang * pi / 180),
      lbl  = c("N (0°)", "NE", "E\nOriente", "SE", "S (180°)", "SW", "W\nPoniente", "NW"),
      lx   = 0.555 * sin(ang * pi / 180),
      ly   = 0.555 * cos(ang * pi / 180)
    )

  p_compass <- ggplot() +
    annotate("rect", xmin = -0.60, xmax = 0, ymin = -0.58, ymax = 0.58, fill = "#EFF6FF", alpha = 0.55) +
    annotate("rect", xmin = 0, xmax = 0.60, ymin = -0.58, ymax = 0.58, fill = "#FFF7ED", alpha = 0.55) +
    geom_path(data = ring_15, aes(x = x, y = y), color = GRID_COL, linetype = "dotted", linewidth = 0.35) +
    geom_path(data = ring_30, aes(x = x, y = y), color = GRID_COL, linetype = "dashed", linewidth = 0.40) +
    geom_path(data = ring_45, aes(x = x, y = y), color = BORDER,   linetype = "solid",  linewidth = 0.45) +
    geom_segment(data = spokes, aes(x = 0, y = 0, xend = xend, yend = yend),
                 color = alpha(BORDER, 0.55), linewidth = 0.3) +
    annotate("text", x = 0.015, y = 0.162, label = "R=0.15", size = 2.1, color = MUTED, hjust = 0) +
    annotate("text", x = 0.015, y = 0.312, label = "R=0.30", size = 2.1, color = MUTED, hjust = 0) +
    annotate("text", x = 0.015, y = 0.462, label = "R=0.45", size = 2.1, color = MUTED, hjust = 0) +
    geom_text(data = spokes, aes(x = lx, y = ly, label = lbl),
              size = 2.6, fontface = "bold", color = SLATE, lineheight = 0.9) +
    geom_segment(
      data = compass_df,
      aes(x = vx_plot, y = vy_plot, xend = lx, yend = ly, color = regla_poniente),
      linetype = "dotted", linewidth = 0.35, alpha = 0.75, show.legend = FALSE
    ) +
    geom_segment(
      data = compass_df,
      aes(x = 0, y = 0, xend = vx_plot, yend = vy_plot, color = regla_poniente),
      linewidth = 1.25,
      arrow = arrow(length = unit(0.22, "cm"), type = "closed")
    ) +
    geom_point(
      data = compass_df,
      aes(x = vx_plot, y = vy_plot, fill = regla_poniente, size = pob_total),
      shape = 21, color = INK, stroke = 0.5
    ) +
    geom_label(
      data = compass_df,
      aes(x = lx, y = ly, label = sprintf("%s\n(%s · R=%.2f)", short_name, vec_octant, segregacion_R),
          color = regla_poniente),
      fill = alpha(PANEL, 0.94), size = 2.2, fontface = "bold", lineheight = 0.92,
      label.size = 0.22, label.padding = unit(0.18, "lines"), show.legend = FALSE
    ) +
    annotate("point", x = 0, y = 0, size = 2.6, color = INK) +
    scale_color_manual(values = VERDICT_COLS, name = "Veredicto") +
    scale_fill_manual(values = VERDICT_COLS, name = "Veredicto") +
    scale_size_continuous(range = c(2.6, 6.2), guide = "none") +
    coord_fixed(xlim = c(-0.62, 0.62), ylim = c(-0.59, 0.61), expand = FALSE) +
    theme_void() +
    theme(
      plot.background = element_rect(fill = PANEL, color = BORDER, linewidth = 0.6),
      legend.position = "none",
      plot.margin = margin(8, 8, 8, 8)
    )

  # Panel de texto explicativo a la derecha
  p_text <- ggplot() +
    annotate("rect", xmin = 0, xmax = 1, ymin = 0, ymax = 1, fill = PANEL, color = BORDER, linewidth = 0.6) +
    annotate("text", x = 0.06, y = 0.91, label = "INTRODUCCIÓN: LA PREGUNTA CARTOGRÁFICA",
             size = 3.6, fontface = "bold", color = "#1E3A8A", hjust = 0) +
    annotate("text", x = 0.06, y = 0.81,
             label = "¿El Poniente siempre es más rico en las ciudades mexicanas?",
             size = 4.2, fontface = "bold", color = INK, hjust = 0) +
    annotate("text", x = 0.06, y = 0.67,
             label = paste0(
               "En el urbanismo mexicano existe el axioma de que las élites viven al Poniente (Oeste)\n",
               "y los sectores populares al Oriente (Este), explicado por piedemontes altos y vientos barlovento.\n\n",
               "Evaluamos esta hipótesis con 14,407 AGEBs urbanas (44.5 millones de personas) del Censo 2020\n",
               "y CONAPO en las 11 metrópolis más pobladas del país mediante PCA (79.9% varianza)."
             ),
             size = 3.1, color = SLATE, hjust = 0, lineheight = 1.30) +
    annotate("text", x = 0.06, y = 0.44, label = "CUATRO PATRONES ENCONTRADOS:",
             size = 3.2, fontface = "bold", color = INK, hjust = 0) +
    annotate("label", x = 0.06, y = 0.35, label = "1. Confirma Poniente / SW (5 metrópolis): CDMX, Guadalajara, Puebla, SLP y Querétaro",
             size = 2.8, fontface = "bold", fill = "#DBEAFE", color = "#1D4ED8", hjust = 0) +
    annotate("label", x = 0.06, y = 0.26, label = "2. Excepción Norte (2 metrópolis): Mérida (R = 0.47) y León",
             size = 2.8, fontface = "bold", fill = "#D1FAE5", color = "#059669", hjust = 0) +
    annotate("label", x = 0.06, y = 0.17, label = "3. Inversión Oriente / SE (2 metrópolis): Ciudad Juárez (-32.3 pts W-E) y Toluca",
             size = 2.8, fontface = "bold", fill = "#FFEDD5", color = "#C2410C", hjust = 0) +
    annotate("label", x = 0.06, y = 0.08, label = "4. Transicionales y Costeras: Monterrey (policéntrica Sierra Madre) y Tijuana (costa Pacífico)",
             size = 2.8, fontface = "bold", fill = "#EDE9FE", color = "#7C3AED", hjust = 0) +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE) +
    theme_void() +
    theme(plot.margin = margin(8, 8, 8, 8))

  comp <- (p_compass | p_text) +
    plot_layout(widths = c(1.0, 1.25)) +
    plot_annotation(
      title = "TOUR METROPOLITANO: GEOGRAFÍA CARDINAL DEL PODER SOCIOECONÓMICO EN MÉXICO",
      subtitle = "Escena 0 de 12 · Síntesis nacional de 11 metrópolis y sus vectores de segregación de élite",
      caption = "#30DayMapChallenge 2026 | Día 12: Power — Datos: INEGI Censo 2020 & CONAPO | Gráfico: Fernando Dorantes Nieto (@FerDoranNie)",
      theme = theme(
        plot.background = element_rect(fill = CREAM, color = NA),
        plot.title = element_text(size = 14.5, face = "bold", color = INK, hjust = 0.5, margin = margin(t = 6, b = 2)),
        plot.subtitle = element_text(size = 9.2, color = SLATE, hjust = 0.5, margin = margin(b = 4)),
        plot.caption = element_text(size = 7.5, color = MUTED, hjust = 0, margin = margin(t = 4, b = 4)),
        plot.margin = margin(6, 10, 6, 10)
      )
    ) &
    theme(plot.background = element_rect(fill = CREAM, color = NA))

  comp
}

# ------------------------------------------------------------------------------
# 4. Función de Renderizado de Escena de Ciudad Individual
# ------------------------------------------------------------------------------
render_city_scene <- function(spec) {
  m_id   <- spec$id
  c_info <- centers_df |> filter(metro_id == m_id)
  c_sum  <- city_summary |> filter(metro_id == m_id)
  c_oct  <- octant_summary |> filter(metro_id == m_id)
  c_ageb <- ageb_metros |> filter(metro_id == m_id, valid_ips)
  c_mun  <- mun_metros  |> filter(metro_id == m_id)

  cx <- c_info$cx_m[1]
  cy <- c_info$cy_m[1]
  xlim_c <- c(cx + spec$xmin * 1000, cx + spec$xmax * 1000)
  ylim_c <- c(cy + spec$ymin * 1000, cy + spec$ymax * 1000)

  span_m <- min(diff(xlim_c), diff(ylim_c))
  arr_len_m <- span_m * 0.32
  rad <- c_sum$vec_azimut * pi / 180
  ax <- cx + arr_len_m * sin(rad)
  ay <- cy + arr_len_m * cos(rad)

  # Mapa Principal de la Metrópoli (Lado Izquierdo)
  p_map <- ggplot() +
    geom_sf(data = c_mun, fill = STONE, color = GRID_COL, linewidth = 0.35) +
    geom_sf(data = c_ageb, aes(fill = IPS_pct), color = NA) +
    geom_sf(data = c_mun, fill = NA, color = alpha(SLATE, 0.40), linewidth = 0.30) +
    geom_vline(xintercept = cx, linetype = "dashed", color = alpha(INK, 0.55), linewidth = 0.45) +
    geom_hline(yintercept = cy, linetype = "dashed", color = alpha(INK, 0.55), linewidth = 0.45) +
    annotate(
      "segment", x = cx, y = cy, xend = ax, yend = ay,
      color = "#FACC15", linewidth = 2.4,
      arrow = arrow(length = unit(0.30, "cm"), type = "closed")
    ) +
    annotate(
      "segment", x = cx, y = cy, xend = ax, yend = ay,
      color = spec$veredicto_col, linewidth = 1.3,
      arrow = arrow(length = unit(0.26, "cm"), type = "closed")
    ) +
    annotate("point", x = cx, y = cy, shape = 21, size = 4.0, fill = "#FACC15", color = INK, stroke = 0.9) +
    # Etiquetas en los bordes
    annotate("label", x = cx, y = ylim_c[2] - span_m * 0.04, label = "N",
             size = 2.4, fontface = "bold", fill = alpha(PANEL, 0.90), color = INK, label.size = 0.2) +
    annotate("label", x = cx, y = ylim_c[1] + span_m * 0.04, label = "S",
             size = 2.4, fontface = "bold", fill = alpha(PANEL, 0.90), color = INK, label.size = 0.2) +
    annotate("label", x = xlim_c[1] + span_m * 0.09, y = cy, label = "W · PONIENTE",
             size = 2.1, fontface = "bold", fill = "#DBEAFE", color = "#1E3A8A", label.size = 0.22) +
    annotate("label", x = xlim_c[2] - span_m * 0.09, y = cy, label = "E · ORIENTE",
             size = 2.1, fontface = "bold", fill = "#FFEDD5", color = "#9A3412", label.size = 0.22) +
    scale_fill_gradientn(colours = IPS_PAL, limits = c(0, 100), guide = "none") +
    coord_sf(crs = 6372, xlim = xlim_c, ylim = ylim_c, expand = FALSE) +
    theme_map2026(base_size = 9.5) +
    theme(
      panel.background = element_rect(fill = OCEAN, color = BORDER, linewidth = 0.6),
      plot.margin = margin(4, 6, 4, 6)
    )

  # Rosa Polar de 8 Octantes
  p_rose <- ggplot(c_oct, aes(x = azimut_oct, y = ips_pct_mean, fill = ips_pct_mean)) +
    geom_hline(yintercept = c(25, 50, 75), color = GRID_COL, linetype = "dashed", linewidth = 0.25) +
    geom_col(width = 41, color = INK, linewidth = 0.25, alpha = 0.92) +
    geom_text(
      aes(y = ips_pct_mean + 7.5, label = sprintf("%.0f", ips_pct_mean)),
      size = 2.3, fontface = "bold", color = INK
    ) +
    annotate(
      "segment", x = c_sum$vec_azimut, y = 0, xend = c_sum$vec_azimut, yend = 68,
      color = "#FACC15", linewidth = 1.7,
      arrow = arrow(length = unit(0.20, "cm"), type = "closed")
    ) +
    annotate(
      "segment", x = c_sum$vec_azimut, y = 0, xend = c_sum$vec_azimut, yend = 68,
      color = spec$veredicto_col, linewidth = 0.9,
      arrow = arrow(length = unit(0.18, "cm"), type = "closed")
    ) +
    scale_fill_gradientn(colours = IPS_PAL, limits = c(0, 100), guide = "none") +
    scale_x_continuous(
      limits = c(-22.5, 337.5),
      breaks = seq(0, 315, by = 45),
      labels = c("N", "NE", "E", "SE", "S", "SW", "W", "NW")
    ) +
    scale_y_continuous(limits = c(0, 84)) +
    coord_polar(theta = "x", start = -22.5 * pi / 180) +
    labs(
      title = "Rosa Cardinal del Poder (IPS medio por octante)",
      subtitle = sprintf("Polo resultante: %s · Escala percentil 0–100", spec$polo_txt)
    ) +
    theme_minimal(base_size = 8.5) +
    theme(
      plot.background = element_rect(fill = PANEL, color = BORDER, linewidth = 0.45),
      panel.background = element_rect(fill = PANEL, color = NA),
      panel.grid.major.x = element_line(color = alpha(BORDER, 0.35), linewidth = 0.25),
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      axis.title = element_blank(),
      axis.text.y = element_blank(),
      axis.text.x = element_text(size = 7.5, face = "bold", color = INK),
      plot.title = element_text(size = 9.2, face = "bold", color = INK, hjust = 0.5, margin = margin(t = 4, b = 1)),
      plot.subtitle = element_text(size = 7.0, color = MUTED, hjust = 0.5, margin = margin(b = 2)),
      plot.margin = margin(3, 4, 3, 4)
    )

  # Tarjeta de Datos y Veredicto (Lado Derecho Inferior)
  p_card <- ggplot() +
    annotate("rect", xmin = 0, xmax = 1, ymin = 0, ymax = 1, fill = PANEL, color = BORDER, linewidth = 0.45) +
    # Badge de Veredicto
    annotate("rect", xmin = 0.04, xmax = 0.96, ymin = 0.84, ymax = 0.96,
             fill = spec$veredicto_col, color = NA) +
    annotate("text", x = 0.50, y = 0.90, label = spec$veredicto_txt,
             size = 3.1, fontface = "bold", color = "#FFFFFF", hjust = 0.5) +
    # Métricas Clave
    annotate("text", x = 0.06, y = 0.76, label = "RUMBO DEL POLO:", size = 2.6, fontface = "bold", color = MUTED, hjust = 0) +
    annotate("text", x = 0.42, y = 0.76, label = spec$polo_txt, size = 2.8, fontface = "bold", color = INK, hjust = 0) +
    annotate("text", x = 0.06, y = 0.65, label = "BRECHA W–E:", size = 2.6, fontface = "bold", color = MUTED, hjust = 0) +
    annotate("text", x = 0.42, y = 0.65, label = spec$kpi_we, size = 2.8, fontface = "bold", color = INK, hjust = 0) +
    annotate("text", x = 0.06, y = 0.54, label = "BRECHA N–S:", size = 2.6, fontface = "bold", color = MUTED, hjust = 0) +
    annotate("text", x = 0.42, y = 0.54, label = spec$kpi_ns, size = 2.8, fontface = "bold", color = INK, hjust = 0) +
    annotate("text", x = 0.06, y = 0.43, label = "OCTANTE RICO:", size = 2.6, fontface = "bold", color = "#1E3A8A", hjust = 0) +
    annotate("text", x = 0.42, y = 0.43, label = spec$rico_txt, size = 2.7, fontface = "bold", color = "#1E3A8A", hjust = 0) +
    annotate("text", x = 0.06, y = 0.32, label = "OCTANTE VULN.:", size = 2.6, fontface = "bold", color = "#7C2D12", hjust = 0) +
    annotate("text", x = 0.42, y = 0.32, label = spec$pob_txt, size = 2.7, fontface = "bold", color = "#7C2D12", hjust = 0) +
    # Nota Geográfica
    annotate("rect", xmin = 0.04, xmax = 0.96, ymin = 0.03, ymax = 0.23,
             fill = alpha("#E2E8F0", 0.45), color = GRID_COL, linewidth = 0.25) +
    annotate("text", x = 0.06, y = 0.13, label = stringr::str_wrap(spec$nota, width = 48),
             size = 2.3, color = SLATE, hjust = 0, lineheight = 1.15) +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE) +
    theme_void() +
    theme(plot.margin = margin(3, 4, 3, 4))

  # Lado derecho completo (Rosa + Tarjeta)
  p_right <- (p_rose / p_card) + plot_layout(heights = c(1.15, 1.25))

  # Barra de Leyenda Inferior
  legend_df <- tibble(x = seq(0, 100, length.out = 150), y = 1)
  p_leg <- ggplot(legend_df, aes(x = x, y = y, fill = x)) +
    geom_tile(height = 0.5) +
    annotate("rect", xmin = 0, xmax = 100, ymin = 0.75, ymax = 1.25, fill = NA, color = INK, linewidth = 0.3) +
    scale_fill_gradientn(colours = IPS_PAL, limits = c(0, 100), guide = "none") +
    scale_x_continuous(
      breaks = c(10, 50, 90),
      labels = c("10 · Periferia vulnerable", "50 · Mediana urbana", "90 · Polo élite"),
      expand = c(0.01, 0.01)
    ) +
    coord_cartesian(ylim = c(0.65, 1.5), clip = "off") +
    theme_void() +
    theme(
      plot.background = element_rect(fill = CREAM, color = NA),
      axis.text.x = element_text(size = 6.8, face = "bold", color = SLATE, margin = margin(t = 2)),
      plot.margin = margin(1, 40, 2, 40)
    )

  comp <- ((p_map | p_right) + plot_layout(widths = c(1.65, 1.0))) / p_leg +
    plot_layout(heights = c(1.0, 0.06)) +
    plot_annotation(
      title = sprintf("METRÓPOLI %d DE 11: %s (%s)", spec$idx, toupper(spec$nombre), toupper(spec$sub)),
      subtitle = sprintf(
        "Población: %.2fM hab. · %s AGEB urbanas analizadas | Centro: %s (%s)",
        c_sum$pob_total / 1e6, format(c_sum$n_ageb, big.mark = ","),
        c_info$centro_nombre, spec$veredicto_txt
      ),
      caption = "#30DayMapChallenge 2026 | Día 12: Power — Datos: INEGI Censo 2020 & CONAPO | Gráfico: Fernando Dorantes Nieto (@FerDoranNie)",
      theme = theme(
        plot.background = element_rect(fill = CREAM, color = NA),
        plot.title = element_text(size = 14.5, face = "bold", color = INK, hjust = 0.5, margin = margin(t = 5, b = 2)),
        plot.subtitle = element_text(size = 9.2, color = spec$veredicto_col, face = "bold", hjust = 0.5, margin = margin(b = 4)),
        plot.caption = element_text(size = 7.4, color = MUTED, hjust = 0, margin = margin(t = 3, b = 3)),
        plot.margin = margin(5, 10, 4, 10)
      )
    ) &
    theme(plot.background = element_rect(fill = CREAM, color = NA))

  comp
}

# ------------------------------------------------------------------------------
# 5. Función de Renderizado de la Escena de Síntesis Final
# ------------------------------------------------------------------------------
render_synthesis_scene <- function() {
  # Tabla de Resumen
  summary_table_df <- city_summary |>
    mutate(
      idx = row_number(),
      y_pos = seq(0.83, 0.08, length.out = n()),
      short_name = case_when(
        metro_id == "zmvm" ~ "Valle de México",
        metro_id == "pue"  ~ "Puebla–Tlaxcala",
        metro_id == "slp"  ~ "San Luis Potosí",
        metro_id == "jrz"  ~ "Ciudad Juárez",
        TRUE               ~ metro_nombre
      ),
      pob_fmt = sprintf("%.2fM", pob_total / 1e6),
      polo_fmt = sprintf("%s (%.0f°)", vec_octant, vec_azimut),
      r_fmt = sprintf("%.2f", segregacion_R),
      gap_we_fmt = sprintf("%+.1f", gap_we_pct),
      gap_ns_fmt = sprintf("%+.1f", gap_ns_pct),
      vered_short = case_when(
        regla_poniente == "Confirma: Poniente / SW" ~ "Confirma Poniente",
        regla_poniente == "Excepción: Norte / NE"   ~ "Excepción Norte",
        regla_poniente == "Inversión: Oriente / SE" ~ "Inversión Oriente",
        TRUE                                        ~ "Policéntrica"
      )
    )

  p_table <- ggplot(summary_table_df) +
    annotate("rect", xmin = 0, xmax = 1, ymin = 0, ymax = 1, fill = PANEL, color = BORDER, linewidth = 0.6) +
    # Encabezado de tabla
    annotate("rect", xmin = 0.02, xmax = 0.98, ymin = 0.89, ymax = 0.98, fill = INK, color = NA) +
    annotate("text", x = 0.04, y = 0.935, label = "# Metrópoli", size = 2.7, fontface = "bold", color = "#FFFFFF", hjust = 0) +
    annotate("text", x = 0.28, y = 0.935, label = "Población", size = 2.7, fontface = "bold", color = "#FFFFFF", hjust = 0) +
    annotate("text", x = 0.40, y = 0.935, label = "Polo (Azimut)", size = 2.7, fontface = "bold", color = "#FFFFFF", hjust = 0) +
    annotate("text", x = 0.55, y = 0.935, label = "Segregación R", size = 2.7, fontface = "bold", color = "#FFFFFF", hjust = 0) +
    annotate("text", x = 0.68, y = 0.935, label = "Δ W–E (pts)", size = 2.7, fontface = "bold", color = "#FFFFFF", hjust = 0) +
    annotate("text", x = 0.82, y = 0.935, label = "Veredicto", size = 2.7, fontface = "bold", color = "#FFFFFF", hjust = 0) +
    # Filas de la tabla
    geom_text(
      aes(x = 0.04, y = y_pos, label = sprintf("%2d. %s", idx, short_name)),
      size = 2.65, fontface = "bold", color = INK, hjust = 0
    ) +
    geom_text(
      aes(x = 0.28, y = y_pos, label = pob_fmt),
      size = 2.65, color = SLATE, hjust = 0
    ) +
    geom_text(
      aes(x = 0.40, y = y_pos, label = polo_fmt),
      size = 2.65, fontface = "bold", color = INK, hjust = 0
    ) +
    geom_text(
      aes(x = 0.55, y = y_pos, label = r_fmt),
      size = 2.65, color = SLATE, hjust = 0
    ) +
    geom_text(
      aes(x = 0.68, y = y_pos, label = gap_we_fmt),
      size = 2.65, fontface = "bold", color = INK, hjust = 0
    ) +
    geom_label(
      aes(
        x = 0.82, y = y_pos, label = vered_short,
        color = regla_poniente
      ),
      size = 2.3, fontface = "bold", fill = alpha(CREAM, 0.90),
      label.size = 0.2, label.padding = unit(0.12, "lines"), hjust = 0
    ) +
    scale_color_manual(values = VERDICT_COLS, guide = "none") +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE) +
    theme_void() +
    theme(plot.margin = margin(8, 8, 8, 8))

  # Panel de Conclusión a la derecha
  p_concl <- ggplot() +
    annotate("rect", xmin = 0, xmax = 1, ymin = 0, ymax = 1, fill = PANEL, color = BORDER, linewidth = 0.6) +
    annotate("text", x = 0.06, y = 0.92, label = "CONCLUSIÓN: ¿EL PONIENTE SIEMPRE ES MÁS RICO?",
             size = 3.6, fontface = "bold", color = "#1E3A8A", hjust = 0) +
    annotate("text", x = 0.06, y = 0.82,
             label = "VEREDICTO CIENTÍFICO FINAL", size = 4.2, fontface = "bold", color = INK, hjust = 0) +
    annotate("text", x = 0.06, y = 0.62,
             label = paste0(
               "1. EL PONIENTE NO ES UNA LEY UNIVERSAL:\n",
               "   Solo se cumple de forma estricta en metrópolis de montaña o piedemonte\n",
               "   occidental donde la topografía y los manantiales ofrecían ventajas\n",
               "   sanitarias y estéticas históricas (CDMX, Guadalajara, Puebla, SLP).\n\n",
               "2. LA TOPOGRAFÍA Y EL MAR VENCEN AL MERIDIANO:\n",
               "   - En Mérida, la brisa y el acceso al Golfo de México fijan el polo en el Norte (R = 0.47).\n",
               "   - En León, el piedemonte norte es el polo residencial élite; el Poniente es Las Joyas.\n\n",
               "3. LA FRONTERA INTERNACIONAL INVIERTE LA GEOGRAFÍA:\n",
               "   - En Ciudad Juárez, el Oriente fronterizo con El Paso concentra la mayor riqueza\n",
               "     del norte de México (-32.3 pts W-E), rompiendo todo axioma cardinal tradicional.\n\n",
               "4. EN METRÓPOLIS POLICÉNTRICAS (MTY, QRO):\n",
               "   Las élites siguen fallas ecológicas y sierras (Sierra Madre), no un punto cardinal simple."
             ),
             size = 2.9, color = SLATE, hjust = 0, lineheight = 1.25) +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE) +
    theme_void() +
    theme(plot.margin = margin(8, 8, 8, 8))

  comp <- (p_table | p_concl) +
    plot_layout(widths = c(1.3, 1.0)) +
    plot_annotation(
      title = "SÍNTESIS FINAL: COMPARATIVA METROPOLITANA Y CONCLUSIONES",
      subtitle = "Escena 12 de 12 · 44.5 millones de habitantes analizados en 14,407 AGEBs de México",
      caption = "#30DayMapChallenge 2026 | Día 12: Power — Datos: INEGI Censo 2020 & CONAPO | Gráfico: Fernando Dorantes Nieto (@FerDoranNie)",
      theme = theme(
        plot.background = element_rect(fill = CREAM, color = NA),
        plot.title = element_text(size = 14.5, face = "bold", color = INK, hjust = 0.5, margin = margin(t = 6, b = 2)),
        plot.subtitle = element_text(size = 9.2, color = SLATE, hjust = 0.5, margin = margin(b = 4)),
        plot.caption = element_text(size = 7.5, color = MUTED, hjust = 0, margin = margin(t = 4, b = 4)),
        plot.margin = margin(6, 10, 6, 10)
      )
    ) &
    theme(plot.background = element_rect(fill = CREAM, color = NA))

  comp
}

# ------------------------------------------------------------------------------
# 6. Renderizado de los Fotogramas de Cada Escena
# ------------------------------------------------------------------------------
dir_frames <- "data/raw/day12/frames_tour"
unlink(dir_frames, recursive = TRUE)
dir.create(dir_frames, recursive = TRUE, showWarnings = FALSE)

# Definir la lista de escenas:
# Escena 0: Intro (Brújula Nacional)
# Escenas 1 a 11: Las 11 Ciudades
# Escena 12: Síntesis Final
# Ajustado a ~45 segundos totales: 13 escenas × 7 fotogramas @ 2.0 fps = 45.5 s (3.5 s por escena)
FPS <- 2.0
FRAMES_PER_SCENE <- 7
scene_keys <- c("intro", names(scenes_info), "synthesis")
total_scenes <- length(scene_keys)
total_frames <- total_scenes * FRAMES_PER_SCENE
total_dur_s  <- total_frames / FPS

msg(sprintf("Total de escenas a renderizar: %d (con %d fotogramas c/u = %d fotogramas totales | Duración: %.1f s)...",
            total_scenes, FRAMES_PER_SCENE, total_frames, total_dur_s))

all_frame_files <- character()
frame_counter <- 1

for (s_idx in seq_along(scene_keys)) {
  s_key <- scene_keys[s_idx]
  msg(sprintf("Renderizando Escena %02d/%02d (%s)...", s_idx, total_scenes, s_key))

  # Generar el gráfico según la escena
  scene_plot <- if (s_key == "intro") {
    render_intro_scene()
  } else if (s_key == "synthesis") {
    render_synthesis_scene()
  } else {
    render_city_scene(scenes_info[[s_key]])
  }

  # Guardar primer fotograma único de la escena
  base_png <- file.path(dir_frames, sprintf("scene_%02d_base.png", s_idx))
  agg_png(base_png, width = 13.5, height = 8.5, units = "in", res = 100, background = CREAM)
  print(scene_plot)
  dev.off()

  # Duplicar el fotograma para dar la duración temporal requerida
  for (f in 1:FRAMES_PER_SCENE) {
    f_path <- file.path(dir_frames, sprintf("frame_%04d.png", frame_counter))
    file.copy(base_png, f_path)
    all_frame_files <- c(all_frame_files, f_path)
    frame_counter <- frame_counter + 1
  }
}

# ------------------------------------------------------------------------------
# 7. Compilación a GIF animado (gifski) y Video MP4 (av)
# ------------------------------------------------------------------------------
dir.create("outputs/gallery",  recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/high_res", recursive = TRUE, showWarnings = FALSE)

out_gif     <- "outputs/gallery/day12_power_ciudades_tour.gif"
out_mp4     <- "outputs/gallery/day12_power_ciudades_tour.mp4"
out_mp4_hi  <- "outputs/high_res/day12_power_ciudades_tour.mp4"

msg("Compilando GIF animado con gifski...")
gifski(
  png_files = all_frame_files,
  gif_file  = out_gif,
  width     = 1350,
  height    = 850,
  delay     = 1 / FPS,
  loop      = TRUE,
  progress  = FALSE
)
msg(sprintf("GIF animado creado: %s (%.2f MB)", out_gif, file.info(out_gif)$size / 1e6))

msg("Codificando video MP4 HD con av...")
av_encode_video(
  input     = all_frame_files,
  output    = out_mp4,
  framerate = FPS,
  verbose   = FALSE
)
file.copy(out_mp4, out_mp4_hi, overwrite = TRUE)
msg(sprintf("Video MP4 creado: %s (%.2f MB)", out_mp4, file.info(out_mp4)$size / 1e6))

# Limpiar fotogramas temporales
unlink(dir_frames, recursive = TRUE)

msg("¡Animación escena a escena del Día 12 completada con éxito!")
