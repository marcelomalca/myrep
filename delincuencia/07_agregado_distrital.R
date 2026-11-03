# 07_agregado_distrital.R
# Base distrito-año (ubigeo_base × año) con la proporción ponderada de cada
# indicador, el número de observaciones sin ponderar que la sustentan y la suma
# de factores de expansión (decisión D16). No se suaviza ni se fija un mínimo de
# observaciones: el usuario decide con n_<indicador>.
#
# Proporciones de 0 a 1 (no porcentajes), como en enaho/datos_procesados/distrito_anio.
# Un distrito-año sin observaciones para un indicador tiene el indicador vacío y n = 0.
#
# Uso: Rscript delincuencia/07_agregado_distrital.R
# Salida: delincuencia/datos_procesados/distrito_anio.{parquet,csv}

source("delincuencia/funciones.R")

leer_base <- function(nombre) arrow::read_parquet(file.path(PROCESADO, paste0(nombre, ".parquet")))

# Para cada indicador: proporción ponderada, n y suma de factores
agregar <- function(d, indicadores, peso) {
  d |> group_by(ubigeo_base, anio) |>
    summarise(across(all_of(indicadores), list(
      v = ~ media_pond(.x, .data[[peso]]),
      n = ~ sum(!is.na(.x)),
      peso = ~ sum(.data[[peso]][!is.na(.x)])
    ), .names = "{.col}__{.fn}"), .groups = "drop")
}

per <- leer_base("enapres_personas")
ind_per <- c("victima_comun", "victima_completa", "robo_dinero", "robo_vehiculo", "amenazas",
             "extorsion", "extorsion_o_intento", "estafa", "robo_negocio", "ofensas_sexuales",
             "arma_fuego", "denuncio")
a_per <- agregar(per, ind_per, "factor") |>
  full_join(agregar(per, c("percepcion", "percepcion_general_2025"), "factor_percepcion"),
            by = c("ubigeo_base", "anio")) |>
  full_join(per |> group_by(ubigeo_base, anio) |>
              summarise(prop_enapres_telefonica = if (all(is.na(modalidad))) NA_real_ else mean(modalidad == 2, na.rm = TRUE),
                        .groups = "drop"), by = c("ubigeo_base", "anio"))

a_viv <- agregar(leer_base("enapres_hogares"), "robo_vivienda", "factor")

hog <- leer_base("enaho_hogares")
a_hog <- agregar(hog, "hecho_delictivo", "factor07") |>
  full_join(hog |> group_by(ubigeo_base, anio) |>
              summarise(prop_enaho_cuestionario_reducido = mean(cuestionario_reducido), .groups = "drop"),
            by = c("ubigeo_base", "anio"))

a_op <- agregar(leer_base("enaho_opinion"), c("delincuencia_problema", "inseguridad_problema", "confia_pnp"), "factor")

dist <- a_per |>
  full_join(a_viv, by = c("ubigeo_base", "anio")) |>
  full_join(a_hog, by = c("ubigeo_base", "anio")) |>
  full_join(a_op, by = c("ubigeo_base", "anio")) |>
  # Nombres: <indicador>, n_<indicador>, peso_<indicador>
  rename_with(~ sub("^(.*)__v$", "\\1", .x)) |>
  rename_with(~ sub("^(.*)__n$", "n_\\1", .x)) |>
  rename_with(~ sub("^(.*)__peso$", "peso_\\1", .x)) |>
  mutate(across(starts_with("n_"), ~ coalesce(as.integer(.x), 0L)),
         across(starts_with("peso_"), ~ coalesce(.x, 0))) |>
  arrange(ubigeo_base, anio)

stopifnot(!anyDuplicated(dist[c("ubigeo_base", "anio")]))
guardar(dist, "distrito_anio")

cat("\nDistritos (ubigeo_base) por año, total y con datos de cada fuente:\n")
print(as.data.frame(dist |> group_by(anio) |> summarise(
  distritos = n(), enapres_personas = sum(n_victima_completa > 0), enapres_hogares = sum(n_robo_vivienda > 0),
  enaho_hogares = sum(n_hecho_delictivo > 0), enaho_opinion = sum(n_confia_pnp > 0), .groups = "drop")))
