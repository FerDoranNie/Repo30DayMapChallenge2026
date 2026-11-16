# Día 16 — Collaborative map (16 de noviembre de 2026)

- **Eje temático:** 🦜 Aves
- **Concepto del mapa:** El pulso de la ciencia ciudadana: eBird y Naturalista (iNaturalist) en México
- **Fuentes de datos:**
  - GBIF API (`EOD – eBird Observation Dataset`, `datasetKey=4fa7b334-ce0d-4e88-aaae-2e0c138d049e`)
  - GBIF API (`iNaturalist Research-grade Observations`, `datasetKey=50c9509d-22c7-4a22-a47d-8c48425ef4a7`)
  - iNaturalist API v1 (`place_id=6793`, `taxon_id=3`) para conteos de observadores (`81,483`) y taxones (`1,707`)

## Notas y Metodología

1. **Extracción y caché (`day16_data_pipeline.py`):**
   - Se consultaron los conteos exactos y facetas históricas/estatales (`year` y `gadmGid`) en GBIF para la clase *Aves* (`taxonKey=212`) en México (`19,222,253` registros totales), confirmando que **eBird (`16,573,694`)** y **Naturalista (`1,616,046`)** concentran **`18,189,740` registros (~94.6%)** de toda la evidencia ornitológica nacional.
   - Para representar fielmente la distribución espacial nacional sin sesgos de truncamiento, se descargó una muestra estratificada de **`114,000` registros georreferenciados** (`56,400` de eBird y `57,600` de Naturalista) cubriendo las **32 entidades federativas** entre 2020 y 2025, ponderados por el volumen real de cada entidad.
2. **Rasterización bivariada y póster (`day16_poster.py`):**
   - Se construyó una grilla de alta resolución (`1400 × 960`) recortada al polígono oficial de México, aplicando acumulación ponderada (`np.add.at`), suavizado gaussiano dual (núcleo + halo) y compresión logarítmica/gamma.
   - La mezcla aditiva bivariada contrasta **eBird** (ámbar dorado, rutas migratorias y costas como Quintana Roo, Veracruz y Yucatán) frente a **Naturalista** (cian turquesa, grandes metrópolis como Valle de México, Guadalajara y Monterrey), convergiendo en marfil brillante en los nodos de alta colaboración.
   - Se siguió el estilo **Atlas Enmarcado** del repositorio (`#F7F4EB` papel crema, `#DCE6F2` océano atlas, `#24344D` territorio y tipografía Georgia).
