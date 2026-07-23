# Story 007: Registro autoload 5º + smoke

> **Epic**: SaveManager (guardado y carga)
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**Fuente**: `docs/architecture/adr-0002-guardado-serializacion.md` (Decision 6 + "Ordering Note: Foundation. Aceptar antes de codificar sistemas con estado mutable"; ADR Dependencies — "ADR-0003: el catálogo debe estar cargado antes de `load_state`") y `control-manifest.md` ("Orden de autoloads: `EventBus → RNGService → Datos → Tiempo → SaveManager` — Datos valida el catálogo en su `_ready` … Tiempo arranca en Pausa"). *(SPEC = ADR-0002; sin GDD.)*
**Requirement**: `TR-save-001` (el `SaveManager` como autoload Foundation que orquesta el guardado/carga).

**ADR Governing Implementation**: ADR-0002: Guardado / serialización *(primario)* · ADR-0003 *(sec. — el orden garantiza que Datos validó el catálogo antes de cualquier `load_state`)*
**ADR Decision Summary**: el `SaveManager` es un autoload Foundation. Se registra **el 5º**, DESPUÉS de Tiempo, para que en el arranque el orden sea `EventBus → RNGService → Datos → Tiempo → SaveManager`: cuando el manager exista y pueda cargar, Datos (3º) ya validó el catálogo y Tiempo (4º) ya arrancó en Pausa — así cualquier `load_state` posterior encuentra el catálogo listo (invariante de ADR-0003). El smoke confirma que el juego arranca con los 5 autoloads sin errores y que un guardar/cargar real funciona una vez de punta a punta.

**Engine**: Godot 4.6 | **Risk**: LOW *(edición de `project.godot` — sección `[autoload]`; el riesgo real es el ORDEN, no la API)*
**Engine Notes**:
- Registro en `project.godot`, sección `[autoload]`: `SaveManager="*res://src/foundation/save_manager/save_manager.gd"` (el `*` marca el singleton habilitado). Debe quedar DESPUÉS de la línea de `Tiempo` (el orden de las líneas en la sección `[autoload]` ES el orden de carga).
- El script del autoload va **SIN `class_name`** (colisión con el nombre del singleton) — ya definido así desde la Story 002.
- El smoke corre el juego real (no solo headless de tests): `godot --headless` para el arranque limpio + la suite completa (`godot --headless --script tests/gdunit4_runner.gd`) con exit 0.

**Control Manifest Rules (Foundation)**:
- Required: orden de autoloads `EventBus → RNGService → Datos → Tiempo → SaveManager`. — ADR-0002/0003. Autoload SIN `class_name`. `user://`.
- Forbidden: registrar `SaveManager` ANTES de Datos/Tiempo (rompería el invariante "catálogo cargado antes de `load_state`"); registrar con `class_name`; guardar en `res://`.
- Cross-cutting: orden determinista de inicialización; robustez del arranque.

---

## Acceptance Criteria

- [x] **AC-SM01**: GIVEN `project.godot` WHEN se lee la sección `[autoload]` THEN `SaveManager` está registrado como `*res://src/foundation/save_manager/save_manager.gd` y aparece DESPUÉS de `Tiempo` (5º autoload; orden `EventBus → RNGService → Datos → Tiempo → SaveManager`).
- [x] **AC-SM02**: GIVEN el juego arrancado en headless WHEN se inicializan los autoloads THEN NO hay errores en la salida (los 5 autoloads cargan; el `_ready` de SaveManager no peta).
- [x] **AC-SM03**: GIVEN el juego arrancado WHEN se hace UN `guardar_partida()` seguido de UN `cargar_partida()` THEN ambos devuelven `true` sin errores (smoke de punta a punta con el singleton real).
- [x] **AC-SM04**: GIVEN la suite completa de tests WHEN corre en CI headless THEN pasa con exit 0 (ningún test roto por el nuevo autoload).

---

## Implementation Notes

- **Registro en `project.godot`** (sección `[autoload]`), como **5ª** línea, tras `Tiempo`:
  ```
  [autoload]
  EventBus="*res://src/foundation/event_bus/event_bus.gd"
  RNGService="*res://src/foundation/rng_service/rng_service.gd"
  Datos="*res://src/foundation/datos/datos.gd"
  Tiempo="*res://src/foundation/tiempo/tiempo.gd"
  SaveManager="*res://src/foundation/save_manager/save_manager.gd"
  ```
  *(Las rutas de EventBus/RNGService/Datos/Tiempo son las existentes; la ÚNICA línea nueva es `SaveManager=...`. Verificar los nombres/rutas exactos de las 4 previas antes de editar — no reescribir la sección, solo AÑADIR la línea de SaveManager en la posición correcta.)*
- **Por qué el 5º (no antes)**: el orden garantiza que Datos (3º) validó el catálogo y Tiempo (4º) arrancó en Pausa ANTES de que el manager pueda cargar. Si el manager cargara un save y llamara a `load_state` de un sistema que referencia `id`s del catálogo, el catálogo YA está listo (invariante ADR-0003). En el MVP los dos Persist (RNGService, Tiempo) no referencian el catálogo, pero el orden se fija ya para cuando lo hagan Construcción/Flujo.
- **`_ready` del SaveManager**: el manager NO necesita `add_to_group("Persist")` (él orquesta, no se guarda a sí mismo). Su `_ready` puede quedar vacío o solo con logging de arranque. NO debe llamar a `cargar_partida` automáticamente (cargar es una acción del jugador / de un flujo de arranque posterior, fuera de este epic).
- **Smoke**:
  1. Arranque limpio headless → sin errores de autoload (AC-SM02).
  2. Un `guardar_partida()` + un `cargar_partida()` reales (desde un script de smoke o el runner) → ambos `true` (AC-SM03).
  3. Suite completa verde, exit 0 (AC-SM04).
- **Evidencia**: documentar el smoke en `production/qa/smoke-2026-07-23.md` (arranque OK + guardar/cargar OK + suite verde con el conteo de tests) y adjuntar el exit code de la suite.

## Out of Scope

- La **UI** de guardar/cargar (menú, botón, slots): fuera del MVP del epic.
- La **carga automática al arrancar** (continuar partida): flujo de arranque posterior, no este epic.
- Los `save()`/`load_state()` de **otros** sistemas: sus epics (el orden 5º los deja listos para cuando existan).

## QA Test Cases

*Integration — arranque real + smoke de guardar/cargar + suite. `production/qa/smoke-2026-07-23.md` + suite verde.*

- **`test_autoload_registrado_orden`** (AC-SM01): verificar en `project.godot` que `SaveManager` está tras `Tiempo` en `[autoload]` (puede ser un check del smoke doc o un test que lea `ProjectSettings`).
- **Smoke AC-SM02**: `godot --headless` arranca sin errores de autoload (capturar la salida; 0 errores).
- **Smoke AC-SM03**: un guardar + un cargar reales → ambos `true`; documentado en el smoke doc.
- **Smoke AC-SM04**: `godot --headless --script tests/gdunit4_runner.gd` → exit 0 con la suite completa (anotar el conteo total de tests, incl. los nuevos de save_manager).

## Test Evidence

**Story Type**: Integration (arranque real + smoke)
**Required evidence**: `production/qa/smoke-2026-07-23.md` (arranque + guardar/cargar OK) + suite completa verde (exit 0). ADVISORY para el smoke doc; la suite verde es BLOCKING.

**Status**: [x] PASA — smoke doc production/qa/smoke-2026-07-23.md (SMOKE_OK guardar/cargar true; suite 135/135 exit 0)

## Dependencies

- Depends on: **Story 006** (con el round-trip verde, registrar el autoload y hacer el smoke de arranque real es el cierre — no tiene sentido registrar el singleton antes de que el ciclo funcione).
- Unlocks: el epic **SaveManager** completo → una partida guardable/cargable de punta a punta; y habilita que los futuros sistemas Persist (Economía, Flujo, Construcción) se orquesten sin tocar el manager.

## Notas de gotchas del proyecto

- **Orden en `[autoload]` = orden de carga**: la POSICIÓN de la línea importa. `SaveManager` va el ÚLTIMO de los 5 (tras Tiempo). Solo AÑADIR la línea; no reordenar ni reescribir las 4 previas.
- **Autoload SIN `class_name`**: `save_manager.gd` no lleva `class_name` (colisión con el singleton). Ya definido en la Story 002.
- **`godot --headless` para el smoke**: ruta del ejecutable de Godot según el flujo del proyecto; validar el arranque sin ventana + la suite con exit 0. Lanzar la ventana real solo si se quiere confirmación visual (no necesaria para este smoke técnico).
- **El manager NO auto-carga al arrancar**: `_ready` no debe llamar a `cargar_partida` (evita cargar un save sin que el jugador lo pida y antes de que el flujo de arranque lo decida).
- **`user://` para el smoke**: el guardar/cargar del smoke usa `user://` (nunca `res://`); limpiar el archivo de smoke si se quiere dejar `user://` limpio.

## Cierre (2026-07-23)

Autoload registrado 5o por subagente Opus (agotado el turno a mitad); smoke REMATADO en hilo principal:
tests/smoke_save_manager.gd (SceneTree standalone) -> SMOKE_GUARDAR true, SMOKE_CARGAR true, exit 0, sin
residuos en user://. Smoke doc: production/qa/smoke-2026-07-23.md. Suite 135/135 exit 0.
