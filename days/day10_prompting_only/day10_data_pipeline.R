# ==============================================================================
# Día 10 — Prompting only: El Bestiario y Herbario Toponímico de México
# Pipeline de Datos y Clasificador Léxico-Espacial de ~300,000 Localidades
#
# Autor: Fernando Dorantes Nieto (@FerDoranNie)
# Reto: #30DayMapChallenge 2026 — 10 de noviembre de 2026
# Fuente: Catálogo Único de Localidades (AGEEML - INEGI)
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(stringr)
  library(stringi)
  library(tidyr)
})

sf_use_s2(FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

cat("======================================================================\n")
cat(" [DÍA 10 - DATA PIPELINE] El Bestiario y Herbario Toponímico de México\n")
cat("======================================================================\n\n")

# ------------------------------------------------------------------------------
# 1. Carga y depuración del Catálogo Nacional de Localidades (INEGI)
# ------------------------------------------------------------------------------
cat("[1/5] Leyendo catálogo nacional de localidades AGEEML...\n")
csv_path <- "data/raw/day10/AGEEML_20251141548499.csv"

df_raw <- read_csv(
  csv_path,
  col_select = c(
    "CVEGEO", "CVE_ENT", "NOM_ENT", "CVE_MUN", "NOM_MUN",
    "CVE_LOC", "NOM_LOC", "AMBITO", "LAT_DECIMAL", "LON_DECIMAL",
    "ALTITUD", "POB_TOTAL"
  ),
  col_types = cols(
    CVEGEO      = col_character(),
    CVE_ENT     = col_character(),
    NOM_ENT     = col_character(),
    CVE_MUN     = col_character(),
    NOM_MUN     = col_character(),
    CVE_LOC     = col_character(),
    NOM_LOC     = col_character(),
    AMBITO      = col_character(),
    LAT_DECIMAL = col_double(),
    LON_DECIMAL = col_double(),
    ALTITUD     = col_double(),
    POB_TOTAL   = col_character()
  ),
  locale = locale(encoding = "Latin1"),
  show_col_types = FALSE
)

cat("  -> Registros totales en catálogo:", nrow(df_raw), "\n")

# Filtrar coordenadas válidas en la extensión territorial de México
df_clean <- df_raw |>
  filter(
    !is.na(LAT_DECIMAL) & !is.na(LON_DECIMAL),
    LAT_DECIMAL >= 14.0 & LAT_DECIMAL <= 33.5,
    LON_DECIMAL >= -119.0 & LON_DECIMAL <= -86.0,
    !is.na(NOM_LOC) & NOM_LOC != ""
  ) |>
  mutate(
    # Normalización: minúsculas, remoción de acentos diacríticos
    nom_norm = str_to_lower(NOM_LOC),
    nom_norm = stri_trans_general(nom_norm, "Latin-ASCII"),
    # Reemplazar caracteres especiales y signos de puntuación por espacios
    nom_clean = str_replace_all(nom_norm, "[^a-z0-9]", " "),
    nom_clean = str_squish(nom_clean)
  )

cat("  -> Localidades con coordenadas y nombres válidos:", nrow(df_clean), "\n\n")

# ------------------------------------------------------------------------------
# 2. Diccionario Taxonómico–Lingüístico y Filtros de Exclusión Antropónima
# ------------------------------------------------------------------------------
cat("[2/5] Aplicando clasificador léxico-espacial (Fauna y Flora)...\n")

# Filtro de exclusión de antropónimos, títulos de personas, próceres y apellidos
regex_exclusiones <- paste0(
  "\\b(pino suarez|emiliano zapata|venustiano carranza|leona vicario|",
  "guadalupe victoria|nuevo leon|leon de los aldama|vicente guerrero|",
  "lazaro cardenas|alvaro obregon|miguel hidalgo|jose maria morelos|",
  "benito juarez|francisco i madero|ignacio zaragoza|melchor ocampo|",
  "aquiles serdan|ninos heroes|aguila azteca|hermenegildo galeana|",
  "mariano matamoros|belisario dominguez|plutarco elias calles|",
  "diaz de leon|ponce de leon|de leon|familia leon|dr |lic |prof |ing |",
  "general |coronel |teniente |don |dona |hermanos |hermanas )\\b"
)

# Diccionario de Fauna (6 grupos)
regex_coyote <- "\\b(coyot[ea]s?|coyotera|coyotillos?|coyotlan)\\b"
regex_venado <- "\\b(venados?|venaditos?|venadero|mazatlan|mazatepec|cervatillos?)\\b"
regex_felinos <- "\\b(jaguares?|tigres?|tigrillos?|ocelot[el]s?|pumas?|balam|tecuani)\\b|\\b(el leon|los leones|rincon del leon|arroyo leon|puerto leon|cerro leon|canon leon|agua leon|potrero leon|cueva leon|barranca leon|leoncito|leoncitos|salto del leon|ojo de agua leon|paso leon)\\b"
regex_aves <- "\\b(aguilas?|aguilillas?|gavilanes?|zopilotes?|palomas?|grullas?|cenzontles?|cuauhtlan|halcon(es)?|quetzales?)\\b"
regex_serpientes <- "\\b(viboras?|viborillas?|culebras?|cascabel(es)?|coatlan|coatepec)\\b"
regex_fauna_menor <- "\\b(armadillos?|tlacuaches?|jabali(es|s)?|conejos?|conejeras?|monos?|saraguatos?|ardillas?|liebres?|zorros?|zorrillos?)\\b"

# Diccionario de Flora (6 grupos)
regex_pino_ocote <- "\\b(ocotes?|ocotal(es)?|ocotlan|pinos?|pinal(es)?|oyamel(es)?|encinos?|encinal(es)?|robles?)\\b"
regex_cactaceas <- "\\b(nopal(es|era|itos?|tepec)?|tunas?|tunal(es)?|maguey(es|era)?|cardon(es|al)?|sahuaros?|pitayas?|biznagas?)\\b"
regex_mezquite_huizache <- "\\b(mezquit(es?|al|era|illos?)|huizach(es?|al|era)|palo\\s+verde|palo\\s+blanco)\\b"
regex_selva_tropical <- "\\b(ceibas?|ceibal|cedros?|cedral(es)?|caobas?|yaxche|palmas?|palmar(es|ito)?)\\b"
regex_sabino_sauce <- "\\b(ahuehuet(es?|la)|sabinos?|sabinal(es)?|sauces?|sauz|saucillo|alamos?|alamitos?)\\b"
regex_frutales_nativos <- "\\b(capulin(es)?|tejocotes?|guamuchil(es)?|zapotes?|zapotal(es)?|chirimoyos?|ciruelos?|guayabos?|guayabas?|aguacates?)\\b"

# Filtrar antropónimos
df_filtrado <- df_clean |>
  filter(!str_detect(nom_clean, regex_exclusiones))

# Asignar grupos específicos con reglas deterministas
df_clasificado <- df_filtrado |>
  mutate(
    # Banderas booleanas de coincidencia
    m_coyote           = str_detect(nom_clean, regex_coyote),
    m_venado           = str_detect(nom_clean, regex_venado),
    m_felinos          = str_detect(nom_clean, regex_felinos) & !str_detect(nom_clean, "nuevo leon"),
    m_aves             = str_detect(nom_clean, regex_aves),
    m_serpientes       = str_detect(nom_clean, regex_serpientes),
    m_fauna_menor      = str_detect(nom_clean, regex_fauna_menor),
    
    m_pino_ocote       = str_detect(nom_clean, regex_pino_ocote),
    m_cactaceas        = str_detect(nom_clean, regex_cactaceas),
    m_mezquite         = str_detect(nom_clean, regex_mezquite_huizache),
    m_selva            = str_detect(nom_clean, regex_selva_tropical),
    m_sabino_sauce     = str_detect(nom_clean, regex_sabino_sauce),
    m_frutales         = str_detect(nom_clean, regex_frutales_nativos),
    
    # Asignación jerárquica de grupo
    grupo_id = case_when(
      m_coyote           ~ "coyote",
      m_venado           ~ "venado",
      m_felinos          ~ "felinos",
      m_aves             ~ "aves",
      m_serpientes       ~ "serpientes",
      m_fauna_menor      ~ "fauna_menor",
      m_pino_ocote       ~ "pino_ocote",
      m_cactaceas        ~ "cactaceas",
      m_mezquite         ~ "mezquite_huizache",
      m_selva            ~ "selva_tropical",
      m_sabino_sauce     ~ "sabino_sauce",
      m_frutales         ~ "frutales_nativos",
      TRUE               ~ NA_character_
    )
  ) |>
  filter(!is.na(grupo_id)) |>
  mutate(
    reino = if_else(grupo_id %in% c("coyote", "venado", "felinos", "aves", "serpientes", "fauna_menor"), "Fauna", "Flora"),
    grupo_label = case_when(
      grupo_id == "coyote"            ~ "Coyote (Canis latrans)",
      grupo_id == "venado"            ~ "Venado y Ciervo (Mazatl)",
      grupo_id == "felinos"           ~ "Jaguar, Tigre y Puma (Balam)",
      grupo_id == "aves"              ~ "Águila, Gavilán y Aves (Cuauhtli)",
      grupo_id == "serpientes"        ~ "Víbora y Serpiente (Coatl)",
      grupo_id == "fauna_menor"       ~ "Fauna Menor (Armadillo, Conejo, Zorrillo)",
      grupo_id == "pino_ocote"        ~ "Pino, Ocote y Encino (Bosque Templado)",
      grupo_id == "cactaceas"         ~ "Nopal, Tuna y Maguey (Cactáceas)",
      grupo_id == "mezquite_huizache" ~ "Mezquite y Huizache (Matorral Árido)",
      grupo_id == "selva_tropical"    ~ "Ceiba, Cedro y Palma (Selva Húmeda)",
      grupo_id == "sabino_sauce"      ~ "Sabino, Sauce y Álamo (Ríos y Lagos)",
      grupo_id == "frutales_nativos"  ~ "Capulín, Tejocote y Zapote (Frutales Nativos)"
    ),
    # Gran Dominio Ecocultural
    dominio_ecocultural = case_when(
      reino == "Fauna"                                           ~ "Bestiario Silvestre (Coyote, Venado, Jaguar, Águila)",
      grupo_id %in% c("pino_ocote")                              ~ "Bosque de Montaña (Pino, Ocote, Encino)",
      grupo_id %in% c("mezquite_huizache", "cactaceas")          ~ "Desierto y Semidesierto (Mezquite, Nopal, Maguey)",
      grupo_id %in% c("selva_tropical")                          ~ "Selva Tropical y Costa (Ceiba, Cedro, Palma)",
      grupo_id %in% c("sabino_sauce", "frutales_nativos")        ~ "Riberas, Sabinos y Frutales Nativos"
    )
  )

cat("  -> Total de localidades con topónimos biológicos filtrados:", nrow(df_clasificado), "\n")
cat("     - Localidades del Bestiario (Fauna):", sum(df_clasificado$reino == "Fauna"), "\n")
cat("     - Localidades del Herbario (Flora):", sum(df_clasificado$reino == "Flora"), "\n\n")

# ------------------------------------------------------------------------------
# 3. Georreferenciación y Proyección Cartográfica Oficial de México (EPSG:6372)
# ------------------------------------------------------------------------------
cat("[3/5] Reproyectando a coordenadas cónicas conformes de Lambert de México (EPSG:6372)...\n")

mx_states <- st_read("data/raw/day01/mexico_states.geojson", quiet = TRUE) |>
  st_transform(6372)

mx_union <- st_union(mx_states)

sf_localidades <- st_as_sf(
  df_clasificado,
  coords = c("LON_DECIMAL", "LAT_DECIMAL"),
  crs = 4326
) |>
  st_transform(6372)

# Intersección espacial para retener puntos en territorio nacional
sf_localidades <- sf_localidades[st_intersects(sf_localidades, mx_union, sparse = FALSE), ]

cat("  -> Localidades proyectadas dentro del contorno nacional:", nrow(sf_localidades), "\n\n")

# ------------------------------------------------------------------------------
# 4. Agregación Espacial Hexagonal (Malla de 35 km)
# ------------------------------------------------------------------------------
cat("[4/5] Generando malla hexagonal nacional (35 km) para densidad y dominancia...\n")

hex_grid <- st_make_grid(
  mx_union,
  cellsize = 35000,
  square = FALSE
) |>
  st_as_sf() |>
  rename(geometry = x) |>
  mutate(hex_id = row_number())

hex_grid <- hex_grid[st_intersects(hex_grid, mx_union, sparse = FALSE), ]

joined <- st_join(sf_localidades, hex_grid)

hex_resumen <- joined |>
  st_drop_geometry() |>
  filter(!is.na(hex_id)) |>
  group_by(hex_id, dominio_ecocultural) |>
  summarise(n = n(), .groups = "drop") |>
  group_by(hex_id) |>
  arrange(desc(n)) |>
  summarise(
    total_locs = sum(n),
    dominio_top = first(dominio_ecocultural),
    pct_top = first(n) / sum(n),
    .groups = "drop"
  )

hex_final <- hex_grid |>
  inner_join(hex_resumen, by = "hex_id")

# ------------------------------------------------------------------------------
# 5. Estadísticas de Síntesis y Resumen Nacional
# ------------------------------------------------------------------------------
cat("[5/5] Generando tablas estadísticas de conteos y ejemplos curados...\n")

conteos_grupo <- df_clasificado |>
  group_by(reino, grupo_id, grupo_label) |>
  summarise(
    n_localidades = n(),
    ejemplos = paste(head(unique(NOM_LOC), 3), collapse = ", "),
    .groups = "drop"
  ) |>
  arrange(reino, desc(n_localidades))

print(conteos_grupo)

conteos_dominio <- df_clasificado |>
  group_by(dominio_ecocultural) |>
  summarise(
    total = n(),
    pct = round(100 * n() / nrow(df_clasificado), 1),
    .groups = "drop"
  ) |>
  arrange(desc(total))

# Guardar dataset procesado
out_file <- "data/processed/day10_toponimos_biologicos.rds"
saveRDS(
  list(
    localidades_bio  = sf_localidades,
    hex_grid         = hex_final,
    mx_states        = mx_states,
    mx_union         = mx_union,
    conteos_grupo    = conteos_grupo,
    conteos_dominio  = conteos_dominio,
    total_catalogo   = nrow(df_raw),
    total_bio        = nrow(sf_localidades)
  ),
  file = out_file
)

cat("\n[ÉXITO] Pipeline completado. Archivo generado en:", out_file, "\n")
