class_name SerialUtil
## SerialUtil — helper ESTÁTICO para traducir tipos nativos de Godot a/desde representaciones JSON-safe.
##
## JSON no conoce `Vector2i`/`Color`/`Rect2`: hay que DESCOMPONERLOS a `Dictionary`/`Array` de números al
## guardar y RECONSTRUIRLOS al cargar. Este helper centraliza esa aritmética para que cualquier sistema
## (Construcción, Flujo…) la use en SUS propios `save()`/`load_state()` sin duplicarla y SIN depender del
## autoload `SaveManager` (corre antes de que el manager ensamble nada).
##
## Lleva `class_name` a propósito (NO es autoload): se invoca por su nombre de clase (`SerialUtil.vec2i_a_dict(...)`)
## sin instanciar. El autoload `SaveManager` (Story 002) va SIN `class_name` para no colisionar con el singleton.
##
## SOLO `static func`: sin estado, sin `_init`, sin nodos, sin I/O (lógica pura → testeable sin disco).
##
## Story: production/epics/save-manager/story-001-serial-util.md · ADR-0002 · TR-save-003

# ── Vector2i ↔ {"x", "y"} ────────────────────────────────────────────────────────────────
## Descompone un `Vector2i` en `{"x": int, "y": int}` (JSON-serializable). Las celdas del layout de
## Construcción son `Vector2i` → esta es la representación que sobrevive un round-trip por JSON.
static func vec2i_a_dict(v: Vector2i) -> Dictionary:
	return {"x": v.x, "y": v.y}


## Reconstruye un `Vector2i` desde `{"x", "y"}`. Defensivo: si falta alguna clave (save parcial/manipulado)
## devuelve `Vector2i.ZERO` y avisa, sin petar.
##
## `int(...)` es OBLIGATORIO, no cosmético: tras `JSON.parse_string` un `3` guardado vuelve como `3.0`
## (float) → el cast explícito lo normaliza y documenta la intención bajo tipado estático estricto.
static func dict_a_vec2i(d: Dictionary) -> Vector2i:
	if not d.has("x") or not d.has("y"):
		push_warning("SerialUtil.dict_a_vec2i: faltan claves x/y -> Vector2i.ZERO")
		return Vector2i.ZERO
	return Vector2i(int(d["x"]), int(d["y"]))


# ── Hueco reservado para tipos futuros (YAGNI: solo `Vector2i` tiene consumidor real ahora) ──
# Cuando Construcción/Presentation lo necesiten, añadir aquí siguiendo el MISMO patrón descomponer/reconstruir:
#   Color → {"r", "g", "b", "a"}:  color_a_dict(c: Color) / dict_a_color(d: Dictionary)
#   Rect2 → {"x", "y", "w", "h"}:  rect2_a_dict(r: Rect2) / dict_a_rect2(d: Dictionary)
# NO implementar sin consumidor: ningún sistema los serializa todavía.
