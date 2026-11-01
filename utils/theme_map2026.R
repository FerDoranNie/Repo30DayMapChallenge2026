# ==============================================================================
# Utilidades y Tema Visual Base en R — #30DayMapChallenge 2026
# Autor: Fernando Dorantes Nieto (@FerDoranNie)
# ==============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
})

#' Tema cartográfico estilo Atlas para ggplot2
#'
#' @param bg_color Color de fondo del lienzo exterior (por defecto crema #F7F4EB)
#' @param panel_color Color de fondo del panel/océano (por defecto azul atlas pálido #DCE6F2)
#' @param border_color Color del marco del panel (por defecto #94A3B8)
#' @param text_color Color principal del texto sobre el lienzo
#' @param base_family Fuente tipográfica base
#' @param base_size Tamaño base de fuente
theme_map2026 <- function(bg_color = "#F7F4EB",
                          panel_color = "#DCE6F2",
                          border_color = "#94A3B8",
                          text_color = "#0f172a",
                          base_family = "sans",
                          base_size = 11) {
  theme_void(base_family = base_family, base_size = base_size) +
    theme(
      plot.background = element_rect(fill = bg_color, color = NA),
      panel.background = element_rect(fill = panel_color, color = border_color, linewidth = 0.6),
      text = element_text(color = text_color),
      plot.title = element_text(
        face = "bold",
        size = base_size * 1.6,
        color = text_color,
        margin = margin(t = 10, b = 6)
      ),
      plot.subtitle = element_text(
        size = base_size * 1.05,
        color = alpha(text_color, 0.80),
        margin = margin(b = 12)
      ),
      plot.caption = element_text(
        size = base_size * 0.75,
        color = alpha(text_color, 0.65),
        hjust = 0,
        margin = margin(t = 12, b = 6)
      ),
      legend.position = "bottom",
      legend.title = element_text(size = base_size * 0.85, face = "bold"),
      legend.text = element_text(size = base_size * 0.75),
      plot.margin = margin(15, 15, 15, 15)
    )
}

#' Firma estándar para el pie de mapa (caption)
#'
#' @param day Número de día (1-30)
#' @param prompt Nombre del tema oficial del día
#' @param source Fuente de los datos
map_caption <- function(day, prompt, source) {
  sprintf(
    "#30DayMapChallenge 2026 | Día %02d: %s\nDatos: %s | Gráfico: Fernando Dorantes Nieto (@FerDoranNie)",
    day, prompt, source
  )
}
