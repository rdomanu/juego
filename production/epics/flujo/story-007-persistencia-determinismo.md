# Story 007: Persistencia y el AC rey del determinismo

> **Epic**: Flujo de Personas y Colas
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/flow-queues.md` (edge "si se guarda la partida", F7 determinista)
**Requirement**: `TR-flow-006` (serializar colas/puestos/personas: estado, turno, posición, tiempo restante)
**Governing ADRs**: ADR-0002 (primario — save/load + Persist; "cargar sitúa"; full_precision ya
aplicado), ADR-0001 (secundario — determinismo por diseño)
**ADR Decision Summary**: cada sistema serializa SU estado; la "posición" del GDD es el estado
LÓGICO (en qué cola/puesto está), no el píxel del sprite (FL5 — lo cosmético se re-deriva).

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM (persistencia — patrones rodados)
**Engine Notes**: solo tipos JSON-safe (StringName→String; la ficha envuelta de Demanda se
serializa por sus campos).

**Control Manifest Rules (Core / Foundation)**:
- Required: `save()`/`load_state()` + grupo `"Persist"`; carga sin señales; arranca en Pausa
  (SaveManager ya lo hace). — ADR-0002
- Forbidden: serializar posiciones de sprites o duplicar el estado del RNG.

---

## Acceptance Criteria

- [ ] **AC-FL26** `[Unit]` — GIVEN un save con una cola de N y una atención con `t` restante WHEN se carga THEN se restauran N, estados y `t`, y arranca en **Pausa**; sin eventos retroactivos.
- [ ] **AC-FL27** `[Unit]` — GIVEN la misma secuencia de llegadas/acciones desde idéntico estado WHEN se ejecuta dos veces THEN colas, asignaciones y eventos son **idénticos** (determinismo; sin dependencia de reloj real ni semillas).

---

## Implementation Notes

- **`save()`**: `{"personas": [{servicio, tramite (String), minuto_llegada, turno, estado (String)}],
  "puestos": [{id, abierto, cierre_pendiente, persona_turno (o -1), restante}], "turnos": {servicio:
  contador}, "reconfiguraciones": {...}}`. La pertenencia a colas/dentro-fuera se RE-DERIVA de los
  estados al cargar (una sola verdad). La ficha de Demanda envuelta se reconstruye desde sus campos
  (Persona es RefCounted de 3 campos).
- **`load_state(d)`**: defensivo (entrada corrupta → descartada con aviso, patrón personal/const);
  reconstruir personas → recolocar en colas por estado y turno → re-atar la persona en atención a su
  puesto por `persona_turno`; contador de turnos restaurado (sin reuso); 0 señales; nómina/saldo NO
  se tocan. INVARIANTE de orden: Construcción y Personal cargan ANTES (orden de hijos en Main:
  ...Construcción → Personal → Flujo — la 008 lo instancia al final).
- **AC-FL27 (determinismo A-vs-B)**: patrón personal-006 — mundo A: secuencia de admisiones +
  ticks + acciones (cerrar un puesto, reconfigurar) registrando eventos (espía del bus); repetir en
  mundo B desde el mismo estado → registro idéntico. Y la variante con SAVE a mitad: A sigue vs B
  carga y sigue → idénticos (la prueba reina, patrón demanda-006).
- Grupo Persist en `_ready` (clave "Flujo").

---

## Out of Scope

- El save de los NPCs visibles (cosmético — se re-derivan del estado lógico al cargar, story 008).

---

## QA Test Cases

*Del qa-plan-sprint-2 (hilo principal, modo lean).*

- **AC-FL26**: Given 4 en cola (2 dentro/2 fuera), 1 en atención con 7.5 min restantes → save →
  JSON full_precision → load en mundo B (Construcción+Personal cargados antes) → Then N/estados/
  turnos/restante idénticos campo a campo; 0 señales; el siguiente tick continúa desde 7.5.
- **AC-FL27**: secuencia guionizada (6 admisiones + 30 ticks + cerrar puesto a mitad) ejecutada en
  A y B → eventos (orden y payload) y colas finales IDÉNTICOS; variante con save/load a mitad en B
  → idéntico a A.
- **Corrupto**: persona con tramite inexistente en el save → descartada con aviso; el resto carga.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/flujo/flujo_save_determinismo_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (estado completo con cierres pendientes) — DONE antes de empezar.
- Unlocks: Story 008 (el cierre visible del epic y del Core).
