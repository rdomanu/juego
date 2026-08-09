extends Node2D
## _hoja_mesas_ventanilla — DESECHABLE, hoja de presentación (2026-08-06).
##
## Compone las mesas de ventanilla renderizadas (`mesa_pro_*` del scratchpad; `mesa_media`/
## `mesa_basica` SIN RENDER -- los 3 GLB de origen resultaron ser una única MeshInstance3D fusionada,
## sin nodos separables, ver informe) sobre la rejilla isométrica real del juego. Por mesa: BLOQUE
## 2×3 -- fila ciudadano (silla_espera actual del juego) + fila mesa (huella 2×1) + fila policía
## (silla_funcionario actual del juego) -- con un muñeco real de 44px al lado para escala.
##
## Escribe SOLO `hoja_mesas_ventanilla.png` al scratchpad.

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 15
const FILAS: int = 5
const TAM_RENDER := Vector2i(900, 560)

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"
const CARPETA_MOBILIARIO := "res://assets/sprites/mobiliario/"

## Ancho medido/objetivo (impreso en `_render_mesa_ventanilla_lote.gd`): mesa_pro calibrada por
## ANCHO (huella 2×1 -> 58px), NO por alto -- el alto que sale (~53px) es muy superior a la
## referencia de altura real (0,75m*presencia = 24px): la huella (ancha y poco profunda) domina la
## silueta isométrica. Se informa aquí SIN maquillar -- el veredicto de "alto" es informativo, no
## vinculante (el objetivo funcional es el ANCHO, que sí encaja).
const ANCHO_MEDIDO_PX: int = 58
const ANCHO_OBJETIVO_PX: float = 58.0
const ALTO_MEDIDO_PX: int = 53
const ALTO_REFERENCIA_PX: float = 24.3

## Cada bloque: `id` (nombre de archivo en el scratchpad, "" si no hay render), `titulo` y, si no hay
## render, el motivo.
const MESAS: Array[Dictionary] = [
	{"id": "mesa_pro", "titulo": "mesa_pro (aprobada)", "motivo": ""},
	{"id": "mesa_basica_compuesta", "titulo": "mesa_basica_v3_vacia + CRT (compuesta)", "motivo": ""},
	{"id": "", "titulo": "mesa_media", "motivo": "SIN RENDER — GLB fusionado en 1 sola\nMeshInstance3D (1 surface), la silla\nNO es un nodo separable"},
]

## Ancho en columnas que ocupa cada bloque (2 celdas de mueble + 1 de aire + 1 de muñeco).
const PASO_COLUMNAS := 5


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
	titulo.text = "mesas de ventanilla — huella 2×1 · mesa_pro: ancho=%dpx objetivo=%.0fpx (±3px) -> PASA · mesa_basica_v3_vacia: ancho=58px objetivo=58px dif=0,0 -> PASA (CRT compuesto encima, lado sur) · alto informativo=%dpx (referencia 0,75m*presencia=%.0fpx, la huella manda el ancho)" % [
		ANCHO_MEDIDO_PX, ANCHO_OBJETIVO_PX, ALTO_MEDIDO_PX, ALTO_REFERENCIA_PX
	]
	titulo.add_theme_font_size_override("font_size", 12)
	titulo.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	titulo.position = Vector2(8.0, 4.0)
	titulo.custom_minimum_size = Vector2(880.0, 0.0)
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD
	mundo.add_child(titulo)

	for i: int in MESAS.size():
		var mesa: Dictionary = MESAS[i]
		var base_col: int = 1 + i * PASO_COLUMNAS
		_dibujar_bloque(mundo, origen, base_col, mesa)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta_salida: String = CARPETA_SCRATCH + "hoja_mesas_ventanilla.png"
	var err: Error = imagen.save_png(ruta_salida)
	if err != OK:
		push_error("[HOJA MESAS] save_png '%s' falló (error %d)" % [ruta_salida, err])
	else:
		print("[HOJA MESAS] %dx%d px -> %s" % [imagen.get_width(), imagen.get_height(), ruta_salida])
	print("[HOJA MESAS] hecho.")
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


func _marcar_celda(mundo: Node2D, celda: Vector2i, origen: Vector2, color: Color) -> void:
	var relleno := Polygon2D.new()
	relleno.color = color
	relleno.polygon = PackedVector2Array([
		origen + ProyeccionScript.esquina_iso(celda.x, celda.y),
		origen + ProyeccionScript.esquina_iso(celda.x + 1, celda.y),
		origen + ProyeccionScript.esquina_iso(celda.x + 1, celda.y + 1),
		origen + ProyeccionScript.esquina_iso(celda.x, celda.y + 1),
	])
	mundo.add_child(relleno)


## Bloque 2×3: fila 0 = ciudadano (silla_espera), fila 1 = mesa (huella 2×1, este), fila 2 =
## policía (silla_funcionario). `base_col` es la columna 0 del bloque (2 celdas: base_col, base_col+1).
func _dibujar_bloque(mundo: Node2D, origen: Vector2, base_col: int, mesa: Dictionary) -> void:
	var col0 := base_col
	var col1 := base_col + 1

	# Título del bloque.
	var titulo := Label.new()
	titulo.text = mesa["titulo"]
	titulo.add_theme_font_size_override("font_size", 14)
	titulo.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	titulo.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	titulo.add_theme_constant_override("outline_size", 4)
	titulo.position = origen + ProyeccionScript.esquina_iso(col0, 0) + Vector2(-10.0, -18.0)
	mundo.add_child(titulo)

	var id_archivo: String = mesa["id"]
	if id_archivo == "":
		var aviso := Label.new()
		aviso.text = mesa["motivo"]
		aviso.add_theme_font_size_override("font_size", 11)
		aviso.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		aviso.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
		aviso.add_theme_constant_override("outline_size", 3)
		aviso.position = origen + ProyeccionScript.esquina_iso(col0, 1) + Vector2(0.0, 10.0)
		mundo.add_child(aviso)
		return

	# Marca las 3 filas del bloque (2 celdas cada una).
	for fila: int in [0, 1, 2]:
		_marcar_celda(mundo, Vector2i(col0, fila), origen, Color(0.3, 0.5, 0.9, 0.12))
		_marcar_celda(mundo, Vector2i(col1, fila), origen, Color(0.3, 0.5, 0.9, 0.12))
	# Resalta la huella real de la mesa (fila 1) en amarillo, como en la hoja de la impresora.
	_marcar_celda(mundo, Vector2i(col0, 1), origen, Color(0.95, 0.75, 0.15, 0.22))
	_marcar_celda(mundo, Vector2i(col1, 1), origen, Color(0.95, 0.75, 0.15, 0.22))

	# Silla del ciudadano (DELANTE, lado norte de la mesa, fila 0) -- mira hacia la mesa (sur) ->
	# `silla_oficina_180.png` (4 vistas reales, scratchpad -- corrección del usuario 2026-08-06:
	# la silla_espera vieja solo tenía 1 vista y salía girada). Centrada visualmente entre col0/col1.
	var centro_silla_ciudadano: Vector2 = origen + (
		ProyeccionScript.centro_iso(Vector2i(col0, 0)) + ProyeccionScript.centro_iso(Vector2i(col1, 0))
	) * 0.5
	_colocar_pieza_scratch(mundo, CARPETA_SCRATCH + "silla_oficina_180.png", centro_silla_ciudadano)

	# Mesa (huella 2×1, este) anclada en la ÚLTIMA celda (col1, fila 1).
	var celda_ancla_mesa := Vector2i(col1, 1)
	var raiz_mesa := Node2D.new()
	raiz_mesa.position = origen + ProyeccionScript.centro_iso(celda_ancla_mesa)
	var sprite_mesa := Sprite2D.new()
	sprite_mesa.texture = _cargar_textura_absoluta(CARPETA_SCRATCH + id_archivo + "_0.png")
	if sprite_mesa.texture != null:
		AnclajeSpriteScript.aplicar(sprite_mesa, Vector2i(1, 0), 2)
	raiz_mesa.add_child(sprite_mesa)
	mundo.add_child(raiz_mesa)

	# Silla del policía (DETRÁS, lado sur de la mesa, fila 2) -- mira hacia la mesa (norte) ->
	# opuesta a 180° = `silla_oficina_0.png` (mismo razonamiento: 4 vistas reales, sin girar mal).
	# Centrada visualmente entre col0/col1.
	var centro_silla_funcionario: Vector2 = origen + (
		ProyeccionScript.centro_iso(Vector2i(col0, 2)) + ProyeccionScript.centro_iso(Vector2i(col1, 2))
	) * 0.5
	_colocar_pieza_scratch(mundo, CARPETA_SCRATCH + "silla_oficina_0.png", centro_silla_funcionario)

	# Muñeco real 44px al lado del bloque, columna siguiente, fila 1 (a la altura de la mesa).
	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = origen + ProyeccionScript.centro_iso(Vector2i(col1 + 1, 1))
	mundo.add_child(muneco)


func _cargar_textura_absoluta(ruta: String) -> Texture2D:
	var img: Image = Image.load_from_file(ruta)
	if img == null:
		push_warning("[HOJA MESAS] no se pudo cargar '%s'" % ruta)
		return null
	return ImageTexture.create_from_image(img)


## Coloca un sprite de mobiliario de 1 celda CENTRADO en un punto de pantalla dado (no en una celda
## concreta -- para las sillas "centradas" visualmente entre las 2 columnas del bloque).
func _colocar_pieza_mobiliario(mundo: Node2D, ruta_res: String, centro_pantalla: Vector2) -> void:
	var tex: Texture2D = load(ruta_res)
	if tex == null:
		push_warning("[HOJA MESAS] no se pudo cargar '%s'" % ruta_res)
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	AnclajeSpriteScript.aplicar(sprite, Vector2i(0, 1), 1)
	var raiz := Node2D.new()
	raiz.position = centro_pantalla
	raiz.add_child(sprite)
	mundo.add_child(raiz)


## Igual que `_colocar_pieza_mobiliario`, pero para un PNG del scratchpad (ruta absoluta de disco,
## no `res://`) -- las 4 vistas reales de `silla_oficina` viven ahí, no en `assets/sprites/mobiliario/`.
func _colocar_pieza_scratch(mundo: Node2D, ruta_absoluta: String, centro_pantalla: Vector2) -> void:
	var tex: Texture2D = _cargar_textura_absoluta(ruta_absoluta)
	if tex == null:
		push_warning("[HOJA MESAS] no se pudo cargar '%s'" % ruta_absoluta)
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	AnclajeSpriteScript.aplicar(sprite, Vector2i(0, 1), 1)
	var raiz := Node2D.new()
	raiz.position = centro_pantalla
	raiz.add_child(sprite)
	mundo.add_child(raiz)
