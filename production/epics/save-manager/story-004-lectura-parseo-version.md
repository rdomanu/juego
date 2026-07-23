# Story 004: Lectura + parseo + chequeo de `version` (hook de migraciones)

> **Epic**: SaveManager (guardado y carga)
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: (lo fija /dev-story al empezar)

## Context

**Fuente**: `docs/architecture/adr-0002-guardado-serializacion.md` (Decision 7 — "Versionado: el campo `"version"` habilita migraciones futuras del formato"; Risks — "JSON inválido (save corrupto/editado a mano) → `JSON.parse` falla → manejar el error, no cargar, avisar; **nunca ejecuta nada** — seguro por diseño"; Migration Plan — "N/A — proyecto nuevo. El campo `"version"` habilita migraciones futuras"). *(SPEC = ADR-0002; sin GDD.)*
**Requirement**: `TR-save-001` (patrón de carga JSON en `user://`).

**ADR Governing Implementation**: ADR-0002: Guardado / serialización *(primario)*
**ADR Decision Summary**: cargar es leer el archivo, parsear el JSON de forma **segura** (JSON son datos, nunca ejecuta código — a diferencia de un `.tres` manipulado), validar que el resultado es un `Dictionary` con `"version"`, y pasarlo por un **hook de migración** antes de distribuirlo a los sistemas. Un save inválido/corrupto NO se carga y NO crashea (se avisa). El campo `"version"` habilita migraciones futuras; en el MVP no hay migraciones (identidad para `version == 1`), y una `version` **mayor que la actual** se RECHAZA (no sabemos leer un formato del futuro).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**:
- `FileAccess.open(ruta, FileAccess.READ)` devuelve `null` si el archivo no existe o no es legible → comprobar antes de leer.
- `JSON.parse_string(texto)` devuelve `null` ante texto inválido (**NO lanza excepción** en 4.x) → comprobar `typeof(resultado) == TYPE_DICTIONARY` antes de tratarlo como dict.
- Los enteros grandes del RNG (`semilla`/`estado`, int64) se guardaron como **String** (ver `rng_service.gd`); al parsear el JSON llegan como String y **NO deben convertirse aquí** — se pasan crudos al `load_state` del RNGService, que ya hace `int(str(...))`. El manager no toca el contenido de los sub-dicts.

**Control Manifest Rules (Foundation)**:
- Required: al cargar, campo `"version"` en el save; un save inválido no se carga y no crashea; JSON son datos (seguro). — ADR-0002. Tipado estático.
- Forbidden: nunca cargar un save como Resource (`load()`/`ResourceLoader`) — solo JSON (seguridad); nunca convertir los String de int64 del RNG (rompería la precisión); nunca continuar la carga con un parseo fallido o sin `"version"`.
- Cross-cutting: seguridad por diseño (JSON no ejecuta código); robustez (save corrupto → false + log, no crash).

---

## Acceptance Criteria

- [ ] **AC-LC01**: GIVEN una ruta inexistente (o `FileAccess.open` devuelve `null`) WHEN `cargar_partida(ruta)` THEN devuelve `false`, emite log, y NO crashea.
- [ ] **AC-LC02**: GIVEN un archivo con texto NO-JSON (o JSON que no es un objeto, p. ej. `"42"` o `"[1,2]"`) WHEN `cargar_partida(ruta)` THEN `JSON.parse_string` devuelve algo cuyo `typeof != TYPE_DICTIONARY` → `false` + log, sin crash.
- [ ] **AC-LC03**: GIVEN un JSON válido pero SIN la clave `"version"` WHEN `cargar_partida(ruta)` THEN devuelve `false` + log (no es un save reconocible).
- [ ] **AC-LC04**: GIVEN un save con `"version"` **mayor** que `VERSION_ACTUAL` (p. ej. 99) WHEN `cargar_partida(ruta)` THEN se **RECHAZA** con log (MVP sin migraciones hacia adelante — no sabemos leer un formato futuro); GIVEN `version == 1` THEN `_migrar` es la **identidad** y la carga continúa.

---

## Implementation Notes

- **Firma pública (DECISIÓN APROBADA)**:
  ```
  func cargar_partida(ruta := "user://savegame.save") -> bool
  ```
  Mismo patrón de `ruta` que `guardar_partida` (puerta a slots futuros). *(El ADR usa `cargar()` en "Key Interfaces" — ver anomalía al pie; se sigue la decisión aprobada `cargar_partida`.)*
- **Flujo de lectura** (esta story llega hasta tener el dict migrado listo; la DISTRIBUCIÓN a los nodos es Story 005):
  1. `if not FileAccess.file_exists(ruta): push_warning(...); return false`.
  2. `var f := FileAccess.open(ruta, FileAccess.READ)`; `if f == null: push_error(...); return false`.
  3. `var texto := f.get_as_text()`; `f.close()`.
  4. `var parseado: Variant = JSON.parse_string(texto)` — **puede ser `null`** (texto inválido).
  5. `if typeof(parseado) != TYPE_DICTIONARY: push_error("save invalido: no es un objeto JSON"); return false`.
  6. `var dict: Dictionary = parseado`.
  7. `if not dict.has("version"): push_error("save sin version"); return false`.
  8. `var version: int = int(dict["version"])`.
  9. `var migrado: Dictionary = _migrar(dict, version)`; si `_migrar` señala rechazo (ver abajo) → `return false`.
  10. *(Story 005 distribuye `migrado` a los nodos; esta story deja el dict validado/migrado listo y, para poder testear el chequeo de versión de forma aislada, la parte de lectura+versión debe ser observable — ver QT.)*
- **Hook de migración**:
  ```
  func _migrar(dict: Dictionary, version: int) -> Dictionary:
      if version == VERSION_ACTUAL:
          return dict                     # identidad (MVP)
      if version > VERSION_ACTUAL:
          push_error("save version %d > actual %d -> RECHAZADO (sin migracion hacia adelante)" % [version, VERSION_ACTUAL])
          return {}                       # marcador de rechazo (dict vacio) -> el caller devuelve false
      # version < VERSION_ACTUAL: aqui iran las migraciones hacia adelante (identidad por ahora; ninguna definida)
      return dict
  ```
  **DECISIÓN APROBADA 3**: `version` desconocida (mayor que la actual) → RECHAZAR con log. `_migrar` es la identidad para `version == VERSION_ACTUAL (1)`. El caller distingue "migración OK" de "rechazo" (un dict vacío `{}` tras `_migrar` de un `version > actual` significa rechazo → `return false`). *(Alternativa de implementación: `_migrar` devuelve un flag/`bool` de éxito por separado; el subagente elige la forma más limpia siempre que el comportamiento observable cumpla AC-LC04.)*
- **Los String de int64 del RNG NO se tocan**: el manager parsea el JSON y pasa los sub-dicts tal cual; `RNGService.load_state` hace `int(str(...))`. Convertirlos aquí (p. ej. asumir que `semilla` es un número) rompería la precisión y el determinismo.
- **Seguridad**: `JSON.parse_string` nunca ejecuta código (a diferencia de cargar un `.tres`). Un save editado a mano, en el peor caso, es un JSON que no parsea o al que le faltan claves → se rechaza; nunca es un vector de ejecución.

## Out of Scope

- La **distribución** del dict migrado a los nodos del grupo (`load_state`): **Story 005**.
- Las **migraciones reales** entre versiones (`version < actual`): fuera del MVP — el hook existe como identidad + rechazo de versiones futuras; ninguna migración concreta se implementa.
- La **tolerancia a `id` huérfano** del catálogo (TR-data-006): la aplica cada sistema en su `load_state` (coordinado con Datos), no el manager.
- El **round-trip end-to-end**: **Story 006**.

## QA Test Cases

*Integration — lectura de fixtures REALES escritos con el helper de la Story 003, borrados en teardown. `tests/integration/save_manager/save_manager_lectura_test.gd`.*

- **`test_ruta_inexistente_devuelve_false`** (AC-LC01): `cargar_partida("user://no_existe_lc01.save")` → `false`, sin crash.
- **`test_json_invalido_devuelve_false`** (AC-LC02): escribir a mano un archivo con `"esto no es json {"` (o con `"[1,2]"`); `cargar_partida` → `false`, sin crash (verifica el manejo del `null`/no-dict de `parse_string`).
- **`test_falta_version_devuelve_false`** (AC-LC03): escribir un JSON válido `{"Tiempo": {...}}` sin `"version"`; `cargar_partida` → `false` + log.
- **`test_version_futura_se_rechaza`** (AC-LC04): escribir `{"version": 99, ...}`; `cargar_partida` → `false` (rechazo). Y un fixture con `{"version": 1, ...}` → NO se rechaza por versión (el chequeo pasa; la distribución la valida la Story 005).

**Fixtures**: preferentemente generados con `guardar_partida` (Story 003) para los casos válidos, y escritos a mano (FileAccess directo) para los casos corruptos/inválidos. Ruta única por test; teardown borra `ruta` y `ruta + ".tmp"`.

## Test Evidence

**Story Type**: Integration (lee fixtures reales de `user://`)
**Required evidence**: `tests/integration/save_manager/save_manager_lectura_test.gd` — debe existir y pasar (BLOCKING).

**Status**: not yet created

## Dependencies

- Depends on: **Story 003** (los fixtures válidos se generan con `guardar_partida`; comparten el patrón de rutas/teardown en `user://`).
- Unlocks: **Story 005** (recibe el dict validado/migrado y lo distribuye a los nodos).

## Notas de gotchas del proyecto

- **`JSON.parse_string` devuelve `null`** ante texto inválido (no lanza) → comprobar `typeof == TYPE_DICTIONARY` antes de tratarlo como dict. Este es EL gotcha central de esta story.
- **int64 del RNG como String**: `semilla`/`estado` viajan como texto (precisión int64 en JSON) → NO convertirlos en el manager; pasarlos crudos a `RNGService.load_state`, que hace `int(str(...))`.
- **`user://` aislamiento con teardown**: fixtures con ruta única + borrado en teardown (incl. `.tmp`).
- **Seguridad JSON**: nunca cargar el save con `load()`/`ResourceLoader` (ejecutaría `_init` de un Resource manipulado) — solo `FileAccess` + `JSON.parse_string`.
- **Preload por ruta en headless**: `preload("res://src/foundation/save_manager/save_manager.gd")` en el test.
