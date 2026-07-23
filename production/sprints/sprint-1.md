# Sprint 1 — 2026-07-23 a 2026-07-30 · "La comisaría cobra vida (Core A)"

> **Review mode**: lean (production/review-mode.txt; regla fija del proyecto — PR-SPRINT omitido)
> **Contexto**: primer sprint formal. Foundation 5/5 completa (25 stories, suite 135/135, esqueleto
> visible firmado) se ejecutó como setup técnico pre-sprint.

## Sprint Goal

Economía y Demanda funcionando sobre los cimientos: el juego tiene presupuesto que sube y baja (visible
en el HUD del esqueleto) y ciudadanos que llegan —lógicamente— según la población de Pozuelo.

## Capacity

- Unidad real: **sesiones de trabajo con Claude** (velocidad Foundation: 25 stories ≈ 3 sesiones ≈ 8-9 stories/sesión).
- Total estimado: ~3 sesiones en la ventana del sprint
- Buffer (20%): ~0,5 sesión (imprevistos: agentes caídos, rescates en hilo principal)
- Disponible: ~2,5 sesiones

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|---------------------|
| C1-1 | `/create-stories economia` (propuesta agente lector → aprobación usuario → escritura) | Fable (coord.) + Opus | 0,2 ses. | — | Stories escritas con formato del proyecto; EPIC+índice actualizados |
| C1-2 | Implementar epic **Economía** (~5-6 stories: saldo + gates `puede_pagar`/`cobrar`/`abonar`, ingreso instantáneo por `tramite_completado`, cobros al `nuevo_dia` prioridad 20, retorno DGP `sat_cierre_doc`, save/load + Persist, saldo en HUD provisional) | Especialistas Opus + Fable verifica | 0,8 ses. | C1-1, QA plan | Cada story con test en verde; suite completa exit 0; catálogo como única fuente de valores |
| C1-3 | Cierre formal epic Economía (stories → Complete, EPIC, índice, bitácora, commits) | Fable | 0,1 ses. | C1-2 | EPIC Complete; todo pusheado |

### Should Have
| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|---------------------|
| C1-4 | `/create-stories demanda` + implementar epic **Demanda** (~4-5 stories: tasas de llegada calibradas a R5, mezcla ponderada 14 tipos vía RNGService, régimen día/noche `mult_nocturno_odac`, perfil semanal) | ídem | 1,0 ses. | C1-3 | Stories con test en verde; determinismo con semilla fija |

### Nice to Have
| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|---------------------|
| C1-5 | Arrancar `/create-stories personal` (solo propuesta + escritura) | ídem | 0,2 ses. | C1-4 | Stories de Personal listas para el Sprint 2 |

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| — (primer sprint) | | |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Inestabilidad de subagentes (límites/atascos/procesos caídos) | Media | Medio | Patrón rodado: rescate del parcial + remate en hilo principal; commits frecuentes por hito |
| Economía escucha eventos de sistemas aún no implementados (Flujo emite `tramite_completado`) | Alta | Bajo | Los tests emiten las señales del bus directamente (patrón ya usado en Tiempo/SaveManager) |
| Scope creep visual (tentación de adelantar UI real) | Media | Medio | Solo el saldo en el HUD provisional; el HUD real espera a `/ux-design hud` + epic UI #11 |
| W2 del review-all-gdds (estrategia dominante Doc>ODAC) | Baja (aún) | Medio | Vigilar al definir el objetivo del MVP; ODAC debe pesar vía valoración de jefes |

## Dependencies on External Factors

- Ninguna.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-1.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off: patrón lean (evidencia por story + verificación independiente del hilo principal)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed (spot-check hilo principal + review agente en módulos delicados) and merged

> **Nota de proceso**: las stories concretas de Economía/Demanda las crea C1-1/C1-4; tras cada
> `/create-stories` se actualizará `sprint-status.yaml` con los archivos reales (`/sprint-plan update`).

> **Scope check:** si el sprint incorpora stories más allá del alcance original del epic, correr
> `/scope-check [epic]` antes de implementar.
