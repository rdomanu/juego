# Story 007: Integración `_physics_process` — tick + determinismo + presupuesto

> **Epic**: Sistema de Tiempo
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/time-system.md` (Core Rules 1.3 — acumula tiempo real, idéntico a cualquier FPS; F2; Interacciones — fuente única; AC-T33/T35/T36 — presupuesto, determinismo, fuente única)
**Requirement**: `TR-time-001` (paso fijo del tick) · `TR-time-007` (fuente **única** de tiempo) · `TR-time-009` (update < 0,1 ms, AC-T33)

**ADR Governing Implementation**: ADR-0001: Bus de eventos, tick y orden determinista *(primario)*
**ADR Decision Summary**: toda la lógica de simulación corre en **`_physics_process`** (paso fijo, 60 Hz por defecto). Tiempo calcula `delta_juego = delta_fijo × escala × mult` (0 en Pausa) y **empuja** el tick a los sistemas en orden fijo (Tiempo → Demanda → Flujo → Paciencia). El **dibujado** (UI/HUD/Feedback) corre en `_process` (variable). El paso fijo da determinismo y es lo que `NavigationAgent2D` necesita. El reloj es la **fuente única**: nadie más mantiene un contador.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `_physics_process(delta)` entrega un `delta` **fijo** (~0.016667 a 60 Hz) e independiente de los FPS de dibujado (verificado en ADR-0001 contra la doc oficial de Idle/Physics Processing). Para medir el presupuesto: **`Time.get_ticks_usec()`** (microsegundos), **NO** `OS.get_ticks_msec()` (deprecado/menos preciso — gotcha del proyecto).

**Control Manifest Rules (Foundation)**:
- Required: la lógica del reloj corre en **`_physics_process`** (paso fijo); `delta_juego = delta_fijo × escala × mult`; el reloj es la **fuente única** (nadie más mantiene un contador de tiempo); hook documentado del tick (lista de suscriptores).
- Forbidden: **nunca** correr la lógica del reloj en `_process` (variable → no determinista); **nunca** leer la hora real del sistema en la lógica; **nunca** llamar a Demanda/Flujo/Paciencia **por nombre** (aún no existen; el hook es una lista de callables/suscriptores, no nombres).
- Cross-cutting: determinismo (misma secuencia de deltas → idéntico); rendimiento (< 0,1 ms).

---

## Acceptance Criteria

*De GDD AC-T33/T35/T36. Valores transcritos exactos de los AC-T del GDD:*

- [x] **AC-T33**: GIVEN el reloj a 3× con `escala=12` (peor caso) WHEN se mide el update del reloj durante **1000 frames** THEN el tiempo medio del update es **< 0,1 ms** (< 0,6 % del presupuesto de 16,6 ms a 60 FPS). *(Hardware de referencia = Open Question del GDD; ver Implementation Notes — umbral holgado, NO gate bloqueante.)*
- [x] **AC-T35**: GIVEN la **misma secuencia de deltas** aplicada dos veces desde idéntico estado WHEN se ejecutan THEN `minutos_juego`, turno y señales son **idénticos** (sin dependencia de fecha/hora real del sistema ni semillas aleatorias).
- [x] **AC-T36** `[Integration]`: GIVEN Flujo, Demanda y Documentación activos WHEN cada uno consulta la hora THEN los tres devuelven el **mismo `minutos_del_dia`** del Sistema de Tiempo (ninguno mantiene su propio contador). *(MVP: como esos sistemas aún no existen, el test verifica el principio: **múltiples consultores leen el mismo valor del único reloj** y no hay un segundo contador — ver Implementation Notes.)*

---

## Implementation Notes

- **El tick real**: `_physics_process(delta: float)` en `tiempo.gd`:
  ```
  _physics_process(delta):
      avanzar(delta)            # H1: acumula delta_juego = delta * escala * mult (clampado)
      _procesar_cruces()        # H4: turno / dia-noche
      _procesar_medianoche()    # H5: calendario + nuevo_dia/nuevo_mes
      # (el "empuje" del tick a Demanda/Flujo/Paciencia es un HOOK documentado, ver abajo)
  ```
  `delta` de `_physics_process` es el **paso fijo**; `avanzar()` ya multiplica por escala×mult y clampa. En Pausa (mult 0) el avance es 0 → todo lo demás no ocurre (no hay cruces).
- **Hook del tick (documentado, sin nombres)**: el ADR-0001 define que Tiempo **empuja** el tick a Demanda→Flujo→Paciencia en orden fijo. Como esos sistemas **aún no existen**, esta story deja un **hook explícito**: una lista de suscriptores (`Array[Callable]` o señal `tick_simulacion(delta_juego)`) que los sistemas de Core se registrarán a consumir en su epic. **NUNCA** llamar a `Demanda`/`Flujo`/`Paciencia` por nombre (violaría las capas — ADR-0001). Documentar el orden esperado en el comentario del hook.
- **Fuente única (AC-T36)**: el reloj expone getters (`minutos_del_dia`, `hora`, `turno`, `es_de_noche`, `mes`/`semana`/`anio`). Los sistemas **leen** estos getters; ninguno guarda su propio contador. Como los consumidores reales no existen en el MVP, el test simula 2-3 "consultores" que leen el getter y comprueba que devuelven el mismo valor y que Tiempo es el único que lo incrementa.
- **Determinismo (AC-T35)**: aplicar dos veces la misma secuencia de `delta` desde el mismo estado inicial → mismo `minutos_juego`, mismo turno, mismas señales. **Nunca** leer `Time.get_datetime_*`/hora real del sistema en la lógica (solo `delta` inyectado por el motor). Sin RNG en el reloj.
- **Presupuesto (AC-T33)** — **DECISIÓN aprobada (2026-07-22)**: medir con `Time.get_ticks_usec()` alrededor del update, promediar 1000 frames en el peor caso (3×, escala 12). El **hardware de referencia es una Open Question del GDD**, así que el AC se implementa con un **umbral holgado y documentado** y **NO como gate bloqueante**: si en la máquina de CI/desarrollo el medio supera 0,1 ms, se registra el número real y se anota (no rompe el sprint). El coste real del reloj es aritmética trivial → se espera muy por debajo.
- **`_process` vs `_physics_process`**: la lógica del reloj va en `_physics_process` (determinismo). Lo único que puede ir en `_process` es dibujo/HUD (H9), no el reloj.

## Out of Scope

- Los **sistemas consumidores** (Demanda/Flujo/Paciencia/Documentación): no se implementan; solo el **hook** y los getters que ellos usarán. Sus tests reales viven en sus epics.
- **H8**: serialización.
- **H9**: el HUD que dibuja la hora (corre en `_process`).
- Fijar el hardware de referencia del AC-T33 (Open Question del GDD; spike de rendimiento futuro).

## QA Test Cases

*Integration — el reloj corriendo en su tick. Determinista. `tests/integration/tiempo/`.*

- **`test_determinismo_misma_secuencia_deltas`** (AC-T35): dos ejecuciones con la misma lista de deltas desde el mismo estado → `minutos_juego`, turno y lista de señales idénticos. *(Registrar señales en una lista y comparar.)*
- **`test_fuente_unica_varios_consultores_mismo_valor`** (AC-T36): tras avanzar, N "consultores" leen `minutos_del_dia` del reloj → todos iguales; ningún consultor mantiene su propio acumulador (se verifica que solo Tiempo lo incrementa).
- **`test_presupuesto_update_bajo_umbral`** (AC-T33): 1000 frames a 3×/escala 12 midiendo con `Time.get_ticks_usec()` → media registrada; assert **advisory** (< 0,1 ms esperado; si falla, log del número real, no bloquea). Documentar la máquina de medición.
- **`test_pausa_no_avanza_en_tick`**: con PAUSA, correr N `_physics_process` → `minutos_juego` no cambia y no hay cruces.

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/tiempo/tiempo_integracion_test.gd` — debe existir y pasar (BLOCKING para T35/T36; T33 es advisory).

**Status**: [x] Creado y PASA (tiempo_integracion_test.gd 5/5; suite 107/107, 2026-07-23)

## Dependencies

- Depends on: **Story 004** (cruces de turno/día-noche que el tick procesa) y **Story 006** (el multiplicador que el tick aplica). *(Implícitamente también H5, que corre dentro del mismo tick; ordenar la implementación H4→H5→H6→H7.)*
- Unlocks: **H8** (serialización del reloj ya corriendo) y **H9** (el esqueleto que instancia el reloj real en una escena).

## Notas de headless (gotcha del proyecto)

Preload por ruta literal de `tiempo.gd`. Para test de `_physics_process` sin ventana, instanciar el nodo en el árbol del test y **llamar `_physics_process(dt)` manualmente** con deltas fijos (no depender del bucle real del motor headless) — así el test es determinista y no depende del scheduler. Medir con `Time.get_ticks_usec()`, **nunca** `OS.get_ticks_msec()`. **Nunca** hora real del sistema en la lógica.

## Cierre (2026-07-23)

Implementada via subagente godot-gdscript-specialist (Opus) + verificacion independiente del hilo
principal (suite 107/107, exit 0). Commit d54246e. T33 medido como ADVISORY con umbral holgado
documentado (hardware objetivo = Open Question del GDD).
