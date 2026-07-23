# Story 006: Round-trip END-TO-END con autoloads reales (disco `user://`)

> **Epic**: SaveManager (guardado y carga)
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**Fuente**: `docs/architecture/adr-0002-guardado-serializacion.md` (Validation Criteria — "Round-trip: guardar → cargar → el estado de cada sistema es idéntico"; "Determinismo: cargar + continuar produce la misma secuencia que sin guardar (RNG restaurado)"; "Carga limpia: tras cargar, el juego está en Pausa y no se han disparado eventos retroactivos"). *(SPEC = ADR-0002; sin GDD.)*
**Requirement**: `TR-save-001` (guardado JSON en `user://`) · `TR-save-002` (serializar el estado del RNG + semilla → secuencia futura idéntica) · `TR-time-008` (serializar reloj/fecha; cargar arranca en Pausa, sin eventos retroactivos).

**ADR Governing Implementation**: ADR-0002: Guardado / serialización *(primario)* · ADR-0001 *(sec. — arranque en Pausa)*
**ADR Decision Summary**: la prueba definitiva del epic. Con instancias REALES de RNGService y Tiempo en un grupo `Persist`, un ciclo completo `guardar_partida` → **alterar el estado** → `cargar_partida` a través de **JSON real en disco** debe dejar todo idéntico: el reloj en el mismo minuto/fecha y en **Pausa**, y — la parte más delicada — la **secuencia futura del RNG** idéntica a la esperada (el truco del int64-como-String de `RNGService.save()` tiene que sobrevivir el `JSON.stringify`/`parse` real). Esto valida las Stories 003+005 juntas contra los `save()`/`load_state()` ya cerrados de Tiempo (H8) y RNGService (S3).

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM *(I/O real + determinismo del RNG a través de JSON en disco — el punto que más fácil se rompe si el int64 pierde precisión)*
**Engine Notes**:
- Instancias REALES por `preload` de ruta: `preload("res://src/foundation/rng_service/rng_service.gd").new()` y `preload("res://src/foundation/tiempo/tiempo.gd").new()`, añadidas a un árbol de test y al grupo `"Persist"` (con `add_to_group` o forzando su `_ready`). El `Tiempo._ready` intenta resolver `/root/EventBus` y cargar el config — en el test, inyectar un bus (`usar_bus`) o tolerar `null` (fallback seguro documentado en `tiempo.gd`).
- El **determinismo del RNG** es el corazón: sembrar, consumir N valores, guardar; alterar; cargar; los SIGUIENTES valores deben coincidir con los que habría dado el RNG original sin guardar. El int64 viaja como String por el JSON (precisión) — si algo lo convierte a número, el round-trip a disco lo delata aquí.
- **15:30 = 930 min**, NO 14:30. Errata conocida del GDD (el ejemplo del AC-T26 empareja "14:30" con turno "Tarde", pero 14:30 cae en MAÑANA según la tabla de turnos; 15:30 es Tarde real). Usar 930 para un estado de reloj inequívocamente en turno Tarde.

**Control Manifest Rules (Foundation)**:
- Required: round-trip idéntico (guardar→cargar→mismo estado); serializar el RNG (determinismo); cargar arranca en Pausa sin eventos retroactivos. — ADR-0002/0001. `user://`. Tipado estático.
- Forbidden: nunca dar por bueno el determinismo sin probar la secuencia FUTURA del RNG a través del disco; nunca dejar el archivo de test sin borrar (teardown); nunca `res://`.
- Cross-cutting: determinismo por diseño; "cargar sitúa, no reproduce".

---

## Acceptance Criteria

- [x] **AC-RT01**: GIVEN Tiempo con `minutos_juego = 930.0` (15:30), `semana`/`mes`/`anio` conocidos, guardado a `user://` y luego ALTERADO WHEN `cargar_partida` THEN el reloj vuelve a `minutos_juego == 930.0` y la misma `semana`/`mes`/`anio` (round-trip idéntico a través de JSON en disco).
- [x] **AC-RT02**: GIVEN el mismo ciclo WHEN se carga THEN `Tiempo.velocidad_actual == PAUSA` (cargar arranca en Pausa, sea cual sea la velocidad previa — TR-time-008).
- [x] **AC-RT03**: GIVEN RNGService sembrado y consumido antes de guardar, luego ALTERADO WHEN se carga THEN la **secuencia futura** del RNG tras cargar es **idéntica** a la que habría producido sin guardar (determinismo restaurado vía el int64-como-String a través del disco — TR-save-002).
- [x] **AC-RT04**: GIVEN el archivo de test en `user://` WHEN termina el test THEN el teardown lo borra (aislamiento; el `user://` queda limpio).

---

## Implementation Notes

- **Ubicación del test**: `tests/integration/save_manager/save_manager_roundtrip_test.gd`. Es el test más integrador del epic: usa los autoloads REALES (no espías).
- **Montaje del escenario**:
  1. Instanciar RNGService y Tiempo por `preload` de ruta + `.new()`; añadirlos al árbol del test (`add_child`) y al grupo `"Persist"`. Instanciar/inyectar el SaveManager (también por `preload`).
  2. Sembrar el RNG (`rng.sembrar(SEMILLA)`), consumir K valores (`randi_rango`/`randf`) para avanzar su `state`.
  3. Fijar el reloj a un estado conocido: `tiempo.minutos_juego = 930.0` (15:30, Tarde), `semana`/`mes`/`anio` a valores concretos.
  4. **Calcular la secuencia esperada**: ANTES de alterar, capturar los SIGUIENTES M valores que daría el RNG (en un RNG clonado con el mismo estado, o anotándolos y luego re-sembrando) — esa es la "verdad" contra la que se compara tras cargar.
- **El ciclo**:
  5. `save_manager.guardar_partida("user://test_roundtrip.save")` → `true`.
  6. **ALTERAR** el estado: `tiempo.minutos_juego = 0.0`, `tiempo.fijar_velocidad(X3)`, consumir más valores del RNG (mover su `state` lejos del guardado).
  7. `save_manager.cargar_partida("user://test_roundtrip.save")` → `true`.
  8. Verificar AC-RT01 (reloj), AC-RT02 (Pausa), AC-RT03 (los M siguientes valores del RNG == la secuencia esperada del paso 4).
- **Determinismo del RNG a través del disco (AC-RT03, el más delicado)**: la secuencia esperada se captura del estado del RNG **en el momento de guardar**. Tras cargar, el `state` restaurado debe producir exactamente esos M valores. Como el `state` (int64) viajó como String por el JSON real en disco, este test es la prueba de que el truco de String preserva la precisión end-to-end (no solo en el round-trip en memoria que ya cubre el epic RNGService).
- **Pausa (AC-RT02)**: aunque en el paso 6 se puso `X3`, tras cargar debe ser `PAUSA` — lo garantiza `Tiempo.load_state` (`fijar_velocidad(PAUSA)`), no el manager. El test lo confirma end-to-end.
- **EventBus**: si Tiempo tiene un bus inyectado, conectar un espía y confirmar 0 emisiones de cruce durante la carga (refuerza el AC-DT04 de la Story 005 a nivel end-to-end); si no, basta con verificar el estado. El `load_state` de Tiempo ya sincroniza umbrales sin emitir.

## Out of Scope

- El **registro del autoload** en `project.godot` y el smoke de arranque real del juego: **Story 007** (aquí las instancias se crean a mano en el test, no se depende del registro global).
- Los `save()`/`load_state()` de **otros** sistemas (Economía, Flujo, Construcción): sus epics. Este round-trip usa solo RNGService + Tiempo (los dos Persist ya cerrados).
- La UI de guardar/cargar (menú, slots): fuera del MVP de este epic (infraestructura pura).

## QA Test Cases

*Integration — autoloads REALES + JSON real en `user://`. Teardown borra el archivo. `tests/integration/save_manager/save_manager_roundtrip_test.gd`.*

- **`test_roundtrip_reloj_identico`** (AC-RT01): ciclo guardar→alterar→cargar → `minutos_juego == 930.0` y `semana`/`mes`/`anio` restaurados.
- **`test_carga_arranca_en_pausa`** (AC-RT02): tras cargar (habiendo alterado a X3) → `velocidad_actual == PAUSA`.
- **`test_rng_secuencia_futura_determinista`** (AC-RT03): los M valores del RNG tras cargar == la secuencia esperada capturada al guardar (determinismo a través del disco / int64-como-String).
- **`test_teardown_limpia_archivo`** (AC-RT04): el teardown borra `user://test_roundtrip.save` (y su `.tmp` si quedara) — verificable porque el siguiente `file_exists` da `false`.

**Teardown**: borrar `user://test_roundtrip.save` y `user://test_roundtrip.save.tmp` con `DirAccess.remove_absolute` si existen; `queue_free`/`free` de las instancias añadidas al árbol.

## Test Evidence

**Story Type**: Integration (autoloads reales + disco `user://`)
**Required evidence**: `tests/integration/save_manager/save_manager_roundtrip_test.gd` — debe existir y pasar (BLOCKING).

**Status**: [x] Creado y PASA (save_manager_roundtrip_test.gd 4/4; suite 135/135, 2026-07-23)

## Dependencies

- Depends on: **Story 003** (escritura real que produce el archivo) y **Story 005** (distribución que reparte el dict cargado a los autoloads reales). *(Implícitamente usa 002+004 vía 003/005; y los `save()`/`load_state()` YA cerrados de Tiempo H8 y RNGService S3.)*
- Unlocks: **Story 007** (con el round-trip verde, registrar el autoload y hacer el smoke de arranque real es la guinda).

## Notas de gotchas del proyecto

- **15:30 = 930, NO 14:30**: errata del GDD (14:30 cae en MAÑANA según la tabla de turnos; el ejemplo del AC-T26 la empareja mal con "Tarde"). Usar 930 para un estado inequívocamente en Tarde. Ya anotado en el cierre de la Story 008 de Tiempo.
- **int64-como-String del RNG a través del disco**: el `state`/`semilla` del RNG viajan como texto por el JSON (precisión int64). Este test es LA prueba de que sobrevive el round-trip real a disco, no solo en memoria.
- **Preload por ruta en headless**: instanciar RNGService/Tiempo/SaveManager con `preload("res://.../*.gd").new()` — no depender de la resolución por nombre de autoload (que en el test aún no está registrado / class_name en frío).
- **`Tiempo._ready` con bus/config**: en el test, inyectar un bus (`usar_bus`) o tolerar `null` (fallback seguro documentado); el config ausente cae a defaults seguros (no peta).
- **`user://` aislamiento**: ruta única + teardown que borra el archivo Y su `.tmp`.
- **Lambdas capturan por valor → Arrays**: si se acumula la secuencia esperada del RNG en un `Array`, ojo con la captura (referencia mutable del Array, valores por copia).

## Cierre (2026-07-23)

Test de integracion escrito por subagente Opus (aislamiento: instancias propias + metodos internos con
lista inyectada, sin contaminar los autoloads del runner) + verificacion del hilo principal. Suite
135/135, exit 0.
