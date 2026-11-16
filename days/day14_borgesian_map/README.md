# Día 14 — Borgesian map (14 de noviembre de 2026)

- **Eje temático:** Datos Curiosos
- **Concepto del mapa:** *El Aleph de las Ecorregiones*: Mapa caligráfico de México donde el territorio y sus 45 ecorregiones se dibujan exclusivamente mediante los nombres científicos reales de su flora, fauna y hongos.
- **Fuentes de datos:**
  - [GBIF API v1](https://api.gbif.org/v1/) (`occurrence/search` & `species`): consulta taxonómica balanceada por reino (*Plantae*, *Animalia*, *Fungi*) dentro de las 45 ecorregiones mexicanas (**2,185 especies binomiales únicas**).
  - [Ecoregions2017 (RESOLVE)](https://ecoregions.appspot.com/) recortadas al territorio nacional en proyección equivalente/cónica conforme `EPSG:6372` (ITRF2008 / Mexico LCC).

## Notas y Metodología

1. **Extracción taxonómica por ecorregión (`day14_data_pipeline.py`):**
   - Se consultó la API de GBIF para cada una de las 45 ecorregiones de México (utilizando polígonos WKT simplificados con respaldo por rango geográfico), equilibrando registros de plantas, animales y hongos.
   - Se resolvieron **2,185 nombres binomiales canónicos** y se ponderó su distintividad ecológica (`count / eco_freq^1.35`) para resaltar en primer plano las especies características de cada ecorregión sobre las especies urbanas o cosmopolitas.
2. **Motor caligráfico sin colisiones (`day14_poster.py`):**
   - Cada ecorregión se rasterizó en una máscara booleana exacta y se rellenó de menor a mayor superficie en tres niveles tipográficos (*Georgia Bold Italic* y *Georgia Italic*), garantizando **0% de traslape** mediante detección de colisiones a nivel de píxel.
   - En total se inscribieron **1,347 nombres científicos** coloreados según los **7 biomas de México**, acompañados de una lente microscópica (*El Aleph*, zoom 3×) sobre la Sierra Madre del Sur, Oaxaca y el Valle de Tehuacán.

## Salidas

- Alta resolución (4200 × 3060 px, 300 DPI): [`outputs/high_res/day14_borgesian_map_aleph.png`](../../outputs/high_res/day14_borgesian_map_aleph.png)
- Galería: [`outputs/gallery/day14_borgesian_map_aleph.png`](../../outputs/gallery/day14_borgesian_map_aleph.png)
