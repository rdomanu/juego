extends Node2D
## _hoja_impresora_dni — DESECHABLE, hoja de presentación (2026-08-06).
##
## Compone `impresora_dni_{0,90,180,270}.png` (`tools/_render_impresora_dni.gd`, scratchpad) sobre
## la rejilla isométrica real del juego, CADA vista con su huella 2×1 marcada y su propio muñeco de
## 44 px al lado — mismo patrón que `_hoja_impresora_doc.gd`, con la huella multi-celda añadida
## (ver `AnclajeSprite.aplicar`/`Proyeccion.delta_ultima_celda`: el nodo del sprite se ancla en la
## ÚLTIMA celda del cuerpo, aquí `paso=Vector2i(1,0)` este, `celdas=2`).
##
## Escribe SOLO `hoja_impresora_dni_4pos.png` al scratchpad.

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 18
const FILAS: int = 4
const TAM_RENDER := Vector2i(1000, 480)

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

## Ancho medido/objetivo de `_render_impresora_dni.gd` (impreso ahí, repetido aquí SOLO para
## rotular la hoja — no se remide nada, es texto de presentación).
const ANCHO_MEDIDO_PX: int = 58
const ANCHO_OBJETIVO_PX: float = 58.2

## `paso`: la huella GIRA con el objeto (aviso del usuario 2026-08-06: "la ocupación de las celdas
## también tiene que girar"). 0°/180° -- el render no cambia de eje, sigue ANCHO en ESTE/OESTE, 2×1
## -- `paso=Vector2i(1,0)`. 90°/270° -- el render gira 90°, la huella TRASPUESTA, 1×2 en NORTE/SUR
## -- `paso=Vector2i(0,1)`.
const PIEZAS: Array[Dictionary] = [
	{"archivo": "impresora_dni_0", "rot": "0°", "paso": Vector2i(1, 0)},
	{"archivo": "impresora_dni_90", "rot": "90°", "paso": Vector2i(0, 1)},
	{"archivo": "impresora_dni_180", "rot": "180°", "paso": Vector2i(1, 0)},
	{"archivo": "impresora_dni_270", "rot": "270°", "paso": Vector2i(0, 1)},
]

## Huella de 2 celdas -- la DIRECCIÓN (`paso`, por pieza, ver arriba) es lo que gira; el número de
## celdas no cambia. La celda ÚLTIMA (destino de `paso` desde la celda ancla, ver la cabecera y
## `Proyeccion.delta_ultima_celda`) es donde se cuelga el nodo del sprite.
const CELDAS_FOOTPRINT: int = 2


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
	titulo.text = "impresora_dni — 4 rotaciones · ancho cuerpo medido=%dpx objetivo=%.1fpx (±3px) -> PASA" % [
		ANCHO_MEDIDO_PX, ANCHO_OBJETIVO_PX
	]
	titulo.add_theme_font_size_override("font_size", 14)
	titulo.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	titulo.position = Vector2(8.0, 4.0)
	mundo.add_child(titulo)

	# UNA sola fila (mismo criterio que `_hoja_props_v3.gd`: escalonar en filas distintas hace que
	# la diagonal isométrica solape sprites de piezas vecinas; en fila única solo hace falta separar
	# en columnas). `PASO_COLUMNAS` = 4 por pieza: 2 para la huella + 2 de aire, de sobra para un
	# sprite de ~60-80 px con columnas de 80 px de ancho de rombo cada una.
	const PASO_COLUMNAS := 4
	var fila := 1
	for i: int in PIEZAS.size():
		var pieza: Dictionary = PIEZAS[i]
		var paso: Vector2i = pieza["paso"]
		var base_col: int = 4 + i * PASO_COLUMNAS
		# La celda ÚLTIMA (destino de `paso`) es donde se cuelga el sprite. Para `paso` este
		# (0°/180°) es la propia fila `fila`; para `paso` sur (90°/270°, huella traspuesta) la
		# huella crece una fila hacia abajo, así que la ÚLTIMA cae en `fila+1` -- mismo `base_col`
		# en los dos casos, para que las 4 piezas sigan alineadas en columna.
		var celda_ancla: Vector2i = Vector2i(base_col, fila) if paso == Vector2i(1, 0) else Vector2i(base_col, fila + 1)
		var celda_muneco := Vector2i(1 + i * PASO_COLUMNAS, fila)

		_marcar_huella(mundo, celda_ancla, paso, origen)

		var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
		muneco.position = origen + ProyeccionScript.centro_iso(celda_muneco)
		mundo.add_child(muneco)

		_colocar_pieza(mundo, "%s%s.png" % [CARPETA_SCRATCH, pieza["archivo"]], celda_ancla, paso, origen)
		_etiqueta(mundo, pieza["rot"], celda_muneco, origen)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta_salida: String = CARPETA_SCRATCH + "hoja_impresora_dni_4pos.png"
	var err: Error = imagen.save_png(ruta_salida)
	if err != OK:
		push_error("[HOJA DNI] save_png '%s' falló (error %d)" % [ruta_salida, err])
	else:
		print("[HOJA DNI] %dx%d px -> %s" % [imagen.get_width(), imagen.get_height(), ruta_salida])
	print("[HOJA DNI] hecho.")
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


## Rellena las 2 celdas de la huella (la de ATRÁS = ancla-paso, la ÚLTIMA = ancla) con un color de
## aviso -- `paso` es lo que GIRA con el objeto (este/oeste a 0°/180°, norte/sur a 90°/270°, ver la
## cabecera de `PIEZAS`), para que se vea de un vistazo dónde debe caer el cuerpo de 2 celdas YA
## orientado como el sprite.
func _marcar_huella(mundo: Node2D, celda_ancla: Vector2i, paso: Vector2i, origen: Vector2) -> void:
	var celda_atras: Vector2i = celda_ancla - paso * (CELDAS_FOOTPRINT - 1)
	for celda: Vector2i in [celda_atras, celda_ancla]:
		var relleno := Polygon2D.new()
		relleno.color = Color(0.95, 0.75, 0.15, 0.22)
		relleno.polygon = PackedVector2Array([
			origen + ProyeccionScript.esquina_iso(celda.x, celda.y),
			origen + ProyeccionScript.esquina_iso(celda.x + 1, celda.y),
			origen + ProyeccionScript.esquina_iso(celda.x + 1, celda.y + 1),
			origen + ProyeccionScript.esquina_iso(celda.x, celda.y + 1),
		])
		mundo.add_child(relleno)


func _colocar_pieza(mundo: Node2D, ruta_absoluta: String, celda_ancla: Vector2i, paso: Vector2i, origen: Vector2) -> void:
	var img: Image = Image.load_from_file(ruta_absoluta)
	if img == null:
		push_error("[HOJA DNI] no se pudo cargar '%s'" % ruta_absoluta)
		var aviso := Label.new()
		aviso.text = "⚠ sin PNG"
		aviso.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		aviso.position = origen + ProyeccionScript.centro_iso(celda_ancla) + Vector2(-20.0, -10.0)
		mundo.add_child(aviso)
		return
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	AnclajeSpriteScript.aplicar(sprite, paso, CELDAS_FOOTPRINT)
	var raiz := Node2D.new()
	raiz.position = origen + ProyeccionScript.centro_iso(celda_ancla)
	raiz.add_child(sprite)
	mundo.add_child(raiz)


func _etiqueta(mundo: Node2D, texto: String, celda: Vector2i, origen: Vector2) -> void:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = origen + ProyeccionScript.esquina_iso(celda.x, celda.y) + Vector2(-30.0, -55.0)
	label.custom_minimum_size = Vector2(80.0, 0.0)
	mundo.add_child(label)
