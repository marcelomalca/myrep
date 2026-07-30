# 00_setup.R ------------------------------------------------------------------
# Dependencias y rutas del proyecto.
# Ejecutar una vez antes que cualquier otro script.

pkgs <- c(
  # manipulación
  "data.table", "dplyr", "tidyr", "stringr", "lubridate", "janitor",
  # descarga
  "httr2", "rvest", "readxl", "haven",
  # SIG
  "sf",
  # econometría
  "did",            # Callaway & Sant'Anna (2021)
  "fixest",         # TWFE y Sun & Abraham (2021)
  "didimputation",  # Borusyak, Jaravel & Spiess (2024)
  "bacondecomp",    # Goodman-Bacon (2021)
  "HonestDiD",      # Rambachan & Roth (2023)
  # salida
  "ggplot2", "modelsummary"
)

faltantes <- setdiff(pkgs, rownames(installed.packages()))
if (length(faltantes) > 0) {
  message("Instalando: ", paste(faltantes, collapse = ", "))
  install.packages(faltantes, repos = "https://cloud.r-project.org")
}

invisible(lapply(pkgs, library, character.only = TRUE))

# Rutas ------------------------------------------------------------------------
# Todos los scripts asumen que el directorio de trabajo es la RAÍZ del proyecto
# (la carpeta que contiene R/ y docs/). Ejecutar, por ejemplo:
#   Rscript R/07_estimate_did.R
# desde la raíz, o abrir el proyecto en RStudio en esa carpeta.
PROJ <- getwd()
if (!dir.exists(file.path(PROJ, "R"))) {
  stop("El directorio de trabajo debe ser la raíz del proyecto (la que contiene R/).\n",
       "Actual: ", PROJ)
}

DIR_RAW  <- file.path(PROJ, "data", "raw")
DIR_INT  <- file.path(PROJ, "data", "interim")
DIR_PROC <- file.path(PROJ, "data", "processed")
DIR_OUT  <- file.path(PROJ, "output")

for (d in c(DIR_RAW, DIR_INT, DIR_PROC, DIR_OUT)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# Parámetros del estudio -------------------------------------------------------
ANIO_INICIO <- 2007L   # revisar tras 01_download_sunat.R (ver docs/02, riesgo SUNAT)
ANIO_FIN    <- 2025L

# Umbral mínimo de monto (soles) para que un proyecto vial cuente como tratamiento.
# La sensibilidad a este valor se testea en 08_robustness.R
UMBRAL_MONTO <- 1e6

message("Setup completo. PROJ = ", PROJ)
