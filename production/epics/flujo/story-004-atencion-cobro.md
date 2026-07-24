# Story 004: La atención y el cobro — F1 + `tramite_completado` (el saldo SUBE)

> **Epic**: Flujo de Personas y Colas
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/flow-queues.md` (FL5, F1)
**Requirement**: `TR-flow-003` *(ciclo de atención con delta)* + `TR-flow-004` (emite `tramite_completado`)
**Governing ADRs**: ADR-0001 (primario — el ciclo avanza con `delta` del tick de Tiempo; señales por
el bus; orden de suscripción Tiempo→Demanda→**Flujo**→Paciencia)
**ADR Decision Summary**: Flujo se suscribe al tick DESPUÉS de Demanda (las fichas del mismo tick
entran antes de mover el flujo). La atención es un contador de minutos de juego — jamás reloj real.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: n/a.

**Control Manifest Rules (Core)**:
- Required: simulación con `delta` de juego en el tick; señales de aviso por el bus. — ADR-0001
- Required: `tramite_completado(tramite_id, agente)` YA existe en el bus (event_bus.gd, señal
  fundacional) — Economía ya la escucha y cobra. NO crear señales nuevas.
- Forbidden: reloj real; leer posición del sprite para decidir el fin de la atención (FL5).

---

## Acceptance Criteria

- [ ] **AC-FL09** `[Unit]` — GIVEN `dni` (12) y `modificador_produccion=1.0` THEN `duracion_efectiva=12`; con `0.7` → **8,4** (F1).
- [ ] **AC-FL10** `[Unit]` — GIVEN `modificador_produccion=0` (corrupto) WHEN F1 THEN `duracion_efectiva` se clampa a **1 min** (nunca instantánea/negativa).
- [ ] **AC-FL11** `[Integration]` — GIVEN una atención en curso WHEN cumple `duracion_efectiva` THEN se emite **`tramite_completado`** (trámite+agente) **una vez**, la Persona pasa a **Resuelta** y sale, y el puesto queda **Libre** (y llama al siguiente).
- [ ] *(E2E)* — GIVEN Economía real escuchando THEN el saldo **SUBE** con la tarifa del trámite al completarse (el hito económico del MVP).

---

## Implementation Notes

- **F1**: `duracion_efectiva(tramite_id, puesto_id) = duracion_min (Datos por id) ×
  _personal.modificador_produccion_de(puesto_id)`, clamp `maxf(1.0, ...)` (AC-FL10). El campo de
  duración del catálogo: verificar nombre exacto (`duracion_min`) en el esquema al implementar.
- **Tick**: `usar_tiempo(tiempo)` + `_suscribir_al_tick` (patrón Demanda — Flujo se suscribe
  DESPUÉS; Main garantiza el orden instanciando Flujo tras Demanda, story 008). `_al_tick(delta_min)`:
  (1) transicionar Llamada→En atención (el desplazamiento visible es cosmético — en la lógica la
  llegada al puesto es inmediata en el MVP; el tiempo de viaje NO se descuenta del trámite, FL5),
  (2) restar delta a cada atención en curso, (3) al llegar a 0: emitir `tramite_completado(
  tramite_id, agente)` UNA vez, Persona → Resuelta (despawn lógico: fuera de las estructuras),
  (4) `_emparejar()` (el puesto liberado llama al siguiente EN EL MISMO tick — el flujo no se
  queda un tick parado).
- En Pausa, Tiempo no empuja el tick → nada avanza (FL8 por construcción, patrón Demanda DG9).
- Bus inyectable `usar_bus` (patrón del proyecto); la señal `abandono(persona)` NO se emite en esta
  story (la emite la 006 vía `forzar_abandono`).

---

## Out of Scope

- Story 005: aforo/cola exterior. · Story 006: cierre en caliente y compromiso. · Story 008: el
  cuerpo que camina (cosmético).

---

## QA Test Cases

*Del qa-plan-sprint-2 (hilo principal, modo lean). Mundo real: Datos+Personal+Economía+bus.*

- **AC-FL09**: duracion_efectiva de dni (12, catálogo real) con agente estándar (mod 1.0) → 12.0;
  con crack (R5/M4 → mod 0.76 del test de Personal) → 9.12 (is_equal_approx).
- **AC-FL10**: modificador 0 inyectado (agente corrupto vía knobs artificiales) → clamp 1.0 min.
- **AC-FL11**: Given atención de dni en curso → ticks de 1 min → Then a los 12 min exactos UNA
  emisión (espía cuenta), Persona "resuelta", puesto Libre; un tick más → 0 emisiones nuevas.
- **E2E saldo SUBE**: Given Economía real (saldo 3000, tarifas del catálogo) escuchando el bus real
  → completar un dni → Then saldo > 3000 (+tarifa dni 12 € × retorno? — usar el comportamiento REAL
  de Economía: el test asegura que SUBE y en cuánto según su fórmula de ingreso ya testeada).
- **Encadenado**: al liberarse el puesto con cola no vacía → toma al siguiente en el mismo tick
  (la cola baja 2 personas en 24 min con 1 puesto).
- **Pausa**: patrón physics real en árbol (mult 0) → la atención no avanza (0 emisiones).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/flujo/flujo_atencion_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (emparejamiento) — DONE antes de empezar.
- Unlocks: Story 005 (aforo con el ciclo completo) y el HITO económico del MVP.
