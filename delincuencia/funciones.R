# funciones.R
# Funciones y constantes compartidas por los scripts numerados de delincuencia/.
# No se ejecuta solo: cada script lo carga con source("delincuencia/funciones.R").
# Sigue las convenciones de enaho/funciones.R.

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
  library(tidyr)
  library(readr)
})

ANIOS     <- 2014:2025
CACHE     <- "delincuencia/cache"
PROCESADO <- "delincuencia/datos_procesados"
dir.create(PROCESADO, showWarnings = FALSE, recursive = TRUE)

# Ruta del archivo de una encuesta y año que cumple un patrón; falla si no hay exactamente uno
archivo <- function(encuesta, anio, patron) {
  f <- list.files(file.path(CACHE, encuesta, anio), pattern = patron, recursive = TRUE,
                  full.names = TRUE, ignore.case = TRUE)
  if (length(f) != 1) stop("Se esperaba un archivo para ", encuesta, " ", anio, " con ", patron,
                           " y se encontraron ", length(f), ": ", paste(f, collapse = ", "))
  f
}
PAT_ENAPRES_SEGURIDAD <- "^(07_)?CAP_(600|400)_.*\\.sav$"   # capítulo 600 (2014-2024) o 400 (2025)
PAT_ENAPRES_CAP100    <- "^(01_)?CAP_?100.*\\.sav$"
PAT_ENAHO_OPINION     <- "^enaho01b-\\d{4}-1\\.dta$"
PAT_ENAHO_HOGAR       <- "^enaho01b-\\d{4}-2\\.dta$"

# Lectura sin etiquetas haven, solo con las columnas pedidas que existan.
# Algunos .dta (ENAHO 2025) requieren latin1.
leer_sav <- function(f, columnas) zap_labels(zap_formats(read_sav(f, col_select = any_of(columnas))))
leer_dta <- function(f, columnas) {
  d <- tryCatch(read_dta(f, col_select = any_of(columnas)),
                error = function(e) read_dta(f, col_select = any_of(columnas), encoding = "latin1"))
  zap_labels(zap_formats(d))
}

# Identificadores como texto, tal como vienen en el archivo (sin rellenar)
como_id <- function(x) trimws(as.character(x))

# Ubigeo de 6 dígitos a partir de departamento, provincia y distrito (ENAPRES)
ubigeo_enapres <- function(ccdd, ccpp, ccdi) {
  sprintf("%02d%02d%02d", as.integer(ccdd), as.integer(ccpp), as.integer(ccdi))
}

# Distrito de 2014 (ubigeo_base) con la tabla construida para la ENAHO
# (enaho/geografia/correspondencia_ubigeo.csv). Un código que no está en la tabla
# debe existir en la capa distrital de 2014; si no, el script se detiene.
correspondencia <- read_csv("enaho/geografia/correspondencia_ubigeo.csv",
                            col_types = cols(.default = "c"))
capa_2014 <- local({
  g <- jsonlite::fromJSON("datos/insumos/peru_distrital_simple.geojson", simplifyVector = TRUE)
  g$features$properties$IDDIST
})
a_base <- function(ubigeo) {
  base <- correspondencia$ubigeo_base[match(ubigeo, correspondencia$ubigeo)]
  sin <- is.na(base) & !is.na(ubigeo)
  faltan <- setdiff(unique(ubigeo[sin]), capa_2014)
  if (length(faltan)) stop("Ubigeos sin correspondencia ni distrito de 2014: ", paste(faltan, collapse = ", "))
  ifelse(sin, ubigeo, base)
}

# Indicadora "al menos un 1" por fila; NA si todas las columnas están vacías
alguno <- function(m) {
  m <- as.matrix(m)
  if (ncol(m) == 0) return(rep(NA_integer_, nrow(m)))
  ifelse(rowSums(!is.na(m)) == 0, NA_integer_, as.integer(rowSums(m == 1, na.rm = TRUE) > 0))
}

# Promedio ponderado que ignora faltantes
media_pond <- function(x, w) {
  ok <- !is.na(x) & !is.na(w)
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}

# Escribe una base en parquet y csv
guardar <- function(d, nombre) {
  if (!requireNamespace("arrow", quietly = TRUE))
    stop("Falta el paquete 'arrow' (install.packages('arrow')) para escribir parquet")
  arrow::write_parquet(d, file.path(PROCESADO, paste0(nombre, ".parquet")))
  write_csv(d, file.path(PROCESADO, paste0(nombre, ".csv")), na = "")
  cat("Guardado", nombre, ":", nrow(d), "filas x", ncol(d), "columnas\n")
}

# Verifica que una llave sea única
llave_unica <- function(d, llave, nombre) {
  dup <- sum(duplicated(d[llave]))
  if (dup > 0) stop(nombre, ": ", dup, " filas duplicadas en la llave ", paste(llave, collapse = " + "))
  invisible(TRUE)
}
