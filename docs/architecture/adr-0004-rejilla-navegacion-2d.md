# ADR-0004: Rejilla de construcción (TileMapLayer) + navegación 2D de NPCs (NavigationAgent2D)

## Status
Accepted

## Date
2026-07-22

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering (2D / TileMap) + Navigation |
| **Knowledge Risk** | MEDIUM-HIGH (dominios con cambios post-cutoff, verificados) |
| **References Consulted** | `docs/engine-reference/godot/modules/tilemap-2d.md`, `.../navigation.md`; `design/gdd/construction-layout.md`, `.../flow-queues.md`; verificación web 2026-07-22 (TileMapLayer 4.6 docs; AStarGrid2D vs NavigationServer; Using NavigationAgents) |
| **Post-Cutoff APIs Used** | `TileMapLayer` (reemplaza `TileMap`, 4.3+); `NavigationServer2D` dedicado (4.5); `NavigationAgent2D` — **su avoidance es Experimental en 4.6** |
| **Verification Required** | (1) `set_cell`/`local_to_map`/`map_to_local` de `TileMapLayer`; (2) fijar `target_position` **tras el 1er physics frame**; (3) **spike de rendimiento** con docenas de NPCs (QQ-02, riesgo técnico nº1) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (la navegación corre en el tick `_physics_process`; ahí aplica el *gotcha* del primer fotograma) |
| **Enables** | Los epics de Construcción #7 y del movimiento de Flujo #4 |
| **Blocks** | Construcción #7 (rejilla) y el movimiento visible de Flujo #4 |
| **Ordering Note** | *Should-have* antes de construir Construcción/Flujo. No bloquea a los sistemas Foundation. |

## Context

### Problem Statement
Dos necesidades técnicas concretas: **(1) la rejilla de construcción** —dibujar salas de tamaño libre,
colocar puestos, previsualizar la colocación bajo el ratón y validarla— y **(2) el movimiento de los NPCs**
—ciudadanos/denunciantes que caminan de la entrada a la sala de espera, al puesto y a la salida— por el
edificio, sin atravesar paredes ni quedarse atascados. Hay que fijar las APIs de Godot 4.6 para ambas.

### Constraints
- `TileMap` está **deprecado** (desde 4.3) → `TileMapLayer`.
- `NavigationServer2D` es **dedicado** desde 4.5 (mejor para 2D).
- El **avoidance** (evitación entre agentes) de `NavigationAgent2D` es **Experimental en 4.6**.
- *Gotcha:* el servidor de navegación se sincroniza en el **primer physics frame** → no fijar
  `target_position` en `_ready()`.
- **El movimiento es cosmético** (Flujo FL5: "desplazamiento breve y visible, no relevante para el balance")
  → el determinismo estricto **no se exige** del movimiento; la lógica de colas/atención/abandono sí es
  determinista (RNG sembrado, ADR-0001/0002) y **no depende de la posición exacta del sprite**.
- **Rendimiento:** docenas de NPCs navegando a la vez es el **riesgo técnico nº1** del concepto (QQ-02).
- La navegación corre en `_physics_process` (regla `bucle_de_simulacion`, ADR-0001).

### Requirements
- Rejilla con conversión ratón↔celda (preview fantasma) y validación de colocación — Construcción CO3/F6.
- Puestos/objetos como escenas con lógica, no como tiles — TR-construction-003.
- Navegación de cada Persona a puesto/sala/salida — Flujo FL1/FL5.
- 60 FPS con docenas de NPCs — presupuesto de rendimiento (QQ-02).

## Decision

**Rejilla con `TileMapLayer`; navegación con `NavigationServer2D` + `NavigationRegion2D` + `NavigationAgent2D`
(mesh-based), con el avoidance desactivado/mínimo; movimiento tratado como capa cosmética separada de la
lógica determinista.**

1. **Rejilla = `TileMapLayer`** (una capa por función: `suelo`, `paredes/salas`). La celda bajo el cursor =
   `local_to_map(get_local_mouse_position())` (preview fantasma). Validación de colocación con
   `get_cell_source_id` (solapamiento) + límites del edificio (`get_used_rect` o tamaño fijo del `Escenario`).
   Salas de tamaño libre = iterar `Vector2i` de esquina a esquina + `set_cell`.
2. **Puestos/objetos = `PackedScene`** instanciadas y posicionadas con `map_to_local(celda)` — **no** tiles
   (un puesto es un nodo con estado/lógica, no un gráfico del mapa).
3. **Navegación = `NavigationRegion2D` + `NavigationPolygon`** (el suelo caminable, *bakeado*) +
   **`NavigationAgent2D`** hijo de cada Persona (`CharacterBody2D`):
   - `nav_agent.target_position = destino`; cada `_physics_process`: si no `is_navigation_finished()`,
     moverse hacia `get_next_path_position()` con `move_and_slide()`.
   - **Avoidance desactivado/mínimo** (Experimental en 4.6): el solapamiento visual leve es aceptable
     (movimiento cosmético).
   - **Gotcha:** fijar el primer `target_position` **tras** el primer physics frame
     (`await get_tree().physics_frame`), no en `_ready()`.
   - **Re-bake** de la `NavigationPolygon` **solo cuando cambia el layout** (construir/demoler una sala o
     pared) — nunca por frame.
4. **Separación lógica ↔ presentación (clave):** el movimiento es la **capa cosmética**. La lógica de
   colas/atención/abandono (Flujo/Paciencia) es **determinista** y **no** depende de la posición del
   sprite; el "tiempo de desplazamiento" se contabiliza en la lógica (Flujo FL5), no se mide del sprite. Por
   eso el avoidance experimental (posiblemente no determinista) **no afecta** al determinismo del juego.
5. **Rendimiento (QQ-02):** la navegación mesh-based escala bien (una sala = un polígono, no muchas celdas).
   **Spike de rendimiento obligatorio** con docenas de NPCs antes de escalar el volumen. *Plan B* si el
   spike falla: degradar el movimiento (menos NPCs visibles / teleport parcial) **sin tocar la lógica**, o
   cambiar a `AStarGrid2D`.

### Architecture Diagram
```
  CONSTRUCCION (Construccion #7)            NAVEGACION (Flujo #4, capa COSMETICA)
  TileMapLayer "suelo" / "paredes"          NavigationRegion2D + NavigationPolygon (bake)
    | local_to_map(mouse) -> celda            | (re-bake solo al cambiar el layout)
    | set_cell (dibujar sala)                 v
    | validar: get_cell_source_id           Persona = CharacterBody2D + NavigationAgent2D
    v                                          | target_position = puesto/sala/salida
  Puestos/objetos = PackedScene               | _physics_process -> get_next_path_position
    posicionados con map_to_local(celda)      | (avoidance experimental -> off/minimo)
                                              v
  LOGICA (determinista, RNG) <--- NO depende de la posicion del sprite (Flujo FL5)
```

### Key Interfaces
```gdscript
# Construccion (sobre TileMapLayer)
func celda_bajo_cursor() -> Vector2i           # local_to_map(get_local_mouse_position())
func colocacion_valida(celda: Vector2i) -> bool  # get_cell_source_id + limites del edificio
func dibujar_sala(a: Vector2i, b: Vector2i) -> void   # itera Vector2i + set_cell
func posicion_de_celda(c: Vector2i) -> Vector2   # map_to_local

# Persona (CharacterBody2D con NavigationAgent2D hijo)
func ir_a(destino: Vector2) -> void            # nav_agent.target_position = destino
func _physics_process(_delta: float) -> void:
    if nav_agent.is_navigation_finished(): return
    var siguiente := nav_agent.get_next_path_position()
    velocity = global_position.direction_to(siguiente) * vel_mov
    move_and_slide()
# El PRIMER target se fija tras: await get_tree().physics_frame  (gotcha 4.x)
```

## Alternatives Considered

### Alternative 1: `TileMap` (nodo multi-capa)
- **Description**: el nodo clásico de rejilla.
- **Pros**: familiar en tutoriales antiguos.
- **Cons**: **deprecado** desde 4.3.
- **Rejection Reason**: no usar APIs deprecadas en código nuevo.

### Alternative 2: Navegación casilla-a-casilla (`AStarGrid2D`)
- **Description**: A* sobre la misma cuadrícula del `TileMapLayer`.
- **Pros**: encaja con la rejilla; 100% determinista; sin APIs experimentales; simple.
- **Cons**: rutas "en escalera" poco naturales en salas abiertas; la evitación entre agentes hay que
  hacerla a mano; escala peor en áreas grandes que el mesh.
- **Rejection Reason**: la navegación por zonas es más natural para salas abiertas (Pilar 2, "la comisaría
  está viva") y es lo idiomático/recomendado; el determinismo no se exige del movimiento cosmético.
  **Queda como plan B** de rendimiento (QQ-02).

### Alternative 3: Movimiento directo sin cálculo de ruta
- **Description**: mover cada NPC en línea recta al destino.
- **Pros**: trivial.
- **Cons**: los NPCs atravesarían paredes o se atascarían en las esquinas.
- **Rejection Reason**: rompe la credibilidad de "la comisaría está viva".

## Consequences

### Positive
- `TileMapLayer` (no deprecado) con editor de tiles y conversión ratón↔celda nativa → preview fantasma sencillo.
- Navegación mesh idiomática, fluida en salas abiertas, que **escala bien** con áreas.
- La **separación lógica/presentación** protege el determinismo del juego frente al avoidance experimental.

### Negative
- Hay que **re-bake** la `NavigationPolygon` al cambiar el layout (coste puntual al construir/demoler).
- Sin avoidance fino (experimental) → posible **solapamiento visual leve** de NPCs (aceptable, es cosmético).
- El pathfinding depende del `NavigationServer` (una "caja negra" respecto a nuestro código).

### Risks
- **Riesgo (nº1):** rendimiento con docenas de NPCs (QQ-02).
  **Mitigación:** **spike obligatorio** antes de escalar; mesh escala bien; *plan B* (degradar movimiento / `AStarGrid2D`).
- **Riesgo:** el avoidance experimental es inestable.
  **Mitigación:** desactivado/mínimo; el movimiento es cosmético → no crítico.
- **Riesgo:** olvidar el *gotcha* del primer physics frame → el primer path sale vacío.
  **Mitigación:** patrón `await get_tree().physics_frame` documentado en el control-manifest.
- **Riesgo:** re-bake por frame (costoso).
  **Mitigación:** re-bake **solo** al cambiar el layout (evento de construcción), nunca por frame.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| construction-layout.md | CO1 rejilla; CO3 dibujar salas de tamaño libre; F6 validez de colocación; preview con ratón | `TileMapLayer` + `local_to_map`/`set_cell`/`get_cell_source_id` |
| construction-layout.md | Puestos/objetos como elementos con lógica dentro de las salas | `PackedScene` posicionadas con `map_to_local`, no tiles |
| flow-queues.md | FL1 la Persona recorre el edificio; FL5 desplazamiento **breve/cosmético**, no relevante para el balance | `NavigationAgent2D` en capa cosmética; la lógica no depende del sprite |
| flow-queues.md | Muchos NPCs a la vez (riesgo técnico) | Navegación mesh que escala + spike QQ-02 |

## Performance Implications
- **CPU**: navegación en `_physics_process`; mesh escala bien; re-bake **puntual** (al construir), no por frame.
- **Memory**: la `NavigationPolygon` + un `NavigationAgent2D` por Persona.
- **Load Time**: bake inicial del suelo caminable (trivial en Pozuelo).
- **Network**: N/A. **QQ-02: spike de rendimiento obligatorio** antes de escalar el volumen de NPCs.

## Migration Plan
N/A — proyecto nuevo.

## Validation Criteria
- `TileMapLayer`: `local_to_map` da la celda bajo el cursor; la validación detecta solapamiento; dibujar una sala coloca las celdas correctas.
- Navegación: una Persona va de la entrada al puesto **sin atravesar paredes**; fijar el target tras el 1er physics frame funciona.
- **Spike QQ-02:** 60 FPS con docenas de NPCs navegando (número objetivo a fijar en el spike).
- **Separación:** la lógica (colas/abandono) es **idéntica** independientemente del movimiento del sprite.

## Related Decisions
- **ADR-0001** — el tick `_physics_process` donde corre la navegación y el *gotcha* del primer fotograma.
- `design/gdd/construction-layout.md` y `design/gdd/flow-queues.md` — los GDD que implementa.
- `docs/architecture/architecture.md` §Open Questions (QQ-02, el spike de rendimiento).
