# =============================================================================
# Día 13 — Video del póster (~45 s)
# -----------------------------------------------------------------------------
# Recorrido en tres capítulos sobre el póster de alta resolución:
#   1) el mapa global   2) la matriz quién le vende a quién   3) México
# Cada capítulo es un recorte del PNG original; el zoom se hace recortando el
# recorte (no escalando), así la imagen siempre encaja exacta en el área.
#
# Uso:  Rscript day13_video.R
#       DAY13_VIDEO_TEST=1 Rscript day13_video.R   (fotogramas de control)
# =============================================================================

suppressPackageStartupMessages({
  library(grid)
  library(png)
  library(ragg)
  library(av)
})

raiz <- normalizePath(file.path("..", ".."), mustWork = FALSE)
source(file.path(raiz, "utils", "arcos_cites.R"))

poster  <- file.path(raiz, "outputs", "high_res", "day13_interactions_cites_fauna.png")
dir_out <- file.path(raiz, "outputs", "gallery")
dir_tmp <- file.path(raiz, "data", "raw", "day13", "video_frames")
dir.create(dir_tmp, showWarnings = FALSE, recursive = TRUE)

ANCHO <- 1920; ALTO <- 1080
BANDA <- 118
AREA  <- ALTO - BANDA
FPS   <- 24
DUR   <- 45.0
N     <- as.integer(DUR * FPS)

img <- readPNG(poster)

# --- Capítulo México: regenerado desde los datos -----------------------------
# El recorte del póster solapa dos nombres de especie con el panel B, así que
# este capítulo se vuelve a dibujar a medida para el video.
mx_png <- file.path(dir_tmp, "panel_mexico.png")
if (!file.exists(mx_png)) {
  suppressPackageStartupMessages({
    library(data.table); library(ggplot2); library(patchwork); library(sf)
  })
  det <- readRDS(file.path(raiz, "data", "processed", "day13_detalle_taxon.rds"))
  mundo <- st_read(file.path(raiz, "data", "raw", "day04",
                             "ne_50m_admin_0_countries.geojson"), quiet = TRUE)
  llaves <- unique(as.data.frame(st_drop_geometry(mundo))[, c("ISO_A2_EH", "NAME_ES")])
  nom <- function(x) { n <- llaves$NAME_ES[match(x, llaves$ISO_A2_EH)]
                       ifelse(is.na(n), x, n) }

  mx_imp <- det[Source == "W" & !reexportacion & Importer == "MX" & Term != "live",
                .(vol = sum(volumen)), by = .(Exporter, Taxon)][order(-vol)][1:6]
  mx_imp[, etiqueta := factor(sprintf("%s\n%s", Taxon, nom(Exporter)), levels = rev(sprintf("%s\n%s", Taxon, nom(Exporter))))]

  mx_exp <- det[Source == "W" & !reexportacion & Exporter == "MX",
                .(vol = sum(volumen)), by = .(Importer, Taxon)][order(-vol)][1:5]
  mx_exp[, etiqueta := factor(sprintf("%s\n→ %s", Taxon, nom(Importer)), levels = rev(sprintf("%s\n→ %s", Taxon, nom(Importer))))]

  tema <- function() {
    theme_minimal(base_size = 20) +
      theme(plot.background = element_rect(fill = COL$papel, color = NA),
            panel.grid.minor = element_blank(),
            panel.grid.major.y = element_blank(),
            axis.text.y = element_text(size = 19, color = COL$tinta2, lineheight = 0.85),
            axis.text.x = element_text(size = 18, color = COL$tinta3),
            plot.title = element_text(face = "bold", size = 32, color = COL$tinta),
            plot.subtitle = element_text(size = 22, color = COL$tinta3),
            plot.margin = margin(16, 40, 12, 8))
  }
  p1 <- ggplot(mx_imp, aes(etiqueta, vol)) + geom_col(fill = COL$Reptiles, width = 0.7) +
    geom_text(aes(label = fmt(vol)), hjust = -0.12, size = 6.2, color = COL$tinta2) +
    coord_flip() + scale_y_continuous(expand = expansion(mult = c(0, 0.24))) +
    labs(title = "México importa", subtitle = "Pieles y trofeos silvestres", x = NULL, y = NULL) + tema()
  p2 <- ggplot(mx_exp, aes(etiqueta, vol)) + geom_col(fill = COL$Aves, width = 0.7) +
    geom_text(aes(label = fmt(vol)), hjust = -0.12, size = 6.2, color = COL$tinta2) +
    coord_flip() + scale_y_continuous(expand = expansion(mult = c(0, 0.24))) +
    labs(title = "México exporta", subtitle = "Sobre todo trofeos de caza a EE.UU.", x = NULL, y = NULL) + tema()

  agg_png(mx_png, width = 2400, height = 1320, units = "px", res = 144, background = COL$papel)
  print(p1 / p2)
  dev.off()
}

# --- Recortes por capítulo (filas, columnas del PNG) -------------------------
recortes <- list(
  todo = img,
  mapa = img[380:1725, 420:3720, , drop = FALSE],
  red  = img[1706:2900, 30:2150,  , drop = FALSE],
  mx   = readPNG(mx_png)
)

tramos <- list(
  list(t0 = 0.0,  t1 = 2.8,  ch = "todo", ch2 = "todo", z0 = 1.00, z1 = 1.05),
  list(t0 = 3.4,  t1 = 16.0, ch = "mapa", ch2 = "mapa", z0 = 1.00, z1 = 1.06),
  list(t0 = 17.0, t1 = 29.6, ch = "red",  ch2 = "red",  z0 = 1.00, z1 = 1.06),
  list(t0 = 30.6, t1 = 43.2, ch = "mx",   ch2 = "mx",   z0 = 1.00, z1 = 1.06),
  list(t0 = 43.6, t1 = 45.0, ch = "todo", ch2 = "todo", z0 = 1.05, z1 = 1.00)
)

suave <- function(u) u * u * (3 - 2 * u)

estado <- function(t) {
  for (tr in tramos) {
    if (t >= tr$t0 && t <= tr$t1) {
      u <- suave((t - tr$t0) / (tr$t1 - tr$t0))
      return(list(ch = tr$ch, z = tr$z0 + (tr$z1 - tr$z0) * u))
    }
  }
  list(ch = "todo", z = 1)
}

fundido <- function(t) {
  bordes <- c(2.8, 3.4, 16.0, 17.0, 29.6, 30.6, 43.2, 43.6)
  a <- 0
  for (i in seq(1, length(bordes), by = 2)) {
    t0 <- bordes[i]; t1 <- bordes[i + 1]
    if (t > t0 && t < t1) a <- max(a, 1 - abs(2 * (t - t0) / (t1 - t0) - 1))
  }
  a
}

rotulos <- list(
  list(t0 = 3.4,  t1 = 16.0, kicker = "1 / 3", titulo = "El mapa",
       linea = "35.99 millones de especímenes silvestres CITES en 2,568 rutas (2015–2024)"),
  list(t0 = 17.0, t1 = 29.6, kicker = "2 / 3", titulo = "Quién le vende a quién",
       linea = "Los 10 mayores exportadores (filas) e importadores (columnas) de fauna"),
  list(t0 = 30.6, t1 = 43.2, kicker = "3 / 3", titulo = "México",
       linea = "4.º importador mundial y 52.º exportador: 90 % de lo que entra son pieles")
)

# --- Un fotograma ------------------------------------------------------------
pintar <- function(t) {
  st  <- estado(t)
  rec <- recortes[[st$ch]]
  h   <- dim(rec)[1]; w <- dim(rec)[2]

  # zoom recortando el propio recorte
  zw <- w / st$z; zh <- h / st$z
  x0 <- round((w - zw) / 2) + 1; y0 <- round((h - zh) / 2) + 1
  sub <- rec[y0:(y0 + round(zh) - 1), x0:(x0 + round(zw) - 1), , drop = FALSE]

  esc <- min(ANCHO / dim(sub)[2], AREA / dim(sub)[1])

  pushViewport(viewport(xscale = c(0, ANCHO), yscale = c(0, ALTO)))
  grid.rect(gp = gpar(fill = COL$papel, col = NA))
  grid.raster(sub, x = unit(ANCHO / 2, "native"), y = unit(BANDA + AREA / 2, "native"),
              width = unit(dim(sub)[2] * esc, "native"),
              height = unit(dim(sub)[1] * esc, "native"),
              interpolate = TRUE)

  grid.rect(x = 0, y = 0, width = unit(ANCHO, "native"), height = unit(BANDA, "native"),
            just = c("left", "bottom"), gp = gpar(fill = "#EFEADF", col = NA))
  grid.lines(x = c(0, ANCHO), y = c(BANDA, BANDA), gp = gpar(col = "#D6CFC0", lwd = 1))

  for (r in rotulos) {
    if (t >= r$t0 && t <= r$t1) {
      ap <- min(1, (t - r$t0) / 0.45, (r$t1 - t) / 0.45)
      grid.text(r$kicker, x = unit(56, "native"), y = unit(BANDA - 22, "native"),
                just = c("left", "top"),
                gp = gpar(fontsize = 13, col = rgb(0.36, 0.41, 0.50, ap), fontface = "bold"))
      grid.text(r$titulo, x = unit(118, "native"), y = unit(BANDA - 18, "native"),
                just = c("left", "top"),
                gp = gpar(fontsize = 30, col = rgb(0.06, 0.09, 0.16, ap), fontface = "bold"))
      grid.text(r$linea, x = unit(118, "native"), y = unit(BANDA - 64, "native"),
                just = c("left", "top"),
                gp = gpar(fontsize = 17, col = rgb(0.2, 0.25, 0.33, ap)))
    }
  }

  if (t < 3.4 || t > 43.2) {
    ap <- if (t < 3.4) min(1, t / 0.6) else min(1, (t - 43.2) / 0.5)
    grid.text("Día 13 · Interactions", x = unit(118, "native"), y = unit(BANDA - 18, "native"),
              just = c("left", "top"),
              gp = gpar(fontsize = 30, col = rgb(0.06, 0.09, 0.16, ap), fontface = "bold"))
    grid.text("#30DayMapChallenge 2026 · CITES Trade Database (UNEP-WCMC)",
              x = unit(118, "native"), y = unit(BANDA - 64, "native"),
              just = c("left", "top"),
              gp = gpar(fontsize = 17, col = rgb(0.2, 0.25, 0.33, ap)))
  }

  a <- fundido(t)
  if (a > 0) grid.rect(gp = gpar(fill = rgb(0.969, 0.957, 0.922, a), col = NA))
  popViewport()
}

# --- Exportar ----------------------------------------------------------------
if (nzchar(Sys.getenv("DAY13_VIDEO_TEST"))) {
  for (tt in c(1.8, 9, 23, 37, 44.6)) {
    f <- sprintf("test_%05.1f.png", tt)
    agg_png(file.path(dir_tmp, f), width = ANCHO, height = ALTO, units = "px", res = 72,
            background = COL$papel)
    pintar(tt); dev.off()
    cat("test:", f, "\n")
  }
} else {
  archivos <- character(N)
  for (i in seq_len(N)) {
    tt <- (i - 1) / FPS
    archivos[i] <- file.path(dir_tmp, sprintf("frame_%04d.jpg", i))
    agg_jpeg(archivos[i], width = ANCHO, height = ALTO, units = "px", res = 72,
             quality = 92, background = COL$papel)
    pintar(tt)
    dev.off()
    if (i %% 120 == 0) cat("fotograma", i, "de", N, "\n")
  }
  salida <- file.path(dir_out, "day13_interactions_cites_video.mp4")
  av::av_encode_video(archivos, output = salida, framerate = FPS,
                      vfilter = "scale=1920:1080")
  cat("VIDEO:", salida, "|", round(file.size(salida) / 1e6, 1), "MB |", round(DUR), "s\n")
}
