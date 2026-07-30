# 04_ubigeo_concordance.R -----------------------------------------------------
# Concordancia temporal de ubigeos.
#
# PROBLEMA: entre 2007 y 2025 se crearon y redefinieron distritos en el Perú.
# Un distrito nuevo aparece de la nada en el panel (falso "cero" en años previos)
# y su distrito madre muestra una caída artificial. Sin corregir esto, el DiD
# confunde reorganización administrativa con efecto de tratamiento.
#
# SOLUCIÓN: trabajar con "distritos armonizados" — unidades geográficas
# constantes en el tiempo. Cuando un distrito se escinde de otro, se agregan
# ambos bajo el ubigeo del distrito madre durante TODO el periodo.

if (!exists("PROJ")) source("R/00_setup.R")

# 1. Universo de ubigeos vigentes ----------------------------------------------
# Fuente recomendada: INEI (Censos 2017 / SIRTOD) o el padrón de ubigeos del RENIEC.
# Colocar en data/raw/ubigeos_inei.csv con columnas:
#   ubigeo, departamento, provincia, distrito, anio_creacion (si disponible)

cargar_ubigeos <- function() {
  f <- file.path(DIR_RAW, "ubigeos_inei.csv")
  if (!file.exists(f)) {
    stop("Falta ", f, "\nDescarga el padrón de ubigeos del INEI (SIRTOD: ",
         "https://systems.inei.gob.pe/SIRTOD/) y guárdalo con ese nombre.")
  }
  u <- data.table::fread(f, colClasses = list(character = "ubigeo"))
  u[, ubigeo := sprintf("%06s", ubigeo)]
  u[]
}

# 2. Tabla de escisiones -------------------------------------------------------
# Mapea ubigeo hijo -> ubigeo madre. DEBE COMPLETARSE consultando las leyes de
# creación de distritos (normas legales de El Peruano) para el periodo de estudio.
#
# Esta tabla es el insumo manual más importante del pipeline. Un error aquí se
# propaga a todos los resultados.

escisiones <- data.table::data.table(
  ubigeo_hijo  = character(),
  ubigeo_madre = character(),
  anio         = integer(),
  norma        = character()
)

# EJEMPLO de formato (reemplazar con los casos reales del periodo):
# escisiones <- data.table::rbindlist(list(escisiones, data.table::data.table(
#   ubigeo_hijo = "150142", ubigeo_madre = "150122",
#   anio = 2015L, norma = "Ley N° XXXXX"
# )))

# 3. Construcción del mapa armonizado ------------------------------------------
# Aplica las escisiones de forma transitiva: si C se escindió de B y B de A,
# entonces C -> A.

construir_mapa <- function(ubigeos, escis) {
  mapa <- data.table::data.table(
    ubigeo = ubigeos$ubigeo,
    ubigeo_arm = ubigeos$ubigeo
  )
  if (nrow(escis) == 0) {
    warning("La tabla de escisiones está vacía. El panel NO está armonizado. ",
            "Completa `escisiones` antes de estimar.")
    return(mapa)
  }

  cambio <- TRUE
  iter <- 0L
  while (cambio && iter < 20L) {
    antes <- data.table::copy(mapa$ubigeo_arm)
    mapa[escis, on = .(ubigeo_arm = ubigeo_hijo), ubigeo_arm := i.ubigeo_madre]
    cambio <- !identical(antes, mapa$ubigeo_arm)
    iter <- iter + 1L
  }
  if (iter >= 20L) warning("Posible ciclo en la tabla de escisiones.")

  message("Distritos originales: ", nrow(mapa),
          " | armonizados: ", data.table::uniqueN(mapa$ubigeo_arm))
  mapa[]
}

# 4. Utilidad de aplicación ----------------------------------------------------
armonizar <- function(dt, col_ubigeo = "ubigeo", mapa = NULL) {
  if (is.null(mapa)) mapa <- readRDS(file.path(DIR_PROC, "mapa_ubigeos.rds"))
  d <- data.table::as.data.table(dt)
  d[[col_ubigeo]] <- sprintf("%06s", as.character(d[[col_ubigeo]]))
  d <- merge(d, mapa, by.x = col_ubigeo, by.y = "ubigeo", all.x = TRUE)

  sin_match <- sum(is.na(d$ubigeo_arm))
  if (sin_match > 0) {
    warning(sin_match, " filas con ubigeo no reconocido (",
            round(100 * sin_match / nrow(d), 2), "%). Revisar antes de continuar.")
  }
  d[]
}

if (sys.nframe() == 0 || interactive()) {
  ubigeos <- cargar_ubigeos()
  mapa <- construir_mapa(ubigeos, escisiones)
  saveRDS(mapa, file.path(DIR_PROC, "mapa_ubigeos.rds"))
  message("Guardado: ", file.path(DIR_PROC, "mapa_ubigeos.rds"))
}
