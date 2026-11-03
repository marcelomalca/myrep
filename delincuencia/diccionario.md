# Diccionario de datos: indicadores de delincuencia 2014–2025

Bases construidas con dos encuestas del INEI, 2014–2025:

- **ENAPRES** (Encuesta Nacional de Programas Presupuestales): capítulo de
  seguridad ciudadana y capítulo 100.
- **ENAHO**: módulo 85, Gobernabilidad, Democracia y Transparencia.

No se usan registros administrativos.

Las fuentes, la disponibilidad de variables por año y las decisiones de
construcción están en [`inventario.md`](inventario.md). Las decisiones D1–D16 se
aprobaron como se propusieron.

## Cómo reproducir

```
Rscript delincuencia/ejecutar_todo.R
```

| Script | Qué hace |
|---|---|
| `01_descarga.R` | Descarga los módulos de la ENAPRES y el módulo 85 de la ENAHO en `datos_brutos/` (omite los que ya existen) y escribe el registro con URL, fecha, bytes y MD5 |
| `02_extraer.R` | Extrae los zip en `cache/` sin modificar los originales |
| `03_enapres_personas.R` | Base de personas de la ENAPRES: victimización, denuncia, arma de fuego, percepción |
| `04_enapres_hogares.R` | Base de hogares de la ENAPRES: robo o intento de robo de vivienda |
| `05_enaho_hogares.R` | Base de hogares de la ENAHO: hogar afectado por hecho delictivo |
| `06_enaho_opinion.R` | Base de opinión de la ENAHO: delincuencia como problema, confianza en la PNP |
| `07_agregado_distrital.R` | Base distrito-año |
| `08_verificacion.R` | Comparación con cifras publicadas por el INEI |

**Detalles técnicos**

- `funciones.R` contiene las funciones comunes.
- Paquetes de R: `haven`, `dplyr`, `tidyr`, `readr`, `jsonlite` y `arrow`.
- El flujo completo tarda menos de 2 minutos con los archivos ya descargados.

## Bases producidas (`delincuencia/datos_procesados/`)

| Archivo | Unidad | Filas | Universo |
|---|---|---|---|
| `enapres_personas.{parquet,csv}` | Persona × año | 805 919 | Población urbana de 15 años y más con factor > 0 |
| `enapres_hogares.{parquet,csv}` | Hogar × año | 324 199 | Hogares urbanos con respuesta a la pregunta de robo de vivienda y factor > 0 |
| `enaho_hogares.{parquet,csv}` | Hogar × año | 409 659 | Todos los hogares del módulo 85 (urbano y rural) |
| `enaho_opinion.{parquet,csv}` | Persona × año | 368 134 | Una persona de 18 años y más por hogar, con respuesta y factor > 0 |
| `distrito_anio.{parquet,csv}` | `ubigeo_base` × año | 15 096 | Distritos con al menos una observación en alguna de las cuatro bases (1 585 distritos de 2014) |
| `verificacion_oficial.csv` | Indicador × versión × año | — | Comparación con cifras publicadas por el INEI |

Todos los archivos pesan menos de 100 MB. El más grande es
`enapres_personas.csv`, con 89 MB.

---

## Convenciones generales

**Indicadores**
- En las bases de personas y hogares valen 1, 0 o vacío. Vacío significa que la
  pregunta no se aplicó o no tiene respuesta; no se imputa nada.
- En la base distrito-año son proporciones de 0 a 1, no porcentajes, como en
  `enaho/datos_procesados/distrito_anio`.

**Geografía**
- `ubigeo` es el código de 6 dígitos de la encuesta. En la ENAPRES se arma con
  `CCDD`, `CCPP` y `CCDI`.
- `ubigeo_base` es el distrito de 2014 según la tabla de `enaho/` (ver
  `enaho/diccionario.md`).
- Todos los códigos de ambas encuestas están en esa tabla o en la capa distrital
  de 2014. Si apareciera un código nuevo, el script se detiene.

**Identificadores**
- Son texto.
- En la ENAPRES se dejan tal como vienen en el archivo. Su formato cambia entre
  años, así que sirven para identificar dentro de cada año.
- En la ENAHO se completan con ceros, como en `enaho/`.

**Factores de expansión**
- Son los de cada archivo; los detalles están en la sección de cada base.
- Las proporciones se ponderan con el factor de la base. El de percepción
  (2024–2025) y el de opinión son distintos al principal.

**Representatividad.** Ninguna de las dos encuestas está diseñada para estimar a
nivel distrital. La tasa distrito-año se basa en pocas observaciones; la
mediana es de unas 40 personas en la ENAPRES y unos 14 hogares en la ENAHO. Por
eso la base trae `n_` y `peso_` para cada indicador.

**ENAPRES solo urbana.** El capítulo de seguridad y la pregunta de robo de
vivienda solo se aplican en el área urbana. La ENAPRES cubre 92 de los 276
distritos con oro antes de 2014. El único indicador de victimización con
cobertura rural es el de la ENAHO, `hecho_delictivo`.

---

## 1. `enapres_personas`: personas de la ENAPRES

**Fuente.** El capítulo de seguridad ciudadana: 600 en 2014–2024
(`CAP_600_*.sav`), 400 en 2025 (`CAP_400_URBANO_4.sav`).

**Universo**
- Personas de 15 años y más (`P208_A`) del área urbana con factor > 0.
- No se filtra por `RESFIN` (D9).
- Se descartan 36 701 filas de menores de 15 años o sin factor.

**Llave:** `anio` + `mes` + `conglomerado` + `nselv` + `vivienda` + `hogar` +
`persona`. Se verifica que sea única.

| Variable | Definición |
|---|---|
| `anio`, `mes` | Año y mes de la entrevista |
| `conglomerado`, `nselv`, `vivienda`, `hogar`, `persona` | `CONGLOMERADO`, `NSELV`, `VIVIENDA`, `HOGAR`, `P201` (texto, sin rellenar) |
| `ubigeo`, `ubigeo_base` | Distrito de la encuesta y distrito de 2014 |
| `edad` | `P208_A` |
| `resfin` | Resultado final del hogar: 1 completa, 2 incompleta |
| `modalidad` | `MOD_ENC`, solo 2020–2022: 1 presencial, 2 telefónica |
| `factor` | Factor anual: `FACTORANUALCAP600` (2014–15), `FACTORANUAL` (2016–17), `FACTOR` (2018–25). En 2020–21 se usa `FACTOR` y no `FACTOR_CALIBRADO` (D15) |
| `victima_comun` | Víctima de al menos un tipo de delito de la lista presente los 12 años (D1) |
| `victima_completa` | Víctima de al menos un tipo de delito de la lista del año, sin vandalismo (D1) |
| `robo_dinero` | Robo **o** intento de robo de dinero, cartera, celular (D3) |
| `robo_vehiculo` | Robo consumado de vehículo automotor **o** de motocicleta/mototaxi (D4) |
| `amenazas` | Amenazas e intimidaciones |
| `extorsion` | Extorsión consumada (D5) |
| `extorsion_o_intento` | Extorsión o intento de extorsión; desde 2016, vacío en 2014–2015 (D5) |
| `estafa` | Estafa |
| `robo_negocio` | Robo de negocio |
| `ofensas_sexuales` | Ofensas sexuales (acoso, abuso, violación) |
| `arma_fuego` | Fue víctima de algún hecho en que se usó un arma de fuego de mano o larga, sobre toda la población (D8) |
| `denuncio` | Entre las víctimas (`victima_completa` = 1), denunció al menos uno de los hechos; vacío para quienes no son víctimas (D7) |
| `percepcion` | Cree que podría ser víctima de al menos un tipo de delito en los próximos 12 meses (D6) |
| `percepcion_general_2025` | Solo 2025: `P401` = 1 ("¿cree usted que podría ser víctima de algún hecho delictivo?") |
| `factor_percepcion` | Factor para `percepcion` y `percepcion_general_2025` |
| `submuestra_percepcion` | `TRUE` en 2024–2025, cuando la percepción se pregunta a una submuestra |

**Variables de origen de la victimización**

| | 2014–2023 | 2024 | 2025 |
|---|---|---|---|
| Víctima por tipo (1 Sí, 2 No, 3 No tiene) | `P601_k` | `P615_k` | `P424_k` |
| ¿Denunció? (1 Sí, 2 No) | `P606_k` | `P619_k` | `P428_k` |
| Arma de fuego de mano / larga (1 marcado) | `P605_k_1`, `P605_k_2` | `P632_k_1`, `P632_k_2` | `P451_k_1`, `P451_k_2` |

La correspondencia de `k` por tipo de delito y año está en
`inventario/tipos_delito_enapres.csv`. "No tiene" (3) cuenta como 0.

**Listas de delitos (D1)**

- **Lista común:** robo e intento de robo de vehículo, de autopartes, de
  moto/mototaxi, de bicicleta y de dinero/cartera/celular; robo de negocio;
  amenazas; maltrato; ofensas sexuales; secuestro e intento; extorsión; estafa; y
  "otro". En 2024–2025, "otro patrimonial" y "otro no patrimonial" reemplazan a
  "otro".
- **Lista completa:** la lista común, más el intento de extorsión (desde 2016) y
  los delitos informáticos (2023; desglosados desde 2024).
- **Vandalismo** (2024) no entra en ninguna, porque pregunta por "víctima o
  testigo".

**Percepción (D6)**

| Año | Definición | Factor | Ítems |
|---|---|---|---|
| 2014–2023 | "Sí" en al menos uno de `P611_1`…`P611_14` | factor principal | 1 Sí, 2 No, 4 No sabe |
| 2024 | "Sí" en al menos uno de `P601_1`…`P601_16`; submuestra de unas 24 mil personas | `FACTOR_CAP600B` | |
| 2025 | "Sí" en al menos uno de los ítems `P402_k`; submuestra de unas 24 mil personas | `FACTOR_CAP400` | se preguntan a todos los que responden `P401` |

`percepcion_general_2025` usa la pregunta general nueva y da 72,9 %, frente a
83,4 % de `percepcion`. No se mezcla con la serie.

## 2. `enapres_hogares`: hogares de la ENAPRES

**Fuente.** Capítulo 100.

**Universo**
- Hogares urbanos con respuesta y factor > 0.
- La pregunta no tiene respuestas en el área rural; el script lo comprueba.

**Llave (D10):** `anio` + `mes` + `conglomerado` + `nselv` + `vivienda` +
`hogar`, verificada como única.

- Sin el mes, la llave `conglomerado` + `nselv` + `vivienda` + `hogar` tiene entre
  0 y 22 repeticiones por año.
- Son entrevistas del mismo código de hogar en meses distintos, con respuestas
  distintas, así que se tratan como observaciones separadas.
- Lo mismo ocurre en pocas personas de la base anterior.

| Variable | Definición |
|---|---|
| `anio`, `mes`, `conglomerado`, `nselv`, `vivienda`, `hogar`, `ubigeo`, `ubigeo_base` | Como en la base de personas |
| `factor` | `FACTORANUAL` (2014–2017), `FACTOR` (2018–2025) |
| `robo_vivienda` | En los últimos 12 meses, el hogar sufrió robo **o** intento de robo en la vivienda: `P112_1`/`P112_2` (2014–2023) o `P116_1`/`P116_2` (2024–2025) |

## 3. `enaho_hogares`: hogares de la ENAHO

**Fuente.** `enaho01b-AAAA-2.dta` (módulo 85, sección de vulnerabilidad).

**Universo**
- Todos los hogares del archivo; ninguno tiene factor vacío.
- La pregunta la responde el jefe o jefa de hogar o su cónyuge.

**Llave:** `anio` + `conglome` + `vivienda` + `hogar`.

| Variable | Definición |
|---|---|
| `anio`, `mes`, `conglome`, `vivienda`, `hogar` | Identificadores (con ceros a la izquierda, como en `enaho/`) |
| `ubigeo`, `ubigeo_base` | Distrito |
| `area` | 1 urbana (`estrato` 1–5), 2 rural (6–8) |
| `factor07` | Factor de expansión del hogar |
| `hecho_delictivo` | `p40_5`: en los últimos 12 meses el hogar "se vio afectado por… hecho delictivo (robo, asalto, etc.)". 1 = sí, 0 = no (D12) |
| `cuestionario_reducido` | 1 = cuestionario telefónico reducido de 2020–2021 (`tipocuestionario` = 1), que no incluye la pregunta |

**`hecho_delictivo` vacío.** Pasa en dos casos:

- **Cuestionario reducido:** 17 077 hogares en 2020 (abril a agosto completos, y
  parte de marzo y septiembre) y 1 514 en 2021 (febrero).
- **Hogares sin respuesta a toda la pregunta 40:** entre 900 y 3 500 por año.

En 2020 quedan 16 475 hogares con dato, en 878 distritos.

**Qué mide.** Es un choque que afectó al **hogar**, en una lista de problemas
económicos del hogar; no la victimización de cada persona. Por eso su nivel (2–4 %)
es muy inferior al de la ENAPRES.

## 4. `enaho_opinion`: opinión de la ENAHO

**Fuente.** `enaho01b-AAAA-1.dta` (módulo 85, Gobernabilidad).

**Universo**
- Una persona de 18 años y más por hogar, la que cumplió años más recientemente.
- Se excluyen las filas sin respuesta y sin factor (41 525 en total).

**Llave:** `anio` + `conglome` + `vivienda` + `hogar`.

| Variable | Definición |
|---|---|
| `anio`, `mes`, `conglome`, `vivienda`, `hogar`, `codperso` | Identificadores |
| `ubigeo`, `ubigeo_base`, `area` | Como arriba |
| `edad` | `p208_01`; hay 2 a 8 casos de 16–17 años por año, tal como vienen |
| `factor` | `facgob07` (2014), `famiegob07` (2015–2025) (D14). No se usa `facgob_p` (2020–2021) |
| `delincuencia_problema` | Menciona la delincuencia entre los principales problemas del país (`p2_1_15` = 15) |
| `inseguridad_problema` | Menciona la delincuencia o la falta de seguridad ciudadana (`p2_1_15` = 15 o `p2_1_04` = 4) |
| `confia_pnp` | Confía en la Policía Nacional "suficiente" (3) o "bastante" (4) según `p1_06`. "Nada" (1), "poco" (2) y "no sabe" (5) valen 0 |
| `cuestionario_reducido` | 1 = cuestionario telefónico reducido (2020–2021); la opinión sí se preguntó |

## 5. `distrito_anio`: base distrito-año

**Unidad:** `ubigeo_base` × `anio`.

**Columnas por indicador (D16).** Para cada indicador de las cuatro bases hay
tres columnas:

| Columna | Contenido |
|---|---|
| `<indicador>` | Proporción ponderada (0 a 1) con el factor de su base. `percepcion` y `percepcion_general_2025` usan `factor_percepcion` |
| `n_<indicador>` | Observaciones sin ponderar con dato |
| `peso_<indicador>` | Suma de los factores de esas observaciones |

**Si un distrito-año no tiene observaciones** para un indicador, el indicador
queda vacío, con `n_` = 0 y `peso_` = 0.

**No hay umbral mínimo de observaciones ni suavizado.** Según el uso, se puede
filtrar por `n_` o ponderar por `peso_`.

**Indicadores incluidos**
- De `enapres_personas`: `victima_comun`, `victima_completa`, `robo_dinero`,
  `robo_vehiculo`, `amenazas`, `extorsion`, `extorsion_o_intento`, `estafa`,
  `robo_negocio`, `ofensas_sexuales`, `arma_fuego`, `denuncio`, `percepcion`,
  `percepcion_general_2025`.
- De `enapres_hogares`: `robo_vivienda`.
- De `enaho_hogares`: `hecho_delictivo`.
- De `enaho_opinion`: `delincuencia_problema`, `inseguridad_problema`,
  `confia_pnp`.

**Columnas de diseño**
- `prop_enapres_telefonica`: proporción de personas de la ENAPRES entrevistadas
  por teléfono (2020–2022; vacía en otros años).
- `prop_enaho_cuestionario_reducido`: proporción de hogares de la ENAHO con el
  cuestionario reducido.

**Cobertura por año**

| | Distritos |
|---|---|
| ENAPRES (personas y hogares) | 526–561 |
| ENAHO hogares | 1 161–1 309 (878 en 2020) |
| ENAHO opinión | 1 161–1 308 |

---

## 6. Verificación con cifras del INEI

**Fuentes** (`08_verificacion.R`):

- **[V]** INEI (2025), *Victimización en el Perú 2024* (ENAPRES 2015–2024):
  - cuadros 1.1 (victimización), 1.10 (denuncia), 1.17 (arma de fuego, como
    porcentaje de las víctimas), 2.1 (robo e intento de robo de vivienda) y 3.1
    (percepción);
  - sus cifras 2015–2021 coinciden con INEI (2022), *Victimización en el Perú
    2015–2021*.
- **[G]** INEI (2025), *Perú: Percepción ciudadana sobre gobernabilidad, democracia
  y confianza en las instituciones, julio–diciembre 2024*. Se compara con el mismo
  semestre (meses 7–12) de la base de opinión.

Tabla completa en `datos_procesados/verificacion_oficial.csv`. Valores: INEI /
construido, en %.

| Indicador — versión | 2015 | 2016 | 2017 | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 |
|---|---|---|---|---|---|---|---|---|---|---|
| Victimización — `victima_comun` | 30,8 / 30,8 | 28,8 / 28,6 | 26,4 / 26,1 | 25,7 / 25,4 | 26,6 / 26,3 | 23,4 / 23,0 | 18,2 / 18,0 | 22,9 / 22,7 | 27,1 / 25,6 | 27,1 / 24,5 |
| Victimización — `victima_completa` | 30,8 / 30,8 | 28,8 / 31,2 | 26,4 / 28,6 | 25,7 / 27,1 | 26,6 / 27,3 | 23,4 / 23,6 | 18,2 / 18,4 | 22,9 / 23,1 | 27,1 / 27,3 | 27,1 / 26,7 |
| Arma de fuego entre víctimas de la lista común | 8,1 / 8,1 | 8,9 / 8,9 | 9,2 / 9,2 | 9,1 / 9,1 | 11,3 / 11,3 | 12,6 / 12,6 | 12,6 / 12,6 | 11,3 / 11,4 | 12,7 / 13,2 | 10,1 / 11,0 |
| Denuncia — `denuncio` (víctimas de la lista completa) | 14,0 / 14,0 | 12,8 / 12,1 | 14,5 / 12,6 | 16,2 / 14,5 | 16,7 / 15,1 | 17,0 / 16,2 | 15,3 / 14,1 | 14,9 / 14,0 | 15,6 / 14,8 | 16,1 / 15,1 |
| Denuncia — entre víctimas de la lista común | 14,0 / 14,0 | 12,8 / 12,9 | 14,5 / 13,6 | 16,2 / 15,2 | 16,7 / 15,6 | 17,0 / 16,5 | 15,3 / 14,4 | 14,9 / 14,1 | 15,6 / 14,8 | 16,1 / 15,3 |
| Percepción — `percepcion` | 88,4 / 88,4 | 90,0 / 89,5 | 86,9 / 86,4 | 86,3 / 85,7 | 85,8 / 85,1 | 83,2 / 82,5 | 83,9 / 83,0 | 85,2 / 84,6 | 83,6 / 82,8 | 86,0 / 85,2 |
| Robo o intento de robo de vivienda — `robo_vivienda` | 11,4 / 11,6 | 10,8 / 10,7 | 10,5 / 10,5 | 9,5 / 9,5 | 9,4 / 9,4 | 10,4 / 10,4 | 8,8 / 8,7 | 9,9 / 10,1 | 12,9 / 12,8 | 10,8 / 10,8 |

Semestre julio–diciembre (ENAHO, [G]):

| Indicador | 2023 | 2024 (preliminar) |
|---|---|---|
| `delincuencia_problema` | 38,0 / 37,9 | 45,0 / 45,1 |
| Falta de seguridad ciudadana (`p2_1_04`, solo para verificar) | 13,5 / 13,6 | 17,6 / 17,4 |
| `confia_pnp` | 20,1 / 19,6 | 18,0 / 16,9 |

**Lectura**

1. **Coincidencias exactas o casi exactas.**
   - **2015:** todos los indicadores coinciden exactamente.
   - **Robo de vivienda:** coincide con diferencias de ±0,2 puntos.
   - **Arma de fuego entre víctimas de la lista común:** coincide exactamente en
     2015–2021.
   - **Delincuencia y falta de seguridad como problema:** dentro de ±0,2 puntos.
2. **Victimización y percepción quedan levemente por debajo desde 2016.** Con la
   definición comparable, la brecha es de 0,2–0,4 puntos en victimización y
   0,5–0,9 en percepción.
   - Como la proporción con arma de fuego **entre las víctimas** coincide
     exactamente, las víctimas identificadas son las mismas. La diferencia está en
     el denominador o en los totales de población que usa el INEI.
   - No se explica por residentes habituales, edad (14 o 15 años), entrevistas
     incompletas ni casos con respuestas faltantes; todo eso se probó.
   - Una hipótesis no verificada es que el INEI tabule con factores actualizados
     que no están en los microdatos públicos.
   - La brecha es pequeña y estable, así que no afecta la comparación entre años
     ni entre distritos.
3. **La definición de victimización del INEI cambia.**
   - **2015–2022:** coincide con `victima_comun`.
   - **2023:** el INEI incluye los delitos informáticos, pero no el intento de
     extorsión. Con esa lista, nuestro cálculo da 26,8 % frente a 27,1 %.
   - **Desde 2024:** incluye también el intento de extorsión, como
     `victima_completa`.
   - `victima_comun` mantiene una lista fija los 12 años. Por eso en 2023–2024
     queda 1,5–2,6 puntos debajo de la cifra oficial.
4. **Denuncia.** La definición aprobada (D7, víctimas de la lista completa) queda
   0,7–1,9 puntos debajo del INEI desde 2016.
   - El intento de extorsión entra en la lista completa desde 2016, y sus víctimas
     casi no denuncian.
   - Con las víctimas de la lista común, la brecha baja a 0–1,1 puntos.
5. **Confianza en la PNP:** queda 0,5–1,1 puntos debajo de la cifra semestral
   del INEI. Las cifras de 2024 del INEI son preliminares.
6. **ENAHO, hogar afectado por hecho delictivo:** no se encontró una cifra
   publicada por el INEI. El archivo de verificación la reporta sin valor oficial
   (2,2–4,0 % según el año).

---

## 7. Advertencias para el análisis

- **Quiebres de serie:**
  - **Estafa en 2025:** baja de 3,8 % a 2,0 %, junto con los cambios en los
    delitos informáticos.
  - **Percepción:** en 2024–2025 se mide en una submuestra.
  - **`victima_completa` en 2016 y en 2023–2024:** sube por los tipos que se
    agregan a la lista.
- **Indicadores ralos.** Extorsión, robo de vehículo, ofensas sexuales, robo de
  negocio y arma de fuego valen cero en la mayoría de distrito-año (65–90 %; ver
  `inventario/ceros_distrito_anio.csv`).
- **2020.** La ENAPRES se hizo por teléfono de abril a agosto, y la ENAHO perdió
  `hecho_delictivo` en esos meses. Hay que usar `prop_enapres_telefonica`,
  `prop_enaho_cuestionario_reducido` y los `n_`.
