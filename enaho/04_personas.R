# 04_personas.R
# Base a nivel persona, 2014-2025 apilada: residentes habituales de 14 años o
# más (módulo 05 Empleo e ingresos), con el módulo 04 para el seguro de salud.
# Outcomes de mercado laboral, ingreso laboral, horas e informalidad (ver
# diccionario.md para las definiciones y decisiones).
#
# Uso: Rscript enaho/04_personas.R
# Salidas:
#   enaho/datos_procesados/personas_tmp.rds (la versión final, con ubigeo_base,
#     la escribe 05_geografia.R)
#   enaho/datos_procesados/validacion_informalidad.csv

source("enaho/funciones.R")

defl <- leer_deflactores()

cols500 <- c("mes", "conglome", "vivienda", "hogar", "codperso", "ubigeo", "dominio", "estrato",
             "p204", "p205", "p206", "p208a", "fac500a", "ocu500",
             "p506", "p506r4", "p507", "p510", "p510a1", "p512a", "p512b",
             "i513t", "i518", "p558a1", "p558a2", "p558a3", "p558a4", "p558a5",
             "i524a1", "d529t", "i530a", "d536", "i538a1", "d540t", "i541a", "d543", "d544t",
             "i538a_1", "d538a_2", "ocupinf", "emplpsec", "tipoentrevista", "tipocuestionario")
cols400 <- c("conglome", "vivienda", "hogar", "codperso", paste0("p419a", 1:8))

# Componentes anuales del ingreso laboral (ocupación principal y secundaria)
comp_ingreso <- c("i524a1", "d529t", "i530a", "d536",   # principal: dependiente, especie, independiente, autoconsumo
                  "i538a1", "d540t", "i541a", "d543",   # secundaria
                  "d544t",                              # extraordinarios por trabajo
                  "i538a_1", "d538a_2")                 # secundaria con cuestionario reducido (2020-2021)

per <- lapply(ANIOS, function(anio) {
  d <- leer(archivo(anio, PAT_M500), cols500)
  for (v in setdiff(cols500, names(d))) d[[v]] <- NA_real_
  s <- leer(archivo(anio, PAT_M400), cols400) |> normalizar_ids()
  d |>
    mutate(anio = anio) |>
    filter(es_residente(p204, p205, p206)) |>
    normalizar_ids() |>
    left_join(s, by = c("conglome", "vivienda", "hogar", "codperso"))
}) |> bind_rows()

stopifnot(!anyDuplicated(per[c("anio", "conglome", "vivienda", "hogar", "codperso")]))

per <- per |>
  mutate(mes = as.integer(mes), dominio = as.integer(dominio), estrato = as.integer(estrato)) |>
  agregar_dominio_deflactor() |>
  left_join(defl$temporal |> select(anio, dpto_defl, i00), by = c("anio", "dpto_defl")) |>
  left_join(defl$espacial, by = "dominioA")
stopifnot(!anyNA(per$i00), !anyNA(per$ld))

inf <- clasificar_informalidad(per)

per <- per |>
  bind_cols(inf) |>
  mutate(
    ocupado = as.integer(ocu500 == 1),
    # PEA = ocupados + desocupados abiertos (definición oficial del INEI); los
    # desocupados ocultos (ocu500 = 3) se consideran inactivos
    pea = as.integer(ocu500 %in% 1:2),
    # --- Ingreso laboral (ocupados, sin trabajadores familiares no remunerados,
    #     que por definición no perciben ingreso; convención del INEI) ------------
    ingreso_laboral_nominal = ifelse(ocupado == 1 & p507 != 5,
                                     rowSums(across(all_of(comp_ingreso)), na.rm = TRUE) / 12, NA_real_),
    ingreso_laboral_real = ingreso_laboral_nominal / (ld * i00),
    # --- Horas (solo ocupados) --------------------------------------------------
    horas_principal = ifelse(ocupado == 1, i513t, NA_real_),
    horas_total = ifelse(ocupado == 1, i513t + coalesce(i518, 0), NA_real_),
    ingreso_hora_real = ifelse(!is.na(ingreso_laboral_real) & horas_total > 0,
                               ingreso_laboral_real / (horas_total * 52 / 12), NA_real_),
    # --- Rama de actividad, CIIU rev. 4 (solo ocupados) -------------------------
    ciiu4 = ifelse(ocupado == 1 & !is.na(p506r4), sprintf("%04d", as.integer(p506r4)), NA_character_),
    ciiu4_division = as.integer(substr(ciiu4, 1, 2)),
    ciiu4_seccion = seccion_ciiu4(ciiu4_division),
    mineria_metalifera = ifelse(ocupado == 1, as.integer(ciiu4_division %in% 7), NA_integer_),
    # --- Categoría ocupacional (solo ocupados) -----------------------------------
    categoria_ocupacional = ifelse(ocupado == 1, case_when(
      p507 == 1 ~ "empleador",
      p507 %in% c(3, 4, 6) ~ "asalariado",
      p507 == 2 ~ "independiente",
      p507 == 5 ~ "trabajador_familiar_no_remunerado",
      p507 == 7 ~ "otro"), NA_character_),
    # --- Informalidad (solo ocupados) ---------------------------------------------
    across(c(empleo_informal, empleo_sector_informal, seguro_salud_empleo),
           ~ ifelse(ocupado == 1, .x, NA_integer_)),
    afiliado_pension = ifelse(ocupado == 1,
                              as.integer(if_any(c(p558a1, p558a2, p558a3, p558a4), ~ .x %in% 1:4)),
                              NA_integer_),
    empleo_informal_oficial = ifelse(ocupado == 1 & !is.na(ocupinf), as.integer(ocupinf == 1), NA_integer_),
    empleo_sector_informal_oficial = ifelse(ocupado == 1 & !is.na(ocupinf), as.integer(emplpsec %in% 1), NA_integer_),
    tipoentrevista = as.integer(tipoentrevista),
    tipocuestionario = as.integer(tipocuestionario),
    cuestionario_reducido = as.integer(tipocuestionario %in% 1)
  )

# Validación de la informalidad reconstruida contra la oficial (2014-2023)
val <- per |>
  filter(ocupado == 1, !is.na(empleo_informal_oficial)) |>
  group_by(anio) |>
  summarise(ocupados = n(),
            coincidencia_informal_pct = 100 * mean(empleo_informal == empleo_informal_oficial),
            coincidencia_sector_pct = 100 * mean(empleo_sector_informal == empleo_sector_informal_oficial),
            tasa_informal_oficial = 100 * media_pond(empleo_informal_oficial, fac500a),
            tasa_informal_reconstruida = 100 * media_pond(empleo_informal, fac500a),
            tasa_sector_oficial = 100 * media_pond(empleo_sector_informal_oficial, fac500a),
            tasa_sector_reconstruida = 100 * media_pond(empleo_sector_informal, fac500a),
            .groups = "drop") |>
  mutate(across(where(is.double), ~ round(.x, 2)))
write_csv(val, file.path(PROCESADO, "validacion_informalidad.csv"))
print(as.data.frame(val))

per <- per |>
  transmute(anio, mes, conglome, vivienda, hogar, codperso, ubigeo, dpto, area, estrato, dominio,
            fac500a, edad = as.integer(p208a),
            tipoentrevista, tipocuestionario, cuestionario_reducido,
            condicion_actividad = as.integer(ocu500), pea, ocupado,
            horas_principal, horas_total,
            ingreso_laboral_nominal, i00, ld, ingreso_laboral_real, ingreso_hora_real,
            ciiu4, ciiu4_division, ciiu4_seccion, mineria_metalifera,
            categoria_ocupacional,
            empleo_informal, empleo_sector_informal, afiliado_pension, seguro_salud_empleo,
            empleo_informal_oficial, empleo_sector_informal_oficial)

saveRDS(per, file.path(PROCESADO, "personas_tmp.rds"))

per |>
  group_by(anio) |>
  summarise(pet = n(),
            tasa_actividad = 100 * media_pond(pea, fac500a),
            tasa_ocupacion = 100 * media_pond(ocupado, fac500a),
            ingreso_laboral_real = media_pond(ingreso_laboral_real, fac500a),
            horas_total = media_pond(horas_total, fac500a),
            informal = 100 * media_pond(empleo_informal, fac500a),
            mineria_metalifera = 100 * media_pond(mineria_metalifera, fac500a),
            .groups = "drop") |>
  as.data.frame() |> print(digits = 4)
