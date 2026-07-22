# Epic: EventBus (bus de eventos)

> **Layer**: Foundation
> **GDD**: — (módulo de infraestructura sin GDD; derivado de `docs/architecture/architecture.md` §3.2 y ADR-0001)
> **Architecture Module**: ▸EventBus
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories event-bus`

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

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- El contrato del EventBus (señales publicadas + dispatcher de orden) está documentado y estable
- All Logic and Integration stories have passing test files in `tests/` (incl. test del **orden
  determinista** de handlers en `nuevo_dia`/`nuevo_mes`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/` (N/A esperado
  para este módulo puramente técnico)

## Next Step

Run `/create-stories event-bus` to break this epic into implementable stories.
