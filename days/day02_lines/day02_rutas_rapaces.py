# -*- coding: utf-8 -*-
"""
#30DayMapChallenge 2026 — Día 02: Lines
Tema: El Embudo del Mundo — Veracruz Río de Rapaces y las Autopistas del Cielo
Autor: Fernando Dorantes Nieto (@FerDoranNie)
Entorno: Anaconda (data_engineering)

Descripción:
  Descarga y almacena en caché local (.parquet) observaciones georreferenciadas
  de GBIF a lo largo del continente americano para las 4 especies principales del
  fenómeno migratorio de rapaces más grande del planeta ("Veracruz Río de Rapaces"):
    1. Buteo platypterus (Aguililla Ala Ancha)      ~ 1,800,000 aves/otoño
    2. Cathartes aura (Zopilote Aura)               ~ 2,000,000 aves/otoño
    3. Buteo swainsoni (Aguililla de Swainson)      ~   600,000 aves/otoño
    4. Ictinia mississippiensis (Milano de Misisipi)~   250,000 aves/otoño
  Construye las líneas de flujo (streamlines) migratorias hemisféricas desde
  Norteamérica hasta Sudamérica convergiendo en la planicie costera de Veracruz
  (Chichicaxtle y Cardel) e incluye un panel de acercamiento al embudo mexicano
  y la distribución del volumen de paso otoñal.
"""

from pathlib import Path
import json
import urllib.request
import numpy as np
import pandas as pd
import requests
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.collections import LineCollection
from matplotlib.gridspec import GridSpec
from scipy.interpolate import make_interp_spline
from shapely.geometry import shape, Polygon, MultiPolygon

# ------------------------------------------------------------------------------
# 1. Configuración de directorios y archivos de caché
# ------------------------------------------------------------------------------
RAW_DIR = Path("data/raw/day02")
PROC_DIR = Path("data/processed")
OUT_HIGH = Path("outputs/high_res/day02_lines_veracruz_rio_rapaces.png")
OUT_GALLERY = Path("outputs/gallery/day02_lines_veracruz_rio_rapaces.png")

RAW_DIR.mkdir(parents=True, exist_ok=True)
PROC_DIR.mkdir(parents=True, exist_ok=True)
OUT_HIGH.parent.mkdir(parents=True, exist_ok=True)
OUT_GALLERY.parent.mkdir(parents=True, exist_ok=True)

WORLD_GEOJSON = RAW_DIR / "ne_110m_admin_0_countries.geojson"
MX_STATES_GEOJSON = Path("data/raw/day01/mexico_states.geojson")
RAPTOR_CACHE_PARQUET = PROC_DIR / "day02_raptors_gbif_americas.parquet"
TRAILS_CACHE_PARQUET = PROC_DIR / "day02_raptors_migration_lines.parquet"

# Catálogo de las 4 especies principales de Veracruz Río de Rapaces (Pronatura Veracruz / Hawk Mountain)
SPECIES_INFO = [
    {
        "scientific_name": "Cathartes aura",
        "common_name": "Zopilote Aura",
        "en_name": "Turkey Vulture",
        "autumn_count": 2050000,
        "color": "#f97316",  # Naranja ámbar brillante
        "zorder": 4,
    },
    {
        "scientific_name": "Buteo platypterus",
        "common_name": "Aguililla Ala Ancha",
        "en_name": "Broad-winged Hawk",
        "autumn_count": 1850000,
        "color": "#38bdf8",  # Azul cielo eléctrico
        "zorder": 5,
    },
    {
        "scientific_name": "Buteo swainsoni",
        "common_name": "Aguililla de Swainson",
        "en_name": "Swainson's Hawk",
        "autumn_count": 620000,
        "color": "#facc15",  # Dorado solar
        "zorder": 6,
    },
    {
        "scientific_name": "Ictinia mississippiensis",
        "common_name": "Milano de Misisipi",
        "en_name": "Mississippi Kite",
        "autumn_count": 260000,
        "color": "#ec4899",  # Magenta / Rosa neón
        "zorder": 7,
    },
]

# ------------------------------------------------------------------------------
# 2. Descarga con caché local de capas base y ocurrencias de GBIF
# ------------------------------------------------------------------------------
def ensure_basemaps():
    """Descarga el GeoJSON mundial de Natural Earth si no existe en disco."""
    if not WORLD_GEOJSON.exists():
        print("Descargando contorno continental (Natural Earth 110m)...")
        url = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson"
        urllib.request.urlretrieve(url, WORLD_GEOJSON)

    if not MX_STATES_GEOJSON.exists():
        MX_STATES_GEOJSON.parent.mkdir(parents=True, exist_ok=True)
        url_mx = "https://raw.githubusercontent.com/angelnmara/geojson/master/mexicoHigh.json"
        urllib.request.urlretrieve(url_mx, MX_STATES_GEOJSON)


def fetch_gbif_raptors() -> pd.DataFrame:
    """
    Descarga puntos reales de GBIF en el continente americano para las 4 especies
    o carga directamente el archivo .parquet si ya existe en caché.
    """
    if RAPTOR_CACHE_PARQUET.exists():
        print(f"Cargando ocurrencias de GBIF desde caché: {RAPTOR_CACHE_PARQUET}")
        return pd.read_parquet(RAPTOR_CACHE_PARQUET)

    records = []
    session = requests.Session()

    for sp in SPECIES_INFO:
        sci_name = sp["scientific_name"]
        print(f"Consultando API de GBIF para: {sci_name}...")

        # Resolver taxonKey
        match_resp = session.get(
            "https://api.gbif.org/v1/species/match",
            params={"name": sci_name, "kingdom": "Animalia"},
            timeout=20,
        ).json()
        taxon_key = match_resp.get("usageKey")
        if not taxon_key:
            continue

        # Descargar muestras en distintas bandas latitudinales de América para cubrir todo el corredor
        lat_bands = [
            (30, 62),    # Norteamérica (Reproducción: Canadá y EE.UU.)
            (14, 30),    # México y el embudo de Veracruz
            (5, 14),     # Centroamérica y puente terrestre panameño
            (-42, 5),    # Sudamérica (Invernada: Andes, Amazonía, Pampas)
        ]

        for lat_min, lat_max in lat_bands:
            try:
                occ_resp = session.get(
                    "https://api.gbif.org/v1/occurrence/search",
                    params={
                        "taxonKey": taxon_key,
                        "decimalLatitude": f"{lat_min},{lat_max}",
                        "decimalLongitude": "-135,-34",
                        "hasCoordinate": "true",
                        "hasGeospatialIssue": "false",
                        "limit": 200,
                    },
                    timeout=25,
                ).json()
                for row in occ_resp.get("results", []):
                    lon = row.get("decimalLongitude")
                    lat = row.get("decimalLatitude")
                    month = row.get("month")
                    if lon is not None and lat is not None:
                        records.append({
                            "scientific_name": sci_name,
                            "common_name": sp["common_name"],
                            "lon": float(lon),
                            "lat": float(lat),
                            "month": int(month) if month is not None else -1,
                        })
            except Exception as exc:
                print(f"  Aviso en banda {lat_min}..{lat_max}: {exc}")

    df = pd.DataFrame(records)
    # Deduplicar espacialmente a ~0.1 grados
    df["lon_r"] = df["lon"].round(1)
    df["lat_r"] = df["lat"].round(1)
    df = df.drop_duplicates(subset=["scientific_name", "lon_r", "lat_r"]).drop(columns=["lon_r", "lat_r"])

    df.to_parquet(RAPTOR_CACHE_PARQUET, index=False)
    print(f"Guardados {len(df):,} registros en caché: {RAPTOR_CACHE_PARQUET}")
    return df


# ------------------------------------------------------------------------------
# 3. Generación de trayectorias migratorias (Streamlines) con caché en Parquet
# ------------------------------------------------------------------------------
def generate_migration_streamlines(df_occ: pd.DataFrame) -> pd.DataFrame:
    """
    Construye haces de trayectorias suaves (splines cúbicos) que conectan los
    territorios reales de reproducción en Norteamérica con los de invernada en
    Centro y Sudamérica, pasando por los cuellos de botella topográficos reales:
      - Costa central de Veracruz (Cardel / Chichicaxtle: -96.38, 19.35)
      - Istmo de Tehuantepec (-94.95, 16.55)
      - Vertiente Mesoamericana y Tapón del Darién (-79.5, 8.95)
    """
    if TRAILS_CACHE_PARQUET.exists():
        print(f"Cargando líneas de flujo desde caché: {TRAILS_CACHE_PARQUET}")
        return pd.read_parquet(TRAILS_CACHE_PARQUET)

    rng = np.random.default_rng(20261102)
    corridors = {
        # (lon, lat, dispersión_lon, dispersión_lat) en puntos de control de Norte a Sur
        "Buteo swainsoni": {
            "n_streams": 38,
            "waypoints": [
                (-111.0, 50.5, 9.5, 4.0),   # Praderas de Canadá / Norte EE.UU. (Alberta, Saskatchewan, Montana)
                (-103.5, 39.0, 6.5, 2.5),   # Grandes Llanuras centrales (Colorado, Kansas, Texas)
                (-98.8,  26.5, 1.8, 1.0),   # Entrada a México (Tamaulipas / Nuevo León)
                (-96.42, 19.38, 0.20, 0.15),# EMBUDO DE VERACRUZ (Cardel / Chichicaxtle)
                (-95.00, 16.55, 0.35, 0.20),# Istmo de Tehuantepec
                (-90.50, 14.50, 0.65, 0.35),# Guatemala / Chiapas
                (-84.00, 10.00, 0.45, 0.25),# Costa Rica
                (-79.50,  8.95, 0.35, 0.20),# Istmo de Panamá
                (-74.50,  2.50, 1.60, 1.00),# Andes Colombianos / Ecuatorianos
                (-66.00, -14.0, 2.50, 1.80),# Piedemonte Andino (Perú / Bolivia)
                (-62.50, -33.5, 3.80, 3.20),# Pampas Argentinas (Córdoba / La Pampa)
            ],
        },
        "Buteo platypterus": {
            "n_streams": 48,
            "waypoints": [
                (-82.0,  47.5, 12.0, 3.8),  # Bosques boreales y templados del Este de Canadá y EE.UU.
                (-88.0,  37.5, 7.0,  2.5),  # Apalaches y Valle del Misisipi
                (-96.2,  28.5, 1.6,  0.8),  # Costa de Texas (Corpus Christi / Río Bravo)
                (-96.36, 19.34, 0.18, 0.14),# EMBUDO DE VERACRUZ (Cardel / Chichicaxtle)
                (-94.85, 16.65, 0.35, 0.20),# Istmo de Tehuantepec
                (-88.50, 14.20, 0.70, 0.35),# Corredor Centroamericano
                (-83.80,  9.80, 0.40, 0.20),# Costa Rica (Talamanca / Kekoldi)
                (-79.40,  8.95, 0.35, 0.20),# Panamá (Cerro Ancón)
                (-73.00,  3.50, 2.80, 1.50),# Colombia / Venezuela
                (-67.00, -7.50, 6.50, 3.50),# Cuenca Amazónica Occidental y Andes (Perú, Ecuador, Brasil, Bolivia)
            ],
        },
        "Cathartes aura": {
            "n_streams": 52,
            "waypoints": [
                (-102.0, 44.0, 16.0, 5.0),  # Amplia distribución en Norteamérica (Oeste, Centro y Este)
                (-99.5,  33.0, 8.5,  2.5),  # Sur de EE.UU. y Norte de México
                (-97.5,  24.5, 1.5,  0.8),  # Planicie Costera del Golfo (Tamaulipas)
                (-96.38, 19.32, 0.22, 0.16),# EMBUDO DE VERACRUZ
                (-94.75, 16.60, 0.45, 0.25),# Istmo / Sur de Veracruz
                (-89.50, 13.80, 1.10, 0.50),# Centroamérica
                (-79.60,  8.95, 0.40, 0.20),# Panamá
                (-71.00,  5.50, 5.50, 2.80),# Norte de Sudamérica (Llanos de Venezuela y Colombia)
            ],
        },
        "Ictinia mississippiensis": {
            "n_streams": 28,
            "waypoints": [
                (-95.5,  35.5, 6.5,  2.2),  # Sur-Centro de EE.UU. (Oklahoma, Texas, Valle del Misisipi)
                (-97.2,  27.5, 1.5,  0.7),  # Costa del Golfo de Texas
                (-96.35, 19.36, 0.16, 0.12),# EMBUDO DE VERACRUZ
                (-94.90, 16.58, 0.30, 0.18),# Istmo de Tehuantepec
                (-87.50, 13.20, 0.60, 0.30),# Centroamérica
                (-79.50,  8.95, 0.30, 0.18),# Panamá
                (-65.00, -12.0, 2.80, 1.80),# Bolivia
                (-59.50, -23.5, 3.50, 2.50),# Gran Chaco (Paraguay / Norte de Argentina)
            ],
        },
    }

    rows = []
    stream_id = 0

    for sp in SPECIES_INFO:
        sci_name = sp["scientific_name"]
        cfg = corridors[sci_name]
        wps = cfg["waypoints"]
        n_streams = cfg["n_streams"]

        for _ in range(n_streams):
            stream_id += 1
            # Mantener coherencia lateral relativa de cada hebra (percentil u en [-1, 1])
            u = rng.uniform(-1.0, 1.0)
            pts_lon = []
            pts_lat = []
            for lon_c, lat_c, sd_lon, sd_lat in wps:
                jitter_lon = u * sd_lon + rng.normal(0, sd_lon * 0.22)
                jitter_lat = rng.normal(0, sd_lat * 0.35)
                pts_lon.append(lon_c + jitter_lon)
                pts_lat.append(lat_c + jitter_lat)

            # Interpolación spline paramétrica suave
            t = np.linspace(0, 1, len(pts_lon))
            t_fine = np.linspace(0, 1, 220)
            spl_lon = make_interp_spline(t, pts_lon, k=3)(t_fine)
            spl_lat = make_interp_spline(t, pts_lat, k=3)(t_fine)

            for step_idx, (x, y) in enumerate(zip(spl_lon, spl_lat)):
                rows.append({
                    "stream_id": stream_id,
                    "step": step_idx,
                    "scientific_name": sci_name,
                    "common_name": sp["common_name"],
                    "color": sp["color"],
                    "lon": float(x),
                    "lat": float(y),
                })

    df_trails = pd.DataFrame(rows)
    df_trails.to_parquet(TRAILS_CACHE_PARQUET, index=False)
    print(f"Guardadas {stream_id} trayectorias migratorias en caché: {TRAILS_CACHE_PARQUET}")
    return df_trails


# ------------------------------------------------------------------------------
# 4. Funciones auxiliares para dibujar polígonos GeoJSON en Matplotlib
# ------------------------------------------------------------------------------
def plot_geojson_polygons(ax, geojson_path: Path, facecolor: str, edgecolor: str, linewidth: float = 0.4, alpha: float = 1.0, zorder: int = 1):
    with open(geojson_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    verts = []
    for feat in data.get("features", []):
        geom_dict = feat.get("geometry")
        if not geom_dict:
            continue
        geom = shape(geom_dict)
        if isinstance(geom, Polygon):
            polys = [geom]
        elif isinstance(geom, MultiPolygon):
            polys = list(geom.geoms)
        else:
            continue
        for poly in polys:
            coords = np.asarray(poly.exterior.coords)[:, :2]
            patch = mpatches.Polygon(
                coords,
                closed=True,
                facecolor=facecolor,
                edgecolor=edgecolor,
                linewidth=linewidth,
                alpha=alpha,
                zorder=zorder,
            )
            ax.add_patch(patch)


# ------------------------------------------------------------------------------
# 5. Renderizado del Póster Cartográfico
# ------------------------------------------------------------------------------
def build_map():
    ensure_basemaps()
    df_occ = fetch_gbif_raptors()
    df_trails = generate_migration_streamlines(df_occ)

    bg_color = "#F7F4EB"
    ocean_color = "#DCE6F2"
    land_fill = "#24344D"
    land_edge = "#435B7D"
    mx_fill = "#1B283D"
    mx_edge = "#526D94"
    text_white = "#f8fafc"
    text_canvas_main = "#0f172a"
    text_canvas_sub = "#334155"

    plt.rcParams["font.sans-serif"] = ["Segoe UI", "DejaVu Sans", "Arial"]
    fig = plt.figure(figsize=(15, 13.5), dpi=300, facecolor=bg_color)

    gs = GridSpec(
        nrows=2,
        ncols=2,
        figure=fig,
        width_ratios=[1.25, 1.0],
        height_ratios=[1.15, 1.0],
        wspace=0.08,
        hspace=0.15,
        left=0.03,
        right=0.97,
        top=0.87,
        bottom=0.06,
    )

    # ==========================================================================
    # PANEL A (Izquierda completa): Mapa Hemisférico de las Autopistas del Cielo
    # ==========================================================================
    ax_main = fig.add_subplot(gs[:, 0], facecolor=ocean_color)
    plot_geojson_polygons(ax_main, WORLD_GEOJSON, facecolor=land_fill, edgecolor=land_edge, linewidth=0.5, zorder=1)
    plot_geojson_polygons(ax_main, MX_STATES_GEOJSON, facecolor=mx_fill, edgecolor=mx_edge, linewidth=0.3, zorder=2)

    # Puntos reales de GBIF en el fondo como destellos sutiles del rango real
    for sp in SPECIES_INFO:
        sub_occ = df_occ[df_occ["scientific_name"] == sp["scientific_name"]]
        ax_main.scatter(
            sub_occ["lon"],
            sub_occ["lat"],
            s=3.5,
            c=sp["color"],
            alpha=0.14,
            edgecolors="none",
            zorder=3,
        )

    # Dibujar las líneas de flujo (halo ancho + línea central brillante)
    for sp in SPECIES_INFO:
        sub_trails = df_trails[df_trails["scientific_name"] == sp["scientific_name"]]
        segments = []
        for _, grp in sub_trails.groupby("stream_id"):
            pts = grp[["lon", "lat"]].to_numpy()
            segments.append(pts)

        # Halo exterior difuminado
        lc_glow = LineCollection(segments, colors=sp["color"], linewidths=2.2, alpha=0.09, zorder=sp["zorder"])
        # Hebra central definida
        lc_core = LineCollection(segments, colors=sp["color"], linewidths=0.65, alpha=0.55, zorder=sp["zorder"] + 1)
        ax_main.add_collection(lc_glow)
        ax_main.add_collection(lc_core)

    # Destacar el punto exacto del Embudo de Veracruz (Cardel / Chichicaxtle)
    vx_lon, vx_lat = -96.38, 19.35
    ax_main.scatter([vx_lon], [vx_lat], s=260, c="#ffffff", alpha=0.20, edgecolors="none", zorder=12)
    ax_main.scatter([vx_lon], [vx_lat], s=95, c="#facc15", alpha=0.95, edgecolors="#ffffff", linewidths=1.2, zorder=13)

    # Recuadro indicador del zoom sobre el Golfo de México / Veracruz
    zoom_box = mpatches.Rectangle(
        (-102.5, 15.0), 12.0, 9.5,
        fill=False, edgecolor="#facc15", linewidth=1.2, linestyle="--", alpha=0.95, zorder=14
    )
    ax_main.add_patch(zoom_box)
    ax_main.annotate(
        "EMBUDO DE VERACRUZ\n>4.5 millones de rapaces / otoño\n(Ver Zoom →)",
        xy=(vx_lon, vx_lat),
        xytext=(-126.0, 18.5),
        color=text_white,
        fontsize=9.5,
        fontweight="bold",
        bbox=dict(boxstyle="round,pad=0.45", facecolor="#0f172a", edgecolor="#facc15", linewidth=1.0),
        arrowprops=dict(arrowstyle="->", color="#facc15", lw=1.3, connectionstyle="arc3,rad=0.18"),
        zorder=15,
    )

    # Anotaciones biogeográficas a lo largo del continente
    label_box = dict(boxstyle="round,pad=0.35", facecolor="#F7F4EB", edgecolor="#94a3b8", linewidth=0.7, alpha=0.92)
    ax_main.text(-128.5, 54.5, "BOSQUES BOREALES Y PRADERAS\n(Territorios de anidación boreal:\nCanadá y EE. UU.)", color="#0f172a", fontsize=8.4, style="italic", fontweight="bold", bbox=label_box, zorder=14)
    ax_main.text(-113.0, 6.2, "PUENTE MESOAMERICANO\n(Corredor centroamericano\ny Tapón del Darién)", color="#0f172a", fontsize=8.3, style="italic", fontweight="bold", bbox=label_box, zorder=14)
    ax_main.text(-60.5, -42.5, "PAMPAS Y GRAN CHACO\n(Invernada austral de\nButeo swainsoni e I. mississippiensis)", color="#0f172a", fontsize=8.1, style="italic", fontweight="bold", bbox=label_box, zorder=14)

    ax_main.set_xlim(-130, -34)
    ax_main.set_ylim(-45, 63)
    ax_main.set_aspect("equal", adjustable="box")
    ax_main.set_anchor("N")
    for spine in ax_main.spines.values():
        spine.set_visible(True)
        spine.set_color("#94a3b8")
        spine.set_linewidth(0.8)
    ax_main.set_xticks([])
    ax_main.set_yticks([])
    ax_main.set_title(
        "A. Corredor Hemisférico (Alaska / Canadá — Patagonia)",
        color=text_canvas_main, fontsize=12.5, fontweight="bold", loc="left", pad=10
    )

    # ==========================================================================
    # PANEL B (Arriba Derecha): Acercamiento al Cuello de Botella en Veracruz
    # ==========================================================================
    ax_zoom = fig.add_subplot(gs[0, 1], facecolor=ocean_color)
    plot_geojson_polygons(ax_zoom, WORLD_GEOJSON, facecolor=land_fill, edgecolor=land_edge, linewidth=0.55, zorder=1)
    plot_geojson_polygons(ax_zoom, MX_STATES_GEOJSON, facecolor=mx_fill, edgecolor=mx_edge, linewidth=0.48, zorder=2)

    for sp in SPECIES_INFO:
        sub_trails = df_trails[df_trails["scientific_name"] == sp["scientific_name"]]
        segments = [grp[["lon", "lat"]].to_numpy() for _, grp in sub_trails.groupby("stream_id")]
        ax_zoom.add_collection(LineCollection(segments, colors=sp["color"], linewidths=3.2, alpha=0.18, zorder=sp["zorder"]))
        ax_zoom.add_collection(LineCollection(segments, colors=sp["color"], linewidths=0.95, alpha=0.78, zorder=sp["zorder"] + 1))

        sub_occ = df_occ[df_occ["scientific_name"] == sp["scientific_name"]]
        ax_zoom.scatter(sub_occ["lon"], sub_occ["lat"], s=10, c=sp["color"], alpha=0.38, edgecolors="none", zorder=8)

    # Estaciones de conteo de Pronatura Veracruz (Cardel y Chichicaxtle) y barrera montañosa
    ax_zoom.scatter([vx_lon], [vx_lat], s=320, c="#facc15", alpha=0.32, zorder=12)
    ax_zoom.scatter([vx_lon], [vx_lat], s=90, c="#ffffff", edgecolors="#facc15", linewidths=2.0, zorder=13)

    ax_zoom.annotate(
        "Chichicaxtle y Cardel (Veracruz)\nLa Sierra Madre Oriental (~3,000 m) y el\nCofre de Perote acercan las montañas\na solo 35 km del Golfo de México,\ncomprimiendo todo el flujo continental.",
        xy=(vx_lon, vx_lat),
        xytext=(-95.3, 21.6),
        color=text_white,
        fontsize=8.3,
        bbox=dict(boxstyle="round,pad=0.4", facecolor="#1B283D", edgecolor="#38bdf8", linewidth=0.9),
        arrowprops=dict(arrowstyle="->", color="#1B283D", lw=1.3, connectionstyle="arc3,rad=-0.15"),
        zorder=15,
    )

    ax_zoom.text(-99.7, 20.2, "Sierra Madre\nOriental\n(Barrera topográfica)", color="#cbd5e1", fontsize=8.2, fontweight="bold", ha="center")
    ax_zoom.text(-93.2, 24.0, "Golfo de México\n(Sin térmicas para planear)", color="#1e3a5f", fontsize=8.3, style="italic", fontweight="bold", ha="center")
    ax_zoom.annotate(
        "Istmo de Tehuantepec",
        xy=(-94.9, 16.5),
        xytext=(-98.5, 15.3),
        color="#1e293b",
        fontsize=8.3,
        fontweight="bold",
        bbox=dict(boxstyle="round,pad=0.25", facecolor="#F7F4EB", edgecolor="#94a3b8", linewidth=0.6, alpha=0.9),
        arrowprops=dict(arrowstyle="->", color="#1e293b", lw=1.1),
        zorder=15,
    )

    ax_zoom.set_xlim(-102.5, -88.5)
    ax_zoom.set_ylim(14.5, 25.5)
    ax_zoom.set_aspect("equal", adjustable="box")
    ax_zoom.set_anchor("N")
    for spine in ax_zoom.spines.values():
        spine.set_visible(True)
        spine.set_color("#94a3b8")
        spine.set_linewidth(0.8)
    ax_zoom.set_xticks([])
    ax_zoom.set_yticks([])
    ax_zoom.set_title(
        "B. El Embudo Topográfico: Planicie Costera de Veracruz",
        color=text_canvas_main, fontsize=11.5, fontweight="bold", loc="left", pad=8
    )

    # ==========================================================================
    # PANEL C (Abajo Derecha): Magnitud por Especie y Explicación Ecológica
    # ==========================================================================
    ax_info = fig.add_subplot(gs[1, 1], facecolor="#1E2D45")
    ax_info.set_xlim(0, 100)
    ax_info.set_ylim(0, 100)
    for spine in ax_info.spines.values():
        spine.set_visible(True)
        spine.set_color("#94a3b8")
        spine.set_linewidth(0.8)
    ax_info.set_xticks([])
    ax_info.set_yticks([])
    ax_info.set_title(
        "C. Las 4 Protagonistas del 'Río de Rapaces' (Promedio Otoñal)",
        color=text_canvas_main, fontsize=11.5, fontweight="bold", loc="left", pad=8
    )

    max_count = max(s["autumn_count"] for s in SPECIES_INFO)
    y_positions = [80, 60, 40, 20]

    for sp, y_pos in zip(SPECIES_INFO, y_positions):
        bar_len = (sp["autumn_count"] / max_count) * 58.0
        # Barra con brillo
        ax_info.barh(y_pos, bar_len, height=7.5, left=4, color=sp["color"], alpha=0.85, edgecolor="none")
        ax_info.barh(y_pos, bar_len, height=10.5, left=4, color=sp["color"], alpha=0.18, edgecolor="none")

        # Nombre común y científico arriba de la barra
        ax_info.text(
            4, y_pos + 6.5,
            f"{sp['common_name']}  ({sp['scientific_name']})",
            color=sp["color"], fontsize=9.8, fontweight="bold", va="bottom"
        )
        # Conteo a la derecha de la barra
        ax_info.text(
            4 + bar_len + 2.0, y_pos,
            f"~{sp['autumn_count']:,} aves / otoño",
            color=text_white, fontsize=9.2, fontweight="bold", va="center"
        )

    # Nota explicativa de por qué ocurre el fenómeno en Veracruz
    ax_info.text(
        4, 4.5,
        "¿Por qué convergen en Veracruz? Las grandes aves rapaces migran planeando sobre corrientes\n"
        "térmicas ascendentes para ahorrar energía. Como el agua del Golfo de México y del Océano Pacífico\n"
        "no genera suficientes térmicas y la Sierra Madre Oriental supera los 3,000 m s.n.m., millones de\n"
        "individuos de todo el continente quedan encauzados en una franja costera de apenas 35 km.",
        color="#cbd5e1", fontsize=8.0, va="bottom", linespacing=1.35
    )

    # ==========================================================================
    # Títulos y Firma Cartográfica Global
    # ==========================================================================
    fig.suptitle(
        "AUTOPISTAS DEL CIELO: VERACRUZ Y EL EMBUDO MIGRATORIO DE AMÉRICA",
        color=text_canvas_main, fontsize=19, fontweight="bold", y=0.955
    )
    fig.text(
        0.5, 0.912,
        "Cada otoño, entre 4.5 y 5 millones de aves rapaces de Norteamérica convergen en el centro de Veracruz (México) rumbo a Centro y Sudamérica,\n"
        "formando el corredor migratorio de rapaces más denso del planeta. Líneas: rutas de flujo hemisférico | Puntos: ocurrencias reales en GBIF.",
        color=text_canvas_sub, fontsize=10.2, ha="center", linespacing=1.35
    )
    fig.text(
        0.5, 0.018,
        "#30DayMapChallenge 2026  |  Día 02: Lines  |  Datos: Pronatura Veracruz (Río de Rapaces), Hawk Mountain & GBIF API (n = "
        f"{len(df_occ):,} localidades en caché)\n"
        "Visualización: Fernando Dorantes Nieto (@FerDoranNie)  |  Herramientas: Python (Anaconda data_engineering — pandas, shapely, scipy, matplotlib)",
        color="#475569", fontsize=8.5, ha="center", linespacing=1.35
    )

    fig.savefig(OUT_HIGH, dpi=300, facecolor=bg_color)
    fig.savefig(OUT_GALLERY, dpi=140, facecolor=bg_color)
    plt.close(fig)

    print("¡Mapa del Día 02 generado exitosamente!")
    print(f" - Alta resolución: {OUT_HIGH}")
    print(f" - Galería README:  {OUT_GALLERY}")


if __name__ == "__main__":
    build_map()
