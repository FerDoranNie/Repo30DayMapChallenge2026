# ==============================================================================
# Día 19: Senses: Smell — Paisaje Olfativo Urbano de la Ciudad de México
# Script 03: Procesamiento espacial en R (sf + data.table)
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))

suppressPackageStartupMessages({
  library(sf)
  library(data.table)
  library(jsonlite)
})

sf_use_s2(FALSE)
crs_utm14 <- 32614

cat("1. Cargando polígonos oficiales de CDMX y contexto EdoMex...\n")
alc <- st_read("data/raw/day12/ent_09/conjunto_de_datos/09mun.shp", quiet = TRUE) |>
  st_transform(crs_utm14)
alc$area_km2 <- as.numeric(st_area(alc)) / 1e6
cdmx_union <- st_union(alc)
cdmx_buf <- st_buffer(cdmx_union, 1500)

edomex_path <- "data/raw/day12/ent_15/conjunto_de_datos/15mun.shp"
edomex <- NULL
if (file.exists(edomex_path)) {
  edomex <- st_read(edomex_path, quiet = TRUE) |>
    st_transform(crs_utm14) |>
    st_simplify(dTolerance = 80, preserveTopology = TRUE)
}

cat("2. Georreferenciando y validando establecimientos RETC 2024...\n")
retc_dt <- fread("data/processed/day19_retc_voc_raw.csv")
retc_dms <- st_as_sf(
  retc_dt[!is.na(lon) & !is.na(lat)],
  coords = c("lon", "lat"), crs = 4326, remove = FALSE
) |> st_transform(crs_utm14)

in_dms <- lengths(st_intersects(retc_dms, cdmx_buf)) > 0
retc_valid_dms <- retc_dms[in_dms, ]

# Intentar UTM para los que no cayeron en CDMX por DMS
nra_ok <- retc_valid_dms$NRA
retc_rem <- retc_dt[!(NRA %in% nra_ok) & !is.na(utm_x) & !is.na(utm_y)]
if (nrow(retc_rem) > 0) {
  retc_utm <- st_as_sf(retc_rem, coords = c("utm_x", "utm_y"), crs = crs_utm14, remove = FALSE)
  in_utm <- lengths(st_intersects(retc_utm, cdmx_buf)) > 0
  retc_pts <- rbind(retc_valid_dms, retc_utm[in_utm, ])
} else {
  retc_pts <- retc_valid_dms
}
cat(sprintf("   RETC VOC válidos dentro de CDMX: %d (%.1f ton/año)\n", nrow(retc_pts), sum(retc_pts$ton_voc)))

cat("3. Georreferenciando DENUE CDMX...\n")
denue_dt <- fread("data/processed/day19_denue_smell.csv", encoding = "UTF-8")
denue_pts <- st_as_sf(
  denue_dt[!is.na(longitud) & !is.na(latitud)],
  coords = c("longitud", "latitud"), crs = 4326, remove = FALSE
) |> st_transform(crs_utm14)
denue_pts <- denue_pts[lengths(st_intersects(denue_pts, st_buffer(cdmx_union, 250))) > 0, ]
cat(sprintf("   DENUE olfativo válido en CDMX: %d establecimientos\n", nrow(denue_pts)))

cat("4. Construyendo grilla hexagonal (750 m) y calculando Índice de Contraste Olfativo...\n")
hex_raw <- st_make_grid(alc, cellsize = 750, square = FALSE)
hex_sf <- st_sf(hex_id = seq_along(hex_raw), geometry = hex_raw)
hex_cdmx <- hex_sf[lengths(st_intersects(hex_sf, cdmx_union)) > 0, ]
hex_cdmx$hex_id <- seq_len(nrow(hex_cdmx))

# Spatial join DENUE -> hex
j_denue <- st_join(denue_pts[, c("polo", "subcat")], hex_cdmx[, "hex_id"], join = st_within, left = FALSE)
j_dt <- as.data.table(st_drop_geometry(j_denue))
hex_polo <- dcast(j_dt, hex_id ~ polo, fun.aggregate = length, value.var = "polo")

# Spatial join RETC -> hex
j_retc <- st_join(retc_pts[, c("ton_voc")], hex_cdmx[, "hex_id"], join = st_within, left = FALSE)
r_dt <- as.data.table(st_drop_geometry(j_retc))
if (nrow(r_dt) > 0) {
  hex_retc <- r_dt[, .(n_retc = .N, ton_voc = sum(ton_voc, na.rm = TRUE)), by = hex_id]
} else {
  hex_retc <- data.table(hex_id = integer(0), n_retc = integer(0), ton_voc = numeric(0))
}

hex_dt <- as.data.table(st_drop_geometry(hex_cdmx))
hex_dt <- merge(hex_dt, hex_polo, by = "hex_id", all.x = TRUE)
hex_dt <- merge(hex_dt, hex_retc, by = "hex_id", all.x = TRUE)

setnames(hex_dt,
         old = c("Aroma Cotidiano", "Aroma Floral", "Solventes y Combustibles"),
         new = c("n_gastro", "n_floral", "n_solv_denue"),
         skip_absent = TRUE)

for (col in c("n_gastro", "n_floral", "n_solv_denue", "n_retc", "ton_voc")) {
  if (!col %in% names(hex_dt)) hex_dt[, (col) := 0]
  hex_dt[is.na(get(col)), (col) := 0]
}

hex_dt[, n_arom_tot := n_gastro + n_floral]
hex_dt[, carga_solv := n_solv_denue + n_retc * 8.0]
hex_dt[, total_olfativo := n_arom_tot + carga_solv]
hex_dt[, ico := log1p(n_arom_tot) - log1p(carga_solv * 2.5)]

hex_dt[, olfato_cat := fcase(
  total_olfativo < 2,                                "Suelo de conservación / baja densidad",
  n_floral >= 8 & n_floral >= 0.28 * n_arom_tot,     "Oasis floral (viveros y mercados)",
  carga_solv >= 4 & ico <= 0.25,                     "Dominio de solventes, combustibles e industria",
  n_retc >= 1 & ico < 1.2,                           "Dominio de solventes, combustibles e industria",
  n_gastro >= 25 & ico >= 1.4,                       "Aroma gastronómico intenso (pan, café, tacos)",
  n_arom_tot >= 5 & ico > 0.4,                       "Aroma cotidiano moderado",
  default =                                          "Paisaje mixto (transición)"
)]

hex_final <- merge(hex_cdmx, hex_dt, by = "hex_id")
hex_final <- st_intersection(hex_final, cdmx_union)

cat("Distribución de hexágonos por categoría olfativa:\n")
print(table(hex_final$olfato_cat))

cat("5. Calculando métricas por Alcaldía...\n")
ja_d <- st_join(denue_pts[, c("polo")], alc[, c("CVE_MUN", "NOMGEO")], join = st_within, left = FALSE)
ja_dt <- as.data.table(st_drop_geometry(ja_d))
alc_polo <- dcast(ja_dt, CVE_MUN ~ polo, fun.aggregate = length, value.var = "polo")

ja_r <- st_join(retc_pts[, c("ton_voc")], alc[, c("CVE_MUN")], join = st_within, left = FALSE)
jr_dt <- as.data.table(st_drop_geometry(ja_r))
alc_retc <- jr_dt[, .(n_retc = .N, ton_voc = sum(ton_voc, na.rm = TRUE)), by = CVE_MUN]

alc_dt <- as.data.table(st_drop_geometry(alc))[, .(CVE_MUN, NOMGEO, area_km2)]
alc_dt <- merge(alc_dt, alc_polo, by = "CVE_MUN", all.x = TRUE)
alc_dt <- merge(alc_dt, alc_retc, by = "CVE_MUN", all.x = TRUE)
setnames(alc_dt,
         old = c("Aroma Cotidiano", "Aroma Floral", "Solventes y Combustibles"),
         new = c("n_gastro", "n_floral", "n_solv_denue"),
         skip_absent = TRUE)
for (col in c("n_gastro", "n_floral", "n_solv_denue", "n_retc", "ton_voc")) {
  if (!col %in% names(alc_dt)) alc_dt[, (col) := 0]
  alc_dt[is.na(get(col)), (col) := 0]
}
alc_dt[, n_arom_tot := n_gastro + n_floral]
alc_dt[, dens_arom_km2 := n_arom_tot / area_km2]
alc_dt[, dens_solv_km2 := n_solv_denue / area_km2]
alc_dt[, ratio_arom_solv := n_arom_tot / pmax(n_solv_denue, 1)]

print(alc_dt[order(-dens_arom_km2), .(NOMGEO, n_arom_tot, n_solv_denue, n_retc, round(ton_voc, 1), round(dens_arom_km2, 1))])

saveRDS(
  list(
    alc = alc,
    alc_dt = alc_dt,
    edomex = edomex,
    cdmx_union = cdmx_union,
    hex_final = hex_final,
    retc_pts = retc_pts
  ),
  "data/processed/day19_spatial.rds"
)

cat("Listo: data/processed/day19_spatial.rds guardado.\n")
