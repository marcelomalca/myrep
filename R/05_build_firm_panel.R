# 05_build_firm_panel.R -------------------------------------------------------
# Construye el panel distrito-año de creación de empresas formales.
#
# Depende del ESCENARIO detectado en 01_download_sunat.R:
#   A) el padrón trae fecha de inscripción -> cohortes retrospectivas
#   B) no la trae -> diferencias entre snapshots consecutivos

if (!exists("PROJ")) source("R/00_setup.R")
source("R/04_ubigeo_concordance.R")

# --- Escenario A: cohortes de nacimiento desde un snapshot --------------------
altas_desde_fecha <- function(padron, col_fecha, col_ubigeo, col_ciiu) {
  d <- data.table::as.data.table(padron)
  d[, anio := lubridate::year(lubridate::as_date(get(col_fecha)))]
  d <- d[anio >= ANIO_INICIO & anio <= ANIO_FIN]
  d <- armonizar(d, col_ubigeo = col_ubigeo)

  d[, .(altas = .N), by = .(ubigeo_arm, anio, ciiu = get(col_ciiu))]
}

# --- Escenario B: diferencias entre snapshots ---------------------------------
# Requiere >=2 snapshots del padrón en data/raw/snapshots/<YYYYMM>/
altas_desde_snapshots <- function(dir_snapshots, col_ruc, col_ubigeo, col_ciiu) {
  carpetas <- sort(list.dirs(dir_snapshots, recursive = FALSE))
  if (length(carpetas) < 2) stop("Se requieren al menos 2 snapshots.")

  leer <- function(carp) {
    f <- list.files(carp, pattern = "\\.(txt|csv)$", full.names = TRUE)[1]
    x <- data.table::fread(f, encoding = "Latin-1",
                           select = c(col_ruc, col_ubigeo, col_ciiu))
    x[, periodo := basename(carp)]
    x
  }

  res <- list()
  for (i in 2:length(carpetas)) {
    prev <- leer(carpetas[i - 1]); curr <- leer(carpetas[i])
    nuevos <- curr[!prev, on = col_ruc]          # RUC presente hoy, ausente antes
    nuevos <- armonizar(nuevos, col_ubigeo = col_ubigeo)
    res[[i]] <- nuevos[, .(altas = .N),
                       by = .(ubigeo_arm,
                              periodo = basename(carpetas[i]),
                              ciiu = get(col_ciiu))]
  }
  data.table::rbindlist(res)
}

# --- Panel balanceado ---------------------------------------------------------
# Los distritos-año sin altas deben ser CERO explícito, no filas ausentes.
# Omitir esto sesga el estimador: los ceros son información, no datos faltantes.

balancear <- function(altas, mapa, anios = ANIO_INICIO:ANIO_FIN) {
  grilla <- data.table::CJ(
    ubigeo_arm = unique(mapa$ubigeo_arm),
    anio = anios
  )
  agregado <- altas[, .(altas = sum(altas)), by = .(ubigeo_arm, anio)]
  panel <- merge(grilla, agregado, by = c("ubigeo_arm", "anio"), all.x = TRUE)
  panel[is.na(altas), altas := 0L]
  panel[]
}

# --- Denominador poblacional --------------------------------------------------
# Sin población, "altas" mezcla efecto de tratamiento con tamaño del distrito.
agregar_poblacion <- function(panel) {
  f <- file.path(DIR_RAW, "poblacion_distrital.csv")
  if (!file.exists(f)) {
    warning("Falta ", f, " (Censos 2017 + proyecciones INEI). ",
            "El panel queda sin tasa per cápita.")
    return(panel)
  }
  pob <- data.table::fread(f, colClasses = list(character = "ubigeo"))
  pob <- armonizar(pob, col_ubigeo = "ubigeo")
  pob <- pob[, .(poblacion = sum(poblacion)), by = .(ubigeo_arm, anio)]

  p <- merge(panel, pob, by = c("ubigeo_arm", "anio"), all.x = TRUE)
  p[, tasa_altas := 1000 * altas / poblacion]
  p[]
}

# --- Tamaño de empresa (PRODUCE) ----------------------------------------------
agregar_tamano <- function(panel_ruc) {
  f <- file.path(DIR_RAW, "produce_directorio_mipyme.csv")
  if (!file.exists(f)) {
    warning("Falta ", f, ". No se podrá desagregar por tamaño (H3).")
    return(NULL)
  }
  mipyme <- data.table::fread(f)
  mipyme <- janitor::clean_names(mipyme)
  # Cruce por RUC; genera altas por segmento de tamaño.
  merge(panel_ruc, mipyme, by = "ruc", all.x = TRUE)
}

# --- Validación externa contra INEI -------------------------------------------
# Test decisivo de credibilidad: si la serie construida no reproduce las altas
# oficiales del INEI a nivel departamental, la construcción está mal.

validar_contra_inei <- function(panel) {
  f <- file.path(DIR_RAW, "inei_demografia_empresarial.csv")
  if (!file.exists(f)) {
    message("Sin archivo de validación (", f, "). ",
            "Transcribe la serie de Demografía Empresarial del INEI para validar.")
    return(invisible(NULL))
  }
  inei <- data.table::fread(f)   # columnas: departamento, anio, altas_inei

  propio <- data.table::copy(panel)
  propio[, departamento := substr(ubigeo_arm, 1, 2)]
  propio <- propio[, .(altas_propias = sum(altas)), by = .(departamento, anio)]

  comp <- merge(propio, inei, by = c("departamento", "anio"))
  r <- cor(comp$altas_propias, comp$altas_inei, use = "complete.obs")

  cat("\n===== VALIDACIÓN EXTERNA vs. INEI =====\n")
  cat("Correlación departamento-año: ", round(r, 4), "\n", sep = "")
  cat("Ratio medio propio/INEI:      ",
      round(mean(comp$altas_propias / comp$altas_inei, na.rm = TRUE), 4), "\n", sep = "")
  if (r < 0.90) {
    cat("\n*** ADVERTENCIA: correlación < 0.90. Revisar construcción antes de estimar. ***\n")
  }
  # Un ratio que decae hacia años antiguos es la firma del sesgo de supervivencia.
  print(comp[, .(ratio = mean(altas_propias / altas_inei, na.rm = TRUE)), by = anio])
  cat("=======================================\n\n")
  invisible(comp)
}

if (sys.nframe() == 0 || interactive()) {
  message("Ejecutar tras resolver el escenario en 01_download_sunat.R.")
  message("Escenario A -> altas_desde_fecha(); Escenario B -> altas_desde_snapshots().")
}
