extends Node2D
## _hoja_mesa_trabajo_kaykit — DESECHABLE (2026-08-06). REESCRITO: `table_medium` RECHAZADA por el
## usuario ("es una mesa de revistas/centro" -- cierto, ver `design/art/plan-escalado.md` no
## tocado, huella y altura de mesa auxiliar). Sus vistas NO se borran (quedan de mesita de sala de
## espera, sin usar aquí). Candidatas nuevas: `kitchentable_A` / `kitchentable_B`
## (`capturas/fuentes/kaykit_restaurant/`, altura real de comedor).
##
##  1) Muñeco REAL del juego -- MISMO mecanismo que `tools/_hoja_impresora_dni.gd`
##     (`MunecoScript.construir_sprite("civil_h1", 44)`).
##  2) HUELLA: los dos `.gltf` miden su base en X∈[-1,1] / Z∈[-1,1] -- CUADRADA, igual que
##     `table_medium` -- confirmado por el ancho del render recortado (31px de 80px de rombo de
##     1 celda, muy por debajo del ancho de celda): decisión = 1×1 celda para AMBAS, no 2×1.
##
## Escribe SOLO `hoja_mesa_trabajo_AB.png` al scratchpad. Se borra tras usarlo.

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const COLUMNAS: int = 11
const FILAS: int = 6
const TAM_RENDER := Vector2i(1150, 720)

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

const PX_POR_METRO: float = 44.0 / 1.70
const FACTOR_PRESENCIA: float = 1.25
const ALTURA_OBJETIVO_M: float = 0.75
const OBJETIVO_PX: float = ALTURA_OBJETIVO_M * PX_POR_METRO * FACTOR_PRESENCIA  # ~24,3 px
const ROTACIONES: Array[int] = [0, 90, 180, 270]

const CELDA_MUNECO_A := Vector2i(0, 1)
const CELDA_MUNECO_B := Vector2i(0, 4)


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
	titulo.text = "Mesa de trabajo KayKit -- kitchentable_A vs kitchentable_B (table_medium RECHAZADA: es mesa de centro) -- objetivo 0,75m -> %.1fpx -- huella 1×1 celda" % OBJETIVO_PX
	titulo.add_theme_font_size_override("font_size", 14)
	titulo.add_theme_color_override("font_color", Color.WHITE)
	titulo.position = Vector2(16.0, 8.0)
	mundo.add_child(titulo)

	_fila_variante(mundo, origen, "kaykit_kitchentable_A", "A) kitchentable_A", 1, CELDA_MUNECO_A)
	_fila_variante(mundo, origen, "kaykit_kitchentable_B", "B) kitchentable_B", 4, CELDA_MUNECO_B)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta: String = CARPETA_SCRATCH + "hoja_mesa_trabajo_AB.png"
	var err: Error = imagen.save_png(ruta)
	if err != OK:
		push_error("[HOJA MESA AB] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[HOJA MESA AB] %dx%d px -> %s" % [imagen.get_width(), imagen.get_height(), ruta])
	print("[HOJA MESA AB] hecho.")
	get_tree().quit()


func _fila_variante(
	mundo: Node2D, origen: Vector2, id: String, etiqueta_fila: String, fila_y: int, celda_muneco: Vector2i
) -> void:
	var etiqueta := Label.new()
	etiqueta.text = etiqueta_fila
	etiqueta.add_theme_font_size_override("font_size", 14)
	etiqueta.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	etiqueta.position = origen + ProyeccionScript.esquina_iso(0, fila_y) + Vector2(-4.0, -14.0)
	mundo.add_child(etiqueta)

	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = origen + ProyeccionScript.centro_iso(celda_muneco)
	mundo.add_child(muneco)
	_etiqueta(mundo, "muñeco\n(1,70 m)", celda_muneco, origen, Color(1.0, 1.0, 0.2))

	for i: int in ROTACIONES.size():
		var rot: int = ROTACIONES[i]
		var celda := Vector2i(2 + i * 2, fila_y)
		_marcar_huella(mundo, celda, origen)
		var alto_medido: int = _colocar_pieza(mundo, "%s%s_%d.png" % [CARPETA_SCRATCH, id, rot], celda, origen)
		var dif: float = absf(float(alto_medido) - OBJETIVO_PX)
		var veredicto: String = "PASA" if dif <= 3.0 else "FALLA"
		var color_veredicto: Color = Color(0.4, 1.0, 0.4) if veredicto == "PASA" else Color(1.0, 0.35, 0.35)
		_etiqueta(mundo, "rot %d°" % rot, celda, origen, Color(1.0, 1.0, 0.2))
		_etiqueta_baja(
			mundo, "%dpx / %.0fpx\n%s" % [alto_medido, OBJETIVO_PX, veredicto], celda, origen, color_veredicto
		)


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
		push_error("[HOJA MESA AB] no se pudo cargar '%s'" % ruta_absoluta)
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
