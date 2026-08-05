extends Node2D
## _hoja_props_v3 — DESECHABLE, fase de PROPUESTA (2026-08-05). Corrige, sobre la hoja v2, los dos
## defectos del feedback 3c del usuario:
##  · fuente_agua reescalada a 1,60 m (`_render_fuente_v2.gd`, ganadora entre 1,50/1,60 -- ver el
##    informe) en vez de los 1,20 m descartados.
##  · cafetera/impresora/television HORNEADAS sobre su propio mueble bajo (`_render_cajonera_
##    soporte.gd` + `_componer_props_soporte.gd`, precedente `ID_RADIO`) en vez de las 3 amontonadas
##    sobre una única mesa.
## `vending`/`taquilla`/`archivador` sin cambios (el usuario no los objetó).
##
## Mismo patrón que `_hoja_props_nuevos.gd` v2 (rejilla isométrica real + `AnclajeSprite` +
## muñeco de 44 px de referencia), un paso de 2 columnas por pieza para que ninguna silueta se pise.
##
## Escribe SOLO `hoja_props_v3.png` al scratchpad. Se borra tras usarlo.

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 18
const FILAS: int = 4
const TAM_RENDER := Vector2i(1500, 480)

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/e2e2376e-13c2-4add-ad50-5abb00a96123/scratchpad/"

## Los 7 definitivos (ver la cabecera): 3 sin cambios + fuente v2 + 3 con soporte horneado.
const PIEZAS: Array[Dictionary] = [
	{"archivo": "vending_0", "etiqueta": "vending\n(sin cambios)"},
	{"archivo": "taquilla_0", "etiqueta": "taquilla\n(sin cambios)"},
	{"archivo": "archivador_0", "etiqueta": "archivador\n(sin cambios)"},
	{"archivo": "fuente_agua_v2_0", "etiqueta": "fuente_agua v2\n1,60 m (antes 1,20 m)"},
	{"archivo": "cafetera_soporte_0", "etiqueta": "cafetera\n+ soporte (cajonera)"},
	{"archivo": "impresora_soporte_0", "etiqueta": "impresora\n+ soporte (cajonera)"},
	{"archivo": "television_soporte_0", "etiqueta": "television\n+ soporte (cajonera)"},
]

const CELDA_MUNECO := Vector2i(1, 1)


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

	var muneco: Node2D = MunecoScript.construir_sprite("girl", 44)
	muneco.position = origen + ProyeccionScript.centro_iso(CELDA_MUNECO)
	mundo.add_child(muneco)
	_etiqueta(mundo, "muñeco\n(1,70 m)", CELDA_MUNECO, origen)

	for i: int in PIEZAS.size():
		var pieza: Dictionary = PIEZAS[i]
		var celda := Vector2i(3 + i * 2, 1)
		var ruta: String = "%s%s.png" % [CARPETA_SCRATCH, pieza["archivo"]]
		_colocar_pieza_externa(mundo, ruta, celda, origen)
		_etiqueta(mundo, pieza["etiqueta"], celda, origen)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta_salida: String = CARPETA_SCRATCH + "hoja_props_v3.png"
	var err: Error = imagen.save_png(ruta_salida)
	if err != OK:
		push_error("[HOJA PROPS V3] save_png '%s' fallo (error %d)" % [ruta_salida, err])
	else:
		print("[HOJA PROPS V3] %dx%d px -> %s" % [imagen.get_width(), imagen.get_height(), ruta_salida])
	print("[HOJA PROPS V3] hecho.")
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


func _colocar_pieza_externa(mundo: Node2D, ruta_absoluta: String, celda: Vector2i, origen: Vector2) -> void:
	var img: Image = Image.load_from_file(ruta_absoluta)
	if img == null:
		push_error("[HOJA PROPS V3] no se pudo cargar '%s'" % ruta_absoluta)
		var aviso := Label.new()
		aviso.text = "⚠ sin PNG"
		aviso.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		aviso.position = origen + ProyeccionScript.centro_iso(celda) + Vector2(-20.0, -10.0)
		mundo.add_child(aviso)
		return
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
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
