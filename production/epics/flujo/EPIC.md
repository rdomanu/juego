# Epic: Flujo de Personas y Colas

> **Layer**: Core
> **GDD**: design/gdd/flow-queues.md
> **Architecture Module**: Flujo #4
> **Status**: In Progress (stories creadas 2026-07-24 — Sprint 2, C2-4)
> **Stories**: 8 (ver tabla)

## Overview

El sistema de Flujo de Personas y Colas es el **motor** del juego: gobierna el recorrido de cada persona
que entra en la comisaría (ciudadanos a por el DNI, denunciantes, y más adelante detenidos) a través de un
ciclo común — **entrada → coger turno → sala de espera → puesto libre → atención → salida**. Lleva las
colas de cada servicio (FIFO + prioridad ODAC), decide **a quién le toca y en qué puesto** con
emparejamiento automático y determinista (desempate por menor id), y avanza la atención con el reloj
durante la **duración efectiva** del trámite (base de Datos, modulada por el agente de Personal). Cada
Persona es una máquina de estados (7 estados); una vez en "Llamada"/"En atención" ya no abandona. Emite
`tramite_completado` y `abandono` al bus. Es el **bottleneck** del que casi todo lo visible depende, y el
sitio donde viven **muchos NPCs navegando a la vez**.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Rejilla + navegación 2D | Caminar con `NavigationServer2D`/`NavigationAgent2D` (mesh; avoidance OFF; gotcha: fijar target tras el 1er physics frame); movimiento **cosmético** separado de la lógica determinista (FL5) | MEDIUM (post-cutoff) |
| ADR-0001: Bus de eventos + tick + orden | Ciclo de atención avanza con `delta`; emite `tramite_completado`/`abandono`; simulación en `_physics_process` | LOW |
| ADR-0002: Guardado / serialización | Serializa colas/puestos/personas (estado, turno, posición, tiempo restante) | MEDIUM |

**Engine Risk (mayor entre los ADR gobernantes): MEDIUM-ALTO — el módulo más delicado del MVP.** Junta
navegación 2D (API dedicada de 4.5/4.6, post-cutoff) con el **riesgo de rendimiento nº1** (docenas de NPCs
a 60 FPS). **MITIGADO:** el spike **QQ-02** del vertical slice midió **150 NPCs → ~145 FPS** (simulación),
así que el plan B `AStarGrid2D` **no es necesario**. Verificado en `modules/navigation.md`.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-flow-001 | Instancia **Persona** con máquina de estados (7 estados) | ADR-0001 ✅ (SIM) |
| TR-flow-002 | Colas por servicio (FIFO + prioridad ODAC); selección/desempate determinista | ADR-0001 ✅ |
| TR-flow-003 | Emparejamiento automático puesto→persona; ciclo de atención avanza con `delta` | ADR-0001 ✅ |
| TR-flow-004 | Emite `tramite_completado` y `abandono` | ADR-0001 ✅ |
| TR-flow-005 | **Muchos NPCs navegando a la vez** → `NavigationAgent2D` + spike de rendimiento | ADR-0004 ✅ (spike QQ-02 pasado) |
| TR-flow-006 | Serializar colas/puestos/personas (estado, turno, posición, tiempo restante) | ADR-0002 ✅ |

**Untraced Requirements**: None (6/6 cubiertos).

**Depende de (Foundation + Core):** Tiempo (delta/pausa), Datos (duración base), EventBus, SaveManager;
recibe Personas de **Demanda**, el agente de **Personal** (gate FL4) y aforo/posición de **Construcción**.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/flow-queues.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (incl. determinismo del
  emparejamiento y de las colas; **la navegación cosmética queda fuera del test determinista** por diseño FL5)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- **Rendimiento**: confirmado ≥60 FPS con el volumen objetivo de NPCs (el spike QQ-02 ya da el margen)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [La Persona en el flujo: 7 estados + turnos](story-001-persona-estados-turnos.md) | Logic | Ready | ADR-0001, ADR-0003 |
| 002 | [Las colas: FIFO + prioridad ODAC + compatibilidad (F7)](story-002-colas-seleccion-f7.md) | Logic | Ready | ADR-0001, ADR-0003 |
| 003 | [Los puestos: estados, gate FL4 y emparejamiento sin dobles](story-003-puestos-gate-emparejamiento.md) | Integration | Ready | ADR-0001 |
| 004 | [La atención y el cobro: F1 + tramite_completado (saldo SUBE)](story-004-atencion-cobro.md) | Integration | Ready | ADR-0001 |
| 005 | [La sala respira: aforo + cola exterior (F6) y F2-F5](story-005-aforo-formulas-colas.md) | Logic | Ready | ADR-0001 |
| 006 | [Compromiso de servicio y gestión en caliente (+AC-CO13)](story-006-compromiso-gestion-caliente.md) | Integration | Ready | ADR-0001 |
| 007 | [Persistencia y determinismo (AC-FL27)](story-007-persistencia-determinismo.md) | Integration | Ready | ADR-0002, ADR-0001 |
| 008 | [🎉 La comisaría VIVE: NPCs navegando + demo (HITO VISIBLE)](story-008-comisaria-viva-npcs.md) | Visual/Feel | Ready | ADR-0004, ADR-0001 |

Cobertura: **27/27 AC del GDD + AC-CO13** (el diferido de Construcción se cierra en la 006). Orden
secuencial estricto 001→008; la nav (post-cutoff, riesgo del epic) queda AISLADA en la 008 con la
lógica ya determinista y testeada (FL5). **Interfaces provisionales documentadas en las stories**
(aprobar al implementar): paciencia = stub + `forzar_abandono` (Paciencia #10) · cierre Doc por
cruce de 870 en Flujo (→ Documentación #8) · `minutos_operativos` como entrada de F2 (→ Horarios) ·
puestos nacen abiertos (→ horarios de Doc #8) · AC-CO13 vía callable `puede_demoler` cableado por
Main.

## Next Step

`/story-readiness production/epics/flujo/story-001-persona-estados-turnos.md` → implementar en
orden. QA plan: `production/qa/qa-plan-sprint-2.md` (gates y casos ya definidos).
