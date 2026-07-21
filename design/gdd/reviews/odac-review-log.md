# Review Log — ODAC / Denuncias (`odac.md`)

Historial de `/design-review` sobre este GDD. Entrada más reciente arriba.

## Review — 2026-07-22 — Verdict: NEEDS REVISION (leve) → RESUELTO en la misma sesión
- **Scope signal:** M (Feature configurador; reconfiguración; 16 AC; 2 fórmulas tras la reconciliación).
- **Modo:** lean (lentes game-designer / systems-designer / qa-lead / creative-director en el hilo principal; subagentes caídos por "1M context").
- **Blocking (leve):** 1 (reconciliación de reputación) | **Recommended:** 1 (estructural) | **Nice:** 3 — **todo resuelto en la sesión.**
- **Prior verdict resolved:** First review.

### Hallazgo principal — solapamiento de la reputación de ODAC (reconciliado)
ODAC F1/F2 (`reputacion_aporte`/`reputacion_penalizacion`, con `base_reputacion`/`base_abandono`) y Paciencia F2/F3 (`satisfaccion_odac`, media ponderada por `peso_prioridad`) eran **dos modelos de lo mismo**. Diferencia: Paciencia penaliza la espera y trata el abandono como visita 0; ODAC eran puntos absolutos sin espera. **Decisión del usuario (opción A): Paciencia posee la escala 0–100; ODAC solo aporta `peso_prioridad` (2.5).**

### Cambios aplicados
1. **[F1]** Reescrita: de "aporte de reputación" (fórmula propia) a **"Contribución de ODAC a la satisfacción (el peso de la prioridad)"** — ODAC aporta `peso_prioridad`; Paciencia calcula. Retiradas las fórmulas `reputacion_aporte`/`reputacion_penalizacion`.
2. **[F2]** La antigua "F3 · Capacidad" se renumeró a **F2** (ya no hay F1/F2 de reputación).
3. **[Tuning]** Retirados los knobs `base_reputacion` y `base_abandono` (redundantes con `puntuacion_base`=80 / abandono=0 de Paciencia); se mantiene `peso_prioridad_prioritaria` (2.5). Restricciones actualizadas.
4. **[AC-OD09/OD10]** Reformulados: de puntos absolutos (+1/+3,3, −2/−5) a "peso 2.5× en la media de Paciencia" (Integration).
5. **[Paciencia PS6]** Corregida la referencia cruzada "reusa ODAC F1/F2" → "usa `peso_prioridad` (knob de ODAC F1)".
6. **[Registro]** Añadido `peso_prioridad_prioritaria` (2.5) a `entities.yaml` (source ODAC, referenced_by Paciencia) — antes no estaba y ahora es la interfaz clave ODAC→Paciencia.
7. **[estructural]** Eliminada la sección "UI Requirements" **duplicada** (vacía "[To be designed]").
8. **[nice]** `Last Updated` → 2026-07-22; retirado `admite_cita` de las tablas de interfaces (coherente con OD9 "sin cita").

### Verificación previa (ya OK)
Capacidad F2 (throughput 32, 128/día, demanda ~36) consistente con Datos/Flujo/registro; OD9 "sin cita" ya propagado; prioridad (VioGén primero) y reconfiguración bien definidas.

### Veredicto senior (síntesis)
Buen GDD con fantasía potente (priorizar la VioGén). El único punto real era la **frontera mal trazada** entre ODAC y Paciencia (ambos calculaban la satisfacción de ODAC), ya reconciliada: una sola escala 0–100 (Paciencia) que penaliza la espera, con ODAC aportando el peso de prioridad. **ODAC queda aprobado.**
