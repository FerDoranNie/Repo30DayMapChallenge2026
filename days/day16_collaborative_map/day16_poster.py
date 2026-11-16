# -*- coding: utf-8 -*-
"""
#30DayMapChallenge 2026 — Día 16: Collaborative map
El poder de la ciencia ciudadana: eBird y Naturalista (iNaturalist) en México.

Autor: Fernando Dorantes Nieto (@FerDoranNie)
Entorno: Anaconda (data_engineering)
"""

import json
from pathlib import Path
import sys
import numpy as np
import pandas as pd
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter
from shapely.geometry import shape, Polygon, MultiPolygon
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.gridspec import GridSpec
from matplotlib.collections import PolyCollection
import matplotlib.ticker as ticker

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from utils.theme_map2026 import apply_map_style, map_caption

# -----------------------------------------------------------------------------
# 1. Rutas y Paleta Editorial (Estilo Atlas Enmarcado)
# -----------------------------------------------------------------------------
MX_GEOJSON = Path("data/raw/day01/mexico_states.geojson")
SUMMARY_JSON = Path("data/processed/day16_summary.json")
EBIRD_PARQUET = Path("data/processed/day16_points_ebird.parquet")
INAT_PARQUET = Path("data/processed/day16_points_inat.parquet")

OUT_HIGH = Path("outputs/high_res/day16_collaborative_map_ciencia_ciudadana.png")
OUT_GALLERY = Path("outputs/gallery/day16_collaborative_map_ciencia_ciudadana.png")
OUT_HIGH.parent.mkdir(parents=True, exist_ok=True)
OUT_GALLERY.parent.mkdir(parents=True, exist_ok=True)

PAPEL = "#F7F4EB"
OCEANO = "#DCE6F2"
MARCO = "#94A3B8"
RETICULA = "#B8C7D9"
TIERRA = "#24344D"
BORDE_EST = "#435B7D"
COSTA = "#162235"
TINTA = "#0F172A"
SUBTINTA = "#334155"
GRIS = "#475569"

COL_EBIRD = "#F59E0B"      # Ámbar dorado
COL_EBIRD_HI = "#FDE047"   # Dorado luminoso
COL_INAT = "#06B6D4"       # Cian turquesa
COL_INAT_HI = "#67E8F9"    # Cian luminoso
COL_CONV = "#FFFBEB"       # Marfil brillante (convergencia)

# Bounding box de México en Lon/Lat
LON_MIN, LON_MAX = -118.4, -86.2
LAT_MIN, LAT_MAX = 14.1, 33.1
ASPECT_CORR = 1.0 / np.cos(np.deg2rad(23.5))


def load_mexico_polygons():
    """Carga los polígonos estatales de México desde GeoJSON."""
    with open(MX_GEOJSON, "r", encoding="utf-8") as f:
        gj = json.load(f)
    polys = []
    for feat in gj["features"]:
        geom = shape(feat["geometry"])
        if isinstance(geom, Polygon):
            polys.append(geom)
        elif isinstance(geom, MultiPolygon):
            polys.extend(list(geom.geoms))
    return gj["features"], polys


def build_land_mask(features, nx, ny):
    """Rasteriza la silueta de México en una grilla (ny, nx) para recortar el mapa de calor."""
    img = Image.new("L", (nx, ny), 0)
    draw = ImageDraw.Draw(img)

    def to_px(coords):
        pts = []
        for x, y in coords:
            px = (x - LON_MIN) / (LON_MAX - LON_MIN) * (nx - 1)
            py = (LAT_MAX - y) / (LAT_MAX - LAT_MIN) * (ny - 1)
            pts.append((px, py))
        return pts

    for feat in features:
        geom = shape(feat["geometry"])
        geoms = [geom] if isinstance(geom, Polygon) else list(geom.geoms)
        for g in geoms:
            if len(g.exterior.coords) >= 3:
                draw.polygon(to_px(g.exterior.coords), fill=255)
            for hole in g.interiors:
                if len(hole.coords) >= 3:
                    draw.polygon(to_px(hole.coords), fill=0)

    return np.array(img) > 127


def rasterize_points(df, nx, ny, sigma=1.2, q_clip=99.6):
    """
    Rasteriza coordenadas ponderadas en una grilla (ny, nx) estilo Datashader
    con compresión logarítmica y halo gaussiano sutil.
    """
    grid = np.zeros((ny, nx), dtype=np.float64)
    lon = df["lon"].to_numpy()
    lat = df["lat"].to_numpy()
    w = df["weight"].to_numpy()

    ix = np.clip(((lon - LON_MIN) / (LON_MAX - LON_MIN) * (nx - 1)).astype(int), 0, nx - 1)
    iy = np.clip(((LAT_MAX - lat) / (LAT_MAX - LAT_MIN) * (ny - 1)).astype(int), 0, ny - 1)
    np.add.at(grid, (iy, ix), w)

    # Núcleo fino + halo suave para visibilidad a escala nacional
    core = gaussian_filter(grid, sigma=sigma)
    halo = gaussian_filter(grid, sigma=sigma * 2.8)
    comb = np.log1p(core * 0.85 + halo * 0.35)

    nz = comb[comb > 0]
    vmax = np.percentile(nz, q_clip) if len(nz) > 0 else 1.0
    norm = np.clip(comb / max(vmax, 1e-9), 0.0, 1.0)
    # Realce gamma sutil para destacar corredores secundarios
    return np.power(norm, 0.78)


def make_bivariate_rgba(ebird_norm, inat_norm, mask):
    """
    Combina las intensidades de eBird (ámbar) y Naturalista (cian) en una imagen RGBA
    sobre fondo transparente (para superponer sobre el polígono #24344D).
    """
    ny, nx = ebird_norm.shape
    rgba = np.zeros((ny, nx, 4), dtype=np.float32)

    e = np.where(mask, ebird_norm, 0.0)
    i = np.where(mask, inat_norm, 0.0)

    # Colores base en [0, 1]
    # eBird: (0.96, 0.62, 0.04) -> (0.99, 0.88, 0.28)
    # iNat:  (0.02, 0.71, 0.83) -> (0.40, 0.91, 0.98)
    r = np.clip(e * 0.98 + i * 0.12 + np.minimum(e, i) * 0.45, 0.0, 1.0)
    g = np.clip(e * 0.65 + i * 0.76 + np.minimum(e, i) * 0.35, 0.0, 1.0)
    b = np.clip(e * 0.06 + i * 0.92 + np.minimum(e, i) * 0.45, 0.0, 1.0)

    alpha = np.clip(np.maximum(e, i) * 1.15, 0.0, 1.0)
    alpha = np.where(alpha < 0.03, 0.0, alpha)

    rgba[..., 0] = r
    rgba[..., 1] = g
    rgba[..., 2] = b
    rgba[..., 3] = alpha
    return rgba


def make_mono_rgba(norm, mask, rgb_low, rgb_high):
    """Genera capa RGBA monocromática luminosa para los mini-mapas individuales."""
    ny, nx = norm.shape
    rgba = np.zeros((ny, nx, 4), dtype=np.float32)
    v = np.where(mask, norm, 0.0)

    for c in range(3):
        rgba[..., c] = np.clip(rgb_low[c] + (rgb_high[c] - rgb_low[c]) * v, 0.0, 1.0)
    alpha = np.clip(v * 1.15, 0.0, 1.0)
    alpha = np.where(alpha < 0.03, 0.0, alpha)
    rgba[..., 3] = alpha
    return rgba


def plot_mexico_base(ax, features, lw_state=0.45, lw_coast=0.7):
    """Dibuja los polígonos de México con estilo Atlas (#24344D sobre #DCE6F2)."""
    verts = []
    for feat in features:
        geom = shape(feat["geometry"])
        geoms = [geom] if isinstance(geom, Polygon) else list(geom.geoms)
        for g in geoms:
            verts.append(np.asarray(g.exterior.coords))

    pc = PolyCollection(
        verts,
        facecolor=TIERRA,
        edgecolor=BORDE_EST,
        linewidth=lw_state,
        zorder=2,
    )
    ax.add_collection(pc)
    ax.set_xlim(LON_MIN, LON_MAX)
    ax.set_ylim(LAT_MIN, LAT_MAX)
    ax.set_aspect(ASPECT_CORR)


def main():
    print("Cargando datos procesados y geometrías...")
    summary = json.loads(SUMMARY_JSON.read_text(encoding="utf-8"))
    df_ebird = pd.read_parquet(EBIRD_PARQUET)
    df_inat = pd.read_parquet(INAT_PARQUET)
    features, _ = load_mexico_polygons()

    # Grilla de alta resolución para el mapa principal y mini-mapas
    NX, NY = 1400, 960
    mask = build_land_mask(features, NX, NY)

    print("Rasterizando densidades estilo Datashader...")
    ebird_grid = rasterize_points(df_ebird, NX, NY, sigma=1.15, q_clip=99.6)
    inat_grid = rasterize_points(df_inat, NX, NY, sigma=1.15, q_clip=99.6)

    rgba_main = make_bivariate_rgba(ebird_grid, inat_grid, mask)
    rgba_ebird = make_mono_rgba(ebird_grid, mask, (0.96, 0.62, 0.04), (1.00, 0.94, 0.55))
    rgba_inat = make_mono_rgba(inat_grid, mask, (0.02, 0.71, 0.83), (0.75, 0.97, 1.00))

    # Configuración tipográfica y de tema
    apply_map_style(bg_color=PAPEL, panel_color=OCEANO, text_color=TINTA)
    plt.rcParams.update({
        "font.family": "serif",
        "font.serif": ["Georgia", "DejaVu Serif"],
    })

    fig = plt.figure(figsize=(16.5, 10.6), dpi=300, facecolor=PAPEL)

    # GridSpec maestro: Fila 0 (Header), Fila 1 (Contenido: Mapa + Paneles), Fila 2 (Footer)
    gs = GridSpec(
        3, 2,
        figure=fig,
        height_ratios=[0.145, 0.785, 0.070],
        width_ratios=[1.52, 1.00],
        hspace=0.14,
        wspace=0.14,
        left=0.04,
        right=0.965,
        top=0.955,
        bottom=0.045,
    )

    # -------------------------------------------------------------------------
    # A. Encabezado Editorial + KPIs
    # -------------------------------------------------------------------------
    ax_head = fig.add_subplot(gs[0, :])
    ax_head.set_facecolor(PAPEL)
    ax_head.axis("off")

    ax_head.set_xlim(0, 1)
    ax_head.set_ylim(0, 1)

    ax_head.text(
        0.0, 0.96,
        "El pulso de la ciencia ciudadana: eBird y Naturalista en México",
        fontsize=23.5, fontweight="bold", color=TINTA, va="top", ha="left",
        transform=ax_head.transAxes,
    )
    ax_head.text(
        0.0, 0.62,
        "Más de 18.1 millones de registros de aves (~94.6% de toda la evidencia en GBIF para México) "
        "construidos colectivamente por observadores ciudadanos.",
        fontsize=11.5, color=SUBTINTA, va="top", ha="left", style="italic",
        transform=ax_head.transAxes,
    )

    # 4 tarjetas KPI discretas en la parte inferior del header
    all_aves = summary["all_aves_mx"]
    eb_cnt = summary["ebird"]["count"]
    in_cnt = summary["inat"]["count"]
    cit_cnt = eb_cnt + in_cnt
    cit_pct = 100.0 * cit_cnt / all_aves
    obs_cnt = summary["inat_extra"]["observers"]
    spp_cnt = summary["inat_extra"]["species"]

    kpis = [
        ("CIENCIA CIUDADANA (AVES MX)", f"{cit_cnt/1e6:.2f} M", f"{cit_pct:.1f}% del total en GBIF ({all_aves/1e6:.2f} M)", TINTA),
        ("eBIRD (CORNELL LAB / CONABIO)", f"{eb_cnt/1e6:.2f} M", f"{100*eb_cnt/all_aves:.1f}% · Corredores y costas", "#B45309"),
        ("NATURALISTA (iNATURALIST MX)", f"{in_cnt/1e6:.2f} M", f"{obs_cnt:,} observadores · {spp_cnt:,} taxones", "#0E7490"),
        ("COBERTURA TERRITORIAL", "32 / 32", "Entidades federativas con redes activas", SUBTINTA),
    ]
    kpi_x = [0.0, 0.255, 0.51, 0.77]
    for x0, (lbl, val, sub, col) in zip(kpi_x, kpis):
        ax_head.plot([x0, x0], [0.02, 0.36], color=col, lw=2.8, transform=ax_head.transAxes)
        ax_head.text(x0 + 0.01, 0.37, lbl, fontsize=7.6, fontweight="bold", color=GRIS, va="top", transform=ax_head.transAxes)
        ax_head.text(x0 + 0.01, 0.22, val, fontsize=15.0, fontweight="bold", color=col, va="top", transform=ax_head.transAxes)
        ax_head.text(x0 + 0.080, 0.17, sub, fontsize=8.1, color=SUBTINTA, va="top", transform=ax_head.transAxes)

    # -------------------------------------------------------------------------
    # B. Mapa Principal Bivariado (Izquierda)
    # -------------------------------------------------------------------------
    ax_map = fig.add_subplot(gs[1, 0])
    ax_map.set_facecolor(OCEANO)
    plot_mexico_base(ax_map, features, lw_state=0.45)

    # Retícula geográfica sutil
    ax_map.set_xticks(np.arange(-115, -85, 5))
    ax_map.set_yticks(np.arange(15, 35, 5))
    ax_map.xaxis.set_major_formatter(ticker.FuncFormatter(lambda v, _: f"{abs(int(v))}°O"))
    ax_map.yaxis.set_major_formatter(ticker.FuncFormatter(lambda v, _: f"{int(v)}°N"))
    ax_map.tick_params(labelsize=8, colors=GRIS, length=3)
    ax_map.grid(True, color=RETICULA, linestyle="--", linewidth=0.5, alpha=0.75, zorder=1)

    # Capa rasterizada bivariada
    ax_map.imshow(
        rgba_main,
        extent=[LON_MIN, LON_MAX, LAT_MIN, LAT_MAX],
        origin="upper",
        interpolation="bilinear",
        zorder=4,
    )

    # Título interno discreto del mapa principal (esquina superior derecha sobre el Golfo)
    ax_map.text(
        0.975, 0.965,
        "CONVERGENCIA COLABORATIVA",
        transform=ax_map.transAxes,
        fontsize=10.5, fontweight="bold", color=TINTA, va="top", ha="right",
        bbox=dict(boxstyle="round,pad=0.35", facecolor=PAPEL, edgecolor=MARCO, alpha=0.92, lw=0.7),
        zorder=10,
    )

    # Anotaciones de 5 nodos clave
    nodes = [
        (-99.13, 19.43, "Valle de México\n(Epicentro Naturalista)", (-104.8, 16.5)),
        (-96.14, 19.20, "Veracruz · Río de Rapaces\n(1.49 M eBird)", (-92.2, 23.0)),
        (-88.30, 20.60, "Península de Yucatán\n(2.76 M eBird en Q. Roo + Yuc.)", (-91.5, 25.4)),
        (-103.35, 20.67, "Jalisco & Bahía de Banderas\n(Convergencia Pacífico)", (-111.5, 20.2)),
        (-100.31, 25.68, "Monterrey & Sierra Madre\n(87 mil reg. Naturalista)", (-97.0, 28.6)),
    ]
    for lx, ly, label, (tx, ty) in nodes:
        ax_map.scatter([lx], [ly], s=22, facecolor="#FFFFFF", edgecolor=TINTA, linewidth=0.9, zorder=8)
        ax_map.annotate(
            label,
            xy=(lx, ly),
            xytext=(tx, ty),
            fontsize=7.6,
            color=TINTA,
            fontweight="bold",
            ha="center",
            va="center",
            bbox=dict(boxstyle="round,pad=0.25", facecolor=PAPEL, edgecolor=MARCO, alpha=0.88, lw=0.6),
            arrowprops=dict(arrowstyle="-", color=TINTA, lw=0.8, shrinkA=2, shrinkB=3),
            zorder=9,
        )

    # Leyenda bivariada en esquina inferior izquierda del mapa
    leg_ax = ax_map.inset_axes([0.025, 0.04, 0.34, 0.16])
    leg_ax.set_facecolor(PAPEL)
    for sp in leg_ax.spines.values():
        sp.set_edgecolor(MARCO)
        sp.set_linewidth(0.7)
    leg_ax.set_xticks([])
    leg_ax.set_yticks([])

    leg_ax.text(0.06, 0.84, "DENSIDAD DE OBSERVACIÓN", fontsize=7.5, fontweight="bold", color=TINTA)
    items = [
        (COL_EBIRD, "Predominio eBird (rutas y costas)"),
        (COL_CONV, "Alta convergencia (ambas redes)"),
        (COL_INAT, "Predominio Naturalista (urbes)"),
    ]
    for idx, (c, txt) in enumerate(items):
        y = 0.60 - idx * 0.24
        leg_ax.add_patch(mpatches.Rectangle((0.06, y - 0.05), 0.08, 0.14, facecolor=c, edgecolor=TINTA, lw=0.5))
        leg_ax.text(0.17, y + 0.02, txt, fontsize=7.0, color=SUBTINTA, va="center")

    # -------------------------------------------------------------------------
    # C. Paneles Laterales (Derecha: 3 bloques apilados)
    # -------------------------------------------------------------------------
    gs_right = gs[1, 1].subgridspec(3, 1, height_ratios=[0.95, 0.90, 1.15], hspace=0.34)

    # C1. Mini-mapas lado a lado (eBird vs Naturalista)
    gs_mini = gs_right[0].subgridspec(1, 2, wspace=0.08)
    for col_idx, (title_m, rgba_m, badge_col) in enumerate([
        ("eBird (16.57 M reg.)", rgba_ebird, "#B45309"),
        ("Naturalista (1.62 M reg.)", rgba_inat, "#0E7490"),
    ]):
        ax_m = fig.add_subplot(gs_mini[col_idx])
        ax_m.set_facecolor(OCEANO)
        plot_mexico_base(ax_m, features, lw_state=0.22)
        ax_m.imshow(
            rgba_m,
            extent=[LON_MIN, LON_MAX, LAT_MIN, LAT_MAX],
            origin="upper",
            interpolation="bilinear",
            zorder=4,
        )
        ax_m.set_xticks([])
        ax_m.set_yticks([])
        ax_m.set_title(title_m, fontsize=9.2, fontweight="bold", color=badge_col, pad=4)

    # C2. Serie temporal histórica (2005–2025)
    ax_ts = fig.add_subplot(gs_right[1])
    ax_ts.set_facecolor(PAPEL)
    yrs = list(range(2005, 2026))
    eb_y = [summary["ebird"]["years"].get(str(y), 0) for y in yrs]
    in_y = [summary["inat"]["years"].get(str(y), 0) for y in yrs]

    ax_ts.plot(yrs, eb_y, color="#D97706", lw=2.2, marker="o", markersize=3.2, label="eBird")
    ax_ts.fill_between(yrs, eb_y, color=COL_EBIRD, alpha=0.14)
    ax_ts.plot(yrs, in_y, color="#0891B2", lw=2.2, marker="o", markersize=3.2, label="Naturalista")
    ax_ts.fill_between(yrs, in_y, color=COL_INAT, alpha=0.14)

    ax_ts.set_yscale("log")
    ax_ts.set_ylim(300, 4_000_000)
    ax_ts.set_xlim(2005, 2025.5)
    ax_ts.xaxis.set_major_locator(ticker.FixedLocator([2005, 2010, 2015, 2020, 2025]))
    ax_ts.xaxis.set_major_formatter(ticker.FuncFormatter(lambda v, _: f"{int(v)}"))
    ax_ts.axvline(2013, color=GRIS, linestyle=":", lw=0.9)
    ax_ts.text(2013.2, 650, "2013: Lanzamiento\nNaturalista MX", fontsize=7.0, color=GRIS, va="bottom")

    ax_ts.yaxis.set_major_formatter(ticker.FuncFormatter(
        lambda v, _: "1M" if v >= 1e6 else (f"{int(v/1e3)}K" if v >= 1e3 else str(int(v)))
    ))
    ax_ts.tick_params(labelsize=7.8, colors=SUBTINTA)
    ax_ts.grid(True, axis="y", color="#CBD5E1", linestyle="--", lw=0.5, alpha=0.7)
    ax_ts.spines["top"].set_visible(False)
    ax_ts.spines["right"].set_visible(False)
    ax_ts.set_title("Despegue anual de registros ciudadanos (2005–2025, escala log)", fontsize=9.5, fontweight="bold", color=TINTA, loc="left", pad=6)
    ax_ts.legend(frameon=False, fontsize=8.0, loc="upper left", ncol=2)

    # C3. Top 10 Estados: Participación relativa (% del total nacional de cada plataforma)
    ax_bar = fig.add_subplot(gs_right[2])
    ax_bar.set_facecolor(PAPEL)

    gadm_names = summary["gadm_states"]
    rows = []
    for gid, name in gadm_names.items():
        eb_s = summary["ebird"]["states"].get(gid, 0)
        in_s = summary["inat"]["states"].get(gid, 0)
        rows.append({
            "state": name,
            "eb_pct": 100.0 * eb_s / eb_cnt,
            "in_pct": 100.0 * in_s / in_cnt,
            "tot": eb_s + in_s,
        })
    df_top = pd.DataFrame(rows).sort_values("tot", ascending=False).head(10).iloc[::-1]

    y_pos = np.arange(len(df_top))
    h = 0.37
    ax_bar.barh(y_pos + h / 2, df_top["eb_pct"], height=h, color="#D97706", alpha=0.9, label="eBird (% nacional)")
    ax_bar.barh(y_pos - h / 2, df_top["in_pct"], height=h, color="#0891B2", alpha=0.9, label="Naturalista (% nacional)")

    ax_bar.set_yticks(y_pos)
    ax_bar.set_yticklabels(df_top["state"], fontsize=8.0, color=TINTA)
    ax_bar.set_xlim(0, max(df_top["eb_pct"].max(), df_top["in_pct"].max()) * 1.18)
    ax_bar.xaxis.set_major_formatter(ticker.FuncFormatter(lambda v, _: f"{v:.0f}%"))
    ax_bar.tick_params(axis="x", labelsize=7.8, colors=SUBTINTA)
    ax_bar.grid(True, axis="x", color="#CBD5E1", linestyle="--", lw=0.5, alpha=0.7)
    ax_bar.spines["top"].set_visible(False)
    ax_bar.spines["right"].set_visible(False)
    ax_bar.set_title("Top 10 estados: peso relativo por plataforma", fontsize=9.5, fontweight="bold", color=TINTA, loc="left", pad=6)
    ax_bar.legend(frameon=False, fontsize=7.8, loc="lower right")

    # -------------------------------------------------------------------------
    # D. Pie de figura (Caption)
    # -------------------------------------------------------------------------
    ax_foot = fig.add_subplot(gs[2, :])
    ax_foot.set_facecolor(PAPEL)
    ax_foot.axis("off")
    cap = map_caption(
        day=16,
        prompt="Collaborative map",
        source="GBIF (eBird Observation Dataset & iNaturalist Research-grade, nov 2026) & iNaturalist API",
    )
    ax_foot.text(0.0, 0.55, cap, fontsize=8.5, color=GRIS, va="center", ha="left")
    ax_foot.text(
        1.0, 0.55,
        "Muestra espacial estratificada: 114,000 registros recientes (2020–2025) ponderados por entidad federativa.",
        fontsize=8.2, color=GRIS, va="center", ha="right", style="italic",
    )

    print(f"Guardando alta resolución en {OUT_HIGH}...")
    fig.savefig(OUT_HIGH, dpi=300, facecolor=PAPEL)
    plt.close(fig)

    # Versión ligera optimizada para galería (ancho ~1600 px)
    print(f"Generando versión optimizada para galería en {OUT_GALLERY}...")
    with Image.open(OUT_HIGH) as im:
        target_w = 1600
        target_h = int(round(im.height * (target_w / im.width)))
        im_small = im.resize((target_w, target_h), Image.Resampling.LANCZOS)
        im_small.save(OUT_GALLERY, optimize=True, quality=88)

    print("¡Mapa del Día 16 generado con éxito!")


if __name__ == "__main__":
    main()
