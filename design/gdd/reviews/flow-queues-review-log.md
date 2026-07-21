# Review Log — Flujo de Personas y Colas (`flow-queues.md`)

Historial de `/design-review` sobre este GDD. Entrada más reciente arriba.

## Review — 2026-07-22 — Verdict: APPROVED
- **Scope signal:** L (bottleneck central del MVP; 7 fórmulas; 10 reglas; 27 AC; muchas interfaces). Trabajo de corrección: S.
- **Modo:** lean (lentes systems-designer / game-designer / qa-lead / creative-director en el hilo principal; subagentes caídos por "1M context").
- **Blocking:** 0 | **Recommended:** 1 (menor) | **Nice:** 2.
- **Prior verdict resolved:** First review.
- **Completitud:** 8/8 secciones + States, Interactions, Visual/Audio, UI, Open Questions.

### Verificación clave
Fórmulas F1–F7 muy sólidas; casos degenerados cubiertos (clamp `duracion_efectiva ≥ 1`; `puestos_compatibles=0` → espera indefinida F5; `aforo=0` → cola exterior F6). ODAC ya en `30→32→128` tras la corrección del `/consistency-check` de hoy (línea 227). Consistente con Datos F8, Paciencia (aforos 40/10, eventos `trámite completado`/`abandono`) y el registro. Los 27 AC cubren FL1–FL10 y F1–F7 con números exactos y determinismo. FL7 "sin cita" coherente con la decisión de denuncias sin cita (Flujo solo usa `requiere_cita` de Doc).

### Recomendados
1. **[systems-designer, menor] F4 (ρ) con `capacidad = 0`** (todos los puestos cerrados) → carecía de nota explícita (a diferencia de F5). **Aplicado:** añadida la nota de que `ρ` con capacidad 0 = ∞ (servicio parado, cola crece; edge "todos los puestos cerrados", no división por cero real).

### Nice-to-have (aplicados)
1. **[metadatos]** Header `In Design` → **Reviewed**; `Last Updated` → 2026-07-22.
2. **[consistencia]** Nota bidireccional actualizada: todos los dependientes del MVP (Economía, Paciencia, Doc, ODAC, UI, Feedback) y los upstream ya existen; solo Guardado #20 (futuro) queda.

### Veredicto senior (síntesis)
GDD ejemplar para el bottleneck central: fantasía ("lo he arreglado yo" vía ρ), separación de responsabilidades, anti-micromanejo, edge cases exhaustivos y 27 AC deterministas. Nada bloquea; solo higiene de metadatos + una nota de frontera en ρ, ya aplicadas. **Flujo queda aprobado.**
