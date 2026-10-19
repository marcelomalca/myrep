# ejecutar_todo.R
# Corre el flujo completo de la ENAHO, de la descarga a la verificación.
# Uso (desde la raíz del repositorio): Rscript enaho/ejecutar_todo.R
#
# Requisitos de R: haven, dplyr, tidyr, readr, sf, arrow.
# La descarga se omite para los archivos que ya existen en enaho/datos_brutos/.

scripts <- c("01_descarga.R", "02_extraer.R", "03_hogares.R", "04_personas.R",
             "05_geografia.R", "06_agregado_distrital.R", "07_verificacion.R")

for (s in scripts) {
  cat("\n==================== ", s, " ====================\n", sep = "")
  inicio <- Sys.time()
  status <- system2("Rscript", file.path("enaho", s))
  if (status != 0) stop("Falló ", s)
  cat("(", round(as.numeric(difftime(Sys.time(), inicio, units = "mins")), 1), " min)\n", sep = "")
}
cat("\nListo. Bases en enaho/datos_procesados/\n")
