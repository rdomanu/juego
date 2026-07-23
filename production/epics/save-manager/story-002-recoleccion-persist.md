# Story 002: Recolección — grupo `Persist` → dict raíz con `version`

> **Epic**: SaveManager (guardado y carga)
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**Fuente**: `docs/architecture/adr-0002-guardado-serializacion.md` (Decision 2 — "`SaveManager` recorre `get_tree().get_nodes_in_group("Persist")`, pide a cada uno su `save()`, ensambla un diccionario raíz `{ "version": N, ... }`… **No conoce los sistemas por nombre**"; Decision 7 — campo `"version"` para migraciones). *(Este epic NO tiene GDD; la SPEC es el ADR-0002 + `architecture.md` §3.3.)*
**Requirement**: `TR-save-001` (guardado JSON en `user://` — NO custom Resources; patrón `save()`/`load_state()` por sistema, orquestado por el grupo `Persist`).

**ADR Governing Implementation**: ADR-0002: Guardado / serialización *(primario)* · ADR-0001 *(sec. — la regla "la Foundation no llama a los sistemas por nombre" viene de aquí)*
**ADR Decision Summary**: el `SaveManager` NO conoce ningún sistema por nombre (respeta el libro de normas de capas). Recorre el **grupo genérico `Persist`**, le pide a cada nodo su `save() -> Dictionary`, y ensambla un **dict raíz** con un campo `"version"` (para migraciones futuras) más una entrada por sistema. Los dueños de esa entrada son los nodos del grupo; el manager es pura fontanería de recolección.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Node.name` es un `StringName`/`String`. `get_tree().get_nodes_in_group("Persist")` devuelve `Array[Node]`. Esta story separa el **método interno** (recibe la lista de nodos por parámetro → testeable sin árbol de escena real, sin autoload) del **método público** (que saca la lista del árbol). Sin I/O ni JSON todavía (eso es Story 003).

**Control Manifest Rules (Foundation)**:
- Required: `SaveManager` recorre `get_tree().get_nodes_in_group("Persist")` — patrón `save()`/`load_state()` por sistema. — ADR-0002. Nunca la Foundation llama a los sistemas por nombre (usar el grupo). — ADR-0001. Campo `"version"` en el save. Tipado estático.
- Forbidden: **nunca** referenciar un sistema por su nombre de clase/autoload dentro del manager (violaría las capas); nunca asumir que un nodo del grupo tiene `save()` sin comprobar (`has_method` defensivo); nunca serializar datos derivados (responsabilidad de cada `save()`, no del manager).
- Cross-cutting: capas estrictas (el grupo desacopla); determinismo del dict resultante (mismas entradas → mismo dict).

---

## Acceptance Criteria

- [x] **AC-RC01**: GIVEN una lista de nodos `Persist` WHEN `_recolectar_de(nodos)` THEN el dict resultante incluye la clave `"version"` con valor `1`.
- [x] **AC-RC02**: GIVEN 2 nodos con `name` = `"RNGService"` y `"Tiempo"`, cada uno con su `save()` WHEN `_recolectar_de([rng, tiempo])` THEN el dict tiene una entrada por nodo con clave = `node.name` y valor = lo que devuelve su `save()`.
- [x] **AC-RC03**: GIVEN una lista **vacía** WHEN `_recolectar_de([])` THEN el dict es exactamente `{"version": 1}` (no peta, no añade entradas espurias).
- [x] **AC-RC04**: GIVEN el dict recolectado WHEN se pasa por `JSON.stringify(...)` THEN NO lanza ni produce error (todas las entradas son JSON-serializables porque cada `save()` devuelve solo tipos serializables).

---

## Implementation Notes

- **Ubicación**: `src/foundation/save_manager/save_manager.gd`, **autoload SIN `class_name`**. El autoload se llamará `SaveManager` (registro en `project.godot` — **Story 007**); un `class_name SaveManager` homónimo colisionaría con el nombre global del singleton (mismo footgun que `event_bus.gd`, `rng_service.gd`, `tiempo.gd`). El helper `SerialUtil` (Story 001) SÍ lleva `class_name` porque no es autoload.
- **Método interno testeable** (recibe la lista → sin árbol):
  ```
  const VERSION_ACTUAL: int = 1

  func _recolectar_de(nodos: Array) -> Dictionary:
      var raiz: Dictionary = {"version": VERSION_ACTUAL}
      for n in nodos:
          if n.has_method("save"):
              raiz[n.name] = n.save()
          # else: nodo en el grupo sin contrato save() -> se ignora (defensivo)
      return raiz
  ```
- **Método público** (saca la lista del árbol y delega):
  ```
  func _recolectar() -> Dictionary:
      return _recolectar_de(get_tree().get_nodes_in_group("Persist"))
  ```
- **Clave por sistema = `node.name`** (DECISIÓN APROBADA): la Foundation no conoce los sistemas por nombre en código; solo lee el **nombre del nodo** del grupo. Como los autoloads se registran con un nombre estable (`RNGService`, `Tiempo`, …), ese nombre es la clave natural del sub-dict. **Consecuencia a documentar**: renombrar un autoload rompería los saves antiguos (la clave dejaría de coincidir) → eso es territorio del **hook de migración** (`version`, Story 004), no de esta recolección.
- **`has_method("save")` defensivo**: si algún nodo se une al grupo `Persist` sin implementar `save()` (error de integración), se ignora en vez de petar. Esto NO sustituye la disciplina del control-manifest (todo nodo `Persist` DEBE implementar el contrato), es una red de seguridad.
- **VERSION_ACTUAL = 1** como constante del manager: es la versión del **formato del save**, no de un sistema. Sube cuando el formato cambie de forma incompatible (Story 004 define el rechazo de versiones mayores).
- **Nada de I/O aquí**: esta story solo construye el `Dictionary` en memoria. `JSON.stringify` + escritura a `user://` es la Story 003.

## Out of Scope

- **`JSON.stringify` + escritura segura** (temp+rename, bool de `store_*`): **Story 003**.
- **Lectura/parseo/chequeo de `version`**: **Story 004**.
- **Distribución** del dict de vuelta a los nodos (`load_state`): **Story 005**.
- El **contenido** de cada `save()` (qué campos guarda cada sistema): responsabilidad del epic dueño (Tiempo/RNGService ya cerrados; Construcción/Flujo/… en los suyos).

## QA Test Cases

*Logic — recolección pura con nodos-espía, sin árbol real ni I/O. `tests/unit/save_manager/save_manager_recoleccion_test.gd`.*

- **`test_recolecta_incluye_version`** (AC-RC01): `_recolectar_de([])` incluye `"version" == 1`.
- **`test_recolecta_una_entrada_por_nodo`** (AC-RC02): crear 2 nodos-espía con `name` fijado y un `save()` que devuelve un dict conocido; `_recolectar_de([a, b])` → tiene `raiz["NombreA"]` y `raiz["NombreB"]` con los valores esperados.
- **`test_recolecta_grupo_vacio`** (AC-RC03): `_recolectar_de([])` == `{"version": 1}` exactamente.
- **`test_recolectado_es_json_serializable`** (AC-RC04): recolectar de espías cuyos `save()` devuelven tipos serializables; `JSON.stringify(raiz)` no vacío y `JSON.parse_string(...)` reproduce un `Dictionary`.

**Nodos-espía**: `Node` de test con `name` fijado (`espia.name = "RNGService"`) y un `save()` que devuelve un dict constante (p. ej. `{"k": 1}`). Se añaden a la lista que se inyecta a `_recolectar_de` — NO hace falta `add_to_group` ni árbol para el método interno.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/save_manager/save_manager_recoleccion_test.gd` — debe existir y pasar (BLOCKING).

**Status**: [x] Creado y PASA (save_manager_recoleccion_test.gd 5/5; suite 135/135, 2026-07-23)

## Dependencies

- Depends on: **Story 001** (el dict recolectado puede contener sub-dicts con `Vector2i` ya traducidos por `SerialUtil`; y comparte el paquete `src/foundation/save_manager/`). *(La recolección en sí no llama a `SerialUtil` — lo hacen los `save()` de cada sistema — pero la story 001 establece el paquete y el patrón de tipos JSON-safe que hace válido el AC-RC04.)*
- Unlocks: **Story 003** (escribe el dict recolectado a disco).

## Notas de gotchas del proyecto

- **Autoload SIN `class_name`**: el nombre del singleton (`SaveManager`) y un `class_name SaveManager` colisionarían. El registro del autoload es la Story 007; hasta entonces el script existe pero no está registrado (los tests lo `preload`ean por ruta).
- **Preload por ruta en headless**: `preload("res://src/foundation/save_manager/save_manager.gd")` en el test (class_name en frío / autoload sin registrar).
- **`Node.name`**: al crear los espías, fijar `name` ANTES de leerlo; Godot puede renombrar nodos duplicados en el árbol (con `@`), pero como el método interno recibe la lista sin añadirlos al árbol, `name` queda tal cual se fijó.
- **Lambdas capturan por valor → Arrays**: si algún test usa un lambda para el `save()` del espía y acumula en un `Array`, recordar que el lambda captura la referencia del `Array` (mutable) pero valores por copia (patrón ya visto en los tests del proyecto).

## Cierre (2026-07-23)

Implementada via subagente godot-gdscript-specialist (Opus) + verificacion independiente del hilo
principal (suite 135/135, exit 0). Commit 821d33a. Hallazgo Windows (003): rename_absolute NO sobrescribe
-> borrar destino solo con .tmp valido listo; rutas globalizadas con ProjectSettings.globalize_path.
