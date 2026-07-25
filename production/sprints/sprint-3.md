# Sprint 3 — 2026-07-25 a 2026-08-01 · "Que la espera duela: Paciencia (Feature A)"

> **Review mode**: lean (`production/review-mode.txt`; regla fija del proyecto — PR-SPRINT omitido)
> **Contexto**: Sprint 2 cerrado al **100 %** (7/7 tareas, 15 stories) con 6 días de adelanto.
> **Foundation 5/5 + Core 5/5 COMPLETOS.** Esta es la primera capa **Feature**.
> **Velocidad demostrada**: ~7-8 stories por sesión de trabajo, estable en dos sprints.
> **⚠️ Decisión del usuario REVISADA (2026-07-25, el mismo día)**: primero se eligieron los
> configuradores (Doc + ODAC) y minutos después el usuario pidió arrancar por **Paciencia #10**
> ("continúa con el #10"). **Orden vigente: Paciencia #10 → Documentación #8 → ODAC #9.** El motivo
> de diseño es sólido: Paciencia es lo que mete **presión** en la partida, y sin presión los horarios
> y las prioridades son decisiones sin consecuencia — con ella, configurar mal se paga.
> **Retrospectiva de entrada**: `production/retrospectives/retro-sprint-2-2026-07-25.md`.

## Sprint Goal

**Que la espera duela.** Al terminar el sprint, una comisaría mal gestionada debe **perder gente**: los
ciudadanos se cansan de esperar, se marchan sin ser atendidos y hunden la satisfacción — que a su vez
baja el retorno DGP y, por tanto, el dinero. Es la primera vez que el jugador puede **fracasar**. Si
sobra sprint, se sigue con los configuradores (Documentación #8, y ODAC #9 si cabe).

## Capacity

- Unidad real: **sesiones de trabajo con Claude** (velocidad demostrada: ~7-8 stories/sesión).
- Total estimado: ~3,1 sesiones · Buffer (20 %): ~0,5 · **Disponible: ~2,5**
- **Nota honesta**: el plan completo (Must + Should) suma ~2,9. Si la velocidad se mantiene como en los
  dos sprints anteriores, entra entero; si no, ODAC se arrastra al Sprint 4 sin drama. Los **Must Have
  caben con holgura**.

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|---------------------|
| C3-1 | `/qa-plan sprint` — plan de QA del Sprint 3 **antes** de implementar | Opus 5 (hilo principal) | 0,1 ses. | — | Casos de test por story definidos; patrón de los sprints 1-2 |
| C3-2 | `/create-stories paciencia` | Opus 5 | 0,2 ses. | — | Stories con formato del proyecto; EPIC + índice actualizados; TR-patience-001..004 trazados |
| C3-3 | Implementar epic **Paciencia #10** (barra por persona que drena con el reloj, el hacinamiento la acelera, abandono al llegar a 0 vía `Flujo.forzar_abandono`, escala `sat` 0-100, cierre al `nuevo_dia` que alimenta el retorno DGP, reclamaciones a ODAC con RNG) | Opus 5 | 1,0 ses. | C3-1, C3-2 | Test en verde por story; suite exit 0; **el determinismo A-vs-B sigue pasando con abandonos y reclamaciones activos**; valores solo del catálogo |
| C3-4 | **Rondas de demo y ajustes de Paciencia** (ventana abierta, feedback del usuario, correcciones) | Opus 5 + usuario | 0,3 ses. | C3-3 | Sign-off del usuario en `production/qa/evidence/`; feedback de comportamiento implementado, feedback estético anotado en `design/ux/pulido-backlog.md` |
| C3-5 | Cierre formal Paciencia (stories → Complete, EPIC, índice, commit) | Opus 5 | 0,1 ses. | C3-4 | EPIC Complete; pusheado |

### Should Have
| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|---------------------|
| C3-6 | `/create-stories documentacion` | Opus 5 | 0,2 ses. | C3-5 | Stories escritas; TR-doc-001/002 trazados |
| C3-7 | Implementar epic **Documentación #8** (horario configurable 08:00–20:00 + peonada, última admisión, cita (MVP sin cita), eventos de la División) — **incluye MIGRAR el horario provisional que hoy vive en Flujo** | Opus 5 | 0,8 ses. | C3-6 | Test en verde por story; **los tests de horario de Flujo siguen pasando tras la migración**; valores solo del catálogo |
| C3-8 | **Rondas de demo y ajustes de Documentación** | Opus 5 + usuario | 0,3 ses. | C3-7 | Sign-off del usuario; evidencia escrita |
| C3-9 | Cierre formal Documentación (stories → Complete, EPIC, índice, commit) | Opus 5 | 0,1 ses. | C3-8 | EPIC Complete; pusheado |

**Nota de alcance**: el epic **ODAC #9** (stories + implementación + demo + cierre, ~1,4 ses.) pasa al
**Sprint 4** salvo que este sprint vuele. No es carryover: es alcance que nunca cupo en la ventana con
Paciencia por delante.

### Nice to Have
| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|---------------------|
| C3-10 | **Aviso "demanda sin servicio capaz"** (acción #2 del retro): si llega un tipo de trámite que ningún puesto construido puede atender, avisarlo en el HUD | Opus 5 | 0,1 ses. | — | Reproducir el "misterio de las 22:00" (quitar la ventanilla TIE) y ver el aviso en vez de gente esperando eternamente |
| C3-11 | **Regla escrita de capas** en el control manifest (acción #5): orden de dibujo mundo/UI + `MOUSE_FILTER_IGNORE` en decorativos | Opus 5 | 0,05 ses. | — | Los dos bugs repetidos del Sprint 2 quedan documentados como regla |
| C3-12 | **Desglosar el feedback estético del usuario** en `design/ux/pulido-backlog.md` (acción #3) | Opus 5 + usuario | 0,05 ses. | — | La línea "hay que pulir cosas de diseño" convertida en puntos concretos |

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| — (Sprint 2 cerró al 100 %) | | |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Paciencia toca la simulación en caliente**: si el drenaje o el abandono se cuelan mal en el orden del tick, el determinismo A-vs-B se rompe | Media | **Alto** | Paciencia se suscribe al tick DESPUÉS de Flujo (orden del ADR-0001) y usa **RNGService** para la reclamación, nunca un `randf` propio. El test A-vs-B es la red y se corre en CADA story del epic |
| **El balance de la paciencia es delicado**: si drena rápido el juego frustra, si drena lento no hay tensión | **Alta** | Medio | Todo por knobs del catálogo; calibrar CON el usuario en la ventana (para eso está C3-4). No buscar el número perfecto a la primera |
| **Migrar el horario de Flujo a Documentación rompe la lógica de cierre** (AC-FL24, peonada, reapertura) | Media | Alto | Los tests de `flujo_horario_test.gd` son la red: deben seguir en verde durante toda la migración. Migrar en una story propia, no mezclada con features nuevas |
| **Balance del slider de horario sin datos de playtest** (¿compensa abrir hasta las 20:00 pagando peonada?) | Alta | Medio | Dejarlo como knobs del catálogo con valores semilla y NO calibrar fino; se decide en el 1er playtest (Open Question ya abierta) |
| ~~ODAC se percibe como "carga sin recompensa"~~ | — | — | **Riesgo DISUELTO por el reordenamiento**: al ir Paciencia primero, cuando llegue ODAC ya existirá la satisfacción que convierte su trabajo en dinero (retorno DGP). Otro punto a favor del orden elegido por el usuario |
| Scope creep del feedback en ventana (fue ~30 % del epic Flujo) | Alta | Medio | **Ya presupuestado**: C3-4 y C3-8 son tareas propias con estimación (acción #1 del retro) |
| Condición 3 del gate (UX antes de historias de UI) rozada por el slider de horario | Media | Bajo | El slider es **andamio** como el resto del HUD; la UI real espera a `/ux-design` |

## Dependencies on External Factors

- Ninguna.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-3.md`) — **es la tarea C3-1**
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off: patrón lean (evidencia por story + verificación independiente del hilo principal)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed (spot-check hilo principal) and merged
- [ ] **La partida se puede PERDER**: una comisaría mal gestionada pierde gente de forma visible
- [ ] El horario ya no vive prestado en Flujo (deuda del Sprint 2 — solo si entra C3-7)

> **Acciones heredadas de la retrospectiva del Sprint 2**: #1 presupuestar las rondas de demo (→ C3-4,
> C3-8) · #2 aviso de demanda sin servicio capaz (→ C3-10) · #3 backlog de pulido (→ creado, se
> alimenta en C3-12) · #4 erratas del GDD al momento (→ regla continua, sin tarea) · #5 regla de capas
> (→ C3-11).

> **Nota de proceso**: las stories concretas las crean C3-2 y C3-6; tras cada `/create-stories` se
> actualiza `sprint-status.yaml` con los archivos reales (`/sprint-plan update`).

> **Scope check**: si el sprint incorpora stories más allá del alcance del epic, correr
> `/scope-check [epic]` antes de implementar.
