# 01_descarga.R
# Descarga los módulos de la ENAHO (metodología actualizada, anual) desde el
# portal de microdatos del INEI, en formato STATA, sin modificarlos.
#
# Uso (desde la raíz del repositorio):
#   Rscript enaho/01_descarga.R
#
# Salida:
#   enaho/datos_brutos/<año>/<código>-Modulo<NN>.zip
#   enaho/datos_brutos/manifiesto_descargas.csv  (tamaño y MD5 de cada archivo)
#
# Los códigos de encuesta corresponden a "Condiciones de Vida y Pobreza - ENAHO",
# periodo "Anual - (Ene-Dic)", en la opción "ENAHO Metodología ACTUALIZADA" del
# portal https://proyectos.inei.gob.pe/microdatos/ (consultados el 19/10/2026).

options(timeout = 1800)

raiz    <- "enaho/datos_brutos"
base_url <- "https://proyectos.inei.gob.pe/iinei/srienaho/descarga/STATA"

codigos <- c(
  "2014" = 440,  "2015" = 498,  "2016" = 546,  "2017" = 603,
  "2018" = 634,  "2019" = 687,  "2020" = 737,  "2021" = 759,
  "2022" = 784,  "2023" = 906,  "2024" = 966,  "2025" = 1031
)

# 01 Características de la vivienda y del hogar
# 02 Características de los miembros del hogar
# 04 Salud (seguro de salud, componente de la informalidad)
# 05 Empleo e ingresos
# 34 Sumarias (variables calculadas; incluye los deflactores)
modulos <- c("01", "02", "04", "05", "34")

dir.create(raiz, recursive = TRUE, showWarnings = FALSE)
registro <- list()

for (anio in names(codigos)) {
  dir_anio <- file.path(raiz, anio)
  dir.create(dir_anio, showWarnings = FALSE)
  for (m in modulos) {
    archivo <- sprintf("%d-Modulo%s.zip", codigos[[anio]], m)
    destino <- file.path(dir_anio, archivo)
    if (!file.exists(destino)) {
      url <- file.path(base_url, archivo)
      tmp <- paste0(destino, ".part")
      ok <- tryCatch({
        download.file(url, tmp, mode = "wb", quiet = TRUE)
        TRUE
      }, error = function(e) { message("Error en ", url, ": ", conditionMessage(e)); FALSE })
      # Solo se acepta el archivo si es un zip válido
      if (ok && length(unzip(tmp, list = TRUE)$Name) > 0) {
        file.rename(tmp, destino)
      } else {
        unlink(tmp)
        stop("No se pudo descargar ", url)
      }
    }
    registro[[length(registro) + 1]] <- data.frame(
      anio = as.integer(anio), codigo_encuesta = codigos[[anio]], modulo = m,
      archivo = file.path(anio, archivo),
      bytes = file.size(destino),
      md5 = unname(tools::md5sum(destino))
    )
    cat(anio, "módulo", m, "listo\n")
  }
}

manifiesto <- do.call(rbind, registro)
write.csv(manifiesto, file.path(raiz, "manifiesto_descargas.csv"), row.names = FALSE)
cat("\nArchivos:", nrow(manifiesto), " Total:",
    round(sum(manifiesto$bytes) / 1e6), "MB\n")
