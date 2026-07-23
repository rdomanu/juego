# Epic: Personal / Agentes

> **Layer**: Core
> **GDD**: design/gdd/staff-agents.md
> **Architecture Module**: Personal #6
> **Status**: Ready
> **Stories**: 7 (creadas 2026-07-24 — ver tabla; implementación prevista en Sprint 2)

## Overview

El sistema de Personal / Agentes gobierna la **plantilla** de la comisaría: a quién contratas, cómo lo
asignas y cómo gestionas al equipo que atiende al público. Cada agente es un individuo con **nombre**, un
**tipo** (Documentación u ODAC — qué puestos opera), un **rango** (Policía u Oficial; el jugador es el
Subinspector que los dirige) y **cuatro atributos** que definen su rendimiento: ⚡ Rapidez, 🤝 Trato,
❤️ Salud y 🔥 Motivación. Provee a Flujo el `modificador_produccion` (duración efectiva) y el `factor_trato`
(que modula la satisfacción/retorno DGP), y es el **gate FL4**: un puesto sin agente asignado está cerrado.
El mercado de contratación y las ausencias diarias se resuelven con **RNG sembrado** (deterministas), y las
ausencias se evalúan al `nuevo_dia`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Guardado / serialización + RNG | Mercado y ausencias con RNGService sembrado; serializa plantilla/atributos/asignación | LOW |
| ADR-0001: Bus de eventos + tick + orden | Ausencias evaluadas al `nuevo_dia` (orden determinista) | LOW |

**Engine Risk (mayor entre los ADR gobernantes): LOW** — lógica pura + RNG; sin API de motor post-cutoff.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-staff-001 | Instancias Agente (atributos, rango, asignación); mercado con RNG sembrado | ADR-0002 ✅ (RNGService) |
| TR-staff-002 | Provee `modificador_produccion`/`factor_trato` y gate FL4 a Flujo | ADR-0001 ✅ (API) |
| TR-staff-003 | Ausencias evaluadas al `nuevo_dia` (RNG determinista) | ADR-0001 + ADR-0002 ✅ |

**Untraced Requirements**: None (3/3 cubiertos).

**Depende de (Foundation + Core):** Datos (catálogo de tipos/atributos), gate de **Economía** (contratar),
EventBus (`nuevo_dia`), RNGService, SaveManager. Sirve a **Flujo** el agente por puesto.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/staff-agents.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (incl. determinismo del mercado y de
  las ausencias; cálculo de `modificador_produccion`/`factor_trato`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [El Agente y sus fórmulas (F1–F4)](story-001-agente-y-formulas.md) | Logic | Ready | ADR-0003, ADR-0002 |
| 002 | [El mercado de fichajes](story-002-mercado-fichajes.md) | Logic | Ready | ADR-0002, ADR-0001 |
| 003 | [Asignación a puestos y gate para Flujo (FL4)](story-003-asignacion-gate-flujo.md) | Logic | Ready | ADR-0001, ADR-0003 |
| 004 | [Ausencias del día (nuevo_dia prio 30)](story-004-ausencias-del-dia.md) | Integration | Ready | ADR-0001, ADR-0002 |
| 005 | [El Oficial — cobertura y canalización (F6/F7)](story-005-oficial-cobertura-canalizacion.md) | Integration | Ready | ADR-0001 |
| 006 | [Nómina real a Economía y persistencia](story-006-nomina-persistencia.md) | Integration | Ready | ADR-0002, ADR-0001 |
| 007 | [Personal en el mundo — tu equipo en el HUD (HITO VISIBLE)](story-007-personal-en-el-mundo.md) | UI | Ready | ADR-0001 |

Cobertura: **20/21 AC del GDD** — AC-PE10 (duración efectiva con el agente rápido) queda **diferido a
Flujo** explícitamente (Personal aporta F2 testeada; Flujo la consumirá en su F1). Orden secuencial
estricto. **Decisiones propuestas marcadas en las stories** (aprobar al implementar): prob. de Oficial
en el mercado (0.2), refresco del mercado por calendario, gate de contratación = `puede_pagar(salario)`
sin coste puntual (Open Q4), plantilla inicial 2+1 con atributos medios (nómina 190 € intacta), y
enmiendas menores previstas (señales de personal en el bus; `fijar_salarios_dia` en Economía — hook ya
documentado en eco-003).

## Next Step

**Sprint 2**: `/story-readiness production/epics/personal/story-001-agente-y-formulas.md` → `/dev-story`.
