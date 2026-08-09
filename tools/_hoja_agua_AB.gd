extends Node2D
## _hoja_agua_AB — DESECHABLE (2026-08-06). Hoja de ELECCIÓN entre los dos objetos de "agua" del
## catálogo, para que el usuario decida cuál sobrevive a la unificación:
##  A) `dispensador_agua` (botellón azul) -- el sprite YA integrado hoy en
##     `assets/sprites/mobiliario/comodidad_dispensador_agua_*.png` (recurso REAL, `load()`
##     normal), TAL CUAL está en el juego, sin reescalar. Una sola vista (así es como vive hoy).
##  B) `fuente_agua` (Water Cooler, poly.pizza) RE-RENDERIZADA a 1,60 m real ×1,25 (factor de
##     presencia) -> ~51,8 px (`_render_fuente_agua_160.gd`, scratchpad). 4 rotaciones reales.
##
## Muñeco REAL del juego (`civil_h1_44px`, mismo mecanismo que `_hoja_impresora_dni.gd`) junto a
## cada uno. Rejilla isométrica real dibujada. Bajo cada pieza: altura medida en px Y en metros
## equivalentes (medido_px / PX_POR_METRO, sin descontar el factor de presencia -- lectura directa
## de "a qué tamaño real correspondería este sprite con la regla estándar del proyecto"). B lleva
## además el veredicto PASA/FALLA contra su objetivo (51,8px ±3).
##
## Escribe SOLO `hoja_agua_AB.png` al scratchpad. Se borra tras usarlo.

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const COLUMNAS: int = 11
const FILAS: int = 4
const TAM_RENDER := Vector2i(1150, 480)

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"
const RUTA_A := "res://assets/sprites/mobiliario/comodidad_dispensador_agua_0.png"

const PX_POR_METRO: float = 44.0 / 1.70
const FACTOR_PRESENCIA: float = 1.25
const ALTURA_OBJETIVO_B_M: float = 1.60
const OBJETIVO_B_PX: float = ALTURA_OBJETIVO_B_M * PX_POR_METRO * FACTOR_PRESENCIA  # ~51,8 px
const ROTACIONES: Array[int] = [0, 90, 180, 270]

const CELDA_MUNECO_A := Vector2i(0, 1)
const CELDA_A := Vector2i(1, 1)
const CELDA_MUNECO_B := Vector2i(4, 1)


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

	var titulo := Label.new()
	titulo.text = "Agua -- A) dispensador_agua (integrado, tal cual) vs B) fuente_agua re-render 1,60m -> %.1fpx" % OBJETIVO_B_PX
	titulo.add_theme_font_size_override("font_size", 14)
	titulo.add_theme_color_override("font_color", Color.WHITE)
	titulo.position = Vector2(16.0, 8.0)
	mundo.add_child(titulo)

	# A -- el sprite YA integrado, recurso REAL con load().
	var muneco_a: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco_a.position = origen + ProyeccionScript.centro_iso(CELDA_MUNECO_A)
	mundo.add_child(muneco_a)
	_etiqueta(mundo, "muñeco\n(1,70 m)", CELDA_MUNECO_A, origen, Color(1.0, 1.0, 0.2))

	var alto_a: int = _colocar_pieza_recurso(mundo, RUTA_A, CELDA_A, origen)
	var metros_a: float = float(alto_a) / PX_POR_METRO
	_etiqueta(mundo, "A) dispensador_agua\n(integrado)", CELDA_A, origen, Color(0.4, 0.9, 1.0))
	_etiqueta_baja(mundo, "%dpx (~%.2fm equiv.)" % [alto_a, metros_a], CELDA_A, origen, Color(0.85, 0.85, 0.85))

	# B -- fuente_agua re-renderizada, 4 rotaciones, PNG externo del scratchpad.
	var muneco_b: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco_b.position = origen + ProyeccionScript.centro_iso(CELDA_MUNECO_B)
	mundo.add_child(muneco_b)
	_etiqueta(mundo, "muñeco\n(1,70 m)", CELDA_MUNECO_B, origen, Color(1.0, 1.0, 0.2))

	for i: int in ROTACIONES.size():
		var rot: int = ROTACIONES[i]
		var celda := Vector2i(6 + i * 2, 1)
		var ruta_png: String = "%sfuente_agua_160_%d.png" % [CARPETA_SCRATCH, rot]
		var alto_b: int = _colocar_pieza_externa(mundo, ruta_png, celda, origen)
		var metros_b: float = float(alto_b) / PX_POR_METRO
		var dif: float = absf(float(alto_b) - OBJETIVO_B_PX)
		var veredicto: String = "PASA" if dif <= 3.0 else "FALLA"
		var color_veredicto: Color = Color(0.4, 1.0, 0.4) if veredicto == "PASA" else Color(1.0, 0.35, 0.35)
		_etiqueta(mundo, "B) rot %d°" % rot, celda, origen, Color(0.4, 0.9, 1.0))
		_etiqueta_baja(
			mundo,
			"%dpx (~%.2fm equiv.)\n%.0fpx obj. -- %s" % [alto_b, metros_b, OBJETIVO_B_PX, veredicto],
			celda, origen, color_veredicto
		)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta: String = CARPETA_SCRATCH + "hoja_agua_AB.png"
	var err: Error = imagen.save_png(ruta)
	if err != OK:
		push_error("[HOJA AGUA AB] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[HOJA AGUA AB] %dx%d px -> %s" % [imagen.get_width(), imagen.get_height(), ruta])
	print("[HOJA AGUA AB] hecho.")
	get_tree().quit()


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


## A -- recurso REAL de `res://`, cargado con `load()` normal (no `Image.load_from_file`).
func _colocar_pieza_recurso(mundo: Node2D, ruta_res: String, celda: Vector2i, origen: Vector2) -> int:
	var tex: Texture2D = load(ruta_res)
	if tex == null:
		push_error("[HOJA AGUA AB] no se pudo cargar '%s'" % ruta_res)
		return 0
	var sprite := Sprite2D.new()
	sprite.texture = tex
	AnclajeSpriteScript.aplicar(sprite, Vector2i.ZERO, 1)
	var raiz := Node2D.new()
	raiz.position = origen + ProyeccionScript.centro_iso(celda)
	raiz.add_child(sprite)
	mundo.add_child(raiz)
	var img: Image = tex.get_image()
	return _alto_util(img)


func _colocar_pieza_externa(mundo: Node2D, ruta_absoluta: String, celda: Vector2i, origen: Vector2) -> int:
	var img: Image = Image.load_from_file(ruta_absoluta)
	if img == null:
		push_error("[HOJA AGUA AB] no se pudo cargar '%s'" % ruta_absoluta)
		return 0
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	AnclajeSpriteScript.aplicar(sprite, Vector2i.ZERO, 1)
	var raiz := Node2D.new()
	raiz.position = origen + ProyeccionScript.centro_iso(celda)
	raiz.add_child(sprite)
	mundo.add_child(raiz)
	return _alto_util(img)


func _alto_util(img: Image) -> int:
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	var ancho: int = img.get_width()
	var alto: int = img.get_height()
	var min_y := -1
	for py: int in range(alto):
		if AnclajeSpriteScript._fila_opaca(img, py, ancho):
			min_y = py
			break
	if min_y < 0:
		return 0
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if AnclajeSpriteScript._fila_opaca(img, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1


func _etiqueta(mundo: Node2D, texto: String, celda: Vector2i, origen: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = origen + ProyeccionScript.esquina_iso(celda.x, celda.y) + Vector2(-30.0, -46.0)
	label.custom_minimum_size = Vector2(80.0, 0.0)
	mundo.add_child(label)


func _etiqueta_baja(mundo: Node2D, texto: String, celda: Vector2i, origen: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = origen + ProyeccionScript.esquina_iso(celda.x, celda.y + 1) + Vector2(-30.0, 6.0)
	label.custom_minimum_size = Vector2(80.0, 0.0)
	mundo.add_child(label)
