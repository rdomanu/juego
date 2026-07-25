# Epics Index

Last Updated: 2026-07-25
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
| [Flujo de Personas y Colas](flujo/EPIC.md) | Core | Flujo #4 | flow-queues.md | ADR-0004, ADR-0001, ADR-0002 | MEDIUM-HIGH* | 8 stories | **Complete** (8/8, 2026-07-25) |
| [Generación de Demanda](demanda/EPIC.md) | Core | Demanda #5 | demand-generation.md | ADR-0002, ADR-0001 | LOW | 7 stories | **Complete** |
| [Personal / Agentes](personal/EPIC.md) | Core | Personal #6 | staff-agents.md | ADR-0002, ADR-0001 | LOW | 7 stories | **Complete** |
| [Construcción y Distribución](construccion/EPIC.md) | Core | Construcción #7 | construction-layout.md | ADR-0004, ADR-0002 | MEDIUM | 7 stories | **Complete** |

**\*** Flujo junta navegación 2D (API post-cutoff 4.6) + riesgo de rendimiento nº1 → **MITIGADO** por el
spike QQ-02 del vertical slice (150 NPCs → ~145 FPS; plan B `AStarGrid2D` no necesario).

## Feature (depende de Core)

| Epic | Layer | System | GDD | Governing ADRs | Engine Risk | Stories | Status |
|------|-------|--------|-----|----------------|-------------|---------|--------|
| [Documentación](documentacion/EPIC.md) | Feature | Documentación #8 | documentation.md | ADR-0001, ADR-0003, ADR-0002 | LOW | Not yet created | Ready |
| [ODAC / Denuncias](odac/EPIC.md) | Feature | ODAC #9 | odac.md | ADR-0001, ADR-0003, ADR-0002 | LOW | Not yet created | Ready |
| [Paciencia y Satisfacción](paciencia/EPIC.md) | Feature | Paciencia #10 | patience-satisfaction.md | ADR-0001, ADR-0002, ADR-0003 | LOW | **8 stories** | **In Progress** (Sprint 3) |

**Trazabilidad Feature:** los 8 TR de la capa (TR-doc-001/002, TR-odac-001/002, TR-patience-001..004)
están **100 % cubiertos** por ADR aceptados — 0 huérfanos. **Riesgo de motor LOW en los tres**: no
estrenan ninguna API de Godot, son lógica de simulación, configuración y eventos sobre los cimientos ya
rodados. El riesgo real de esta capa es de **diseño y balance** (¿cuánto aguanta la gente?, ¿cuánto
cuesta la peonada?), que se resuelve en playtest, no en arquitectura.

**Nota de deuda:** el epic **Documentación** se lleva el horario que hoy vive provisionalmente en Flujo
(enmienda del 2026-07-25), y el epic **ODAC** da dueño a `Flujo.reconfigurar_puesto`, ya implementado y
testeado pero aún sin sistema que lo gobierne.

## Presentation (envuelve el juego — depende de Feature/Core)

*Pendiente.* Módulos previstos (MVP): UI/HUD #11 · Feedback y Juice #12.

---

**Progreso:** **13 epics MVP creados** (5 Foundation + 5 Core + 3 Feature). **Foundation 5/5 y Core 5/5
COMPLETOS** (2026-07-25). Falta la capa Presentation (UI/HUD #11 · Feedback #12) — se creará con
`/create-epics layer: presentation` cuando se aproxime, después de `/ux-design` (condición 3 del gate).

**Trazabilidad Foundation + Core:** los ~37 requisitos técnicos de ambas capas (TR-time-*, TR-data-*,
TR-bus-*, TR-save-*, TR-economy-*, TR-flow-*, TR-demand-*, TR-staff-*, TR-construction-*) están **100 %
cubiertos** por ADR aceptados (verificado en `/architecture-review` 2026-07-22, 56/56, 0 gaps). Ninguna
story nacerá bloqueada por falta de ADR.

**Orden de construcción sugerido (se detallará en las stories):**
Foundation: EventBus + RNGService → Datos → Tiempo → SaveManager.
Core: Economía → Demanda → Personal → Construcción → **Flujo** (el que lo integra todo, va al final).
