# 02_extraer.R
# Extrae los zips de enaho/datos_brutos/<año>/ en enaho/cache/<año>/, incluido el
# zip anidado del módulo 34 que trae los deflactores. Los zips originales no se
# modifican. enaho/cache/ es una copia de trabajo y no se versiona.
#
# Uso (desde la raíz del repositorio): Rscript enaho/02_extraer.R

source("enaho/funciones.R")

for (anio in ANIOS) {
  destino <- file.path(CACHE, anio)
  dir.create(destino, recursive = TRUE, showWarnings = FALSE)
  zips <- list.files(file.path("enaho/datos_brutos", anio), pattern = "\\.zip$", full.names = TRUE)
  if (length(zips) == 0) stop("No hay zips para ", anio, ": corra antes 01_descarga.R")
  for (z in zips) {
    sub <- file.path(destino, sub("\\.zip$", "", basename(z)))
    if (!dir.exists(sub)) unzip(z, exdir = sub, junkpaths = TRUE)
  }
  for (z in list.files(destino, pattern = "^ConstVarGasto.*\\.zip$", recursive = TRUE, full.names = TRUE)) {
    sub <- file.path(dirname(z), "ConstVarGasto")
    if (!dir.exists(sub)) unzip(z, exdir = sub, junkpaths = TRUE)
  }
  cat(anio, "extraído\n")
}
