# ESTANTERIAS: MUEBLES DE PARED (2026-08-04 · quick-spec `construccion-pintura-puertas-preview` §1).
# Tipo: Integration. DETERMINISTA (sin azar, sin reloj, sin GPU: la capa visual se monta en headless
# y lo que se mide son posiciones de nodo, no pixeles de pantalla).
#
# El enunciado del usuario, literal: las estanterias "se anclan al EXTREMO de su celda segun su
# orientacion, de modo que NO quede hueco entre la pared y la estanteria (quedaria mal y poco
# realista, tienes que ver que esto se respete)".
#
# Lo que se demuestra aqui:
#   · comprar y colocar una estanteria cobra y CREA SU VISUAL (sprite, no la caja gris);
#   · el borde TRASERO de la base del sprite cae SOBRE la linea de pared de su celda (0 ± 3 px), que
#     es el mismo juez numerico del diagnostico `tools/_diag_estanterias_arrimadas.gd`;
#   · rotar con la R (HORIZONTAL/VERTICAL) cambia la pared a la que se arrima, y sigue cuadrando;
#   · una comodidad que NO es de pared (la papelera) sigue centrada en su celda — el arrimado no se
#     ha colado en el resto del catalogo;
#   · el mueble NO se sale de su celda: arrimarlo lo mete mas adentro de su huella, nunca fuera.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

const TAM_CELDA: int = 40
## Sala de ESPERA (las estanterias son familia "ciudadano"), con sitio de sobra.
const RECT_ESPERA := Rect2i(2, 2, 5, 5)
## La celda de pruebas: la del medio de la fila norte de la sala.
const CELDA := Vector2i(4, 2)

const NORTE := Vector2i(0, -1)
const OESTE := Vector2i(-1, 0)

## Mismo margen que el diagnostico: 3 px de pantalla es menos que el grosor de una linea de rejilla.
const TOL_PX: float = 3.0


# ── Fixture ──────────────────────────────────────────────────────────────────────────────

## Construccion con caja de sobra, sala de espera montada y capa visual encendida.
func _construccion() -> Node:
	var eco: Node = auto_free(EconomiaScript.new())
	eco.aplicar_config(ConfigEconomiaScript.new())
	eco.abonar(50000.0)
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(eco)
	construccion.construir_de_oficio_sala(&"sala_espera_doc", RECT_ESPERA)
	construccion.montar_visual(TAM_CELDA, Vector2.ZERO)
	return construccion


## El `Sprite2D` de la pieza plantada en una celda (null si esa pieza salio con caja gris). Las
## piezas se identifican por su POSICION: el nodo raiz de cada elemento se planta en el centro
## proyectado de su celda ancla.
func _sprite_en(construccion: Node, celda: Vector2i) -> Sprite2D:
	var objetivo: Vector2 = ProyeccionScript.centro_iso(celda)
	for hijo: Node in construccion._capa_elementos.get_children():
		if not (hijo is Node2D) or hijo is Label:
			continue
		if (hijo as Node2D).position.distance_to(objetivo) > 0.5:
			continue
		var sprite: Node = hijo.get_node_or_null("Caja/Sprite")
		if sprite is Sprite2D:
			return sprite as Sprite2D
	return null


## El CENTRO de la base del mueble tal y como queda dibujado, en el plano LOGICO CUADRADO. Es la
## cadena entera (nodo del elemento + nodo de la pieza + desvio de arrimado + ancla del sprite),
## deshecha la proyeccion — o sea: donde pisa de verdad el mueble sobre la rejilla.
func _centro_base_cuadrado(construccion: Node, celda: Vector2i) -> Vector2:
	var sprite: Sprite2D = _sprite_en(construccion, celda)
	var caja: Node2D = sprite.get_parent() as Node2D
	var raiz: Node2D = caja.get_parent() as Node2D
	var pantalla: Vector2 = (
		raiz.position + caja.position + sprite.position + sprite.offset
		+ AnclajeSpriteScript.centro_base(sprite.texture)
	)
	return ProyeccionScript.desproyectar(pantalla)


# ── AC-1 · Comprar y colocar una estanteria crea su visual de sprite ──────────────────────

func test_colocar_una_estanteria_cobra_y_crea_su_sprite() -> void:
	var construccion: Node = _construccion()
	var precio: int = Datos.obtener(&"Comodidad", &"estanteria").coste_construccion_eur
	var saldo_antes: float = construccion._economia.saldo_eur

	var id: StringName = construccion.construir_elemento(&"estanteria", CELDA)

	assert_str(String(id)).is_not_equal("")
	assert_float(construccion._economia.saldo_eur).is_equal_approx(
		saldo_antes - float(precio), 0.001
	)
	var sprite: Sprite2D = _sprite_en(construccion, CELDA)
	assert_object(sprite).override_failure_message(
		"la estanteria salio con la caja gris en vez de su sprite"
	).is_not_null()
	assert_object(sprite.texture).is_not_null()
	# `centered = false`: el sprite se ancla por su base, no por el centro del lienzo.
	assert_bool(sprite.centered).is_false()


func test_la_estanteria_pequena_usa_el_arte_de_la_suelta() -> void:
	var construccion: Node = _construccion()

	assert_str(String(construccion.construir_elemento(&"estanteria_pequena", CELDA))).is_not_equal("")

	var sprite: Sprite2D = _sprite_en(construccion, CELDA)
	assert_object(sprite).is_not_null()
	# El id de catalogo es `estanteria_pequena` pero el arte salio del render como
	# `comodidad_estanteria_suelta_*` (OBJ_022): el puente lo declara `_sprites_comodidad`.
	assert_str(sprite.texture.resource_path).contains("comodidad_estanteria_suelta_")


# ── AC-2 · EL JUEZ: el borde trasero cae sobre la linea de pared (0 ± 3 px) ───────────────

## El mismo test que el diagnostico, en automatico: se compara el punto medio del borde TRASERO de
## la base con el punto medio de la ARISTA de la celda por la que el mueble da la espalda.
func _asertar_arrimado(construccion: Node, celda: Vector2i, espalda: Vector2i) -> void:
	var sprite: Sprite2D = _sprite_en(construccion, celda)
	assert_object(sprite).is_not_null()
	var semiejes: Vector2 = AnclajeSpriteScript.semiejes_base(sprite.texture)
	var semieje_fondo: float = semiejes.y if espalda.x == 0 else semiejes.x
	var trasero: Vector2 = (
		_centro_base_cuadrado(construccion, celda) + Vector2(espalda) * semieje_fondo
	)
	var linea_pared: Vector2 = (
		ProyeccionScript.centro_cuadrado(celda) + Vector2(espalda) * (TAM_CELDA * 0.5)
	)
	# En PANTALLA, que es donde el usuario juzga el hueco (y donde esta definida la tolerancia).
	var delta: Vector2 = (
		ProyeccionScript.proyectar(trasero) - ProyeccionScript.proyectar(linea_pared)
	)
	assert_vector(delta).override_failure_message(
		"queda hueco entre la pared %s y la estanteria de %s: %s px" % [espalda, celda, delta]
	).is_equal_approx(Vector2.ZERO, Vector2(TOL_PX, TOL_PX))


func test_horizontal_arrima_la_estanteria_a_la_pared_norte() -> void:
	var construccion: Node = _construccion()

	construccion.construir_elemento(&"estanteria", CELDA, construccion.HORIZONTAL)

	_asertar_arrimado(construccion, CELDA, NORTE)


func test_vertical_arrima_la_estanteria_a_la_pared_oeste() -> void:
	var construccion: Node = _construccion()

	construccion.construir_elemento(&"estanteria", CELDA, construccion.VERTICAL)

	_asertar_arrimado(construccion, CELDA, OESTE)


func test_la_estanteria_pequena_tambien_se_arrima_en_los_dos_giros() -> void:
	var horizontal: Node = _construccion()
	horizontal.construir_elemento(&"estanteria_pequena", CELDA, horizontal.HORIZONTAL)
	_asertar_arrimado(horizontal, CELDA, NORTE)

	var vertical: Node = _construccion()
	vertical.construir_elemento(&"estanteria_pequena", CELDA, vertical.VERTICAL)
	_asertar_arrimado(vertical, CELDA, OESTE)


# Rotar tiene que MOVER el mueble: si los dos giros dieran el mismo dibujo, los tests de arriba
# podrian pasar los dos por casualidad (con un mueble casi cuadrado) y la R no serviria de nada.
func test_rotar_cambia_de_pared_y_por_tanto_de_sitio() -> void:
	var horizontal: Node = _construccion()
	horizontal.construir_elemento(&"estanteria", CELDA, horizontal.HORIZONTAL)
	var vertical: Node = _construccion()
	vertical.construir_elemento(&"estanteria", CELDA, vertical.VERTICAL)

	var centro_h: Vector2 = _centro_base_cuadrado(horizontal, CELDA)
	var centro_v: Vector2 = _centro_base_cuadrado(vertical, CELDA)

	assert_float(centro_h.distance_to(centro_v)).is_greater(TOL_PX)
	# Y cada uno hacia SU pared: el horizontal mas al norte (Y menor), el vertical mas al oeste.
	assert_float(centro_h.y).is_less(ProyeccionScript.centro_cuadrado(CELDA).y)
	assert_float(centro_v.x).is_less(ProyeccionScript.centro_cuadrado(CELDA).x)


# ── AC-3 · La ley del usuario: un objeto NO puede salir de sus celdas ─────────────────────

# Arrimar mete el mueble contra una pared, y eso NO puede sacarlo por el otro lado. La base entera
# tiene que seguir dentro del cuadrado de su celda (con el margen del rasterizado).
func test_arrimar_no_saca_la_estanteria_de_su_celda() -> void:
	for orientacion: int in [ConstruccionScript.HORIZONTAL, ConstruccionScript.VERTICAL]:
		for id_catalogo: StringName in [&"estanteria", &"estanteria_pequena"]:
			var construccion: Node = _construccion()
			construccion.construir_elemento(id_catalogo, CELDA, orientacion)
			var sprite: Sprite2D = _sprite_en(construccion, CELDA)
			var semiejes: Vector2 = AnclajeSpriteScript.semiejes_base(sprite.texture)
			var centro: Vector2 = _centro_base_cuadrado(construccion, CELDA)
			var celda_min: Vector2 = Vector2(CELDA) * float(TAM_CELDA)
			var celda_max: Vector2 = celda_min + Vector2(TAM_CELDA, TAM_CELDA)
			assert_bool(
				centro.x - semiejes.x >= celda_min.x - TOL_PX
				and centro.y - semiejes.y >= celda_min.y - TOL_PX
				and centro.x + semiejes.x <= celda_max.x + TOL_PX
				and centro.y + semiejes.y <= celda_max.y + TOL_PX
			).override_failure_message(
				"'%s' (%d) se sale de la celda %s: centro=%s semiejes=%s" % [
					id_catalogo, orientacion, CELDA, centro, semiejes
				]
			).is_true()


# ── AC-4 · El arrimado NO se ha colado en el resto del catalogo ───────────────────────────

func test_una_papelera_sigue_centrada_en_su_celda() -> void:
	var construccion: Node = _construccion()

	construccion.construir_elemento(&"papelera", CELDA)

	var sprite: Sprite2D = _sprite_en(construccion, CELDA)
	assert_object(sprite).is_not_null()
	# Sin arrimado, el sprite no lleva desplazamiento propio dentro de su pieza.
	assert_vector(sprite.position).is_equal(Vector2.ZERO)
	# Y su base cae en el centro del rombo de la celda.
	assert_vector(_centro_base_cuadrado(construccion, CELDA)).is_equal_approx(
		ProyeccionScript.centro_cuadrado(CELDA), Vector2(TOL_PX, TOL_PX)
	)
