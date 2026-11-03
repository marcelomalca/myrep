# 03_enapres_personas.R
# Base apilada de personas de la ENAPRES 2014-2025 (capítulo de seguridad
# ciudadana: 600 en 2014-2024, 400 en 2025) con los indicadores de
# victimización y percepción aprobados en el inventario (decisiones D1-D9, D15).
#
# Universo: población urbana de 15 años y más con factor de expansión > 0
# (el capítulo solo se aplica en el área urbana).
#
# Uso: Rscript delincuencia/03_enapres_personas.R
# Salida: delincuencia/datos_procesados/enapres_personas.{parquet,csv}

source("delincuencia/funciones.R")

tipos <- read_csv("delincuencia/inventario/tipos_delito_enapres.csv", col_types = cols(.default = "c"))

# Prefijos de las preguntas: víctima, denunció, tipo de arma
prefijos <- function(anio) {
  if (anio <= 2023) c(v = "P601_", d = "P606_", a = "P605_")
  else if (anio == 2024) c(v = "P615_", d = "P619_", a = "P632_")
  else c(v = "P424_", d = "P428_", a = "P451_")
}
# Sufijo del ítem de cada tipo de delito en un año (vacío si no existe ese año)
sufijo <- function(anio, tipo) {
  col <- if (anio <= 2023) "sufijo_2014_2023" else if (anio == 2024) "sufijo_2024" else "sufijo_2025"
  i <- match(tipo, tipos$tipo)
  s <- tipos[[col]][i]
  vigente <- as.integer(tipos$desde[i]) <= anio & as.integer(tipos$hasta[i]) >= anio
  ifelse(!is.na(s) & s != "" & vigente, s, NA_character_)
}

# D1: lista completa = todos los tipos del año menos vandalismo (víctima o testigo);
#     lista común = solo los tipos presentes en los 12 años.
TIPOS_COMPLETA <- setdiff(tipos$tipo, "vandalismo")
TIPOS_COMUN    <- tipos$tipo[tipos$lista_comun == "1"]

construir <- function(anio) {
  p <- prefijos(anio)
  suf_completa <- na.omit(sufijo(anio, TIPOS_COMPLETA))
  suf_comun    <- na.omit(sufijo(anio, TIPOS_COMUN))
  v_completa <- paste0(p["v"], suf_completa)
  v_comun    <- paste0(p["v"], suf_comun)
  den        <- paste0(p["d"], suf_completa)
  arma       <- as.vector(outer(paste0(p["a"], suf_completa), c("_1", "_2"), paste0))
  percep <- if (anio <= 2023) paste0("P611_", 1:14) else if (anio == 2024) paste0("P601_", 1:16)
            else c("P401", paste0("P402_", c(1:13, 15)))
  pesos <- c("FACTORANUALCAP600", "FACTORANUAL", "FACTOR", "FACTOR_CAP600B", "FACTOR_CAP400")

  f <- archivo("enapres", anio, PAT_ENAPRES_SEGURIDAD)
  d <- leer_sav(f, c("MES", "CONGLOMERADO", "NSELV", "VIVIENDA", "HOGAR", "P201", "AREA",
                     "CCDD", "CCPP", "CCDI", "P208_A", "RESFIN", "MOD_ENC",
                     pesos, v_completa, den, arma, percep))
  faltan <- setdiff(c(v_completa, den, percep), names(d))
  if (length(faltan)) stop("ENAPRES ", anio, ": faltan ", paste(faltan, collapse = ", "))
  stopifnot(all(d$AREA == 1))

  item <- function(tipo) {                       # 1 si fue víctima de ese tipo (1 = Sí)
    s <- sufijo(anio, tipo)
    if (is.na(s)) return(rep(NA_integer_, nrow(d)))
    as.integer(d[[paste0(p["v"], s)]] == 1)
  }
  victima_completa <- alguno(d[v_completa])
  peso <- d[[intersect(c("FACTORANUALCAP600", "FACTORANUAL", "FACTOR"), names(d))[1]]]

  # D6: percepción. 2014-2023 y 2024: "Sí" en al menos un ítem por tipo de delito;
  # 2025: "Sí" en al menos un ítem de P402. P401 (pregunta general de 2025) va aparte.
  percepcion <- if (anio == 2025) {
    ifelse(is.na(d$P401), NA_integer_, alguno(d[setdiff(percep, "P401")]))
  } else alguno(d[percep])
  # Columnas que dependen del año (fuera del tibble, donde 'anio' sería la columna)
  extorsion_o_intento <- if (anio >= 2016) pmax(item("extorsion"), item("intento_extorsion")) else NA_integer_
  percepcion_general_2025 <- if (anio == 2025) as.integer(d$P401 == 1) else NA_integer_
  submuestra <- anio >= 2024
  peso_percepcion <- if (anio == 2024) d$FACTOR_CAP600B else if (anio == 2025) d$FACTOR_CAP400 else peso

  tibble(
    anio = as.integer(anio), mes = as.integer(d$MES),
    conglomerado = como_id(d$CONGLOMERADO), nselv = como_id(d$NSELV),
    vivienda = como_id(d$VIVIENDA), hogar = como_id(d$HOGAR), persona = como_id(d$P201),
    ubigeo = ubigeo_enapres(d$CCDD, d$CCPP, d$CCDI),
    edad = as.integer(d$P208_A), resfin = as.integer(d$RESFIN),
    modalidad = if ("MOD_ENC" %in% names(d)) as.integer(d$MOD_ENC) else NA_integer_,
    factor = as.numeric(peso),
    # D1
    victima_comun = alguno(d[v_comun]),
    victima_completa = victima_completa,
    # D3: robo o intento de robo de dinero, cartera, celular
    robo_dinero = pmax(item("robo_dinero"), item("intento_robo_dinero")),
    # D4: robo consumado de vehículo automotor o de motocicleta/mototaxi ("no tiene" = 0)
    robo_vehiculo = pmax(item("robo_vehiculo"), item("robo_moto")),
    amenazas = item("amenazas"),
    # D5: extorsión consumada; extorsión o intento desde 2016
    extorsion = item("extorsion"),
    extorsion_o_intento = extorsion_o_intento,
    estafa = item("estafa"),
    robo_negocio = item("robo_negocio"),
    ofensas_sexuales = item("ofensas_sexuales"),
    # D8: víctima de algún delito con arma de fuego (de mano o larga), sobre toda la población
    arma_fuego = ifelse(is.na(victima_completa), NA_integer_,
                        as.integer(rowSums(as.matrix(d[intersect(arma, names(d))]) == 1, na.rm = TRUE) > 0)),
    # D7: entre las víctimas (lista completa), denunció al menos un hecho
    denuncio = ifelse(victima_completa %in% 1,
                      as.integer(rowSums(as.matrix(d[den]) == 1, na.rm = TRUE) > 0), NA_integer_),
    percepcion = percepcion,
    percepcion_general_2025 = percepcion_general_2025,
    factor_percepcion = as.numeric(peso_percepcion),
    submuestra_percepcion = submuestra
  )
}

per <- bind_rows(lapply(ANIOS, function(a) { cat("ENAPRES", a, "\n"); construir(a) }))

# D2 y D9: 15 años y más, con factor > 0 (sin filtrar por RESFIN)
antes <- nrow(per)
per <- per |> filter(edad >= 15, !is.na(factor), factor > 0)
cat("Filas descartadas (menores de 15 o sin factor):", antes - nrow(per), "\n")

# La percepción solo vale donde hay respuesta y factor de percepción
per <- per |> mutate(
  percepcion = ifelse(!is.na(factor_percepcion) & factor_percepcion > 0, percepcion, NA_integer_),
  percepcion_general_2025 = ifelse(!is.na(percepcion), percepcion_general_2025, NA_integer_),
  factor_percepcion = ifelse(is.na(percepcion), NA_real_, factor_percepcion),
  ubigeo_base = a_base(ubigeo)
) |> relocate(ubigeo_base, .after = ubigeo)

llave_unica(per, c("anio", "mes", "conglomerado", "nselv", "vivienda", "hogar", "persona"), "ENAPRES personas")
guardar(per, "enapres_personas")

cat("\nPrevalencia nacional (%), factor de expansión:\n")
print(as.data.frame(per |> group_by(anio) |> summarise(
  n = n(), n_percepcion = sum(!is.na(percepcion)),
  victima_comun = 100 * media_pond(victima_comun, factor),
  victima_completa = 100 * media_pond(victima_completa, factor),
  denuncio = 100 * media_pond(denuncio, factor),
  percepcion = 100 * media_pond(percepcion, factor_percepcion), .groups = "drop") |> mutate(across(where(is.double), ~ round(.x, 1)))))
