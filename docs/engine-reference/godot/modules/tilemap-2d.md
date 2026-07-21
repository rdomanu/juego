# Godot TileMapLayer (2D grid) — Quick Reference

Last verified: 2026-07-22 (via docs.godotengine.org/en/4.6) | Engine: Godot 4.6

Para la **rejilla de construcción** de Comisario (Construcción #7: salas de tamaño libre, puestos, objetos por celda).

## Qué cambió desde ~4.3 (LLM cutoff)

- **`TileMap` está DEPRECADO** (desde 4.3) → usar **`TileMapLayer`** (un nodo por capa, en vez de un nodo multi-capa). NUNCA usar `TileMap` en código nuevo.
- **4.6:** los *scene tiles* ahora se pueden **rotar** como los atlas tiles.

## API de código (Godot 4.6) — verificada

### Colocar / borrar celdas
```gdscript
# Colocar un tile en una celda de la rejilla
set_cell(coords: Vector2i, source_id: int = -1, atlas_coords: Vector2i = Vector2i(-1,-1), alternative_tile: int = 0)
# Borrar la celda
erase_cell(coords: Vector2i)
```
- `source_id`: qué `TileSetSource` (qué "hoja" de tiles).
- `atlas_coords`: posición del tile dentro del atlas.
- `alternative_tile`: variante (rotación/flip).

### Leer una celda
```gdscript
get_cell_source_id(coords: Vector2i) -> int          # -1 si vacía
get_cell_atlas_coords(coords: Vector2i) -> Vector2i  # (-1,-1) si vacía
get_cell_alternative_tile(coords: Vector2i) -> int
```

### Conversión posición ↔ rejilla (clave para colocar con el ratón)
```gdscript
local_to_map(local_position: Vector2) -> Vector2i    # píxel/local → celda
map_to_local(map_position: Vector2i) -> Vector2      # celda → centro en píxel/local
```
*(Para el ratón: `local_to_map(get_local_mouse_position())` da la celda bajo el cursor — base del "preview fantasma" de Construcción.)*

### Consultar el mapa
```gdscript
get_used_cells() -> Array[Vector2i]   # todas las celdas con tile
get_used_rect() -> Rect2i             # rectángulo que encierra lo usado
```

### Propiedad
- `tile_set: TileSet` — el `TileSet` con las texturas, colisiones y comportamiento de todos los tiles.

## Patrones para Comisario

- **La rejilla del edificio** = una o varias `TileMapLayer` (p. ej. capa "suelo", capa "paredes/salas").
- **Validación de colocación** (Construcción F6): usar `local_to_map` para la celda bajo el cursor + `get_cell_source_id` para comprobar solapamiento; comparar contra los límites del edificio (`get_used_rect` o un tamaño fijo del Escenario).
- **Salas de tamaño libre** (arrastrar rectángulo): iterar `Vector2i` de la esquina A a la B y `set_cell` en cada celda; el coste = `coste_base + coste_por_celda × area` (Construcción F1).
- **Puestos/objetos**: pueden ser escenas (`PackedScene`) instanciadas y posicionadas con `map_to_local(celda)`, NO tiles del TileMap (un puesto es un nodo con lógica, no solo un gráfico).

## Errores comunes
- Usar `TileMap` (deprecado) en vez de `TileMapLayer`.
- Olvidar que `set_cell`/`get_cell_*` usan **`Vector2i`** (coordenadas de celda), no píxeles → convertir con `local_to_map`/`map_to_local`.
- Meter la lógica de un puesto (que tiene estado/atención) en un tile: los puestos son nodos/escenas; el TileMap es el suelo/paredes.
