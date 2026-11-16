"""
Día 14 — Borgesian map: El Aleph de las Ecorregiones
Mapa caligráfico de México formado por nombres científicos reales (GBIF)
inscritos dentro de las 45 ecorregiones del país.

Autor: Fernando Dorantes Nieto (@FerDoranNie)
Reto: #30DayMapChallenge 2026 — 14 de noviembre de 2026
"""

import json
import os
import random
import time
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from shapely.geometry import shape, Polygon, MultiPolygon

# -----------------------------------------------------------------------------
# 1. Configuración y Paleta Editorial (Estilo Atlas Enmarcado)
# -----------------------------------------------------------------------------
SEED = 20261114
random.seed(SEED)
np.random.seed(SEED)

ECO_GEOJSON = "data/processed/day14_eco_6372.geojson"
MEX_GEOJSON = "data/processed/day14_mex_6372.geojson"
SPECIES_JSON = "data/processed/day14_gbif_species_by_eco.json"

OUT_HIGH = "outputs/high_res/day14_borgesian_map_aleph.png"
OUT_GALLERY = "outputs/gallery/day14_borgesian_map_aleph.png"

# Dimensiones del póster (14 x 10.2 in @ 300 DPI)
W, H = 4200, 3060

# Colores base del repositorio
PAPEL = (247, 244, 235)      # #F7F4EB
OCEANO = (220, 230, 242)     # #DCE6F2
TIERRA = (250, 247, 238)     # #FAF7EE (pergamino muy sutil bajo la caligrafía)
MARCO = (148, 163, 184)      # #94A3B8
RETICULA = (184, 199, 217)   # #B8C7D9
TINTA = (15, 23, 42)         # #0F172A
GRIS2 = (51, 65, 85)         # #334155
GRIS = (71, 85, 105)         # #475569
BORDE_ECO = (203, 213, 225)  # #CBD5E1
BORDE_MEX = (100, 116, 139)  # #64748B

# Paleta de 7 biomas (alto contraste sobre pergamino claro)
BIOME_COLORS = {
    "Desiertos y matorrales xéricos":    (180, 83, 9),     # #B45309 Terracota / Ocre
    "Bosques tropicales de coníferas":   (22, 101, 52),    # #166534 Verde pino profundo
    "Selvas húmedas tropicales":         (4, 120, 87),     # #047857 Esmeralda selva
    "Selvas secas tropicales":           (161, 98, 7),     # #A16207 Ámbar siena
    "Manglares":                         (3, 105, 161),    # #0369A1 Azul manglar
    "Bosque y matorral mediterráneo":    (126, 34, 206),   # #7E22CE Ciruela botánica
    "Sabanas tropicales":                (77, 124, 15),    # #4D7C0F Oliva bronce
}

# Fuentes (Georgia editorial)
FONT_REG = "C:/Windows/Fonts/georgia.ttf"
FONT_BOLD = "C:/Windows/Fonts/georgiab.ttf"
FONT_ITAL = "C:/Windows/Fonts/georgiai.ttf"
FONT_B_ITAL = "C:/Windows/Fonts/georgiaz.ttf"

# Caja del mapa dentro del lienzo (deja margen para encabezado y pie)
MAP_X0, MAP_Y0 = 130, 315
MAP_X1, MAP_Y1 = W - 130, H - 175
MAP_W = MAP_X1 - MAP_X0
MAP_H = MAP_Y1 - MAP_Y0


def load_font(path, size):
    return ImageFont.truetype(path, max(1, int(round(size))))


def world_to_px(x, y, xmin, ymin, scale, off_x, off_y):
    px = off_x + (x - xmin) * scale
    py = off_y - (y - ymin) * scale
    return px, py


def geom_to_px_polys(geom, xmin, ymin, scale, off_x, off_y):
    """Convierte geometría Shapely (Polygon/MultiPolygon) a listas de puntos en píxeles."""
    polys = []
    if isinstance(geom, Polygon):
        geoms = [geom]
    elif isinstance(geom, MultiPolygon):
        geoms = list(geom.geoms)
    else:
        return polys

    for g in geoms:
        if g.is_empty:
            continue
        ext = [world_to_px(x, y, xmin, ymin, scale, off_x, off_y) for x, y in g.exterior.coords]
        holes = [
            [world_to_px(x, y, xmin, ymin, scale, off_x, off_y) for x, y in ring.coords]
            for ring in g.interiors
        ]
        polys.append((ext, holes))
    return polys


def rasterize_eco_mask(px_polys, width, height):
    """Crea una máscara booleana (H, W) del polígono de la ecorregión."""
    mask_img = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask_img)
    for ext, holes in px_polys:
        if len(ext) >= 3:
            draw.polygon(ext, fill=255)
        for h in holes:
            if len(h) >= 3:
                draw.polygon(h, fill=0)
    return np.array(mask_img) > 127


def render_word_patch(text, font, angle, pad=2):
    """Renderiza una palabra rotada en un parche alfa recortado."""
    dummy = Image.new("L", (1, 1), 0)
    dd = ImageDraw.Draw(dummy)
    bbox = dd.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    if tw <= 0 or th <= 0:
        return None
    patch = Image.new("L", (tw + 8, th + 8), 0)
    pd = ImageDraw.Draw(patch)
    pd.text((4 - bbox[0], 4 - bbox[1]), text, font=font, fill=255)
    if angle != 0:
        patch = patch.rotate(angle, resample=Image.BICUBIC, expand=True)
    # Recortar al bounding box real de píxeles no nulos
    nz = patch.getbbox()
    if nz is None:
        return None
    patch = patch.crop(nz)
    arr = np.array(patch)
    # Máscara de colisión ligeramente dilatada (pad)
    if pad > 0:
        dil = patch.filter(ImageFilter.MaxFilter(2 * pad + 1))
        col_mask = np.array(dil) > 20
    else:
        col_mask = arr > 20
    return patch, arr, col_mask


def place_calligraphy_in_eco(
    canvas,
    eco_mask,
    occupied_mask,
    species_list,
    base_color,
    area_km2,
    font_cache,
):
    """Empaqueta nombres científicos dentro de la máscara exacta de una ecorregión."""
    ys, xs = np.where(eco_mask)
    n_px = len(xs)
    if n_px < 120:
        return 0

    # Calcular tamaño de fuente según el área en píxeles de la ecorregión
    sqrt_px = np.sqrt(n_px)
    max_fs = int(np.clip(sqrt_px * 0.095, 10, 32))
    mid_fs = int(np.clip(sqrt_px * 0.048, 8, 15))
    min_fs = int(np.clip(sqrt_px * 0.026, 5, 9))

    # Construir cola de palabras en 3 niveles jerárquicos (alta densidad Borgesian)
    n_t1 = max(1, min(6, int(n_px / 18000) + 1))
    n_t2 = max(10, min(85, int(n_px / 1400)))
    n_t3 = max(35, min(520, int(n_px / 220)))

    queue = []
    n_sp = len(species_list)
    for i in range(n_t1):
        sp = species_list[i % n_sp]["species"]
        fs = int(max_fs * (0.94 ** i))
        queue.append((sp, max(min_fs + 2, fs), "b_ital", 245, 0))
    for i in range(n_t2):
        sp = species_list[(i + n_t1) % n_sp]["species"]
        fs = int(mid_fs * random.uniform(0.85, 1.12))
        ang = random.choice([0, 0, -12, 12, -22, 22])
        queue.append((sp, max(min_fs + 1, fs), "ital", random.randint(205, 238), ang))
    for i in range(n_t3):
        sp = species_list[(i * 7 + 3) % n_sp]["species"]
        fs = int(min_fs * random.uniform(0.90, 1.20))
        ang = random.choice([0, 0, 0, -15, 15, -28, 28, -40, 40])
        queue.append((sp, max(5, fs), "ital", random.randint(160, 210), ang))

    placed = 0
    # Pre-muestrear índices candidatos dentro de la ecorregión
    cx, cy = int(np.mean(xs)), int(np.mean(ys))

    for idx_word, (sp, fs, style, alpha, ang) in enumerate(queue):
        key = (style, fs, ang, sp)
        if key not in font_cache:
            fpath = FONT_B_ITAL if style == "b_ital" else FONT_ITAL
            font = load_font(fpath, fs)
            res = render_word_patch(sp, font, ang, pad=1 if fs <= 11 else 2)
            font_cache[key] = res
        res = font_cache[key]
        if res is None:
            continue

        patch, arr, col_mask = res
        ph, pw = col_mask.shape
        if ph >= MAP_H or pw >= MAP_W:
            continue

        # Número de intentos según nivel
        n_tries = 110 if idx_word < n_t1 else (75 if idx_word < n_t1 + n_t2 else 55)
        ok = False

        # Ordenar candidatos: cerca del centroide para Tier 1, aleatorio para Tier 2-3
        if idx_word < n_t1:
            # Muestrear cerca del centroide primero
            cand_idx = np.random.randint(0, n_px, size=n_tries)
            dists = (xs[cand_idx] - cx) ** 2 + (ys[cand_idx] - cy) ** 2
            cand_idx = cand_idx[np.argsort(dists)]
        else:
            cand_idx = np.random.randint(0, n_px, size=n_tries)

        for ci in cand_idx:
            px = xs[ci] - pw // 2
            py = ys[ci] - ph // 2
            if px < 0 or py < 0 or px + pw >= MAP_W or py + ph >= MAP_H:
                continue

            sub_eco = eco_mask[py : py + ph, px : px + pw]
            # La palabra debe quedar prácticamente 100% dentro de la ecorregión
            if not np.all(sub_eco[col_mask]):
                continue

            sub_occ = occupied_mask[py : py + ph, px : px + pw]
            if np.any(sub_occ & col_mask):
                continue

            # ¡Colocar palabra!
            occupied_mask[py : py + ph, px : px + pw] |= col_mask
            color_rgba = (*base_color, alpha)
            color_img = Image.new("RGBA", (pw, ph), color_rgba)
            canvas.paste(color_img, (MAP_X0 + px, MAP_Y0 + py), patch)
            placed += 1
            ok = True
            break

        # Si un nombre largo no cupo horizontal/rotado, probar solo el género o más pequeño no; simplemente seguir
        if not ok and idx_word < n_t1:
            # Intentar con tamaño reducido al 75% para Tier 1
            fs2 = max(7, int(fs * 0.72))
            font2 = load_font(FONT_B_ITAL, fs2)
            res2 = render_word_patch(sp, font2, 0, pad=1)
            if res2 is not None:
                patch2, _, col_mask2 = res2
                ph2, pw2 = col_mask2.shape
                for ci in np.random.randint(0, n_px, size=60):
                    px = xs[ci] - pw2 // 2
                    py = ys[ci] - ph2 // 2
                    if px < 0 or py < 0 or px + pw2 >= MAP_W or py + ph2 >= MAP_H:
                        continue
                    if np.all(eco_mask[py : py + ph2, px : px + pw2][col_mask2]) and not np.any(
                        occupied_mask[py : py + ph2, px : px + pw2] & col_mask2
                    ):
                        occupied_mask[py : py + ph2, px : px + pw2] |= col_mask2
                        color_img = Image.new("RGBA", (pw2, ph2), (*base_color, alpha))
                        canvas.paste(color_img, (MAP_X0 + px, MAP_Y0 + py), patch2)
                        placed += 1
                        break

    return placed


def draw_dashed_line(draw, p1, p2, color, width=2, dash=8, gap=6):
    x1, y1 = p1
    x2, y2 = p2
    dist = np.hypot(x2 - x1, y2 - y1)
    if dist == 0:
        return
    dx, dy = (x2 - x1) / dist, (y2 - y1) / dist
    cur = 0.0
    while cur < dist:
        nxt = min(cur + dash, dist)
        draw.line(
            [(x1 + dx * cur, y1 + dy * cur), (x1 + dx * nxt, y1 + dy * nxt)],
            fill=color,
            width=width,
        )
        cur += dash + gap


def main():
    t0 = time.time()
    print("=" * 72)
    print(" [DÍA 14] Generando póster: El Aleph de las Ecorregiones (Borgesian map)")
    print("=" * 72)

    with open(ECO_GEOJSON, encoding="utf-8") as f:
        eco_gj = json.load(f)
    with open(MEX_GEOJSON, encoding="utf-8") as f:
        mex_gj = json.load(f)
    with open(SPECIES_JSON, encoding="utf-8") as f:
        sp_data = json.load(f)

    # Calcular frecuencia de cada especie entre ecorregiones para priorizar especies distintivas
    sp_eco_freq = {}
    for eco_name, info in sp_data["ecoregions"].items():
        for item in info["species"]:
            sp = item["species"]
            sp_eco_freq[sp] = sp_eco_freq.get(sp, 0) + 1

    # Construir pools por bioma como respaldo para las 3 ecorregiones sin conteo directo
    biome_pool = {}
    for eco_name, info in sp_data["ecoregions"].items():
        b = info["bioma_es"]
        biome_pool.setdefault(b, [])
        biome_pool[b].extend(info["species"])
    # Deduplicar pools por bioma ordenados por distintividad
    for b in biome_pool:
        seen = set()
        dedup = []
        for item in sorted(
            biome_pool[b],
            key=lambda x: -(x["count"] / (sp_eco_freq.get(x["species"], 1) ** 1.35)),
        ):
            if item["species"] not in seen:
                seen.add(item["species"])
                dedup.append(item)
        biome_pool[b] = dedup

    # Calcular bounding box en EPSG:6372
    mex_geom = shape(mex_gj["features"][0]["geometry"])
    xmin, ymin, xmax, ymax = mex_geom.bounds
    dx = xmax - xmin
    dy = ymax - ymin
    # Añadir respiro oceánico
    xmin -= 0.06 * dx
    xmax += 0.06 * dx
    ymin -= 0.05 * dy
    ymax += 0.04 * dy

    scale = min(MAP_W / (xmax - xmin), MAP_H / (ymax - ymin))
    used_w = (xmax - xmin) * scale
    used_h = (ymax - ymin) * scale
    off_x = (MAP_W - used_w) / 2.0
    off_y = MAP_H - (MAP_H - used_h) / 2.0

    # Crear lienzo principal RGBA
    img = Image.new("RGBA", (W, H), (*PAPEL, 255))
    draw = ImageDraw.Draw(img)

    # 1. Marco del mapa y océano azul atlas pálido
    draw.rectangle([MAP_X0, MAP_Y0, MAP_X1, MAP_Y1], fill=(*OCEANO, 255), outline=(*MARCO, 255), width=2)

    # Retícula sutil proyectada aproximada (líneas guía cada 500 km en EPSG:6372)
    gx_start = int(np.ceil(xmin / 500000) * 500000)
    for gx in range(gx_start, int(xmax), 500000):
        px, _ = world_to_px(gx, ymin, xmin, ymin, scale, off_x, off_y)
        if 0 <= px <= MAP_W:
            draw.line([(MAP_X0 + px, MAP_Y0 + 2), (MAP_X0 + px, MAP_Y1 - 2)], fill=(*RETICULA, 160), width=1)
    gy_start = int(np.ceil(ymin / 500000) * 500000)
    for gy in range(gy_start, int(ymax), 500000):
        _, py = world_to_px(xmin, gy, xmin, ymin, scale, off_x, off_y)
        if 0 <= py <= MAP_H:
            draw.line([(MAP_X0 + 2, MAP_Y0 + py), (MAP_X1 - 2, MAP_Y0 + py)], fill=(*RETICULA, 160), width=1)

    # 2. Dibujar silueta base de México y límites suaves de ecorregiones
    mex_polys = geom_to_px_polys(mex_geom, xmin, ymin, scale, off_x, off_y)
    for ext, holes in mex_polys:
        ext_abs = [(MAP_X0 + x, MAP_Y0 + y) for x, y in ext]
        if len(ext_abs) >= 3:
            draw.polygon(ext_abs, fill=(*TIERRA, 255))

    eco_features = sorted(eco_gj["features"], key=lambda f: f["properties"]["area_km2"])
    eco_px_list = []
    for feat in eco_features:
        g = shape(feat["geometry"])
        polys = geom_to_px_polys(g, xmin, ymin, scale, off_x, off_y)
        eco_px_list.append((feat["properties"], polys))
        for ext, _ in polys:
            ext_abs = [(MAP_X0 + x, MAP_Y0 + y) for x, y in ext]
            if len(ext_abs) >= 3:
                draw.line(ext_abs + [ext_abs[0]], fill=(*BORDE_ECO, 190), width=1)

    for ext, _ in mex_polys:
        ext_abs = [(MAP_X0 + x, MAP_Y0 + y) for x, y in ext]
        if len(ext_abs) >= 3:
            draw.line(ext_abs + [ext_abs[0]], fill=(*BORDE_MEX, 220), width=2)

    # 3. Empaquetado caligráfico por ecorregión (de menor a mayor área)
    print("[1/3] Renderizando caligrafía taxonómica en las 45 ecorregiones...")
    occupied_mask = np.zeros((MAP_H, MAP_W), dtype=bool)
    font_cache = {}
    total_words = 0

    for props, polys in eco_px_list:
        eco_name = props["ECO_NAME"]
        bioma = props["bioma_es"]
        area_km2 = props["area_km2"]
        color = BIOME_COLORS.get(bioma, TINTA)

        sp_list = sp_data["ecoregions"].get(eco_name, {}).get("species", [])
        if len(sp_list) < 25:
            sp_list = biome_pool.get(bioma, sp_list)
        if not sp_list:
            continue
        sp_list = sorted(
            sp_list,
            key=lambda x: -(x["count"] / (sp_eco_freq.get(x["species"], 1) ** 1.35)),
        )

        eco_mask = rasterize_eco_mask(polys, MAP_W, MAP_H)
        n_placed = place_calligraphy_in_eco(
            img, eco_mask, occupied_mask, sp_list, color, area_km2, font_cache
        )
        total_words += n_placed

    print(f"      Total de nombres científicos inscritos en el mapa: {total_words:,}")

    # 4. Lente Borgesian ("EL ALEPH") en el Pacífico Sur-Oeste (zoom 3.5x sobre Oaxaca/Tehuacán)
    print("[2/3] Construyendo lente microscópica 'El Aleph'...")
    # Punto focal en Oaxaca / Valle de Tehuacán-Sierra Madre del Sur (aprox lon -97.0, lat 17.5 -> px)
    # Usamos coordenadas aproximadas en EPSG:6372: x ~ 3,020,000, y ~ 650,000 (ajustado relativo al bbox de México)
    fx_world = xmin + 0.655 * (xmax - xmin)
    fy_world = ymin + 0.255 * (ymax - ymin)
    fx_px, fy_px = world_to_px(fx_world, fy_world, xmin, ymin, scale, off_x, off_y)
    fx_abs, fy_abs = int(MAP_X0 + fx_px), int(MAP_Y0 + fy_px)

    # Recortar región cuadrada alrededor del punto focal y ampliar 3.2x dentro de un círculo
    crop_r = 95
    lens_r = 285
    lens_cx, lens_cy = MAP_X0 + 440, MAP_Y1 - 435

    crop_box = (fx_abs - crop_r, fy_abs - crop_r, fx_abs + crop_r, fy_abs + crop_r)
    patch_zoom = img.crop(crop_box).resize((lens_r * 2, lens_r * 2), Image.LANCZOS)

    # Máscara circular para la lente
    lens_mask = Image.new("L", (lens_r * 2, lens_r * 2), 0)
    ImageDraw.Draw(lens_mask).ellipse([0, 0, lens_r * 2 - 1, lens_r * 2 - 1], fill=255)

    # Sombra sutil y fondo de la lente
    draw.ellipse(
        [lens_cx - lens_r - 6, lens_cy - lens_r - 6, lens_cx + lens_r + 6, lens_cy + lens_r + 6],
        fill=(*PAPEL, 255),
        outline=(*TINTA, 220),
        width=3,
    )
    img.paste(patch_zoom, (lens_cx - lens_r, lens_cy - lens_r), lens_mask)
    draw.ellipse(
        [lens_cx - lens_r, lens_cy - lens_r, lens_cx + lens_r, lens_cy + lens_r],
        outline=(*MARCO, 255),
        width=2,
    )

    # Aro indicador en el mapa y línea conectora
    draw.ellipse(
        [fx_abs - crop_r, fy_abs - crop_r, fx_abs + crop_r, fy_abs + crop_r],
        outline=(*TINTA, 200),
        width=2,
    )
    draw_dashed_line(
        draw,
        (lens_cx + int(lens_r * 0.72), lens_cy - int(lens_r * 0.68)),
        (fx_abs - int(crop_r * 0.75), fy_abs + int(crop_r * 0.65)),
        (*GRIS, 200),
        width=2,
    )

    # Etiqueta de la lente
    f_lens_t = load_font(FONT_BOLD, 24)
    f_lens_s = load_font(FONT_ITAL, 20)
    draw.text((lens_cx, lens_cy - lens_r - 44), "EL ALEPH (Detalle 3×)", font=f_lens_t, fill=(*TINTA, 255), anchor="mm")
    draw.text((lens_cx, lens_cy + lens_r + 24), "Sierra Madre del Sur · Oaxaca y Tehuacán", font=f_lens_s, fill=(*GRIS2, 255), anchor="mm")

    # 5. Etiquetas de mares, cita de Borges, leyenda de biomas y elementos cartográficos
    f_mare = load_font(FONT_ITAL, 26)
    draw.text((MAP_X0 + 420, MAP_Y0 + 620), "OCÉANO PACÍFICO", font=f_mare, fill=(*BORDE_MEX, 180), anchor="mm")
    draw.text((MAP_X1 - 680, MAP_Y0 + 620), "GOLFO DE MÉXICO", font=f_mare, fill=(*BORDE_MEX, 180), anchor="mm")
    draw.text((MAP_X1 - 240, MAP_Y1 - 520), "MAR CARIBE", font=f_mare, fill=(*BORDE_MEX, 180), anchor="mm")

    # Cita de Borges (esquina superior derecha dentro del océano/marco)
    quote_x, quote_y = MAP_X1 - 60, MAP_Y0 + 55
    f_q = load_font(FONT_ITAL, 23)
    f_qa = load_font(FONT_REG, 19)
    quote_lines = [
        "«Vi el Aleph, desde todos los puntos,",
        "vi en el Aleph la tierra, y en la tierra otra vez el Aleph",
        "y en el Aleph la tierra...»",
    ]
    for i, ql in enumerate(quote_lines):
        draw.text((quote_x, quote_y + i * 31), ql, font=f_q, fill=(*GRIS2, 235), anchor="ra")
    draw.text((quote_x, quote_y + 102), "— Jorge Luis Borges, El Aleph (1949)", font=f_qa, fill=(*GRIS, 220), anchor="ra")

    # Leyenda de los 7 biomas (esquina superior derecha, debajo de la cita, o derecha abajo)
    leg_x0 = MAP_X1 - 690
    leg_y0 = MAP_Y1 - 365
    leg_w = 645
    leg_h = 320
    draw.rectangle([leg_x0, leg_y0, leg_x0 + leg_w, leg_y0 + leg_h], fill=(*PAPEL, 240), outline=(*MARCO, 255), width=2)
    f_leg_t = load_font(FONT_BOLD, 24)
    f_leg_i = load_font(FONT_REG, 21)
    draw.text((leg_x0 + 24, leg_y0 + 20), "BIOMAS DE MÉXICO (COLOR CALIGRÁFICO)", font=f_leg_t, fill=(*TINTA, 255))

    for i, (bname, bcol) in enumerate(BIOME_COLORS.items()):
        yy = leg_y0 + 64 + i * 35
        draw.text((leg_x0 + 26, yy), "Aa", font=load_font(FONT_B_ITAL, 22), fill=(*bcol, 255))
        draw.text((leg_x0 + 72, yy + 2), bname, font=f_leg_i, fill=(*TINTA, 255))

    # Rosa de los vientos minimalista (arriba a la izquierda del mapa)
    nx, ny = MAP_X0 + 85, MAP_Y0 + 105
    draw.polygon([(nx, ny - 38), (nx - 10, ny + 10), (nx, ny)], fill=(*TINTA, 255))
    draw.polygon([(nx, ny - 38), (nx + 10, ny + 10), (nx, ny)], fill=(*GRIS, 255))
    draw.text((nx, ny - 54), "N", font=load_font(FONT_BOLD, 24), fill=(*TINTA, 255), anchor="mm")

    # Escala gráfica (500 km) a la derecha de la lente, con respiro
    scale_px = 500000 * scale
    sx0 = MAP_X0 + 820
    sy0 = MAP_Y1 - 52
    draw.rectangle([sx0, sy0, sx0 + scale_px / 2, sy0 + 10], fill=(*TINTA, 255), outline=(*TINTA, 255))
    draw.rectangle([sx0 + scale_px / 2, sy0, sx0 + scale_px, sy0 + 10], fill=(*PAPEL, 255), outline=(*TINTA, 255))
    f_sc = load_font(FONT_REG, 20)
    draw.text((sx0, sy0 - 24), "0", font=f_sc, fill=(*TINTA, 255), anchor="mm")
    draw.text((sx0 + scale_px / 2, sy0 - 24), "250", font=f_sc, fill=(*TINTA, 255), anchor="mm")
    draw.text((sx0 + scale_px, sy0 - 24), "500 km", font=f_sc, fill=(*TINTA, 255), anchor="mm")

    # 6. Encabezado Editorial y Pie de Figura (Caption)
    f_kick = load_font(FONT_BOLD, 28)
    f_tit = load_font(FONT_BOLD, 74)
    f_sub = load_font(FONT_ITAL, 32)
    f_kpi = load_font(FONT_REG, 26)

    draw.text((MAP_X0, 58), "#30DAYMAPCHALLENGE 2026   ·   DÍA 14   ·   BORGESIAN MAP", font=f_kick, fill=(*GRIS, 255))
    draw.text((MAP_X0, 102), "EL ALEPH DE LAS ECORREGIONES", font=f_tit, fill=(*TINTA, 255))
    draw.text(
        (MAP_X0, 198),
        "Mapa caligráfico donde el territorio mexicano se dibuja con los nombres científicos de su flora y fauna",
        font=f_sub,
        fill=(*GRIS2, 255),
    )

    # KPI a la derecha del encabezado
    n_unique = sp_data["metadata"]["n_unique_species"]
    kpi_str = f"{n_unique:,} especies en GBIF   ·   45 ecorregiones   ·   {total_words:,} inscripciones".replace(",", ".")
    draw.text((MAP_X1, 212), kpi_str, font=f_kpi, fill=(*GRIS, 255), anchor="ra")
    draw.line([(MAP_X0, 274), (MAP_X1, 274)], fill=(*MARCO, 255), width=2)

    # Pie de figura estándar
    f_cap = load_font(FONT_REG, 24)
    cap_text = (
        "#30DayMapChallenge 2026 | Día 14: Borgesian map\n"
        "Datos: GBIF API (Plantae, Animalia, Fungi) · Ecoregions2017 (RESOLVE) | Gráfico: Fernando Dorantes Nieto (@FerDoranNie)"
    )
    draw.multiline_text((MAP_X0, H - 125), cap_text, font=f_cap, fill=(*GRIS, 255), spacing=8)

    # 7. Guardar salidas en high_res y gallery
    print("[3/3] Exportando imágenes (alta resolución y galería)...")
    os.makedirs(os.path.dirname(OUT_HIGH), exist_ok=True)
    os.makedirs(os.path.dirname(OUT_GALLERY), exist_ok=True)

    rgb = img.convert("RGB")
    rgb.save(OUT_HIGH, format="PNG", dpi=(300, 300), optimize=True)

    # Versión galería (~1800 px de ancho)
    gal_w = 1800
    gal_h = int(round(H * (gal_w / W)))
    gal = rgb.resize((gal_w, gal_h), Image.LANCZOS)
    gal.save(OUT_GALLERY, format="PNG", optimize=True)

    print(f"Completado en {time.time() - t0:.1f}s")
    print(f" - Alta resolución: {OUT_HIGH}")
    print(f" - Galería:         {OUT_GALLERY}")


if __name__ == "__main__":
    main()
