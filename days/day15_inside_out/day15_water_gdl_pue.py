"""Descarga ligera de agua para Guadalajara y Puebla (solo ways)."""
import json
import time
import urllib.request
from pathlib import Path

OUT = Path("data/raw/day15/agua")
OUT.mkdir(parents=True, exist_ok=True)

CIUDADES = {
    "gdl": (20.415, -103.63, 20.925, -103.07),
    "pue": (18.70, -98.57, 19.38, -97.83),
}
URLS = ["https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter"]
HEADERS = {"User-Agent": "Repo30DayMapChallenge2026/1.0 (ferdorannie)"}


def overpass(query, timeout=120):
    for url in URLS:
        try:
            req = urllib.request.Request(url, data=query.encode(), headers=HEADERS)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as exc:  # noqa: BLE001
            print("   fallo", url.split("/")[2], exc, flush=True)
            time.sleep(4)
    return {"elements": []}


def parse(data):
    polys, lines = [], []
    for el in data.get("elements", []):
        if el.get("type") != "way" or "geometry" not in el:
            continue
        g = [(p["lon"], p["lat"]) for p in el["geometry"] if p]
        if len(g) < 2:
            continue
        tags = el.get("tags", {})
        props = {"name": tags.get("name", ""),
                 "kind": tags.get("natural") or tags.get("waterway") or ""}
        if len(g) > 3 and g[0] == g[-1]:
            polys.append({"type": "Feature", "properties": props,
                          "geometry": {"type": "Polygon", "coordinates": [g]}})
        else:
            lines.append({"type": "Feature", "properties": props,
                          "geometry": {"type": "LineString", "coordinates": g}})
    return polys, lines


for cid, (s, w, n, e) in CIUDADES.items():
    bbox = f"{s},{w},{n},{e}"
    print(cid, "agua...", flush=True)
    qp = (f"[out:json][timeout:90];("
          f'way["natural"="water"]({bbox});'
          f'way["waterway"="riverbank"]({bbox});'
          f");out geom;")
    polys, _ = parse(overpass(qp))
    time.sleep(2)
    print(cid, "ríos...", flush=True)
    ql = (f"[out:json][timeout:90];("
          f'way["waterway"="river"]({bbox});'
          f'way["waterway"="canal"]({bbox});'
          f");out geom;")
    _, lines = parse(overpass(ql))
    for nombre, feats in (("agua_pol", polys), ("agua_lin", lines)):
        (OUT / f"{cid}_{nombre}.geojson").write_text(
            json.dumps({"type": "FeatureCollection", "features": feats}), encoding="utf-8")
    print(f"{cid}: {len(polys)} polígonos, {len(lines)} líneas", flush=True)
    time.sleep(2)
print("Listo.")
