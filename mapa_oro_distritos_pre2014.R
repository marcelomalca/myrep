# Yacimientos mineros de oro (INGEMMET - Geocatmin) registrados antes de 2014,
# por distrito, provincia y departamento: tablas resumen en CSV y mapa
# coroplético a nivel distrital. Es una copia de mapa_oro_distritos.R que solo
# cambia la entrada, los nombres de salida y el subtítulo del mapa.
#
# Requisitos:
#   install.packages(c("sf", "dplyr", "readr", "ggplot2"))
#
# Uso (desde la raíz del repositorio):
#   Rscript mapa_oro_distritos_pre2014.R
#
# Entradas:
#   datos/yacimientos_oro_principal_pre2014.csv   (generado por filtrar_pre2014.py)
#   datos/insumos/peru_distrital_simple.geojson
#       Límites distritales INEI (github.com/juaneladio/peru-geojson)
#   datos/insumos/ubigeo_distrito.csv
#       Códigos ubigeo INEI y nombres (github.com/jmcastagnetto/ubigeo-peru-aumentado)
#
# Salidas (en datos/):
#   oro_por_departamento_pre2014.csv, oro_por_provincia_pre2014.csv,
#   oro_por_distrito_pre2014.csv, mapa_oro_distritos_pre2014.png

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(ggplot2)
})

sf_use_s2(FALSE)

entrada   <- "datos/yacimientos_oro_principal_pre2014.csv"
f_limites <- "datos/insumos/peru_distrital_simple.geojson"
f_ubigeo  <- "datos/insumos/ubigeo_distrito.csv"

# ---------------------------------------------------------------------------
# 1. Datos
# ---------------------------------------------------------------------------
yac <- read_csv(entrada, col_types = cols(.default = col_character()),
                locale = locale(encoding = "UTF-8")) |>
  mutate(lat = as.numeric(lat), lon = as.numeric(lon))

ubigeo <- read_csv(f_ubigeo, col_types = cols(.default = col_character())) |>
  select(DISTRITO = inei, departamento, provincia, distrito)

yac <- yac |> left_join(ubigeo, by = "DISTRITO")
if (any(is.na(yac$distrito))) {
  warning("Hay códigos de distrito sin nombre en la tabla de ubigeo")
}

# ---------------------------------------------------------------------------
# 2. Tablas resumen (según los códigos de ubicación que registra INGEMMET)
# ---------------------------------------------------------------------------
por_dep <- yac |>
  count(cod_departamento = REGION, departamento, name = "yacimientos_oro") |>
  arrange(desc(yacimientos_oro), departamento) |>
  mutate(porcentaje = round(100 * yacimientos_oro / sum(yacimientos_oro), 1))

por_prov <- yac |>
  count(cod_provincia = PROVINCIA, departamento, provincia, name = "yacimientos_oro") |>
  arrange(desc(yacimientos_oro), departamento, provincia)

por_dist <- yac |>
  count(ubigeo = DISTRITO, departamento, provincia, distrito, name = "yacimientos_oro") |>
  arrange(desc(yacimientos_oro), departamento, provincia, distrito)

write_excel_csv(por_dep,  "datos/oro_por_departamento_pre2014.csv")
write_excel_csv(por_prov, "datos/oro_por_provincia_pre2014.csv")
write_excel_csv(por_dist, "datos/oro_por_distrito_pre2014.csv")

cat("Yacimientos:", nrow(yac), "| departamentos:", nrow(por_dep),
    "| provincias:", nrow(por_prov), "| distritos:", nrow(por_dist), "\n")

# ---------------------------------------------------------------------------
# 3. Mapa
# ---------------------------------------------------------------------------
limites <- st_read(f_limites, quiet = TRUE) |>
  select(IDDIST, IDDPTO, geometry)

# Los límites son anteriores a algunos distritos nuevos (p. ej. Kumpirushiato,
# Castillo Grande, Santa Lucía). Esos yacimientos se ubican en el polígono que
# contiene su punto, es decir, el distrito del que se crearon.
yac_pts <- st_as_sf(yac, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
espacial <- st_join(yac_pts, limites |> select(id_espacial = IDDIST),
                    join = st_within) |>
  st_drop_geometry()

yac_mapa <- espacial |>
  mutate(id_mapa = if_else(DISTRITO %in% limites$IDDIST, DISTRITO, id_espacial))

conteo <- yac_mapa |>
  filter(!is.na(id_mapa)) |>
  count(IDDIST = id_mapa, name = "n")

clases <- c("1", "2", "3\u20134", "5\u20139", "10 o m\u00e1s")
mapa <- limites |>
  left_join(conteo, by = "IDDIST") |>
  mutate(
    n = coalesce(n, 0L),
    clase = cut(n, breaks = c(0, 1, 2, 4, 9, Inf), labels = clases,
                right = TRUE, include.lowest = FALSE)
  )

departamentos <- limites |>
  group_by(IDDPTO) |>
  summarise(.groups = "drop")

# Escala secuencial de un solo tono (azul claro -> oscuro)
colores <- c("#86b6ef", "#5598e7", "#2a78d6", "#1c5cab", "#0d366b")
names(colores) <- clases
sin_dato <- "#ebeae6"

n_mapa <- sum(conteo$n)

g <- ggplot() +
  geom_sf(data = mapa, aes(fill = clase), colour = "#fcfcfb", linewidth = 0.05) +
  geom_sf(data = departamentos, fill = NA, colour = "#52514e", linewidth = 0.25) +
  scale_fill_manual(
    values = colores, na.value = sin_dato, drop = FALSE,
    breaks = clases, name = "Yacimientos de oro\npor distrito",
    guide = guide_legend(override.aes = list(colour = NA))
  ) +
  labs(
    title = "Yacimientos mineros de oro en el Per\u00fa, por distrito",
    subtitle = paste0(format(n_mapa, big.mark = ","),
                      " yacimientos con oro (Au) como elemento principal, ",
                      "registrados antes de 2014\n",
                      "En gris, distritos sin yacimientos registrados"),
    caption = paste0("Fuente: INGEMMET, Geocatmin (SERV_METALOGENETICO, capa ",
                     "Yacimientos Mineros), campo ELE_PRINC. L\u00edmites: INEI.")
  ) +
  coord_sf(datum = NA) +
  theme_void(base_size = 11) +
  theme(
    plot.background   = element_rect(fill = "#fcfcfb", colour = NA),
    plot.title        = element_text(face = "bold", size = 15, colour = "#0b0b0b"),
    plot.subtitle     = element_text(size = 10, colour = "#52514e",
                                     margin = margin(t = 4, b = 10)),
    plot.caption      = element_text(size = 8, colour = "#52514e", hjust = 0),
    plot.margin       = margin(16, 16, 12, 16),
    legend.position   = c(0.13, 0.22),
    legend.title      = element_text(size = 10, colour = "#0b0b0b"),
    legend.text       = element_text(size = 9, colour = "#0b0b0b"),
    legend.key.size   = unit(0.45, "cm")
  )

ggsave("datos/mapa_oro_distritos_pre2014.png", g, width = 8, height = 10, dpi = 300,
       bg = "#fcfcfb")
cat("Mapa guardado en datos/mapa_oro_distritos_pre2014.png\n")
