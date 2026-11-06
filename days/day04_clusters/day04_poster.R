# ==============================================================================
# Día 04 — Clusters: póster
# Requiere: days/day04_clusters/day04_megadiversidad.R (genera day04_dataset.rds)
# Salidas: outputs/high_res/day04_clusters_megadiversidad.png
#          outputs/gallery/day04_clusters_megadiversidad.png
# ==============================================================================
.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
suppressPackageStartupMessages({
  library(sf); library(ggplot2); library(dplyr); library(tidyr); library(patchwork)
  library(scales); library(ggrepel); library(units)
})
source("utils/theme_map2026.R")

CREAM <- "#F7F4EB"; OCEAN <- "#DCE6F2"; INK <- "#0F172A"; SLATE <- "#334155"
STONE <- "#E5E0D5"; BORDER <- "#94A3B8"; DEEP <- "#24344D"

ds <- readRDS("data/processed/day04_dataset.rds")
dat <- ds$dat; paises <- ds$paises; cob <- ds$cobertura

CL_LAB <- c(
  `1` = "Neotropical",
  `2` = "Neártico-Mesoamérica",
  `3` = "Indo-Himalayo",
  `4` = "África austral",
  `5` = "SE asiático insular",
  `6` = "Australasia, Madagascar e islas"
)
CL_COL <- c(
  "Neotropical"                      = "#B4441F",
  "Neártico-Mesoamérica"             = "#2E5E8C",
  "Indo-Himalayo"                    = "#6B4C9A",
  "África austral"                   = "#C68A1E",
  "SE asiático insular"              = "#1F7A6B",
  "Australasia, Madagascar e islas"  = "#4C6B3C"
)
dat$cluster_lab <- factor(CL_LAB[as.character(dat$cluster)], levels = unname(CL_LAB))

HOTSPOT_ES <- c(
  "Atlantic Forest"                         = "Bosque Atlántico",
  "California Floristic Province"           = "Provincia florística de California",
  "Caribbean Islands"                       = "Islas del Caribe",
  "Cerrado"                                 = "Cerrado",
  "Coastal Forests of Eastern Africa"       = "Bosques costeros de África oriental",
  "East Melanesian Islands"                 = "Melanesia oriental",
  "Eastern Afromontane"                     = "Afromontano oriental",
  "Forests of East Australia"               = "Bosques del E de Australia",
  "Guinean Forests of West Africa"          = "Bosques guineanos de África occidental",
  "Himalaya"                                = "Himalaya",
  "Horn of Africa"                          = "Cuerno de África",
  "Indo-Burma"                              = "Indo-Birmania",
  "Irano-Anatolian"                         = "Irano-Anatolia",
  "Japan"                                   = "Japón",
  "Madagascar and the Indian Ocean Islands" = "Madagascar e islas",
  "Madrean Pine-Oak Woodlands"              = "Bosques de pino-encino madreanos",
  "Maputaland-Pondoland-Albany"             = "Maputaland-Pondoland",
  "Mediterranean Basin"                     = "Cuenca del Mediterráneo",
  "Mesoamerica"                             = "Mesoamérica",
  "Mountains of Central Asia"               = "Montañas de Asia Central",
  "Mountains of Southwest China"            = "Montañas del SO de China",
  "New Caledonia"                           = "Nueva Caledonia",
  "New Zealand"                             = "Nueva Zelanda",
  "North American Coastal Plain"            = "Llanura costera norteamericana",
  "Philippines"                             = "Filipinas",
  "Polynesia-Micronesia"                    = "Polinesia-Micronesia",
  "Southwest Australia"                     = "SO de Australia",
  "Succulent Karoo"                         = "Karoo suculento",
  "Sundaland"                               = "Sondalandia",
  "Tropical Andes"                          = "Andes tropicales",
  "Tumbes-Choco-Magdalena"                  = "Tumbes-Chocó-Magdalena",
  "Wallacea"                                = "Wallacea",
  "Western Ghats and Sri Lanka"             = "Ghats occidentales y Sri Lanka",
  "Cape Floristic Region"                   = "Región florística del Cabo",
  "Chilean Winter Rainfall and Valdivian Forests" = "Bosques valdivianos",
  "Caucasus"                                = "Cáucaso"
)
dat$hotspot_es <- ifelse(dat$hotspot %in% names(HOTSPOT_ES),
                         unname(HOTSPOT_ES[dat$hotspot]),
                         dat$hotspot)

MOLL <- "+proj=moll +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
world <- st_read("data/raw/day04/ne_50m_admin_0_countries.geojson", quiet = TRUE) |>
  st_make_valid() |> select(iso3 = ISO_A3)

world_m  <- st_transform(world, MOLL)
paises_m <- st_transform(paises, MOLL)

# Fragmentos: la porción de cada hotspot dentro de un país megadiverso
frag_sf <- st_intersection(st_make_valid(ds$hotspots |> select(nombre)), paises) |>
  st_make_valid()
frag_sf$fid <- sprintf("%s|%s", frag_sf$nombre, frag_sf$iso3)
frag_sf <- frag_sf |>
  left_join(dat |> select(fid, cluster_lab, n_especies), by = "fid") |>
  filter(!is.na(cluster_lab))
frag_m <- st_transform(frag_sf, MOLL)

top_all <- dat |> filter(!is.na(n_especies)) |> slice_max(n_especies, n = 1)

# etiquetas: se sustituyen por una nota de texto para no saturar el mapamundi
top3 <- dat |> filter(!is.na(n_especies)) |> slice_max(n_especies, n = 3)
nota_mapa <- paste0(
  "Fragmentos más ricos:\n",
  paste(sprintf("%s (%s) · %s esp.", top3$hotspot_es, top3$pais_es,
                comma(top3$n_especies, big.mark = " ")),
        collapse = "\n")
)
nota_xy <- data.frame(X = -1.73e7, Y = -4.6e6)

# ============================== A. mapa mundial ===============================
pA <- ggplot() +
  geom_sf(data = world_m, fill = STONE, color = "#CBC4B2", linewidth = 0.1) +
  geom_sf(data = paises_m, fill = "#DFD8C8", color = DEEP, linewidth = 0.28) +
  geom_sf(data = frag_m, aes(fill = cluster_lab), color = "#162235",
          linewidth = 0.18, alpha = 0.93) +
  annotate("label", x = nota_xy$X, y = nota_xy$Y, label = nota_mapa,
           hjust = 0, vjust = 0, size = 2.35, color = INK, fontface = "italic",
           fill = alpha(CREAM, 0.90), label.size = 0, label.padding = unit(0.28, "lines"),
           lineheight = 1.05) +
  scale_fill_manual(values = CL_COL, name = "Clúster biogeográfico") +
  coord_sf(crs = MOLL, ylim = c(-5.4e6, 7.6e6), expand = FALSE) +
  theme_map2026(base_size = 11) +
  theme(
    panel.background = element_rect(fill = OCEAN, color = BORDER, linewidth = 0.6),
    legend.position = "bottom",
    legend.text = element_text(size = 8.2),
    legend.key.size = unit(0.36, "cm"),
    legend.spacing.x = unit(0.10, "cm"),
    axis.text = element_blank(), axis.title = element_blank()
  ) +
  guides(fill = guide_legend(nrow = 3, byrow = TRUE,
                             override.aes = list(color = "#162235", linewidth = 0.2))) +
  labs(
    title = "Clústeres de la megadiversidad",
    subtitle = paste0(
      "La avifauna agrupa los fragmentos de regiones prioritarias de los 17 países\n",
      "megadiversos en seis clústeres biogeográficos"
    )
  )

# ====================== B. riqueza vs superficie ==============================
d_b <- dat |> filter(!is.na(n_especies), n_especies > 0)
r2 <- cor(log10(d_b$area_frag_km2), log10(d_b$n_especies))^2
pB <- ggplot(d_b, aes(area_frag_km2, n_especies)) +
  geom_smooth(method = "lm", formula = y ~ x, se = FALSE, color = SLATE,
              linetype = "22", linewidth = 0.45) +
  geom_point(aes(fill = cluster_lab), shape = 21, size = 2.8, color = "#162235",
             stroke = 0.3, alpha = 0.93) +
  geom_text_repel(data = d_b |> slice_max(n_especies, n = 3),
                  aes(label = sprintf("%s (%s)", hotspot_es, pais_es)),
                  size = 2.2, color = INK, fontface = "italic",
                  min.segment.length = 0, segment.size = 0.2, segment.color = SLATE,
                  box.padding = 0.3, max.overlaps = 20, nudge_y = 0.14) +
  scale_x_log10(breaks = c(1e4, 1e5, 1e6),
                labels = c("10 mil", "100 mil", "1 millón")) +
  scale_y_log10(breaks = c(250, 500, 1000, 2000),
                labels = c("250", "500", "1 000", "2 000")) +
  scale_fill_manual(values = CL_COL, guide = "none") +
  annotation_logticks(sides = "lb", size = 0.22, color = SLATE) +
  labs(
    x = "Superficie del fragmento (km², escala log)",
    y = "Especies de aves (escala log)",
    title = "La riqueza no es sólo tamaño",
    subtitle = sprintf("Un punto por fragmento · R² = %s (log-log)",
                       sub("\\.", ",", sprintf("%.2f", r2)))
  ) +
  theme_map2026(base_size = 9.5) +
  theme(
    panel.background = element_rect(fill = "#FBF9F3", color = BORDER, linewidth = 0.5),
    legend.position = "none",
    plot.title = element_text(size = 15),
    plot.subtitle = element_text(size = 8.8, margin = margin(b = 8)),
    axis.text = element_text(size = 7.6),
    axis.title = element_text(size = 8.2),
    panel.grid.major = element_line(color = "#E7E1D2", linewidth = 0.25),
    plot.margin = margin(8, 14, 6, 12)
  )

# ================== C. territorio dentro de hotspots =========================
cob2 <- cob |>
  left_join(dat |> filter(!is.na(cluster)) |>
              group_by(iso3) |> slice_max(n_especies, n = 1, with_ties = FALSE) |>
              ungroup() |> select(iso3, cluster_lab),
            by = "iso3") |>
  arrange(pct_hotspot) |>
  mutate(pais_es = factor(pais_es, levels = pais_es))

pC <- ggplot(cob2, aes(pct_hotspot, pais_es)) +
  geom_col(aes(fill = cluster_lab), width = 0.74, color = "#162235", linewidth = 0.16) +
  geom_text(aes(label = sprintf("%.0f%%", pct_hotspot)),
            hjust = ifelse(cob2$pct_hotspot > 88, 1.15, -0.15),
            size = 2.4, color = ifelse(cob2$pct_hotspot > 88, CREAM, SLATE)) +
  scale_fill_manual(values = CL_COL, guide = "none", na.value = "#A9B0BA") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.10)), limits = c(0, 105)) +
  labs(
    x = "% del territorio nacional en regiones prioritarias", y = NULL,
    title = "¿Cuánto país es región crítica?",
    subtitle = "Malasia, Filipinas y Madagascar caben enteros"
  ) +
  theme_map2026(base_size = 9.5) +
  theme(
    panel.background = element_rect(fill = "#FBF9F3", color = BORDER, linewidth = 0.5),
    legend.position = "none",
    plot.title = element_text(size = 15),
    plot.subtitle = element_text(size = 8.8, margin = margin(b = 8)),
    axis.text.y = element_text(size = 7.8), axis.text.x = element_text(size = 7.4),
    panel.grid.major.x = element_line(color = "#E7E1D2", linewidth = 0.25),
    plot.margin = margin(10, 14, 8, 12)
  )

# ======== D. la zona más biodiversa de cada país =============================
top_pais <- dat |>
  filter(!is.na(n_especies), n_especies > 0) |>
  group_by(pais_es) |>
  slice_max(n_especies, n = 1, with_ties = FALSE) |>
  ungroup() |>
  arrange(n_especies) |>
  mutate(pais_es = factor(pais_es, levels = pais_es),
         hotspot_corto = hotspot_es)
X_TXT <- 2350

pD <- ggplot(top_pais, aes(y = pais_es)) +
  geom_segment(aes(x = n_especies_esp, xend = n_especies, yend = pais_es),
               color = "#8C93A1", linewidth = 0.4) +
  geom_point(aes(x = n_especies_esp), shape = 21, fill = CREAM, color = SLATE,
             size = 2.2, stroke = 0.45) +
  geom_point(aes(x = n_especies, fill = cluster_lab), shape = 21, color = "#162235",
             size = 3.0, stroke = 0.3) +
  geom_text(aes(x = X_TXT, label = hotspot_corto), hjust = 0, size = 2.05, color = SLATE,
            fontface = "italic") +
  scale_fill_manual(values = CL_COL, guide = "none") +
  scale_x_continuous(limits = c(0, X_TXT * 2.05), expand = c(0, 0)) +
  labs(
    x = "Especies de aves en el fragmento más rico", y = NULL,
    title = "El rincón más biodiverso de cada país",
    subtitle = "Punto sólido: todos los registros · hueco: sólo especímenes de museo"
  ) +
  theme_map2026(base_size = 9.5) +
  theme(
    panel.background = element_rect(fill = "#FBF9F3", color = BORDER, linewidth = 0.5),
    legend.position = "none",
    plot.title = element_text(size = 15),
    plot.subtitle = element_text(size = 8.4, margin = margin(b = 8)),
    axis.text.y = element_text(size = 7.8, face = "bold"),
    axis.text.x = element_text(size = 7.4),
    panel.grid.major.x = element_line(color = "#E7E1D2", linewidth = 0.25),
    plot.margin = margin(10, 8, 8, 12)
  )

# ================================ ensamblaje =================================
col_izq <- pA / pB + plot_layout(heights = c(1.18, 1))
col_der <- pD / pC + plot_layout(heights = c(1.18, 1))

poster <- (col_izq | col_der) +
  plot_layout(widths = c(1.62, 1)) +
  plot_annotation(
    caption = map_caption(
      4, "Clústeres (Clusters)",
      paste0("Conservation International / CEPF (regiones críticas de biodiversidad 2016), API de registros de GBIF (Aves) y Natural Earth 1:50m.\n",
             "Riqueza = especies distintas con registro georreferenciado en cada fragmento región-país (n = 40); ",
             "filtro: taxón Aves, coordenadas válidas, estado PRESENTE.")
    ),
    theme = theme(
      plot.background = element_rect(fill = CREAM, color = NA),
      plot.caption = element_text(size = 7.8, color = SLATE, hjust = 0,
                                  lineheight = 1.25, margin = margin(t = 8, b = 10))
    )
  ) &
  theme(plot.background = element_rect(fill = CREAM, color = NA))

dir.create("outputs/high_res", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/gallery", recursive = TRUE, showWarnings = FALSE)

ggsave("outputs/high_res/day04_clusters_megadiversidad.png", poster,
       width = 17, height = 12.4, dpi = 300, bg = CREAM)
# La galería se genera a la misma escala física (sólo cambia la resolución) para que
# la tipografía conserve sus proporciones y no se recorte ningún panel.
ggsave("outputs/gallery/day04_clusters_megadiversidad.png", poster,
       width = 17, height = 12.4, dpi = 105, bg = CREAM, limitsize = FALSE)
cat("Póster guardado en outputs/high_res y outputs/gallery\n")
