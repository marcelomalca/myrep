# 07_estimate_did.R -----------------------------------------------------------
# Estimación del efecto de la infraestructura vial sobre la creación de empresas.
#
# ADVERTENCIA METODOLÓGICA CENTRAL
# --------------------------------
# Con adopción escalonada y efectos heterogéneos, el TWFE está sesgado: usa
# unidades tratadas temprano como controles de las tratadas tarde
# ("comparaciones prohibidas") y puede asignar PESOS NEGATIVOS.
# El estimador principal de este proyecto es Callaway & Sant'Anna (2021).
# El TWFE se reporta SOLO como referencia, junto con la descomposición de
# Goodman-Bacon que muestra cuánto peso cargan las comparaciones problemáticas.

if (!exists("PROJ")) source("R/00_setup.R")

cargar_panel <- function() {
  panel    <- readRDS(file.path(DIR_PROC, "panel_distrito_anio.rds"))
  cohortes <- readRDS(file.path(DIR_PROC, "cohortes_tratamiento.rds"))

  d <- merge(panel, cohortes, by = "ubigeo_arm", all.x = TRUE)
  d[is.na(g), g := 0L]
  d[, id := .GRP, by = ubigeo_arm]           # did::att_gt requiere id numérico
  d[, tratado := as.integer(g > 0 & anio >= g)]
  d[]
}

# 1. ESTIMADOR PRINCIPAL: Callaway & Sant'Anna (2021) --------------------------
estimar_cs <- function(d, yname = "tasa_altas",
                       control_group = "nevertreated") {
  att <- did::att_gt(
    yname         = yname,
    tname         = "anio",
    idname        = "id",
    gname         = "g",
    data          = as.data.frame(d),
    control_group = control_group,   # "notyettreated" si hay pocos nunca-tratados
    clustervars   = "id",
    bstrap        = TRUE,
    cband         = TRUE,            # bandas de confianza uniformes
    allow_unbalanced_panel = TRUE
  )

  list(
    att_gt   = att,
    dinamico = did::aggte(att, type = "dynamic", na.rm = TRUE),  # event study
    simple   = did::aggte(att, type = "simple",  na.rm = TRUE),  # ATT global
    grupo    = did::aggte(att, type = "group",   na.rm = TRUE),  # por cohorte
    calendar = did::aggte(att, type = "calendar",na.rm = TRUE)   # por año
  )
}

# 2. CONTRASTE: Sun & Abraham (2021) -------------------------------------------
estimar_sa <- function(d, yname = "tasa_altas") {
  dd <- data.table::copy(d)
  dd[, cohorte := ifelse(g == 0, 10000, g)]   # fixest::sunab codifica así los nunca-tratados
  fixest::feols(
    stats::as.formula(paste0(yname, " ~ sunab(cohorte, anio) | id + anio")),
    data = dd, cluster = ~id
  )
}

# 3. CONTRASTE: Borusyak, Jaravel & Spiess (2024) ------------------------------
estimar_bjs <- function(d, yname = "tasa_altas") {
  didimputation::did_imputation(
    data = as.data.frame(d), yname = yname,
    gname = "g", tname = "anio", idname = "id",
    horizon = TRUE, cluster_var = "id"
  )
}

# 4. REFERENCIA: TWFE + diagnóstico de Goodman-Bacon ---------------------------
estimar_twfe <- function(d, yname = "tasa_altas") {
  fixest::feols(
    stats::as.formula(paste0(yname, " ~ tratado | id + anio")),
    data = d, cluster = ~id
  )
}

diagnostico_bacon <- function(d, yname = "tasa_altas") {
  # Requiere panel balanceado y tratamiento absorbente.
  bd <- bacondecomp::bacon(
    stats::as.formula(paste0(yname, " ~ tratado")),
    data = as.data.frame(d), id_var = "id", time_var = "anio"
  )
  cat("\n===== DESCOMPOSICIÓN GOODMAN-BACON =====\n")
  print(aggregate(weight ~ type, data = bd, FUN = sum))
  cat("\nSi 'Later vs Earlier Treated' pesa mucho, el TWFE es poco confiable\n")
  cat("y debe primar Callaway-Sant'Anna.\n")
  cat("========================================\n\n")
  bd
}

# 5. Heterogeneidad ------------------------------------------------------------
# H2 (sector) y H3 (tamaño): re-estimar CS sobre submuestras.
estimar_por_grupo <- function(d, var_grupo, yname = "tasa_altas") {
  grupos <- unique(d[[var_grupo]])
  res <- list()
  for (gr in grupos) {
    sub <- d[get(var_grupo) == gr]
    if (data.table::uniqueN(sub$id) < 50) {
      message("Grupo '", gr, "' con muy pocas unidades; se omite.")
      next
    }
    res[[as.character(gr)]] <- tryCatch(
      estimar_cs(sub, yname = yname),
      error = function(e) { message("Falló grupo ", gr, ": ", conditionMessage(e)); NULL }
    )
  }
  res
}

# 6. Gráfico del event study ---------------------------------------------------
graficar_event_study <- function(agg_dinamico, titulo, archivo) {
  df <- data.frame(
    periodo = agg_dinamico$egt,
    att     = agg_dinamico$att.egt,
    se      = agg_dinamico$se.egt
  )
  df$lo <- df$att - 1.96 * df$se
  df$hi <- df$att + 1.96 * df$se

  p <- ggplot2::ggplot(df, ggplot2::aes(periodo, att)) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", colour = "grey40") +
    ggplot2::geom_vline(xintercept = -0.5, linetype = "dotted", colour = "grey40") +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = lo, ymax = hi), alpha = 0.2) +
    ggplot2::geom_point() + ggplot2::geom_line() +
    ggplot2::labs(
      title = titulo,
      subtitle = "Callaway & Sant'Anna (2021). Los periodos < 0 testean tendencias paralelas.",
      x = "Años desde la culminación del proyecto vial",
      y = "Efecto sobre altas por cada 1,000 habitantes"
    ) +
    ggplot2::theme_minimal(base_size = 11)

  ggplot2::ggsave(file.path(DIR_OUT, archivo), p, width = 8, height = 5, dpi = 300)
  p
}

if (sys.nframe() == 0 || interactive()) {
  d <- cargar_panel()

  cs <- estimar_cs(d)
  cat("\n--- ATT global (Callaway-Sant'Anna) ---\n"); print(summary(cs$simple))
  cat("\n--- Event study ---\n");                     print(summary(cs$dinamico))

  # Test de tendencias paralelas: los leads deben ser conjuntamente nulos.
  pre <- cs$dinamico$egt < 0
  cat("\nLeads (pre-tratamiento) significativos al 5%: ",
      sum(abs(cs$dinamico$att.egt[pre] / cs$dinamico$se.egt[pre]) > 1.96),
      " de ", sum(pre), "\n", sep = "")

  sa   <- estimar_sa(d)
  twfe <- estimar_twfe(d)
  cat("\n--- Sun & Abraham ---\n"); print(summary(sa))
  cat("\n--- TWFE (solo referencia) ---\n"); print(summary(twfe))

  bacon <- tryCatch(diagnostico_bacon(d), error = function(e) {
    message("Bacon no disponible: ", conditionMessage(e)); NULL
  })

  graficar_event_study(cs$dinamico,
                       "Efecto de la infraestructura vial sobre la creación de empresas",
                       "event_study_principal.png")

  saveRDS(list(cs = cs, sa = sa, twfe = twfe, bacon = bacon),
          file.path(DIR_OUT, "resultados_did.rds"))
  message("Resultados guardados en ", DIR_OUT)
}
