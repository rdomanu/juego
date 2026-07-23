# Epics Index

Last Updated: 2026-07-22
Engine: Godot 4.6
Manifest: control-manifest 2026-07-22

> Un epic = un módulo de arquitectura (`docs/architecture/architecture.md` §Propiedad de módulos).
> Orden de capas: **Foundation → Core → Feature → Presentation**. Crear epics de una capa solo cuando se
> aproxima su desarrollo. Tras crear cada epic → `/create-stories [epic-slug]`.

## Foundation (cimientos — sin dependencias de diseño)

| Epic | Layer | System | GDD | Governing ADRs | Engine Risk | Stories | Status |
|------|-------|--------|-----|----------------|-------------|---------|--------|
| [Sistema de Tiempo](tiempo/EPIC.md) | Foundation | Tiempo #1 | time-system.md | ADR-0001, ADR-0002 | MEDIUM | 9 stories | **Complete** |
| [Datos y Configuración](datos/EPIC.md) | Foundation | Datos #2 | data-config.md | ADR-0003, ADR-0002 | LOW-MEDIUM | 4 stories | **Complete** |
| [EventBus](event-bus/EPIC.md) | Foundation | ▸EventBus (infra) | — | ADR-0001 | LOW | 2 stories | **Complete** |
| [SaveManager](save-manager/EPIC.md) | Foundation | ▸SaveManager (infra) | — (#20) | ADR-0002 | MEDIUM | 7 stories | **Complete** |
| [RNGService](rng-service/EPIC.md) | Foundation | ▸RNGService (infra) | — | ADR-0002 | LOW | 3 stories | **Complete** |

## Core (la simulación viva — depende de Foundation)

| Epic | Layer | System | GDD | Governing ADRs | Engine Risk | Stories | Status |
|------|-------|--------|-----|----------------|-------------|---------|--------|
| [Economía / Presupuesto](economia/EPIC.md) | Core | Economía #3 | economy-budget.md | ADR-0001, ADR-0002 | LOW | 7 stories | **Complete** |
| [Flujo de Personas y Colas](flujo/EPIC.md) | Core | Flujo #4 | flow-queues.md | ADR-0004, ADR-0001, ADR-0002 | MEDIUM-HIGH* | Not yet created | Ready |
| [Generación de Demanda](demanda/EPIC.md) | Core | Demanda #5 | demand-generation.md | ADR-0002, ADR-0001 | LOW | 7 stories | **Complete** |
| [Personal / Agentes](personal/EPIC.md) | Core | Personal #6 | staff-agents.md | ADR-0002, ADR-0001 | LOW | Not yet created | Ready |
| [Construcción y Distribución](construccion/EPIC.md) | Core | Construcción #7 | construction-layout.md | ADR-0004, ADR-0002 | MEDIUM | Not yet created | Ready |

**\*** Flujo junta navegación 2D (API post-cutoff 4.6) + riesgo de rendimiento nº1 → **MITIGADO** por el
spike QQ-02 del vertical slice (150 NPCs → ~145 FPS; plan B `AStarGrid2D` no necesario).

## Feature (depende de Core)

*Pendiente.* Módulos previstos (MVP): Documentación #8 · ODAC #9 · Paciencia #10.

## Presentation (envuelve el juego — depende de Feature/Core)

*Pendiente.* Módulos previstos (MVP): UI/HUD #11 · Feedback y Juice #12.

---

**Progreso:** 10 epics MVP creados (5 Foundation + 5 Core). Faltan las capas Feature (Documentación #8 ·
ODAC #9 · Paciencia #10) y Presentation (UI/HUD #11 · Feedback #12) — se crearán con `/create-epics
layer: feature` / `layer: presentation` cuando se aproxime su desarrollo.

**Trazabilidad Foundation + Core:** los ~37 requisitos técnicos de ambas capas (TR-time-*, TR-data-*,
TR-bus-*, TR-save-*, TR-economy-*, TR-flow-*, TR-demand-*, TR-staff-*, TR-construction-*) están **100 %
cubiertos** por ADR aceptados (verificado en `/architecture-review` 2026-07-22, 56/56, 0 gaps). Ninguna
story nacerá bloqueada por falta de ADR.

**Orden de construcción sugerido (se detallará en las stories):**
Foundation: EventBus + RNGService → Datos → Tiempo → SaveManager.
Core: Economía → Demanda → Personal → Construcción → **Flujo** (el que lo integra todo, va al final).
