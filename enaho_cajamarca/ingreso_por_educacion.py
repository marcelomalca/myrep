"""Ingreso laboral promedio mensual por nivel educativo en un departamento del Perú.

Fuente: ENAHO (INEI), módulo 500 "Empleo e Ingresos". El archivo del módulo 500
ya trae la variable de nivel educativo (p301a), idéntica a la del módulo 300,
por lo que no hace falta unir ambos módulos.

Uso:
    python ingreso_por_educacion.py                 # Cajamarca (06), ENAHO 2024
    python ingreso_por_educacion.py --departamento 15
"""

import argparse
import io
import urllib.request
import zipfile
from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat

# Código de encuesta en el portal de microdatos del INEI (ENAHO anual, metodología actualizada).
CODIGO_INEI = {2024: 966}
URL_MODULO = "https://proyectos.inei.gob.pe/iinei/srienaho/descarga/STATA/{codigo}-Modulo05.zip"

# Componentes anuales del ingreso laboral (ocupación principal y secundaria,
# monetario y en especie, más ingresos extraordinarios por trabajo dependiente).
COMPONENTES_INGRESO = [
    "i524a1",  # dependiente, ocupación principal (monetario)
    "d529t",   # dependiente, ocupación principal (especie)
    "i530a",   # independiente, ocupación principal (ganancia neta)
    "d536",    # independiente, ocupación principal (autoconsumo)
    "i538a1",  # dependiente, ocupación secundaria (monetario)
    "d540t",   # dependiente, ocupación secundaria (especie)
    "i541a",   # independiente, ocupación secundaria (ganancia neta)
    "d543",    # independiente, ocupación secundaria (autoconsumo)
    "d544t",   # ingresos extraordinarios (gratificaciones, CTS, etc.)
]

NIVELES = {
    1: "Sin nivel",
    2: "Educación inicial",
    3: "Primaria incompleta",
    4: "Primaria completa",
    5: "Secundaria incompleta",
    6: "Secundaria completa",
    7: "Superior no universitaria incompleta",
    8: "Superior no universitaria completa",
    9: "Superior universitaria incompleta",
    10: "Superior universitaria completa",
    11: "Maestría / doctorado",
    12: "Básica especial",
}

# Agrupación usada habitualmente por el INEI en sus publicaciones de empleo e ingreso.
GRUPOS = {
    1: "Primaria o menos", 2: "Primaria o menos", 3: "Primaria o menos",
    4: "Primaria o menos", 12: "Primaria o menos",
    5: "Secundaria", 6: "Secundaria",
    7: "Superior no universitaria", 8: "Superior no universitaria",
    9: "Superior universitaria", 10: "Superior universitaria", 11: "Superior universitaria",
}
ORDEN_GRUPOS = ["Primaria o menos", "Secundaria", "Superior no universitaria", "Superior universitaria"]

CV_MAXIMO = 0.15  # umbral del INEI para considerar una estimación confiable
N_MINIMO = 30     # casos muestrales mínimos para no marcar la celda como referencial


def descargar_modulo(anio, carpeta):
    destino = carpeta / f"enaho01a-{anio}-500.dta"
    if destino.exists():
        return destino
    url = URL_MODULO.format(codigo=CODIGO_INEI[anio])
    print(f"Descargando {url} ...")
    with urllib.request.urlopen(url) as resp:
        contenido = resp.read()
    with zipfile.ZipFile(io.BytesIO(contenido)) as zf:
        nombre = next(n for n in zf.namelist() if n.lower().endswith(f"enaho01a-{anio}-500.dta"))
        carpeta.mkdir(parents=True, exist_ok=True)
        destino.write_bytes(zf.read(nombre))
    return destino


def cargar_datos(ruta):
    columnas = ["conglome", "ubigeo", "estrato", "ocu500", "fac500a", "p301a", "p507"] + COMPONENTES_INGRESO
    df, _ = pyreadstat.read_dta(str(ruta), usecols=columnas)
    df["ingreso_mensual"] = df[COMPONENTES_INGRESO].sum(axis=1) / 12
    df["fac500a"] = df["fac500a"].fillna(0)
    return df


def media_ponderada(df, en_dominio, y="ingreso_mensual", w="fac500a"):
    """Media ponderada (estimador de razón) y su error estándar por linealización de Taylor.

    El dominio se estima sobre la muestra nacional completa (estratos = estrato,
    UPM = conglome), así los conglomerados fuera del dominio aportan ceros y la
    varianza respeta el diseño muestral.
    """
    wd = df[w] * en_dominio
    total_w = wd.sum()
    media = (wd * df[y]).sum() / total_w
    u = wd * (df[y] - media) / total_w
    z = u.groupby([df["estrato"], df["conglome"]]).sum()
    var = 0.0
    for _, zh in z.groupby(level=0):
        n = len(zh)
        if n > 1:
            var += n / (n - 1) * ((zh - zh.mean()) ** 2).sum()
    return media, np.sqrt(var)


def mediana_ponderada(valores, pesos):
    orden = np.argsort(valores)
    v, p = np.asarray(valores)[orden], np.asarray(pesos)[orden]
    acumulado = np.cumsum(p)
    return v[np.searchsorted(acumulado, acumulado[-1] / 2)]


def tabla(df, base, categorias, columna):
    filas = []
    for cat in categorias + ["Total"]:
        en_dominio = base if cat == "Total" else base & (df[columna] == cat)
        sub = df[en_dominio]
        if sub.empty:
            filas.append({"nivel_educativo": cat, "n_muestral": 0, "poblacion_expandida": 0,
                          "confiable": "sin casos"})
            continue
        media, ee = media_ponderada(df, en_dominio)
        cv = ee / media
        filas.append({
            "nivel_educativo": cat,
            "n_muestral": len(sub),
            "poblacion_expandida": round(sub["fac500a"].sum()),
            "ingreso_promedio": round(media, 1),
            "error_estandar": round(ee, 1),
            "ic95_inf": round(media - 1.96 * ee, 1),
            "ic95_sup": round(media + 1.96 * ee, 1),
            "cv_pct": round(100 * cv, 1),
            "mediana": round(mediana_ponderada(sub["ingreso_mensual"], sub["fac500a"]), 1),
            "confiable": "sí" if cv <= CV_MAXIMO and len(sub) >= N_MINIMO else "referencial",
        })
    return pd.DataFrame(filas)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--anio", type=int, default=2024, choices=sorted(CODIGO_INEI))
    parser.add_argument("--departamento", default="06", help="Código ubigeo de 2 dígitos (06 = Cajamarca)")
    parser.add_argument("--datos", type=Path, default=Path(__file__).parent / "datos")
    parser.add_argument("--salida", type=Path, default=Path(__file__).parent / "resultados")
    args = parser.parse_args()

    df = cargar_datos(descargar_modulo(args.anio, args.datos))
    df["nivel"] = df["p301a"].map(NIVELES)
    df["grupo"] = df["p301a"].map(GRUPOS)

    ocupado_dpto = (df["ubigeo"].str[:2] == args.departamento) & (df["ocu500"] == 1)
    # Definición principal: ocupados con ingreso laboral positivo. Excluye a los
    # trabajadores familiares no remunerados, que por definición reportan ingreso cero.
    con_ingreso = ocupado_dpto & (df["ingreso_mensual"] > 0)

    args.salida.mkdir(parents=True, exist_ok=True)
    pd.set_option("display.width", 200)
    pd.set_option("display.max_columns", 20)
    resultados = {
        "grupos": tabla(df, con_ingreso, ORDEN_GRUPOS, "grupo"),
        "detalle": tabla(df, con_ingreso, list(NIVELES.values()), "nivel"),
        "grupos_todos_ocupados": tabla(df, ocupado_dpto, ORDEN_GRUPOS, "grupo"),
    }
    for nombre, res in resultados.items():
        archivo = args.salida / f"ingreso_educacion_{args.departamento}_{args.anio}_{nombre}.csv"
        res.to_csv(archivo, index=False, encoding="utf-8")
        print(f"\n== {nombre} (S/ corrientes por mes) -> {archivo}")
        print(res.to_string(index=False))


if __name__ == "__main__":
    main()
