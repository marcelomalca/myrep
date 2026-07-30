# Infraestructura de transporte y creación de empresas formales en el Perú

Proyecto de investigación econométrica sobre el efecto causal de las mejoras en
infraestructura vial sobre la **creación de empresas formales** a nivel distrital, con la
informalidad como mecanismo complementario.

## Diseño en una línea

DiD escalonado (Callaway & Sant'Anna) sobre un panel **distrito × año** (~1,890 distritos,
2007–2025), donde el tratamiento es la culminación de proyectos viales registrados en el
MEF y el resultado son las altas de RUC de SUNAT.

| Bloque | Pregunta | Unidad | Fuente |
|---|---|---|---|
| Principal | ¿Aumenta la creación de empresas formales? | Distrito × año | SUNAT |
| Secundario | ¿Cae la proporción de empleo informal? | Departamento × año | ENAHO |

## Documentación

- [`docs/01-diseno-investigacion.md`](docs/01-diseno-investigacion.md) — pregunta, hipótesis,
  especificación econométrica, limitaciones.
- [`docs/02-fuentes-datos.md`](docs/02-fuentes-datos.md) — catálogo de fuentes con URLs y
  trampas de integración.
- [`docs/03-extensiones-metodologicas.md`](docs/03-extensiones-metodologicas.md) — IV con
  caminos incas, rutas de mínimo costo, panel FE, DiD sobre megaproyectos IIRSA.

## Pipeline

```
R/00_setup.R                 dependencias, rutas y parámetros
R/01_download_sunat.R        padrón RUC  <- PASO BLOQUEANTE, ver abajo
R/02_download_mef.R          proyectos viales (Invierte.pe + SNIP)
R/03_download_inei.R         RENAMU, ENAHO, población, validación
R/04_ubigeo_concordance.R    armonización temporal de distritos
R/05_build_firm_panel.R      panel distrito-año de altas
R/06_treatment_assignment.R  cohortes de adopción
R/07_estimate_did.R          Callaway-Sant'Anna + Sun-Abraham + TWFE
R/08_robustness.R            placebos, umbrales, Honest DiD, informalidad
```

Ejecutar en orden. Requiere R ≥ 4.2; `00_setup.R` instala las dependencias.

## Primer paso obligatorio

**El esquema del padrón SUNAT no está verificado.** No pudo comprobarse durante el diseño
porque la política de red del entorno de desarrollo bloquea `sunat.gob.pe`.

De ello depende el periodo factible del panel:

- Si el padrón trae **fecha de inscripción** → panel retrospectivo por cohortes de
  nacimiento, con sesgo de supervivencia a cuantificar.
- Si **no** la trae → hay que acumular snapshots mensuales y/o recuperar versiones pasadas
  del Internet Archive, lo que acorta el periodo.

Ejecuta `R/01_download_sunat.R` en una máquina con acceso abierto: el script detecta el
esquema e imprime un reporte con el escenario aplicable. Luego ajusta `ANIO_INICIO` en
`R/00_setup.R` y registra el hallazgo en `docs/02-fuentes-datos.md`.

## Insumos que requieren descarga manual

Estas fuentes no exponen API estable:

| Archivo esperado en `data/raw/` | Fuente |
|---|---|
| `mef_invierte_transporte.xlsx` | [Consulta pública Invierte.pe](https://ofi5.mef.gob.pe/invierte/consultapublica/consultainversiones) — Función 15 TRANSPORTE |
| `mef_snip_transporte.xlsx` | Mismo portal, registros SNIP (2000–2016) |
| `ubigeos_inei.csv` | [SIRTOD](https://systems.inei.gob.pe/SIRTOD/) |
| `poblacion_distrital.csv` | [Censos INEI](https://www.inei.gob.pe/estadisticas/censos/) |
| `produce_directorio_mipyme.csv` | [PRODUCE OGEIEE](https://ogeiee.produce.gob.pe/index.php/en/shortcode/estadistica-oee/estadisticas-mipyme) |
| `inei_demografia_empresarial.csv` | [Demografía Empresarial](https://www.gob.pe/institucion/inei/colecciones/6116-demografia-empresarial) (transcripción manual desde PDF) |

## Verificación

El pipeline se considera válido cuando:

1. Las altas agregadas a nivel departamento-año correlacionan > 0.90 con la serie oficial
   de Demografía Empresarial del INEI (`validar_contra_inei()` en `05`).
2. Los leads del event study no son conjuntamente distintos de cero.
3. Las cohortes placebo adelantadas 4 años no producen efectos significativos.
4. El resultado no depende del umbral de monto que define el tratamiento.

## Advertencia metodológica

No usar TWFE ingenuo como estimador principal: con adopción escalonada y efectos
heterogéneos produce comparaciones prohibidas y pesos negativos. El estimador principal es
Callaway & Sant'Anna (2021); el TWFE se reporta solo como referencia junto con la
descomposición de Goodman-Bacon.
