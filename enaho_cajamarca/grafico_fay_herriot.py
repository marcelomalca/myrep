"""Gráficos de comparación: estimador directo vs. Fay-Herriot.

1. fay_herriot_<dpto>_<periodo>_comparacion.png: por nivel educativo, el directo y
   el EBLUP con sus intervalos al 95%, la predicción sintética y el peso γ.
2. fay_herriot_<dpto>_<periodo>_gamma.png: cómo el peso del directo (γ) cae
   cuando la muestra del área es pequeña.

Uso:
    python grafico_fay_herriot.py
    python grafico_fay_herriot.py --periodo 2024
"""

import argparse
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.lines import Line2D
from matplotlib.ticker import FuncFormatter

from grafico_ingreso_educacion import (ESPACIO_ETAPA, GRILLA, SUPERFICIE, TEXTO, TEXTO_SECUNDARIO, TEXTO_TENUE,
                                       configurar_fuente, posiciones, soles)

DIRECTO = "#2a78d6"
FAY_HERRIOT = "#eb6834"
SINTETICO = TEXTO_TENUE
DESPLAZAMIENTO = 0.18


def intervalo(ax, x0, x1, y, color):
    if pd.isna(x0) or pd.isna(x1):
        return
    ax.plot([x0, x1], [y, y], color=color, linewidth=2, solid_capstyle="round", zorder=3)


def comparacion(tabla, nombre, periodo_txt, alcance, salida):
    datos = tabla.set_index("nivel_educativo")
    pos = posiciones()
    fig, ax = plt.subplots(figsize=(12, 7.4), dpi=200)
    fig.patch.set_facecolor(SUPERFICIE)
    ax.set_facecolor(SUPERFICIE)

    for nivel, y in pos.items():
        f = datos.loc[nivel]
        yd, yf = y - DESPLAZAMIENTO, y + DESPLAZAMIENTO
        if f["n"] > 0:
            intervalo(ax, f["directo_ic95_inf"], f["directo_ic95_sup"], yd, DIRECTO)
            ax.scatter(f["directo"], yd, s=46, color=DIRECTO, edgecolor=SUPERFICIE, linewidth=1.5, zorder=4)
        intervalo(ax, f["fh_ic95_inf"], f["fh_ic95_sup"], yf, FAY_HERRIOT)
        ax.scatter(f["fh"], yf, s=46, color=FAY_HERRIOT, edgecolor=SUPERFICIE, linewidth=1.5, zorder=4)
        ax.scatter(f["sintetico"], y, marker="|", s=170, color=SINTETICO, linewidth=1.6, zorder=2)

        # Columnas de texto a la derecha del gráfico.
        cv_dir = "—" if pd.isna(f["cv_directo_pct"]) else f"{f['cv_directo_pct']:.1f}%"
        textos = [(1.10, f"{f['gamma']:.2f}"), (1.22, cv_dir), (1.34, f"{f['cv_fh_pct']:.1f}%"),
                  (1.48, soles(f["fh"]))]
        for x, t in textos:
            ax.annotate(t, xy=(x, y), xycoords=("axes fraction", "data"), ha="right", va="center",
                        fontsize=9, color=TEXTO if x == 1.48 else TEXTO_SECUNDARIO,
                        fontweight="semibold" if x == 1.48 else "normal", annotation_clip=False)
    for x, t in [(1.10, "γ"), (1.22, "CV\ndirecto"), (1.34, "CV\nFH"), (1.48, "Fay-\nHerriot")]:
        ax.annotate(t, xy=(x, -1.05), xycoords=("axes fraction", "data"), ha="right", va="center",
                    fontsize=8.5, color=TEXTO_SECUNDARIO, fontweight="semibold", annotation_clip=False)

    etiquetas = [f"{nivel}  (n={int(datos.loc[nivel, 'n']):,})" for nivel in pos]
    ax.set_yticks(list(pos.values()), etiquetas, fontsize=9.5, color=TEXTO)
    ax.set_ylim(max(pos.values()) + 0.7, -1.6)
    x_max = np.nanmax(tabla[["directo_ic95_sup", "fh_ic95_sup", "directo"]].to_numpy())
    ax.set_xlim(0, x_max * 1.04)
    ax.xaxis.set_major_formatter(FuncFormatter(soles))
    ax.tick_params(axis="x", labelsize=8.5, colors=TEXTO_SECUNDARIO, length=0)
    ax.tick_params(axis="y", length=0, pad=8)
    ax.grid(axis="x", color=GRILLA, linewidth=0.8, zorder=0)
    for lado in ("top", "right", "left"):
        ax.spines[lado].set_visible(False)
    ax.spines["bottom"].set_color(GRILLA)
    ax.set_xlabel(f"Ingreso laboral promedio mensual ({alcance})", fontsize=9.5, color=TEXTO_SECUNDARIO,
                  labelpad=8)

    leyenda = [
        Line2D([], [], color=DIRECTO, marker="o", linewidth=2, markersize=7, label="Directo (encuesta) ± IC 95%"),
        Line2D([], [], color=FAY_HERRIOT, marker="o", linewidth=2, markersize=7, label="Fay-Herriot (EBLUP) ± IC 95%"),
        Line2D([], [], color=SINTETICO, marker="|", linestyle="none", markersize=12, markeredgewidth=1.6,
               label="Predicción sintética del modelo"),
    ]
    fig.legend(handles=leyenda, loc="upper left", bbox_to_anchor=(0.012, 0.925), ncol=3, frameon=False,
               fontsize=9, labelcolor=TEXTO, handletextpad=0.5, columnspacing=1.6)
    fig.text(0.015, 0.965, f"Directo vs. Fay-Herriot: ingreso laboral por nivel educativo – {nombre}, {periodo_txt}",
             fontsize=14, fontweight="bold", color=TEXTO)
    fig.text(0.015, 0.018, "Áreas del modelo: departamento × nivel educativo (300). γ = peso del directo en el "
             "EBLUP (en logaritmos: log FH = γ·log directo + (1 − γ)·log sintético). CV directo «—»: varianza no estimable. "
             "Fuente: INEI – ENAHO.", fontsize=8, color=TEXTO_TENUE)
    fig.subplots_adjust(left=0.265, right=0.68, top=0.86, bottom=0.11)
    fig.savefig(salida, facecolor=SUPERFICIE)
    print(f"Gráfico guardado en {salida}")


def grafico_gamma(todas, departamento, nombre, periodo_txt, salida):
    con_muestra = todas[todas["n"] > 0]
    dpto = con_muestra[con_muestra["dpto"] == departamento]
    otros = con_muestra[con_muestra["dpto"] != departamento]
    fig, ax = plt.subplots(figsize=(10, 6), dpi=200)
    fig.patch.set_facecolor(SUPERFICIE)
    ax.set_facecolor(SUPERFICIE)
    ax.scatter(otros["n"], otros["gamma"], s=22, color=GRILLA, edgecolor=TEXTO_TENUE, linewidth=0.6,
               zorder=2, label="Otras áreas (departamento × nivel)")
    ax.scatter(dpto["n"], dpto["gamma"], s=64, color=DIRECTO, edgecolor=SUPERFICIE, linewidth=2, zorder=3,
               label=nombre)
    # Los puntos caen sobre una sola curva (con la GVF, γ depende solo de n), así que se
    # rotulan tres casos representativos; el resto está en el gráfico de comparación.
    por_nivel = dpto.set_index("nivel_educativo")
    rotulos = [
        (["Educación inicial", "Básica especial"], (8, 0.30)),
        (["Maestría / doctorado"], (500, 0.30)),
        (["Primaria incompleta"], (2500, 0.62)),
    ]
    for niveles, xy_texto in rotulos:
        niveles = [n for n in niveles if n in por_nivel.index]
        if not niveles:
            continue
        f = por_nivel.loc[niveles[0]]
        texto = " y ".join(niveles) + f"\nn = {int(f['n']):,}  →  γ = {f['gamma']:.2f}"
        ax.annotate(texto, xy=(f["n"], f["gamma"]), xytext=xy_texto, fontsize=9, color=TEXTO, va="center",
                    arrowprops=dict(arrowstyle="-", color=TEXTO_SECUNDARIO, linewidth=0.8,
                                    shrinkA=4, shrinkB=6), zorder=4)
    ax.set_xscale("log")
    ax.xaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{x:,.0f}"))
    ax.set_ylim(-0.03, 1.03)
    ax.set_xlabel("Casos muestrales del área (escala logarítmica)", fontsize=9.5, color=TEXTO_SECUNDARIO)
    ax.set_ylabel("γ: peso del estimador directo", fontsize=9.5, color=TEXTO_SECUNDARIO)
    ax.tick_params(colors=TEXTO_SECUNDARIO, labelsize=8.5, length=0)
    ax.grid(color=GRILLA, linewidth=0.8, zorder=0)
    for lado in ("top", "right"):
        ax.spines[lado].set_visible(False)
    for lado in ("bottom", "left"):
        ax.spines[lado].set_color(GRILLA)
    ax.legend(loc="lower right", frameon=False, fontsize=9, labelcolor=TEXTO)
    fig.text(0.015, 0.955, f"Cuánto confía Fay-Herriot en la encuesta – {periodo_txt}", fontsize=14,
             fontweight="bold", color=TEXTO)
    fig.text(0.015, 0.915, "Con muestras chicas la varianza del directo es grande, γ cae y el EBLUP se acerca "
             "a la predicción del modelo.", fontsize=9.5, color=TEXTO_SECUNDARIO)
    fig.subplots_adjust(left=0.08, right=0.97, top=0.86, bottom=0.11)
    fig.savefig(salida, facecolor=SUPERFICIE)
    print(f"Gráfico guardado en {salida}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--periodo", default="2020-2024")
    parser.add_argument("--departamento", default="06")
    parser.add_argument("--nombre", default="Cajamarca")
    parser.add_argument("--resultados", type=Path, default=Path(__file__).parent / "resultados")
    args = parser.parse_args()

    configurar_fuente()
    anios = args.periodo.split("-")
    periodo_txt = "–".join(anios)
    alcance = f"promedio {periodo_txt} en soles de {anios[-1]}" if len(anios) > 1 else "soles corrientes"
    tabla = pd.read_csv(args.resultados / f"fay_herriot_{args.departamento}_{args.periodo}.csv")
    todas = pd.read_csv(args.resultados / f"fay_herriot_{args.periodo}_todas_areas.csv", dtype={"dpto": str})
    base = args.resultados / f"fay_herriot_{args.departamento}_{args.periodo}"
    comparacion(tabla, args.nombre, periodo_txt, alcance, Path(f"{base}_comparacion.png"))
    grafico_gamma(todas, args.departamento, args.nombre, periodo_txt, Path(f"{base}_gamma.png"))


if __name__ == "__main__":
    main()
