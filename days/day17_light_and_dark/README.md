# Día 17 — Light & dark (17 de noviembre de 2026)

- **Eje temático:** 🦜 Aves
- **Concepto del mapa:** *Trampas de luz* — la migración nocturna del Golfo de México frente al resplandor de las ciudades
- **Fuentes de datos:**
  - **NASA Black Marble / VIIRS Day–Night Band** (compuesto anual 2016), servido por **NASA GIBS** (WMS `VIIRS_Black_Marble`)
  - **eBird Basic Dataset** (Cornell Lab of Ornithology) vía la **API de ocurrencias de GBIF** (`datasetKey=4fa7b334-ce0d-4e88-aaae-2e0c138d049e`)
  - **Natural Earth 50m** (países y provincias/estados) para la base cartográfica
- **Recorte:** 14.0–32.5 °N / 104.5–80.0 °O (Golfo de México, península de Yucatán y costa norte del Golfo)

## Notas y Metodología

### 1. Luces nocturnas (`day17_data_pipeline.py`)

- Se descargó el compuesto anual **VIIRS Black Marble** por `GetMap` de NASA GIBS (EPSG:4326, 2 600 × 2 133 px), y se convirtió a **luminancia perceptual** (`0.2126R + 0.7152G + 0.0722B`).
- Al producto se le descuenta el **pedestal del render** (0.0123 en mar y 0.027 en tierra) para que las zonas sin alumbrado queden efectivamente en negro; ese suelo es el que permite separar *oscuridad real* de *penumbra*.
- **51 % del área continental** del corredor permanece por debajo de `0.03` de brillo (22 % en oscuridad casi total + 29 % en penumbra).

### 2. Migrantes nocturnos (eBird vía GBIF)

- Se seleccionaron **45 especies** de migratorias neotropicales de **vuelo nocturno obligado** (parúlidos, zorzales, vireos, tiránidos, chotacabras, colibríes), las mismas que protagonizan el cruce trans-Golfo.
- Se consultaron las facetas mensuales de las 45 especies dentro del corredor y se aisló la **temporada de otoño (agosto–noviembre, 2016–2025)**, con un pool de **2 234 632 registros**.
- El paginado profundo de la API de GBIF degrada hasta el *timeout* (se comprobó con offsets de decenas de miles), así que el muestreo se **estratificó por especie, mes y año** con offsets cortos (0–600): **540 bloques de 300 registros** → **62 042 puntos únicos**.
- En el póster cada especie pesa lo mismo (peso `1/n`), de modo que el índice de presencia no está dominado por las especies más registradas.

### 3. Índice de trampa de luz (ITL)

Para cada ciudad del corredor se calculó, en un buffer de **25 km**:

- `brillo` = luminancia media del compuesto Black Marble;
- `migrantes` = número de registros de las 45 especies;
- `riqueza` = número de especies distintas;
- `ITL = sqrt(norm(brillo) · norm(log(1+migrantes)))`.

| Ciudad | Brillo | Registros | Riqueza | ITL |
| :--- | ---: | ---: | ---: | ---: |
| Houston | 0.97 | 337 | 30 | 0.91 |
| Tampa | 0.72 | 892 | 39 | 0.86 |
| Baton Rouge | 0.61 | 419 | 34 | 0.73 |
| New Orleans | 0.50 | 517 | 34 | 0.67 |
| Mobile | 0.45 | 224 | 34 | 0.58 |
| Pensacola | 0.35 | 418 | 39 | 0.54 |
| Mérida | 0.38 | 194 | 28 | 0.52 |
| Corpus Christi | 0.34 | 234 | 33 | 0.50 |

### 4. Hallazgos principales

- **El doble pulso:** abril concentra **1.92 M** registros (retorno primaveral) y octubre **0.89 M** (salida otoñal); en ambos picos las aves vuelan de noche y amanecen sobre la misma costa iluminada.
- **La asimetría luz / aves:** el **6 %** del territorio más iluminado (clase *Metrópolis*) concentra el **47 %** de los registros de migrantes, mientras que el **51 %** del territorio en oscuridad o penumbra apenas reúne el **28 %**.
- **El corredor es binario:** de la Sierra Madre Oriental y el Petén —donde todavía se puede ver la Vía Láctea— a la costa de Texas/Luisiana, la luz artificial crece en dos órdenes de magnitud en menos de 300 km.

### 5. Diseño

- Estilo **Atlas Enmarcado** del repositorio: papel crema `#F7F4EB`, tipografía oscura y marco fino tipo lámina.
- Los paneles nocturnos invierten la paleta de forma deliberada (tema *Light & dark*): fondo `#05080F`, luces en ámbar `#FFB347` y migrantes en magenta `#FF4FA3`, con **mezcla aditiva tipo *screen*** (donde coinciden luz y aves, el píxel se vuelve blanco = "trampa de luz").
- Salidas: `outputs/high_res/day17_light_and_dark_trampas_de_luz.png` (4 950 × 3 300 px) y `outputs/gallery/day17_light_and_dark_trampas_de_luz.png` (1 600 px).

## Reproducir

```bash
# 1) datos
python days/day17_light_and_dark/day17_data_pipeline.py

# 2) póster
python days/day17_light_and_dark/day17_poster.py
```
