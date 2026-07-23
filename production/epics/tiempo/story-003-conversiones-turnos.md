# Story 003: Conversiones hora↔minutos + turno + `es_de_noche`

> **Epic**: Sistema de Tiempo
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-22

## Context

**GDD**: `design/gdd/time-system.md` (Core Rules 4 — turnos; Core Rules 5 — ciclo día/noche; F3 — auxiliares hora↔minutos y turno)
**Requirement**: `TR-time-006` (parte de derivación: turno y `es_de_noche` son datos **derivados** de la hora) · `TR-time-007` (fuente única: el turno se calcula, no se almacena en paralelo)

**ADR Governing Implementation**: ADR-0001 *(primario)*
**ADR Decision Summary**: el turno y `es_de_noche` son **estados derivados del reloj**, no almacenados. Se calculan de `minutos_juego` con funciones puras. El enum de turno debe ser coherente con `EventBus.cambio_de_turno(turno: int)` (0=mañana, 1=tarde, 2=noche).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: pura aritmética entera + `String` formateo. `"%02d:%02d" % [h, m]` para HH:MM (evita `24:00`: la hora se deriva de `minutos_del_dia` que ya está en `[0,1440)`).

**Control Manifest Rules (Foundation)**:
- Required: turno y `es_de_noche` son funciones **derivadas** (se calculan de la hora, NUNCA se almacenan como estado paralelo); enum de turno `{MANANA=0, TARDE=1, NOCHE=2}` coherente con `cambio_de_turno(turno: int)`.
- Forbidden: **nunca** almacenar `turno`/`es_de_noche` como variables mutables que puedan desincronizarse del reloj; nunca formatear `24:00` (usar `minutos_del_dia` en `[0,1440)`).
- Cross-cutting: fuente única de tiempo; determinismo; tipado estático.

---

## Acceptance Criteria

*De GDD F3 (conversiones y turno) + Core Rules 5. Valores transcritos exactos de los AC-T del GDD:*

**Conversión hora ↔ minutos (F3):**
- [x] **AC-T06**: GIVEN `minutos_del_dia=567` WHEN a HH:MM THEN **`"09:27"`**.
- [x] **AC-T07**: GIVEN hora=14, min=30 WHEN a minutos del día THEN **`870`**.
- [x] **AC-T08**: GIVEN `minutos_del_dia=0` WHEN a HH:MM THEN **`"00:00"`** (nunca `"24:00"`).

**Cálculo de turno (F3):**
- [x] **AC-T09**: GIVEN `420` (07:00) WHEN calcular turno THEN **MAÑANA**.
- [x] **AC-T10**: GIVEN `900` (15:00) WHEN calcular turno THEN **TARDE**.
- [x] **AC-T11**: GIVEN `1395` (23:15) WHEN calcular turno THEN **NOCHE**.
- [x] **AC-T12**: GIVEN `200` (03:20) WHEN calcular turno THEN **NOCHE** (cubre `[1380,1440) ∪ [0,420)`).

**Estado `es_de_noche`:**
- [x] **AC-T13**: GIVEN `1381` (23:01) THEN `es_de_noche=**true**`.
- [x] **AC-T14**: GIVEN `419` (06:59) THEN `es_de_noche=**true**`.
- [x] **AC-T15**: GIVEN `420` (07:00) THEN `es_de_noche=**false**`.

---

## Implementation Notes

- **Enum de turno**: `enum Turno { MANANA = 0, TARDE = 1, NOCHE = 2 }` — el valor entero es el que viaja en `EventBus.cambio_de_turno(turno: int)` (coherencia con el bus, H4).
- **Conversiones (F3, valores exactos del GDD)**:
  ```
  hora   = floor(minutos_del_dia / 60)
  minuto = minutos_del_dia mod 60
  hhmm(min_dia) -> "%02d:%02d" % [hora, minuto]     # 567 -> "09:27"; 0 -> "00:00"
  a_minutos(hora, minuto) -> hora * 60 + minuto     # (14,30) -> 870
  ```
  Trabajar con `int(minutos_del_dia)` (piso) para derivar HH:MM; `minutos_juego` es `float`, pero la hora mostrada usa el minuto entero.
- **Turno (rangos del GDD F3, con origen 00:00)** — usa los **límites leídos del config** (H2), no constantes:
  ```
  turno = MANANA  si inicio_manana ≤ min_dia < inicio_tarde     # default [420, 900)
          TARDE   si inicio_tarde  ≤ min_dia < inicio_noche     # default [900, 1380)
          NOCHE   en cualquier otro caso                        # resto: [1380,1440) ∪ [0,420)
  ```
  NOCHE es el **caso restante** porque cruza medianoche. `1395` → NOCHE; `200` → NOCHE.
- **`es_de_noche`**: derivado del turno → `es_de_noche = (turno == NOCHE)` (MVP: noche coincide con turno Noche, GDD Core Rules 5). `1381`→true, `419`→true, `420`→false.
- **Funciones puras**: todas reciben `min_dia` (o leen `minutos_juego`) y **no** mutan estado. Son consultables por cualquier sistema (fuente única) sin efectos secundarios.
- **Uso de los límites del config**: como H2 ya cargó `inicio_manana/tarde/noche`, aquí el cálculo del turno los usa (data-driven). Si esta story se implementa con H2 ya cerrada, leer del config; si se solapa, aceptar los defaults 420/900/1380 e integrarlos con H2 al mergear.

## Out of Scope

- **H4**: **emitir** `cambio_de_turno`/`cambio_dia_noche` al cruzar el umbral. Aquí solo se **calcula** el turno actual; no hay detección de cruce ni señales.
- **H5**: calendario/medianoche.
- El "día de la semana L–D" (difuminado por diseño — cada jornada ES una semana, GDD Core Rules 7).

## QA Test Cases

*Logic — funciones puras, deterministas. `tests/unit/tiempo/`.*

- **Conversiones** (AC-T06/07/08): `hhmm(567)=="09:27"`; `a_minutos(14,30)==870`; `hhmm(0)=="00:00"` (y explícitamente **no** `"24:00"`).
- **Turno** (AC-T09..T12): `turno(420)==MANANA`; `turno(900)==TARDE`; `turno(1395)==NOCHE`; `turno(200)==NOCHE`. *(Añadir bordes: `899`→MANANA, `1379`→TARDE, `1380`→NOCHE.)*
- **`es_de_noche`** (AC-T13/14/15): `es_de_noche(1381)==true`; `es_de_noche(419)==true`; `es_de_noche(420)==false`.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tiempo/tiempo_turnos_test.gd` — debe existir y pasar (BLOCKING). *(Nombre
actualizado al archivo real creado; el planificado era `tiempo_conversiones_test.gd` — mismo contenido/AC.)*

**Status**: [x] Creado y PASA (tiempo_turnos_test.gd 14/14; suite 79/79, 2026-07-22)

## Dependencies

- Depends on: **Story 001** (el acumulador `minutos_juego` del que se derivan las conversiones). *(Usa los límites de turno de H2 si ya está cerrada.)*
- Unlocks: H4 (detección de cruce usa el turno calculado aquí y el enum), y a todos los sistemas que consultan hora/turno/`es_de_noche`.

## Notas de headless (gotcha del proyecto)

Preload por ruta literal de `tiempo.gd` en el test. Las funciones son puras → el test las llama directamente con valores de `min_dia`, sin necesidad de correr `_physics_process`.

## Cierre (2026-07-22)

Implementada vía subagente godot-gdscript-specialist (Opus) + verificación independiente del hilo
principal (suite 79/79, exit 0). Commit 8f47e31.
