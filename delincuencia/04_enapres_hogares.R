# 04_enapres_hogares.R
# Base apilada de hogares de la ENAPRES 2014-2025 (capítulo 100) con el
# indicador de robo o intento de robo de vivienda.
#
# Universo: hogares urbanos con respuesta a la pregunta y factor > 0 (la
# pregunta no tiene respuestas en el área rural; decisión D11).
# Llave: año + mes + conglomerado + nselv + vivienda + hogar (decisión D10; ver
# diccionario.md: sin el mes hay entre 0 y 22 repeticiones por año, que son
# entrevistas de meses distintos).
#
# Uso: Rscript delincuencia/04_enapres_hogares.R
# Salida: delincuencia/datos_procesados/enapres_hogares.{parquet,csv}

source("delincuencia/funciones.R")

hog <- bind_rows(lapply(ANIOS, function(anio) {
  v <- if (anio >= 2024) c("P116_1", "P116_2") else c("P112_1", "P112_2")
  d <- leer_sav(archivo("enapres", anio, PAT_ENAPRES_CAP100),
                c("MES", "CONGLOMERADO", "NSELV", "VIVIENDA", "HOGAR", "AREA", "CCDD", "CCPP", "CCDI",
                  "FACTOR", "FACTORANUAL", v))
  stopifnot(all(v %in% names(d)))
  rural_con_dato <- sum(d$AREA == 2 & !(is.na(d[[v[1]]]) & is.na(d[[v[2]]])))
  if (rural_con_dato > 0) stop("ENAPRES ", anio, ": hay hogares rurales con respuesta de robo de vivienda")
  peso <- if (anio >= 2018) d$FACTOR else d$FACTORANUAL
  tibble(
    anio = as.integer(anio), mes = as.integer(d$MES),
    conglomerado = como_id(d$CONGLOMERADO), nselv = como_id(d$NSELV),
    vivienda = como_id(d$VIVIENDA), hogar = como_id(d$HOGAR),
    ubigeo = ubigeo_enapres(d$CCDD, d$CCPP, d$CCDI),
    area = as.integer(d$AREA),
    factor = as.numeric(peso),
    # Robo o intento de robo en la vivienda (1 = Sí en cualquiera de las dos preguntas)
    robo_vivienda = alguno(d[v])
  )
}))

antes <- nrow(hog)
hog <- hog |> filter(area == 1, !is.na(robo_vivienda), !is.na(factor), factor > 0) |>
  mutate(ubigeo_base = a_base(ubigeo)) |> relocate(ubigeo_base, .after = ubigeo) |> select(-area)
cat("Hogares descartados (rurales, sin respuesta o sin factor):", antes - nrow(hog), "\n")

llave_unica(hog, c("anio", "mes", "conglomerado", "nselv", "vivienda", "hogar"), "ENAPRES hogares")
guardar(hog, "enapres_hogares")

print(as.data.frame(hog |> group_by(anio) |>
  summarise(n = n(), robo_vivienda = round(100 * media_pond(robo_vivienda, factor), 1), .groups = "drop")))
