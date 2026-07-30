# Catálogo de fuentes de datos

Estado de verificación: las URLs fueron confirmadas por búsqueda web en julio 2026. Los
**esquemas de campos marcados con ⚠️ no pudieron verificarse empíricamente** porque la
política de red del entorno de desarrollo bloquea `sunat.gob.pe`. Deben confirmarse
ejecutando `R/01_download_sunat.R` en una máquina con acceso abierto.

---

## 1. Variable dependiente principal — creación de empresas

### 1.1 SUNAT — Padrón Reducido del RUC ⭐ fuente central

- **Qué es:** listado censal de contribuyentes con RUC.
- **Nivel:** microdato por empresa, con **ubigeo distrital**.
- **Campos reportados:** RUC, razón social, estado del contribuyente (activo/baja/
  suspendido), condición de domicilio (habido/no habido/no hallado), tipo de contribuyente,
  ubigeo, dirección fiscal, CIIU principal.
- **⚠️ A verificar:** presencia de `fecha de inscripción` o `fecha de inicio de
  actividades`. **Este campo determina la viabilidad del panel retrospectivo.**
- **Formato:** `.zip` con archivo de texto delimitado.
- **Acceso:** libre, sin solicitud.
- **URLs:**
  - https://orientacion.sunat.gob.pe/padron-reducido-del-ruc
  - https://orientacion.sunat.gob.pe/padron-reducido-del-ruc-para-descarga
  - https://www.sunat.gob.pe/descargaPRR/mrc137_padron_reducido.html
  - Espejo en datos abiertos: https://www.datosabiertos.gob.pe/dataset/padr%C3%B3n-ruc-superintendencia-nacional-de-aduanas-y-de-administraci%C3%B3n-tributaria-sunat

**Estrategia según el resultado de la verificación:**

| Escenario | Estrategia de panel |
|---|---|
| Trae fecha de inscripción | Cohortes de nacimiento retrospectivas desde un snapshot. Cuantificar sesgo de supervivencia contra INEI. |
| No trae fecha | Acumular snapshots mensuales hacia adelante; recuperar snapshots pasados vía Internet Archive (`web.archive.org`). |

### 1.2 SUNAT — Padrón de locales anexos

Corrige parcialmente el sesgo de domicilio fiscal vs. ubicación operativa. Mismo portal de
descarga, archivo separado.

### 1.3 PRODUCE — Directorio de Empresas MIPYME (OGEIEE)

- **Qué aporta:** la variable **tamaño**, que el padrón SUNAT no tiene.
- **Campos:** razón social, CIIU (rev. 3), departamento, provincia, **distrito**, monto de
  ventas anuales, años de experiencia, número de trabajadores.
- **Cruce:** por RUC contra el padrón SUNAT.
- **URLs:**
  - https://ogeiee.produce.gob.pe/index.php/en/shortcode/estadistica-oee/estadisticas-mipyme
  - https://www.datosabiertos.gob.pe/dataset/directorio-de-empresas-mipyme-por-sector-productivo-ministerio-de-la-producci%C3%B3n-produce

### 1.4 INEI — Demografía Empresarial (validación externa)

- **Rol:** *benchmark*. Serie trimestral oficial de altas y bajas de empresas.
- **Nivel:** departamental (no distrital) — por eso es validación, no fuente principal.
- **URLs:**
  - https://www.gob.pe/institucion/inei/colecciones/6116-demografia-empresarial
  - https://www.gob.pe/institucion/inei/informes-publicaciones/6853577-demografia-empresarial-en-el-peru-i-trimestre-2025

### 1.5 INEI — Estructura Empresarial

Stock anual de empresas. Las ediciones **regionales** sí bajan a nivel distrital.

- https://www.gob.pe/institucion/inei/informes-publicaciones/7384316-peru-estructura-empresarial-2024
- https://www.gob.pe/institucion/inei/informes-publicaciones/7754305-region-lima-estructura-empresarial-2024

---

## 2. Variable de tratamiento — infraestructura vial

### 2.1 MEF — Invierte.pe / Banco de Inversiones ⭐ núcleo del DiD

- **Qué aporta:** proyecto de inversión con código único, **ubigeo**, fechas del ciclo
  (viabilidad, inicio, culminación) y montos. Es lo que define las **cohortes de adopción**.
- **Cobertura temporal:** Invierte.pe desde 2017; **SNIP** para 2000–2016. El pipeline
  debe unificar ambos registros.
- **URLs:**
  - https://ofi5.mef.gob.pe/invierte/consultapublica/consultainversiones
  - https://ofi5.mef.gob.pe/invierte/
  - https://www.mef.gob.pe/es/inversion-publica-sp-21787

### 2.2 MEF — Consulta Amigable

Devengado anual por **distrito × función Transporte**. Provee una medida de **dosis
continua** de inversión, complementaria al tratamiento binario.

### 2.3 MTC — Geoportal / SINAC

- **Qué aporta:** shapefiles de red vial nacional, departamental y vecinal.
- **⚠️ Limitación:** las versiones publicadas son recientes (2022–2024). Para un panel se
  necesitan cortes históricos — ver fuentes de respaldo abajo.
- **URLs:**
  - https://geoportal.mtc.gob.pe/
  - https://portal.mtc.gob.pe/transportes/caminos/normas_carreteras/informacion_espacial.html
  - Versión 2016 archivada: https://datosabiertos.gob.pe/dataset/mtc-datos-espaciales-de-la-red-vial-nacional-2016
  - Espejos históricos: https://www.geogpsperu.com/2015/09/mtc-red-vial-nacional-descarga-gratis.html

### 2.4 MTC — Anuario Estadístico

Kilómetros por departamento y tipo de superficie, serie histórica. Nivel departamental.

---

## 3. Variable secundaria — informalidad

### 3.1 INEI — ENAHO, módulo de empleo e ingresos

- **Nivel de representatividad:** **departamental**. No es representativa a nivel
  distrital, aunque el microdato incluya ubigeo.
- **Definición de informalidad:** desde 2014 incluye preguntas sobre razones de no registro
  ante la administración tributaria.
- **Acceso:** microdatos libres en SPSS, CSV, STATA, DBF.
- **URLs:**
  - https://proyectos.inei.gob.pe/microdatos/
  - https://webinei.inei.gob.pe/anda_inei/
  - Definiciones MTPE: https://www2.trabajo.gob.pe/empleo-informal-segun-enaho/

### 3.2 INEI — Producción y Empleo Informal en el Perú

Cuenta satélite de la economía informal. Sirve para validar agregados.
https://www.inei.gob.pe/media/MenuRecursivo/publicaciones_digitales/Est/Lib1701/libro.pdf

---

## 4. Controles y denominadores

### 4.1 INEI — Censos Nacionales 2017 + proyecciones distritales

Denominador poblacional, indispensable para expresar la creación de empresas como tasa
per cápita. https://www.inei.gob.pe/estadisticas/censos/

### 4.2 INEI — RENAMU

- **Qué aporta:** censo anual de municipalidades (2011–2025) con **licencias de
  funcionamiento otorgadas**, costos y tiempos de trámite, simplificación administrativa.
- **Doble rol:** (i) medida alternativa de entrada empresarial a nivel distrital;
  (ii) variación institucional distrito-año que sirve como control o instrumento.
- **URLs:**
  - https://www.datosabiertos.gob.pe/dataset/registro-nacional-de-municipalidades-renamu-2025-instituto-nacional-de-estad%C3%ADstica-e
  - https://www.datosabiertos.gob.pe/dataset/registro-nacional-de-municipalidades-renamu-2023-instituto-nacional-de-estad%C3%ADstica-e

### 4.3 INEI — SIRTOD

Sistema de Información Regional para la Toma de Decisiones: indicadores demográficos,
sociales, económicos y de presupuesto a nivel **departamental, provincial y distrital**.
https://systems.inei.gob.pe/SIRTOD/

---

## 5. Fuentes descartadas (y por qué)

| Fuente | Motivo del descarte |
|---|---|
| **IV Censo Nacional Económico 2008** | Único censo económico reciente; desactualizado para un panel 2007–2025. Útil solo como línea de base. El V CENEC fue anunciado — reevaluar si se publica. |
| **INEI — Encuesta Nacional de Empresas (ENE)** | Muestral (~13k empresas), representativa a nivel departamental, con filtro de ventas ≥50 UIT que excluye microempresas. No sirve para medir creación. |
| **INEI — Encuesta Económica Anual (EEA)** | Panel de empresas grandes; requiere solicitud formal; no captura el margen extensivo. |
| **DCEE (directorio a nivel de empresa)** | Información reservada por confidencialidad estadística. Solo se publican tabulados agregados. |

---

## 6. Trampas de integración

1. **Ubigeos cambian en el tiempo.** Se crean y redefinen distritos. Sin tabla de
   concordancia se generan falsos ceros. Ver `R/04_ubigeo_concordance.R`.
2. **CIIU rev. 3 vs. rev. 4.** PRODUCE usa rev. 3; INEI y SUNAT usan rev. 4. Requiere tabla
   de correspondencia.
3. **Domicilio fiscal ≠ operación.** Concentra altas en distritos céntricos. Mitigar con el
   padrón de locales anexos.
4. **SNIP vs. Invierte.pe.** Códigos de proyecto distintos entre ambos sistemas; unificar
   con cuidado para no duplicar proyectos que cruzaron la transición de 2017.
