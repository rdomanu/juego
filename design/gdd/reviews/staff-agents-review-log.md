# Review Log — Personal / Agentes (`staff-agents.md`)

Historial de `/design-review` sobre este GDD. Entrada más reciente arriba.

## Review — 2026-07-22 — Verdict: NEEDS REVISION (leve) → RESUELTO en la misma sesión
- **Scope signal:** M (plantilla; 7 fórmulas —1 reconciliada—; mercado de candidatos; Oficial; 21 AC).
- **Modo:** lean (lentes game-designer / systems-designer / qa-lead / creative-director en el hilo principal; subagentes caídos por "1M context").
- **Blocking (leve):** 1 (reconciliación F3) | **Recommended:** 1 (estructural) | **Nice:** 3 — **todo resuelto en la sesión.**
- **Prior verdict resolved:** First review.

### Hallazgo principal — F3 (Trato) incompatible con Paciencia (reconciliado)
Paciencia F2 espera `factor_trato` como **MULTIPLICADOR** (0.5–1.5, Trato 3 = 1.0); Personal F3 producía `bonus_satisfaccion` **ADITIVO** (±10, Trato 3 = 0). Estructuras incompatibles. **Decisión del usuario: Personal produce el `factor_trato` multiplicador** (Paciencia es el dueño de la satisfacción).

### Cambios aplicados
1. **[F3]** Reescrita: `factor_trato = clamp(1 + 0.25×(Trato−3)×(1+0.1×(Mot−3)), 0.5, 1.5)` → Trato 5 = 1.5, Trato 3 = 1.0, Trato 1 = 0.5. `k_trato` 5 → **0.25**; salida ±10 → **0.5–1.5**.
2. **[AC-PE11]** Reformulado a `factor_trato` 1.5/1.0/0.5.
3. **[Renombrado propagado]** `bonus_satisfaccion` → `factor_trato` en los 4 GDD que lo mencionaban (staff-agents, patience-satisfaction, flow-queues, systems-index) — el identificador viejo ya no existe.
4. **[Tuning]** `k_trato` 5→0.25; añadido `k_motivacion` (0.05) como knob (estaba implícito en F2).
5. **[estructural]** Eliminada la sección "UI Requirements" **duplicada** (vacía).
6. **[nice]** `Last Updated`/Status → Reviewed 2026-07-22; F4 aclarado (Salud 5 ≈ 0% con clamp, no ~1%; a afinar Open Q1).

### Verificación previa (ya OK)
F1 (salario base×prima: 60/90/45/98), F2 (Rapidez→duración [0.5,1.3]), F4 (ausencia), F6/F7 (Oficial) coherentes con el registro (`salario_dia_efectivo`, `k_calidad 0.5`, `prima_rango 1.3`).

### Veredicto senior (síntesis)
GDD de gran calidad con fantasía potente (montar el equipo, delegar en el Oficial). El único punto real era —otra vez— una **frontera entre dos GDD** (cómo el Trato entra en la satisfacción), reconciliada: Personal aporta un factor multiplicador que casa con Paciencia F2. **Personal queda aprobado.**
