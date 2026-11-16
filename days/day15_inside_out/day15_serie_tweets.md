# Día 15 — Hilo de 5 tweets · Serie metropolitana

Video/mapa: *Cuatro ciudades al revés* — Valle de México, Monterrey, Guadalajara y Puebla.

---

**1/5 — De qué trata**

Cuatro ciudades mexicanas vistas al revés: donde está la mancha urbana, el mapa pone la cumbre; donde están las sierras, pone abismos. Día 15 del #30DayMapChallenge (Inside out): 4 mapas y un video de 40 segundos. 🧵

---

**2/5 — El hallazgo**

En las cuatro, la ciudad ocupa el punto más bajo y plano de su valle: por eso, al invertir el relieve, se vuelve la cima. Sumadas son 105 municipios y 33.7 millones de personas. Monterrey tiene 3,408 m de desnivel; Puebla, La Malinche a 4,393 m.

---

**3/5 — Metodología: los datos**

Copernicus DEM GLO-30 (Valle de México) y GLO-90 (resto), © ESA/Airbus. Municipios y AGEB del INEGI (Marco Geoestadístico y Censo 2020). Agua: ríos, canales y presas de OpenStreetMap. Ventanas de ~74 × 68 km en Lambert, EPSG:6372.

---

**4/5 — Metodología: las decisiones**

La bisagra de color es la cota urbana de cada ciudad (centroide poblacional + 120 m): debajo, meseta de oro; arriba, la rampa azul de las sierras. Cada esfera es un municipio con área proporcional a su población. Arriba a la derecha, el mapa real con el agua.

---

**5/5 — Video y código**

🎬 40 s, 10 s por ciudad, 1080 × 1440
💻 R (terra, sf, ragg) + OpenStreetMap + OpenCV
🔗 github.com/FerDoranNie/Repo30DayMapChallenge2026

#30DayMapChallenge #Día15 #México #dataviz

---

## Imágenes sugeridas

1. Video completo (o el póster de Valle de México).
2. Los cuatro pósters en cuadrícula, o el detalle de las cifras.
3. Detalle del mapa tradicional con agua (arriba a la derecha).
4. Detalle de la leyenda y las esferas.
5. Póster de Puebla con La Malinche como abismo, para cerrar.

## Texto alternativo (alt text)

Cuatro pósters verticales de fondo crema, uno por ciudad. En cada uno, el mapa principal muestra el relieve invertido: la mancha urbana como una meseta dorada y las sierras como abismos azul profundo, con esferas de población por municipio. Arriba a la derecha, un mapa tradicional en verdes con los ríos y presas en azul.
