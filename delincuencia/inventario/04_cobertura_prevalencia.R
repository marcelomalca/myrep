# 04_cobertura_prevalencia.R (inventario)
# Cobertura distrital y prevalencia nacional de los indicadores de
# victimización (ENAPRES y ENAHO), con definiciones provisionales para el
# inventario. Las definiciones finales se fijan en la fase 2.
#
# Uso: Rscript delincuencia/inventario/04_cobertura_prevalencia.R
# Salidas (en delincuencia/inventario/):
#   prevalencia_nacional.csv, cobertura_anual.csv, ceros_distrito_anio.csv,
#   modalidad_2020_2022.csv, ubigeos_sin_correspondencia.csv, presencia_distritos_oro.csv

suppressPackageStartupMessages({ library(haven); library(dplyr); library(tidyr); library(readr) })

# Clasificación de distritos del libro (ids_pre, ids_mina, a_base, limites)
owd <- setwd("libro"); source("R/comun.R"); setwd(owd)
cat_oro <- function(ub) case_when(ub %in% ids_mina ~ "oro_mina_proyecto",
                                  ub %in% ids_pre ~ "oro_solo_prospecto_ocurrencia",
                                  TRUE ~ "otro")

media_pond <- function(x, w) { ok <- !is.na(x) & !is.na(w); if (!any(ok)) NA_real_ else sum(x[ok] * w[ok]) / sum(w[ok]) }
arch <- function(enc, anio, patron) {
  f <- list.files(file.path("delincuencia/cache", enc, anio), pattern = patron, recursive = TRUE, full.names = TRUE)
  stopifnot(length(f) == 1); f
}
leer_dta <- function(f, cols) tryCatch(read_dta(f, col_select = any_of(cols)),
                                       error = function(e) read_dta(f, col_select = any_of(cols), encoding = "latin1"))

tipos <- read_csv("delincuencia/inventario/tipos_delito_enapres.csv", col_types = cols(.default = "c"))
pref <- function(anio) if (anio <= 2023) c(v = "P601_", d = "P606_", a = "P605_") else
  if (anio == 2024) c(v = "P615_", d = "P619_", a = "P632_") else c(v = "P424_", d = "P428_", a = "P451_")
sufijo <- function(anio) if (anio <= 2023) tipos$sufijo_2014_2023 else if (anio == 2024) tipos$sufijo_2024 else tipos$sufijo_2025

# ---------------------------------------------------------------- ENAPRES personas
enapres <- lapply(2014:2025, function(anio) {
  f <- arch("enapres", anio, "CAP_?[64]00.*\\.sav$")
  p <- pref(anio); suf <- sufijo(anio)
  ok <- !is.na(suf) & suf != "" & tipos$tipo != "vandalismo"
  vv <- paste0(p["v"], suf[ok]); dd <- paste0(p["d"], suf[ok])
  aa <- c(paste0(p["a"], suf[ok], "_1"), paste0(p["a"], suf[ok], "_2"))
  perc <- if (anio <= 2023) paste0("P611_", 1:14) else if (anio == 2024) paste0("P601_", 1:16) else "P401"
  pesos <- c("FACTORANUALCAP600", "FACTORANUAL", "FACTOR", "FACTOR_CAP600B", "FACTOR_CAP400")
  d <- read_sav(f, col_select = any_of(c("MES", "CCDD", "CCPP", "CCDI", "P208_A", "RESFIN", "MOD_ENC",
                                           pesos, vv, dd, aa, perc))) |> zap_labels()
  w <- d[[intersect(c("FACTORANUALCAP600", "FACTORANUAL", "FACTOR"), names(d))[1]]]
  wp <- if (anio == 2024) d$FACTOR_CAP600B else if (anio == 2025) d$FACTOR_CAP400 else w
  vmat <- as.matrix(d[intersect(vv, names(d))])
  comun <- tipos$tipo[ok] %in% tipos$tipo[tipos$lista_comun == "1"]
  vcom <- as.matrix(d[intersect(vv[comun], names(d))])
  cualquiera <- function(m) ifelse(rowSums(!is.na(m)) == 0, NA, as.integer(rowSums(m == 1, na.rm = TRUE) > 0))
  un_tipo <- function(t) { s <- suf[tipos$tipo == t]; v <- paste0(p["v"], s); if (v %in% names(d)) as.integer(d[[v]] == 1) else NA_integer_ }
  arma <- as.matrix(d[intersect(aa, names(d))])
  den <- as.matrix(d[intersect(dd, names(d))])
  # Percepción: se calcula fuera del tibble (dentro, 'anio' sería la columna y no el escalar)
  percepcion <- if (anio == 2025) as.integer(d$P401 == 1) else cualquiera(as.matrix(d[intersect(perc, names(d))]))
  tibble(
    anio = anio, mes = as.integer(d$MES),
    ubigeo = sprintf("%02d%02d%02d", as.integer(d$CCDD), as.integer(d$CCPP), as.integer(d$CCDI)),
    edad = as.integer(d$P208_A), resfin = as.integer(d$RESFIN),
    modalidad = if ("MOD_ENC" %in% names(d)) as.integer(d$MOD_ENC) else NA_integer_,
    peso = w, peso_percepcion = wp,
    victima_comun = cualquiera(vcom), victima_completa = cualquiera(vmat),
    robo_dinero = pmax(un_tipo("robo_dinero"), un_tipo("intento_robo_dinero")),
    extorsion = un_tipo("extorsion"), estafa = un_tipo("estafa"), amenazas = un_tipo("amenazas"),
    robo_negocio = un_tipo("robo_negocio"), ofensas_sexuales = un_tipo("ofensas_sexuales"),
    robo_vehiculo = pmax(un_tipo("robo_vehiculo"), un_tipo("robo_moto"), na.rm = TRUE),
    arma_fuego = ifelse(is.na(victima_completa), NA, as.integer(rowSums(arma == 1, na.rm = TRUE) > 0)),
    denuncio = ifelse(victima_completa %in% 1, as.integer(rowSums(den == 1, na.rm = TRUE) > 0), NA),
    percepcion = percepcion
  )
}) |> bind_rows() |>
  filter(edad >= 15, !is.na(peso), peso > 0) |>
  mutate(ubigeo_base = a_base(ubigeo), categoria = cat_oro(ubigeo_base))

# ---------------------------------------------------------------- ENAPRES hogares (robo de vivienda)
viv <- lapply(2014:2025, function(anio) {
  f <- arch("enapres", anio, "CAP_?100.*\\.sav$")
  v <- if (anio >= 2024) c("P116_1", "P116_2") else c("P112_1", "P112_2")
  d <- read_sav(f, col_select = any_of(c("AREA", "CCDD", "CCPP", "CCDI", "FACTOR", "FACTORANUAL", v))) |> zap_labels()
  tibble(anio = anio, area = as.integer(d$AREA),
         ubigeo = sprintf("%02d%02d%02d", as.integer(d$CCDD), as.integer(d$CCPP), as.integer(d$CCDI)),
         peso = if ("FACTOR" %in% names(d)) d$FACTOR else d$FACTORANUAL,
         robo_vivienda = ifelse(is.na(d[[v[1]]]) & is.na(d[[v[2]]]), NA,
                                as.integer(d[[v[1]]] %in% 1 | d[[v[2]]] %in% 1)))
}) |> bind_rows() |>
  filter(!is.na(robo_vivienda), !is.na(peso), peso > 0) |>
  mutate(ubigeo_base = a_base(ubigeo), categoria = cat_oro(ubigeo_base))

# ---------------------------------------------------------------- ENAHO módulo 85
enaho_hog <- lapply(2014:2025, function(anio) {
  d <- leer_dta(arch("enaho", anio, "-2\\.dta$"), c("mes", "ubigeo", "factor07", "p40_5", "tipocuestionario")) |> zap_labels()
  tibble(anio = anio, mes = as.integer(d$mes), ubigeo = d$ubigeo, peso = d$factor07,
         hecho_delictivo = as.integer(d$p40_5 == 1) * ifelse(is.na(d$p40_5), NA, 1),
         p40_5_faltante = is.na(d$p40_5),
         tipocuestionario = if ("tipocuestionario" %in% names(d)) as.integer(d$tipocuestionario) else NA_integer_)
}) |> bind_rows() |>
  mutate(ubigeo_base = a_base(ubigeo), categoria = cat_oro(ubigeo_base))

enaho_op <- lapply(2014:2025, function(anio) {
  d <- leer_dta(arch("enaho", anio, "-1\\.dta$"), c("mes", "ubigeo", "facgob07", "famiegob07", "p1_06", "p208_01",
                                                    "p2_1_04", "p2_1_15", "p2_2_04", "p2_2_15")) |> zap_labels()
  tibble(anio = anio, ubigeo = d$ubigeo, edad = as.integer(d$p208_01),
         peso = if ("facgob07" %in% names(d)) d$facgob07 else d$famiegob07,
         respondio = !is.na(d$p1_06),
         # Provisionales: menciona delincuencia (15) / falta de seguridad ciudadana (4) entre los
         # principales problemas; alguno de los dos; alguno de los dos como problema más importante;
         # confianza en la PNP = suficiente o bastante (3-4) sobre todas las respuestas, "no sabe" incluido.
         op_delincuencia = as.integer(d$p2_1_15 %in% 15) * ifelse(is.na(d$p2_1_15), NA, 1),
         op_falta_seguridad = as.integer(d$p2_1_04 %in% 4) * ifelse(is.na(d$p2_1_04), NA, 1),
         op_alguno = pmax(op_delincuencia, op_falta_seguridad),
         op_alguno_primero = ifelse(is.na(d$p2_1_15), NA, as.integer(d$p2_2_15 %in% 1 | d$p2_2_04 %in% 1)),
         op_confia_pnp = ifelse(is.na(d$p1_06), NA, as.integer(d$p1_06 %in% 3:4)))
}) |> bind_rows() |>
  filter(!is.na(peso), peso > 0) |>
  mutate(ubigeo_base = a_base(ubigeo), categoria = cat_oro(ubigeo_base))

# ---------------------------------------------------------------- Prevalencia nacional
ind_enapres <- c("victima_comun", "victima_completa", "robo_dinero", "robo_vehiculo", "amenazas",
                 "extorsion", "estafa", "robo_negocio", "ofensas_sexuales", "arma_fuego", "denuncio", "percepcion")
prev <- bind_rows(
  enapres |> group_by(anio) |>
    summarise(across(all_of(ind_enapres), ~ 100 * media_pond(.x, if (cur_column() == "percepcion") peso_percepcion else peso)),
              n_personas = n(), .groups = "drop"),
  viv |> group_by(anio) |> summarise(robo_vivienda = 100 * media_pond(robo_vivienda, peso), n_hogares_enapres = n(), .groups = "drop"),
  enaho_hog |> filter(!is.na(hecho_delictivo)) |> group_by(anio) |>
    summarise(enaho_hecho_delictivo = 100 * media_pond(hecho_delictivo, peso), n_hogares_enaho = n(), .groups = "drop"),
  enaho_op |> filter(respondio) |> group_by(anio) |>
    summarise(across(starts_with("op_"), ~ 100 * media_pond(.x, peso)), n_personas_opinion = n(), .groups = "drop")
) |> group_by(anio) |> summarise(across(everything(), ~ first(na.omit(.x))), .groups = "drop") |>
  mutate(across(where(is.double), ~ round(.x, 2)))
write_csv(prev, "delincuencia/inventario/prevalencia_nacional.csv")

# ---------------------------------------------------------------- Cobertura distrital
cobertura <- function(d, fuente, n_def) {
  por <- d |> count(anio, ubigeo_base, categoria, name = "n")
  por |> group_by(anio) |>
    summarise(fuente = fuente, unidad = n_def, distritos = n(), obs = sum(n),
              obs_mediana = median(n), obs_min = min(n), obs_max = max(n),
              oro_distritos = sum(categoria != "otro"), oro_obs = sum(n[categoria != "otro"]),
              oro_obs_mediana = median(n[categoria != "otro"]),
              oro_obs_min = min(n[categoria != "otro"]), oro_obs_max = max(n[categoria != "otro"]),
              mina_distritos = sum(categoria == "oro_mina_proyecto"), mina_obs = sum(n[categoria == "oro_mina_proyecto"]),
              prosp_distritos = sum(categoria == "oro_solo_prospecto_ocurrencia"),
              prosp_obs = sum(n[categoria == "oro_solo_prospecto_ocurrencia"]), .groups = "drop")
}
cob <- bind_rows(
  cobertura(enapres |> filter(!is.na(victima_completa)), "ENAPRES personas (urbano, 15+)", "personas"),
  cobertura(enapres |> filter(!is.na(percepcion), !is.na(peso_percepcion)), "ENAPRES percepción", "personas"),
  cobertura(viv, "ENAPRES hogares, robo de vivienda (urbano)", "hogares"),
  cobertura(enaho_hog |> filter(!is.na(hecho_delictivo)), "ENAHO hogares, hecho delictivo", "hogares"),
  cobertura(enaho_op |> filter(respondio), "ENAHO opinión (módulo 85)", "personas")
)
write_csv(cob, "delincuencia/inventario/cobertura_anual.csv")

# ---------------------------------------------------------------- Presencia de los distritos con oro en el panel
# Cuántos de los distritos con oro antes de 2014 aparecen en cada fuente y en cuántos de los 12 años.
presencia <- function(d, fuente) {
  d |> filter(categoria != "otro") |> distinct(anio, ubigeo_base, categoria) |>
    count(ubigeo_base, categoria, name = "anios") |>
    group_by(categoria) |>
    summarise(fuente = fuente, distritos_alguna_vez = n(), distritos_12_anios = sum(anios == 12),
              distritos_6_o_mas = sum(anios >= 6), anios_mediana = median(anios), .groups = "drop")
}
pres <- bind_rows(
  presencia(enapres |> filter(!is.na(victima_completa)), "ENAPRES personas (urbano, 15+)"),
  presencia(viv, "ENAPRES hogares, robo de vivienda (urbano)"),
  presencia(enaho_hog |> filter(!is.na(hecho_delictivo)), "ENAHO hogares, hecho delictivo"),
  presencia(enaho_op |> filter(respondio), "ENAHO opinión (módulo 85)")
) |> mutate(distritos_universo = ifelse(categoria == "oro_mina_proyecto", length(ids_mina),
                                        length(setdiff(ids_pre, ids_mina))))
write_csv(pres, "delincuencia/inventario/presencia_distritos_oro.csv")

# ---------------------------------------------------------------- Distrito-año con cero casos
ceros <- function(d, var, fuente) {
  d |> filter(!is.na(.data[[var]])) |>
    group_by(anio, ubigeo_base, categoria) |>
    summarise(casos = sum(.data[[var]]), n = n(), .groups = "drop") |>
    group_by(anio) |>
    summarise(fuente = fuente, indicador = var, distritos = n(),
              pct_cero = 100 * mean(casos == 0),
              pct_cero_oro = 100 * mean(casos[categoria != "otro"] == 0),
              distritos_oro = sum(categoria != "otro"), .groups = "drop")
}
zero <- bind_rows(
  lapply(setdiff(ind_enapres, c("denuncio", "percepcion")), function(v) ceros(enapres, v, "ENAPRES")),
  list(ceros(viv, "robo_vivienda", "ENAPRES hogares"), ceros(enaho_hog, "hecho_delictivo", "ENAHO hogares"))
) |> mutate(across(where(is.double), ~ round(.x, 1)))
write_csv(zero, "delincuencia/inventario/ceros_distrito_anio.csv")

# ---------------------------------------------------------------- 2020-2022: modalidad y faltantes
modal <- bind_rows(
  enapres |> filter(anio %in% 2020:2022) |> count(anio, mes, modalidad) |> mutate(fuente = "ENAPRES personas"),
  enaho_hog |> filter(anio %in% 2020:2021) |> group_by(anio, mes) |>
    summarise(n = n(), p40_5_faltante = sum(p40_5_faltante),
              reducido = sum(tipocuestionario %in% 1), .groups = "drop") |> mutate(fuente = "ENAHO hogares")
)
write_csv(modal, "delincuencia/inventario/modalidad_2020_2022.csv")

# ---------------------------------------------------------------- Ubigeos sin correspondencia
todos <- bind_rows(enapres |> distinct(anio, ubigeo), viv |> distinct(anio, ubigeo),
                   enaho_hog |> distinct(anio, ubigeo), enaho_op |> distinct(anio, ubigeo)) |> distinct()
sin <- todos |> filter(!ubigeo %in% correspondencia$ubigeo, !ubigeo %in% limites$IDDIST) |>
  group_by(ubigeo) |> summarise(anios = paste(sort(unique(anio)), collapse = ","), .groups = "drop")
write_csv(sin, "delincuencia/inventario/ubigeos_sin_correspondencia.csv")

print(as.data.frame(prev)); print(as.data.frame(pres)); print(sin)
