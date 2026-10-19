# 00_extraer.R (inventario)
# Extrae los zips de enaho/datos_brutos/ en enaho/cache/<año>/ para poder
# leerlos. Los zips originales no se modifican. enaho/cache/ no se versiona.
#
# Uso (desde la raíz del repositorio):
#   Rscript enaho/inventario/00_extraer.R

raiz  <- "enaho/datos_brutos"
cache <- "enaho/cache"

for (anio in 2014:2025) {
  destino <- file.path(cache, anio)
  dir.create(destino, recursive = TRUE, showWarnings = FALSE)
  for (z in list.files(file.path(raiz, anio), pattern = "\\.zip$", full.names = TRUE)) {
    # Cada módulo en su propia carpeta para evitar choques de nombres
    sub <- file.path(destino, sub("\\.zip$", "", basename(z)))
    if (!dir.exists(sub)) unzip(z, exdir = sub, junkpaths = TRUE)
  }
  # Zips anidados (instrucciones y deflactores del gasto) dentro del módulo 34
  for (z in list.files(destino, pattern = "^ConstVarGasto.*\\.zip$",
                       recursive = TRUE, full.names = TRUE)) {
    sub <- file.path(dirname(z), "ConstVarGasto")
    if (!dir.exists(sub)) unzip(z, exdir = sub, junkpaths = TRUE)
  }
}

dta <- list.files(cache, pattern = "\\.dta$", recursive = TRUE, ignore.case = TRUE)
print(dta)
