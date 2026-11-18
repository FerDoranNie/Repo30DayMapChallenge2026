# -*- coding: utf-8 -*-
"""
#30DayMapChallenge 2026 — Día 17: Light & dark
Pipeline de datos: luces nocturnas (NASA Black Marble / VIIRS DNB) y registros de aves
migratorias nocturnas (eBird vía GBIF) en el corredor del Golfo de México.

Salidas:
  data/processed/day17_luces_blackmarble.png   -> compuesto anual VIIRS Black Marble (recorte Golfo)
  data/processed/day17_luces_luminance.npy     -> luminancia normalizada [0,1] alineada al PNG
  data/processed/day17_migrantes.parquet       -> puntos de especies migratorias nocturnas
  data/processed/day17_summary.json            -> conteos, serie mensual y metadatos

Autor: Fernando Dorantes Nieto (@FerDoranNie)
Entorno: Anaconda (data_engineering)
"""

from __future__ import annotations

import json
import math
import random
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import numpy as np
import pandas as pd
import requests
from PIL import Image

# -----------------------------------------------------------------------------
# 0. Rutas y constantes
# -----------------------------------------------------------------------------
PROC = Path("data/processed")
RAW = Path("data/raw/day17")
PROC.mkdir(parents=True, exist_ok=True)
RAW.mkdir(parents=True, exist_ok=True)

LIGHTS_PNG = PROC / "day17_luces_blackmarble.png"
LIGHTS_NPY = PROC / "day17_luces_luminance.npy"
MIG_PARQUET = PROC / "day17_migrantes.parquet"
SUMMARY_JSON = PROC / "day17_summary.json"

# Recorte del corredor del Golfo de México (Yucatán -> costa norte del Golfo)
LON_MIN, LON_MAX = -104.5, -80.0
LAT_MIN, LAT_MAX = 14.0, 32.5
WMS_W = 2600
WMS_H = int(round(WMS_W * (LAT_MAX - LAT_MIN) / ((LON_MAX - LON_MIN) * math.cos(math.radians(23.0)))))

GIBS = "https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi"

EBIRD_KEY = "4fa7b334-ce0d-4e88-aaae-2e0c138d049e"

# Especies migratorias neotropicales de vuelo nocturno (trans-Golfo / corredor del Golfo).
# Clave: nombre científico -> clave taxonómica GBIF (Backbone).
MIGRANT_SPECIES: dict[str, int] = {
    "Setophaga petechia": 7341834,
    "Setophaga castanea": 6093202,
    "Setophaga fusca": 6093199,
    "Setophaga striata": 6092935,
    "Setophaga caerulescens": 7341828,
    "Setophaga magnolia": 6093209,
    "Setophaga tigrina": 6093357,
    "Setophaga palmarum": 7341822,
    "Setophaga discolor": 7341789,
    "Setophaga dominica": 7341800,
    "Setophaga virens": 6092631,
    "Setophaga cerulea": 6093350,
    "Setophaga ruticilla": 2489985,
    "Setophaga americana": 6093345,
    "Setophaga citrina": 6093374,
    "Setophaga pensylvanica": 6092942,
    "Protonotaria citrea": 2489871,
    "Parkesia motacilla": 6093862,
    "Parkesia noveboracensis": 6093856,
    "Vermivora cyanoptera": 6093846,
    "Leiothlypis peregrina": 7415507,
    "Geothlypis formosa": 6093586,
    "Geothlypis philadelphia": 5789148,
    "Oporornis agilis": 2489611,
    "Icteria virens": 2489989,
    "Mniotilta varia": 2489613,
    "Seiurus aurocapilla": 2489590,
    "Helmitheros vermivorum": 2489603,
    "Limnothlypis swainsonii": 2489636,
    "Catharus fuscescens": 2490804,
    "Catharus minimus": 2490826,
    "Catharus ustulatus": 2490821,
    "Hylocichla mustelina": 2490872,
    "Dolichonyx oryzivorus": 2484417,
    "Passerina caerulea": 5230862,
    "Piranga rubra": 2488485,
    "Pheucticus ludovicianus": 2490494,
    "Coccyzus americanus": 2496287,
    "Contopus virens": 5229734,
    "Empidonax virescens": 2482802,
    "Vireo flavifrons": 2487453,
    "Vireo olivaceus": 2487430,
    "Icterus spurius": 5229935,
    "Chordeiles minor": 2497035,
    "Archilochus colubris": 5228514,
}

FALL_MONTHS = [8, 9, 10, 11]
SPRING_MONTHS = [3, 4, 5]
YEARS = "2015,2025"
PAGE = 300


# -----------------------------------------------------------------------------
# 1. Luces nocturnas
# -----------------------------------------------------------------------------
def fetch_black_marble(force: bool = False) -> None:
    """Descarga el compuesto anual VIIRS Black Marble (2016) recortado al Golfo."""
    if LIGHTS_PNG.exists() and LIGHTS_NPY.exists() and not force:
        print(f"   [cache] {LIGHTS_PNG.name}")
        return

    params = {
        "SERVICE": "WMS",
        "REQUEST": "GetMap",
        "VERSION": "1.3.0",
        "LAYERS": "VIIRS_Black_Marble",
        "CRS": "EPSG:4326",
        "BBOX": f"{LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX}",
        "WIDTH": WMS_W,
        "HEIGHT": WMS_H,
        "FORMAT": "image/png",
        "TIME": "2016-01-01",
    }
    r = requests.get(GIBS, params=params, timeout=180)
    r.raise_for_status()
    LIGHTS_PNG.write_bytes(r.content)

    with Image.open(LIGHTS_PNG) as im:
        arr = np.asarray(im.convert("RGB"), dtype=np.float32) / 255.0
    # Luminancia perceptual (sRGB) del render Black Marble
    lum = 0.2126 * arr[..., 0] + 0.7152 * arr[..., 1] + 0.0722 * arr[..., 2]
    lum = lum / max(lum.max(), 1e-6)
    np.save(LIGHTS_NPY, lum.astype(np.float32))
    print(f"   {LIGHTS_PNG.name}: {arr.shape[1]}x{arr.shape[0]} px")


# -----------------------------------------------------------------------------
# 2. Registros de aves migratorias nocturnas (eBird vía GBIF)
# -----------------------------------------------------------------------------
def _gbif(params: dict, tries: int = 3) -> dict:
    for attempt in range(tries):
        try:
            r = requests.get(
                "https://api.gbif.org/v1/occurrence/search",
                params={**params, "datasetKey": EBIRD_KEY},
                timeout=30,
            )
            data = r.json()
            if isinstance(data, dict):
                return data
        except Exception:
            pass
        time.sleep(0.6 * (attempt + 1))
    return {"count": 0, "results": []}


def fetch_page(species: str, taxon_key: int, month: int, year: int,
               offset: int) -> list[tuple]:
    """Descarga una pagina de 300 registros para especie, mes y año concretos.

    Se evita el paginado profundo (offset alto) de la API de GBIF porque degrada
    hasta el timeout; en su lugar se estratifica por año y se usan offsets cortos.
    """
    data = _gbif({
        "taxonKey": taxon_key,
        "limit": PAGE,
        "offset": offset,
        "decimalLatitude": f"{LAT_MIN},{LAT_MAX}",
        "decimalLongitude": f"{LON_MIN},{LON_MAX}",
        "month": month,
        "year": year,
        "hasCoordinate": "true",
        "hasGeospatialIssue": "false",
    })
    rows = []
    for rec in data.get("results", []):
        lat = rec.get("decimalLatitude")
        lon = rec.get("decimalLongitude")
        if lat is None or lon is None:
            continue
        rows.append((
            species,
            float(lon),
            float(lat),
            rec.get("month"),
            rec.get("year"),
            rec.get("countryCode"),
        ))
    return rows


def monthly_facets(taxon_key: int) -> dict[int, int]:
    data = _gbif({
        "taxonKey": taxon_key,
        "limit": 0,
        "decimalLatitude": f"{LAT_MIN},{LAT_MAX}",
        "decimalLongitude": f"{LON_MIN},{LON_MAX}",
        "hasCoordinate": "true",
        "hasGeospatialIssue": "false",
        "year": YEARS,
        "facet": "month",
        "facetLimit": 12,
    })
    out = {}
    for f in data.get("facets", []):
        for c in f.get("counts", []):
            try:
                out[int(c["name"])] = int(c["count"])
            except ValueError:
                pass
    return out


def main() -> None:
    print("1. Descargando luces nocturnas VIIRS Black Marble (GISS/GIBS)...", flush=True)
    fetch_black_marble()

    print("2. Serie mensual y volumen por especie en el corredor (facetas GBIF)...", flush=True)
    with ThreadPoolExecutor(max_workers=4) as ex:
        monthly = dict(zip(MIGRANT_SPECIES, ex.map(monthly_facets, MIGRANT_SPECIES.values())))
    counts: dict[tuple[str, int], int] = {
        (sp, m): int(dic.get(m, 0)) for sp, dic in monthly.items() for m in FALL_MONTHS
    }
    counts_by_species: dict[str, int] = {
        sp: sum(counts.get((sp, m), 0) for m in FALL_MONTHS) for sp in MIGRANT_SPECIES
    }
    total_pool = sum(counts_by_species.values())
    print(f"   Pool total (2015-2025, temporada Ago-Nov): {total_pool:,} registros", flush=True)

    print("3. Muestreo estratificado por anio y mes (offsets cortos)...", flush=True)
    rng = random.Random(20261117)
    tasks = []
    for sp, key in MIGRANT_SPECIES.items():
        for month in FALL_MONTHS:
            for year in rng.sample(range(2016, 2026), 3):
                tasks.append((sp, key, month, year, rng.choice([0, 300, 600])))
    print(f"   {len(tasks)} bloques de {PAGE} registros a solicitar", flush=True)

    rows: list[tuple] = []
    done = 0
    with ThreadPoolExecutor(max_workers=8) as ex:
        futs = {ex.submit(fetch_page, *t): t for t in tasks}
        for fut in as_completed(futs):
            done += 1
            rows.extend(fut.result())
            if done % 60 == 0 or done == len(tasks):
                print(f"   {done}/{len(tasks)} bloques ({len(rows):,} puntos)", flush=True)

    df = pd.DataFrame(rows, columns=["species", "lon", "lat", "month", "year", "country"])
    df = df.drop_duplicates(subset=["species", "lon", "lat", "month", "year"])
    df.to_parquet(MIG_PARQUET, index=False)
    print(f"   Guardado {MIG_PARQUET} ({len(df):,} puntos unicos)", flush=True)

    print("4. Consolidando serie mensual...", flush=True)
    serie = {m: 0 for m in range(1, 13)}
    for sp, dic in monthly.items():
        for m, v in dic.items():
            serie[m] += v

    summary = {
        "bbox": [LON_MIN, LAT_MIN, LON_MAX, LAT_MAX],
        "grid": [WMS_W, WMS_H],
        "years": YEARS,
        "n_species": len(MIGRANT_SPECIES),
        "pool_total": total_pool,
        "sampled_points": int(len(df)),
        "per_species": {sp: int(counts_by_species.get(sp, 0)) for sp in MIGRANT_SPECIES},
        "per_species_month": {f"{sp}|{m}": int(c) for (sp, m), c in counts.items()},
        "seasonal": {
            "fall_total": int(total_pool),
            "monthly_all_year": serie,
        },
        "countries": df["country"].value_counts().to_dict(),
        "sources": {
            "luces": "NASA Black Marble / VIIRS Day-Night Band (compuesto anual 2016) via NASA GIBS",
            "aves": "eBird Basic Dataset (Cornell Lab of Ornithology) via GBIF occurrence API",
        },
    }
    SUMMARY_JSON.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"   Guardado {SUMMARY_JSON}")
    print("Pipeline Día 17 completado.")


if __name__ == "__main__":
    main()
