# Story 001 (epic save-manager) — helper JSON-safe Vector2i↔{x,y} · TR-save-003 · ADR-0002.
# Tipo: Logic. Funciones estáticas puras, deterministas. Sin I/O ni árbol.
#
# Preload por ruta literal (class_name en frío no resuelve en el runner headless): `SU.vec2i_a_dict(...)`.
extends GdUnitTestSuite

const SU := preload("res://src/foundation/save_manager/serial_util.gd")


# ── AC-SU01: vec2i_a_dict descompone a {"x","y"} exactos ───────────────────────────────────
func test_vec2i_a_dict_descompone() -> void:
	# Arrange
	var v: Vector2i = Vector2i(3, 7)
	# Act
	var d: Dictionary = SU.vec2i_a_dict(v)
	# Assert — claves y valores exactos.
	assert_int(d.size()).is_equal(2)
	assert_int(d["x"]).is_equal(3)
	assert_int(d["y"]).is_equal(7)


# ── AC-SU02: dict_a_vec2i reconstruye el Vector2i exacto ───────────────────────────────────
func test_dict_a_vec2i_reconstruye() -> void:
	# Arrange
	var d: Dictionary = {"x": 3, "y": 7}
	# Act
	var v: Vector2i = SU.dict_a_vec2i(d)
	# Assert
	assert_vector(v).is_equal(Vector2i(3, 7))


# ── AC-SU03: round-trip por JSON REAL es idéntico (prueba el paso por float del parseo) ─────
func test_roundtrip_por_json_identico() -> void:
	# Arrange — negativo + positivo para cubrir signos.
	var v: Vector2i = Vector2i(-4, 12)
	# Act — viaje real por JSON como hará SaveManager: los int vuelven como float.
	var d: Variant = JSON.parse_string(JSON.stringify(SU.vec2i_a_dict(v)))
	var reconstruido: Vector2i = SU.dict_a_vec2i(d as Dictionary)
	# Assert — idéntico al original pese al paso por float.
	assert_vector(reconstruido).is_equal(v)


# ── AC-SU04: dict incompleto/vacío → Vector2i.ZERO (defensivo; warning es observacional) ────
func test_dict_incompleto_devuelve_zero() -> void:
	# Arrange / Act — dict vacío y dict al que le falta "y".
	var desde_vacio: Vector2i = SU.dict_a_vec2i({})
	var desde_parcial: Vector2i = SU.dict_a_vec2i({"x": 3})
	# Assert — ambos ZERO (no peta ante un save parcial/manipulado).
	assert_vector(desde_vacio).is_equal(Vector2i.ZERO)
	assert_vector(desde_parcial).is_equal(Vector2i.ZERO)
