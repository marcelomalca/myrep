# 05_disponibilidad.R (inventario)
# Tabla de disponibilidad: para cada indicador y año, las variables de origen,
# si existen en el archivo descargado, la redacción de la pregunta (etiqueta de
# la primera variable) y su codificación.
#
# Uso: Rscript delincuencia/inventario/05_disponibilidad.R
# Entradas: variables_por_anio.csv (01_metadatos.R), tipos_delito_enapres.csv
# Salida:   delincuencia/inventario/disponibilidad.csv

suppressPackageStartupMessages({ library(dplyr); library(readr); library(purrr) })

meta <- read_csv("delincuencia/inventario/variables_por_anio.csv", show_col_types = FALSE)
tipos <- read_csv("delincuencia/inventario/tipos_delito_enapres.csv", col_types = cols(.default = "c"))

sufijos <- function(anio, t) {
  col <- if (anio <= 2023) "sufijo_2014_2023" else if (anio == 2024) "sufijo_2024" else "sufijo_2025"
  i <- match(t, tipos$tipo)
  i <- i[as.integer(tipos$desde[i]) <= anio & as.integer(tipos$hasta[i]) >= anio]
  s <- tipos[[col]][i]
  s[!is.na(s) & s != ""]
}
pv <- function(anio) if (anio <= 2023) "P601_" else if (anio == 2024) "P615_" else "P424_"
pd <- function(anio) if (anio <= 2023) "P606_" else if (anio == 2024) "P619_" else "P428_"
pa <- function(anio) if (anio <= 2023) "P605_" else if (anio == 2024) "P632_" else "P451_"
pre <- function(p, s) if (length(s)) paste0(p, s) else character()
tipos_victima <- tipos$tipo[tipos$tipo != "vandalismo"]
tipos_comun <- tipos$tipo[tipos$lista_comun == "1"]

# indicador -> función(anio) que devuelve c(modulo, variables...)
defs <- list(
  victima_lista_comun   = function(a) list("enapres_seguridad", pre(pv(a), sufijos(a, tipos_comun))),
  victima_lista_completa = function(a) list("enapres_seguridad", pre(pv(a), sufijos(a, tipos_victima))),
  robo_dinero           = function(a) list("enapres_seguridad", pre(pv(a), sufijos(a, c("robo_dinero", "intento_robo_dinero")))),
  robo_vehiculo         = function(a) list("enapres_seguridad", pre(pv(a), sufijos(a, c("robo_vehiculo", "robo_moto")))),
  amenazas              = function(a) list("enapres_seguridad", pre(pv(a), sufijos(a, "amenazas"))),
  extorsion             = function(a) list("enapres_seguridad", pre(pv(a), sufijos(a, "extorsion"))),
  intento_extorsion     = function(a) list("enapres_seguridad", pre(pv(a), sufijos(a, "intento_extorsion"))),
  estafa                = function(a) list("enapres_seguridad", pre(pv(a), sufijos(a, "estafa"))),
  robo_negocio          = function(a) list("enapres_seguridad", pre(pv(a), sufijos(a, "robo_negocio"))),
  ofensas_sexuales      = function(a) list("enapres_seguridad", pre(pv(a), sufijos(a, "ofensas_sexuales"))),
  arma_fuego            = function(a) list("enapres_seguridad", as.vector(outer(pre(pa(a), sufijos(a, tipos_victima)), c("_1", "_2"), paste0))),
  denuncio              = function(a) list("enapres_seguridad", pre(pd(a), sufijos(a, tipos_victima))),
  percepcion            = function(a) list("enapres_seguridad", if (a <= 2023) paste0("P611_", 1:14) else if (a == 2024) paste0("P601_", 1:16) else c("P401", paste0("P402_", c(1:13, 15)))),
  peso_personas         = function(a) list("enapres_seguridad", if (a <= 2015) "FACTORANUALCAP600" else if (a <= 2017) "FACTORANUAL" else "FACTOR"),
  peso_percepcion       = function(a) list("enapres_seguridad", if (a == 2024) "FACTOR_CAP600B" else if (a == 2025) "FACTOR_CAP400" else if (a <= 2015) "FACTORANUALCAP600" else if (a <= 2017) "FACTORANUAL" else "FACTOR"),
  peso_calibrado_2020_21 = function(a) list("enapres_seguridad", if (a %in% 2020:2021) "FACTOR_CALIBRADO" else character()),
  modalidad_entrevista  = function(a) list("enapres_seguridad", if (a %in% 2020:2022) "MOD_ENC" else character()),
  robo_vivienda         = function(a) list("enapres_cap100", if (a >= 2024) c("P116_1", "P116_2") else c("P112_1", "P112_2")),
  peso_hogares_enapres  = function(a) list("enapres_cap100", if (a <= 2017) "FACTORANUAL" else "FACTOR"),
  ubigeo_enapres        = function(a) list("enapres_seguridad", c("CCDD", "CCPP", "CCDI")),
  enaho_hecho_delictivo = function(a) list("enaho_m85_2", "p40_5"),
  enaho_peso_hogar      = function(a) list("enaho_m85_2", "factor07"),
  enaho_problema_delincuencia = function(a) list("enaho_m85_1", c("p2_1_15", "p2_2_15")),
  enaho_problema_falta_seguridad = function(a) list("enaho_m85_1", c("p2_1_04", "p2_2_04")),
  enaho_confianza_pnp   = function(a) list("enaho_m85_1", "p1_06"),
  enaho_peso_opinion    = function(a) list("enaho_m85_1", if (a == 2014) "facgob07" else "famiegob07"),
  enaho_ubigeo          = function(a) list("enaho_m85_2", "ubigeo")
)

disp <- map_dfr(names(defs), function(ind) map_dfr(2014:2025, function(a) {
  x <- defs[[ind]](a); mod <- x[[1]]; v <- x[[2]]
  if (!length(v)) return(tibble(indicador = ind, anio = a, modulo = mod, archivo = NA, n_variables = 0L,
                                variables = "(no existe este año)", faltantes = "", etiqueta = NA, codificacion = NA))
  mm <- meta |> filter(anio == a, modulo == mod)
  esta <- tolower(v) %in% mm$variable_min
  primera <- mm[match(tolower(v[esta][1]), mm$variable_min), ]
  tibble(indicador = ind, anio = a, modulo = mod, archivo = paste(unique(mm$archivo), collapse = " | "),
         n_variables = length(v), variables = paste(v, collapse = " "),
         faltantes = paste(v[!esta], collapse = " "),
         etiqueta = primera$etiqueta, codificacion = primera$etiquetas_valor)
}))
write_csv(disp, "delincuencia/inventario/disponibilidad.csv")
cat("Filas:", nrow(disp), "| con variables faltantes:", sum(disp$faltantes != ""), "\n")
print(disp |> filter(faltantes != "") |> select(indicador, anio, faltantes), n = 50)
