# Story 006: Persistencia — el grifo sobrevive al guardado

> **Epic**: Generación de Demanda
> **Status**: Complete (cierre del epic con sign-off, 2026-07-24)
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S-M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/demand-generation.md` (Edge Case "guardar a mitad de generación"; DG5 determinismo)
**Requirement**: `TR-demand-002` *(la parte de serialización: acumulador + estado del RNG → secuencia futura idéntica; el RNG en sí lo serializa `RNGService` — TR-save-002)*
*(Texto del requisito en `docs/architecture/tr-registry.yaml`)*

**Governing ADRs**: ADR-0002 (primario — patrón `save()`/`load_state()` + grupo `Persist`; JSON en `user://`)
**ADR Decision Summary**: cada sistema persistente implementa `save() -> Dictionary` / `load_state(d)` y se marca con el grupo `Persist`; `SaveManager` lo recorre sin conocer nombres. Al cargar: catálogo ya cargado, Pausa, **sin eventos retroactivos** ("cargar sitúa, no reproduce").

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM (persistencia; APIs post-cutoff ya verificadas en el epic SaveManager)
**Engine Notes**: `FileAccess.store_*` devuelve `bool` (4.4+) — ya lo maneja SaveManager. Solo tipos JSON-safe en el Dictionary (float/int/String/Array/Dict — los `StringName` se guardan como `String` y se reconvierten al cargar).

**Control Manifest Rules (Core / Foundation)**:
- Required: `save()`/`load_state()` + grupo `"Persist"` (en `_ready`, `add_to_group("Persist")` — patrón Economía). — ADR-0002
- Forbidden: **duplicar el estado del RNG** en el save de Demanda — lo serializa `RNGService` en su propia entrada. — ADR-0002
- Required: al cargar, **no** emitir señales (`nivel_demanda_cambiado` se restaura en silencio). — ADR-0002

---

## Acceptance Criteria

*Del GDD, acotados a esta historia:*

- [ ] **AC-DM18** `[Unit/Integration]` — GIVEN un save con acumulador + estado RNG WHEN se carga THEN se restauran y la secuencia futura de llegadas/trámites continúa **idéntica** a la de una partida que no guardó; la partida arranca en **Pausa**.

---

## Implementation Notes

- **`save() -> Dictionary`** con claves (todas JSON-safe):
  `acumulador_doc: float`, `acumulador_odac: float`, `llegadas_hoy: int`, `nivel: String` (de `StringName`),
  `evento_activo: String` ("" si ninguno), `evento_jornadas_restantes: int`.
  **No guardar**: `mult_estacional` vigente (derivable del mes de Tiempo al cargar), nada del RNG, nada del catálogo/config.
- **`load_state(d: Dictionary)`**: restaurar con defaults defensivos (`d.get(clave, default)` — un save viejo sin una clave no revienta); reconvertir `String`→`StringName`; recalcular el mult estacional desde `tiempo.mes`; **sin emitir señales** ni generar nada retroactivo.
- El round-trip pasa **por disco de verdad** vía `SaveManager.guardar_partida()`/`cargar_partida()` (patrón de la suite existente: el smoke de SaveManager ya monta el mundo) — no solo dict-a-dict.
- **El test de determinismo es el corazón**: correr N minutos → guardar → seguir M minutos (secuencia A) VS cargar el save → seguir M minutos (secuencia B) → A == B ficha a ficha. Esto solo funciona si RNGService restauró su estado (su propia entrada del save) — verifica la composición completa.
- Recordar la decisión del epic RNGService: la semilla/estado viajan como **String** en JSON (int64 no sobrevive al float de JSON) — ya resuelto en Foundation, no tocar.

---

## Out of Scope

- La UI de guardar/cargar (SaveManager/Presentation).
- Migraciones de versión del save (campo `version` — lo posee SaveManager).
- Story 007: instancia en Main (el test monta su propio mini-mundo inyectado).

---

## QA Test Cases

*Escritos por el hilo principal (modo lean).*

- **AC-DM18 (round-trip)**: Given Demanda con estado no trivial (acumuladores fraccionales, llegadas_hoy>0, nivel ALTA, evento activo con 2 jornadas) → When `save()` → JSON → disco → `load_state()` en una instancia NUEVA → Then los 6 campos idénticos (comparar campo a campo).
- **AC-DM18 (determinismo)**: Given semilla 42, avanzar 120 min de juego → guardar → avanzar 180 min más registrando fichas (A) → When se carga el save en un mundo nuevo y se avanzan los mismos 180 min (B) → Then A == B (mismo nº, mismos `tramite_id`, mismos minutos).
- **Carga silenciosa**: Given listener de `nivel_demanda_cambiado` y `persona_generada` conectados → When `load_state` → Then 0 emisiones.
- **Save viejo**: Given un dict sin `evento_activo` → When `load_state` → Then defaults sanos (sin evento), sin errores.
- Edge: tras cargar, el juego está en Pausa (lo fija SaveManager/Tiempo — verificar que Demanda no genera hasta reanudar).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/demanda/demanda_persistencia_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [x] Creado y en verde (5 tests; suite total 220/220, exit 0 — 2026-07-23). Round-trip por JSON
real (el de disco lo cubre la suite del SaveManager — patrón Economía). **2 hallazgos aplicados:**
(1) el mult estacional se deriva del mes TAMBIÉN en el arranque (coherencia arranque/carga — DG13 es
calendario); (2) `SaveManager.guardar_partida` ahora usa `full_precision=true` en JSON.stringify (sin
él, los floats perdían decimales en el round-trip → adiós determinismo exacto de ADR-0002).

---

## Dependencies

- Depends on: Story 005 (estado del evento a serializar) — DONE antes de empezar.
- Unlocks: Story 007 (cierre visible del epic).
