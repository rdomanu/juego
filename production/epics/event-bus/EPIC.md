# Epic: EventBus (bus de eventos)

> **Layer**: Foundation
> **GDD**: — (módulo de infraestructura sin GDD; derivado de `docs/architecture/architecture.md` §3.2 y ADR-0001)
> **Architecture Module**: ▸EventBus
> **Status**: Ready
> **Stories**: 2 created — see table below

## Overview

El EventBus es el **bus de eventos global** del juego: un autoload con señales que permite la comunicación
**desacoplada** entre sistemas — nadie llama a nadie por su nombre; los emisores publican eventos y los
interesados escuchan. Su única responsabilidad es **emitir y retransmitir** señales cross-system
(`persona_generada`, `tramite_completado`, `abandono`, `nuevo_dia`, `nuevo_mes`, `cambio_de_turno`,
`cambio_dia_noche`…); **nunca contiene lógica de juego**. Su pieza crítica es garantizar el **orden
determinista de los handlers** cuando varios sistemas escuchan el mismo evento (p. ej. al `nuevo_dia`:
Paciencia cierra la satisfacción → Economía cobra → Tiempo avanza la fecha), mediante un **dispatcher con
prioridad** en el que los sistemas se registran (el bus no conoce a los sistemas). Es infraestructura pura:
no tiene GDD porque no es una mecánica de juego, sino la tubería que el resto necesita.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Bus de eventos + tick + orden | Autoload + signals para comunicación cross-system; orden determinista de handlers vía dispatcher con registro por prioridad (el bus no conoce a los sistemas) | LOW |

**Engine Risk: LOW** — autoload + `signal.emit()`/`.connect(callable)` es API estable y verificada
(`modules/patterns.md`).

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-bus-001 | Bus de eventos global (autoload + signals) para comunicación cross-system desacoplada | ADR-0001 ✅ |
| TR-bus-002 | **Orden de handlers determinista** cuando varios sistemas escuchan el mismo evento (nuevo_dia/nuevo_mes) | ADR-0001 ✅ |

**Untraced Requirements**: None (2/2 cubiertos).

**Nota de dependencia:** este módulo es la base que **todos** los demás usan para comunicarse; su orden de
construcción es de los primeros de Foundation (junto con RNGService).

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [EventBus autoload + señales de aviso](story-001-autoload-senales-aviso.md) | Integration | Implementada · test 3/3 ✅ (pend. /story-done) | ADR-0001 |
| 002 | [Dispatcher de eventos ordenados por prioridad](story-002-dispatcher-orden-prioridad.md) | Logic | Implementada · test 5/5 ✅ (pend. /story-done) | ADR-0001 |

**Estado:** epic COMPLETO en código+test (2026-07-22). Suite EventBus 10/10 PASS (GdUnit4 headless).
Pendiente el cierre formal con `/story-done` de ambas.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- El contrato del EventBus (señales publicadas + dispatcher de orden) está documentado y estable
- All Logic and Integration stories have passing test files in `tests/` (incl. test del **orden
  determinista** de handlers en `nuevo_dia`/`nuevo_mes`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/` (N/A esperado
  para este módulo puramente técnico)

## Next Step

Stories creadas (2). Ejecutar `/story-readiness production/epics/event-bus/story-001-autoload-senales-aviso.md`
y luego `/dev-story` para implementar (empezar por la 001).
