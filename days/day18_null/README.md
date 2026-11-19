# Día 18 — NULL (18 de noviembre de 2026)

- **Eje temático:** Biodiversidad Mundial
- **Concepto del mapa:** Terra Incognita Biológica: Vacíos de registros (`NULL` = 0 ocurrencias en GBIF) en zonas de alta vegetación (`NDVI ≥ 0.55`).
- **Fuentes de datos:**
  - **GBIF Map Density API v2:** 128 tiles vectoriales (`.mvt`, `z=3`, `EPSG:4326`, `squareSize=32`) que acumulan **3,574,947,005** ocurrencias georreferenciadas globales.
  - **NOAA NCEI VIIRS-Land NDVI (2024):** 4 compuestos globales diarios estacionales (`2024-01-15`, `2024-04-15`, `2024-07-15`, `2024-10-15` a 0.05°) combinados para obtener el NDVI máximo anual sin sesgo estacional ni nubosidad.
  - **WWF Ecoregions 2017 & Natural Earth 50m:** Límites nacionales (excluyendo Antártida) y biomas terrestres.

## Notas y Metodología

1. **Descarga (`01_download_data.py`):** Descarga automatizada de los 4 NetCDF globales de VIIRS NDVI 2024 y los 128 tiles MVT globales de GBIF.
2. **Procesamiento Equal Earth (`02_process_data.R`):** Todo el análisis se proyectó a **Equal Earth (`+proj=eqearth`)** sobre una grilla de áreas iguales de **50 × 50 km (2,500 km² por celda)** para evitar distorsiones de área en latitudes altas.
3. **Hallazgos clave:**
   - De **52,165 celdas terrestres** evaluadas (sin Antártida), **18,177** corresponden a zonas de alta vegetación (`NDVI ≥ 0.55`).
   - **111 celdas (277,500 km²)** de alta vegetación presentan **`NULL` absoluto (0 registros en GBIF)**, concentradas en la Taiga de Siberia Oriental (41 celdas), Amazonía brasileña (27), Sudán del Sur (17), República Centroafricana (8), R.D. del Congo (8), Canadá (4), Angola (4), China (1) y Rep. del Congo (1).
   - **2,383 celdas (5.96 M km², 13.1%)** de alta vegetación están en estado `NULL` o críticamente submuestreado (`≤ 50` registros por cada 2,500 km²).
4. **Visualización (`03_plot_map.R`):** Póster estilo Atlas Enmarcado con mapa global Equal Earth, ranking de biomas con mayor vacío relativo y diagrama de la paradoja del muestreo (NDVI vs. densidad GBIF).
