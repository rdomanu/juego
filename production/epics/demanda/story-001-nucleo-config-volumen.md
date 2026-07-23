# Story 001: Núcleo, config y volumen base (F1 + F2)

> **Epic**: Generación de Demanda
> **Status**: Complete (cierre del epic con sign-off, 2026-07-24)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/demand-generation.md` (DG2, DG3, DG7, DG8, F1, F2, F5)
**Requirement**: `TR-demand-001` *(parcial — el volumen y los perfiles que alimentarán el generador; el acumulador llega en la 002/003)*
*(Texto del requisito en `docs/architecture/tr-registry.yaml` — leer fresco al revisar)*

**Governing ADRs**: ADR-0003 (primario — config data-driven como Resource `.tres` por herramienta), ADR-0001 (secundario — el nodo vivirá en el mundo y se suscribirá al tick en la 003)
**ADR Decision Summary**: ADR-0003 — los valores estáticos viven en Resources tipados (`class_name` + `@export`), generados por herramienta en `tools/`, leídos read-only. ADR-0001 — los sistemas Core son nodos del mundo (NO autoloads).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: sin API post-cutoff. `Dictionary[StringName, float]` tipado OK (estable desde 4.4). El `.tres` se genera con `tools/build_config_demanda.gd` (`extends SceneTree` + `ResourceSaver.save`) en headless — nunca a mano (gotcha de uids). En frío headless, si una clase extiende otra del proyecto: heredar por **ruta literal**, no por `class_name`.

**Control Manifest Rules (Core)**:
- Required: **data-driven, nunca hardcodeado** — todo valor de juego vive en catálogo/config; el código lee por `id`.
- Required: **tipado estático obligatorio**.
- Forbidden: sistemas Core como autoloads (son nodos del mundo, patrón Economía).

---

## Acceptance Criteria

*Del GDD, acotados a esta historia:*

- [ ] **AC-DM01** `[Unit]` — GIVEN `poblacion=90000`, `tasa_base_doc=0.5` WHEN F1 THEN `demanda_dia_doc = 45`.
- [ ] **AC-DM02** `[Unit]` — GIVEN `tasa_base_odac=0.4` WHEN F1 THEN `demanda_dia_odac = 36` (< Documentación).
- [ ] **AC-DM03** `[Unit]` — GIVEN perfil Doc (45/día), hora 08–09 (pico, peso 0.30), jornada ×1.3 WHEN F2 THEN `Σ pesos = 1.0` y llegadas esperadas ≈ **17,6**.
- [ ] **AC-DM04** `[Unit]` — GIVEN perfil ODAC (36/día) y `mult_nocturno_odac=0.5` WHEN se suma la franja 00:00–07:00 THEN el total nocturno = valor **derivado** de config (sin hardcode) y **escala proporcional** con otra `poblacion`. *(⚠️ errata GDD: dice "≈10"; con las semillas actuales el valor derivado es ≈5 — ver Nota de calibración.)*
- [ ] **AC-DM12** `[Unit]` — GIVEN semillas MVP (Doc 45, ODAC 36) y capacidades máx (Doc 260, ODAC 128) WHEN se comprueba R5 THEN `demanda_dia ≤ capacidad_max` (se cumple; el guardián en carga es Datos, no Demanda).
- [ ] **AC-DM13** `[Unit]` — GIVEN `factor_crecimiento_nivel=1.5` WHEN se aplica THEN la tasa efectiva sube ×1.5.
- [ ] **AC-DM19** `[Unit]` — GIVEN `tasa_base=0` o `poblacion=0` WHEN F1 THEN `demanda_dia=0` (grifo cerrado = config válida, sin error).
- [ ] **AC-DM20 (nuevo, pedido del usuario 2026-07-23)** `[Unit]` — GIVEN otra `poblacion` (p. ej. 30.000) WHEN F1/F2 THEN todo el volumen escala **exactamente proporcional** (×30000/90000); **prohibido** cualquier `90000` (u otro valor de juego) hardcodeado en `src/`.

---

## Implementation Notes

*Derivadas de ADR-0003 + patrón Economía (eco-001):*

- **`src/core/demanda/demanda.gd`** — nodo (`class_name Demanda extends Node`), NO autoload. En esta historia solo el esqueleto + las funciones de volumen (puras, testeables sin escena).
- **`src/core/demanda/config_demanda.gd`** — `class_name ConfigDemanda extends Resource`, solo `@export` tipados:
  `tasa_base_doc=0.5`, `tasa_base_odac=0.4` *(F1/AC-DM02; la tabla Tuning del GDD dice 0.5 — errata, ver Nota)*,
  `perfil_hora_doc: Dictionary[int, float]` = {8:0.30, 9:0.22, 10:0.16, 11:0.12, 12:0.10, 13:0.07, 14:0.03} *(la franja 14 dura 30 min)*,
  `perfil_hora_odac: Dictionary[int, float]` = uniforme 1/24 por hora *(semilla simple; el matiz "decae 22–23h" es tuning, Open Q2/Q5)*,
  `mult_nocturno_odac=0.5`, `mult_dia_semana=1.0`, `max_llegadas_por_tick=3`, `factor_crecimiento_nivel=1.0`,
  `ventana_doc_inicio=480` (08:00), `ventana_doc_fin=870` (14:30) *(provisional — la ventana la poseerá Documentación #8)*,
  `mezcla_doc` y `mezcla_odac` (para la 002), `umbral_nivel_bajo=40` / `umbral_nivel_alto=60` (para la 004, Open Q9),
  `mult_estacional: Dictionary[int, float]` y eventos (para la 005).
- **`tools/build_config_demanda.gd`** → genera `datos/config/demanda.tres` en headless (patrón `build_config_economia.gd`).
- **Funciones puras** en `demanda.gd`: `tasa_efectiva(servicio)` (= tasa_base × factor_crecimiento — el mult estacional se suma en la 005), `demanda_dia(servicio)` (F1, lee `poblacion` del `Escenario` vía Datos — **nunca** literal), `llegadas_esperadas_hora(min_dia, servicio)` (F2) y `densidad_por_minuto(min_dia, servicio)` = `demanda_dia × peso_franja / duracion_franja_min` *(la franja 14:00–14:30 dura 30 min, no 60 — sin esto se pierde la mitad de su demanda)*. A ODAC en horas 0–6 se le aplica `mult_nocturno_odac` sobre el peso.
- `aplicar_config(config: Resource)` + `_cargar_config()` con clamps de rangos seguros (patrón Economía).
- La `poblacion` llega por el escenario activo: `Datos.obtener(&"escenario", &"pozuelo")` (o el escenario que se inyecte — dejar `fijar_escenario(id)` inyectable para tests y futuros niveles).

**Nota de calibración (erratas del GDD detectadas al trocear, propagar cuando se toque el GDD):**
1. Tuning Knobs dice `tasa_base_odac` default **0.5**, pero F1/AC-DM02/F5 usan **0.4** (→36/día). Se implementa **0.4**.
2. "≈10 atenciones nocturnas en Pozuelo" no cuadra con 36/día × (7/24) × 0.5 ≈ **5,25**. El "≈10" viene del ancla vieja de ODAC. El test valida el valor **derivado de config** y la proporcionalidad, no el literal 10. Ambas erratas quedan anotadas para `/consistency-check` o edición del GDD (Open Q5 ya cubre el tuning de la noche).

---

## Out of Scope

*Lo hacen las historias vecinas — no implementar aquí:*

- Story 002: acumulador, mezcla ponderada, creación de fichas Persona.
- Story 003: suscripción al tick, ventana en runtime, emisión al bus.
- Story 004/005: nivel BAJA/MEDIA/ALTA, estacionalidad y eventos (los knobs ya quedan en config).
- Story 006/007: save/load, instancia en Main y HUD.

---

## QA Test Cases

*Escritos por el hilo principal (modo lean). El desarrollador implementa contra estos casos.*

- **AC-DM01/02**: Given config semilla + escenario 90.000 → When `demanda_dia` → Then Doc=45.0 y ODAC=36.0 (exactos, `assert_float`).
- **AC-DM03**: Given perfil Doc → When se suman los pesos → Then Σ=1.0 (±0.0001). Given hora 08:30, jornada 1.3 → When `llegadas_esperadas_hora` → Then ≈17.55 (±0.1).
- **AC-DM04**: Given perfil ODAC y mult 0.5 → When se integra la densidad de 00:00 a 07:00 → Then total = `36 × (7/24) × 0.5` = 5.25 (±0.1); Given `poblacion=180000` → Then el doble (10.5). Edge: mult=1.0 → 10.5 (sin valle).
- **AC-DM12**: Given demanda_dia semilla → Then 45 ≤ 260 y 36 ≤ 128 (asserts de calibración con los topes del GDD F5).
- **AC-DM13**: Given factor 1.5 → Then `tasa_efectiva` = 0.75 (Doc) y demanda_dia = 67.5.
- **AC-DM19**: Given tasa 0 → Then demanda_dia = 0 y densidad = 0 en toda hora; Given poblacion 0 → ídem. Sin push_error.
- **AC-DM20**: Given escenario de test con poblacion 30000 → Then demanda_dia_doc = 15.0 (proporcional exacto). Además: grep de la suite/review — ningún literal 90000 en `src/core/demanda/`.
- Edge cases: hora fuera de la ventana Doc → densidad Doc = 0 (la función lo devuelve; el runtime lo usa en la 003).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/demanda/demanda_volumen_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [x] Creado y en verde (17 tests; suite total 190/190, exit 0 — 2026-07-23)

---

## Dependencies

- Depends on: None (Foundation 5/5 completa; catálogo y Escenario ya existen).
- Unlocks: Story 002 (generador), y deja los knobs listos para 003–005.
