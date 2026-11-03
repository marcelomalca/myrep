# 08_verificacion.R
# Compara los resultados nacionales de las bases con las cifras publicadas por
# el INEI y reporta las diferencias.
#
# Fuentes oficiales (valores transcritos de las publicaciones):
#   [V] INEI (2025). Victimización en el Perú 2024. Lima: INEI (ENAPRES 2015-2024).
#       https://www.inei.gob.pe/media/MenuRecursivo/publicaciones_digitales/Est/Lib2013/libro.pdf
#       Cuadro 1.1  población urbana de 15 y más años víctima de algún hecho delictivo
#       Cuadro 1.10 víctimas que realizaron la denuncia
#       Cuadro 1.17 víctimas de algún hecho cometido con arma de fuego (% de las víctimas)
#       Cuadro 2.1  viviendas urbanas afectadas por robo e intento de robo
#       Cuadro 3.1  población urbana de 15 y más años con percepción de inseguridad
#       Las cifras 2015-2021 coinciden con INEI (2022), Victimización en el Perú 2015-2021 (Lib1850).
#   [G] INEI (2025). Perú: Percepción ciudadana sobre gobernabilidad, democracia y
#       confianza en las instituciones, julio-diciembre 2024 (ENAHO; cifras de 2024
#       preliminares). Principales problemas del país y confianza en la PNP,
#       semestres julio-diciembre 2023 y 2024.
#       https://www.inei.gob.pe/media/MenuRecursivo/boletines/6524421-01-informe-tecnico-gobernabilidad-julio-diciembre-2024.pdf
#
# Para el hogar afectado por hecho delictivo de la ENAHO (p40_5) no se encontró
# una cifra publicada por el INEI; se reporta sin valor oficial.
#
# Uso: Rscript delincuencia/08_verificacion.R
# Salida: delincuencia/datos_procesados/verificacion_oficial.csv

source("delincuencia/funciones.R")

serie <- function(indicador, valores, fuente) {
  tibble(indicador = indicador, anio = 2015:2024, oficial = valores, fuente = fuente)
}
oficial <- bind_rows(
  serie("victimizacion", c(30.8, 28.8, 26.4, 25.7, 26.6, 23.4, 18.2, 22.9, 27.1, 27.1), "V, cuadro 1.1"),
  serie("denuncia", c(14.0, 12.8, 14.5, 16.2, 16.7, 17.0, 15.3, 14.9, 15.6, 16.1), "V, cuadro 1.10"),
  serie("arma_fuego_entre_victimas", c(8.1, 8.9, 9.2, 9.1, 11.3, 12.6, 12.6, 11.3, 12.7, 10.1), "V, cuadro 1.17"),
  serie("robo_vivienda", c(11.4, 10.8, 10.5, 9.5, 9.4, 10.4, 8.8, 9.9, 12.9, 10.8), "V, cuadro 2.1"),
  serie("percepcion", c(88.4, 90.0, 86.9, 86.3, 85.8, 83.2, 83.9, 85.2, 83.6, 86.0), "V, cuadro 3.1"),
  tribble(
    ~indicador,                         ~anio, ~oficial, ~fuente,
    "delincuencia_problema (jul-dic)",   2023,  38.0,    "G, principales problemas",
    "delincuencia_problema (jul-dic)",   2024,  45.0,    "G, principales problemas (preliminar)",
    "falta_seguridad_problema (jul-dic)", 2023, 13.5,    "G, principales problemas",
    "falta_seguridad_problema (jul-dic)", 2024, 17.6,    "G, principales problemas (preliminar)",
    "confia_pnp (jul-dic)",              2023,  20.1,    "G, confianza en las instituciones",
    "confia_pnp (jul-dic)",              2024,  18.0,    "G, confianza en las instituciones (preliminar)"
  )
)

leer_base <- function(nombre) arrow::read_parquet(file.path(PROCESADO, paste0(nombre, ".parquet")))
per <- leer_base("enapres_personas")
viv <- leer_base("enapres_hogares")
hog <- leer_base("enaho_hogares")
op  <- leer_base("enaho_opinion")
pct <- function(x, w) 100 * media_pond(x, w)

# Falta de seguridad ciudadana sola (p2_1_04): no es una variable de las bases,
# se calcula aquí solo para comparar con [G]
falta_seg <- bind_rows(lapply(2023:2024, function(anio) {
  d <- leer_dta(archivo("enaho", anio, PAT_ENAHO_OPINION), c("mes", "p2_1_04", "famiegob07"))
  d <- d[as.integer(d$mes) >= 7 & !is.na(d$p2_1_04) & !is.na(d$famiegob07) & d$famiegob07 > 0, ]
  tibble(anio = anio, valor = pct(d$p2_1_04 == 4, d$famiegob07))
}))

construido <- bind_rows(
  per |> group_by(anio) |> summarise(
    `victimizacion|victima_comun` = pct(victima_comun, factor),
    `victimizacion|victima_completa` = pct(victima_completa, factor),
    `denuncia|denuncio (víctimas de la lista completa)` = pct(denuncio, factor),
    `denuncia|denuncio entre víctimas de la lista común` = pct(denuncio[victima_comun %in% 1], factor[victima_comun %in% 1]),
    `arma_fuego_entre_victimas|arma_fuego entre víctimas de la lista común` =
      pct(arma_fuego[victima_comun %in% 1], factor[victima_comun %in% 1]),
    `arma_fuego_entre_victimas|arma_fuego entre víctimas de la lista completa` =
      pct(arma_fuego[victima_completa %in% 1], factor[victima_completa %in% 1]),
    `percepcion|percepcion` = pct(percepcion, factor_percepcion),
    .groups = "drop") |>
    pivot_longer(-anio, names_to = c("indicador", "version"), names_sep = "\\|", values_to = "construido"),
  viv |> group_by(anio) |> summarise(construido = pct(robo_vivienda, factor), .groups = "drop") |>
    mutate(indicador = "robo_vivienda", version = "robo_vivienda"),
  op |> filter(mes >= 7) |> group_by(anio) |> summarise(
    `delincuencia_problema (jul-dic)|delincuencia_problema` = pct(delincuencia_problema, factor),
    `confia_pnp (jul-dic)|confia_pnp` = pct(confia_pnp, factor), .groups = "drop") |>
    pivot_longer(-anio, names_to = c("indicador", "version"), names_sep = "\\|", values_to = "construido"),
  falta_seg |> transmute(anio, indicador = "falta_seguridad_problema (jul-dic)",
                         version = "p2_1_04 = 4 (solo para verificar)", construido = valor),
  hog |> group_by(anio) |> summarise(construido = pct(hecho_delictivo, factor07), .groups = "drop") |>
    mutate(indicador = "enaho_hecho_delictivo", version = "hecho_delictivo")
)

verif <- construido |>
  left_join(oficial, by = c("indicador", "anio")) |>
  mutate(construido = round(construido, 1), diferencia = round(construido - oficial, 1)) |>
  select(indicador, version, anio, oficial, construido, diferencia, fuente) |>
  arrange(indicador, version, anio)
write_csv(verif, file.path(PROCESADO, "verificacion_oficial.csv"), na = "")

options(width = 160)
print(as.data.frame(verif |> filter(!is.na(oficial))), row.names = FALSE)
cat("\nDiferencia absoluta máxima por indicador y versión (años con cifra oficial):\n")
print(as.data.frame(verif |> filter(!is.na(oficial)) |> group_by(indicador, version) |>
  summarise(max_abs = max(abs(diferencia)), media = round(mean(diferencia), 2), .groups = "drop")), row.names = FALSE)
