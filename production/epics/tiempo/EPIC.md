# Epic: Sistema de Tiempo

> **Layer**: Foundation
> **GDD**: design/gdd/time-system.md
> **Architecture Module**: Tiempo #1
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories tiempo`

## Overview

El Sistema de Tiempo es el reloj maestro del juego: hace avanzar la jornada en **tiempo real con pausa y
velocidades** (Pausa/1×/2×/3×), la divide en turnos (mañana/tarde/noche) y marca el ciclo día/noche.
Acumula tiempo real (`delta`), no frames, de modo que el resultado es idéntico a cualquier FPS, y detecta
el **cruce** de umbrales (no igualdad) para emitir cada evento temporal una sola vez y en orden
determinista. Es la fuente **única** de tiempo del proyecto: todos los demás sistemas (Flujo, Demanda,
Economía, Paciencia, Documentación) leen su hora en lugar de mantener un reloj propio. Su estado (reloj +
fecha) se serializa, y al cargar la partida arranca en Pausa sin disparar eventos retroactivos.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Bus de eventos + tick + orden | Simulación en `_physics_process` de paso fijo; detección de cruce de umbral; orden determinista de eventos vía dispatcher con prioridad | LOW |
| ADR-0002: Guardado / serialización + RNG | Serializar reloj/fecha en el save JSON; al cargar, Pausa sin eventos retroactivos | MEDIUM |

**Engine Risk (mayor entre los ADR gobernantes): MEDIUM** — el modelo de reloj (`_process`/`delta`) es
estable y conocido; el riesgo medio proviene solo de la serialización (API de ficheros 4.4, cubierta por
SaveManager).

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-time-001 | Reloj acumula tiempo real (`delta`), no frames → mismo resultado a cualquier FPS | ADR-0001 ✅ |
| TR-time-002 | Velocidades {Pausa,1×,2×,3×}; Pausa congela simulación pero permite gestión | ADR-0001 ✅ |
| TR-time-003 | Detección de **cruce** de umbral (no `==`) → cada evento se emite 1 vez | ADR-0001 ✅ |
| TR-time-004 | Orden determinista al cruzar varios umbrales (turno→día/noche→nuevo_dia) | ADR-0001 ✅ |
| TR-time-005 | Clamp de `delta` por frame (anti-salto tras alt-tab/lag) | ADR-0001 ✅ |
| TR-time-006 | Emite señales globales (cambio_de_turno, cambio_dia_noche, nuevo_dia, nuevo_mes…) | ADR-0001 ✅ |
| TR-time-007 | Fuente **única** de tiempo (nadie más mantiene reloj) | ADR-0001 ✅ |
| TR-time-008 | Serializar reloj/fecha; al cargar arranca en Pausa, sin eventos retroactivos | ADR-0002 ✅ |
| TR-time-009 | Update < 0,1 ms (AC-T33) | Principio PERF ✅ |

**Untraced Requirements**: None (9/9 cubiertos).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/time-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories tiempo` to break this epic into implementable stories.
