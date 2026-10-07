"""Gráfico de barras horizontales: ingreso laboral promedio por nivel educativo.

Lee la tabla detallada que genera ingreso_por_educacion.py y dibuja los 12 niveles
de p301a de la ENAHO, con su intervalo de confianza al 95%.

Uso:
    python grafico_ingreso_educacion.py                   # Cajamarca, 2020-2024
    python grafico_ingreso_educacion.py --periodo 2024
    python grafico_ingreso_educacion.py --departamento 15 --nombre Lima
"""

import argparse
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib import font_manager
from matplotlib.ticker import FuncFormatter

SUPERFICIE = "#fcfcfb"
TEXTO = "#0b0b0b"
TEXTO_SECUNDARIO = "#52514e"
TEXTO_TENUE = "#8a8984"
GRILLA = "#e6e5e0"
SERIE = "#2a78d6"

# Etapas educativas: los niveles de una misma etapa van juntos y las etapas se
# separan con un espacio extra en el eje vertical.
ETAPAS = [
    ["Sin nivel", "Educación inicial"],
    ["Primaria incompleta", "Primaria completa"],
    ["Secundaria incompleta", "Secundaria completa"],
    ["Superior no universitaria incompleta", "Superior no universitaria completa"],
    ["Superior universitaria incompleta", "Superior universitaria completa", "Maestría / doctorado"],
    ["Básica especial"],
]
ESPACIO_ETAPA = 0.5


def soles(x, _=None):
    return f"S/ {x:,.0f}"


def posiciones():
    y, pos = 0.0, {}
    for etapa in ETAPAS:
        for nivel in etapa:
            pos[nivel] = y
            y += 1
        y += ESPACIO_ETAPA
    return pos


def configurar_fuente():
    disponibles = {f.name for f in font_manager.fontManager.ttflist}
    for nombre in ("Inter", "Helvetica", "Arial", "DejaVu Sans"):
        if nombre in disponibles:
            plt.rcParams["font.family"] = nombre
            return


def graficar(tabla, nombre, periodo, salida):
    anios = periodo.split("-")
    periodo_txt = "–".join(anios)
    alcance = (f"promedio {periodo_txt} en soles de {anios[-1]}" if len(anios) > 1
               else "soles corrientes")
    configurar_fuente()
    total = tabla.set_index("nivel_educativo").loc["Total", "ingreso_promedio"]
    datos = tabla[tabla["nivel_educativo"] != "Total"].set_index("nivel_educativo")
    pos = posiciones()

    fig, ax = plt.subplots(figsize=(10, 7.2), dpi=200)
    fig.patch.set_facecolor(SUPERFICIE)
    ax.set_facecolor(SUPERFICIE)

    x_max = datos["ic95_sup"].max()
    # Fondo del color de la superficie para que la línea del promedio pase por detrás del texto.
    fondo = dict(facecolor=SUPERFICIE, edgecolor="none", pad=1.5)
    for nivel, y in pos.items():
        fila = datos.loc[nivel]
        if fila["n_muestral"] == 0:
            ax.text(x_max * 0.01, y, "sin casos en la muestra", va="center", fontsize=9,
                    color=TEXTO_TENUE, style="italic", bbox=fondo, zorder=4)
            continue
        referencial = fila["confiable"] != "sí"
        ax.barh(y, fila["ingreso_promedio"], height=0.56, color=SUPERFICIE if referencial else SERIE,
                edgecolor=SERIE, linewidth=1.2, hatch="////" if referencial else None, zorder=2)
        if pd.notna(fila["error_estandar"]) and fila["error_estandar"] > 0:
            ax.plot([fila["ic95_inf"], fila["ic95_sup"]], [y, y], color=TEXTO_SECUNDARIO,
                    linewidth=1.2, solid_capstyle="butt", zorder=3)
            for extremo in (fila["ic95_inf"], fila["ic95_sup"]):
                ax.plot([extremo, extremo], [y - 0.12, y + 0.12], color=TEXTO_SECUNDARIO,
                        linewidth=1.2, zorder=3)
        x_etiqueta = fila[["ingreso_promedio", "ic95_sup"]].max() + x_max * 0.012
        valor = ax.text(x_etiqueta, y, soles(fila["ingreso_promedio"]), va="center", fontsize=9.5,
                        color=TEXTO, fontweight="semibold", bbox=fondo, zorder=4)
        if referencial:
            ax.annotate("referencial", xy=(1, 0.5), xycoords=valor, xytext=(6, 0),
                        textcoords="offset points", va="center", fontsize=8, color=TEXTO_TENUE,
                        style="italic", bbox=fondo, zorder=4)

    ax.axvline(total, color=TEXTO_SECUNDARIO, linewidth=1, linestyle=(0, (4, 3)), zorder=1)
    ax.text(total + x_max * 0.008, -0.85, f"Promedio {nombre}: {soles(total)}", fontsize=8.5,
            color=TEXTO_SECUNDARIO, va="center")

    etiquetas = [f"{nivel}  (n={int(datos.loc[nivel, 'n_muestral']):,})" for nivel in pos]
    ax.set_yticks(list(pos.values()), etiquetas, fontsize=9.5, color=TEXTO)
    ax.set_ylim(max(pos.values()) + 0.7, -1.3)
    ax.set_xlim(0, x_max * 1.14)
    ax.xaxis.set_major_formatter(FuncFormatter(soles))
    ax.tick_params(axis="x", labelsize=8.5, colors=TEXTO_SECUNDARIO, length=0)
    ax.tick_params(axis="y", length=0, pad=8)
    ax.grid(axis="x", color=GRILLA, linewidth=0.8, zorder=0)
    for lado in ("top", "right", "left"):
        ax.spines[lado].set_visible(False)
    ax.spines["bottom"].set_color(GRILLA)
    ax.set_xlabel(f"Ingreso laboral promedio mensual ({alcance})", fontsize=9.5,
                  color=TEXTO_SECUNDARIO, labelpad=8)

    fig.text(0.015, 0.965, f"Ingreso laboral promedio mensual por nivel educativo – {nombre}, {periodo_txt}",
             fontsize=14, fontweight="bold", color=TEXTO)
    fig.text(0.015, 0.932, f"Ocupados con ingreso laboral positivo ({alcance}). Las líneas indican el "
             "intervalo de confianza al 95%.", fontsize=9.5, color=TEXTO_SECUNDARIO)
    fig.text(0.015, 0.018, f"Fuente: INEI – ENAHO {periodo_txt}, módulo 500; IPC Lima del BCRP. Barras rayadas: estimación referencial "
             "(CV > 15% o menos de 30 casos); n = casos muestrales.", fontsize=8, color=TEXTO_TENUE)
    fig.subplots_adjust(left=0.33, right=0.97, top=0.9, bottom=0.11)
    fig.savefig(salida, facecolor=SUPERFICIE)
    print(f"Gráfico guardado en {salida}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--periodo", default="2020-2024", help="Periodo de la tabla: 2020-2024 o 2024")
    parser.add_argument("--departamento", default="06")
    parser.add_argument("--nombre", default="Cajamarca", help="Nombre del departamento para el título")
    parser.add_argument("--resultados", type=Path, default=Path(__file__).parent / "resultados")
    args = parser.parse_args()

    base = f"ingreso_educacion_{args.departamento}_{args.periodo}"
    tabla = pd.read_csv(args.resultados / f"{base}_detalle.csv")
    graficar(tabla, args.nombre, args.periodo, args.resultados / f"{base}_grafico.png")


if __name__ == "__main__":
    main()
