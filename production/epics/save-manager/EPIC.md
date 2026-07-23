# Epic: SaveManager (guardado y carga)

> **Layer**: Foundation
> **GDD**: — (módulo de infraestructura sin GDD; corresponde al sistema #20 "Guardado y Carga" del índice; derivado de `docs/architecture/architecture.md` §3.3 y ADR-0002)
> **Architecture Module**: ▸SaveManager
> **Status**: Ready
> **Stories**: 7 created — see table below

## Overview

El SaveManager **orquesta el guardado y la carga** de la partida. Persiste el estado del juego en **JSON**
dentro de `user://` (NO custom Resources `.tres`, por seguridad y por el issue conocido de `ResourceSaver`
en 4.6). Cada sistema con estado mutable implementa el patrón `save() -> Dictionary` / `load_state(d)` y se
registra en el grupo "Persist" (así el SaveManager no llama a nadie por su nombre, respetando la regla de
capas). El manager recorre ese grupo para serializar/deserializar, coordina el **orden** (el catálogo de
Datos debe estar cargado **antes** de `load_state`), y garantiza que tras cargar el juego queda **en Pausa
y sin eventos retroactivos**. Traduce tipos que JSON no soporta (p. ej. `Vector2i` de las celdas del layout
→ `[x,y]`). Es infraestructura pura: no es una mecánica, es la tubería de persistencia.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Guardado / serialización + RNG | JSON en `user://`; patrón `save()`/`load_state()` vía grupo "Persist"; serializa el RNG; `Vector2i`→`{x,y}`; `.tres` descartado por riesgo de ejecución de código | MEDIUM |

**Engine Risk: MEDIUM** — `FileAccess.store_*` devuelve `bool` desde 4.4 (post-cutoff), `user://` y JSON;
todo verificado en `modules/save-load.md`. Es el **único** módulo de Foundation con riesgo de motor medio.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-save-001 | Guardado JSON/ConfigFile en `user://` (NO custom Resources); patrón `save()`/`load_state()` por sistema | ADR-0002 ✅ |
| TR-save-003 | `Vector2i` (celdas del layout) → descomponer a `[x,y]` (limitación JSON) | ADR-0002 ✅ |

**Coordina (implementados por sus módulos dueños, orquestados aquí):** TR-time-008 (reloj/fecha), TR-data-006
(tolerancia a id huérfano), TR-flow-006 (colas/puestos/personas), TR-save-002 (estado del RNG → RNGService),
TR-ui-005 (preferencias de UI, no estado de juego).

**Untraced Requirements**: None (2/2 propios cubiertos; los coordinados los cubren sus epics).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- Un ciclo **guardar → cerrar → cargar** deja el juego en un estado idéntico (round-trip verificado)
- All Logic and Integration stories have passing test files in `tests/` (incl. round-trip determinista y
  traducción de tipos JSON)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/` (N/A esperado
  para este módulo puramente técnico)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Helper de tipos JSON-safe (`Vector2i`↔`{x,y}`)](story-001-serial-util.md) | Logic | Ready | ADR-0002 |
| 002 | [Recolección: grupo `Persist` → dict raíz con `version`](story-002-recoleccion-persist.md) | Logic | Ready | ADR-0002 |
| 003 | [Escritura segura en `user://` (temp+rename, bool de `store_*`)](story-003-escritura-segura.md) | Logic | Ready | ADR-0002 |
| 004 | [Lectura + parseo + chequeo de `version` (hook migraciones)](story-004-lectura-parseo-version.md) | Logic | Ready | ADR-0002 |
| 005 | [Distribución tolerante: sub-dicts vía `load_state`](story-005-distribucion-tolerante.md) | Logic | Ready | ADR-0002 |
| 006 | [Round-trip END-TO-END con autoloads reales (disco `user://`)](story-006-roundtrip-end-to-end.md) | Integration | Ready | ADR-0002 |
| 007 | [Registro autoload 5º + smoke](story-007-autoload-smoke.md) | Integration | Ready | ADR-0002 |

**Orden**: 001 → 002 → 003 → 004 → 005 → 006 → 007 (dependencias lineales con un par de bifurcaciones: 005 depende de 002 y 004; 006 de 003 y 005). Los tipos JSON-safe (001) son la raíz; el registro del autoload + smoke (007) es el cierre, tras el round-trip verde (006).

## Next Step

Run `/story-readiness production/epics/save-manager/story-001-serial-util.md` para validar la primera story, luego `/dev-story production/epics/save-manager/story-001-serial-util.md` para empezar a implementarla.
