"""
Día 19: Senses: Smell — Paisaje Olfativo Urbano de la Ciudad de México
Script 01: Descarga de datos oficiales (RETC SEMARNAT 2024 + DENUE INEGI CDMX)
"""

import os
import requests
import urllib3

urllib3.disable_warnings()

RAW_DIR = os.path.join("data", "raw", "day19")
os.makedirs(RAW_DIR, exist_ok=True)

FILES = {
    "RETC_Verificado_2004-2024.zip": "https://apps1.semarnat.gob.mx:8443/retc/retc/RETC_Verificado_2004-2024.zip",
    "RETC_Gasolineras_2022-2024.zip": "https://apps1.semarnat.gob.mx:8443/retc/retc/RETC_Gasolineras_2022-2024.zip",
    "denue_09_csv.zip": "https://www.inegi.org.mx/contenidos/masiva/denue/denue_09_csv.zip",
}


def main():
    for fname, url in FILES.items():
        out_path = os.path.join(RAW_DIR, fname)
        if os.path.exists(out_path) and os.path.getsize(out_path) > 0:
            print(f"[OK] Ya existe: {out_path} ({os.path.getsize(out_path):,} bytes)")
            continue
        print(f"[Descargando] {fname} desde {url} ...")
        r = requests.get(url, stream=True, timeout=180, verify=False)
        r.raise_for_status()
        with open(out_path, "wb") as f:
            for chunk in r.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    f.write(chunk)
        print(f"[OK] Guardado: {out_path} ({os.path.getsize(out_path):,} bytes)")


if __name__ == "__main__":
    main()
