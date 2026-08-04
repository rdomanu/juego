extends Node
## MONTA LA HOJA DE CONTACTOS de candidatos a ciudadano, a partir de los PNG que deja
## `tools/_render_hoja_ciudadanos.gd` en el scratchpad de la sesión. Hoja de PROPUESTA para que el
## usuario elija -- no escribe nada en `assets/`.
##
## Compone en un `SubViewport` 2D (mismo truco que el renderizador 3D: tamaño fijo, se captura su
## textura, no depende de la ventana del SO): fondo neutro, rejilla tenue, los 8 personajes de pie a
## 88px en una fila (el policía PRIMERO, etiquetado "POLI (referencia)"), etiquetas 1-7 con el nombre de
## cada civil, y debajo la misma fila a 44px (el tamaño real del juego, ver `Muneco` / `girl_44px_*`).
##
## ── CÓMO SE USA ────────────────────────────────────────────────────────────────────────────────────
##   godot --path <proyecto> res://tools/_hoja_ciudadanos.tscn
## (requiere que `_render_hoja_ciudadanos.gd` ya haya corrido y dejado los PNG en `ORIGEN`.)

## Dónde `_render_hoja_ciudadanos.gd` dejó los PNG (`{prefijo}_{alto}px_sur.png`) -- ruta absoluta de
## sistema de archivos, fuera de `res://` a propósito (scratchpad de sesión, no assets del juego).
const ORIGEN := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"
const SALIDA_PNG := ORIGEN + "hoja_ciudadanos_candidatos.png"

## Un sujeto por columna, en el orden en que se dibujan. El policía va primero como referencia de
## estilo; el resto son los 7 candidatos a ciudadano, numerados 1-7 (mismo orden que le mostró el
## `README`/informe al usuario).
const SUJETOS: Array[Dictionary] = [
	{"prefijo": "male_officer", "etiqueta": "POLI (referencia)"},
	{"prefijo": "generic_male", "etiqueta": "1  generic_male"},
	{"prefijo": "generic_female", "etiqueta": "2  generic_female"},
	{"prefijo": "citizen1", "etiqueta": "3  citizen1"},
	{"prefijo": "citizen2", "etiqueta": "4  citizen2"},
	{"prefijo": "citizen3", "etiqueta": "5  citizen3"},
	{"prefijo": "retail_worker", "etiqueta": "6  retail_worker"},
	{"prefijo": "crypto_bro", "etiqueta": "7  crypto_bro"},
]

const ANCHO_COL: int = 130
const MARGEN_IZQ: int = 20
const ANCHO_LIENZO: int = MARGEN_IZQ * 2 + ANCHO_COL * 8
const ALTO_LIENZO: int = 300

## Línea de base (Y) donde se apoyan los PIES de cada fila -- las imágenes se colocan con su borde
## inferior tocando esta línea, así los personajes de distinta anchura quedan "de pie" en el mismo
## suelo en vez de centrados por su caja (que variaría con la pose/props de cada modelo).
const BASE_FILA_88: int = 168
const BASE_FILA_44: int = 268

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
	titulo.text = "Candidatos a ciudadano -- comparados con el POLI actual (referencia de escala)"
	titulo.position = Vector2(MARGEN_IZQ, 4)
	titulo.add_theme_font_size_override("font_size", 14)
	titulo.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	_sub.add_child(titulo)

	var subtitulo88 := Label.new()
	subtitulo88.text = "De pie -- 88px"
	subtitulo88.position = Vector2(MARGEN_IZQ, 30)
	subtitulo88.add_theme_font_size_override("font_size", 11)
	subtitulo88.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	_sub.add_child(subtitulo88)

	var subtitulo44 := Label.new()
	subtitulo44.text = "Tamano real en el juego -- 44px"
	subtitulo44.position = Vector2(MARGEN_IZQ, 218)
	subtitulo44.add_theme_font_size_override("font_size", 11)
	subtitulo44.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	_sub.add_child(subtitulo44)

	var faltantes: Array[String] = []
	for i: int in SUJETOS.size():
		var sujeto: Dictionary = SUJETOS[i]
		var prefijo: String = sujeto["prefijo"]
		var etiqueta: String = sujeto["etiqueta"]
		var x_col: int = MARGEN_IZQ + i * ANCHO_COL

		var nombre_lbl := Label.new()
		nombre_lbl.text = etiqueta
		nombre_lbl.position = Vector2(x_col, 46)
		nombre_lbl.custom_minimum_size = Vector2(ANCHO_COL, 16)
		nombre_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nombre_lbl.add_theme_font_size_override("font_size", 12)
		var color_etiqueta: Color = Color(0.1, 0.3, 0.55) if i == 0 else Color(0.1, 0.1, 0.1)
		nombre_lbl.add_theme_color_override("font_color", color_etiqueta)
		_sub.add_child(nombre_lbl)

		var ok88: bool = _colocar_imagen("%s%s_88px_sur.png" % [ORIGEN, prefijo], x_col, ANCHO_COL, BASE_FILA_88)
		var ok44: bool = _colocar_imagen("%s%s_44px_sur.png" % [ORIGEN, prefijo], x_col, ANCHO_COL, BASE_FILA_44)
		if not ok88 or not ok44:
			faltantes.append(prefijo)

	if not faltantes.is_empty():
		push_warning("HojaCiudadanos: faltan PNG de: %s (¿corrió _render_hoja_ciudadanos.tscn antes?)" % [faltantes])

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = _sub.get_texture().get_image()
	var err: Error = imagen.save_png(SALIDA_PNG)
	if err != OK:
		push_error("HojaCiudadanos: no se pudo guardar %s -> error %d" % [SALIDA_PNG, err])
	else:
		print("[HOJA] guardada en %s" % SALIDA_PNG)
	get_tree().quit()


## Carga un PNG del scratchpad y lo coloca en un `TextureRect` centrado horizontalmente en su columna,
## con el borde INFERIOR apoyado en `base_y` (para que todas las figuras queden "de pie en el mismo
## suelo" pese a tener anchuras/proporciones distintas). Devuelve `false` si el archivo no existe o no
## se pudo cargar -- no interrumpe el resto de la hoja (se anota en `faltantes`).
func _colocar_imagen(ruta: String, x_col: int, ancho_col: int, base_y: int) -> bool:
	if not FileAccess.file_exists(ruta):
		push_warning("HojaCiudadanos: no existe %s" % ruta)
		return false
	var img := Image.new()
	var err: Error = img.load(ruta)
	if err != OK:
		push_warning("HojaCiudadanos: no se pudo cargar %s -> error %d" % [ruta, err])
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


## `Control` mínimo que dibuja una rejilla tenue -- no hay nodo de "rejilla" hecho en Godot, así que se
## dibuja a mano con `_draw`. Interno de este script: no necesita `class_name` propio.
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
