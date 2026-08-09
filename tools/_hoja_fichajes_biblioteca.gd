extends Node2D
## _hoja_fichajes_biblioteca — DESECHABLE (2026-08-06). Hoja de presentación de los 3 fichajes de
## la biblioteca gratis de Summer (`_render_biblioteca_fichajes.gd`, scratchpad): escritorio_trabajo
## (huella 1x1 marcada), silla_oficina, vending_nueva -- cada uno con su muñeco REAL de 44px al
## lado, y SOLO para vending_nueva, la vending VIEJA (`assets/sprites/mobiliario/vending_0.png`,
## SOLO LECTURA, sin integrar) al lado para comparar.
##
## Cada sección usa su PROPIO origen isométrico local (mini-tablero independiente dentro de su
## franja horizontal del lienzo) -- NO una sola rejilla compartida con `fila` distinta por sección:
## en isométrico, aumentar `fila` con `columna` fija desplaza el dibujo hacia la IZQUIERDA además
## de hacia abajo (`Proyeccion.esquina_iso`/`origen_centrado`), así que tres secciones en una
## rejilla común con filas 1/4/8 se montaban unas sobre otras en pantalla. Con un origen propio por
## franja, cada sección se centra en su propio rectángulo sin arrastrar a las demás.
##
## Escribe SOLO `hoja_fichajes_biblioteca.png` al scratchpad.

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_RENDER := Vector2i(1000, 1020)
const ALTO_CABECERA: int = 30
const ALTO_SECCION: int = 330
const ANCHO_SECCION: int = 1000
const COLUMNAS_SECCION: int = 14
const FILAS_SECCION: int = 8
const FILA_ITEMS: int = 3
const FILA_VIEJA: int = 6

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"
const CARPETA_MOBILIARIO := "res://assets/sprites/mobiliario/"

## Medidas impresas por `_render_biblioteca_fichajes.gd` (repetidas aquí SOLO para rotular -- no
## se remide nada).
const OBJETIVO_ESCRITORIO_PX: float = 51.76
const OBJETIVO_SILLA_PX: float = 32.35
const OBJETIVO_VENDING_PX: float = 59.21

## rot -> [medida_px, dif_px, "PASA"/"FALLA"]
const MEDIDAS_ESCRITORIO: Dictionary = {
	0: [52, 0.2, "PASA"], 90: [52, 0.2, "PASA"], 180: [52, 0.2, "PASA"], 270: [52, 0.2, "PASA"],
}
const MEDIDAS_SILLA: Dictionary = {
	0: [32, 0.4, "PASA"], 90: [32, 0.4, "PASA"], 180: [28, 4.4, "FALLA"], 270: [28, 4.4, "FALLA"],
}
const MEDIDAS_VENDING: Dictionary = {
	0: [59, 0.2, "PASA"], 90: [59, 0.2, "PASA"], 180: [59, 0.2, "PASA"], 270: [59, 0.2, "PASA"],
}

const ROTACIONES: Array[int] = [0, 90, 180, 270]
const PASO_COLUMNAS: int = 2

var _mundo: Node2D


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

	_mundo = Node2D.new()
	sub.add_child(_mundo)

	var titulo := Label.new()
	titulo.text = "fichajes biblioteca Summer — objetivos: escritorio_trabajo ancho=%.0fpx (huella 1x1) · silla_oficina alto=%.1fpx · vending_nueva alto=%.1fpx — tolerancia ±3px" % [
		OBJETIVO_ESCRITORIO_PX, OBJETIVO_SILLA_PX, OBJETIVO_VENDING_PX
	]
	titulo.add_theme_font_size_override("font_size", 13)
	titulo.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	titulo.position = Vector2(8.0, 6.0)
	_mundo.add_child(titulo)

	_seccion_escritorio(0)
	_seccion_silla(1)
	_seccion_vending(2)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta_salida: String = CARPETA_SCRATCH + "hoja_fichajes_biblioteca.png"
	var err: Error = imagen.save_png(ruta_salida)
	if err != OK:
		push_error("[HOJA BIBLIOTECA] save_png '%s' falló (error %d)" % [ruta_salida, err])
	else:
		print("[HOJA BIBLIOTECA] %dx%d px -> %s" % [imagen.get_width(), imagen.get_height(), ruta_salida])
	print("[HOJA BIBLIOTECA] hecho.")
	get_tree().quit()


## El origen isométrico local de la franja `indice` (0,1,2 de arriba a abajo) -- un mini-tablero
## de `COLUMNAS_SECCION`x`FILAS_SECCION` centrado en su propio rectángulo de `ANCHO_SECCION`x
## `ALTO_SECCION`, desplazado verticalmente por la cabecera y las franjas anteriores.
func _origen_seccion(indice: int) -> Vector2:
	var area := Vector2(ANCHO_SECCION, ALTO_SECCION)
	var local: Vector2 = ProyeccionScript.origen_centrado(COLUMNAS_SECCION, FILAS_SECCION, area)
	return local + Vector2(0.0, float(ALTO_CABECERA + indice * ALTO_SECCION))


func _dibujar_rejilla(origen: Vector2) -> void:
	for x: int in range(COLUMNAS_SECCION):
		for y: int in range(FILAS_SECCION):
			var borde := Line2D.new()
			borde.width = 1.0
			borde.default_color = Color(0.45, 0.48, 0.52, 0.55)
			borde.closed = true
			borde.points = PackedVector2Array([
				origen + ProyeccionScript.esquina_iso(x, y),
				origen + ProyeccionScript.esquina_iso(x + 1, y),
				origen + ProyeccionScript.esquina_iso(x + 1, y + 1),
				origen + ProyeccionScript.esquina_iso(x, y + 1),
			])
			_mundo.add_child(borde)


func _marcar_celda(celda: Vector2i, origen: Vector2) -> void:
	var relleno := Polygon2D.new()
	relleno.color = Color(0.95, 0.75, 0.15, 0.28)
	relleno.polygon = PackedVector2Array([
		origen + ProyeccionScript.esquina_iso(celda.x, celda.y),
		origen + ProyeccionScript.esquina_iso(celda.x + 1, celda.y),
		origen + ProyeccionScript.esquina_iso(celda.x + 1, celda.y + 1),
		origen + ProyeccionScript.esquina_iso(celda.x, celda.y + 1),
	])
	_mundo.add_child(relleno)


func _colocar_pieza(nombre: String, celda: Vector2i, origen: Vector2) -> void:
	_colocar_pieza_res(CARPETA_SCRATCH + nombre + ".png", celda, origen)


func _colocar_pieza_res(ruta: String, celda: Vector2i, origen: Vector2) -> void:
	var ruta_disco: String = ruta if ruta.begins_with("C:") else ProjectSettings.globalize_path(ruta)
	var img: Image = Image.load_from_file(ruta_disco)
	if img == null:
		push_error("[HOJA BIBLIOTECA] no se pudo cargar '%s'" % ruta_disco)
		var aviso := Label.new()
		aviso.text = "sin PNG"
		aviso.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		aviso.position = origen + ProyeccionScript.centro_iso(celda) + Vector2(-20.0, -10.0)
		_mundo.add_child(aviso)
		return
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	AnclajeSpriteScript.aplicar(sprite, Vector2i.ZERO, 1)
	var raiz := Node2D.new()
	raiz.position = origen + ProyeccionScript.centro_iso(celda)
	raiz.add_child(sprite)
	_mundo.add_child(raiz)


func _seccion_titulo(texto: String, indice: int) -> void:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
	label.position = Vector2(8.0, float(ALTO_CABECERA + indice * ALTO_SECCION + 4))
	_mundo.add_child(label)


func _etiqueta(texto: String, celda: Vector2i, origen: Vector2) -> void:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = origen + ProyeccionScript.esquina_iso(celda.x, celda.y) + Vector2(-35.0, -78.0)
	label.custom_minimum_size = Vector2(90.0, 0.0)
	_mundo.add_child(label)


func _seccion_escritorio(indice: int) -> void:
	var origen: Vector2 = _origen_seccion(indice)
	_dibujar_rejilla(origen)
	_seccion_titulo("escritorio_trabajo — huella 1x1 (celda marcada, ancho objetivo=%.0fpx)" % OBJETIVO_ESCRITORIO_PX, indice)

	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = origen + ProyeccionScript.centro_iso(Vector2i(1, FILA_ITEMS))
	_mundo.add_child(muneco)
	_etiqueta("muñeco\n1,70 m", Vector2i(1, FILA_ITEMS), origen)

	for i: int in ROTACIONES.size():
		var rot: int = ROTACIONES[i]
		var celda := Vector2i(4 + i * PASO_COLUMNAS, FILA_ITEMS)
		_marcar_celda(celda, origen)
		_colocar_pieza("escritorio_trabajo_%d" % rot, celda, origen)
		var m: Array = MEDIDAS_ESCRITORIO[rot]
		_etiqueta("%d°\nancho=%dpx dif=%.1f\n%s" % [rot, m[0], m[1], m[2]], celda, origen)


func _seccion_silla(indice: int) -> void:
	var origen: Vector2 = _origen_seccion(indice)
	_dibujar_rejilla(origen)
	_seccion_titulo("silla_oficina — alto objetivo=%.1fpx (~1,00 m con respaldo)" % OBJETIVO_SILLA_PX, indice)

	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = origen + ProyeccionScript.centro_iso(Vector2i(1, FILA_ITEMS))
	_mundo.add_child(muneco)
	_etiqueta("muñeco\n1,70 m", Vector2i(1, FILA_ITEMS), origen)

	for i: int in ROTACIONES.size():
		var rot: int = ROTACIONES[i]
		var celda := Vector2i(4 + i * PASO_COLUMNAS, FILA_ITEMS)
		_colocar_pieza("silla_oficina_%d" % rot, celda, origen)
		var m: Array = MEDIDAS_SILLA[rot]
		_etiqueta("%d°\nalto=%dpx dif=%.1f\n%s" % [rot, m[0], m[1], m[2]], celda, origen)


func _seccion_vending(indice: int) -> void:
	var origen: Vector2 = _origen_seccion(indice)
	_dibujar_rejilla(origen)
	_seccion_titulo("vending_nueva — alto objetivo=%.1fpx (1,83 m) · junto a vending VIEJA (integrada hoy, sin tocar)" % OBJETIVO_VENDING_PX, indice)

	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = origen + ProyeccionScript.centro_iso(Vector2i(1, FILA_ITEMS))
	_mundo.add_child(muneco)
	_etiqueta("muñeco\n1,70 m", Vector2i(1, FILA_ITEMS), origen)

	for i: int in ROTACIONES.size():
		var rot: int = ROTACIONES[i]
		var celda := Vector2i(4 + i * PASO_COLUMNAS, FILA_ITEMS)
		_colocar_pieza("vending_nueva_%d" % rot, celda, origen)
		var m: Array = MEDIDAS_VENDING[rot]
		_etiqueta("%d°\nalto=%dpx dif=%.1f\n%s" % [rot, m[0], m[1], m[2]], celda, origen)

	var celda_vieja := Vector2i(1, FILA_VIEJA)
	_colocar_pieza_res(CARPETA_MOBILIARIO + "vending_0.png", celda_vieja, origen)
	_etiqueta("vending VIEJA\n(sin tocar)", celda_vieja, origen)
