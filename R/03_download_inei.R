# 03_download_inei.R ----------------------------------------------------------
# Insumos del INEI: RENAMU, ENAHO, población censal, SIRTOD y la serie de
# validación de Demografía Empresarial.

if (!exists("PROJ")) source("R/00_setup.R")

# RENAMU -----------------------------------------------------------------------
# Censo anual de municipalidades (2011-2025). Doble rol:
#   (i)  licencias de funcionamiento = medida alternativa de entrada empresarial
#   (ii) costos/tiempos de trámite  = control institucional distrito-año
URLS_RENAMU <- c(
  "2025" = "https://www.datosabiertos.gob.pe/dataset/registro-nacional-de-municipalidades-renamu-2025-instituto-nacional-de-estad%C3%ADstica-e",
  "2024" = "https://datosabiertos.gob.pe/dataset/registro-nacional-de-municipalidades-renamu-2024-instituto-nacional-de-estad%C3%ADstica-e-0",
  "2023" = "https://www.datosabiertos.gob.pe/dataset/registro-nacional-de-municipalidades-renamu-2023-instituto-nacional-de-estad%C3%ADstica-e",
  "2022" = "https://www.datosabiertos.gob.pe/dataset/registro-nacional-de-municipalidades-renamu-2022-instituto-nacional-de-estad%C3%ADstica-e",
  "2020" = "https://www.datosabiertos.gob.pe/dataset/registro-nacional-de-municipalidades-renamu-2020-instituto-nacional-de-estad%C3%ADstica-e",
  "2019" = "https://www.datosabiertos.gob.pe/dataset/registro-nacional-de-municipalidades-renamu-2019-instituto-nacional-de-estad%C3%ADstica-e",
  "2018" = "https://datosabiertos.gob.pe/dataset/registro-nacional-de-municipalidades-renamu-2018-instituto-nacional-de-estad%C3%ADstica-e"
)

# Las páginas de datosabiertos.gob.pe (CKAN) enlazan los recursos; se extraen
# los enlaces directos en vez de codificarlos fijos.
enlaces_recursos <- function(url_dataset) {
  pagina <- rvest::read_html(url_dataset)
  hrefs  <- rvest::html_attr(rvest::html_elements(pagina, "a"), "href")
  grep("\\.(zip|csv|xlsx|rar)$", hrefs, value = TRUE, ignore.case = TRUE)
}

descargar_renamu <- function(anios = names(URLS_RENAMU)) {
  destino <- file.path(DIR_RAW, "renamu"); dir.create(destino, showWarnings = FALSE)
  for (a in anios) {
    message("RENAMU ", a, " ...")
    recursos <- tryCatch(enlaces_recursos(URLS_RENAMU[[a]]),
                         error = function(e) { message("  falló: ", conditionMessage(e)); character(0) })
    for (r in recursos) {
      f <- file.path(destino, paste0("renamu_", a, "_", basename(r)))
      if (!file.exists(f)) try(utils::download.file(r, f, mode = "wb", quiet = TRUE), silent = TRUE)
    }
  }
}

# ENAHO ------------------------------------------------------------------------
# Bloque secundario de informalidad. Módulo de empleo e ingresos (módulo 500).
# Los microdatos se descargan desde el portal; no hay API estable.
URL_MICRODATOS <- "https://proyectos.inei.gob.pe/microdatos/"
URL_ANDA       <- "https://webinei.inei.gob.pe/anda_inei/"

# La definición operativa de empleo informal debe seguir el criterio del INEI/MTPE:
#   https://www2.trabajo.gob.pe/empleo-informal-segun-enaho/
construir_informalidad <- function(dir_enaho) {
  archivos <- list.files(dir_enaho, pattern = "\\.sav$", recursive = TRUE, full.names = TRUE)
  if (length(archivos) == 0) {
    stop("Sin microdatos ENAHO en ", dir_enaho, "\nDescargar desde: ", URL_MICRODATOS)
  }
  res <- lapply(archivos, function(f) {
    x <- haven::read_sav(f)
    x <- janitor::clean_names(x)
    # TODO: aplicar la definición de informalidad del INEI y el factor de
    # expansión (variable de ponderación) antes de agregar por departamento.
    x
  })
  res
}

# Población distrital ----------------------------------------------------------
# Denominador del panel. Censos 2017 + proyecciones.
URL_CENSOS <- "https://www.inei.gob.pe/estadisticas/censos/"
URL_SIRTOD <- "https://systems.inei.gob.pe/SIRTOD/"

# Validación externa -----------------------------------------------------------
# Demografía Empresarial: altas y bajas trimestrales por departamento.
# Publicado en PDF; requiere transcripción manual a
# data/raw/inei_demografia_empresarial.csv con columnas:
#   departamento, anio, altas_inei
URL_DEMOGRAFIA <- "https://www.gob.pe/institucion/inei/colecciones/6116-demografia-empresarial"

if (sys.nframe() == 0 || interactive()) {
  descargar_renamu()
  message("\nDescargas manuales pendientes:")
  message("  ENAHO (módulo empleo):  ", URL_MICRODATOS)
  message("  Población distrital:    ", URL_SIRTOD)
  message("  Demografía Empresarial: ", URL_DEMOGRAFIA)
}
