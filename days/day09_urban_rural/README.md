# Día 09 — Urban-rural (09 de noviembre de 2026)

- **Título:** La frontera que devora el bosque: 50 años de expansión metropolitana sobre ecosistemas y tierras rurales en México (1975–2025)
- **Eje temático:** 🇲🇽 México (Demografía, Sociedad y Medio Ambiente)
- **Formato de salida:** 🎞️ **Animación `.gif` y `.mp4`** (evolución multitemporal) + 🖼️ **Póster estático `.png`** (mapa bivariado de síntesis 300 dpi).
- **Herramientas utilizadas:** R 4.3.2 (`terra`, `sf`, `ggplot2`, `biscale`, `patchwork`, `ragg`, `gifski`, `av`).
- **Fuentes de datos:**
  1. **Global Human Settlement Layer (GHSL JRC R2023A, `GHS_BUILT_S`):** Crecimiento histórico de la superficie construida en 6 épocas decenales (1975, 1985, 1995, 2005, 2015 y 2025) a 3 segundos de arco (~100 m) y 30 segundos de arco (~900 m).
  2. **INEGI — Uso del Suelo y Vegetación (Serie VII, 1:250,000):** Clasificación ecológica en bosque templado/selva, matorral submontano, suelo agrícola y cuerpos de agua.
  3. **Marco Geoestadístico INEGI:** Límites estatales y delimitación oficial de zonas metropolitanas proyectadas en **Cónica Conforme de Lambert (`EPSG:6372`)**.

---

## 🎯 Resumen Ejecutivo y Hallazgos Cartográficos

La transición **urbano-rural** en México no es una línea fronteriza estática, sino una **onda expansiva centrífuga** (*urban sprawl*) que en el último medio siglo ha multiplicado de forma crítica la huella construida de las metrópolis, devorando ecosistemas primarios y tierras rurales productivas:

1. **La Costa Maya (Cancún–Riviera Maya):** Registra el crecimiento más vertiginoso del país con un incremento de **+556%** en su huella urbana desde 1975 (pasando de apenas 21.3 km² de campamentos e infraestructura pionera a 139.7 km²), habiendo devorado directamente más de 10.2 km² de selva mediana y manglares costeros.
2. **El Norte Industrial (Monterrey):** Triplicó su tamaño (+202%, de 276.6 km² a 835.4 km²), escalando sobre el piedemonte de la Sierra Madre Oriental y consumiendo 55.6 km² de matorral submontano y áreas contiguas al Parque Nacional Cumbres de Monterrey.
3. **El Bajío / Occidente (Guadalajara):** Creció un +162% (de 308.7 km² a 808.3 km²), cercando por el poniente el Área de Protección de Flora y Fauna La Primavera y devorando 488.4 km² de valles agrícolas de alta fertilidad en Zapopan, Tlajomulco y Tlaquepaque.
4. **La Península Kárstica (Mérida):** Creció un +200% (de 122.5 km² a 367.6 km²), con un modelo de lotificación horizontal expansivo sobre la selva baja caducifolia del norte de Yucatán.
5. **El Valle de México:** Por su gran base histórica consolidada (1,313 km² en 1975), creció un +39.1% en porcentaje relativo pero absorbió **513.8 km² netos** de territorio periurbano hacia el oriente lacustre (antiguo Lago de Texcoco/Chimalhuacán) y hacia el Bosque de Agua en las laderas del sur y poniente.
6. **El Valle Poblano–Tlaxcalteca (Puebla–Tlaxcala):** Creció un +124% (de 326.1 km² a 730.8 km²), conurbando decenas de municipios rurales y absorbiendo más de 402 km² de tierras de labor hacia las faldas de La Malinche y el Iztaccíhuatl.

---

## 📊 Métricas Consolidadas por Zona Metropolitana (1975 vs 2025)

| Región Metropolitana | Ecosistema / Zona de Fricción | Sup. Urbana 1975 (km²) | Sup. Urbana 2025 (km²) | Crecimiento Absoluto (km²) | Crecimiento Relativo (%) | Bosque / Selva Absorbido (km²) | Suelo Agrícola Absorbido (km²) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Valle de México** | Bosque templado y lecho lacustre | 1,313.1 | 1,826.9 | +513.8 | **+39.1%** | 29.5 | 484.3 |
| **2. Monterrey** | Matorral submontano y piedemonte Sierra Madre | 276.6 | 835.4 | +558.8 | **+202.0%** | **55.6** | 503.2 |
| **3. Guadalajara** | Bosque La Primavera y valles agrícolas | 308.7 | 808.3 | +499.6 | **+161.8%** | 11.2 | 488.4 |
| **4. Mérida** | Selva baja caducifolia y karst | 122.5 | 367.6 | +245.1 | **+200.1%** | 20.4 | 224.7 |
| **5. Cancún – Riviera Maya** | Selva mediana y manglares costeros | 21.3 | 139.7 | +118.4 | **+555.9%** | 10.2 | 108.2 |
| **6. Puebla – Tlaxcala** | Valle agrícola y faldas volcánicas | 326.1 | 730.8 | +404.7 | **+124.1%** | 2.0 | 402.7 |

---

## 🎨 Arquitectura de Visualización y Paleta Editorial

El mapa aplica rigurosamente el **Estilo Atlas Enmarcado** del repositorio:
- **Lienzo Exterior:** Papel crema editorial (`#F7F4EB`), con tipografía oscura en pizarra profunda (`#0F172A`) y gris editorial (`#334155` / `#475569`).
- **Océanos y Fondo del Panel:** Azul atlas pálido (`#DCE6F2`) con borde cartográfico continuo en `#94A3B8`.
- **Panel A (Nacional Bivariado 3×3):** Malla hexagonal de 12 km en Cónica Conforme de Lambert (`EPSG:6372`) cruzando la **Presión Urbana** (Eje X) con la **Cobertura Natural Remanente** (Eje Y) mediante la paleta `biscale::bi_scale_fill(pal = "DkBlue2", dim = 3)`. La esquina `3-3` revela los anillos críticos de tensión urbana-ecológica.
- **Panel B (6 Insets Metropolitanos):**
  - **Huella Urbana Histórica (1975):** Pizarra grafito profundo (`#1E293B`).
  - **Frente de Expansión (1975 → 2025):** Carmín/fuego incandescente (`#EF4444`).
  - **Bosque / Selva / Matorral:** Verde bosque profundo (`#1B4332`).
  - **Suelo Agrícola / Rural:** Ocre crema editorial suave (`#E9DFC8`).
  - **Cuerpos de Agua:** Azul lacustre (`#A5C4D4`).

---

## 📂 Archivos y Entregables

```bash
days/day09_urban_rural/
├── day09_data_pipeline.R  # Descarga GHSL, cruce con USV y cálculo de métricas
├── day09_poster.R         # Generación del póster estático (alta res y galería)
├── day09_animate.R        # Generación de fotogramas y ensamblado en GIF y MP4
└── README.md              # Documentación técnica y métricas

outputs/
├── high_res/
│   └── day09_urban_rural_frontera_bosque.png  # 300 dpi (15 x 19 in, 5.0 MB)
└── gallery/
    ├── day09_urban_rural_frontera_bosque.png  # 150 dpi (1.8 MB)
    ├── day09_urban_rural_expansion.gif        # Animación multitemporal optimizada
    └── day09_urban_rural_expansion.mp4        # Video HD (framerate = 2 fps)
```
