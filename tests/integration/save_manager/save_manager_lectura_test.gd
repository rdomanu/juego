# Story 004 (epic save-manager) — lectura + parseo + chequeo de "version" (hook de migraciones) · TR-save-001 · ADR-0002.
# Tipo: Integration. Lee fixtures REALES de user:// (válidos generados con `guardar_partida`; corruptos escritos a
# mano con FileAccess). Ruta ÚNICA por test + BORRADO en teardown (ruta y su `.tmp`) → aislamiento total.
#
# El foco de la story es el manejo SEGURO y ROBUSTO: archivo ausente / JSON inválido / falta "version" / versión
# futura → `false` + log, SIN crashear. `JSON.parse_string` devuelve null ante texto inválido (no lanza), de ahí
# el chequeo `typeof == TYPE_DICTIONARY`. Los push_error/push_warning de los casos de fallo son intencionados.
extends GdUnitTestSuite

const SaveManagerScript := preload("res://src/foundation/save_manager/save_manager.gd")

# Rutas únicas por test (aislamiento). Se registran para borrarlas (+ su `.tmp`) en teardown.
const RUTA_LC01: String = "user://test_lc01_no_existe.save"
const RUTA_LC02_TXT: String = "user://test_lc02_no_json.save"
const RUTA_LC02_ARR: String = "user://test_lc02_array.save"
const RUTA_LC03: String = "user://test_lc03_sin_version.save"
const RUTA_LC04_FUT: String = "user://test_lc04_version_futura.save"
const RUTA_LC04_OK: String = "user://test_lc04_version_uno.save"

var _a_limpiar: Array[String] = []


# ── Fixture / teardown ─────────────────────────────────────────────────────────────────────
func before_test() -> void:
	_a_limpiar.clear()


## Borra cada ruta registrada Y su `.tmp` si quedaron en disco (aislamiento entre tests).
func after_test() -> void:
	for ruta in _a_limpiar:
		_borrar(ruta)
		_borrar(ruta + ".tmp")


## Crea un manager fresco añadido al árbol (para que `_distribuir` pueda usar `get_tree()`), y registra
## `ruta` para el borrado en teardown. El grupo "Persist" está vacío en el árbol de test → distribuir no hace nada.
func _manager_para(ruta: String) -> Node:
	_a_limpiar.append(ruta)
	var manager: Node = auto_free(SaveManagerScript.new())
	add_child(manager)
	return manager


## Escribe `texto` crudo en `ruta` (fixture corrupto/inválido escrito a mano con FileAccess).
func _escribir_texto(ruta: String, texto: String) -> void:
	var f: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(texto)
	f.close()


## Borra `ruta` si existe (ruta absoluta del SO globalizada).
func _borrar(ruta: String) -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


# ── AC-LC01: ruta inexistente → false, sin crash ────────────────────────────────────────────
func test_ruta_inexistente_devuelve_false() -> void:
	# Arrange — la ruta NO existe (no se escribe nada); se registra por si un futuro cambio la crease.
	var manager: Node = _manager_para(RUTA_LC01)
	_borrar(RUTA_LC01)   # garantía de que no existe (aislamiento frente a runs previos).
	# Act
	var ok: bool = manager.cargar_partida(RUTA_LC01)
	# Assert — false y sin crash (push_warning intencionado).
	assert_bool(ok).is_false()


# ── AC-LC02: texto NO-JSON → false, sin crash (parse_string devuelve null) ──────────────────
func test_json_invalido_devuelve_false() -> void:
	# Arrange — texto que NO es JSON válido escrito a mano.
	var manager: Node = _manager_para(RUTA_LC02_TXT)
	_escribir_texto(RUTA_LC02_TXT, "esto no es json {")
	# Act
	var ok: bool = manager.cargar_partida(RUTA_LC02_TXT)
	# Assert — false, sin crash (verifica el manejo del null de parse_string).
	assert_bool(ok).is_false()


# ── AC-LC02 (variante): JSON válido pero NO es un objeto (array) → false ─────────────────────
func test_json_array_no_es_objeto_devuelve_false() -> void:
	# Arrange — "[1,2]" parsea a un Array (typeof != TYPE_DICTIONARY).
	var manager: Node = _manager_para(RUTA_LC02_ARR)
	_escribir_texto(RUTA_LC02_ARR, "[1, 2]")
	# Act
	var ok: bool = manager.cargar_partida(RUTA_LC02_ARR)
	# Assert — false: un array no es un save reconocible.
	assert_bool(ok).is_false()


# ── AC-LC03: JSON válido SIN "version" → false + log ────────────────────────────────────────
func test_falta_version_devuelve_false() -> void:
	# Arrange — objeto JSON válido pero sin la clave "version".
	var manager: Node = _manager_para(RUTA_LC03)
	_escribir_texto(RUTA_LC03, JSON.stringify({"Tiempo": {"minutos_juego": 930.0}}))
	# Act
	var ok: bool = manager.cargar_partida(RUTA_LC03)
	# Assert — false: no es un save reconocible (push_error intencionado).
	assert_bool(ok).is_false()


# ── AC-LC04: version MAYOR que la actual → RECHAZADO (false) ─────────────────────────────────
func test_version_futura_se_rechaza() -> void:
	# Arrange — save con una versión del futuro (99) que el MVP no sabe leer.
	var manager: Node = _manager_para(RUTA_LC04_FUT)
	_escribir_texto(RUTA_LC04_FUT, JSON.stringify({"version": 99, "Tiempo": {"minutos_juego": 930.0}}))
	# Act
	var ok: bool = manager.cargar_partida(RUTA_LC04_FUT)
	# Assert — false: rechazo por versión futura (push_error intencionado).
	assert_bool(ok).is_false()


# ── AC-LC04 (positivo): version == 1 NO se rechaza por versión (fixture generado con guardar_partida) ──
func test_version_actual_no_se_rechaza_por_version() -> void:
	# Arrange — fixture REAL escrito con `guardar_partida` (grupo Persist vacío → {"version": 1}).
	var manager: Node = _manager_para(RUTA_LC04_OK)
	assert_bool(manager.guardar_partida(RUTA_LC04_OK)).is_true()
	# Act — cargar el save recién escrito.
	var ok: bool = manager.cargar_partida(RUTA_LC04_OK)
	# Assert — true: pasa la versión y la distribución (grupo vacío → no hace nada, no invalida).
	assert_bool(ok).is_true()
