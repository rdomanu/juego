# LAS LUCES VAN EN EL TECHO (petición del usuario, 2026-07-30): *"las luces pueden ir encima de
# otros objetos, ya que están arriba, excepto la luz de suelo"*.
#
# Una pieza marcada `en_techo` en el catálogo NO ocupa suelo: se cuelga encima de lo que sea. La
# lámpara DE PIE no la lleva — esa se apoya y estorba como cualquier mueble.
# Tipo: Integration (Construccion + Economia reales). DETERMINISTA: sin azar ni reloj.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")

## Del catálogo REAL: un tubo de techo y una lámpara que se apoya en el suelo.
const LUZ_TECHO := &"fluorescente"
const LUZ_SUELO := &"lampara_pie"
## Un mueble corriente que sí ocupa suelo, para poner la luz encima.
const MUEBLE := &"vending"


func _mundo(saldo: float = 100000.0) -> Node:
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	economia.saldo_eur = saldo
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(economia)
	construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(1, 1, 6, 6))
	return construccion


# AC-1: el catálogo dice quién va en el techo y quién no. Si esto cambiara, los tests de abajo
# dejarían de probar lo que creen probar.
func test_el_catalogo_distingue_techo_de_suelo() -> void:
	var c: Node = _mundo()
	assert_bool(c.es_de_techo(LUZ_TECHO)).is_true()
	assert_bool(c.es_de_techo(LUZ_SUELO)).is_false()
	assert_bool(c.es_de_techo(MUEBLE)).is_false()


# AC-2 🔑 una luz de techo SE PUEDE poner encima de un mueble que ya está ahí.
func test_la_luz_de_techo_va_encima_de_un_mueble() -> void:
	var c: Node = _mundo()
	assert_that(c.construir_elemento(MUEBLE, Vector2i(2, 2))).is_not_equal(&"")
	assert_bool(c.validar_elemento(LUZ_TECHO, Vector2i(2, 2))).is_true()
	assert_that(c.construir_elemento(LUZ_TECHO, Vector2i(2, 2))).is_not_equal(&"")


# AC-3: y al revés — tener una luz colgada no impide amueblar debajo. Si solo funcionara en un
# sentido, el jugador tendría que acordarse de poner las luces las últimas.
func test_se_puede_amueblar_debajo_de_una_luz() -> void:
	var c: Node = _mundo()
	assert_that(c.construir_elemento(LUZ_TECHO, Vector2i(3, 3))).is_not_equal(&"")
	assert_bool(c.validar_elemento(MUEBLE, Vector2i(3, 3))).is_true()
	assert_that(c.construir_elemento(MUEBLE, Vector2i(3, 3))).is_not_equal(&"")


# AC-4: la lámpara DE PIE sigue ocupando suelo — es la excepción que pidió el usuario.
func test_la_lampara_de_pie_si_ocupa_suelo() -> void:
	var c: Node = _mundo()
	assert_that(c.construir_elemento(MUEBLE, Vector2i(2, 2))).is_not_equal(&"")
	assert_bool(c.validar_elemento(LUZ_SUELO, Vector2i(2, 2))).is_false()


# AC-5: dos muebles de suelo siguen sin poder compartir celda. La regla del techo no ha aflojado la
# de siempre.
func test_dos_muebles_de_suelo_siguen_sin_caber_juntos() -> void:
	var c: Node = _mundo()
	assert_that(c.construir_elemento(MUEBLE, Vector2i(2, 2))).is_not_equal(&"")
	assert_bool(c.validar_elemento(MUEBLE, Vector2i(2, 2))).is_false()


# AC-6: al pinchar en una celda con luz Y mueble, la herramienta de demoler encuentra LA LUZ — que
# es la que está dibujada encima y a la que estás apuntando.
func test_al_pinchar_gana_la_luz_que_esta_encima() -> void:
	var c: Node = _mundo()
	var mueble: StringName = c.construir_elemento(MUEBLE, Vector2i(4, 4))
	var luz: StringName = c.construir_elemento(LUZ_TECHO, Vector2i(4, 4))
	assert_that(c.elemento_en(Vector2i(4, 4))).is_equal(luz)
	# Y al quitarla, debajo sigue estando el mueble.
	assert_bool(c.demoler_elemento(luz)).is_true()
	assert_that(c.elemento_en(Vector2i(4, 4))).is_equal(mueble)


# AC-7: la luz de techo sobrevive al guardado con lo que tenga debajo (fue un bug real con las
# comodidades el 2026-07-29: se perdían al cargar).
func test_luz_y_mueble_sobreviven_al_guardado() -> void:
	var c: Node = _mundo()
	var mueble: StringName = c.construir_elemento(MUEBLE, Vector2i(5, 5))
	var luz: StringName = c.construir_elemento(LUZ_TECHO, Vector2i(5, 5))
	var guardado: Dictionary = c.save()

	var otra: Node = _mundo()
	otra.load_state(guardado)
	assert_that(otra.elemento_en(Vector2i(5, 5))).is_equal(luz)
	assert_bool(otra.demoler_elemento(luz)).is_true()
	assert_that(otra.elemento_en(Vector2i(5, 5))).is_equal(mueble)
