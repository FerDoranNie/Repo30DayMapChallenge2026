# 🗺️ #30DayMapChallenge 2026

Repositorio oficial de mi participación en el **#30DayMapChallenge 2026** (noviembre de 2026). Esta es mi **tercera edición consecutiva** participando en el reto cartográfico creado por Topi Tjukanov:

- 📁 **Edición 2025:** [FerDoranNie/-Repo30DayMapChallenge2025](https://github.com/FerDoranNie/-Repo30DayMapChallenge2025)
- 📁 **Edición 2024:** [FerDoranNie/Repo30DayMapChallenge2024](https://github.com/FerDoranNie/Repo30DayMapChallenge2024)

---

## 🎯 Ejes Temáticos de la Edición 2026

En esta edición los 30 mapas giran alrededor de cuatro grandes líneas de investigación y visualización espacial:

1. **🌍 Biodiversidad y Problemas Ambientales Mundiales:** Riqueza de especies, países megadiversos, deforestación, conectividad ecológica y conservación global.
2. **🇲🇽 México (Demografía, Sociedad y Medio Ambiente):** Desigualdad urbana (como la hipótesis del *Poniente rico* en las metrópolis mexicanas), estrés hídrico, transición urbano-rural e islas de calor.
3. **🦜 Información sobre Aves:** Endemismo en México, rutas migratorias continentales, ecología del plumaje, paisajes sonoros y ciencia ciudadana.
4. **💡 Datos Curiosos y Exploraciones Creativas:** Cartografía borgesiana, topónimos animales, mapas históricos estilo *vintage* y visualizaciones experimentales.

---

## 🛠️ Herramientas y Stack Tecnológico

- **R:** `sf`, `terra`, `stars`, `ggplot2`, `tmap`, `rayshader`, `biscale`, `ggridges`, `rgbif`
- **Python:** `geopandas`, `rasterio`, `xarray`, `matplotlib`, `leafmap`, `pydeck`, `h3`, `osmnx`, `duckdb`
- **SIG de Escritorio y Diseño:** QGIS, ArcGIS, Blender
- **Web / Interactivo:** Leaflet, MapLibre GL, Deck.gl, Observable, Quarto / Shiny

---

## 📅 Calendario y Progreso de los 30 Días

| Día | Fecha | Tema Oficial | Eje Temático | Mapa / Proyecto | Herramientas | Código | Estado |
| :---: | :---: | :--- | :--- | :--- | :--- | :---: | :---: |
| **01** | 01 Nov | **Points** | 🦜 Aves | Endemismo alado en México (~110 especies endémicas) | R (`sf`, `ggplot2`) | [`day01`](./days/day01_points/) | ✅ Publicado |
| **02** | 02 Nov | **Lines** | 🦜 Aves | Autopistas del cielo: Veracruz Río de Rapaces y el embudo migratorio de América | Python (`pandas`, `shapely`, `scipy`, `matplotlib`) | [`day02`](./days/day02_lines/) | ✅ Publicado |
| **03** | 03 Nov | **Polygons** | 🇲🇽 México | El escudo verde de México: 223 ANP y presión antrópica | R (`sf`, `terra`, `ggplot2`) | [`day03`](./days/day03_polygons/) | ✅ Publicado |
| **04** | 04 Nov | **Clusters** | 🌍 Bio/Amb | Clústeres de la megadiversidad: la zona más biodiversa de los 17 países más biodiversos | R (`sf`, `ggplot2`, `patchwork`, `cluster`) + GBIF API | [`day04`](./days/day04_clusters/) | ✅ Publicado |
| **05** | 05 Nov | **Senses: Sight** | 🦜 Aves | Ecología del plumaje: Riqueza cromática e iridiscencia aviar en México | R (`terra`, `sf`, `ggplot2`, `patchwork`) + GBIF & BirdColorBase | [`day05`](./days/day05_senses_sight/) | ✅ Publicado |
| **06** | 06 Nov | **Vintage** | 🌍 Bio/Amb | Cuatro naturalistas, cuatro rutas: Darwin, Humboldt, Wallace y Helia Bravo | R (`sf`, `ggplot2`, `patchwork`, `gifski`) + GBIF | [`day06`](./days/day06_vintage/) | ✅ Publicado |
| **07** | 07 Nov | **10 minute map** | 🇲🇽 México | Los primeros 10 minutos del Cenozoico: Chicxulub y el Anillo de Cenotes (11,878 cenotes y cavernas) | R (`sf`, `terra`, `ggplot2`, `patchwork`) | [`day07`](./days/day07_10_minute_map/) | ✅ Publicado |
| **08** | 08 Nov | **Utopia** | 🌍 Bio/Amb | Planeta 30×30: una utopía posible — Ecorregiones y megacorredores biológicos | R (`sf`, `ggplot2`, `patchwork`) | [`day08`](./days/day08_utopia/) | ✅ Publicado |
| **09** | 09 Nov | **Urban-rural** | 🇲🇽 México | La frontera que devora el bosque: 50 años de expansión metropolitana en México | R (`terra`, `sf`, `biscale`, `patchwork`, `gifski`, `av`) | [`day09`](./days/day09_urban_rural/) | ✅ Publicado |
| **10** | 10 Nov | **Prompting only** | 💡 Curioso | El Bestiario y Herbario Toponímico de México (16,667 localidades clasificadas) | R (`sf`, `ggplot2`, `patchwork`, `stringi`) | [`day10`](./days/day10_prompting_only/) | ✅ Publicado |
| **11** | 11 Nov | **Senses: Sound** | 🦜 Aves | El coro del amanecer en México: La ola acústica de las aves del Caribe al Pacífico (38,353 grabaciones) | R (`sf`, `terra`, `ggplot2`, `patchwork`, `gifski`, `av`) + GBIF Sound | [`day11`](./days/day11_senses_sound/) | ✅ Publicado |
| **12** | 12 Nov | **Power** | 🇲🇽 México | ⭐ **¿El Poniente siempre es más rico? Geografía cardinal del poder socioeconómico en 11 metrópolis** | R (`sf`, `ggplot2`, `patchwork`, `gifski`, `av`, `data.table`) | [`day12`](./days/day12_power/) | ✅ Publicado |
| **13** | 13 Nov | **Interactions** | 🌍 Bio/Amb | ⭐ **¿Hacia dónde drena la biodiversidad? La red global del comercio de vida silvestre (CITES)** | R (`sf`, `data.table`, `ggplot2`, `patchwork`, `gifski`, `av`) | [`day13`](./days/day13_interactions/) | ✅ Publicado |
| **14** | 14 Nov | **Borgesian map** | 💡 Curioso | El Aleph de las Ecorregiones: Mapa caligráfico con nombres científicos | Python (`shapely`, `Pillow`, `numpy`) + GBIF API | [`day14`](./days/day14_borgesian_map/) | ✅ Publicado |
| **15** | 15 Nov | **Inside out** | 🇲🇽 México | El Valle de México al revés: topografía invertida y vaso lacustre | R (`terra`, `sf`, `ragg`) | [`day15`](./days/day15_inside_out/) | ✅ Publicado |
| **16** | 16 Nov | **Collaborative map** | 🦜 Aves | El pulso de la ciencia ciudadana: eBird y Naturalista en México (18.19 M registros) | Python (`numpy`, `scipy`, `shapely`, `matplotlib`) | [`day16`](./days/day16_collaborative_map/) | ✅ Publicado |
| **17** | 17 Nov | **Light & dark** | 🦜 Aves | ⭐ **Trampas de luz: la migración nocturna del Golfo frente al resplandor de las ciudades** (45 especies, 2.23 M registros) | Python (`numpy`, `pandas`, `scipy`, `Pillow`, `matplotlib`) + NASA GIBS & GBIF | [`day17`](./days/day17_light_and_dark/) | ✅ Publicado |
| **18** | 18 Nov | **NULL** | 🌍 Bio/Amb | Terra Incognita Biológica: Vacíos de muestreo (`NULL` en GBIF) en zonas de alta vegetación | R (`terra`, `sf`, `ggplot2`, `patchwork`) + Python (`requests`) | [`day18`](./days/day18_null/) | ✅ Publicado |
| **19** | 19 Nov | **Senses: Smell** | 🇲🇽 México | ¿A qué huele la Ciudad de México? Paisaje olfativo urbano (50,152 comercios DENUE vs. 940.6 t COVs RETC 2024) | R (`sf`, `data.table`, `ggplot2`, `patchwork`, `ragg`) + Python | [`day19`](./days/day19_senses_smell/) | ✅ Publicado |
| **20** | 20 Nov | **Hexagons** | 🌍 Bio/Amb | ⭐ **El mosaico de la crisis y la vida: riqueza de vertebrados vs. huella de pérdida de cobertura arbórea en 11,854 hexágonos H3** | Python (`h3`, `rasterio`, `matplotlib`) + Map of Life & WRI/Google DeepMind | [`day20`](./days/day20_hexagons/) | ✅ Publicado |
| **21** | 21 Nov | **OpenStreetMap** | 🇲🇽 México | Oasis urbanos: Accesibilidad peatonal a áreas verdes en ciudades de México | Python (`osmnx`) | [`day21`](./days/day21_openstreetmap/) | ⏳ Pendiente |
| **22** | 22 Nov | **Projections** | 🦜 Aves | El mundo visto por el Charrán Ártico (*Sterna paradisaea*) de polo a polo | R (`sf`) | [`day22`](./days/day22_projections/) | ⏳ Pendiente |
| **23** | 23 Nov | **Senses: Taste** | 🇲🇽 México | Centro Vavilov: Razas nativas de maíz, chiles, cacao y Denominaciones de Origen | R / QGIS | [`day23`](./days/day23_senses_taste/) | ⏳ Pendiente |
| **24** | 24 Nov | **Network** | 🌍 Bio/Amb | Ríos conectados y fragmentados: Cuencas hidrográficas por orden de Strahler | R (`sf`, `ggplot2`) | [`day24`](./days/day24_network/) | ⏳ Pendiente |
| **25** | 25 Nov | **Is this a map?** | 💡 Curioso | Paisajes de crestas (*joyplot*) de anomalías térmicas / espectrogramas aviares | R (`ggridges`) | [`day25`](./days/day25_is_this_a_map/) | ⏳ Pendiente |
| **26** | 26 Nov | **Water** | 🇲🇽 México | La sed de un país: Estrés hídrico y sobreexplotación de acuíferos en México | R (`sf`, `tmap`) | [`day26`](./days/day26_water/) | ⏳ Pendiente |
| **27** | 27 Nov | **New tool** | 🌍 Bio/Amb | Exploración masiva de biodiversidad con DuckDB Spatial + Lonboard / MapLibre | Python (`lonboard`) | [`day27`](./days/day27_new_tool/) | ⏳ Pendiente |
| **28** | 28 Nov | **Senses: Feeling** | 🇲🇽 México | Islas de calor urbano y vulnerabilidad térmica en ciudades mexicanas | Python / R (`terra`) | [`day28`](./days/day28_senses_feeling/) | ⏳ Pendiente |
| **29** | 29 Nov | **Raster** | 🌍 Bio/Amb | Altura del dosel forestal y relieve sombreado en bosques mesófilos | R (`terra`, `rayshader`) | [`day29`](./days/day29_raster/) | ⏳ Pendiente |
| **30** | 30 Nov | **Pen & paper** | 🦜 Aves | Cuaderno de campo de un naturalista: Mapa dibujado a mano de ruta de aves | Pluma, papel y tinta | [`day30`](./days/day30_pen_and_paper/) | ⏳ Pendiente |

---

## 📂 Estructura del Proyecto

```text
Repo30DayMapChallenge2026/
├── README.md                  # Documentación general, calendario y galería visual
├── utils/                     # Plantillas de estilo y funciones auxiliares en R y Python
│   ├── theme_map2026.R
│   └── theme_map2026.py
├── data/                      # Datos crudos y procesados (ignorados en Git por tamaño)
│   ├── raw/
│   └── processed/
├── days/                      # Código reproducible y notas para cada uno de los 30 días
│   ├── day01_points/
│   ├── ...
│   └── day30_pen_and_paper/
└── outputs/                   # Mapas exportados
    ├── gallery/               # Imágenes optimizadas para la galería de este README
    └── high_res/              # Salidas en alta resolución
```

---

## 🖼️ Galería de Mapas

### Día 1
#### Constelaciones del endemismo aviar en México
![Día 1](outputs/gallery/day01_points_aves_endemicas.png)

### Día 2
#### Veracruz Río de Rapaces
![Día 2](outputs/gallery/day02_lines_veracruz_rio_rapaces.png)

### Día 3
#### Estado actual de las áreas protegidas de México
![Día 3](outputs/gallery/day03_polygons_anp_presion.png)

### Día 4
#### Centros de biodiversidad en los países megadiversos
![Día 4](outputs/gallery/day04_clusters_megadiversidad.png)

### Día 5
#### Ecología del plumaje: riqueza cromática e iridiscencia aviar en México
![Día 5](outputs/gallery/day05_senses_sight_plumaje.png)

### Día 6
#### ¿Cómo fue el viaje de 4 grandes naturalistas/científicos que cambiaron la visión de la naturaleza en el mundo?
![Día 6](outputs/gallery/day06_naturalistas_facetas.gif)

**Versión MP4:** [Cuatro facetas](outputs/gallery/day06_naturalistas_facetas.mp4) · [Darwin](outputs/gallery/day06_darwin.mp4) · [Humboldt](outputs/gallery/day06_humboldt.mp4) · [Humboldt en Nueva España](outputs/gallery/day06_humboldt_mexico.mp4) · [Wallace](outputs/gallery/day06_wallace.mp4) · [Bravo](outputs/gallery/day06_bravo.mp4)

### Día 7
#### Los primeros 10 minutos del Cenozoico: Chicxulub y el Anillo de Cenotes
![Día 7](outputs/gallery/day07_10_minute_map_chicxulub_cenotes.png)

### Día 8
#### Planeta 30×30: una utopía posible — ecorregiones y megacorredores biológicos
![Día 8](outputs/gallery/day08_utopia_planeta_30x30.png)

**Versión México:** [México 30×30](outputs/gallery/day08_utopia_mexico.png)

### Día 9
#### La frontera que devora el bosque: 50 años de expansión metropolitana en México
![Día 9](outputs/gallery/day09_urban_rural_frontera_bosque.png)

### Día 10
#### El Bestiario y Herbario Toponímico de México: Geografía de la fauna y flora en los nombres de ~300,000 localidades
![Día 10 - Versión Detalle](outputs/gallery/day10_prompting_only_detalle.png)

**Versión Atlas con pequeños múltiplos:** [Ver póster con múltiplos por taxón](outputs/gallery/day10_prompting_only_toponimos.png)

### Día 11
#### ¿Cómo es el panorama acústico de la avifauna en México?
![Día 11](outputs\high_res\day11_senses_sound_coro_amanecer.png)

### Día 12
#### ¿El Poniente siempre es más rico? Geografía cardinal del poder socioeconómico en México
![Día 12](outputs/gallery/day12_power_poniente_rico.png)

**Tour metropolitano escena a escena:** [Ver animación GIF](outputs/gallery/day12_power_ciudades_tour.gif) · [Ver video MP4](outputs/gallery/day12_power_ciudades_tour.mp4)



### Día 13
#### ¿Hacia dónde drena la biodiversidad del planeta? El comercio mundial de vida silvestre (CITES, 2015–2024)
![Día 13](outputs/gallery/day13_interactions_cites_fauna.png)

**Animación de flujos:** [GIF](outputs/gallery/day13_interactions_cites_flujos.gif) · [MP4](outputs/gallery/day13_interactions_cites_flujos.mp4) · **Video del póster (45 s):** [MP4](outputs/gallery/day13_interactions_cites_video.mp4)

### Día 14
#### El Aleph de las Ecorregiones: Mapa caligráfico de México formado por nombres científicos
![Día 14](outputs/gallery/day14_borgesian_map_aleph.png)

### Día 15
#### El Valle de México al revés: la cuenca que fue lago es hoy la cumbre de su mapa
![Día 15](outputs/gallery/day15_inside_out_valle_invertido.png)

**Variante de comparación:** [el mismo valle sin invertir](outputs/gallery/day15_inside_out_valle_derecho.png)

**Serie metropolitana (video de 40 s):** [Cuatro ciudades al revés](outputs/gallery/day15_serie_4ciudades.mp4) — [Monterrey](outputs/gallery/day15_serie_mty.png) · [Guadalajara](outputs/gallery/day15_serie_gdl.png) · [Puebla](outputs/gallery/day15_serie_pue.png) · [Valle de México](outputs/gallery/day15_serie_cdmx.png)

### Día 16
#### El pulso de la ciencia ciudadana: eBird y Naturalista en México
![Día 16](outputs/gallery/day16_collaborative_map_ciencia_ciudadana.png)

### Día 18
#### Terra Incognita Biológica: El mapa del NULL (vacíos de GBIF en zonas de alta vegetación)
![Día 18](outputs/gallery/day18_null_terra_incognita.png)

### Día 17
#### Trampas de luz: la migración nocturna del Golfo de México frente al resplandor de las ciudades
![Día 17](outputs/gallery/day17_light_and_dark_trampas_de_luz.png)


### Día 19
#### ¿A qué huele la Ciudad de México? El paisaje olfativo urbano
![Día 19](outputs/gallery/day19_senses_smell_paisaje_olfativo.png)

### Día 20
#### El mosaico de la crisis y la vida: riqueza de vertebrados y huella de pérdida de cobertura arbórea
![Día 20](outputs/gallery/day20_hexagons_crisis_y_vida.png)

*11,854 hexágonos H3 · 48% de la tierra de alta riqueza ya muestra huella de pérdida · 1,623 hexágonos en el frente crítico*


---

## 👤 Autor

**Fernando Dorantes Nieto**
- GitHub: [@FerDoranNie](https://github.com/FerDoranNie)
