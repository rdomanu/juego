# Story 001: El núcleo, la config y F1 — la barra que baja

> **Epic**: Paciencia y Satisfacción
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-25 — implementada + test 17/17 en verde

## Context

**GDD**: `design/gdd/patience-satisfaction.md` (Detailed Design PS1-PS5, F1)
**Requirement**: `TR-patience-001` (barra de paciencia por persona; drena con `delta`; Pausa congela;
hacinamiento acelera) — *parte pura; el tick real es la 002*
**Governing ADRs**: ADR-0001 (primario — determinismo), ADR-0003 (config del catálogo)
**ADR Decision Summary**: F1 es una función **pura** (dado un estado y unos minutos, devuelve la
paciencia resultante); los knobs vienen de un `ConfigPaciencia` (`.tres`), nunca hardcodeados.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: n/a — matemática y estado, sin API de motor.

**Control Manifest Rules (Feature)**:
- Required: nodo `class_name Paciencia extends Node` con `aplicar_config(config)` + clamps con aviso
  (patrón Economía/Flujo). Valores SOLO del catálogo. — ADR-0003
- Required: la paciencia de cada persona es estado de ESTE sistema, no de `PersonaFlujo` (Flujo no
  sabe nada de paciencia; la clave es la persona). — ADR-0001
- Forbidden: leer el reloj del sistema o `randf` propio (RNG solo en la 006, vía RNGService).

---

## Acceptance Criteria

- [x] **AC-PS01** `[Unit]` — GIVEN una persona coge turno THEN `paciencia = 100`.
- [x] **AC-PS02** `[Unit]` — GIVEN condiciones neutras (`tolerancia_base_min=30`, multiplicadores 1.0)
      WHEN espera 30 min sin ser llamada THEN `paciencia = 0` (lista para abandonar).
- [x] **AC-PS03** `[Unit]` — GIVEN hacinamiento ×1.5 WHEN espera THEN llega a 0 en **~20 min**.
- [x] **AC-PS05** `[Unit]` — ánimo derivado de la paciencia: **80 → 🟢 · 50 → 🟡 · 20 → 🔴**.

---

## Implementation Notes

- **F1**: `tasa_drenaje_efectiva = (100 / tolerancia_base_min) × mult_hacinamiento × mult_comodidad ×
  mult_horapunta`; `paciencia -= tasa × Δ_min`. En el MVP `mult_comodidad` y `mult_horapunta` son
  **1.0 fijos** (los activarán Comodidades #15 y el tuning de hora punta).
- **Hacinamiento**: `1.0` si `ocupacion ≤ aforo`; si no, `1 + k_hacinamiento × (ocupacion − aforo) / aforo`.
  La ocupación y el aforo se **leen** de Flujo/Construcción (`ocupacion_dentro`, `aforo_de_servicio`);
  Paciencia no los recalcula.
- **⚠️ Umbrales de ánimo — aclaración importante (verificada 2026-07-25, no es errata):** los umbrales
  son **66 / 33** (`ui-hud.md` F2 y el registro de entidades). El AC-PS05 no define umbrales distintos:
  enumera **tres casos de prueba** que los verifican (80 > 66 → 🟢; 33 ≤ 50 ≤ 66 → 🟡; 20 < 33 → 🔴).
  Los umbrales van en la **config**, no en el código (la UI los lee, nunca los hardcodea).
- **ConfigPaciencia** (knobs de esta story): `tolerancia_base_min` 30 · `k_hacinamiento` · `mult_comodidad`
  1.0 · `mult_horapunta` 1.0 · `umbral_animo_alto` 66 · `umbral_animo_bajo` 33. Los de puntuación y
  reclamación llegan en 003/006. Generar el `.tres` con `tools/build_config_paciencia.gd`.
- Almacenamiento: `Dictionary` persona → paciencia (la persona es la clave; RefCounted vive mientras
  Flujo la referencie). Alta al coger turno, baja al resolverse o abandonar (002).

---

## Test Cases

`tests/unit/paciencia/paciencia_drenaje_test.gd`
- `test_coge_turno_paciencia_100` (AC-PS01)
- `test_neutro_treinta_minutos_llega_a_cero` (AC-PS02 — valor exacto calculado a mano)
- `test_hacinamiento_uno_y_medio_llega_a_cero_en_veinte` (AC-PS03)
- `test_animo_por_umbrales_66_33` (AC-PS05 — los tres casos del GDD)
- `test_config_fuera_de_rango_se_clampa_con_aviso` (patrón del proyecto)

---

## Out of Scope

- El drenaje real con el tick y el abandono (002).
- La puntuación de la visita (003) y la `sat` agregada (004).

## Cierre (2026-07-25)

Implementada en hilo principal (Opus 5). **Ruta nueva: `src/feature/paciencia/`** — es el primer
sistema de la capa Feature y no había convención escrita; se sigue el patrón de capas de la
arquitectura (`foundation/` → `core/` → **`feature/`**).

- `paciencia.gd` (`class_name Paciencia`): alta/baja por persona, F1 (`tasa_drenaje`,
  `mult_hacinamiento`, `minutos_hasta_agotar`, `drenar`) y el ánimo derivado (`animo_de`).
- `config_paciencia.gd` + `tools/build_config_paciencia.gd` → `datos/config/paciencia.tres`
  (6 knobs; `tolerancia_base_min` 30 es el número a calibrar con el usuario en la demo).
- Test `tests/unit/paciencia/paciencia_drenaje_test.gd` **17/17 a la primera**. **Suite total:
  359/359, exit 0** (+42 respecto a los 342 del cierre de Flujo). Arranque headless limpio.

**Decisiones de implementación (más allá de los AC):**
- `registrar` es **idempotente**: un re-registro accidental no le regala paciencia a quien ya lleva
  esperando (sería un bug invisible y muy difícil de cazar en partida).
- La paciencia **no baja de 0** (una barra vacía no se vacía más) y `tolerancia_base_min = 0` no
  divide por cero: devuelve tasa 0 y el centinela **-1.0** para "no se agota" — misma convención que
  las fórmulas de Flujo (nunca ∞).
- Umbrales de ánimo **cruzados** en el `.tres` → se ordenan con aviso en vez de dejar una franja
  imposible donde el ánimo no se pudiera calcular.
- Sin sala medible (aforo ≤ 0) → sin castigo de hacinamiento: el drenaje base ya penaliza la espera.
