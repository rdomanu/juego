# Epic: Generación de Demanda

> **Layer**: Core
> **GDD**: design/gdd/demand-generation.md
> **Architecture Module**: Demanda #5
> **Status**: Ready
> **Stories**: 7 (creadas 2026-07-23 — ver tabla)

## Overview

El sistema de Generación de Demanda es el **grifo** del juego: decide cuánta gente entra en la comisaría,
cuándo y a qué viene. Crea cada Persona (ciudadanos a por el DNI/Pasaporte/TIE y denunciantes de ODAC) a
partir de la **población** del escenario (Pozuelo, 90.000 hab.), la **hora/turno** del reloj y el **día de
la semana**, y la entrega a **Flujo** por el bus (`persona_generada`). No mueve a nadie ni lleva colas (eso
es Flujo): solo **produce la afluencia**. El modelo es determinista y sembrado: un acumulador alimentado
por `delta` marca el ritmo de llegadas, y una **mezcla ponderada** (con normalización defensiva) vía
RNGService decide el tipo de cada visita — de modo que la misma semilla produce la misma secuencia de
llegadas. Expone además una señal derivada BAJA/MEDIA/ALTA que la UI y Documentación consultan.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Guardado / serialización + RNG | Toda la aleatoriedad (mezcla ponderada, ritmo) pasa por el RNGService sembrado → determinismo | LOW |
| ADR-0001: Bus de eventos + tick + orden | Emite `persona_generada` a Flujo; acumulador alimentado por `delta` en `_physics_process` | LOW |

**Engine Risk (mayor entre los ADR gobernantes): LOW** — lógica pura de simulación + RNG; sin API de motor
post-cutoff.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-demand-001 | Genera Personas → `persona_generada` a Flujo; acumulador alimentado por `delta` | ADR-0001 ✅ |
| TR-demand-002 | **RNG sembrado** determinista (mezcla ponderada, normalización defensiva) | ADR-0002 ✅ (RNGService) |
| TR-demand-003 | Señal derivada BAJA/MEDIA/ALTA expuesta a UI/Documentación | ADR-0001 ✅ (API) |

**Untraced Requirements**: None (3/3 cubiertos).

**Depende de (Foundation):** Tiempo (hora/turno/delta), Datos (catálogo + `tasa_base`/perfiles), EventBus,
RNGService; respeta la ventana horaria de **Documentación**/ODAC.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/demand-generation.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (incl. **determinismo**: misma
  semilla → misma secuencia de llegadas y misma mezcla de tipos; validación del invariante R5)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Núcleo, config y volumen base (F1+F2)](story-001-nucleo-config-volumen.md) | Logic | Ready | ADR-0003, ADR-0001 |
| 002 | [Generador determinista por tick (acumulador + mezcla)](story-002-generador-determinista.md) | Logic | Ready | ADR-0002, ADR-0001 |
| 003 | [En el tick del reloj — ventana, pausa y entrega al bus](story-003-tick-ventana-bus.md) | Integration | Ready | ADR-0001, ADR-0002 |
| 004 | [Nivel de demanda BAJA/MEDIA/ALTA](story-004-nivel-demanda.md) | Logic | Ready | ADR-0001 |
| 005 | [Estacionalidad anual y eventos de demanda](story-005-estacionalidad-eventos.md) | Logic | Ready | ADR-0001, ADR-0002 |
| 006 | [Persistencia — el grifo sobrevive al guardado](story-006-persistencia.md) | Integration | Ready | ADR-0002 |
| 007 | [Demanda en el mundo — la comisaría respira (HITO VISIBLE)](story-007-demanda-en-el-mundo.md) | UI | Ready | ADR-0001 |

Cobertura: **19/19 AC del GDD** + AC-DM20 nuevo (proporcionalidad de `poblacion`, pedido del usuario
2026-07-23). Orden estrictamente secuencial (cada una depende de la anterior). Enmienda del bus prevista
en la 004 (`nivel_demanda_cambiado`). Erratas del GDD anotadas en la 001 (tasa ODAC 0.4 vs 0.5; "≈10"
nocturno vs ≈5 derivado) — propagar al tocar el GDD.

## Next Step

Run `/story-readiness production/epics/demanda/story-001-nucleo-config-volumen.md` → `/dev-story` para empezar.
