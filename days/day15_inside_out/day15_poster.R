# ==============================================================================
# Día 15 — Inside out | Póster cartográfico
# "El Valle de México al revés"
#
# Requiere: data/processed/day15_inside_out.rds
#           data/processed/day15_dem_30m.tif
# Salidas:  outputs/high_res/day15_inside_out_valle_invertido.png (300 dpi)
#           outputs/gallery/day15_inside_out_valle_invertido.png  (150 dpi)
# Autor:    Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

user_lib <- "C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3"
if (dir.exists(user_lib) && !(user_lib %in% .libPaths())) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(terra)
  library(sf)
  library(dplyr)
  library(ragg)
})

sf_use_s2(FALSE)
msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n")
alpha <- function(col, a) grDevices::adjustcolor(col, alpha.f = a)

# ==============================================================================
# 0. Paleta editorial (AGENTS.md)
# ==============================================================================
CREAM  <- "#F7F4EB"
PANEL  <- "#EFEAD9"
INK    <- "#0F172A"
SLATE  <- "#334155"
MUTED  <- "#475569"
BORDER <- "#94A3B8"
GOLD   <- "#A87B14"
GOLD_L <- "#E8C15A"
LAKE   <- "#8FB3D0"
LAKE_D <- "#2F5D80"
SHORE  <- "#D9A93F"

# Fuera del vaso: altitud invertida (abismo azul -> orilla dorada)
# Sierras: de la orilla de la cuenca (2,450 m) al abismo de 4,134 m
PAL_OUT <- colorRampPalette(c(
  "#060C16", "#0C1A2B", "#162E44", "#284E63",
  "#4E7C8C", "#8CA6A0", "#C9A862", "#D8BE8A"
))(256)

# Vaso lacustre: de la orilla (2,450 m) al fondo (2,218 m), que es la cumbre
PAL_IN <- colorRampPalette(c(
  "#D8BE8A", "#D9A445", "#DCA648", "#DEA63C"
))(256)

# Color de una elevación: dos tramos continuos, con bisagra en 2,450 m
elev_cols <- function(z) {
  z  <- pmin(pmax(z, zmin), zmax)
  lo <- pmin(z, 2300)
  hi <- pmax(z, 2300)
  tt_in  <- (2300 - lo) / (2300 - zmin)
  tt_out <- 1 - (hi - 2300) / (zmax - 2300)
  ci <- PAL_IN[pmin(255, pmax(1, floor(tt_in * 255) + 1))]
  co <- PAL_OUT[pmin(255, pmax(1, floor(tt_out * 255) + 1))]
  ifelse(z < 2300, ci, co)
}



# Hipsometría clásica para el mapa "al derecho"
PAL_NOR <- colorRampPalette(c(
  "#3C6146", "#6E8C4E", "#A5AA6A", "#C9BC8C",
  "#D9C6A8", "#C9A88C", "#EFEDE4"
))(256)

# ==============================================================================
# 1. Datos
# ==============================================================================
msg("Cargando datos del Día 15...")
ds <- readRDS("data/processed/day15_inside_out.rds")
zmvm   <- st_transform(ds$zmvm, 6372)
stats  <- ds$stats
zmin   <- ds$zmin
zmax   <- ds$zmax
cota   <- ds$cota_lago
zocalo <- ds$zocalo

dem <- rast("data/processed/day15_dem_30m.tif")

# DEM suavizado: escala regional, sin el ruido del tejido urbano
d90 <- aggregate(dem, 5, fun = "mean", na.rm = TRUE)
d90 <- focal(d90, matrix(1, 7, 7), fun = "mean", na.rm = TRUE)
hs  <- shade(terrain(d90, "slope", unit = "radians"),
             terrain(d90, "aspect", unit = "radians"),
             angle = 40, direction = 315) / 255

e  <- ext(d90)
XL <- c(e$xmin, e$xmax); YL <- c(e$ymin, e$ymax)

# Silueta generalizada del vaso lacustre (trazo editorial y mapa pequeño)
lago_sil <- aggregate(dem, 30, fun = "mean", na.rm = TRUE)
lago_sil <- focal(lago_sil, matrix(1, 5, 5), fun = "mean", na.rm = TRUE)
lago_sil <- ifel(lago_sil <= 2250, 1, NA) |>
  as.polygons(dissolve = TRUE) |>
  st_as_sf() |>
  st_make_valid() |>
  st_transform(6372) |>
  st_simplify(dTolerance = 600, preserveTopology = TRUE)

# ==============================================================================
# 2. Utilidades de dibujo
# ==============================================================================
cols_from <- function(values, pal) {
  idx <- pmin(255, pmax(1, floor(values * 255) + 1))
  idx[is.na(idx)] <- 1
  pal[idx]
}

apply_shade <- function(cols, s, ambient = 0.86, contrast = 0.34) {
  rgbm <- grDevices::col2rgb(cols) / 255
  ss <- pmin(1, ambient + contrast * s); ss[is.na(ss)] <- 1
  for (k in 1:3) rgbm[k, ] <- pmin(1, rgbm[k, ] * as.vector(ss))
  rgbm
}

to_array <- function(rgbm, nr, nc) {
  arr <- array(0, dim = c(nr, nc, 3))
  for (k in 1:3) arr[, , k] <- matrix(rgbm[k, ], nrow = nr, ncol = nc)
  arr
}

# Mapa principal: altitud invertida fuera del vaso y profundidad dentro de él
make_main <- function() {
  m <- as.matrix(d90, wide = TRUE)
  s <- as.matrix(hs, wide = TRUE)
  cols <- elev_cols(m)
  to_array(apply_shade(cols, s, ambient = 0.84, contrast = 0.36), nrow(m), ncol(m))
}

# Mapa pequeño "al derecho"
make_mini <- function() {
  m <- as.matrix(d90, wide = TRUE)
  s <- as.matrix(hs, wide = TRUE)
  tt <- (m - zmin) / (zmax - zmin)
  cols <- cols_from(tt, PAL_NOR)
  to_array(apply_shade(cols, s, ambient = 0.85, contrast = 0.28), nrow(m), ncol(m))
}

# Panel en pulgadas (origen abajo-izquierda sobre un lienzo de 12 x 16 in)
new_panel <- function(x0, y0, x1, y1, canvas = FALSE) {
  par(fig = c(x0 / 12, x1 / 12, y0 / 16, y1 / 16), mar = c(0, 0, 0, 0), new = TRUE)
  plot.new()
  if (canvas) plot.window(xlim = c(x0, x1), ylim = c(y0, y1), xaxs = "i", yaxs = "i")
}

map_window <- function() {
  plot.window(xlim = XL, ylim = YL, xaxs = "i", yaxs = "i", asp = 1)
}

draw_img <- function(arr) {
  rasterImage(arr, XL[1], YL[1], XL[2], YL[2], interpolate = TRUE)
}

lab <- function(lon, lat, txt, cex = 0.55, col = "#F7F4EB", font = 1, adj = 0.5) {
  p <- st_transform(st_sfc(st_point(c(lon, lat)), crs = 4326), 6372)
  xy <- st_coordinates(p)
  text(xy[1, 1], xy[1, 2], txt, cex = cex, col = col, font = font, adj = adj,
       family = "sans")
}

fmt <- function(x) formatC(round(x), big.mark = ",", format = "d")

# ==============================================================================
# 3. Lienzo y composición
# ==============================================================================
render <- function(path, res, invert = TRUE) {
  agg_png(path, width = 12, height = 16, units = "in", res = res, background = CREAM)
  par(family = "sans", xpd = NA)

  # --- Variante: mapa invertido o mapa real ---------------------------------
  V <- if (invert) list(
    palabra      = "al revés",
    subtitulo    = "La cuenca que fue lago\nes hoy la cumbre de su propio mapa",
    titulo_panel = "EL RELIEVE INVERTIDO   ·   cada celda reflejada respecto al plano medio de la cuenca",
    col_vaso     = "#2B1F06", col_vaso2 = alpha("#2B1F06", 0.75),
    col_sierra   = alpha("#E6EEF6", 0.95), col_menor = alpha("#3B2A08", 0.80),
    l_vaso       = "EL VASO LACUSTRE", l_vaso2 = "la cumbre de este mapa",
    l_ajusco     = "ABISMO DEL AJUSCO · 3,930 m",
    l_cruces     = "ABISMO DE LAS\nCRUCES",
    l_guadalupe  = "ABISMO DE GUADALUPE",
    l_estrella   = "Cerro de la Estrella\nisla convertida en abismo",
    col_texcoco  = alpha("#4A3508", 0.9),
    leg_top      = "cumbre", leg_top2 = "el vaso lacustre",
    leg_bot      = "abismo", leg_bot2 = "las sierras",
    leg_nota     = "El color recorre la altitud al revés: el fondo del valle ocupa\nla parte alta de la rampa y las sierras, la baja. Dentro del vaso,\nel tono se satura hacia lo más hundido (hasta 27 m bajo la cota).",
    t2           = "LA INVERSIÓN",
    b2           = "Cada celda del modelo digital de elevación se\nrefleja respecto al plano medio de la cuenca.\nEl fondo del vaso (2,218 m) asciende a la cima;\nel Ajusco y las Cruces descienden a abismos."
  ) else list(
    palabra      = "al derecho",
    subtitulo    = "La misma cuenca sin invertir:\nel lago en el fondo del valle",
    titulo_panel = "EL RELIEVE REAL   ·   la cuenca tal como es, sin invertir",
    col_vaso     = "#F7F4EB", col_vaso2 = alpha("#F7F4EB", 0.80),
    col_sierra   = alpha("#F7F4EB", 0.95), col_menor = alpha("#F7F4EB", 0.85),
    l_vaso       = "EL VASO LACUSTRE", l_vaso2 = "el fondo del valle",
    l_ajusco     = "SIERRA DEL AJUSCO · 3,930 m",
    l_cruces     = "SIERRA DE LAS\nCRUCES",
    l_guadalupe  = "SIERRA DE GUADALUPE",
    l_estrella   = "Cerro de la Estrella\nisla del antiguo lago",
    col_texcoco  = alpha("#F7F4EB", 0.9),
    leg_top      = "cumbres", leg_top2 = "las sierras",
    leg_bot      = "fondo del valle", leg_bot2 = "el antiguo lago",
    leg_nota     = "El color sigue la altitud: claro en las cumbres,\noscuro en el fondo del valle y azul en el agua.",
    t2           = "LA COMPARACIÓN",
    b2           = "Esta versión conserva la altitud real: el lago\nvuelve al fondo del valle y las sierras a su sitio.\nSin inversión se gana en lectura geográfica,\npero se pierde el hallazgo visual del mapa."
  )

  # --- Papel ----------------------------------------------------------------
  new_panel(0, 0, 12, 16, canvas = TRUE)
  rect(0, 0, 12, 16, col = CREAM, border = NA)

  # ==========================================================================
  # 4. Cabecera
  # ==========================================================================
  text(0.55, 15.45, "#30DAYMAPCHALLENGE 2026    ·    DÍA 15    ·    INSIDE OUT",
       adj = c(0, 0.5), cex = 0.60, col = GOLD, font = 2)
  text(0.55, 14.80, "El Valle de México", adj = c(0, 0.5),
       cex = 2.80, col = INK, family = "serif", font = 2)
  text(0.55, 14.08, V$palabra, adj = c(0, 0.5),
       cex = 2.80, col = GOLD, family = "serif", font = 3)
  text(6.95, 14.55,
       V$subtitulo,
       adj = c(0, 0.5), cex = 0.78, col = MUTED, family = "serif", font = 3)
  segments(0.55, 13.62, 11.45, 13.62, col = alpha(BORDER, 0.7), lwd = 1)

  # ==========================================================================
  # 5. Mapa principal
  # ==========================================================================
  msg("Dibujando mapa principal...")
  map_w <- 7.75
  map_h <- map_w * diff(YL) / diff(XL)
  new_panel(0.45, 13.30 - map_h, 0.45 + map_w, 13.30)
  par(xpd = FALSE)
  map_window()
  if (invert) {
    draw_img(make_main())
    # Límite municipal de la ZMVM
    plot(st_geometry(zmvm), add = TRUE, border = alpha("#3B2A08", 0.06), lwd = 0.26)
    plot(st_geometry(st_union(zmvm)), add = TRUE, border = alpha("#F7F4EB", 0.26), lwd = 0.6)
  } else {
    draw_img(make_mini())
    plot(st_geometry(lago_sil), add = TRUE, col = alpha(LAKE, 0.22), border = LAKE_D, lwd = 0.7)
    plot(st_geometry(zmvm), add = TRUE, border = alpha(INK, 0.30), lwd = 0.28)
  }

  # Zócalo
  zc <- st_coordinates(zocalo)
  points(zc[1, 1], zc[1, 2], pch = 21, bg = INK, col = CREAM, cex = 0.7, lwd = 1)

  rect(XL[1], YL[1], XL[2], YL[2], col = NA, border = BORDER, lwd = 1.3)
  par(xpd = FALSE)

  # --- Esferas de población por municipio (Censo 2020) ----------------------
  pb  <- ds$mun_pob
  pxy <- st_coordinates(pb)
  dentro <- pxy[, 1] > XL[1] + 3000 & pxy[, 1] < XL[2] - 3000 &
            pxy[, 2] > YL[1] + 3000 & pxy[, 2] < YL[2] - 3000
  pb  <- pb[dentro, ]; pxy <- pxy[dentro, ]
  r_m <- 2600 * sqrt(pb$pob / 1e6)
  o   <- order(pb$pob, decreasing = TRUE)
  symbols(pxy[o, 1], pxy[o, 2], circles = r_m[o], inches = FALSE, add = TRUE,
          bg = alpha("#0F172A", 0.06), fg = alpha("#0F172A", 0.50), lwd = 0.6)

  # --- Etiquetas -------------------------------------------------------------
  lab(-99.190, 19.398, V$l_vaso, cex = 0.72, col = V$col_vaso, font = 2)
  lab(-99.190, 19.374, V$l_vaso2, cex = 0.50, col = V$col_vaso2, font = 3)
  lab(-99.272, 19.222, V$l_ajusco, cex = 0.48, col = V$col_sierra)
  lab(-99.398, 19.352, V$l_cruces, cex = 0.46, col = V$col_sierra, adj = c(0, 0.5))
  lab(-99.118, 19.588, V$l_guadalupe, cex = 0.48, col = V$col_sierra, adj = c(0, 0.5))
  lab(-99.092, 19.338, V$l_estrella, cex = 0.38, col = V$col_menor, adj = c(0, 0.5))
  lab(-99.1332, 19.4435, "Zócalo", cex = 0.42, col = V$col_vaso, font = 2, adj = c(0.5, 0))
  lab(-98.965, 19.478, "Vaso de Texcoco", cex = 0.44, col = V$col_texcoco, font = 3)

  # Nombres de las dos mayores concentraciones
  for (i in 1:2) {
    text(pxy[o[i], 1] + r_m[o[i]] + 700, pxy[o[i], 2], pb$NOMGEO[o[i]],
         adj = c(0, 0.5), cex = 0.34, col = if (invert) "#2B1F06" else "#F7F4EB", font = 2)
  }

  # Clave de tamaño (caja sobre el mapa)
  bx0 <- XL[2] - 17800; by0 <- YL[1] + 2200
  bx1 <- XL[2] - 1800;  by1 <- by0 + 14200
  rect(bx0, by0, bx1, by1, col = alpha(CREAM, 0.92), border = alpha(BORDER, 0.9), lwd = 0.6)
  text(bx0 + 900, by1 - 1300, "POBLACIÓN 2020", adj = c(0, 1), cex = 0.32, col = INK, font = 2)
  for (i in 0:2) {
    p  <- c(1e6, 5e5, 2e5)[i + 1]
    rr <- 2600 * sqrt(p / 1e6)
    yy <- by1 - 4400 - i * 3600
    symbols(bx0 + 3300, yy, circles = rr, inches = FALSE, add = TRUE,
            bg = alpha("#0F172A", 0.10), fg = alpha("#0F172A", 0.55), lwd = 0.5)
    text(bx0 + 7000, yy, c("1 M", "500 mil", "200 mil")[i + 1],
         adj = c(0, 0.5), cex = 0.32, col = INK)
  }

  # --- Escala ---------------------------------------------------------------
  sx <- XL[1] + 4200; sy <- YL[1] + 3000
  for (i in 0:4) {
    rect(sx + i * 2500, sy, sx + (i + 1) * 2500, sy + 560,
         col = if (i %% 2 == 0) CREAM else INK, border = NA)
  }
  rect(sx, sy, sx + 12500, sy + 560, border = alpha(INK, 0.7), lwd = 0.6)
  text(sx, sy + 1000, "0", cex = 0.38, col = if (invert) INK else CREAM, adj = c(0.5, 0))
  text(sx + 5000, sy + 1000, "5", cex = 0.38, col = if (invert) INK else CREAM, adj = c(0.5, 0))
  text(sx + 10000, sy + 1000, "10 km", cex = 0.38, col = if (invert) INK else CREAM, adj = c(0.5, 0))

  # --- Norte ----------------------------------------------------------------
  nx <- XL[2] - 3000; ny <- YL[2] - 5400
  text(nx, ny + 3000, "N", cex = 0.58, col = "#F7F4EB", font = 2)
  arrows(nx, ny + 2000, nx, ny + 200, length = 0.055, lwd = 1.4, col = "#F7F4EB")

  # Título del panel
  par(xpd = NA)
  text(XL[1], YL[2] + 750,
       V$titulo_panel,
       adj = c(0, 0), cex = 0.50, col = MUTED, font = 2)

  # ==========================================================================
  # 6. Mapa pequeño "al derecho": lago y alcaldías
  # ==========================================================================
  msg("Dibujando mapa al derecho...")
  mini_w <- 2.90
  mini_h <- mini_w * diff(YL) / diff(XL)
  new_panel(8.55, 13.30 - mini_h, 8.55 + mini_w, 13.30)
  par(xpd = FALSE)
  map_window()
  draw_img(if (invert) make_mini() else make_main())
  if (invert) {
    plot(st_geometry(lago_sil), add = TRUE, col = alpha(LAKE, 0.85), border = LAKE_D, lwd = 0.7)
    plot(st_geometry(zmvm), add = TRUE, border = alpha(INK, 0.35), lwd = 0.3)
  } else {
    plot(st_geometry(zmvm), add = TRUE, border = alpha("#3B2A08", 0.10), lwd = 0.26)
    plot(st_geometry(st_union(zmvm)), add = TRUE, border = alpha("#F7F4EB", 0.26), lwd = 0.5)
  }
  rect(XL[1], YL[1], XL[2], YL[2], col = NA, border = BORDER, lwd = 1.1)
  par(xpd = NA)
  text(XL[1], YL[2] + 750,
       if (invert) "EL MISMO VALLE, AL DERECHO" else "EL MISMO VALLE, AL REVÉS",
       adj = c(0, 0), cex = 0.50, col = MUTED, font = 2)

  # ==========================================================================
  # 7. Leyenda de color
  # ==========================================================================
  new_panel(8.55, 7.68, 11.45, 10.32, canvas = TRUE)
  text(8.55, 10.20, "CÓMO LEER EL COLOR", adj = c(0, 1), cex = 0.50, col = MUTED, font = 2)

  # Barra vertical: rampa continua de elevación (idéntica a la del mapa)
  by0 <- 8.30; by1 <- 10.00; bx0 <- 8.62; bx1 <- 8.90
  nr <- 256
  zs <- seq(zmax, zmin, length.out = nr)
  gcols <- if (invert) elev_cols(zs) else PAL_NOR[seq_len(nr)]
  grad <- array(0, dim = c(nr, 1, 3))
  palg <- col2rgb(gcols) / 255
  for (k in 1:3) grad[, 1, k] <- palg[k, nr:1]
  rasterImage(grad, bx0, by0, bx1, by1, interpolate = TRUE)
  rect(bx0, by0, bx1, by1, border = BORDER, lwd = 0.6)

  # Marcas: fondo del vaso, cota lacustre, media montaña y cima de la sierra
  ticks <- c(zmin, 3000, zmax)
  tys <- by0 + (1 - (ticks - zmin) / (zmax - zmin)) * (by1 - by0)
  segments(bx1, tys, bx1 + 0.08, tys, col = SLATE, lwd = 0.6)
  text(bx1 + 0.13, tys, sprintf("%s m", fmt(ticks)), adj = c(0, 0.5), cex = 0.40, col = SLATE)

  text(9.40, 9.90, V$leg_top, adj = c(0, 0.5), cex = 0.44, col = GOLD, font = 2)
  text(9.40, 9.80, V$leg_top2, adj = c(0, 0.5), cex = 0.38, col = MUTED)
  text(9.40, 8.48, V$leg_bot, adj = c(0, 0.5), cex = 0.44, col = LAKE_D, font = 2)
  text(9.40, 8.38, V$leg_bot2, adj = c(0, 0.5), cex = 0.38, col = MUTED)

  text(8.55, 8.10, V$leg_nota,
       adj = c(0, 1), cex = 0.38, col = MUTED)

  # ==========================================================================
  # 8. Cifras
  # ==========================================================================
  new_panel(8.55, 5.78, 11.45, 7.56, canvas = TRUE)
  text(8.55, 7.46, "EL VALLE EN CIFRAS", adj = c(0, 1), cex = 0.50, col = MUTED, font = 2)
  cifras <- c(
    "9.4 M" = "personas viven sobre el vaso (45.8 % de la ZMVM)",
    "1,114" = "km² bajo la cota lacustre (2,245 m)",
    "22.3"  = "% del suelo de la ZMVM dentro del vaso",
    "1,916" = "m de desnivel, invertidos en este mapa"
  )
  yy <- 7.14
  for (i in seq_along(cifras)) {
    text(8.55, yy, names(cifras)[i], adj = c(0, 0.5), cex = 1.15, col = INK,
         family = "serif", font = 2)
    text(9.42, yy, cifras[i], adj = c(0, 0.5), cex = 0.40, col = SLATE)
    yy <- yy - 0.33
  }

  # ==========================================================================
  # 9. Bloques de texto
  # ==========================================================================
  msg("Escribiendo texto...")
  new_panel(0, 0, 12, 16, canvas = TRUE)

  txt <- function(x, y, titulo, cuerpo) {
    text(x, y, titulo, adj = c(0, 1), cex = 0.56, col = GOLD, font = 2)
    text(x, y - 0.28, cuerpo, adj = c(0, 1), cex = 0.48, col = SLATE)
  }

  txt(0.55, 5.20, "EL VASO",
      "Bajo la cota de 2,245 m —la altura a la que se\nestabilizaban los lagos de Texcoco, Xochimilco,\nChalco, Xaltocan y Zumpango— quedan 1,114 km²\nde superficie plana: el lecho del antiguo lago.")
  txt(4.30, 5.20, V$t2, V$b2)
  txt(8.05, 5.20, "EL HUNDIMIENTO",
      "El fondo del valle ya está por debajo de la cota\ndel lago: la ciudad se hunde más rápido de lo que\nel drenaje desaloja el agua. El mapa al revés no\nes una fantasía; es la cuenca que vaciamos.")

  # ==========================================================================
  # 10. Cifra destacada: población
  # ==========================================================================
  segments(0.55, 4.02, 11.45, 4.02, col = alpha(BORDER, 0.7), lwd = 1)
  text(0.55, 3.22, "9.4", adj = c(0, 0.5), cex = 4.4, col = GOLD,
       family = "serif", font = 2)
  text(2.15, 3.44, "millones de personas", adj = c(0, 0.5), cex = 0.95, col = INK,
       family = "serif", font = 2)
  text(2.15, 3.02, "viven hoy sobre el vaso lacustre: el 45.8 % de la población\nde la Zona Metropolitana del Valle de México.",
       adj = c(0, 0.5), cex = 0.52, col = SLATE)
  segments(0.55, 2.42, 11.45, 2.42, col = alpha(BORDER, 0.7), lwd = 1)

  # ==========================================================================
  # 11. Pie
  # ==========================================================================
  segments(0.55, 1.62, 11.45, 1.62, col = alpha(BORDER, 0.7), lwd = 1)
  text(0.55, 1.28,
       "#30DayMapChallenge 2026  |  Día 15: Inside out  |  Fuente: Copernicus DEM GLO-30 (© ESA / Airbus)  ·  INEGI, Marco Geoestadístico y Censo de Población y Vivienda 2020",
       adj = c(0, 0.5), cex = 0.40, col = MUTED)
  text(0.55, 1.02,
       "Proyección Cónica Conforme de Lambert (EPSG:6372)  ·  Sombreado con azimut 315° y elevación solar 40°  ·  Procesado en R (terra, sf) y dibujado con R gráficos base.",
       adj = c(0, 0.5), cex = 0.40, col = MUTED)
  text(0.55, 0.68, "Fernando Dorantes Nieto  ·  @FerDoranNie",
       adj = c(0, 0.5), cex = 0.44, col = INK, font = 2)
  text(11.45, 0.68, "Noviembre de 2026", adj = c(1, 0.5), cex = 0.44, col = MUTED)

  dev.off()
}

# ==============================================================================
# 12. Salidas
# ==============================================================================
dir.create("outputs/high_res", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/gallery",  showWarnings = FALSE, recursive = TRUE)

msg("Render de alta resolución (300 dpi)...")
render("outputs/high_res/day15_inside_out_valle_invertido.png", 300, invert = TRUE)
msg("Render de galería (150 dpi)...")
render("outputs/gallery/day15_inside_out_valle_invertido.png", 150, invert = TRUE)

# Variante de comparación: el mismo valle sin invertir
msg("Render de la variante al derecho...")
render("outputs/high_res/day15_inside_out_valle_derecho.png", 300, invert = FALSE)
render("outputs/gallery/day15_inside_out_valle_derecho.png", 150, invert = FALSE)

msg("Póster Día 15 listo.")
