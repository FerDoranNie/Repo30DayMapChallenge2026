"""
Utilidades y Tema Visual Base en Python — #30DayMapChallenge 2026
Autor: Fernando Dorantes Nieto (@FerDoranNie)
"""

import matplotlib.pyplot as plt


def apply_map_style(
    bg_color: str = "#F7F4EB",
    panel_color: str = "#DCE6F2",
    text_color: str = "#0f172a",
):
    """Configura parámetros globales de Matplotlib con estilo Atlas (lienzo crema y océano azul pálido)."""
    plt.rcParams.update({
        "figure.facecolor": bg_color,
        "axes.facecolor": panel_color,
        "axes.edgecolor": "#94a3b8",
        "axes.linewidth": 0.7,
        "savefig.facecolor": bg_color,
        "text.color": text_color,
        "axes.labelcolor": text_color,
        "xtick.color": text_color,
        "ytick.color": text_color,
        "figure.dpi": 300,
    })


def map_caption(day: int, prompt: str, source: str) -> str:
    """Genera el texto estándar de créditos para el pie del mapa."""
    return (
        f"#30DayMapChallenge 2026 | Día {day:02d}: {prompt}\n"
        f"Datos: {source} | Gráfico: Fernando Dorantes Nieto (@FerDoranNie)"
    )
