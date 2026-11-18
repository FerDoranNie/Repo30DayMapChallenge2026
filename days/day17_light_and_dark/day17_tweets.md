# Día 17 — Hilo de 5 tweets

Mapa: *Trampas de luz* — la migración nocturna del Golfo de México frente al resplandor de las ciudades (Light & dark).

---

**1/5 — De qué trata**

Cada otoño, millones de aves cruzan el Golfo de México de noche. Cada primavera regresan y amanecen sobre una de las costas más iluminadas del planeta.

Día 17 del #30DayMapChallenge (Light & dark): dos capas, luces en ámbar y aves en magenta. 🧵

---

**2/5 — El hallazgo**

El 6 % del territorio más iluminado concentra el 47 % de los registros de migrantes nocturnos.

Houston es la ciudad más brillante del corredor (0.97) y Tampa la que más aves y especies acumula: 892 registros, 39 especies.

---

**3/5 — El pulso y la oscuridad**

La migración tiene dos pulsos: abril (1.92 M registros) y octubre (0.89 M). Dos veces al año, la misma costa recibe a las aves al amanecer.

Y aun así, el 51 % del corredor sigue por debajo de 0.03 de brillo: todavía hay noche.

---

**4/5 — Metodología**

Luces: NASA Black Marble / VIIRS (compuesto anual vía NASA GIBS). Aves: 45 especies de migrantes nocturnos de eBird (Cornell Lab) vía GBIF.

De 2.23 M registros de ago–nov (2016–2025) muestreé 62,042 puntos, estratificados por especie, mes y año.

---

**5/5 — Decisiones, fuentes y código**

Técnico: brillo sin el pedestal del render e índice de trampa = brillo × aves en 25 km.

📊 NASA GIBS · 🐦 eBird vía GBIF · 🗺️ Natural Earth
💻 Python: numpy, scipy, matplotlib
🔗 github.com/FerDoranNie/Repo30DayMapChallenge2026

#30DayMapChallenge #Día17 #Aves

---

## Imágenes sugeridas

1. Póster completo.
2. Recorte del mapa nocturno (costa de Texas–Luisiana y Yucatán, con la leyenda ámbar/magenta).
3. Recorte del panel «El pulso anual de la migración».
4. Recorte del panel «La trampa: mucha luz, muchos migrantes».
5. Póster completo, otra vez, para cerrar el hilo.

## Texto alternativo (alt text)

Póster horizontal de fondo crema titulado «Trampas de luz». A la izquierda, un mapa nocturno del Golfo de México en negro profundo: las luces de las ciudades brillan en ámbar y las zonas con más registros de aves migratorias se encienden en magenta, con puntos blancos donde ambas capas coinciden. A la derecha, tres paneles de fondo crema: una curva anual con picos en abril y octubre, una dispersión de ciudades según brillo y migrantes, y un gráfico de barras que contrasta el territorio disponible con los registros por clase de brillo.
