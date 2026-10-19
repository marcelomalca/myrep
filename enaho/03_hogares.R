# 03_hogares.R
# Base a nivel hogar, 2014-2025 apilada: identificadores, geografía, factor de
# expansión y los outcomes del hogar:
#   gasto_real_pc   gasto real per cápita mensual  = gashog2d / (12 × mieperho × ld × i00)
#   ingreso_real_pc ingreso real per cápita mensual = inghog1d / (12 × mieperho × ld × i00)
# Valores en soles de 2025 a precios de Lima Metropolitana (ver diccionario.md).
#
# Uso: Rscript enaho/03_hogares.R
# Salida: enaho/datos_procesados/hogares_tmp.rds (la versión final, con
#         ubigeo_base, la escribe 06_geografia.R)

source("enaho/funciones.R")

defl <- leer_deflactores()

cols <- c("aÑo", "mes", "conglome", "vivienda", "hogar", "ubigeo", "dominio", "estrato",
          "factor07", "mieperho", "gashog2d", "inghog1d", "tipoentrevista", "tipocuestionario")

hog <- lapply(ANIOS, function(anio) {
  s <- leer(archivo(anio, PAT_SUMARIA), cols)
  if (!"tipoentrevista" %in% names(s)) s$tipoentrevista <- NA_real_
  if (!"tipocuestionario" %in% names(s)) s$tipocuestionario <- NA_real_
  s |>
    transmute(anio = as.integer(anio), mes = as.integer(mes),
              conglome, vivienda, hogar, ubigeo,
              dominio = as.integer(dominio), estrato = as.integer(estrato),
              factor07 = as.numeric(factor07), mieperho = as.integer(mieperho),
              gashog2d = as.numeric(gashog2d), inghog1d = as.numeric(inghog1d),
              tipoentrevista = as.integer(tipoentrevista),
              tipocuestionario = as.integer(tipocuestionario))
}) |> bind_rows()

hog <- hog |>
  normalizar_ids() |>
  agregar_dominio_deflactor() |>
  left_join(defl$temporal |> select(anio, dpto_defl, i00), by = c("anio", "dpto_defl")) |>
  left_join(defl$espacial, by = "dominioA")

stopifnot(!anyNA(hog$i00), !anyNA(hog$ld), all(hog$mieperho > 0))
stopifnot(!anyDuplicated(hog[c("anio", "conglome", "vivienda", "hogar")]))

hog <- hog |>
  mutate(
    gasto_real_pc   = gashog2d / (12 * mieperho * ld * i00),
    ingreso_real_pc = inghog1d / (12 * mieperho * ld * i00),
    factor_pob      = factor07 * mieperho,
    # Modo de entrevista: solo se registra en 2020 (1 presencial, 2 telefónica)
    # y el tipo de cuestionario en 2020-2021 (1 = reducido)
    cuestionario_reducido = as.integer(tipocuestionario %in% 1)
  ) |>
  select(anio, mes, conglome, vivienda, hogar, ubigeo, dpto, area, estrato, dominio,
         factor07, factor_pob, mieperho, tipoentrevista, tipocuestionario, cuestionario_reducido,
         gashog2d, inghog1d, i00, ld, gasto_real_pc, ingreso_real_pc)

saveRDS(hog, file.path(PROCESADO, "hogares_tmp.rds"))

hog |>
  group_by(anio) |>
  summarise(hogares = n(),
            gasto_real_pc = media_pond(gasto_real_pc, factor_pob),
            ingreso_real_pc = media_pond(ingreso_real_pc, factor_pob), .groups = "drop") |>
  as.data.frame() |> print(digits = 5)
