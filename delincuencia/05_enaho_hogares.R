# 05_enaho_hogares.R
# Base apilada de hogares de la ENAHO 2014-2025 (módulo 85, archivo
# enaho01b-AAAA-2) con el indicador "hogar afectado por hecho delictivo".
#
# Decisión D12: 1 si p40_5 = 1, 0 si p40_5 = 0, faltante si no hay dato (en
# 2020-2021 corresponde al cuestionario telefónico reducido, que no incluye la
# pregunta). No se imputa. La pregunta la responde el jefe o jefa de hogar o su
# cónyuge.
#
# Universo: todos los hogares del archivo con factor07 > 0 (urbano y rural).
#
# Uso: Rscript delincuencia/05_enaho_hogares.R
# Salida: delincuencia/datos_procesados/enaho_hogares.{parquet,csv}

source("delincuencia/funciones.R")

hog <- bind_rows(lapply(ANIOS, function(anio) {
  d <- leer_dta(archivo("enaho", anio, PAT_ENAHO_HOGAR),
                c("mes", "conglome", "vivienda", "hogar", "ubigeo", "estrato", "factor07",
                  "p40_5", "tipocuestionario"))
  stopifnot(all(d$p40_5 %in% c(0, 1, NA)))
  tipo <- if ("tipocuestionario" %in% names(d)) as.integer(d$tipocuestionario) else rep(NA_integer_, nrow(d))
  tibble(
    anio = as.integer(anio), mes = as.integer(d$mes),
    conglome = formatC(as.integer(d$conglome), width = 6, flag = "0"),
    vivienda = formatC(as.integer(d$vivienda), width = 3, flag = "0"),
    hogar = formatC(as.integer(d$hogar), width = 2, flag = "0"),
    ubigeo = formatC(as.integer(d$ubigeo), width = 6, flag = "0"),
    # Área como en enaho/: urbana si estrato 1-5, rural si 6-8
    area = ifelse(as.integer(d$estrato) <= 5, 1L, 2L),
    factor07 = as.numeric(d$factor07),
    hecho_delictivo = as.integer(d$p40_5),
    # 2020-2021: 1 = cuestionario reducido de la emergencia sanitaria (sin la pregunta)
    cuestionario_reducido = ifelse(is.na(tipo), 0L, as.integer(tipo == 1))
  )
}))

antes <- nrow(hog)
hog <- hog |> filter(!is.na(factor07), factor07 > 0) |>
  mutate(ubigeo_base = a_base(ubigeo)) |> relocate(ubigeo_base, .after = ubigeo)
cat("Hogares descartados (sin factor):", antes - nrow(hog), "\n")

llave_unica(hog, c("anio", "conglome", "vivienda", "hogar"), "ENAHO hogares")
guardar(hog, "enaho_hogares")

print(as.data.frame(hog |> group_by(anio) |> summarise(
  n = n(), con_dato = sum(!is.na(hecho_delictivo)), reducido = sum(cuestionario_reducido),
  faltante_no_reducido = sum(is.na(hecho_delictivo) & cuestionario_reducido == 0),
  hecho_delictivo = round(100 * media_pond(hecho_delictivo, factor07), 2), .groups = "drop")))
