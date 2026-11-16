# -*- coding: utf-8 -*-
"""
#30DayMapChallenge 2026 — Día 16: Collaborative map
Pipeline de descarga y caché de datos reales de ciencia ciudadana (eBird y Naturalista/iNaturalist)
en México vía GBIF API e iNaturalist API.

Autor: Fernando Dorantes Nieto (@FerDoranNie)
Entorno: Anaconda (data_engineering)
"""

from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import time
import pandas as pd
import requests

PROC_DIR = Path("data/processed")
PROC_DIR.mkdir(parents=True, exist_ok=True)

SUMMARY_JSON = PROC_DIR / "day16_summary.json"
EBIRD_PARQUET = PROC_DIR / "day16_points_ebird.parquet"
INAT_PARQUET = PROC_DIR / "day16_points_inat.parquet"

EBIRD_KEY = "4fa7b334-ce0d-4e88-aaae-2e0c138d049e"
INAT_KEY = "50c9509d-22c7-4a22-a47d-8c48425ef4a7"

# Mapeo oficial GADM nivel 1 (MEX.1_1 .. MEX.32_1 en orden alfabético de GADM)
GADM_STATES = {
    "MEX.1_1": "Aguascalientes",
    "MEX.2_1": "Baja California",
    "MEX.3_1": "Baja California Sur",
    "MEX.4_1": "Campeche",
    "MEX.5_1": "Chiapas",
    "MEX.6_1": "Chihuahua",
    "MEX.7_1": "Coahuila",
    "MEX.8_1": "Colima",
    "MEX.9_1": "Ciudad de México",
    "MEX.10_1": "Durango",
    "MEX.11_1": "Guanajuato",
    "MEX.12_1": "Guerrero",
    "MEX.13_1": "Hidalgo",
    "MEX.14_1": "Jalisco",
    "MEX.15_1": "Estado de México",
    "MEX.16_1": "Michoacán",
    "MEX.17_1": "Morelos",
    "MEX.18_1": "Nayarit",
    "MEX.19_1": "Nuevo León",
    "MEX.20_1": "Oaxaca",
    "MEX.21_1": "Puebla",
    "MEX.22_1": "Querétaro",
    "MEX.23_1": "Quintana Roo",
    "MEX.24_1": "San Luis Potosí",
    "MEX.25_1": "Sinaloa",
    "MEX.26_1": "Sonora",
    "MEX.27_1": "Tabasco",
    "MEX.28_1": "Tamaulipas",
    "MEX.29_1": "Tlaxcala",
    "MEX.30_1": "Veracruz",
    "MEX.31_1": "Yucatán",
    "MEX.32_1": "Zacatecas",
}


def fetch_gbif_facets(dataset_key=None):
    """Obtiene conteo total y facetas por año y entidad GADM en GBIF para México."""
    params = {
        "country": "MX",
        "taxonKey": 212,
        "limit": 0,
        "facet": ["year", "gadmGid"],
        "year.facetLimit": 50,
        "gadmGid.facetLimit": 100,
    }
    if dataset_key:
        params["datasetKey"] = dataset_key

    r = requests.get("https://api.gbif.org/v1/occurrence/search", params=params, timeout=30)
    r.raise_for_status()
    data = r.json()

    years = {}
    states = {}
    for f in data.get("facets", []):
        if f["field"] == "YEAR":
            for c in f["counts"]:
                try:
                    y = int(c["name"])
                    if 1995 <= y <= 2026:
                        years[str(y)] = c["count"]
                except ValueError:
                    pass
        elif f["field"] == "GADM_GID":
            for c in f["counts"]:
                gid = c["name"]
                if gid in GADM_STATES:
                    states[gid] = c["count"]
    return {
        "count": data.get("count", 0),
        "years": years,
        "states": states,
    }


def fetch_inat_meta():
    """Obtiene conteos totales de observadores y especies de aves en iNaturalist México."""
    obs = requests.get(
        "https://api.inaturalist.org/v1/observations/observers",
        params={"place_id": 6793, "taxon_id": 3, "per_page": 1},
        timeout=20,
    ).json().get("total_results", 0)

    spp = requests.get(
        "https://api.inaturalist.org/v1/observations/species_counts",
        params={"place_id": 6793, "taxon_id": 3, "per_page": 1},
        timeout=20,
    ).json().get("total_results", 0)

    all_mx = requests.get(
        "https://api.gbif.org/v1/occurrence/search",
        params={"country": "MX", "datasetKey": INAT_KEY, "limit": 0},
        timeout=20,
    ).json().get("count", 0)

    return {"observers": obs, "species": spp, "all_taxa_gbif_mx": all_mx}


def fetch_state_page(dataset_key, gid, year, offset):
    """Descarga hasta 300 coordenadas de GBIF para un estado y año dados."""
    params = {
        "country": "MX",
        "taxonKey": 212,
        "datasetKey": dataset_key,
        "gadmGid": gid,
        "year": year,
        "hasCoordinate": "true",
        "hasGeospatialIssue": "false",
        "limit": 300,
        "offset": offset,
    }
    for attempt in range(3):
        try:
            r = requests.get("https://api.gbif.org/v1/occurrence/search", params=params, timeout=25)
            if r.status_code == 200:
                rows = []
                for rec in r.json().get("results", []):
                    lat = rec.get("decimalLatitude")
                    lon = rec.get("decimalLongitude")
                    if lat is not None and lon is not None:
                        if 14.3 <= lat <= 32.8 and -118.5 <= lon <= -86.5:
                            rows.append((lon, lat, gid, rec.get("year")))
                return rows
            time.sleep(0.5 * (attempt + 1))
        except Exception:
            time.sleep(0.5 * (attempt + 1))
    return []


def sample_dataset_points(dataset_key, state_counts, label):
    """Descarga una muestra estratificada por estado y año reciente para todo México."""
    tasks = []
    years = [2025, 2024, 2023, 2022, 2021, 2020]
    for gid in GADM_STATES:
        for yr in years:
            tasks.append((dataset_key, gid, yr, 0))

    all_rows = []
    done = 0
    with ThreadPoolExecutor(max_workers=12) as ex:
        futs = {ex.submit(fetch_state_page, *t): t for t in tasks}
        for fut in as_completed(futs):
            done += 1
            rows = fut.result()
            all_rows.extend(rows)
            if done % 48 == 0 or done == len(tasks):
                print(f"  [{label}] {done}/{len(tasks)} bloques descargados ({len(all_rows):,} pts)")

    df = pd.DataFrame(all_rows, columns=["lon", "lat", "gadm_gid", "year"])
    # Peso por registro para reflejar la densidad real total de cada entidad federativa
    counts_by_gid = df["gadm_gid"].value_counts().to_dict()
    df["weight"] = df["gadm_gid"].map(
        lambda g: state_counts.get(g, 0) / max(1, counts_by_gid.get(g, 1))
    )
    return df


def main():
    print("1. Consultando estadísticas y facetas globales en GBIF e iNaturalist...")
    all_aves = requests.get(
        "https://api.gbif.org/v1/occurrence/search",
        params={"country": "MX", "taxonKey": 212, "limit": 0},
        timeout=25,
    ).json().get("count", 0)

    ebird_meta = fetch_gbif_facets(EBIRD_KEY)
    inat_meta = fetch_gbif_facets(INAT_KEY)
    inat_extra = fetch_inat_meta()

    summary = {
        "all_aves_mx": all_aves,
        "ebird": ebird_meta,
        "inat": inat_meta,
        "inat_extra": inat_extra,
        "gadm_states": GADM_STATES,
    }
    SUMMARY_JSON.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    print(
        f"   Totales -> All Aves MX: {all_aves:,} | eBird: {ebird_meta['count']:,} | "
        f"iNat Aves: {inat_meta['count']:,} | iNat Observadores: {inat_extra['observers']:,}"
    )

    print("2. Descargando muestra espacial estratificada de eBird (32 estados x 6 años)...")
    df_ebird = sample_dataset_points(EBIRD_KEY, ebird_meta["states"], "eBird")
    df_ebird.to_parquet(EBIRD_PARQUET, index=False)
    print(f"   Guardado {EBIRD_PARQUET} ({len(df_ebird):,} puntos)")

    print("3. Descargando muestra espacial estratificada de Naturalista/iNaturalist (32 estados x 6 años)...")
    df_inat = sample_dataset_points(INAT_KEY, inat_meta["states"], "Naturalista")
    df_inat.to_parquet(INAT_PARQUET, index=False)
    print(f"   Guardado {INAT_PARQUET} ({len(df_inat):,} puntos)")
    print("Pipeline completado.")


if __name__ == "__main__":
    main()
