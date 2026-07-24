# Story 002: Las colas — FIFO, prioridad ODAC y compatibilidad (F7)

> **Epic**: Flujo de Personas y Colas
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S-M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/flow-queues.md` (FL2, FL3, F7)
**Requirement**: `TR-flow-002` (colas por servicio FIFO + prioridad ODAC; selección determinista)
**Governing ADRs**: ADR-0001 (primario — selección determinista, sin azar), ADR-0003 (secundario —
`prioridad` de la DenunciaODAC y `atenciones_admitidas` del TipoPuesto salen del catálogo)
**ADR Decision Summary**: la selección es una función PURA sobre la cola: clave mínima
`(rango_prioridad, numero_turno)` entre las compatibles. Sin RNG (manifest: la cobertura/selección
es determinista por reglas).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: n/a.

**Control Manifest Rules (Core)**:
- Required: leer `prioridad`/`atenciones_admitidas` del catálogo por id, read-only. — ADR-0003
- Forbidden: azar fuera de RNGService (aquí NO hay azar: F7 es determinista).

---

## Acceptance Criteria

- [ ] **AC-FL03** `[Unit]` — GIVEN cola de Documentación con turnos {3,1,2} WHEN un puesto llama THEN sirve en orden **1,2,3** (FIFO puro, menor `numero_turno`).
- [ ] **AC-FL04** `[Unit]` — GIVEN cola ODAC con Normal(turno 1) y Prioritaria(turno 2) WHEN un puesto llama THEN sirve **la Prioritaria primero** (F7: rango 0 antes que 1).
- [ ] **AC-FL05** `[Unit]` — GIVEN un `puesto_tie` y una cola que solo contiene DNI/Pasaporte WHEN evalúa THEN **no llama a nadie** (ninguna compatible → espera).
- [ ] **AC-FL06** `[Integration]` — GIVEN `puesto_doc_general` Libre y cola [tie, dni, pasaporte] WHEN llama THEN toma **`dni`** (primera compatible por turno), **no** `tie`.

---

## Implementation Notes

- Colas: `_colas: {servicio -> Array[PersonaFlujo]}` (las de estado Esperando dentro/fuera; el
  detalle dentro/fuera es de la 005 — aquí la cola LÓGICA completa).
- **`elegir_de_cola(servicio, atenciones_admitidas: Array[StringName]) -> PersonaFlujo`** (F7):
  entre las Personas EN ESPERA compatibles (`tramite_id in atenciones_admitidas`), la de clave
  `(rango_prioridad, numero_turno)` mínima; sin compatible → null (el puesto espera, FL3).
- `rango_prioridad`: Documentación → 1 para todas (FIFO puro). ODAC → de la `DenunciaODAC.prioridad`
  del catálogo (`"Prioritaria"` = 0 · `"Normal"` = 1 — verificar el nombre EXACTO del campo/valores
  en el esquema al implementar; el test usa el catálogo real con `viogen`).
- `atenciones_admitidas` del `TipoPuesto` del catálogo (verificar nombre exacto del campo).
- La cola NO se reordena al meter (se inserta al final); el ORDEN lo impone la clave al elegir —
  menos invariantes que mantener y el mismo resultado determinista.

---

## Out of Scope

- Story 003: quién llama (el puesto) y el gate FL4. · Story 005: dentro/fuera por aforo.

---

## QA Test Cases

*Del qa-plan-sprint-2 (hilo principal, modo lean).*

- **AC-FL03**: Given 3 PersonasFlujo Doc encoladas en orden de llegada 3,1,2 (turnos manipulados
  para el escenario) → elegir 3 veces retirando → Then orden 1,2,3.
- **AC-FL04**: Given ODAC con denuncia Normal (turno 1) y `viogen` del catálogo real (Prioritaria,
  turno 2) → Then sale viogen primero; luego la Normal.
- **AC-FL05**: Given cola Doc solo con dni/pasaporte → elegir con admitidas del `puesto_tie`
  (catálogo real) → null.
- **AC-FL06**: Given cola [tie(t1), dni(t2), pasaporte(t3)] → elegir con admitidas de
  `puesto_doc_general` → dni (la compatible de menor turno, saltándose la tie).
- **Borde**: cola vacía → null; todas incompatibles → null (no revienta).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/flujo/flujo_colas_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (PersonaFlujo y turnos) — DONE antes de empezar.
- Unlocks: Story 003 (el puesto tira de la cola).
