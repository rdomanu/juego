# Story 004: Cruce de umbrales → señales de turno y día/noche (1 vez, en orden)

> **Epic**: Sistema de Tiempo
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: (lo fija /dev-story al empezar)

## Context

**GDD**: `design/gdd/time-system.md` (Core Rules 4.2 — el turno avisa al cambiar; States and Transitions B — estados derivados con aviso; Edge Cases — cruce por umbral, no igualdad; jitter de float una sola vez)
**Requirement**: `TR-time-003` (detección de **cruce** de umbral, no `==` → cada evento se emite 1 vez) · `TR-time-004` (orden determinista al cruzar varios umbrales: turno → día/noche) · `TR-time-006` (emite señales globales `cambio_de_turno`, `cambio_dia_noche`)

**ADR Governing Implementation**: ADR-0001: Bus de eventos, tick y orden determinista *(primario)*
**ADR Decision Summary**: los eventos de cruce se emiten **una sola vez** detectando `anterior < umbral ≤ nuevo` (nunca `==`). `cambio_de_turno` y `cambio_dia_noche` son **señales de aviso** del EventBus (orden entre oyentes indiferente) → se emiten con `EventBus.<señal>.emit(...)`, **NO** por el dispatcher (`disparar_ordenado`); el dispatcher se reserva para `nuevo_dia`/`nuevo_mes` (H5). El orden **relativo** dentro de un mismo frame es turno → día/noche.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `EventBus.cambio_de_turno.emit(turno)` y `EventBus.cambio_dia_noche.emit(es_noche)` ya existen en `event_bus.gd` (firmas `cambio_de_turno(turno: int)`, `cambio_dia_noche(es_de_noche: bool)`). No se añade nada al bus en esta story.

**Control Manifest Rules (Foundation)**:
- Required: detección de cruce por **`anterior < umbral ≤ nuevo`** (nunca `==`); **1 emisión por cruce**; guarda del último umbral cruzado (anti-jitter/anti-duplicado); orden dentro del frame **turno → día/noche**; emisión vía `EventBus.<señal>.emit()`.
- Forbidden: **nunca** comparar `hora == X` para disparar; nunca emitir el mismo cruce dos veces por imprecisión de float; **no** usar el dispatcher (`disparar_ordenado`) para `cambio_de_turno`/`cambio_dia_noche` (son avisos, no ordenados).
- Cross-cutting: determinismo; el bus solo retransmite (no lógica de juego).

---

## Acceptance Criteria

*De GDD States/Transitions B + Edge Cases. Valores transcritos exactos de los AC-T del GDD:*

- [ ] **AC-T16**: GIVEN `899.7` (Mañana) a 3× WHEN el update pasa a `900.3` (cruza 15:00) THEN se emite **`cambio_de_turno(TARDE)` una sola vez** y el turno registrado es TARDE.
- [ ] **AC-T17**: GIVEN `1379.8` (Tarde) WHEN pasa a `1380.5` (cruza 23:00) THEN se emiten **`cambio_de_turno(NOCHE)`** y **`cambio_dia_noche(noche)`**, una vez cada uno, **en ese orden**.
- [ ] **AC-T18**: GIVEN `419.8` (Noche) WHEN pasa a `420.5` (cruza 07:00) THEN se emiten **`cambio_de_turno(MAÑANA)`** y **`cambio_dia_noche(dia)`**, una vez cada uno, **en ese orden**.
- [ ] **AC-T19** `[Integration]`: GIVEN un sistema oyente suscrito a `cambio_de_turno` WHEN el reloj cruza 15:00 THEN el oyente recibe **exactamente una** notificación con `TARDE` antes del siguiente frame.
- [ ] **AC-T23** *(parte turno+día/noche del multi-cruce)*: GIVEN `1379.0` (22:59, Tarde) WHEN un `delta` grande lleva el acumulador a `1441.0` (cruza 23:00 **y** 00:00) THEN, de los eventos de esta story, se disparan **en orden** `cambio_de_turno(NOCHE)` → `cambio_dia_noche(noche)`, **una vez cada uno**. *(El `nuevo_dia` del mismo frame es H5; el orden completo turno→día/noche→nuevo_dia se cierra allí.)*
- [ ] **AC-T24**: GIVEN el escenario de AC-T23 WHEN se recogen las señales THEN **ninguna se omite ni se duplica** (sin duplicados por jitter de float; la guarda del último umbral lo garantiza).

---

## Implementation Notes

- **Detección de cruce (regla de oro del GDD)**: comparar el turno/estado **anterior** con el **nuevo** tras `avanzar()`:
  ```
  turno_nuevo = turno(minutos_juego)
  si turno_nuevo != turno_anterior:
      EventBus.cambio_de_turno.emit(turno_nuevo)
      turno_anterior = turno_nuevo
  ```
  Se compara el **cambio de valor derivado** (turno anterior vs nuevo), que es equivalente a "cruzó el umbral una vez" y es robusto a float y a saltos grandes. Mismo patrón para `es_de_noche` (bool anterior vs nuevo).
- **Orden dentro del frame**: emitir **primero** `cambio_de_turno`, **después** `cambio_dia_noche` (GDD: turno → día/noche). Un solo frame puede cambiar ambos (23:00: Tarde→Noche y día→noche).
- **Anti-jitter (Edge Case del GDD)**: guardar `turno_anterior` y `era_de_noche_anterior` como estado; solo se emite cuando el valor derivado **cambia**. Si el jitter de float mueve `minutos_juego` alrededor de un umbral ya cruzado, el turno derivado **no** cambia → no se re-emite.
- **Multi-cruce en un frame (AC-T23/T24)**: como se compara "valor derivado anterior vs nuevo" (no se recorre umbral a umbral), un `delta` que salta de 22:59 a 00:02 deja `turno_anterior=TARDE`, `turno_nuevo=NOCHE` → **un** `cambio_de_turno(NOCHE)`; `era_noche=false`→`true` → **un** `cambio_dia_noche(noche)`. Ninguno se duplica. El `nuevo_dia` de ese mismo salto lo añade H5 (que ordena turno→día/noche→nuevo_dia; ver Out of Scope).
- **Punto de comparación**: esta lógica se llama **tras** `avanzar()` (misma función que en H7 correrá cada `_physics_process`). Para testear sin motor, un método `_procesar_cruces()` (o similar) que se invoca después de `avanzar()` en los tests.
- **NO usar el dispatcher**: `cambio_de_turno`/`cambio_dia_noche` son señales de **aviso** (orden entre oyentes indiferente) → `EventBus.cambio_de_turno.emit(...)`. El `disparar_ordenado` es solo para `nuevo_dia`/`nuevo_mes` (H5). Confundirlos violaría el patrón del ADR-0001.
- **`self.` footgun**: si un método interno se llamara como una global, cualificar con `self.` (patrón de `rng_service.gd`). No aplica a los nombres actuales.

## Out of Scope

- **H5**: `nuevo_dia`/`nuevo_mes` y el calendario (semana/mes/año). El **orden completo** del multi-cruce (turno → día/noche → **nuevo_dia**) se cierra en H5; aquí solo se garantiza turno → día/noche.
- **H3**: el cálculo del turno/`es_de_noche` en sí (ya existe; aquí solo se detecta su **cambio**).
- La sincronización del umbral anterior al **cargar** (para no disparar cruce espurio el 1er frame) es **H8**.

## QA Test Cases

*Logic — con un doble/espía del EventBus o conectando a las señales reales y contando. Determinista. `tests/unit/tiempo/` (+ integración en `tests/integration/tiempo/` para AC-T19).*

- **`test_cruce_15h_emite_cambio_turno_tarde_una_vez`** (AC-T16): de 899.7 a 900.3 → 1× `cambio_de_turno(TARDE)`, turno registrado TARDE.
- **`test_cruce_23h_turno_y_dianoche_en_orden`** (AC-T17): de 1379.8 a 1380.5 → `cambio_de_turno(NOCHE)` **antes** de `cambio_dia_noche(true)`, uno cada uno.
- **`test_cruce_7h_turno_y_dianoche_en_orden`** (AC-T18): de 419.8 a 420.5 → `cambio_de_turno(MANANA)` antes de `cambio_dia_noche(false)`.
- **AC-T19 `[Integration]`**: un nodo oyente conectado a `EventBus.cambio_de_turno`; cruzar 15:00 → recibe exactamente 1 aviso con TARDE. Evidencia en `tests/integration/tiempo/`.
- **`test_multicruce_turno_y_dianoche_sin_duplicar`** (AC-T23/T24): de 1379.0 a 1441.0 → un `cambio_de_turno(NOCHE)` seguido de un `cambio_dia_noche(true)`, sin duplicados. *(No se comprueba `nuevo_dia` aquí; es H5.)*
- **`test_jitter_no_reemite`**: mover `minutos_juego` con pequeños deltas alrededor de un umbral ya cruzado → 0 emisiones nuevas.

## Test Evidence

**Story Type**: Logic (+ un caso Integration para AC-T19)
**Required evidence**: `tests/unit/tiempo/tiempo_cruces_test.gd` — debe existir y pasar (BLOCKING). Caso AC-T19 en `tests/integration/tiempo/tiempo_senales_test.gd`.

**Status**: not yet created

## Dependencies

- Depends on: **Story 003** (el cálculo de turno/`es_de_noche` cuyo **cambio** se detecta aquí). *(Usa el EventBus ya existente — epic EventBus Complete.)*
- Unlocks: **H5** (que añade `nuevo_dia`/`nuevo_mes` y el orden completo del multi-cruce), y a todos los oyentes de turno/día-noche (Demanda, Feedback, UI).

## Notas de headless (gotcha del proyecto)

Preload por ruta literal de `tiempo.gd`. Para contar emisiones sin depender del árbol, conectar un `Callable` local a `EventBus.cambio_de_turno`/`cambio_dia_noche` en el `before`/`setup` del test y desconectar en el `teardown` (aislamiento entre tests). **Nunca** leer la hora real del sistema para decidir un cruce.
