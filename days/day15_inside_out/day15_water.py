"""
Día 15 — Serie metropolitana | Descarga de cuerpos de agua desde OpenStreetMap
Consulta Overpass por ciudad y guarda polígonos y líneas de agua en GeoJSON.

Uso: python days/day15_inside_out/day15_water.py
"""
import json
import time
import urllib.request
from pathlib import Path

OUT = Path("data/raw/day15/agua")
OUT.mkdir(parents=True, exist_ok=True)

CIUDADES = {
    "cdmx": (19.08, -99.44, 19.76, -98.70),
    "mty":  (25.346, -100.686, 26.026, -99.946),
    "gdl":  (20.33, -103.72, 21.01, -102.98),
    "pue":  (18.70, -98.57, 19.38, -97.83),
}

HEADERS = {"User-Agent": "Repo30DayMapChallenge2026/1.0 (ferdorannie)"}
URLS = ["https://overpass-api.de/api/interpreter",
         "https://overpass.kumi.systems/api/interpreter",
         "https://overpass.private.coffee/api/interpreter"]


def overpass(query):
    last = None
    for intento in range(3):
        for url in URLS:
            try:
                req = urllib.request.Request(url, data=query.encode("utf-8"),
                                             headers={**HEADERS, "Content-Type": "text/plain"})
                with urllib.request.urlopen(req, timeout=240) as r:
                    return json.loads(r.read().decode("utf-8"))
            except Exception as exc:  # noqa: BLE001
                last = exc
                time.sleep(5 + 5 * intento)
    raise RuntimeError(f"Overpass no respondió: {last}")


def ways_to_geojson(data):
    polys, lines = [], []
    for el in data.get("elements", []):
        if el.get("type") != "way" or "geometry" not in el:
            continue
        geom = [(p["lon"], p["lat"]) for p in el["geometry"] if p]
        if len(geom) < 2:
            continue
        tags = el.get("tags", {})
        props = {"name": tags.get("name", ""),
                 "kind": tags.get("natural") or tags.get("waterway") or tags.get("landuse") or ""}
        cerrado = len(geom) > 3 and geom[0] == geom[-1]
        if cerrado:
            polys.append({"type": "Feature",
                          "properties": props,
                          "geometry": {"type": "Polygon", "coordinates": [geom]}})
        else:
            lines.append({"type": "Feature",
                          "properties": props,
                          "geometry": {"type": "LineString", "coordinates": geom}})
    return polys, lines


for cid, (s, w, n, e) in CIUDADES.items():
    bbox = f"{s},{w},{n},{e}"
    q_poly = (f"[out:json][timeout:180];("
              f'way["natural"="water"]({bbox});'
              f'way["water"="reservoir"]({bbox});'
              f'way["waterway"="riverbank"]({bbox});'
              f'way["landuse"="reservoir"]({bbox});'
              f");out geom;")
    q_line = (f"[out:json][timeout:180];("
              f'way["waterway"="river"]({bbox});'
              f'way["waterway"="canal"]({bbox});'
              f");out geom;")

    print(cid, "polígonos...", flush=True)
    polys, _ = ways_to_geojson(overpass(q_poly))
    time.sleep(3)
    print(cid, "ríos...", flush=True)
    try:
        _, lines = ways_to_geojson(overpass(q_line))
    except Exception as exc:  # noqa: BLE001
        print("  sin ríos:", exc, flush=True)
        lines = []

    for nombre, feats in (("agua_pol", polys), ("agua_lin", lines)):
        (OUT / f"{cid}_{nombre}.geojson").write_text(
            json.dumps({"type": "FeatureCollection", "features": feats}),
            encoding="utf-8")
    print(f"{cid}: {len(polys)} polígonos, {len(lines)} líneas", flush=True)
    time.sleep(3)

print("Listo.")
