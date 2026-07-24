# Story 001: La Persona en el flujo — máquina de 7 estados y turnos por servicio

> **Epic**: Flujo de Personas y Colas
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S-M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/flow-queues.md` (FL1, FL2, States A)
**Requirement**: `TR-flow-001` (instancia Persona con máquina de estados de 7)
**Governing ADRs**: ADR-0001 (primario — simulación determinista por estados; FL5: el movimiento es
COSMÉTICO y vive en otra story), ADR-0003 (secundario — trámite por id del catálogo)
**ADR Decision Summary**: la LÓGICA del flujo es una máquina de estados pura que avanza con el reloj
de juego — nunca lee posiciones de sprites ni depende de la navegación (story 008).

**Engine**: Godot 4.6 | **Risk**: LOW (sin API de motor en esta story)
**Engine Notes**: n/a — RefCounted + nodo puro.

**Control Manifest Rules (Core)**:
- Forbidden: la lógica de balance NUNCA lee la posición/movimiento del sprite (FL5). — ADR-0004
- Required: tipado estático; ficha de Demanda envuelta, no duplicada (decisión demanda-001 ratificada).

---

## Acceptance Criteria

- [ ] **AC-FL01** `[Unit]` — GIVEN Demanda crea una Persona de `dni` WHEN entra THEN tiene `servicio=Documentacion`, `tramite=dni`, un `numero_turno`, estado inicial **Llegando** y una referencia de paciencia *(stub — Paciencia #10)*.
- [ ] **AC-FL02** `[Unit]` — GIVEN dos Personas del mismo servicio WHEN cogen número THEN reciben `numero_turno` **consecutivos crecientes** (contador único por servicio).
- [ ] *(States A)* — Las transiciones válidas de la tabla del GDD se aplican y las inválidas se rechazan con aviso (Llegando→Esperando; Esperando→Llamada; Llamada→En atención; En atención→Resuelta; Esperando→Abandonando).

---

## Implementation Notes

- **Nodo `Flujo`** (`class_name Flujo extends Node`, nodo del mundo — arq. §3.4; Main lo instanciará
  DESPUÉS de Demanda en la 008) + **`ConfigFlujo`** (Resource + tools/build_config_flujo.gd →
  datos/config/flujo.tres; knobs del GDD §Tuning Knobs — leer la tabla al implementar, patrón de
  clamps del proyecto).
- **`PersonaFlujo`** (RefCounted, patrón Agente): ENVUELVE la ficha `Persona` de Demanda (referencia,
  no copia: servicio/tramite_id/minuto_llegada) + `numero_turno: int`, `estado: StringName`
  (constantes ESTADO_LLEGANDO/ESPERANDO_FUERA/ESPERANDO_DENTRO/LLAMADA/EN_ATENCION/RESUELTA/
  ABANDONANDO), `paciencia: RefCounted = null` (stub; Paciencia #10 lo poblará).
- **`admitir(ficha) -> PersonaFlujo`**: crea la PersonaFlujo, asigna turno del contador de SU
  servicio (`_turnos: {servicio -> int}`, empieza en 1, NUNCA se reusa) y estado Llegando.
- **Transiciones**: método `_transicionar(persona, estado_nuevo)` con tabla de transiciones VÁLIDAS
  (inválida → aviso y no cambia — dato corrupto no rompe, patrón Agente).

---

## Out of Scope

- Story 002: colas y selección. · Story 005: aforo (Llegando→dentro/fuera). · Story 008: el cuerpo
  visible de la persona (nav).

---

## QA Test Cases

*Del qa-plan-sprint-2 (hilo principal, modo lean).*

- **AC-FL01**: Given ficha real de Demanda (Persona dni/Documentacion) → admitir → Then servicio,
  tramite y minuto conservados (misma referencia), turno asignado, estado "llegando", paciencia null.
- **AC-FL02**: Given 3 admisiones Doc y 2 ODAC intercaladas → Then turnos Doc = 1,2,3 y ODAC = 1,2
  (contadores independientes, crecientes, sin huecos).
- **Transiciones**: válidas de la tabla → cambian; inválida (Resuelta→Llamada) → aviso y no cambia.
- **Config**: clamps + .tres real (patrón del proyecto).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/flujo/flujo_persona_turnos_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (primera del epic; Demanda/Personal/Construcción completos).
- Unlocks: Story 002 (las colas ordenan PersonasFlujo).
