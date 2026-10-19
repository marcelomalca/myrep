# Inventario ENAHO 2014–2025 (fase 1)

Encuesta Nacional de Hogares (INEI), metodología actualizada, periodo anual
(enero–diciembre). Consulta y descarga realizadas el 19 de octubre de 2026.

Todo lo que se afirma aquí sobre variables, etiquetas y valores se verificó en los
archivos descargados. Los scripts que lo reproducen están en `enaho/inventario/`:

| Script | Qué hace | Salidas |
|---|---|---|
| `enaho/01_descarga.R` | Descarga los módulos sin modificarlos | `datos_brutos/<año>/*.zip`, `datos_brutos/manifiesto_descargas.csv` |
| `inventario/00_extraer.R` | Extrae los zips en `enaho/cache/` (copia de trabajo) | — |
| `inventario/01_metadatos.R` | Nombre, etiqueta y etiquetas de valores de todas las variables, por año y archivo | `variables_por_anio.csv` |
| `inventario/02_cobertura.R` | Distritos, hogares, personas y ocupados por distrito y año | `cobertura_*.csv` |
| `inventario/03_verificaciones.R` | Verificaciones sobre los datos citadas abajo | `verif_*.csv` |

---

## 1. Resumen

- **La ENAHO 2025 anual ya está publicada** (código 1031). El periodo de trabajo es
  **2014–2025**. 2026 solo tiene los trimestres 1 y 2.
- **Todos los outcomes pedidos pueden construirse para los 12 años**, con una
  excepción importante: **el INEI dejó de publicar las variables de informalidad
  (`ocupinf`, `emplpsec`) en 2024 y 2025**. Para esos años habría que reconstruirlas
  a partir de sus componentes, que sí existen todos los años (sección 4.3).
- **Deflactores:** el INEI publica con la sumaria de 2025 una serie única
  (`deflactores_base2025_new.dta`) que cubre 2001–2025. Con ella, los valores
  reales quedan en **soles de 2025 a precios de Lima Metropolitana**.
- **Factores de expansión:** la serie es consistente. Los nombres son los mismos los
  12 años y todos están calibrados a las proyecciones del CPV 2007, sin
  recalibraciones.
- **2020:** el 49.5 % de los hogares se entrevistó por teléfono con un
  cuestionario reducido, que no registra por partidas el ingreso de la ocupación
  secundaria.
- **Cobertura de los 276 distritos con oro:**
  - entre 184 y 209 aparecen en la muestra cada año, con una mediana de 14 hogares;
  - 121 aparecen los 12 años;
  - 26 nunca aparecen.
- **Hay 11 decisiones de construcción que necesito que apruebes** antes de la fase 2
  (sección 9).

---

## 2. Descarga

**Fuente.** Portal de microdatos del INEI (https://proyectos.inei.gob.pe/microdatos/),
opción "ENAHO Metodología ACTUALIZADA" → "Condiciones de Vida y Pobreza - ENAHO" →
año → "Anual - (Ene-Dic)". Cada módulo se descarga en formato STATA desde:

`https://proyectos.inei.gob.pe/iinei/srienaho/descarga/STATA/<código>-Modulo<NN>.zip`

| Año | 2014 | 2015 | 2016 | 2017 | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Código | 440 | 498 | 546 | 603 | 634 | 687 | 737 | 759 | 784 | 906 | 966 | 1031 |

**Módulos descargados (12 años × 5 = 60 archivos, 852 MB):**

| Módulo | Contenido | Archivo de datos |
|---|---|---|
| 01 | Características de la vivienda y del hogar | `enaho01-<año>-100.dta` |
| 02 | Características de los miembros del hogar | `enaho01-<año>-200.dta` |
| 04 | Salud (seguro de salud y quién lo paga) | `enaho01a-<año>-400.dta` |
| 05 | Empleo e ingresos | `enaho01a-<año>-500.dta` |
| 34 | Sumarias (variables calculadas) | `sumaria-<año>.dta` |

El módulo 04 no estaba en la lista mínima, pero es necesario para el componente de
seguro de salud de la informalidad (sección 4.3). Los números de módulo son los
mismos los 12 años.

**Lo que trae cada zip, además de los datos:**
- el diccionario de variables (PDF);
- la ficha técnica;
- el cuestionario (en el módulo 05);
- las tablas de códigos CIIU rev. 3 y rev. 4, CIUO-88 y CNO-2015;
- en el módulo 34, un zip `ConstVarGasto-Metodologia actualizada` con:
  - los deflactores;
  - el do-file del INEI que construye el gasto y el ingreso real.

**Particularidades de los archivos** (no impiden la lectura, pero el código debe
contemplarlas):
- **2015 trae dos archivos del módulo 05** (`enaho01a-2015-500.dta` y
  `enaho01a-2015_500.dta`), ambos con 794 variables. Usaré `enaho01a-2015-500.dta`,
  que sigue el patrón de los demás años. Pendiente en la fase 2: confirmar que el
  otro es un duplicado.
- **La estructura de carpetas dentro de los zips cambia entre años** (en 2015, el
  módulo 04 y el 34 no traen carpeta).
- **El zip `ConstVarGasto` viene en `.rar` en 2018 y 2022.** No afecta, porque se
  usan los deflactores de 2025.
- **`conglome` tiene 4 dígitos en 2014 y 6 desde 2015.** El INEI incluye
  `ConglomeA6digitos.do`, que completa con ceros a la izquierda hasta 6 dígitos;
  aplicaré lo mismo.
- **`ubigeo` es texto de 6 dígitos con ceros a la izquierda en todos los años.**

**Archivos en el repositorio.** Los zips (852 MB) y la copia extraída (7 GB) no se
versionan: se excluyen en `.gitignore`. Se versionan el manifiesto con tamaño y MD5
de cada zip y los scripts que los regeneran.

---

## 3. Deflactores

| Archivo | Contenido |
|---|---|
| `deflactores_base2025_new.dta` (en el zip de 2025) | Índices temporales por departamento (24, Callao se asigna a Lima) y año 2001–2025: `i00` (general) e `i01`–`i08` (8 grupos de gasto) |
| `despacial_ldnew.dta` | Deflactor espacial `ld` para 17 dominios geográficos (Lima Metropolitana = 1). Es idéntico en todas las ediciones |

- **Año base:** todos los índices valen 1 en 2025 para todos los departamentos
  (verificado). Con el deflactor espacial, **los valores reales quedan en soles de
  2025 a precios de Lima Metropolitana**.
- **Ediciones anteriores:** la edición 2024 (base 2024) es proporcional a la de 2025
  dentro de cada departamento (`verif_deflactores.csv`). Usar la edición 2025 para
  todos los años es equivalente a usar cualquier otra y luego cambiar de base.
- **Procedimiento del INEI** (do-file `01_ConstrVarGastoIngreso2015-2025.do`):
  1. cruzar la sumaria con los índices por año y departamento;
  2. cruzar con `ld` por un dominio de 17 categorías que se construye con `dominio`,
     `estrato` (urbano si es menor que 6) y el departamento;
  3. dividir cada monto anual entre `12 × miembros × ld × índice`.

---

## 4. Disponibilidad por outcome

`x` = existe con el mismo nombre y significado; los cambios se detallan debajo de
cada tabla.

### 4.1 Gasto real per cápita mensual (sumaria)

| Variable | Contenido | 2014–2025 |
|---|---|---|
| `gashog2d` | Gasto total bruto del hogar (anual, nominal) | x |
| `mieperho` | Total de miembros del hogar | x |
| `factor07` | Factor de expansión del hogar | x |
| `dominio`, `estrato`, `ubigeo` | Para el deflactor espacial y el área | x |

- **Diferencia con el método del INEI.** El INEI no deflacta el gasto total con un
  solo índice: deflacta cada uno de los 8 grupos con su índice (`i01`–`i08`) y luego
  suma. Construí ambas versiones (`verif_gasto_ingreso.csv`). La que pediste
  (`gashog2d / (12 × mieperho × ld × i00)`) difiere del método del INEI en el
  promedio nacional entre −0.3 % y +1.1 %. La diferencia es mayor en 2021–2022, por
  la inflación dispar entre grupos.
- **Gasto real promedio, método del INEI** (S/ mensuales por persona, 2025, Lima):

  | Año | 2014 | 2015 | 2016 | 2017 | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 |
  |---|---|---|---|---|---|---|---|---|---|---|---|---|
  | Gasto | 949 | 954 | 974 | 972 | 988 | 999 | 840 | 892 | 898 | 892 | 903 | 920 |

- **Variables del do-file que faltan en algunos años.** Hay que tratarlas como 0,
  igual que el INEI (al apilar las sumarias, las vuelve 0 con `recode (.=0)`):
  - `gru52hd2` no existe desde 2017;
  - `sg27` y `sig28` solo existen desde 2023;
  - `insedthd1` y `paesechd1` solo existen en 2020–2022 (cuestionario reducido).

### 4.2 Ingreso

**a) Ingreso real per cápita mensual del hogar (sumaria)**

| Variable | Contenido | 2014–2025 |
|---|---|---|
| `inghog2d` | Ingreso neto total del hogar (anual, nominal) | x |
| `inghog1d` | Ingreso bruto del hogar (alternativa, ver abajo) | x |

**La serie oficial de ingreso real del INEI (`ipcr_0` en su do-file) es el ingreso
bruto, no el neto.** Coincide exactamente con `inghog1d` deflactado con `i00` y `ld`
en los 12 años. El ingreso neto que pediste (`inghog2d`) es entre 4 % y 5 % menor y no
será comparable directamente con las cifras publicadas.

**b) Ingreso laboral mensual del trabajador (módulo 05)**

| Componente | Ocupación principal | Ocupación secundaria |
|---|---|---|
| Dependiente, monetario | `i524a1` | `i538a1` |
| Dependiente, en especie | `d529t` | `d540t` |
| Independiente, monetario (ganancia neta) | `i530a` | `i541a` |
| Independiente, autoconsumo | `d536` | `d543` |
| Ingresos extraordinarios por trabajo | `d544t` (ambas) | |

Las 9 variables existen los 12 años con el mismo nombre.

- **Prefijos `p`, `d` e `i`.** Según la nota del INEI que trae cada zip:
  - `p` es el valor de campo;
  - `d` es el valor anualizado y ajustado al IPC promedio del año (por grupo de
    gasto y departamento);
  - `i` es el valor `d` con imputación de los faltantes.

  Los componentes en especie y extraordinarios solo existen como `d`: no tienen
  versión imputada.
- **Cambio de etiqueta en 2022.** Las variables `i` dicen "(imputado, deflactado,
  anualizado)" hasta 2021 y "(imputado, anual)" desde 2022. Verifiqué que **el
  significado no cambió**: en los 12 años, `i524a1 = d524a1`, `i530a = d530a`,
  `i538a1 = d538a1` e `i541a = d541a` en el 100 % de los casos con dato deflactado
  (`verif_imputado_deflactado.csv`).
- **Los montos son nominales.** Están anualizados a precios promedio de cada año, no
  son reales entre años. Para comparar en el tiempo hay que deflactarlos con `i00` y
  `ld` (decisión 3).
- **2020–2021.** Con el cuestionario reducido, el ingreso de la ocupación secundaria
  se preguntó en una sola pregunta (`p538a_1`–`p538a_3`), procesada en `i538a_1`,
  `d538a_1` y `d538a_2`. La etiqueta dice "mensualizado" en 2020 y "anualizado" en
  2021; verificaré la escala en la fase 2.

**c) Ingreso laboral por hora**

Ingreso laboral mensual entre las horas trabajadas en el mes (decisión 5).

### 4.3 Informalidad laboral (ocupados)

| Variable | Contenido | 2014–2023 | 2024–2025 |
|---|---|---|---|
| `ocupinf` | Empleo informal, ocupación principal (1 = informal, 2 = formal) | x | **no existe** |
| `emplpsec` | 1 = informal en el sector informal, 2 = informal fuera del sector informal (vacía para los formales) | x | **no existe** |
| `p558a1`–`p558a5` | Sistema de pensiones: AFP, ONP 19990, 20530, otro, no afiliado | x | x |
| `p419a1`–`p419a8` (módulo 04) | Quién aporta las cuotas de cada seguro de salud (1 = su centro de trabajo) | x | x |
| `p507`, `p510`, `p510a1`, `p510b`, `p512a`, `p512b` | Categoría, tipo de empleador, registro en SUNAT, libros contables, tamaño | x | x |

- **`ocupinf` y `emplpsec` no se publican en 2024 ni 2025.** No se renombraron: no
  hay ninguna variable equivalente en esos años, y ya no figuran en los diccionarios
  de 2024 y 2025. No encontré una nota del INEI que lo explique. La prensa cita la
  tasa de informalidad de 2024 a partir de la EPEN, no de la ENAHO, pero no lo pude
  confirmar en una fuente del INEI.
- **Empleo en el sector informal** = `emplpsec == 1`. Vale 0 para el resto de los
  ocupados, incluidos los formales, para los que `emplpsec` está vacía por
  construcción.
- **Seguro de salud vinculado al empleo.** `p419a*` permite medirlo directamente: el
  seguro lo paga el centro de trabajo. Es mejor que usar la afiliación a EsSalud como
  aproximación.
- **Tasa de empleo informal 2023 con `ocupinf`:** 73.9 % (ocupados residentes, con
  `fac500a`). Se contrastará con la cifra oficial en la fase 2.
- **Universo del módulo 05.** Incluye a no residentes con factor positivo (entre
  1.5 % y 2.8 % de las filas en los años revisados: 2014, 2019 y 2023). Aplicaré el filtro de residentes habituales del INEI:
  `(p204 == 1 & p205 == 2) | (p204 == 2 & p206 == 1)`.

### 4.4 Mercado laboral (14 años o más, módulo 05)

| Variable | Contenido | 2014–2025 | Cambios |
|---|---|---|---|
| `ocu500` | 1 = ocupado, 2 = desocupado abierto, 3 = desocupado oculto, 4 = no PEA | x | Ninguno |
| `p208a` | Edad (el módulo incluye solo personas de 14 años o más) | x | Ninguno |
| `i513t` | Horas trabajadas la semana pasada, ocupación principal (imputadas) | x | Solo redacción |
| `i518` | Horas trabajadas la semana pasada, ocupaciones secundarias (imputadas) | x | Solo redacción |
| `p513t`, `p518` | Las mismas horas, sin imputar | x | Ninguno |
| `p520` | Horas que *normalmente* trabaja en todas sus ocupaciones (otro concepto; solo se pregunta a una parte) | x | Ninguno |
| `p506r4` | Rama, CIIU rev. 4, 4 dígitos | x | Ninguno |
| `p506` | Rama, CIIU rev. 3 | x | Ninguno |
| `p507` | Categoría ocupacional (1 empleador, 2 independiente, 3 empleado, 4 obrero, 5 TFNR, 6 trabajador del hogar, 7 otro) | x | Ninguno |

- **Tasas.** Tasa de actividad = PEA (`ocu500` 1–3) / población de 14 años o más.
  Tasa de ocupación = ocupados (`ocu500 == 1`) / población de 14 años o más.
- **Rama y división 07.** `p506r4` es numérica, así que el cero inicial se pierde
  (0710 se guarda como 710). División = `floor(p506r4 / 100)`; la división 07
  (extracción de minerales metalíferos) corresponde a los códigos 710–729.
  - El 100 % de los ocupados tiene código todos los años.
  - La división 07 es entre 0.8 % y 1.1 % de los ocupados.
  - Entre 418 y 704 trabajadores residentes por año en la muestra (439–730 sin
    filtrar residencia).

---

## 5. Factores de expansión

| Factor | Archivo | Uso | 2014–2025 |
|---|---|---|---|
| `factor07` | sumaria, módulos 01 y 04 | Hogares | x |
| `facpob07` | módulo 02 | Personas (miembros del hogar) | x |
| `fac500a` | módulo 05 | Empleo e ingresos (14 años o más) | x |
| `factor_p` / `fac500_p` | módulos 01, 02, 04 y 05 | Solo 2020 ("presencial") y 2021 ("presencial o completo") | Solo 2020–2021 |

- **La serie es consistente para todo el periodo.** Los nombres son los mismos y todas
  las etiquetas dicen "proyecciones CPV-2007" de 2014 a 2025: el INEI no
  recalibró los factores al CPV 2017 en estos archivos. Los totales expandidos
  crecen de forma suave, sin saltos que indiquen recalibración:

| Año | 2014 | 2015 | 2016 | 2017 | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Hogares expandidos (millones) | 8.21 | 8.51 | 8.62 | 8.81 | 9.01 | 9.18 | 9.39 | 9.90 | 10.00 | 10.20 | 10.36 | 10.71 |
| Población (`factor07 × mieperho`, millones) | 31.27 | 31.66 | 31.89 | 32.11 | 32.38 | 32.68 | 32.97 | 33.27 | 33.75 | 34.11 | 34.48 | 34.86 |
| Población de 14 años o más (`fac500a`, millones) | 23.30 | 23.71 | 24.01 | 24.23 | 24.56 | 24.89 | 25.27 | 25.60 | 26.08 | 26.52 | 26.94 | 27.35 |

- **Factores de 2020–2021.** `factor_p` y `fac500_p` expanden solo la submuestra
  presencial. Son alternativas del INEI para análisis sin entrevistas telefónicas,
  no reemplazan a los factores anuales.
- **Factor de las medidas per cápita.** El INEI pondera el gasto y el ingreso per
  cápita por personas (`factor07 × mieperho`), no por hogares (decisión 9).
- **Sin faltantes.** `factor07` y `fac500a` no tienen valores faltantes en ningún año.

---

## 6. Particularidades de 2020 (y 2021)

| Mes 2020 | Ene | Feb | Mar | Abr | May | Jun | Jul | Ago | Set | Oct | Nov | Dic |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Hogares (sumaria) | 2852 | 2846 | 2844 | 2892 | 2872 | 2922 | 2880 | 2952 | 2882 | 2902 | 2851 | 2795 |
| Entrevista telefónica | 0 | 0 | 684 | 2892 | 2872 | 2922 | 2880 | 2952 | 1875 | 0 | 0 | 0 |

- **Entrevistas telefónicas.** Variables `tipoentrevista` (1 presencial,
  2 telefónica) y `tipocuestionario` (0 completo antes de la emergencia, 1 reducido,
  2 completo durante la emergencia). Del 16 de marzo a mediados de setiembre, todas
  las entrevistas fueron telefónicas con cuestionario reducido: **17 077 hogares, el
  49.5 % del año**.
- **El tamaño de la muestra no cayó:** cerca de 2 850 hogares por mes, igual que en
  2019. Sí cambió el modo de entrevista.
- **Qué falta con el cuestionario reducido** (`verif_cuestionario_2020_2021.csv`):
  - falta el ingreso de la ocupación secundaria por partidas (`i538a1`, `d540t`,
    `i541a`, `d543`, con 0 % de datos); se registra de forma agregada en `i538a_1`;
  - se mantienen la categoría, el registro en SUNAT, el tamaño, las horas, la
    afiliación a pensiones, el ingreso principal y `ocupinf`/`emplpsec`;
  - en el módulo 04 se mantiene quién paga el seguro de salud.
- **2021.** Hubo cuestionario reducido en febrero (segunda cuarentena): 1 958
  viviendas y 2 486 ocupados. `tipoentrevista` ya no existe en 2021.
- **Recomendación:** usar los factores anuales en todos los años y conservar en la
  base de personas y hogares una variable con el tipo de entrevista y cuestionario,
  para poder excluir o controlar 2020 en el análisis.

---

## 7. Clasificaciones y codificación

- **Rama.** Los archivos de los 12 años traen **las dos versiones de la CIIU**: rev. 3
  (`p506`) y rev. 4 (`p506r4`), completas para todos los ocupados. No hay quiebre
  dentro del periodo si se usa la rev. 4 en todos los años. Que la rev. 4 de los
  primeros años sea un código asignado en campo o una conversión del INEI no puede
  determinarse con los datos.
- **Ocupación** (no la pediste, pero también es estable): CIUO-88 (`p505`) y CNO-2015
  (`p505r4`), ambas en los 12 años.
- **En 2015, `p506`, `p506r4`, `p505` y `p505r4` vienen sin etiquetas de valores.**
  Los códigos son los mismos; las etiquetas se toman de las tablas que trae el zip.
- **`p510`** (tipo de empleador) incluye el código 4 ("cooperativa de trabajadores")
  solo en 2014.
- **`estrato`** (marco muestral) cambia de definición: en 2014–2015 se basa en el
  número de viviendas y desde 2016 en el número de habitantes. En ambos casos los
  códigos 1–5 son urbanos y 6–8 rurales; el INEI usa esa regla para el área en todos
  los años, y Lima Metropolitana (dominio 8) se considera urbana.
- **`p507`** (categoría ocupacional) y **`ocu500`** tienen la misma codificación los
  12 años.

---

## 8. Cobertura distrital

**Muestra por año** (hogares de la sumaria; personas = residentes habituales del
módulo 02):

| Año | Distritos | Hogares | Personas | Hogares por distrito: mín / mediana / media / máx | Personas por distrito (mediana) |
|---|---|---|---|---|---|
| 2014 | 1161 | 30 848 | 114 095 | 4 / 14 / 26.6 / 486 | 45 |
| 2015 | 1216 | 32 188 | 116 552 | 2 / 14 / 26.5 / 430 | 47 |
| 2016 | 1256 | 35 785 | 128 651 | 4 / 14 / 28.5 / 522 | 46 |
| 2017 | 1262 | 34 584 | 122 825 | 3 / 14 / 27.4 / 428 | 46 |
| 2018 | 1316 | 37 462 | 130 357 | 2 / 15 / 28.5 / 495 | 48 |
| 2019 | 1259 | 34 565 | 120 052 | 3 / 14 / 27.5 / 433 | 45 |
| 2020 | 1217 | 34 490 | 118 810 | 2 / 15 / 28.3 / 427 | 47 |
| 2021 | 1255 | 34 245 | 113 057 | 3 / 14 / 27.3 / 419 | 42 |
| 2022 | 1253 | 34 213 | 113 142 | 2 / 14 / 27.3 / 426 | 42 |
| 2023 | 1263 | 33 886 | 110 792 | 2 / 14 / 26.8 / 434 | 41 |
| 2024 | 1271 | 33 691 | 108 664 | 2 / 14 / 26.5 / 423 | 40 |
| 2025 | 1271 | 33 702 | 106 135 | 3 / 14 / 26.5 / 433 | 38 |

En total aparecen 1612 códigos de distrito distintos en 2014–2025.

**Distritos de `datos/oro_por_distrito_pre2014.csv` (276):**

| Año | En la muestra | Hogares | Hogares por distrito: mín / mediana / máx | Personas | Ocupados por distrito (mediana) | Con trabajadores de la división 07 |
|---|---|---|---|---|---|---|
| 2014 | 184 | 4 186 | 5 / 14 / 329 | 15 261 | 24 | 58 |
| 2015 | 185 | 4 122 | 5 / 13 / 293 | 14 463 | 23 | 60 |
| 2016 | 193 | 4 772 | 4 / 15 / 349 | 16 453 | 22 | 63 |
| 2017 | 193 | 4 555 | 4 / 15 / 284 | 15 473 | 24 | 58 |
| 2018 | 209 | 5 439 | 4 / 16 / 495 | 18 001 | 28 | 71 |
| 2019 | 193 | 4 603 | 3 / 15 / 292 | 15 387 | 25 | 57 |
| 2020 | 186 | 4 620 | 3 / 15 / 322 | 15 559 | 26 | 40 |
| 2021 | 188 | 4 376 | 4 / 15 / 337 | 14 135 | 27 | 58 |
| 2022 | 191 | 4 375 | 2 / 14 / 318 | 13 847 | 22 | 58 |
| 2023 | 194 | 4 327 | 3 / 14 / 327 | 13 606 | 21.5 | 61 |
| 2024 | 198 | 4 405 | 2 / 14 / 305 | 13 906 | 21.5 | 62 |
| 2025 | 197 | 4 362 | 4 / 14 / 309 | 13 328 | 21 | 70 |

- **Años en la muestra.** 121 distritos con oro aparecen los 12 años; su mediana es
  de unos 20 hogares por año.
- **Distritos nunca muestreados.** 26 no aparecen en ningún año; concentran 45 de los
  799 yacimientos. Su detalle está en `cobertura_oro_por_distrito.csv`.
- **División 07.** Entre el 35 % y el 45 % de los trabajadores de la división 07 de la
  muestra nacional vive en un distrito con oro: entre 172 y 310 trabajadores por año.

**Códigos de distrito que requieren `ubigeo_base`** (fase 2, punto 3):
- **32 códigos creados después de la capa de límites usada en los mapas.** La ENAHO
  usa el ubigeo vigente de cada año: Mi Perú (070107) y Veintiséis de Octubre
  (200115) aparecen desde 2015; Putumayo (160801) desde 2020; Rosa Panduro y
  Teniente Manuel Clavero desde 2024, entre otros. La lista completa sale de
  `cobertura_distrito_anio.csv`.
- **`120699` = "Mazamari-Pangoa"** (Satipo, Junín). No es un distrito oficial: la
  ENAHO lo usa en 2014–2020 para agrupar dos distritos (742 hogares en total), que
  en esos mismos años también aparecen por separado (120604 y 120606) (decisión 10).
- **La base de oro tiene 3 códigos posteriores a 2014:** 080915 Kumpirushiato,
  100608 Castillo Grande y 221006 Santa Lucía. Para cruzar con `ubigeo_base`
  también habrá que llevarlos a su distrito de origen.

---

## 9. Decisiones que necesito que apruebes

| # | Tema | Opciones | Mi recomendación |
|---|---|---|---|
| 1 | **Gasto real** | (a) `gashog2d` con `i00` y `ld`, como lo pediste; (b) método del INEI por grupos (`i01`–`i08`) | (a), como lo pediste. La diferencia con (b) es ≤ 1.1 % en el promedio nacional. Lo documentaré y usaré (b) solo para verificar contra las cifras oficiales |
| 2 | **Ingreso real del hogar** | (a) neto, `inghog2d`, como lo pediste; (b) bruto, `inghog1d`, que es el que publica el INEI | Necesito que lo confirmes. Si tu interés es la serie oficial, es (b). Si quieres el ingreso disponible, (a) |
| 3 | **Ingreso laboral real** | Deflactar las variables `i`/`d` del módulo 05 con `i00` (departamento-año) y `ld` (dominio), igual que el ingreso del hogar | Sí. Sin esto, el ingreso laboral es nominal a precios de cada año |
| 4 | **Informalidad 2024–2025** | (a) reconstruir `ocupinf` y `emplpsec` con los criterios del INEI para los 12 años, validar contra la variable oficial en 2014–2023 e informar la coincidencia; (b) usar solo 2014–2023 | (a), conservando la variable oficial donde exista para comparar. Si la coincidencia es baja, te lo informo antes de seguir |
| 5 | **Horas y salario por hora** | Horas totales = `i513t + i518` (semana pasada, imputadas); ingreso por hora = ingreso laboral mensual / (horas totales × 52/12) | Así. `p520` (horas habituales) no es comparable: es otro concepto y solo se pregunta a una parte de los ocupados |
| 6 | **Categoría ocupacional** | Asalariado = empleado, obrero y trabajador del hogar (3, 4, 6); independiente = 2; TFNR = 5; otros = empleador (1) y otro (7) | Así, pero confirma dónde va el **empleador**: dejarlo en "otros" o separarlo |
| 7 | **Seguro de salud vinculado al empleo** | Algún `p419a*` = 1 (el centro de trabajo aporta) | Sí |
| 8 | **Universo de personas** | Residentes habituales (filtro del INEI) | Sí |
| 9 | **Ponderación del promedio distrital de gasto e ingreso per cápita** | (a) por personas, `factor07 × mieperho` (convención del INEI); (b) por hogares, `factor07` | (a) |
| 10 | **Mazamari-Pangoa (120699)** | (a) unir 120604, 120606 y 120699 en una sola unidad `ubigeo_base` todos los años; (b) excluir los hogares con 120699 | (a) |
| 11 | **Tabla de correspondencia `ubigeo_base`** | Asignar cada distrito creado después de 2014 a su distrito de origen según su ley de creación, documentando la ley | Así. Si un distrito se formó con partes de varios, lo asignaré al que cedió la mayor parte del territorio y lo anotaré |

**Otros puntos para la fase 2:**
- Instalaré el paquete `arrow` de R para escribir los archivos `.parquet`.
- Verificaré los resultados contra las cifras oficiales del INEI:
  - gasto e ingreso real per cápita y tasa de empleo informal (informe técnico
    *Evolución de la pobreza monetaria* y publicaciones de empleo);
  - tasa de actividad y tasa de ocupación.
