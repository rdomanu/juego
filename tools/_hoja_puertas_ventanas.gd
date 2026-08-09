extends Node2D
## HOJA DE PROPUESTA DESECHABLE (2026-08-04) — feedback del usuario jugando: "de las puertas solo
## se ve el hueco... con ventanas algo parecido: se ponen pero no se ve nada". Hoy puerta/ventana
## son dibujo 100% por código (`paredes_salas.gd`: jambas cortas + hueco / línea de cristal fina).
## Esta hoja compara ESO con 4 piezas del pack (`isometric_office.glb`, `catalogo_objetos_manifest.
## json` sección `arquitectura`) superpuestas en su sitio, sobre una SALA REAL (paredes construidas
## por `Construccion`/`ParedesSalas`, mismo camino que el juego — patrón `_montar` de
## `tools/_diag_oclusion_murete.gd`):
##
##   A) tramo PUERTA (muro norte, col 2) + `arq004_marco_madera` (ARQ_004 — marco de madera SIN hoja).
##   B) tramo PUERTA (muro oeste, fila 2) + `arq009_marco_metal` (ARQ_009 — marco metálico SIN hoja).
##   C) tramo VENTANA (muro norte, col 4) + `arq023_panel_ventana` (ARQ_023 — panel de pared con
##      hueco rectangular tipo ventana interior).
##   D) tramo VENTANA (muro oeste, fila 4) + `arq022_persiana` (ARQ_022 — persiana/estor enrollable).
##
## Los 4 PNG (`tools/_render_arq_puertas_ventanas.gd`, ejecutado antes que esta hoja) están
## calibrados con la MISMA escala mundo→píxel que el resto de mobiliario ya integrado (`render_
## mobiliario.gd`: el mostrador define el factor) — a propósito NO se reescalan aquí para forzar que
## "quepan" en el hueco: la pregunta que hace esta hoja es precisamente si CASAN a esa escala real
## o no (ver el informe de la sesión).
##
## COLOCACIÓN: mockup EN MOTOR, aproximada y a mano — NO es el mecanismo final. Cada pieza se ancla
## con `AnclajeSprite.aplicar` (auto-ancla por la base del PNG) y su raíz se plumea, a mano, en el
## PUNTO MEDIO del tramo de muro que ilustra (`Proyeccion.esquina_iso` de sus dos extremos — el
## mismo punto que usa `ParedesSalas` para dibujar esa arista), a nivel de SUELO. La rotación
## (0° en el muro norte, 90° en el oeste, para que la misma cara mire a cámara en las dos paredes)
## es una PRIMERA estimación sin verificar orientación real de cada malla — se corrige a ojo tras
## ver esta misma hoja, antes de cualquier integración.
##
## Escribe SOLO `hoja_puertas_ventanas.png` al scratchpad. Se borra tras usarlo — no es pipeline.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(1100, 780)

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"

## Rutas de los 4 candidatos ya renderizados (`_render_arq_puertas_ventanas.gd`), rotación %d.
const RUTA_ARQ004 := CARPETA_SCRATCH + "arq004_marco_madera_%d.png"
const RUTA_ARQ009 := CARPETA_SCRATCH + "arq009_marco_metal_%d.png"
const RUTA_ARQ022 := CARPETA_SCRATCH + "arq022_persiana_%d.png"
const RUTA_ARQ023 := CARPETA_SCRATCH + "arq023_panel_ventana_%d.png"

## La sala de la hoja: perímetro con paredes reales. Muro norte = fila `rect.y` (lado "arriba");
## muro oeste = columna `rect.x` (lado "izquierda") — convención de `Construccion.clave_de_muro`.
const RECT_SALA := Rect2i(1, 1, 6, 5)
const COL_A := 2   # muro norte, tramo A (puerta + marco madera)
const COL_C := 4   # muro norte, tramo C (ventana + panel)
const FILA_B := 2  # muro oeste, tramo B (puerta + marco metal)
const FILA_D := 4  # muro oeste, tramo D (ventana + persiana)


func _ready() -> void:
	var sub := SubViewport.new()
	sub.size = TAM_RENDER
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)

	var capa_fondo := CanvasLayer.new()
	capa_fondo.layer = -1
	sub.add_child(capa_fondo)
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.14, 0.16)
	fondo.size = Vector2(TAM_RENDER)
	capa_fondo.add_child(fondo)

	# Encuadre con CÁMARA (no con un Node2D padre): las capas de `Construccion` cuelgan de un nodo
	# no-CanvasItem y son raíces de canvas — mismo gotcha que `_diag_oclusion_murete._montar`.
	var camara := Camera2D.new()
	camara.zoom = Vector2(1.35, 1.35)
	camara.position = ProyeccionScript.proyectar(Vector2(4.0, 3.0) * float(TAM_CELDA))
	sub.add_child(camara)
	camara.make_current()

	var mundo := Node2D.new()
	sub.add_child(mundo)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)

	var paredes := ParedesSalasScript.new()
	profundo.add_child(paredes)
	var construccion := ConstruccionScript.new()
	construccion.aplicar_config(ConfigConstruccionScript.new())
	mundo.add_child(construccion)
	construccion.montar_visual(TAM_CELDA, Vector2.ZERO, profundo)

	var sala: StringName = construccion.construir_de_oficio_sala(&"sala_documentacion", RECT_SALA)
	construccion.fijar_paredes_de_sala(sala, true)
	var ok_a: bool = construccion.fijar_tipo_de_muro(Vector2i(COL_A, RECT_SALA.position.y), &"arriba", construccion.PUERTA)
	var ok_b: bool = construccion.fijar_tipo_de_muro(Vector2i(RECT_SALA.position.x, FILA_B), &"izquierda", construccion.PUERTA)
	var ok_c: bool = construccion.fijar_tipo_de_muro(Vector2i(COL_C, RECT_SALA.position.y), &"arriba", construccion.VENTANA)
	var ok_d: bool = construccion.fijar_tipo_de_muro(Vector2i(RECT_SALA.position.x, FILA_D), &"izquierda", construccion.VENTANA)
	print("[HOJA PYV] tramos fijados: A(puerta norte)=%s B(puerta oeste)=%s C(ventana norte)=%s D(ventana oeste)=%s" % [
		ok_a, ok_b, ok_c, ok_d
	])
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)

	# Muñeco de 44px, referencia de escala, plantado dentro de la sala.
	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = ProyeccionScript.centro_iso(Vector2i(3, 3))
	profundo.add_child(muneco)
	_etiqueta(mundo, "44px (1,70m aprox.)", ProyeccionScript.centro_iso(Vector2i(3, 3)) + Vector2(10.0, -70.0))

	# A: muro NORTE, col COL_A -- marco de madera (ARQ_004), rotación 0° (cara al norte, sin verificar).
	var punto_a: Vector2 = _mid_arriba(COL_A, RECT_SALA.position.y)
	_colocar_pieza_externa(profundo, RUTA_ARQ004 % 0, punto_a)
	_etiqueta(mundo, "A", punto_a + Vector2(-6.0, -100.0))

	# B: muro OESTE, fila FILA_B -- marco metálico (ARQ_009), rotación 90° (misma cara, girada al oeste).
	var punto_b: Vector2 = _mid_izquierda(RECT_SALA.position.x, FILA_B)
	_colocar_pieza_externa(profundo, RUTA_ARQ009 % 90, punto_b)
	_etiqueta(mundo, "B", punto_b + Vector2(-6.0, -100.0))

	# C: muro NORTE, col COL_C -- panel con hueco de ventana (ARQ_023), rotación 0°.
	var punto_c: Vector2 = _mid_arriba(COL_C, RECT_SALA.position.y)
	_colocar_pieza_externa(profundo, RUTA_ARQ023 % 0, punto_c)
	_etiqueta(mundo, "C", punto_c + Vector2(-6.0, -160.0))

	# D: muro OESTE, fila FILA_D -- persiana desplegada (ARQ_022), rotación 90°.
	var punto_d: Vector2 = _mid_izquierda(RECT_SALA.position.x, FILA_D)
	_colocar_pieza_externa(profundo, RUTA_ARQ022 % 90, punto_d)
	_etiqueta(mundo, "D", punto_d + Vector2(-6.0, -110.0))

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta: String = CARPETA_SCRATCH + "hoja_puertas_ventanas.png"
	var err: Error = imagen.save_png(ruta)
	if err != OK:
		push_error("[HOJA PYV] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[HOJA PYV] %dx%d px -> %s" % [imagen.get_width(), imagen.get_height(), ruta])
	print("[HOJA PYV] hecho.")
	get_tree().quit()


## Punto medio del tramo de muro "arriba" (norte) de la celda (columna `col`, fila `fila`), en
## pantalla, al nivel de SUELO (`Proyeccion.esquina_iso` ya son los vértices de la rejilla, la
## misma base que dibuja `ParedesSalas`).
func _mid_arriba(col: int, fila: int) -> Vector2:
	return (ProyeccionScript.esquina_iso(col, fila) + ProyeccionScript.esquina_iso(col + 1, fila)) * 0.5


## Punto medio del tramo de muro "izquierda" (oeste) de la celda (columna `col`, fila `fila`).
func _mid_izquierda(col: int, fila: int) -> Vector2:
	return (ProyeccionScript.esquina_iso(col, fila) + ProyeccionScript.esquina_iso(col, fila + 1)) * 0.5


## Un `Sprite2D` cargado desde un PNG EXTERNO del scratchpad (no recurso importado), anclado por su
## base con `AnclajeSprite` (auto-ancla, mide el PNG) y plantado en `punto` (pantalla, YA con
## cualquier origen que use el llamador).
func _colocar_pieza_externa(padre: Node2D, ruta_absoluta: String, punto: Vector2) -> void:
	var img: Image = Image.load_from_file(ruta_absoluta)
	if img == null:
		push_error("[HOJA PYV] no se pudo cargar '%s'" % ruta_absoluta)
		return
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	AnclajeSpriteScript.aplicar(sprite, Vector2i.ZERO, 1)
	var raiz := Node2D.new()
	raiz.position = punto
	raiz.add_child(sprite)
	padre.add_child(raiz)
	print("[HOJA PYV] pieza '%s' en %s -- textura %dx%d px" % [
		ruta_absoluta.get_file(), punto, tex.get_width(), tex.get_height()
	])


## Etiqueta pequeña (Label con contorno) en un punto de pantalla YA calculado.
func _etiqueta(mundo: Node2D, texto: String, punto: Vector2) -> void:
	var label := Label.new()
	label.text = texto
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	label.position = punto
	mundo.add_child(label)
