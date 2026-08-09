extends Node2D
## _hoja_comparativa_impresoras — DESECHABLE (2026-08-06). Duelo de impresoras a ESCALA DE JUEGO:
## la composición del pipeline propio (impresora_doc_v1, scratchpad) contra la de Summer
## (demo/impresora_summer/, fotorrealista a ~740 px) — ambas junto al muñeco de 44 px.
##
## La de Summer llega SIN la escala del juego: aquí se recorta su contenido (el fondo casi blanco
## se hace transparente), se mide su alto útil y se reescala a 31 px (1,20 m) — el mismo listón
## que la propia v1. Escribe SOLO hoja_comparativa_impresoras.png al scratchpad.

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 12
const FILAS: int = 4
const TAM_RENDER := Vector2i(1000, 480)
const ALTO_OBJETIVO_PX: float = 31.0

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/3d17fabd-3e64-4077-8e28-18435fc15bba/scratchpad/"
const CARPETA_SUMMER := "C:/Users/manur/juego/demo/impresora_summer/"


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
	_rejilla(mundo, origen)

	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = origen + ProyeccionScript.centro_iso(Vector2i(1, 1))
	mundo.add_child(muneco)
	_etiqueta(mundo, "muñeco\n(1,70 m)", Vector2i(1, 1), origen)

	# HOJA A/B/C DE PRESENCIA (2026-08-06): el usuario ve "enana" la fotocopiadora a escala métrica
	# junto a los muñecos CABEZONES del juego. Tres factores para que elija: A realista (1,20 m =
	# 31 px) · B presencia +25% (39 px) · C presencia +45% (45 px, casi la altura del muñeco).
	_pieza_summer(mundo, "impresora_doc_summer_0", Vector2i(3, 1), origen, 31.0)
	_etiqueta(mundo, "A · realista\n31 px (1,20 m)", Vector2i(3, 1), origen)
	_pieza_summer(mundo, "impresora_doc_summer_0", Vector2i(5, 1), origen, 39.0)
	_etiqueta(mundo, "B · presencia\n39 px (+25%)", Vector2i(5, 1), origen)
	_pieza_summer(mundo, "impresora_doc_summer_0", Vector2i(7, 1), origen, 45.0)
	_etiqueta(mundo, "C · presencia+\n45 px (+45%)", Vector2i(7, 1), origen)
	var muneco2: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco2.position = origen + ProyeccionScript.centro_iso(Vector2i(9, 1))
	mundo.add_child(muneco2)
	_etiqueta(mundo, "muñeco\n(referencia)", Vector2i(9, 1), origen)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta: String = CARPETA_SCRATCH + "hoja_comparativa_impresoras.png"
	var err: Error = imagen.save_png(ruta)
	print("[HOJA COMPARATIVA] save=%d -> %s" % [err, ruta])
	get_tree().quit()


func _rejilla(mundo: Node2D, origen: Vector2) -> void:
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


func _pieza_scratch(mundo: Node2D, nombre: String, celda: Vector2i, origen: Vector2) -> void:
	var img: Image = Image.load_from_file(CARPETA_SCRATCH + nombre + ".png")
	if img == null:
		return
	_colocar(mundo, img, celda, origen)


## La pieza de Summer: fondo casi blanco → transparente, recorte al contenido y reescala al alto pedido.
func _pieza_summer(
	mundo: Node2D, nombre: String, celda: Vector2i, origen: Vector2,
	alto_px: float = ALTO_OBJETIVO_PX
) -> void:
	var img: Image = Image.load_from_file(CARPETA_SUMMER + nombre + ".png")
	if img == null:
		return
	img.convert(Image.FORMAT_RGBA8)
	var min_x: int = img.get_width()
	var max_x: int = -1
	var min_y: int = img.get_height()
	var max_y: int = -1
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.05 or (c.r > 0.96 and c.g > 0.96 and c.b > 0.96):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return
	var recorte: Image = img.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
	var escala: float = alto_px / float(recorte.get_height())
	recorte.resize(
		maxi(1, roundi(recorte.get_width() * escala)), roundi(alto_px),
		Image.INTERPOLATE_LANCZOS
	)
	print("[HOJA COMPARATIVA] %s: original %dx%d -> util %dx%d -> reescalada %dx%d" % [
		nombre, img.get_width(), img.get_height(), max_x - min_x + 1, max_y - min_y + 1,
		recorte.get_width(), recorte.get_height(),
	])
	_colocar(mundo, recorte, celda, origen)


func _colocar(mundo: Node2D, img: Image, celda: Vector2i, origen: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	AnclajeSpriteScript.aplicar(sprite, Vector2i.ZERO, 1)
	var raiz := Node2D.new()
	raiz.position = origen + ProyeccionScript.centro_iso(celda)
	raiz.add_child(sprite)
	mundo.add_child(raiz)


func _etiqueta(mundo: Node2D, texto: String, celda: Vector2i, origen: Vector2) -> void:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = origen + ProyeccionScript.esquina_iso(celda.x, celda.y) + Vector2(-30.0, -50.0)
	label.custom_minimum_size = Vector2(80.0, 0.0)
	mundo.add_child(label)
