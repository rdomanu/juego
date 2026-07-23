# Story 005: Medianoche → calendario semanal + `nuevo_dia`/`nuevo_mes` por dispatcher

> **Epic**: Sistema de Tiempo
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/time-system.md` (Core Rules 7 — fin de jornada / calendario semanal; States/Transitions B — la fecha avanza al cruzar 00:00; Edge Cases — medianoche dispara `nuevo_dia` pero NO `cambio_de_turno`; multi-cruce en orden)
**Requirement**: `TR-time-004` (orden determinista al cruzar varios umbrales: turno → día/noche → `nuevo_dia`) · `TR-time-006` (emite `nuevo_dia`, `nuevo_mes`)

**ADR Governing Implementation**: ADR-0001: Bus de eventos, tick y orden determinista *(primario)*
**ADR Decision Summary**: `nuevo_dia` y `nuevo_mes` son **eventos ordenados** → se disparan con **`EventBus.disparar_ordenado(&"nuevo_dia")`** / `&"nuevo_mes"`, que invoca los callables registrados en orden de prioridad ascendente (para `nuevo_dia`: Paciencia 10 → Economía 20 → Personal 30 → Demanda 40) y **luego** emite la señal de notificación homónima para oyentes no críticos. El Tiempo es el **origen**: solo dispara; no conoce los sistemas.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `EventBus.disparar_ordenado(&"nuevo_dia")` y `disparar_ordenado(&"nuevo_mes")` ya existen en `event_bus.gd` (Story 002 del epic EventBus, Complete). Esta story los **llama**; no modifica el bus.

**Control Manifest Rules (Foundation)**:
- Required: al cruzar **00:00** avanzar la **semana**; S4 → mes+1 y S→1 (`jornadas_por_mes=4`); Dic·S4 → año+1 (48 jornadas = 1 año); disparar `nuevo_dia`/`nuevo_mes` **SIEMPRE** vía `EventBus.disparar_ordenado(...)`; orden del multi-cruce **turno → día/noche → nuevo_dia**.
- Forbidden: **nunca** emitir `nuevo_dia`/`nuevo_mes` con `.emit()` directo saltándose el dispatcher (rompería el orden crítico Paciencia→Economía→Personal→Demanda); medianoche **NO** implica `cambio_de_turno` (sigue Noche).
- Cross-cutting: determinismo; orden crítico; el bus solo retransmite.

---

## Acceptance Criteria

*De GDD Core Rules 7 + Edge Cases. Valores transcritos exactos de los AC-T del GDD:*

- [x] **AC-T20**: GIVEN `1439.8` WHEN pasa a `0.3` (cruza 00:00) THEN se emite **`nuevo_dia` una vez** y avanza **1 semana** (Semana +1; al pasar de Semana 4 → mes +1, regla 7).
- [x] **AC-T21**: GIVEN cruce de 00:00 en turno Noche THEN se emite **`nuevo_dia` pero NO `cambio_de_turno`** (sigue NOCHE).
- [x] **AC-T22**: GIVEN la **Semana 4** de un mes a 23:59 WHEN cruza medianoche THEN se emiten **`nuevo_dia` y `nuevo_mes`**, el mes **+1** y la Semana vuelve a **1**.
- [x] **AC-T22b**: GIVEN el **mes 12 (Diciembre) · Semana 4** a 23:59 WHEN cruza medianoche THEN se emiten `nuevo_dia` y `nuevo_mes`, avanza el **año +1**, el mes vuelve a **1** y la Semana a **1** (48 jornadas = 1 año).
- [x] **AC-T23** *(orden completo del multi-cruce)*: GIVEN `1379.0` (22:59, Tarde) WHEN un `delta` grande lleva el acumulador a `1441.0` (cruza 23:00 y 00:00) THEN se disparan **en orden** `cambio_de_turno(NOCHE)` → `cambio_dia_noche(noche)` → **`nuevo_dia`**, una vez cada uno.

---

## Implementation Notes

- **Detección de cruce de medianoche**: al envolver el acumulador (H1: `minutos_juego` pasa de ~1440 a ~0), detectar el cruce de 00:00 comparando el valor anterior con el nuevo (mismo principio que H4: el acumulador **decreció** = envolvió). Registrar el cruce y avanzar el calendario.
- **Avance del calendario** (GDD Core Rules 7, `jornadas_por_mes = 4` — leído del config, H2):
  ```
  al cruzar 00:00:
      semana += 1
      si semana > jornadas_por_mes (4):        # completó la 4ª semana
          semana = 1
          mes += 1
          hay_nuevo_mes = true
          si mes > 12:                          # completó Diciembre
              mes = 1
              anio += 1
  disparar_ordenado(&"nuevo_dia")               # SIEMPRE
  si hay_nuevo_mes: disparar_ordenado(&"nuevo_mes")
  ```
  48 jornadas = 1 año (4 semanas × 12 meses). Getters: `mes`, `semana`, `anio` (para UI/HUD y sistemas que gestionan ciclos).
- **Orden del multi-cruce (AC-T23, completa H4)**: en el mismo frame, emitir **en este orden**: `cambio_de_turno` (H4) → `cambio_dia_noche` (H4) → `disparar_ordenado(&"nuevo_dia")` (esta story). El GDD lo exige: Demanda y Economía no pueden perderse un cambio de día. En la práctica: el `_procesar_cruces()` de H4 corre primero (turno, día/noche) y **luego** esta story procesa la medianoche.
- **Medianoche NO es cambio de turno (AC-T21)**: 00:00 cae dentro del turno Noche (23:00–07:00). El turno derivado **no cambia** al cruzar 00:00 (sigue NOCHE) → H4 no emite `cambio_de_turno`. Solo se dispara `nuevo_dia`. La fecha y el turno son independientes.
- **`nuevo_mes`**: solo cuando `semana` pasa de 4 a 1. Se dispara **después** de `nuevo_dia` (misma jornada). Su orden crítico interno (Economía 10 → Paciencia 20 → Demanda 30) lo gestiona el dispatcher del bus; el Tiempo solo lo **dispara**.
- **SIEMPRE por dispatcher**: nunca `EventBus.nuevo_dia.emit()` directo desde Tiempo — eso saltaría el orden crítico (los handlers ordenados no correrían). Usar `disparar_ordenado`, que YA emite la señal de notificación homónima al final para los oyentes no críticos.

## Out of Scope

- El **registro** de prioridades de los handlers (Paciencia 10, Economía 20, etc.) lo hace **cada sistema** en su propio epic (Core), no el Tiempo. El Tiempo solo **dispara** el evento.
- La sincronización del calendario al **cargar** (fijar semana/mes/año sin re-disparar) es **H8**.
- El "día de la semana L–D" (difuminado por diseño — GDD Core Rules 7).

## QA Test Cases

*Logic — espiando el EventBus (señales `nuevo_dia`/`nuevo_mes` y/o registrando un callable ordenado). Determinista. `tests/unit/tiempo/`.*

- **`test_medianoche_dispara_nuevo_dia_y_semana_mas_1`** (AC-T20): de 1439.8 a 0.3 → 1× `nuevo_dia`, `semana` +1.
- **`test_medianoche_no_dispara_cambio_de_turno`** (AC-T21): cruzar 00:00 en Noche → `nuevo_dia` sí, `cambio_de_turno` **no**.
- **`test_semana4_cruza_a_mes_mas_1_y_semana_1`** (AC-T22): semana 4 + cruce → `nuevo_dia` y `nuevo_mes`, `mes`+1, `semana==1`.
- **`test_diciembre_semana4_avanza_anio`** (AC-T22b): mes 12, semana 4 + cruce → `anio`+1, `mes==1`, `semana==1`.
- **`test_multicruce_orden_turno_dianoche_nuevodia`** (AC-T23): de 1379.0 a 1441.0 → orden observado `cambio_de_turno(NOCHE)`, `cambio_dia_noche(true)`, `nuevo_dia`, uno cada uno. *(Registrar el orden real de invocación, p. ej. añadiendo a una lista en cada callback.)*

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tiempo/tiempo_calendario_test.gd` — debe existir y pasar (BLOCKING).

**Status**: [x] Creado y PASA (tiempo_calendario_test.gd 5/5; suite 90/90, 2026-07-23)

## Dependencies

- Depends on: **Story 004** (la detección de cruces de turno/día-noche, cuyo orden esta story completa con `nuevo_dia`). *(Usa el dispatcher `disparar_ordenado` ya existente — epic EventBus Complete.)*
- Unlocks: **H8** (que serializa semana/mes/año) y a Economía/Demanda (ciclo mensual, perfil estacional).

## Notas de headless (gotcha del proyecto)

Preload por ruta literal de `tiempo.gd`. Para verificar el ORDEN del multi-cruce, registrar callbacks que **añadan un token a una lista compartida** (p. ej. `["turno","dianoche","nuevo_dia"]`) y assertar la secuencia — más robusto que medir tiempos. **Nunca** hora real del sistema.

## Cierre (2026-07-23)

Código iniciado por subagente Opus (interrumpido por caída de infraestructura) y REMATADO en el hilo
principal (tests del orquestador). Suite 90/90, exit 0. `nuevo_dia`/`nuevo_mes` verificados vía la señal
de notificación que emite `disparar_ordenado` (patrón del ADR-0001); orden completo del multi-cruce
turno→día/noche→nuevo_dia cubierto por test con lista de tokens. El calendario avanza aunque no haya bus
inyectado (fallback seguro documentado).
