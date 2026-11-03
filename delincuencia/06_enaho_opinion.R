# 06_enaho_opinion.R
# Base apilada de personas de la ENAHO 2014-2025 (módulo 85, archivo
# enaho01b-AAAA-1: Gobernabilidad, Democracia y Transparencia) con los
# indicadores de opinión aprobados en el inventario (decisiones D13 y D14).
#
# Universo: una persona de 18 años y más por hogar (la que cumplió años más
# recientemente), con respuesta al módulo y factor > 0.
# Factor: facgob07 (2014) y famiegob07 (2015-2025).
#
# Uso: Rscript delincuencia/06_enaho_opinion.R
# Salida: delincuencia/datos_procesados/enaho_opinion.{parquet,csv}

source("delincuencia/funciones.R")

op <- bind_rows(lapply(ANIOS, function(anio) {
  d <- leer_dta(archivo("enaho", anio, PAT_ENAHO_OPINION),
                c("mes", "conglome", "vivienda", "hogar", "codperso", "ubigeo", "estrato", "p208_01",
                  "facgob07", "famiegob07", "p1_06", "p2_1_04", "p2_1_15", "tipocuestionario"))
  stopifnot(all(d$p1_06 %in% c(1:5, NA)), all(d$p2_1_15 %in% c(0, 15, NA)), all(d$p2_1_04 %in% c(0, 4, NA)))
  peso <- if (anio == 2014) d$facgob07 else d$famiegob07
  tipo <- if ("tipocuestionario" %in% names(d)) as.integer(d$tipocuestionario) else rep(NA_integer_, nrow(d))
  tibble(
    anio = as.integer(anio), mes = as.integer(d$mes),
    conglome = formatC(as.integer(d$conglome), width = 6, flag = "0"),
    vivienda = formatC(as.integer(d$vivienda), width = 3, flag = "0"),
    hogar = formatC(as.integer(d$hogar), width = 2, flag = "0"),
    codperso = formatC(as.integer(d$codperso), width = 2, flag = "0"),
    ubigeo = formatC(as.integer(d$ubigeo), width = 6, flag = "0"),
    area = ifelse(as.integer(d$estrato) <= 5, 1L, 2L),
    edad = as.integer(d$p208_01),
    factor = as.numeric(peso),
    # Menciona la delincuencia entre los principales problemas del país
    delincuencia_problema = ifelse(is.na(d$p2_1_15), NA_integer_, as.integer(d$p2_1_15 == 15)),
    # Menciona la delincuencia o la falta de seguridad ciudadana
    inseguridad_problema = ifelse(is.na(d$p2_1_15) & is.na(d$p2_1_04), NA_integer_,
                                  as.integer(d$p2_1_15 %in% 15 | d$p2_1_04 %in% 4)),
    # Confía en la Policía Nacional: suficiente (3) o bastante (4); "no sabe" (5) cuenta como no
    confia_pnp = ifelse(is.na(d$p1_06), NA_integer_, as.integer(d$p1_06 %in% 3:4)),
    cuestionario_reducido = ifelse(is.na(tipo), 0L, as.integer(tipo == 1))
  )
}))

antes <- nrow(op)
op <- op |> filter(!is.na(factor), factor > 0, !(is.na(confia_pnp) & is.na(delincuencia_problema))) |>
  mutate(ubigeo_base = a_base(ubigeo)) |> relocate(ubigeo_base, .after = ubigeo)
cat("Filas descartadas (sin respuesta al módulo o sin factor):", antes - nrow(op), "\n")

llave_unica(op, c("anio", "conglome", "vivienda", "hogar"), "ENAHO opinión")
guardar(op, "enaho_opinion")

print(as.data.frame(op |> group_by(anio) |> summarise(
  n = n(),
  delincuencia_problema = 100 * media_pond(delincuencia_problema, factor),
  inseguridad_problema = 100 * media_pond(inseguridad_problema, factor),
  confia_pnp = 100 * media_pond(confia_pnp, factor), .groups = "drop") |>
  mutate(across(where(is.double), ~ round(.x, 1)))))
