# Story 001 (epic construccion) — núcleo, config y validación de colocación F6 · TR-construction-001/002 ·
# ADR-0004/0003. Tipo: Logic. DETERMINISTA (sin azar; catálogo REAL para `puestos_admitidos` y tipos).
# Aislamiento: nodo con .new() sin árbol; salas/elementos sembrados con el registro directo del modelo.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Construcción aislada con los defaults del config (edificio 24×13, área mínima 2×2).
func _construccion() -> Node:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	return construccion


## Fixture con las dos oficinas y una espera ya en el modelo (registro directo, sin coste).
func _con_salas() -> Node:
	var construccion: Node = _construccion()
	construccion._crear_sala(&"sala_documentacion", Rect2i(0, 0, 4, 4))
	construccion._crear_sala(&"sala_odac", Rect2i(6, 0, 4, 4))
	construccion._crear_sala(&"sala_espera_doc", Rect2i(0, 6, 3, 3))
	return construccion


# ── AC-CO01: dentro + sin solape → válida; solapar o salirse → inválida (F6) ──────────────
func test_validar_sala_dentro_solape_y_limites() -> void:
	# Arrange
	var construccion: Node = _con_salas()

	# Act / Assert — hueco libre dentro del edificio: válida.
	assert_bool(construccion.validar_sala(&"sala_espera_odac", Rect2i(12, 6, 3, 3))).is_true()
	# Solapa con sala_documentacion (0,0,4,4): inválida.
	assert_bool(construccion.validar_sala(&"sala_espera_odac", Rect2i(2, 2, 3, 3))).is_false()
	# Se sale del edificio (24×13): inválida.
	assert_bool(construccion.validar_sala(&"sala_espera_odac", Rect2i(22, 11, 4, 4))).is_false()
	# ADYACENTE compartiendo borde (termina donde empieza la ODAC): válida — solapar es estricto.
	assert_bool(construccion.validar_sala(&"sala_espera_odac", Rect2i(4, 0, 2, 4))).is_true()


# ── AC-CO03: área < mínimo → rechazada (frontera exacta en 4 celdas = 2×2) ────────────────
func test_area_minima_boundary() -> void:
	# Arrange — boundary values intencionales.
	var construccion: Node = _construccion()

	# Act / Assert — 1×3 (área 3) rechazada; 2×2 (área 4) justa: válida.
	assert_bool(construccion.validar_sala(&"sala_espera_doc", Rect2i(0, 0, 1, 3))).is_false()
	assert_bool(construccion.validar_sala(&"sala_espera_doc", Rect2i(0, 0, 2, 2))).is_true()


# ── AC-CO02 (regla CO4): un puesto solo en la oficina de SU servicio ──────────────────────
func test_puesto_solo_en_su_oficina() -> void:
	# Arrange
	var construccion: Node = _con_salas()

	# Act / Assert — doc_general dentro de sala_documentacion: válido (puestos_admitidos del catálogo).
	assert_bool(construccion.validar_elemento(&"puesto_doc_general", Vector2i(1, 1))).is_true()
	# En la oficina de ODAC: rechazado (no está en sus puestos_admitidos).
	assert_bool(construccion.validar_elemento(&"puesto_doc_general", Vector2i(7, 1))).is_false()
	# El de ODAC en su casa: válido.
	assert_bool(construccion.validar_elemento(&"puesto_odac", Vector2i(7, 1))).is_true()
	# En una celda sin sala: rechazado (los elementos viven dentro de salas).
	assert_bool(construccion.validar_elemento(&"puesto_doc_general", Vector2i(20, 12))).is_false()


# ── Asientos: solo en salas de ESPERA (regla de tipo de sala) ─────────────────────────────
func test_asiento_solo_en_espera() -> void:
	# Arrange
	var construccion: Node = _con_salas()

	# Act / Assert — en la sala de espera: válido; en una oficina: rechazado.
	assert_bool(construccion.validar_elemento(construccion.ASIENTO_BASICO, Vector2i(1, 7))).is_true()
	assert_bool(construccion.validar_elemento(construccion.ASIENTO_BASICO, Vector2i(1, 1))).is_false()


# ── CO4: los elementos no solapan (celda ocupada → inválido) ──────────────────────────────
func test_solape_de_elementos_rechazado() -> void:
	# Arrange — un puesto ya construido en (1,1).
	var construccion: Node = _con_salas()
	construccion._crear_elemento(&"puesto_doc_general", Vector2i(1, 1), 500.0)

	# Act / Assert — la misma celda queda ocupada; la de al lado sigue libre.
	assert_bool(construccion.validar_elemento(&"puesto_doc_general", Vector2i(1, 1))).is_false()
	assert_bool(construccion.validar_elemento(&"puesto_doc_general", Vector2i(2, 1))).is_true()
	assert_str(String(construccion.sala_en(Vector2i(1, 1)))).is_equal("sala_1")


# ── Robustez: tipos inexistentes en el catálogo → inválido con aviso ──────────────────────
func test_tipos_inexistentes_no_revientan() -> void:
	# Arrange — los push_warning esperados son intencionales (Datos avisa del id colgante).
	var construccion: Node = _con_salas()

	# Act / Assert
	assert_bool(construccion.validar_sala(&"sala_inventada", Rect2i(12, 6, 3, 3))).is_false()
	assert_bool(construccion.validar_elemento(&"puesto_inventado", Vector2i(1, 1))).is_false()


# ── Config: clamps defensivos + el .tres real carga (patrón del proyecto) ─────────────────
func test_config_clamps_y_tres_real() -> void:
	# Arrange — knobs corruptos (los push_warning esperados son intencionales).
	var corrupto: Resource = ConfigConstruccionScript.new()
	corrupto.coste_por_celda = -5.0
	corrupto.densidad_asientos = 2.0
	corrupto.pct_reembolso = -1.0
	corrupto.area_min_sala = 0
	corrupto.edificio_columnas = 0
	var construccion: Node = _construccion()

	# Act
	construccion.aplicar_config(corrupto)

	# Assert — clamps a rangos sanos.
	assert_float(construccion.coste_por_celda).is_equal_approx(0.0, 0.0001)
	assert_float(construccion.densidad_asientos).is_equal_approx(1.0, 0.0001)
	assert_float(construccion.pct_reembolso).is_equal_approx(0.0, 0.0001)
	assert_int(construccion.area_min_sala).is_equal(1)
	assert_int(construccion.edificio_columnas).is_equal(1)

	# El .tres real generado por la herramienta carga con los valores semilla del GDD.
	var real: Resource = load("res://datos/config/construccion.tres")
	assert_object(real).is_not_null()
	var con_real: Node = _construccion()
	con_real.aplicar_config(real)
	assert_float(con_real.coste_por_celda).is_equal_approx(20.0, 0.0001)
	assert_float(con_real.densidad_asientos).is_equal_approx(0.7, 0.0001)
	assert_int(con_real.edificio_columnas).is_equal(24)
