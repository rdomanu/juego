extends Node2D
## _hoja_ventanillas_final — DESECHABLE (2026-08-07). Hoja definitiva de la ronda de correcciones:
##
## REGLAS DURAS aplicadas (usuario, verificadas por GEOMETRÍA -- ver el informe de la sesión):
##  - Convención real del juego (`mesa_atencion.gd`): `CELDA_FUNCIONARIO` = NORTE/detrás,
##    `CELDA_CIUDADANO` = SUR/delante (antes invertido en la hoja previa -- bug corregido aquí).
##  - Para TODAS las piezas de este lote (silla_oficina, sillas candidatas A/B/C, crt_antiguo,
##    comodidad_equipo_informatico) la familia "hacia cámara" (silueta más alta / cara frontal
##    visible) cae en las rotaciones {0°,90°} -- la ÚNICA solución consistente con el ciclo
##    norte→oeste→sur→este (`AnclajeSprite.CICLO_ESPALDA`) es: facing(0°)=SUR, facing(90°)=ESTE,
##    facing(180°)=NORTE, facing(270°)=OESTE. De ahí: silla del funcionario (fila norte) mirando
##    al sur -> vista 0°; silla/monitor que deben mirar al NORTE -> vista 180°.
##  - `escritorio_trabajo` usa la MISMA lógica pero con familia visible {90°,180°} (su silla
##    horneada, ya descartada, se ve en esas 2) -> facing(0°)=OESTE, facing(90°)=SUR,
##    facing(180°)=ESTE, facing(270°)=NORTE. Monitor mirando al norte -> vista 270° (silla
##    horneada oculta, sin duplicar con la `silla_oficina` añadida aparte).
##
## Bloques 2×3 (básica·media·pro), bloque escritorio (2 celdas) y fila de sillas candidatas A/B/C
## (4 vistas + muñeco). Escribe SOLO `hoja_ventanillas_final.png` al scratchpad.

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

const TAM_RENDER := Vector2i(1500, 1400)
const ALTO_CABECERA: int = 110
const ALTO_FRANJA: int = 420
const COLUMNAS_FRANJA: int = 26
const FILAS_FRANJA: int = 9
const FILA_BASE: int = 3

## Silla del funcionario (fila NORTE): mira al SUR -> vista 0° (visible/hacia cámara).
const SILLA_FUNCIONARIO := "silla_oficina_0"
## Silla del ciudadano (fila SUR): mira al NORTE -> vista 180° (familia oculta/hacia el fondo).
const SILLA_CIUDADANO := "silla_ciudadano_A_180"
## PRO usa la silla C PROVISIONAL (el usuario ya avisó que llega una silla cómoda nueva -- ver
## `nota` del bloque más abajo, se marca en la hoja para que no se lea como definitiva).
const SILLA_CIUDADANO_PROVISIONAL := "silla_ciudadano_C_180"

## Los 3 bloques de mesa 2×3: `id_mesa` = nombre base en el scratchpad de la mesa YA orientada
## (con el sufijo de vista correcto incluido en el nombre de archivo). 2026-08-07, 2º intento
## (3D DE VERDAD, ver `_render_conjunto_ventanillas.gd`): básica/media ya NO son un compuesto 2D
## (`*_compuesta_0`, con el CRT anclado a ojo sobre un PNG plano -- el usuario lo rechazó, "flotaba/
## se descentraba") sino el render de una escena 3D con mesa+aparato en el MISMO Node3D, oclusión
## real del renderer -- `*_conjunto_0`.
const BLOQUES: Array[Dictionary] = [
	{
		"titulo": "mesa_basica_v3_vacia + CRT antiguo (3D real)\n(CRT apoyado en el tablero, centrado en la mitad norte)",
		"archivo": "mesa_basica_conjunto_0", "silla_ciudadano": SILLA_CIUDADANO,
		"medida": "ancho 58/58px PASA · CRT 0,40m (F relativo a la mesa)",
	},
	{
		"titulo": "mesa_media_v2_vacia + monitor ÚNICO (3D real, +grande)\n(mampara lado ciudadano OCLUYE al monitor -- oclusión real)",
		"archivo": "mesa_media_conjunto_0", "silla_ciudadano": SILLA_CIUDADANO,
		"medida": "ancho 58/58px PASA · monitor 0,55m (antes 0,35m)",
	},
	{
		"titulo": "mesa_pro (aprobada, girada 180°)\n(monitores horneados mirando al policía)",
		"archivo": "mesa_pro_180", "silla_ciudadano": SILLA_CIUDADANO_PROVISIONAL,
		"nota": "silla C PROVISIONAL -- llega silla cómoda nueva",
	},
]

const ROTACIONES: Array[int] = [0, 90, 180, 270]
const PASO_COLUMNAS_BLOQUE := 6
const PASO_COLUMNAS_SILLA := 3


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
	titulo.text = "hoja_ventanillas_final — funcionario NORTE mirando al sur (silla_oficina_0) · ciudadano SUR mirando al norte (silla_ciudadano_A_180) · monitores SIEMPRE mirando al policía"
	titulo.add_theme_font_size_override("font_size", 13)
	titulo.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	titulo.position = Vector2(8.0, 6.0)
	mundo.add_child(titulo)

	# ── Franja 0: los 3 bloques 2×3 lado a lado ─────────────────────────────────────────────────
	var origen0: Vector2 = _origen_franja(0)
	_dibujar_rejilla(mundo, origen0)
	for i: int in BLOQUES.size():
		_bloque_2x3(mundo, origen0, 1 + i * PASO_COLUMNAS_BLOQUE, BLOQUES[i])

	# ── Franja 1: bloque escritorio (2 celdas) + silla del funcionario centrada, norte ─────────
	var origen1: Vector2 = _origen_franja(1)
	_dibujar_rejilla(mundo, origen1)
	_bloque_escritorio(mundo, origen1, 1)

	# ── Franja 2: fila de sillas candidatas A/B/C, 4 vistas cada una + muñeco ───────────────────
	var origen2: Vector2 = _origen_franja(2)
	_dibujar_rejilla(mundo, origen2)
	_fila_sillas_candidatas(mundo, origen2)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta_salida: String = CARPETA_SCRATCH + "hoja_ventanillas_final.png"
	var err: Error = imagen.save_png(ruta_salida)
	if err != OK:
		push_error("[HOJA FINAL] save_png '%s' falló (error %d)" % [ruta_salida, err])
	else:
		print("[HOJA FINAL] %dx%d px -> %s" % [imagen.get_width(), imagen.get_height(), ruta_salida])
	print("[HOJA FINAL] hecho.")
	get_tree().quit()


func _origen_franja(indice: int) -> Vector2:
	var area := Vector2(TAM_RENDER.x, ALTO_FRANJA)
	var local: Vector2 = ProyeccionScript.origen_centrado(COLUMNAS_FRANJA, FILAS_FRANJA, area)
	return local + Vector2(0.0, float(ALTO_CABECERA + indice * ALTO_FRANJA))


func _dibujar_rejilla(mundo: Node2D, origen: Vector2) -> void:
	for x: int in range(COLUMNAS_FRANJA):
		for y: int in range(FILAS_FRANJA):
			var borde := Line2D.new()
			borde.width = 1.0
			borde.default_color = Color(0.45, 0.48, 0.52, 0.5)
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


func _cargar_textura_absoluta(ruta: String) -> Texture2D:
	var img: Image = Image.load_from_file(ruta)
	if img == null:
		push_warning("[HOJA FINAL] no se pudo cargar '%s'" % ruta)
		return null
	return ImageTexture.create_from_image(img)


func _colocar_pieza_scratch(mundo: Node2D, nombre: String, celda: Vector2i, origen: Vector2) -> void:
	var tex: Texture2D = _cargar_textura_absoluta(CARPETA_SCRATCH + nombre + ".png")
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	AnclajeSpriteScript.aplicar(sprite, Vector2i.ZERO, 1)
	var raiz := Node2D.new()
	raiz.position = origen + ProyeccionScript.centro_iso(celda)
	raiz.add_child(sprite)
	mundo.add_child(raiz)


func _colocar_pieza_centrada(mundo: Node2D, nombre: String, centro_pantalla: Vector2) -> void:
	var tex: Texture2D = _cargar_textura_absoluta(CARPETA_SCRATCH + nombre + ".png")
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	AnclajeSpriteScript.aplicar(sprite, Vector2i(0, 1), 1)
	var raiz := Node2D.new()
	raiz.position = centro_pantalla
	raiz.add_child(sprite)
	mundo.add_child(raiz)


## Bloque 2×3: fila 0 = FUNCIONARIO (norte, detrás), fila 1 = mesa (huella 2×1, cuerpo este),
## fila 2 = CIUDADANO (sur, delante). Convención REAL del juego (`mesa_atencion.gd`), corregida.
func _bloque_2x3(mundo: Node2D, origen: Vector2, base_col: int, bloque: Dictionary) -> void:
	var col0 := base_col
	var col1 := base_col + 1

	var titulo := Label.new()
	titulo.text = bloque["titulo"]
	titulo.add_theme_font_size_override("font_size", 12)
	titulo.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	titulo.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	titulo.add_theme_constant_override("outline_size", 4)
	titulo.position = origen + ProyeccionScript.esquina_iso(col0, FILA_BASE) + Vector2(-10.0, -34.0)
	mundo.add_child(titulo)

	var fila_n: int = FILA_BASE
	var fila_mesa: int = FILA_BASE + 1
	var fila_s: int = FILA_BASE + 2
	for fila: int in [fila_n, fila_mesa, fila_s]:
		_marcar_celda(mundo, Vector2i(col0, fila), origen, Color(0.3, 0.5, 0.9, 0.10))
		_marcar_celda(mundo, Vector2i(col1, fila), origen, Color(0.3, 0.5, 0.9, 0.10))
	_marcar_celda(mundo, Vector2i(col0, fila_mesa), origen, Color(0.95, 0.75, 0.15, 0.20))
	_marcar_celda(mundo, Vector2i(col1, fila_mesa), origen, Color(0.95, 0.75, 0.15, 0.20))

	# Etiquetas norte/sur, para que se lea el bloque sin ambigüedad.
	_etiqueta_pequena(mundo, "N (funcionario)", Vector2i(col0, fila_n), origen, Color(0.6, 0.85, 1.0))
	_etiqueta_pequena(mundo, "S (ciudadano)", Vector2i(col0, fila_s), origen, Color(1.0, 0.75, 0.5))

	# Silla del FUNCIONARIO (fila norte) -- mira al sur.
	var centro_funcionario: Vector2 = origen + (
		ProyeccionScript.centro_iso(Vector2i(col0, fila_n)) + ProyeccionScript.centro_iso(Vector2i(col1, fila_n))
	) * 0.5
	_colocar_pieza_centrada(mundo, SILLA_FUNCIONARIO, centro_funcionario)

	# Mesa (huella 2×1, este), ancla en la ÚLTIMA celda (col1, fila_mesa).
	var raiz_mesa := Node2D.new()
	raiz_mesa.position = origen + ProyeccionScript.centro_iso(Vector2i(col1, fila_mesa))
	var sprite_mesa := Sprite2D.new()
	sprite_mesa.texture = _cargar_textura_absoluta(CARPETA_SCRATCH + (bloque["archivo"] as String) + ".png")
	if sprite_mesa.texture != null:
		AnclajeSpriteScript.aplicar(sprite_mesa, Vector2i(1, 0), 2)
	raiz_mesa.add_child(sprite_mesa)
	mundo.add_child(raiz_mesa)
	if bloque.has("medida"):
		_etiqueta_pequena(mundo, bloque["medida"], Vector2i(col0, fila_mesa + 1), origen, Color(0.6, 1.0, 0.6))

	# Silla del CIUDADANO (fila sur) -- mira al norte. Cada bloque puede traer la suya (PRO usa la
	# provisional C, ver `BLOQUES`).
	var centro_ciudadano: Vector2 = origen + (
		ProyeccionScript.centro_iso(Vector2i(col0, fila_s)) + ProyeccionScript.centro_iso(Vector2i(col1, fila_s))
	) * 0.5
	var silla_ciudadano_id: String = bloque.get("silla_ciudadano", SILLA_CIUDADANO)
	_colocar_pieza_centrada(mundo, silla_ciudadano_id, centro_ciudadano)
	if bloque.has("nota"):
		_etiqueta_pequena(mundo, bloque["nota"], Vector2i(col0, fila_s), origen, Color(1.0, 0.55, 0.55))

	# Muñeco real 44px al lado, a la altura de la mesa.
	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = origen + ProyeccionScript.centro_iso(Vector2i(col1 + 1, fila_mesa))
	mundo.add_child(muneco)


## Bloque escritorio (2 celdas): SOLO el escritorio -- trae su PROPIA silla blanca horneada, el
## usuario descartó añadir la `silla_oficina` negra aparte (duplicaba silla). Vista 90° (la silla
## horneada queda visible y bien compuesta, verificado a ojo en las 4 rotaciones).
func _bloque_escritorio(mundo: Node2D, origen: Vector2, base_col: int) -> void:
	var col0 := base_col
	var col1 := base_col + 1

	var titulo := Label.new()
	titulo.text = "escritorio_trabajo (2 celdas, 58px), solo\n(silla blanca horneada propia, vista 90°)"
	titulo.add_theme_font_size_override("font_size", 12)
	titulo.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	titulo.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	titulo.add_theme_constant_override("outline_size", 4)
	titulo.position = origen + ProyeccionScript.esquina_iso(col0, FILA_BASE) + Vector2(-10.0, -34.0)
	mundo.add_child(titulo)

	var fila_n: int = FILA_BASE
	var fila_mesa: int = FILA_BASE + 1
	for fila: int in [fila_n, fila_mesa]:
		_marcar_celda(mundo, Vector2i(col0, fila), origen, Color(0.3, 0.5, 0.9, 0.10))
		_marcar_celda(mundo, Vector2i(col1, fila), origen, Color(0.3, 0.5, 0.9, 0.10))
	_marcar_celda(mundo, Vector2i(col0, fila_mesa), origen, Color(0.95, 0.75, 0.15, 0.20))
	_marcar_celda(mundo, Vector2i(col1, fila_mesa), origen, Color(0.95, 0.75, 0.15, 0.20))

	var raiz_mesa := Node2D.new()
	raiz_mesa.position = origen + ProyeccionScript.centro_iso(Vector2i(col1, fila_mesa))
	var sprite_mesa := Sprite2D.new()
	sprite_mesa.texture = _cargar_textura_absoluta(CARPETA_SCRATCH + "escritorio_trabajo_90.png")
	if sprite_mesa.texture != null:
		AnclajeSpriteScript.aplicar(sprite_mesa, Vector2i(1, 0), 2)
	raiz_mesa.add_child(sprite_mesa)
	mundo.add_child(raiz_mesa)

	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = origen + ProyeccionScript.centro_iso(Vector2i(col1 + 1, fila_mesa))
	mundo.add_child(muneco)


func _fila_sillas_candidatas(mundo: Node2D, origen: Vector2) -> void:
	var titulo := Label.new()
	titulo.text = "sillas candidatas del ciudadano (KayKit CC BY, madera) — 4 vistas, ~0,90 m -> ~29 px"
	titulo.add_theme_font_size_override("font_size", 12)
	titulo.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	titulo.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	titulo.add_theme_constant_override("outline_size", 4)
	titulo.position = origen + ProyeccionScript.esquina_iso(1, FILA_BASE - 1) + Vector2(-10.0, -34.0)
	mundo.add_child(titulo)

	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = origen + ProyeccionScript.centro_iso(Vector2i(1, FILA_BASE + 1))
	mundo.add_child(muneco)
	_etiqueta_pequena(mundo, "muñeco 1,70 m", Vector2i(1, FILA_BASE + 1), origen, Color(1.0, 1.0, 0.6))

	var letras := ["A", "C"]  # B descartada por el usuario -- solo A y C quedan en pie.
	for f: int in letras.size():
		var letra: String = letras[f]
		for i: int in ROTACIONES.size():
			var rot: int = ROTACIONES[i]
			var celda := Vector2i(4 + i * PASO_COLUMNAS_SILLA, FILA_BASE + f)
			_colocar_pieza_scratch(mundo, "silla_ciudadano_%s_%d" % [letra, rot], celda, origen)
			_etiqueta_pequena(mundo, "%s %d°" % [letra, rot], celda, origen, Color(0.9, 0.9, 0.9))


func _etiqueta_pequena(mundo: Node2D, texto: String, celda: Vector2i, origen: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = origen + ProyeccionScript.esquina_iso(celda.x, celda.y) + Vector2(-30.0, -40.0)
	label.custom_minimum_size = Vector2(80.0, 0.0)
	mundo.add_child(label)
