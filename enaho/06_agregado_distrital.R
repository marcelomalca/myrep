# 06_agregado_distrital.R
# Base agregada distrito-año (ubigeo_base × año) con promedios ponderados de
# cada outcome y el número de observaciones que los sustentan.
#
# Ponderación:
#   - Gasto e ingreso per cápita del hogar: factor07 × mieperho (por personas,
#     convención del INEI).
#   - Outcomes de personas: fac500a, sobre la población de referencia de cada
#     indicador (14 años o más para las tasas; ocupados para el resto; ocupados
#     sin trabajadores familiares no remunerados para el ingreso laboral).
# Las proporciones (tasas, informalidad, ramas, categorías) van de 0 a 1.
#
# Uso: Rscript enaho/06_agregado_distrital.R
# Salida: enaho/datos_procesados/distrito_anio.{parquet,csv}

source("enaho/funciones.R")

hog <- arrow::read_parquet(file.path(PROCESADO, "hogares.parquet"))
per <- arrow::read_parquet(file.path(PROCESADO, "personas.parquet"))

agr_hog <- hog |>
  group_by(ubigeo_base, anio) |>
  summarise(
    n_hogares = n(),
    n_personas_hogares = sum(mieperho),
    gasto_real_pc = media_pond(gasto_real_pc, factor_pob),
    ingreso_real_pc = media_pond(ingreso_real_pc, factor_pob),
    prop_hogares_cuestionario_reducido = mean(cuestionario_reducido),
    .groups = "drop"
  )

secciones <- LETTERS[1:21]
ocup <- per |> filter(ocupado == 1)

agr_pet <- per |>
  group_by(ubigeo_base, anio) |>
  summarise(
    n_pet = n(),
    tasa_actividad = media_pond(pea, fac500a),
    tasa_ocupacion = media_pond(ocupado, fac500a),
    .groups = "drop"
  )

agr_ocu <- ocup |>
  group_by(ubigeo_base, anio) |>
  summarise(
    n_ocupados = n(),
    n_ocupados_con_horas = sum(horas_total > 0, na.rm = TRUE),
    n_ocupados_con_ingreso = sum(!is.na(ingreso_laboral_real)),
    horas_principal = media_pond(horas_principal, fac500a),
    horas_total = media_pond(horas_total, fac500a),
    ingreso_laboral_real = media_pond(ingreso_laboral_real, fac500a),
    ingreso_hora_real = media_pond(ingreso_hora_real, fac500a),
    empleo_informal = media_pond(empleo_informal, fac500a),
    empleo_sector_informal = media_pond(empleo_sector_informal, fac500a),
    afiliado_pension = media_pond(afiliado_pension, fac500a),
    seguro_salud_empleo = media_pond(seguro_salud_empleo, fac500a),
    empleo_informal_oficial = media_pond(empleo_informal_oficial, fac500a),
    empleo_sector_informal_oficial = media_pond(empleo_sector_informal_oficial, fac500a),
    mineria_metalifera = media_pond(mineria_metalifera, fac500a),
    n_ocupados_mineria_metalifera = sum(mineria_metalifera, na.rm = TRUE),
    across(.cols = all_of("categoria_ocupacional"), .fns = list(
      empleador = ~ media_pond(.x == "empleador", fac500a),
      asalariado = ~ media_pond(.x == "asalariado", fac500a),
      independiente = ~ media_pond(.x == "independiente", fac500a),
      tfnr = ~ media_pond(.x == "trabajador_familiar_no_remunerado", fac500a),
      otro = ~ media_pond(.x == "otro", fac500a)
    ), .names = "cat_{.fn}"),
    !!!setNames(lapply(secciones, function(s) rlang::expr(media_pond(ciiu4_seccion == !!s, fac500a))),
                paste0("rama_", secciones)),
    .groups = "drop"
  )

dist <- agr_hog |>
  full_join(agr_pet, by = c("ubigeo_base", "anio")) |>
  full_join(agr_ocu, by = c("ubigeo_base", "anio")) |>
  mutate(across(starts_with("n_"), ~ coalesce(as.integer(.x), 0L))) |>
  arrange(ubigeo_base, anio)

stopifnot(!anyDuplicated(dist[c("ubigeo_base", "anio")]))
guardar(dist, "distrito_anio")

cat("\nDistritos (ubigeo_base) por año:\n")
print(table(dist$anio))
