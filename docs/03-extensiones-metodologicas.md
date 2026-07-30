# Extensiones metodológicas

Métodos alternativos al DiD escalonado, registrados para retomarlos en fases posteriores.
Ninguno está implementado todavía en `R/`.

El problema que todos atacan es el mismo: **la endogeneidad del trazado vial**. El Estado no
asigna carreteras al azar — las construye donde ya hay actividad económica o donde espera
que la haya. El DiD escalonado lo maneja parcialmente (efectos fijos absorben diferencias de
nivel; los leads testean tendencias previas), pero no lo resuelve si la priorización responde
a dinamismo *creciente*.

---

## A. Variable instrumental: la red de caminos incas (Qhapaq Ñan)

**Nivel de ambición:** paper publicable / tesis de maestría fuerte.

**Idea.** Instrumentar la red vial moderna con la red vial precolombina. La lógica de
exclusión: los caminos incas determinan dónde es barato construir carreteras hoy (siguen
corredores topográficos naturales), pero no afectan la creación de empresas contemporánea
por otra vía que no sea la infraestructura moderna.

**Precedente publicado para Perú.** Volpe Martincus, C., Carballo, J. & Cusolito, A. (2017),
"Roads, exports and employment: Evidence from a developing country", *Journal of Development
Economics*. Instrumentan el cambio en la red vial 2003–2010 con dos instrumentos:
1. Distancia desde el origen geográfico al camino inca más cercano.
2. Distancia entre ese origen y el puerto actual recorrible por la red incaica.

Que exista un precedente publicado con este instrumento para Perú es una ventaja fuerte: la
validez ya fue defendida ante referees.

**Datos necesarios adicionales:**
- Trazado georreferenciado del Qhapaq Ñan (Ministerio de Cultura; el sistema vial andino
  está inscrito en la lista de Patrimonio Mundial de la UNESCO, con cartografía asociada).
- Modelo digital de elevación para rutas de mínimo costo.

**Objeciones a anticipar.** Los caminos incas conectaban centros administrativos que pueden
seguir siendo centros económicos hoy — violación potencial de la restricción de exclusión.
Mitigación estándar: controlar por distancia a centros administrativos incas
(*tambos*, capitales de *wamani*) y verificar que el instrumento no predice resultados
pre-tratamiento.

---

## B. Rutas de mínimo costo y rugosidad topográfica

**Nivel de ambición:** complemento del IV incaico.

**Idea.** Construir una red vial "hipotética" que conectaría los principales centros
poblados minimizando costo de construcción según topografía, sin referencia a resultados
económicos. Los distritos que caen en esa ruta óptima por accidente geográfico —pero que no
son origen ni destino— reciben tratamiento cuasi-aleatorio.

Es la lógica de *inconsequential units*: usar distritos que fueron atravesados
incidentalmente, no aquellos que eran el objetivo de la obra.

**Datos:** modelo digital de elevación (SRTM/ASTER), centros poblados censales, algoritmo
de least-cost path en `R` (`gdistance`, `terra`).

---

## C. Panel de efectos fijos con dosis continua

**Nivel de ambición:** tesis de pregrado / especificación de referencia.

**Idea.** Regresión de la tasa de creación de empresas sobre inversión vial acumulada
(devengado de Consulta Amigable del MEF), con efectos fijos de distrito y año.

```
Y_it = α_i + λ_t + β · InversiónVialAcumulada_it + X_it'γ + ε_it
```

**Ventaja:** simple, aprovecha toda la variación continua, fácil de comunicar.
**Desventaja:** correlacional. La endogeneidad se reconoce explícitamente como limitación.

**Rol en este proyecto:** especificación de referencia y chequeo de consistencia. Si el
signo y magnitud son compatibles con el DiD principal, refuerza el resultado.

---

## D. DiD sobre megaproyectos específicos

**Nivel de ambición:** tesis de maestría; alternativa nítida al DiD escalonado general.

**Idea.** En vez de usar todos los proyectos viales, explotar shocks discretos grandes y
bien datados:

| Proyecto | Periodo de ejecución | Ámbito |
|---|---|---|
| **IIRSA Norte** | 2005–2011 | Eje Amazonas (Paita–Yurimaguas) |
| **IIRSA Sur / Interoceánica** | 2006–2011 | Eje Perú–Brasil–Bolivia |
| **Longitudinal de la Sierra** | por tramos | Eje andino |

**Diseño:** intensidad de tratamiento según distancia del distrito al eje, con distritos
lejanos como comparación. Permite un *event study* limpio con fecha de apertura conocida.

**Ventaja sobre el DiD general:** la fecha de tratamiento es inequívoca y verificable, y hay
literatura previa de evaluación de impacto (incluyendo estudios del BID) contra la cual
contrastar resultados.

**Referencia de contexto:** BID, *"The Environmental and Social Impacts of Major
IDB-Financed Road Improvement Projects: The Interoceanica IIRSA Sur and IIRSA Norte Highways
in Peru"*.

---

## Orden sugerido de incorporación

1. **DiD escalonado** (implementado — `R/07_estimate_did.R`).
2. **Panel FE con dosis continua** (C) — barato, es casi un subproducto del pipeline actual.
3. **DiD sobre megaproyectos** (D) — requiere solo georreferenciar los ejes IIRSA.
4. **IV incaico** (A) + **mínimo costo** (B) — el salto metodológico mayor; requiere trabajo
   SIG sustantivo.
