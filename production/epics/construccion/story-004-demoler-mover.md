# Story 004: Demoler y mover — reembolso F4, cascada con confirmación y reorganización libre

> **Epic**: Construcción y Distribución
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S-M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/construction-layout.md` (CO8, F4 + edges de demolición/mover)
**Requirement**: `TR-construction-004` *(parcial — el ciclo de vida completo del layout)*
**Governing ADRs**: ADR-0004 (primario), ADR-0001 (secundario — el reembolso lo abona Economía)
**ADR Decision Summary**: demoler devuelve `coste_pagado × pct_reembolso` vía `abonar` de Economía;
mover es gratis (Pilar 4: reorganizar no penaliza). La cascada de sala es una API en dos pasos para
que la UI confirme antes.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: sin API post-cutoff en esta story.

**Control Manifest Rules (Core)**:
- Required: el dinero lo mueve Economía (`abonar` para el reembolso). — ADR-0001
- Required: capas — al retirar un puesto, `quitar_puesto` en Personal (su agente queda libre, ya
  implementado en personal-003). — ADR-0001
- Forbidden: perder `coste_pagado` (el reembolso es sobre lo pagado, no sobre el precio actual).

---

## Acceptance Criteria

- [ ] **AC-CO11** `[Unit]` — GIVEN demoler `doc_general` (pagado 500), `pct_reembolso=0.5` THEN reembolso **250**.
- [ ] **AC-CO12** `[Integration]` — GIVEN una oficina con 2 puestos WHEN se demuele THEN **cascada con confirmación**: reembolsa los 2 puestos + la sala, y todo desaparece del modelo.
- [ ] **AC-CO14** `[Integration]` — GIVEN un puesto construido WHEN se **mueve** THEN es **gratis** y queda reubicado (posición nueva; mismo id; Personal NI se entera — el registro no cambia).
- [ ] *(Edge CO4)* — GIVEN mover un `odac` a la oficina de Documentación THEN **rechazado** (revalidación al mover).

---

## Implementation Notes

- **`demoler_elemento(id) -> bool`**: reembolso = `coste_pagado × pct_reembolso` → `_economia.abonar(...)`
  → libera la celda → si era puesto, `_personal.quitar_puesto(id)` (su agente al banquillo — ya hecho).
- **Cascada en 2 pasos (AC-CO12)**: `contenido_de_sala(sala_id) -> Array` (para que la UI liste y
  confirme) + `demoler_sala(sala_id)` que demuele contenido + sala reembolsando CADA elemento por su
  `coste_pagado` (y la sala por el suyo). La CONFIRMACIÓN es de la UI (007): la API no pregunta.
- **`mover_elemento(id, celda_destino) -> bool`**: revalida con `validar_elemento` (misma regla CO4 —
  un `odac` no se muda a la oficina de Doc), coste `coste_mover` (0 = gratis, knob), conserva id y
  `coste_pagado`. Salas NO se mueven en el MVP (decisión propuesta: demoler + redibujar; mover salas
  con contenido es un feature de QoL futuro).
- **AC-CO13 (puesto ATENDIENDO: termina la atención y luego demuele) → DIFERIDO al epic Flujo**
  (patrón AC-PE10): hoy no existe "atendiendo". Al integrar Flujo, `demoler_elemento` deberá consultar
  el compromiso de servicio. Anotado aquí y en el qa-plan.

---

## Out of Scope

- AC-CO13 (compromiso de servicio) — se verifica al integrar Flujo.
- La confirmación visual de la cascada (007 — aquí solo la API en 2 pasos).

---

## QA Test Cases

*Escritos por el hilo principal (modo lean) desde qa-plan-sprint-2.*

- **AC-CO11**: Given doc_general pagado a 500 y saldo S → demoler → saldo S+250 exacto y la celda libre
  (se puede construir ahí de nuevo).
- **AC-CO12**: Given oficina con 2 doc_general (500+500) y base 0 → contenido_de_sala devuelve los 2 →
  demoler_sala → saldo +500 (2×250 + 0) y ni sala ni puestos constan; Personal sin esos puestos
  (agentes al banquillo).
- **AC-CO14**: Given puesto en celda A → mover a celda B válida → posicion_de(id) == B, saldo intacto,
  Personal conserva el registro y el agente asignado sigue asignado.
- **Edge CO4**: mover `odac` a celda de sala_documentacion → false y no se mueve.
- **Reembolso con precio cambiado**: Given coste_pagado 500 y catálogo ahora a 999 → reembolso sigue
  siendo 250 (sobre lo PAGADO).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/construccion/construccion_demoler_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (puentes) — DONE antes de empezar.
- Unlocks: Story 005 (persistencia del ciclo completo).
