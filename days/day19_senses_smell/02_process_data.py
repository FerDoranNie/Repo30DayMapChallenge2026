"""
Día 19: Senses: Smell — Paisaje Olfativo Urbano de la Ciudad de México
Script 02: Extracción y limpieza tabular (RETC 2024 + Gasolineras 2024 + DENUE CDMX)
"""

import json
import os
import re
import zipfile

import numpy as np
import pandas as pd

RAW_DIR = os.path.join("data", "raw", "day19")
PROC_DIR = os.path.join("data", "processed")
os.makedirs(PROC_DIR, exist_ok=True)

# Gases de efecto invernadero inodoros (se excluyen del perfil olfativo químico)
INODOROS_GEI = {
    "bióxido de carbono",
    "dióxido de carbono",
    "metano",
    "oxido nitroso",
    "óxido nitroso",
    "hexafluoruro de azufre",
}

ODOR_NOTES = {
    "Estireno (fenil etileno)": "Dulce plástico / resina acre",
    "Clorobenceno (monoclorobenceno)": "Almendra química / solvente",
    "Tolueno": "Thinner / pegamento / laca",
    "Xileno (mezcla de isómeros)": "Aromático dulce / pintura",
    "Benceno": "Dulce a gasolina / hidrocarburo",
    "Acetato de vinilo": "Etéreo dulce / adhesivo",
    "Arsénico (polvos, respirables, vapores o humos)": "Aliáceo / metálico (humos)",
    "Fenol": "Medicinal / desinfectante acre",
    "Cloruro de metileno": "Dulzón clorinado / removedor",
    "Formaldehído": "Picante / irritante / formol",
    "Dibutilftalato": "Éster suave / plastificante",
    "Cumeno": "Aromático penetrante / petróleo",
    "Etilbenceno": "Dulce a gasolina / solvente",
    "Hexano": "Gasolina ligera / solvente",
}


def parse_dms(val, is_lon=False):
    if pd.isna(val):
        return np.nan
    s = str(val).strip()
    m = re.match(r"(\d+)[°\s]+(\d+)['\s]+([\d\.]+)", s)
    if not m:
        try:
            v = float(s)
            return -abs(v) if is_lon else abs(v)
        except Exception:
            return np.nan
    d, mn, sec = float(m.group(1)), float(m.group(2)), float(m.group(3))
    dec = d + mn / 60.0 + sec / 3600.0
    return -dec if is_lon else dec


def load_retc_table(zip_path, xlsx_name):
    with zipfile.ZipFile(zip_path) as z:
        with z.open(xlsx_name) as f:
            xl = pd.ExcelFile(f)
            dg = pd.read_excel(xl, sheet_name="Datos Generales", skiprows=9)
            et_sheet = (
                "Emisiones y Transferencias"
                if "Emisiones y Transferencias" in xl.sheet_names
                else "Emisiones Transferencias Verif"
            )
            et = pd.read_excel(xl, sheet_name=et_sheet, skiprows=9)
    return dg, et


def main():
    print("1. Extrayendo RETC Verificado 2024 y Gasolineras 2024 (CDMX)...")
    dg_retc, et_retc = load_retc_table(
        os.path.join(RAW_DIR, "RETC_Verificado_2004-2024.zip"), "retc 2024.xlsx"
    )
    dg_gas, et_gas = load_retc_table(
        os.path.join(RAW_DIR, "RETC_Gasolineras_2022-2024.zip"), "Gasolineras_2024.xlsx"
    )

    dg_retc_cdmx = dg_retc[dg_retc["ESTADO"] == "Ciudad de México"].copy()
    dg_retc_cdmx["fuente_retc"] = "RETC Industrial"
    dg_gas_cdmx = dg_gas[dg_gas["ESTADO"] == "Ciudad de México"].copy()
    dg_gas_cdmx["fuente_retc"] = "RETC Gasolineras"

    dg_all = pd.concat([dg_retc_cdmx, dg_gas_cdmx], ignore_index=True)
    dg_all["lat"] = dg_all["LATITUD NORTE REVISADA"].apply(lambda v: parse_dms(v, is_lon=False))
    dg_all["lon"] = dg_all["LONGITUD OESTE REVISADA"].apply(lambda v: parse_dms(v, is_lon=True))
    dg_all["utm_x"] = pd.to_numeric(dg_all["COORDENADA UTM X"], errors="coerce")
    dg_all["utm_y"] = pd.to_numeric(dg_all["COORDENADA UTM Y"], errors="coerce")

    et_all = pd.concat(
        [
            et_retc[et_retc["ESTADO"] == "Ciudad de México"].assign(fuente="RETC Industrial"),
            et_gas[et_gas["ESTADO"] == "Ciudad de México"].assign(fuente="RETC Gasolineras"),
        ],
        ignore_index=True,
    )
    et_all["AIRE_kg"] = pd.to_numeric(et_all["AIRE"], errors="coerce").fillna(0.0)
    et_air = et_all[et_all["AIRE_kg"] > 0].copy()
    et_air["es_gei_inodoro"] = et_air["SUSTANCIA"].astype(str).str.strip().str.lower().isin(INODOROS_GEI)
    et_voc = et_air[~et_air["es_gei_inodoro"]].copy()

    sub_sum = (
        et_voc.groupby("SUSTANCIA", as_index=False)
        .agg(establecimientos=("NRA", "nunique"), emision_kg=("AIRE_kg", "sum"))
        .sort_values("emision_kg", ascending=False)
    )
    sub_sum["emision_ton"] = sub_sum["emision_kg"] / 1000.0
    sub_sum["nota_olfativa"] = sub_sum["SUSTANCIA"].map(ODOR_NOTES).fillna("Compuesto volátil / químico")
    sub_sum.to_csv(os.path.join(PROC_DIR, "day19_substances.csv"), index=False)

    nra_voc = (
        et_voc.sort_values("AIRE_kg", ascending=False)
        .groupby("NRA", as_index=False)
        .agg(
            kg_voc=("AIRE_kg", "sum"),
            n_sustancias=("SUSTANCIA", "nunique"),
            sustancia_principal=("SUSTANCIA", "first"),
        )
    )
    retc_voc = dg_all.merge(nra_voc, on="NRA", how="inner")
    retc_voc["ton_voc"] = retc_voc["kg_voc"] / 1000.0
    cols_keep = [
        "NRA", "NOMBRE", "SECTOR", "MUNICIPIO", "fuente_retc",
        "lat", "lon", "utm_x", "utm_y",
        "kg_voc", "ton_voc", "n_sustancias", "sustancia_principal"
    ]
    retc_voc[cols_keep].to_csv(os.path.join(PROC_DIR, "day19_retc_voc_raw.csv"), index=False)
    print(f"   RETC VOC establecimientos extraídos: {len(retc_voc)}")

    print("2. Extrayendo DENUE INEGI CDMX...")
    usecols = ["id", "nom_estab", "codigo_act", "nombre_act", "cve_mun", "municipio", "latitud", "longitud"]
    with zipfile.ZipFile(os.path.join(RAW_DIR, "denue_09_csv.zip")) as z:
        with z.open("conjunto_de_datos/denue_inegi_09_.csv") as f:
            denue = pd.read_csv(f, usecols=usecols, encoding="latin-1", dtype={"codigo_act": str, "cve_mun": str})

    denue["latitud"] = pd.to_numeric(denue["latitud"], errors="coerce")
    denue["longitud"] = pd.to_numeric(denue["longitud"], errors="coerce")
    denue = denue.dropna(subset=["latitud", "longitud"]).copy()

    cod = denue["codigo_act"].astype(str).str.strip()
    cat_map = {}
    for c in ["722513", "722514"]:
        cat_map[c] = ("Aroma Cotidiano", "Tacos, tortas y antojitos")
    for c in ["311811", "311812", "311813", "311830"]:
        cat_map[c] = ("Aroma Cotidiano", "Panaderías y tortillerías")
    for c in ["722515", "311921", "311922"]:
        cat_map[c] = ("Aroma Cotidiano", "Cafeterías y tostadores")
    cat_map["466312"] = ("Aroma Floral", "Florerías y plantas")
    for c in ["811121", "325510", "467113", "434226"]:
        cat_map[c] = ("Solventes y Combustibles", "Hojalatería, pintura y solventes")
    cat_map["468411"] = ("Solventes y Combustibles", "Gasolineras y combustibles")
    for c in ["326110", "326160", "326191", "326193", "326194", "326198", "326199", "325993", "434222", "434314", "562121", "562122", "562921"]:
        cat_map[c] = ("Solventes y Combustibles", "Plásticos, química y residuos")

    denue["polo"] = cod.map(lambda x: cat_map[x][0] if x in cat_map else None)
    denue["subcat"] = cod.map(lambda x: cat_map[x][1] if x in cat_map else None)
    denue_smell = denue[denue["polo"].notna()].copy()

    denue_smell.to_csv(os.path.join(PROC_DIR, "day19_denue_smell.csv"), index=False)

    cat_summary = (
        denue_smell.groupby(["polo", "subcat"], as_index=False)
        .size()
        .rename(columns={"size": "n_establecimientos"})
        .sort_values(["polo", "n_establecimientos"], ascending=[True, False])
    )
    cat_summary.to_csv(os.path.join(PROC_DIR, "day19_categories.csv"), index=False)
    print(cat_summary.to_string(index=False))
    print("Extracción tabular completada.")


if __name__ == "__main__":
    main()
