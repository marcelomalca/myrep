# 02_download_mef.R -----------------------------------------------------------
# Proyectos de inversión vial: define las COHORTES DE ADOPCIÓN del DiD.
#
# Dos registros a unificar:
#   - SNIP        (2000-2016)
#   - Invierte.pe (2017 en adelante)
# Cuidado con los proyectos que cruzaron la transición de 2017: aparecen en
# ambos sistemas con códigos distintos y se duplican si no se deduplican.

if (!exists("PROJ")) source("R/00_setup.R")

URL_CONSULTA_INV <- "https://ofi5.mef.gob.pe/invierte/consultapublica/consultainversiones"
URL_MEF_INVPUB   <- "https://www.mef.gob.pe/es/inversion-publica-sp-21787"

# El portal del MEF no expone una API pública documentada y estable. La ruta
# práctica es exportar desde la consulta pública filtrando por:
#   Función      : 15 - TRANSPORTE
#   División     : 033 - TRANSPORTE TERRESTRE
#   Estado       : incluir cerrados/liquidados para tener fecha de culminación
# y guardar el export en data/raw/.
#
# Si consigues acceso programático, implementa la descarga en esta función.

ARCHIVOS_ESPERADOS <- c(
  invierte = "mef_invierte_transporte.xlsx",
  snip     = "mef_snip_transporte.xlsx"
)

verificar_insumos <- function() {
  faltan <- ARCHIVOS_ESPERADOS[!file.exists(file.path(DIR_RAW, ARCHIVOS_ESPERADOS))]
  if (length(faltan) > 0) {
    stop(
      "Faltan exports del MEF en ", DIR_RAW, ":\n  ",
      paste(faltan, collapse = "\n  "),
      "\n\nExporta desde:\n  ", URL_CONSULTA_INV,
      "\nFiltro: Función 15 TRANSPORTE / División 033 TRANSPORTE TERRESTRE."
    )
  }
  invisible(TRUE)
}

# Normalización ----------------------------------------------------------------
# Los dos sistemas usan nombres de columna distintos. Se mapean a un esquema común.

normalizar_proyectos <- function(df, sistema) {
  d <- janitor::clean_names(df)

  col <- function(patron) {
    hit <- grep(patron, names(d), value = TRUE)[1]
    if (is.na(hit)) NA_character_ else hit
  }

  c_cod   <- col("codigo|cod_unico|cui|snip")
  c_nom   <- col("nombre|denominacion")
  c_ubi   <- col("ubigeo")
  c_dist  <- col("distrito")
  c_prov  <- col("provincia")
  c_dep   <- col("departamento|region")
  c_monto <- col("monto|costo|viable|actualizado")
  c_fini  <- col("fecha_inicio|inicio_ejec")
  c_ffin  <- col("fecha_termino|culmin|cierre|fin_ejec|liquidacion")

  stopifnot(!is.na(c_cod), !is.na(c_monto))

  data.table::data.table(
    sistema      = sistema,
    codigo       = as.character(d[[c_cod]]),
    nombre       = if (!is.na(c_nom))  as.character(d[[c_nom]])  else NA_character_,
    ubigeo       = if (!is.na(c_ubi))  sprintf("%06s", as.character(d[[c_ubi]])) else NA_character_,
    distrito     = if (!is.na(c_dist)) as.character(d[[c_dist]]) else NA_character_,
    provincia    = if (!is.na(c_prov)) as.character(d[[c_prov]]) else NA_character_,
    departamento = if (!is.na(c_dep))  as.character(d[[c_dep]])  else NA_character_,
    monto        = suppressWarnings(as.numeric(d[[c_monto]])),
    fecha_inicio = if (!is.na(c_fini)) lubridate::as_date(d[[c_fini]]) else as.Date(NA),
    fecha_fin    = if (!is.na(c_ffin)) lubridate::as_date(d[[c_ffin]]) else as.Date(NA)
  )
}

# Deduplicación entre SNIP e Invierte.pe ---------------------------------------
# Heurística: mismo ubigeo + nombre muy similar => mismo proyecto. Se conserva
# el registro de Invierte.pe (más completo en fechas de cierre).

deduplicar <- function(dt) {
  dt[, clave := paste0(ubigeo, "_", substr(toupper(gsub("[^A-Z]", "", toupper(nombre))), 1, 40))]
  data.table::setorder(dt, clave, -sistema)   # "invierte" > "snip" alfabéticamente inverso
  dt_unico <- dt[!duplicated(clave)]
  message("Deduplicación: ", nrow(dt), " -> ", nrow(dt_unico), " proyectos.")
  dt_unico[, clave := NULL][]
}

if (sys.nframe() == 0 || interactive()) {
  verificar_insumos()

  inv  <- normalizar_proyectos(readxl::read_excel(file.path(DIR_RAW, ARCHIVOS_ESPERADOS["invierte"])), "invierte")
  snip <- normalizar_proyectos(readxl::read_excel(file.path(DIR_RAW, ARCHIVOS_ESPERADOS["snip"])),     "snip")

  proyectos <- deduplicar(data.table::rbindlist(list(inv, snip), fill = TRUE))

  # Diagnóstico de cobertura: cuántos proyectos tienen fecha de culminación.
  cat("\nProyectos sin fecha de fin: ",
      sum(is.na(proyectos$fecha_fin)), " de ", nrow(proyectos), "\n", sep = "")
  cat("Proyectos sin ubigeo: ",
      sum(is.na(proyectos$ubigeo)), "\n", sep = "")

  saveRDS(proyectos, file.path(DIR_INT, "mef_proyectos_viales.rds"))
  message("Guardado: ", file.path(DIR_INT, "mef_proyectos_viales.rds"))
}
