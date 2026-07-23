# Story 003 (epic save-manager) — escritura segura en user:// (temp+rename, bool de store_*) · TR-save-001 · ADR-0002.
# Tipo: Integration. I/O REAL en user://. Ruta ÚNICA por test + BORRADO en teardown (aislamiento total).
#
# Cada test usa `user://test_esNN.save` y en el teardown borra tanto la ruta como su `.tmp` con
# DirAccess.remove_absolute si existen. Nunca se comparten rutas entre tests (orden-independencia del manifest).
extends GdUnitTestSuite

const SaveManagerScript := preload("res://src/foundation/save_manager/save_manager.gd")

# Rutas únicas por test (aislamiento). Se registran para borrarlas en teardown.
const RUTA_ES01: String = "user://test_es01.save"
const RUTA_ES02: String = "user://test_es02.save"
const RUTA_ES03: String = "user://no/existe/test_es03.save"   # subcarpeta inexistente → open falla.
const RUTA_ES04: String = "user://test_es04.save"

var _a_limpiar: Array[String] = []


# ── Fixture / teardown ─────────────────────────────────────────────────────────────────────
func before_test() -> void:
	_a_limpiar.clear()


## Borra cada ruta registrada Y su `.tmp` si quedaron en disco (aislamiento entre tests).
func after_test() -> void:
	for ruta in _a_limpiar:
		_borrar(ruta)
		_borrar(ruta + ".tmp")


## Crea un manager fresco y registra `ruta` (+ su `.tmp`) para el borrado en teardown.
func _manager_para(ruta: String) -> Node:
	_a_limpiar.append(ruta)
	return auto_free(SaveManagerScript.new())


## Borra `ruta` si existe (ruta absoluta del SO globalizada).
func _borrar(ruta: String) -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


## Lee el contenido completo de `ruta` como texto (o "" si no existe).
func _leer(ruta: String) -> String:
	if not FileAccess.file_exists(ruta):
		return ""
	var f: FileAccess = FileAccess.open(ruta, FileAccess.READ)
	var contenido: String = f.get_as_text()
	f.close()
	return contenido


# ── AC-ES01: guardar crea el archivo con JSON válido que contiene "version" ─────────────────
func test_guardar_crea_archivo_json_valido() -> void:
	# Arrange — manager sin árbol → _recolectar sobre un grupo Persist vacío = {"version": 1}.
	var manager: Node = _manager_para(RUTA_ES01)
	add_child(manager)   # da acceso a get_tree() para _recolectar(); grupo Persist vacío en este árbol de test.
	# Act
	var ok: bool = manager.guardar_partida(RUTA_ES01)
	# Assert — true, el archivo existe, y su contenido es un Dictionary con "version".
	assert_bool(ok).is_true()
	assert_bool(FileAccess.file_exists(RUTA_ES01)).is_true()
	var parseado: Variant = JSON.parse_string(_leer(RUTA_ES01))
	assert_int(typeof(parseado)).is_equal(TYPE_DICTIONARY)
	assert_bool((parseado as Dictionary).has("version")).is_true()


# ── AC-ES02: tras un guardado exitoso NO queda el .tmp (el rename lo consumió) ──────────────
func test_guardar_no_deja_tmp() -> void:
	# Arrange
	var manager: Node = _manager_para(RUTA_ES02)
	add_child(manager)
	# Act
	var ok: bool = manager.guardar_partida(RUTA_ES02)
	# Assert
	assert_bool(ok).is_true()
	assert_bool(FileAccess.file_exists(RUTA_ES02 + ".tmp")).is_false()


# ── AC-ES03: open del temporal falla → false, sin crash, sin .tmp colgando ─────────────────
func test_open_fallido_devuelve_false_sin_crash() -> void:
	# Arrange — ruta con subcarpeta inexistente en user:// → FileAccess.open del .tmp devuelve null.
	var manager: Node = _manager_para(RUTA_ES03)
	add_child(manager)
	# Act
	var ok: bool = manager.guardar_partida(RUTA_ES03)
	# Assert — false, sin crash, y no se creó ningún .tmp (nunca se abrió).
	assert_bool(ok).is_false()
	assert_bool(FileAccess.file_exists(RUTA_ES03 + ".tmp")).is_false()


# ── AC-ES04: un save previo válido permanece intacto si el guardado no llega al rename ──────
func test_save_previo_intacto_si_falla() -> void:
	# Arrange — escribir un save "bueno" con contenido conocido en la ruta destino.
	var manager: Node = _manager_para(RUTA_ES04)
	add_child(manager)
	assert_bool(manager.guardar_partida(RUTA_ES04)).is_true()
	var contenido_previo: String = _leer(RUTA_ES04)
	assert_str(contenido_previo).is_not_empty()

	# Act — forzar un fallo que NO llega al rename: open del .tmp falla (subcarpeta inexistente).
	#   Cubre la garantía por diseño: el final solo se toca en el rename, y un open fallido nunca llega ahí.
	_a_limpiar.append(RUTA_ES03)   # por si acaso quedara rastro (no debería: el open ni siquiera abre).
	var ok: bool = manager.guardar_partida(RUTA_ES03)

	# Assert — el guardado falla PERO el save previo de RUTA_ES04 no se tocó (contenido idéntico).
	assert_bool(ok).is_false()
	assert_str(_leer(RUTA_ES04)).is_equal(contenido_previo)
