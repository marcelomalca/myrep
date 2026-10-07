"""Estimación de áreas pequeñas con el modelo de Fay-Herriot (ejercicio didáctico).

Compara el estimador directo del ingreso laboral promedio por nivel educativo en
un departamento con el EBLUP de Fay-Herriot. Las "áreas" son las combinaciones
departamento × nivel educativo (25 × 12 = 300): cada área toma prestada
información de las demás a través de un modelo de regresión.

Modelo (en logaritmos, porque el ingreso es asimétrico y los efectos de
departamento y nivel educativo son multiplicativos):

    Muestreo:  y_d = θ_d + e_d,         e_d ~ N(0, ψ_d)   ψ_d conocida
    Enlace:    θ_d = x_d'β + u_d,       u_d ~ N(0, σ²_u)

    y_d  = log del promedio directo del área d
    x_d  = constante + efectos fijos de departamento + efectos fijos de nivel educativo
    u_d  = efecto aleatorio del área (lo que el modelo no explica)

El EBLUP es un promedio ponderado entre el directo y la predicción sintética:

    θ̂_d = γ_d · y_d + (1 − γ_d) · x_d'β̂,      γ_d = σ²_u / (σ²_u + ψ_d)

Cuanto más preciso es el directo (ψ_d chico), más pesa γ_d. Las áreas sin
muestra reciben solo la predicción sintética x_d'β̂.

Pasos:
  1. Estimación directa por área (media ponderada y varianza por linealización).
  2. Suavizado de varianzas (función generalizada de varianza, GVF):
     log ψ_d = a + b · log n_d, ajustada con las áreas de varianza confiable.
  3. σ²_u por REML (Fisher scoring) y β̂ por mínimos cuadrados generalizados.
  4. EBLUP y su error cuadrático medio (Prasad-Rao para REML).
  5. Vuelta a soles: exp(θ̂ + MSE/2) (corrección de sesgo simple).

Uso:
    python fay_herriot.py                     # Cajamarca, ENAHO 2020-2024
    python fay_herriot.py --anios 2024
"""

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

from ingreso_por_educacion import NIVELES, cargar_anio, descargar_modulo, leer_anios

N_MINIMO_GVF = 30  # áreas usadas para ajustar la GVF: al menos 30 casos y 2 conglomerados


def directo_por_area(df, base, area):
    """Media ponderada y varianza (linealización de Taylor) para todas las áreas a la vez.

    Misma fórmula que ingreso_por_educacion.media_ponderada, vectorizada: en cada
    estrato h con n_h conglomerados, Σ_c (z_c − z̄_h)² = Σ z_c² − (Σ z_c)² / n_h,
    y los conglomerados sin casos del área aportan z_c = 0.
    """
    d = df.loc[base, ["estrato", "conglome", "fac500a", "ingreso_mensual"]].copy()
    d["area"] = area[base]
    d["wy"] = d["fac500a"] * d["ingreso_mensual"]
    totales = d.groupby("area").agg(n=("conglome", "size"), upm=("conglome", "nunique"),
                                    w_area=("fac500a", "sum"), wy=("wy", "sum"))
    totales["media"] = totales["wy"] / totales["w_area"]
    d = d.join(totales[["media", "w_area"]], on="area")
    d["u"] = d["fac500a"] * (d["ingreso_mensual"] - d["media"]) / d["w_area"]
    z = d.groupby(["area", "estrato", "conglome"])["u"].sum().reset_index()
    n_h = df.groupby("estrato")["conglome"].nunique().rename("n_h")
    por_estrato = z.groupby(["area", "estrato"])["u"].agg(suma="sum", suma2=lambda s: (s ** 2).sum())
    por_estrato = por_estrato.join(n_h, on="estrato")
    por_estrato["var"] = (por_estrato["n_h"] / (por_estrato["n_h"] - 1)
                          * (por_estrato["suma2"] - por_estrato["suma"] ** 2 / por_estrato["n_h"]))
    totales["var"] = por_estrato.groupby("area")["var"].sum()
    totales.loc[totales["upm"] < 2, "var"] = np.nan  # varianza no estimable
    return totales[["n", "upm", "media", "var"]].astype(float)


def suavizar_varianzas(areas):
    """GVF: regresión de log ψ_d sobre log n_d con las áreas de varianza confiable.

    Devuelve ψ suavizada para todas las áreas con muestra y los coeficientes.
    Incluye el factor de corrección de Duan (smearing) al volver de logaritmos.
    """
    ok = (areas["n"] >= N_MINIMO_GVF) & (areas["upm"] >= 2) & (areas["psi_directa"] > 0)
    X = np.column_stack([np.ones(ok.sum()), np.log(areas.loc[ok, "n"])])
    y = np.log(areas.loc[ok, "psi_directa"])
    coef, *_ = np.linalg.lstsq(X, y, rcond=None)
    residuos = y - X @ coef
    smearing = np.mean(np.exp(residuos))
    r2 = 1 - residuos.var() / y.var()
    psi = np.exp(coef[0] + coef[1] * np.log(areas["n"])) * smearing
    return psi, {"a": coef[0], "b": coef[1], "smearing": smearing, "r2": r2, "areas_ajuste": int(ok.sum())}


def reml_fay_herriot(y, X, psi, iteraciones=100, tolerancia=1e-8):
    """σ²_u por REML con Fisher scoring.

    score(σ²) = −½ tr(P) + ½ y'PPy,   información(σ²) = ½ tr(PP),
    P = V⁻¹ − V⁻¹X(X'V⁻¹X)⁻¹X'V⁻¹,    V = diag(σ² + ψ_d).
    """
    sigma2 = max(np.var(y - X @ np.linalg.lstsq(X, y, rcond=None)[0]) - psi.mean(), 1e-4)
    for _ in range(iteraciones):
        v_inv = 1 / (sigma2 + psi)
        xtvx = X.T @ (X * v_inv[:, None])
        P = np.diag(v_inv) - (X * v_inv[:, None]) @ np.linalg.solve(xtvx, (X * v_inv[:, None]).T)
        Py = P @ y
        score = -0.5 * np.trace(P) + 0.5 * Py @ Py
        info = 0.5 * np.sum(P * P)
        nuevo = max(sigma2 + score / info, 0.0)
        if abs(nuevo - sigma2) < tolerancia:
            sigma2 = nuevo
            break
        sigma2 = nuevo
    return sigma2, info


def ajustar_fay_herriot(y, X, psi):
    sigma2, info = reml_fay_herriot(y, X, psi)
    v_inv = 1 / (sigma2 + psi)
    xtvx_inv = np.linalg.inv(X.T @ (X * v_inv[:, None]))
    beta = xtvx_inv @ X.T @ (v_inv * y)
    return {"sigma2_u": sigma2, "beta": beta, "xtvx_inv": xtvx_inv,
            "var_sigma2": 2 / np.sum(v_inv ** 2)}  # varianza asintótica de σ̂²_u (REML)


def predecir(modelo, X, y=None, psi=None):
    """EBLUP y MSE de Prasad-Rao (g1 + g2 + 2·g3). Sin y: predicción sintética."""
    s2, beta, xtvx_inv = modelo["sigma2_u"], modelo["beta"], modelo["xtvx_inv"]
    sintetico = X @ beta
    g_x = np.einsum("ij,jk,ik->i", X, xtvx_inv, X)  # x_d'(X'V⁻¹X)⁻¹x_d
    if y is None:
        return sintetico, sintetico, np.zeros(len(X)), s2 + g_x
    gamma = s2 / (s2 + psi)
    eblup = gamma * y + (1 - gamma) * sintetico
    g1 = gamma * psi
    g2 = (1 - gamma) ** 2 * g_x
    g3 = psi ** 2 / (s2 + psi) ** 3 * modelo["var_sigma2"]
    return eblup, sintetico, gamma, g1 + g2 + 2 * g3


def matriz_diseno(areas, categorias_dpto, categorias_nivel):
    """Constante + dummies de departamento + dummies de nivel educativo (primera categoría como base)."""
    dpto = pd.Categorical(areas["dpto"], categories=categorias_dpto)
    nivel = pd.Categorical(areas["p301a"], categories=categorias_nivel)
    X = pd.concat([pd.get_dummies(dpto, prefix="dpto", drop_first=True),
                   pd.get_dummies(nivel, prefix="nivel", drop_first=True)], axis=1).astype(float)
    X.insert(0, "constante", 1.0)
    return X.to_numpy(), list(X.columns)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--anios", type=leer_anios, default=leer_anios("2020-2024"))
    parser.add_argument("--departamento", default="06")
    parser.add_argument("--datos", type=Path, default=Path(__file__).parent / "datos")
    parser.add_argument("--salida", type=Path, default=Path(__file__).parent / "resultados")
    args = parser.parse_args()

    anios, anio_base = args.anios, max(args.anios)
    df = pd.concat([cargar_anio(descargar_modulo(a, args.datos), a, anio_base, len(anios)) for a in anios],
                   ignore_index=True)
    df["dpto"] = df["ubigeo"].str[:2]
    # Ocupados con ingreso y nivel educativo informado (unos pocos casos no reportan p301a).
    base = (df["ocu500"] == 1) & (df["ingreso_mensual"] > 0) & df["p301a"].notna()

    # 1. Estimación directa por área (departamento × nivel educativo).
    directo = directo_por_area(df, base, df["dpto"] + "_" + df["p301a"].fillna(0).astype(int).astype(str))
    dptos = sorted(df.loc[base, "dpto"].unique())
    areas = pd.MultiIndex.from_product([dptos, list(NIVELES)], names=["dpto", "p301a"]).to_frame(index=False)
    areas["area"] = areas["dpto"] + "_" + areas["p301a"].astype(str)
    areas = areas.join(directo, on="area")
    areas["n"] = areas["n"].fillna(0).astype(int)
    areas["upm"] = areas["upm"].fillna(0).astype(int)

    # En logaritmos: y = log(media), ψ = var / media² (método delta).
    con_muestra = areas["n"] > 0
    areas["y"] = np.log(areas["media"])
    areas["psi_directa"] = areas["var"] / areas["media"] ** 2

    # 2. Varianzas suavizadas.
    areas.loc[con_muestra, "psi"], gvf = suavizar_varianzas(areas[con_muestra])

    # 3-4. Ajuste y predicción.
    X, nombres = matriz_diseno(areas, dptos, list(NIVELES))
    m = con_muestra.to_numpy()
    modelo = ajustar_fay_herriot(areas.loc[m, "y"].to_numpy(), X[m], areas.loc[m, "psi"].to_numpy())
    eblup, sint, gamma, mse = predecir(modelo, X[m], areas.loc[m, "y"].to_numpy(), areas.loc[m, "psi"].to_numpy())
    areas.loc[m, ["eta_fh", "eta_sintetico", "gamma", "mse_log"]] = np.column_stack([eblup, sint, gamma, mse])
    if (~m).any():
        eblup, sint, gamma, mse = predecir(modelo, X[~m])
        areas.loc[~m, ["eta_fh", "eta_sintetico", "gamma", "mse_log"]] = np.column_stack([eblup, sint, gamma, mse])

    # 5. De vuelta a soles.
    areas["fh"] = np.exp(areas["eta_fh"] + areas["mse_log"] / 2)
    areas["sintetico"] = np.exp(areas["eta_sintetico"])
    areas["cv_fh_pct"] = 100 * np.sqrt(np.exp(areas["mse_log"]) - 1)
    areas["fh_ic95_inf"] = np.exp(areas["eta_fh"] - 1.96 * np.sqrt(areas["mse_log"]))
    areas["fh_ic95_sup"] = np.exp(areas["eta_fh"] + 1.96 * np.sqrt(areas["mse_log"]))
    areas["ee_directo"] = np.sqrt(areas["var"])
    areas["cv_directo_pct"] = 100 * areas["ee_directo"] / areas["media"]
    areas["directo_ic95_inf"] = areas["media"] - 1.96 * areas["ee_directo"]
    areas["directo_ic95_sup"] = areas["media"] + 1.96 * areas["ee_directo"]
    areas["nivel_educativo"] = areas["p301a"].map(NIVELES)

    periodo = f"{anios[0]}-{anios[-1]}" if len(anios) > 1 else str(anios[0])
    columnas = ["dpto", "nivel_educativo", "n", "upm", "media", "directo_ic95_inf", "directo_ic95_sup",
                "cv_directo_pct", "sintetico", "gamma", "fh", "fh_ic95_inf", "fh_ic95_sup", "cv_fh_pct"]
    salida = areas[columnas].rename(columns={"media": "directo"}).round(
        {"directo": 1, "directo_ic95_inf": 1, "directo_ic95_sup": 1, "cv_directo_pct": 1, "sintetico": 1,
         "gamma": 3, "fh": 1, "fh_ic95_inf": 1, "fh_ic95_sup": 1, "cv_fh_pct": 1})
    args.salida.mkdir(parents=True, exist_ok=True)
    salida.to_csv(args.salida / f"fay_herriot_{periodo}_todas_areas.csv", index=False, encoding="utf-8")
    dpto = salida[salida["dpto"] == args.departamento].drop(columns="dpto")
    archivo = args.salida / f"fay_herriot_{args.departamento}_{periodo}.csv"
    dpto.to_csv(archivo, index=False, encoding="utf-8")

    print(f"Áreas: {len(areas)} ({m.sum()} con muestra, {(~m).sum()} sin muestra)")
    print(f"GVF: log ψ = {gvf['a']:.3f} + {gvf['b']:.3f}·log n  (R² = {gvf['r2']:.2f}, "
          f"{gvf['areas_ajuste']} áreas, smearing = {gvf['smearing']:.3f})")
    print(f"σ²_u (REML) = {modelo['sigma2_u']:.5f}   ee = {np.sqrt(modelo['var_sigma2']):.5f}")
    efectos = dict(zip(nombres, modelo["beta"]))
    print("Efectos de nivel educativo (exp β, relativo a 'Sin nivel'):")
    for k, nivel in NIVELES.items():
        if f"nivel_{k}" in efectos:
            print(f"   {nivel:<38} ×{np.exp(efectos[f'nivel_{k}']):.2f}")
    pd.set_option("display.width", 220)
    print(f"\n== Departamento {args.departamento}, {periodo} (S/ de {anio_base} por mes) -> {archivo}")
    print(dpto.to_string(index=False))


if __name__ == "__main__":
    main()
