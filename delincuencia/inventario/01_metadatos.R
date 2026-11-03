# 01_metadatos.R (inventario)
# Nombre, etiqueta y etiquetas de valores de todas las variables de los
# archivos de datos descargados (ENAPRES caps. 100, 200 y seguridad ciudadana;
# ENAHO módulo 85), por año. No carga observaciones.
#
# Uso: Rscript delincuencia/inventario/01_metadatos.R
# Salida: delincuencia/inventario/variables_por_anio.csv

suppressPackageStartupMessages({ library(haven); library(dplyr); library(readr) })

etq_valor <- function(x) {
  l <- attr(x, "labels")
  if (is.null(l)) return(NA_character_)
  paste0(unname(l), "=", names(l), collapse = "; ")
}
archivos <- list.files("delincuencia/cache", pattern = "\\.(sav|dta)$", recursive = TRUE, full.names = TRUE)
meta <- lapply(archivos, function(f) {
  partes <- strsplit(sub("^delincuencia/cache/", "", f), "/")[[1]]
  # Algunos .dta declaran una codificación distinta de la que usan: se reintenta en latin1
  d <- if (grepl("\\.sav$", f)) read_sav(f, n_max = 0) else
    tryCatch(read_dta(f, n_max = 0), error = function(e) read_dta(f, n_max = 0, encoding = "latin1"))
  modulo <- case_when(
    partes[1] == "enaho" & grepl("-1\\.dta$", f) ~ "enaho_m85_1",
    partes[1] == "enaho" & grepl("-2\\.dta$", f) ~ "enaho_m85_2",
    grepl("CAP_?100", basename(f)) ~ "enapres_cap100",
    grepl("CAP_?200", basename(f)) ~ "enapres_cap200",
    TRUE ~ "enapres_seguridad")
  tibble(encuesta = partes[1], anio = as.integer(partes[2]), modulo = modulo, archivo = basename(f),
         variable = names(d), variable_min = tolower(names(d)),
         etiqueta = vapply(d, function(x) { e <- attr(x, "label"); if (is.null(e)) NA_character_ else e }, ""),
         etiquetas_valor = vapply(d, etq_valor, ""))
}) |> bind_rows()
write_csv(meta, "delincuencia/inventario/variables_por_anio.csv")
print(meta |> count(encuesta, modulo, anio) |> tidyr::pivot_wider(names_from = anio, values_from = n) |> as.data.frame())
