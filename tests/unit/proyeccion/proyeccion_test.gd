# Conversion a ISOMETRICO (2026-07-30) — la proyeccion plano cuadrado <-> pantalla isometrica.
# Tipo: Logic. DETERMINISTA (matematica pura, sin nodos, sin autoloads, sin reloj).
#
# Es la funcion RAIZ de toda la capa visual: si esta se equivoca en medio rombo, TODO el juego
# aparece descolocado medio rombo. Por eso se prueba el viaje de ida y vuelta, los cuatro vertices
# del rombo, y el caso de las coordenadas NEGATIVAS (la calle vive a la izquierda del edificio).
extends GdUnitTestSuite

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")

# Tolerancia en pixeles para comparar floats. 0.001 px es indistinguible en pantalla pero
# suficientemente estricto para cazar un error de medio rombo (20 px) o de una celda (40 px).
const TOL: float = 0.001


# ── La forma del rombo ────────────────────────────────────────────────────────────────────────

# AC-1: el rombo estandar es 2:1 — 80 de ancho por 40 de alto (art bible §8).
func test_el_rombo_es_dos_a_uno() -> void:
	assert_int(ProyeccionScript.ANCHO_ROMBO).is_equal(2 * ProyeccionScript.ALTO_ROMBO)
	assert_int(ProyeccionScript.ANCHO_ROMBO).is_equal(80)
	assert_int(ProyeccionScript.ALTO_ROMBO).is_equal(40)


# AC-2: la celda del plano LOGICO sigue siendo de 40 px — la conversion no la toca (es contra
# este numero contra el que estan calibradas la navegacion y las velocidades).
func test_la_celda_logica_sigue_siendo_de_cuarenta() -> void:
	assert_int(ProyeccionScript.TAM_CELDA).is_equal(40)


# AC-3: los cuatro vertices del rombo de la celda (0,0) caen donde dice el diseno.
# En cuadrado sus esquinas son (0,0) (40,0) (40,40) (0,40); en isometrico deben ser el vertice
# de arriba, el de la derecha, el de abajo y el de la izquierda de un rombo de 80x40.
func test_los_cuatro_vertices_de_la_primera_celda() -> void:
	var rombo: PackedVector2Array = ProyeccionScript.rombo_de_celda(Vector2i(0, 0))
	assert_int(rombo.size()).is_equal(4)
	_igual(rombo[0], Vector2(0.0, 0.0), "vertice de ARRIBA")
	_igual(rombo[1], Vector2(40.0, 20.0), "vertice de la DERECHA")
	_igual(rombo[2], Vector2(0.0, 40.0), "vertice de ABAJO")
	_igual(rombo[3], Vector2(-40.0, 20.0), "vertice de la IZQUIERDA")


# AC-4: el centro del rombo es el centro geometrico de sus cuatro vertices.
func test_el_centro_del_rombo_es_el_centro_de_sus_vertices() -> void:
	for celda: Vector2i in [Vector2i(0, 0), Vector2i(3, 7), Vector2i(23, 12), Vector2i(-2, 5)]:
		var rombo: PackedVector2Array = ProyeccionScript.rombo_de_celda(celda)
		var medio: Vector2 = (rombo[0] + rombo[1] + rombo[2] + rombo[3]) / 4.0
		_igual(ProyeccionScript.centro_iso(celda), medio, "centro de %s" % celda)


# ── El viaje de ida y vuelta ──────────────────────────────────────────────────────────────────

# AC-5: proyectar y desproyectar son inversas exactas — el punto vuelve a donde estaba.
# Se prueba tambien con NEGATIVOS: la cola de la calle vive en x negativa (2 celdas a la
# izquierda del edificio), asi que la proyeccion tiene que funcionar fuera del tablero.
func test_ida_y_vuelta_devuelve_el_mismo_punto() -> void:
	var puntos: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(20.0, 20.0), Vector2(960.0, 520.0),
		Vector2(-80.0, 200.0), Vector2(-80.0, -40.0), Vector2(13.7, 401.3),
	]
	for p: Vector2 in puntos:
		var vuelta: Vector2 = ProyeccionScript.desproyectar(ProyeccionScript.proyectar(p))
		_igual(vuelta, p, "ida y vuelta de %s" % p)


# AC-6: el clic dentro de un rombo devuelve SU celda, no la de al lado. Se prueba el centro y los
# cuatro puntos "casi en el borde" de cada rombo: es el caso que decide si el modo construccion
# coloca la sala donde el jugador la ve o una celda mas alla.
func test_un_punto_dentro_del_rombo_da_su_celda() -> void:
	for celda: Vector2i in [Vector2i(0, 0), Vector2i(5, 2), Vector2i(23, 12), Vector2i(-2, 6)]:
		var centro: Vector2 = ProyeccionScript.centro_iso(celda)
		assert_that(ProyeccionScript.celda_de_iso(centro)).is_equal(celda)
		# Casi tocando cada uno de los cuatro vertices, pero por dentro (90 % del camino).
		var rombo: PackedVector2Array = ProyeccionScript.rombo_de_celda(celda)
		for vertice: Vector2 in rombo:
			var casi_borde: Vector2 = centro.lerp(vertice, 0.9)
			assert_that(ProyeccionScript.celda_de_iso(casi_borde)).is_equal(celda)


# AC-7: celdas contiguas dan celdas contiguas — moverse un rombo a la derecha en pantalla no
# puede saltar dos celdas del modelo.
func test_celdas_vecinas_en_pantalla_son_vecinas_en_el_modelo() -> void:
	var base := Vector2i(6, 4)
	var centro: Vector2 = ProyeccionScript.centro_iso(base)
	# Un rombo entero hacia la derecha de la pantalla = una columna mas Y una fila menos.
	var derecha: Vector2 = centro + Vector2(ProyeccionScript.ANCHO_ROMBO, 0.0)
	assert_that(ProyeccionScript.celda_de_iso(derecha)).is_equal(Vector2i(7, 3))
	# Un rombo entero hacia abajo = una columna mas Y una fila mas.
	var abajo: Vector2 = centro + Vector2(0.0, ProyeccionScript.ALTO_ROMBO)
	assert_that(ProyeccionScript.celda_de_iso(abajo)).is_equal(Vector2i(7, 5))


# ── Esquinas de la rejilla (donde viven las paredes) ──────────────────────────────────────────

# AC-8: la esquina (c,f) es el vertice de ARRIBA de la celda (c,f), y la (c+1,f+1) el de ABAJO.
# Es la relacion de la que vive el dibujo de las paredes (que van de vertice a vertice).
func test_la_esquina_es_el_vertice_de_arriba_de_su_celda() -> void:
	for celda: Vector2i in [Vector2i(0, 0), Vector2i(4, 9), Vector2i(-1, 2)]:
		var rombo: PackedVector2Array = ProyeccionScript.rombo_de_celda(celda)
		_igual(ProyeccionScript.esquina_iso(celda.x, celda.y), rombo[0], "arriba de %s" % celda)
		_igual(
			ProyeccionScript.esquina_iso(celda.x + 1, celda.y + 1), rombo[2], "abajo de %s" % celda
		)


# AC-9: dos celdas pegadas COMPARTEN la arista — el tabique entre ellas es una sola linea, no dos.
# (Es la version en pixeles de la decision de modelo "el muro vive en la arista".)
func test_dos_celdas_pegadas_comparten_la_arista() -> void:
	# La celda (3,5) y la (4,5) comparten la arista vertical de la columna 4, fila 5.
	var izquierda: PackedVector2Array = ProyeccionScript.rombo_de_celda(Vector2i(3, 5))
	var derecha: PackedVector2Array = ProyeccionScript.rombo_de_celda(Vector2i(4, 5))
	# El vertice DERECHO de la izquierda es el vertice de ARRIBA de la derecha.
	_igual(izquierda[1], derecha[0], "vertice compartido superior")
	# El vertice ABAJO de la izquierda es el vertice IZQUIERDO de la derecha.
	_igual(izquierda[2], derecha[3], "vertice compartido inferior")


# ── Profundidad (quien tapa a quien) ──────────────────────────────────────────────────────────

# AC-10: cuanto mas al fondo de la comisaria (columna+fila mayor), MAS abajo en pantalla — que es
# justo la regla de quien tapa a quien en isometrico.
func test_la_profundidad_crece_hacia_el_fondo() -> void:
	var cerca: float = ProyeccionScript.profundidad(ProyeccionScript.centro_cuadrado(Vector2i(0, 0)))
	var medio: float = ProyeccionScript.profundidad(ProyeccionScript.centro_cuadrado(Vector2i(3, 3)))
	var lejos: float = ProyeccionScript.profundidad(ProyeccionScript.centro_cuadrado(Vector2i(9, 9)))
	assert_float(cerca).is_less(medio)
	assert_float(medio).is_less(lejos)


# AC-11: dos celdas de la MISMA diagonal (misma suma columna+fila) estan a la misma profundidad —
# ninguna tapa a la otra, y el desempate tendra que decidirlo otra cosa.
func test_la_misma_diagonal_esta_a_la_misma_profundidad() -> void:
	var a: float = ProyeccionScript.profundidad(ProyeccionScript.centro_cuadrado(Vector2i(2, 6)))
	var b: float = ProyeccionScript.profundidad(ProyeccionScript.centro_cuadrado(Vector2i(6, 2)))
	assert_float(a).is_equal_approx(b, TOL)


# ── La transformada que se le cuelga al suelo ─────────────────────────────────────────────────

# AC-14: la Transform2D hace EXACTAMENTE lo mismo que proyectar(). Si estas dos cuentas se
# separaran, el suelo (que usa la transformada) quedaria descolocado respecto de la gente y las
# paredes (que usan proyectar) — el bug clasico de "todo medio rombo movido".
func test_la_transformada_hace_lo_mismo_que_proyectar() -> void:
	var origen := Vector2(600.0, 40.0)
	var t: Transform2D = ProyeccionScript.transformada(origen)
	var puntos: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(40.0, 0.0), Vector2(0.0, 40.0), Vector2(960.0, 520.0),
		Vector2(-80.0, 137.0),
	]
	for p: Vector2 in puntos:
		_igual(t * p, ProyeccionScript.proyectar(p) + origen, "transformada de %s" % p)


# AC-15: la transformada es invertible (determinante != 0). Si no lo fuera, el suelo se aplastaria
# en una linea y `to_local` —de la que vive el clic del modo construccion— reventaria.
func test_la_transformada_es_invertible() -> void:
	var t: Transform2D = ProyeccionScript.transformada(Vector2.ZERO)
	assert_float(t.determinant()).is_equal_approx(1.0, TOL)
	var vuelta: Vector2 = t.affine_inverse() * (t * Vector2(123.0, -45.0))
	_igual(vuelta, Vector2(123.0, -45.0), "ida y vuelta por la transformada")


# ── Encaje del tablero en la ventana ──────────────────────────────────────────────────────────

# AC-12: el tablero real del juego (24x13) mide 1480x740 proyectado — el numero que obligo a
# subir la ventana a 1600x900 (project.godot, [display]).
func test_el_tablero_del_juego_mide_lo_que_dice_el_diseno() -> void:
	var tam: Vector2 = ProyeccionScript.tamano_tablero(24, 13)
	_igual(tam, Vector2(1480.0, 740.0), "tablero 24x13 proyectado")


# AC-13: con el origen centrado, el tablero cabe DENTRO del area y queda centrado de verdad:
# el vertice mas a la izquierda y el mas a la derecha dejan el mismo margen.
func test_el_origen_centrado_deja_el_tablero_centrado() -> void:
	var columnas: int = 24
	var filas: int = 13
	var area := Vector2(1600.0, 816.0)   # 1600x900 menos la barra del HUD
	var origen: Vector2 = ProyeccionScript.origen_centrado(columnas, filas, area)
	# Los cuatro vertices extremos del tablero completo.
	var arriba: Vector2 = origen + ProyeccionScript.esquina_iso(0, 0)
	var derecha: Vector2 = origen + ProyeccionScript.esquina_iso(columnas, 0)
	var abajo: Vector2 = origen + ProyeccionScript.esquina_iso(columnas, filas)
	var izquierda: Vector2 = origen + ProyeccionScript.esquina_iso(0, filas)
	# Cabe dentro del area.
	assert_float(izquierda.x).is_greater_equal(0.0)
	assert_float(derecha.x).is_less_equal(area.x)
	assert_float(arriba.y).is_greater_equal(0.0)
	assert_float(abajo.y).is_less_equal(area.y)
	# Y esta centrado: mismo margen a izquierda y derecha, y arriba y abajo.
	assert_float(izquierda.x).is_equal_approx(area.x - derecha.x, TOL)
	assert_float(arriba.y).is_equal_approx(area.y - abajo.y, TOL)


# ── Ayuda ─────────────────────────────────────────────────────────────────────────────────────

# Compara dos Vector2 con tolerancia, diciendo QUE se comparaba si falla (sin esto, un fallo dice
# "esperaba 40.0, era 0.0" sin contar de que punto hablaba).
func _igual(obtenido: Vector2, esperado: Vector2, que: String) -> void:
	assert_float(obtenido.x).override_failure_message(
		"%s: X esperada %s, obtenida %s" % [que, esperado.x, obtenido.x]
	).is_equal_approx(esperado.x, TOL)
	assert_float(obtenido.y).override_failure_message(
		"%s: Y esperada %s, obtenida %s" % [que, esperado.y, obtenido.y]
	).is_equal_approx(esperado.y, TOL)
