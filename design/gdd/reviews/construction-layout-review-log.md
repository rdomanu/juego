# Review Log — Construcción y Distribución (`construction-layout.md`)

Historial de `/design-review` sobre este GDD. Entrada más reciente arriba.

## Review — 2026-07-22 — Verdict: APPROVED
- **Scope signal:** M (construcción libre; 6 fórmulas; 18 AC; rejilla/layout).
- **Modo:** lean (lentes game-designer / systems-designer / qa-lead / creative-director en el hilo principal; subagentes caídos por "1M context").
- **Blocking:** 0 | **Recommended:** 1 (estructural) | **Nice:** 3 — **todo aplicado en la sesión.**
- **Prior verdict resolved:** First review.
- **Completitud:** 8/8 secciones + States, Interactions, Visual/Audio, UI, Open Questions.

### Verificación (systems-designer)
F1–F6 correctas y consistentes: coste de sala (3×3→380, 5×4→600), coste de puesto (500/500/600), aforo por asientos (`min(colocadas, floor(área×0.7))`), reembolso (500→250), y **F5 `puestos_utiles = ceil(17,6/4) = 5`** (cuadra con Demanda F2 pico 17,6/h y Flujo throughput 4/h). Coherente con el registro (`coste_por_celda 20`, `densidad_asientos 0.7`, `pct_reembolso 0.5`, `coste_sala`).

### Recomendado (aplicado)
1. **[estructural]** Eliminada la sección "UI Requirements" **duplicada** (vacía "[To be designed]").

### Nice-to-have (aplicados)
1. Status `In Design` → **Reviewed**; `Last Updated` → 2026-07-22.
2. Open Q3 marcada **Resuelta**: la reconciliación con Datos (`tope_construible`→referencia, `aforo_espera`→referencia) **ya estaba aplicada** en Datos F7/F4 (consistency-check 5ª).
3. Nota bidireccional actualizada (todos los dependientes del MVP ya existen).

### Veredicto senior (síntesis)
GDD ejemplar para la construcción libre estilo Theme Hospital: fantasía ("esta comisaría la he diseñado yo"), modelo "puestos ilimitados, la demanda manda" (capacidad ≠ demanda), aforo por asientos, reorganización barata — todo bien resuelto y ya reconciliado con Datos. Solo higiene (UI duplicada + una Open Question ya resuelta). **Construcción queda aprobada.**
