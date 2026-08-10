# BANCOS DE ESPERA MULTI-PLAZA — quick-spec `bancos-espera-multiplaza-2026-08-09.md`.
# Tipo: Logic. DETERMINISTA: catalogo de datos fijo + aritmetica de celdas; sin reloj ni RNG.
#
# Encargo del usuario (2026-08-08, arte aprobado el 2026-08-09): "bancos de espera de 2-3 celdas,
# 1 NPC por celda". Hasta hoy "ser un asiento" era comparar el catalogo con ASIENTO_BASICO -- una
# celda, una silla, un NPC -- asi que un banco habria sido un mueble decorativo.
#
# Cubre los AC de la spec que son del MODELO (AC1 parcial, AC3 y AC4); AC2 (dibujarse sentado) y AC5
# (aparecer en la barra) son de la capa visual y se verifican con sonda/captura.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")

const RECT_ESPERA := Rect2i(0, 0, 6, 4)


func _construccion() -> Node:
	var c: Node = auto_free(ConstruccionScript.new())
	add_child(c)
	c.aplicar_config(ConfigConstruccionScript.new())
	return c


# ── Cuantas plazas sienta cada cosa ─────────────────────────────────────────────────────────────

## 🔒 AC4 (sin regresion): el asiento basico de SIEMPRE sigue valiendo exactamente 1.
func test_el_asiento_basico_sigue_siendo_una_plaza() -> void:
	var c: Node = _construccion()
	assert_int(c.plazas_sentadas_de(c.ASIENTO_BASICO)).is_equal(1)


## Los tres bancos del encargo: 2 el basico, 3 el medio y el pro.
func test_cada_banco_declara_sus_plazas() -> void:
	var c: Node = _construccion()
	assert_int(c.plazas_sentadas_de(&"banco_espera_basico")).is_equal(2)
	assert_int(c.plazas_sentadas_de(&"banco_espera_medio")).is_equal(3)
	assert_int(c.plazas_sentadas_de(&"banco_espera_pro")).is_equal(3)


## Lo que NO es para sentarse da 0 -- una papelera no es un banco por estar en la sala.
func test_lo_que_no_es_asiento_no_sienta_a_nadie() -> void:
	var c: Node = _construccion()
	assert_int(c.plazas_sentadas_de(&"papelera")).is_equal(0)
	assert_int(c.plazas_sentadas_de(&"id_que_no_existe")).is_equal(0)


# ── Una plaza por celda ─────────────────────────────────────────────────────────────────────────

## 🔒 AC1 (modelo): un banco ofrece UN SITIO POR PLAZA del mueble, aunque tenga menos celdas.
##
## Cambió el 2026-08-10 (decisión del usuario "que mande el mueble, no la celda"): desde que la
## huella se declara en celdas ENTERAS, el banco de aeropuerto dibuja 3 asientos y ocupa 2 celdas.
## Antes se daba "una plaza por celda" y un asiento del dibujo quedaba siempre vacío.
func test_un_banco_ofrece_un_sitio_por_plaza() -> void:
	var c: Node = _construccion()
	var sala: StringName = c.construir_de_oficio_sala(&"sala_espera_odac", RECT_ESPERA)
	assert_str(String(sala)).is_not_equal("")
	var banco: StringName = c.construir_de_oficio_elemento(&"banco_espera_medio", Vector2i(1, 1))
	assert_str(String(banco)).override_failure_message(
		"no se pudo colocar el banco de 3 plazas en la sala de espera"
	).is_not_equal("")

	var plazas: int = c.plazas_sentadas_de(&"banco_espera_medio")
	var sitios: Array[Vector2] = c.sitios_sentables_de_sala(sala)
	assert_int(sitios.size()).override_failure_message(
		"un banco de %d plazas deberia dar %d sitios, dio %d" % [plazas, plazas, sitios.size()]
	).is_equal(plazas)
	# Y son sitios DISTINTOS (si no, la gente se sentaria encima de otra).
	var unicos: Dictionary = {}
	for sitio: Vector2 in sitios:
		unicos[Vector2i(sitio.round())] = true
	assert_int(unicos.size()).override_failure_message(
		"los %d sitios del banco deberian caer en puntos distintos" % plazas
	).is_equal(plazas)


## Una sala sin nada donde sentarse no da ninguna celda (y no revienta).
func test_sala_sin_asientos_no_da_celdas_sentables() -> void:
	var c: Node = _construccion()
	var sala: StringName = c.construir_de_oficio_sala(&"sala_espera_odac", RECT_ESPERA)
	assert_int(c.celdas_sentables_de_sala(sala).size()).is_equal(0)


# ── El aforo cuenta plazas, no muebles ──────────────────────────────────────────────────────────

## 🔒 AC3: el tope de asientos por area cuenta un banco de 3 como TRES. Se comprueba por su efecto
## observable: tras colocar el banco, caben 3 asientos basicos MENOS que en la sala vacia.
func test_el_aforo_cuenta_las_plazas_del_banco_no_el_mueble() -> void:
	var vacia: Node = _construccion()
	var sala_v: StringName = vacia.construir_de_oficio_sala(&"sala_espera_odac", RECT_ESPERA)
	var caben_vacia := 0
	for y: int in range(RECT_ESPERA.size.y):
		for x: int in range(RECT_ESPERA.size.x):
			if vacia.construir_de_oficio_elemento(vacia.ASIENTO_BASICO, Vector2i(x, y)) != &"":
				caben_vacia += 1

	var con_banco: Node = _construccion()
	con_banco.construir_de_oficio_sala(&"sala_espera_odac", RECT_ESPERA)
	assert_str(String(
		con_banco.construir_de_oficio_elemento(&"banco_espera_medio", Vector2i(1, 3))
	)).is_not_equal("")
	var caben_con_banco := 0
	for y: int in range(RECT_ESPERA.size.y - 1):   # la fila del banco queda ocupada
		for x: int in range(RECT_ESPERA.size.x):
			if con_banco.construir_de_oficio_elemento(
				con_banco.ASIENTO_BASICO, Vector2i(x, y)
			) != &"":
				caben_con_banco += 1

	assert_int(caben_con_banco).override_failure_message(
		"el banco de 3 plazas deberia descontar 3 del aforo (vacia=%d, con banco=%d)"
		% [caben_vacia, caben_con_banco]
	).is_equal(maxi(caben_vacia - 3, 0))
