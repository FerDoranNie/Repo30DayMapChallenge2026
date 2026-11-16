# =============================================================================
# Día 13 — Interactions | Animación de flujos CITES
# -----------------------------------------------------------------------------
# Partículas ("cometas") recorren los arcos exportador -> importador de la red
# de fauna silvestre 2015-2024. Bucle continuo: cada arco da exactamente una
# vuelta por ciclo, de modo que el último fotograma empalma con el primero.
#
# Uso:  Rscript day13_animate.R
#       DAY13_FRAMES=24 Rscript day13_animate.R   (prueba rápida)
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(sf)
  library(ggplot2)
  library(ragg)
  library(gifski)
  library(av)
})

raiz <- normalizePath(file.path("..", ".."), mustWork = FALSE)
source(file.path(raiz, "utils", "theme_map2026.R"))
source(file.path(raiz, "utils", "arcos_cites.R"))

dir_proc <- file.path(raiz, "data", "processed")
dir_gal  <- file.path(raiz, "outputs", "gallery")
dir_tmp  <- file.path(raiz, "data", "raw", "day13", "frames")
dir.create(dir_gal, showWarnings = FALSE, recursive = TRUE)
dir.create(dir_tmp, showWarnings = FALSE, recursive = TRUE)

N_FRAMES <- as.integer(Sys.getenv("DAY13_FRAMES", "72"))
FPS      <- 12
LARGO    <- 0.16          # longitud de la estela (fracción del arco)
N_TOP    <- 90

# --- Datos -------------------------------------------------------------------
red   <- readRDS(file.path(dir_proc, "day13_cites_network.rds"))
fauna <- red$flujos[reexportacion == FALSE & grupo_fuente == "Silvestre" &
                      grupo != "Plantas"]

aristas <- fauna[, .(volumen = sum(volumen)), by = .(Exporter, Importer)]
grupo_arista <- fauna[, .(v = sum(volumen)), by = .(Exporter, Importer, grupo)]
setorder(grupo_arista, Exporter, Importer, -v)
grupo_arista <- grupo_arista[, .SD[1], by = .(Exporter, Importer)]
aristas <- merge(aristas, grupo_arista[, .(Exporter, Importer, grupo)],
                 by = c("Exporter", "Importer"))

top <- aristas[order(-volumen)][1:N_TOP]
mx  <- aristas[Exporter == "MX" | Importer == "MX"]
mapa_aristas <- unique(rbind(top, mx, fill = TRUE))
setorder(mapa_aristas, -volumen)
mapa_aristas[, id := .I]
cat("Arcos animados:", nrow(mapa_aristas), "| cobertura:",
    round(100 * sum(mapa_aristas$volumen) / sum(aristas$volumen), 1), "%\n")

# --- Países ------------------------------------------------------------------
mundo <- st_read(file.path(raiz, "data", "raw", "day04", "ne_50m_admin_0_countries.geojson"),
                 quiet = TRUE)
mundo <- mundo[mundo$CONTINENT != "Antarctica", ]
mundo <- st_break_antimeridian(mundo, lon_0 = 0)
mundo <- st_simplify(st_transform(mundo, 4326), dTolerance = 0.02, preserveTopology = TRUE)

llaves <- as.data.table(st_drop_geometry(mundo))[, .(ISO_A2_EH, NAME_ES)]
llaves <- unique(llaves[!is.na(ISO_A2_EH) & ISO_A2_EH != "-99"], by = "ISO_A2_EH")
extra <- data.table(ISO_A2_EH = c("BQ", "GP", "MQ", "RE", "SJ", "TK", "UM", "TW", "MO"),
                    NAME_ES = c("Bonaire", "Guadalupe", "Martinica", "Reunión", "Svalbard",
                                "Tokelau", "Islas menores de EE.UU.", "Taiwán", "Macao"))
llaves <- unique(rbind(llaves, extra, use.names = TRUE), by = "ISO_A2_EH")
nombre_de <- function(x) { n <- llaves$NAME_ES[match(x, llaves$ISO_A2_EH)]; fifelse(is.na(n), x, n) }

centros <- as.data.table(st_coordinates(st_point_on_surface(mundo)))[, .(lon = X, lat = Y)]
centros[, ISO_A2_EH := mundo$ISO_A2_EH]
centros <- centros[!is.na(ISO_A2_EH)][!duplicated(ISO_A2_EH)]

proj <- "+proj=robin +lon_0=0 +datum=WGS84 +units=m +no_defs"
mundo_p <- st_transform(mundo, proj)

# --- Puntos de todos los arcos ----------------------------------------------
partes <- vector("list", nrow(mapa_aristas))
for (i in seq_len(nrow(mapa_aristas))) {
  a <- centros[ISO_A2_EH == mapa_aristas$Exporter[i]]
  b <- centros[ISO_A2_EH == mapa_aristas$Importer[i]]
  if (!nrow(a) || !nrow(b)) next
  p <- puntos_arco(a$lon[1], a$lat[1], b$lon[1], b$lat[1])
  if (is.null(p)) next
  p[, `:=`(id = mapa_aristas$id[i], grupo = mapa_aristas$grupo[i],
           vol = mapa_aristas$volumen[i])]
  partes[[i]] <- p
}
pts <- rbindlist(partes)

suave <- function(x, k = 8) {           # escala de tamaño/normalización
  r <- range(x); (x - r[1]) / (r[2] - r[1] + 1e-9)
}
escala_vol <- suave(log10(pts$vol))
pts[, w := 0.35 + 1.9 * escala_vol]
pts[, grupo := factor(grupo, levels = names(ETIQUETA))]

pts_sf <- st_as_sf(pts, coords = c("lon", "lat"), crs = 4326)
coords <- st_coordinates(st_transform(pts_sf, proj))
pts[, `:=`(x = coords[, 1], y = coords[, 2])]
setorder(pts, id, tramo, t)

# Fase inicial repartida con la razón áurea para que no entren todas a la vez
fases <- data.table(id = sort(unique(pts$id)))
fases[, fase := ((id * 0.61803398875) %% 1)]

# --- Nodos -------------------------------------------------------------------
nodos <- rbind(
  data.table(ISO_A2_EH = mapa_aristas$Exporter, v = mapa_aristas$volumen, rol = "exp"),
  data.table(ISO_A2_EH = mapa_aristas$Importer, v = mapa_aristas$volumen, rol = "imp"))
nodos <- nodos[, .(exp = sum(v[rol == "exp"]), imp = sum(v[rol == "imp"])), by = ISO_A2_EH]
nodos <- merge(nodos, centros[, .(ISO_A2_EH, lon, lat)], by = "ISO_A2_EH")
nodos <- st_as_sf(nodos, coords = c("lon", "lat"), crs = 4326) |> st_transform(proj)
nodos$balance <- nodos$exp - nodos$imp
nodos$tam <- 1 + 3.2 * suave(sqrt(nodos$exp + nodos$imp))

# --- Animación ---------------------------------------------------------------
etiquetas <- data.table(
  texto = c("Estados Unidos", "México", "Indonesia", "Australia", "Europa importadora"),
  lon   = c(-118, -112, 121, 134, 18),
  lat   = c(51, 21, 4, -19, 63))
etiquetas <- st_transform(st_as_sf(etiquetas, coords = c("lon", "lat"), crs = 4326), proj)

titulo <- "¿Hacia dónde drena la biodiversidad del planeta?"
subtitulo <- sprintf(
  "Comercio CITES de fauna silvestre, 2015–2024 · %s especímenes en las %d rutas principales (%.0f%% del volumen total)",
  fmt(round(sum(fauna$volumen))), nrow(mapa_aristas),
  100 * sum(mapa_aristas$volumen) / sum(aristas$volumen))

pie <- map_caption(13, "Interactions",
                   "CITES Trade Database v2026.1 (UNEP-WCMC), 2015–2024")

archivos <- character(N_FRAMES)
for (f in 0:(N_FRAMES - 1)) {
  avance <- f / N_FRAMES
  h <- fases[, .(id, t_head = (fase + avance) %% 1)]

  pts[, d := (t - h$t_head[match(id, h$id)]) %% 1]
  cola <- pts[d < LARGO]
  cola[, alfa := 0.95 * (1 - d / LARGO)^1.35]
  cabeza <- cola[order(id, d)][, .SD[1], by = id]

  p <- ggplot() +
    geom_sf(data = mundo_p, fill = COL$tierra, color = COL$frontera, linewidth = 0.12) +
    geom_path(data = pts, aes(x = x, y = y, group = interaction(id, tramo)),
              color = "#94A3B8", alpha = 0.10, linewidth = 0.25,
              lineend = "round", show.legend = FALSE) +
    geom_path(data = cola, aes(x = x, y = y, group = interaction(id, tramo),
                               color = grupo, alpha = alfa, linewidth = w),
              lineend = "round", show.legend = FALSE) +
    geom_point(data = cabeza, aes(x = x, y = y, color = grupo), size = 1.9,
               alpha = 0.95, show.legend = FALSE) +
    geom_sf(data = nodos, aes(size = tam, fill = balance > 0), shape = 21,
            color = COL$papel, stroke = 0.4, alpha = 0.95) +
    geom_sf_label(data = etiquetas, aes(label = texto), size = 2.4,
                  color = COL$tinta, fill = alpha(COL$papel, 0.88), label.size = 0,
                  label.padding = unit(0.12, "lines"), fontface = "bold") +
    scale_color_manual(values = unlist(COL[names(ETIQUETA)])) +
    scale_alpha_identity() +
    scale_linewidth_identity() +
    scale_size_identity() +
    scale_fill_manual(values = c(`TRUE` = "#F8FAFC", `FALSE` = "#F59E0B"), guide = "none") +
    labs(title = titulo, subtitle = subtitulo, caption = pie) +
    theme_map2026(base_size = 11) +
    theme(legend.position = "none",
          panel.background = element_rect(fill = COL$oceano, color = COL$marco, linewidth = 0.6),
          plot.title = element_text(size = 21, face = "bold", color = COL$tinta),
          plot.subtitle = element_text(size = 10.5, color = COL$tinta2),
          plot.caption = element_text(size = 7.4, color = COL$tinta3, hjust = 0,
                                      margin = margin(t = 8, b = 4)),
          plot.margin = margin(10, 14, 8, 14))

  archivos[f + 1] <- file.path(dir_tmp, sprintf("frame_%03d.png", f))
  agg_png(archivos[f + 1], width = 11, height = 6.7, units = "in", res = 150,
          background = COL$papel)
  print(p)
  dev.off()
  if ((f + 1) %% 12 == 0) cat("fotograma", f + 1, "de", N_FRAMES, "\n")
}

# --- Exportar ----------------------------------------------------------------
gif_file <- file.path(dir_gal, "day13_interactions_cites_flujos.gif")
mp4_file <- file.path(dir_gal, "day13_interactions_cites_flujos.mp4")

gifski::gifski(archivos, gif_file = gif_file, width = 1100, height = 670,
               delay = 1 / FPS, loop = TRUE, progress = FALSE)
cat("GIF:", gif_file, "|", round(file.size(gif_file) / 1e6, 1), "MB\n")

av::av_encode_video(archivos, output = mp4_file, framerate = FPS,
                    vfilter = "scale=trunc(iw/2)*2:trunc(ih/2)*2")
cat("MP4:", mp4_file, "|", round(file.size(mp4_file) / 1e6, 1), "MB\n")
