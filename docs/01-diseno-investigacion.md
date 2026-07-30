# Infraestructura de transporte y creación de empresas formales en el Perú

## 1. Pregunta de investigación

¿La mejora de la infraestructura de transporte incrementa la creación de empresas formales
a nivel distrital en el Perú, y reduce la informalidad?

## 2. Motivación y precisión conceptual

La hipótesis de partida es que mejor infraestructura vial reduce la informalidad porque
incentiva la creación de empresas. Al operacionalizarla conviene separar dos afirmaciones
que suelen confundirse:

**(a) El alta de un RUC es formalización en el margen extensivo.** Medir creación de
empresas formales no abandona la pregunta de informalidad: la mide con un registro
administrativo censal en vez de una encuesta de hogares muestral.

**(b) Más altas formales NO implica menor informalidad.** Si la carretera expande la
actividad económica total, pueden crecer simultáneamente las unidades formales y las
informales. La *tasa* de informalidad es un cociente cuyo denominador el RUC no observa.

De (a) y (b) se sigue el diseño híbrido de este proyecto:

| Bloque | Pregunta que responde | Unidad | Fuente |
|---|---|---|---|
| **Principal** | ¿Aumenta la creación de empresas formales? | Distrito × año | SUNAT |
| **Secundario** | ¿Cae la *proporción* de empleo informal? | Departamento × año | ENAHO |

El bloque principal es donde está la identificación: las carreteras son un tratamiento que
varía a nivel distrital, y SUNAT observa ~1,890 distritos. ENAHO solo es representativa a
nivel departamental (~26 unidades), lo que implica baja potencia y sesgo de agregación —
por eso es bloque secundario y se reporta como evidencia de mecanismo, no como resultado
principal.

## 3. Hipótesis

- **H1.** Los distritos que reciben un proyecto vial culminado experimentan un aumento en
  la tasa de creación de empresas formales respecto a distritos aún no tratados.
- **H2.** El efecto es heterogéneo por sector: mayor en actividades transables
  (manufactura, comercio mayorista) que en no transables.
- **H3.** El efecto se concentra en microempresas — el margen extensivo de la formalización.
- **H4 (secundaria).** La exposición vial acumulada se asocia a una caída en la tasa de
  empleo informal a nivel departamental.

## 4. Datos

Ver [`02-fuentes-datos.md`](02-fuentes-datos.md) para el catálogo completo con URLs.

- **Y principal:** altas de RUC por distrito × año × CIIU (SUNAT, padrón reducido).
- **Tamaño:** ventas anuales y trabajadores (PRODUCE, Directorio MIPYME), cruzado por RUC.
- **Tratamiento:** proyectos viales culminados por distrito y año (MEF, Invierte.pe/SNIP).
- **Y secundaria:** tasa de empleo informal (INEI, ENAHO módulo empleo).
- **Controles:** población (Censos 2017 + proyecciones), trámites municipales (RENAMU),
  indicadores socioeconómicos (SIRTOD).

Periodo objetivo: **2007–2025**, sujeto a la resolución del riesgo de disponibilidad
histórica del padrón SUNAT (sección 7).

## 5. Estrategia empírica

### 5.1 Especificación: DiD escalonado

Un distrito *i* se considera tratado desde el año *g_i* en que culmina su primer proyecto
vial por encima de un umbral mínimo de monto. Los distritos sin proyecto en toda la ventana
son el grupo de comparación nunca-tratado.

Event study:

```
Y_it = α_i + λ_t + Σ_{k≠-1} β_k · D_it^k + X_it'γ + ε_it
```

donde `Y_it` es la tasa de creación de empresas (altas por cada 1,000 habitantes),
`α_i` y `λ_t` son efectos fijos de distrito y año, y `D_it^k` indica estar a *k* periodos
del tratamiento.

### 5.2 Punto técnico crítico: no usar TWFE ingenuo

Con adopción escalonada y efectos heterogéneos en el tiempo, el estimador de efectos fijos
bidireccionales (TWFE) está sesgado: usa unidades tratadas tempranamente como controles de
las tratadas tardíamente ("comparaciones prohibidas"), y puede producir estimadores con
**pesos negativos**. Este proyecto usa estimadores robustos a heterogeneidad:

| Estimador | Rol | Implementación |
|---|---|---|
| **Callaway & Sant'Anna (2021)** | Principal | R: `did::att_gt` / Stata: `csdid` |
| **Sun & Abraham (2021)** | Contraste | R: `fixest::sunab` |
| **Borusyak et al. (2024)** | Contraste | R: `didimputation` |
| **TWFE** | Solo referencia | R: `fixest::feols` |
| **Goodman-Bacon (2021)** | Diagnóstico | Descomposición de pesos del TWFE |

El TWFE se reporta únicamente como referencia, acompañado de la descomposición de
Goodman-Bacon que muestra cuánto peso cargan las comparaciones problemáticas.

### 5.3 Inferencia

Errores estándar agrupados a nivel **distrito**. Dado que las carreteras generan
dependencia espacial entre distritos vecinos, se reporta como robustez el clustering a
nivel **provincia** y errores estándar espacialmente robustos (Conley).

### 5.4 Heterogeneidad

Estimaciones separadas por:
- Sector CIIU (transable vs. no transable; secciones a 1 dígito).
- Segmento de tamaño (micro / pequeña / mediana-grande, vía PRODUCE).
- Tipo de red vial (nacional / departamental / vecinal).
- Región natural (costa / sierra / selva).

## 6. Verificación

1. **Validación externa.** Agregar las altas construidas a nivel departamento-año y
   correlacionarlas con las altas oficiales de *Demografía Empresarial* del INEI.
2. **Tendencias paralelas.** Los coeficientes de leads del event study no deben ser
   conjuntamente distintos de cero.
3. **Placebos.** Cohortes de tratamiento falsas (adelantadas 3–5 años) no deben producir
   efectos significativos.
4. **Sensibilidad al umbral** de monto que define el tratamiento.
5. **Honest DiD** (Rambachan & Roth, 2023) para acotar violaciones plausibles de
   tendencias paralelas.

## 7. Limitaciones reconocidas

1. **Endogeneidad del trazado vial.** El Estado prioriza obras donde hay dinamismo
   económico. El DiD la ataja parcialmente vía efectos fijos y test de leads, pero no la
   elimina. Si la priorización responde a dinamismo *creciente*, los leads lo revelarán.
   Las estrategias en [`03-extensiones-metodologicas.md`](03-extensiones-metodologicas.md)
   atacan este problema de frente.
2. **Disponibilidad histórica del padrón SUNAT.** SUNAT publica un *snapshot* actual, no
   una serie archivada. Si se reconstruyen cohortes de nacimiento desde un único snapshot,
   hay **sesgo de supervivencia creciente hacia atrás**: las empresas que nacieron y
   murieron antes del snapshot pueden no figurar, subestimando la creación en años lejanos.
   Debe cuantificarse contra la serie del INEI.
3. **Domicilio fiscal ≠ ubicación operativa.** Sesga las altas hacia distritos céntricos.
   Se mitiga cruzando con el padrón de locales anexos.
4. **Formalización vs. creación genuina.** Un alta de RUC puede ser (i) un negocio nuevo,
   (ii) un negocio informal que se formaliza, o (iii) una reubicación registral. Solo (ii)
   es reducción de informalidad. El registro no los distingue; de ahí el bloque ENAHO.
5. **Georreferenciación de proyectos MEF.** El ubigeo registrado puede ser el de la unidad
   ejecutora y no el del tramo intervenido.

## 8. Referencias metodológicas

- Callaway, B. & Sant'Anna, P. (2021). "Difference-in-Differences with Multiple Time
  Periods". *Journal of Econometrics*.
- Sun, L. & Abraham, S. (2021). "Estimating Dynamic Treatment Effects in Event Studies with
  Heterogeneous Treatment Effects". *Journal of Econometrics*.
- Goodman-Bacon, A. (2021). "Difference-in-Differences with Variation in Treatment Timing".
  *Journal of Econometrics*.
- Rambachan, A. & Roth, J. (2023). "A More Credible Approach to Parallel Trends".
  *Review of Economic Studies*.
- Volpe Martincus, C., Carballo, J. & Cusolito, A. (2017). "Roads, exports and employment:
  Evidence from a developing country". *Journal of Development Economics*.
