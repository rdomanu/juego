# Review Log — Sistema de Tiempo (`time-system.md`)

Historial de `/design-review` sobre este GDD. Entrada más reciente arriba.

## Re-review — 2026-07-22 — Verdict: APPROVED
- **Scope signal:** M.
- **Modo:** lean (lentes systems-designer / game-designer / qa-lead / creative-director en el hilo principal; subagentes caídos por "1M context").
- **Motivo de re-revisión:** la **regla 7 (calendario) se reescribió a semanal** — jornada 24 h = 1 semana; 4 semanas = 1 mes; `jornadas_por_mes=4`; 48 jornadas = 1 año; "Mes · Semana N"; `nuevo_mes` cada 4 jornadas.
- **Blocking items:** 0 | **Recommended:** 2 | **Nice-to-have:** 3 — **los 5 aplicados en la misma sesión.**
- **Prior verdict resolved:** Yes — el recomendado advisory de 2026-07-19 (ventana Documentación 09:00 → 08:00–14:30) ya estaba aplicado; sin regresiones.

### Verificación clave
El modelo semanal es **internamente consistente**: regla 7 ↔ States/Transitions (`nuevo_dia` avanza la fecha) ↔ Edge Case de medianoche ↔ **AC-T20/T22** ↔ knob `jornadas_por_mes` ↔ UI (*Mes · Semana N*) ↔ Interacciones (Economía cierra mensual cada 4 jornadas; Demanda perfil estacional). Sin contradicciones.

### Cambios aplicados
1. **[metadatos]** Status header "Designed (pendiente)" → **Reviewed** (2026-07-19 APPROVED + re-revisión 2026-07-22); Last Updated/Verified → 2026-07-22.
2. **[consistencia]** Nota "Consistencia bidireccional" actualizada: los dependientes del MVP ya tienen GDD y listan "depende de: Tiempo".
3. **[Cross-References]** Nota "los GDDs destino aún no existen" actualizada: `demand-generation` y `documentation` ya existen y son consistentes.
4. **[AC]** Añadido **AC-T22b** (cruce de AÑO: mes 12 · Semana 4 → año +1, mes y Semana vuelven a 1).
5. **[AC-T33]** Coletilla "hardware de referencia a fijar en implementación" + nueva Open Question sobre el hardware del AC de rendimiento.

### Veredicto senior (síntesis)
La reescritura del calendario a semanal está entre los cambios **mejor integrados** de la ronda (ACs y edge cases actualizados a la par que la regla). Lo pendiente era solo higiene de metadatos/notas obsoletas, ya resuelto. **Tiempo queda re-aprobado.**

---

## Review — 2026-07-19 — Verdict: APPROVED (con notas advisory)
Scope signal: M
Specialists: ninguno (modo lean; lentes de systems-designer / game-designer / qa-lead aplicadas en el hilo principal — los subagentes de estudio fallan con el error "1M context")
Blocking items: 0 | Recommended: 1 | Nice-to-have: 2
Summary: GDD Foundation maduro y listo para implementar. Fantasía clara y anclada al prototipo (el ritmo del reloj como motor de diversión), separación de responsabilidades ejemplar (Tiempo solo provee hora/turno/fecha; horarios finos y demanda son de otros sistemas), edge cases muy completos (picos de lag, medianoche, jitter de float, alt-tab, clamp de escala_tiempo) y 36 AC casi todos testables con números exactos. Fórmulas (F1/F2/F3) correctas y sin degeneraciones en los extremos; única singularidad es duracion_dia_real ÷0 en Pausa, ya excluida por diseño. Coherente con Datos (escala_tiempo=4, minutos_por_dia=1440, turnos 420/900/1380) y con entities.yaml. Único recomendado (no bloqueante): reconciliar la ventana de Documentación (Regla 4.3 cita complementario 08:00–14:30, pero F1/F3 usan 09:00–14:30 como ventana ilustrativa) — no es contradicción real (horario del personal vs apertura al público) pero conviene aclararlo o marcarlo como placeholder del futuro GDD de Documentación. Nice-to-have: nota explícita de que F1 excluye Pausa; y fijar hardware de referencia para el AC de rendimiento AC-T33.
Prior verdict resolved: First review
