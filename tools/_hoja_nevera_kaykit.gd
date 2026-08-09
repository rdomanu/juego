extends Node2D
## _hoja_nevera_kaykit — DESECHABLE (2026-08-06). REESCRITO tras la corrección del usuario:
##  1) Muñeco REAL del juego -- MISMO mecanismo que `tools/_hoja_impresora_dni.gd`
##     (`MunecoScript.construir_sprite("civil_h1", 44)`), no "girl" (silueta distinta, sin
##     cabezón naranja -- no es la referencia visual real del juego).
##  2) La variante elegida es `fridge_A` RETINTADA A BLANCO (`kaykit_fridge_A_blanca_*.png`,
##     `_render_kaykit_poly2.gd` -- retinte por SHADER/textura, no filtro plano).
##
## Escribe SOLO `hoja_nevera_blanca.png` al scratchpad. Se borra tras usarlo. NADA se integra en
## `assets/sprites/mobiliario/` -- es material de confirmación.

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const COLUMNAS: int = 11
const FILAS: int = 3
const TAM_RENDER := Vector2i(1150, 380)

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

const PX_POR_METRO: float = 44.0 / 1.70
const FACTOR_PRESENCIA: float = 1.25
const ALTURA_OBJETIVO_M: float = 1.80
const OBJETIVO_PX: float = ALTURA_OBJETIVO_M * PX_POR_METRO * FACTOR_PRESENCIA  # ~58,2 px
const ROTACIONES: Array[int] = [0, 90, 180, 270]
const ID_PIEZA := "kaykit_fridge_A_blanca"

const CELDA_MUNECO := Vector2i(0, 1)


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
	titulo.text = "Nevera KayKit -- fridge_A retintada a BLANCO (elegida) -- objetivo 1,80 m -> %.1f px" % OBJETIVO_PX
	titulo.add_theme_font_size_override("font_size", 15)
	titulo.add_theme_color_override("font_color", Color.WHITE)
	titulo.position = Vector2(16.0, 8.0)
	mundo.add_child(titulo)

	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = origen + ProyeccionScript.centro_iso(CELDA_MUNECO)
	mundo.add_child(muneco)
	_etiqueta(mundo, "muñeco\n(1,70 m)", CELDA_MUNECO, origen, Color(1.0, 1.0, 0.2))

	for i: int in ROTACIONES.size():
		var rot: int = ROTACIONES[i]
		var celda := Vector2i(2 + i * 2, 1)
		_marcar_huella(mundo, celda, origen)
		var alto_medido: int = _colocar_pieza(mundo, "%s%s_%d.png" % [CARPETA_SCRATCH, ID_PIEZA, rot], celda, origen)
		var dif: float = absf(float(alto_medido) - OBJETIVO_PX)
		var veredicto: String = "PASA" if dif <= 3.0 else "FALLA"
		var color_veredicto: Color = Color(0.4, 1.0, 0.4) if veredicto == "PASA" else Color(1.0, 0.35, 0.35)
		_etiqueta(mundo, "rot %d°" % rot, celda, origen, Color(1.0, 1.0, 0.2))
		_etiqueta_baja(
			mundo, "%dpx / %.0fpx\n%s" % [alto_medido, OBJETIVO_PX, veredicto], celda, origen, color_veredicto
		)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta: String = CARPETA_SCRATCH + "hoja_nevera_blanca.png"
	var err: Error = imagen.save_png(ruta)
	if err != OK:
		push_error("[HOJA NEVERA BLANCA] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[HOJA NEVERA BLANCA] %dx%d px -> %s" % [imagen.get_width(), imagen.get_height(), ruta])
	print("[HOJA NEVERA BLANCA] hecho.")
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


func _marcar_huella(mundo: Node2D, celda: Vector2i, origen: Vector2) -> void:
	var borde := Line2D.new()
	borde.width = 2.5
	borde.default_color = Color(1.0, 0.75, 0.2, 0.9)
	borde.closed = true
	borde.points = PackedVector2Array([
		origen + ProyeccionScript.esquina_iso(celda.x, celda.y),
		origen + ProyeccionScript.esquina_iso(celda.x + 1, celda.y),
		origen + ProyeccionScript.esquina_iso(celda.x + 1, celda.y + 1),
		origen + ProyeccionScript.esquina_iso(celda.x, celda.y + 1),
	])
	mundo.add_child(borde)


func _colocar_pieza(mundo: Node2D, ruta_absoluta: String, celda: Vector2i, origen: Vector2) -> int:
	var img: Image = Image.load_from_file(ruta_absoluta)
	if img == null:
		push_error("[HOJA NEVERA BLANCA] no se pudo cargar '%s'" % ruta_absoluta)
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
