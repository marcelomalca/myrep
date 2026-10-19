# 02_cobertura.R (inventario)
# Cobertura distrital de la ENAHO 2014-2025: distritos, hogares y personas por
# distrito, y presencia de los distritos con yacimientos de oro anteriores a 2014.
#
# Uso: Rscript enaho/inventario/02_cobertura.R
# Salidas:
#   enaho/inventario/cobertura_anual.csv
#   enaho/inventario/cobertura_distrito_anio.csv
#   enaho/inventario/cobertura_oro_por_distrito.csv

suppressPackageStartupMessages({ library(haven); library(dplyr); library(readr); library(tidyr) })

cache <- "enaho/cache"
archivo <- function(anio, patron) {
  f <- list.files(file.path(cache, anio), pattern = patron, recursive = TRUE, full.names = TRUE)
  stopifnot(length(f) == 1)
  f
}

oro <- read_csv("datos/oro_por_distrito_pre2014.csv", col_types = cols(.default = "c")) |>
  transmute(ubigeo, yacimientos_oro = as.integer(yacimientos_oro))

por_distrito <- list()
for (anio in 2014:2025) {
  hog <- read_dta(archivo(anio, "^sumaria-\\d{4}\\.dta$"), col_select = c(ubigeo)) |>
    count(ubigeo, name = "hogares")
  # Residentes habituales (definición del INEI): miembros presentes, o no miembros
  # que viven en el hogar hace 30 días o más
  per <- read_dta(archivo(anio, "^enaho01-\\d{4}-200\\.dta$"),
                  col_select = c(ubigeo, p204, p205, p206)) |>
    filter((p204 == 1 & p205 == 2) | (p204 == 2 & p206 == 1)) |>
    count(ubigeo, name = "personas")
  por_distrito[[as.character(anio)]] <- full_join(hog, per, by = "ubigeo") |>
    mutate(anio = anio, .before = 1)
}
dist <- bind_rows(por_distrito) |>
  mutate(across(c(hogares, personas), ~ coalesce(.x, 0L)),
         distrito_oro = ubigeo %in% oro$ubigeo)

resumen <- dist |>
  group_by(anio) |>
  summarise(
    distritos = n_distinct(ubigeo),
    hogares_total = sum(hogares), personas_total = sum(personas),
    hog_min = min(hogares), hog_p25 = quantile(hogares, .25), hog_mediana = median(hogares),
    hog_media = round(mean(hogares), 1), hog_p75 = quantile(hogares, .75), hog_max = max(hogares),
    per_mediana = median(personas), per_media = round(mean(personas), 1),
    distritos_oro = sum(distrito_oro),
    hogares_oro = sum(hogares[distrito_oro]),
    hog_oro_mediana = median(hogares[distrito_oro]),
    hog_oro_min = min(hogares[distrito_oro]), hog_oro_max = max(hogares[distrito_oro]),
    personas_oro = sum(personas[distrito_oro]),
    .groups = "drop"
  )

# Para cada distrito con oro: en cuántos años aparece y con cuántos hogares
oro_cob <- oro |>
  left_join(dist |> select(anio, ubigeo, hogares), by = "ubigeo") |>
  group_by(ubigeo, yacimientos_oro) |>
  summarise(anios_en_muestra = sum(!is.na(anio)),
            hogares_total = sum(hogares, na.rm = TRUE),
            hogares_media_anio_presente = ifelse(anios_en_muestra > 0,
                                                 round(hogares_total / anios_en_muestra, 1), NA),
            .groups = "drop") |>
  arrange(desc(anios_en_muestra), desc(hogares_total))

write_csv(resumen, "enaho/inventario/cobertura_anual.csv")
write_csv(dist, "enaho/inventario/cobertura_distrito_anio.csv")
write_csv(oro_cob, "enaho/inventario/cobertura_oro_por_distrito.csv")

print(as.data.frame(resumen))
cat("\nDistritos distintos en 2014-2025:", n_distinct(dist$ubigeo), "\n")
cat("Distritos con oro (", nrow(oro), ") según años en muestra:\n")
print(table(oro_cob$anios_en_muestra))

# Ocupados y trabajadores de la división 07 (CIIU rev. 4) en los distritos con oro
emp <- list()
for (anio in 2014:2025) {
  d <- read_dta(archivo(anio, "^enaho01a-\\d{4}-500\\.dta$"),
                col_select = c(ubigeo, ocu500, p204, p205, p206, p506r4)) |>
    filter((p204 == 1 & p205 == 2) | (p204 == 2 & p206 == 1)) |>
    mutate(ocupado = ocu500 == 1,
           div07 = ocupado & floor(as.numeric(p506r4) / 100) == 7)
  g <- d |> filter(ubigeo %in% oro$ubigeo) |>
    group_by(ubigeo) |> summarise(pet = n(), ocup = sum(ocupado), d07 = sum(div07), .groups = "drop")
  emp[[length(emp) + 1]] <- tibble(
    anio = anio, distritos_oro = nrow(g), pet_mediana = median(g$pet),
    ocupados_mediana = median(g$ocup), ocupados_min = min(g$ocup),
    distritos_oro_con_trab_div07 = sum(g$d07 > 0),
    trab_div07_en_distritos_oro = sum(g$d07), trab_div07_pais = sum(d$div07))
}
emp <- bind_rows(emp)
write_csv(emp, "enaho/inventario/cobertura_oro_empleo.csv")
print(as.data.frame(emp))
