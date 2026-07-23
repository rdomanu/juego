# Story 003: Asignación a puestos y el gate para Flujo (FL4)

> **Epic**: Personal / Agentes
> **Status**: Implemented — 7/7 tests en verde (pendiente `/story-done`)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-24

## Context

**GDD**: `design/gdd/staff-agents.md` (PA2, PA5 + edges de asignación)
**Requirement**: `TR-staff-002` (provee `modificador_produccion`/`factor_trato` y gate FL4 a Flujo)
**Governing ADRs**: ADR-0001 (primario — API limpia entre sistemas; sin acoplar por nombre), ADR-0003 (secundario — validación por catálogo)
**ADR Decision Summary**: Personal PROVEE y Flujo CONSUME; la validez de una asignación la dicta el catálogo (`TipoAgente.puestos_operables`).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: sin API post-cutoff.

**Control Manifest Rules (Core)**:
- Required: leer definiciones por `id` read-only vía `Datos.obtener` (nunca mutarlas). — ADR-0003
- Forbidden: Personal nunca llama a Flujo/UI por nombre — expone API y señales. — ADR-0001

---

## ⚠️ Contexto de secuencia (honesto)

Construcción #7 y Flujo #4 **no existen aún**. Esta story modela los puestos como **identificadores
abstractos registrados por el mundo** (`registrar_puesto(puesto_id, tipo_puesto_id)`) — Main registra la
dotación estándar; cuando Construcción exista, registrará los puestos REALES con la misma API y nada se
tira. El **gate FL4** se entrega como API que Flujo consumirá (`puesto_dotado`, modificadores por puesto).

---

## Acceptance Criteria

- [ ] **AC-PE08** `[Unit*]` — GIVEN un `ag_doc` WHEN se asigna a un puesto de tipo `puesto_doc_general` THEN se acepta y `puesto_dotado()` es true (gate FL4 listo para Flujo); a un `puesto_odac` → **rechazado** (`puestos_operables` de Datos). *(La atención real la verificará Flujo — parte diferida documentada.)*
- [ ] **AC-PE02** `[Unit*]` — GIVEN un servicio con Oficial asignado WHEN se intenta asignar un 2.º Oficial al mismo servicio THEN se **rechaza** (máx. 1/servicio).
- [ ] **AC-PE09** `[Unit*]` — GIVEN un agente ya asignado WHEN se reasigna a otro puesto THEN se **mueve** (libera el anterior; nunca queda en dos). *(El "no cortar una atención en curso" es contrato de Flujo al consumir el cambio — anotado para su epic.)*
- [ ] *(PE10 — DIFERIDO a Flujo)* — Personal ya expone `modificador_produccion_de(puesto)`; que la duración efectiva cambie lo testeará Flujo (F1 suyo). Registrado como AC pendiente de integración.

---

## Implementation Notes

- **Registro de puestos**: `registrar_puesto(puesto_id: StringName, tipo_puesto_id: StringName)` (y
  `quitar_puesto`). El **servicio** del puesto se deriva del catálogo (`TipoPuesto` → servicio); si el
  esquema no lo trae directo, mapear por convención de id (`puesto_doc_*`/`puesto_tie` → Documentacion;
  `puesto_odac` → ODAC) — **decisión propuesta, aprobar al implementar** mirando el esquema real.
- **`asignar(agente, puesto_id) -> bool`**: valida (a) puesto registrado y sin otro agente
  (`plazas_agente=1`), (b) `tipo_puesto_id ∈ TipoAgente.puestos_operables` (catálogo), (c) si el agente
  es Oficial → no hay ya Oficial asignado en ese servicio (PA2). Si venía de otro puesto → lo libera
  (mover atómico). Estado → `&"asignado"`.
- **`desasignar(agente)`** → `&"libre"`, puesto sin dotar.
- **API para Flujo (el gate FL4)**: `puesto_dotado(puesto_id) -> bool` (tiene agente Y su estado es
  asignado/cubriendo — el ausente NO dota, story 004), `agente_de(puesto_id) -> Agente`,
  `modificador_produccion_de(puesto_id) -> float` y `factor_trato_de(puesto_id) -> float` (fórmulas de
  la 001 sobre el agente asignado; sin agente → 1.0 con aviso).
- Nota de contrato para **Flujo** (dejar en el código): al cambiar la dotación de un puesto con atención
  en curso, Flujo termina la atención antes de aplicar el cambio (compromiso de servicio).

---

## Out of Scope

- Story 004: el estado ausente y su efecto en `puesto_dotado`. · Story 005: cobertura (estado cubriendo). · UI de asignación (UI/HUD #11). · La duración efectiva real (Flujo F1).

---

## QA Test Cases

*Escritos por el hilo principal (modo lean). Catálogo REAL (Datos) para `puestos_operables`.*

- **AC-PE08**: Given ag_doc y puestos registrados doc_1 (`puesto_doc_general`) y odac_1 (`puesto_odac`) → `asignar(a, doc_1)` true y `puesto_dotado(doc_1)` true; `asignar(a, odac_1)` false (y el agente NO se movió de doc_1).
- **AC-PE02**: Given Oficial O1 asignado a doc_1 → `asignar(O2_oficial, doc_2)` false (mismo servicio); `asignar(O2_oficial, odac_1)` true si es ag_odac compatible (servicio distinto).
- **AC-PE09**: Given agente en doc_1 → `asignar(a, doc_2)` → Then doc_1 sin dotar, doc_2 dotado, y el agente consta solo en doc_2.
- **Doble ocupación**: Given doc_1 dotado → `asignar(b, doc_1)` false (`plazas_agente=1`).
- **Modificadores por puesto**: Given crack (R5/M4) en doc_1 → `modificador_produccion_de(doc_1)` ≈ 0.76; puesto sin agente → 1.0 + aviso.
- **Puesto no registrado**: `asignar(a, &"no_existe")` false con aviso (sin crash).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/personal/personal_asignacion_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [x] Creado y en verde (7 tests; suite total 243/243, exit 0 — 2026-07-24). La decisión del
servicio se resolvió limpia: `TipoPuesto.servicio` YA existe en el esquema (sin convención de nombres).

---

## Dependencies

- Depends on: Story 002 (plantilla con agentes) — DONE antes de empezar.
- Unlocks: Story 004 (ausencias afectan al gate), Flujo (futuro consumidor).
