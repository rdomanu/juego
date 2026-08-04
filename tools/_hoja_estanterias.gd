extends Node2D
## HOJA DE PROPUESTA DESECHABLE (2026-08-04) — regla del proyecto: todo objeto nuevo se enseña en
## imagen CON CELDAS antes de su OK. Muestra, sobre la rejilla isométrica real (`Proyeccion`) y
## anclado con `AnclajeSprite` (auto-anclaje: nada de fracciones a mano):
##   A) OBJ_007 entera (`comodidad_estanteria_obj007`, renderizada esta sesión al scratchpad).
##   B) OBJ_022 despiezada -- UNA estantería suelta (`comodidad_estanteria_suelta`, ídem).
##   C) DOS sueltas montando la esquina (rot 0 + rot 90), como la montaría el jugador.
##   D) El sillón YA integrado (OBJ_011 -> `comodidad_sofa_descanso`, recurso REAL de
##      `assets/sprites/mobiliario/`, cargado con `load()` normal).
##   E) Un muñeco de pie (`MunecoScript`, sprite "girl" 44px) de referencia de escala junto a A.
##
## Los PNG de A/B/C NO son recursos importados (viven en el scratchpad, fuera de `res://`): se
## cargan con `Image.load_from_file()` + `ImageTexture.create_from_image()`, no con `load()`.
##
## Escribe SOLO `hoja_estanterias_propuesta.png` al scratchpad. Se borra tras usarlo.

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 9
const FILAS: int = 5
const TAM_RENDER := Vector2i(900, 560)

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"
const RUTA_OBJ007 := CARPETA_SCRATCH + "comodidad_estanteria_obj007_%d.png"
const RUTA_SUELTA := CARPETA_SCRATCH + "comodidad_estanteria_suelta_%d.png"
const RUTA_SOFA := "res://assets/sprites/mobiliario/comodidad_sofa_descanso_0.png"

## Celdas de cada pieza de la hoja (ver la cabecera).
const CELDA_A := Vector2i(1, 1)
const CELDA_MUNECO := Vector2i(2, 1)
const CELDA_B := Vector2i(4, 1)
const CELDA_C1 := Vector2i(6, 1)  # rot 0
const CELDA_C2 := Vector2i(6, 2)  # rot 90 -- la segunda pieza, formando la esquina con la primera
const CELDA_D := Vector2i(1, 3)


func _ready() -> void:
	var sub := SubViewport.new()
	sub.size = TAM_RENDER
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)

	var capa_fondo := CanvasLayer.new()
	capa_fondo.layer = -1
	sub.add_child(capa_fondo)
	var fondo := ColorRect.new()
	fondo.color = Color(0.15, 0.16, 0.18)
	fondo.size = Vector2(TAM_RENDER)
	capa_fondo.add_child(fondo)

	var mundo := Node2D.new()
	sub.add_child(mundo)
	var origen: Vector2 = ProyeccionScript.origen_centrado(COLUMNAS, FILAS, Vector2(TAM_RENDER))

	_dibujar_rejilla(mundo, origen)

	# A) OBJ_007 entera.
	_colocar_pieza_externa(mundo, RUTA_OBJ007 % 0, CELDA_A, origen)
	_etiqueta(mundo, "A", CELDA_A, origen)

	# E) Muñeco de pie junto a A, referencia de escala.
	var muneco: Node2D = MunecoScript.construir_sprite("girl", 44)
	muneco.position = origen + ProyeccionScript.centro_iso(CELDA_MUNECO)
	mundo.add_child(muneco)
	_etiqueta(mundo, "E (1,70m)", CELDA_MUNECO, origen)

	# B) OBJ_022 despiezada -- una suelta.
	_colocar_pieza_externa(mundo, RUTA_SUELTA % 0, CELDA_B, origen)
	_etiqueta(mundo, "B", CELDA_B, origen)

	# C) Dos sueltas montando la esquina (rot 0 + rot 90).
	_colocar_pieza_externa(mundo, RUTA_SUELTA % 0, CELDA_C1, origen)
	_colocar_pieza_externa(mundo, RUTA_SUELTA % 90, CELDA_C2, origen)
	_etiqueta(mundo, "C", CELDA_C1, origen)

	# D) El sillón YA integrado (OBJ_011), recurso real.
	var sprite_d := Sprite2D.new()
	sprite_d.texture = load(RUTA_SOFA)
	AnclajeSpriteScript.aplicar(sprite_d, Vector2i.ZERO, 1)
	var raiz_d := Node2D.new()
	raiz_d.position = origen + ProyeccionScript.centro_iso(CELDA_D)
	raiz_d.add_child(sprite_d)
	mundo.add_child(raiz_d)
	_etiqueta(mundo, "D", CELDA_D, origen)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta: String = CARPETA_SCRATCH + "hoja_estanterias_propuesta.png"
	var err: Error = imagen.save_png(ruta)
	if err != OK:
		push_error("[HOJA ESTANTERIAS] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[HOJA ESTANTERIAS] %dx%d px -> %s" % [imagen.get_width(), imagen.get_height(), ruta])
	print("[HOJA ESTANTERIAS] hecho.")
	get_tree().quit()


## Rejilla isométrica de celdas dibujada, `COLUMNAS`×`FILAS`.
func _dibujar_rejilla(mundo: Node2D, origen: Vector2) -> void:
	for x: int in range(COLUMNAS):
		for y: int in range(FILAS):
			var borde := Line2D.new()
			borde.width = 1.0
			borde.default_color = Color(0.45, 0.48, 0.52, 0.65)
			borde.closed = true
			borde.points = PackedVector2Array([
				origen + ProyeccionScript.esquina_iso(x, y),
				origen + ProyeccionScript.esquina_iso(x + 1, y),
				origen + ProyeccionScript.esquina_iso(x + 1, y + 1),
				origen + ProyeccionScript.esquina_iso(x, y + 1),
			])
			mundo.add_child(borde)


## Un `Sprite2D` cargado desde un PNG EXTERNO (scratchpad, no recurso importado) y anclado con
## `AnclajeSprite` en `celda` (pieza de 1 celda: `paso=ZERO`, `celdas=1`).
func _colocar_pieza_externa(mundo: Node2D, ruta_absoluta: String, celda: Vector2i, origen: Vector2) -> void:
	var img: Image = Image.load_from_file(ruta_absoluta)
	if img == null:
		push_error("[HOJA ESTANTERIAS] no se pudo cargar '%s'" % ruta_absoluta)
		return
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	AnclajeSpriteScript.aplicar(sprite, Vector2i.ZERO, 1)
	var raiz := Node2D.new()
	raiz.position = origen + ProyeccionScript.centro_iso(celda)
	raiz.add_child(sprite)
	mundo.add_child(raiz)


## Etiqueta pequeña (Label con contorno) sobre la esquina norte de `celda`.
func _etiqueta(mundo: Node2D, texto: String, celda: Vector2i, origen: Vector2) -> void:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	label.position = origen + ProyeccionScript.esquina_iso(celda.x, celda.y) + Vector2(-4.0, -22.0)
	mundo.add_child(label)
