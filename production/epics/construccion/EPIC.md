# Epic: Construcción y Distribución

> **Layer**: Core
> **GDD**: design/gdd/construction-layout.md
> **Architecture Module**: Construcción #7
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories construccion`

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

## Next Step

Run `/create-stories construccion` to break this epic into implementable stories.
