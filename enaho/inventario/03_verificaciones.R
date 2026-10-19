# 03_verificaciones.R (inventario)
# Verificaciones sobre los datos que respaldan el inventario:
#   1. Las variables "I" (imputadas) coinciden con las "D" (deflactadas) donde
#      estas existen, en todos los años (el cambio de etiqueta de 2022 es solo
#      de redacción).
#   2. Variables de resultado faltantes según tipo de cuestionario (2020-2021).
#   3. Base de los deflactores de 2025 y coherencia con la edición 2024.
#   4. Gasto e ingreso real per cápita: método del INEI frente a las
#      definiciones solicitadas (gashog2d e inghog2d con un solo deflactor).
#
# Uso: Rscript enaho/inventario/03_verificaciones.R
# Salidas: enaho/inventario/verif_*.csv

suppressPackageStartupMessages({ library(haven); library(dplyr); library(readr); library(tidyr) })

cache <- "enaho/cache"
archivo <- function(anio, patron) {
  f <- list.files(file.path(cache, anio), pattern = patron, recursive = TRUE, full.names = TRUE)
  stopifnot(length(f) == 1)
  f
}
pat500 <- "^enaho01a-\\d{4}-500\\.dta$"

# 1. Imputado = deflactado donde hay dato deflactado ---------------------------
pares <- list(c("i524a1", "d524a1"), c("i530a", "d530a"), c("i538a1", "d538a1"), c("i541a", "d541a"))
v1 <- list()
for (anio in 2014:2025) {
  d <- read_dta(archivo(anio, pat500), col_select = all_of(unlist(pares)))
  for (p in pares) {
    a <- d[[p[1]]]; b <- d[[p[2]]]; ok <- !is.na(b) & b > 0
    v1[[length(v1) + 1]] <- tibble(anio = anio, imputada = p[1], deflactada = p[2],
      pct_iguales = round(100 * mean(abs(a[ok] - b[ok]) < 0.01), 2),
      n_solo_imputados = sum(is.na(b) & !is.na(a) & a > 0))
  }
}
v1 <- bind_rows(v1)
write_csv(v1, "enaho/inventario/verif_imputado_deflactado.csv")
cat("1. Mínimo % de coincidencia I = D en todos los años:", min(v1$pct_iguales), "\n")

# 2. Faltantes por tipo de cuestionario (ocupados) -----------------------------
vars <- c("p507", "p510a1", "p512b", "i513t", "i518", "p520", "p558a1", "p558a5",
          "i524a1", "d529t", "i530a", "d536", "i538a1", "d540t", "i541a", "d543", "d544t",
          "i538a_1", "ocupinf", "emplpsec")
v2 <- list()
for (anio in 2020:2021) {
  d <- read_dta(archivo(anio, pat500),
                col_select = c(ocu500, tipocuestionario, any_of(vars))) |>
    filter(ocu500 == 1) |> mutate(tipo = as.integer(tipocuestionario))
  v2[[length(v2) + 1]] <- d |>
    group_by(tipo) |>
    summarise(n_ocupados = n(), across(any_of(vars), ~ round(100 * mean(!is.na(.x)), 1)), .groups = "drop") |>
    mutate(anio = anio, .before = 1)
}
v2 <- bind_rows(v2)
write_csv(v2, "enaho/inventario/verif_cuestionario_2020_2021.csv")
cat("2. % de ocupados con dato, por tipo de cuestionario:\n"); print(as.data.frame(v2))

# 3. Deflactores ---------------------------------------------------------------
def25 <- read_dta(archivo(2025, "^deflactores_base2025.*\\.dta$")) |> zap_labels()
def24 <- read_dta(archivo(2024, "^deflactores_base2024.*\\.dta$")) |> zap_labels()
v3 <- inner_join(def25, def24, by = c("aniorec", "dpto"), suffix = c("_25", "_24")) |>
  filter(aniorec >= 2014) |>
  group_by(dpto) |>
  summarise(razon_i00_min = min(i00_25 / i00_24), razon_i00_max = max(i00_25 / i00_24), .groups = "drop")
write_csv(v3, "enaho/inventario/verif_deflactores.csv")
cat("3. Deflactores 2025: años", paste(range(def25$aniorec), collapse = "-"),
    "| índices en 2025 entre", paste(range(as.matrix(def25[def25$aniorec == 2025, paste0("i0", 0:8)])), collapse = " y "),
    "| máx. variación de la razón base2025/base2024 dentro de un dpto:",
    signif(max(v3$razon_i00_max - v3$razon_i00_min), 3), "\n")

# 4. Gasto e ingreso: método INEI vs definiciones solicitadas -------------------
ld <- read_dta(archivo(2025, "^despacial_ldnew\\.dta$")) |> zap_labels()
grupos <- list(
  i01 = c(paste0("gru1", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd", "4hd1", "4hd2", "4hd3", "4hd4", "4hd5")),
          "g05hd", paste0("g05hd", 1:6), "ig06hd", "sg23", "sig24", "sg25", "sig26", "sg27", "sig28"),
  i02 = paste0("gru2", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd")),
  i03 = paste0("gru3", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd")),
  i04 = c(paste0("gru4", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd")), "sg421", "sg42d1", "sg423", "sg42d3"),
  i05 = paste0("gru5", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd")),
  i06 = c(paste0("gru6", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd")), "g07hd", "ig08hd", "sg422", "sg42d2"),
  i07 = c(paste0("gru7", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd")), "sg42", "sg42d"),
  i08 = paste0("gru8", c("1hd", "2hd1", "2hd2", "3hd1", "3hd2", "3hd3", "4hd"))
)
ing_mas <- c("ingbruhd", "ingindhd", "insedthd", "ingseihd", "insedthd1", "pagesphd", "paesechd",
             "ingauthd", "isecauhd", "paesechd1", "ingexthd", "ingtrahd", "ingtexhd", "ingrenhd",
             "ingoexhd", paste0("gru", 1:8, "3hd3"), "gru24hd", "gru44hd", "gru54hd", "gru74hd",
             "gru84hd", "gru14hd5", "ia01hd", "gru34hd", "gru64hd", paste0("gru", 1:8, "3hd1"),
             "sig24", "gru14hd3", "sig26", "sig28", paste0("gru", 1:8, "3hd2"), "ig06hd", "ig08hd",
             "gru14hd4", "sg42d", "sg42d1", "sg42d2", "sg42d3")
necesarias <- unique(c(unlist(grupos), ing_mas, "ga04hd"))

v4 <- list()
for (anio in 2014:2025) {
  s <- read_dta(archivo(anio, "^sumaria-\\d{4}\\.dta$")) |> zap_labels() |> select(-any_of("ld"))
  # Como en el do-file del INEI: una variable ausente en un año vale 0
  for (x in setdiff(necesarias, names(s))) s[[x]] <- 0
  s[necesarias] <- lapply(s[necesarias], function(x) ifelse(is.na(x), 0, x))
  s <- s |>
    mutate(aniorec = anio,
           dpto = as.integer(substr(ubigeo, 1, 2)), dpto = ifelse(dpto == 7, 15, dpto),
           estrato = ifelse(dominio == 8, 1, estrato), area = ifelse(estrato < 6, 1, 2),
           dominioA = case_when(dominio %in% 1:6 ~ 2 * dominio - ifelse(area == 1, 1, 0),
                                dominio == 7 & dpto %in% c(16, 17, 25) ~ ifelse(area == 1, 15, 16),
                                dominio == 7 ~ ifelse(area == 1, 13, 14),
                                dominio == 8 ~ 17)) |>
    left_join(def25, by = c("aniorec", "dpto")) |>
    left_join(ld, by = "dominioA")
  k <- 12 * s$mieperho * s$ld
  gasto_inei <- Reduce(`+`, lapply(names(grupos), function(i) rowSums(s[grupos[[i]]]) / s[[i]])) / k
  ingreso_inei <- (rowSums(s[ing_mas]) - s$ga04hd) / (k * s$i00)
  w <- s$factor07 * s$mieperho
  wm <- function(x) weighted.mean(x, w)
  v4[[length(v4) + 1]] <- tibble(
    anio = anio, hogares = nrow(s), sin_deflactor = sum(is.na(s$i00) | is.na(s$ld)),
    gasto_inei_grupos = wm(gasto_inei),
    gasto_gashog2d_i00 = wm(s$gashog2d / (k * s$i00)),
    ingreso_inei = wm(ingreso_inei),
    ingreso_bruto_inghog1d = wm(s$inghog1d / (k * s$i00)),
    ingreso_neto_inghog2d = wm(s$inghog2d / (k * s$i00))
  )
}
v4 <- bind_rows(v4) |>
  mutate(dif_gasto_pct = 100 * (gasto_gashog2d_i00 / gasto_inei_grupos - 1),
         dif_ingreso_bruto_pct = 100 * (ingreso_bruto_inghog1d / ingreso_inei - 1),
         dif_ingreso_neto_pct = 100 * (ingreso_neto_inghog2d / ingreso_inei - 1)) |>
  mutate(across(where(is.double), ~ round(.x, 2)))
write_csv(v4, "enaho/inventario/verif_gasto_ingreso.csv")
cat("4. Gasto e ingreso real per cápita mensual (S/ de 2025, precios de Lima Metropolitana):\n")
print(as.data.frame(v4))
