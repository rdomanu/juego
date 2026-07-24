# Story 005: Pausa y persistencia del layout

> **Epic**: Construcción y Distribución
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S-M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/construction-layout.md` (CO12 + edge "si se guarda la partida")
**Requirement**: `TR-construction-004` *(serializa layout)*
**Governing ADRs**: ADR-0002 (primario — `save()`/`load_state()` + grupo `Persist`; Vector2i→[x,y]),
ADR-0004 (secundario — el layout es el estado)
**ADR Decision Summary**: cada sistema serializa SU estado; "cargar sitúa, no reproduce" (0 señales,
sin cobros retroactivos). `SerialUtil` ya convierte `Vector2i` ↔ `{x,y}` (limitación JSON).

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM (persistencia — APIs ya rodadas; `full_precision` ya
aplicado en SaveManager)
**Engine Notes**: solo tipos JSON-safe (StringName → String; Vector2i/Rect2i → componentes int).

**Control Manifest Rules (Core / Foundation)**:
- Required: `save()`/`load_state()` + grupo `"Persist"`; carga sin señales. — ADR-0002
- Forbidden: cobrar/reembolsar al cargar (el saldo ya viene en el save de Economía).

---

## Acceptance Criteria

- [ ] **AC-CO16** `[Integration]` — GIVEN el juego en **Pausa** (mundo real en árbol) WHEN se construye/demuele/mueve THEN se permite y funciona (CO12 — la construcción no depende del reloj).
- [ ] **AC-CO17** `[Unit]` — GIVEN un save del **layout** WHEN se carga en una instancia nueva THEN se restauran rejilla, salas (tipo+rect), puestos y objetos (tipo+celda+coste_pagado) — campo a campo.
- [ ] *(ADR-0002)* — GIVEN la carga THEN **cero señales** y los puestos quedan **re-registrados en Personal**.

---

## Implementation Notes

- **`save()`**: `{"salas": [{id, tipo (String), rect: [x,y,w,h]}], "elementos": [{id, tipo_catalogo
  (String), celda: [x,y], sala (String), coste_pagado}], "contador_ids": int}`. NO guardar: aforos ni
  costes de catálogo (derivados), NI el tamaño del edificio (config).
- **`load_state(d)`**: defensivo (entrada corrupta → descartar ESA con aviso, patrón personal-006);
  reconstruir modelo; **re-registrar los puestos en Personal** (`registrar_puesto`) SIN señales; ids del
  contador restaurados (que un id nuevo no pise uno cargado).
- **⚠️ ORDEN DE CARGA (punto de diseño detectado en las stories de Personal):** el invariante de
  `Personal.load_state` es "puestos registrados ANTES de cargar asignaciones". Con puestos dinámicos,
  **Construcción debe instanciarse ANTES que Personal en Main** (el SaveManager distribuye en orden de
  árbol) → la 006 reordena `_instanciar_mundo` (Construcción → Personal) y lo documenta. Los tests de
  esta story verifican el round-trip combinado Construcción+Personal en ese orden.
- **Pausa (AC-CO16)**: no requiere código (nada de Construcción escucha el tick) — el test lo demuestra
  con physics real en árbol y Tiempo en PAUSA (patrón DM11/PE19).

---

## Out of Scope

- El save de asignaciones de agentes (Personal, hecho en personal-006). · El visual (006/007).

---

## QA Test Cases

*Escritos por el hilo principal (modo lean) desde qa-plan-sprint-2.*

- **AC-CO17**: Given layout rico (oficina Doc con 2 puestos, espera con 3 asientos, ODAC con 1) →
  save → JSON.stringify(full_precision) → parse → load en instancia B (mismo config) → salas y
  elementos campo a campo idénticos; aforo_de_sala recalculado idéntico; construir tras cargar genera
  un id que NO colisiona.
- **Re-registro**: Given B con Personal real inyectado → load → Personal.asignar a un puesto cargado →
  true (el puente revivió).
- **Round-trip combinado (orden de carga)**: Given mundo A con agente ASIGNADO a un puesto CONSTRUIDO →
  save de Construccion+Personal → cargar en B **Construcción primero, Personal después** → el agente
  sigue asignado y `puesto_dotado` true.
- **Carga silenciosa**: espías del bus (todas las señales) → load → 0 emisiones; saldo de Economía
  intacto (ni cobros ni reembolsos).
- **Corrupto**: elemento con tipo_catalogo inexistente en el save → se descarta con aviso, el resto
  carga (NUNCA invalida el save — ADR-0002).
- **AC-CO16**: mundo real en árbol (Tiempo PAUSA) → construir+demoler durante 30 physics frames →
  funciona y el reloj no avanzó.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/construccion/construccion_save_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (ciclo completo construir/demoler/mover) — DONE antes de empezar.
- Unlocks: Story 006 (el mundo visible con carga ordenada).
