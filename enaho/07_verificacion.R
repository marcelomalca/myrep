# 07_verificacion.R
# Compara los resultados nacionales con cifras oficiales del INEI y reporta las
# diferencias.
#
# Fuentes oficiales (valores transcritos de las publicaciones):
#   [P] INEI (2026). Perú: Evolución de la pobreza monetaria 2016-2025. Nota de
#       prensa del 5 de mayo de 2026: gasto real per cápita mensual de S/ 903
#       (2024) y S/ 920 (2025), a precios de Lima Metropolitana de 2025.
#   [E] INEI (2019). Perú: Evolución de los indicadores de empleo e ingreso por
#       departamento, 2007-2018 (ENAHO). Cuadro 1.27 (tasa de actividad),
#       Cuadro 7.4 (tasa de empleo informal) y Cuadro 10.1 (ingreso promedio
#       mensual proveniente del trabajo, soles corrientes).
#   [M] Variable oficial ocupinf de los microdatos de la ENAHO (2014-2023).
#
# Uso: Rscript enaho/07_verificacion.R
# Salida: enaho/datos_procesados/verificacion_oficial.csv

source("enaho/funciones.R")

hog <- arrow::read_parquet(file.path(PROCESADO, "hogares.parquet"))
per <- arrow::read_parquet(file.path(PROCESADO, "personas.parquet"))

oficial <- tribble(
  ~indicador,                          ~anio, ~oficial, ~fuente,
  "gasto_real_pc (S/ 2025)",            2024,   903,   "P",
  "gasto_real_pc (S/ 2025)",            2025,   920,   "P",
  "tasa_actividad (%)",                 2014,   72.3,  "E, cuadro 1.27",
  "tasa_actividad (%)",                 2015,   71.6,  "E, cuadro 1.27",
  "tasa_actividad (%)",                 2016,   72.2,  "E, cuadro 1.27",
  "tasa_actividad (%)",                 2017,   72.4,  "E, cuadro 1.27",
  "tasa_actividad (%)",                 2018,   72.3,  "E, cuadro 1.27",
  "empleo_informal (%)",                2014,   72.8,  "E, cuadro 7.4",
  "empleo_informal (%)",                2015,   73.2,  "E, cuadro 7.4",
  "empleo_informal (%)",                2016,   72.0,  "E, cuadro 7.4",
  "empleo_informal (%)",                2017,   72.5,  "E, cuadro 7.4",
  "empleo_informal (%)",                2018,   72.4,  "E, cuadro 7.4",
  "ingreso_laboral nominal (S/)",       2014, 1239.9,  "E, cuadro 10.1",
  "ingreso_laboral nominal (S/)",       2015, 1304.9,  "E, cuadro 10.1",
  "ingreso_laboral nominal (S/)",       2016, 1370.7,  "E, cuadro 10.1",
  "ingreso_laboral nominal (S/)",       2017, 1376.8,  "E, cuadro 10.1",
  "ingreso_laboral nominal (S/)",       2018, 1400.1,  "E, cuadro 10.1"
)

# Gasto real con el método del INEI (cada grupo de gasto con su índice), para
# separar la diferencia de método de cualquier error de construcción
defl <- leer_deflactores()
grupos <- list(
  i01 = c(paste0("gru1", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd", "4hd1", "4hd2", "4hd3", "4hd4", "4hd5")),
          "g05hd", paste0("g05hd", 1:6), "ig06hd", "sg23", "sig24", "sg25", "sig26", "sg27", "sig28"),
  i02 = paste0("gru2", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd")),
  i03 = paste0("gru3", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd")),
  i04 = c(paste0("gru4", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd")), "sg421", "sg42d1", "sg423", "sg42d3"),
  i05 = paste0("gru5", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd")),
  i06 = c(paste0("gru6", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd")), "g07hd", "ig08hd", "sg422", "sg42d2"),
  i07 = c(paste0("gru7", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd")), "sg42", "sg42d"),
  i08 = paste0("gru8", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd"))
)
gasto_inei <- lapply(ANIOS, function(anio) {
  s <- leer(archivo(anio, PAT_SUMARIA)) |> select(-any_of("ld"))
  for (x in setdiff(unlist(grupos), names(s))) s[[x]] <- 0   # ausente = 0, como el INEI
  s[unlist(grupos)] <- lapply(s[unlist(grupos)], function(x) ifelse(is.na(x), 0, x))
  s <- s |> mutate(anio = anio, dominio = as.integer(dominio), estrato = as.integer(estrato)) |>
    normalizar_ids() |> agregar_dominio_deflactor() |>
    left_join(defl$temporal, by = c("anio", "dpto_defl")) |> left_join(defl$espacial, by = "dominioA")
  g <- Reduce(`+`, lapply(names(grupos), function(i) rowSums(s[grupos[[i]]]) / s[[i]])) /
    (12 * s$mieperho * s$ld)
  tibble(anio = anio, valor = media_pond(g, s$factor07 * s$mieperho))
}) |> bind_rows()

propios <- bind_rows(
  hog |> group_by(anio) |> summarise(valor = media_pond(gasto_real_pc, factor_pob), .groups = "drop") |>
    mutate(indicador = "gasto_real_pc (S/ 2025)", version = "construido (gashog2d con i00)"),
  gasto_inei |> mutate(indicador = "gasto_real_pc (S/ 2025)", version = "método INEI por grupos"),
  per |> group_by(anio) |> summarise(valor = 100 * media_pond(pea, fac500a), .groups = "drop") |>
    mutate(indicador = "tasa_actividad (%)", version = "construido"),
  per |> filter(ocupado == 1) |> group_by(anio) |>
    summarise(valor = 100 * media_pond(empleo_informal, fac500a), .groups = "drop") |>
    mutate(indicador = "empleo_informal (%)", version = "construido (reconstruido)"),
  per |> filter(ocupado == 1, !is.na(empleo_informal_oficial)) |> group_by(anio) |>
    summarise(valor = 100 * media_pond(empleo_informal_oficial, fac500a), .groups = "drop") |>
    mutate(indicador = "empleo_informal (%)", version = "variable oficial ocupinf [M]"),
  per |> filter(!is.na(ingreso_laboral_nominal)) |> group_by(anio) |>
    summarise(valor = media_pond(ingreso_laboral_nominal, fac500a), .groups = "drop") |>
    mutate(indicador = "ingreso_laboral nominal (S/)", version = "construido")
)

verif <- propios |>
  inner_join(oficial, by = c("indicador", "anio")) |>
  mutate(diferencia = valor - oficial,
         diferencia_pct = 100 * (valor / oficial - 1)) |>
  select(indicador, version, anio, oficial, valor, diferencia, diferencia_pct, fuente) |>
  mutate(across(c(valor, diferencia, diferencia_pct), ~ round(.x, 2))) |>
  arrange(indicador, version, anio)

write_csv(verif, file.path(PROCESADO, "verificacion_oficial.csv"))
print(as.data.frame(verif))
