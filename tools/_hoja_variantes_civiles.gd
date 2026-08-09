extends Node
## MONTA LA HOJA DE VARIANTES DE COLOR de los 7 ciudadanos civiles, a partir de los PNG que deja
## `tools/_render_variantes_civiles.gd` en el scratchpad de la sesión. Hoja de PROPUESTA para que el
## usuario elija -- no escribe nada en `assets/` (mismo criterio que `_hoja_ciudadanos.gd`).
##
## Cuadrícula: 7 FILAS (una por modelo, h1/m1/h2/h3/m2/h4/h5) x 3 COLUMNAS (a=original, b=variante 1,
## c=variante 2), con etiquetas "h1-a"/"h1-b"/... bajo cada figura, y el muñeco de policía de
## referencia en la esquina superior derecha (mismo tamaño/escala, para juzgar el aspecto general).
##
## ── CÓMO SE USA ────────────────────────────────────────────────────────────────────────────────────
##   godot --path <proyecto> res://tools/_hoja_variantes_civiles.tscn
## (requiere que `_render_variantes_civiles.tscn` ya haya corrido y dejado los PNG en `ORIGEN`.)

const ORIGEN := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"
const SALIDA_PNG := ORIGEN + "hoja_variantes_civiles.png"

## Una fila por modelo, en el mismo orden que `render_sprites_civiles.gd` (prefijos `civil_*`).
const FILAS: Array[Dictionary] = [
	{"fila": "h1", "nombre": "generic_male"},
	{"fila": "m1", "nombre": "generic_female"},
	{"fila": "h2", "nombre": "citizen1"},
	{"fila": "h3", "nombre": "citizen2"},
	{"fila": "m2", "nombre": "citizen3"},
	{"fila": "h4", "nombre": "retail_worker"},
	{"fila": "h5", "nombre": "crypto_bro"},
]
const COLUMNAS: Array[String] = ["a", "b", "c"]
const NOMBRE_COLUMNA: Dictionary = {"a": "original", "b": "variante 1", "c": "variante 2"}

const ANCHO_COL: int = 150
const MARGEN_IZQ: int = 140
const ANCHO_FILA_LABEL: int = 110
const ALTO_FILA: int = 130
const MARGEN_SUP: int = 70

const ANCHO_LIENZO: int = MARGEN_IZQ + ANCHO_COL * 3 + 170
const ALTO_LIENZO: int = MARGEN_SUP + ALTO_FILA * 7 + 20

const COLOR_FONDO := Color(0.87, 0.87, 0.85)
const COLOR_REJILLA := Color(0.6, 0.6, 0.6, 0.25)
const PASO_REJILLA: int = 20

var _sub: SubViewport


func _ready() -> void:
	_sub = SubViewport.new()
	_sub.size = Vector2i(ANCHO_LIENZO, ALTO_LIENZO)
	_sub.transparent_bg = false
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)

	var fondo := ColorRect.new()
	fondo.color = COLOR_FONDO
	fondo.size = Vector2(ANCHO_LIENZO, ALTO_LIENZO)
	_sub.add_child(fondo)

	var rejilla := _NodoRejilla.new()
	rejilla.tam = Vector2(ANCHO_LIENZO, ALTO_LIENZO)
	rejilla.paso = PASO_REJILLA
	rejilla.color_linea = COLOR_REJILLA
	_sub.add_child(rejilla)

	var titulo := Label.new()
	titulo.text = "Variantes de color -- ciudadanos civiles (propuesta, sin tocar assets/)"
	titulo.position = Vector2(20, 6)
	titulo.add_theme_font_size_override("font_size", 15)
	titulo.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	_sub.add_child(titulo)

	# Cabecera de columnas.
	for c: int in COLUMNAS.size():
		var col: String = COLUMNAS[c]
		var x_col: int = MARGEN_IZQ + c * ANCHO_COL
		var cab := Label.new()
		cab.text = "%s (%s)" % [col, NOMBRE_COLUMNA[col]]
		cab.position = Vector2(x_col, MARGEN_SUP - 20)
		cab.custom_minimum_size = Vector2(ANCHO_COL, 16)
		cab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cab.add_theme_font_size_override("font_size", 11)
		cab.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
		_sub.add_child(cab)

	var faltantes: Array[String] = []
	for f: int in FILAS.size():
		var fila_info: Dictionary = FILAS[f]
		var fila: String = fila_info["fila"]
		var nombre: String = fila_info["nombre"]
		var y_base: int = MARGEN_SUP + f * ALTO_FILA
		var base_pies: int = y_base + ALTO_FILA - 24

		var etiqueta_fila := Label.new()
		etiqueta_fila.text = "%s\n%s" % [fila, nombre]
		etiqueta_fila.position = Vector2(10, y_base + ALTO_FILA * 0.5 - 16)
		etiqueta_fila.custom_minimum_size = Vector2(ANCHO_FILA_LABEL, 32)
		etiqueta_fila.add_theme_font_size_override("font_size", 12)
		etiqueta_fila.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		_sub.add_child(etiqueta_fila)

		for c: int in COLUMNAS.size():
			var col: String = COLUMNAS[c]
			var x_col: int = MARGEN_IZQ + c * ANCHO_COL
			var etiqueta: String = "%s-%s" % [fila, col]
			var ok: bool = _colocar_imagen(
				"%s%s_88px_sur.png" % [ORIGEN, etiqueta], x_col, ANCHO_COL, base_pies
			)
			if not ok:
				faltantes.append(etiqueta)
			var lbl := Label.new()
			lbl.text = etiqueta
			lbl.position = Vector2(x_col, base_pies + 6)
			lbl.custom_minimum_size = Vector2(ANCHO_COL, 14)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
			_sub.add_child(lbl)

	# Muñeco de policía de referencia, esquina superior derecha (reutiliza el PNG de la tanda anterior
	# `_render_hoja_ciudadanos.gd`, ya en el scratchpad -- mismo ángulo/escala de cámara).
	var x_poli: int = MARGEN_IZQ + ANCHO_COL * 3 + 20
	var ok_poli: bool = _colocar_imagen(
		"%smale_officer_88px_sur.png" % ORIGEN, x_poli, 140, MARGEN_SUP + 100
	)
	var lbl_poli := Label.new()
	lbl_poli.text = "POLI\n(referencia)"
	lbl_poli.position = Vector2(x_poli, MARGEN_SUP + 106)
	lbl_poli.custom_minimum_size = Vector2(140, 28)
	lbl_poli.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_poli.add_theme_font_size_override("font_size", 11)
	lbl_poli.add_theme_color_override("font_color", Color(0.1, 0.3, 0.55))
	_sub.add_child(lbl_poli)
	if not ok_poli:
		faltantes.append("male_officer (referencia)")

	if not faltantes.is_empty():
		push_warning("HojaVariantesCiviles: faltan PNG de: %s (¿corrió _render_variantes_civiles.tscn antes?)" % [faltantes])

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = _sub.get_texture().get_image()
	var err: Error = imagen.save_png(SALIDA_PNG)
	if err != OK:
		push_error("HojaVariantesCiviles: no se pudo guardar %s -> error %d" % [SALIDA_PNG, err])
	else:
		print("[HOJA] guardada en %s" % SALIDA_PNG)
	get_tree().quit()


## Carga un PNG del scratchpad y lo coloca centrado horizontalmente en su columna, con el borde
## INFERIOR apoyado en `base_y` (para que todas las figuras queden "de pie en el mismo suelo").
func _colocar_imagen(ruta: String, x_col: int, ancho_col: int, base_y: int) -> bool:
	if not FileAccess.file_exists(ruta):
		push_warning("HojaVariantesCiviles: no existe %s" % ruta)
		return false
	var img := Image.new()
	var err: Error = img.load(ruta)
	if err != OK:
		push_warning("HojaVariantesCiviles: no se pudo cargar %s -> error %d" % [ruta, err])
		return false
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	rect.size = Vector2(img.get_width(), img.get_height())
	rect.custom_minimum_size = rect.size
	var x: float = float(x_col) + (float(ancho_col) - float(img.get_width())) * 0.5
	var y: float = float(base_y) - float(img.get_height())
	rect.position = Vector2(x, y)
	_sub.add_child(rect)
	return true


## `Control` mínimo que dibuja una rejilla tenue.
class _NodoRejilla extends Control:
	var tam: Vector2 = Vector2.ZERO
	var paso: int = 20
	var color_linea: Color = Color(0.6, 0.6, 0.6, 0.25)

	func _ready() -> void:
		size = tam
		queue_redraw()

	func _draw() -> void:
		var x: float = 0.0
		while x <= tam.x:
			draw_line(Vector2(x, 0.0), Vector2(x, tam.y), color_linea, 1.0)
			x += float(paso)
		var y: float = 0.0
		while y <= tam.y:
			draw_line(Vector2(0.0, y), Vector2(tam.x, y), color_linea, 1.0)
			y += float(paso)
