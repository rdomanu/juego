# Story 002: Escala configurable data-driven + clamp [3,12]

> **Epic**: Sistema de Tiempo
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: (lo fija /dev-story al empezar)

## Context

**GDD**: `design/gdd/time-system.md` (Core Rules 3 — escala del reloj; F1 — `escala_tiempo`; Tuning Knobs; Edge Cases — clamp de `escala_tiempo` a [3,12])
**Requirement**: `TR-time-001` (parte data-driven: la escala y los límites de turno **no están incrustados en el código**; se leen de config)

**ADR Governing Implementation**: ADR-0001 *(primario)* · ADR-0002 *(sec. — el `.tres` de config es contenido del desarrollador, no del save del jugador)*
**ADR Decision Summary**: los valores de gameplay son **data-driven** (coding-standards: nunca hardcodear). La config del reloj vive en un Resource tipado propio (`.tres` del desarrollador), no en el save del jugador. `escala_tiempo` es el valor **más sensible** del juego (driver nº1 del ritmo) → debe ser retuneable sin tocar código.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `class_name` + `@export` estables en 4.6. `load()` de un `.tres` del propio desarrollador es seguro (a diferencia del save del jugador — ADR-0002). Defaults seguros si el `.tres` falta o no carga.

**Control Manifest Rules (Foundation)**:
- Required: `escala_tiempo` y los límites de turno se **leen de config** (`ConfigTiempo`), nunca hardcodeados; `escala_tiempo` se **clampa al rango seguro [3, 12]** con aviso en el log; defaults seguros si falta el config.
- Forbidden: nunca incrustar `escala_tiempo`/límites de turno en el código; nunca permitir escala ≤ 0 (reloj congelado) ni negativa (reloj hacia atrás).
- Cross-cutting: determinismo; tipado estático.

---

## Acceptance Criteria

*De GDD F1/Tuning + Edge Cases (clamp de escala). Valores transcritos de los AC-T del GDD:*

- [ ] **AC-T28**: GIVEN se configura `escala_tiempo=0` (o ≤0) WHEN se procesa THEN queda en **`3.0`** (mínimo) y se registra **aviso** en el log.
- [ ] **AC-T29**: GIVEN se configura `escala_tiempo=15` (fuera de 3–12) WHEN se procesa THEN queda en **`12.0`** (máximo) y se registra **aviso**.
- [ ] **AC-T34** *(parte de escala/config)*: GIVEN un config con `escala_tiempo=6`, `inicio_mañana=360`, `inicio_tarde=840`, `inicio_noche=1320` WHEN se inicializa leyendo ese config (sin tocar código) THEN el reloj usa **esos valores exactos**; **ningún** límite de turno ni `escala_tiempo` está incrustado en el código. *(El uso de los límites de turno en el cálculo se completa en H3/H4; aquí se verifica que se LEEN exactos del config y que `escala=6` está dentro de [3,12] y se respeta sin clamp.)*

---

## Implementation Notes

**DECISIÓN aprobada (2026-07-22)**: la config del reloj es un **Resource tipado propio** `ConfigTiempo`, no un `Dictionary` suelto ni el catálogo de Datos (el reloj es Foundation raíz y no debe depender del autoload `Datos`).

- **Clase**: `src/foundation/tiempo/config_tiempo.gd` — `extends Resource` (SIN `class_name` conflictivo con autoloads; `class_name ConfigTiempo` es seguro aquí porque **no** hay un autoload homónimo). Campos `@export`:
  - `escala_tiempo: float` (default **4.0**)
  - `inicio_manana: int` (default **420** = 07:00)
  - `inicio_tarde: int` (default **900** = 15:00)
  - `inicio_noche: int` (default **1380** = 23:00)
  - `jornadas_por_mes: int` (default **4**)
  - `delta_max_por_frame: float` (default **0.5**)
- **`.tres`**: `res://datos/config/tiempo.tres`, **generado por herramienta**, NUNCA a mano (regla del proyecto: los `.tres` los materializa una herramienta/el editor, no se editan a pelo).
- **Carga**: `Tiempo` en `_ready` hace `load("res://datos/config/tiempo.tres")`; si falta o no es un `ConfigTiempo` válido → usa **defaults seguros** (construye un `ConfigTiempo.new()` con los defaults) y registra un aviso. **No** peta si falta.
- **Clamp de escala**: al aplicar el config, `escala_tiempo = clampf(escala_tiempo, 3.0, 12.0)`; si el valor original estaba fuera de rango, `push_warning(...)` (aviso en el log). El clamp protege el motor de un dato corrupto/mod (GDD Edge Case).
- **T34**: los tests inyectan un `ConfigTiempo` con valores custom (escala 6, límites 360/840/1320) y verifican que el reloj los usa **exactos**; ninguna constante de escala/límite vive en `tiempo.gd`.
- La constante `MINUTOS_DIA = 1440` **sí** es una constante del código (no es un tuning knob de gameplay; es la definición de "día de 24 h").

## Out of Scope

- **H1**: el acumulador (ya existe; aquí solo pasa a leer `escala`/`delta_max` del config en vez de defaults fijos).
- **H3/H4**: **usar** los límites de turno para calcular turno/`es_de_noche` y emitir eventos. Aquí solo se leen y almacenan; su uso viene después.
- **Herramienta que genera el `.tres`**: si no existe aún, la story puede crear el `.tres` vía un pequeño script `@tool`/editor; **nunca** escribirlo a mano. El contenido de balance real (valor final de `escala`) es Open Question del GDD (playtest).
- **H8**: la config **no** se serializa en el save del jugador (es contenido del desarrollador); el save guarda el estado del reloj, no su config.

## QA Test Cases

*Logic — inyectando `ConfigTiempo`. Determinista. `tests/unit/tiempo/`.*

- **`test_escala_cero_clampa_a_3`** (AC-T28): config con `escala_tiempo=0` → tras aplicar, escala efectiva `== 3.0` (+ aviso).
- **`test_escala_alta_clampa_a_12`** (AC-T29): config con `escala_tiempo=15` → escala efectiva `== 12.0` (+ aviso).
- **`test_escala_negativa_clampa_a_3`**: `escala_tiempo=-2` → `3.0` (nunca reloj hacia atrás).
- **`test_config_custom_se_respeta_exacto`** (AC-T34): config `escala=6`, límites `360/840/1320` → el reloj expone/usa exactamente esos valores (escala 6 dentro de rango, sin clamp).
- **`test_falta_config_usa_defaults`**: `load` devuelve null / ruta inexistente → escala 4,0, límites 420/900/1380, sin petar (+ aviso).

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tiempo/tiempo_config_test.gd` — debe existir y pasar (BLOCKING).

**Status**: not yet created

## Dependencies

- Depends on: **Story 001** (el acumulador que ahora lee escala/`delta_max` del config).
- Unlocks: H3 (usa los límites de turno leídos aquí), H6 (la escala base para los multiplicadores).

## Notas de headless (gotcha del proyecto)

Preload por ruta literal de `tiempo.gd` y `config_tiempo.gd` en los tests headless. Para inyectar config sin depender del `.tres` en disco, construir `ConfigTiempo.new()` en el test y pasarlo (inyección de dependencia > singleton) — así el test no toca I/O ni el `.tres` real.
