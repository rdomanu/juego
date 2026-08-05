extends Node2D
## HOJA DE PROPUESTA DESECHABLE (2026-08-05) — regla del proyecto: todo objeto nuevo se enseña en
## imagen CON CELDAS antes de su OK. Muestra, sobre la rejilla isométrica real (`Proyeccion`) y
## anclado con `AnclajeSprite` (auto-anclaje: nada de fracciones a mano), los 7 modelos nuevos de
## `capturas/fuentes/props_poly/` (renderizados por `tools/_render_props_nuevos.gd` al scratchpad),
## uno por celda, cada uno con su etiqueta de "a qué comodidad caja-gris sustituye", junto a un
## muñeco de pie (44 px) de referencia de escala.
##
## Los PNG NO son recursos importados (viven en el scratchpad, fuera de `res://`): se cargan con
## `Image.load_from_file()` + `ImageTexture.create_from_image()`, no con `load()`.
##
## v2 (2026-08-05): calibración por ALTURA REAL (ya no por huella forzada — ver `_render_props_
## nuevos.gd`) + una celda VACÍA entre cada pieza para que no se solapen sus siluetas.
##
## Escribe SOLO `hoja_props_nuevos_v2.png` al scratchpad. Se borra tras usarlo.

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
## v2 (petición del usuario): una celda VACÍA entre cada pieza -- las 4 rotaciones ya demostraron
## que sin margen las siluetas se solapaban. 7 piezas + muñeco, paso de 2 columnas cada una.
const COLUMNAS: int = 18
const FILAS: int = 4
const TAM_RENDER := Vector2i(1500, 480)

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/e2e2376e-13c2-4add-ad50-5abb00a96123/scratchpad/"

## id de archivo -> etiqueta "nombre / comodidad gris que sustituye" (ver el encargo del usuario).
const PIEZAS: Array[Dictionary] = [
	{"id": "cafetera", "etiqueta": "cafetera\n-> maquina_cafe"},
	{"id": "vending", "etiqueta": "vending\n-> vending"},
	{"id": "impresora", "etiqueta": "impresora\n-> impresora (oficina)"},
	{"id": "television", "etiqueta": "television\n-> television"},
	{"id": "fuente_agua", "etiqueta": "fuente_agua\n-> fuente_agua"},
	{"id": "taquilla", "etiqueta": "taquilla\n-> [nueva]"},
	{"id": "archivador", "etiqueta": "archivador\n-> [nueva]"},
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

	# Muñeco de pie, referencia de escala (1,70 m ~ 44 px).
	var muneco: Node2D = MunecoScript.construir_sprite("girl", 44)
	muneco.position = origen + ProyeccionScript.centro_iso(CELDA_MUNECO)
	mundo.add_child(muneco)
	_etiqueta(mundo, "muñeco\n(1,70 m)", CELDA_MUNECO, origen)

	for i: int in PIEZAS.size():
		var pieza: Dictionary = PIEZAS[i]
		# paso de 2 columnas: deja una celda vacía entre cada pieza (y entre el muñeco y la 1ª).
		var celda := Vector2i(3 + i * 2, 1)
		var ruta: String = "%s%s_0.png" % [CARPETA_SCRATCH, pieza["id"]]
		_colocar_pieza_externa(mundo, ruta, celda, origen)
		_etiqueta(mundo, pieza["etiqueta"], celda, origen)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta_salida: String = CARPETA_SCRATCH + "hoja_props_nuevos_v2.png"
	var err: Error = imagen.save_png(ruta_salida)
	if err != OK:
		push_error("[HOJA PROPS NUEVOS] save_png '%s' fallo (error %d)" % [ruta_salida, err])
	else:
		print("[HOJA PROPS NUEVOS] %dx%d px -> %s" % [imagen.get_width(), imagen.get_height(), ruta_salida])
	print("[HOJA PROPS NUEVOS] hecho.")
	get_tree().quit()


## Rejilla isométrica de celdas dibujada, `COLUMNAS`×`FILAS`.
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


## Un `Sprite2D` cargado desde un PNG EXTERNO (scratchpad, no recurso importado) y anclado con
## `AnclajeSprite` en `celda` (pieza de 1 celda: `paso=ZERO`, `celdas=1`). Si el PNG no existe (un
## modelo que falló al renderizar), dibuja un aviso en su lugar en vez de romper la hoja entera.
func _colocar_pieza_externa(mundo: Node2D, ruta_absoluta: String, celda: Vector2i, origen: Vector2) -> void:
	var img: Image = Image.load_from_file(ruta_absoluta)
	if img == null:
		push_error("[HOJA PROPS NUEVOS] no se pudo cargar '%s'" % ruta_absoluta)
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


## Etiqueta pequeña (Label con contorno) sobre la esquina norte de `celda`.
func _etiqueta(mundo: Node2D, texto: String, celda: Vector2i, origen: Vector2) -> void:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = origen + ProyeccionScript.esquina_iso(celda.x, celda.y) + Vector2(-30.0, -42.0)
	label.custom_minimum_size = Vector2(80.0, 0.0)
	mundo.add_child(label)
