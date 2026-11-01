# ==============================================================================
# #30DayMapChallenge 2026 — Día 03: Polygons
# Tema: El escudo verde de México — ¿qué protege realmente la red federal de ANP?
# Autor: Fernando Dorantes Nieto (@FerDoranNie)
# Entorno: R 4.3.2 (librería de usuario) — sf, terra, ggplot2, patchwork
# ==============================================================================
# Descripción:
#   Construye el mapa nacional de las Áreas Naturales Protegidas federales de
#   México como polígonos coloreados por un Índice de Presión Antrópica (IPA)
#   derivado del Uso del Suelo y Vegetación de INEGI (Serie VII, 2018), y lo
#   contrasta contra el anillo de 10 km que rodea a cada ANP ("efecto blindaje").
#   Añade además la pérdida bruta de vegetación primaria entre 2014 y 2018.
# ==============================================================================

# ------------------------------------------------------------------------------
# 0. Entorno, rutas y utilidades
# ------------------------------------------------------------------------------
user_lib <- file.path(Sys.getenv("USERPROFILE"), "AppData", "Local", "R", "win-library", "4.3")
if (dir.exists(user_lib) && !(user_lib %in% .libPaths())) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(patchwork)
  library(foreign)
  library(scales)
})

sf_use_s2(FALSE)

RAW_DIR   <- "data/raw/day03"
PROC_DIR  <- "data/processed"
OUT_HIGH  <- "outputs/high_res/day03_polygons_anp_presion.png"
OUT_GAL   <- "outputs/gallery/day03_polygons_anp_presion.png"

for (d in c(RAW_DIR, PROC_DIR, "outputs/high_res", "outputs/gallery")) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

msg <- function(...) message(format(Sys.time(), "[%H:%M:%S] "), ...)

# ------------------------------------------------------------------------------
# 1. Descarga con caché de las capas de CONABIO
# ------------------------------------------------------------------------------
layers <- list(
  list(code = "anpjul2025gw", label = "ANP federales (CONANP, jul 2025)", type = "shp"),
  list(code = "usv250s7gw",  label = "Uso de suelo INEGI Serie VII (2018)", type = "shp"),
  list(code = "usv250s6gw",  label = "Uso de suelo INEGI Serie VI (2014)",  type = "shp")
)

descargar <- function(code) {
  dir_dst <- file.path(RAW_DIR, if (code == "anpjul2025gw") "anp" else code)
  shp <- file.path(dir_dst, paste0(code, ".shp"))
  if (file.exists(shp)) return(shp)

  zip_path <- file.path(RAW_DIR, paste0(code, ".zip"))
  if (!file.exists(zip_path)) {
    url <- paste0("http://www.conabio.gob.mx/informacion/gis/maps/geo/", code, ".zip")
    msg("Descargando ", code, " ...")
    download.file(url, zip_path, mode = "wb", quiet = TRUE)
  }
  msg("Extrayendo ", code, " ...")
  utils::unzip(zip_path, exdir = dir_dst, junkpaths = TRUE)
  shp
}

shp_anp <- descargar("anpjul2025gw")
shp_s7  <- descargar("usv250s7gw")
shp_s6  <- descargar("usv250s6gw")

# ------------------------------------------------------------------------------
# 2. Macro-clases de uso de suelo (por descripción, no por código numérico:
#    la Serie VII usa códigos compuestos de 11 dígitos)
# ------------------------------------------------------------------------------
clasificar <- function(des) {
  d <- toupper(trimws(des))
  out <- rep(NA_character_, length(d))
  out[grepl("^VEGETACI[OÓ]N SECUNDARIA", d)] <- "secundaria"
  out[is.na(out) & grepl("^AGRICULTURA", d)] <- "antropico"
  out[is.na(out) & grepl("^PASTIZAL (INDUCIDO|CULTIVADO)", d)] <- "antropico"
  out[is.na(out) & grepl("^(ASENTAMIENTOS HUMANOS|URBANO CONSTRUIDO)", d)] <- "antropico"
  out[is.na(out) & grepl("^(BOSQUE|PALMAR) (CULTIVADO|INDUCIDO)", d)] <- "antropico"
  out[is.na(out) & grepl("^ACU[IÍ]COLA", d)] <- "antropico"
  out[is.na(out) & grepl("^(AGUA|CUERPO DE AGUA)$", d)] <- "agua"
  out[is.na(out) & grepl("^([AÁ]REA DESPROVISTA|DESPROVIST|SIN VEGETACI[OÓ]N APARENTE)", d)] <- "sin_vegetacion"
  out[is.na(out)] <- "primaria"
  out
}

CLASES <- c(primaria = 1L, secundaria = 2L, antropico = 3L, agua = 4L, sin_vegetacion = 5L)

# ------------------------------------------------------------------------------
# 3. Rasterización de ambas series a 0.0025° (~250 m)
# ------------------------------------------------------------------------------
mx_states <- st_read("data/raw/day01/mexico_states.geojson", quiet = TRUE) %>%
  st_make_valid()
mx_union <- st_union(mx_states)

rasterizar_serie <- function(code, shp) {
  tif <- file.path(PROC_DIR, paste0("day03_", code, "_clases.tif"))
  if (file.exists(tif)) return(rast(tif))

  msg("Rasterizando ", code, " (puede tardar varios minutos) ...")
  plantilla <- rast(ext(mx_states), resolution = 0.0025, crs = "EPSG:4326")
  dbf <- read.dbf(file.path(RAW_DIR, code, paste0(code, ".dbf")), as.is = TRUE)
  v <- vect(shp)
  cls_num <- unname(CLASES[clasificar(dbf$DESCRIPCIO)])
  if (length(cls_num) != nrow(v)) {
    stop("El numero de registros del .dbf no coincide con el del .shp en ", code)
  }
  v$cod <- cls_num
  r <- rasterize(v, plantilla, field = "cod", touches = FALSE)
  writeRaster(r, tif, overwrite = TRUE, datatype = "INT1U")
  r
}

r7 <- rasterizar_serie("usv250s7gw", shp_s7)
r6 <- rasterizar_serie("usv250s6gw", shp_s6)

# ------------------------------------------------------------------------------
# 4. Estadísticas zonales por ANP y por anillo de 10 km
# ------------------------------------------------------------------------------
anp <- st_read(shp_anp, quiet = TRUE) %>% st_make_valid()

archivo_indice <- file.path(PROC_DIR, "day03_anp_indice.rds")
archivo_e_anp  <- file.path(PROC_DIR, "day03_extract_anp.rds")
archivo_e_ring <- file.path(PROC_DIR, "day03_extract_ring.rds")

if (file.exists(archivo_indice)) {
  dat <- readRDS(archivo_indice)
  msg("Índice de presión cargado desde caché")
} else {
  anp_t <- anp[anp$S_TERRES > 0, ]
  anp_t$id <- seq_len(nrow(anp_t))

  if (file.exists(archivo_e_anp) && file.exists(archivo_e_ring)) {
    msg("Cargando extracciones zonales desde caché")
    e_anp  <- readRDS(archivo_e_anp)
    e_ring <- readRDS(archivo_e_ring)
  } else {
    anp_m   <- st_transform(anp_t, 6372)
    union_m <- st_union(anp_m)

    msg("Construyendo anillos de 10 km ...")
    ring_m <- st_difference(st_buffer(anp_m, 10000), union_m)

    anp_sf  <- st_transform(anp_m, 4326)
    ring_sf <- st_transform(ring_m, 4326)

    cs <- cellSize(r7, unit = "km")
    stack_lu <- c(r6, r7)
    names(stack_lu) <- c("s6", "s7")

    extraer <- function(polys, etiqueta, chunk = 6) {
      res <- list()
      grupos <- split(seq_len(nrow(polys)), ceiling(seq_len(nrow(polys)) / chunk))
      for (k in seq_along(grupos)) {
        ii <- grupos[[k]]
        e <- extract(stack_lu, vect(polys[ii, ]), weights = TRUE, cells = TRUE, na.rm = TRUE)
        if (nrow(e) == 0) next
        # extract devuelve el ID local al lote: se remapea al ID global
        e$ID <- ii[e$ID]
        e$area_km2 <- e$weight * cs[e$cell][, 1]
        res[[k]] <- e[, c("ID", "s6", "s7", "area_km2")]
        if (k %% 5 == 0) msg("  ", etiqueta, ": ", k, "/", length(grupos))
      }
      bind_rows(res)
    }

    msg("Estadísticas dentro de las ANP ...")
    e_anp <- extraer(anp_sf, "ANP")
    saveRDS(e_anp, archivo_e_anp)

    msg("Estadísticas en los anillos ...")
    e_ring <- extraer(ring_sf, "ANILLO", chunk = 3)
    saveRDS(e_ring, archivo_e_ring)
  }

  resumir <- function(e, prefijo) {
    d <- e %>%
      mutate(
        # Ojo: s7 tiene NA donde esa serie no tiene dato; ifelse propagaria el NA
        primaria   = ifelse(!is.na(s7) & s7 == 1, area_km2, 0),
        secundaria = ifelse(!is.na(s7) & s7 == 2, area_km2, 0),
        antropico  = ifelse(!is.na(s7) & s7 == 3, area_km2, 0),
        agua       = ifelse(!is.na(s7) & s7 == 4, area_km2, 0),
        sinveg     = ifelse(!is.na(s7) & s7 == 5, area_km2, 0)
      ) %>%
      group_by(ID) %>%
      summarise(across(primaria:sinveg, sum), .groups = "drop")
    names(d)[-1] <- paste0(prefijo, "_", names(d)[-1])
    d
  }

  # Pérdida bruta de vegetación primaria 2014 -> 2018 (solo dentro de la ANP)
  perdida <- e_anp %>%
    mutate(
      prim14 = ifelse(!is.na(s6) & s6 == 1, area_km2, 0),
      perd   = ifelse(!is.na(s6) & !is.na(s7) & s6 == 1 & s7 != 1, area_km2, 0)
    ) %>%
    group_by(ID) %>%
    summarise(prim14 = sum(prim14), perd = sum(perd), .groups = "drop") %>%
    mutate(perd_pct = 100 * perd / ifelse(prim14 > 0, prim14, NA))

  dat <- anp_t %>%
    st_drop_geometry() %>%
    mutate(ID = id) %>%
    left_join(resumir(e_anp, "anp"), by = "ID") %>%
    left_join(resumir(e_ring, "ring"), by = "ID") %>%
    left_join(perdida, by = "ID") %>%
    mutate(
      tierra_anp  = anp_primaria + anp_secundaria + anp_antropico,
      tierra_ring = ring_primaria + ring_secundaria + ring_antropico,
      pct_primaria   = 100 * anp_primaria / tierra_anp,
      pct_secundaria = 100 * anp_secundaria / tierra_anp,
      pct_antropico  = 100 * anp_antropico / tierra_anp,
      ipa      = 100 * (anp_antropico + 0.5 * anp_secundaria) / tierra_anp,
      ipa_ring = 100 * (ring_antropico + 0.5 * ring_secundaria) / tierra_ring,
      blindaje = ipa_ring / ipa
    )

  saveRDS(dat, archivo_indice)
  msg("Índice de presión calculado y guardado")
}

# ------------------------------------------------------------------------------
# 5. Preparación de capas para el mapa
# ------------------------------------------------------------------------------
# ANP recortadas al territorio continental/insular para el mapa nacional
anp_mapa <- anp %>%
  filter(S_TERRES > 0) %>%
  st_intersection(mx_union) %>%
  left_join(dat %>% select(NOMBRE, CAT_MANEJO, ipa, ipa_ring, blindaje, tierra_anp, perd_pct),
            by = c("NOMBRE", "CAT_MANEJO"))

anp_mapa$ipa_cls <- cut(
  anp_mapa$ipa,
  breaks = c(-Inf, 10, 25, 50, 75, Inf),
  labels = c("0 – 10", "10 – 25", "25 – 50", "50 – 75", "75 – 100")
)

# ------------------------------------------------------------------------------
# 6. Paleta y tema (Estilo Atlas Enmarcado)
# ------------------------------------------------------------------------------
bg_dark   <- "#F7F4EB"
bg_ocean  <- "#DCE6F2"
bg_panel  <- "#24344D"
txt_main  <- "#0f172a"
txt_sub   <- "#334155"
land_fill <- "#24344D"
land_line <- "#435B7D"

col_ipa <- c(
  "0 – 10"   = "#10b981",
  "10 – 25"  = "#a3e635",
  "25 – 50"  = "#facc15",
  "50 – 75"  = "#f97316",
  "75 – 100" = "#ef4444"
)

col_lu <- c(
  primaria       = "#166534",
  secundaria     = "#a16207",
  antropico      = "#991b1b",
  agua           = "#1d4ed8",
  sin_vegetacion = "#475569"
)

tema_panel <- function() {
  theme_void(base_size = 10) +
    theme(
      plot.background  = element_rect(fill = bg_dark, color = NA),
      panel.background = element_rect(fill = bg_dark, color = NA),
      plot.margin      = margin(4, 4, 4, 4)
    )
}

# ------------------------------------------------------------------------------
# 7. Panel A — mapa nacional
# ------------------------------------------------------------------------------
hitos <- c("Mariposa Monarca", "Calakmul", "Sierra Gorda", "El Vizcaíno")
lab <- anp_mapa %>%
  filter(NOMBRE %in% hitos) %>%
  st_point_on_surface() %>%
  st_coordinates() %>%
  as.data.frame() %>%
  bind_cols(anp_mapa %>% filter(NOMBRE %in% hitos) %>% st_drop_geometry() %>% select(NOMBRE))

pA <- ggplot() +
  geom_sf(data = mx_states, fill = land_fill, color = land_line, linewidth = 0.25) +
  geom_sf(data = anp_mapa, aes(fill = ipa_cls), color = "#162235", linewidth = 0.14) +
  geom_sf(data = anp_mapa %>% filter(ipa > 75), fill = NA, color = "#fecaca", linewidth = 0.35) +
  geom_text(
    data = lab, aes(x = X, y = Y, label = NOMBRE),
    color = "#f8fafc", size = 2.7, fontface = "bold", vjust = -0.8,
    check_overlap = TRUE
  ) +
  scale_fill_manual(
    values = col_ipa, name = "ÍNDICE DE PRESIÓN\nANTRÓPICA (0–100)",
    na.value = "#475569",
    na.translate = FALSE,
    guide = guide_legend(override.aes = list(color = "#162235", linewidth = 0.2))
  ) +
  coord_sf(xlim = c(-118.2, -86.3), ylim = c(14.2, 32.9), expand = FALSE) +
  labs(title = "A. El escudo verde: 223 ANP federales de México") +
  theme_void(base_size = 10) +
  theme(
    plot.background   = element_rect(fill = bg_dark, color = NA),
    panel.background  = element_rect(fill = bg_ocean, color = "#94a3b8", linewidth = 0.6),
    plot.title        = element_text(color = txt_main, face = "bold", size = 11.5,
                                     margin = margin(b = 5)),
    legend.position   = c(0.02, 0.06),
    legend.justification = c(0, 0),
    legend.direction  = "vertical",
    legend.background = element_rect(fill = alpha(bg_dark, 0.94), color = "#94a3b8", linewidth = 0.4),
    legend.margin     = margin(6, 8, 6, 8),
    legend.title      = element_text(color = txt_main, size = 7.2, face = "bold"),
    legend.text       = element_text(color = txt_sub, size = 7),
    legend.key.size   = unit(0.3, "cm"),
    legend.key.width  = unit(0.55, "cm"),
    legend.spacing.y  = unit(0.06, "cm"),
    plot.margin       = margin(6, 8, 4, 8)
  )

# ------------------------------------------------------------------------------
# 8. Panel B — efecto blindaje
# ------------------------------------------------------------------------------
dat_b <- dat %>%
  filter(is.finite(ipa), is.finite(ipa_ring)) %>%
  mutate(ipa_cls = cut(
    ipa,
    breaks = c(-Inf, 10, 25, 50, 75, Inf),
    labels = c("0 – 10", "10 – 25", "25 – 50", "50 – 75", "75 – 100")
  ))

pB <- ggplot(dat_b, aes(x = ipa, y = ipa_ring)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed",
              color = "#94a3b8", linewidth = 0.45) +
  geom_point(aes(color = ipa_cls, size = tierra_anp), alpha = 0.88, stroke = 0) +
  scale_color_manual(values = col_ipa, guide = "none") +
  scale_size_area(max_size = 6, guide = "none") +
  annotate("text", x = 8, y = 92, label = "ANP blindadas",
           color = "#4ade80", size = 2.9, hjust = 0, fontface = "bold") +
  annotate("text", x = 72, y = 18, label = "ANP ahogadas",
           color = "#fb7185", size = 2.9, hjust = 0, fontface = "bold") +
  labs(
    title = "B. ¿Escudo o isla?",
    subtitle = "Presión dentro de la ANP vs. en su anillo de 10 km",
    x = "IPA dentro de la ANP", y = "IPA en el anillo de 10 km"
  ) +
  coord_cartesian(xlim = c(0, 100), ylim = c(0, 100)) +
  theme_minimal(base_size = 8) +
  theme(
    plot.background  = element_rect(fill = bg_dark, color = NA),
    panel.background = element_rect(fill = bg_panel, color = "#94a3b8", linewidth = 0.5),
    panel.grid       = element_line(color = "#364B6B", linewidth = 0.25),
    plot.title       = element_text(color = txt_main, face = "bold", size = 10),
    plot.subtitle    = element_text(color = txt_sub, size = 7.4, margin = margin(b = 4)),
    axis.title       = element_text(color = txt_sub, size = 7.2),
    axis.text        = element_text(color = "#475569", size = 6.6),
    plot.margin      = margin(6, 8, 6, 6)
  )

# ------------------------------------------------------------------------------
# 9. Panel C — tres acercamientos (mosaico de uso de suelo)
# ------------------------------------------------------------------------------
etiquetas_lu <- c("primaria" = "Vegetación primaria", "secundaria" = "Vegetación secundaria",
                  "antropico" = "Antrópico", "agua" = "Agua", "sin_vegetacion" = "Sin vegetación")

hacer_inset <- function(nombre_anp, titulo) {
  feat <- anp_mapa %>% filter(NOMBRE == nombre_anp)
  if (nrow(feat) == 0) return(NULL)
  ext_i <- ext(vect(st_buffer(st_transform(feat, 6372), 6000) %>% st_transform(4326)))

  rc <- crop(r7, ext_i)
  df <- as.data.frame(rc, xy = TRUE)
  names(df)[3] <- "clase"
  df$clase <- factor(names(CLASES)[as.integer(df$clase)], levels = names(CLASES))

  ggplot() +
    geom_raster(data = df, aes(x = x, y = y, fill = clase)) +
    geom_sf(data = feat, fill = NA, color = "#f8fafc", linewidth = 0.75) +
    scale_fill_manual(values = col_lu, labels = etiquetas_lu, name = NULL) +
    labs(title = titulo) +
    theme_void(base_size = 8) +
    theme(
      plot.background  = element_rect(fill = bg_dark, color = NA),
      plot.title       = element_text(color = txt_main, face = "bold", size = 8.4,
                                      margin = margin(b = 2)),
      legend.position  = "bottom",
      legend.direction = "horizontal",
      legend.text      = element_text(color = txt_sub, size = 5.8),
      legend.key.size  = unit(0.28, "cm"),
      aspect.ratio     = 0.82,
      plot.margin      = margin(5, 5, 5, 5)
    )
}

pC1 <- hacer_inset("Mariposa Monarca", "C1. Mariposa Monarca")
pC2 <- hacer_inset("Calakmul", "C2. Calakmul")
pC3 <- hacer_inset("Sierra Gorda", "C3. Sierra Gorda")

pC <- (pC1 | pC2 | pC3) +
  plot_layout(guides = "collect") +
  plot_annotation(
    title = "C. El mosaico alrededor del escudo (uso de suelo 2018)",
    theme = theme(
      plot.background = element_rect(fill = bg_dark, color = NA),
      plot.title = element_text(color = txt_main, face = "bold", size = 10,
                                margin = margin(4, 0, 2, 0)),
      legend.position = "bottom",
      legend.text = element_text(color = txt_sub, size = 6)
    )
  )

# ------------------------------------------------------------------------------
# 10. Panel D — ranking
# ------------------------------------------------------------------------------
top_d <- dat_b %>%
  filter(tierra_anp >= 50) %>%      # excluye parques urbanos minimos
  arrange(desc(ipa)) %>%
  slice_head(n = 10) %>%
  mutate(NOMBRE = substr(NOMBRE, 1, 30))

pD <- ggplot(top_d, aes(x = ipa, y = reorder(NOMBRE, ipa))) +
  geom_col(aes(fill = ipa_cls), width = 0.72) +
  geom_text(aes(label = sprintf("%.0f", ipa)), hjust = -0.25,
            color = "#e2e8f0", size = 2.6) +
  scale_fill_manual(values = col_ipa, guide = "none") +
  scale_x_continuous(limits = c(0, 108)) +
  labs(title = "D. Las ANP más presionadas", subtitle = "Solo ANP con al menos 50 km² de superficie terrestre",
       x = "IPA", y = NULL) +
  theme_minimal(base_size = 8) +
  theme(
    plot.background  = element_rect(fill = bg_dark, color = NA),
    panel.background = element_rect(fill = bg_panel, color = "#94a3b8", linewidth = 0.5),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = "#364B6B", linewidth = 0.25),
    plot.title       = element_text(color = txt_main, face = "bold", size = 10),
    plot.subtitle    = element_text(color = txt_sub, size = 7.2, margin = margin(b = 3)),
    axis.text.y      = element_text(color = txt_sub, size = 6.5),
    axis.text.x      = element_text(color = "#475569", size = 6.5),
    axis.title.x     = element_text(color = txt_sub, size = 7.2),
    plot.margin      = margin(6, 8, 6, 6)
  )

# ------------------------------------------------------------------------------
# 11. Composición del póster
# ------------------------------------------------------------------------------
n_blindadas <- sum(dat_b$blindaje > 1.5, na.rm = TRUE)
mediana_ipa <- round(median(dat_b$ipa, na.rm = TRUE), 1)
sup_nacional_mha <- round(sum(dat$S_TERRES, na.rm = TRUE) / 1e6, 1)
n_anp <- nrow(dat)

col_der <- (pB | pC | pD) + plot_layout(widths = c(1, 1.45, 1))

poster <- (pA / col_der) +
  plot_layout(heights = c(1.62, 1)) +
  plot_annotation(
    title = "EL ESCUDO VERDE DE MÉXICO",
    subtitle = paste0(
      "Las ", n_anp, " Áreas Naturales Protegidas federales con superficie terrestre cubren ",
      sup_nacional_mha, " millones de hectáreas.\n",
      "Coloreadas por su Índice de Presión Antrópica (IPA): la mediana nacional es ", mediana_ipa,
      " y ", n_blindadas, " ANP soportan una presión al menos 50% mayor en su entorno que dentro de sus límites."
    ),
    caption = paste0(
      "#30DayMapChallenge 2026  |  Día 03: Polygons\n",
      "Datos: CONANP — Áreas Naturales Protegidas Federales (julio 2025); INEGI — Uso del Suelo y Vegetación, Series VI (2014) y VII (2018); ambos vía CONABIO.\n",
      "IPA = 100 × (antrópico + 0.5 × vegetación secundaria) / superficie terrestre con dato. Se excluyen 9 ANP exclusivamente marinas.\n",
      "Visualización: Fernando Dorantes Nieto (@FerDoranNie)  |  Herramientas: R (sf, terra, ggplot2, patchwork)"
    ),
    theme = theme(
      plot.background = element_rect(fill = bg_dark, color = NA),
      plot.title = element_text(color = txt_main, face = "bold", size = 21,
                                hjust = 0.5, margin = margin(t = 12, b = 4)),
      plot.subtitle = element_text(color = txt_sub, size = 9.2, hjust = 0.5,
                                   lineheight = 1.25, margin = margin(b = 8)),
      plot.caption = element_text(color = "#475569", size = 7.2, hjust = 0.5,
                                  lineheight = 1.35, margin = margin(t = 8, b = 6)),
      plot.margin = margin(8, 12, 8, 12)
    )
  )

# ------------------------------------------------------------------------------
# 12. Exportación
# ------------------------------------------------------------------------------
W <- 16
H <- 14.5

ggsave(OUT_HIGH, poster, width = W, height = H, dpi = 300, bg = bg_dark)
ggsave(OUT_GAL, poster, width = W, height = H, dpi = 140, bg = bg_dark)

msg("Mapa del Día 03 generado:")
msg(" - Alta resolución: ", OUT_HIGH)
msg(" - Galería:         ", OUT_GAL)
