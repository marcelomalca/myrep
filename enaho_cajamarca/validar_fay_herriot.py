"""Valida la implementación propia de Fay-Herriot contra el paquete samplics.

Ajusta el mismo modelo (mismas y, X y ψ) con fay_herriot.py y con
samplics.sae.EblupAreaModel (REML) y reporta las diferencias. También compara la
varianza directa vectorizada con la función original de ingreso_por_educacion.py.

Requiere: pip install samplics
Uso:
    python validar_fay_herriot.py
"""

import argparse
import warnings
from pathlib import Path

import numpy as np
import pandas as pd

import fay_herriot as fh
from ingreso_por_educacion import NIVELES, cargar_anio, descargar_modulo, leer_anios, media_ponderada


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--anios", type=leer_anios, default=leer_anios("2020-2024"))
    parser.add_argument("--datos", type=Path, default=Path(__file__).parent / "datos")
    args = parser.parse_args()

    anios = args.anios
    df = pd.concat([cargar_anio(descargar_modulo(a, args.datos), a, max(anios), len(anios)) for a in anios],
                   ignore_index=True)
    df["dpto"] = df["ubigeo"].str[:2]
    base = (df["ocu500"] == 1) & (df["ingreso_mensual"] > 0) & df["p301a"].notna()
    d = fh.directo_por_area(df, base, df["dpto"] + "_" + df["p301a"].fillna(0).astype(int).astype(str))
    d = d.reset_index()
    d["dpto"], d["p301a"] = d["area"].str[:2], d["area"].str[3:].astype(int)

    print("1) Varianza directa vectorizada vs. media_ponderada (Cajamarca):")
    for nivel in (1, 7, 11):
        media, ee = media_ponderada(df, base & (df["dpto"] == "06") & (df["p301a"] == nivel))
        fila = d[(d["dpto"] == "06") & (d["p301a"] == nivel)].iloc[0]
        print(f"   {NIVELES[nivel]:<38} media {media:9.3f} vs {fila['media']:9.3f}   "
              f"ee {ee:8.4f} vs {np.sqrt(fila['var']):8.4f}")

    d["y"] = np.log(d["media"])
    d["psi_directa"] = d["var"] / d["media"] ** 2
    d["psi"], _ = fh.suavizar_varianzas(d)
    X, _ = fh.matriz_diseno(d, sorted(d["dpto"].unique()), list(NIVELES))
    y, psi = d["y"].to_numpy(), d["psi"].to_numpy()
    modelo = fh.ajustar_fay_herriot(y, X, psi)
    eblup, _, _, mse = fh.predecir(modelo, X, y, psi)

    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        from samplics.sae import EblupAreaModel
        ref = EblupAreaModel()  # REML por defecto
        ref.fit(yhat=y, X=X, area=d["area"].to_numpy(), error_std=np.sqrt(psi), intercept=False,
                tol=1e-10, maxiter=200)
        ref.predict(X=X, area=d["area"].to_numpy(), intercept=False)
    est = np.array([ref.area_est[a] for a in d["area"]])
    mse_ref = np.array([ref.area_mse[a] for a in d["area"]])

    print("\n2) Fay-Herriot propio vs. samplics:")
    print(f"   σ²_u           {modelo['sigma2_u']:.8f} vs {ref.re_std ** 2:.8f}")
    print(f"   máx |Δβ|        {np.abs(modelo['beta'] - np.asarray(ref.fixed_effects)).max():.2e}")
    print(f"   máx |ΔEBLUP|    {np.abs(eblup - est).max():.2e}")
    print(f"   máx ΔMSE rel.   {np.abs(mse / mse_ref - 1).max():.2e}")


if __name__ == "__main__":
    main()
