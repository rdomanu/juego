# Story 003: Los puestos — estados, gate FL4 y emparejamiento sin dobles

> **Epic**: Flujo de Personas y Colas
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/flow-queues.md` (FL3, FL4, States B)
**Requirement**: `TR-flow-003` *(parcial — emparejamiento automático puesto→persona)*
**Governing ADRs**: ADR-0001 (primario — capas: Flujo consume Construcción/Personal, nunca al revés)
**ADR Decision Summary**: el puesto de Flujo es un ESTADO sobre el puesto físico de Construcción
(existencia/posición) y la dotación de Personal (gate FL4) — Flujo no duplica ni posee ninguna de
las dos cosas.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: n/a.

**Control Manifest Rules (Core)**:
- Required: capas estrictas — el agente lo posee Personal (`puesto_dotado`/`agente_de`); la
  existencia, Construcción (`puestos_de_servicio`/`elemento_en`). — ADR-0001
- Forbidden: que el emparejamiento dependa de posiciones de sprites (FL5). — ADR-0004

---

## Acceptance Criteria

- [ ] **AC-FL07** `[Integration]` — GIVEN puesto **abierto sin agente** y cola compatible WHEN evalúa THEN **NO atiende** (FL4).
- [ ] **AC-FL08** `[Integration]` — GIVEN puesto abierto **con agente** y cola compatible WHEN llama THEN pasa a **Atendiendo** (la Persona a **Llamada**).
- [ ] **AC-FL23** `[Integration]` — GIVEN dos puestos Libres simultáneos y **una** sola Persona compatible WHEN ambos evalúan THEN la toma **exactamente uno** (menor `id`); el otro sigue Libre (sin doble asignación).
- [ ] *(States B)* — Cerrado ↔ Abierto-sin-agente ↔ Libre ↔ Atendiendo según la tabla del GDD; abrir/cerrar es API del jugador (FL10 — el cierre DURANTE atención es de la 006).

---

## Implementation Notes

- **Registro de puestos de Flujo**: `_puestos: {puesto_id -> {abierto: bool, persona: PersonaFlujo}}`.
  Los ids son los de Construcción (`registrar_puesto_flujo` al construirse / al arrancar — usar
  `usar_construccion(nodo)` inyectable + los getters `puestos_de_servicio`; el estado abierto
  ARRANCA en abierto (decisión propuesta: en el MVP los puestos nacen abiertos — los horarios de
  Documentación #8 los gobernarán después).
- **Estado DERIVADO** (nunca almacenado como verdad): `estado_de_puesto(id)` = Cerrado (si
  !abierto) · Abierto-sin-agente (si !`_personal.puesto_dotado(id)`) · Atendiendo (si persona) ·
  Libre. El gate FL4 completo = construido ∧ abierto ∧ dotado ∧ compatible en cola.
- **`_emparejar()`**: recorre los puestos LIBRES en orden estable de id (menor primero — AC-FL23:
  el orden de iteración ES el desempate) y por cada uno `elegir_de_cola` (002) con las
  `atenciones_admitidas` de su tipo del catálogo; si hay Persona → sacarla de la cola, estado
  Llamada, puesto la referencia. Una Persona SOLO puede estar en un puesto (sale de la cola al
  tomarla — la doble asignación es imposible por construcción, y el test lo demuestra).
- La transición Llamada→En atención y el avance con delta son de la 004 (aquí el emparejamiento
  deja a la Persona en Llamada).

---

## Out of Scope

- Story 004: el tick, la duración y el `tramite_completado`. · Story 006: cerrar/reconfigurar en
  caliente. · Story 008: el desplazamiento visible hasta el puesto.

---

## QA Test Cases

*Del qa-plan-sprint-2 (hilo principal, modo lean). Personal y Construcción REALES.*

- **AC-FL07**: Given puesto construido y abierto, SIN agente (Personal real sin asignar) + cola con
  dni compatible → _emparejar → Then la Persona sigue en cola y el puesto en Abierto-sin-agente.
- **AC-FL08**: Given el mismo puesto CON agente asignado → _emparejar → Then Persona en Llamada,
  fuera de la cola, puesto Atendiendo.
- **AC-FL23**: Given doc_1 y doc_2 dotados y libres + UNA persona dni → _emparejar → Then la tiene
  exactamente uno (el de menor id en orden de registro) y el otro sigue Libre.
- **States B**: cerrar un puesto Libre → Cerrado y no llama; reabrir → vuelve a llamar; quitar el
  agente (Personal.desasignar) → Abierto-sin-agente.
- **Puente completo**: construir un puesto NUEVO con Construcción real → registrarlo en Flujo →
  asignarle agente → atiende (el hilo Construcción→Personal→Flujo de punta a punta).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/flujo/flujo_puestos_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (selección F7) — DONE antes de empezar.
- Unlocks: Story 004 (la atención avanza y cobra).
