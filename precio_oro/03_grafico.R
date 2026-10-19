# 03_grafico.R
# Gráfico del precio nominal del oro (US$/oz), 2014-2026: promedio anual y,
# como contexto, promedio mensual.
#
# Uso: Rscript precio_oro/03_grafico.R
# Salida: precio_oro/precio_oro.png

suppressPackageStartupMessages({ library(dplyr); library(readr); library(ggplot2) })

MESES <- c("ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "set", "oct", "nov", "dic")

mensual <- read_csv("precio_oro/datos_procesados/precio_oro_mensual.csv", show_col_types = FALSE) |>
  mutate(fecha = as.Date(sprintf("%s-15", periodo)))
anual <- read_csv("precio_oro/datos_procesados/precio_oro_anual.csv", show_col_types = FALSE) |>
  mutate(fecha = as.Date(sprintf("%d-07-01", anio)),
         etiqueta = ifelse(anio_completo, sprintf("%d: %s", anio, format(round(precio_promedio_usd_oz), big.mark = ",")),
                           sprintf("%d (ene-%s): %s", anio, MESES[as.integer(format(max(mensual$fecha), "%m"))],
                                   format(round(precio_promedio_usd_oz), big.mark = ","))))

azul <- "#2a78d6"; gris <- "#b9b8b3"; tinta <- "#0b0b0b"; tinta2 <- "#52514e"
rotular <- anual |> filter(anio %in% c(min(anio), 2025, max(anio)))
ultima_fecha <- max(mensual$ultimo_dia)

g <- ggplot() +
  geom_line(data = mensual, aes(fecha, precio_promedio_usd_oz), colour = gris, linewidth = 0.5) +
  geom_line(data = anual |> filter(anio_completo), aes(fecha, precio_promedio_usd_oz),
            colour = azul, linewidth = 0.9) +
  geom_point(data = anual, aes(fecha, precio_promedio_usd_oz, shape = anio_completo),
             colour = azul, fill = "white", size = 2.4, stroke = 1) +
  scale_shape_manual(values = c(`TRUE` = 16, `FALSE` = 21), guide = "none") +
  geom_text(data = rotular, aes(fecha, precio_promedio_usd_oz, label = etiqueta,
                                hjust = ifelse(anio == max(anio), 0.95, 0.5)),
            vjust = -1.2, size = 3.2, colour = tinta) +
  scale_y_continuous(labels = scales::label_comma(), limits = c(0, NA),
                     expand = expansion(mult = c(0, 0.08))) +
  # Marcas a mitad de año, donde se ubican los promedios anuales
  scale_x_date(breaks = anual$fecha, labels = anual$anio,
               expand = expansion(mult = c(0.02, 0.03))) +
  labs(
    title = "Precio del oro, 2014-2026 (US$ nominales por onza troy)",
    subtitle = "Azul: promedio anual de los promedios mensuales. Gris: promedio mensual de cierres diarios.\nEl punto vacío de 2026 es un año incompleto.",
    caption = sprintf("Fuente: Yahoo Finance, GC=F (futuros de oro COMEX, contrato continuo). Datos al %s.",
                      format(ultima_fecha, "%d/%m/%Y")),
    x = NULL, y = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.background = element_rect(fill = "#fcfcfb", colour = NA),
    panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = "#e6e5e0", linewidth = 0.3),
    plot.title = element_text(face = "bold", colour = tinta),
    plot.subtitle = element_text(colour = tinta2, size = 9.5),
    plot.caption = element_text(colour = tinta2, size = 8, hjust = 0),
    axis.text = element_text(colour = tinta2),
    plot.margin = margin(12, 16, 10, 12)
  )

ggsave("precio_oro/precio_oro.png", g, width = 8, height = 5, dpi = 200, bg = "#fcfcfb")
cat("Gráfico guardado en precio_oro/precio_oro.png\n")
