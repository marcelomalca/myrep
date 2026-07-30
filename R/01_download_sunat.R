# 01_download_sunat.R ---------------------------------------------------------
# Descarga e inspección del Padrón Reducido del RUC (SUNAT).
#
# ############################################################################
# # PASO BLOQUEANTE DEL PROYECTO                                             #
# ############################################################################
# El esquema real del padrón NO pudo verificarse durante el diseño porque la
# política de red del entorno de desarrollo bloquea sunat.gob.pe.
#
# Este script está escrito de forma DEFENSIVA: detecta el esquema en vez de
# asumirlo. Ejecútalo en una máquina con acceso abierto y revisa el reporte
# que imprime. De su resultado depende el periodo factible del panel.
# ############################################################################

if (!exists("PROJ")) source("R/00_setup.R")

URL_PADRON  <- "https://www.sunat.gob.pe/descargaPRR/mrc137_padron_reducido.html"
URL_ANEXOS  <- "https://www.sunat.gob.pe/descargaPRR/mrc137_padron_reducido.html"

# 1. Localizar el enlace vigente al .zip ---------------------------------------
# SUNAT versiona el archivo por fecha, así que el enlace se extrae de la página
# en vez de codificarse fijo.

obtener_enlaces_zip <- function(url = URL_PADRON) {
  pagina <- rvest::read_html(url)
  hrefs  <- rvest::html_attr(rvest::html_elements(pagina, "a"), "href")
  zips   <- grep("\\.zip$", hrefs, value = TRUE, ignore.case = TRUE)
  xml2::url_absolute(zips, url)
}

descargar <- function(url, destino) {
  if (file.exists(destino)) {
    message("Ya existe, se omite: ", basename(destino))
    return(invisible(destino))
  }
  message("Descargando ", basename(destino), " ...")
  utils::download.file(url, destino, mode = "wb", quiet = FALSE)
  invisible(destino)
}

# 2. Inspección del esquema ----------------------------------------------------
# Reporta qué campos trae realmente el archivo y, sobre todo, si hay alguna
# columna de fecha utilizable para reconstruir cohortes de nacimiento.

inspeccionar_padron <- function(ruta_archivo, n = 2000) {
  muestra <- data.table::fread(ruta_archivo, nrows = n, encoding = "Latin-1")
  campos  <- names(muestra)

  cat("\n=========== ESQUEMA DETECTADO ===========\n")
  cat("Columnas (", length(campos), "):\n", sep = "")
  print(campos)

  patron_fecha <- "fec|fch|inscrip|alta|inicio|activ"
  candidatas   <- grep(patron_fecha, campos, ignore.case = TRUE, value = TRUE)

  cat("\n--- Columnas candidatas a FECHA ---\n")
  if (length(candidatas) == 0) {
    cat("NINGUNA.\n\n")
    cat("=> ESCENARIO B: el padrón no permite panel retrospectivo.\n")
    cat("   Estrategia: acumular snapshots mensuales hacia adelante y/o\n")
    cat("   recuperar versiones pasadas vía web.archive.org.\n")
    cat("   Ajustar ANIO_INICIO en 00_setup.R en consecuencia.\n")
  } else {
    print(candidatas)
    for (cc in candidatas) {
      cat("\nEjemplos de", cc, ":\n")
      print(utils::head(unique(muestra[[cc]]), 10))
    }
    cat("\n=> ESCENARIO A: panel retrospectivo por cohortes de nacimiento viable.\n")
    cat("   ATENCION: cuantificar el sesgo de supervivencia contra la serie de\n")
    cat("   Demografia Empresarial del INEI antes de fijar ANIO_INICIO.\n")
  }

  patron_geo <- "ubigeo|distrito|provincia|departamento"
  cat("\n--- Columnas geográficas ---\n")
  print(grep(patron_geo, campos, ignore.case = TRUE, value = TRUE))

  cat("\n--- Columnas de actividad económica ---\n")
  print(grep("ciiu|activ", campos, ignore.case = TRUE, value = TRUE))

  cat("\n--- Columnas de estado ---\n")
  print(grep("estado|condic|tipo", campos, ignore.case = TRUE, value = TRUE))
  cat("=========================================\n\n")

  invisible(list(campos = campos, fechas = candidatas, muestra = muestra))
}

# 3. Ejecución -----------------------------------------------------------------
if (sys.nframe() == 0 || interactive()) {

  enlaces <- tryCatch(obtener_enlaces_zip(), error = function(e) {
    message("No se pudo leer la página de SUNAT: ", conditionMessage(e))
    message("Descarga el .zip manualmente desde:\n  ", URL_PADRON,
            "\ny colócalo en: ", DIR_RAW)
    character(0)
  })

  if (length(enlaces) > 0) {
    message("Enlaces encontrados:"); print(enlaces)
    for (u in enlaces) descargar(u, file.path(DIR_RAW, basename(u)))
  }

  zips <- list.files(DIR_RAW, pattern = "\\.zip$", full.names = TRUE)
  if (length(zips) == 0) {
    stop("No hay archivos .zip en ", DIR_RAW, ". Descárgalos manualmente y reejecuta.")
  }

  for (z in zips) utils::unzip(z, exdir = DIR_RAW)

  archivos <- list.files(DIR_RAW, pattern = "\\.(txt|csv)$",
                         full.names = TRUE, ignore.case = TRUE)
  if (length(archivos) == 0) stop("No se encontró archivo de datos tras descomprimir.")

  esquema <- inspeccionar_padron(archivos[1])

  saveRDS(esquema$campos, file.path(DIR_INT, "sunat_esquema.rds"))
  message("Esquema guardado en ", file.path(DIR_INT, "sunat_esquema.rds"))
  message("\nSIGUIENTE PASO: registra el resultado en docs/02-fuentes-datos.md ",
          "y ajusta ANIO_INICIO en R/00_setup.R.")
}
