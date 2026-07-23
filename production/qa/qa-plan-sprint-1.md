# QA Plan — Sprint 1 · "La comisaría cobra vida (Core A)" · 2026-07-23

> **Modo**: lean (review-mode del proyecto) — el plan agrega los requisitos de test embebidos en cada
> story; sin QA Lead spawn. Gates de evidencia según `coding-standards.md` §Testing.
> **Suite base al abrir el sprint**: 135/135, exit 0.

## Clasificación de historias y evidencia exigida

### Epic Economía (Must Have — C1-2)

| Story | Tipo | Gate | Evidencia exigida | Casos clave |
|-------|------|------|-------------------|-------------|
| 001 núcleo/gates | Logic | **BLOCKING** | `tests/unit/economia/economia_nucleo_test.gd` | gates E07/E08; config data-driven E17; clamps |
| 002 ingresos DGP | Logic | **BLOCKING** | `economia_ingresos_test.gd` | E01 (3,6 €), E02/E03 (extremos+clamp), E03b (constante intra-jornada), E04 (ODAC no ingresa) |
| 003 cierre diario | Logic | **BLOCKING** | `economia_cierre_test.gd` | E05 (190 €), E06, **orden E09/E10/E10b/E10c** (recargo sobre apertura, compuesto) |
| 004 préstamos | Logic | **BLOCKING** | `economia_prestamos_test.gd` | E11, E12/E12b (híbrida), E14f/g/h (strike no se recupera) |
| 005 insolvencia | Logic | **BLOCKING** | `economia_insolvencia_test.gd` | E13/E14/E14a-e (pausa, gracia 720 min de juego, auto-rescate, game over) |
| 006 balance+save | Logic | **BLOCKING** | `economia_ciclo_save_test.gd` | E16, E18 (carga sin señales/cobros), **E19 determinismo** |
| 007 saldo en HUD | Visual/UI | ADVISORY | `production/qa/evidence/economia-saldo-hud-[fecha].md` + PNG + **sign-off usuario** | saldo 3000 visible; nómina −190 a la vista; color+texto por estado |

### Epic Demanda (Should Have — C1-4)
Se clasificará al crear sus stories (previsto: todas Logic BLOCKING con semilla fija del RNGService).

## Reglas transversales (test-standards del proyecto)

- Determinismo: sin reloj real ni RNG global; tiempo de juego y satisfacción **inyectados**; floats con
  `is_equal_approx`.
- Aislamiento: bus/Tiempo **espías propios** en unit (nunca los autoloads reales); teardown limpia.
- Nombres `test_[escenario]_[esperado]`; Arrange/Act/Assert; fixtures en el propio test.
- Los valores esperados (12 €, 0.15/0.45, 60/70, 15 €/h) salen del **catálogo real** — si un test los
  duplica hardcodeados y el catálogo cambia, debe fallar (eso es correcto: detecta divergencia).

## Smoke scope del sprint

Al cerrar C1-2/C1-3: suite completa exit 0 + arranque headless del juego con Economía instanciada sin
errores + (007) walkthrough manual con captura y sign-off. Smoke doc: `production/qa/smoke-[fecha].md`.

## Sign-off del sprint

Patrón lean: evidencia por story + verificación independiente del hilo principal (re-ejecución de la
suite) + sign-off del usuario en las stories visibles. Sin S1/S2 abiertos al cierre.
