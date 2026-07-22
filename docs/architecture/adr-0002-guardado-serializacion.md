# ADR-0002: Guardado y serialización de partida (JSON en user://) + RNG determinista

## Status
Accepted

## Date
2026-07-22

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (persistencia / serialización) |
| **Knowledge Risk** | MEDIUM (persistencia toca APIs post-cutoff, ya verificadas) |
| **References Consulted** | `docs/engine-reference/godot/modules/save-load.md`, `.../patterns.md`; verificación web 2026-07-22 (godot-proposals #10968; GDQuest save systems; issue "loading .tres allows arbitrary code") |
| **Post-Cutoff APIs Used** | `FileAccess.store_line`/`store_string` (devuelven `bool` desde 4.4); `JSON.stringify`/`JSON.parse` (4.x, estable) |
| **Verification Required** | (1) comprobar el `bool` de retorno de `store_*`; (2) round-trip guardar→cargar reproduce el estado exacto; (3) cargar arranca en Pausa sin re-disparar eventos |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (arranque en Pausa + `RNGService` de la Foundation) · ADR-0003 (el catálogo debe estar cargado antes de `load_state`) |
| **Enables** | El sistema de Guardado y Carga (#20) y cualquier feature que necesite persistencia |
| **Blocks** | Todo sistema con estado mutable no puede considerarse "completo" sin su `save()`/`load_state()` |
| **Ordering Note** | Foundation. Aceptar antes de codificar sistemas con estado mutable. |

## Context

### Problem Statement
Casi todos los sistemas tienen **estado que cambia al jugar** (saldo y préstamos, plantilla, layout del
edificio, colas y personas, reloj/fecha, satisfacción y reclamaciones, estado del RNG). Ese estado debe
**persistir en disco** de forma **segura** (un save no debe poder ejecutar código malicioso),
**determinista** (al cargar, la partida continúa idéntica) y **legible** (poder abrir el save para depurar).
Al cargar, la regla común de todos los GDD es: **arrancar en Pausa y no re-disparar eventos pasados**
("cargar sitúa, no reproduce").

### Constraints
- **`user://` obligatorio:** `res://` es de solo lectura en las exportaciones.
- **Seguridad:** cargar custom Resources (`.tres`/`.res`/`.tscn`) puede **ejecutar código arbitrario**
  (vía `_init`) — riesgo real si un save se comparte/manipula (verificado 2026-07-22).
- **Issue 4.6:** `ResourceSaver` reportó fallos al persistir Resources con subrecursos anidados.
- **JSON no serializa** `Vector2i`, `Color`, `Rect2` directamente → hay que descomponerlos.
- **Libro de normas (ADR-0001):** la Foundation no puede llamar a los sistemas por nombre → el guardador
  recorre un **grupo genérico `Persist`**, no nombres concretos.
- **Determinismo:** hay que serializar el estado del RNG + la semilla (exigencia del proyecto).

### Requirements
- Guardar/cargar todo el estado mutable de partida — TR-save-001, TR-time-008, TR-flow-006, TR-patience-008, TR-construction-004, etc.
- Formato **seguro** (no ejecuta código) y **legible/depurable**.
- **Determinista:** serializar el RNG → TR-save-002.
- Cargar arranca en **Pausa**, sin eventos retroactivos — TR-time-008.
- Tolerar catálogos que evolucionan entre versiones (id huérfano → migrar/descartar + log, coordinado con Datos) — TR-save/TR-data-006.

## Decision

**Guardado en JSON + `FileAccess` dentro de `user://`, con un patrón `save()`/`load_state()` por sistema
orquestado por un `SaveManager` (autoload Foundation) que recorre el grupo `Persist`.**

1. **Patrón por sistema:** cada sistema persistente implementa `save() -> Dictionary` y
   `load_state(d: Dictionary)`. Se marca con el grupo de nodos `Persist`.
2. **Orquestación (respeta el libro de normas):** `SaveManager` recorre `get_tree().get_nodes_in_group("Persist")`,
   pide a cada uno su `save()`, ensambla un diccionario raíz `{ "version": N, "rng": {...}, "<sistema>": {...} }`,
   lo pasa por `JSON.stringify` y lo escribe. **No conoce los sistemas por nombre** (grupo genérico).
3. **Tipos de Godot:** `Vector2i` (celdas del layout) → `{"x":.., "y":..}`; `Color`/otros → descomponer.
4. **Determinismo:** se serializa el estado + semilla del `RNGService` → al cargar, la secuencia futura es idéntica.
5. **Escritura segura:** escribir en un archivo temporal y **renombrar** al final (`temp` → `savegame.save`)
   para no corromper el save anterior si algo falla a mitad; comprobar el `bool` de `store_*`.
6. **Al cargar:** Datos (catálogo) ya está cargado (arranque, ADR-0003); se llama a `load_state` de cada
   sistema; Tiempo queda en **Pausa**; **no** se re-disparan eventos. Un `id` huérfano (catálogo cambió) se
   migra o descarta con log — **nunca invalida el save completo**.
7. **Versionado:** el campo `"version"` habilita migraciones futuras del formato.

### Architecture Diagram
```
  GUARDAR                                   CARGAR
  SaveManager (Foundation)                  SaveManager (Foundation)
    | recorre grupo "Persist"                 | lee user://savegame.save
    | (NO por nombre)                         | JSON.parse -> Dictionary
    v                                         v
  cada sistema: save()->Dictionary          cada sistema: load_state(dict)
    | + RNGService.save()                     | (Datos ya cargado; ids validados)
    v                                         v
  JSON.stringify -> temp -> rename          Tiempo -> PAUSA; sin eventos retroactivos
    -> user://savegame.save                   UI -> vista Comisaria
```

### Key Interfaces
```gdscript
# save_manager.gd — Autoload "SaveManager" (Foundation)
func guardar(ruta := "user://savegame.save") -> bool
func cargar(ruta := "user://savegame.save") -> bool

# Contrato que implementa cada sistema persistente (marcado con el grupo "Persist"):
func save() -> Dictionary            # devuelve SOLO datos serializables (numeros, texto, listas, dicts)
func load_state(d: Dictionary) -> void
# Invariante caller: Datos (catalogo) debe estar cargado antes de load_state.
# Garantia: tras cargar, el juego queda en Pausa y sin eventos retroactivos.
```

## Alternatives Considered

### Alternative 1: Custom Resources (`.tres`) con `ResourceSaver`
- **Description**: guardar el estado como recursos propios de Godot.
- **Pros**: integración nativa; tipado; no hay que descomponer `Vector2i`.
- **Cons**: **riesgo de seguridad** — cargar un `.tres` manipulado puede ejecutar código arbitrario
  (borrar archivos del usuario); **issue de `ResourceSaver` en 4.6** con subrecursos anidados.
- **Rejection Reason**: inseguro para datos que el jugador puede tocar/compartir; la comunidad Godot lo
  desaconseja explícitamente para saves. *(Sí se usan `.tres` para el catálogo estático del desarrollador — ver ADR-0003.)*

### Alternative 2: Binario `store_var()` / `get_var()`
- **Description**: formato binario nativo de Godot.
- **Pros**: **seguro** (desactiva la serialización de objetos → sin ejecución de código), compacto, maneja
  `Vector2i`/`Color` de forma nativa.
- **Cons**: **no es legible/depurable** — no puedes abrir el archivo y ver qué pasó.
- **Rejection Reason**: la legibilidad es muy valiosa en desarrollo (y para un equipo que aprende); el
  tamaño no es un problema en el MVP. Queda como opción de reserva si el layout creciera muchísimo.

### Alternative 3: Base de datos (SQLite)
- **Description**: guardar en una BD embebida.
- **Pros**: consultas, transacciones.
- **Cons**: dependencia extra, complejidad; innecesario para un single-player pequeño.
- **Rejection Reason**: sobredimensionado para el MVP.

## Consequences

### Positive
- **Seguro**: JSON son datos, no código → un save manipulado no ejecuta nada.
- **Legible/depurable**: abres el `.save` y lees el estado → arreglar fallos es mucho más fácil.
- **Determinista**: al serializar el RNG, cargar + continuar da la misma partida.
- **Respeta las capas**: el guardador usa el grupo `Persist`, no conoce sistemas por nombre.
- **Un solo formato** para toda la partida.

### Negative
- Hay que **descomponer** `Vector2i`/`Color` a números a mano (trivial, pero es trabajo).
- JSON pesa algo más que el binario (irrelevante en el MVP).
- Cada sistema debe implementar `save()`/`load_state()` de forma consistente (disciplina de equipo → control-manifest).

### Risks
- **Riesgo:** olvidar serializar algún estado (p. ej. el RNG) → rompe el determinismo o la carga.
  **Mitigación:** test de round-trip por sistema (guardar→cargar→comparar).
- **Riesgo:** JSON inválido (save corrupto/editado a mano) → `JSON.parse` falla.
  **Mitigación:** manejar el error, no cargar, avisar; **nunca ejecuta nada** (seguro por diseño).
- **Riesgo:** `store_*` falla (disco lleno/permisos) → save incompleto.
  **Mitigación:** comprobar el `bool`; escribir en temp + renombrar para no perder el save anterior.
- **Riesgo:** el catálogo cambia entre versiones → `id` huérfano.
  **Mitigación:** migrar/descartar con log; no invalidar el save (coordinado con Datos/ADR-0003).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| time-system.md | Serializar el reloj/fecha; al cargar arrancar en Pausa sin eventos | `save()`/`load_state()` de Tiempo + regla de carga |
| economy-budget.md | Restaurar saldo/préstamos/deuda sin cobros retroactivos | `save()` de Economía; carga sin re-disparar `nuevo_dia` |
| flow-queues.md | Restaurar colas, puestos y personas (estado, turno, posición, tiempo restante) | `save()` de Flujo por instancia |
| construction-layout.md | Persistir el layout completo (rejilla, salas, puestos, objetos) | `Vector2i`→`{x,y}` en `save()` de Construcción |
| staff-agents.md | Serializar plantilla, mercado y estado del RNG | `save()` de Personal + `RNGService.save()` |
| patience-satisfaction.md | Serializar acumulador de jornada, `sat_cierre`, contadores y paciencias | `save()` de Paciencia |
| demand-generation.md | Serializar acumulador + estado del RNG → secuencia futura idéntica | `RNGService.save()` + `save()` de Demanda |
| odac.md | Serializar la configuración de cada puesto + reputación | `save()` de ODAC |

## Performance Implications
- **CPU**: guardar/cargar es **puntual** (no por frame); `JSON.stringify`/`parse` de un save de MVP es rápido.
- **Memory**: un `Dictionary` temporal durante el guardado (despreciable).
- **Load Time**: leer/parsear un archivo pequeño → milisegundos.
- **Network**: N/A (single-player).

## Migration Plan
N/A — proyecto nuevo. El campo `"version"` del save habilita migraciones futuras del formato.

## Validation Criteria
- **Round-trip:** guardar → cargar → el estado de cada sistema es idéntico.
- **Determinismo:** cargar + continuar produce la misma secuencia que sin guardar (RNG restaurado).
- **Carga limpia:** tras cargar, el juego está en Pausa y no se han disparado eventos retroactivos.
- **Robustez:** un save con un `id` huérfano carga el resto (no se invalida); un `store_*` fallido no corrompe el save previo.

## Related Decisions
- **ADR-0001** — provee el arranque en Pausa (Tiempo) y el `RNGService` que aquí se serializa.
- **ADR-0003** — formato del **catálogo** (distinto del save): ahí `.tres` sí es válido (contenido del
  desarrollador, no del jugador); coordina la tolerancia a `id` huérfano.
- `docs/architecture/architecture.md` §3.3 (save/load) y §Principios ("cargar = situar, no reproducir").
