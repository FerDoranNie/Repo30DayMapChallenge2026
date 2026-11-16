# ==============================================================================
# Día 15 — Serie metropolitana | Póster por ciudad
# Valle de México · Monterrey · Guadalajara · Puebla
#
# Requiere: data/processed/day15_serie/<id>.rds y <id>_dem.tif
#           data/raw/day15/agua/<id>_agua_{pol,lin}.geojson
# Salidas:  outputs/high_res/day15_serie_<id>.png
#           outputs/gallery/day15_serie_<id>.png
# Autor:    Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

user_lib <- "C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3"
if (dir.exists(user_lib) && !(user_lib %in% .libPaths())) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(terra); library(sf); library(dplyr); library(ragg)
})
sf_use_s2(FALSE)
msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n")
alpha <- function(col, a) grDevices::adjustcolor(col, alpha.f = a)

CREAM  <- "#F7F4EB"; INK <- "#0F172A"; SLATE <- "#334155"
MUTED  <- "#475569"; BORDER <- "#94A3B8"; GOLD <- "#A87B14"
LAKE   <- "#6FA3C6"; LAKE_D <- "#2F5D80"
SHORE  <- "#D9A93F"

PAL_OUT <- colorRampPalette(c(
  "#060C16", "#0C1A2B", "#162E44", "#284E63",
  "#4E7C8C", "#8CA6A0", "#C9A862", "#D8BE8A"
))(256)
PAL_IN <- colorRampPalette(c(
  "#D8BE8A", "#D9A445", "#DCA648", "#DEA63C"
))(256)
PAL_NOR <- colorRampPalette(c(
  "#3C6146", "#6E8C4E", "#A5AA6A", "#C9BC8C",
  "#D9C6A8", "#C9A88C", "#EFEDE4"
))(256)

fmt <- function(x) formatC(round(x), big.mark = ",", format = "d")

# --- Rampa continua con bisagra en la cota urbana -----------------------------
# La llanura urbana (<= cota) es una meseta de oro; por encima, la sierra azul.
elev_cols <- function(z, zmin, zmax, hinge) {
  z[is.na(z)] <- hinge
  z <- pmin(pmax(z, zmin), zmax)
  oro <- grDevices::col2rgb("#DFA83A")[, 1] / 255
  tt_out <- 1 - (pmax(z, hinge) - hinge) / max(1, zmax - hinge)
  co <- grDevices::col2rgb(PAL_OUT[pmin(255, pmax(1, floor(tt_out * 255) + 1))]) / 255
  w <- pmin(1, pmax(0, (z - hinge) / 220))
  out <- co
  for (k in 1:3) out[k, ] <- (1 - w) * oro[k] + w * co[k, ]
  grDevices::rgb(out[1, ], out[2, ], out[3, ])
}

apply_shade <- function(cols, s, ambient = 0.84, contrast = 0.36) {
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

new_panel <- function(x0, y0, x1, y1, canvas = FALSE) {
  par(fig = c(x0 / 12, x1 / 12, y0 / 16, y1 / 16), mar = c(0, 0, 0, 0), new = TRUE)
  plot.new()
  if (canvas) plot.window(xlim = c(x0, x1), ylim = c(y0, y1), xaxs = "i", yaxs = "i")
}

render_ciudad <- function(id, res) {
  ds <- readRDS(file.path("data/processed/day15_serie", paste0(id, ".rds")))
  cfg <- ds$cfg
  dem <- rast(ds$dem)
  zmin <- ds$zmin; zmax <- ds$zmax
  mun <- ds$mun; pb <- ds$mun_pob; st <- ds$stats

  # Cota urbana: elevación en el centroide poblacional + 120 m
  cen <- st_coordinates(st_centroid(st_union(mun)))
  zcen <- terra::extract(dem, terra::vect(st_sfc(st_point(cen[1, ]), crs = 6372)))[, 2]
  hinge <- min(zmax - 200, max(zmin + 120, zcen + 120))

  # DEM suavizado (150 m) y sombreado
  d150 <- aggregate(dem, 2, "mean", na.rm = TRUE)
  d150 <- focal(d150, matrix(1, 5, 5), "mean", na.rm = TRUE)
  hs <- shade(terrain(d150, "slope", unit = "radians"),
              terrain(d150, "aspect", unit = "radians"),
              angle = 40, direction = 315) / 255

  e <- ext(d150); XL <- c(e$xmin, e$xmax); YL <- c(e$ymin, e$ymax)

  # Agua (OSM)
  fpol <- file.path("data/raw/day15/agua", paste0(id, "_agua_pol.geojson"))
  flin <- file.path("data/raw/day15/agua", paste0(id, "_agua_lin.geojson"))
  agua_pol <- if (file.exists(fpol)) st_transform(st_read(fpol, quiet = TRUE), 6372) else NULL
  agua_lin <- if (file.exists(flin)) st_transform(st_read(flin, quiet = TRUE), 6372) else NULL
  if (!is.null(agua_pol)) agua_pol <- agua_pol[!st_is_empty(agua_pol), ]

  # Punto más alto de la ventana
  k_max <- which.max(terra::values(dem, mat = FALSE))
  p_max <- st_sfc(st_point(terra::xyFromCell(dem, k_max)), crs = 6372)

  # --- arrays ----------------------------------------------------------------
  m <- as.matrix(d150, wide = TRUE); s <- as.matrix(hs, wide = TRUE)
  img_inv <- to_array(apply_shade(elev_cols(m, zmin, zmax, hinge), s), nrow(m), ncol(m))
  img_nor <- to_array(apply_shade(
    PAL_NOR[pmin(255, pmax(1, floor((m - zmin) / (zmax - zmin) * 255) + 1))],
    s, ambient = 0.85, contrast = 0.28), nrow(m), ncol(m))

  draw_img <- function(arr) rasterImage(arr, XL[1], YL[1], XL[2], YL[2], interpolate = TRUE)

  lab <- function(lon, lat, txt, ...) {
    p <- st_transform(st_sfc(st_point(c(lon, lat)), crs = 4326), 6372)
    xy <- st_coordinates(p)
    text(xy[1, 1], xy[1, 2], txt, family = "sans", ...)
  }

  path <- if (res > 200) "outputs/high_res" else "outputs/gallery"
  fout <- file.path(path, paste0("day15_serie_", id, ".png"))
  agg_png(fout, width = 12, height = 16, units = "in", res = res, background = CREAM)
  par(family = "sans", xpd = NA)

  new_panel(0, 0, 12, 16, canvas = TRUE)
  rect(0, 0, 12, 16, col = CREAM, border = NA)

  # Cabecera -----------------------------------------------------------------
  text(0.55, 15.45, "#30DAYMAPCHALLENGE 2026    ·    DÍA 15    ·    INSIDE OUT",
       adj = c(0, 0.5), cex = 0.60, col = GOLD, font = 2)
  text(0.55, 14.80, cfg$nombre, adj = c(0, 0.5), cex = 2.80, col = INK,
       family = "serif", font = 2)
  text(0.55, 14.08, "al revés", adj = c(0, 0.5), cex = 2.80, col = GOLD,
       family = "serif", font = 3)
  text(6.95, 14.55,
       "La ciudad ocupa el fondo del valle:\nen este mapa, la cumbre",
       adj = c(0, 0.5), cex = 0.78, col = MUTED, family = "serif", font = 3)
  segments(0.55, 13.62, 11.45, 13.62, col = alpha(BORDER, 0.7), lwd = 1)

  # Mapa principal -----------------------------------------------------------
  map_w <- 7.75; map_h <- map_w * diff(YL) / diff(XL)
  new_panel(0.45, 13.30 - map_h, 0.45 + map_w, 13.30)
  par(xpd = FALSE)
  plot.window(xlim = XL, ylim = YL, xaxs = "i", yaxs = "i", asp = 1)
  draw_img(img_inv)
  plot(st_geometry(mun), add = TRUE, border = alpha("#3B2A08", 0.07), lwd = 0.26)
  plot(st_geometry(st_union(mun)), add = TRUE, border = alpha("#F7F4EB", 0.26), lwd = 0.6)

  # Esferas de población
  pxy <- st_coordinates(pb)
  dentro <- pxy[, 1] > XL[1] + 3000 & pxy[, 1] < XL[2] - 3000 &
            pxy[, 2] > YL[1] + 3000 & pxy[, 2] < YL[2] - 3000
  pb2 <- pb[dentro, ]; pxy2 <- pxy[dentro, ]
  r_m <- 2600 * sqrt(pb2$pob / 1e6)
  o <- order(pb2$pob, decreasing = TRUE)
  symbols(pxy2[o, 1], pxy2[o, 2], circles = r_m[o], inches = FALSE, add = TRUE,
          bg = alpha("#0F172A", 0.06), fg = alpha("#0F172A", 0.50), lwd = 0.6)

  # Etiquetas
  cxy <- st_coordinates(st_centroid(st_union(mun)))
  text(cxy[1, 1], cxy[1, 2] + 2500, toupper(cfg$corto), cex = 0.72, col = "#2B1F06", font = 2)
  text(cxy[1, 1], cxy[1, 2] + 500, "la cumbre de este mapa", cex = 0.48,
       col = alpha("#2B1F06", 0.75), font = 3)
  pmax_xy <- st_coordinates(p_max)
  lx <- min(max(pmax_xy[1, 1], XL[1] + 9000), XL[2] - 9000)
  ly <- min(max(pmax_xy[1, 2] + 2500, YL[1] + 9000), YL[2] - 9000)
  text(lx, ly, sprintf("ABISMO · %s m", fmt(zmax)), cex = 0.46, col = alpha("#E6EEF6", 0.95))

  # Escala y norte
  sx <- XL[1] + 4200; sy <- YL[1] + 3000
  for (i in 0:4) {
    rect(sx + i * 2500, sy, sx + (i + 1) * 2500, sy + 560,
         col = if (i %% 2 == 0) CREAM else INK, border = NA)
  }
  rect(sx, sy, sx + 12500, sy + 560, border = alpha(INK, 0.7), lwd = 0.6)
  text(sx, sy + 1000, "0", cex = 0.38, col = INK, adj = c(0.5, 0))
  text(sx + 5000, sy + 1000, "5", cex = 0.38, col = INK, adj = c(0.5, 0))
  text(sx + 10000, sy + 1000, "10 km", cex = 0.38, col = INK, adj = c(0.5, 0))

  nx <- XL[2] - 3000; ny <- YL[2] - 5400
  text(nx, ny + 3000, "N", cex = 0.58, col = "#F7F4EB", font = 2)
  arrows(nx, ny + 2000, nx, ny + 200, length = 0.055, lwd = 1.4, col = "#F7F4EB")

  # Clave de esferas
  bx0 <- XL[2] - 17800; by0 <- YL[1] + 2200
  bx1 <- XL[2] - 1800;  by1 <- by0 + 14200
  rect(bx0, by0, bx1, by1, col = alpha(CREAM, 0.92), border = alpha(BORDER, 0.9), lwd = 0.6)
  text(bx0 + 900, by1 - 1300, "POBLACIÓN 2020", adj = c(0, 1), cex = 0.32, col = INK, font = 2)
  esc <- c(1e6, 5e5, 2e5)
  if (max(pb2$pob) < 1e6) esc <- c(5e5, 2e5, 1e5)
  for (i in 0:2) {
    rr <- 2600 * sqrt(esc[i + 1] / 1e6)
    yy <- by1 - 4400 - i * 3600
    symbols(bx0 + 3300, yy, circles = rr, inches = FALSE, add = TRUE,
            bg = alpha("#0F172A", 0.10), fg = alpha("#0F172A", 0.55), lwd = 0.5)
    text(bx0 + 7000, yy, c("1 M", "500 mil", "200 mil")[i + 1],
         adj = c(0, 0.5), cex = 0.32, col = INK)
  }

  par(xpd = NA)
  text(XL[1], YL[2] + 750,
       "EL RELIEVE INVERTIDO   ·   cada celda reflejada respecto al plano medio de la cuenca",
       adj = c(0, 0), cex = 0.50, col = MUTED, font = 2)

  # Mapa tradicional (arriba a la derecha) ------------------------------------
  mini_w <- 2.90; mini_h <- mini_w * diff(YL) / diff(XL)
  new_panel(8.55, 13.30 - mini_h, 8.55 + mini_w, 13.30)
  par(xpd = FALSE)
  plot.window(xlim = XL, ylim = YL, xaxs = "i", yaxs = "i", asp = 1)
  draw_img(img_nor)
  if (!is.null(agua_pol) && nrow(agua_pol) > 0) {
    plot(st_geometry(agua_pol), add = TRUE, col = alpha("#59A8D6", 0.92), border = alpha("#2F5D80", 0.5), lwd = 0.35)
  }
  if (!is.null(agua_lin) && nrow(agua_lin) > 0) {
    plot(st_geometry(agua_lin), add = TRUE, col = alpha("#4E9BC8", 0.75), lwd = 0.45)
  }
  plot(st_geometry(mun), add = TRUE, border = alpha(INK, 0.35), lwd = 0.3)
  rect(XL[1], YL[1], XL[2], YL[2], col = NA, border = BORDER, lwd = 1.1)
  par(xpd = NA)
  text(XL[1], YL[2] + 750, "LA MISMA CIUDAD, AL DERECHO · CON AGUA",
       adj = c(0, 0), cex = 0.50, col = MUTED, font = 2)

  # Leyenda ------------------------------------------------------------------
  new_panel(8.55, 7.68, 11.45, 10.32, canvas = TRUE)
  text(8.55, 10.20, "CÓMO LEER EL COLOR", adj = c(0, 1), cex = 0.50, col = MUTED, font = 2)
  by0 <- 8.30; by1 <- 10.00; bx0 <- 8.62; bx1 <- 8.90
  zs <- seq(zmax, zmin, length.out = 256)
  palg <- col2rgb(elev_cols(zs, zmin, zmax, hinge)) / 255
  grad <- array(0, dim = c(256, 1, 3))
  for (k in 1:3) grad[, 1, k] <- palg[k, 256:1]
  rasterImage(grad, bx0, by0, bx1, by1, interpolate = TRUE)
  rect(bx0, by0, bx1, by1, border = BORDER, lwd = 0.6)
  ticks <- c(zmin, zmax)
  tys <- by0 + (1 - (ticks - zmin) / (zmax - zmin)) * (by1 - by0)
  segments(bx1, tys, bx1 + 0.08, tys, col = SLATE, lwd = 0.6)
  text(bx1 + 0.13, tys, sprintf("%s m", fmt(ticks)), adj = c(0, 0.5), cex = 0.38, col = SLATE)
  text(9.40, 9.90, "cumbre", adj = c(0, 0.5), cex = 0.44, col = GOLD, font = 2)
  text(9.40, 9.80, "la ciudad", adj = c(0, 0.5), cex = 0.38, col = MUTED)
  text(9.40, 8.48, "abismo", adj = c(0, 0.5), cex = 0.44, col = LAKE_D, font = 2)
  text(9.40, 8.38, "las sierras", adj = c(0, 0.5), cex = 0.38, col = MUTED)
  text(8.55, 8.10, "El color recorre la altitud al revés: el fondo urbano ocupa\nla parte alta de la rampa y las sierras, la baja.",
       adj = c(0, 1), cex = 0.38, col = MUTED)

  # Cifras -------------------------------------------------------------------
  new_panel(8.55, 5.78, 11.45, 7.56, canvas = TRUE)
  text(8.55, 7.46, "LA CIUDAD EN CIFRAS", adj = c(0, 1), cex = 0.50, col = MUTED, font = 2)
  cifras <- setNames(
    c("personas en la zona metropolitana",
      "km² de superficie municipal",
      "m de desnivel, invertidos en este mapa",
      "municipios en la zona metropolitana"),
    c(sprintf("%.1f M", st$pob / 1e6), fmt(st$area_km2),
      fmt(st$desnivel), fmt(st$n_mun)))
  yy <- 7.14
  for (i in seq_along(cifras)) {
    text(8.55, yy, names(cifras)[i], adj = c(0, 0.5), cex = 1.10, col = INK,
         family = "serif", font = 2)
    text(9.55, yy, cifras[i], adj = c(0, 0.5), cex = 0.40, col = SLATE)
    yy <- yy - 0.33
  }

  # Bloques de texto ----------------------------------------------------------
  new_panel(0, 0, 12, 16, canvas = TRUE)
  txt <- function(x, y, titulo, cuerpo) {
    text(x, y, titulo, adj = c(0, 1), cex = 0.56, col = GOLD, font = 2)
    text(x, y - 0.28, cuerpo, adj = c(0, 1), cex = 0.48, col = SLATE)
  }
  txt(0.55, 5.20, "LA CIUDAD",
      sprintf("La zona metropolitana de %s suma %s municipios y\n%s km². Su mancha urbana ocupa el punto más bajo\ndel valle: aquí se convierte en la cumbre del mapa.",
              cfg$nombre, st$n_mun, fmt(st$area_km2)))
  txt(4.30, 5.20, "LA INVERSIÓN",
      "Cada celda del modelo digital de elevación se\nrefleja respecto al plano medio de la cuenca.\nEl fondo urbano asciende a la cima; las sierras\nque rodean la ciudad descienden a abismos.")
  txt(8.05, 5.20, "EL RELIEVE",
      sprintf("Del fondo del valle (%s m) a la cumbre más alta\nde la ventana (%s m) hay %s m de desnivel: la\nciudad ocupa la parte más plana y baja de su\npropia cuenca, y por eso es la cumbre del mapa.",
              fmt(zmin), fmt(zmax), fmt(st$desnivel)))

  # Cifra destacada -----------------------------------------------------------
  segments(0.55, 4.02, 11.45, 4.02, col = alpha(BORDER, 0.7), lwd = 1)
  text(0.55, 3.22, sprintf("%.1f", st$pob / 1e6), adj = c(0, 0.5), cex = 4.4,
       col = GOLD, family = "serif", font = 2)
  text(2.15, 3.44, "millones de personas", adj = c(0, 0.5), cex = 0.95,
       col = INK, family = "serif", font = 2)
  text(2.15, 3.02, sprintf("viven en la zona metropolitana de %s: la ciudad que\nocupa el fondo de su propio valle.", cfg$nombre),
       adj = c(0, 0.5), cex = 0.52, col = SLATE)
  segments(0.55, 2.42, 11.45, 2.42, col = alpha(BORDER, 0.7), lwd = 1)

  # Pie -----------------------------------------------------------------------
  segments(0.55, 1.62, 11.45, 1.62, col = alpha(BORDER, 0.7), lwd = 1)
  text(0.55, 1.28,
       "#30DayMapChallenge 2026  |  Día 15: Inside out  |  Fuente: Copernicus DEM GLO-30/90 (© ESA / Airbus) · INEGI, Marco Geoestadístico y Censo 2020 · Agua: OpenStreetMap",
       adj = c(0, 0.5), cex = 0.38, col = MUTED)
  text(0.55, 1.02,
       "Proyección Cónica Conforme de Lambert (EPSG:6372)  ·  Sombreado con azimut 315° y elevación solar 40°  ·  Procesado en R (terra, sf) y dibujado con R gráficos base.",
       adj = c(0, 0.5), cex = 0.38, col = MUTED)
  text(0.55, 0.68, "Fernando Dorantes Nieto  ·  @FerDoranNie",
       adj = c(0, 0.5), cex = 0.44, col = INK, font = 2)
  text(11.45, 0.68, "Noviembre de 2026", adj = c(1, 0.5), cex = 0.44, col = MUTED)

  dev.off()
  msg("  -> ", fout)
}

dir.create("outputs/high_res", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/gallery", showWarnings = FALSE, recursive = TRUE)

for (id in c("cdmx", "mty", "gdl", "pue")) {
  msg("Renderizando ", id, "...")
  render_ciudad(id, 300)
}
for (id in c("cdmx", "mty", "gdl", "pue")) {
  render_ciudad(id, 150)
}
msg("Serie renderizada.")
