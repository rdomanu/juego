# Review Log — Generación de Demanda (`demand-generation.md`)

Historial de `/design-review` sobre este GDD. Entrada más reciente arriba.

## Review — 2026-07-22 — Verdict: APPROVED
- **Scope signal:** M (generador; 5 fórmulas; 19 AC; RNG determinista sembrado).
- **Modo:** lean (lentes systems-designer / game-designer / qa-lead / creative-director en el hilo principal; subagentes caídos por "1M context").
- **Blocking:** 0 | **Recommended:** 1 | **Nice:** 3 — **todo aplicado en la sesión.**
- **Prior verdict resolved:** First review.
- **Completitud:** 8/8 secciones + States, Interactions, Visual/Audio, UI, Open Questions.

### Verificación numérica (systems-designer)
Cálculos **cuadran**: F1 (Doc 45/día, ODAC 36/día); F2 (perfil Doc suma 1.00; pico 45×0.30×1.3≈17,6); **F3 (mezcla de 13 denuncias suma 1.00 y su duración media ponderada da 29,75 min** — verificado a mano — el número exacto que usan ODAC/Flujo/Datos: `960/30≈32→128`; Prioritarias 0.13, Normales 0.87); F4 (acumulador+RNG determinista, tope de ráfaga, normalización); F5 (R5 OK: 45«260, 36«128). `mult_nocturno_odac` 0.5 ≈10 Pozuelo escalable, consistente.

### Recomendado (aplicado)
1. **Residuo del calendario semanal en `mult_dia_semana`:** el ejemplo de F2 ("lunes ×1.3") y el default del Tuning ("lunes ~1.3; sábado ~0.6") conservaban el modelo diario, contradiciendo la propia nota (con calendario semanal cada jornada = 1 semana). → Reconciliado: ejemplo F2 = "jornada de carga alta ×1.3"; Tuning = variación entre jornadas (la variación gruesa la llevan DG13/DG11).

### Nice-to-have (aplicados)
1. Status `In Design` → **Reviewed**; `Last Updated` → 2026-07-22.
2. Nota bidireccional actualizada (Documentación/ODAC ya existen y reflejan la relación).
3. Retirada la mención de `admite_cita` en la mezcla F3 (irrelevante con "denuncias sin cita").

### Veredicto senior (síntesis)
GDD de alta calidad para el motor de presión: fantasía ("os estaba esperando"), modelo determinista con azar acotado y calibrado a R5, y **coherencia numérica impecable** (la mezcla que produce el 29,75 de todo el proyecto). Único residuo real (vocabulario `mult_dia_semana`) ya reconciliado. **Demanda queda aprobada.**
