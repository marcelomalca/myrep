# Precio del oro, 2014–2026 (US$ nominales por onza troy)

Series mensual y anual del precio nominal del oro, construidas a partir de los
precios diarios de Yahoo Finance.

## Cómo reproducir

Desde la raíz del repositorio:

```
Rscript precio_oro/01_descarga.R      # descarga de Yahoo Finance
Rscript precio_oro/02_construccion.R  # series mensual y anual
Rscript precio_oro/03_grafico.R       # gráfico
```

Paquetes de R: `jsonlite`, `dplyr`, `readr` y `ggplot2` (y `scales`, que
`ggplot2` instala).

## Fuente

| | |
|---|---|
| Proveedor | Yahoo Finance, API de gráficos (`query1.finance.yahoo.com/v8/finance/chart`) |
| Símbolo | `GC=F`: futuros de oro de COMEX (CME Group), contrato continuo del mes más cercano |
| Unidad | US$ por onza troy, precio nominal |
| URL diaria | `https://query1.finance.yahoo.com/v8/finance/chart/GC%3DF?period1=1388534400&period2=1792439645&interval=1d` |
| URL mensual | `https://query1.finance.yahoo.com/v8/finance/chart/GC%3DF?period1=1388534400&period2=1792439645&interval=1mo` |
| Fecha de descarga | 19 de octubre de 2026, 19:54 UTC |
| Periodo | 2 de enero de 2014 al 19 de octubre de 2026 |

`period1` y `period2` son el inicio (1/1/2014) y el final (momento de la
descarga) en segundos desde 1970.

**Archivos descargados** (en `datos_brutos/`, sin modificar):
- `yahoo_GC=F_1d.json`: precios diarios;
- `yahoo_GC=F_1mo.json`: barras mensuales de Yahoo, que solo se usan como control;
- `registro_descargas.csv`: URL, fecha y hora, tamaño y MD5 de cada descarga.

Al volver a correr `01_descarga.R`, la descarga llega hasta la fecha de ese
momento y el registro se actualiza.

## Salidas

### `datos_procesados/precio_oro_mensual.csv`
Una fila por año-mes (154 meses, de 2014-01 a 2026-10).

| Columna | Definición |
|---|---|
| `periodo` | Año-mes, `AAAA-MM` |
| `anio`, `mes` | Año y mes |
| `precio_promedio_usd_oz` | **Precio mensual**: promedio de los cierres diarios del mes (US$/oz) |
| `precio_cierre_usd_oz` | Cierre del último día con cotización del mes (US$/oz) |
| `dias_cotizacion` | Días con cierre que entran en el promedio |
| `primer_dia`, `ultimo_dia` | Primer y último día con cotización del mes |
| `mes_completo` | `FALSE` para el mes en curso al descargar (octubre de 2026, datos al día 19) |

### `datos_procesados/precio_oro_anual.csv`
Una fila por año (2014–2026).

| Columna | Definición |
|---|---|
| `anio` | Año |
| `precio_promedio_usd_oz` | **Precio anual**: promedio de los promedios mensuales del año (US$/oz) |
| `precio_cierre_usd_oz` | Cierre del último mes disponible del año (US$/oz) |
| `meses` | Meses con datos |
| `anio_completo` | `FALSE` para 2026 (enero a octubre, octubre incompleto) |

### `precio_oro.png`
Promedio anual (azul) y promedio mensual (gris), 2014–2026, en US$ nominales.

## Año base

**No aplica.** Todas las series son nominales (dólares corrientes de cada
periodo); no se construyeron series reales.

## Decisiones

1. **Solo Yahoo Finance, solo valores nominales.** Así lo pediste: no se usa el
   Banco Mundial ni se construyen las series reales ni en soles. Por eso el gráfico
   muestra el precio nominal en dólares, 2014–2026, y no el precio real
   2000–2025 en dólares y soles.
2. **Se usan futuros, no precio spot.**
   - Yahoo ya no publica el precio spot del oro (`XAUUSD=X` devuelve "symbol may be
     delisted"); la serie disponible es `GC=F`.
   - El precio del contrato más cercano suele estar ligeramente por encima del spot
     (costo de mantener la posición), y en las fechas de vencimiento el contrato
     continuo cambia de mes, lo que puede producir saltos pequeños.
   - Si necesitas el precio spot de referencia (LBMA), la fuente es el Banco
     Mundial (Pink Sheet).
3. **El precio mensual es el promedio de los cierres diarios**, comparable con las
   series de "promedio de cotizaciones diarias". El cierre de fin de mes se incluye
   como columna aparte.
4. **El precio anual es el promedio de los 12 promedios mensuales.** Difiere apenas
   del promedio de todos los días, porque los meses tienen distinto número de días
   de cotización.
5. **La serie mensual se construye con datos diarios, no con las barras mensuales
   de Yahoo.**
   - Las barras mensuales tienen 22 meses faltantes (p. ej., 2014-06, 2020-03 y
     2024-12) y la barra del mes en curso no está actualizada.
   - Como control, en los 131 meses completos que sí tienen barra mensual, el cierre
     del último día coincide exactamente con el de la barra (diferencia 0).
     `02_construccion.R` se detiene si esto deja de cumplirse.
6. **Días sin cierre.** Se descartan 5 días que Yahoo publica sin cierre:
   2016-01-18, 2016-02-15, 2025-05-26 y 2025-06-19 (feriados de EE. UU.) y
   2018-01-29.
7. **Fechas en horario de Nueva York.** Las fechas diarias se asignan en
   America/New_York, la zona horaria de la bolsa.
8. **Periodos incompletos.** 2026 y octubre de 2026 quedan marcados como
   incompletos (`anio_completo`, `mes_completo`) y no deben compararse
   directamente con años o meses completos.
9. **Términos de uso de Yahoo Finance.** Los datos de Yahoo Finance son para uso
   personal y no tienen licencia de redistribución. Para una publicación conviene
   citarlos como fuente o contrastarlos con una fuente oficial.
