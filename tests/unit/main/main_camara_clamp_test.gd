# CLAMP DE CÁMARA (2026-08-07, "que al moverse no se vean cosas vacías fuera, solo entorno" —
# petición del usuario, emparejada con la cobertura del entorno de
# `entorno_exterior_cobertura_test.gd`: el borde del área cubierta DEBE coincidir con este límite).
#
# Prueba `Main._clamp_posicion_camara` en AISLAMIENTO — SIN `add_child` (mismo patrón que
# `ModoConstruccion` en `construccion_picking_muros_test.gd::_modo()`: instanciar sin meter en el
# árbol para no disparar el `_ready()` pesado de todo el juego). La función es pura una vez
# inyectados `_camara`/`_limite_camara_min`/`_limite_camara_max`, gracias al refactor que saca
# `ventana` como parámetro en vez de leer `get_viewport_rect()` (necesitaría Viewport real).
#
# Tipo: Unit. DETERMINISTA: sin azar, sin reloj, sin GPU.
extends GdUnitTestSuite

const MainScript := preload("res://src/main/main.gd")

const VENTANA := Vector2(1600.0, 900.0)
## Límites de prueba: los mismos órdenes de magnitud que produce `EntornoExterior.
## limites_iso_cubiertos()` en producción (ver el otro test), pero fijos aquí para que este test no
## dependa de esa cuenta -- cada fichero prueba SU parte del contrato.
const LIMITE_MIN := Vector2(-1000.0, -700.0)
const LIMITE_MAX := Vector2(2600.0, 1600.0)


func _main_con_limites(zoom: float) -> Node2D:
	var main: Node2D = auto_free(MainScript.new())
	main._camara = auto_free(Camera2D.new())
	main._camara.zoom = Vector2(zoom, zoom)
	main._limite_camara_min = LIMITE_MIN
	main._limite_camara_max = LIMITE_MAX
	return main


# ── El clamp nunca deja que la posición se salga del mínimo/máximo ──────────────────────────────

func test_clamp_recorta_por_debajo_del_minimo() -> void:
	var main: Node2D = _main_con_limites(1.0)
	var resultado: Vector2 = main._clamp_posicion_camara(Vector2(-99999.0, -99999.0), VENTANA)
	assert_vector(resultado).is_equal(LIMITE_MIN)


func test_clamp_recorta_por_encima_del_maximo_descontando_lo_visible() -> void:
	var main: Node2D = _main_con_limites(1.0)
	var resultado: Vector2 = main._clamp_posicion_camara(Vector2(99999.0, 99999.0), VENTANA)
	# A zoom 1.0 lo visible ES la ventana: el máximo permitido es LIMITE_MAX menos esa ventana.
	assert_vector(resultado).is_equal_approx(LIMITE_MAX - VENTANA, Vector2(0.01, 0.01))


# ── Las 4 "esquinas" del clamp, a ZOOM_MIN y ZOOM_MAX — el caso literal del encargo ──────────────

func _probar_4_esquinas_dentro_de_limites(zoom: float) -> void:
	var main: Node2D = _main_con_limites(zoom)
	var visible: Vector2 = VENTANA / zoom
	var deseos: Array[Vector2] = [
		Vector2(-99999.0, -99999.0), Vector2(99999.0, -99999.0),
		Vector2(99999.0, 99999.0), Vector2(-99999.0, 99999.0),
	]
	for deseo: Vector2 in deseos:
		var resultado: Vector2 = main._clamp_posicion_camara(deseo, VENTANA)
		assert_bool(resultado.x >= LIMITE_MIN.x - 0.01) \
			.override_failure_message("esquina %s: x=%f por debajo del mínimo" % [deseo, resultado.x]) \
			.is_true()
		assert_bool(resultado.y >= LIMITE_MIN.y - 0.01) \
			.override_failure_message("esquina %s: y=%f por debajo del mínimo" % [deseo, resultado.y]) \
			.is_true()
		assert_bool(resultado.x + visible.x <= LIMITE_MAX.x + 0.01) \
			.override_failure_message(
				"esquina %s: borde derecho %f excede el máximo" % [deseo, resultado.x + visible.x]
			).is_true()
		assert_bool(resultado.y + visible.y <= LIMITE_MAX.y + 0.01) \
			.override_failure_message(
				"esquina %s: borde inferior %f excede el máximo" % [deseo, resultado.y + visible.y]
			).is_true()


func test_las_4_esquinas_al_zoom_minimo_quedan_dentro_de_los_limites() -> void:
	_probar_4_esquinas_dentro_de_limites(MainScript.ZOOM_MIN)


func test_las_4_esquinas_al_zoom_maximo_quedan_dentro_de_los_limites() -> void:
	_probar_4_esquinas_dentro_de_limites(MainScript.ZOOM_MAX)


# ── A ZOOM_MAX (ve MENOS mundo) hay más margen de pan que a ZOOM_MIN, dentro de los MISMOS límites ──

func test_a_zoom_max_hay_mas_margen_de_pan_que_a_zoom_min() -> void:
	var main_min: Node2D = _main_con_limites(MainScript.ZOOM_MIN)
	var main_max: Node2D = _main_con_limites(MainScript.ZOOM_MAX)
	var rango_min: float = (
		main_min._clamp_posicion_camara(Vector2(99999.0, 0.0), VENTANA).x - LIMITE_MIN.x
	)
	var rango_max: float = (
		main_max._clamp_posicion_camara(Vector2(99999.0, 0.0), VENTANA).x - LIMITE_MIN.x
	)
	assert_float(rango_max).is_greater(rango_min)


# ── El clamp es idempotente: recortar dos veces da lo mismo que una ─────────────────────────────

func test_clamp_es_idempotente() -> void:
	var main: Node2D = _main_con_limites(1.3)
	var una_vez: Vector2 = main._clamp_posicion_camara(Vector2(500.0, -200.0), VENTANA)
	var dos_veces: Vector2 = main._clamp_posicion_camara(una_vez, VENTANA)
	assert_vector(dos_veces).is_equal_approx(una_vez, Vector2(0.001, 0.001))
