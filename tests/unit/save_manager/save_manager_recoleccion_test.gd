# Story 002 (epic save-manager) — recolección grupo "Persist" → dict raíz con "version" · TR-save-001 · ADR-0002.
# Tipo: Logic. Recolección pura con nodos-espía, sin árbol real ni I/O.
#
# El método interno `_recolectar_de(nodos)` recibe la lista por parámetro → NO hace falta add_to_group ni árbol.
# Los espías son `Node` con `name` fijado ANTES de leerlo y un `save()` que devuelve un dict constante conocido.
# Preload por ruta literal (autoload sin registrar / class_name en frío).
extends GdUnitTestSuite

const SaveManagerScript := preload("res://src/foundation/save_manager/save_manager.gd")
const EspiaScript := preload("res://tests/unit/save_manager/persist_espia.gd")


# ── Helper de fixture ────────────────────────────────────────────────────────────────────
## Crea un nodo-espía Persist con `name` fijado y un `save()` que devuelve `datos` (dict constante).
func _espia(nombre: String, datos: Dictionary) -> Node:
	var e: Node = auto_free(EspiaScript.new())
	e.name = nombre                 # fijar name ANTES de leerlo (el método interno no lo mete en el árbol).
	e.datos_save = datos
	return e


# ── AC-RC01: el dict recolectado incluye "version" == 1 ────────────────────────────────────
func test_recolecta_incluye_version() -> void:
	# Arrange
	var manager: Node = auto_free(SaveManagerScript.new())
	# Act
	var raiz: Dictionary = manager._recolectar_de([])
	# Assert
	assert_bool(raiz.has("version")).is_true()
	assert_int(raiz["version"]).is_equal(1)


# ── AC-RC02: una entrada por nodo (clave = node.name, valor = su save()) ────────────────────
func test_recolecta_una_entrada_por_nodo() -> void:
	# Arrange — 2 espías con nombres de autoload estables y saves conocidos.
	var manager: Node = auto_free(SaveManagerScript.new())
	var rng: Node = _espia("RNGService", {"semilla": "2024", "estado": "99"})
	var tiempo: Node = _espia("Tiempo", {"minutos_juego": 930.0, "semana": 3})
	# Act
	var raiz: Dictionary = manager._recolectar_de([rng, tiempo])
	# Assert — entrada por nombre con el valor EXACTO devuelto por cada save().
	assert_bool(raiz.has("RNGService")).is_true()
	assert_bool(raiz.has("Tiempo")).is_true()
	assert_dict(raiz["RNGService"]).is_equal({"semilla": "2024", "estado": "99"})
	assert_dict(raiz["Tiempo"]).is_equal({"minutos_juego": 930.0, "semana": 3})
	# version + 2 sistemas = 3 claves (sin entradas espurias).
	assert_int(raiz.size()).is_equal(3)


# ── AC-RC03: grupo vacío → exactamente {"version": 1} ──────────────────────────────────────
func test_recolecta_grupo_vacio() -> void:
	# Arrange
	var manager: Node = auto_free(SaveManagerScript.new())
	# Act
	var raiz: Dictionary = manager._recolectar_de([])
	# Assert — exactamente {"version": 1}, sin entradas espurias.
	assert_dict(raiz).is_equal({"version": 1})


# ── AC-RC04: el dict recolectado es JSON-serializable (round-trip stringify/parse) ─────────
func test_recolectado_es_json_serializable() -> void:
	# Arrange — espías cuyos save() devuelven solo tipos serializables (string, float, int).
	var manager: Node = auto_free(SaveManagerScript.new())
	var rng: Node = _espia("RNGService", {"semilla": "2024", "estado": "99"})
	var tiempo: Node = _espia("Tiempo", {"minutos_juego": 930.0, "semana": 3})
	var raiz: Dictionary = manager._recolectar_de([rng, tiempo])
	# Act
	var texto: String = JSON.stringify(raiz)
	var parseado: Variant = JSON.parse_string(texto)
	# Assert — stringify produce texto no vacío y parse reproduce un Dictionary con "version".
	assert_str(texto).is_not_empty()
	assert_int(typeof(parseado)).is_equal(TYPE_DICTIONARY)
	assert_bool((parseado as Dictionary).has("version")).is_true()


# ── Extra defensivo: un nodo del grupo SIN save() se ignora, no peta (has_method defensivo) ─
func test_nodo_sin_save_se_ignora() -> void:
	# Arrange — un espía válido + un Node pelado (sin método save()).
	var manager: Node = auto_free(SaveManagerScript.new())
	var valido: Node = _espia("RNGService", {"k": 1})
	var sin_contrato: Node = auto_free(Node.new())
	sin_contrato.name = "SinContrato"
	# Act
	var raiz: Dictionary = manager._recolectar_de([valido, sin_contrato])
	# Assert — solo el válido entra; el pelado se ignora sin petar (version + 1 = 2 claves).
	assert_bool(raiz.has("RNGService")).is_true()
	assert_bool(raiz.has("SinContrato")).is_false()
	assert_int(raiz.size()).is_equal(2)
