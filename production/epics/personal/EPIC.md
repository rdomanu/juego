# Epic: Personal / Agentes

> **Layer**: Core
> **GDD**: design/gdd/staff-agents.md
> **Architecture Module**: Personal #6
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories personal`

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

## Next Step

Run `/create-stories personal` to break this epic into implementable stories.
