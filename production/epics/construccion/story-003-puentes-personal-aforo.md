# Story 003: Los puentes — puestos registrados en Personal, aforo por asientos (F3) y puestos útiles (F5)

> **Epic**: Construcción y Distribución
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S-M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/construction-layout.md` (CO5, CO7, CO10, F3, F5 + edges de aforo)
**Requirement**: `TR-construction-004` (provee existencia/posición/aforo a Flujo/Personal)
**Governing ADRs**: ADR-0004 (primario), ADR-0001 (secundario — capas: Construcción provee, Personal/Flujo consumen)
**ADR Decision Summary**: Construcción posee la EXISTENCIA y posición; Personal posee quién opera
(gate FL4); Flujo poseerá abierto/cerrado. El puente usa la API que Personal YA expone
(`registrar_puesto`/`quitar_puesto`, personal-003) — nada se tira.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: sin API post-cutoff en esta story.

**Control Manifest Rules (Core)**:
- Required: capas estrictas — Construcción NO conoce agentes ni colas; solo registra/retira puestos y
  expone aforo/posición. — ADR-0001
- Forbidden: duplicar en Construcción estado que posee Personal (asignaciones) o Datos (tipos).

---

## Acceptance Criteria

- [ ] **AC-CO15** `[Integration]` — GIVEN un puesto **construido** THEN Personal puede asignarle agente y el gate FL4 responde (`puesto_dotado`); **sin construir**, `asignar` a ese id falla (no existe).
- [ ] **AC-CO07** `[Unit]` — GIVEN sala 5×4 (densidad 0.7) THEN caben **14** plazas; 10 asientos → aforo **10**; intentar el 15.º… 20.º asiento → **rechazado** (tope 14).
- [ ] **AC-CO08** `[Integration]` — GIVEN una sala de espera **sin asientos** THEN `aforo_de_sala == 0` (Flujo mandará a todos a la cola exterior — su edge, aquí solo el dato).
- [ ] **AC-CO09** `[Integration]` — GIVEN `puestos_utiles=5` WHEN el jugador pone 10 puestos THEN **permitido** (sin tope), no error.
- [ ] **AC-CO10** `[Unit]` — GIVEN demanda pico 17,6/h y throughput 4/h THEN `puestos_utiles = ceil(17.6/4) = 5` (F5).

---

## Implementation Notes

- **Puente a Personal**: al `construir_elemento` de un PUESTO → `_personal.registrar_puesto(puesto_id,
  tipo_puesto_id)`; al retirarlo (004) → `quitar_puesto`. `usar_personal(personal)` inyectable (patrón
  usar_economia). Sin Personal inyectado → aviso (tests unitarios de aforo no lo necesitan).
- **Aforo (F3)**: `aforo_de_sala(sala_id) -> int` = `min(asientos_en_sala, floor(area × densidad_asientos))`.
  El asiento POR ENCIMA del tope físico se RECHAZA al colocarlo (edge F3: "no cabe" — rechazo de regla,
  silencioso; el aforo nunca supera `plazas_max_por_area`).
- **F5 informativo**: `puestos_utiles(tasa_pico_hora, throughput_hora) -> int` = `ceil(tasa/throughput)`
  — función PURA para la UI futura (la brújula "¿cuántos me rentan?"). throughput 0 → 0 con aviso
  (división por cero defendida). SIN tope duro de puestos (CO7): construir 10 con 5 útiles es legal.
- **Getters para Flujo** (los consumirá su epic): `posicion_de(elemento_id) -> Vector2i`,
  `puestos_de_servicio(servicio) -> Array[StringName]`, `aforo_de_sala`. Solo lectura.

---

## Out of Scope

- Quién opera el puesto y las ausencias (Personal, hecho). · Abierto/cerrado y colas (Flujo).
- La calidad de los asientos (Comodidades #15 — aquí un asiento = 1 plaza).

---

## QA Test Cases

*Escritos por el hilo principal (modo lean) desde qa-plan-sprint-2.*

- **AC-CO15**: Given Construccion + Personal + Economía reales → construir un `doc_general` → Personal
  `asignar(agente, id_nuevo)` true y `puesto_dotado` true; Given id NO construido → asignar false (aviso
  de puesto no registrado). Given el puesto se retira → quitar_puesto liberó al agente (patrón
  personal-003).
- **AC-CO07**: Given sala espera 5×4, densidad 0.7 → colocar 10 asientos → aforo 10; colocar hasta 14 →
  aforo 14; el 15.º → rechazado y aforo sigue 14 (boundary intencional).
- **AC-CO08**: Given sala espera recién construida sin asientos → aforo_de_sala == 0.
- **AC-CO09**: Given oficina Doc grande y saldo de sobra → construir 10 `doc_general` → los 10 constan
  y están registrados en Personal (sin tope).
- **AC-CO10**: puestos_utiles(17.6, 4.0) == 5; puestos_utiles(0, 4) == 0; throughput 0 → 0 con aviso.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/construccion/construccion_puentes_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (construir y pagar) — DONE antes de empezar.
- Unlocks: Story 004 (demoler retira del puente) y el epic Flujo (consume los getters).
