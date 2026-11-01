# ==============================================================================
# Día 04 — Clusters
# "La zona más biodiversa de los países más biodiversos"
#
# Pipeline de datos:
#   1. Geometrías: 36 hotspots (Conservation International / CEPF 2016) x 17 países
#      megadiversos (Mittermeier et al. 1997) + límites Natural Earth 1:50m.
#   2. Riqueza de aves por fragmento hotspot-país vía API de GBIF (faceta speciesKey).
#   3. Clústeres biogeográficos por composición de especies (Jaccard + Ward).
#
# Salida: data/processed/day04_dataset.rds
# Autor: Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================
.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
suppressPackageStartupMessages({
  library(sf); library(dplyr); library(tidyr); library(httr); library(jsonlite)
  library(units)
})

dir.create("data/raw/day04", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

MEGADIVERSE <- c(
  "AUS" = "Australia", "BRA" = "Brasil", "CHN" = "China", "COL" = "Colombia",
  "COD" = "Rep. Dem. del Congo", "ECU" = "Ecuador", "IND" = "India",
  "IDN" = "Indonesia", "MDG" = "Madagascar", "MYS" = "Malasia", "MEX" = "México",
  "PNG" = "Papúa Nueva Guinea", "PER" = "Perú", "PHL" = "Filipinas",
  "ZAF" = "Sudáfrica", "USA" = "Estados Unidos", "VEN" = "Venezuela"
)

## ---------------------------------------------------------------- 1. geometrías
geo_file <- "data/processed/day04_geometrias.rds"
if (file.exists(geo_file)) {
  geo <- readRDS(geo_file)
  paises <- geo$paises; hs <- geo$hotspots; frag <- geo$frag; cob <- geo$cobertura
  cat("Geometrías cargadas desde caché\n")
} else {
  ne_file <- "data/raw/day04/ne_50m_admin_0_countries.geojson"
  if (!file.exists(ne_file)) {
    download.file(
      "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson",
      ne_file, mode = "wb", quiet = TRUE
    )
  }
  paises <- st_read(ne_file, quiet = TRUE) |>
    filter(ISO_A3 %in% names(MEGADIVERSE)) |>
    select(iso3 = ISO_A3, pais = ADMIN) |>
    st_make_valid() |> st_cast("MULTIPOLYGON")
  paises$pais_es <- unname(MEGADIVERSE[paises$iso3])

  hotspots <- st_read("data/raw/day04/hotspots_ci2016.geojson", quiet = TRUE) |>
    st_make_valid() |> st_cast("MULTIPOLYGON")
  hs <- hotspots |>
    group_by(nombre = NAME) |>
    summarise(area_attr_km2 = sum(as.numeric(Area_km2), na.rm = TRUE), do_union = TRUE) |>
    ungroup() |> st_make_valid()
  hs$area_km2 <- as.numeric(set_units(st_area(hs), "km^2"))

  hs_s <- suppressWarnings(st_simplify(hs, dTolerance = 0.02, preserveTopology = TRUE))
  frag <- st_intersection(hs_s, paises)
  frag$area_km2 <- as.numeric(set_units(st_area(frag), "km^2"))
  frag <- frag |> filter(area_km2 > 1)

  cob <- frag |> st_drop_geometry() |> group_by(iso3, pais_es) |>
    summarise(area_hs_km2 = sum(area_km2), .groups = "drop")
  paises$area_km2 <- as.numeric(set_units(st_area(paises), "km^2"))
  cob <- left_join(paises |> st_drop_geometry() |> select(iso3, pais_es, area_pais = area_km2),
                   cob, by = c("iso3", "pais_es"))
  cob$pct_hotspot <- 100 * cob$area_hs_km2 / cob$area_pais
  saveRDS(list(paises = paises, hotspots = hs, frag = frag, cobertura = cob), geo_file)
  cat("Geometrías calculadas y guardadas\n")
}
frag$fid <- sprintf("%s|%s", frag$nombre, frag$iso3)

## ------------------------------------------------------- 2. riqueza vía GBIF ----
# Dos límites de la API condicionan el diseño:
#   (1) la URL no puede pasar de ~4 KB (por encima devuelve 400 sin mensaje), y
#   (2) los multipolígonos grandes fallan en el parser espacial (spatial4j).
# Solución: simplificar con s2 (tolerancia en metros), partir cada fragmento en
# polígonos simples, consultarlos por separado y unir las especies halladas.
GBIF_URL <- "https://api.gbif.org/v1/occurrence/search"
MAX_URL  <- 3900

mk_query <- function(wkt, basis = NULL) {
  q <- list(geometry = wkt, taxonKey = 212L, hasCoordinate = "true",
            hasGeospatialIssue = "false", occurrenceStatus = "PRESENT",
            facet = "speciesKey", facetLimit = 20000, limit = 0)
  if (!is.null(basis)) q$basisOfRecord <- basis
  q
}

decompose <- function(gi, tol_m = 5000, min_area_deg2 = 5e-4, cover = 0.995) {
  gs <- suppressWarnings(st_make_valid(
    st_simplify(st_sfc(gi, crs = 4326), dTolerance = tol_m, preserveTopology = TRUE)
  ))
  parts <- suppressWarnings(st_cast(gs, "POLYGON", warn = FALSE))
  ar <- suppressWarnings(as.numeric(st_area(parts)))
  keep <- is.finite(ar) & ar > min_area_deg2
  parts <- parts[keep]; ar <- ar[keep]
  if (!length(parts)) return(parts)
  ord <- order(ar, decreasing = TRUE)
  n_keep <- max(1L, which(cumsum(ar[ord]) / sum(ar) >= cover)[1])
  parts[ord[seq_len(n_keep)]]
}

# WKT del polígono ajustando la simplificación hasta caber en la URL permitida
wkt_scaled <- function(p, max_url = MAX_URL) {
  txt <- st_as_text(p, digits = 5)
  for (tol in c(2000, 5000, 10000, 20000, 40000)) {
    if (nchar(httr::modify_url(GBIF_URL, query = mk_query(txt))) <= max_url) return(txt)
    pp <- suppressWarnings(st_make_valid(
      st_simplify(st_sfc(p, crs = 4326), dTolerance = tol, preserveTopology = TRUE)
    ))
    pp <- suppressWarnings(st_cast(pp, "POLYGON", warn = FALSE))
    if (!length(pp)) break
    txt <- st_as_text(pp[[which.max(suppressWarnings(as.numeric(st_area(pp))))]], digits = 5)
  }
  txt
}

gbif_facet <- function(wkt, basis = NULL, intentos = 4) {
  q <- mk_query(wkt, basis)
  err <- NA_character_
  for (i in seq_len(intentos)) {
    r <- try(httr::GET(GBIF_URL, query = q, httr::timeout(300)), silent = TRUE)
    if (!inherits(r, "try-error")) {
      if (httr::status_code(r) == 200) {
        js <- jsonlite::fromJSON(httr::content(r, "text", encoding = "UTF-8"),
                                 simplifyVector = FALSE)
        fc <- js$facets[[1]]$counts
        return(list(n_registros = as.numeric(js$count),
                    n_especies = length(fc),
                    especies = vapply(fc, function(x) as.character(x$name), character(1)),
                    conteos = vapply(fc, function(x) as.numeric(x$count), numeric(1)),
                    error = NA_character_))
      }
      err <- gsub("<[^>]+>", " ", httr::content(r, "text", encoding = "UTF-8"))
      err <- substr(gsub("\\s+", " ", err), 1, 200)
      if (httr::status_code(r) == 400) break   # geometría o URL: no reintentar
    }
    Sys.sleep(2 * i)
  }
  list(n_registros = NA_real_, n_especies = NA_integer_, especies = character(0),
       conteos = numeric(0), error = err)
}

q_cache <- "data/processed/day04_gbif_facetas.rds"
facetas <- if (file.exists(q_cache)) readRDS(q_cache) else list()
pend <- setdiff(frag$fid, names(facetas))
cat("\nFragmentos a consultar en GBIF:", length(pend), "de", nrow(frag), "\n")

for (i in seq_along(pend)) {
  id <- pend[i]
  gi <- frag$geometry[[match(id, frag$fid)]]
  parts <- decompose(gi)
  esp_tot <- character(0); esp_esp <- character(0)
  reg_tot <- 0; reg_esp <- 0; errores <- character(0)
  if (!length(parts)) errores <- "sin componentes válidos"
  for (p in parts) {
    wkt <- wkt_scaled(p)
    r1 <- gbif_facet(wkt)
    r2 <- gbif_facet(wkt, basis = "PRESERVED_SPECIMEN")
    if (is.na(r1$n_especies)) errores <- c(errores, r1$error) else {
      esp_tot <- union(esp_tot, r1$especies); reg_tot <- reg_tot + r1$n_registros
    }
    if (is.na(r2$n_especies)) errores <- c(errores, r2$error) else {
      esp_esp <- union(esp_esp, r2$especies); reg_esp <- reg_esp + r2$n_registros
    }
  }
  facetas[[id]] <- list(
    n_parts = length(parts),
    n_registros = reg_tot,
    n_especies = length(esp_tot),
    especies = esp_tot,
    n_especies_esp = length(esp_esp),
    n_registros_esp = reg_esp,
    errores = unique(errores)
  )
  cat(sprintf("  [%2d/%2d] %-46s partes=%-3d esp=%-5d (museo=%-5d) reg=%.3g\n",
              i, length(pend), id, length(parts), length(esp_tot), length(esp_esp), reg_tot))
  if (length(errores)) cat("          ! ", substr(errores[1], 1, 150), "\n")
  if (i %% 3 == 0) saveRDS(facetas, q_cache)
  Sys.sleep(0.4)
}
saveRDS(facetas, q_cache)
cat("Cache GBIF:", q_cache, "\n")

## ---------------------------------------- 3. métricas, clústeres y dataset ----
esp_tbl <- tibble(
  fid = names(facetas),
  n_registros = vapply(facetas, function(x) as.numeric(x$n_registros), numeric(1)),
  n_especies = vapply(facetas, function(x) as.integer(x$n_especies), integer(1)),
  n_especies_esp = vapply(facetas, function(x) as.integer(x$n_especies_esp), integer(1)),
  n_registros_esp = vapply(facetas, function(x) as.numeric(x$n_registros_esp), numeric(1)),
  n_partes = vapply(facetas, function(x) as.integer(x$n_parts), integer(1))
)

dat <- frag |>
  st_drop_geometry() |>
  select(fid, hotspot = nombre, iso3, pais_es, area_frag_km2 = area_km2) |>
  left_join(esp_tbl, by = "fid") |>
  mutate(
    pct_hotspot_en_pais = 100 * area_frag_km2 / (
      hs$area_km2[match(hotspot, hs$nombre)]
    ),
    esp_por_mil_km2 = n_especies / (area_frag_km2 / 1000),
    sesgo_muestreo = n_registros / pmax(n_especies, 1),
    pct_esp_museo = 100 * n_especies_esp / pmax(n_especies, 1)
  ) |>
  arrange(desc(n_especies))

cat("\n=== Riqueza de aves por fragmento (top 15) ===\n")
print(as.data.frame(head(dat[, c("hotspot", "pais_es", "n_especies", "n_especies_esp",
                                 "area_frag_km2", "pct_hotspot_en_pais")], 15)), row.names = FALSE)
cat("\nFallos de consulta:", sum(is.na(dat$n_especies)), "\n")

# --- clústeres por composición de especies (Jaccard + Ward.D2) -----------------
# Se excluyen astillas sin datos suficientes: no informan sobre composición.
ok <- dat$fid[!is.na(dat$n_especies) & dat$n_especies >= 30]
excluidos <- setdiff(dat$fid, ok)
if (length(excluidos)) cat("\nExcluidos del clustering:", paste(excluidos, collapse = ", "), "\n")
sp_list <- lapply(facetas[ok], function(x) x$especies)
all_sp <- unique(unlist(sp_list))
M <- matrix(0L, nrow = length(ok), ncol = length(all_sp),
            dimnames = list(ok, all_sp))
for (i in seq_along(sp_list)) M[i, sp_list[[i]]] <- 1L
# descartar especies presentes en una sola localidad (no informan sobre similitud)
M <- M[, colSums(M) >= 2, drop = FALSE]
cat("\nMatriz de composición:", nrow(M), "fragmentos x", ncol(M), "especies (>=2 fragmentos)\n")

inter <- M %*% t(M)
a <- rowSums(M)
D <- 1 - inter / (outer(a, a, "+") - inter)   # distancia de Jaccard
hc <- hclust(as.dist(D), method = "ward.D2")

# número de clústeres por silueta media; se descartan soluciones con grupos de 1-2 miembros
suppressPackageStartupMessages(library(cluster))
sil <- sapply(2:10, function(k) {
  cl <- cutree(hc, k)
  if (min(table(cl)) < 3) return(NA_real_)
  mean(silhouette(cl, as.dist(D))[, 3])
})
names(sil) <- 2:10
k_best <- as.integer(names(which.max(sil)))
cat("Silueta media por k:", paste(sprintf("%d=%s", 2:10, ifelse(is.na(sil), "—", sprintf("%.3f", sil))), collapse = "  "), "\n")
cat("k elegido:", k_best, "\n")

dat$cluster <- NA_integer_
dat$cluster[match(ok, dat$fid)] <- cutree(hc, k_best)
dat$especies_compartidas <- NA_real_
dat$especies_compartidas[match(ok, dat$fid)] <- rowSums(M)

cat("\n=== Clústeres ===\n")
for (k in seq_len(k_best)) {
  cl <- dat |> filter(cluster == k) |> arrange(desc(n_especies))
  cat(sprintf("\nClúster %d (n=%d, riqueza mediana %d):\n", k, nrow(cl),
              as.integer(median(cl$n_especies, na.rm = TRUE))))
  print(as.data.frame(cl[, c("hotspot", "pais_es", "n_especies")]), row.names = FALSE)
}

saveRDS(list(dat = dat, hc = hc, D = D, sil = sil, k = k_best, M = M,
             paises = paises, hotspots = hs, cobertura = cob),
        "data/processed/day04_dataset.rds")
cat("\nGuardado data/processed/day04_dataset.rds\n")
