# Story 001: Reloj base — acumulador `minutos_juego` + clamp anti-salto

> **Epic**: Sistema de Tiempo
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-22

## Context

**GDD**: `design/gdd/time-system.md` (Core Rules 1 — modelo de tiempo; F2 — avance del reloj por frame; Edge Cases — clamp anti-salto y módulo 1440)
**Requirement**: `TR-time-001` (reloj acumula tiempo real `delta`, no frames → mismo resultado a cualquier FPS) · `TR-time-005` (clamp de `delta` por frame, anti-salto tras alt-tab/lag)

**ADR Governing Implementation**: ADR-0001: Bus de eventos, tick de simulación y orden determinista *(primario)*
**ADR Decision Summary**: la simulación corre en `_physics_process` de paso fijo; el reloj **acumula `delta`** (no cuenta frames) → determinismo. Esta story implementa el **acumulador puro** (`avanzar(delta)`); el enganche a `_physics_process` es H7 y la emisión de eventos de cruce es H4/H5.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: pura aritmética sobre un `float`. Sin APIs de motor en la lógica del acumulador. El `delta` real lo entregará el motor en H7; aquí `avanzar(delta_real)` es una función **pura y testeable** que recibe el delta por parámetro (inyección) — no lee el reloj del sistema ni `_physics_process` todavía.

**Control Manifest Rules (Foundation)**:
- Required: el reloj **acumula `delta`** en un `float` (`minutos_juego`), nunca cuenta frames; clamp de `delta` por frame antes de acumular; `minutos_juego` se mantiene en `[0, 1440)` (módulo 1440).
- Forbidden: **nunca** leer la hora real del sistema (`Time.get_datetime_*`, `OS.get_*`) en la lógica del reloj (rompería el determinismo); nunca contar frames; el autoload va **SIN `class_name`** (ver Implementation Notes).
- Cross-cutting: determinismo (mismo delta → mismo resultado); tipado estático.

---

## Acceptance Criteria

*De GDD F2 (avance del reloj) + Edge Cases (clamp anti-salto, módulo medianoche). Valores transcritos de los AC-T del GDD:*

- [x] **AC-T01**: GIVEN 1× con `escala_tiempo=4` WHEN `avanzar(delta_real=1.0)` THEN `minutos_juego` sube exactamente **4,0 min** (±0,001).
- [x] **AC-T02**: GIVEN 2× (`escala=4`) WHEN `avanzar(1.0)` THEN sube **8,0 min**.
- [x] **AC-T03**: GIVEN 3× (`escala=4`) WHEN `avanzar(1.0)` THEN sube **12,0 min**.
- [x] **AC-T04**: GIVEN Pausa (mult 0) WHEN cualquier `avanzar(delta_real>0)` THEN `minutos_juego` **no cambia** (incremento 0).
- [x] **AC-T05**: GIVEN 1× (`escala=4`) WHEN se acumulan **360,0 s** de `delta_real` THEN el reloj recorre **1440 min** y vuelve a **00:00** del día siguiente (módulo 1440; envuelve).
- [x] **AC-T25**: GIVEN `delta_max_por_frame=0.5 s`, 1× (`escala=4`) WHEN el motor entrega `delta_real=30.0 s` (alt-tab) THEN el reloj solo avanza `4×1×0.5=**2,0 min**`, no 120,0 min (el `delta` se clampa **antes** de acumular).

---

## Implementation Notes

- **Ubicación**: `src/foundation/tiempo/tiempo.gd`. **Autoload SIN `class_name`** (igual que `event_bus.gd` y `rng_service.gd`): un autoload llamado `Tiempo` **más** un `class_name Tiempo` homónimo colisionaría (el nombre global del singleton choca con el nombre de la clase). Registrar el autoload `Tiempo` como **4º** en `project.godot` (tras `EventBus`, `RNGService`, `Datos`).
- **Función pura del acumulador** (el corazón de la story):
  ```
  avanzar(delta_real: float) -> void:
      minutos_juego += escala_tiempo * multiplicador_velocidad * min(delta_real, delta_max_por_frame)
      # módulo 1440: envuelve al cruzar medianoche (los EVENTOS de cruce son H4/H5, aquí solo envuelve)
  ```
  con `delta_max_por_frame = 0.5` (constante en esta story; en H2 pasa a venir del config).
- **Acumular en `float`** antes de convertir a HH:MM (evita errores de truncado — GDD F2). `minutos_juego` es `float`.
- **Módulo 1440**: al pasar de 1440, restar 1440 (o `fmod`). Esta story solo **envuelve el valor**; NO emite `nuevo_dia` ni ningún evento (eso es H4/H5). Un test verifica que tras 360 s a 1× el valor vuelve cerca de 0.
- **Valores por defecto seguros en esta story** (aún sin config): `escala_tiempo = 4.0`, `multiplicador_velocidad = 1`, `delta_max_por_frame = 0.5`. En H2 pasan a ser data-driven; aquí como constantes/vars con default para poder testear el acumulador aislado.
- **Determinismo**: `avanzar()` recibe el `delta` por parámetro → los tests inyectan secuencias fijas de deltas. **Nunca** leer la hora del sistema aquí.
- **Gotcha `self.` (footgun de autoloads)**: si algún método interno se llamara igual que una utilidad global de GDScript (p. ej. `min`, `clamp`) NO aplica aquí (no sombreamos ninguna); pero si en el futuro se añade un método homónimo de una global, cualificar la llamada con `self.` (patrón ya visto en `rng_service.gd` con `randf`/`randi`).

## Out of Scope

- **H2**: escala/límites data-driven desde `ConfigTiempo` + clamp de escala a [3,12]. Aquí la escala es un default fijo.
- **H3**: conversiones hora↔minutos, turno, `es_de_noche`.
- **H4/H5**: emitir eventos de cruce (`cambio_de_turno`, `cambio_dia_noche`, `nuevo_dia`, `nuevo_mes`). Esta story solo **envuelve** el acumulador; no dispara nada.
- **H6**: máquina de velocidad (aquí `multiplicador_velocidad` es una var simple; la lógica Pausa/1×/2×/3× es H6).
- **H7**: enganche a `_physics_process` (aquí `avanzar()` se llama desde los tests, no desde el motor).
- **H8**: serialización.

## QA Test Cases

*Logic — acumulador puro, determinista. `tests/unit/tiempo/`.*

- **`test_avance_1x_escala4_sube_4min`** (AC-T01): `avanzar(1.0)` a 1×/escala 4 → `minutos_juego == 4.0` (±0,001).
- **AC-T02/T03**: mismo con mult 2 y 3 → 8,0 y 12,0.
- **`test_pausa_mult0_no_avanza`** (AC-T04): mult 0, `avanzar(1.0)` → `minutos_juego` sin cambio.
- **`test_dia_completo_360s_vuelve_a_cero`** (AC-T05): acumular 360 s (p. ej. 360 llamadas de 1,0 s, o deltas pequeños) a 1×/escala 4 → recorre 1440 min y `minutos_juego` vuelve a ~0 (envuelve). *(Cuidar el epsilon de float.)*
- **`test_delta_grande_se_clampa_a_max`** (AC-T25): `avanzar(30.0)` a 1×/escala 4 con `delta_max=0.5` → sube solo 2,0 min.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tiempo/tiempo_reloj_test.gd` — debe existir y pasar (BLOCKING).

**Status**: [x] Creado y PASA (tiempo_reloj_test.gd 6/6; suite 79/79, 2026-07-22)

## Dependencies

- Depends on: **None** (es la base del epic Foundation raíz).
- Unlocks: H2 (config), H3 (conversiones), H4/H5 (eventos), H6 (velocidad), H7 (integración), H8 (save).

## Notas de headless (gotcha del proyecto)

En los tests headless, si el runner corre "en frío" sin el proyecto importado, **preload por ruta literal** el script bajo test (`preload("res://src/foundation/tiempo/tiempo.gd")`) en lugar de depender de resolución por nombre de autoload. Patrón ya usado en los tests de `datos`/`rng_service`.

## Cierre (2026-07-22)

Implementada vía subagente godot-gdscript-specialist (Opus) + verificación independiente del hilo
principal (suite 79/79, exit 0). Commit 67c118b.
