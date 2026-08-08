#!/usr/bin/env python3
"""
Construccion del marco de distritos tratados y de control.

Implementa la regla de asignacion descrita en datos.tex: umbral absoluto
pre-registrado sobre la dotacion aurifera predeterminada, estratificado por
regimen geologico, con comparacion local via efectos fijos de provincia y
bandas de distancia.

El script es deterministico: dados los mismos insumos produce exactamente la
misma particion. No descarga nada y no imputa nada. Si falta un insumo, aborta
nombrando el archivo, en lugar de continuar con datos parciales.

Uso:
    python3 build_treatment_frame.py --input-dir ../data/raw --output-dir ../data/out

Ver README.md para la lista de insumos requeridos y su origen.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass, field
from pathlib import Path

# =====================================================================
# BLOQUE DE CONSTANTES
# Todos los umbrales del diseno viven aqui. Deben fijarse ANTES de mirar
# cualquier variable de resultado. Cambiarlos despues de ver resultados
# invalida la interpretacion de las pruebas de hipotesis.
# =====================================================================

DEPARTAMENTOS = [
    "AREQUIPA",
    "AYACUCHO",
    "CAJAMARCA",
    "ICA",
    "LA LIBERTAD",
    "MADRE DE DIOS",
    "PUNO",
]

# Vintage del padron de ubigeos al que se armoniza toda la geografia.
# Los distritos creados despues de esta fecha se reagregan a su distrito madre.
UBIGEO_VINTAGE = 2004

# Periodo base para la medida de validacion de produccion (previo a la muestra).
PRODUCCION_BASE_DESDE = 1999
PRODUCCION_BASE_HASTA = 2003

# Umbrales absolutos de dotacion, por regimen geologico.
# Unidades: ocurrencias auriferas por 100 km2 para roca dura y filoniano;
# proporcion de superficie distrital con aptitud aluvial para el aluvial.
UMBRAL_DOTACION = {
    "roca_dura": 0.50,
    "filoniano": 0.50,
    "aluvial": 0.05,
}

# Regla alternativa de outlier dentro de la provincia (solo robustez).
# No se aplica en provincias con menos distritos que este minimo, porque el
# rango intercuartilico deja de ser informativo. Ver seccion 5 de datos.tex.
MIN_DISTRITOS_PARA_IQR = 8
FACTOR_IQR = 1.5

# Bandas de distancia al distrito tratado mas cercano, en kilometros.
# Alimentan la ecuacion de derrames espaciales de metodologia.tex.
BANDAS_DISTANCIA_KM = [0, 25, 50, 75, 100, 150]

# Sistemas de referencia proyectados. Toda medicion de area o distancia debe
# hacerse sobre coordenadas metricas: calcularlas sobre EPSG:4326 devuelve
# grados cuadrados, no kilometros cuadrados.
# Para area se usa una proyeccion equivalente (Albers Sudamerica); para
# distancia, UTM 18S, que cubre la mayor parte del area de estudio. Los
# departamentos del extremo sur y norte caen parcialmente en 19S y 17S, lo que
# introduce una distorsion de distancia menor pero no nula.
CRS_AREA = (
    "+proj=aea +lat_1=-5 +lat_2=-42 +lat_0=-32 +lon_0=-60 "
    "+x_0=0 +y_0=0 +ellps=aust_SA +units=m +no_defs"
)
CRS_DISTANCIA = "EPSG:32718"

# Exclusiones.
# Un distrito con produccion relevante de otro metal se excluye del grupo de
# control porque su informalidad responde al precio de ese metal.
UMBRAL_OTRO_METAL_TM = 1000.0
EXCLUIR_DISTRITOS_COCALEROS = True
EXCLUIR_LIMITES_NO_ARMONIZABLES = True

# Covariables predeterminadas para la tabla de balance.
COVARIABLES_BALANCE = [
    "altitud_media_msnm",
    "rugosidad_terreno",
    "superficie_km2",
    "poblacion_base",
    "tasa_rural_base",
    "tasa_pobreza_base",
    "dist_capital_prov_km",
]

# =====================================================================
# INSUMOS REQUERIDOS
# =====================================================================


@dataclass(frozen=True)
class Insumo:
    nombre: str
    archivo: str
    fuente: str
    columnas: tuple[str, ...]
    nota: str = ""


INSUMOS: tuple[Insumo, ...] = (
    Insumo(
        nombre="padron_ubigeo",
        archivo="ubigeo_distritos.csv",
        fuente="INEI, padron nacional de ubigeos",
        columnas=("ubigeo", "departamento", "provincia", "distrito", "superficie_km2"),
        nota=f"Debe corresponder a la vintage {UBIGEO_VINTAGE}",
    ),
    Insumo(
        nombre="equivalencias_ubigeo",
        archivo="ubigeo_equivalencias.csv",
        fuente="Construccion propia a partir de leyes de creacion de distritos",
        columnas=("ubigeo_nuevo", "ubigeo_madre", "anio_creacion"),
        nota="Permite reagregar distritos creados despues de la vintage base",
    ),
    Insumo(
        nombre="ocurrencias_au",
        archivo="ingemmet_ocurrencias_au.geojson",
        fuente="INGEMMET / GEOCATMIN, servicio SERV_METALOGENETICO",
        columnas=("geometry", "elemento_principal", "tipo_deposito"),
        nota="Filtrar a ocurrencias con Au como elemento principal o secundario",
    ),
    Insumo(
        nombre="franjas_metalogeneticas",
        archivo="ingemmet_franjas.geojson",
        fuente="INGEMMET / GEOCATMIN",
        columnas=("geometry", "franja_id", "elementos"),
    ),
    Insumo(
        nombre="aptitud_aluvial",
        archivo="aptitud_aluvial.geojson",
        fuente="Construccion propia: llanura aluvial y terrazas sobre red hidrografica",
        columnas=("geometry",),
        nota="Necesario porque el conteo de ocurrencias subrepresenta el oro aluvial",
    ),
    Insumo(
        nombre="limites_distritales",
        archivo="limites_distritales.geojson",
        fuente="INEI, cartografia distrital",
        columnas=("geometry", "ubigeo"),
    ),
    Insumo(
        nombre="produccion_minera",
        archivo="minem_produccion_distrital.csv",
        fuente="MINEM, ESTAMIN y anuarios mineros",
        columnas=("ubigeo", "anio", "metal", "produccion_tm"),
        nota="Se usa solo el periodo base como validacion, nunca contemporanea",
    ),
    Insumo(
        nombre="covariables",
        archivo="covariables_distritales.csv",
        fuente="INEI, censos y cartografia; modelos de elevacion",
        columnas=("ubigeo",) + tuple(COVARIABLES_BALANCE),
    ),
    Insumo(
        nombre="distritos_cocaleros",
        archivo="distritos_cocaleros.csv",
        fuente="DEVIDA / UNODC, monitoreo de cultivos de coca",
        columnas=("ubigeo",),
        nota="Solo se usa si EXCLUIR_DISTRITOS_COCALEROS es True",
    ),
)


# =====================================================================
# VERIFICACION DE ENTORNO E INSUMOS
# =====================================================================


class InsumoFaltante(RuntimeError):
    """Se lanza cuando falta un archivo de entrada. Nunca se captura."""


def verificar_dependencias() -> None:
    """Aborta si faltan librerias, nombrando cual y como instalarla."""
    faltantes = []
    for modulo, paquete in (("pandas", "pandas"), ("geopandas", "geopandas")):
        try:
            __import__(modulo)
        except ImportError:
            faltantes.append((modulo, paquete))
    if faltantes:
        nombres = ", ".join(m for m, _ in faltantes)
        paquetes = " ".join(p for _, p in faltantes)
        raise InsumoFaltante(
            f"Faltan dependencias: {nombres}.\n"
            f"Instalar con:  pip install {paquetes}"
        )


def verificar_insumos(input_dir: Path) -> None:
    """Comprueba que todos los insumos existan ANTES de procesar nada."""
    if not input_dir.is_dir():
        raise InsumoFaltante(
            f"El directorio de insumos no existe: {input_dir}\n"
            f"Crearlo y colocar alli los archivos listados en README.md"
        )

    faltantes = []
    for ins in INSUMOS:
        if ins.nombre == "distritos_cocaleros" and not EXCLUIR_DISTRITOS_COCALEROS:
            continue
        ruta = input_dir / ins.archivo
        if not ruta.exists():
            faltantes.append(ins)

    if faltantes:
        lineas = [f"Faltan {len(faltantes)} insumo(s) en {input_dir}:", ""]
        for ins in faltantes:
            lineas.append(f"  {ins.archivo}")
            lineas.append(f"      fuente:   {ins.fuente}")
            lineas.append(f"      columnas: {', '.join(ins.columnas)}")
            if ins.nota:
                lineas.append(f"      nota:     {ins.nota}")
            lineas.append("")
        lineas.append("Ver README.md para el detalle de cada fuente.")
        raise InsumoFaltante("\n".join(lineas))


# =====================================================================
# ETAPAS DEL PIPELINE
# =====================================================================


@dataclass
class Registro:
    """Lleva el conteo de filas por etapa para que el usuario audite perdidas."""

    etapas: list[tuple[str, int]] = field(default_factory=list)

    def anotar(self, etapa: str, n: int) -> None:
        self.etapas.append((etapa, n))
        anterior = self.etapas[-2][1] if len(self.etapas) > 1 else None
        delta = "" if anterior is None else f"  ({n - anterior:+d})"
        print(f"  [{len(self.etapas)}] {etapa:44s} n={n:6d}{delta}")

    def resumen(self) -> str:
        return "\n".join(f"{e}\t{n}" for e, n in self.etapas)


def cargar_marco(input_dir: Path, reg: Registro):
    """Etapa 1: padron de ubigeos restringido a los departamentos del estudio."""
    import pandas as pd

    marco = pd.read_csv(input_dir / "ubigeo_distritos.csv", dtype={"ubigeo": str})
    reg.anotar("padron nacional cargado", len(marco))

    marco["departamento"] = marco["departamento"].str.upper().str.strip()
    marco = marco[marco["departamento"].isin(DEPARTAMENTOS)].copy()
    reg.anotar("restringido a departamentos auriferos", len(marco))
    return marco


def armonizar_geografia(marco, input_dir: Path, reg: Registro):
    """Etapa 2: reagrega distritos creados despues de la vintage base.

    Sin esto el panel no es balanceado: un distrito escindido en 2012 aparece
    como unidad nueva y su distrito madre cambia de superficie y poblacion,
    generando saltos que no son economicos.
    """
    import pandas as pd

    equiv = pd.read_csv(
        input_dir / "ubigeo_equivalencias.csv",
        dtype={"ubigeo_nuevo": str, "ubigeo_madre": str},
    )
    equiv = equiv[equiv["anio_creacion"] > UBIGEO_VINTAGE]

    mapa = dict(zip(equiv["ubigeo_nuevo"], equiv["ubigeo_madre"]))
    marco["ubigeo_armonizado"] = marco["ubigeo"].map(mapa).fillna(marco["ubigeo"])

    n_reagregados = (marco["ubigeo_armonizado"] != marco["ubigeo"]).sum()
    marco = (
        marco.groupby("ubigeo_armonizado", as_index=False)
        .agg(
            departamento=("departamento", "first"),
            provincia=("provincia", "first"),
            distrito=("distrito", "first"),
            superficie_km2=("superficie_km2", "sum"),
        )
        .rename(columns={"ubigeo_armonizado": "ubigeo"})
    )
    reg.anotar(f"armonizado ({n_reagregados} reagregados)", len(marco))
    return marco


def calcular_dotacion(marco, input_dir: Path, reg: Registro):
    """Etapa 3: construye g_d por union espacial y asigna regimen geologico.

    g_d se mide en unidades distintas segun el regimen, y por eso el umbral
    tambien es distinto. Un conteo de ocurrencias ordena bien la roca dura y el
    filoniano, pero subrepresenta gravemente el oro aluvial amazonico, donde el
    deposito no es puntual sino extendido sobre terrazas.
    """
    import geopandas as gpd
    import pandas as pd

    limites = gpd.read_file(input_dir / "limites_distritales.geojson")
    limites["ubigeo"] = limites["ubigeo"].astype(str)
    limites = limites[limites["ubigeo"].isin(set(marco["ubigeo"]))]

    ocurrencias = gpd.read_file(input_dir / "ingemmet_ocurrencias_au.geojson")
    ocurrencias = ocurrencias.to_crs(limites.crs)
    # No entra al registro de etapas: el conteo es de ocurrencias, no de
    # distritos, y mezclarlo haria ilegibles los deltas de la cadena.
    print(f"      ocurrencias auriferas cargadas: {len(ocurrencias)}")

    union = gpd.sjoin(ocurrencias, limites[["ubigeo", "geometry"]], how="inner")
    conteo = union.groupby("ubigeo").size().rename("n_ocurrencias")

    # El area se calcula sobre una proyeccion equivalente, nunca sobre lat/lon.
    limites_area = limites[["ubigeo", "geometry"]].to_crs(CRS_AREA)
    aluvial = gpd.read_file(input_dir / "aptitud_aluvial.geojson").to_crs(CRS_AREA)
    interseccion = gpd.overlay(
        limites_area, aluvial[["geometry"]], how="intersection"
    )
    interseccion["area_aluvial_km2"] = interseccion.geometry.area / 1e6
    area_aluvial = interseccion.groupby("ubigeo")["area_aluvial_km2"].sum()

    marco = marco.merge(conteo, on="ubigeo", how="left")
    marco = marco.merge(area_aluvial, on="ubigeo", how="left")
    marco[["n_ocurrencias", "area_aluvial_km2"]] = marco[
        ["n_ocurrencias", "area_aluvial_km2"]
    ].fillna(0.0)

    marco["ocurrencias_por_100km2"] = (
        100.0 * marco["n_ocurrencias"] / marco["superficie_km2"]
    )
    # El numerador se calcula de la cartografia y el denominador viene del
    # padron, de modo que pequenas inconsistencias pueden dar valores > 1.
    marco["prop_aluvial"] = (
        marco["area_aluvial_km2"] / marco["superficie_km2"]
    ).clip(upper=1.0)

    marco["regimen"] = marco.apply(_clasificar_regimen, axis=1)
    marco["g_d"] = marco.apply(
        lambda r: r["prop_aluvial"]
        if r["regimen"] == "aluvial"
        else r["ocurrencias_por_100km2"],
        axis=1,
    )

    reg.anotar("dotacion g_d calculada", len(marco))
    print(f"      regimenes: {marco['regimen'].value_counts().to_dict()}")
    return marco


def _clasificar_regimen(fila) -> str:
    """Asigna regimen geologico. Madre de Dios y las cuencas amazonicas de Puno
    son aluviales; el resto se separa por departamento segun el tipo de deposito
    dominante. Esta clasificacion debe validarse contra las franjas de INGEMMET.
    """
    if fila["departamento"] == "MADRE DE DIOS":
        return "aluvial"
    if fila["prop_aluvial"] > UMBRAL_DOTACION["aluvial"]:
        return "aluvial"
    if fila["departamento"] in ("CAJAMARCA", "LA LIBERTAD"):
        return "roca_dura"
    return "filoniano"


def asignar_tratamiento(marco, reg: Registro):
    """Etapa 4: regla principal por umbral absoluto, estratificada por regimen.

    Se calcula tambien la regla de outlier dentro de la provincia, pero solo
    para robustez y solo donde la provincia tiene suficientes distritos.
    """
    marco["umbral"] = marco["regimen"].map(UMBRAL_DOTACION)
    marco["Au_d"] = (marco["g_d"] >= marco["umbral"]).astype(int)
    reg.anotar(f"tratados por umbral absoluto", int(marco["Au_d"].sum()))

    marco["Au_d_iqr"] = 0
    marco["iqr_aplicable"] = 0
    for (_, _), grupo in marco.groupby(["departamento", "provincia"]):
        if len(grupo) < MIN_DISTRITOS_PARA_IQR:
            continue
        q75 = grupo["g_d"].quantile(0.75)
        iqr = q75 - grupo["g_d"].quantile(0.25)
        if iqr <= 0:
            continue  # regla degenerada: ver seccion 5 de datos.tex
        corte = q75 + FACTOR_IQR * iqr
        marco.loc[grupo.index, "iqr_aplicable"] = 1
        marco.loc[grupo.index, "Au_d_iqr"] = (grupo["g_d"] > corte).astype(int)

    n_aplicable = int(marco["iqr_aplicable"].sum())
    print(
        f"      regla IQR aplicable en {n_aplicable} de {len(marco)} distritos "
        f"({100.0 * n_aplicable / max(len(marco), 1):.1f}%)"
    )
    return marco


def calcular_bandas_distancia(marco, input_dir: Path, reg: Registro):
    """Etapa 5: distancia al distrito tratado mas cercano, en bandas.

    Alimenta la ecuacion de derrames. El signo del perfil estimado distingue
    demanda derivada (positivo) de reasignacion de trabajadores (negativo).
    """
    import geopandas as gpd
    import numpy as np

    limites = gpd.read_file(input_dir / "limites_distritales.geojson")
    limites["ubigeo"] = limites["ubigeo"].astype(str)
    limites = limites.merge(marco[["ubigeo", "Au_d"]], on="ubigeo", how="inner")

    proyectado = limites.to_crs(CRS_DISTANCIA)
    centroides = proyectado.geometry.centroid
    tratados = centroides[proyectado["Au_d"] == 1]

    if tratados.empty:
        raise InsumoFaltante(
            "Ningun distrito supero el umbral de dotacion. Revisar UMBRAL_DOTACION "
            "y la unidad de medida de g_d antes de continuar."
        )

    distancias = []
    for punto in centroides:
        distancias.append(tratados.distance(punto).min() / 1000.0)

    proyectado["dist_tratado_km"] = distancias
    # banda 0 = distrito tratado; banda k = [BANDAS[k-1], BANDAS[k]) km del
    # tratado mas cercano; la ultima banda es abierta por la derecha.
    proyectado["banda"] = np.digitize(
        proyectado["dist_tratado_km"], BANDAS_DISTANCIA_KM
    )
    proyectado.loc[proyectado["Au_d"] == 1, "banda"] = 0
    proyectado["banda_etiqueta"] = proyectado["banda"].map(_etiquetar_banda)

    marco = marco.merge(
        proyectado[["ubigeo", "dist_tratado_km", "banda", "banda_etiqueta"]],
        on="ubigeo",
        how="left",
    )
    reg.anotar("bandas de distancia asignadas", len(marco))
    return marco


def _etiquetar_banda(k: int) -> str:
    if k == 0:
        return "tratado"
    if k >= len(BANDAS_DISTANCIA_KM):
        return f">={BANDAS_DISTANCIA_KM[-1]}km"
    return f"{BANDAS_DISTANCIA_KM[k - 1]}-{BANDAS_DISTANCIA_KM[k]}km"


def aplicar_exclusiones(marco, input_dir: Path, reg: Registro):
    """Etapa 6: retira del grupo de control los distritos contaminados."""
    import pandas as pd

    marco["excluido"] = 0
    marco["motivo_exclusion"] = ""

    produccion = pd.read_csv(
        input_dir / "minem_produccion_distrital.csv", dtype={"ubigeo": str}
    )
    base = produccion[
        (produccion["anio"].between(PRODUCCION_BASE_DESDE, PRODUCCION_BASE_HASTA))
        & (produccion["metal"].str.upper() != "ORO")
    ]
    otros_metales = (
        base.groupby("ubigeo")["produccion_tm"].mean().rename("prod_otro_metal")
    )
    marco = marco.merge(otros_metales, on="ubigeo", how="left")
    marco["prod_otro_metal"] = marco["prod_otro_metal"].fillna(0.0)

    mascara = (marco["prod_otro_metal"] > UMBRAL_OTRO_METAL_TM) & (marco["Au_d"] == 0)
    marco.loc[mascara, ["excluido", "motivo_exclusion"]] = [1, "otro_metal"]
    reg.anotar("tras excluir controles con otro metal", int((marco["excluido"] == 0).sum()))

    if EXCLUIR_DISTRITOS_COCALEROS:
        coca = pd.read_csv(input_dir / "distritos_cocaleros.csv", dtype={"ubigeo": str})
        mascara = marco["ubigeo"].isin(set(coca["ubigeo"])) & (marco["excluido"] == 0)
        marco.loc[mascara, ["excluido", "motivo_exclusion"]] = [1, "coca"]
        reg.anotar("tras excluir distritos cocaleros", int((marco["excluido"] == 0).sum()))

    return marco


def tabla_balance(marco, input_dir: Path):
    """Etapa 7: balance de covariables predeterminadas, tratados vs control."""
    import pandas as pd

    cov = pd.read_csv(input_dir / "covariables_distritales.csv", dtype={"ubigeo": str})
    # Se descartan del marco las columnas que tambien trae el archivo de
    # covariables: de lo contrario el merge las renombra con sufijos y la
    # variable desaparece de la tabla sin aviso.
    duplicadas = [c for c in cov.columns if c != "ubigeo" and c in marco.columns]
    if duplicadas:
        print(f"      columnas tomadas del archivo de covariables: {duplicadas}")
    datos = marco[marco["excluido"] == 0].drop(columns=duplicadas).merge(
        cov, on="ubigeo", how="left"
    )

    omitidas = []
    filas = []
    for var in COVARIABLES_BALANCE:
        if var not in datos.columns:
            omitidas.append(var)
            continue
        t = datos.loc[datos["Au_d"] == 1, var].dropna()
        c = datos.loc[datos["Au_d"] == 0, var].dropna()
        if t.empty or c.empty:
            omitidas.append(var)
            continue
        pooled = ((t.std() ** 2 + c.std() ** 2) / 2) ** 0.5
        filas.append(
            {
                "variable": var,
                "media_tratados": t.mean(),
                "media_control": c.mean(),
                "diferencia": t.mean() - c.mean(),
                "dif_estandarizada": (t.mean() - c.mean()) / pooled if pooled else float("nan"),
                "n_tratados": len(t),
                "n_control": len(c),
            }
        )
    if omitidas:
        print(
            f"      AVISO: sin datos para {len(omitidas)} covariable(s) "
            f"de balance: {', '.join(omitidas)}"
        )
    return pd.DataFrame(filas)


# =====================================================================
# ORQUESTACION
# =====================================================================


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, default=Path("../data/raw"))
    parser.add_argument("--output-dir", type=Path, default=Path("../data/out"))
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Solo verifica dependencias e insumos, sin procesar",
    )
    args = parser.parse_args(argv)

    print("Verificando entorno e insumos...")
    verificar_dependencias()
    verificar_insumos(args.input_dir)
    print("  todos los insumos presentes\n")

    if args.check_only:
        return 0

    reg = Registro()
    print("Construyendo marco:")
    marco = cargar_marco(args.input_dir, reg)
    marco = armonizar_geografia(marco, args.input_dir, reg)
    marco = calcular_dotacion(marco, args.input_dir, reg)
    marco = asignar_tratamiento(marco, reg)
    marco = calcular_bandas_distancia(marco, args.input_dir, reg)
    marco = aplicar_exclusiones(marco, args.input_dir, reg)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    activos = marco[marco["excluido"] == 0]
    activos[activos["Au_d"] == 1].to_csv(args.output_dir / "treated.csv", index=False)
    activos[activos["Au_d"] == 0].to_csv(args.output_dir / "control.csv", index=False)
    marco.to_csv(args.output_dir / "frame_completo.csv", index=False)
    tabla_balance(marco, args.input_dir).to_csv(
        args.output_dir / "balance.csv", index=False
    )
    (args.output_dir / "conteos_por_etapa.tsv").write_text(reg.resumen() + "\n")

    n_t = int((activos["Au_d"] == 1).sum())
    n_c = int((activos["Au_d"] == 0).sum())
    print(f"\nMarco final: {n_t} tratados, {n_c} controles")
    print(f"Resultados en {args.output_dir}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except InsumoFaltante as exc:
        print(f"\nERROR: {exc}\n", file=sys.stderr)
        sys.exit(2)
