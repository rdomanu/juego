# Sprint 2 — 2026-07-24 a 2026-07-31 · "La comisaría se construye y se llena (Core B)"

> **Review mode**: lean (production/review-mode.txt; regla fija del proyecto — **PR-SPRINT omitido, Lean mode**)
> **Contexto**: Sprint 1 cerrado al 100 % con 6 días de adelanto (Economía + Demanda completos).
> **El epic Personal (7/7, sign-off 2026-07-24) se implementó en el hueco entre sprints** — trabajo
> pre-sprint que NO cuenta contra la capacidad de este. Core 3/5 → este sprint ataca los 2 restantes
> en el orden del índice: Construcción → **Flujo** (el integrador, al final).
> **Velocidad demostrada**: ~7 stories/sesión en hilo principal (14 stories S1 en ~2 ses. + Personal 7 en 1 ses.).

## Sprint Goal

Cerrar la capa Core del MVP: mostradores y salas que se **construyen con el ratón** sobre la rejilla
(Construcción) y ciudadanos **visibles** que entran, hacen cola y son atendidos (Flujo) — con el cobro
real de trámites, **el saldo del HUD sube por primera vez**.

## Capacity

- Unidad real: **sesiones de trabajo con Claude** (velocidad demostrada: ~7 stories/sesión).
- Total estimado: ~3 sesiones en la ventana del sprint
- Buffer (20 %): ~0,5 sesión (imprevistos; regla fija: todo en hilo principal)
- Disponible: ~2,5 sesiones

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|---------------------|
| C2-1 | `/create-stories construccion` (propuesta → aprobación usuario → escritura) | Fable (hilo principal) | 0,2 ses. | — | Stories con formato del proyecto; EPIC+índice actualizados |
| C2-2 | Implementar epic **Construcción** (~6-7 stories: rejilla de construcción sobre el TileMapLayer, colocar/demoler puestos y salas con el ratón, costes vía gate E4 de Economía, topes del escenario, `registrar_puesto`/`quitar_puesto` hacia Personal — API ya existente, save/load, HITO VISIBLE) | Fable | 0,8 ses. | C2-1, QA plan | Test en verde por story; suite completa exit 0; valores solo del catálogo; sign-off del hito visible |
| C2-3 | Cierre formal Construcción (stories → Complete, EPIC, índice, commits) | Fable | 0,1 ses. | C2-2 | EPIC Complete, pusheado |

### Should Have
| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|---------------------|
| C2-4 | `/create-stories flujo` | Fable | 0,2 ses. | C2-3 | Stories escritas; APIs de nav 2D verificadas contra `docs/engine-reference/godot/modules/navigation.md` |
| C2-5 | Implementar epic **Flujo** (~7-8 stories: ficha `Persona` → NPC navegando (ADR-0004), cola, atención en puesto con gate FL4 + `modificador_produccion`, `tramite_completado` → Economía cobra, salida; orden de tick Tiempo→Demanda→Flujo) | Fable | 1,2 ses. | C2-4 | Determinismo en la lógica; 60 FPS con el volumen del spike QQ-02; **HITO VISIBLE: gente entrando y saldo subiendo** |
| C2-6 | Cierre formal Flujo + demo integradora con sign-off | Fable | 0,1 ses. | C2-5 | EPIC Complete; evidencia + sign-off |

### Nice to Have
| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|---------------------|
| C2-7 | Propagar erratas anotadas al GDD (F6 floor→ceil en staff-agents; ejemplo 14:30 AC-T26 en time-system; tasa_base_odac 0.4/0.5 y "≈10 nocturnas" en demand-generation) | Fable | 0,1 ses. | — | GDDs corregidos; `/consistency-check` limpio |

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| — (Sprint 1 cerró al 100 %) | | |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Flujo = riesgo técnico nº1** (NavigationServer2D post-cutoff 4.6 + rendimiento) | Media | Alto | Spike QQ-02 ya validó 150 NPCs ≈ 145 FPS; ADR-0004; consultar SIEMPRE engine-reference antes de cada API de nav |
| Construcción estrena **interacción de ratón** en producción | Media | Medio | El slice ya validó el concepto; andamio mínimo (clic/teclas), sin UI real |
| Condición 3 del gate (UX antes de historias de UI) rozada por la toolbar de construcción | Media | Medio | Mantenerla como ANDAMIO provisional (patrón HUD esqueleto); el HUD/UI real espera a `/ux-design` |
| Scope creep visual (tentación de arte/juice al ver NPCs) | Media | Medio | Placeholder de formas/colores; arte tras art bible §5-9 (condición 2 del gate) |
| Subagentes inestables | Media | Bajo | Regla fija: todo en hilo principal; commits por hito |

## Dependencies on External Factors

- Ninguna.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-2.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off: patrón lean (evidencia por story + verificación independiente del hilo principal)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed (spot-check hilo principal) and merged

> **Nota de proceso**: las stories concretas de Construcción/Flujo las crean C2-1/C2-4; tras cada
> `/create-stories` se actualizará `sprint-status.yaml` con los archivos reales (`/sprint-plan update`).

> **QA Plan**: pendiente — correr `/qa-plan sprint` ANTES de implementar la primera story de
> Construcción (decisión del usuario 2026-07-24, patrón Sprint 1).

> **Scope check:** si el sprint incorpora stories más allá del alcance original del epic, correr
> `/scope-check [epic]` antes de implementar.
