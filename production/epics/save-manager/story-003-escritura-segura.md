# Story 003: Escritura segura en `user://` (temp+rename, bool de `store_*`)

> **Epic**: SaveManager (guardado y carga)
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**Fuente**: `docs/architecture/adr-0002-guardado-serializacion.md` (Decision 5 — "Escritura segura: escribir en un archivo temporal y **renombrar** al final (`temp` → `savegame.save`) para no corromper el save anterior si algo falla a mitad; comprobar el `bool` de `store_*`"; Constraints — "`user://` obligatorio: `res://` es de solo lectura en las exportaciones"; Risks — "`store_*` falla (disco lleno/permisos) → save incompleto → comprobar el `bool`; escribir en temp + renombrar"). *(SPEC = ADR-0002; sin GDD.)*
**Requirement**: `TR-save-001` (guardado JSON en `user://`, NO custom Resources).

**ADR Governing Implementation**: ADR-0002: Guardado / serialización *(primario)*
**ADR Decision Summary**: el guardado NUNCA sobrescribe el save bueno directamente. Se serializa el dict raíz (Story 002) con `JSON.stringify`, se escribe a un archivo **temporal**, y solo si TODO fue bien se **renombra** el temporal al nombre final (operación atómica en la práctica). Si algo falla a mitad (disco lleno, permisos, `store_*` devuelve `false`), el save anterior queda **intacto** y no queda un `.tmp` corrupto colgando. `user://` es obligatorio (`res://` es de solo lectura al exportar).

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM *(la I/O real y el rename en Windows son el único punto con riesgo de motor; API verificada en `modules/save-load.md`)*
**Engine Notes**:
- `FileAccess.store_string(...)` devuelve **`bool` desde 4.4** (post-cutoff) — **comprobarlo NO es opcional**, es regla del manifest. Verificado en `docs/engine-reference/godot/modules/save-load.md`.
- `DirAccess.rename_absolute(desde, hasta)` para el temp→final. **Verificar el comportamiento de sobrescritura en Windows**: en algunos SO/versiones, renombrar sobre un archivo existente falla; si `rename_absolute` no sobrescribe en Windows, borrar el destino primero (`DirAccess.remove_absolute`) o usar la ruta absoluta resuelta con `ProjectSettings.globalize_path`. Anotado como verificación de la story.
- `FileAccess.open(ruta, FileAccess.WRITE)` puede devolver `null` (p. ej. ruta inválida) → comprobar antes de usar.

**Control Manifest Rules (Foundation)**:
- Required: escritura de save segura (temp + rename); **comprobar el `bool` de retorno de `store_*`** (bool desde 4.4). Guardado en `user://`. — ADR-0002. Tipado estático.
- Forbidden: **nunca** guardar en `res://` (solo lectura al exportar); nunca sobrescribir el save final directamente (siempre temp+rename); nunca ignorar el `bool` de `store_string`; nunca guardar el save como custom Resource (`.tres`).
- Cross-cutting: robustez (un fallo no corrompe el save previo); seguridad (JSON son datos, no código).

---

## Acceptance Criteria

- [x] **AC-ES01**: GIVEN un estado recolectable WHEN `guardar_partida()` (ruta por defecto `user://savegame.save`) THEN devuelve `true` y crea el archivo con JSON válido que contiene la clave `"version"`.
- [x] **AC-ES02**: GIVEN un guardado exitoso WHEN termina THEN **NO** existe el archivo temporal (`ruta + ".tmp"`) — el rename lo consumió.
- [x] **AC-ES03**: GIVEN que `FileAccess.open` del temporal falla (ruta inválida/no escribible) WHEN `guardar_partida(ruta_mala)` THEN devuelve `false`, emite `push_error`, y **NO** crashea ni deja un `.tmp` colgando.
- [x] **AC-ES04**: GIVEN un save previo válido en la ruta destino WHEN un guardado falla a mitad THEN el save previo **permanece intacto** (temp+rename lo garantiza — no se tocó el archivo final).

---

## Implementation Notes

- **Firma pública (DECISIÓN APROBADA)**:
  ```
  func guardar_partida(ruta := "user://savegame.save") -> bool
  ```
  Un solo archivo por defecto; el parámetro `ruta` deja la puerta abierta a **slots** futuros sin cambiar la API. *(El ADR usa el nombre `guardar()` en su "Key Interfaces" — ver anomalía al pie; se sigue la decisión aprobada `guardar_partida`.)*
- **Flujo**:
  1. `var texto: String = JSON.stringify(_recolectar())` (Story 002).
  2. `var ruta_tmp := ruta + ".tmp"`.
  3. `var f := FileAccess.open(ruta_tmp, FileAccess.WRITE)`; si `f == null` → `push_error(...)`; `return false` (nada que limpiar, no se creó nada).
  4. `var ok := f.store_string(texto)` — **comprobar el bool** (4.4+). `f.close()`. Si `not ok` → borrar el `.tmp` (`DirAccess.remove_absolute(ruta_tmp_globalizada)`), `push_error`, `return false`.
  5. Renombrar `ruta_tmp` → `ruta`. En Windows, si `rename_absolute` no sobrescribe el destino existente: `if FileAccess.file_exists(ruta): DirAccess.remove_absolute(ruta_glob)` ANTES del rename. Comprobar el resultado del rename (`Error` / `OK`); si falla → dejar el `.tmp` NO es aceptable → limpiarlo, `push_error`, `return false`, y el save final queda intacto (nunca se borró si el rename no llegó a ejecutarse).
  6. `return true`.
- **`ProjectSettings.globalize_path(ruta)`** para las operaciones de `DirAccess` que necesitan ruta absoluta del SO (rename/remove sobre `user://`). Verificar en la implementación qué API acepta `user://` directamente y cuál necesita globalizar.
- **NUNCA `res://`**: la ruta por defecto es `user://`; si alguien pasara una `res://` (bug), no es responsabilidad del manager blindarlo, pero los tests solo usan `user://`.
- **Orden de la garantía anti-corrupción**: el archivo **final** solo se toca en el paso de rename (paso 5), y solo después de que el `.tmp` se escribió con éxito. Cualquier fallo en pasos 1-4 deja el final sin tocar (AC-ES04).
- **`self.` footgun**: `_recolectar` no sombrea globales; no aplica.

## Out of Scope

- La **lectura** y el parseo (`cargar_partida`): **Story 004**.
- La **distribución** del dict cargado a los nodos: **Story 005**.
- El **round-trip end-to-end** con autoloads reales: **Story 006**.
- El **registro del autoload** y el smoke de arranque: **Story 007**.

## QA Test Cases

*Integration — I/O REAL en `user://`. Ruta ÚNICA por test + BORRAR en teardown. `tests/integration/save_manager/save_manager_escritura_test.gd`.*

- **`test_guardar_crea_archivo_json_valido`** (AC-ES01): `guardar_partida("user://test_es01.save")` → `true`; el archivo existe; `JSON.parse_string(contenido)` es un `Dictionary` con `"version"`.
- **`test_guardar_no_deja_tmp`** (AC-ES02): tras un guardado exitoso, `FileAccess.file_exists("user://test_es02.save.tmp") == false`.
- **`test_open_fallido_devuelve_false_sin_crash`** (AC-ES03): `guardar_partida` a una ruta cuyo `open` falla (p. ej. una subcarpeta inexistente en `user://` como `user://no/existe/x.save`) → `false`, sin crash, sin `.tmp`.
- **`test_save_previo_intacto_si_falla`** (AC-ES04): escribir un save "bueno" con contenido conocido; forzar un fallo del guardado (ruta/condición que falle tras haber un final previo); verificar que el contenido del final NO cambió. *(Si forzar el fallo a mitad es difícil de reproducir de forma determinista, cubrir la garantía por diseño: comprobar que el final solo se toca en el rename y que un `open` fallido del `.tmp` — AC-ES03 — nunca llega al rename.)*

**Teardown**: cada test usa una ruta única (`user://test_esNN.save`) y en el teardown borra tanto `ruta` como `ruta + ".tmp"` con `DirAccess.remove_absolute` si existen. Aislamiento total entre tests.

## Test Evidence

**Story Type**: Integration (I/O real a `user://`)
**Required evidence**: `tests/integration/save_manager/save_manager_escritura_test.gd` — debe existir y pasar (BLOCKING).

**Status**: [x] Creado y PASA (save_manager_escritura_test.gd 4/4; suite 135/135, 2026-07-23)

## Dependencies

- Depends on: **Story 002** (`_recolectar()` provee el dict raíz que se serializa).
- Unlocks: **Story 004** (lee lo que esta story escribe — sus fixtures se generan con `guardar_partida`).

## Notas de gotchas del proyecto

- **`store_string` devuelve `bool` (4.4+)**: comprobarlo es regla del manifest, no opcional. Un `store_*` que devuelve `false` (disco lleno/permisos) sin comprobar = save silenciosamente corrupto.
- **`rename_absolute` en Windows**: verificar la sobrescritura del destino existente; si no sobrescribe, borrar el destino primero. La plataforma objetivo es Windows (`technical-preferences.md`).
- **`user://` aislamiento**: I/O real → ruta única por test + teardown que borra el archivo Y su `.tmp`. Nunca compartir rutas entre tests (romperían el aislamiento/orden-independencia del manifest de testing).
- **`FileAccess.open` puede devolver `null`**: comprobar antes de llamar a `store_string` (no es una excepción, es un valor de retorno).
- **`res://` prohibido**: nunca escribir el save fuera de `user://`.

## Cierre (2026-07-23)

Implementada via subagente godot-gdscript-specialist (Opus) + verificacion independiente del hilo
principal (suite 135/135, exit 0). Commit 821d33a. Hallazgo Windows (003): rename_absolute NO sobrescribe
-> borrar destino solo con .tmp valido listo; rutas globalizadas con ProjectSettings.globalize_path.
