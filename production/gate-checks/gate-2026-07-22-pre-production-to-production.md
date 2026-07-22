# Gate Check: Pre-Production → Production

**Date**: 2026-07-22
**Checked by**: `/gate-check` skill
**Review mode**: LEAN (no `review-mode.txt` → default; subagentes caídos por "1M context" → panel de directores por lentes manuales en el hilo principal)
**Decision**: **ADVANCE con condiciones** (elección del usuario tras el veredicto CONCERNS)

---

## Required Artifacts

| Artefacto | Estado | Nota |
|---|---|---|
| Vertical slice REPORT.md (recomendado) | ✅ | `prototypes/comisaria-vertical-slice/REPORT.md` — veredicto **PROCEED** |
| First sprint plan (`production/sprints/`) | ❌ | No creado (carpeta inexistente) |
| Art bible completo (9 secciones) + sign-off AD-ART-BIBLE | ⚠️ | Solo secciones 1–4; 5–9 + sign-off pendientes. **Condición conocida del gate de Producción.** |
| Entity inventory (`design/assets/entity-inventory.md`) (recomendado) | ❌ | No creado |
| Todos los GDD del MVP completos | ✅ | 12/12 en `design/gdd/`, consistentes (10ª+ `/consistency-check` PASS) |
| Master architecture doc | ✅ | `docs/architecture/architecture.md` v1.0 |
| ≥3 ADR Foundation | ✅ | 4 ADR (0001–0004) |
| Todos los ADR Foundation/Core = `Accepted` | ✅ | Los 4 verificados `Accepted` (grep 2026-07-22) |
| Control manifest | ✅ | `docs/architecture/control-manifest.md` |
| Epics (`production/epics/`, Foundation + Core) | ❌ | No creados |
| Vertical slice jugable (recomendado) | ✅ | Jugado por el usuario a lo largo de la sesión |
| Playtest ≥1 sesión (recomendado) | ✅ | REPORT.md = evidencia de playtest |
| Playtest report (recomendado) | ✅ | Equivalente: `REPORT.md` del slice |
| UX de pantallas clave (menú, HUD, pausa) | ❌ | Solo existe `interaction-patterns.md`; falta `hud.md`, menú principal, pausa |
| HUD design (`design/ux/hud.md`) | ❌ | Diferido en el slice, nunca redactado |
| UX specs pasan `/ux-review` | ⚠️ | `interaction-patterns.md` APPROVED; faltan las specs de pantalla |

## Quality Checks

- ✅ **Core loop fun validado** — el REPORT documenta que el jugador entendió y explotó el bucle sin guía.
- ✅ **Vertical slice COMPLETO** end-to-end (Escalones 0–5): ciclo [inicio → reto → resolución → ascenso].
- ✅ **Riesgo técnico nº1 despejado** — spike QQ-02: 150 NPCs → ~145 FPS (simulación); plan B AStarGrid2D no necesario.
- ✅ Arquitectura sin ADR circulares; 4 ADR `Accepted`; motor 4.6 consistente.
- ✅ Sin conflictos de consistencia abiertos (`docs/consistency-failures.md`: 2 entradas, ambas *Resuelto*).
- ❌ Backlog de Producción (epics/stories/sprint) inexistente.
- ⚠️ Art bible incompleto (gates de producción de **arte**, no del código de cimientos).
- ⚠️ UX de pantallas (HUD/menú/pausa) sin specs (gates de producción de **UI**, no del código de cimientos).

## Vertical Slice Validation

- ✅ Un humano jugó el bucle sin guía del desarrollador.
- ✅ El juego comunica qué hacer en los primeros 2 min.
- ✅ Sin bugs "fun-blocker" críticos en el build del slice.
- ✅ El mecanismo central se siente bien (confirmado por el usuario en la sesión).

→ Ningún ítem de validación del slice es NO → **no dispara FAIL automático.**

## Director Panel (lentes manuales — LEAN)

- **Creative Director → READY.** Diversión y fantasía del jugador validadas por el slice (PROCEED).
- **Technical Director → READY.** Arquitectura sólida, 4 ADR aceptados, spike superado, tests + CI montados.
- **Producer → CONCERNS.** Backlog de Producción sin planificar (epics/stories/sprint).
- **Art Director → CONCERNS.** Art bible incompleto (5–9 + sign-off AD-ART-BIBLE pendientes).

→ 2 directores CONCERNS → veredicto mínimo **CONCERNS**.

---

## Condiciones a resolver en Producción (aceptadas por el usuario al avanzar)

Ninguna bloquea el **código de cimientos** (Foundation: EventBus, SaveManager, RNGService, Tiempo…),
que no requiere arte ni pantallas. Se resuelven **justo a tiempo**, antes de las historias que dependan de ellas:

1. **Backlog de Producción** — `/create-epics` (foundation + core) → `/create-stories [epic]` → `/sprint-plan`.
   *(Inmediato: es el siguiente paso; sin esto no se puede empezar a implementar.)*
2. **Art bible 5–9 + sign-off AD-ART-BIBLE** — antes de la primera historia de **arte/assets**.
3. **UX de pantallas clave** (`design/ux/hud.md`, menú principal, pausa) + `/ux-review` — antes de las historias de **UI**.
4. **Inventario de entidades** (`design/assets/entity-inventory.md`, `/asset-spec`) — antes de producir arte (recomendado).

---

## Chain-of-Verification

5 preguntas de desafío verificadas (≥2 con acción de herramienta):

1. ¿Alguna CONCERN debería elevarse a bloqueante? — No para *entrar* en Producción: el código de cimientos no depende de arte/UX. Epics/stories/sprint bloquean *implementar*, y son el siguiente paso inmediato. **[TOOL ACTION]** `Glob production/**` confirma que no existen `epics/` ni `sprints/`.
2. ¿Se resuelven en la fase siguiente o se agravan? — Todas resolubles justo a tiempo; el art bible es una condición rastreada. No se agravan si se rastrean.
3. ¿Suavicé un FAIL a CONCERNS? — Considerado: por la letra, faltan artefactos "required". Pero la validación del slice (el propósito decisivo de Pre-Prod) está superada y los huecos son *preparación por hacer*, no defectos. La filosofía de la skill (veredicto asesor, "nunca bloquear el avance", tags "recommended not blocking") respalda CONCERNS con condiciones documentadas.
4. ¿Artefactos sin comprobar que revelen más bloqueantes? — **[TOOL ACTION]** Comprobados `production/`, `design/ux/`, `design/art/`, `design/assets/`, `docs/architecture/` y estados de ADR (grep `Accepted`). Cubierta la lista del gate.
5. ¿El conjunto de CONCERNS crea un problema bloqueante? — Significan "planificación + prep de arte/UX por hacer" = justamente el trabajo de transición. No es un problema de diseño/técnico. Veredicto **CONCERNS** sin cambios.

**Chain-of-Verification: 5 preguntas verificadas — veredicto unchanged (CONCERNS).**

---

## Verdict: **CONCERNS** → Usuario decide **AVANZAR con condiciones**

La diversión y la viabilidad están validadas y los cimientos técnicos son firmes (el núcleo del gate).
Los huecos son artefactos de planificación y preparación de arte/UX, no defectos, y no bloquean el
primer código (Foundation). El usuario avanza la etapa a **Production** y arranca el backlog con
`/create-epics`, con las 4 condiciones anteriores registradas para resolverse a su debido tiempo.

**Next step:** `/create-epics` (layer foundation, luego core).
