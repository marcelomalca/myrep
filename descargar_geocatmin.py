"""
Descarga capas del Geocatmin (INGEMMET) como data frame / GeoDataFrame.

Requisitos:
    pip install requests pandas geopandas

Uso:
    # 1) Ver las capas del servicio metalogenético
    python descargar_geocatmin.py --listar

    # 2) Ver los campos de una capa
    python descargar_geocatmin.py --campos 1

    # 3) Descargar todos los yacimientos mineros (capa 1, CSV + GeoPackage)
    python descargar_geocatmin.py --capa 1 --salida yacimientos

    # 4) Igual que 3, y además guardar los yacimientos de oro
    python descargar_geocatmin.py --capa 1 --salida yacimientos --oro

    # 5) Filtrar en el servidor con SQL (el campo de elementos principales es ELE_PRINC)
    python descargar_geocatmin.py --capa 1 --where "ELE_PRINC LIKE '%Au%'" --salida yacimientos_oro

Capas útiles de SERV_METALOGENETICO (verificado en oct-2026):
    0  Proyectos y Operaciones
    1  Yacimientos Mineros      <- campo ELE_PRINC = elementos principales ("Au", "Cu,Au", ...)
    4  Franja Metalogenética
"""

import argparse
import os
import sys
import tempfile

import geopandas as gpd
import pandas as pd
import requests

HOST = "https://geocatmin.ingemmet.gob.pe/arcgis/rest/services"
# Si el host anterior no responde, prueba con:
# HOST = "https://geocatminapp.ingemmet.gob.pe/arcgis/rest/services"

TIMEOUT = 120

# El servidor de Geocatmin no envía su certificado intermedio, así que
# requests falla con "unable to get local issuer certificate". Se agrega el
# intermedio de Sectigo (válido hasta 2036) al bundle de CAs en lugar de
# desactivar la verificación SSL.
# Fuente: http://crt.sectigo.com/SectigoPublicServerAuthenticationCAOVR36.crt
SECTIGO_OV_R36 = """-----BEGIN CERTIFICATE-----
MIIGTDCCBDSgAwIBAgIQLBo8dulD3d3/GRsxiQrtcTANBgkqhkiG9w0BAQwFADBf
MQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTYwNAYDVQQD
Ey1TZWN0aWdvIFB1YmxpYyBTZXJ2ZXIgQXV0aGVudGljYXRpb24gUm9vdCBSNDYw
HhcNMjEwMzIyMDAwMDAwWhcNMzYwMzIxMjM1OTU5WjBgMQswCQYDVQQGEwJHQjEY
MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTcwNQYDVQQDEy5TZWN0aWdvIFB1Ymxp
YyBTZXJ2ZXIgQXV0aGVudGljYXRpb24gQ0EgT1YgUjM2MIIBojANBgkqhkiG9w0B
AQEFAAOCAY8AMIIBigKCAYEApkMtJ3R06jo0fceI0M52B7K+TyMeGcv2BQ5AVc3j
lYt76TvHIu/nNe22W/RJXX9rWUD/2GE6GF5x0V4bsY7K3IeJ8E7+KzG/TGboySfD
u+F52jqQBbY62ofhYjMeiAbLI02+FqwHeM8uIrUtcX8b2RCxF358TB0NHVccAXZc
FYgZndZCeXxjuca7pJJ20LLUnXtgXcjAE1vY4WvbReW0W6mkeZyNGdmpTcFs5Y+s
yy6LtE5Zocji9J9NlNnReox2RWVyEXpA1ChZ4gqN+ZpVSIQ0HBorVFbBKyhdZyEX
gZgNSNtBRwxqwIzJePJhYd4ZUhO1vk+/uP3nwDk0p95q/j7naXNCSvESnrHPypaB
WRK066nKfPRPi9m9kIOhMdYfS8giFRTcdgL24Ycilj7ecAK9Trh0VbjwouJ4WH+x
bt47u68ZFCD/ac55I0DNHkCpaPruj6e9Rmr7K46wZDAYXuEAqB7tGG/jd6JAA+H2
O44CV98NRsU213f1kScIZntNAgMBAAGjggGBMIIBfTAfBgNVHSMEGDAWgBRWc1hk
lfmSGrASKgRieaFAFYghSTAdBgNVHQ4EFgQU42Z0u3BojSxdTg6mSo+bNyKcgpIw
DgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0lBBYwFAYI
KwYBBQUHAwEGCCsGAQUFBwMCMBsGA1UdIAQUMBIwBgYEVR0gADAIBgZngQwBAgIw
VAYDVR0fBE0wSzBJoEegRYZDaHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdv
UHVibGljU2VydmVyQXV0aGVudGljYXRpb25Sb290UjQ2LmNybDCBhAYIKwYBBQUH
AQEEeDB2ME8GCCsGAQUFBzAChkNodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3Rp
Z29QdWJsaWNTZXJ2ZXJBdXRoZW50aWNhdGlvblJvb3RSNDYucDdjMCMGCCsGAQUF
BzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEA
BZXWDHWC3cubb/e1I1kzi8lPFiK/ZUoH09ufmVOrc5ObYH/XKkWUexSPqRkwKFKr
7r8OuG+p7VNB8rifX6uopqKAgsvZtZsq7iAFw04To6vNcxeBt1Eush3cQ4b8nbQR
MQLChgEAqwhuXp9P48T4QEBSksYav7+aFjNySsLYlPzNqVM3RNwvBdvp6vgDtGwc
xlKQZVuuNVIaoYyls8swhxDeSHKpRdxRauTLZ+pl+wGvy0pnrLEJGSz9mOEmfbod
e/XopR2NGqaHJ6bIjyxPu6UtyQGI26En7UAEozACrHz06Nx2jTAY9E6NeB6XuobE
wLK025ZRmvglcURG1BrV24tGHHTgxCe8M3oGlpUSMTKQ2dkgljZVYt+gKdFtWELZ
MuRdi+X3XsrR8LFz+aLUiDRfQqhmw3RxjIyVKvvu9UPYY1nsvxYmFnUSeM+2q1z/
iPUry+xDY9MC6+IhleKT094VKdFVp7LXH42+wvU+17lRolQ2mK2N/nBLVBwaIhib
QXw4VYKwB86Bc6eS6iqsc94KEgD/U4VsjmgfhK+Xp4NM+VYzTTa3QeV3p8xOM0cw
q1p8oZFA+OBcz3FYWpDIe5j0NWKlw9hXsTyPY/HeZUV59akskSOSRSmDfe8wJDPX
58uB9/7lud0G3x0pxQAcffP0ayKavNwDTw4UfJ34cEw=
-----END CERTIFICATE-----
"""


def crear_bundle_ca():
    """Bundle de CAs del sistema/certifi + el intermedio de Sectigo."""
    base = os.environ.get("REQUESTS_CA_BUNDLE") or os.environ.get("SSL_CERT_FILE")
    if not base:
        base = requests.certs.where()
    with open(base, encoding="utf-8") as f:
        contenido = f.read()
    tmp = tempfile.NamedTemporaryFile("w", suffix=".pem", delete=False, encoding="utf-8")
    tmp.write(contenido + "\n" + SECTIGO_OV_R36)
    tmp.close()
    return tmp.name


CA_BUNDLE = crear_bundle_ca()


def get_json(url, **params):
    params.setdefault("f", "json")
    r = requests.get(url, params=params, timeout=TIMEOUT, verify=CA_BUNDLE)
    r.raise_for_status()
    data = r.json()
    if "error" in data:
        raise RuntimeError(f"Error del servidor: {data['error']}")
    return data


def listar_capas(base):
    data = get_json(base)
    print(f"\nCapas en {base}:\n")
    for capa in data.get("layers", []):
        print(f"  {capa['id']:>3}  {capa['name']}  ({capa.get('type', '')})")
    for tabla in data.get("tables", []):
        print(f"  {tabla['id']:>3}  {tabla['name']}  (tabla)")


def listar_campos(base, capa_id):
    data = get_json(f"{base}/{capa_id}")
    print(f"\nCapa {capa_id}: {data.get('name')}  -  geometría: {data.get('geometryType')}\n")
    for campo in data.get("fields", []):
        print(f"  {campo['name']:<30} {campo.get('alias', ''):<35} {campo.get('type', '')}")


def descargar(base, capa_id, where="1=1", lote=500):
    url = f"{base}/{capa_id}/query"

    # 1) Pedir solo los IDs (evita el límite de registros por consulta)
    ids = get_json(url, where=where, returnIdsOnly="true").get("objectIds") or []
    ids = sorted(ids)
    print(f"Registros encontrados: {len(ids)}")
    if not ids:
        return gpd.GeoDataFrame()

    # 2) Descargar por lotes de IDs
    features = []
    for i in range(0, len(ids), lote):
        bloque = ids[i:i + lote]
        data = get_json(
            url,
            f="geojson",
            objectIds=",".join(map(str, bloque)),
            outFields="*",
            returnGeometry="true",
            outSR=4326,
        )
        features.extend(data.get("features", []))
        print(f"  descargados {len(features)}/{len(ids)}")

    gdf = gpd.GeoDataFrame.from_features(features, crs="EPSG:4326")

    # Agrega lon/lat como columnas si son puntos (útil para el CSV)
    if not gdf.empty and gdf.geom_type.dropna().eq("Point").all():
        gdf["lon"] = gdf.geometry.x
        gdf["lat"] = gdf.geometry.y
    return gdf


def elementos(valor):
    """'Cu, Au' -> ['Cu', 'Au']"""
    if not isinstance(valor, str):
        return []
    return [e.strip() for e in valor.split(",") if e.strip()]


def filtrar_oro(gdf, campo="ELE_PRINC"):
    """Devuelve (Au entre los elementos principales, Au como primer elemento)."""
    lista = gdf[campo].map(elementos)
    con_au = gdf[lista.map(lambda els: "Au" in els)]
    au_primero = gdf[lista.map(lambda els: bool(els) and els[0] == "Au")]
    return con_au, au_primero


def guardar(gdf, salida):
    pd.DataFrame(gdf.drop(columns="geometry")).to_csv(
        f"{salida}.csv", index=False, encoding="utf-8-sig")
    gdf.to_file(f"{salida}.gpkg", driver="GPKG")
    print(f"Guardado: {salida}.csv y {salida}.gpkg ({len(gdf)} filas)")


def main():
    p = argparse.ArgumentParser(description="Descarga capas del Geocatmin")
    p.add_argument("--servicio", default="SERV_METALOGENETICO",
                   help="Nombre del servicio (por defecto SERV_METALOGENETICO)")
    p.add_argument("--listar", action="store_true", help="Lista las capas del servicio")
    p.add_argument("--campos", type=int, help="Muestra los campos de la capa indicada")
    p.add_argument("--capa", type=int, help="ID de la capa a descargar (1 = Yacimientos Mineros)")
    p.add_argument("--where", default="1=1", help="Filtro SQL, p. ej. \"ELE_PRINC LIKE '%%Au%%'\"")
    p.add_argument("--salida", default="geocatmin_capa", help="Nombre base de los archivos de salida")
    p.add_argument("--oro", action="store_true",
                   help="Además guarda <salida>_oro (Au en ELE_PRINC) y "
                        "<salida>_oro_principal (Au como primer elemento)")
    args = p.parse_args()

    base = f"{HOST}/{args.servicio}/MapServer"

    if args.listar:
        listar_capas(base)
    elif args.campos is not None:
        listar_campos(base, args.campos)
    elif args.capa is not None:
        gdf = descargar(base, args.capa, args.where)
        if gdf.empty:
            print("No se descargó nada. Revisa el ID de capa o el filtro.")
            sys.exit(1)
        print()
        guardar(gdf, args.salida)

        if args.oro:
            if "ELE_PRINC" not in gdf.columns:
                print("La capa no tiene el campo ELE_PRINC; no se puede filtrar por oro.")
                sys.exit(1)
            con_au, au_primero = filtrar_oro(gdf)
            guardar(con_au, f"{args.salida}_oro")
            guardar(au_primero, f"{args.salida}_oro_principal")
    else:
        p.print_help()


if __name__ == "__main__":
    main()
