# =============================================================================
# Día 13 — Interactions | Póster estático
# Red global de comercio de vida silvestre (CITES): fauna silvestre 2015-2024
# -----------------------------------------------------------------------------
# Panel A: mapa global de arcos Exporter -> Importer (Robinson, Atlántico)
# Panel B: matriz exportadores x importadores (fauna) + nota sobre flora
# Panel C: México en la red (top especies importadas / exportadas)
#
# Uso:  Rscript day13_poster.R            -> alta resolución + galería
#       DAY13_RES=gallery Rscript ...     -> sólo galería (iteración rápida)
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(sf)
  library(ggplot2)
  library(patchwork)
  library(ragg)
})

raiz <- normalizePath(file.path("..", ".."), mustWork = FALSE)
source(file.path(raiz, "utils", "theme_map2026.R"))

dir_proc <- file.path(raiz, "data", "processed")
dir_hi   <- file.path(raiz, "outputs", "high_res")
dir_gal  <- file.path(raiz, "outputs", "gallery")
dir.create(dir_hi,  showWarnings = FALSE, recursive = TRUE)
dir.create(dir_gal, showWarnings = FALSE, recursive = TRUE)

# --- Paleta y utilidades compartidas ----------------------------------------
source(file.path(raiz, "utils", "arcos_cites.R"))

# --- Datos -------------------------------------------------------------------
red <- readRDS(file.path(dir_proc, "day13_cites_network.rds"))
fl  <- red$flujos
det <- readRDS(file.path(dir_proc, "day13_detalle_taxon.rds"))

fauna <- fl[reexportacion == FALSE & grupo_fuente == "Silvestre" & grupo != "Plantas"]

# Tipo de flujo dominante por arista (vivo vs piel/trofeo)
por_termino <- fauna[, .(vol = sum(volumen)), by = .(Exporter, Importer, Term)]
por_termino[, clase := fifelse(Term == "live", "Vivo", "Piel o trofeo")]
tipo_arista <- por_termino[, .(vol = sum(vol)), by = .(Exporter, Importer, clase)]
setorder(tipo_arista, Exporter, Importer, -vol)
tipo_arista <- tipo_arista[, .SD[1], by = .(Exporter, Importer)][, .(Exporter, Importer, tipo = clase)]

aristas <- fauna[, .(volumen = sum(volumen), n_anios = uniqueN(Year)),
                 by = .(Exporter, Importer)]
aristas <- merge(aristas, tipo_arista, by = c("Exporter", "Importer"))

grupo_arista <- fauna[, .(vol = sum(volumen)), by = .(Exporter, Importer, grupo)]
setorder(grupo_arista, Exporter, Importer, -vol)
grupo_arista <- grupo_arista[, .SD[1], by = .(Exporter, Importer)]
aristas <- merge(aristas, grupo_arista[, .(Exporter, Importer, grupo)],
                 by = c("Exporter", "Importer"))

N_TOP <- 80
top <- aristas[order(-volumen)][1:N_TOP]
mx  <- aristas[Exporter == "MX" | Importer == "MX"]
mapa_aristas <- unique(rbind(top, mx, fill = TRUE))
setorder(mapa_aristas, -volumen)

cat("Aristas dibujadas:", nrow(mapa_aristas), "| volumen cubierto:",
    round(100 * sum(mapa_aristas$volumen) / sum(aristas$volumen), 1), "%\n")

# --- Países ------------------------------------------------------------------
mundo <- st_read(file.path(raiz, "data", "raw", "day04", "ne_50m_admin_0_countries.geojson"),
                 quiet = TRUE)
mundo <- mundo[mundo$CONTINENT != "Antarctica", ]
mundo <- st_break_antimeridian(mundo, lon_0 = 0)
mundo_ll <- st_transform(mundo, 4326)

llaves <- as.data.table(st_drop_geometry(mundo_ll))[, .(ISO_A2_EH, NAME_ES, CONTINENT)]
llaves <- unique(llaves[!is.na(ISO_A2_EH) & ISO_A2_EH != "-99"], by = "ISO_A2_EH")
extra <- data.table(
  ISO_A2_EH = c("AN", "BQ", "GF", "GP", "HS", "KV", "MQ", "RE", "SJ", "TK",
                "UM", "TW", "MO", "XV", "XX"),
  NAME_ES   = c("Antillas Neerlandesas", "Bonaire", "Guayana Francesa", "Guadalupe",
                "Sudán del Sur", "Kosovo", "Martinica", "Reunión", "Svalbard",
                "Tokelau", "Islas menores de EE.UU.", "Taiwán", "Macao",
                "Diversos", "No declarado"),
  CONTINENT = "—")
llaves <- unique(rbind(llaves, extra, use.names = TRUE), by = "ISO_A2_EH")
nombre_de <- function(x) { n <- llaves$NAME_ES[match(x, llaves$ISO_A2_EH)]; fifelse(is.na(n), x, n) }

centros <- st_point_on_surface(mundo_ll)
centros <- as.data.table(st_coordinates(centros))[, .(lon = X, lat = Y)]
centros[, ISO_A2_EH := mundo_ll$ISO_A2_EH]
centros <- centros[!is.na(ISO_A2_EH)]
centros <- centros[!duplicated(ISO_A2_EH)]
centros <- merge(centros, llaves, by = "ISO_A2_EH", all.x = TRUE)

faltan <- setdiff(unique(c(mapa_aristas$Exporter, mapa_aristas$Importer)), centros$ISO_A2_EH)
if (length(faltan)) cat("Sin centroide:", paste(faltan, collapse = ", "), "\n")

partes <- vector("list", nrow(mapa_aristas))
for (i in seq_len(nrow(mapa_aristas))) {
  a <- centros[ISO_A2_EH == mapa_aristas$Exporter[i]]
  b <- centros[ISO_A2_EH == mapa_aristas$Importer[i]]
  if (!nrow(a) || !nrow(b)) next
  partes[[i]] <- trozos_arco(a$lon[1], a$lat[1], b$lon[1], b$lat[1])
}
ok <- !vapply(partes, is.null, logical(1))
arco_geom <- st_sf(mapa_aristas[ok, ], geometry = st_sfc(partes[ok], crs = 4326))
cat("Arcos con geometría:", nrow(arco_geom), "\n")

proj <- "+proj=robin +lon_0=0 +datum=WGS84 +units=m +no_defs"
mundo_p <- st_transform(mundo, proj)
arco_geom <- arco_geom[order(arco_geom$volumen), ]
arco_p  <- st_transform(arco_geom, proj)

# --- Nodos -------------------------------------------------------------------
nodos <- rbind(
  data.table(ISO_A2_EH = mapa_aristas$Exporter, vol = mapa_aristas$volumen, rol = "exp"),
  data.table(ISO_A2_EH = mapa_aristas$Importer, vol = mapa_aristas$volumen, rol = "imp"))
nodos <- nodos[, .(exp = sum(vol[rol == "exp"]), imp = sum(vol[rol == "imp"])), by = ISO_A2_EH]
nodos[, total := exp + imp][, balance := exp - imp]
nodos <- merge(nodos, centros[, .(ISO_A2_EH, lon, lat, NAME_ES)], by = "ISO_A2_EH")
nodos_sf <- st_as_sf(nodos, coords = c("lon", "lat"), crs = 4326) |> st_transform(proj)

etq <- centros[ISO_A2_EH %in% c("US", "MX", "ID", "AU"), .(ISO_A2_EH, lon, lat, NAME_ES)]
etq[, `:=`(lon = lon + c(US = -8, MX = -10, ID = 0, AU = 0)[ISO_A2_EH],
           lat = lat + c(US = 6, MX = -2, ID = 6, AU = 6)[ISO_A2_EH])]
etq <- rbind(etq[, .(texto = NAME_ES, lon, lat)],
             data.table(texto = "Europa importadora", lon = 18, lat = 63))
etiquetas_sf <- st_transform(st_as_sf(etq, coords = c("lon", "lat"), crs = 4326), proj)

if (nzchar(Sys.getenv("DAY13_DEBUG"))) {
  saveRDS(list(arco = arco_p, mundo = mundo_p, nodos = nodos_sf),
          file.path(dir_proc, "day13_debug_geo.rds"))
}

# --- Panel A -----------------------------------------------------------------
pA <- ggplot() +
  geom_sf(data = mundo_p, fill = COL$tierra, color = COL$frontera, linewidth = 0.1) +
  geom_sf(data = arco_p, aes(color = grupo, linetype = tipo, linewidth = volumen,
                             alpha = volumen), lineend = "round") +
  geom_sf(data = nodos_sf, aes(size = total, fill = balance > 0), shape = 21,
          color = COL$papel, stroke = 0.4, alpha = 0.95) +
  geom_sf_label(data = etiquetas_sf, aes(label = texto), size = 2.3,
                color = COL$tinta, fill = alpha(COL$papel, 0.88), label.size = 0,
                label.padding = unit(0.13, "lines"), fontface = "bold",
                show.legend = FALSE) +
  scale_color_manual(values = unlist(COL[names(ETIQUETA)]), labels = ETIQUETA, name = NULL) +
  scale_linetype_manual(values = c("Vivo" = "solid", "Piel o trofeo" = "dashed"), name = NULL) +
  scale_linewidth_continuous(range = c(0.14, 2.0), trans = "sqrt", guide = "none") +
  scale_alpha_continuous(range = c(0.25, 0.9), trans = "sqrt", guide = "none") +
  scale_size_continuous(range = c(0.6, 6.5), trans = "sqrt",
                        breaks = c(1e5, 1e6, 5e6),
                        labels = c("100 mil", "1 millón", "5 millones"),
                        name = NULL) +
  scale_fill_manual(values = c(`TRUE` = "#F8FAFC", `FALSE` = "#F59E0B"),
                    labels = c(`TRUE` = "Exportador neto", `FALSE` = "Importador neto"),
                    name = NULL) +
  guides(color    = guide_legend(order = 1, nrow = 1,
                                 override.aes = list(linewidth = 0.9, alpha = 1)),
         linetype = guide_legend(order = 2, nrow = 1,
                                 override.aes = list(linewidth = 0.9, alpha = 1)),
         fill     = guide_legend(order = 3, nrow = 1,
                                 override.aes = list(size = 2.6)),
         size     = guide_legend(order = 4, nrow = 1,
                                 override.aes = list(fill = "#94A3B8"))) +
  labs(title = "El comercio mundial de vida silvestre, 2015–2024",
       subtitle = "El arco nace en el país exportador y termina en el importador; el grosor es volumen y el trazo discontinuo, pieles y trofeos") +
  theme_map2026(base_size = 10) +
  theme(legend.position = "bottom",
        legend.box = "horizontal",
        legend.box.just = "left",
        legend.key = element_blank(),
        legend.key.width = unit(0.8, "cm"),
        legend.spacing.x = unit(0.18, "cm"),
        legend.margin = margin(0, 0, 0, 6),
        panel.background = element_rect(fill = COL$oceano, color = COL$marco, linewidth = 0.6),
        plot.title = element_text(size = 19, face = "bold", color = COL$tinta),
        plot.subtitle = element_text(size = 10.5, color = COL$tinta2),
        plot.margin = margin(6, 8, 0, 8))

# --- Panel B: matriz ---------------------------------------------------------
exp10 <- fauna[, .(v = sum(volumen)), by = Exporter][order(-v)][1:10]
imp10 <- fauna[, .(v = sum(volumen)), by = Importer][order(-v)][1:10]
mat <- fauna[Exporter %in% exp10$Exporter & Importer %in% imp10$Importer,
             .(vol = sum(volumen)), by = .(Exporter, Importer)]
mat <- merge(CJ(Exporter = exp10$Exporter, Importer = imp10$Importer), mat,
             by = c("Exporter", "Importer"), all.x = TRUE)
mat[is.na(vol), vol := 0]
mat[, valor := fifelse(vol > 0, vol, NA_real_)]
mat[, nom_exp := factor(nombre_de(Exporter), levels = rev(nombre_de(exp10$Exporter)))]
mat[, nom_imp := factor(nombre_de(Importer), levels = nombre_de(imp10$Importer))]

pB <- ggplot(mat, aes(nom_imp, nom_exp, fill = valor)) +
  geom_tile(color = COL$papel, linewidth = 0.9) +
  geom_text(aes(label = ifelse(vol >= 5e4, fmt(vol / 1e3), "")),
            size = 1.9, color = COL$tinta, fontface = "bold") +
  scale_fill_gradient(low = "#E8EEF4", high = "#0F766E", trans = "log10", na.value = COL$papel,
                      labels = function(x) fmt(x), name = "Especímenes") +
  labs(title = "Quién le vende a quién",
       subtitle = "Miles de especímenes; 10 mayores exportadores (filas) e importadores (columnas)",
       x = NULL, y = NULL) +
  theme_minimal(base_size = 8) +
  theme(plot.background = element_rect(fill = COL$papel, color = NA),
        panel.grid = element_blank(),
        axis.text.x = element_text(angle = 50, hjust = 1, size = 6.6, color = COL$tinta2),
        axis.text.y = element_text(size = 6.8, color = COL$tinta2),
        plot.title = element_text(face = "bold", size = 11.5, color = COL$tinta),
        plot.subtitle = element_text(size = 7.4, color = COL$tinta3),
        legend.position = "right",
        legend.key.height = unit(0.9, "cm"),
        legend.key.width = unit(0.35, "cm"),
        legend.title = element_text(size = 6.8),
        legend.text = element_text(size = 6.2),
        plot.margin = margin(4, 2, 2, 2))

# --- Panel C: México ---------------------------------------------------------
mx_imp <- det[Source == "W" & !reexportacion & Importer == "MX" & Term != "live",
              .(vol = sum(volumen)), by = .(Exporter, Taxon)]
mx_imp <- mx_imp[order(-vol)][1:6]
mx_imp[, etiqueta := sprintf("%s\n%s", Taxon, nombre_de(Exporter))]
mx_imp[, etiqueta := factor(etiqueta, levels = rev(etiqueta))]

mx_exp <- det[Source == "W" & !reexportacion & Exporter == "MX",
              .(vol = sum(volumen)), by = .(Importer, Taxon)]
mx_exp <- mx_exp[order(-vol)][1:5]
mx_exp[, etiqueta := sprintf("%s\n→ %s", Taxon, nombre_de(Importer))]
mx_exp[, etiqueta := factor(etiqueta, levels = rev(etiqueta))]

tema_barra <- function() {
  theme_minimal(base_size = 8) +
    theme(plot.background = element_rect(fill = COL$papel, color = NA),
          panel.grid.minor = element_blank(),
          panel.grid.major.y = element_blank(),
          axis.text.y = element_text(size = 6.4, color = COL$tinta2, lineheight = 0.85),
          axis.text.x = element_text(size = 6.2, color = COL$tinta3),
          plot.title = element_text(face = "bold", size = 9.6, color = COL$tinta),
          plot.subtitle = element_text(size = 7, color = COL$tinta3),
          plot.margin = margin(3, 8, 3, 2))
}

pC1 <- ggplot(mx_imp, aes(etiqueta, vol)) +
  geom_col(fill = COL$Reptiles, width = 0.7) +
  geom_text(aes(label = fmt(vol)), hjust = -0.12, size = 2.1, color = COL$tinta2) +
  coord_flip() +
  scale_y_continuous(expand = expansion(mult = c(0, 0.22))) +
  labs(title = "México importa", subtitle = "Pieles y trofeos silvestres", x = NULL, y = NULL) +
  tema_barra()

pC2 <- ggplot(mx_exp, aes(etiqueta, vol)) +
  geom_col(fill = COL$Aves, width = 0.7) +
  geom_text(aes(label = fmt(vol)), hjust = -0.12, size = 2.1, color = COL$tinta2) +
  coord_flip() +
  scale_y_continuous(expand = expansion(mult = c(0, 0.22))) +
  labs(title = "México exporta", subtitle = "Sobre todo trofeos de caza a EE.UU.", x = NULL, y = NULL) +
  tema_barra()

# --- Ensamble ----------------------------------------------------------------
vol_fauna <- sum(fauna$volumen)
nota <- sprintf("Fauna silvestre: %s especímenes, %s rutas, %d países.",
                fmt(round(vol_fauna)), fmt(nrow(aristas)),
                uniqueN(c(aristas$Exporter, aristas$Importer)))

pie <- map_caption(13, "Interactions",
                   "CITES Trade Database v2026.1 (UNEP-WCMC), 2015–2024 · 5.5 M de registros filtrados de 29.2 M")

diseno <- (pA) /
  ((pB | (pC1 / pC2)) + plot_layout(widths = c(1.15, 1))) +
  plot_layout(heights = c(1.6, 1)) +
  plot_annotation(caption = pie,
                  theme = theme(
                    plot.background = element_rect(fill = COL$papel, color = NA),
                    plot.caption = element_text(size = 7.6, color = COL$tinta3, hjust = 0,
                                                margin = margin(4, 12, 6, 14))))

# --- Exportar ----------------------------------------------------------------
res <- Sys.getenv("DAY13_RES", "todas")
if (res %in% c("todas", "gallery")) {
  agg_png(file.path(dir_gal, "day13_interactions_cites_fauna.png"),
          width = 13, height = 10, units = "in", res = 150, background = COL$papel)
  print(diseno); dev.off()
  cat("Galería lista\n")
}
if (res %in% c("todas", "high")) {
  agg_png(file.path(dir_hi, "day13_interactions_cites_fauna.png"),
          width = 13, height = 10, units = "in", res = 300, background = COL$papel)
  print(diseno); dev.off()
  cat("Alta resolución lista\n")
}
