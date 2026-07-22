# Story 003 (epic rng-service) — TR-save-002 · ADR-0002
# Serialización del RNG: save/load_state. Tipo: Integration (round-trip). DETERMINISTA.
extends GdUnitTestSuite

const RngScript := preload("res://src/foundation/rng_service/rng_service.gd")


# Helper: consume N enteros del generador y los devuelve (avanza el estado).
func _generar(rng: Node, n: int) -> Array:
	var out: Array = []
	for _i in n:
		out.append(rng.randi_rango(0, 1_000_000))
	return out


# AC-1: round-trip DIRECTO -> tras load_state, la secuencia futura continúa idéntica al punto de guardado.
func test_round_trip_directo_continua_la_secuencia() -> void:
	# Arrange
	var a: Node = auto_free(RngScript.new())
	a.sembrar(2024)
	_generar(a, 3)                       # avanzar el estado un poco
	var g: Dictionary = a.save()         # punto de guardado
	# Act
	var seq_a: Array = _generar(a, 5)    # continuación real
	a.load_state(g)                      # volver al punto de guardado
	var seq_b: Array = _generar(a, 5)    # misma continuación
	# Assert
	assert_array(seq_b).is_equal(seq_a)


# AC-2: save() devuelve semilla y estado como TEXTO (para el round-trip por JSON sin perder precisión).
func test_save_devuelve_semilla_y_estado_como_texto() -> void:
	# Arrange
	var a: Node = auto_free(RngScript.new())
	a.sembrar(2024)
	# Act
	var g: Dictionary = a.save()
	# Assert
	assert_bool(g.has("semilla") and g.has("estado")).is_true()
	assert_int(typeof(g["semilla"])).is_equal(TYPE_STRING)
	assert_int(typeof(g["estado"])).is_equal(TYPE_STRING)
	assert_str(g["semilla"]).is_equal("2024")


# AC-3: round-trip VÍA JSON -> stringify + parse + load_state reproduce la continuación exacta.
func test_round_trip_via_json_continua_la_secuencia() -> void:
	# Arrange
	var a: Node = auto_free(RngScript.new())
	a.sembrar(2024)
	_generar(a, 3)
	var g: Dictionary = a.save()
	var seq_a: Array = _generar(a, 5)
	# Act: pasar por JSON como hará SaveManager
	var texto: String = JSON.stringify(g)
	var parseado: Variant = JSON.parse_string(texto)
	a.load_state(parseado as Dictionary)
	var seq_b: Array = _generar(a, 5)
	# Assert
	assert_array(seq_b).is_equal(seq_a)


# AC-4: el nodo pertenece al grupo "Persist" (se marca en _ready).
func test_pertenece_al_grupo_persist() -> void:
	# Arrange
	var a: Node = auto_free(RngScript.new())
	add_child(a)                         # dispara _ready -> add_to_group("Persist")
	# Assert
	assert_bool(a.is_in_group("Persist")).is_true()
