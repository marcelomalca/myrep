# 05_geografia.R
# Agrega ubigeo_base: asigna los distritos creados después de 2014 a su distrito
# de origen, para tener unidades geográficas constantes en 2014-2025.
#
# Base geográfica: los 1834 distritos de datos/insumos/peru_distrital_simple.geojson
# (límites INEI). Todos los códigos de la ENAHO 2014 existen en esa capa, salvo
# 120699 (Mazamari-Pangoa), por lo que se toma como la división vigente en 2014.
#
# Reglas, en orden de prioridad:
#   1. Correspondencia manual (enaho/geografia/correspondencia_manual.csv):
#      casos sin coordenadas y la unión Mazamari-Pangoa.
#   2. Código presente en la capa de 2014: se mantiene.
#   3. Código nuevo: distrito de 2014 que contiene la capital del distrito nuevo
#      (coordenadas de datos/insumos/ubigeo_distrito.csv). Si ese distrito es de
#      otro departamento (límites simplificados), se toma el distrito más cercano
#      del mismo departamento.
#   4. Si el distrito de origen fue a su vez unido por la regla 1, se aplica esa
#      unión (p. ej., Vizcatán del Ene, creado de Pangoa, pasa a 120699).
#
# Uso: Rscript enaho/05_geografia.R
# Salidas:
#   enaho/geografia/correspondencia_ubigeo.csv (tabla usada, documentada)
#   enaho/datos_procesados/hogares.{parquet,csv}
#   enaho/datos_procesados/personas.{parquet,csv}

source("enaho/funciones.R")
suppressPackageStartupMessages(library(sf))
sf_use_s2(FALSE)

hog <- readRDS(file.path(PROCESADO, "hogares_tmp.rds"))
per <- readRDS(file.path(PROCESADO, "personas_tmp.rds"))
oro <- read_csv("datos/oro_por_distrito_pre2014.csv", col_types = cols(.default = "c"))
lim <- st_read("datos/insumos/peru_distrital_simple.geojson", quiet = TRUE) |>
  select(IDDIST, NOMBDIST)
ubi <- read_csv("datos/insumos/ubigeo_distrito.csv", col_types = cols(.default = "c")) |>
  transmute(ubigeo = inei, departamento, provincia, distrito,
            lat = suppressWarnings(as.numeric(latitude)), lon = suppressWarnings(as.numeric(longitude)))
manual <- read_csv("enaho/geografia/correspondencia_manual.csv", col_types = cols(.default = "c"))

codigos <- tibble(ubigeo = sort(unique(c(hog$ubigeo, per$ubigeo, oro$ubigeo))))

# Regla 3: asignación espacial de los códigos que no están en la capa de 2014
nuevos <- codigos |>
  filter(!ubigeo %in% lim$IDDIST, !ubigeo %in% manual$ubigeo) |>
  left_join(ubi, by = "ubigeo")
if (any(is.na(nuevos$lat)))
  stop("Códigos nuevos sin coordenadas ni correspondencia manual: ",
       paste(nuevos$ubigeo[is.na(nuevos$lat)], collapse = ", "))
pts <- st_as_sf(nuevos, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
dentro <- suppressMessages(st_join(pts, lim, join = st_within))
espacial <- lapply(seq_len(nrow(dentro)), function(i) {
  x <- dentro[i, ]
  mismo_dpto <- !is.na(x$IDDIST) && substr(x$IDDIST, 1, 2) == substr(x$ubigeo, 1, 2)
  if (mismo_dpto) {
    tibble(ubigeo = x$ubigeo, ubigeo_base = x$IDDIST,
           metodo = "espacial: capital dentro del distrito de 2014")
  } else {
    cand <- lim[substr(lim$IDDIST, 1, 2) == substr(x$ubigeo, 1, 2), ]
    j <- which.min(suppressMessages(st_distance(st_geometry(x), cand)))
    tibble(ubigeo = x$ubigeo, ubigeo_base = cand$IDDIST[j],
           metodo = paste0("espacial: distrito más cercano del mismo departamento (la capital cae en ",
                           ifelse(is.na(x$IDDIST), "ningún polígono", x$IDDIST), ")"))
  }
}) |> bind_rows()

corr <- codigos |>
  left_join(manual |> transmute(ubigeo, base_manual = ubigeo_base, fuente, nota), by = "ubigeo") |>
  left_join(espacial, by = "ubigeo") |>
  mutate(
    ubigeo_base = case_when(!is.na(base_manual) ~ base_manual,
                            ubigeo %in% lim$IDDIST ~ ubigeo,
                            TRUE ~ ubigeo_base),
    metodo = case_when(!is.na(base_manual) ~ "manual",
                       ubigeo %in% lim$IDDIST ~ "sin cambio",
                       TRUE ~ metodo)
  )
# Regla 4: uniones en cadena (origen que a su vez fue unido)
uniones <- manual |> select(ubigeo, destino = ubigeo_base)
corr <- corr |>
  left_join(uniones, by = c("ubigeo_base" = "ubigeo")) |>
  mutate(metodo = ifelse(!is.na(destino) & destino != ubigeo_base & metodo != "manual",
                         paste0(metodo, "; luego unión ", ubigeo_base, " -> ", destino), metodo),
         ubigeo_base = coalesce(destino, ubigeo_base)) |>
  select(-destino, -base_manual)

nombres <- bind_rows(ubi |> select(ubigeo, distrito),
                     tibble(ubigeo = "120699", distrito = "MAZAMARI-PANGOA (código ENAHO)"))
corr <- corr |>
  left_join(nombres, by = "ubigeo") |>
  left_join(nombres |> rename(ubigeo_base = ubigeo, distrito_base = distrito), by = "ubigeo_base") |>
  mutate(en_enaho = ubigeo %in% c(hog$ubigeo, per$ubigeo),
         en_base_oro = ubigeo %in% oro$ubigeo) |>
  select(ubigeo, distrito, ubigeo_base, distrito_base, metodo, fuente, nota, en_enaho, en_base_oro)

stopifnot(!anyNA(corr$ubigeo_base), all(nchar(corr$ubigeo_base) == 6))
write_csv(corr, "enaho/geografia/correspondencia_ubigeo.csv", na = "")
cat("Correspondencia:", nrow(corr), "códigos;", sum(corr$ubigeo != corr$ubigeo_base), "reasignados\n")
print(corr |> filter(ubigeo != ubigeo_base | metodo != "sin cambio") |>
        select(ubigeo, distrito, ubigeo_base, distrito_base, metodo) |> as.data.frame())

# Aplicar a las bases y guardar las versiones finales
mapa <- corr |> select(ubigeo, ubigeo_base)
hog <- hog |> left_join(mapa, by = "ubigeo") |> relocate(ubigeo_base, .after = ubigeo)
per <- per |> left_join(mapa, by = "ubigeo") |> relocate(ubigeo_base, .after = ubigeo)
stopifnot(!anyNA(hog$ubigeo_base), !anyNA(per$ubigeo_base))

guardar(hog, "hogares")
guardar(per, "personas")
