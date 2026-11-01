# ==============================================================================
# #30DayMapChallenge 2026 — Día 01: Points
# Tema: Constelaciones del Endemismo Alado en México
# Autor: Fernando Dorantes Nieto (@FerDoranNie)
# ==============================================================================
# Descripción:
#   Descarga registros georreferenciados desde la API pública de GBIF para una
#   selección representativa de especies de aves estrictamente endémicas de México
#   (con énfasis en 6 especies insignia de distintas regiones biogeográficas) y
#   construye un póster estilo "constelaciones" sobre fondo oscuro con un mapa
#   principal de México y 6 paneles de especies bandera.
# ==============================================================================

# Asegurar que la librería de usuario de R esté en .libPaths()
user_lib <- file.path(Sys.getenv("USERPROFILE"), "AppData", "Local", "R", "win-library", "4.3")
if (dir.exists(user_lib) && !(user_lib %in% .libPaths())) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(sf)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(patchwork)
  library(httr)
  library(jsonlite)
  library(scales)
})

# Evitar errores de geometría esférica estricta al cortar polígonos
sf_use_s2(FALSE)

# Rutas del proyecto
dir.create("data/raw/day01", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/high_res", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/gallery", recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------------------------
# 1. Catálogo curado de aves endémicas de México (6 especies insignia + 18 adicionales)
# ------------------------------------------------------------------------------
species_catalog <- tibble::tribble(
  ~scientific_name,              ~common_name,                  ~region,                       ~flagship, ~color_hex,
  # 6 Especies Bandera (para los mini-mapas laterales e inferiores)
  "Cyanocorax dickeyi",          "Chara Pinta",                 "Sierra Madre Occidental",     TRUE,      "#38bdf8",
  "Campylorhynchus yucatanicus", "Matraca Yucateca",            "Península de Yucatán",        TRUE,      "#facc15",
  "Xenospiza baileyi",           "Gorrión Serrano",             "Eje Neovolcánico y SMO",      TRUE,      "#fb7185",
  "Cynanthus forficatus",        "Esmeralda de Cozumel",        "Isla Cozumel (Caribe)",       TRUE,      "#34d399",
  "Euptilotis neoxenus",         "Trogón Orejón",               "Bosques Templados (SMO)",     TRUE,      "#c084fc",
  "Calocitta colliei",           "Urraca Cara Negra",           "Pacífico Norte y Noroeste",   TRUE,      "#f97316",
  # Otras especies estrictamente endémicas de México para nutrir la "constelación" nacional
  "Rhynchopsitta pachyrhyncha",  "Cotorra Serrana Occidental",  "Sierra Madre Occidental",     FALSE,     "#38bdf8",
  "Rhynchopsitta terrisi",       "Cotorra Serrana Oriental",    "Sierra Madre Oriental",       FALSE,     "#a78bfa",
  "Geothlypis speciosa",         "Mascarita Transvolcánica",    "Humedales Eje Neovolcánico",  FALSE,     "#fb7185",
  "Romerolagus diazi",           NA_character_,                 NA_character_,                 FALSE,     NA_character_
) %>%
  filter(!is.na(common_name)) %>%
  bind_rows(
    tibble::tribble(
      ~scientific_name,              ~common_name,                    ~region,                       ~flagship, ~color_hex,
      "Dendrortyx macroura",         "Codorniz-coluda Transvolcánica","Eje Neovolcánico",            FALSE,     "#fb7185",
      "Philortyx fasciatus",         "Codorniz Listada",              "Cuenca del Balsas / Pacífico",FALSE,     "#f59e0b",
      "Callipepla douglasii",        "Codorniz Cresta Dorada",        "Pacífico Noroeste",           FALSE,     "#f97316",
      "Meleagris ocellata",          "Guajolote Ocelado",             "Península de Yucatán",        FALSE,     "#facc15",
      "Amazona finschi",             "Loro Corona Lila",              "Vertiente del Pacífico",      FALSE,     "#f97316",
      "Amazona xantholora",          "Loro Yucateco",                 "Península de Yucatán",        FALSE,     "#facc15",
      "Forpus cyanopygius",          "Perico Catarino",               "Pacífico Mexicano",           FALSE,     "#f97316",
      "Phaethornis mexicanus",       "Ermitaño Mexicano",             "Sierra Madre del Sur",        FALSE,     "#34d399",
      "Eupherusa poliocerca",        "Colibrí Cola Blanca",           "Sierra Madre del Sur",        FALSE,     "#34d399",
      "Eupherusa cyanophrys",        "Colibrí Miahuatleco",           "Sierra de Miahuatlán (Oax.)", FALSE,     "#34d399",
      "Doricha eliza",               "Colibrí Tijereta Mexicano",     "Veracruz y Costa de Yucatán", FALSE,     "#facc15",
      "Atthis heloisa",              "Zumbador Mexicano",             "Montañas de México",          FALSE,     "#c084fc",
      "Momotus mexicanus",           "Momoto Corona Café",            "Pacífico y Cuenca del Balsas",FALSE,     "#f59e0b",
      "Melanerpes pygmaeus",         "Carpintero Yucateco",           "Península de Yucatán",        FALSE,     "#facc15",
      "Melanerpes chrysogenys",      "Carpintero Mejilla Dorada",     "Pacífico Mexicano",           FALSE,     "#f97316",
      "Deltarhynchus flammulatus",   "Papamoscas Jaspeado",           "Bosque Seco del Pacífico",    FALSE,     "#f59e0b",
      "Cyanolyca nana",              "Chara Enana",                   "Bosques de Oaxaca y Veracruz",FALSE,     "#38bdf8",
      "Cyanolyca mirabilis",         "Chara Garganta Blanca",         "Sierra Madre del Sur",        FALSE,     "#38bdf8",
      "Aphelocoma ultramarina",      "Chara Transvolcánica",          "Eje Neovolcánico",            FALSE,     "#fb7185",
      "Campylorhynchus megalopterus","Matraca Barrada",               "Eje Neovolcánico",            FALSE,     "#fb7185",
      "Toxostoma ocellatum",         "Cuitlacoche Ocelado",           "Altiplano y Centro-Sur",      FALSE,     "#c084fc",
      "Melozone kieneri",            "Rascador Nuca Rufa",            "Occidente y Sur de México",   FALSE,     "#f97316",
      "Piranga erythrocephala",      "Piranga Cabeza Roja",           "Vertiente del Pacífico y SMO",FALSE,     "#fb7185",
      "Granatellus venustus",        "Granatelo Mexicano",            "Pacífico Mexicano",           FALSE,     "#f59e0b",
      "Ergaticus ruber",             "Chipe Rojo (Cardellina rubra)", "Montañas de Pino-Encino",     FALSE,     "#fb7185",
      "Icterus abeillei",            "Calandria Flancos Negros",      "Altiplano y Eje Neovolcánico",FALSE,     "#f59e0b",
      # Endémicas de la Península de Baja California y Noroeste
      "Toxostoma cinereum",          "Cuitlacoche Peninsular",        "Península de Baja California",FALSE,     "#38bdf8",
      "Basilinna xantusii",          "Colibrí de Xantus",             "Península de Baja California",FALSE,     "#38bdf8",
      "Geothlypis beldingi",         "Mascarita Peninsular",          "Oasis de Baja California Sur",FALSE,     "#38bdf8"
    )
  )

# ------------------------------------------------------------------------------
# 2. Función ligera para consultar GBIF Occurrence API directamente vía REST
# ------------------------------------------------------------------------------
fetch_gbif_species <- function(sci_name, max_records = 300) {
  message(sprintf("Consultando GBIF para: %s ...", sci_name))
  
  # 1) Resolver usageKey en el backbone taxonómico de GBIF
  match_res <- tryCatch(
    GET(
      "https://api.gbif.org/v1/species/match",
      query = list(name = sci_name, kingdom = "Animalia"),
      timeout(20)
    ),
    error = function(e) NULL
  )
  
  if (is.null(match_res) || status_code(match_res) != 200) return(tibble())
  match_json <- fromJSON(content(match_res, as = "text", encoding = "UTF-8"))
  usage_key <- match_json$usageKey
  if (is.null(usage_key)) return(tibble())
  
  # 2) Descargar ocurrencias con coordenadas en México (country = MX)
  occ_res <- tryCatch(
    GET(
      "https://api.gbif.org/v1/occurrence/search",
      query = list(
        taxonKey = usage_key,
        country = "MX",
        hasCoordinate = "true",
        hasGeospatialIssue = "false",
        limit = max_records
      ),
      timeout(25)
    ),
    error = function(e) NULL
  )
  
  if (is.null(occ_res) || status_code(occ_res) != 200) return(tibble())
  occ_json <- fromJSON(content(occ_res, as = "text", encoding = "UTF-8"), flatten = TRUE)
  
  if (length(occ_json$results) == 0 || !is.data.frame(occ_json$results)) return(tibble())
  
  df <- occ_json$results
  if (!all(c("decimalLongitude", "decimalLatitude") %in% names(df))) return(tibble())
  
  df %>%
    transmute(
      scientific_name = sci_name,
      lon = as.numeric(decimalLongitude),
      lat = as.numeric(decimalLatitude),
      year = if ("year" %in% names(df)) as.integer(year) else NA_integer_
    ) %>%
    filter(!is.na(lon), !is.na(lat)) %>%
    # Redondear ligeramente a ~1 km para eliminar duplicados exactos de un mismo sitio
    mutate(lon_r = round(lon, 2), lat_r = round(lat, 2)) %>%
    distinct(scientific_name, lon_r, lat_r, .keep_all = TRUE) %>%
    select(-lon_r, -lat_r)
}

cache_file <- "data/processed/day01_endemic_birds_gbif.rds"

if (file.exists(cache_file)) {
  message("Cargando datos en caché desde: ", cache_file)
  birds_df <- readRDS(cache_file)
  missing_sp <- setdiff(species_catalog$scientific_name, unique(birds_df$scientific_name))
  if (length(missing_sp) > 0) {
    message("Descargando especies faltantes: ", paste(missing_sp, collapse = ", "))
    extra_raw <- map_dfr(missing_sp, ~fetch_gbif_species(.x, max_records = 250))
    extra_df <- extra_raw %>% inner_join(species_catalog, by = "scientific_name")
    birds_df <- bind_rows(birds_df, extra_df)
    saveRDS(birds_df, cache_file)
  }
} else {
  birds_raw <- map_dfr(species_catalog$scientific_name, function(sp) {
    is_flag <- species_catalog$flagship[species_catalog$scientific_name == sp][1]
    lim <- ifelse(is_flag, 300, 250)
    fetch_gbif_species(sp, max_records = lim)
  })
  
  birds_df <- birds_raw %>%
    inner_join(species_catalog, by = "scientific_name")
  
  saveRDS(birds_df, cache_file)
  message(sprintf("Guardados %s registros únicos en %s", nrow(birds_df), cache_file))
}

# ------------------------------------------------------------------------------
# 3. Descargar o cargar geometría de Estados de México (GeoJSON ligero)
# ------------------------------------------------------------------------------
mx_states_file <- "data/raw/day01/mexico_states.geojson"
if (!file.exists(mx_states_file)) {
  message("Descargando contorno estatal de México...")
  # GeoJSON ligero de estados de México (angelnmara / gangulys)
  geojson_url <- "https://raw.githubusercontent.com/angelnmara/geojson/master/mexicoHigh.json"
  download.file(geojson_url, mx_states_file, mode = "wb", quiet = TRUE)
}

mx_states <- st_read(mx_states_file, quiet = TRUE) %>%
  st_make_valid()
mx_border <- st_union(mx_states)

# Filtrar puntos estrictamente dentro del bounding box de México continental e insular
birds_sf <- st_as_sf(birds_df, coords = c("lon", "lat"), crs = 4326, remove = FALSE) %>%
  filter(lon >= -118.5, lon <= -86.0, lat >= 14.0, lat <= 32.8)

message(sprintf("Total de puntos listos para mapear: %s observaciones de %s especies.",
                format(nrow(birds_sf), big.mark = ","),
                n_distinct(birds_sf$scientific_name)))

# ------------------------------------------------------------------------------
# 4. Construcción del Póster Cartográfico ("Constelaciones del Endemismo")
# ------------------------------------------------------------------------------
bg_canvas <- "#F7F4EB"
bg_ocean  <- "#DCE6F2"
bg_panel  <- "#1E2D45"
mx_fill   <- "#1E2D45"
mx_line   <- "#395075"
mx_coast  <- "#152236"
text_main <- "#0f172a"
text_sub  <- "#334155"

# Leyenda manual de colores por provincia/región biogeográfica en el mapa principal
legend_pts <- tibble::tribble(
  ~x,      ~y,     ~color_hex, ~label,
  -117.15, 18.85,  "#fb7185",  "Eje Neovolcánico y Centro-Sur",
  -117.15, 18.12,  "#38bdf8",  "Sierra Madre Occidental y B.C.",
  -117.15, 17.39,  "#f97316",  "Pacífico y Cuenca del Balsas",
  -117.15, 16.66,  "#facc15",  "Península de Yucatán",
  -117.15, 15.93,  "#34d399",  "Sierra Madre del Sur y Cozumel",
  -117.15, 15.20,  "#c084fc",  "Sierra Madre Oriental y Altiplano"
)

# Mapa Central Principal: Todas las constelaciones de endemismo en México
p_main <- ggplot() +
  # Sombra exterior sutil del país sobre el mar azul atlas
  geom_sf(data = mx_border, fill = NA, color = "#64748b", linewidth = 1.4, alpha = 0.35) +
  # Relleno y división estatal en azul pizarra medio
  geom_sf(data = mx_states, fill = mx_fill, color = mx_line, linewidth = 0.25) +
  geom_sf(data = mx_border, fill = NA, color = mx_coast, linewidth = 0.55) +
  # Efecto "resplandor" (halo exterior suave)
  geom_point(
    data = birds_df,
    aes(x = lon, y = lat, color = color_hex),
    size = 2.4, alpha = 0.10, shape = 16
  ) +
  geom_point(
    data = birds_df,
    aes(x = lon, y = lat, color = color_hex),
    size = 1.2, alpha = 0.26, shape = 16
  ) +
  # Núcleo brillante de cada observación
  geom_point(
    data = birds_df,
    aes(x = lon, y = lat, color = color_hex),
    size = 0.48, alpha = 0.90, shape = 16
  ) +
  # Cartela compacta ajustada al texto con letra más grande (sin tocar la costa)
  annotate(
    "rect", xmin = -117.65, xmax = -107.65, ymin = 14.65, ymax = 20.15,
    fill = bg_panel, color = "#64748b", linewidth = 0.45
  ) +
  annotate(
    "text", x = -117.35, y = 19.62,
    label = "REGIONES BIOGEOGRÁFICAS",
    color = "#f8fafc", size = 3.25, hjust = 0, fontface = "bold"
  ) +
  geom_point(data = legend_pts, aes(x = x, y = y, color = color_hex), size = 3.3, alpha = 0.35) +
  geom_point(data = legend_pts, aes(x = x, y = y, color = color_hex), size = 1.75, alpha = 0.95) +
  geom_text(
    data = legend_pts, aes(x = x + 0.50, y = y, label = label),
    color = "#f1f5f9", size = 3.1, hjust = 0
  ) +
  scale_color_identity() +
  annotate(
    "label", x = -96.5, y = 31.3,
    label = sprintf("%s localidades únicas  |  %d especies estrictamente endémicas",
                    format(nrow(birds_df), big.mark = ","),
                    n_distinct(birds_df$scientific_name)),
    fill = bg_panel, color = "#f8fafc", size = 3.3, fontface = "bold",
    label.size = 0.35, label.padding = unit(0.45, "lines")
  ) +
  coord_sf(xlim = c(-118.2, -86.2), ylim = c(14.2, 32.8), expand = FALSE) +
  theme_void() +
  theme(
    plot.background = element_rect(fill = bg_canvas, color = NA),
    panel.background = element_rect(fill = bg_ocean, color = "#94a3b8", linewidth = 0.65),
    plot.margin = margin(5, 5, 5, 5)
  )

# Función para crear cada uno de los 6 mini-mapas de Especies Bandera
make_flagship_card <- function(sp_row) {
  sp_data <- birds_df %>% filter(scientific_name == sp_row$scientific_name)
  n_obs <- nrow(sp_data)
  
  ggplot() +
    geom_sf(data = mx_states, fill = "#263854", color = "#395075", linewidth = 0.14) +
    # Puntos de fondo de todas las demás especies muy tenues como contexto
    geom_point(
      data = birds_df,
      aes(x = lon, y = lat),
      color = "#64748b", size = 0.15, alpha = 0.18, shape = 16
    ) +
    # Halo de la especie bandera
    geom_point(
      data = sp_data,
      aes(x = lon, y = lat),
      color = sp_row$color_hex, size = 3.0, alpha = 0.18, shape = 16
    ) +
    geom_point(
      data = sp_data,
      aes(x = lon, y = lat),
      color = sp_row$color_hex, size = 1.4, alpha = 0.45, shape = 16
    ) +
    # Punto central brillante
    geom_point(
      data = sp_data,
      aes(x = lon, y = lat),
      color = "#ffffff", size = 0.45, alpha = 0.9, shape = 16
    ) +
    coord_sf(xlim = c(-118.0, -86.3), ylim = c(14.3, 32.7), expand = FALSE) +
    labs(
      title = sp_row$common_name,
      subtitle = sprintf("%s\n%s (n = %s)", sp_row$scientific_name, sp_row$region, n_obs)
    ) +
    theme_void() +
    theme(
      plot.background = element_rect(fill = bg_panel, color = sp_row$color_hex, linewidth = 0.45),
      panel.background = element_rect(fill = bg_panel, color = NA),
      plot.title = element_text(
        color = sp_row$color_hex, face = "bold", size = 10.5,
        hjust = 0.06, margin = margin(t = 7, b = 2)
      ),
      plot.subtitle = element_text(
        color = "#cbd5e1", face = "italic", size = 7.8,
        hjust = 0.06, lineheight = 1.15, margin = margin(b = 4)
      ),
      plot.margin = margin(6, 6, 6, 6)
    )
}

flagships <- species_catalog %>% filter(flagship)
cards <- map(seq_len(nrow(flagships)), ~make_flagship_card(flagships[.x, ]))

# Diseño del póster: Mapa grande arriba y mosaico de 6 tarjetas de especies bandera abajo (2x3)
cards_grid <- (cards[[1]] | cards[[2]] | cards[[3]]) /
              (cards[[4]] | cards[[5]] | cards[[6]])

final_poster <- (p_main / cards_grid) +
  plot_layout(heights = c(2.05, 1.25)) +
  plot_annotation(
    title = '"CONSTELACIONES" DEL ENDEMISMO AVIAR EN MÉXICO',
    subtitle = "Distribución espacial de aves estrictamente endémicas de México: de las cumbres de la Sierra Madre y los humedales\ndel Eje Neovolcánico hasta las selvas de Yucatán e Isla Cozumel. Abajo: 6 especies insignia y su huella biogeográfica.",
    caption = "#30DayMapChallenge 2026  |  Día 01: Points  |  Datos: GBIF (Global Biodiversity Information Facility) & CONABIO\nVisualización: Fernando Dorantes Nieto (@FerDoranNie)  |  Herramientas: R (sf, ggplot2, patchwork)",
    theme = theme(
      plot.background = element_rect(fill = bg_canvas, color = NA),
      plot.title = element_text(
        color = text_main, face = "bold", size = 20,
        hjust = 0.5, margin = margin(t = 14, b = 6)
      ),
      plot.subtitle = element_text(
        color = text_sub, size = 11, hjust = 0.5,
        lineheight = 1.25, margin = margin(b = 10)
      ),
      plot.caption = element_text(
        color = "#475569", size = 8.5, hjust = 0.5,
        lineheight = 1.3, margin = margin(t = 12, b = 10)
      ),
      plot.margin = margin(10, 14, 10, 14)
    )
  )

# ------------------------------------------------------------------------------
# 5. Exportación en Alta Resolución y Versión Galería
# ------------------------------------------------------------------------------
out_high <- "outputs/high_res/day01_points_aves_endemicas.png"
out_gallery <- "outputs/gallery/day01_points_aves_endemicas.png"

ggsave(out_high, final_poster, width = 13, height = 14.5, dpi = 300, bg = bg_canvas)
ggsave(out_gallery, final_poster, width = 13, height = 14.5, dpi = 140, bg = bg_canvas)

message("¡Mapa del Día 01 generado exitosamente!")
message(" - Alta resolución: ", out_high)
message(" - Galería README:  ", out_gallery)
