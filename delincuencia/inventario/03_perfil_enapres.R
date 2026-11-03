# 03_perfil_enapres.R (inventario)
# Perfil del capítulo de seguridad ciudadana de la ENAPRES por año: área, edad,
# resultado de la entrevista, factores de expansión, meses y códigos geográficos.
# Uso: Rscript delincuencia/inventario/03_perfil_enapres.R
# Salida: delincuencia/inventario/perfil_enapres.csv

suppressPackageStartupMessages({ library(haven); library(dplyr); library(readr) })
arch <- function(anio, patron) list.files(file.path("delincuencia/cache/enapres", anio), pattern = patron,
                                         recursive = TRUE, full.names = TRUE)
# Variable de víctima de robo de dinero, cartera, celular (para medir respuesta)
v_robo <- c(setNames(rep("P601_6A", 10), 2014:2023), "2024" = "P615_9", "2025" = "P424_9")
v_perc <- c(setNames(rep("P611_6", 10), 2014:2023), "2024" = "P601_6", "2025" = "P401")
pesos <- c("FACTORANUALCAP600", "FACTORANUAL", "FACTOR", "FACTOR_CALIBRADO", "FACTOR_CAP600B", "FACTOR_CAP400")

filas <- list()
for (anio in 2014:2025) {
  f <- arch(anio, "CAP_?[64]00.*\\.sav$")
  d <- read_sav(f, col_select = any_of(c("MES", "AREA", "CCDD", "CCPP", "CCDI", "P208_A", "RESFIN",
                                           pesos, v_robo[[as.character(anio)]], v_perc[[as.character(anio)]]))) |>
    zap_labels()
  w <- intersect(pesos, names(d))
  rob <- d[[v_robo[[as.character(anio)]]]]; per <- d[[v_perc[[as.character(anio)]]]]
  peso_principal <- intersect(c("FACTORANUALCAP600", "FACTORANUAL", "FACTOR"), names(d))[1]
  filas[[length(filas) + 1]] <- tibble(
    anio = anio, archivo = basename(f), filas = nrow(d),
    area = paste(names(table(d$AREA)), table(d$AREA), sep = ":", collapse = " "),
    edad_min = min(d$P208_A, na.rm = TRUE), edad_max = max(d$P208_A, na.rm = TRUE),
    resfin = paste(names(table(d$RESFIN, useNA = "ifany")), table(d$RESFIN, useNA = "ifany"), sep = ":", collapse = " "),
    pesos = paste(sapply(w, function(x) sprintf("%s(no NA %d)", x, sum(!is.na(d[[x]]) & d[[x]] > 0))), collapse = " "),
    peso_principal = peso_principal,
    robo_no_na = sum(!is.na(rob)), percepcion_no_na = sum(!is.na(per)),
    meses = paste(sort(unique(d$MES)), collapse = ","),
    ccdi_nchar = paste(names(table(nchar(as.character(d$CCDI)))), collapse = "/"),
    ccdd_nchar = paste(names(table(nchar(as.character(d$CCDD)))), collapse = "/"),
    ejemplo_ubigeo = paste0(d$CCDD[1], "|", d$CCPP[1], "|", d$CCDI[1])
  )
}
perfil <- bind_rows(filas)
write_csv(perfil, "delincuencia/inventario/perfil_enapres.csv")
print(as.data.frame(perfil |> select(anio, filas, area, edad_min, edad_max, resfin)))
print(as.data.frame(perfil |> select(anio, pesos, robo_no_na, percepcion_no_na)))
print(as.data.frame(perfil |> select(anio, meses, ccdd_nchar, ccdi_nchar, ejemplo_ubigeo)))
