# 01_descarga.R
# Descarga de Yahoo Finance la serie del oro GC=F (futuros de oro COMEX,
# contrato continuo del mes más cercano, US$ por onza troy), diaria y mensual,
# desde el 1 de enero de 2014 hasta la fecha de descarga. Las respuestas se
# guardan sin modificar (JSON de la API de gráficos de Yahoo).
#
# Uso (desde la raíz del repositorio): Rscript precio_oro/01_descarga.R
# Salidas:
#   precio_oro/datos_brutos/yahoo_GC=F_1d.json   (precios diarios)
#   precio_oro/datos_brutos/yahoo_GC=F_1mo.json  (barras mensuales de Yahoo)
#   precio_oro/datos_brutos/registro_descargas.csv (URL, fecha, tamaño y MD5)

options(timeout = 300)

dir_brutos <- "precio_oro/datos_brutos"
dir.create(dir_brutos, recursive = TRUE, showWarnings = FALSE)

simbolo <- "GC=F"
desde <- as.numeric(as.POSIXct("2014-01-01", tz = "UTC"))
hasta <- as.numeric(Sys.time())
agente <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

registro <- list()
for (intervalo in c("1d", "1mo")) {
  url <- sprintf("https://query1.finance.yahoo.com/v8/finance/chart/%s?period1=%.0f&period2=%.0f&interval=%s",
                 URLencode(simbolo, reserved = TRUE), desde, hasta, intervalo)
  destino <- file.path(dir_brutos, sprintf("yahoo_%s_%s.json", simbolo, intervalo))
  download.file(url, destino, mode = "wb", quiet = TRUE, headers = c("User-Agent" = agente))
  # Verificación mínima: la respuesta debe traer datos y no un error
  j <- jsonlite::fromJSON(destino)
  if (is.null(j$chart$result) || !is.null(j$chart$error))
    stop("Yahoo no devolvió datos para ", url)
  registro[[intervalo]] <- data.frame(
    archivo = basename(destino), url = url,
    fecha_descarga_utc = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    bytes = file.size(destino), md5 = unname(tools::md5sum(destino))
  )
  cat("Descargado", basename(destino), "\n")
}

write.csv(do.call(rbind, registro), file.path(dir_brutos, "registro_descargas.csv"), row.names = FALSE)
