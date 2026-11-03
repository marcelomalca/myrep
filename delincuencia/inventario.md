# Indicadores de delincuencia: inventario (fase 1)

Este inventario cubre la ENAPRES y la ENAHO de 2014 a 2025 y propone las
decisiones de construcción (sección 7).

**Estado:** las decisiones D1–D16 se aprobaron tal como se propusieron. La fase 2
(bases apiladas, base distrito-año y verificación) está documentada en
[`diccionario.md`](diccionario.md).

Todas las tasas de este documento son **provisionales**: sirven para ver
disponibilidad, cobertura y órdenes de magnitud, y usan las definiciones
provisionales de `inventario/04_cobertura_prevalencia.R`. Las definiciones finales
se fijan con tus respuestas a la sección 7.

Fuentes: solo la ENAPRES y la ENAHO del INEI; no se usan registros administrativos.

## 1. Descarga

**Portal y ruta de descarga**

- Portal de microdatos del INEI (`proyectos.inei.gob.pe/microdatos`). Se consultó
  el 03/11/2026, por encuesta, luego año y luego periodo "Anual".
- Los archivos salen de
  `https://proyectos.inei.gob.pe/iinei/srienaho/descarga/<formato>/<código>-Modulo<NNN>.zip`.
- La ENAPRES solo se ofrece en SPSS, CSV y DBF (no en STATA), así que se bajó en
  SPSS. La ENAHO se bajó en STATA, como en `enaho/`.

**Contenido**

- **ENAPRES** (periodo anual):
  - capítulo 100, vivienda y hogar (robo de vivienda);
  - capítulo 200, residentes;
  - capítulo de seguridad ciudadana: es el capítulo 600 en 2014–2024 y el 400 en 2025.
- **ENAHO**: módulo 85, "Gobernabilidad, Democracia y Transparencia". Los otros
  módulos ya estaban en `enaho/`.

**ENAPRES 2025: publicada.** El portal lista la ENAPRES de 2010 a 2025, y la
edición anual 2025 (código 1030) se descargó completa. Así, 2014–2025 queda
completo en ambas encuestas.

En el portal, 2017 usa el código de periodo anual 143 (los demás años usan 18).
Esto solo afecta la consulta en el portal, no la ruta de descarga.

**Archivos y registro**

- Son 48 archivos y 292 MB: ENAPRES 36 (190 MB) y ENAHO 12 (102 MB).
  El más grande pesa 17 MB.
- Están en `datos_brutos/<enapres|enaho>/<año>/` sin modificar.
- `datos_brutos/registro_descargas.csv` registra URL, fecha y hora (UTC), bytes y MD5
  de cada archivo.
- Los zip y la copia extraída (`cache/`, 4,1 GB) están en `.gitignore` y se
  regeneran con `01_descarga.R` y `02_extraer.R`; en git queda el registro con los
  MD5.

| Año | ENAPRES: código | ENAPRES: módulos (cap. 100, 200, seguridad) | ENAHO: código (módulo 85) | MB |
|---|---|---|---|---|
| 2014 | 438 | 560, 562, 566 | 440 | 17.1 |
| 2015 | 495 | 699, 700, 703 | 498 | 14.6 |
| 2016 | 544 | 1073, 1074, 1077 | 546 | 23.2 |
| 2017 | 596 | 1235, 1236, 1239 | 603 | 23.6 |
| 2018 | 626 | 1370, 1371, 1374 | 634 | 25.2 |
| 2019 | 684 | 1490, 1491, 1494 | 687 | 32.2 |
| 2020 | 736 | 1618, 1619, 1622 | 737 | 26.2 |
| 2021 | 761 | 1675, 1676, 1679 | 759 | 32.7 |
| 2022 | 785 | 1727, 1728, 1731 | 784 | 34.6 |
| 2023 | 903 | 1815, 1816, 1819 | 906 | 19.7 |
| 2024 | 965 | 1856, 1857, 1860 | 966 | 22.7 |
| 2025 | 1030 | 2071, 2072, 2074 | 1031 | 20.3 |

## 2. Disponibilidad por indicador y año

La tabla completa, con una fila por indicador y año, está en
`inventario/disponibilidad.csv`. Para cada fila da el archivo, las variables, si
existen, la etiqueta de la pregunta y la codificación. La generó
`inventario/05_disponibilidad.R` comparando con los metadatos de los 48 archivos
(`inventario/variables_por_anio.csv`).

**Todas las variables listadas existen en todos los años indicados.** Solo faltan
preguntas de arma en tipos de delito que no la tienen; se explica abajo.

### 2.1 ENAPRES, capítulo de seguridad (personas)

La pregunta de victimización es la misma en los 12 años: "En los últimos 12 meses,
¿Ud. ha sido víctima de: …?", con un ítem por tipo de delito. Lo que cambia es el
prefijo de las variables y la lista de tipos.

| Pregunta | 2014–2023 | 2024 | 2025 | Codificación |
|---|---|---|---|---|
| Víctima por tipo de delito | `P601_k` | `P615_k` | `P424_k` | 1 Sí, 2 No, 3 No tiene (en los bienes) |
| ¿Denunció el hecho? (por tipo) | `P606_k` | `P619_k` | `P428_k` | 1 Sí, 2 No; solo si fue víctima |
| Tipo de arma: de fuego de mano, de fuego largo (por tipo) | `P605_k_1`, `P605_k_2` | `P632_k_1`, `P632_k_2` | `P451_k_1`, `P451_k_2` | 1 marcado, 0 pase |
| Percepción de inseguridad | `P611_1`…`P611_14` | `P601_1`…`P601_16` | `P401` (+ `P402_k`) | ver 2.3 |
| Factor de expansión | `FACTORANUALCAP600` (2014–15), `FACTORANUAL` (2016–17), `FACTOR` (2018–23) | `FACTOR`; percepción `FACTOR_CAP600B` | `FACTOR`; percepción `FACTOR_CAP400` | |
| Ubicación | `CCDD`, `CCPP`, `CCDI` | igual | igual | dos dígitos cada uno |

**Correspondencia de los ítems por tipo de delito** (detalle en
`inventario/tipos_delito_enapres.csv`):

| Indicador solicitado | 2014–2023 (`k`) | 2024 (`k`) | 2025 (`k`) | Nota |
|---|---|---|---|---|
| Robo de dinero, cartera, celular | 6A | 9 | 9 | |
| Intento de robo de dinero, cartera, celular | 6B | 10 | 10 | |
| Robo de vehículo automotor | 1 | 1 | 1 | Hay ítems aparte para intento (2), autopartes (3A/3B → 3/4), moto o mototaxi (4A/4B → 5/6) y bicicleta (5A/5B → 7/8) |
| Amenazas e intimidaciones | 7 | 14 | 14 | |
| Extorsión | 12 | 19 | 19 | |
| Intento de extorsión | 12A (desde 2016) | 20 | 20 | **No existe en 2014–2015** |
| Estafa | 13 | 21 | 21 | En 2025 no tiene pregunta de arma |
| Robo de negocio | 14 | 11 | 11 | |
| Delitos sexuales ("ofensas sexuales: acoso, abuso, violación") | 9 | 16 | 16 | |

**Cambios en la lista de delitos**

- **2016:** se agrega el intento de extorsión (12A).
- **2023:** se agrega "delitos informáticos" (16), que no tiene pregunta de arma.
- **2024:**
  - "delitos informáticos" se desagrega en fraude bancario (23), fraude al
    consumidor (24), estafas por medios tecnológicos (25), suplantación de identidad
    (26), ciberacoso (27) y otras modalidades (28);
  - "otro" se divide en "otro patrimonial" (12) y "otro no patrimonial" (22);
  - aparece "vandalismo" (13), que pregunta si fue "víctima **o testigo**".
- **2025:** desaparecen fraude al consumidor, estafas tecnológicas y vandalismo.

Los tipos informáticos no tienen pregunta de arma (por eso `disponibilidad.csv`
marca `P605_16_*`, `P632_23…28_*` y `P451_21/23…28_*` como inexistentes).

El periodo de referencia ("últimos 12 meses") y la redacción de la pregunta general
no cambian.

### 2.2 ENAPRES, capítulo 100 (hogares)

Robo en la vivienda, con la pregunta "En los últimos 12 meses de … a …, ¿han sido
víctimas de: robo en la vivienda / intento de robo en la vivienda?":

- variables: `P112_1` y `P112_2` (2014–2023), `P116_1` y `P116_2` (2024–2025);
- codificación: 1 Sí, 2 No;
- factor: `FACTORANUAL` (2014–17), `FACTOR` (2018–25).

### 2.3 Percepción de inseguridad (cambio importante)

**2014–2023:** "En los próximos 12 meses, ¿cree usted que puede ser víctima de: …?",
con 14 ítems por tipo de delito (`P611_1`…`P611_14`; 1 Sí, 2 No, 4 No sabe). El INEI
define la percepción como "Sí" en al menos un ítem.

**2024:** la misma pregunta, con 16 ítems (`P601_1`…`P601_16`; se agregan
vandalismo y delitos informáticos).

- Solo se aplica a una **submuestra**: 24.582 personas, frente a unas 65 mil en
  otros años.
- Tiene su propio factor, `FACTOR_CAP600B`.

**2025:** cambia la pregunta.

- **Nueva pregunta general:** `P401`, "En los próximos 12 meses, ¿cree usted que
  **podría ser víctima de algún hecho delictivo**?" (1 Sí, 2 No, 3 No sabe).
- **Ítems por tipo:** siguen en `P402_k`, preguntados a todos los que responden
  `P401`.
- Se agrega `P403` (sensación de seguridad en la zona o barrio).
- **Submuestra y factor:** sigue la submuestra (24.039 personas), con el factor
  `FACTOR_CAP400`.

Con la pregunta general de 2025, la percepción da **72,9 %**. Con la definición
anterior (al menos un ítem por tipo) da **83,4 %**, cercana al 85,2 % de 2024. La
serie con `P401` tendría un quiebre en 2025.

Los factores de la submuestra **no suman la población** urbana de 15 años y más:

- `FACTOR_CAP600B` (2024) y `FACTOR_CAP400` (2025) tienen valor también para
  quienes no están en la submuestra.
- Sumados solo sobre la submuestra, dan unos 19 millones, contra unos 29 millones
  con `FACTOR` sobre todos.

Esto no afecta una proporción ponderada, pero hay que confirmarlo con la ficha
técnica (decisión D6).

### 2.4 ENAHO, módulo 85

| Indicador | Archivo | Variable | Pregunta | Codificación | Años |
|---|---|---|---|---|---|
| Hogar afectado por hecho delictivo | `enaho01b-AAAA-2.dta` | `p40_5` | "En los últimos 12 meses de … a …, ¿su hogar se vio afectado por alguno de los siguientes problemas: … hecho delictivo (robo, asalto, etc.)?" (respuesta múltiple; es un ítem de la lista) | 1 marcado; 0 pase (en 2014–2016 el 0 no tiene etiqueta) | 2014–2025 |
| Delincuencia como principal problema del país | `enaho01b-AAAA-1.dta` | `p2_1_15` (mención), `p2_2_15` (orden de prioridad) | "En su opinión, actualmente, ¿cuáles son los principales problemas del país?" (respuesta múltiple) y "¿cuál es el más importante?" | 15 mencionado, 0 pase; orden 1, 2, 3… | 2014–2025 |
| Falta de seguridad ciudadana como principal problema | `enaho01b-AAAA-1.dta` | `p2_1_04`, `p2_2_04` | la misma pregunta | 4 mencionado, 0 pase | 2014–2025 |
| Confianza en la Policía Nacional | `enaho01b-AAAA-1.dta` | `p1_06` | "Actualmente, ¿tiene usted confianza en instituciones tales como: la Policía Nacional?" | 1 Nada, 2 Poco, 3 Suficiente, 4 Bastante, 5 No sabe | 2014–2025 |
| Factor del hogar | `-2.dta` | `factor07` | | | 2014–2025 |
| Factor de opinión | `-1.dta` | `facgob07` (2014), `famiegob07` (2015–2025); además `facgob_p` en 2020–2021 | | | |

En los 12 años no cambian ni la redacción ni las categorías.

## 3. Universo y diseño

### 3.1 ENAPRES

**Universo**

- El capítulo de seguridad se aplica **solo en el área urbana** (`AREA` = 1 en
  todas las filas, todos los años).
- Lo responden las personas de **14 años y más** (15 y más en 2025), de manera
  directa.
- El INEI publica sus indicadores para la población urbana de 15 años y más.

**Robo de vivienda**

- El capítulo 100 cubre lo urbano y lo rural, pero la pregunta de robo de vivienda
  solo tiene respuestas en hogares urbanos (unos 27 mil al año; en lo rural está
  vacía).
- **La ENAPRES no da información rural de delincuencia.**

**Entrevistas incompletas**

- `RESFIN` = 2 (incompleta) va de 4.500 a 12.500 personas al año.
- Muchas no tienen factor y salen al exigir factor > 0. Algunas sí tienen respuestas
  de victimización (decisión D9).

**Factores de expansión**

- `FACTORANUALCAP600` (2014–15), `FACTORANUAL` (2016–17), `FACTOR` (2018–25).
- Entre casi 0 % y 10 % de las filas no tiene factor, según el año.

**2020–2021**

- Modalidad de entrevista en `MOD_ENC` (1 presencial, 2 teléfono), disponible en
  2020–2022:
  - **2020:** solo teléfono de abril a agosto (unas 2.100 entrevistas al mes,
    frente a unas 6.000), mixto en marzo y septiembre, presencial el resto. Hay
    13.171 entrevistas telefónicas.
  - **2021:** 1.156 entrevistas telefónicas, todas en febrero.
  - **2022:** todas presenciales.
- En 2020–21 existe también `FACTOR_CALIBRADO`, que solo tienen las entrevistas
  presenciales.

Victimización según el factor y la modalidad (%):

| Año | `FACTOR`, todas | `FACTOR`, presencial | `FACTOR`, teléfono | `FACTOR_CALIBRADO`, presencial |
|---|---|---|---|---|
| 2020 | 23,6 | 24,1 | 23,1 | 23,9 |
| 2021 | 18,4 | 18,2 | 22,2 | 18,3 |

La diferencia por factor es pequeña.

**Llave del hogar (capítulo 100):** `CONGLOMERADO` + `VIVIENDA` + `HOGAR` tiene
duplicados (de 57 a 1.067 por año), así que probablemente hace falta `NSELV`. Se
resuelve en la fase 2 y se documenta.

### 3.2 ENAHO, módulo 85

**Hogar afectado (`-2.dta`)**

- Una fila por hogar, en lo urbano y lo rural.
- Según el cuestionario, esta sección la responde solo el jefe o jefa de hogar o
  su cónyuge (el jefe en el 73–79 % de los casos).
- Factor: `factor07`.
- Mide si el **hogar** "se vio afectado" por un hecho delictivo. No es exactamente
  "algún miembro fue víctima": es un ítem en una lista de choques del hogar.

**Opinión (`-1.dta`)**

- Una persona por hogar: un miembro de **18 años y más** seleccionado por el
  **cumpleaños más reciente** (nota del cuestionario).
- Hay 2 a 8 casos al año con 16–17 años, probablemente por la edad tomada del
  capítulo 200.
- Unas 2.000–3.000 filas por año no tienen respuesta ni factor (`p1_06` y el factor
  vacíos a la vez).

**2020–2021**

- `tipocuestionario` marca el cuestionario reducido telefónico.
- Ese cuestionario **no incluye `p40_5`**:
  - **2020:** todos los hogares de abril a agosto, y la mayoría de marzo y
    septiembre. Quedan 16.475 hogares con dato, frente a unos 31 mil normalmente.
  - **2021:** la mitad de los hogares de febrero.
- Las preguntas de opinión sí se hicieron en 2020: hay 32.447 respondientes.

## 4. Geografía

**ENAPRES.** **Tiene ubigeo distrital en todos los años:**

- `CCDD`, `CCPP` y `CCDI`, de dos dígitos cada uno;
- el ubigeo de 6 dígitos se reconstruye como `sprintf("%02d%02d%02d", …)`;
- 2016 además trae `UBIGEO`.

**ENAHO.** Trae `ubigeo` en los dos archivos.

**Paso a `ubigeo_base`:**

- Se aplica `ubigeo_base` con `a_base()` de `libro/R/comun.R`, que usa
  `enaho/geografia/correspondencia_ubigeo.csv`.
- **Todos los ubigeos de ambas encuestas** están en la tabla de correspondencia o
  en los límites distritales del libro (`ubigeos_sin_correspondencia.csv` está
  vacío). No hay que agregar nada a la tabla.

**Representatividad.** La muestra de ninguna de las dos encuestas está diseñada
para estimar a nivel distrital:

- la ENAPRES es representativa a nivel nacional urbano, por departamento y en
  algunas ciudades;
- la ENAHO, a nivel nacional, por área y por departamento.

La tasa distrito-año es un promedio de pocas observaciones, con mucho ruido.

## 5. Cobertura de los distritos con oro

Clasificación de `libro/R/comun.R` (antes de 2014):

- **"Mina o proyecto"**: 120 distritos.
- **"Solo prospectos u ocurrencias"**: 156 distritos.

Los distritos con oro registrado solo desde 2014 cuentan como "otro". Detalle por
año en `inventario/cobertura_anual.csv`.

**Presencia en el panel 2014–2025** (`inventario/presencia_distritos_oro.csv`):

| Fuente | Categoría | Distritos en el universo | Aparecen algún año | Los 12 años | 6 años o más | Años (mediana) |
|---|---|---|---|---|---|---|
| ENAPRES personas (urbano, 15+) | Mina o proyecto | 120 | 43 | 24 | 36 | 12 |
| ENAPRES personas (urbano, 15+) | Solo prospectos u ocurrencias | 156 | 49 | 29 | 40 | 12 |
| ENAPRES hogares, robo de vivienda | Mina o proyecto | 120 | 43 | 24 | 36 | 12 |
| ENAPRES hogares, robo de vivienda | Solo prospectos u ocurrencias | 156 | 49 | 29 | 40 | 12 |
| ENAHO hogares, hecho delictivo | Mina o proyecto | 120 | 110 | 46 | 91 | 11 |
| ENAHO hogares, hecho delictivo | Solo prospectos u ocurrencias | 156 | 141 | 56 | 116 | 11 |
| ENAHO opinión | Mina o proyecto | 120 | 110 | 56 | 91 | 12 |
| ENAHO opinión | Solo prospectos u ocurrencias | 156 | 142 | 68 | 121 | 11 |

**Lo principal:** la ENAPRES solo cubre **92 de los 276 distritos con oro** (43 con
mina o proyecto), y solo su parte urbana.

- Son sobre todo capitales de provincia y ciudades.
- La ENAHO llega a 251 de 276.

**Por año, ENAPRES personas (urbano, 15+).** Observaciones por distrito: mediana
(mínimo–máximo).

| Año | Distritos | Personas | Obs./distrito | Distritos con oro | Obs./distrito con oro | Mina/proyecto: distritos (personas) | Solo prospectos: distritos (personas) |
|---|---|---|---|---|---|---|---|
| 2014 | 526 | 71187 | 50 (8–2766) | 68 | 50.5 (8–1580) | 31 (5470) | 37 (3053) |
| 2015 | 541 | 65550 | 42 (9–2048) | 71 | 46 (11–1406) | 34 (4675) | 37 (2999) |
| 2016 | 541 | 66572 | 44 (7–2088) | 71 | 46 (9–1498) | 34 (4822) | 37 (2985) |
| 2017 | 541 | 66561 | 42 (12–2050) | 71 | 48 (12–1461) | 34 (4828) | 37 (2951) |
| 2018 | 541 | 67700 | 44 (10–2072) | 71 | 50 (12–1527) | 34 (5108) | 37 (3076) |
| 2019 | 541 | 67296 | 43 (9–1962) | 71 | 44 (10–1590) | 34 (5060) | 37 (2945) |
| 2020 | 539 | 46108 | 30 (5–1458) | 72 | 31.5 (5–1009) | 34 (3378) | 38 (1969) |
| 2021 | 546 | 63484 | 40 (7–1746) | 77 | 44 (13–1462) | 35 (4956) | 42 (2826) |
| 2022 | 556 | 62809 | 40 (8–1779) | 77 | 41 (13–1406) | 34 (4762) | 43 (2786) |
| 2023 | 561 | 64480 | 41 (10–1859) | 77 | 40 (10–1427) | 34 (4844) | 43 (2670) |
| 2024 | 561 | 62349 | 39 (6–1874) | 77 | 37 (8–1353) | 34 (4636) | 43 (2562) |
| 2025 | 561 | 60214 | 39 (7–1791) | 77 | 39 (10–1175) | 34 (4322) | 43 (2521) |

En 2024–2025, la percepción (submuestra) baja a unas 24 mil personas: 15–16 por
distrito en la mediana, con mínimos de 1 a 4. La tabla de hogares de la ENAPRES
tiene los mismos distritos, con una mediana de 16–24 hogares.

**Por año, ENAHO hogares (hecho delictivo).**

| Año | Distritos | Hogares | Obs./distrito | Distritos con oro | Obs./distrito con oro | Mina/proyecto: distritos (hogares) | Solo prospectos: distritos (hogares) |
|---|---|---|---|---|---|---|---|
| 2014 | 1161 | 28826 | 14 (2–363) | 187 | 14 (5–311) | 86 (2175) | 101 (2115) |
| 2015 | 1209 | 30416 | 14 (1–358) | 188 | 12 (4–279) | 83 (2114) | 105 (2121) |
| 2016 | 1249 | 33345 | 14 (3–461) | 196 | 15 (4–348) | 84 (2446) | 112 (2391) |
| 2017 | 1255 | 31870 | 14 (1–368) | 196 | 15 (4–268) | 83 (2263) | 113 (2305) |
| 2018 | 1309 | 33942 | 15 (1–457) | 212 | 15 (3–457) | 91 (2788) | 121 (2598) |
| 2019 | 1251 | 31805 | 14 (1–359) | 196 | 14 (2–273) | 82 (2250) | 114 (2340) |
| 2020 | 878 | 16475 | 8 (1–231) | 140 | 9 (4–167) | 61 (1050) | 79 (1286) |
| 2021 | 1205 | 31075 | 14 (2–382) | 187 | 14 (4–331) | 81 (2161) | 106 (2073) |
| 2022 | 1226 | 32368 | 14 (1–383) | 193 | 14 (2–307) | 85 (2245) | 108 (2163) |
| 2023 | 1234 | 31943 | 14 (1–369) | 196 | 14 (3–321) | 86 (2259) | 110 (2131) |
| 2024 | 1241 | 30774 | 13 (1–340) | 200 | 14 (2–295) | 88 (2276) | 112 (2139) |
| 2025 | 1241 | 31261 | 13 (1–328) | 199 | 13 (1–295) | 87 (2202) | 112 (2140) |

La ENAHO de opinión tiene una cobertura casi igual (13–15 personas por distrito en
la mediana). En 2020 no cae, porque la opinión sí se preguntó por teléfono.

## 6. Prevalencia nacional y distrito-año sin casos

Todas las cifras son porcentajes ponderados con definiciones provisionales.

**ENAPRES, población urbana de 15 años y más.**

| Año | Víctima (lista común) | Víctima (lista completa) | Robo/intento dinero | Robo vehículo/moto | Amenazas | Extorsión | Estafa | Robo negocio | Ofensas sexuales | Arma de fuego | Denunció (víctimas) | Percepción | N personas |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2014 | 30.5 | 30.5 | 20.4 | 0.5 | 2.5 | 0.2 | 7.0 | 0.8 | 0.4 | 2.6 | 13.8 | 85.8 | 73902 |
| 2015 | 30.8 | 30.8 | 19.7 | 0.4 | 1.9 | 0.3 | 9.0 | 0.7 | 0.6 | 2.5 | 14.0 | 88.4 | 65550 |
| 2016 | 28.6 | 31.2 | 17.9 | 0.4 | 1.9 | 0.3 | 7.6 | 0.7 | 0.6 | 2.5 | 12.1 | 89.5 | 71880 |
| 2017 | 26.1 | 28.6 | 17.1 | 0.4 | 2.1 | 0.4 | 5.2 | 0.7 | 0.7 | 2.4 | 12.6 | 86.4 | 66561 |
| 2018 | 25.4 | 27.1 | 16.5 | 0.4 | 2.0 | 0.2 | 5.2 | 0.6 | 0.8 | 2.3 | 14.5 | 85.7 | 71769 |
| 2019 | 26.3 | 27.3 | 18.0 | 0.4 | 2.1 | 0.2 | 4.3 | 0.5 | 1.2 | 3.0 | 15.1 | 85.1 | 67296 |
| 2020 | 23.0 | 23.6 | 16.3 | 0.3 | 1.7 | 0.1 | 3.1 | 0.4 | 1.1 | 2.9 | 16.2 | 82.5 | 48783 |
| 2021 | 18.0 | 18.4 | 11.2 | 0.2 | 1.6 | 0.1 | 2.8 | 0.4 | 0.9 | 2.3 | 14.1 | 83.0 | 68041 |
| 2022 | 22.7 | 23.1 | 14.6 | 0.3 | 1.7 | 0.1 | 4.2 | 0.5 | 1.2 | 2.6 | 14.0 | 84.6 | 68594 |
| 2023 | 25.6 | 27.3 | 16.3 | 0.3 | 2.1 | 0.2 | 5.0 | 1.0 | 1.7 | 3.4 | 14.8 | 82.8 | 69506 |
| 2024 | 24.5 | 26.7 | 15.4 | 0.4 | 1.7 | 0.2 | 3.8 | 1.6 | 1.2 | 2.7 | 15.1 | 85.2 | 67821 |
| 2025 | 23.4 | 24.9 | 15.4 | 0.5 | 2.0 | 0.5 | 2.0 | 1.5 | 1.0 | 2.8 | 19.4 | 72.9 | 66216 |

Cómo se calculó cada columna:

- **Lista común:** solo los tipos que existen los 12 años; excluye el intento de
  extorsión y los delitos informáticos. **Lista completa:** todos los tipos del año,
  menos vandalismo.
- **Arma de fuego:** como porcentaje de toda la población (no solo de las víctimas).
- **Denunció:** sobre las víctimas (lista completa).
- **Percepción:** en 2024 usa la submuestra; en 2025 usa `P401`.
- **Robo de vehículo:** robo consumado de vehículo automotor o de moto/mototaxi,
  sobre toda la población.

**Hogares y opinión**

| Año | Robo o intento en vivienda (ENAPRES, urbano) | N hogares ENAPRES | Hogar afectado por hecho delictivo (ENAHO) | N hogares ENAHO | Delincuencia: problema principal | Falta de seguridad: problema principal | Alguno de los dos | Alguno como el más importante | Confía en la PNP (suficiente o bastante) | N opinión |
|---|---|---|---|---|---|---|---|---|---|---|
| 2014 | 12.3 | 27421 | 3.8 | 28826 | 42.6 | 24.1 | 56.8 | 33.3 | 18.0 | 27816 |
| 2015 | 11.6 | 27004 | 3.4 | 30416 | 46.6 | 24.5 | 60.4 | 34.6 | 19.3 | 29385 |
| 2016 | 10.7 | 27373 | 4.0 | 33345 | 48.5 | 24.7 | 63.8 | 38.7 | 18.0 | 31839 |
| 2017 | 10.5 | 27249 | 3.5 | 31870 | 44.4 | 17.3 | 54.9 | 30.3 | 18.7 | 30245 |
| 2018 | 9.5 | 27407 | 2.7 | 33942 | 40.5 | 16.4 | 51.0 | 22.4 | 17.2 | 32089 |
| 2019 | 9.4 | 27269 | 2.8 | 31805 | 41.5 | 15.8 | 50.8 | 22.2 | 18.8 | 30257 |
| 2020 | 10.4 | 27154 | 2.9 | 16475 | 27.1 | 9.1 | 33.4 | 12.7 | 28.2 | 32447 |
| 2021 | 8.7 | 27116 | 2.2 | 31075 | 28.8 | 8.6 | 34.5 | 12.1 | 24.6 | 31596 |
| 2022 | 10.1 | 26676 | 2.9 | 32368 | 31.9 | 11.8 | 39.2 | 15.1 | 21.2 | 31226 |
| 2023 | 12.8 | 26958 | 3.4 | 31943 | 35.4 | 13.4 | 43.6 | 20.8 | 20.5 | 30940 |
| 2024 | 10.8 | 26593 | 2.9 | 30774 | 42.1 | 17.2 | 52.5 | 27.9 | 17.6 | 29546 |
| 2025 | 8.8 | 25979 | 2.4 | 31261 | 53.2 | 21.2 | 63.4 | 35.9 | 13.4 | 30748 |

Lo que se ve en estas tablas:

- **Victimización en la ENAPRES:** la lista común da 30,5 % en 2014 y 30,8 % en
  2015, del orden de lo que publica el INEI. La verificación formal contra las
  cifras publicadas se hace en la fase 2.
- **ENAHO frente a ENAPRES:** el hogar afectado de la ENAHO (2–4 %) es mucho menor
  que la victimización de la ENAPRES (18–31 %). Son preguntas distintas:
  - la ENAHO pregunta por un choque que afectó al hogar, dentro de una lista de
    choques económicos;
  - la ENAPRES pregunta a cada persona, tipo por tipo.
- **Estafa en 2025:** baja de 3,8 % a 2,0 %. Coincide con los nuevos tipos
  informáticos y la desaparición de "estafas por medios tecnológicos"; no es
  comparable sin cuidado.

**Distrito-año con cero casos** (`inventario/ceros_distrito_anio.csv`). Es el
porcentaje de distrito-año sin ningún caso en la muestra:

| Fuente | Indicador | Rango 2014–2025 | Mediana | Distritos con oro: rango | 2020 |
|---|---|---|---|---|---|
| ENAPRES | Víctima (lista común) | 1.8–9.7 | 3.7 | 0.0–15.3 | 9.6 |
| ENAPRES | Víctima (lista completa) | 1.7–9.5 | 3.7 | 0.0–13.9 | 9.5 |
| ENAPRES | Robo/intento de dinero | 6.5–20.3 | 11.1 | 5.9–26.4 | 17.4 |
| ENAPRES | Estafa | 26.0–49.0 | 34.1 | 25.0–45.5 | 49.0 |
| ENAPRES | Amenazas | 32.9–55.3 | 45.4 | 32.4–54.2 | 55.3 |
| ENAPRES | Arma de fuego | 52.3–63.6 | 58.1 | 49.3–71.4 | 62.9 |
| ENAPRES | Robo de negocio | 50.6–77.1 | 66.0 | 45.5–76.4 | 75.0 |
| ENAPRES | Ofensas sexuales | 64.9–76.7 | 71.5 | 70.1–85.9 | 74.6 |
| ENAPRES | Robo de vehículo/moto | 72.2–85.2 | 80.2 | 70.6–88.3 | 85.0 |
| ENAPRES | Extorsión | 78.9–92.7 | 85.4 | 77.5–94.8 | 91.1 |
| ENAPRES hogares | Robo/intento de vivienda | 20.5–31.8 | 24.7 | 21.1–35.1 | 27.6 |
| ENAHO hogares | Hogar afectado por hecho delictivo | 61.1–74.9 | 69.5 | 61.2–77.1 | 74.1 |

Lo que implica para cada indicador:

- **Víctima de cualquier delito y robo de dinero:** tienen variación distrital
  útil.
- **Extorsión, robo de vehículo, ofensas sexuales, robo de negocio y arma de
  fuego:** son mayoritariamente cero a nivel distrito-año, así que la tasa
  distrital es casi binaria y muy ruidosa.
- **Hogar afectado de la ENAHO:** es cero en el 61–75 % de los distrito-año.

## 7. Decisiones que necesito que apruebes

Para cada una propongo una opción (**Propuesta**), con alternativas.

**D1. Definición de "víctima de algún delito" (ENAPRES).**

- **Propuesta:** construir dos variables:
  - `victima_comun`: solo los tipos presentes los 12 años, para la serie
    comparable;
  - `victima_completa`: todos los tipos de cada año, comparable con el INEI de cada
    año.
- En ambas se excluye vandalismo de 2024, porque pregunta por "víctima o testigo".
- Las dos difieren en 1–2 puntos desde 2016.
- ¿Usamos `victima_comun` como principal?

**D2. Edad.**

- **Propuesta:** 15 años y más en todos los años, como el INEI y como la ENAPRES
  2025.
- Se descarta el grupo de 14 años de 2014–2024.

**D3. Robo de dinero, cartera o celular.**

- **Propuesta:** robo **o** intento de robo, que es el indicador estándar del INEI.
- Alternativa: solo el robo consumado.

**D4. Robo de vehículo.**

- **Propuesta:** robo consumado de vehículo automotor **o** de motocicleta o
  mototaxi, sin intentos, autopartes ni bicicleta. Denominador: toda la población
  urbana de 15 años y más ("no tiene" = 0).
- Alternativas:
  - incluir intentos y autopartes;
  - usar como denominador solo a quienes tienen vehículo. No es posible con
    precisión, porque "no tiene" se marca por ítem.
- Es muy ralo: 0,2–0,5 % nacional y 72–85 % de distrito-año con cero.

**D5. Extorsión.**

- **Propuesta:** solo la extorsión consumada, que es la serie comparable 2014–2025.
- Se reporta aparte "extorsión o intento" desde 2016.

**D6. Percepción de inseguridad (cambio en 2024–2025).**

- **Propuesta:**
  - **2014–2023:** "Sí" en al menos un ítem (`P611_k`), con el factor principal.
  - **2024:** igual con `P601_k`, en la submuestra, con `FACTOR_CAP600B`.
  - **2025:** "Sí" en al menos un `P402_k`, con `FACTOR_CAP400`. Da 83,4 %,
    comparable con la serie.
  - Se guarda además `P401` como variable aparte (72,9 %), sin mezclarla con la
    serie.
- En 2024–2025 solo hay unas 15 personas por distrito en la mediana.
- ¿Aceptas usar `P402` en 2025 y marcar 2024–2025 como submuestra?

**D7. Denuncia.**

- **Propuesta:** entre las víctimas (lista completa), haber denunciado al menos uno
  de los hechos sufridos.
- Alternativa: denunció el hecho más reciente o un tipo específico; la ENAPRES no
  identifica un "hecho principal".

**D8. Arma de fuego.**

- **Propuesta:** el universo es toda la población (es "víctima de un delito con
  arma de fuego", 2,3–3,4 %); se marca si en algún tipo de delito sufrido se usó un
  arma de fuego de mano o larga.
- Alternativa: como porcentaje de las víctimas (unos 8–13 %).
- Los delitos informáticos (2023–2025) y la estafa en 2025 no tienen pregunta de
  arma.

**D9. Entrevistas incompletas y factor.**

- **Propuesta:** incluir a toda persona con respuesta a la victimización y con
  factor > 0, sin filtrar por `RESFIN`.
- Las que no tienen factor se excluyen, como hace el INEI.

**D10. Llave del hogar en la ENAPRES (capítulo 100).**

- **Propuesta:** usar `CONGLOMERADO` + `NSELV` + `VIVIENDA` + `HOGAR`.
- Se verifica que sea única en la fase 2; si no lo es, te consulto.

**D11. Cobertura solo urbana de la ENAPRES.**

- La ENAPRES cubre solo 92 de los 276 distritos con oro, y solo su población urbana
  (sección 5).
- **Propuesta:** mantener todos los indicadores solicitados de la ENAPRES con esa
  advertencia explícita en el diccionario. No se imputa lo rural.
- La ENAHO (`p40_5`) es el único indicador de victimización con cobertura rural.

**D12. Hogar afectado por hecho delictivo (ENAHO).**

- **Propuesta:** 1 si `p40_5` = 1 y 0 si `p40_5` = 0.
- Queda faltante cuando no hay dato, que en 2020–2021 es el cuestionario
  telefónico reducido. No se imputa.
- En 2020 quedan sobre todo los hogares de enero–marzo y octubre–diciembre (16.475;
  878 distritos).
- ¿Aceptas tratar 2020 como año con muestra reducida, marcado en la base?

**D13. Opinión (ENAHO).**

- **Propuesta:** tres variables por persona:
  - `delincuencia_problema` (`p2_1_15` = 15);
  - `inseguridad_problema` (delincuencia **o** falta de seguridad ciudadana,
    `p2_1_15` = 15 o `p2_1_04` = 4);
  - `confia_pnp` (`p1_06` en 3 Suficiente o 4 Bastante). En `confia_pnp`, "No
    sabe" (5) cuenta en el denominador como "no confía", como en los reportes de
    gobernabilidad del INEI.
- Alternativas:
  - solo "delincuencia";
  - solo el problema **más importante** (`p2_2_*` = 1);
  - excluir "No sabe" del denominador.

**D14. Factor de opinión.**

- **Propuesta:** `facgob07` (2014) y `famiegob07` (2015–2025) en todos los años.
- Se excluyen las filas sin respuesta y sin factor (unas 2–3 mil por año).
- En 2020–2021 existe además `facgob_p`, que solo tienen 16 mil filas en 2020. Se
  documenta, pero no se usa salvo que lo prefieras.

**D15. Factores 2020–2021 de la ENAPRES.**

- **Propuesta:** usar `FACTOR` (todas las entrevistas, presenciales y telefónicas),
  no `FACTOR_CALIBRADO` (solo presenciales). La diferencia nacional es de 0,1–0,3
  puntos.
- Se agrega a la base una marca de modalidad (`MOD_ENC`).

**D16. Agregación distrito-año (para la fase 2).**

- **Propuesta:** proporción ponderada por distrito (`ubigeo_base`) y año, más
  observaciones sin ponderar (n) y suma de factores.
- No se suaviza ni se usan estimadores de áreas pequeñas; eso sería "otro
  indicador".
- ¿Agrego un umbral mínimo de observaciones o solo reporto n?

## 8. Archivos de esta fase

| Archivo | Contenido |
|---|---|
| `01_descarga.R` | Descarga y registro (URL, fecha, bytes, MD5) |
| `02_extraer.R` | Extrae los zip a `cache/` (sin tocar los originales) |
| `datos_brutos/registro_descargas.csv` | Registro de las 48 descargas |
| `inventario/01_metadatos.R` → `variables_por_anio.csv` | Variables, etiquetas y valores de todos los archivos |
| `inventario/02_mapa_enapres.R` → `mapa_enapres_variables.csv` | Variable por tipo de delito, pregunta y año, según la etiqueta |
| `inventario/tipos_delito_enapres.csv` | Correspondencia de los ítems por tipo de delito, 2014–2023, 2024 y 2025 |
| `inventario/03_perfil_enapres.R` → `perfil_enapres.csv` | Área, edades, `RESFIN`, factores y ubicación por año |
| `inventario/04_cobertura_prevalencia.R` | Escribe `prevalencia_nacional.csv`, `cobertura_anual.csv`, `presencia_distritos_oro.csv`, `ceros_distrito_anio.csv`, `modalidad_2020_2022.csv` y `ubigeos_sin_correspondencia.csv` |
| `inventario/05_disponibilidad.R` → `disponibilidad.csv` | Disponibilidad por indicador y año, con comprobación de existencia |

Para reproducir, desde la raíz del repositorio:

```
Rscript delincuencia/01_descarga.R
Rscript delincuencia/02_extraer.R
Rscript delincuencia/inventario/01_metadatos.R
Rscript delincuencia/inventario/02_mapa_enapres.R
Rscript delincuencia/inventario/03_perfil_enapres.R
Rscript delincuencia/inventario/04_cobertura_prevalencia.R
Rscript delincuencia/inventario/05_disponibilidad.R
```
