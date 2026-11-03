# ejecutar_todo.R
# Corre el flujo completo de delincuencia, de la descarga a la verificación.
# Uso (desde la raíz del repositorio): Rscript delincuencia/ejecutar_todo.R
#
# Requisitos de R: haven, dplyr, tidyr, readr, jsonlite, arrow.
# Requiere además enaho/geografia/correspondencia_ubigeo.csv (de enaho/05_geografia.R)
# y datos/insumos/peru_distrital_simple.geojson.
# La descarga se omite para los archivos que ya existen en delincuencia/datos_brutos/.
# Los scripts del inventario (delincuencia/inventario/) no forman parte de este flujo.

scripts <- c("01_descarga.R", "02_extraer.R", "03_enapres_personas.R", "04_enapres_hogares.R",
             "05_enaho_hogares.R", "06_enaho_opinion.R", "07_agregado_distrital.R", "08_verificacion.R")

for (s in scripts) {
  cat("\n==================== ", s, " ====================\n", sep = "")
  inicio <- Sys.time()
  status <- system2("Rscript", file.path("delincuencia", s))
  if (status != 0) stop("Falló ", s)
  cat("(", round(as.numeric(difftime(Sys.time(), inicio, units = "mins")), 1), " min)\n", sep = "")
}
cat("\nListo. Bases en delincuencia/datos_procesados/\n")
