# 02_extraer.R
# Extrae los zips de delincuencia/datos_brutos/ en delincuencia/cache/, una
# carpeta por archivo. Los zips originales no se modifican y cache/ no se versiona.
#
# Uso: Rscript delincuencia/02_extraer.R

zips <- list.files("delincuencia/datos_brutos", pattern = "\\.zip$", recursive = TRUE, full.names = TRUE)
if (length(zips) == 0) stop("No hay zips: corra antes 01_descarga.R")
for (z in zips) {
  rel <- sub("^delincuencia/datos_brutos/", "", sub("\\.zip$", "", z))   # enapres/2024/965-Modulo1860
  destino <- file.path("delincuencia/cache", rel)
  if (!dir.exists(destino)) unzip(z, exdir = destino, junkpaths = TRUE)
}
cat("Extraídos", length(zips), "archivos\n")
