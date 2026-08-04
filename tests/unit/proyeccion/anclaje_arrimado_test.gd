# ARRIMADO A PARED de los muebles de pared (estanterias) — la geometria, sin nodos ni escena.
# Tipo: Logic. DETERMINISTA: mide PNG del repo (fijos) y hace aritmetica; sin reloj ni RNG.
#
# Orden del usuario (quick-spec construccion-pintura-puertas-preview-2026-08-04 §1): una estanteria
# se ancla al EXTREMO de su celda, "de modo que NO quede hueco entre la pared y la estanteria".
# La cuenta que lo hace vive en AnclajeSprite y es:
#
#     recorrido = TAM_CELDA/2 − semieje_del_fondo      (en el plano logico cuadrado)
#     desvio    = proyectar(direccion_de_la_espalda * recorrido)
#
# Lo que este test protege, en orden de importancia:
#   1. Que el semieje de fondo se MIDA bien del PNG (contra la anchura total de la silueta, que se
#      mide por otro camino: los dos semiejes tienen que sumar el ancho del rombo de la base).
#   2. Que la ESPALDA declarada de cada estanteria siga cuadrando con el eje DELGADO medido. Es la
#      red que salta si alguien re-renderiza el arte girado: el dato declarado dejaria de ser cierto
#      y hoy nadie se enteraria hasta ver el mueble incrustado en la pared.
#   3. Que el desvio apunte a la pared correcta y valga lo mismo en las cuatro rotaciones.
extends GdUnitTestSuite

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")

const RUTA_MOBILIARIO := "res://assets/sprites/mobiliario/"

const NORTE := Vector2i(0, -1)
const OESTE := Vector2i(-1, 0)
const SUR := Vector2i(0, 1)
const ESTE := Vector2i(1, 0)

# Tolerancia en px. 1 px cubre el redondeo del rasterizado (el borde de la base cae dentro de un
# pixel, no en su frontera exacta) y sigue siendo 20 veces mas fino que el error que se persigue.
const TOL: float = 1.0

# Las dos estanterias del catalogo y el prefijo con el que se renderizo su arte.
const PREFIJO := {
	&"estanteria": "comodidad_estanteria",
	&"estanteria_pequena": "comodidad_estanteria_suelta",
}


func _textura(prefijo: String, rotacion: int) -> Texture2D:
	var ruta: String = "%s%s_%d.png" % [RUTA_MOBILIARIO, prefijo, rotacion]
	assert_bool(ResourceLoader.exists(ruta)).override_failure_message(
		"falta el PNG '%s'" % ruta
	).is_true()
	return load(ruta)


# ── 1. La medida de la base sale de los pixeles y es coherente consigo misma ───────────────────

# Los dos semiejes tienen que sumar la MITAD del ancho de la silueta: en la proyeccion 2:1 un
# rectangulo de suelo de lados a×b proyecta un rombo de (a+b) de ancho, mida lo que mida cada lado.
# Los semiejes se miden por el contorno inferior y el ancho por los extremos opacos — dos caminos
# distintos que tienen que dar el mismo numero.
func test_los_semiejes_suman_el_semiancho_de_la_silueta() -> void:
	for id_catalogo: StringName in PREFIJO:
		for rotacion: int in [0, 90, 180, 270]:
			var textura: Texture2D = _textura(PREFIJO[id_catalogo], rotacion)
			var semiejes: Vector2 = AnclajeSpriteScript.semiejes_base(textura)
			var imagen: Image = textura.get_image()
			var min_x: int = imagen.get_width()
			var max_x: int = -1
			for px: int in imagen.get_width():
				for py: int in imagen.get_height():
					if imagen.get_pixel(px, py).a > AnclajeSpriteScript.UMBRAL_ALFA:
						min_x = mini(min_x, px)
						max_x = maxi(max_x, px)
						break
			var semiancho: float = float(max_x + 1 - min_x) * 0.5
			# 1,5 px de margen: cada semieje arrastra medio pixel de redondeo del contorno.
			assert_float(semiejes.x + semiejes.y).override_failure_message(
				"%s@%d: semiejes %s no suman el semiancho %.2f" % [
					id_catalogo, rotacion, semiejes, semiancho
				]
			).is_equal_approx(semiancho, 1.5)


# Una estanteria es un mueble LARGO y POCO PROFUNDO: su lado delgado tiene que medir menos de media
# celda, que es lo que hace que arrimarla se note. Si algun dia el arte cambiara y midiera mas, el
# arrimado se anularia solo (recorrido 0) y este test lo cantaria antes.
func test_las_estanterias_son_menos_hondas_que_media_celda() -> void:
	for id_catalogo: StringName in PREFIJO:
		var textura: Texture2D = _textura(PREFIJO[id_catalogo], 0)
		var semiejes: Vector2 = AnclajeSpriteScript.semiejes_base(textura)
		var semieje_corto: float = minf(semiejes.x, semiejes.y)
		assert_float(semieje_corto).is_less(ProyeccionScript.TAM_CELDA * 0.5)


# ── 2. La espalda DECLARADA contra el eje delgado MEDIDO ───────────────────────────────────────

# LA RED DE SEGURIDAD del dato a mano. `espalda_0` es lo unico del arte que se declara en el codigo
# (`Construccion._sprites_comodidad`), porque los dos modelos venian girados 90° el uno respecto del
# otro en el catalogo 3D. Aqui se comprueba contra la medida: el eje por el que un mueble da la
# espalda TIENE que ser el eje por el que es delgado, en las cuatro rotaciones.
func test_la_espalda_declarada_cae_por_el_eje_delgado_medido() -> void:
	for id_catalogo: StringName in PREFIJO:
		var datos: Dictionary = ConstruccionScript._sprites_comodidad()[id_catalogo]
		assert_bool(datos.has("espalda_0")).override_failure_message(
			"'%s' deberia estar declarada como mueble de pared" % id_catalogo
		).is_true()
		for rotacion: int in [0, 90, 180, 270]:
			var textura: Texture2D = _textura(PREFIJO[id_catalogo], rotacion)
			var espalda: Vector2i = AnclajeSpriteScript.espalda_girada(datos["espalda_0"], rotacion)
			var eje_espalda := Vector2i(absi(espalda.x), absi(espalda.y))
			assert_vector(AnclajeSpriteScript.eje_corto(textura)).override_failure_message(
				"%s@%d: da la espalda a %s pero es delgada por el otro eje" % [
					id_catalogo, rotacion, espalda
				]
			).is_equal(eje_espalda)


# El ciclo de la espalda: cuatro pasos de 90° vuelven al punto de partida, y girar 180° da la
# direccion contraria. Sin esto, "girar" podria ir en el sentido equivocado y nadie lo notaria en
# los muebles simetricos.
func test_el_ciclo_de_la_espalda_da_la_vuelta_completa() -> void:
	for espalda: Vector2i in AnclajeSpriteScript.CICLO_ESPALDA:
		assert_vector(AnclajeSpriteScript.espalda_girada(espalda, 0)).is_equal(espalda)
		assert_vector(AnclajeSpriteScript.espalda_girada(espalda, 180)).is_equal(-espalda)
		assert_vector(AnclajeSpriteScript.espalda_girada(espalda, 360)).is_equal(espalda)


# `rotacion_para_espalda` es la inversa de `espalda_girada`: la ida y la vuelta tienen que cerrar
# para cualquier par. Es lo que traduce "esta estanteria va contra la pared norte" a "carga el PNG
# de 270°", asi que si esto se desalinea el mueble sale mirando a la pared.
func test_la_rotacion_para_una_espalda_es_la_inversa_del_giro() -> void:
	for desde: Vector2i in AnclajeSpriteScript.CICLO_ESPALDA:
		for hasta: Vector2i in AnclajeSpriteScript.CICLO_ESPALDA:
			var rotacion: int = AnclajeSpriteScript.rotacion_para_espalda(desde, hasta)
			assert_vector(AnclajeSpriteScript.espalda_girada(desde, rotacion)).is_equal(hasta)


# ── 3. El desvio: la cuenta, con un sprite CONOCIDO ────────────────────────────────────────────

# La estanteria pequena a 0° (32×58 px) da la espalda al NORTE y su base mide 6,5 px de fondo, asi
# que el recorrido es 40/2 − 6,5/2 = 16,75 px de plano cuadrado hacia el norte, que proyectado son
# (+16,75, −8,375) px de pantalla (el norte, en isometrico, es arriba-DERECHA).
#
# Los numeros no estan escritos a mano: se derivan aqui de la propia medida. Lo que fija el test es
# la CUENTA — que el desvio es exactamente "media celda menos medio fondo, en la direccion de la
# espalda, proyectado" — y de paso las dos cosas que se ven a ojo en el juego: hacia donde empuja.
func test_el_desvio_es_media_celda_menos_medio_fondo_hacia_la_espalda() -> void:
	var textura: Texture2D = _textura(PREFIJO[&"estanteria_pequena"], 0)
	var semiejes: Vector2 = AnclajeSpriteScript.semiejes_base(textura)
	var recorrido: float = ProyeccionScript.TAM_CELDA * 0.5 - semiejes.y
	var esperado: Vector2 = ProyeccionScript.proyectar(Vector2(NORTE) * recorrido)

	var desvio: Vector2 = AnclajeSpriteScript.desvio_arrimado(textura, NORTE)

	assert_vector(desvio).is_equal_approx(esperado, Vector2(TOL, TOL))
	# Y el norte empuja arriba-derecha: si el signo se invirtiera, la estanteria se iria al centro
	# de la sala en vez de a la pared, y el test de arriba (que compara contra la misma formula)
	# seguiria pasando. Por eso se comprueba tambien el SENTIDO, que es lo que ve el jugador.
	assert_bool(desvio.x > 0.0 and desvio.y < 0.0).is_true()


# Las cuatro paredes: el desvio siempre mide lo mismo (el mueble es el mismo, solo gira) y apunta a
# la pared que toca. Girar 180° tiene que dar el desvio opuesto, exactamente.
func test_las_cuatro_paredes_dan_el_mismo_recorrido_en_direcciones_opuestas() -> void:
	var datos: Dictionary = ConstruccionScript._sprites_comodidad()[&"estanteria"]
	var desvios: Dictionary[Vector2i, Vector2] = {}
	for espalda: Vector2i in [NORTE, ESTE, SUR, OESTE]:
		var rotacion: int = AnclajeSpriteScript.rotacion_para_espalda(datos["espalda_0"], espalda)
		desvios[espalda] = AnclajeSpriteScript.desvio_arrimado(
			_textura(PREFIJO[&"estanteria"], rotacion), espalda
		)
	assert_float(desvios[NORTE].length()).is_equal_approx(desvios[SUR].length(), TOL)
	assert_float(desvios[ESTE].length()).is_equal_approx(desvios[OESTE].length(), TOL)
	assert_vector(desvios[NORTE]).is_equal_approx(-desvios[SUR], Vector2(TOL, TOL))
	assert_vector(desvios[ESTE]).is_equal_approx(-desvios[OESTE], Vector2(TOL, TOL))


# Un mueble MAS HONDO que su celda no se empuja (se saldria mas todavia): el recorrido se recorta a
# cero. Se prueba con una textura sintetica de un rombo de celda ENTERA (80×40), que es justo el
# caso limite — fondo = celda, recorrido = 0.
func test_un_mueble_tan_hondo_como_su_celda_no_se_arrima() -> void:
	var imagen := Image.create(80, 40, false, Image.FORMAT_RGBA8)
	for py: int in 40:
		for px: int in 80:
			# El rombo de una celda: |x−40|/2 + |y−20| <= 20.
			var dentro: bool = absf(float(px) - 39.5) * 0.5 + absf(float(py) - 19.5) <= 20.0
			imagen.set_pixel(px, py, Color(1, 1, 1, 1) if dentro else Color(0, 0, 0, 0))
	var textura: Texture2D = ImageTexture.create_from_image(imagen)

	var desvio: Vector2 = AnclajeSpriteScript.desvio_arrimado(textura, NORTE)

	assert_vector(desvio).is_equal_approx(Vector2.ZERO, Vector2(TOL, TOL))


# ── 4. La R de rotar: los dos estados llegan a las dos paredes del FONDO ───────────────────────

# HORIZONTAL → pared norte, VERTICAL → pared oeste, para las DOS estanterias, aunque su arte venga
# girado distinto. Es lo unico que el jugador percibe del mecanismo, y lo que garantiza que la R
# haga algo util con estos muebles.
func test_la_erre_lleva_las_dos_estanterias_a_la_pared_norte_y_a_la_oeste() -> void:
	for id_catalogo: StringName in PREFIJO:
		var datos: Dictionary = ConstruccionScript._sprites_comodidad()[id_catalogo]
		var rot_h: int = ConstruccionScript.rotacion_sprite_comodidad(
			datos, ConstruccionScript.HORIZONTAL
		)
		var rot_v: int = ConstruccionScript.rotacion_sprite_comodidad(
			datos, ConstruccionScript.VERTICAL
		)
		assert_vector(AnclajeSpriteScript.espalda_girada(datos["espalda_0"], rot_h)).is_equal(NORTE)
		assert_vector(AnclajeSpriteScript.espalda_girada(datos["espalda_0"], rot_v)).is_equal(OESTE)


# Las comodidades de siempre NO son de pared: se siguen centrando en su celda. Sin esta linea, un
# `espalda_0` colado por error en otra entrada movería medio metro una papelera sin que nadie lo
# pidiera.
func test_las_comodidades_de_siempre_no_son_de_pared() -> void:
	for id_catalogo: StringName in [&"papelera", &"radio", &"dispensador_agua", &"equipo_informatico"]:
		assert_bool(ConstruccionScript.es_comodidad_de_pared(id_catalogo)).override_failure_message(
			"'%s' no deberia ser mueble de pared" % id_catalogo
		).is_false()
