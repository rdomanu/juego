# Epic: Datos y Configuración

> **Layer**: Foundation
> **GDD**: design/gdd/data-config.md
> **Architecture Module**: Datos #2
> **Status**: Complete (2026-07-22)
> **Stories**: 4 created — see table below

## Overview

El sistema de Datos y Configuración es el **catálogo data-driven** del juego: la capa (sin lógica propia)
donde se definen, **fuera del código**, qué cosas existen en la comisaría y con qué forma y valores —tipos
de trámite (DNI, Pasaporte, TIE), tipos de denuncia de ODAC, tipos de puesto/sala/agente, escenarios y
tablas de costes—. Todos los demás sistemas lo leen como su **fuente de verdad**, respetando el principio
del proyecto "valores data-driven, nunca hardcodeados". Distingue **definición** (plantilla read-only) de
**instancia** (la poseen otros sistemas y la referencian por `id`), valida la integridad en carga (ids
únicos, integridad referencial, clamp de rangos, invariante R5) y ofrece lookup por `id` en runtime.
Tolera catálogos que cambian entre versiones de guardado (id huérfano → migra/descarta + log).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Formato del catálogo | Catálogo en `.tres` (Resources tipados, editor visual, sin parseo manual); referencias por `id` (no Resources anidados → evita `duplicate_deep` 4.5); read-only | LOW |
| ADR-0002: Guardado / serialización | Tolerancia a id huérfano entre versiones de save (migra/descarta + log) | MEDIUM |

**Engine Risk (mayor entre los ADR gobernantes): LOW-MEDIUM** — `Resource`/`.tres` es estable; el matiz
leve es `duplicate_deep()` en 4.5 si se anidan Resources (evitado por diseño: referencias por `id`).

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-data-001 | Catálogo data-driven (TramiteDoc, DenunciaODAC, TipoPuesto/Sala/Agente, Escenario) desde fuente externa | ADR-0003 ✅ |
| TR-data-002 | Definición (read-only) ≠ Instancia (la poseen otros, referencian por `id`) | ADR-0003 ✅ |
| TR-data-003 | Validación en carga: integridad referencial, ids únicos, clamp de rangos, invariante R5 | ADR-0003 ✅ |
| TR-data-004 | Lookup de definición por `id` en runtime | ADR-0003 ✅ |
| TR-data-005 | Formato del catálogo `.tres` vs JSON (Open Q#8) → decisión de arquitectura | ADR-0003 ✅ |
| TR-data-006 | Tolerancia a catálogo cambiante entre versiones de save (id huérfano→migra/descarta+log) | ADR-0002 ✅ |

**Untraced Requirements**: None (6/6 cubiertos).

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Esquema — clases Resource](story-001-esquema-clases-resource.md) | Logic | **Complete** (2026-07-22) | ADR-0003 |
| 002 | [Datos autoload — carga + lookup](story-002-autoload-carga-lookup.md) | Integration | **Complete** (2026-07-22) | ADR-0003 |
| 003 | [Validación en carga](story-003-validacion-en-carga.md) | Logic | **Complete** (2026-07-22) | ADR-0003 |
| 004 | [Catálogo MVP de Pozuelo](story-004-catalogo-mvp-pozuelo.md) | Config/Data | **Complete** (2026-07-22) | ADR-0003 |

**Orden:** 001 → 002 → 003 → 004. El contenido `.tres` (004) se genera con un script-herramienta
(`tools/build_catalogo.gd`) para evitar escribir `.tres` a mano en headless.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/data-config.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

EPIC COMPLETO (2026-07-22): 4/4 stories cerradas, suite 53/53, catálogo real de 30 .tres validando limpio. Siguiente trabajo del proyecto: epic tiempo (/create-stories) y, al terminarlo, el "esqueleto visible" (escena principal mínima: rejilla + reloj — decisión del usuario 2026-07-22).
