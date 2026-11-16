# Día 15 — Inside out (15 de noviembre de 2026)

**El Valle de México al revés: la cuenca que fue lago es hoy la cumbre de su propio mapa**

- **Eje temático:** México
- **Concepto:** Invertir el modelo digital de elevaciones del Valle de México para
  convertir el vaso lacustre en la cima del mapa y las sierras que lo rodean en abismos.
- **Fuentes de datos:**
  - **Copernicus DEM GLO-30** (© ESA / Airbus) — modelo digital de superficie de 30 m,
    mosaicos `N19_00_W100_00` y `N19_00_W099_00`, descargados de AWS Open Data.
  - **INEGI, Marco Geoestadístico** — 52 municipios de la Zona Metropolitana del
    Valle de México (ZMVM), reutilizados del acervo del Día 12.
- **Herramientas:** R 4.3.2 (`terra`, `sf`, `dplyr`, `ragg`) y gráficos base de R.

## Salidas

| Archivo | Descripción |
| :--- | :--- |
| `outputs/high_res/day15_inside_out_valle_invertido.png` | Póster 12 × 16 in a 300 dpi |
| `outputs/gallery/day15_inside_out_valle_invertido.png` | Versión ligera 150 dpi para la galería |
| `outputs/*/day15_inside_out_valle_derecho.png` | Variante de comparación: el mismo mapa sin invertir |

## Metodología

1. **Mosaico y recorte.** Se unen los dos mosaicos Copernicus GLO-30 y se recorta una
   ventana de 74 × 68 km (`-99.44, -98.70, 19.08, 19.76`) que contiene la cuenca cerrada
   y las sierras que la encierran (Cruces, Guadalupe, Ajusco). Se excluyen
   deliberadamente los grandes volcanes (Popocatépetl, Iztaccíhuatl, Malinche) para que
   la inversión se lea a escala de cuenca.
2. **Proyección.** Cónica Conforme de Lambert para México (`EPSG:6372`), 30 m de
   resolución. Rango resultante: **2,218 – 4,134 m s.n.m.** (desnivel de **1,916 m**).
3. **Relieve invertido.** Cada celda se refleja respecto al plano medio de la cuenca:
   `z_inv = z_min + z_max − z`. El fondo del vaso (2,218 m) pasa a ocupar la cima de la
   rampa; el Ajusco (3,930 m) y las Cruces descienden al fondo de abismos.
4. **Vaso lacustre histórico.** Se delimita la superficie bajo la cota **2,245 m**, la
   altura a la que se estabilizaban los lagos de Texcoco, Xochimilco, Chalco, Xaltocan y
   Zumpango: **1,114 km²**. Los 1,114 km² quedan dentro de los 52 municipios de la
   ZMVM: el **22.3 %** de su superficie (4,990 km²).
5. **Sombreado.** El DEM se agrega a 150 m y se suaviza con un filtro focal 7 × 7 para
   atenuar el ruido del tejido urbano; el sombreado usa azimut 315° y elevación solar 40°.
6. **Escala de color.** La rampa tiene dos tramos continuos con bisagra en **2,300 m**:
   por encima, la altitud invertida (de la orilla al abismo); por debajo, el vaso
   lacustre, cuyo tono se satura hacia lo más hundido (hasta **27 m** bajo la cota).
   El mismo color se usa en la leyenda y en el mapa.
7. **Población.** Con las AGEB urbanas del censo 2020 se calcula qué fracción de cada
   AGEB cae dentro del vaso y se pondera su población: **9.4 millones de personas**
   viven sobre el lecho del antiguo lago, el **45.8 %** de la ZMVM (20.5 millones).
8. **Esferas.** Cada municipio lleva un círculo de área proporcional a su población
   (Censo 2020), situado en el centroide ponderado por población de sus AGEB, para que
   la esfera caiga sobre el tejido urbano y no sobre el monte.

## Hallazgos

- El fondo del valle (**2,218 m**) está hoy **por debajo de la cota histórica de los
  lagos (2,245 m)**: la cuenca se vació y se hundió, y el drenaje ya no alcanza.
- El área bajo la cota lacustre equivale a **19 % de la ventana de estudio** y a casi una
  cuarta parte del suelo metropolitanizado: **9.4 millones de personas** viven ahí.
- En el mapa invertido, la ciudad ocupa una meseta dorada continua: la única "cumbre"
  de 1,100 km² del país, y las sierras que la rodean, abismos de hasta 1,900 m.

## Reproducibilidad

```bash
# Descarga previa (dataset crudo, ignorado por Git)
# https://copernicus-dem-30m.s3.amazonaws.com/Copernicus_DSM_COG_10_N19_00_W100_00_DEM/...
# https://copernicus-dem-30m.s3.amazonaws.com/Copernicus_DSM_COG_10_N19_00_W099_00_DEM/...

Rscript days/day15_inside_out/day15_data_pipeline.R
Rscript days/day15_inside_out/day15_poster.R
```

## Notas

- Los datos crudos viven en `data/raw/day15/`; los intermedios (DEM proyectado,
  sombreados, vaso lacustre, perfil y estadísticas) en `data/processed/`. El perfil
  A–A′ sigue calculándose en el pipeline, pero ya no se dibuja en el póster.
- El "hundimiento" se menciona de forma cualitativa: el dato duro que sostiene el mapa es
  la diferencia entre el fondo actual del valle y la cota histórica de los lagos.

## Serie metropolitana: cuatro ciudades al revés

El mismo tratamiento se aplicó a las otras tres grandes zonas metropolitanas del país,
con un póster por ciudad y un video que las recorre:

| Ciudad | ZMVM | Municipios | Población (2020) | Desnivel |
| :--- | :---: | :---: | ---: | ---: |
| Valle de México | zmvm | 52 | 20.5 M | 1,901 m |
| Monterrey | mty | 18 | 5.3 M | 3,408 m |
| Guadalajara | gdl | 10 | 5.1 M | 2,304 m |
| Puebla | pue | 25 | 2.8 M | 3,128 m |

- En cada póster, **arriba a la derecha** va el mapa tradicional (hipsometría normal) con
  los **cuerpos de agua de OpenStreetMap**: ríos, canales, presas y lagunas.
- El mapa principal invierte el relieve: la llanura urbana es una **meseta de oro** y las
  sierras que rodean cada ciudad, abismos.
- Las **esferas** dimensionan la población de cada municipio (Censo 2020).
- **Video:** `outputs/gallery/day15_serie_4ciudades.mp4`, 40 s (10 s por ciudad), 1080 × 1440.

Scripts: `day15_serie.R` (datos), `day15_water.py` (agua de OSM), `day15_serie_poster.R`
(pósters) y `day15_video.py` (video). Hilo de difusión: `day15_serie_tweets.md`.