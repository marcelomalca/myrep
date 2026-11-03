# 02_mapa_enapres.R (inventario)
# Mapa auxiliar: variable de la ENAPRES por tipo de delito, pregunta y año,
# identificada por la redacción de su etiqueta.
#
# Uso: Rscript delincuencia/inventario/02_mapa_enapres.R
# Entrada: delincuencia/inventario/variables_por_anio.csv (de 01_metadatos.R)
# Salida:  delincuencia/inventario/mapa_enapres_variables.csv

suppressPackageStartupMessages({ library(dplyr); library(readr); library(stringr) })

m <- read_csv("delincuencia/inventario/variables_por_anio.csv", show_col_types = FALSE) |>
  filter(encuesta == "enapres", modulo == "enapres_seguridad")

norm <- function(t) {
  t <- iconv(t, "UTF-8", "ASCII//TRANSLIT", sub = "")
  str_squish(tolower(t))
}
tipo <- function(e) {
  t <- vapply(str_split(e, "victima (?:o testigo )?de:?|el ?/?las?:|del ?/?las?:"), function(x) x[length(x)], "")
  t <- str_remove_all(t, "[?¿]")
  t <- str_remove(t, "\\s*\\(.*")            # quita los ejemplos entre paréntesis
  str_sub(str_trim(str_remove_all(t, "^[ _-]+|[ _-]+$")), 1, 45)
}

s <- m |> mutate(e = norm(etiqueta))
preg <- list(
  victima    = function(e) str_detect(e, "ultimos 12 meses") & str_detect(e, "victima de") & !str_detect(e, "cuantas veces"),
  denuncio   = function(e) str_detect(e, "denuncio el"),
  arma_mano  = function(e) str_detect(e, "tipo de arma") & str_detect(e, "fuego de mano"),
  arma_largo = function(e) str_detect(e, "tipo de arma") & str_detect(e, "fuego largo"),
  percepcion = function(e) str_detect(e, "proximos 12 meses") & str_detect(e, "victima")
)
mapa <- bind_rows(lapply(names(preg), function(p) {
  x <- s[preg[[p]](s$e), ]
  if (!nrow(x)) return(NULL)
  t <- if (startsWith(p, "arma")) tipo(str_remove(x$e, ".*fuego (de mano|largo)[^_]*_?")) else tipo(x$e)
  tibble(anio = x$anio, pregunta = p, variable = x$variable, tipo = t)
})) |> arrange(anio, factor(pregunta, names(preg)))
write_csv(mapa, "delincuencia/inventario/mapa_enapres_variables.csv")
cat("Filas:", nrow(mapa), "\n"); print(count(mapa, anio, pregunta) |> tidyr::pivot_wider(names_from = pregunta, values_from = n))
