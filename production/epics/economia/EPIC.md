# Epic: Economía / Presupuesto

> **Layer**: Core
> **GDD**: design/gdd/economy-budget.md
> **Architecture Module**: Economía #3
> **Status**: Ready
> **Stories**: 7 created — see table below

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Núcleo: nodo + config + saldo + gates](story-001-nucleo-saldo-gates.md) | Logic | Ready | ADR-0001/0002 |
| 002 | [Ingresos: retorno DGP + trámite completado](story-002-ingresos-retorno-dgp.md) | Logic | Ready | ADR-0001 |
| 003 | [Cierre diario: recargo→gastos→reset (prio 20)](story-003-cierre-diario.md) | Logic | Ready | ADR-0001 |
| 004 | [Préstamos del Comisario](story-004-prestamos-comisario.md) | Logic | Ready | ADR-0001 |
| 005 | [Estados + insolvencia (gracia, game over)](story-005-estados-insolvencia.md) | Logic | Ready | ADR-0001 |
| 006 | [Balance mensual + save/load](story-006-balance-mensual-save.md) | Logic | Ready | ADR-0001/0002 |
| 007 | [💶 Saldo en el HUD (visible + sign-off)](story-007-saldo-en-hud.md) | Visual/UI | Ready | ADR-0001 |

**Orden**: 001 → … → 007 (la 007 abre la ventana al usuario con el saldo vivo). Decisiones fijadas
(2026-07-23): Economía = **nodo del mundo** (no autoload, arquitectura §3.4); config `ConfigEconomia`
`.tres` propio; enmienda del bus `saldo_cambiado: int → float` + señales nuevas (`prestamo_pedido`,
`entro_en_deuda`, `salio_de_deuda`, `insolvencia`, `gracia_iniciada`, `game_over`); interfaces
provisionales con sistemas futuros (sat fija 50, plantilla inyectable, peonadas por API, modal = señales).

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

Stories creadas (7, aprobadas por el usuario 2026-07-23 — tarea C1-1 del Sprint 1 ✅). Siguiente:
`/qa-plan sprint` (decidido) y `/dev-story` de la 001 (tarea C1-2).
