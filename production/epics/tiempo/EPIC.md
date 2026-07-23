# Epic: Sistema de Tiempo

> **Layer**: Foundation
> **GDD**: design/gdd/time-system.md
> **Architecture Module**: Tiempo #1
> **Status**: In Progress (5/9)
> **Stories**: 9 created — see table below

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

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Reloj base: acumulador `minutos_juego` + clamp anti-salto](story-001-reloj-base.md) | Logic | **Complete** (2026-07-22) | ADR-0001 |
| 002 | [Escala configurable data-driven + clamp [3,12]](story-002-escala-configurable.md) | Logic | **Complete** (2026-07-22) | ADR-0001, ADR-0002 |
| 003 | [Conversiones hora↔minutos + turno + `es_de_noche`](story-003-conversiones-turnos.md) | Logic | **Complete** (2026-07-22) | ADR-0001 |
| 004 | [Cruce de umbrales → señales de turno y día/noche](story-004-cruce-umbrales-senales.md) | Logic | **Complete** (2026-07-23) | ADR-0001 |
| 005 | [Medianoche → calendario semanal + `nuevo_dia`/`nuevo_mes`](story-005-calendario-semanal.md) | Logic | **Complete** (2026-07-23) | ADR-0001 |
| 006 | [Máquina de velocidad Pausa/1×/2×/3× + `velocidad_cambiada`](story-006-maquina-velocidad.md) | Logic | Ready | ADR-0001 |
| 007 | [Integración `_physics_process`: tick + determinismo + presupuesto](story-007-integracion-physics.md) | Integration | Ready | ADR-0001 |
| 008 | [`save()`/`load_state()` + grupo Persist + "cargar sitúa"](story-008-serializacion-reloj.md) | Logic | Ready | ADR-0002, ADR-0001 |
| 009 | [(EXTRA) Esqueleto visible: `Main.tscn` + TileMapLayer + HUD reloj](story-009-esqueleto-visible.md) | Visual/UI | Ready | ADR-0001 |

**Orden**: 001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 (la 009 **abre la primera ventana al usuario**). El grafo de dependencias es lineal salvo ramas menores (003 puede solaparse con 002; 006 depende de 002; 007 requiere 004+006). Seguir el orden numérico es seguro.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/time-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Stories 001–005 Complete (suite 90/90; el reloj emite cruces y calendario por el bus). Siguientes:
**006** (máquina de velocidad + `velocidad_cambiada` al EventBus) → **007** (integración
`_physics_process`) → **008** (save/load) → **009** (esqueleto visible — abre la primera ventana al
usuario).
