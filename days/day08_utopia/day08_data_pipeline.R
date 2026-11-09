# ============================================================================
# Día 08 — Utopia | Pipeline de datos
# Planeta 30x30: estado de conservación de las ecorregiones terrestres
# y red esquemática de megacorredores biológicos
#
# Fuente: RESOLVE Ecoregions 2017 (Dinerstein et al. 2017, BioScience)
#         https://storage.googleapis.com/teow2016/Ecoregions2017.zip
# Autor:  Fernando Dorantes Nieto (@FerDoranNie)
# ============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(tidyr)
  library(tibble)
})

sf_use_s2(FALSE)  # geometrías globales complejas: mejor GEOS plano
dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)

t0 <- Sys.time()
msg <- function(...) cat(format(Sys.time() - t0), "-", ..., "\n")

# ---------------------------------------------------------------------------
# 1. Lectura y limpieza
# ---------------------------------------------------------------------------
msg("Leyendo ecorregiones...")
eco <- st_read("data/raw/day08/Ecoregions2017.shp", quiet = TRUE)

# La fila NNH = 0 es "Rock and Ice" (sin bioma ni reino): se excluye.
# Se excluye también la Antártida para ceñir el mapa a las tierras habitadas.
eco <- eco[eco$NNH != 0, ]
eco <- eco[eco$REALM != "Antarctica", ]
msg("Ecorregiones retenidas:", nrow(eco))

msg("Reparando geometrías inválidas...")
eco <- st_make_valid(eco)

msg("Proyectando a Equal Earth (EPSG:8857)...")
eco <- st_transform(eco, 8857)

msg("Calculando superficies...")
eco$area_km2 <- as.numeric(st_area(eco)) / 1e6

# ---------------------------------------------------------------------------
# 2. Clasificación del estado de conservación (NNH de Dinerstein et al.)
# ---------------------------------------------------------------------------
niveles <- c(
  "Half Protected"                     = "santuario",
  "Nature Could Reach Half Protected"  = "alcanzar",
  "Nature Could Recover"               = "recuperar",
  "Nature Imperiled"                   = "peligro"
)
eco$nivel <- factor(
  unname(niveles[eco$NNH_NAME]),
  levels = c("santuario", "alcanzar", "recuperar", "peligro"),
  labels = c(
    "Ya alcanzó la mitad protegida",
    "Aún puede alcanzar la mitad",
    "Restauración posible",
    "En peligro"
  )
)
stopifnot(!anyNA(eco$nivel))

# Nombres cortos en español para las etiquetas del póster
biomas_es <- c(
  "Boreal Forests/Taiga"                                        = "Bosques boreales y taiga",
  "Deserts & Xeric Shrublands"                                  = "Desiertos y matorrales xéricos",
  "Flooded Grasslands & Savannas"                               = "Praderas y sabanas inundables",
  "Mangroves"                                                   = "Manglares",
  "Mediterranean Forests, Woodlands & Scrub"                    = "Bosque y matorral mediterráneo",
  "Montane Grasslands & Shrublands"                             = "Praderas y matorrales de montaña",
  "Temperate Broadleaf & Mixed Forests"                         = "Bosques templados de hoja ancha",
  "Temperate Conifer Forests"                                   = "Bosques templados de coníferas",
  "Temperate Grasslands, Savannas & Shrublands"                 = "Praderas y sabanas templadas",
  "Tropical & Subtropical Coniferous Forests"                   = "Bosques tropicales de coníferas",
  "Tropical & Subtropical Dry Broadleaf Forests"                = "Selvas secas tropicales",
  "Tropical & Subtropical Grasslands, Savannas & Shrublands"    = "Sabanas tropicales",
  "Tropical & Subtropical Moist Broadleaf Forests"              = "Selvas húmedas tropicales",
  "Tundra"                                                      = "Tundra"
)
stopifnot(all(eco$BIOME_NAME %in% names(biomas_es)))
eco$bioma_es <- factor(biomas_es[eco$BIOME_NAME], levels = unname(biomas_es))

# ---------------------------------------------------------------------------
# 3. Resúmenes cuantitativos
# ---------------------------------------------------------------------------
total_km2 <- sum(eco$area_km2)

resumen <- eco %>%
  st_drop_geometry() %>%
  group_by(nivel) %>%
  summarise(n_eco = n(), area_km2 = sum(area_km2), .groups = "drop") %>%
  mutate(pct = 100 * area_km2 / total_km2)

barras <- eco %>%
  st_drop_geometry() %>%
  group_by(bioma_es, nivel) %>%
  summarise(area_km2 = sum(area_km2), .groups = "drop") %>%
  complete(bioma_es, nivel, fill = list(area_km2 = 0))

# Orden de biomas: por superficie total (mayor arriba en el gráfico)
orden_biomas <- barras %>%
  group_by(bioma_es) %>%
  summarise(total = sum(area_km2), .groups = "drop") %>%
  arrange(total) %>%
  pull(bioma_es)
barras$bioma_es <- factor(barras$bioma_es, levels = as.character(orden_biomas))

totales_bioma <- barras %>%
  group_by(bioma_es) %>%
  summarise(total_km2 = sum(area_km2), .groups = "drop")

# ---------------------------------------------------------------------------
# 4. Nodos núcleo y megacorredores esquemáticos
# ---------------------------------------------------------------------------
nodos <- tribble(
  ~id,           ~nombre,                   ~lon,    ~lat,  ~continente,
  "brooks",      "Brooks Range",            -150.0,   68.0,  "América",
  "yukon",       "Yukón",                   -139.0,   61.0,  "América",
  "yellowstone", "Yellowstone",             -110.5,   44.5,  "América",
  "sierra",      "Sierra Madre Occidental", -107.5,   27.5,  "América",
  "maya",        "Selva Maya",               -89.5,   17.8,  "América",
  "choco",       "Chocó-Darién",             -77.0,    7.0,  "América",
  "andes",       "Andes tropicales",         -68.5,  -16.5,  "América",
  "amazonas",    "Amazonía central",         -62.0,   -4.0,  "América",
  "pantanal",    "Pantanal",                 -56.5,  -17.5,  "América",
  "patagonia",   "Patagonia",                -71.5,  -49.0,  "América",
  "sahel",       "Sahel",                     -3.0,   15.0,  "África",
  "guineano",    "Bosques guineanos",         -8.0,    6.5,  "África",
  "congo",       "Cuenca del Congo",          20.0,    0.0,  "África",
  "miombo",      "Miombo",                    30.0,  -12.0,  "África",
  "rift",        "Rift oriental",             35.0,   -3.0,  "África",
  "etiopia",     "Tierras altas de Etiopía",  39.5,    9.0,  "África",
  "pirineos",    "Pirineos",                   0.5,   42.7,  "Eurasia",
  "alpes",       "Alpes",                     10.0,   46.5,  "Eurasia",
  "carpatos",    "Cárpatos",                  24.5,   47.5,  "Eurasia",
  "pontico",     "Estepa póntica",            39.8,   47.2,  "Eurasia",
  "caucaso",     "Cáucaso",                   41.5,   43.5,  "Eurasia",
  "astracan",    "Estepa del Volga",          48.5,   46.8,  "Eurasia",
  "caspia",      "Estepa caspia",             53.0,   48.5,  "Eurasia",
  "altai",       "Altái",                     88.0,   49.0,  "Eurasia",
  "amur",        "Amur",                     135.0,   50.0,  "Eurasia",
  "ghats",       "Ghats occidentales",        75.0,   13.0,  "Asia",
  "himalaya",    "Himalaya",                  85.0,   28.0,  "Asia",
  "swchina",     "Suroeste de China",        100.0,   28.0,  "Asia",
  "sundaland",   "Sundaland",                102.0,   -2.0,  "Asia",
  "capeyork",    "Cabo York",                142.5,  -12.0,  "Oceanía",
  "gdr",         "Gran Cordillera Divisoria",147.0,  -25.0,  "Oceanía",
  "alpesaus",    "Alpes australianos",       148.0,  -36.5,  "Oceanía"
)

corredores_def <- list(
  list(n = 1,  nombre = "Yellowstone–Yukón",                    ids = c("brooks", "yukon", "yellowstone")),
  list(n = 2,  nombre = "Puente Biológico Mesoamericano",       ids = c("yellowstone", "sierra", "maya", "choco")),
  list(n = 3,  nombre = "Andes–Amazonas–Atlántico (AAA)",       ids = c("choco", "andes", "amazonas", "pantanal", "patagonia")),
  list(n = 4,  nombre = "Eje Trans-Congoleño",                  ids = c("guineano", "congo", "miombo")),
  list(n = 5,  nombre = "Sahel–Rift–Etiopía",                   ids = c("sahel", "rift", "etiopia")),
  list(n = 6,  nombre = "Cinturón Verde Europeo",               ids = c("pirineos", "alpes", "carpatos", "pontico", "caucaso")),
  list(n = 7,  nombre = "Estepa–Taiga Siberiana",               ids = c("caucaso", "astracan", "caspia", "altai", "amur")),
  list(n = 8,  nombre = "Ghats–Himalaya",                       ids = c("ghats", "himalaya", "swchina")),
  list(n = 9,  nombre = "Sundaland",                            ids = c("swchina", "sundaland")),
  list(n = 10, nombre = "Great Eastern Ranges",                 ids = c("capeyork", "gdr", "alpesaus"))
)

# --- Interpolación sobre círculo máximo + suavizado Chaikin -----------------
slerp <- function(p1, p2, t) {
  d <- acos(max(-1, min(1, sum(p1 * p2))))
  if (d < 1e-9) return(p1)
  (sin((1 - t) * d) * p1 + sin(t * d) * p2) / sin(d)
}

arco_gc <- function(lon1, lat1, lon2, lat2, n = 40) {
  to_xyz <- function(lon, lat) {
    lo <- lon * pi / 180; la <- lat * pi / 180
    c(cos(la) * cos(lo), cos(la) * sin(lo), sin(la))
  }
  p1 <- to_xyz(lon1, lat1); p2 <- to_xyz(lon2, lat2)
  t <- seq(0, 1, length.out = n)
  m <- t(vapply(t, function(tt) slerp(p1, p2, tt), numeric(3)))
  cbind(
    lon = atan2(m[, 2], m[, 1]) * 180 / pi,
    lat = asin(pmax(-1, pmin(1, m[, 3]))) * 180 / pi
  )
}

chaikin <- function(m, iter = 3) {
  for (i in seq_len(iter)) {
    a <- m[-nrow(m), , drop = FALSE]
    b <- m[-1, , drop = FALSE]
    q1 <- 0.75 * a + 0.25 * b
    q2 <- 0.25 * a + 0.75 * b
    inter <- matrix(NA_real_, nrow = 2 * nrow(q1), ncol = 2)
    inter[seq(1, nrow(inter), by = 2), ] <- q1
    inter[seq(2, nrow(inter), by = 2), ] <- q2
    m <- rbind(m[1, , drop = FALSE], inter, m[nrow(m), , drop = FALSE])
  }
  m
}

construir_corredor <- function(ids) {
  pts <- nodos[match(ids, nodos$id), ]
  tramos <- lapply(seq_len(nrow(pts) - 1), function(i) {
    arco_gc(pts$lon[i], pts$lat[i], pts$lon[i + 1], pts$lat[i + 1], n = 30)
  })
  m <- do.call(rbind, tramos)
  # quitar duplicados en las uniones
  keep <- c(TRUE, rowSums(abs(diff(m))) > 1e-9)
  m <- m[keep, , drop = FALSE]
  chaikin(m, iter = 3)
}

lineas <- list(); etiquetas <- list()
for (cd in corredores_def) {
  m <- construir_corredor(cd$ids)
  ln <- st_sfc(st_linestring(m), crs = 4326)
  ln <- st_transform(ln, 8857)
  lineas[[as.character(cd$n)]] <- st_sf(
    corredor = cd$n, nombre = cd$nombre, geometry = ln
  )
  # punto medio sobre la longitud acumulada (para el número)
  xy <- st_coordinates(ln)[, 1:2, drop = FALSE]
  d <- sqrt(rowSums(diff(xy)^2))
  s <- c(0, cumsum(d))
  mid <- which.min(abs(s - s[length(s)] / 2))
  etiquetas[[as.character(cd$n)]] <- data.frame(
    corredor = cd$n, nombre = cd$nombre,
    x = xy[mid, 1], y = xy[mid, 2]
  )
}
corredores_sf <- do.call(rbind, lineas)
etiquetas <- do.call(rbind, etiquetas)
corredores_sf$largo_km <- as.numeric(st_length(corredores_sf)) / 1000

nodos_sf <- st_as_sf(nodos, coords = c("lon", "lat"), crs = 4326) %>%
  st_transform(8857)

# ---------------------------------------------------------------------------
# 5. Indicadores
# ---------------------------------------------------------------------------
get_area <- function(niv) resumen$area_km2[resumen$nivel == niv]
kpi <- list(
  total_km2    = total_km2,
  area_santuario = get_area("Ya alcanzó la mitad protegida"),
  area_alcanzar  = get_area("Aún puede alcanzar la mitad"),
  area_recuperar = get_area("Restauración posible"),
  area_peligro   = get_area("En peligro"),
  pct_santuario  = 100 * get_area("Ya alcanzó la mitad protegida") / total_km2,
  pct_alcanzar   = 100 * get_area("Aún puede alcanzar la mitad") / total_km2,
  pct_peligro    = 100 * get_area("En peligro") / total_km2,
  meta30_km2     = 0.30 * total_km2,
  meta50_km2     = 0.50 * total_km2,
  red_km         = sum(corredores_sf$largo_km),
  n_corredores   = nrow(corredores_sf),
  n_eco          = nrow(eco),
  n_biomas       = nlevels(eco$bioma_es)
)

msg("Superficie total analizada:", round(total_km2 / 1e6, 1), "Mkm2")
msg("Red de corredores:", round(kpi$red_km), "km")
print(resumen)
print(corredores_sf[, c("corredor", "nombre", "largo_km")] %>% st_drop_geometry())

saveRDS(
  list(
    eco = eco, biomas = barras, totales_bioma = totales_bioma,
    resumen = resumen, corredores = corredores_sf, nodos = nodos_sf,
    etiquetas = etiquetas, kpi = kpi, biomas_es = biomas_es
  ),
  "data/processed/day08_dataset.rds"
)

write.csv(
  resumen %>% mutate(area_km2 = round(area_km2), pct = round(pct, 2)),
  "data/processed/day08_resumen_nnh.csv", row.names = FALSE
)
write.csv(
  corredores_sf %>% st_drop_geometry() %>% mutate(largo_km = round(largo_km)),
  "data/processed/day08_corredores.csv", row.names = FALSE
)

msg("Listo. Dataset guardado en data/processed/day08_dataset.rds")
