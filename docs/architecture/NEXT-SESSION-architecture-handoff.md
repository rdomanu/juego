# Prompt de traspaso — Sesión de ARQUITECTURA (`/create-architecture`)

> Copia todo lo de abajo (desde "===") como primer mensaje de la sesión nueva.
> Guardado el 2026-07-22 tras cerrar diseño (12/12 GDD APPROVED) + gate PASS + formación Godot 4.6.

===

Continúa el proyecto **"Comisario"** (tycoon de gestión de una comisaría del CNP español; **Godot 4.6 + GDScript, 2D top-down**; plantilla CCGS; repo `rdomanu/juego`, rama `main`, trunk-based). **El diseño MVP está COMPLETO y REVISADO** (12/12 GDD `/design-review` APPROVED; `/review-all-gdds` CONCERNS sin blockers; `/gate-check` Systems Design → Technical Setup **PASS**; etapa = `Technical Setup`). Ahora toca **terminar la Fase 4: `/create-architecture`** (Ruta A).

## Reglas fijas de trabajo
- **Habla en español.** Modo de revisión: **LEAN**.
- **Los subagentes FALLAN** ("API Error: Usage credits required for 1M context") → haz TODO en el hilo principal (lentes de technical-director/lead-programmer manualmente). Internet SÍ funciona (WebSearch/WebFetch).
- Cuando corresponda tier Sonnet, **Sonnet 5** (nunca 4.6).
- **Contexto 1M** (Opus 4.8): no cortes por "contexto cargado".
- **Protocolo colaborativo:** Pregunta→Opciones→Decisión→Borrador→Aprobación; `AskUserQuestion` para aprobar; pide permiso antes de escribir. Usuario **principiante en gamedev** — explica lo técnico con claridad.

## Primer paso obligatorio
Lee `production/session-state/active.md` (estado vivo). El registro de valores es `design/registry/entities.yaml`. **La biblioteca de Godot 4.6 YA está verificada y actualizada** (2026-07-22) en `docs/engine-reference/godot/` — LÉELA antes de decidir APIs (módulos: `navigation.md`, `tilemap-2d.md`, `save-load.md`, `patterns.md`, `rendering.md`, `ui.md`).

## Decisiones técnicas YA tomadas (formación 4.6, 2026-07-22 — NO re-investigar)
1. **Glow real DESCARTADO en 2D** → mood con **CanvasModulate + Light2D**; dorado del ascenso con **animación de sprite** (Tween). *(Feedback #12 OpenQ2 resuelta; no necesita ADR.)*
2. **Save de partida = JSON/ConfigFile en `user://`** (NO custom Resources: seguridad + issue ResourceSaver 4.6). **Catálogo de Datos = `.tres`** (o JSON — a decidir en ADR de formato de datos).
3. **Rejilla de Construcción = `TileMapLayer`** (`TileMap` deprecado). API en `modules/tilemap-2d.md`.
4. **Pathfinding NPCs = NavigationServer2D + NavigationAgent2D** (gotcha: fijar `target_position` tras el 1er physics frame, no en `_ready()`).
5. **Bus de eventos = autoload + signals**; **orden de handlers determinista** (dispatcher) para `nuevo_dia`/`nuevo_mes` (Paciencia cierra sat / Economía cobra / Tiempo avanza fecha).
6. **Hallazgo clave:** la mayoría de HIGH-risk de Godot 4.6 son de 3D → **NO afectan** a Comisario (2D).

## Qué queda de `/create-architecture` (Fases pendientes)
- **0b — Technical Requirements Baseline:** extraer TRs (`TR-[gdd]-NNN`) de los 12 GDD (data structures, performance, engine APIs, comunicación, estado persistente, timing).
- **1 — Mapa de capas:** Foundation (Tiempo, Datos, bus de eventos, guardado) / Core (Flujo, Demanda, Personal, Construcción, Economía) / Feature (Documentación, ODAC, Paciencia) / Presentation (UI, Feedback).
- **2 — Module Ownership** (owns/exposes/consumes + engine APIs por módulo).
- **3 — Data Flow** (frame update, bus de eventos, save/load, orden de init).
- **4 — API Boundaries** (contratos entre módulos).
- **5 — ADR Audit + Traceability** (no hay ADRs aún → todos son "Required New ADRs").
- **6 — Missing ADR list** (Foundation primero).
- **7 — Escribir `docs/architecture/architecture.md`** + sign-off TD.

## ADRs previstos (Foundation primero)
1. **Bus de eventos** (autoload + signals; orden de handlers determinista) — base de todo.
2. **Guardado / serialización** (JSON+FileAccess en `user://`; patrón `save()`/`load_state()` por sistema; serializar estado del RNG para determinismo).
3. **Formato de datos del catálogo** (`.tres` Resource vs JSON — Datos OpenQ#8).
4. **Rejilla + navegación 2D** (TileMapLayer para el layout; NavigationAgent2D para NPCs).
*(Glow ya resuelto → sin ADR.)*

## Después de la arquitectura
`/architecture-review` → `/create-control-manifest` → `/test-setup` → `/ux-design` (interaction-patterns + accessibility) → gate Technical Setup → Pre-Production → `/vertical-slice` (1er build jugable — **AVISAR al usuario**).

## Warnings de la revisión holística a tener presentes
- **W1** carga cognitiva (~4-5 sistemas activos) → a playtest; mitigado por Oficial/pausa/revelación progresiva.
- **W2** que la **valoración de jefes / ODAC pese de verdad** en el objetivo del MVP (si no, estrategia dominante Doc>ODAC). Decisión de balance clave.
