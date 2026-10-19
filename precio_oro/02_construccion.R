# 02_construccion.R
# Construye las series mensual y anual del precio nominal del oro (US$/oz) a
# partir de los precios diarios de Yahoo Finance (GC=F).
#
#   Mensual: promedio de los cierres diarios del mes; también el cierre del
#            último día con cotización del mes.
#   Anual:   promedio de los promedios mensuales del año.
#
# Uso: Rscript precio_oro/02_construccion.R
# Salidas:
#   precio_oro/datos_procesados/precio_oro_mensual.csv
#   precio_oro/datos_procesados/precio_oro_anual.csv

suppressPackageStartupMessages({ library(jsonlite); library(dplyr); library(readr) })

dir_brutos <- "precio_oro/datos_brutos"
dir_proc <- "precio_oro/datos_procesados"
dir.create(dir_proc, showWarnings = FALSE)

registro <- read_csv(file.path(dir_brutos, "registro_descargas.csv"), show_col_types = FALSE)
fecha_descarga <- as.Date(substr(registro$fecha_descarga_utc[1], 1, 10))

leer_yahoo <- function(archivo) {
  r <- fromJSON(file.path(dir_brutos, archivo))$chart$result
  zona <- r$meta$exchangeTimezoneName   # America/New_York
  tibble(
    fecha = as.Date(as.POSIXct(r$timestamp[[1]], origin = "1970-01-01", tz = zona), tz = zona),
    cierre = r$indicators$quote[[1]]$close[[1]]
  )
}

# Precios diarios; se descartan los días sin cierre (vienen como nulos)
diario <- leer_yahoo("yahoo_GC=F_1d.json")
cat("Días descargados:", nrow(diario), "| sin cierre (descartados):", sum(is.na(diario$cierre)), "\n")
diario <- diario |> filter(!is.na(cierre)) |> arrange(fecha)
stopifnot(!anyDuplicated(diario$fecha))

mensual <- diario |>
  mutate(anio = as.integer(format(fecha, "%Y")), mes = as.integer(format(fecha, "%m"))) |>
  group_by(anio, mes) |>
  summarise(
    precio_promedio_usd_oz = mean(cierre),
    precio_cierre_usd_oz = cierre[which.max(fecha)],
    dias_cotizacion = n(),
    primer_dia = min(fecha), ultimo_dia = max(fecha),
    .groups = "drop"
  ) |>
  mutate(
    periodo = sprintf("%d-%02d", anio, mes),
    # El mes de la descarga está incompleto
    mes_completo = !(anio == as.integer(format(fecha_descarga, "%Y")) &
                       mes == as.integer(format(fecha_descarga, "%m")))
  ) |>
  select(periodo, anio, mes, precio_promedio_usd_oz, precio_cierre_usd_oz,
         dias_cotizacion, primer_dia, ultimo_dia, mes_completo)

# Control: en los meses completos, el cierre mensual debe coincidir con la barra
# mensual de Yahoo. La serie mensual de Yahoo tiene meses faltantes (por eso se
# construye a partir de los precios diarios) y su barra del mes en curso no está
# actualizada, por lo que solo se comparan meses completos.
barras <- leer_yahoo("yahoo_GC=F_1mo.json") |>
  filter(!is.na(cierre)) |>
  transmute(periodo = format(fecha, "%Y-%m"), cierre_barra_mensual = cierre) |>
  distinct(periodo, .keep_all = TRUE)
control <- mensual |> filter(mes_completo) |> inner_join(barras, by = "periodo") |>
  mutate(dif = abs(precio_cierre_usd_oz - cierre_barra_mensual))
cat("Meses completos comparados con la barra mensual de Yahoo:", nrow(control),
    "| máxima diferencia en el cierre:", round(max(control$dif), 4), "US$/oz",
    "| meses sin barra mensual en Yahoo:", sum(!mensual$periodo %in% barras$periodo), "\n")
stopifnot(max(control$dif) < 0.01)

anual <- mensual |>
  group_by(anio) |>
  summarise(
    precio_promedio_usd_oz = mean(precio_promedio_usd_oz),
    precio_cierre_usd_oz = precio_cierre_usd_oz[which.max(mes)],
    meses = n(),
    anio_completo = meses == 12 & all(mes_completo),
    .groups = "drop"
  )

mensual <- mensual |> mutate(across(c(precio_promedio_usd_oz, precio_cierre_usd_oz), ~ round(.x, 2)))
anual <- anual |> mutate(across(c(precio_promedio_usd_oz, precio_cierre_usd_oz), ~ round(.x, 2)))

write_csv(mensual, file.path(dir_proc, "precio_oro_mensual.csv"))
write_csv(anual, file.path(dir_proc, "precio_oro_anual.csv"))
cat("Mensual:", nrow(mensual), "meses (", mensual$periodo[1], "a", tail(mensual$periodo, 1), ")\n")
print(as.data.frame(anual))
