# Marco de distritos tratados y de control

Código que acompaña a `datos.tex`. Produce la partición de distritos tratados y de control
para el estudio del efecto del precio del oro sobre la informalidad.

## Advertencia sobre los datos

**Este repositorio no contiene los datos.** Los insumos deben descargarse de las fuentes
oficiales peruanas y colocarse en `data/raw/`. El script no descarga nada: verifica que los
archivos existan, y aborta nombrando los que falten.

`provisional_districts.csv` **no es un resultado**. Es una lista de hipótesis armada a partir
de conocimiento del sector, pensada para orientar la validación y para detectar errores
gruesos en la salida del pipeline. Cada fila lleva su base de inclusión y un nivel de
confianza. Ninguna entrada sustituye a la verificación contra INGEMMET y MINEM.

## Insumos requeridos

Colocar en el directorio pasado con `--input-dir` (por defecto `../data/raw`):

| Archivo | Fuente | Columnas mínimas |
|---|---|---|
| `ubigeo_distritos.csv` | INEI, padrón nacional de ubigeos | `ubigeo, departamento, provincia, distrito, superficie_km2` |
| `ubigeo_equivalencias.csv` | Construcción propia (leyes de creación) | `ubigeo_nuevo, ubigeo_madre, anio_creacion` |
| `ingemmet_ocurrencias_au.geojson` | INGEMMET / GEOCATMIN, `SERV_METALOGENETICO` | `geometry, elemento_principal, tipo_deposito` |
| `ingemmet_franjas.geojson` | INGEMMET / GEOCATMIN | `geometry, franja_id, elementos` |
| `aptitud_aluvial.geojson` | Construcción propia sobre red hidrográfica | `geometry` |
| `limites_distritales.geojson` | INEI, cartografía distrital | `geometry, ubigeo` |
| `minem_produccion_distrital.csv` | MINEM, ESTAMIN y anuarios | `ubigeo, anio, metal, produccion_tm` |
| `covariables_distritales.csv` | INEI, censos; modelos de elevación | `ubigeo` + las siete covariables de balance |
| `distritos_cocaleros.csv` | DEVIDA / UNODC | `ubigeo` |

Al descargar, registrar para cada archivo: URL exacta, fecha de descarga y suma de
verificación. Sin eso el ejercicio no es reproducible.

## Uso

```bash
pip install pandas geopandas

# Verificar insumos sin procesar
python3 build_treatment_frame.py --input-dir ../data/raw --check-only

# Construir el marco
python3 build_treatment_frame.py --input-dir ../data/raw --output-dir ../data/out
```

## Salidas

| Archivo | Contenido |
|---|---|
| `treated.csv` | Distritos tratados no excluidos |
| `control.csv` | Distritos de control no excluidos |
| `frame_completo.csv` | Todos los distritos, con `g_d`, régimen, banda de distancia y motivo de exclusión |
| `balance.csv` | Balance de covariables predeterminadas, tratados vs control |
| `conteos_por_etapa.tsv` | Filas al final de cada etapa, para auditar dónde se pierden observaciones |

## Umbrales

Todos los parámetros del diseño están en el bloque de constantes al inicio de
`build_treatment_frame.py`. **Deben fijarse antes de mirar cualquier variable de resultado.**
Cambiarlos después de ver resultados invalida la interpretación de las pruebas de hipótesis.

La regla principal es un umbral absoluto sobre la dotación, estratificado por régimen
geológico. La regla de outlier dentro de la provincia (p75 + 1,5·IQR) se calcula solo como
robustez y solo donde la provincia tiene al menos `MIN_DISTRITOS_PARA_IQR` distritos; el
script reporta en qué fracción de la muestra resulta aplicable. Ver sección 5 de `datos.tex`
para por qué no puede ser la regla principal en el Perú.

## Notas de implementación

Áreas y distancias se calculan sobre coordenadas proyectadas, nunca sobre EPSG:4326. El área
usa una proyección equivalente de Albers para Sudamérica; la distancia usa UTM 18S, que cubre
la mayor parte del área de estudio y deja una distorsión menor en los extremos norte y sur.

El script fue probado end-to-end con insumos sintéticos que replican la estructura
administrativa esperada (600 distritos, 7 departamentos, 65 provincias). Esa prueba valida el
flujo, no los resultados.
