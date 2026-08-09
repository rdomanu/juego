extends Node2D
## _hoja_lamparas_kaykit — DESECHABLE (2026-08-06). REESCRITO 2 VECES tras correcciones del
## usuario:
##  1) Muñeco REAL del juego -- MISMO mecanismo que `tools/_hoja_impresora_dni.gd`
##     (`MunecoScript.construir_sprite("civil_h1", 44)`).
##  2) v1 quedó "casi invisible" (piezas casi blancas, pequeñas, sin contraste) Y v2 (con zooms)
##     quedó con las DOS bandas (de pie / de mesa) SOLAPADAS -- el error: intentar meter el
##     recuadro de zoom (~150-210px de alto) dentro del mismo espaciado de FILA de la rejilla
##     isométrica (solo 20px por fila). Corregido: cada lámpara vive en su propia BANDA con un
##     origen de rejilla LOCAL e independiente (`_origen_banda`), separadas por 460px fijos en
##     pantalla -- ya NO comparten fila con nada más.
##
## Cada banda: fila real-escala (rejilla + huella + muñeco + 4 rotaciones) arriba, recuadro de
## ZOOM (panel claro, contraste con el fondo oscuro) debajo, mismas 4 rotaciones ampliadas.
##
## Escribe SOLO `hoja_lamparas.png` al scratchpad. Se borra tras usarlo.

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const COLUMNAS: int = 10
const TAM_RENDER := Vector2i(1150, 1040)

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

const PX_POR_METRO: float = 44.0 / 1.70
const FACTOR_PRESENCIA: float = 1.25
const ROTACIONES: Array[int] = [0, 90, 180, 270]

const COLOR_PANEL_ZOOM := Color(0.55, 0.57, 0.60)
const COLOR_BORDE_PANEL := Color(0.85, 0.87, 0.90)


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

	var titulo := Label.new()
	titulo.text = "Lámparas KayKit -- por banda: escala real en celda (arriba) + ZOOM sobre panel claro (abajo)"
	titulo.add_theme_font_size_override("font_size", 15)
	titulo.add_theme_color_override("font_color", Color.WHITE)
	titulo.position = Vector2(16.0, 8.0)
	mundo.add_child(titulo)

	var objetivo_pie: float = 1.70 * PX_POR_METRO * FACTOR_PRESENCIA
	_banda_lampara(
		mundo, 130.0, "kaykit_lamp_standing",
		"DE PIE -- 1,70m -> %.1fpx (huella 1 celda, zoom ×3)" % objetivo_pie,
		objetivo_pie, true, 3.0, Vector2(120.0, 210.0)
	)

	var objetivo_mesa: float = 0.45 * PX_POR_METRO * FACTOR_PRESENCIA
	_banda_lampara(
		mundo, 620.0, "kaykit_lamp_table",
		"DE MESA -- 0,45m -> %.1fpx (SIN huella propia, zoom ×6)" % objetivo_mesa,
		objetivo_mesa, false, 6.0, Vector2(140.0, 150.0)
	)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta: String = CARPETA_SCRATCH + "hoja_lamparas.png"
	var err: Error = imagen.save_png(ruta)
	if err != OK:
		push_error("[HOJA LAMPARAS] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[HOJA LAMPARAS] %dx%d px -> %s" % [imagen.get_width(), imagen.get_height(), ruta])
	print("[HOJA LAMPARAS] hecho.")
	get_tree().quit()


## Una BANDA completa (rejilla local de 1 fila + zoom), con `y_arriba` el borde superior de SU
## PROPIA rejilla local -- independiente de cualquier otra banda, así que no hay forma de que se
## pisen: solo hay que dejar `y_arriba` con suficiente separación (460px, ver las llamadas).
func _banda_lampara(
	mundo: Node2D, y_arriba: float, id: String, etiqueta_banda: String,
	objetivo_px: float, marcar_huella: bool, factor_zoom: float, tam_panel: Vector2
) -> void:
	# Solo se usa la X de `origen_centrado` (centra la fila en el ancho del lienzo); la Y se fija
	# a mano con `y_arriba` -- pasar un alto de área de verdad aquí y luego SUMARLE `y_arriba`
	# (como hacía la v2, ya retirada) descolocaba la banda: `origen_centrado` ya resta la mitad del
	# alto del tablero para centrar, así que sumar encima duplicaba el ajuste.
	var origen_calc: Vector2 = ProyeccionScript.origen_centrado(COLUMNAS, 1, Vector2(float(TAM_RENDER.x), 1000.0))
	var origen_banda := Vector2(origen_calc.x, y_arriba)

	var etiqueta := Label.new()
	etiqueta.text = etiqueta_banda
	etiqueta.add_theme_font_size_override("font_size", 13)
	etiqueta.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	etiqueta.position = Vector2(16.0, y_arriba - 70.0)
	mundo.add_child(etiqueta)

	_dibujar_rejilla_banda(mundo, origen_banda)

	var celda_muneco := Vector2i(0, 0)
	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = origen_banda + ProyeccionScript.centro_iso(celda_muneco)
	mundo.add_child(muneco)
	_etiqueta(mundo, "muñeco\n(1,70 m)", celda_muneco, origen_banda, Color(1.0, 1.0, 0.2))

	# El panel de zoom tiene que caer POR DEBAJO de toda la fila real-escala (rejilla + etiqueta
	# baja de verificación, ~60px de alto) más un margen -- si no, el panel (opaco, se dibuja
	# encima) tapa la fila real-escala en vez de quedar debajo (bug visto y corregido: la primera
	# versión con bandas ponía el panel casi pegado a la fila y la tapaba entera).
	var fila_abajo: float = origen_banda.y + ProyeccionScript.esquina_iso(0, 1).y + 60.0
	var y_zoom: float = fila_abajo + 40.0 + tam_panel.y * 0.5

	for i: int in ROTACIONES.size():
		var rot: int = ROTACIONES[i]
		var celda := Vector2i(2 + i * 2, 0)
		if marcar_huella:
			_marcar_huella(mundo, celda, origen_banda)
		var ruta_png: String = "%s%s_%d.png" % [CARPETA_SCRATCH, id, rot]
		var alto_medido: int = _colocar_pieza(mundo, ruta_png, celda, origen_banda)
		var dif: float = absf(float(alto_medido) - objetivo_px)
		var veredicto: String = "PASA" if dif <= 3.0 else "FALLA"
		var color_veredicto: Color = Color(0.4, 1.0, 0.4) if veredicto == "PASA" else Color(1.0, 0.35, 0.35)
		_etiqueta(mundo, "rot %d°" % rot, celda, origen_banda, Color(1.0, 1.0, 0.2))
		_etiqueta_baja(
			mundo, "%dpx / %.0fpx\n%s" % [alto_medido, objetivo_px, veredicto], celda, origen_banda, color_veredicto
		)

		var centro_x: float = origen_banda.x + ProyeccionScript.centro_iso(celda).x
		_zoom_pieza(mundo, ruta_png, Vector2(centro_x, y_zoom), factor_zoom, tam_panel, rot)


func _dibujar_rejilla_banda(mundo: Node2D, origen: Vector2) -> void:
	for x: int in range(COLUMNAS):
		var borde := Line2D.new()
		borde.width = 1.0
		borde.default_color = Color(0.45, 0.48, 0.52, 0.65)
		borde.closed = true
		borde.points = PackedVector2Array([
			origen + ProyeccionScript.esquina_iso(x, 0),
			origen + ProyeccionScript.esquina_iso(x + 1, 0),
			origen + ProyeccionScript.esquina_iso(x + 1, 1),
			origen + ProyeccionScript.esquina_iso(x, 1),
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


func _zoom_pieza(
	mundo: Node2D, ruta_absoluta: String, centro_panel: Vector2, factor: float, tam_panel: Vector2, rot: int
) -> void:
	var mitad: Vector2 = tam_panel * 0.5
	var panel := Polygon2D.new()
	panel.color = COLOR_PANEL_ZOOM
	panel.polygon = PackedVector2Array([
		centro_panel + Vector2(-mitad.x, -mitad.y), centro_panel + Vector2(mitad.x, -mitad.y),
		centro_panel + Vector2(mitad.x, mitad.y), centro_panel + Vector2(-mitad.x, mitad.y),
	])
	mundo.add_child(panel)
	var borde := Line2D.new()
	borde.width = 2.0
	borde.default_color = COLOR_BORDE_PANEL
	borde.closed = true
	borde.points = panel.polygon
	mundo.add_child(borde)

	var img: Image = Image.load_from_file(ruta_absoluta)
	if img == null:
		push_error("[HOJA LAMPARAS] no se pudo cargar '%s'" % ruta_absoluta)
		return
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.scale = Vector2(factor, factor)
	sprite.position = centro_panel + Vector2(0.0, mitad.y - (img.get_height() * factor) * 0.5 - 22.0)
	mundo.add_child(sprite)

	var etiqueta_zoom := Label.new()
	etiqueta_zoom.text = "zoom ×%d — rot %d°" % [int(factor), rot]
	etiqueta_zoom.add_theme_font_size_override("font_size", 11)
	etiqueta_zoom.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	etiqueta_zoom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta_zoom.position = centro_panel + Vector2(-mitad.x, mitad.y - 18.0)
	etiqueta_zoom.custom_minimum_size = Vector2(tam_panel.x, 0.0)
	mundo.add_child(etiqueta_zoom)


func _colocar_pieza(mundo: Node2D, ruta_absoluta: String, celda: Vector2i, origen: Vector2) -> int:
	var img: Image = Image.load_from_file(ruta_absoluta)
	if img == null:
		push_error("[HOJA LAMPARAS] no se pudo cargar '%s'" % ruta_absoluta)
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
