# Día 13 — Interactions (13 de noviembre de 2026)

**Título:** ¿Hacia dónde drena la biodiversidad del planeta? La red global de comercio de vida silvestre (CITES), 2015–2024

- **Eje temático:** 🌍 Biodiversidad y Problemas Ambientales Mundiales
- **Formato de salida:** 🖼️ Póster estático `.png` (300 dpi) + 🎞️ Animación `.gif` y `.mp4` (bucle de 72 fotogramas)
- **Herramientas:** R (`sf`, `data.table`, `ggplot2`, `patchwork`, `ragg`, `gifski`, `av`)
- **Fuente:** [CITES Trade Database](https://trade.cites.org/) — *Full CITES Trade Database Download*, versión **2026.1**, compilada por UNEP-WCMC para la Secretaría CITES (29.2 millones de registros, extracción del 9 de junio de 2026).

---

## 🎯 Qué muestra

La biodiversidad no solo interactúa dentro de los ecosistemas: millones de especímenes cruzan fronteras cada año dentro de una red comercial regulada por CITES. Este mapa dibuja esa red como **arcos direccionales**: cada arco nace en el país exportador y termina en el importador, el grosor codifica el volumen y el trazo discontinuo distingue **pieles y trofeos** de **animales vivos**.

El póster suma tres paneles:

- **A. Mapa global** (Robinson, centrado en Greenwich): las 145 rutas principales de fauna silvestre, 87 % del volumen total.
- **B. Matriz exportador → importador:** los 10 mayores exportadores contra los 10 mayores importadores.
- **C. México en la red:** qué importa (pieles de reptil de Argentina, Indonesia, Bolivia y Brasil) y qué exporta (trofeos de caza a EE.UU.).

---

## 📊 Hallazgos

**35,990,169 especímenes** de fauna silvestre en **2,568 rutas** entre **223 países y territorios** (2015–2024, origen directo, sin reexportaciones).

| Gremio | Especímenes | Rutas | Países exp. / imp. |
|---|---:|---:|---:|
| Reptiles | 18,824,867 | 857 | 87 / 134 |
| Acuáticos y anfibios | 15,753,312 | 535 | 81 / 100 |
| Mamíferos | 1,103,055 | 1,536 | 139 / 172 |
| Aves | 307,738 | 528 | 92 / 130 |

**Exportadores:** Indonesia (10.8 M), Australia (7.5 M), Estados Unidos (6.4 M), Argentina (1.9 M), Fiyi (1.9 M), Malasia (1.6 M).
**Importadores:** Estados Unidos (7.3 M), Singapur (5.0 M), Francia (3.0 M), **México (3.0 M)**, Italia (2.8 M), Alemania (2.2 M).

**Rutas más intensas:** Indonesia → Singapur (3.09 M), Indonesia → EE.UU. (2.36 M), Australia → EE.UU. (2.21 M), EE.UU. → Francia (1.81 M), **Argentina → México (1.30 M)**.

**El hallazgo incómodo:** México es el **cuarto importador mundial** de fauna silvestre CITES (de 195) y solo el **52.º exportador** (de 186). Importa 3,007,079 especímenes, **90 % pieles** —de reptil sobre todo: *Salvator rufescens*, *Varanus salvator*, *Malayopython reticulatus*— y 429,292 acuáticos (*Arapaima gigas*). Exporta apenas 10,905, casi todos trofeos de caza: pavo ocelado (*Meleagris ocellata*, 5,589) y borrego cimarrón (*Ovis canadensis*, 3,088). La imagen de México como potencia exportadora de vida silvestre no se sostiene en los datos; sí la de **hub manufacturero de pieles exóticas**.

**La flora se trata aparte.** El comercio silvestre de plantas (17.0 M de especímenes) está dominado por un solo corredor: *Galanthus woronowii* (campanilla de invierno), Georgia → Turquía y Países Bajos, 15.5 M de bulbos, casi todo en 2016. Incluirlo en la misma escala que la fauna habría tapado la historia principal, así que se documenta aquí y queda fuera del mapa.

---

## 🛠️ Decisiones metodológicas

1. **Unidad de conteo.** Se conservan solo registros contados en especímenes (`Unit` vacío o `"Number of specimens"`); se excluyen kg, m³, ml y similares. Ojo: `Unit` trae cadenas en blanco (`" "`), no `NA`; sin `trimws()` se perdían 22.4 M de filas y 2015–2016 quedaban en cero.
2. **Armonización importador/exportador.** Cada envío puede estar reportado por ambas partes; el volumen se toma como `max(lo reportado por el importador, lo reportado por el exportador)` por año, ruta y gremio (criterio recomendado por la guía CITES).
3. **Origen directo.** Se excluyen las reexportaciones (`Origin` con código ISO de dos letras), de modo que cada arco representa comercio desde el país de origen. `Origin` también viene como cadena vacía, no `NA`.
4. **Filtros.** Años 2015–2024; `Term` ∈ {live, trophies, skins}; `Source` ∈ {W, R, F, C, A, D}, etiquetadas como silvestre, rancheo, cautiverio y propagado; códigos ISO-2 válidos y distintos entre sí.
5. **Gremios.** Clase taxonómica cuando existe; las plantas (que llegan sin `Class`) se resuelven por orden y familia botánica.

De 29.2 M de registros quedan **5,457,771** tras el filtrado.

---

## 📂 Archivos

| Archivo | Contenido |
|---|---|
| `day13_data_pipeline.R` | Lee los 59 CSV del zip, filtra, armoniza y construye el grafo (2.7 min) |
| `day13_qa_taxon.R` | Auditoría a nivel especie/término |
| `day13_poster.R` | Póster de tres paneles, 300 dpi y 150 dpi |
| `day13_animate.R` | 72 fotogramas, `.gif` y `.mp4` |
| `day13_video.R` | Video de 45 s del póster en tres capítulos |
| `../../utils/arcos_cites.R` | Paleta, formato y geometría de arcos (compartida) |
| `data/processed/day13_cites_network.rds` | Grafo, nodos, rutas y resumen de México |
| `data/processed/day13_detalle_taxon.rds` | Detalle por especie y término comercial |

Salidas: `outputs/high_res/day13_interactions_cites_fauna.png`, `outputs/gallery/day13_interactions_cites_fauna.png`, `outputs/gallery/day13_interactions_cites_flujos.gif`, `outputs/gallery/day13_interactions_cites_flujos.mp4` y `outputs/gallery/day13_interactions_cites_video.mp4`.

## 🎬 Video del póster (45 s)

`day13_video.R` convierte el póster en un recorrido de tres capítulos —el mapa, la matriz de flujos y México— sobre 1920×1080 a 24 fps. Cada capítulo es un recorte del PNG de alta resolución y el zoom se hace recortando el recorte, así la imagen siempre encaja exacta en el área; el capítulo de México se redibuja desde los datos porque en el póster sus etiquetas se solapan con el panel B.

```bash
Rscript day13_video.R                      # 45 s, ~20 min de render
DAY13_VIDEO_TEST=1 Rscript day13_video.R   # 5 fotogramas de control
```

## 🐦 Hilo de 5 tweets

El texto listo para publicar está en `day13_tweets.md`: qué muestra el mapa, el hallazgo de México, metodología (filtros, armonización importador/exportador, proyección) y fuentes.

### Reproducir

```bash
# 1) descargar el zip completo (~480 MB) desde https://trade.cites.org/
#    y guardarlo en data/raw/day13/Trade_database_download_v2026.1.zip
Rscript day13_data_pipeline.R
Rscript day13_qa_taxon.R
Rscript day13_poster.R
Rscript day13_animate.R
```

---

## 🖋️ Pie de figura

`#30DayMapChallenge 2026 | Día 13: Interactions\nDatos: CITES Trade Database v2026.1 (UNEP-WCMC), 2015–2024 | Gráfico: Fernando Dorantes Nieto (@FerDoranNie)`
