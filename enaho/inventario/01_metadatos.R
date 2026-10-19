# 01_metadatos.R (inventario)
# Lista, para cada año y archivo de datos, todas las variables con su etiqueta
# y sus etiquetas de valores. No carga las observaciones.
#
# Uso: Rscript enaho/inventario/01_metadatos.R
# Salida: enaho/inventario/variables_por_anio.csv

suppressPackageStartupMessages({ library(haven); library(dplyr); library(readr) })

cache <- "enaho/cache"

# Archivo principal de cada módulo (se excluyen tablas auxiliares)
patrones <- c(
  m100     = "^enaho01-\\d{4}-100\\.dta$",
  m200     = "^enaho01-\\d{4}-200\\.dta$",
  m400     = "^enaho01a-\\d{4}-400\\.dta$",
  m500     = "^enaho01a-\\d{4}[-_]500\\.dta$",
  sumaria  = "^sumaria-\\d{4}\\.dta$",
  sum12g   = "^sumaria-\\d{4}-12g?\\.dta$"
)

etiquetas_valor <- function(x) {
  l <- attr(x, "labels")
  if (is.null(l)) return(NA_character_)
  paste0(unname(l), "=", names(l), collapse = "; ")
}

filas <- list()
for (anio in 2014:2025) {
  archivos <- list.files(file.path(cache, anio), pattern = "\\.dta$",
                         recursive = TRUE, full.names = TRUE)
  for (mod in names(patrones)) {
    sel <- archivos[grepl(patrones[[mod]], basename(archivos), ignore.case = TRUE)]
    for (f in sel) {
      d <- read_dta(f, n_max = 0)
      filas[[length(filas) + 1]] <- tibble(
        anio = anio, modulo = mod, archivo = basename(f),
        variable = names(d),
        variable_min = tolower(names(d)),
        etiqueta = vapply(d, function(x) { e <- attr(x, "label"); if (is.null(e)) NA_character_ else e }, ""),
        clase = vapply(d, function(x) class(x)[length(class(x))], ""),
        etiquetas_valor = vapply(d, etiquetas_valor, "")
      )
    }
  }
}

meta <- bind_rows(filas)
write_csv(meta, "enaho/inventario/variables_por_anio.csv")
print(meta |> count(anio, modulo, archivo), n = 100)
