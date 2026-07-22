# Epic: Economía / Presupuesto

> **Layer**: Core
> **GDD**: design/gdd/economy-budget.md
> **Architecture Module**: Economía #3
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories economia`

## Overview

El sistema de Economía / Presupuesto es la **capa de dinero** del juego: lleva la caja de la comisaría y
gobierna cada ingreso y cada gasto. Lee de Datos las cifras ya definidas (tarifas, costes de construcción,
salarios, peonada, parámetros de retorno DGP) y las convierte en un saldo que sube y baja con el tiempo:
**cobra al instante** al oír `tramite_completado`, **paga los salarios** al `nuevo_dia` (en orden
determinista: recargo → gastos → reset), descuenta obras y horas extra, y **cierra cuentas por jornada**.
Deriva un estado financiero (con rescate/pausa y ventana de gracia si el saldo se hunde) y expone los
**gates** "¿puedo construir/contratar?" a Construcción y Personal (que solo gastan si `puede_pagar()`).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Bus de eventos + tick + orden | Ingreso instantáneo al oír `tramite_completado`; cobros al `nuevo_dia` en orden determinista vía dispatcher | LOW |
| ADR-0002: Guardado / serialización | Serializa saldo, préstamos y estado financiero (patrón `save()`/`load_state()`) | MEDIUM |

**Engine Risk (mayor entre los ADR gobernantes): LOW** — Economía es lógica pura de simulación; no usa
ninguna API de motor post-cutoff. El riesgo del guardado lo absorbe SaveManager.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-economy-001 | `saldo_eur` mutable; ingreso instantáneo al oír `tramite_completado` | ADR-0001 ✅ |
| TR-economy-002 | Cobros al `nuevo_dia` en **orden determinista** (recargo→gastos→reset) | ADR-0001 ✅ |
| TR-economy-003 | Estado financiero derivado + rescate con pausa/modal/ventana de gracia (timer de juego) | ADR-0001 ✅ |
| TR-economy-004 | Gates "¿puedo construir/contratar?" expuestos a Construcción/Personal | ADR-0001 ✅ (API) |

**Untraced Requirements**: None (4/4 cubiertos).

**Depende de (Foundation):** Datos (catálogo de tarifas/costes), Tiempo (`nuevo_dia`/delta), EventBus
(`tramite_completado`), SaveManager (persistencia).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/economy-budget.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (incl. determinismo del cierre de
  cuentas y orden de cobros al `nuevo_dia`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories economia` to break this epic into implementable stories.
