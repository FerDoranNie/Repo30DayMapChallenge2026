# Reglas del Agente — Repo30DayMapChallenge2026

## Entornos de Ejecución

1. **Python (Anaconda):**
   - Para cualquier tarea, análisis, descarga de datos o visualización en Python, **SIEMPRE se debe utilizar el ambiente `data_engineering` de Anaconda** (`C:\Users\fernando.dorantes\anaconda3\envs\data_engineering\python.exe` o activando `conda run -n data_engineering`).
   - No utilizar el Python global del sistema salvo indicación explícita.

2. **R:**
   - Utilizar `Rscript.exe` en `C:\Program Files\R\R-4.3.2\bin\Rscript.exe` asegurándose de incluir la librería de usuario (`C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3`).
   - Nota de entorno: Cuando se requiera acceso a la librería de usuario de R, al entorno de Anaconda `data_engineering` fuera del workspace o descargas desde APIs externas (GBIF, INEGI, Natural Earth, etc.), ejecutar el comando con permisos fuera del sandbox (`BypassSandbox: true`).

## Convenciones Cartográficas y del Repositorio

- **Fondo y Paleta Base (Regla de Diseño — Estilo Atlas Enmarcado):**
  - **Lienzo exterior del póster (`plot.background` / `figure.facecolor`):** Papel crema cálido editorial (`#F7F4EB`), con tipografía oscura de alto contraste (`#0F172A` para títulos principales y `#334155` / `#475569` para subtítulos, leyendas exteriores y pies de figura).
  - **Marco de mapa y océanos (`panel.background`):** Azul atlas pálido (`#DCE6F2`) delimitado por un borde fino tipo lámina de atlas (`#94A3B8`), evitando que los mapas floten sin contexto sobre el papel crema.
  - **Polígonos continentales/nacionales y paneles de datos:** Evitar el negro abisal puro; emplear **azul pizarra / petróleo medio** (`#24344D` con divisiones internas en `#435B7D` y costa en `#162235`) cuando se requiera contraste para puntos luminosos, líneas de flujo o coropletas vibrantes, o bien tonos tierra/piedra claros (`#E5E0D5`) en mapas coropléticos clásicos.
- **Estilo y Firma:** Todos los mapas deben incluir en el pie de figura (`caption`) la referencia a `#30DayMapChallenge 2026`, el día, el tema oficial, la fuente de los datos y la autoría (`Fernando Dorantes Nieto (@FerDoranNie)`).
- **Salidas:**
  - Guardar una versión en alta resolución en `outputs/high_res/dayXX_<tema>.png`.
  - Guardar una versión ligera optimizada en `outputs/gallery/dayXX_<tema>.png` para la galería del `README.md` principal.
- **Datos:** Guardar datos descargados crudos en `data/raw/` y datos limpios/intermedios en `data/processed/` (ambos ignorados por Git para mantener el repositorio limpio).
