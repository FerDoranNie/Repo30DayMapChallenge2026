# ============================================================================
# Día 08 — Utopia | Versión alterna: México
# Pipeline de datos: recorte de ecorregiones al territorio mexicano
#
# Requiere: data/processed/day08_dataset.rds y
#           data/raw/day04/ne_50m_admin_0_countries.geojson
# Autor:    Fernando Dorantes Nieto (@FerDoranNie)
# ============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(tidyr)
})

sf_use_s2(FALSE)

d <- readRDS("data/processed/day08_dataset.rds")
eco <- d$eco  # ya está en EPSG:8857 y con nivel/bioma_es

paises <- st_read("data/raw/day04/ne_50m_admin_0_countries.geojson", quiet = TRUE)
mex <- paises[paises$ADMIN == "Mexico", ]
mex <- st_make_valid(mex)
mex <- st_transform(mex, 6372)  # México ITRF2008 / LCC (áreas equivalentes locales)

eco_mx_proj <- st_transform(eco, 6372)

# Recorte espacial: solo ecorregiones que tocan México
idx <- st_intersects(mex, eco_mx_proj)[[1]]
eco_sub <- eco_mx_proj[idx, ]

message("Ecorregiones candidatas: ", nrow(eco_sub))
eco_mx <- st_intersection(eco_sub, mex)
eco_mx <- eco_mx[!st_is_empty(eco_mx), ]
eco_mx$area_km2 <- as.numeric(st_area(eco_mx)) / 1e6

message("Fragmentos tras el recorte: ", nrow(eco_mx))
message("Superficie de México (polígono): ", round(as.numeric(st_area(mex)) / 1e6), " km2")
message("Superficie de ecorregiones recortadas: ", round(sum(eco_mx$area_km2)), " km2")

# Resúmenes
total_mx <- sum(eco_mx$area_km2)
resumen_mx <- eco_mx %>%
  st_drop_geometry() %>%
  group_by(nivel) %>%
  summarise(n = n(), area_km2 = sum(area_km2), .groups = "drop") %>%
  mutate(pct = 100 * area_km2 / total_mx)

barras_mx <- eco_mx %>%
  st_drop_geometry() %>%
  group_by(bioma_es, nivel) %>%
  summarise(area_km2 = sum(area_km2), .groups = "drop")

totales_mx <- barras_mx %>%
  group_by(bioma_es) %>%
  summarise(total_km2 = sum(area_km2), .groups = "drop")

# Solo biomas realmente presentes en México
presentes <- totales_mx$bioma_es[totales_mx$total_km2 > 0]
barras_mx <- barras_mx %>%
  filter(bioma_es %in% presentes) %>%
  mutate(bioma_es = droplevels(bioma_es))
totales_mx <- totales_mx %>% filter(total_km2 > 0)

# Orden ascendente por superficie (el mayor queda arriba en el gráfico)
orden <- totales_mx %>% arrange(total_km2) %>% pull(bioma_es)
barras_mx$bioma_es <- factor(as.character(barras_mx$bioma_es),
                             levels = as.character(orden))

kpi_mx <- list(
  total_km2 = total_mx,
  area_santuario = resumen_mx$area_km2[resumen_mx$nivel == "Ya alcanzó la mitad protegida"],
  area_alcanzar  = resumen_mx$area_km2[resumen_mx$nivel == "Aún puede alcanzar la mitad"],
  area_recuperar = resumen_mx$area_km2[resumen_mx$nivel == "Restauración posible"],
  area_peligro   = resumen_mx$area_km2[resumen_mx$nivel == "En peligro"],
  pct_santuario  = 100 * resumen_mx$area_km2[resumen_mx$nivel == "Ya alcanzó la mitad protegida"] / total_mx,
  pct_alcanzar   = 100 * resumen_mx$area_km2[resumen_mx$nivel == "Aún puede alcanzar la mitad"] / total_mx,
  pct_peligro    = 100 * resumen_mx$area_km2[resumen_mx$nivel == "En peligro"] / total_mx,
  n_eco = nrow(eco_mx),
  n_biomas = length(presentes)
)

print(resumen_mx)
print(totales_mx)
print(kpi_mx)

saveRDS(
  list(
    mex = mex, eco_mx = eco_mx, resumen = resumen_mx,
    barras = barras_mx, totales = totales_mx, kpi = kpi_mx
  ),
  "data/processed/day08_mexico.rds"
)
