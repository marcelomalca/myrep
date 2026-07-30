# 06_treatment_assignment.R ---------------------------------------------------
# Asigna la cohorte de adopción `g` a cada distrito.
#
# Convención de `did::att_gt`: g = primer año de tratamiento; g = 0 para
# unidades NUNCA tratadas (grupo de comparación limpio).

if (!exists("PROJ")) source("R/00_setup.R")
source("R/04_ubigeo_concordance.R")

# Definición de tratamiento ----------------------------------------------------
# Un distrito se considera tratado en el año en que CULMINA su primer proyecto
# vial por encima de UMBRAL_MONTO.
#
# Decisión sustantiva: se usa fecha de CULMINACIÓN, no de inicio, porque el
# efecto económico opera cuando la vía está operativa. La sensibilidad a este
# criterio se testea en 08_robustness.R.

asignar_cohortes <- function(proyectos, mapa, umbral = UMBRAL_MONTO) {
  p <- data.table::as.data.table(proyectos)

  n0 <- nrow(p)
  p <- p[!is.na(ubigeo) & !is.na(fecha_fin) & !is.na(monto)]
  message("Proyectos utilizables: ", nrow(p), " de ", n0,
          " (se descartan los que carecen de ubigeo, fecha de fin o monto).")

  p <- p[monto >= umbral]
  message("Tras umbral de ", format(umbral, big.mark = ","), ": ", nrow(p), " proyectos.")

  p <- armonizar(p, col_ubigeo = "ubigeo", mapa = mapa)
  p[, anio_fin := lubridate::year(fecha_fin)]
  p <- p[anio_fin >= ANIO_INICIO & anio_fin <= ANIO_FIN]

  cohortes <- p[, .(g = min(anio_fin), n_proyectos = .N,
                    monto_total = sum(monto)), by = ubigeo_arm]

  # Universo completo: los distritos sin proyecto son nunca-tratados (g = 0).
  todos <- data.table::data.table(ubigeo_arm = unique(mapa$ubigeo_arm))
  out <- merge(todos, cohortes, by = "ubigeo_arm", all.x = TRUE)
  out[is.na(g), `:=`(g = 0L, n_proyectos = 0L, monto_total = 0)]

  cat("\n===== DISTRIBUCIÓN DE COHORTES =====\n")
  print(out[, .N, by = g][order(g)])
  cat("Nunca tratados: ", out[g == 0, .N], "\n", sep = "")
  cat("Tratados:       ", out[g > 0, .N], "\n", sep = "")

  # Un grupo de control muy pequeño invalida la estrategia.
  frac_control <- out[g == 0, .N] / nrow(out)
  if (frac_control < 0.15) {
    cat("\n*** ADVERTENCIA: solo ", round(100 * frac_control, 1),
        "% nunca tratados. Considerar usar `control_group = 'notyettreated'` ",
        "en did::att_gt, o subir UMBRAL_MONTO. ***\n", sep = "")
  }
  cat("====================================\n\n")

  out[]
}

# Dosis continua ---------------------------------------------------------------
# Inversión vial acumulada por distrito-año (para la extensión C de docs/03).
construir_dosis <- function(proyectos, mapa, anios = ANIO_INICIO:ANIO_FIN) {
  p <- data.table::as.data.table(proyectos)[!is.na(ubigeo) & !is.na(fecha_fin)]
  p <- armonizar(p, col_ubigeo = "ubigeo", mapa = mapa)
  p[, anio := lubridate::year(fecha_fin)]

  flujo <- p[, .(inversion = sum(monto, na.rm = TRUE)), by = .(ubigeo_arm, anio)]
  grilla <- data.table::CJ(ubigeo_arm = unique(mapa$ubigeo_arm), anio = anios)
  d <- merge(grilla, flujo, by = c("ubigeo_arm", "anio"), all.x = TRUE)
  d[is.na(inversion), inversion := 0]
  data.table::setorder(d, ubigeo_arm, anio)
  d[, inversion_acum := cumsum(inversion), by = ubigeo_arm]
  d[]
}

if (sys.nframe() == 0 || interactive()) {
  proyectos <- readRDS(file.path(DIR_INT, "mef_proyectos_viales.rds"))
  mapa      <- readRDS(file.path(DIR_PROC, "mapa_ubigeos.rds"))

  cohortes <- asignar_cohortes(proyectos, mapa)
  dosis    <- construir_dosis(proyectos, mapa)

  saveRDS(cohortes, file.path(DIR_PROC, "cohortes_tratamiento.rds"))
  saveRDS(dosis,    file.path(DIR_PROC, "dosis_inversion.rds"))
  message("Guardados en ", DIR_PROC)
}
