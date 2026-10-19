# Diccionario de datos: outcomes ENAHO 2014–2025

Bases construidas a partir de la ENAHO del INEI (metodología actualizada, anual),
2014–2025. El detalle de las fuentes, la disponibilidad de variables por año y las
particularidades de cada año está en [`inventario.md`](inventario.md).

## Cómo reproducir

```
Rscript enaho/ejecutar_todo.R
```

| Script | Qué hace |
|---|---|
| `01_descarga.R` | Descarga los módulos 01, 02, 04, 05 y 34 de 2014–2025 en `datos_brutos/` (omite los que ya existen) |
| `02_extraer.R` | Extrae los zips en `cache/` sin modificar los originales |
| `03_hogares.R` | Base de hogares: gasto e ingreso real per cápita |
| `04_personas.R` | Base de personas: mercado laboral, ingreso laboral, horas, rama, categoría, informalidad; validación de la informalidad |
| `05_geografia.R` | `ubigeo_base` y tabla de correspondencia; escribe las bases finales de hogares y personas |
| `06_agregado_distrital.R` | Base distrito-año |
| `07_verificacion.R` | Comparación con cifras oficiales del INEI |

`funciones.R` contiene las funciones comunes, incluida la clasificación de
informalidad. Paquetes de R: `haven`, `dplyr`, `tidyr`, `readr`, `sf` y `arrow`.

## Bases producidas (`enaho/datos_procesados/`)

| Archivo | Unidad | Filas | Universo |
|---|---|---|---|
| `hogares.{parquet,csv}` | Hogar × año | 409 659 | Todos los hogares de la sumaria |
| `personas.{parquet,csv}` | Persona × año | 1 060 784 | Residentes habituales de 14 años o más (módulo 05) |
| `distrito_anio.{parquet,csv}` | `ubigeo_base` × año | 14 800 | Distritos con al menos un hogar o persona en la muestra |
| `validacion_informalidad.csv` | Año | 10 | Informalidad reconstruida frente a la oficial, 2014–2023 |
| `verificacion_oficial.csv` | Indicador × año | — | Comparación con cifras publicadas por el INEI |

En el repositorio se versionan los `.parquet`, la base distrito-año en `.csv` y las
tablas de validación. `hogares.csv` (77 MB) y `personas.csv` (190 MB) superan el
límite de tamaño de GitHub: se generan localmente al correr los scripts.

---

## Convenciones generales

- **Año base de los valores reales.** Soles de 2025 a precios de Lima
  Metropolitana. Se usan los deflactores que el INEI publica con la sumaria 2025
  (`deflactores_base2025_new.dta`, índices temporales por departamento y año, que
  valen 1 en 2025) y el deflactor espacial `despacial_ldnew.dta` (17 dominios, Lima
  Metropolitana = 1).
- **Deflactores de cada registro.**
  - `i00` (índice general del año y departamento; Callao usa el de Lima) y `ld`
    (dominio geográfico).
  - El dominio se arma como en el do-file del INEI: `dominio` × área, y la selva se
    separa en alta y baja según el departamento.
- **Área.** Urbana si `estrato` es de 1 a 5 y rural si es de 6 a 8; Lima
  Metropolitana (`dominio` 8) siempre es urbana.
- **Identificadores.**
  - `conglome` (6 dígitos; en 2014 tiene 4 y se completa con ceros, como indica el
    INEI), `vivienda` (3), `hogar` (2), `codperso` (2).
  - `ubigeo` (6 dígitos) es texto con ceros a la izquierda.
- **Factores de expansión.**
  - `factor07` para hogares; `factor_pob = factor07 × mieperho` para promedios per
    cápita (convención del INEI);
  - `fac500a` para personas.
  - Son la serie anual del INEI, consistente en todo el periodo (proyecciones CPV
    2007). No se usan los factores "presenciales" de 2020–2021.
- **Universo de personas.** Residentes habituales, según la definición del INEI:
  `(p204 == 1 & p205 == 2) | (p204 == 2 & p206 == 1)`.
- **Proporciones.** Los indicadores binarios valen 0/1 en las bases de hogares y
  personas. En la base distrito-año son proporciones de 0 a 1, no porcentajes.
- **2020–2021.** `tipoentrevista` (solo 2020: 1 presencial, 2 telefónica),
  `tipocuestionario` y `cuestionario_reducido` (1 = cuestionario reducido de la
  emergencia sanitaria) permiten identificar las entrevistas afectadas. En la base
  distrito-año, `prop_hogares_cuestionario_reducido` resume esa información.

---

## 1. Gasto

### `gasto_real_pc`: gasto real per cápita mensual del hogar
**Base:** hogares (y promedio en distrito-año).

`gasto_real_pc = gashog2d / (12 × mieperho × ld × i00)`

| Variable | Origen | 2014–2025 |
|---|---|---|
| `gashog2d` | Sumaria: gasto total bruto del hogar, anual, nominal | Mismo nombre y definición |
| `mieperho` | Sumaria: total de miembros del hogar | Mismo nombre y definición |
| `i00`, `ld` | Deflactores de la edición 2025 | — |

**Decisiones:**
- **Un solo deflactor, como se pidió.** El INEI deflacta cada grupo de gasto con su
  índice (`i01`–`i08`). La versión con `i00` difiere del método del INEI en el
  promedio nacional entre −0.3 % y +1.1 % (máximo en 2022, por la inflación dispar
  entre grupos). Ver `inventario/verif_gasto_ingreso.csv`.
- **Promedio distrital** ponderado por `factor_pob`.

## 2. Ingreso

### `ingreso_real_pc`: ingreso real per cápita mensual del hogar
**Base:** hogares (y promedio en distrito-año).

`ingreso_real_pc = inghog1d / (12 × mieperho × ld × i00)`

| Variable | Origen | 2014–2025 |
|---|---|---|
| `inghog1d` | Sumaria: ingreso bruto del hogar, anual, nominal | Mismo nombre y definición (en 2020 la etiqueta dice "ingreso bruto total") |

**Decisiones:**
- **Ingreso bruto, no neto** (aprobado). Coincide exactamente con la serie oficial
  del INEI (`ipcr_0` de su do-file) en los 12 años.
- **Promedio distrital** ponderado por `factor_pob`.

### `ingreso_laboral_real`: ingreso laboral mensual del trabajador
**Base:** personas (ocupados).

`ingreso_laboral_nominal = (i524a1 + d529t + i530a + d536 + i538a1 + d540t + i541a + d543 + d544t + i538a_1 + d538a_2) / 12`

`ingreso_laboral_real = ingreso_laboral_nominal / (ld × i00)`

| Componente | Ocupación principal | Ocupación secundaria |
|---|---|---|
| Dependiente, monetario (imputado) | `i524a1` | `i538a1` |
| Dependiente, en especie | `d529t` | `d540t` |
| Independiente, ganancia neta (imputada) | `i530a` | `i541a` |
| Independiente, autoconsumo | `d536` | `d543` |
| Ingresos extraordinarios por trabajo | `d544t` | |
| Cuestionario reducido 2020–2021: monetario (imputado) y en especie | | `i538a_1`, `d538a_2` |

**Variables de origen por año:**
- Las 9 variables del cuestionario completo existen los 12 años.
- `i538a_1` y `d538a_2` solo existen en 2020–2021. Se llenan solo para el
  cuestionario reducido, que no tiene las partidas de la secundaria.
- **Cambio de etiqueta en 2022:** las variables `i` dicen "imputado, deflactado" hasta
  2021 y "imputado" desde 2022. Se verificó que el significado no cambió: `i = d`
  donde hay dato deflactado, en el 100 % de los casos de los 12 años.

**Decisiones:**
- **Variables imputadas cuando existen** (`i`); las de especie y extraordinarios solo
  existen deflactadas (`d`). Los componentes faltantes cuentan como 0.
- **Escala de los montos de 2020.** El INEI etiqueta `i538a_1` como "mensualizado" en
  2020, pero es anual: su relación con el monto de campo es 12, igual que en 2021. Se
  divide entre 12 como los demás.
- **Doble deflactación.** Las variables `d`/`i` están deflactadas solo dentro del
  año (a precios promedio del año). Para hacerlas comparables entre años y regiones
  se deflactan además con `i00` y `ld`, igual que el ingreso del hogar (decisión 3
  del inventario).
- **TFNR = `NA`.** Para los trabajadores familiares no remunerados el ingreso queda
  `NA`, porque por definición no perciben ingreso laboral; es la convención del INEI.
  Otros 2 146 ocupados tienen ingreso 0 y se mantienen así.
- **Incluye ocupación principal y secundaria**, monetario y en especie, más los
  ingresos extraordinarios por trabajo (como en la serie del INEI).
- **Sin recorte de valores extremos.**
- **Promedio distrital** ponderado por `fac500a` sobre los ocupados con ingreso
  (`n_ocupados_con_ingreso`).

### `ingreso_hora_real`: ingreso laboral real por hora
**Base:** personas (ocupados con ingreso y horas > 0).

`ingreso_hora_real = ingreso_laboral_real / (horas_total × 52 / 12)`

**Decisiones:**
- **Horas totales** (principal + secundaria), porque el ingreso también incluye ambas
  ocupaciones.
- **Horas = 0** (10 914 ocupados ausentes temporalmente) → `NA`.

## 3. Informalidad laboral (ocupados, ocupación principal)

| Variable | Definición | Origen |
|---|---|---|
| `empleo_informal` | 1 = empleo informal | Reconstruida con los criterios del INEI, 2014–2025 |
| `empleo_sector_informal` | 1 = empleo informal en el sector informal | Reconstruida, 2014–2025 |
| `afiliado_pension` | 1 = afiliado a AFP, ONP (19990), 20530 u otro sistema | `p558a1`–`p558a4` (módulo 05), 2014–2025 |
| `seguro_salud_empleo` | 1 = algún seguro de salud cuyas cuotas aporta su centro de trabajo | `p419a1`–`p419a8` = 1 (módulo 04), 2014–2025 |
| `empleo_informal_oficial` | `ocupinf == 1` | Variable del INEI, solo 2014–2023 |
| `empleo_sector_informal_oficial` | `emplpsec == 1` (0 para el resto de ocupados) | Variable del INEI, solo 2014–2023 |

**Por qué se reconstruyó.** El INEI dejó de publicar `ocupinf` y `emplpsec` en 2024
y 2025. Para tener una serie consistente se reconstruyeron para los 12 años. La
función `clasificar_informalidad()` de `funciones.R` sigue el procedimiento del INEI
para la ENAHO desde 2012 (*Producción y empleo informal en el Perú*, Anexo B3,
figuras B3.2–B3.5):

1. **Unidades de los hogares productores de mercado.**
   - Se excluyen las sociedades (FFAA, sector público, cooperativas, services y
     personas jurídicas).
   - Se excluyen las cuasisociedades: más de 30 trabajadores, según `p512b`.
   - Las unidades agropecuarias quedan como hogares (CIIU rev. 3 `p506`, divisiones
     01, 02 y 05).
2. **Sector informal.** Unidades de hogares no registradas en SUNAT
   (`p510a1 == 3`) o agropecuarias.
3. **Empleo informal.** Todo el empleo del sector informal, los TFNR y "otro", y los
   asalariados (empleados, obreros y trabajadores del hogar) cuyo seguro de salud no
   es aportado por su centro de trabajo.
4. **Dos precisiones de la validación**, que no figuran en los diagramas:
   - TFNR y "otro" están en el sector informal si la unidad no está registrada o
     tiene hasta 5 trabajadores;
   - el empleo en el sector informal se define, como `emplpsec`, solo para el empleo
     informal.

**Validación** (`validacion_informalidad.csv`, ocupados 2014–2023):

| | Coincidencia individual | Diferencia en la tasa nacional |
|---|---|---|
| Empleo informal | 99.95 %–99.98 % | ≤ 0.04 puntos |
| Empleo en el sector informal | 99.83 %–99.93 % | ≤ 0.17 puntos |

**Decisión.** Las variables principales son las reconstruidas, para tener una sola
definición en todo el periodo. Las oficiales se conservan para comparar.

## 4. Mercado laboral (población de 14 años o más)

| Variable | Definición | Origen (2014–2025, mismo nombre y codificación) |
|---|---|---|
| `condicion_actividad` | 1 ocupado, 2 desocupado abierto, 3 desocupado oculto, 4 no PEA | `ocu500` |
| `pea` | 1 = ocupado o desocupado abierto | `ocu500` en 1–2 |
| `ocupado` | 1 = ocupado | `ocu500 == 1` |
| `horas_principal` | Horas trabajadas la semana pasada en la ocupación principal | `i513t` (imputada) |
| `horas_total` | Horas en la ocupación principal y las secundarias | `i513t + i518` (`i518` faltante = 0) |
| `ciiu4` | Rama de la ocupación principal, CIIU rev. 4, 4 dígitos con cero inicial | `p506r4` |
| `ciiu4_division`, `ciiu4_seccion` | División (2 dígitos) y sección (A–U) | Derivadas de `p506r4` |
| `mineria_metalifera` | 1 = división 07, extracción de minerales metalíferos | `p506r4` 0710–0729 |
| `categoria_ocupacional` | empleador; asalariado (empleado, obrero, trabajador del hogar); independiente; trabajador familiar no remunerado; otro | `p507` |

**Decisiones:**
- **PEA = ocupados + desocupados abiertos.** Es la definición oficial del INEI: los
  desocupados ocultos se consideran inactivos. Con ella, la tasa de actividad queda a
  0.1–0.2 puntos de la oficial. Incluir a los ocultos la llevaría 0.8 puntos por
  encima. `condicion_actividad` conserva el código original para otras definiciones.
- **Tasa de ocupación** = ocupados / población de 14 años o más.
- **Horas imputadas** (`i513t`, `i518`) de la semana pasada. No se usa `p520`
  (horas habituales), que es otro concepto y solo se pregunta a una parte de los
  ocupados.
- **Rama con la CIIU rev. 4**, completa los 12 años para todos los ocupados.
- **Empleador como categoría propia** (aprobado).
- **Promedios distritales** con `fac500a`:
  - las tasas, sobre la población de 14 años o más;
  - las horas, la rama, la categoría y la informalidad, sobre los ocupados.

## 5. Geografía

| Variable | Definición |
|---|---|
| `ubigeo` | Ubigeo original de la ENAHO en cada año |
| `ubigeo_base` | Distrito de la división de 2014 al que se asigna el registro |

La tabla de correspondencia es `geografia/correspondencia_ubigeo.csv`: 1 638 códigos,
36 reasignados, con el método y la fuente de cada uno.

- **Base.** Los 1 834 distritos de `datos/insumos/peru_distrital_simple.geojson`.
  Todos los códigos de la ENAHO 2014 existen en esa capa, salvo 120699.
- **Distritos creados después.** Se asignan al distrito de 2014 que contiene la
  coordenada de su capital. Si cae en otro departamento por la simplificación de
  límites, se asigna al distrito más cercano del mismo departamento (es el caso de
  Villa Kintiarina → Kimbiri).
- **Casos manuales** (`geografia/correspondencia_manual.csv`):
  - Kumpirushiato → Echarate (Ley 31142);
  - Santa Lucía → Uchiza (Ley 31128, 21 % del territorio de Uchiza);
  - la unión de Mazamari (120604), Pangoa (120606) y el código de la ENAHO
    "Mazamari-Pangoa" (120699) en una sola unidad, `120699` (decisión 10). Vizcatán
    del Ene (120609), creado de Pangoa, también queda en esa unidad.
- **Aplicación.** La correspondencia se aplica también a los códigos de
  `datos/oro_por_distrito_pre2014.csv`, para poder cruzar ambas bases por
  `ubigeo_base`.
- **Limitación.** Cuando un distrito nuevo se formó con territorio de varios
  distritos, se asigna completo al que contiene su capital. Las leyes de creación se
  verificaron para Villa Virgen, Villa Kintiarina, Kumpirushiato y Santa Lucía; para
  los demás la asignación es espacial.

## 6. Base distrito-año (`distrito_anio`)

Una fila por `ubigeo_base` y año.

**Promedios ponderados:**
- **Hogares:** `gasto_real_pc` e `ingreso_real_pc`, ponderados por `factor_pob`.
- **Personas:**
  - `tasa_actividad`, `tasa_ocupacion`;
  - `horas_principal`, `horas_total`, `ingreso_laboral_real`, `ingreso_hora_real`;
  - `empleo_informal`, `empleo_sector_informal`, `afiliado_pension`,
    `seguro_salud_empleo` y sus versiones `_oficial`;
  - `mineria_metalifera`;
  - `cat_*` (proporción de ocupados en cada categoría);
  - `rama_A` … `rama_U` (proporción de ocupados en cada sección de la CIIU rev. 4).

**Observaciones que sustentan cada promedio:**
- `n_hogares`, `n_personas_hogares` (suma de `mieperho`);
- `n_pet` (personas de 14 años o más);
- `n_ocupados`, `n_ocupados_con_ingreso`, `n_ocupados_con_horas`;
- `n_ocupados_mineria_metalifera`.

**Indicador de 2020–2021:** `prop_hogares_cuestionario_reducido`.

Los promedios distritales provienen de muestras pequeñas (la mediana es de 14
hogares por distrito y año). La ENAHO no es representativa a nivel distrital: estos
promedios son estimaciones con alto error muestral y deben usarse con los conteos
de observaciones.

## 7. Verificación contra cifras oficiales del INEI

Archivo `verificacion_oficial.csv`, generado por `07_verificacion.R`:

| Indicador | Años | Cifra oficial | Construido | Diferencia |
|---|---|---|---|---|
| Gasto real per cápita (S/ de 2025) | 2024 / 2025 | 903 / 920 | 903.9 / 920.4 | +0.1 % / +0.05 % (con el método por grupos del INEI: −0.04 % / +0.05 %) |
| Tasa de empleo informal (%) | 2014–2018 | 72.8 / 73.2 / 72.0 / 72.5 / 72.4 | 72.80 / 73.13 / 71.94 / 72.52 / 72.43 | ≤ 0.07 puntos |
| Tasa de actividad (%) | 2014–2018 | 72.3 / 71.6 / 72.2 / 72.4 / 72.3 | 72.21 / 71.45 / 72.01 / 72.32 / 72.22 | −0.08 a −0.19 puntos |
| Ingreso laboral promedio, nominal (S/) | 2014–2018 | 1 239.9 / 1 304.9 / 1 370.7 / 1 376.8 / 1 400.1 | 1 235.8 / 1 301.4 / 1 366.7 / 1 372.6 / 1 396.5 | −0.26 % a −0.33 % |

**Fuentes:**
- Gasto real per cápita: INEI, *Perú: Evolución de la pobreza monetaria 2016–2025*
  (nota de prensa del 5/5/2026).
- Informalidad, actividad e ingreso laboral: INEI, *Perú: Evolución de los
  indicadores de empleo e ingreso por departamento, 2007–2018* (ENAHO), cuadros 7.4,
  1.27 y 10.1.

**Diferencias que no pude explicar:**
- **Tasa de actividad**, entre 0.1 y 0.2 puntos por debajo. No se explica por el
  filtro de residentes: sin él, la diferencia aumenta.
- **Ingreso laboral nominal**, 0.3 % por debajo. Puede deberse a diferencias en el
  tratamiento de casos sin ingreso o en los componentes incluidos.

**Cifras sin contraste:**
- No encontré cifras oficiales de la ENAHO de informalidad, actividad e ingreso
  laboral posteriores a 2018. Desde 2023, el INEI publica esos indicadores con la
  EPEN, una encuesta distinta. Para 2019–2023, la informalidad se comparó con la
  variable oficial de los microdatos.
- El ingreso real per cápita del hogar coincide por construcción con la serie del
  INEI (ver la sección 2).
