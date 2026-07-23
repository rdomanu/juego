# Story 005: Distribución tolerante — sub-dicts vía `load_state`

> **Epic**: SaveManager (guardado y carga)
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: (lo fija /dev-story al empezar)

## Context

**Fuente**: `docs/architecture/adr-0002-guardado-serializacion.md` (Decision 6 — "Al cargar: … se llama a `load_state` de cada sistema; Tiempo queda en Pausa; **no** se re-disparan eventos. Un `id` huérfano … se migra o descarta con log — **nunca invalida el save completo**"; Validation Criteria — "Robustez: un save con un `id` huérfano carga el resto (no se invalida)"). *(SPEC = ADR-0002; sin GDD.)*
**Requirement**: `TR-save-001` (patrón `save()`/`load_state()` orquestado por el grupo) · `TR-data-006` (tolerancia a catálogo cambiante — un `id` huérfano se migra/descarta con log, coordinado con Datos; NO invalida el save completo).

**ADR Governing Implementation**: ADR-0002: Guardado / serialización *(primario)* · ADR-0003 *(sec. — el catálogo Datos debe estar cargado antes de `load_state`)*
**ADR Decision Summary**: con el dict raíz ya validado/migrado (Story 004), el manager lo **reparte** a los nodos del grupo `Persist`: por cada nodo, busca su entrada por `node.name` y le pasa el sub-dict con `load_state`. La distribución es **tolerante**: si un nodo no tiene entrada en el save (save viejo, sistema nuevo), ese nodo mantiene sus defaults y se avisa, PERO los demás cargan igual — un save nunca se invalida en bloque. El manager **NO re-dispara eventos**: "cargar sitúa, no reproduce" lo garantizan los propios sistemas (Tiempo fuerza Pausa + `sincronizar_umbrales` en su `load_state`).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: iterar `Array[Node]`, `has_method("load_state")`, `Dictionary.has(clave)`. Sin I/O (el dict ya está en memoria desde la Story 004). El manager NO conoce Tiempo/RNGService por nombre: recorre el grupo y usa `node.name` como clave, exactamente el inverso de la recolección (Story 002).

**Control Manifest Rules (Foundation)**:
- Required: al cargar, se llama a `load_state` de cada sistema; el catálogo (Datos) ya debe estar cargado; **NO se re-disparan eventos** ("cargar sitúa, no reproduce"); un `id` huérfano se migra/descarta con log, nunca invalida el save. — ADR-0002/0003. Tipado estático.
- Forbidden: **nunca** el manager re-dispara eventos de juego al cargar (lo hace, o mejor dicho lo EVITA, cada sistema en su `load_state`); nunca invalidar el save completo por una entrada faltante/huérfana; nunca llamar a un sistema por su nombre de clase (usar el grupo + `node.name`).
- Cross-cutting: "cargar = situar, no reproducir"; robustez (tolerancia a entradas faltantes); capas estrictas.

---

## Acceptance Criteria

- [ ] **AC-DT01**: GIVEN un dict con entradas para `"RNGService"` y `"Tiempo"` y ambos nodos en el grupo WHEN se distribuye THEN a cada nodo se le llama `load_state(subdict)` con SU sub-dict correspondiente.
- [ ] **AC-DT02**: GIVEN un dict que **NO** trae la clave de un nodo del grupo (p. ej. falta `"Tiempo"`) WHEN se distribuye THEN ese nodo mantiene sus defaults + `push_warning`, y **los demás nodos cargan igual** (el save no se invalida).
- [ ] **AC-DT03**: GIVEN un nodo en el grupo sin método `load_state` (error de integración) WHEN se distribuye THEN se ignora ese nodo (defensivo, `has_method`) sin crashear ni afectar a los demás.
- [ ] **AC-DT04**: GIVEN una distribución completa WHEN termina THEN el **EventBus recibe CERO emisiones** provocadas por el manager (el manager no re-dispara nada; los sistemas garantizan "situar, no reproducir" en su propio `load_state`).

---

## Implementation Notes

- **Método interno testeable** (recibe la lista de nodos + el dict → sin árbol):
  ```
  func _distribuir_a(nodos: Array, dict: Dictionary) -> void:
      for n in nodos:
          if not n.has_method("load_state"):
              continue                                   # defensivo (AC-DT03)
          if dict.has(n.name):
              n.load_state(dict[n.name])                 # AC-DT01
          else:
              push_warning("SaveManager: no hay estado guardado para '%s' -> mantiene defaults" % n.name)  # AC-DT02
  ```
- **Método público** (del árbol, tras la lectura/migración de la Story 004):
  ```
  func _distribuir(dict: Dictionary) -> void:
      _distribuir_a(get_tree().get_nodes_in_group("Persist"), dict)
  ```
- **Integración con `cargar_partida`** (Story 004 + esta): al final de la lectura+migración exitosa, `cargar_partida` llama a `_distribuir(migrado)` y `return true`. El flujo completo de carga queda: leer → parsear → validar version → `_migrar` → **distribuir** → `true`.
- **El manager NO re-dispara eventos** (clave del AC-DT04): no llama a `EventBus.disparar_ordenado`, no emite ninguna señal, no fuerza ticks. La regla "cargar sitúa, no reproduce" la cumplen los SISTEMAS: `Tiempo.load_state` ya fuerza `fijar_velocidad(PAUSA)` + `sincronizar_umbrales()` (sin emitir), y `RNGService.load_state` solo restaura estado. El manager es fontanería pura de reparto.
- **Tolerancia (TR-data-006)**: una entrada faltante (`not dict.has(n.name)`) → warning + defaults, NUNCA `return false` global. La tolerancia a `id` huérfano DENTRO de un sub-dict (p. ej. Construcción con un `id` que ya no está en el catálogo) es responsabilidad del `load_state` de ESE sistema (coordinado con Datos), no del manager — el manager solo garantiza que una entrada rara no tumba la carga de las demás.
- **Orden de distribución**: el orden del grupo no debería importar (cada `load_state` es independiente y no dispara eventos). Si en el futuro un sistema dependiera del estado ya cargado de otro, eso se resolvería en el sistema, no reordenando aquí. El invariante crítico (Datos cargado ANTES de cualquier `load_state`) lo garantiza el ORDEN DE AUTOLOADS (Datos 3º, SaveManager 5º — Story 007), no la distribución.
- **`self.` footgun**: no aplica.

## Out of Scope

- La **lectura/parseo/versión** (produce el dict que aquí se distribuye): **Story 004**.
- El **contenido** de cada `load_state` (cómo cada sistema aplica su sub-dict, incl. tolerancia a `id` huérfano): epic dueño de cada sistema.
- El **round-trip end-to-end** con autoloads reales sobre disco: **Story 006**.
- El **registro del autoload** y el orden: **Story 007** (aunque el AC-DT depende del orden, aquí solo se prueba la distribución con listas inyectadas).

## QA Test Cases

*Logic — distribución pura con nodos-espía + espía del EventBus. `tests/unit/save_manager/save_manager_distribucion_test.gd`.*

- **`test_distribuye_subdict_por_nombre`** (AC-DT01): 2 espías con `name` `"RNGService"`/`"Tiempo"` y un `load_state` que registra el dict recibido; `_distribuir_a([rng, tiempo], {"RNGService": {...}, "Tiempo": {...}})` → cada espía recibió SU sub-dict.
- **`test_entrada_faltante_no_invalida`** (AC-DT02): dict con solo `"RNGService"`; `_distribuir_a([rng, tiempo], dict)` → `rng` recibió su sub-dict; `tiempo` NO fue llamado (mantiene defaults) + warning; sin crash.
- **`test_nodo_sin_load_state_se_ignora`** (AC-DT03): un espía sin `load_state`; `_distribuir_a([espia_malo, rng], dict)` → `espia_malo` ignorado, `rng` cargado.
- **`test_manager_no_emite_eventos`** (AC-DT04): espía del EventBus conectado a las señales (`cambio_de_turno`, `nuevo_dia`, `velocidad_cambiada`, …) con contador; `_distribuir_a(...)` con espías cuyo `load_state` NO emite → contador del bus **== 0** (el manager no re-dispara). *(Los `load_state` reales de Tiempo/RNG tampoco emiten; eso se verifica en sus propios epics y en el round-trip de la Story 006.)*

**Espías**: nodos-espía con `name` y un `load_state(d)` que guarda `d` en una var del espía (verificable). El espía del EventBus se conecta a las señales del bus y cuenta emisiones; se desconecta en teardown.

## Test Evidence

**Story Type**: Logic (distribución pura; el round-trip real es la Story 006)
**Required evidence**: `tests/unit/save_manager/save_manager_distribucion_test.gd` — debe existir y pasar (BLOCKING).

**Status**: not yet created

## Dependencies

- Depends on: **Story 002** (simetría de la clave `node.name` recolección↔distribución) y **Story 004** (recibe el dict validado/migrado que reparte).
- Unlocks: **Story 006** (round-trip end-to-end: guardar → distribuir a autoloads reales).

## Notas de gotchas del proyecto

- **`node.name` como clave** (simétrico a la recolección): renombrar un autoload rompería el emparejamiento save↔nodo → territorio del hook de migración (Story 004), documentado.
- **El manager NO emite eventos**: "cargar sitúa, no reproduce" es de los SISTEMAS (Tiempo fuerza Pausa + `sincronizar_umbrales`), no del manager. El AC-DT04 lo blinda con un espía del bus a 0 emisiones.
- **Lambdas capturan por valor → Arrays**: el `load_state` de un espía que guarda lo recibido en un `Array`/var del espía funciona porque el lambda captura la referencia mutable; para valores escalares, capturar en un objeto/dict del espía.
- **Espía del EventBus**: conectar en setup, contar, DESCONECTAR en teardown (no contaminar el autoload real; patrón de los tests de `tiempo`).
- **Preload por ruta en headless**: `preload("res://src/foundation/save_manager/save_manager.gd")`.
