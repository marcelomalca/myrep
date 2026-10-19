# Funciones y datos comunes a los capítulos del libro.
# Las rutas son relativas a la carpeta libro/, dentro del repositorio.

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(knitr)
})
sf_use_s2(FALSE)

dir_datos <- "../datos"
dir_enaho <- "../enaho"

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
leer_csv <- function(ruta) {
  read_csv(ruta, col_types = cols(.default = col_character()), progress = FALSE)
}

# Lee una base procesada de la ENAHO. Usa el .parquet si el paquete arrow está
# instalado; si no, el .csv que generan los scripts de enaho/ en la misma carpeta.
leer_enaho <- function(nombre, columnas) {
  base <- file.path(dir_enaho, "datos_procesados", nombre)
  if (requireNamespace("arrow", quietly = TRUE) && file.exists(paste0(base, ".parquet"))) {
    as_tibble(arrow::read_parquet(paste0(base, ".parquet"), col_select = all_of(columnas)))
  } else {
    read_csv(paste0(base, ".csv"), col_select = all_of(columnas), progress = FALSE,
             col_types = cols(ubigeo = "c", ubigeo_base = "c", .default = col_guess()))
  }
}

lleno <- function(x) !is.na(x) & trimws(x) != ""
pct   <- function(x, total) round(100 * x / total, 1)
num   <- function(x, d = 0) format(round(x, d), big.mark = " ", decimal.mark = ".",
                                   nsmall = d, trim = TRUE)
media_pond <- function(x, w) {
  ok <- !is.na(x) & !is.na(w)
  sum(x[ok] * w[ok]) / sum(w[ok])
}
anio_ms  <- function(ms) as.integer(format(as.POSIXct(as.numeric(ms) / 1000,
                                                      origin = "1970-01-01", tz = "UTC"), "%Y"))
fecha_ms <- function(ms) as.Date(as.POSIXct(as.numeric(ms) / 1000,
                                            origin = "1970-01-01", tz = "UTC"))

orden_tipo <- c("Mina", "Proyecto", "Prospecto", "Ocurrencia", "Yacimiento")

# ---------------------------------------------------------------------------
# Geografía común: distritos de 2014 (ubigeo_base)
# ---------------------------------------------------------------------------
# Tabla de correspondencia construida con la ENAHO (enaho/05_geografia.R):
# asigna los distritos creados después de 2014 a su distrito de origen y une
# Mazamari, Pangoa y el código 120699 de la ENAHO en una sola unidad.
correspondencia <- leer_csv(file.path(dir_enaho, "geografia/correspondencia_ubigeo.csv")) |>
  select(ubigeo, ubigeo_base) |>
  distinct()

a_base <- function(codigo) {
  base <- correspondencia$ubigeo_base[match(codigo, correspondencia$ubigeo)]
  if_else(is.na(base), codigo, base)
}

limites <- st_read(file.path(dir_datos, "insumos/peru_distrital_simple.geojson"),
                   quiet = TRUE) |>
  select(IDDIST, IDDPTO, geometry) |>
  mutate(ubigeo_base = a_base(IDDIST))

departamentos <- limites |> group_by(IDDPTO) |> summarise(.groups = "drop")

# ---------------------------------------------------------------------------
# Yacimientos de oro (GEOCATMIN)
# ---------------------------------------------------------------------------
aluvial <- function(st) ifelse(st %in% c("Placer", "Aluviales"),
                               "Aluvial (placer o aluvial)", "En roca")

# Asigna cada registro a su distrito de 2014: por la tabla de correspondencia o,
# si el código no está en ella ni en la cartografía, por el polígono que
# contiene su punto.
asignar_base <- function(d) {
  d <- d |> mutate(lat = as.numeric(lat), lon = as.numeric(lon))
  pts <- st_as_sf(d, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
  esp <- st_join(pts, limites |> select(id_espacial = IDDIST), join = st_within) |>
    st_drop_geometry()
  esp |>
    mutate(ubigeo_base = case_when(
      DISTRITO %in% correspondencia$ubigeo ~ a_base(DISTRITO),
      DISTRITO %in% limites$IDDIST         ~ a_base(DISTRITO),
      TRUE                                 ~ a_base(id_espacial)
    )) |>
    select(-id_espacial)
}

capa <- leer_csv(file.path(dir_datos, "yacimientos.csv"))
oro  <- leer_csv(file.path(dir_datos, "yacimientos_oro_principal.csv")) |>
  asignar_base()
pre  <- leer_csv(file.path(dir_datos, "yacimientos_oro_principal_pre2014.csv")) |>
  asignar_base() |>
  mutate(deposito = aluvial(ST_YACIM))

# Clasificación de las unidades distritales según sus yacimientos de oro
niveles_cat <- c("Con mina o proyecto antes de 2014",
                 "Solo prospectos u ocurrencias antes de 2014",
                 "Con oro registrado solo desde 2014",
                 "Sin yacimientos de oro registrados")

ids_pre     <- unique(na.omit(pre$ubigeo_base))
ids_mina    <- unique(na.omit(pre$ubigeo_base[pre$COD_TIPO %in% c("Mina", "Proyecto")]))
ids_aluvial <- unique(na.omit(pre$ubigeo_base[pre$deposito == "Aluvial (placer o aluvial)"]))
ids_post    <- setdiff(unique(na.omit(oro$ubigeo_base)), ids_pre)

clasificar <- function(ubigeo_base) {
  factor(case_when(
    ubigeo_base %in% ids_mina ~ niveles_cat[1],
    ubigeo_base %in% ids_pre  ~ niveles_cat[2],
    ubigeo_base %in% ids_post ~ niveles_cat[3],
    TRUE                      ~ niveles_cat[4]
  ), levels = niveles_cat)
}

unidades <- tibble(ubigeo_base = unique(limites$ubigeo_base)) |>
  mutate(categoria = clasificar(ubigeo_base))
