# Godot TileMapLayer ISOMÉTRICO + Y-Sort — Quick Reference

Last verified: 2026-07-30 (vía docs.godotengine.org/en/4.6, XML de clases y RST de tutoriales de `godotengine/godot` y `godotengine/godot-docs`, rama `4.6`/`4.6-stable`, más `CHANGELOG.md` de `4.4-stable`/`4.5-stable`/`4.6-stable`) | Engine: Godot 4.6

Para el cambio de rumbo CENITAL → ISOMÉTRICO (ver `design/gdd` y art bible). Cubre: configuración del `TileSet` isométrico, conversión posición↔celda, orden de dibujo (Y-sort/z-index) y anclaje de sprites por la base.

## Qué cambió desde ~4.3 (LLM cutoff)

- El nodo `YSort` (Godot 3.x) **no existe en 4.x** — ya lo tenía documentado `deprecated-apis.md` del proyecto. Confirmado además que `doc/classes/YSort.xml` ya no existe en la rama `4.6` del repo (404), a diferencia de `3.5` donde sí existe. La propiedad equivalente es `CanvasItem.y_sort_enabled` (no `Node2D` — ver más abajo), disponible en cualquier nodo 2D.
- **4.6**: fix de un bug real de `TileMapLayer` + y-sort + capas de visibilidad (ver "Gotchas del changelog" más abajo). No hay cambios de *API* documentados en el rango 4.3→4.6 para `tile_shape`/`y_sort_enabled`/`z_index` — la mecánica parece estable desde 4.0.
- **`TileMap` sigue deprecado** (desde 4.3) → usar siempre `TileMapLayer` (ver `tilemap-2d.md`).

## 1. `TileSet` isométrico — propiedades y enums exactos

Fuente: https://docs.godotengine.org/en/4.6/classes/class_tileset.html (verificado contra `doc/classes/TileSet.xml`, rama `4.6-stable`)

### `tile_shape: TileShape`

> "The tile shape." — default `0`

| Constante exacta | Valor | Descripción exacta de la doc |
|---|---|---|
| `TileSet.TILE_SHAPE_SQUARE` | 0 | "Rectangular tile shape." |
| **`TileSet.TILE_SHAPE_ISOMETRIC`** | 1 | "Diamond tile shape (for isometric look)." |
| `TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE` | 2 | "Rectangular tile shape with one row/column out of two offset by half a tile." |
| `TileSet.TILE_SHAPE_HEXAGON` | 3 | "Hexagonal tile shape." |

Para rombo isométrico: **`TileSet.TILE_SHAPE_ISOMETRIC`**.

### `tile_layout: TileLayout`

> "For all half-offset shapes (Isometric, Hexagonal and Half-Offset square), changes the way tiles are indexed in the TileMapLayer grid." — default `0` (`TILE_LAYOUT_STACKED`)

| Constante exacta | Valor | Descripción exacta |
|---|---|---|
| `TileSet.TILE_LAYOUT_STACKED` | 0 | "...both axis stay consistent with their respective local horizontal and vertical axis." |
| `TileSet.TILE_LAYOUT_STACKED_OFFSET` | 1 | "Same as TILE_LAYOUT_STACKED, but the first half-offset is negative instead of positive." |
| `TileSet.TILE_LAYOUT_STAIRS_RIGHT` | 2 | "...horizontal axis stay horizontal, and the vertical one goes down-right." |
| `TileSet.TILE_LAYOUT_STAIRS_DOWN` | 3 | "...vertical axis stay vertical, and the horizontal one goes down-right." |
| `TileSet.TILE_LAYOUT_DIAMOND_RIGHT` | 4 | "...horizontal axis goes up-right, and the vertical one goes down-right." |
| `TileSet.TILE_LAYOUT_DIAMOND_DOWN` | 5 | "...horizontal axis goes down-right, and the vertical one goes down-left." |

⚠️ **NO VERIFICADO**: la doc oficial **no dice** "usa X para isométrico 2:1 estándar" — solo describe qué hace cada valor a nivel de indexado de coordenadas de celda. No hay un ejemplo canónico en `using_tilesets.rst`. Recomendación práctica (NO es cita de la doc): para un rombo estándar donde el atlas es una grilla rectangular simple de imágenes-rombo, `TILE_LAYOUT_STACKED` (el default) es lo más usado en tutoriales de la comunidad; probar en el editor con un atlas de prueba (tablero de ajedrez) antes de comprometerse.

### `tile_offset_axis: TileOffsetAxis`

> "For all half-offset shapes (Isometric, Hexagonal and Half-Offset square), determines the offset axis." — default `0` (`TILE_OFFSET_AXIS_HORIZONTAL`)

| Constante exacta | Valor | Descripción exacta |
|---|---|---|
| `TileSet.TILE_OFFSET_AXIS_HORIZONTAL` | 0 | "Horizontal half-offset." |
| `TileSet.TILE_OFFSET_AXIS_VERTICAL` | 1 | "Vertical half-offset." |

⚠️ **NO VERIFICADO**: la doc no indica cuál es "el correcto" para isométrico clásico. Verificar visualmente en el editor.

### `tile_size: Vector2i`

> "The tile size, in pixels. For all tile shapes, this size corresponds to the encompassing rectangle of the tile shape. This is thus the minimal cell size required in an atlas." — default `Vector2i(16, 16)`

Para un rombo 2:1 de 80×40 px, el rectángulo envolvente **es** 80×40, así que `tile_size = Vector2i(80, 40)` se deduce directamente de esta regla (no es un ejemplo numérico literal de la doc, pero es aplicación directa de una regla que sí está citada).

## 2. Configurar el TileSet isométrico por código

```gdscript
var tile_set := TileSet.new()

# Verificado: propiedad + constante existen tal cual (ver tabla arriba)
tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC

# Verificado que la propiedad/enum existen; el valor concreto (STACKED) es el
# default y el más común en tutoriales de comunidad — NO prescrito por la doc.
tile_set.tile_layout = TileSet.TILE_LAYOUT_STACKED

# Verificado que la propiedad/enum existen; el valor concreto (HORIZONTAL) es
# el default — NO prescrito por la doc como "el correcto" para isométrico.
tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL

# Verificado: Vector2i, "encompassing rectangle of the tile shape"
tile_set.tile_size = Vector2i(80, 40)

var atlas_source := TileSetAtlasSource.new()
atlas_source.texture = preload("res://assets/art/tiles/piso_iso.png")

# Verificado: "must be bigger than or equal to the TileSet's tile_size value"
atlas_source.texture_region_size = Vector2i(80, 40)

# Verificado: create_tile(atlas_coords: Vector2i, size: Vector2i = Vector2i(1, 1))
atlas_source.create_tile(Vector2i(0, 0))

# Verificado: TileSet.add_source(source: TileSetSource, atlas_source_id_override: int = -1) -> int
var source_id: int = tile_set.add_source(atlas_source)
```

## 3. `local_to_map` / `map_to_local` en modo isométrico

Fuente: `doc/classes/TileMapLayer.xml`, rama `4.6-stable` → https://docs.godotengine.org/en/4.6/classes/class_tilemaplayer.html

```
local_to_map(local_position: Vector2) const -> Vector2i
map_to_local(map_position: Vector2i) const -> Vector2
```

- `local_to_map` — cita exacta: *"Returns the map coordinates of the cell containing the given local_position. If local_position is in global coordinates, consider using Node2D.to_local before passing it to this method."* **No hay ninguna nota especial para isométrico/hexagonal** — funciona con cualquier punto dentro del rombo, sin distinción documentada por `tile_shape`.
- `map_to_local` — cita exacta: *"Returns the **centered** position of a cell in the TileMapLayer's local coordinate space... **Note:** This may not correspond to the visual position of the tile, i.e. it ignores the `TileData.texture_origin` property of individual tiles."* Confirma que devuelve el **centro geométrico del rombo**, no la posición visual final si el tile usa `texture_origin` (ver §5).

⚠️ **NO VERIFICADO**: ningún texto oficial dice explícitamente "esto resuelve automáticamente la matemática del rombo, no necesitas calcularla tú". Es una inferencia razonable (la API no distingue por forma), no una afirmación textual. `using_tilemaps.rst` **no menciona "isometric" en absoluto** (cero coincidencias, confirmado con grep del RST oficial) — el tutorial de TileMaps NO cubre isométrico paso a paso; solo `using_tilesets.rst` menciona la forma isométrica, y únicamente a nivel de configuración de Inspector (dos frases, sin matemática de coordenadas).

### Patrón oficial ratón → celda (código embebido en la doc de clase)

```gdscript
func get_clicked_tile_power():
    var clicked_cell = tile_map_layer.local_to_map(tile_map_layer.get_local_mouse_position())
    var data = tile_map_layer.get_cell_tile_data(clicked_cell)
    if data:
        return data.get_custom_data("power")
    else:
        return 0
```

`get_cell_tile_data(coords: Vector2i) -> TileData` — **sin parámetro `layer`** (a diferencia de la vieja API de `TileMap` multi-capa; `TileMapLayer` es un nodo por capa).

## 4. La textura del tile isométrico

Fuente: `doc/classes/TileSetAtlasSource.xml` → https://docs.godotengine.org/en/4.6/classes/class_tilesetatlassource.html

- `texture: Texture2D` — "The atlas texture."
- `texture_region_size: Vector2i` — "The base tile size in the texture (in pixel). This size must be bigger than or equal to the TileSet's `tile_size` value."
- `margins: Vector2i` — "Margins, in pixels, to offset the origin of the grid in the texture."
- `separation: Vector2i` — "Separation, in pixels, between each tile texture region of the grid."
- `use_texture_padding: bool` — "If true, generates an internal texture with an additional one pixel padding around each tile."

**`texture_origin` NO existe en `TileSetAtlasSource`.** Vive en `TileData` (por-celda), obtenido vía `atlas_source.get_tile_data(atlas_coords, alternative_tile)` o `tile_map_layer.get_cell_tile_data(coords)`:

- `TileData.texture_origin: Vector2i` (default `Vector2i(0, 0)`) — "Offsets the position of where the tile is drawn." Útil cuando el gráfico de un tile es más alto que el rombo base (p. ej. una pared) y hay que desplazar el dibujo hacia arriba respecto a la celda.

⚠️ **NO VERIFICADO**: ni `using_tilesets.rst` ni `using_tilemaps.rst` dan recomendación de tamaño/proporción/transparencia de textura para tiles isométricos (no hay mención de "recorta la textura en forma de rombo" ni de proporción 2:1 como estándar oficial — es práctica de facto de la industria, no texto de Godot).

## 5. Y-sort y z-index — dónde vive cada propiedad y la regla de precedencia

Fuente: `doc/classes/CanvasItem.xml`, rama `4.6` → https://docs.godotengine.org/en/4.6/classes/class_canvasitem.html

- **`y_sort_enabled: bool`** (default `false`) — vive en **`CanvasItem`**, NO en `Node2D` (Node2D solo la hereda; no está redeclarada en su XML). Cita exacta completa:

  > "If `true`, this and child CanvasItem nodes with a higher Y position are rendered in front of nodes with a lower Y position. If `false`, this and child CanvasItem nodes are rendered normally in scene tree order.
  > With Y-sorting enabled on a parent node ('A') but disabled on a child node ('B'), the child node ('B') is sorted but its children ('C1', 'C2', etc.) render together on the same Y position as the child node ('B'). This allows you to organize the render order of a scene without changing the scene tree.
  > **Nodes sort relative to each other only if they are on the same `z_index`.**"

  Esto responde a la regla exacta pedida:
  - El y-sort ordena **hijos directos** de un nodo con `y_sort_enabled = true`. **No es recursivo** por defecto: si un hijo B tiene `y_sort_enabled = false`, sus propios hijos (nietos de A) NO se ordenan entre sí — se mueven en bloque, pegados a la Y de B. Para que el ordenamiento se propague otro nivel, hay que activar `y_sort_enabled` también en B.
  - **Precedencia**: primero se agrupa por `z_index` (grupos distintos nunca se entrelazan); **dentro** de cada grupo del mismo `z_index` es donde aplica el y-sort. El y-sort JAMÁS hace que un `z_index` menor se dibuje delante de uno mayor.

- **`z_index: int`** — cita exacta: *"The order in which this node is drawn. A node with a higher Z index will display in front of others... **Note:** The Z index does not affect the order in which CanvasItem nodes are processed or the way input events are handled."*
- **`z_as_relative: bool`** — cita exacta: *"If true, this node's final Z index is relative to its parent's Z index. For example, if z_index is 2 and its parent's final Z index is 3, then this node's final Z index will be 5 (2 + 3)."*

⚠️ Consecuencia práctica (no cita textual, deducción de la regla de arriba): si personajes/paredes van a compartir el mismo grupo de y-sort, hay que asegurarse de que todos terminen con el **mismo `z_index` efectivo** (cuidado con `z_as_relative` heredado de padres distintos) — si no, el y-sort dentro de cada grupo deja de "verse" entre sí.

## 6. `y_sort_origin` — `TileMapLayer` (capa) y `TileData` (por-tile)

Fuente: `doc/classes/TileMapLayer.xml` y `doc/classes/TileData.xml`, rama `4.6-stable`.

- **`TileMapLayer.y_sort_origin: int`** (default `0`) — cita exacta: *"This Y-sort origin value is added to each tile's Y-sort origin value. This allows, for example, to fake a different height level. This can be useful for top-down view games."* El tutorial (`using_tilemaps` — sección de propiedades del nodo en el Inspector) aclara que está **en píxeles** y que *"Only effective if Y Sort Enabled under CanvasItem settings is true."*
- **`TileData.y_sort_origin: int`** (default `0`), por CELDA/tile — cita exacta: *"Vertical point of the tile used for determining y-sorted order."* Confirmado en `using_tilesets` (propiedades pintables por tile): sirve exactamente para **tiles con distinta altura visual** (p. ej. paredes vs. suelo) — *"This allows using layers as if they were on different height for top-down games. Adjusting this can help alleviate issues with sorting certain tiles."* Solo tiene efecto si `y_sort_enabled` está activo en el `TileMapLayer`.
- **`TileData.z_index: int`** (default `0`) — cita exacta: *"Ordering index of this tile, relative to TileMapLayer."* (Distinto de `y_sort_origin`: esto es z_index por-tile, no el punto de ordenamiento vertical.)
- **`TileMapLayer.y_sort_enabled`** — no está redeclarada en `TileMapLayer.xml`; es la propiedad heredada de `CanvasItem` (§5), confirmada por el tutorial: *"under CanvasItem > Ordering"*. Actívala en el propio `TileMapLayer` para que sus celdas se ordenen entre sí y con otros `CanvasItem` hermanos (personajes) del mismo padre — misma regla de precedencia con `z_index` de §5, sin mecanismo especial adicional.
- **`TileMapLayer.x_draw_order_reversed: bool`** — cita exacta: *"If CanvasItem.y_sort_enabled is enabled, setting this to true will reverse the order the tiles are drawn on the X-axis."*

## 7. Anclaje de `Sprite2D` por la base (pies)

Fuente: `doc/classes/Sprite2D.xml` → https://docs.godotengine.org/en/4.6/classes/class_sprite2d.html

- **`centered: bool`** (default `true`) — cita exacta: *"If true, texture is centered."* (más nota sobre pixel art y snapping, no relevante aquí).
- **`offset: Vector2`** (default `Vector2(0, 0)`) — cita exacta: *"The texture's drawing offset. **Note:** When you increase offset.y in Sprite2D, the sprite moves downward on screen (i.e., +Y is down)."*

⚠️ **NO VERIFICADO**: la doc **no dice explícitamente** desde qué esquina se dibuja el sprite cuando `centered = false` (búsqueda de "corner"/"top-left" sin resultados en el XML). Tampoco hay ningún ejemplo oficial de código para anclar por la base. Patrón deducido (no citado, pero consecuencia directa de la semántica de `offset` arriba): con `centered = true` (default), el origen de dibujo es el centro; para anclar visualmente por los pies, desplazar el offset hacia arriba la mitad de la altura del sprite: `offset = Vector2(0, -altura_px / 2.0)`. Equivalente por-tile: `TileData.texture_origin` (§4).

## 8. Gotchas del changelog (4.4 → 4.6)

Verificado en `CHANGELOG.md` de cada rama estable (no `master`, que ya está en ciclo 4.7):

| Versión | Cambio (cita/paráfrasis del changelog) | Referencia |
|---|---|---|
| **4.6** | Fix: `TileMapLayer` tiles displaying incorrectly with `y_sort` based on visibility layer | `godotengine/godot` `4.6-stable/CHANGELOG.md`, GH-110550 |
| **4.5** | Ningún cambio relacionado con y-sort/z-index/isométrico encontrado (grep sin resultados) | `4.5-stable/CHANGELOG.md` |
| **4.4** | Fix: Account for physics interpolation and transform snapping when Y-sorting | `4.4-stable/CHANGELOG.md`, GH-93025 |
| **4.4** | Fix: Y-sorted root item having modulation applied twice | `4.4-stable/CHANGELOG.md`, GH-95669 |

Release notes oficiales (godotengine.org/releases/4.5 y /4.6): sin mención a y-sort/isométrico. Lo único remotamente relacionado con `TileMapLayer` es "Rotatable scene tiles" (4.6, sin relación con orden de dibujo) y "Chunk tilemap physics" (4.5, física, sin relación con y-sort). **Conclusión**: el proyecto está en 4.6, así que el bug GH-110550 ya está corregido — no requiere workaround, pero conviene tenerlo presente si algún día se hace downgrade a 4.5.

## 9. Rendimiento

- **No hay ninguna advertencia oficial general** sobre el coste de `y_sort_enabled` en `CanvasItem` (ni en la referencia de clase ni en `general_optimization.rst` / `cpu_optimization.rst` / `gpu_optimization.rst` — grep sin resultados para "y_sort"/"z_index"/"sort").
- Sí hay un dato oficial específico de `TileMapLayer` (sección "Rendering Quadrant Size" del tutorial `using_tilemaps`): normalmente Godot agrupa tiles en "cuadrantes" dibujados como un único `CanvasItem` (optimización). Cita exacta: *"The quadrant size does not apply to a Y sorted TileMapLayer since tiles are grouped by Y position in that case."* → **activar y-sort en un `TileMapLayer` desactiva esa optimización de agrupado por cuadrantes**; cada tile pasa a necesitar su propia posición de orden. Es el único indicio oficial de coste — no está cuantificado.
- ⚠️ **NO VERIFICADO**: no existe una nota oficial tipo "evita y-sort en nodos con muchos hijos" ni "recalcula el orden cada frame" — es plausible por cómo funciona el sorting dinámico, pero no hay cita oficial que lo confirme.

## Checklist de migración cenital → isométrico

- [ ] `TileSet.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC` en el/los TileSet de suelo y paredes.
- [ ] Probar `tile_layout` / `tile_offset_axis` visualmente en el editor (la doc no prescribe un valor único — ver §1).
- [ ] `tile_size` = rectángulo envolvente del rombo (p. ej. `Vector2i(80, 40)` para un 2:1 de 80 px de ancho).
- [ ] Tiles con altura visual (paredes, muebles) → configurar `TileData.texture_origin` (offset de dibujo) y `TileData.y_sort_origin` (punto de ordenamiento) por tile, NO asumir que `map_to_local` ya lo resuelve (ignora `texture_origin` — ver §3).
- [ ] Activar `y_sort_enabled` (heredado de `CanvasItem`) en el `TileMapLayer` de paredes/objetos Y en el nodo padre común de los personajes, para que compartan el mismo grupo de ordenamiento — vigilar que todos terminen con el mismo `z_index` efectivo (§5).
- [ ] Anclar personajes por los pies: `Sprite2D`/`AnimatedSprite2D` con `offset.y` negativo (mitad de la altura) — no hay API dedicada "anchor bottom", es a mano (§7).
- [ ] Conversión ratón→celda: `tile_map_layer.local_to_map(tile_map_layer.get_local_mouse_position())` (patrón oficial, §3) — no `local_to_map(get_global_mouse_position())` directo (no acepta coordenadas globales sin convertir antes).

## Errores comunes

- Asumir que `map_to_local` devuelve la posición visual final del tile: devuelve el CENTRO geométrico de la celda e **ignora `TileData.texture_origin`** — para tiles con offset visual hay que sumarlo a mano.
- Poner `y_sort_enabled` solo en un nodo intermedio y esperar que ordene a los nietos: **no es recursivo** — hay que activarlo en cada nivel que deba ordenarse independientemente.
- Mezclar nodos con distinto `z_index` efectivo (por `z_as_relative` heredado) dentro de lo que debería ser un mismo grupo de y-sort: el y-sort solo compara nodos con el **mismo** `z_index`.
- Buscar un tutorial oficial paso a paso de isométrico en `using_tilemaps.rst`: no existe (cero menciones a "isometric" en ese tutorial) — la única mención oficial de configuración está en `using_tilesets.rst`, y es breve.
- Olvidar que `get_cell_tile_data(coords)` en `TileMapLayer` **no** lleva parámetro `layer` (a diferencia de la vieja `TileMap`).
