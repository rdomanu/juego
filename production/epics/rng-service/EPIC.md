# Epic: RNGService (aleatoriedad determinista)

> **Layer**: Foundation
> **GDD**: — (módulo de infraestructura sin GDD; deriva del principio de **determinismo global** y ADR-0002)
> **Architecture Module**: ▸RNGService
> **Status**: Ready
> **Stories**: 3 created — see table below

## Overview

El RNGService es el **dado controlado** del juego: el servicio central de aleatoriedad **sembrada**. Toda
la aleatoriedad de juego pasa por aquí (nadie usa `randi()`/`randf()` globales), de modo que **la misma
semilla + la misma secuencia de llamadas produce siempre los mismos resultados** — la base del
determinismo que hace la simulación reproducible y **testeable**. Expone envoltorios sembrados
(`randi()`, `randf()`, elección ponderada…) que consumen Demanda (mezcla de trámites), Personal (mercado y
ausencias) y Paciencia (probabilidad de reclamación). Su estado (posición del generador + semilla) se
**serializa** junto con la partida, para que al cargar el azar continúe exactamente donde estaba. Es
infraestructura pura: no es una mecánica, es la garantía técnica de que "el juego se comporta igual dos
veces".

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Guardado / serialización + RNG | Servicio de RNG sembrado central; serializa estado + semilla para determinismo al cargar | LOW |

**Engine Risk: LOW** — `RandomNumberGenerator` (estado + `seed`) es API estable.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-save-002 | Serializar estado del **RNG** + semilla (determinismo al cargar) | ADR-0002 ✅ |

**Habilita (requisitos de otros epics que dependen de este servicio):** TR-demand-002 (mezcla ponderada
sembrada), TR-staff-001/003 (mercado y ausencias con RNG), TR-patience-004 (`reclamacion` por probabilidad),
además del principio transversal de **determinismo global**.

**Untraced Requirements**: None (1/1 propio cubierto).

**Nota de dependencia:** junto con EventBus, es de los primeros módulos a construir en Foundation — Demanda,
Personal y Paciencia (Core/Feature) no pueden ser deterministas sin él.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [RNGService autoload + envoltorios sembrados](story-001-autoload-sembrado.md) | Logic | Implementada · test 4/4 ✅ (pend. /story-done) | ADR-0002 |
| 002 | [Elección ponderada (`elegir_ponderado`)](story-002-eleccion-ponderada.md) | Logic | Implementada · test 5/5 ✅ (pend. /story-done) | ADR-0002 |
| 003 | [Serialización del RNG (`save`/`load_state`)](story-003-serializacion-rng.md) | Integration | Implementada · test 4/4 ✅ (pend. /story-done) | ADR-0002 |

**Estado:** epic COMPLETO en código+test (2026-07-22). 13 tests del RNGService (4+5+4) verdes; suite total del
proyecto 23/23. Pendiente el cierre formal con `/story-done` de las 3.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- Se demuestra el **determinismo**: misma semilla + misma secuencia → misma salida; y el round-trip de
  guardado del estado del RNG continúa la secuencia sin repetir ni saltar
- All Logic and Integration stories have passing test files in `tests/` (test de determinismo — patrón ya
  sembrado en `tests/unit/example/example_sanity_test.gd`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/` (N/A esperado
  para este módulo puramente técnico)

## Next Step

Stories creadas (3). Ejecutar `/story-readiness production/epics/rng-service/story-001-autoload-sembrado.md`
y luego `/dev-story` para implementar (empezar por la 001).
