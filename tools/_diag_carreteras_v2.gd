extends Node2D
## Sonda DESECHABLE (2026-08-08, verificación de los 3 bugs de playtest de carreteras -- v3, tras
## el veredicto del usuario sobre v2: "la curva sigue mal" + "los coches salían atravesados").
## Coloca sprites YA RENDERIZADOS con el MISMO mecanismo de ancla que usa el juego
## (`AnclajeSprite.aplicar`, `Proyeccion.centro_iso`) para comprobar la cadena
## recta(N-S, con 2 coches)->curva(dobla a Este)->recta(E-O continuando).
##
## ── ORIENTACIÓN, VERIFICADA CON PÍXELES (NO A OJO -- ver `tools/_diag_orientacion_coches.gd` y el
## muestreo de color de los 4 bordes de cada rotación, informe de esta tarea) ────────────────────
##  · `carretera_recta_0`/`_180`: asfalto ESTE-OESTE (bordes abiertos oeste+este).
##  · `carretera_recta_90`/`_270`: asfalto NORTE-SUR (bordes abiertos norte+sur) -- la que hace
##    falta para la calle N-S de esta sonda.
##  · `carretera_curva_180`: bordes abiertos NORTE+ESTE -- dobla un tramo que llega del norte hacia
##    el este.
##  · Coches: `AnclajeSprite.semiejes_base` da el eje LARGO (morro-cola) en Y (norte-sur) a
##    rotación 0/180 -- las que hacen falta sobre una calle N-S; a 90/270 el eje largo es X
##    (este-oeste), ahí es donde iban "atravesados" en `carreteras_v2.png`.
##
## Vuelca un PNG a la ruta pasada por `OS.get_cmdline_user_args()`.

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const SALIDA_ENTORNO := "res://assets/sprites/entorno/"
const PASO: int = 6  # ancho_objetivo_celdas de la familia roads -- ver la cabecera de MODELOS.

func _cargar(id: String, rot: int) -> Texture2D:
	return load("%s%s_%d.png" % [SALIDA_ENTORNO, id, rot])


func _colocar(textura: Texture2D, celda: Vector2i, capa: Node2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = textura
	AnclajeSpriteScript.aplicar(sprite, Vector2i(1, 0), 1)
	sprite.position = Proyeccion.centro_iso(celda)
	capa.add_child(sprite)
	return sprite


func _ready() -> void:
	position = Vector2(700.0, 250.0)

	# Cadena: tramo1 (N-S, recta_90) en (0,0) -> curva_180 (abre norte+este) en (0,PASO) -- al sur
	# de tramo1, comparte su borde NORTE con el SUR de tramo1 -- -> tramo2 (E-O, recta_0) en
	# (PASO,PASO) -- al este de la curva, comparte su borde OESTE con el ESTE de la curva.
	_colocar(_cargar("carretera_recta", 90), Vector2i(0, 0), self)
	_colocar(_cargar("carretera_curva", 180), Vector2i(0, PASO), self)
	_colocar(_cargar("carretera_recta", 0), Vector2i(PASO, PASO), self)

	# 2 coches en tramo1, cada uno en su carril (offset ESTE-OESTE, perpendicular a la vía),
	# alineados con la calle N-S: rotación 0 (mira al sur) y 180 (mira al norte) -- eje largo en Y,
	# ver la cabecera.
	var coche1 := Sprite2D.new()
	coche1.texture = _cargar("coche_policia", 0)
	AnclajeSpriteScript.aplicar(coche1, Vector2i(1, 0), 1)
	coche1.position = Proyeccion.centro_iso(Vector2i(-1, 0))
	add_child(coche1)
	var coche2 := Sprite2D.new()
	coche2.texture = _cargar("coche_sedan", 180)
	AnclajeSpriteScript.aplicar(coche2, Vector2i(1, 0), 1)
	coche2.position = Proyeccion.centro_iso(Vector2i(1, 0))
	add_child(coche2)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ruta_salida: String = args[0] if args.size() > 0 else "C:/Users/manur/juego/tools/_diag_carreteras_v3_salida.png"

	var viewport: Viewport = get_viewport()
	var imagen: Image = viewport.get_texture().get_image()
	var err: Error = imagen.save_png(ruta_salida)
	if err != OK:
		push_error("[DIAG CARRETERAS V3] save_png '%s' fallo (error %d)" % [ruta_salida, err])
	else:
		print("[DIAG CARRETERAS V3] guardado -> %s" % ruta_salida)

	get_tree().quit()
