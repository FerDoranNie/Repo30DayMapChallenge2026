"""
Día 15 — Serie metropolitana | Video de 40 s (10 s por ciudad)
Recorre los cuatro pósters con un zoom lento y fundidos a crema.

Uso: python days/day15_inside_out/day15_video.py
"""
from pathlib import Path

import cv2
import numpy as np

CIUDADES = ["cdmx", "mty", "gdl", "pue"]
W, H, FPS, SEG = 1080, 1440, 30, 10
CREAM = (235, 244, 247)  # BGR de #F7F4EB
FADE = int(0.5 * FPS)

src_dir = Path("outputs/high_res")
out = Path("outputs/gallery/day15_serie_4ciudades.mp4")

writer = cv2.VideoWriter(str(out), cv2.VideoWriter_fourcc(*"mp4v"), FPS, (W, H))
assert writer.isOpened(), "No se pudo abrir el VideoWriter"


def frame_at(img, t, n):
    """Zoom lento del 5% centrado."""
    h, w = img.shape[:2]
    s = 1.0 + 0.05 * (t / max(1, n - 1))
    cw, ch = int(w / s), int(h / s)
    x0, y0 = (w - cw) // 2, (h - ch) // 2
    crop = img[y0:y0 + ch, x0:x0 + cw]
    return cv2.resize(crop, (W, H), interpolation=cv2.INTER_AREA)


imgs = [cv2.imread(str(src_dir / f"day15_serie_{c}.png")) for c in CIUDADES]
assert all(i is not None for i in imgs), "Falta algún póster"

total = SEG * FPS
for idx, img in enumerate(imgs):
    n = total
    for t in range(n):
        f = frame_at(img, t, n)
        # fundido desde/hacia crema al inicio y fin de cada bloque
        if t < FADE:
            a = t / FADE
            f = cv2.addWeighted(f, a, np.full_like(f, CREAM), 1 - a, 0)
        if t >= n - FADE:
            a = (n - 1 - t) / FADE
            f = cv2.addWeighted(f, a, np.full_like(f, CREAM), 1 - a, 0)
        writer.write(f)
    print(f"{CIUDADES[idx]}: {n} frames", flush=True)

writer.release()
print("Video listo:", out)
