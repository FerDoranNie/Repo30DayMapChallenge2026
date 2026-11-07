# Día 06 — Vintage (06 de noviembre de 2026)

- **Título:** Cuatro naturalistas, cuatro rutas — Darwin, Humboldt, Wallace y Bravo
- **Eje temático:** 🌍 Biodiversidad y Problemas Ambientales Mundiales
- **Herramientas:** R (`sf`, `ggplot2`, `patchwork`, `gifski`, `ragg`, `ggrepel`) + GBIF Occurrence API.
- **Fuentes de datos:**
  - **Charles Darwin (1831–1836):** itinerario del HMS *Beagle*, 43 paradas fechadas y georreferenciadas (Darwin Online, *Beagle* Diary y la cronología del segundo viaje).
  - **Alexander von Humboldt (1799–1804):** expedición americana, 44 paradas, con 19 localidades de la ruta por Nueva España en 1803–1804 (cronología de Charles Minguet, UNAM; *Humboldt's Mexico*).
  - **Alfred Russel Wallace (1848–1862):** Amazonía y archipiélago malayo, 45 paradas (Wallace Online, *The Malay Archipelago*, cronologías del NHM).
  - **Helia Bravo Hollis (1931–1981):** 357 registros de herbario en GBIF (`recordedBy = "Helia Bravo Hollis"`) que, tras deduplicar por fecha y coordenada, dejan **103 localidades fechadas** de colecta de cactáceas en México (MEXU, ENCB y otras colecciones).

## Concepto

El día pide estética **vintage**, y la ruta naturalista del siglo XIX es su forma más honesta: no un mapa de datos contemporáneos disfrazado de sepia, sino **itinerarios reales** dibujados como láminas de atlas. Cuatro naturalistas, cuatro escalas. La cartela del GIF de facetas resume el método en diez palabras: *«Itinerarios fechados, pista temporal acumulativa, proyección Robinson y tramos esquemáticos»*.

| Naturalista | Profesión | Periodo | Escala | Paradas |
| :--- | :--- | :--- | :--- | ---: |
| Charles Darwin | Naturalista | 1831–1836 | Mundo (hemisferio sur) | 43 |
| Alexander von Humboldt | Naturalista y geógrafo | 1799–1804 | América y Nueva España | 44 |
| Alfred Russel Wallace | Naturalista y biogeógrafo | 1848–1862 | Amazonía y Sudeste asiático | 45 |
| Helia Bravo Hollis | Botánica y cactóloga | 1931–1981 | México | 103 |

La animación no interpola un "mapa de calor": **revela la ruta en el tiempo**. Cada fotograma avanza el reloj y dibuja el tramo recorrido hasta ese año, con una cabeza móvil y el año en curso.

## Metodología

1. **Itinerarios curados.** Para Darwin, Humboldt y Wallace se construyó un CSV de paradas con `lugar`, `lat`, `lon`, `fecha_llegada`, `fecha_salida`, `fuente_url` y `nota`. Las fechas con día documentado se conservan; cuando sólo hay mes o año se usa el día 15 o el 1 de julio y se marca en `nota`.
2. **Bravo desde GBIF.** Se descargaron los 357 registros georreferenciados de Helia Bravo Hollis (`day06_bravo_gbif.R`), se filtraron a México, se deduplicaron por fecha y coordenada y se ordenaron cronológicamente. Para evitar los largos vacíos entre campañas (1932–1950) el tiempo se comprime con una **escala ordinal**: cada intervalo entre colectas se cuenta hasta un máximo de 45 días.
3. **Pista densa.** Entre paradas se interpola la posición cada 5 días (3 días en el detalle de Nueva España), respetando las estancias: el punto permanece en el puerto mientras el naturalista está allí.
4. **Cruce del antimeridiano.** Los tramos del Pacífico se cortan en ±180° para que la ruta no atraviese el mapa por el lado equivocado; en la animación se inserta un corte (`NA`) y se dibujan los dos bordes.
5. **Traslados intercontinentales.** En Wallace, los tramos hacia/desde Liverpool y Londres **no se dibujan**: se cortan para que la ruta no atraviese África o el Atlántico. La cartela del GIF lo indica con la frase «vacío: traslado a Europa no dibujado».
6. **Fotogramas.** Cada naturalista se normaliza a 100 fotogramas; se renderiza un PNG por fotograma con `ragg` y se ensambla el GIF con `gifski` (12 fps, pausa final). Esto da control exacto del orden temporal, algo que `gganimate` no garantiza con identificadores de fotograma sin rellenar.
7. **Cartografía.** Proyección de Robinson para las rutas globales y cónica conforme de Lambert centrada en México (`lon_0 = -102`, `lat_0 = 23`) para México. Fondo de papel crema, océano azul atlas desaturado, tierra beige y tipografía Georgia en cursiva.

## Hallazgos

- **Humboldt es el más eficiente:** 44 paradas en 5 años, incluida la ruta mexicana de 1803–1804 que va de Acapulco a Veracruz pasando por Taxco, Cuernavaca, la capital, Guanajuato, Valladolid, Pátzcuaro, el Jorullo, Toluca, Puebla, Perote y Jalapa.
- **Darwin dibuja un hemisferio:** 43 paradas y un solo giro completo, con la densidad concentrada en Patagonia y el cono sur; el Pacífico se cruza en dos saltos largos (Galápagos–Tahití y Tahití–Nueva Zelanda).
- **Wallace es el más dispar:** dos campañas separadas por un regreso a Inglaterra (1852) y un reencuentro con el archipiélago malayo que dura ocho años.
- **Bravo cubre México de forma discontinua:** 103 localidades de herbario, con núcleos en Veracruz, Puebla, Oaxaca y Baja California, y un hueco de casi dos décadas entre sus primeras colectas (1931–1932) y la campaña de 1950.

## Advertencias metodológicas

- **Las rutas son esquemáticas.** Las líneas unen paradas en línea recta (en longitud/latitud), no reproducen la derrota marítima ni el camino real; sirven para leer la secuencia, no la geometría del viaje.
- **Fechas aproximadas.** Humboldt, en particular, tiene varias fechas reconstruidas por cronistas; se marcan en la columna `nota` y no deben citarse como días exactos.
- **Bravo no es una ruta.** Sus 103 puntos son localidades de colecta, no un itinerario continuo: por eso se muestran como puntos acumulados, sin línea.
- **GBIF no es exhaustivo.** La ausencia de registros no implica ausencia de la especie ni de la colecta; el sesgo de digitalización favorece ciertas colecciones (MEXU, ENCB) y estados.

## Archivos generados

- Scripts: [`day06_bravo_gbif.R`](./day06_bravo_gbif.R), [`day06_data_pipeline.R`](./day06_data_pipeline.R), [`day06_animate.R`](./day06_animate.R) y [`day06_poster.R`](./day06_poster.R).
- Datos: `data/raw/day06/*.csv`, `data/processed/day06_bravo.rds` y `data/processed/day06_naturalistas.rds`.
- Itinerarios curados versionados en [`itinerarios/`](./itinerarios/) (`darwin_beagle.csv`, `humboldt_americas.csv`, `wallace_expediciones.csv`); el pipeline los usa como respaldo si no existen en `data/raw/day06/`.
- Salidas:
  - `outputs/high_res/day06_vintage_naturalistas.png` (póster, 300 dpi)
  - `outputs/gallery/day06_vintage_naturalistas.png` (galería)
  - `outputs/high_res/` (GIF a resolución completa, ignorados por Git)
  - `outputs/gallery/` (GIF optimizados para la galería y el `README.md`):
    - `day06_darwin.gif`
    - `day06_humboldt.gif`
    - `day06_humboldt_mexico.gif`
    - `day06_wallace.gif`
    - `day06_bravo.gif`
    - `day06_naturalistas_facetas.gif`

## Reproducir

```powershell
# 1. Datos de Helia Bravo Hollis desde GBIF (requiere red)
& "C:\Program Files\R\R-4.3.2\bin\Rscript.exe" days/day06_vintage/day06_bravo_gbif.R

# 2. Dataset unificado (itinerarios + GBIF)
& "C:\Program Files\R\R-4.3.2\bin\Rscript.exe" days/day06_vintage/day06_data_pipeline.R

# 3. Animaciones (todas o una: darwin, humboldt, mexico, wallace, bravo, facetas)
& "C:\Program Files\R\R-4.3.2\bin\Rscript.exe" days/day06_vintage/day06_animate.R all

# 4. Póster
& "C:\Program Files\R\R-4.3.2\bin\Rscript.exe" days/day06_vintage/day06_poster.R
```

## Vista previa

![Día 06: Cuatro naturalistas, cuatro rutas](../../outputs/gallery/day06_vintage_naturalistas.png)

![Darwin](../../outputs/gallery/day06_darwin.gif)
