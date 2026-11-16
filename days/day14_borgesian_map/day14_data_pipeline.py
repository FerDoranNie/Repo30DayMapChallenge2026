"""
Día 14 — Borgesian map: El Aleph de las Ecorregiones
Pipeline de datos: consulta de especies reales por ecorregión en México vía GBIF API
(equilibrando flora y fauna para construir un mapa caligráfico taxonómico).

Autor: Fernando Dorantes Nieto (@FerDoranNie)
Reto: #30DayMapChallenge 2026 — 14 de noviembre de 2026
"""

import json
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests
from shapely.geometry import shape, Polygon, MultiPolygon
from shapely.ops import orient

RAW_GEO = "data/processed/day14_eco_4326.geojson"
OUT_JSON = "data/processed/day14_gbif_species_by_eco.json"

SESSION = requests.Session()
SESSION.headers.update({"User-Agent": "Repo30DayMapChallenge2026/1.0 (contact: FerDoranNie)"})


def get_clean_wkt(geom_dict, max_chars=1400):
    """Genera un WKT POLYGON simplificado y orientado CCW para la API de GBIF."""
    geom = shape(geom_dict)
    if isinstance(geom, MultiPolygon):
        geom = max(geom.geoms, key=lambda g: g.area)
    if not isinstance(geom, Polygon):
        geom = geom.convex_hull

    tol = 0.02
    for _ in range(8):
        simp = geom.simplify(tol, preserve_topology=True)
        if isinstance(simp, MultiPolygon):
            simp = max(simp.geoms, key=lambda g: g.area)
        if simp.is_empty or not isinstance(simp, Polygon):
            simp = geom.convex_hull
        # Quitar huecos interiores para evitar WKT inválido o enorme en GBIF
        ext = orient(Polygon(simp.exterior), sign=1.0)
        coords = [(round(x, 4), round(y, 4)) for x, y in ext.exterior.coords]
        wkt = "POLYGON((" + ", ".join(f"{x} {y}" for x, y in coords) + "))"
        if len(wkt) <= max_chars:
            return wkt
        tol *= 1.8

    hull = orient(geom.convex_hull, sign=1.0)
    coords = [(round(x, 4), round(y, 4)) for x, y in hull.exterior.coords]
    return "POLYGON((" + ", ".join(f"{x} {y}" for x, y in coords) + "))"


def query_gbif_facets(eco_name, wkt, bounds, kingdom_key=None, facet_limit=90):
    """Consulta las especies más registradas en GBIF dentro de la ecorregión (WKT o bbox)."""
    url = "https://api.gbif.org/v1/occurrence/search"
    minx, miny, maxx, maxy = bounds
    base_params = {
        "country": "MX",
        "hasCoordinate": "true",
        "hasGeospatialIssue": "false",
        "limit": 0,
        "facet": "speciesKey",
        "facetLimit": facet_limit,
    }
    if kingdom_key is not None:
        base_params["kingdomKey"] = kingdom_key

    # Intento 1: polígono WKT; Intento 2: rango lat/lon (nunca falla por topología WKT)
    strategies = [
        {**base_params, "geometry": wkt},
        {**base_params, "decimalLongitude": f"{minx:.4f},{maxx:.4f}", "decimalLatitude": f"{miny:.4f},{maxy:.4f}"},
    ]

    for params in strategies:
        for attempt in range(2):
            try:
                r = SESSION.get(url, params=params, timeout=25)
                if r.status_code == 200:
                    data = r.json()
                    facets = data.get("facets", [])
                    counts = facets[0].get("counts", []) if facets else []
                    if counts:
                        return [(int(c["name"]), int(c["count"])) for c in counts], data.get("count", 0)
                    break  # si 200 pero vacío, probar siguiente estrategia
                elif r.status_code == 400:
                    break  # WKT rechazado -> pasar inmediatamente a rango lat/lon
            except Exception:
                time.sleep(0.4 * (attempt + 1))
    return [], 0


def fetch_species_meta(species_key):
    """Obtiene nombre científico canónico y taxonomía desde GBIF Species API."""
    url = f"https://api.gbif.org/v1/species/{species_key}"
    for attempt in range(3):
        try:
            r = SESSION.get(url, timeout=15)
            if r.status_code == 200:
                d = r.json()
                canonical = d.get("canonicalName") or d.get("species") or d.get("scientificName", "")
                # Asegurar formato binomial limpio (Genus species)
                parts = canonical.strip().split()
                if len(parts) >= 2:
                    binomial = f"{parts[0]} {parts[1]}"
                else:
                    binomial = canonical.strip()
                return species_key, {
                    "speciesKey": species_key,
                    "species": binomial,
                    "kingdom": d.get("kingdom", ""),
                    "phylum": d.get("phylum", ""),
                    "class": d.get("class", ""),
                    "family": d.get("family", ""),
                }
        except Exception:
            time.sleep(0.3 * (attempt + 1))
    return species_key, None


def main():
    print("=" * 70)
    print(" [DÍA 14] Pipeline GBIF: El Aleph de las Ecorregiones de México")
    print("=" * 70)

    with open(RAW_GEO, encoding="utf-8") as f:
        gj = json.load(f)

    features = gj["features"]
    print(f"[1/3] Ecorregiones cargadas: {len(features)}")

    eco_tasks = []
    for idx, feat in enumerate(features):
        props = feat["properties"]
        eco_name = props["ECO_NAME"]
        wkt = get_clean_wkt(feat["geometry"])
        bounds = shape(feat["geometry"]).bounds
        eco_tasks.append((idx, eco_name, props["bioma_es"], props["area_km2"], wkt, bounds))

    eco_species_raw = {}
    all_species_keys = set()

    def process_eco(task):
        idx, eco_name, bioma, area_km2, wkt, bounds = task
        # Consultar Plantae (kingdomKey=6) y Animalia (kingdomKey=1) por separado para balancear
        plant_counts, n_plants = query_gbif_facets(eco_name, wkt, bounds, kingdom_key=6, facet_limit=90)
        anim_counts, n_anim = query_gbif_facets(eco_name, wkt, bounds, kingdom_key=1, facet_limit=90)
        fungi_counts, n_fungi = query_gbif_facets(eco_name, wkt, bounds, kingdom_key=5, facet_limit=20)

        combined = []
        for k, cnt in (plant_counts or []):
            combined.append((k, cnt, "Plantae"))
        for k, cnt in (anim_counts or []):
            combined.append((k, cnt, "Animalia"))
        for k, cnt in (fungi_counts or []):
            combined.append((k, cnt, "Fungi"))

        return eco_name, {
            "eco_name": eco_name,
            "bioma_es": bioma,
            "area_km2": area_km2,
            "total_occurrences": (n_plants or 0) + (n_anim or 0) + (n_fungi or 0),
            "species_counts": combined,
        }

    print("[2/3] Consultando especies por ecorregión en GBIF API (Plantae + Animalia + Fungi)...")
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=8) as ex:
        futures = [ex.submit(process_eco, t) for t in eco_tasks]
        for fut in as_completed(futures):
            eco_name, res = fut.result()
            eco_species_raw[eco_name] = res
            for k, _, _ in res["species_counts"]:
                all_species_keys.add(k)

    print(f"      Consultas completadas en {time.time() - t0:.1f}s. Especies únicas (keys): {len(all_species_keys)}")

    print(f"[3/3] Resolviendo nombres científicos canónicos de {len(all_species_keys)} especies...")
    t1 = time.time()
    species_meta = {}
    with ThreadPoolExecutor(max_workers=16) as ex:
        futures = [ex.submit(fetch_species_meta, k) for k in all_species_keys]
        for i, fut in enumerate(as_completed(futures), 1):
            k, meta = fut.result()
            if meta and " " in meta["species"]:
                species_meta[k] = meta
            if i % 500 == 0:
                print(f"      Resueltas {i}/{len(all_species_keys)}...")

    print(f"      Nombres resueltos en {time.time() - t1:.1f}s: {len(species_meta)} especies binomiales válidas.")

    # Ensamblar salida final
    output = {
        "metadata": {
            "source": "GBIF API v1 (occurrence/search & species) + Ecoregions2017 (RESOLVE)",
            "n_ecoregions": len(eco_species_raw),
            "n_unique_species": len(species_meta),
        },
        "ecoregions": {},
    }

    for eco_name, res in eco_species_raw.items():
        sp_list = []
        seen = set()
        for k, cnt, kdom in res["species_counts"]:
            if k in species_meta:
                m = species_meta[k]
                sp_name = m["species"]
                if sp_name not in seen:
                    seen.add(sp_name)
                    sp_list.append({
                        "species": sp_name,
                        "count": cnt,
                        "kingdom": m["kingdom"] or kdom,
                        "class": m["class"],
                        "family": m["family"],
                    })
        # Ordenar por frecuencia dentro de la ecorregión
        sp_list.sort(key=lambda x: -x["count"])
        output["ecoregions"][eco_name] = {
            "bioma_es": res["bioma_es"],
            "area_km2": res["area_km2"],
            "total_occurrences": res["total_occurrences"],
            "n_species_fetched": len(sp_list),
            "species": sp_list,
        }

    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"Guardado en: {OUT_JSON}")
    # Resumen rápido
    counts_per_eco = [v["n_species_fetched"] for v in output["ecoregions"].values()]
    print(f"Especies por ecorregión: min={min(counts_per_eco)}, median={sorted(counts_per_eco)[len(counts_per_eco)//2]}, max={max(counts_per_eco)}")


if __name__ == "__main__":
    main()
