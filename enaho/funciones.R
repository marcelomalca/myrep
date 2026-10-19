# funciones.R
# Funciones y constantes compartidas por los scripts numerados de enaho/.
# No se ejecuta solo: cada script lo carga con source("enaho/funciones.R").

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
  library(tidyr)
  library(readr)
})

ANIOS     <- 2014:2025
CACHE     <- "enaho/cache"
PROCESADO <- "enaho/datos_procesados"
dir.create(PROCESADO, showWarnings = FALSE, recursive = TRUE)

# Año base de los deflactores (edición publicada con la ENAHO 2025)
ANIO_BASE <- 2025

# Ruta del archivo de un año que cumple un patrón; falla si no hay exactamente uno
archivo <- function(anio, patron) {
  f <- list.files(file.path(CACHE, anio), pattern = patron, recursive = TRUE,
                  full.names = TRUE, ignore.case = TRUE)
  if (length(f) != 1) stop("Se esperaba un archivo para ", anio, " con ", patron,
                           " y se encontraron ", length(f), ": ", paste(f, collapse = ", "))
  f
}
PAT_SUMARIA <- "^sumaria-\\d{4}\\.dta$"
PAT_M200    <- "^enaho01-\\d{4}-200\\.dta$"
PAT_M400    <- "^enaho01a-\\d{4}-400\\.dta$"
# 2015 trae además "enaho01a-2015_500.dta" (duplicado, ver diccionario.md)
PAT_M500    <- "^enaho01a-\\d{4}-500\\.dta$"

# Lee un .dta con solo las columnas pedidas que existan, sin etiquetas haven
leer <- function(f, columnas = NULL) {
  d <- if (is.null(columnas)) read_dta(f) else read_dta(f, col_select = any_of(columnas))
  zap_labels(zap_formats(d))
}

# Identificadores de la ENAHO como texto con ancho fijo
# (conglome tiene 4 dígitos en 2014 y 6 desde 2015; el INEI completa con ceros)
normalizar_ids <- function(d) {
  rellenar <- function(x, n) formatC(as.integer(x), width = n, flag = "0")
  d |> mutate(
    conglome = rellenar(conglome, 6),
    vivienda = rellenar(vivienda, 3),
    hogar    = rellenar(hogar, 2),
    across(any_of("codperso"), ~ rellenar(.x, 2)),
    across(any_of("ubigeo"), ~ rellenar(.x, 6))
  )
}

# Residente habitual (definición del INEI): miembro presente, o no miembro que
# vive en el hogar hace 30 días o más
es_residente <- function(p204, p205, p206) {
  (p204 %in% 1 & p205 %in% 2) | (p204 %in% 2 & p206 %in% 1)
}

# Área (1 urbana, 2 rural) y dominio de 17 categorías del deflactor espacial,
# tal como en el do-file del INEI (01_ConstrVarGastoIngreso2015-2025.do)
agregar_dominio_deflactor <- function(d) {
  d |> mutate(
    dpto = as.integer(substr(ubigeo, 1, 2)),
    dpto_defl = ifelse(dpto == 7, 15L, dpto),            # Callao usa el índice de Lima
    estrato_defl = ifelse(dominio == 8, 1, estrato),       # Lima Metropolitana es urbana
    area = ifelse(estrato_defl < 6, 1L, 2L),
    dominioA = case_when(
      dominio %in% 1:6 ~ as.integer(2 * dominio - ifelse(area == 1, 1, 0)),
      dominio == 7 & dpto %in% c(16, 17, 25) ~ ifelse(area == 1, 15L, 16L),
      dominio == 7 ~ ifelse(area == 1, 13L, 14L),
      dominio == 8 ~ 17L
    )
  ) |> select(-estrato_defl)
}

# Deflactores temporales (base ANIO_BASE) y espacial (Lima Metropolitana = 1)
leer_deflactores <- function() {
  temp <- leer(archivo(ANIO_BASE, sprintf("^deflactores_base%d.*\\.dta$", ANIO_BASE))) |>
    rename(anio = aniorec, dpto_defl = dpto) |>
    mutate(across(everything(), as.numeric), anio = as.integer(anio), dpto_defl = as.integer(dpto_defl))
  esp <- leer(archivo(ANIO_BASE, "^despacial_ldnew\\.dta$")) |>
    mutate(dominioA = as.integer(dominioA), ld = as.numeric(ld))
  list(temporal = temp, espacial = esp)
}

# Escribe una base en parquet y csv
guardar <- function(d, nombre) {
  if (!requireNamespace("arrow", quietly = TRUE))
    stop("Falta el paquete 'arrow' (install.packages('arrow')) para escribir parquet")
  arrow::write_parquet(d, file.path(PROCESADO, paste0(nombre, ".parquet")))
  write_csv(d, file.path(PROCESADO, paste0(nombre, ".csv")), na = "")
  cat("Guardado", nombre, ":", nrow(d), "filas x", ncol(d), "columnas\n")
}

# Promedio ponderado que ignora faltantes
media_pond <- function(x, w) {
  ok <- !is.na(x) & !is.na(w)
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}

# Empleo informal y empleo en el sector informal (ocupación principal), según el
# procedimiento del INEI para la ENAHO desde 2012 (Producción y empleo informal
# en el Perú, Anexo B3, figuras B3.2 a B3.5), con dos precisiones obtenidas al
# validar contra las variables oficiales ocupinf/emplpsec de 2014-2023:
#   - TFNR y "otro" están en el sector informal si la unidad no está registrada
#     en SUNAT o tiene hasta 5 trabajadores;
#   - el empleo en el sector informal se define, como emplpsec, solo para el
#     empleo informal.
# Requiere: p507, p510, p510a1, p512a, p512b, p506 (CIIU rev. 3) y p419a1-p419a8.
clasificar_informalidad <- function(d) {
  agro <- floor(as.numeric(d$p506) / 100) %in% c(1, 2, 5)   # agricultura, silvicultura, pesca (rev. 3)
  seguro_por_empleo <- Reduce(`|`, lapply(1:8, function(k) d[[paste0("p419a", k)]] %in% 1))
  # Paso 1: unidades de los hogares productores de mercado (no sociedades ni cuasisociedades)
  hogar_mercado <- case_when(
    d$p507 %in% c(5, 7) ~ TRUE,
    d$p507 == 6 ~ FALSE,                                    # hogares que emplean trabajadores del hogar
    d$p507 %in% c(3, 4) & d$p510 %in% 1:5 ~ FALSE,           # FFAA, sector público, cooperativas, services
    d$p510a1 %in% 1 ~ FALSE,                                 # persona jurídica
    agro ~ TRUE,
    !is.na(d$p512b) & d$p512b <= 30 ~ TRUE,                  # más de 30 trabajadores = cuasisociedad
    is.na(d$p512b) & d$p512a %in% 1 ~ TRUE,
    TRUE ~ FALSE
  )
  # Paso 2: sector informal (unidades no registradas en SUNAT o agropecuarias)
  sector_informal <- case_when(
    d$p507 %in% c(5, 7) ~ agro | d$p510a1 %in% 3 | (!is.na(d$p512b) & d$p512b <= 5),
    TRUE ~ hogar_mercado & d$p507 != 6 & (agro | d$p510a1 %in% 3)
  )
  # Pasos 3 y 4: empleo informal
  asalariado <- d$p507 %in% c(3, 4, 6)
  informal <- case_when(
    sector_informal ~ TRUE,
    d$p507 %in% c(5, 7) ~ TRUE,
    asalariado ~ !seguro_por_empleo,                         # seguro de salud no pagado por el empleador
    TRUE ~ FALSE
  )
  tibble(empleo_informal = as.integer(informal),
         empleo_sector_informal = as.integer(sector_informal & informal),
         seguro_salud_empleo = as.integer(seguro_por_empleo))
}

# Sección de la CIIU rev. 4 a partir de la división (2 dígitos)
seccion_ciiu4 <- function(div) {
  cortes <- c(1, 5, 10, 35, 36, 41, 45, 49, 55, 58, 64, 68, 69, 77, 84, 85, 86, 90, 94, 97, 99, 100)
  letras <- c("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U")
  out <- as.character(cut(div, breaks = cortes, labels = letras, right = FALSE))
  out[is.na(div)] <- NA_character_
  out
}
