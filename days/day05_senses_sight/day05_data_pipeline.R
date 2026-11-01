# ==============================================================================
# Día 05 — Senses: Sight
# "Ecología del plumaje: Riqueza cromática e iridiscencia aviar en México"
#
# Pipeline de datos:
#   1. Procesamiento de 31,650 curvas de reflectancia espectrofotométrica
#      (300–700 nm, resolución de 2 nm, incluyendo el canal UV 300–400 nm)
#      provenientes de BirdColorBase (Dale, Stoddard & Prum, Maia, Eaton,
#      Dunning & Endler).
#   2. Catálogo taxonómico completo de las aves terrestres registradas en México
#      vía GBIF Occurrence API (19+ millones de registros), clasificadas en los
#      4 gremios biofísicos de coloración del plumaje (Prum 2006; Stoddard &
#      Prum 2011; Cooney et al. 2022; Delhey et al. 2023):
#        (I)   Iridiscencia estructural y UV (nanocristales de melanina / multicapas)
#        (II)  Azul estructural no iridiscente y psitacofulvinas (matriz esponjosa)
#        (III) Pigmentación por carotenoides (cetocarotenoides y xantofilas, 550-700 nm)
#        (IV)  Pigmentación por melaninas (eumelanina y feomelanina: cripticismo/Gloger)
#   3. Muestreo espacial en malla de 0.6° x 0.6° sobre el territorio continental
#      e insular de México consultando la faceta speciesKey de GBIF por celda.
#   4. Construcción de rásters continuos en alta resolución (0.08°) con `terra`
#      mediante suavizado espacial focal gaussiano enmascarado al contorno de México.
#
# Salidas:
#   - data/processed/day05_dataset.rds
#   - data/processed/day05_rasters.tif
# Autor: Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readxl)
  library(httr)
  library(curl)
  library(jsonlite)
})

sf_use_s2(FALSE)

dir.create("data/raw/day05", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------------------------
# 1. Procesamiento de Espectrofotometría (300–700 nm) desde BirdColorBase
# ------------------------------------------------------------------------------
bcb_cache <- "data/processed/day05_birdcolorbase_spectra.rds"

if (file.exists(bcb_cache)) {
  cat("Cargando datos espectrofotométricos desde caché:", bcb_cache, "\n")
  bcb_data <- readRDS(bcb_cache)
} else {
  bcb_files <- c(
    "Dale_27Dec24.xlsx",
    "StoddardPrum_31Dec24.xlsx",
    "Dunning.Endler_27Dec24.xlsx",
    "Maia_27Dec24.xlsx",
    "Eaton_27Dec24.xlsx"
  )
  
  for (fn in bcb_files) {
    dest <- file.path("data/raw/day05", fn)
    if (!file.exists(dest) || file.info(dest)$size < 10000) {
      u <- paste0("https://raw.githubusercontent.com/BirdColorBase/home/main/Data_from_each_Research_Group/", fn)
      cat("Descargando", fn, "...\n")
      GET(u, write_disk(dest, overwrite = TRUE), timeout(180))
    }
  }
  
  wl_cols <- as.character(seq(300, 700, by = 2))
  wl_num  <- seq(300, 700, by = 2)
  
  read_one_bcb <- function(fn) {
    path <- file.path("data/raw/day05", fn)
    sh <- excel_sheets(path)[1]
    df <- read_excel(path, sheet = sh)
    wl_present <- intersect(wl_cols, names(df))
    mat <- as.matrix(sapply(df[, wl_present], function(x) suppressWarnings(as.numeric(x))))
    mat[mat < 0] <- 0
    
    w_num <- as.numeric(wl_present)
    b_uv <- rowMeans(mat[, w_num >= 300 & w_num <= 400, drop = FALSE], na.rm = TRUE)
    b_bl <- rowMeans(mat[, w_num > 400  & w_num <= 500, drop = FALSE], na.rm = TRUE)
    b_gr <- rowMeans(mat[, w_num > 500  & w_num <= 600, drop = FALSE], na.rm = TRUE)
    b_rd <- rowMeans(mat[, w_num > 600  & w_num <= 700, drop = FALSE], na.rm = TRUE)
    tot  <- b_uv + b_bl + b_gr + b_rd
    
    r_max  <- apply(mat, 1, max, na.rm = TRUE)
    r_min  <- apply(mat, 1, min, na.rm = TRUE)
    r_mean <- rowMeans(mat, na.rm = TRUE)
    idx_max <- max.col(replace(mat, is.na(mat), -Inf), ties.method = "first")
    lambda_max <- w_num[idx_max]
    
    keep <- is.finite(r_mean) & r_mean > 0.005
    
    meta <- tibble(
      source_file  = fn,
      family_bcb   = as.character(df$Family3)[keep],
      order_bcb    = as.character(df$Order3)[keep],
      jetz_species = gsub("_", " ", as.character(df$JetzSpecies)[keep]),
      orig_species = gsub("_", " ", as.character(df$OriginalSpecies)[keep]),
      genus_bcb    = sub(" .*", "", gsub("_", " ", as.character(df$JetzSpecies)[keep])),
      sex          = as.character(df$Sex)[keep],
      patch        = as.character(df$Patch)[keep],
      b_uv         = b_uv[keep],
      b_bl         = b_bl[keep],
      b_gr         = b_gr[keep],
      b_rd         = b_rd[keep],
      prop_uv      = b_uv[keep] / pmax(tot[keep], 1e-6),
      prop_sw      = (b_uv[keep] + b_bl[keep]) / pmax(tot[keep], 1e-6),
      prop_mw      = b_gr[keep] / pmax(tot[keep], 1e-6),
      prop_lw      = b_rd[keep] / pmax(tot[keep], 1e-6),
      r_mean       = r_mean[keep],
      r_span       = (r_max - r_min)[keep],
      chroma       = (r_max[keep] - r_min[keep]) / pmax(r_mean[keep], 0.015),
      lambda_max   = lambda_max[keep]
    )
    list(meta = meta, mat = mat[keep, , drop = FALSE])
  }
  
  cat("Procesando 31,650 espectros de BirdColorBase...\n")
  res_bcb <- lapply(bcb_files, read_one_bcb)
  bcb_meta <- bind_rows(lapply(res_bcb, `[[`, "meta"))
  bcb_mat  <- do.call(rbind, lapply(res_bcb, `[[`, "mat"))
  
  # Clasificar cada espectro individual por su firma física para construir las
  # curvas empíricas de los 4 gremios ópticos (300-700 nm):
  spec_guild <- case_when(
    bcb_meta$family_bcb %in% c("Trochilidae", "Trogonidae", "Momotidae", "Galbulidae") &
      bcb_meta$chroma >= 1.1 ~ "Iridiscente y UV",
    bcb_meta$genus_bcb %in% c("Quiscalus", "Molothrus", "Tachycineta", "Chloroceryle", "Cairina", "Aix") &
      bcb_meta$chroma >= 0.9 ~ "Iridiscente y UV",
    (bcb_meta$family_bcb %in% c("Psittacidae", "Cotingidae", "Pipridae", "Maluridae") |
       bcb_meta$genus_bcb %in% c("Cyanocorax", "Cyanolyca", "Aphelocoma", "Calocitta", "Cyanocitta",
                                 "Passerina", "Cyanocompsa", "Sialia", "Cyanerpes", "Dacnis", "Thraupis", "Tangara")) &
      bcb_meta$prop_sw >= 0.42 & bcb_meta$chroma >= 1.0 ~ "Azul estructural y psitacofulvinas",
    bcb_meta$prop_lw >= 0.42 & bcb_meta$chroma >= 1.35 & bcb_meta$lambda_max >= 570 ~ "Carotenoides (rojo/amarillo)",
    bcb_meta$chroma <= 0.85 & bcb_meta$r_span <= 0.18 ~ "Melaninas (críptico/terrestre)",
    TRUE ~ NA_character_
  )
  
  guild_levels <- c(
    "Iridiscente y UV",
    "Azul estructural y psitacofulvinas",
    "Carotenoides (rojo/amarillo)",
    "Melaninas (críptico/terrestre)"
  )
  
  curves_list <- lapply(guild_levels, function(g) {
    idx <- which(spec_guild == g)
    sub_m <- bcb_mat[idx, , drop = FALSE]
    tibble(
      guild = g,
      wavelength = as.numeric(colnames(sub_m)),
      n_spectra = length(idx),
      r_median = apply(sub_m, 2, median, na.rm = TRUE) * 100,
      r_mean   = colMeans(sub_m, na.rm = TRUE) * 100,
      r_q25    = apply(sub_m, 2, quantile, probs = 0.25, na.rm = TRUE) * 100,
      r_q75    = apply(sub_m, 2, quantile, probs = 0.75, na.rm = TRUE) * 100
    )
  })
  spectral_curves <- bind_rows(curves_list) |>
    mutate(guild = factor(guild, levels = guild_levels))
  
  # Resumen óptico por especie, género y familia
  sp_optics <- bcb_meta |>
    group_by(species = jetz_species) |>
    summarise(
      n_spec = n(),
      chroma_p90 = quantile(chroma, 0.90, na.rm = TRUE),
      chroma_mean = mean(chroma, na.rm = TRUE),
      uv_p90 = quantile(prop_uv, 0.90, na.rm = TRUE),
      uv_mean = mean(prop_uv, na.rm = TRUE),
      span_p90 = quantile(r_span, 0.90, na.rm = TRUE),
      .groups = "drop"
    )
  
  gen_optics <- bcb_meta |>
    group_by(genus = genus_bcb) |>
    summarise(
      chroma_p90 = quantile(chroma, 0.90, na.rm = TRUE),
      chroma_mean = mean(chroma, na.rm = TRUE),
      uv_p90 = quantile(prop_uv, 0.90, na.rm = TRUE),
      uv_mean = mean(prop_uv, na.rm = TRUE),
      .groups = "drop"
    )
  
  fam_optics <- bcb_meta |>
    group_by(family = family_bcb) |>
    summarise(
      chroma_p90 = quantile(chroma, 0.90, na.rm = TRUE),
      chroma_mean = mean(chroma, na.rm = TRUE),
      uv_p90 = quantile(prop_uv, 0.90, na.rm = TRUE),
      uv_mean = mean(prop_uv, na.rm = TRUE),
      .groups = "drop"
    )
  
  bcb_data <- list(
    spectral_curves = spectral_curves,
    sp_optics = sp_optics,
    gen_optics = gen_optics,
    fam_optics = fam_optics,
    n_total_spectra = nrow(bcb_meta),
    n_total_species = n_distinct(bcb_meta$jetz_species),
    n_total_families = n_distinct(bcb_meta$family_bcb)
  )
  saveRDS(bcb_data, bcb_cache)
  cat("Guardado caché de BirdColorBase en:", bcb_cache, "\n")
}

cat(sprintf("BirdColorBase listo: %d espectros | %d especies | %d familias\n",
            bcb_data$n_total_spectra, bcb_data$n_total_species, bcb_data$n_total_families))

# ------------------------------------------------------------------------------
# 2. Catálogo de Especies de Aves en México desde GBIF y Clasificación Óptica
# ------------------------------------------------------------------------------
tax_cache <- "data/processed/day05_mexico_species_catalog.rds"

if (file.exists(tax_cache)) {
  cat("Cargando catálogo de especies de México desde caché:", tax_cache, "\n")
  mx_species <- readRDS(tax_cache)
} else {
  cat("Consultando faceta nacional de especies de aves en México (GBIF)...\n")
  r_mx <- GET("https://api.gbif.org/v1/occurrence/search",
              query = list(
                country = "MX", taxonKey = 212L,
                hasCoordinate = "true", hasGeospatialIssue = "false",
                occurrenceStatus = "PRESENT",
                facet = "speciesKey", facetLimit = 2000, limit = 0
              ), timeout(60))
  js_mx <- fromJSON(content(r_mx, "text", encoding = "UTF-8"), simplifyVector = FALSE)
  fc_mx <- js_mx$facets[[1]]$counts
  
  sp_raw <- tibble(
    speciesKey = vapply(fc_mx, function(x) as.integer(x$name), integer(1)),
    n_records_mx = vapply(fc_mx, function(x) as.numeric(x$count), numeric(1))
  ) |> filter(n_records_mx >= 10) # Excluir vagabundos extremos/fósiles con <10 registros
  
  cat("Resolviendo taxonomía para", nrow(sp_raw), "especies de aves en México vía curl paralelo...\n")
  pool <- new_pool(total_con = 12, host_con = 6)
  tax_list <- vector("list", nrow(sp_raw))
  
  for (i in seq_len(nrow(sp_raw))) {
    sk <- sp_raw$speciesKey[i]
    nr <- sp_raw$n_records_mx[i]
    url <- sprintf("https://api.gbif.org/v1/species/%d", sk)
    local({
      idx <- i; key <- sk; n_rec <- nr
      curl_fetch_multi(url, done = function(resp) {
        if (resp$status_code == 200) {
          d <- tryCatch(fromJSON(rawToChar(resp$content)), error = function(e) NULL)
          if (!is.null(d)) {
            tax_list[[idx]] <<- tibble(
              speciesKey = key,
              species = ifelse(!is.null(d$canonicalName), d$canonicalName, NA_character_),
              genus = ifelse(!is.null(d$genus), d$genus, NA_character_),
              family = ifelse(!is.null(d$family), d$family, NA_character_),
              order = ifelse(!is.null(d$order), d$order, NA_character_),
              n_records_mx = n_rec
            )
          }
        }
      }, pool = pool)
    })
  }
  multi_run(pool = pool)
  mx_species <- bind_rows(tax_list) |> filter(!is.na(species), !is.na(family))
  
  # Filtrar avifauna terrestre (excluyendo órdenes marinos/playeros/acuáticos pelágicos,
  # siguiendo a Dale et al. 2015 Nature y Cooney et al. 2022 Nat. Ecol. Evol.)
  water_orders <- c(
    "Charadriiformes", "Pelecaniformes", "Suliformes", "Procellariiformes",
    "Anseriformes", "Podicipediformes", "Gruiformes", "Gaviiformes",
    "Phaethontiformes", "Ciconiiformes", "Phoenicopteriformes", "Sphenisciformes",
    "Eurypygiformes"
  )
  mx_species <- mx_species |>
    mutate(is_terrestrial = !(order %in% water_orders) & !(family %in% c("Alcedinidae", "Cinclidae", "Pandionidae")))
  
  # Clasificación biofísica en los 4 gremios ópticos del plumaje (aves terrestres + martines pescadores)
  # 1) Iridiscencia estructural y UV (nanocristales de melanina y multicapas de queratina)
  # 2) Azul estructural no iridiscente y psitacofulvinas (matriz esponjosa de beta-queratina)
  # 3) Pigmentación por carotenoides (cetocarotenoides rojos/naranjas y xantofilas amarillas)
  # 4) Pigmentación por melaninas (eumelanina y feomelanina: tonos tierra, grises, pardos y negros)
  mx_species <- mx_species |>
    mutate(
      guild = case_when(
        # Gremio 1: Iridiscencia estructural y UV
        family %in% c("Trochilidae", "Trogonidae", "Momotidae", "Galbulidae") ~
          "Iridiscente y UV",
        genus %in% c("Quiscalus", "Molothrus", "Euphagus", "Tachycineta",
                     "Progne", "Chloroceryle", "Meleagris", "Patagioenas",
                     "Geotrygon", "Leptotila", "Claravis") ~
          "Iridiscente y UV",
        
        # Gremio 2: Azul estructural no iridiscente y psitacofulvinas
        family %in% c("Psittacidae", "Cotingidae", "Pipridae") ~
          "Azul estructural y psitacofulvinas",
        genus %in% c("Cyanocorax", "Cyanolyca", "Aphelocoma", "Calocitta",
                     "Cyanocitta", "Gymnorhinus", "Passerina", "Cyanocompsa",
                     "Amaurospiza", "Sialia", "Cyanerpes", "Dacnis",
                     "Chlorophonia", "Thraupis", "Tangara", "Ixothraupis",
                     "Stilpnia", "Guiraca", "Megaceryle") ~
          "Azul estructural y psitacofulvinas",
        
        # Gremio 3: Pigmentación por Carotenoides (rojos, naranjas, amarillos vivos)
        family %in% c("Ramphastidae", "Spindalidae", "Rhodinocichlidae",
                      "Bombycillidae", "Peucedramidae") ~
          "Carotenoides (rojo/amarillo)",
        family == "Cardinalidae" & !(genus %in% c("Passerina", "Cyanocompsa", "Amaurospiza")) ~
          "Carotenoides (rojo/amarillo)",
        family == "Thraupidae" & genus %in% c("Ramphocelus", "Lanio", "Piranga", "Habia",
                                              "Chrysothlypis", "Hemithraupis", "Coereba",
                                              "Sicalis", "Saltator", "Eucometis") ~
          "Carotenoides (rojo/amarillo)",
        family == "Icteridae" & genus %in% c("Icterus", "Psarocolius", "Cacicus",
                                             "Sturnella", "Xanthocephalus", "Amblycercus", "Gymnostinops") ~
          "Carotenoides (rojo/amarillo)",
        family == "Parulidae" & genus %in% c("Cardellina", "Setophaga", "Myioborus",
                                             "Geothlypis", "Basileuterus", "Protonotaria",
                                             "Vermivora", "Oreothlypis", "Leiothlypis", "Icteria") ~
          "Carotenoides (rojo/amarillo)",
        family == "Fringillidae" & genus %in% c("Spinus", "Haemorhous", "Coccothraustes",
                                                "Loxia", "Euphonia", "Chlorophonia") ~
          "Carotenoides (rojo/amarillo)",
        family == "Tyrannidae" & genus %in% c("Pyrocephalus", "Pitangus", "Myiozetetes",
                                              "Megarynchus", "Tyrannus", "Myiodynastes",
                                              "Attila", "Pachyramphus", "Tityra") ~
          "Carotenoides (rojo/amarillo)",
        family == "Picidae" & genus %in% c("Melanerpes", "Dryocopus", "Campephilus",
                                           "Colaptes", "Piculus", "Sphyrapicus", "Dryobates", "Celeus") ~
          "Carotenoides (rojo/amarillo)",
        family == "Vireonidae" & genus %in% c("Vireolanius", "Cyclarhis") ~
          "Carotenoides (rojo/amarillo)",
        family == "Ptilogonatidae" & genus %in% c("Ptiliogonys") ~
          "Carotenoides (rojo/amarillo)",
        family == "Regulidae" ~
          "Carotenoides (rojo/amarillo)",
        
        # Gremio 4: Pigmentación por Melaninas (eumelanina y feomelanina: cripticismo/Gloger)
        TRUE ~ "Melaninas (críptico/terrestre)"
      )
    )
  
  # Unir métricas espectrofotométricas de BirdColorBase (por especie -> género -> familia -> gremio)
  mx_species <- mx_species |>
    left_join(bcb_data$sp_optics |> select(species, sp_chroma = chroma_p90, sp_uv = uv_p90), by = "species") |>
    left_join(bcb_data$gen_optics |> select(genus, gen_chroma = chroma_p90, gen_uv = uv_p90), by = "genus") |>
    left_join(bcb_data$fam_optics |> select(family, fam_chroma = chroma_p90, fam_uv = uv_p90), by = "family") |>
    mutate(
      guild_chroma_default = case_when(
        guild == "Iridiscente y UV" ~ 2.95,
        guild == "Azul estructural y psitacofulvinas" ~ 2.55,
        guild == "Carotenoides (rojo/amarillo)" ~ 2.35,
        TRUE ~ 1.15
      ),
      guild_uv_default = case_when(
        guild == "Iridiscente y UV" ~ 0.235,
        guild == "Azul estructural y psitacofulvinas" ~ 0.255,
        guild == "Carotenoides (rojo/amarillo)" ~ 0.165,
        TRUE ~ 0.115
      ),
      chroma_score = coalesce(sp_chroma, gen_chroma, fam_chroma, guild_chroma_default),
      uv_score     = coalesce(sp_uv, gen_uv, fam_uv, guild_uv_default)
    )
  
  saveRDS(mx_species, tax_cache)
  cat("Guardado catálogo taxonómico y óptico en:", tax_cache, "\n")
}

cat("\nResumen de especies terrestres de México por gremio óptico:\n")
print(
  mx_species |>
    filter(is_terrestrial) |>
    group_by(guild) |>
    summarise(
      n_especies = n(),
      registros_gbif = sum(n_records_mx),
      chroma_mediano = median(chroma_score, na.rm = TRUE),
      uv_mediano = median(uv_score, na.rm = TRUE),
      .groups = "drop"
    )
)

# ------------------------------------------------------------------------------
# 3. Malla Espacial (0.6° x 0.6°) sobre México y Consulta Paralela a GBIF
# ------------------------------------------------------------------------------
mx_states_file <- "data/raw/day01/mexico_states.geojson"
if (!file.exists(mx_states_file)) {
  dir.create("data/raw/day01", recursive = TRUE, showWarnings = FALSE)
  download.file("https://raw.githubusercontent.com/angelnmara/geojson/master/mexicoHigh.json",
                mx_states_file, mode = "wb", quiet = TRUE)
}
mx_states <- st_read(mx_states_file, quiet = TRUE) |> st_make_valid()
mx_border <- st_union(mx_states) |> st_make_valid()

grid_cache <- "data/processed/day05_gbif_grid_facets.rds"

# Crear grilla regular de 0.6 x 0.6 grados que intersecta México
grid_full <- st_make_grid(mx_border, cellsize = c(0.6, 0.6), what = "polygons", square = TRUE) |>
  st_sf(crs = 4326) |>
  mutate(cell_id = row_number())

hits <- st_intersects(grid_full, mx_border, sparse = FALSE)[, 1]
grid_mx <- grid_full[hits, ] |>
  mutate(cell_id = seq_len(n()))

coords_cent <- st_coordinates(st_centroid(grid_mx))
grid_mx$lon <- coords_cent[, 1]
grid_mx$lat <- coords_cent[, 2]

if (file.exists(grid_cache)) {
  cat("Cargando facetas espaciales de GBIF por celda desde caché:", grid_cache, "\n")
  cell_facets <- readRDS(grid_cache)
} else {
  cell_facets <- vector("list", nrow(grid_mx))
}

# Construir WKT de cada caja para la consulta GBIF
geom_col <- st_geometry(grid_mx)
wkts <- vapply(seq_len(nrow(grid_mx)), function(i) {
  bb <- st_bbox(geom_col[[i]])
  sprintf("POLYGON((%.4f %.4f,%.4f %.4f,%.4f %.4f,%.4f %.4f,%.4f %.4f))",
          bb["xmin"], bb["ymin"], bb["xmax"], bb["ymin"],
          bb["xmax"], bb["ymax"], bb["xmin"], bb["ymax"],
          bb["xmin"], bb["ymin"])
}, character(1))

pend <- which(vapply(cell_facets, is.null, logical(1)))
round_num <- 1L
while (length(pend) > 0 && round_num <= 5L) {
  cat(sprintf("Ronda %d — Consultando GBIF para %d celdas pendientes (de %d totales)...\n",
              round_num, length(pend), nrow(grid_mx)))
  batch_size <- 20
  batches <- split(pend, ceiling(seq_along(pend) / batch_size))
  
  for (b_idx in seq_along(batches)) {
    idxs <- batches[[b_idx]]
    pool <- new_pool(total_con = 1, host_con = 1)
    n_429 <- 0L
    for (i in idxs) {
      q_url <- modify_url(
        "https://api.gbif.org/v1/occurrence/search",
        query = list(
          country = "MX", taxonKey = 212L, geometry = wkts[i],
          hasCoordinate = "true", hasGeospatialIssue = "false",
          occurrenceStatus = "PRESENT",
          facet = "speciesKey", facetLimit = 2000, limit = 0
        )
      )
      local({
        cid <- i
        curl_fetch_multi(q_url, done = function(resp) {
          if (resp$status_code == 200) {
            js <- tryCatch(fromJSON(rawToChar(resp$content), simplifyVector = FALSE), error = function(e) NULL)
            if (!is.null(js) && length(js$facets) > 0) {
              fc <- js$facets[[1]]$counts
              cell_facets[[cid]] <<- list(
                n_records = as.numeric(js$count),
                speciesKeys = vapply(fc, function(x) as.integer(x$name), integer(1)),
                counts = vapply(fc, function(x) as.numeric(x$count), numeric(1))
              )
            } else {
              cell_facets[[cid]] <<- list(n_records = 0, speciesKeys = integer(0), counts = numeric(0))
            }
          } else if (resp$status_code == 429) {
            n_429 <<- n_429 + 1L
          }
        }, pool = pool)
      })
    }
    multi_run(pool = pool)
    saveRDS(cell_facets, grid_cache)
    n_done <- sum(!vapply(cell_facets, is.null, logical(1)))
    cat(sprintf("  Lote %2d/%2d | Completadas: %3d/%3d celdas (429 en lote: %d)\n",
                b_idx, length(batches), n_done, nrow(grid_mx), n_429))
    Sys.sleep(ifelse(n_429 > 0, 4.0, 0.25))
  }
  pend <- which(vapply(cell_facets, is.null, logical(1)))
  round_num <- round_num + 1L
}

# ------------------------------------------------------------------------------
# 4. Cálculo de Métricas del Ensamblaje por Celda y Rásters Continuos (`terra`)
# ------------------------------------------------------------------------------
terr_sp <- mx_species |> filter(is_terrestrial)

cell_metrics <- map_dfr(seq_len(nrow(grid_mx)), function(i) {
  cf <- cell_facets[[i]]
  if (is.null(cf) || length(cf$speciesKeys) == 0) {
    return(tibble(
      cell_id = i, n_records = 0, n_sp_total = 0,
      n_irid = 0, n_blue = 0, n_carot = 0, n_melan = 0,
      pct_irid = NA_real_, pct_blue = NA_real_, pct_carot = NA_real_, pct_melan = NA_real_,
      pct_structural_total = NA_real_, pct_vivid_total = NA_real_,
      mean_chroma = NA_real_, mean_uv = NA_real_, icri = NA_real_
    ))
  }
  
  sub <- terr_sp |> filter(speciesKey %in% cf$speciesKeys)
  n_tot <- nrow(sub)
  if (n_tot < 15) {
    return(tibble(
      cell_id = i, n_records = cf$n_records, n_sp_total = n_tot,
      n_irid = NA_integer_, n_blue = NA_integer_, n_carot = NA_integer_, n_melan = NA_integer_,
      pct_irid = NA_real_, pct_blue = NA_real_, pct_carot = NA_real_, pct_melan = NA_real_,
      pct_structural_total = NA_real_, pct_vivid_total = NA_real_,
      mean_chroma = NA_real_, mean_uv = NA_real_, icri = NA_real_
    ))
  }
  
  n_irid  <- sum(sub$guild == "Iridiscente y UV")
  n_blue  <- sum(sub$guild == "Azul estructural y psitacofulvinas")
  n_carot <- sum(sub$guild == "Carotenoides (rojo/amarillo)")
  n_melan <- sum(sub$guild == "Melaninas (críptico/terrestre)")
  
  p_irid  <- 100 * n_irid / n_tot
  p_blue  <- 100 * n_blue / n_tot
  p_carot <- 100 * n_carot / n_tot
  p_melan <- 100 * n_melan / n_tot
  
  m_chroma <- mean(sub$chroma_score, na.rm = TRUE)
  m_uv     <- mean(sub$uv_score, na.rm = TRUE)
  
  # Índice Compuesto de Riqueza Cromática e Iridiscencia (ICRI, escala 0-100):
  # Combina la fracción de especies con coloración estructural/iridiscente (peso 0.50),
  # la fracción de especies con señalización carotenoide (peso 0.25) y el croma espectral
  # medio del ensamblaje (peso 0.25).
  icri_raw <- 1.45 * p_irid + 1.25 * p_blue + 0.65 * p_carot + 12 * m_chroma
  
  tibble(
    cell_id = i,
    n_records = cf$n_records,
    n_sp_total = n_tot,
    n_irid = n_irid,
    n_blue = n_blue,
    n_carot = n_carot,
    n_melan = n_melan,
    pct_irid = p_irid,
    pct_blue = p_blue,
    pct_carot = p_carot,
    pct_melan = p_melan,
    pct_structural_total = p_irid + p_blue,
    pct_vivid_total = p_irid + p_blue + p_carot,
    mean_chroma = m_chroma,
    mean_uv = m_uv,
    icri = icri_raw
  )
})

# Normalizar ICRI a escala 0-100 interpretable
rng_icri <- quantile(cell_metrics$icri, probs = c(0.01, 0.99), na.rm = TRUE)
cell_metrics <- cell_metrics |>
  mutate(
    icri = pmin(100, pmax(0, 100 * (icri - rng_icri[1]) / (rng_icri[2] - rng_icri[1])))
  )

grid_mx_dat <- grid_mx |> left_join(cell_metrics, by = "cell_id")

cat(sprintf("\nCeldas terrestres con muestreo válido (>=15 spp.): %d de %d\n",
            sum(!is.na(grid_mx_dat$icri)), nrow(grid_mx_dat)))

# Construir rásters continuos a 0.08° con `terra` (interpolación focal gaussiana + máscara de México)
cat("Construyendo rásters continuos en `terra` (resolución 0.08°)...\n")
v_mx   <- vect(mx_border)
v_grid <- vect(grid_mx_dat |> filter(!is.na(icri)))

r_tmpl <- rast(ext(-117.5, -86.5, 14.3, 32.8), res = 0.08, crs = "EPSG:4326")
w_gauss <- focalMat(r_tmpl, d = 0.48, type = "Gauss")

vars_to_raster <- c(
  "icri", "pct_irid", "pct_blue", "pct_carot", "pct_melan",
  "pct_structural_total", "pct_vivid_total", "mean_chroma", "n_sp_total"
)

rast_list <- lapply(vars_to_raster, function(vn) {
  r0 <- rasterize(v_grid, r_tmpl, field = vn, fun = "mean")
  #Dos pasadas de suavizado gaussiano con na.rm = TRUE para interpolar suavemente
  # entre celdas vecinas y eliminar bordes escalonados de la grilla de 0.6°
  r1 <- focal(r0, w = w_gauss, fun = "mean", na.policy = "all", na.rm = TRUE)
  r2 <- focal(r1, w = w_gauss, fun = "mean", na.policy = "all", na.rm = TRUE)
  r_m <- mask(r2, v_mx)
  names(r_m) <- vn
  r_m
})

r_stack <- rast(rast_list)
writeRaster(r_stack, "data/processed/day05_rasters.tif", overwrite = TRUE)

# Convertir el SpatRaster a tabla (x, y, capas) para graficar en ggplot2 / geom_raster
rast_df <- as.data.frame(r_stack, xy = TRUE, na.rm = TRUE) |> as_tibble()

# Guardar todo el dataset procesado
out_ds <- list(
  grid_sf = grid_mx_dat,
  rast_df = rast_df,
  mx_states = mx_states,
  mx_border = mx_border,
  mx_species = mx_species,
  spectral_curves = bcb_data$spectral_curves,
  bcb_summary = list(
    n_spectra = bcb_data$n_total_spectra,
    n_species = bcb_data$n_total_species,
    n_families = bcb_data$n_total_families
  )
)

saveRDS(out_ds, "data/processed/day05_dataset.rds")
cat("¡Pipeline completado! Guardados data/processed/day05_dataset.rds y data/processed/day05_rasters.tif\n")
