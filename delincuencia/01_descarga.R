# 01_descarga.R
# Descarga, sin modificarlos, los módulos necesarios para los indicadores de
# delincuencia desde el portal de microdatos del INEI
# (https://proyectos.inei.gob.pe/microdatos/):
#
#   ENAPRES (Encuesta Nacional de Programas Presupuestales), periodo anual,
#   formato SPSS: capítulo 100 (vivienda y hogar), 200 (residentes) y el
#   capítulo de seguridad ciudadana (600 en 2014-2024, 400 en 2025).
#
#   ENAHO (metodología actualizada, anual), formato STATA: módulo 85
#   (Gobernabilidad, Democracia y Transparencia). Los demás módulos de la ENAHO
#   ya están en enaho/datos_brutos/ y no se vuelven a descargar.
#
# Códigos de encuesta y de módulo consultados en el portal el 03/11/2026
# (Consulta por encuesta -> año -> periodo "Anual").
#
# Uso (desde la raíz del repositorio): Rscript delincuencia/01_descarga.R
# Salidas:
#   delincuencia/datos_brutos/<enapres|enaho>/<año>/<código>-Modulo<NNN>.zip
#   delincuencia/datos_brutos/registro_descargas.csv

options(timeout = 1800)
base_url <- "https://proyectos.inei.gob.pe/iinei/srienaho/descarga"
raiz <- "delincuencia/datos_brutos"

enapres <- read.csv(text = "
anio,encuesta,cap100,cap200,cap_seguridad
2014,438,560,562,566
2015,495,699,700,703
2016,544,1073,1074,1077
2017,596,1235,1236,1239
2018,626,1370,1371,1374
2019,684,1490,1491,1494
2020,736,1618,1619,1622
2021,761,1675,1676,1679
2022,785,1727,1728,1731
2023,903,1815,1816,1819
2024,965,1856,1857,1860
2025,1030,2071,2072,2074")

enaho <- c("2014" = 440, "2015" = 498, "2016" = 546, "2017" = 603, "2018" = 634,
           "2019" = 687, "2020" = 737, "2021" = 759, "2022" = 784, "2023" = 906,
           "2024" = 966, "2025" = 1031)

pedidos <- rbind(
  do.call(rbind, lapply(seq_len(nrow(enapres)), function(i) {
    r <- enapres[i, ]
    data.frame(encuesta = "enapres", anio = r$anio, codigo = r$encuesta, formato = "SPSS",
               modulo = c(r$cap100, r$cap200, r$cap_seguridad),
               contenido = c("Capítulo 100: vivienda y hogar", "Capítulo 200: residentes",
                             ifelse(r$anio == 2025, "Capítulo 400: seguridad ciudadana",
                                    "Capítulo 600: seguridad ciudadana")))
  })),
  data.frame(encuesta = "enaho", anio = as.integer(names(enaho)), codigo = unname(enaho),
             formato = "STATA", modulo = "85",
             contenido = "Módulo 85: Gobernabilidad, Democracia y Transparencia")
)

registro <- list()
for (i in seq_len(nrow(pedidos))) {
  p <- pedidos[i, ]
  archivo <- sprintf("%d-Modulo%s.zip", p$codigo, p$modulo)
  dir_destino <- file.path(raiz, p$encuesta, p$anio)
  dir.create(dir_destino, recursive = TRUE, showWarnings = FALSE)
  destino <- file.path(dir_destino, archivo)
  url <- file.path(base_url, p$formato, archivo)
  if (!file.exists(destino)) {
    tmp <- paste0(destino, ".part")
    download.file(url, tmp, mode = "wb", quiet = TRUE)
    if (length(unzip(tmp, list = TRUE)$Name) == 0) stop("Respuesta no válida: ", url)
    file.rename(tmp, destino)
    fecha <- format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC")
  } else {
    fecha <- format(file.mtime(destino), "%Y-%m-%d %H:%M:%S", tz = "UTC")
  }
  registro[[i]] <- data.frame(p, archivo = file.path(p$encuesta, p$anio, archivo), url = url,
                              fecha_descarga_utc = fecha, bytes = file.size(destino),
                              md5 = unname(tools::md5sum(destino)))
  cat(p$encuesta, p$anio, "módulo", p$modulo, "listo\n")
}
registro <- do.call(rbind, registro)
write.csv(registro, file.path(raiz, "registro_descargas.csv"), row.names = FALSE)
cat("\nArchivos:", nrow(registro), "| total:", round(sum(registro$bytes) / 1e6), "MB\n")
