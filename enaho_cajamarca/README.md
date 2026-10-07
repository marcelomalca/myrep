# Ingreso promedio por nivel educativo – Cajamarca (ENAHO 2020–2024)

Estima el ingreso laboral promedio mensual por nivel educativo en un departamento
del Perú (por defecto Cajamarca, ubigeo `06`) usando los microdatos de la
**ENAHO** del INEI. Por defecto combina (pooling) los años **2020 a 2024** para
ganar muestra en los niveles educativos poco frecuentes.

## Uso

```bash
pip install -r requirements.txt
python ingreso_por_educacion.py                    # Cajamarca, 2020-2024 combinados
python ingreso_por_educacion.py --anios 2024       # un solo año
python ingreso_por_educacion.py --departamento 15  # otro departamento (ubigeo de 2 dígitos)
python grafico_ingreso_educacion.py                # gráfico 2020-2024 con los 12 niveles de p301a
python grafico_ingreso_educacion.py --periodo 2024 # gráfico de un solo año
```

La primera ejecución descarga el módulo 05 de cada año (~17 MB comprimido cada uno) del
[portal de microdatos del INEI](https://proyectos.inei.gob.pe/microdatos/) a `datos/`,
que no se versiona. Los resultados se guardan en `resultados/` como CSV.

## Metodología

| Elemento | Definición |
|---|---|
| Base | ENAHO anual, archivo `enaho01a-AAAA-500.dta`. Códigos INEI: 2020 = 737, 2021 = 759, 2022 = 784, 2023 = 906, 2024 = 966 |
| Población | Ocupados (`ocu500 == 1`) con ubigeo del departamento |
| Ingreso | Suma anual de `i524a1, d529t, i530a, d536, i538a1, d540t, i541a, d543, d544t` ÷ 12: ocupación principal y secundaria, monetario y en especie, más ingresos extraordinarios |
| Precios | Con varios años, los ingresos se llevan a soles del último año con el IPC de Lima Metropolitana (BCRP, serie PN38705PM, promedio anual) |
| Nivel educativo | `p301a` (el archivo del módulo 500 ya la incluye y coincide al 100% con la del módulo 300) |
| Factor de expansión | `fac500a` ÷ número de años (la población expandida es un promedio anual) |
| Varianza | Linealización de Taylor; estratos = `estrato`, UPM = `conglome`, estimación de dominio sobre la muestra nacional. Un conglomerado visitado varios años (panel) cuenta como una sola UPM |
| Confiabilidad | "referencial" si CV > 15%, n < 30 o la varianza no es estimable (todos los casos en un solo conglomerado) |

Se generan estas tablas (`*` = `ingreso_educacion_06_2020-2024`):

- `*_grupos.csv`: **definición principal**. Ocupados con ingreso > 0, por etapa educativa.
  Excluye a los trabajadores familiares no remunerados, que reportan ingreso cero.
  Básica especial se mantiene como categoría propia.
- `*_detalle.csv`: la misma población con las 12 categorías de `p301a`.
- `*_grupos_todos_ocupados.csv`: todos los ocupados, incluidos los de ingreso cero.
- `*_por_anio.csv`: ingreso promedio total de cada año, en soles de 2024.

Los archivos `ingreso_educacion_06_2024_*` son las mismas tablas solo con la ENAHO 2024, en soles corrientes.

## Resultados – Cajamarca 2020–2024 (ocupados con ingreso, S/ de 2024 por mes)

| Nivel educativo | n | Promedio | IC 95% | Mediana |
|---|---:|---:|---|---:|
| Primaria o menos | 5,377 | 669 | 623 – 716 | 465 |
| Secundaria | 2,919 | 1,007 | 943 – 1,071 | 754 |
| Superior no universitaria | 913 | 1,742 | 1,600 – 1,885 | 1,321 |
| Superior universitaria | 998 | 2,872 | 2,534 – 3,210 | 2,465 |
| Básica especial (referencial) | 2 | 1,350 | no estimable | 1,367 |
| **Total** | 10,211 | **1,142** | 1,060 – 1,225 | 702 |

### Detalle por los 12 niveles educativos de la ENAHO

![Ingreso por nivel educativo, Cajamarca 2020-2024](resultados/ingreso_educacion_06_2020-2024_grafico.png)

Al combinar los cinco años, todos los niveles son confiables (CV < 10%) salvo
"Educación inicial" (2 casos) y "Básica especial" (2 casos, ambos de 2023 y del
mismo conglomerado), que siguen siendo solo referenciales.

## Fay-Herriot (estimación de áreas pequeñas)

```bash
python fay_herriot.py                     # 2020-2024 combinados
python fay_herriot.py --anios 2024        # un solo año (más contraste didáctico)
python grafico_fay_herriot.py             # o --periodo 2024
python validar_fay_herriot.py             # opcional: compara con samplics (pip install samplics)
```

### Idea

El estimador directo usa solo la muestra del área. Cuando la muestra es chica, es
muy impreciso. Fay-Herriot combina el directo con una predicción de un modelo de
regresión ajustado sobre **todas** las áreas, y pondera según la precisión de cada una.

Las áreas son **departamento × nivel educativo** (25 × 12 = 300). El modelo trabaja
en logaritmos, porque los efectos de departamento y de educación son multiplicativos:

| Nivel | Ecuación |
|---|---|
| Muestreo | `y_d = θ_d + e_d`, con `e_d ~ N(0, ψ_d)` y `y_d` = log del promedio directo |
| Enlace | `θ_d = x_d'β + u_d`, con `u_d ~ N(0, σ²_u)` |
| EBLUP | `θ̂_d = γ_d·y_d + (1 − γ_d)·x_d'β̂`, con `γ_d = σ²_u / (σ²_u + ψ_d)` |

- **Covariables `x_d`:** constante + efectos fijos de departamento + efectos fijos de nivel educativo.
  La predicción sintética de "Cajamarca × Maestría" es, entonces, el efecto Cajamarca por el efecto Maestría.
  En una aplicación real se agregarían covariables externas (por ejemplo, del Censo 2017).
- **Varianzas `ψ_d`:** FH supone que son conocidas, pero las áreas con 1 o 2 casos no tienen
  varianza estimable. Se suavizan con una función generalizada de varianza (GVF),
  `log ψ_d = a + b·log n_d`, ajustada con las áreas de al menos 30 casos. Por eso, en el gráfico de γ,
  todas las áreas caen sobre una misma curva.
- **σ²_u:** REML con Fisher scoring. **β:** mínimos cuadrados generalizados.
- **Error:** MSE de Prasad-Rao (`g1 + g2 + 2·g3`). Las áreas sin muestra reciben solo la predicción sintética,
  con MSE `σ²_u + g2`.
- **Vuelta a soles:** `exp(θ̂ + MSE/2)`, una corrección de sesgo simple.
- **Validación:** la implementación coincide con `samplics` (σ²_u, β, EBLUP y MSE iguales hasta ~1e-7).

### Resultados – Cajamarca

![Directo vs. Fay-Herriot, Cajamarca 2020-2024](resultados/fay_herriot_06_2020-2024_comparacion.png)

![Peso del directo según tamaño de muestra](resultados/fay_herriot_06_2020-2024_gamma.png)

Qué muestra el ejercicio:

- **Áreas grandes** (primaria, secundaria): γ ≈ 0.8–0.9. FH casi no cambia el directo, pero reduce un poco el CV.
- **Áreas chicas** ("Educación inicial" y "Básica especial", 2 casos cada una): γ ≈ 0.02. FH reemplaza el
  directo por la predicción del modelo. Básica especial pasa de S/ 1,350 (2 casos) a S/ 473.
- **Áreas atípicas:** en Cajamarca, los universitarios completos y con maestría ganan más de lo que predice el
  modelo aditivo. FH los "jala" hacia la predicción sintética: de S/ 3,133 a S/ 2,878 y de S/ 4,927 a S/ 4,250.
  Ese es el costo de Fay-Herriot: menos varianza a cambio de posible sesgo cuando el área no se parece al modelo.
- **Con un solo año (2024)** el efecto es mucho mayor: γ baja a 0.2–0.7 y Básica especial (0 casos) se estima
  solo con el modelo (S/ 608, CV 28%). Ver `resultados/fay_herriot_06_2024_*`.
- **El CV de FH no incluye el error del modelo.** Un CV bajo en un área casi sintética (por ejemplo,
  Educación inicial: 12.5%) dice que el modelo es preciso, no que sea correcto para esa área.

## Advertencias

- 2020 fue un año de pandemia. Su ingreso promedio (S/ 1,025 en soles de 2024) es el más bajo del periodo y reduce un poco el promedio combinado; ver `*_por_anio.csv`.
- Los conglomerados de la ENAHO se repiten casi todos entre años (componente panel), así que combinar 5 años no quintuplica la información efectiva. La varianza lo toma en cuenta.
- Las variables `i*` son imputadas y las `d*` deflactadas, como las entrega el INEI.
- Las cifras no son directamente comparables con las de la EPEN (por ejemplo, el S/ 1,766 nacional de 2024), que es una encuesta urbana con otra metodología.
