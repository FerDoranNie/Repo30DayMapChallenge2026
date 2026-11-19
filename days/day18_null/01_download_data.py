"""
Día 18: NULL — Terra Incognita Biológica
Descarga de datos reales:
1. NOAA NCEI VIIRS-Land NDVI (2024, 4 fechas estacionales: Ene, Abr, Jul, Oct)
2. GBIF Map Density API v2 (tiles MVT globales z=3 en EPSG:4326, squareSize=32)
"""

import os
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests

RAW_DIR = os.path.join("data", "raw", "day18")
MVT_DIR = os.path.join(RAW_DIR, "gbif_mvt")
os.makedirs(RAW_DIR, exist_ok=True)
os.makedirs(MVT_DIR, exist_ok=True)

NCEI_BASE = "https://www.ncei.noaa.gov/data/land-normalized-difference-vegetation-index/access/2024/"
TARGET_DATES = ["20240115", "20240415", "20240715", "20241015"]


def download_viirs_ndvi():
    print("Consultando índice de NOAA NCEI VIIRS NDVI 2024...")
    idx_html = requests.get(NCEI_BASE, timeout=30).text
    for d in TARGET_DATES:
        matches = re.findall(rf'href="([^"]*_{d}_[^"]*\.nc)"', idx_html)
        if not matches:
            print(f"[WARN] No se encontró archivo para {d}")
            continue
        fname = matches[0]
        out_path = os.path.join(RAW_DIR, fname)
        if os.path.exists(out_path) and os.path.getsize(out_path) > 1_000_000:
            print(f"[SKIP] Ya existe: {fname}")
            continue
        print(f"[DOWN] Descargando {fname}...")
        with requests.get(NCEI_BASE + fname, stream=True, timeout=180) as r:
            r.raise_for_status()
            with open(out_path, "wb") as f:
                for chunk in r.iter_content(chunk_size=1024 * 1024):
                    f.write(chunk)
        print(f"[OK] {fname} ({os.path.getsize(out_path) / 1e6:.2f} MB)")


def fetch_mvt_tile(x: int, y: int, z: int = 3):
    out_path = os.path.join(MVT_DIR, f"gbif_z{z}_{x}_{y}.mvt")
    if os.path.exists(out_path):
        return f"skip {x},{y}"
    url = (
        f"https://api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}.mvt"
        f"?srs=EPSG:4326&bin=square&squareSize=32"
    )
    r = requests.get(url, timeout=30)
    if r.status_code == 204 or len(r.content) == 0:
        return f"empty {x},{y}"
    r.raise_for_status()
    with open(out_path, "wb") as f:
        f.write(r.content)
    return f"ok {x},{y} ({len(r.content)} B)"


def download_gbif_tiles(z: int = 3):
    nx = 2 * (2 ** z)  # 16 para z=3
    ny = 2 ** z        # 8 para z=3
    coords = [(x, y) for x in range(nx) for y in range(ny)]
    print(f"Descargando {len(coords)} tiles MVT de GBIF (z={z}, EPSG:4326)...")
    ok_count = 0
    empty_count = 0
    with ThreadPoolExecutor(max_workers=12) as ex:
        futures = {ex.submit(fetch_mvt_tile, x, y, z): (x, y) for x, y in coords}
        for fut in as_completed(futures):
            res = fut.result()
            if res.startswith("ok") or res.startswith("skip"):
                ok_count += 1
            elif res.startswith("empty"):
                empty_count += 1
    print(f"GBIF MVT listo: {ok_count} tiles con datos, {empty_count} tiles vacíos (204).")


if __name__ == "__main__":
    download_viirs_ndvi()
    download_gbif_tiles(z=3)
