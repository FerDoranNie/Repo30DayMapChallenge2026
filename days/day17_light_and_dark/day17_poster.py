# -*- coding: utf-8 -*-
"""
#30DayMapChallenge 2026 — Día 17: Light & dark
"Trampas de luz": la migración nocturna del Golfo de México frente al resplandor de las ciudades.

Autor: Fernando Dorantes Nieto (@FerDoranNie)
Entorno: Anaconda (data_engineering)

Entradas (generadas por day17_data_pipeline.py):
  data/processed/day17_luces_blackmarble.png
  data/processed/day17_luces_luminance.npy
  data/processed/day17_migrantes.parquet
  data/processed/day17_summary.json

Salidas:
  outputs/high_res/day17_light_and_dark_trampas_de_luz.png
  outputs/gallery/day17_light_and_dark_trampas_de_luz.png
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter
from shapely.geometry import shape, Polygon
import matplotlib.pyplot as plt
import matplotlib.patheffects as pe
from matplotlib.gridspec import GridSpec
from matplotlib.colors import LinearSegmentedColormap
import matplotlib.ticker as ticker

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from utils.theme_map2026 import apply_map_style, map_caption  # noqa: E402

# -----------------------------------------------------------------------------
# 1. Rutas
# -----------------------------------------------------------------------------
PROC = ROOT / "data" / "processed"
SUMMARY_JSON = PROC / "day17_summary.json"
MIG_PARQUET = PROC / "day17_migrantes.parquet"
LUM_NPY = PROC / "day17_luces_luminance.npy"
COUNTRIES = ROOT / "data" / "raw" / "day04" / "ne_50m_admin_0_countries.geojson"
ADMIN1 = ROOT / "data" / "raw" / "day17" / "ne_50m_admin_1_states_provinces.geojson"
MX_STATES = ROOT / "data" / "raw" / "day01" / "mexico_states.geojson"

OUT_NAME = "day17_light_and_dark_trampas_de_luz.png"
OUT_HIGH = ROOT / "outputs" / "high_res" / OUT_NAME
OUT_GALLERY = ROOT / "outputs" / "gallery" / OUT_NAME
OUT_HIGH.parent.mkdir(parents=True, exist_ok=True)
OUT_GALLERY.parent.mkdir(parents=True, exist_ok=True)

# -----------------------------------------------------------------------------
# 2. Paleta (Atlas Enmarcado + inversión nocturna)
# -----------------------------------------------------------------------------
PAPEL = "#F7F4EB"
TINTA = "#0F172A"
SUBTINTA = "#334155"
GRIS = "#475569"
MARCO = "#94A3B8"

NOCHE_MAR = "#05080F"
NOCHE_TIERRA = "#121B2C"
COSTA = "#5B7899"
FRONTERA = "#283A50"

AMBAR = "#FFB347"
AMBAR_ALTO = "#FFEFC8"
MAGENTA = "#FF4FA3"
MAGENTA_ALTO = "#FFD3E7"

# Niveles del compuesto Black Marble: se descuenta el pedestal del render
SEA_FLOOR = 0.0123
LAND_FLOOR = 0.0270
DARK_THRESHOLD = 0.030

CLASS_EDGES = [0.0, 0.01, 0.03, 0.08, 0.18, 0.40, 1.01]
CLASS_LABELS = ["Oscuridad", "Penumbra", "Rural", "Poblados", "Ciudades", "Metrópolis"]

# -----------------------------------------------------------------------------
# 3. Ciudades del corredor (lon, lat)
# -----------------------------------------------------------------------------
CITIES = [
    ("Houston", -95.37, 29.76),
    ("Galveston", -94.80, 29.30),
    ("New Orleans", -90.07, 29.95),
    ("Baton Rouge", -91.14, 30.45),
    ("Mobile", -88.04, 30.69),
    ("Pensacola", -87.22, 30.42),
    ("Tampa", -82.46, 27.95),
    ("Corpus Christi", -97.40, 27.80),
    ("Tampico", -97.86, 22.23),
    ("Veracruz", -96.13, 19.17),
    ("Coatzacoalcos", -94.42, 18.14),
    ("Villahermosa", -92.95, 17.99),
    ("Ciudad del Carmen", -91.80, 18.65),
    ("Campeche", -90.53, 19.84),
    ("Mérida", -89.62, 20.97),
    ("Cancún", -86.85, 21.16),
]

# Posición explícita de las etiquetas sobre el mapa
CITY_LABELS = {
    "Houston": (-96.90, 29.00),
    "New Orleans": (-92.40, 30.55),
    "Mobile": (-88.10, 31.65),
    "Tampa": (-85.90, 28.05),
    "Tampico": (-100.10, 23.05),
    "Veracruz": (-99.70, 19.75),
    "Mérida": (-87.90, 21.95),
    "Cancún": (-85.30, 22.25),
}

# -----------------------------------------------------------------------------
# 4. Utilidades geográficas
# -----------------------------------------------------------------------------
def load_geojson_polys(path: Path, bbox: tuple[float, float, float, float]) -> list[np.ndarray]:
    lon0, lat0, lon1, lat1 = bbox
    with open(path, encoding="utf-8") as fh:
        gj = json.load(fh)
    rings = []
    for feat in gj["features"]:
        try:
            geom = shape(feat["geometry"])
        except Exception:
            continue
        if geom.is_empty:
            continue
        minx, miny, maxx, maxy = geom.bounds
        if maxx < lon0 or minx > lon1 or maxy < lat0 or miny > lat1:
            continue
        geoms = [geom] if isinstance(geom, Polygon) else [
            g for g in getattr(geom, "geoms", []) if isinstance(g, Polygon)
        ]
        for g in geoms:
            rings.append(np.asarray(g.exterior.coords))
    return rings


def build_land_mask(rings: list[np.ndarray], nx: int, ny: int,
                    bbox: tuple[float, float, float, float]) -> np.ndarray:
    lon0, lat0, lon1, lat1 = bbox
    img = Image.new("L", (nx, ny), 0)
    draw = ImageDraw.Draw(img)
    for ring in rings:
        pts = [((x - lon0) / (lon1 - lon0) * (nx - 1),
                (lat1 - y) / (lat1 - lat0) * (ny - 1)) for x, y in ring]
        if len(pts) >= 3:
            draw.polygon(pts, fill=255)
    return np.asarray(img) > 127


def km_to_px(km: float, nx: int, bbox: tuple[float, float, float, float]) -> float:
    lon0, _, lon1, _ = bbox
    deg_per_px = (lon1 - lon0) / nx
    return km / (111.32 * math.cos(math.radians(25.0)) * deg_per_px)


# -----------------------------------------------------------------------------
# 5. Capa nocturna
# -----------------------------------------------------------------------------
def rasterize_points(df: pd.DataFrame, weights: np.ndarray, nx: int, ny: int,
                     bbox: tuple[float, float, float, float],
                     sigma: float = 2.0, q: float = 99.3) -> np.ndarray:
    lon0, lat0, lon1, lat1 = bbox
    grid = np.zeros((ny, nx), dtype=np.float64)
    ix = np.clip(((df["lon"].to_numpy() - lon0) / (lon1 - lon0) * (nx - 1)).astype(int), 0, nx - 1)
    iy = np.clip(((lat1 - df["lat"].to_numpy()) / (lat1 - lat0) * (ny - 1)).astype(int), 0, ny - 1)
    np.add.at(grid, (iy, ix), weights)

    core = gaussian_filter(grid, sigma=sigma)
    halo = gaussian_filter(grid, sigma=sigma * 3.2)
    comb = np.log1p(core * 2.4 + halo * 0.55)
    nz = comb[comb > 0]
    vmax = np.percentile(nz, q) if nz.size else 1.0
    norm = np.clip(comb / max(vmax, 1e-9), 0.0, 1.0)
    return np.power(norm, 0.72)


def screen_blend(base: np.ndarray, layer: np.ndarray) -> np.ndarray:
    return 1.0 - (1.0 - base) * (1.0 - np.clip(layer, 0, 1))


def hex_rgb(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], dtype=np.float32)


def build_night_canvas(lum: np.ndarray, bird: np.ndarray, land: np.ndarray) -> np.ndarray:
    """Fondo cartográfico + emisión aditiva de luces (ámbar) y migrantes (magenta)."""
    base = np.where(land[..., None], hex_rgb(NOCHE_TIERRA), hex_rgb(NOCHE_MAR)).astype(np.float32)

    lights = np.power(np.clip(lum, 0, 1), 0.62)
    birds = np.power(np.clip(bird, 0, 1), 1.02)

    emissive = (hex_rgb(AMBAR)[None, None, :] * lights[..., None] * 1.00
                + hex_rgb(MAGENTA)[None, None, :] * birds[..., None] * 0.82)
    both = np.minimum(lights, birds * 1.6)
    emissive += hex_rgb(AMBAR_ALTO)[None, None, :] * both[..., None] * 0.60

    return np.clip(screen_blend(base, emissive), 0, 1)


def bezier(p0, p1, p2, n=180):
    t = np.linspace(0, 1, n)[:, None]
    return (1 - t) ** 2 * np.array(p0) + 2 * (1 - t) * t * np.array(p1) + t ** 2 * np.array(p2)


def fmt_thousands(v, _):
    if v >= 1e6:
        return f"{v/1e6:.1f} M"
    if v >= 1e3:
        return f"{int(round(v/1e3))} K"
    return f"{int(v)}"


# -----------------------------------------------------------------------------
# 6. Póster
# -----------------------------------------------------------------------------
def main() -> None:
    print("Cargando datos...")
    summary = json.loads(SUMMARY_JSON.read_text(encoding="utf-8"))
    df = pd.read_parquet(MIG_PARQUET)
    lon0, lat0, lon1, lat1 = summary["bbox"]
    bbox = (lon0, lat0, lon1, lat1)
    nx, ny = summary["grid"]

    raw_lum = np.load(LUM_NPY).astype(np.float32)
    lum = np.clip((raw_lum - SEA_FLOOR) / (1.0 - SEA_FLOOR), 0, 1)
    lum = np.clip((lum - LAND_FLOOR) / (1.0 - LAND_FLOOR), 0, 1)

    country_rings = load_geojson_polys(COUNTRIES, bbox)
    admin1_rings = load_geojson_polys(ADMIN1, bbox)
    mx_rings = load_geojson_polys(MX_STATES, bbox)
    land = build_land_mask(country_rings, nx, ny, bbox)

    # Peso equitativo por especie
    counts = df["species"].value_counts()
    w = (df["species"].map(lambda s: 1.0 / counts[s]) * len(counts)).to_numpy()
    bird = rasterize_points(df, w, nx, ny, bbox)

    print("Componiendo lienzo nocturno...")
    canvas = build_night_canvas(lum, bird, land)

    # --- Análisis por ciudad ---
    r_px = km_to_px(25.0, nx, bbox)
    yy, xx = np.mgrid[0:ny, 0:nx]
    rows = []
    for name, clon, clat in CITIES:
        cx = (clon - lon0) / (lon1 - lon0) * (nx - 1)
        cy = (lat1 - clat) / (lat1 - lat0) * (ny - 1)
        m = ((xx - cx) ** 2 + (yy - cy) ** 2) <= r_px ** 2
        b = float(lum[m].mean()) if m.any() else 0.0
        near = df[((df["lon"] - clon) ** 2 * math.cos(math.radians(clat)) ** 2
                   + (df["lat"] - clat) ** 2) <= (25.0 / 111.32) ** 2]
        rows.append({"city": name, "lon": clon, "lat": clat, "brillo": b,
                     "migrantes": len(near), "riqueza": int(near["species"].nunique())})
    cdf = pd.DataFrame(rows)

    def norm01(s):
        lo, hi = s.min(), s.max()
        return (s - lo) / (hi - lo) if hi > lo else s * 0

    cdf["itl"] = np.sqrt(norm01(cdf["brillo"]) * norm01(np.log1p(cdf["migrantes"])))
    cdf = cdf.sort_values("itl", ascending=False)
    n_crit = int((cdf["itl"] >= 0.55).sum())
    print(cdf[["city", "brillo", "migrantes", "riqueza", "itl"]].to_string(index=False))

    # --- Clases de brillo ---
    land_vals = lum[land]
    area_share = np.array([100 * np.mean((land_vals >= CLASS_EDGES[i]) & (land_vals < CLASS_EDGES[i + 1]))
                           for i in range(len(CLASS_LABELS))])

    bx = np.clip(((df["lon"].to_numpy() - lon0) / (lon1 - lon0) * (nx - 1)).astype(int), 0, nx - 1)
    by = np.clip(((lat1 - df["lat"].to_numpy()) / (lat1 - lat0) * (ny - 1)).astype(int), 0, ny - 1)
    point_lum = lum[by, bx]
    mig_share = np.array([100 * np.mean((point_lum >= CLASS_EDGES[i]) & (point_lum < CLASS_EDGES[i + 1]))
                          for i in range(len(CLASS_LABELS))])
    dark_land_pct = 100.0 * np.mean(land_vals < DARK_THRESHOLD)

    # -------------------------------------------------------------------------
    # Figura
    # -------------------------------------------------------------------------
    apply_map_style(bg_color=PAPEL, panel_color=PAPEL, text_color=TINTA)
    plt.rcParams.update({
        "font.family": "serif",
        "font.serif": ["Georgia", "DejaVu Serif"],
        "axes.unicode_minus": False,
    })

    fig = plt.figure(figsize=(16.5, 11.0), dpi=300, facecolor=PAPEL)
    gs = GridSpec(
        3, 2, figure=fig,
        height_ratios=[0.190, 0.740, 0.070],
        width_ratios=[1.50, 1.00],
        hspace=0.10, wspace=0.055,
        left=0.035, right=0.968, top=0.968, bottom=0.038,
    )

    # ------------------------- Encabezado -------------------------
    ax_head = fig.add_subplot(gs[0, :])
    ax_head.set_facecolor(PAPEL)
    ax_head.axis("off")
    ax_head.set_xlim(0, 1)
    ax_head.set_ylim(0, 1)

    ax_head.text(0.0, 1.00, "DÍA 17   ·   LIGHT & DARK   ·   #30DAYMAPCHALLENGE 2026",
                 fontsize=8.6, color=GRIS, fontweight="bold", va="top", fontfamily="sans-serif")
    ax_head.text(0.0, 0.900, "Trampas de luz", fontsize=34, fontweight="bold",
                 color=TINTA, va="top")
    ax_head.text(0.287, 0.915,
                 "La migración nocturna del Golfo de México\nfrente al resplandor de las ciudades",
                 fontsize=12.4, color=SUBTINTA, va="top", style="italic", linespacing=1.4)
    ax_head.text(
        0.0, 0.360,
        "Cada otoño, millones de aves cruzan el Golfo en la oscuridad; cada primavera regresan y "
        "amanecen sobre una de las costas más iluminadas del planeta.",
        fontsize=9.7, color=SUBTINTA, va="top",
    )

    pool = summary["pool_total"]
    kpis = [
        ("ESPECIES MIGRATORIAS", f"{summary['n_species']}", "de vuelo nocturno obligado", AMBAR),
        ("REGISTROS DE RESPALDO", f"{pool/1e6:.2f} M", "eBird · 2016–2025", MAGENTA),
        ("TERRITORIO A OSCURAS", f"{dark_land_pct:.0f}%", "brillo < 0.03 (incluye penumbra)", "#1E3A5F"),
        ("CIUDADES CRÍTICAS", f"{n_crit}", "luz alta + paso de migrantes", TINTA),
    ]
    kpi_x = [0.0, 0.258, 0.512, 0.762]
    for x0, (lbl, val, sub, col) in zip(kpi_x, kpis):
        ax_head.plot([x0, x0], [0.0, 0.215], color=col, lw=2.6)
        ax_head.text(x0 + 0.011, 0.225, lbl, fontsize=7.3, fontweight="bold",
                     color=GRIS, va="top")
        ax_head.text(x0 + 0.011, 0.005, val, fontsize=20, fontweight="bold",
                     color=col, va="bottom")
        ax_head.text(x0 + 0.112, 0.025, sub, fontsize=7.7, color=SUBTINTA, va="bottom")

    # ------------------------- Mapa principal -------------------------
    ax_map = fig.add_subplot(gs[1, 0])
    ax_map.set_facecolor(NOCHE_MAR)
    ax_map.imshow(canvas, extent=[lon0, lon1, lat0, lat1], origin="upper",
                  interpolation="bilinear", zorder=1)
    for ring in admin1_rings + mx_rings:
        ax_map.plot(ring[:, 0], ring[:, 1], color=FRONTERA, lw=0.32, alpha=0.55, zorder=2)
    for ring in country_rings:
        ax_map.plot(ring[:, 0], ring[:, 1], color=COSTA, lw=0.55, alpha=0.75, zorder=3)

    ax_map.set_xlim(lon0, lon1)
    ax_map.set_ylim(lat0, lat1)
    ax_map.set_aspect(1.0 / math.cos(math.radians(23.0)))
    ax_map.set_xticks(np.arange(-102, -79, 4))
    ax_map.set_yticks(np.arange(16, 33, 4))
    ax_map.xaxis.set_major_formatter(ticker.FuncFormatter(lambda v, _: f"{abs(int(v))}°O"))
    ax_map.yaxis.set_major_formatter(ticker.FuncFormatter(lambda v, _: f"{int(v)}°N"))
    ax_map.tick_params(labelsize=7.6, colors="#7C93B0", length=2.5)
    for sp in ax_map.spines.values():
        sp.set_edgecolor(MARCO)
        sp.set_linewidth(1.0)

    # Corredor trans-Golfo (esquemático; en otoño el flujo va del norte al sureste)
    for p0, p1, p2 in [
        ((-96.8, 28.6), (-93.2, 26.2), (-89.8, 22.4)),
        ((-94.6, 29.6), (-90.6, 25.6), (-87.6, 21.6)),
        ((-92.2, 30.0), (-88.6, 25.4), (-86.6, 21.4)),
    ]:
        pts = bezier(p0, p1, p2)
        ax_map.plot(pts[:, 0], pts[:, 1], color=MAGENTA, lw=1.25, alpha=0.42,
                    linestyle=(0, (5, 3)), zorder=5)
        ax_map.scatter([pts[-1, 0]], [pts[-1, 1]], marker=(3, 0, 0), s=28,
                       color=MAGENTA, alpha=0.8, zorder=6, linewidths=0)

    ax_map.text(-93.6, 24.3, "corredor trans-Golfo · vuelo nocturno de otoño",
                fontsize=7.6, color=MAGENTA, alpha=0.85, ha="center", va="center",
                style="italic", zorder=7)

    # Ciudades
    for _, r in cdf.iterrows():
        critical = r["itl"] >= 0.45
        ax_map.scatter([r["lon"]], [r["lat"]], s=9 + 48 * r["itl"],
                       facecolor=(AMBAR_ALTO if critical else "#C9D6E8"),
                       edgecolor=NOCHE_MAR, linewidth=0.7, zorder=8, alpha=0.95)

    for city, (tx, ty) in CITY_LABELS.items():
        row = cdf[cdf["city"] == city].iloc[0]
        ax_map.annotate(
            city, xy=(row["lon"], row["lat"]), xytext=(tx, ty),
            fontsize=7.7, color="#F2F6FB", fontweight="bold",
            ha="left" if tx > row["lon"] else "right", va="center", zorder=9,
            path_effects=[pe.withStroke(linewidth=2.0, foreground="#05080F")],
            arrowprops=dict(arrowstyle="-", color="#9FB4CC", lw=0.55, shrinkA=1, shrinkB=3),
        )

    ax_map.text(0.020, 0.968, "EL GOLFO DE MÉXICO, DE NOCHE",
                transform=ax_map.transAxes, fontsize=10.0, fontweight="bold",
                color="#DCE6F2", va="top", ha="left", zorder=10,
                path_effects=[pe.withStroke(linewidth=2.4, foreground="#05080F")])
    ax_map.text(0.020, 0.928, "luces nocturnas VIIRS y presencia de migrantes nocturnos",
                transform=ax_map.transAxes, fontsize=7.9, color="#AFC2D6",
                va="top", ha="left", style="italic", zorder=10,
                path_effects=[pe.withStroke(linewidth=2.0, foreground="#05080F")])

    # Barra de escala (500 km)
    sb_len = 500 / (111.32 * math.cos(math.radians(23.0)))
    sb_x = lon1 - 0.9 - sb_len
    sb_y = lat0 + 0.6
    ax_map.plot([sb_x, sb_x + sb_len], [sb_y, sb_y], color="#DCE6F2", lw=2.4,
                solid_capstyle="butt", zorder=10)
    ax_map.text(sb_x + sb_len / 2, sb_y + 0.25, "500 km", fontsize=7.4,
                color="#DCE6F2", ha="center", va="bottom", zorder=10)

    # Leyenda
    leg = ax_map.inset_axes([0.022, 0.035, 0.265, 0.205])
    leg.set_facecolor("#0A111C")
    leg.patch.set_alpha(0.95)
    for sp in leg.spines.values():
        sp.set_edgecolor(COSTA)
        sp.set_linewidth(0.7)
    leg.set_xticks([])
    leg.set_yticks([])
    leg.set_xlim(0, 1)
    leg.set_ylim(0, 1)

    amber_cmap = LinearSegmentedColormap.from_list("amb", ["#000000", "#5A3410", AMBAR, AMBAR_ALTO])
    mag_cmap = LinearSegmentedColormap.from_list("mag", ["#000000", "#5C1136", MAGENTA, MAGENTA_ALTO])
    leg.imshow(np.linspace(0, 1, 128)[None, :], extent=[0.06, 0.53, 0.70, 0.78],
               aspect="auto", cmap=amber_cmap, origin="lower")
    leg.imshow(np.linspace(0, 1, 128)[None, :], extent=[0.06, 0.53, 0.46, 0.54],
               aspect="auto", cmap=mag_cmap, origin="lower")
    leg.text(0.58, 0.74, "Luz artificial", fontsize=7.5, color="#E8EFF8", va="center")
    leg.text(0.58, 0.50, "Migrantes\nnocturnos", fontsize=7.5, color="#E8EFF8",
             va="center", linespacing=1.05)
    leg.scatter([0.10], [0.26], s=36, facecolor=AMBAR_ALTO, edgecolor=NOCHE_MAR, linewidth=0.6)
    leg.text(0.18, 0.26, "Ciudad del corredor", fontsize=7.3, color="#C9D6E8", va="center")
    leg.text(0.06, 0.07, "blanco = luz + migrantes (trampa)", fontsize=6.9,
             color="#8FA6C0", va="center", style="italic")

    # ------------------------- Paneles laterales -------------------------
    gs_r = gs[1, 1].subgridspec(3, 1, height_ratios=[0.88, 1.10, 1.02], hspace=0.95)

    def panel_title(ax, title, subtitle):
        ax.text(0, 1.235, title, transform=ax.transAxes, fontsize=10.4,
                fontweight="bold", color=TINTA, va="top")
        ax.text(0, 1.062, subtitle, transform=ax.transAxes, fontsize=7.7,
                color=GRIS, style="italic", va="top")

    # B. Pulso anual
    ax_b = fig.add_subplot(gs_r[0])
    ax_b.set_facecolor(PAPEL)
    serie = summary["seasonal"]["monthly_all_year"]
    months = list(range(1, 13))
    vals = np.array([serie.get(str(m), serie.get(m, 0)) for m in months], dtype=float)
    ax_b.fill_between(months, vals, color=MAGENTA, alpha=0.16, lw=0)
    ax_b.plot(months, vals, color="#C2185B", lw=1.9)
    ax_b.scatter(months, vals, s=12, color="#C2185B", zorder=3)
    ax_b.axvspan(7.6, 11.5, color=AMBAR, alpha=0.18, lw=0)
    ax_b.text(9.55, vals.max() * 1.16, "otoño", fontsize=7.8, color="#92400E",
              ha="center", fontweight="bold")
    ax_b.text(2.35, vals.max() * 1.16, "primavera", fontsize=7.8, color="#92400E",
              ha="center", fontweight="bold")
    ax_b.set_xlim(0.6, 12.4)
    ax_b.set_ylim(0, vals.max() * 1.30)
    ax_b.set_xticks(months)
    ax_b.set_xticklabels(["E", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"], fontsize=7.4)
    ax_b.yaxis.set_major_formatter(ticker.FuncFormatter(fmt_thousands))
    ax_b.yaxis.set_major_locator(ticker.MaxNLocator(3, integer=True))
    ax_b.tick_params(labelsize=7.4, colors=SUBTINTA)
    ax_b.grid(True, axis="y", color="#CBD5E1", linestyle="--", lw=0.5, alpha=0.7)
    for s in ("top", "right"):
        ax_b.spines[s].set_visible(False)
    panel_title(ax_b, "El pulso anual de la migración",
                "registros de las 45 especies en el corredor, por mes")

    # C. Dispersión luz × migrantes
    ax_c = fig.add_subplot(gs_r[1])
    ax_c.set_facecolor(PAPEL)
    xv = np.log10(cdf["brillo"].clip(lower=0.008))
    ax_c.axvspan(math.log10(0.28), math.log10(1.0), color=MAGENTA, alpha=0.07, lw=0)
    ax_c.scatter(xv, cdf["migrantes"], s=26 + 7.0 * cdf["riqueza"], c=xv,
                 cmap=LinearSegmentedColormap.from_list("amb2", ["#FDE68A", "#D97706", "#7C2D12"]),
                 edgecolor=TINTA, linewidth=0.6, alpha=0.93, zorder=3)
    offsets = {
        "Houston": (-3, 13), "Tampa": (10, -1), "New Orleans": (0, 15),
        "Pensacola": (-11, 6), "Corpus Christi": (13, -19),
        "Cancún": (9, 20), "Veracruz": (11, -14),
    }
    for city, off in offsets.items():
        r = cdf[cdf["city"] == city].iloc[0]
        ax_c.annotate(city, xy=(math.log10(max(r["brillo"], 0.008)), r["migrantes"]),
                      xytext=off, textcoords="offset points",
                      fontsize=7.2, color=TINTA, fontweight="bold",
                      ha="center" if off[0] == 0 else ("left" if off[0] > 0 else "right"),
                      path_effects=[pe.withStroke(linewidth=2.2, foreground=PAPEL)])
    ax_c.set_xlabel("brillo artificial medio en 25 km a la redonda", fontsize=7.8, color=SUBTINTA)
    ax_c.set_ylabel("registros de migrantes", fontsize=7.8, color=SUBTINTA)
    ticks = [0.01, 0.03, 0.1, 0.3, 0.9]
    ax_c.set_xticks([math.log10(v) for v in ticks])
    ax_c.set_xticklabels(["0.01", "0.03", "0.1", "0.3", "0.9"], fontsize=7.2)
    ax_c.yaxis.set_major_formatter(ticker.FuncFormatter(fmt_thousands))
    ax_c.yaxis.set_major_locator(ticker.MaxNLocator(4, integer=True))
    ax_c.tick_params(labelsize=7.4, colors=SUBTINTA)
    ax_c.grid(True, color="#CBD5E1", linestyle="--", lw=0.5, alpha=0.75)
    for s in ("top", "right"):
        ax_c.spines[s].set_visible(False)
    panel_title(ax_c, "La trampa: mucha luz, muchos migrantes",
                "cada punto es una ciudad; el tamaño indica su riqueza de especies")
    ax_c.text(0.985, 0.06, "zona de\ntrampa", transform=ax_c.transAxes,
              fontsize=7.2, color="#9D174D", ha="right", va="bottom", style="italic")

    # D. Luz vs oscuridad
    ax_d = fig.add_subplot(gs_r[2])
    ax_d.set_facecolor(PAPEL)
    xpos = np.arange(len(CLASS_LABELS))
    bw = 0.38
    ax_d.bar(xpos - bw / 2, area_share, width=bw, color="#1E3A5F", alpha=0.88,
             label="% del territorio")
    ax_d.bar(xpos + bw / 2, mig_share, width=bw, color=MAGENTA, alpha=0.90,
             label="% de los registros")
    for i in range(len(CLASS_LABELS)):
        ax_d.text(xpos[i] - bw / 2, area_share[i] + 1.0, f"{area_share[i]:.0f}",
                  ha="center", fontsize=6.9, color="#1E3A5F", fontweight="bold")
        ax_d.text(xpos[i] + bw / 2, mig_share[i] + 1.0, f"{mig_share[i]:.0f}",
                  ha="center", fontsize=6.9, color="#9D174D", fontweight="bold")
    ax_d.set_xticks(xpos)
    ax_d.set_xticklabels(CLASS_LABELS, fontsize=6.9, rotation=20, ha="right")
    ax_d.set_ylabel("% del total", fontsize=7.8, color=SUBTINTA)
    ax_d.set_ylim(0, max(area_share.max(), mig_share.max()) * 1.28)
    ax_d.tick_params(labelsize=7.2, colors=SUBTINTA)
    ax_d.grid(True, axis="y", color="#CBD5E1", linestyle="--", lw=0.5, alpha=0.7)
    for s in ("top", "right"):
        ax_d.spines[s].set_visible(False)
    ax_d.legend(frameon=False, fontsize=7.2, loc="upper left", handlelength=1.1)
    panel_title(ax_d, "¿Dónde están las aves y dónde la oscuridad?",
                "clases de brillo artificial: territorio disponible frente a registros")

    # ------------------------- Pie -------------------------
    ax_foot = fig.add_subplot(gs[2, :])
    ax_foot.set_facecolor(PAPEL)
    ax_foot.axis("off")
    cap = map_caption(
        day=17,
        prompt="Light & dark",
        source="NASA Black Marble / VIIRS Day-Night Band (compuesto anual) & eBird (Cornell Lab) vía GBIF",
    )
    ax_foot.text(0.0, 0.60, cap, fontsize=8.3, color=GRIS, va="center", ha="left")
    ax_foot.text(
        1.0, 0.60,
        f"{len(df):,} puntos muestreados · corredor 14–32.5°N / 104.5–80°O · "
        "muestreo estratificado por especie, mes y año",
        fontsize=7.5, color=GRIS, va="center", ha="right", style="italic",
    )

    print(f"Guardando {OUT_HIGH} ...")
    fig.savefig(OUT_HIGH, dpi=300, facecolor=PAPEL)
    plt.close(fig)

    with Image.open(OUT_HIGH) as im:
        target_w = 1600
        target_h = int(round(im.height * (target_w / im.width)))
        im.convert("RGB").resize((target_w, target_h), Image.Resampling.LANCZOS).save(
            OUT_GALLERY, optimize=True, quality=90
        )
    print(f"Versión de galería: {OUT_GALLERY}")
    print("¡Mapa del Día 17 generado con éxito!")


if __name__ == "__main__":
    main()
