"""
Limita los yacimientos de oro a los registros cargados antes de 2014.

Parte de datos/yacimientos_oro_principal.csv (oro como primer elemento
principal, generado por descargar_geocatmin.py --oro) y conserva solo los
registros cuyo CREATIONDATE es anterior al 1 de enero de 2014. No cambia
columnas, valores ni orden de las filas.

Uso (desde la raíz del repositorio):
    python filtrar_pre2014.py
"""

import pandas as pd

ENTRADA = "datos/yacimientos_oro_principal.csv"
SALIDA = "datos/yacimientos_oro_principal_pre2014.csv"
CORTE = pd.Timestamp("2014-01-01", tz="UTC")

# Se lee todo como texto para reescribir los valores tal como están
df = pd.read_csv(ENTRADA, dtype=str, keep_default_na=False, encoding="utf-8-sig")

# CREATIONDATE viene de ArcGIS en milisegundos desde 1970 (UTC)
creacion = pd.to_datetime(pd.to_numeric(df["CREATIONDATE"]), unit="ms", utc=True)
pre = df[creacion < CORTE]

pre.to_csv(SALIDA, index=False, encoding="utf-8-sig")
print(f"{len(pre)} de {len(df)} registros creados antes de 2014 -> {SALIDA}")
