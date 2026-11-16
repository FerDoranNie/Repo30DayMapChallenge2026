# Día 15 — Hilo de 5 tweets

Mapa: *El Valle de México al revés* — topografía invertida, vaso lacustre y población.

---

**1/5 — De qué trata**

El Valle de México es una cuenca cerrada: 1,114 km² de lago rodeados de montañas. Para el Día 15 del #30DayMapChallenge (Inside out) invertí el relieve: el fondo del lago es hoy la única cumbre del mapa y las sierras, abismos. 🧵

---

**2/5 — El hallazgo**

Bajo la cota histórica de los lagos (2,245 m) quedan 1,114 km² planos: el 22.3 % del suelo de la ZMVM. Ahí viven 9.4 millones de personas —cada esfera del mapa es un municipio—, el 45.8 % de la metrópoli. El punto más bajo del valle está 27 m por debajo de esa cota.

---

**3/5 — Metodología: los datos**

Datos: Copernicus DEM GLO-30 (30 m, © ESA/Airbus), los 52 municipios de la ZMVM y las AGEB del Censo 2020 (INEGI). Ventana de 74×68 km que deja fuera los volcanes. Proyección Lambert, EPSG:6372.

---

**4/5 — Metodología: las decisiones**

Inversión: z_inv = z_mín + z_máx − z. La escala tiene bisagra en 2,300 m. Cada esfera es un municipio: área proporcional a su población. Los 9.4 M de habitantes del vaso se ponderan por la fracción de cada AGEB dentro del lago. R: terra, sf, ragg.

---

**5/5 — Fuentes y código**

📊 Copernicus DEM GLO-30 (AWS Open Data)
🏙️ INEGI: Marco Geoestadístico y Censo 2020
💻 R: terra, sf, dplyr, ragg
🔗 github.com/FerDoranNie/Repo30DayMapChallenge2026

#30DayMapChallenge #Día15 #México #dataviz

---

## Imágenes sugeridas

1. Póster completo (o detalle de la meseta dorada).
2. Detalle del bloque «El Valle en cifras» y de la cifra de 9.4 millones.
3. Detalle de la leyenda de color.
4. Detalle del mapa con las etiquetas de abismos.
5. Póster completo, otra vez, para cerrar el hilo.

## Texto alternativo (alt text)

Póster vertical de fondo crema titulado «El Valle de México al revés». Al centro, un mapa de relieve del Valle de México con la elevación invertida: el fondo del valle aparece como una meseta dorada y las sierras que lo rodean como abismos azul profundo. Abajo, la cifra destacada de 9.4 millones de personas que viven sobre el vaso lacustre.
