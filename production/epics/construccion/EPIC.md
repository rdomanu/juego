# Epic: Construcción y Distribución

> **Layer**: Core
> **GDD**: design/gdd/construction-layout.md
> **Architecture Module**: Construcción #7
> **Status**: In Progress (stories creadas 2026-07-24 — Sprint 2, C2-1)
> **Stories**: 7 (ver tabla)

## Overview

El sistema de Construcción y Distribución es con el que el jugador **da forma física a su comisaría**: sobre
una **rejilla 2D** de una planta, dibuja las **salas** del tamaño que quiera (las oficinas de Documentación
y ODAC y sus salas de espera), coloca los **puestos** de atención y los **objetos** (asientos, mostradores)
y lo paga todo con su presupuesto. Es construcción **libre estilo Theme Hospital**: salas grandes o pequeñas
a gusto (con la opción de sobredimensionar o hacinar, con sus consecuencias). Traduce ratón↔celda
(`local_to_map`/`map_to_local`) para el preview fantasma y la validación de colocación, instancia los
puestos/objetos como **escenas** (`PackedScene`, no tiles), y **provee a Flujo/Personal** la existencia,
posición y aforo de cada puesto. Usa el gate de Economía para cobrar y serializa el layout.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Rejilla + navegación 2D | Rejilla = `TileMapLayer` (⚠️ `TileMap` deprecado desde 4.3); puestos/objetos = `PackedScene` instanciadas, no tiles | MEDIUM (post-cutoff) |
| ADR-0002: Guardado / serialización | Serializa el layout; `Vector2i` (celdas) → `[x,y]` (limitación JSON) | MEDIUM |

**Engine Risk (mayor entre los ADR gobernantes): MEDIUM** — `TileMapLayer` es API post-cutoff (sustituye al
`TileMap` deprecado); verificada en `modules/tilemap-2d.md`. Sin sorpresas de rendimiento (una capa
estática de rejilla).

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-construction-001 | **Rejilla 2D = `TileMapLayer`** (⚠️ `TileMap` deprecado) | ADR-0004 ✅ |
| TR-construction-002 | Ratón↔celda (`local_to_map`/`map_to_local`) para preview fantasma + validación | ADR-0004 ✅ |
| TR-construction-003 | Puestos/objetos = escenas (`PackedScene`) instanciadas, no tiles | ADR-0004 ✅ |
| TR-construction-004 | Provee existencia/posición/aforo a Flujo/Personal; serializa layout | ADR-0004 + ADR-0002 ✅ |

**Untraced Requirements**: None (4/4 cubiertos).

**Depende de (Foundation):** Datos (catálogo de tipos de puesto/sala/objeto), gate de **Economía** (pagar
obras), SaveManager (layout). Sirve a **Flujo** y **Personal** la existencia/posición/aforo de los puestos.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/construction-layout.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (incl. validación de colocación
  celda↔ratón y round-trip de serialización del layout)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [El solar: núcleo, config y validación de colocación (F6)](story-001-nucleo-rejilla-validacion.md) | Logic | Ready | ADR-0004, ADR-0003 |
| 002 | [Construir y pagar: F1/F2 con el gate E4](story-002-construir-pagar.md) | Integration | Ready | ADR-0004, ADR-0001 |
| 003 | [Puentes: puestos → Personal, aforo F3, puestos útiles F5](story-003-puentes-personal-aforo.md) | Integration | Ready | ADR-0004, ADR-0001 |
| 004 | [Demoler y mover: reembolso F4, cascada, reorganización](story-004-demoler-mover.md) | Integration | Ready | ADR-0004, ADR-0001 |
| 005 | [Pausa y persistencia del layout](story-005-pausa-persistencia.md) | Integration | Ready | ADR-0002, ADR-0004 |
| 006 | [El solar visible: TileMapLayer + escenas + montaje inicial](story-006-solar-visible-montaje-inicial.md) | UI | Ready | ADR-0004, ADR-0001 |
| 007 | [Modo construcción con ratón: preview fantasma (HITO VISIBLE)](story-007-modo-construccion-raton.md) | UI | Ready | ADR-0004, ADR-0001 |

Cobertura: **17/18 AC del GDD** — **AC-CO13 (demoler un puesto atendiendo) DIFERIDO al epic Flujo**
explícitamente (no existe "atendiendo" aún — patrón AC-PE10). Orden secuencial estricto 001→007.
**Decisiones propuestas EN las stories** (aprobar al implementar): tamaño del edificio en
ConfigConstruccion (→ Escenario en multi-comisaría) · montaje inicial pagado "de oficio" (coste 0 al
arranque; saldo 3000 y nómina 190 INTACTOS) · mover solo puestos/objetos (salas: demoler+redibujar;
gesto de mover en UI diferido a UI/HUD #11) · ids `doc_1`/`doc_2`/`odac_1` conservados (compat) ·
**Main reordenado: Construcción ANTES que Personal** (invariante de carga de personal-006).

## Next Step

`/story-readiness production/epics/construccion/story-001-nucleo-rejilla-validacion.md` → implementar
en orden. El QA plan del sprint (`production/qa/qa-plan-sprint-2.md`) ya define gates y casos.
