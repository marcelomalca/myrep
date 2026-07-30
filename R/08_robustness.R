# 08_robustness.R -------------------------------------------------------------
# Robustez y bloque secundario de informalidad.

if (!exists("PROJ")) source("R/00_setup.R")
source("R/07_estimate_did.R")

# 1. Sensibilidad al umbral de monto -------------------------------------------
# El umbral que define "proyecto relevante" es una decisión arbitraria.
# Si el resultado depende de ella, el hallazgo es frágil.
sensibilidad_umbral <- function(proyectos, mapa, panel,
                                umbrales = c(5e5, 1e6, 5e6, 1e7)) {
  source("R/06_treatment_assignment.R")
  res <- lapply(umbrales, function(u) {
    coh <- asignar_cohortes(proyectos, mapa, umbral = u)
    d <- merge(panel, coh, by = "ubigeo_arm", all.x = TRUE)
    d[is.na(g), g := 0L]; d[, id := .GRP, by = ubigeo_arm]
    est <- estimar_cs(d)
    data.table::data.table(umbral = u,
                           att = est$simple$overall.att,
                           se  = est$simple$overall.se)
  })
  data.table::rbindlist(res)
}

# 2. Placebo: cohortes falsas --------------------------------------------------
# Adelantar el tratamiento 3-5 años no debe producir efectos.
placebo_cohortes <- function(d, adelanto = 4L) {
  dp <- data.table::copy(d)
  dp[g > 0, g := g - adelanto]
  dp <- dp[anio < (g + adelanto) | g == 0]   # descartar el post real
  estimar_cs(dp)
}

# 3. Clustering alternativo ----------------------------------------------------
# Las carreteras generan dependencia espacial: distritos vecinos no son
# independientes. Se re-agrupa a nivel provincia.
robustez_cluster <- function(d, yname = "tasa_altas") {
  dd <- data.table::copy(d)
  dd[, provincia := substr(ubigeo_arm, 1, 4)]
  list(
    distrito  = fixest::feols(stats::as.formula(paste0(yname, " ~ tratado | id + anio")),
                              data = dd, cluster = ~id),
    provincia = fixest::feols(stats::as.formula(paste0(yname, " ~ tratado | id + anio")),
                              data = dd, cluster = ~provincia)
  )
}

# 4. Honest DiD (Rambachan & Roth, 2023) ---------------------------------------
# Acota el efecto bajo violaciones plausibles de tendencias paralelas, en vez
# de asumir que se cumplen exactamente.
honest_did <- function(cs_dinamico, Mvec = seq(0, 0.5, by = 0.1)) {
  HonestDiD::createSensitivityResults_relativeMagnitudes(
    betahat = cs_dinamico$att.egt,
    sigma   = diag(cs_dinamico$se.egt^2),
    numPrePeriods  = sum(cs_dinamico$egt < 0),
    numPostPeriods = sum(cs_dinamico$egt >= 0),
    Mbarvec = Mvec
  )
}

# 5. Especificación alternativa: dosis continua (extensión C de docs/03) -------
estimar_dosis <- function(panel, dosis) {
  d <- merge(panel, dosis, by = c("ubigeo_arm", "anio"))
  d[, log_inv := log1p(inversion_acum)]
  fixest::feols(tasa_altas ~ log_inv | ubigeo_arm + anio, data = d, cluster = ~ubigeo_arm)
}

# 6. BLOQUE SECUNDARIO: informalidad (ENAHO, departamental) --------------------
# Reportar SIEMPRE con la advertencia de potencia: ~26 unidades geográficas
# frente a un tratamiento que varía a nivel distrital.
estimar_informalidad <- function() {
  f <- file.path(DIR_PROC, "panel_informalidad_dep.rds")
  if (!file.exists(f)) {
    stop("Falta ", f, ". Construir desde microdatos ENAHO (módulo empleo):\n",
         "  https://proyectos.inei.gob.pe/microdatos/\n",
         "Columnas: departamento, anio, tasa_informalidad, exposicion_vial")
  }
  d <- readRDS(f)

  cat("\n*** ADVERTENCIA DE POTENCIA ***\n")
  cat("Unidades geográficas: ", data.table::uniqueN(d$departamento), "\n", sep = "")
  cat("ENAHO es representativa a nivel departamental; el tratamiento varía a\n")
  cat("nivel distrital. Interpretar como evidencia de MECANISMO, no como\n")
  cat("resultado principal.\n\n")

  fixest::feols(tasa_informalidad ~ exposicion_vial | departamento + anio,
                data = d, cluster = ~departamento)
}

if (sys.nframe() == 0 || interactive()) {
  d <- cargar_panel()

  cat("\n===== PLACEBO (cohortes adelantadas 4 años) =====\n")
  pl <- placebo_cohortes(d); print(summary(pl$simple))
  cat("Un efecto significativo aquí invalida el diseño.\n")

  cat("\n===== CLUSTERING ALTERNATIVO =====\n")
  print(modelsummary::msummary(robustez_cluster(d), output = "markdown"))

  message("\nEjecutar sensibilidad_umbral(), honest_did() y estimar_informalidad() ",
          "cuando los insumos correspondientes estén disponibles.")
}
