extends Node2D
## HOJA DE PROPUESTA DESECHABLE (2026-08-04, quick-spec §3b) — compara los 4 candidatos YA
## RE-ESCALADOS a la altura real de la pared del juego (`tools/_render_puertas_escala_pared.gd`,
## que casa cada uno a `ParedesSalas.ALTO_PARED` px, no a la escala de catálogo) sobre una SALA REAL
## (paredes construidas por `Construccion`/`ParedesSalas`, mismo camino que el juego — patrón
## `_montar` de `tools/_diag_oclusion_murete.gd`):
##
##   A) tramo PUERTA (muro norte, col 2) + `doorA_kaykit_pared` (KayKit `door_A`, CON hoja).
##   B) tramo PUERTA (muro norte, col 4) + `doorB_kaykit_pared` (KayKit `door_B`, CON hoja).
##   C) tramo PUERTA (muro norte, col 6) + `arq004_marco_pared` (ARQ_004, marco de madera SIN hoja).
##   D) tramo VENTANA (muro norte, col 8) + `arq009_ventana_pared` (ARQ_009, marco alargado —
##      "de suelo a techo").
##
## Modo de altura `&"todas"` (`ParedesSalas.fijar_modo_altura`, 2026-08-04): TODOS los tramos salen a
## `ALTO_PARED` (34 px) — el mismo criterio con el que se calibró cada PNG — así los 4 candidatos se
## juzgan contra la MISMA altura de pared, sin la excepción "cercana → media altura" del modo `auto`.
##
## Un MUÑECO de 44 px AL LADO de cada pieza (Sims/Theme Hospital: la persona sobresale de la pared
## enana — es la convención que el usuario tiene que juzgar aquí: ¿se lee bien una puerta más baja
## que la persona?).
##
## COLOCACIÓN: mockup EN MOTOR, aproximada y a mano — NO es el mecanismo final. Cada pieza se ancla
## con `AnclajeSprite.aplicar` (auto-ancla por la base del PNG) y su raíz se planta, a mano, en el
## PUNTO MEDIO del tramo de muro que ilustra (`Proyeccion.esquina_iso` de sus dos extremos), a nivel
## de SUELO. Rotación 0° en las 4 (todas sobre el mismo muro norte) — PRIMERA estimación sin
## verificar orientación real de cada malla, se corrige a ojo tras ver esta misma hoja.
##
## Escribe SOLO `hoja_puertas_escala.png` al scratchpad. Se borra tras usarlo — no es pipeline.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(1300, 780)

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"

## Rutas de los 4 candidatos ya renderizados A ESCALA DE PARED (`_render_puertas_escala_pared.gd`),
## rotación %d.
const RUTA_DOOR_A := CARPETA_SCRATCH + "doorA_kaykit_pared_%d.png"
const RUTA_DOOR_B := CARPETA_SCRATCH + "doorB_kaykit_pared_%d.png"
const RUTA_ARQ004 := CARPETA_SCRATCH + "arq004_marco_pared_%d.png"
const RUTA_ARQ009 := CARPETA_SCRATCH + "arq009_ventana_pared_%d.png"

## La sala de la hoja: perímetro con paredes reales, 4 tramos en el muro NORTE (fila `rect.y`).
const RECT_SALA := Rect2i(1, 1, 9, 4)
const COL_A := 2  # puerta + door_A
const COL_B := 4  # puerta + door_B
const COL_C := 6  # puerta + marco ARQ_004
const COL_D := 8  # ventana + ARQ_009


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
	camara.zoom = Vector2(1.05, 1.05)
	camara.position = ProyeccionScript.proyectar(Vector2(5.0, 1.6) * float(TAM_CELDA))
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
	var ok_b: bool = construccion.fijar_tipo_de_muro(Vector2i(COL_B, RECT_SALA.position.y), &"arriba", construccion.PUERTA)
	var ok_c: bool = construccion.fijar_tipo_de_muro(Vector2i(COL_C, RECT_SALA.position.y), &"arriba", construccion.PUERTA)
	var ok_d: bool = construccion.fijar_tipo_de_muro(Vector2i(COL_D, RECT_SALA.position.y), &"arriba", construccion.VENTANA)
	print("[HOJA ESCALA] tramos fijados: A(door_A)=%s B(door_B)=%s C(marco ARQ_004)=%s D(ventana ARQ_009)=%s" % [
		ok_a, ok_b, ok_c, ok_d
	])
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	# TODAS las paredes a ALTO_PARED (34 px) -- ver la cabecera: es la misma altura contra la que se
	# calibró cada PNG candidato.
	paredes.fijar_modo_altura(&"todas")

	# Un muñeco de 44px AL LADO de cada pieza (columna+1, fila+1: dentro de la sala, junto al tramo).
	_muneco_junto_a(profundo, COL_A + 1)
	_muneco_junto_a(profundo, COL_B + 1)
	_muneco_junto_a(profundo, COL_C + 1)
	_muneco_junto_a(profundo, COL_D + 1)
	_etiqueta(mundo, "44px (1,70m aprox.)", ProyeccionScript.centro_iso(Vector2i(COL_A + 1, RECT_SALA.position.y + 1)) + Vector2(-40.0, 24.0))

	# A: muro NORTE, col COL_A -- KayKit door_A, rotación 0°.
	var punto_a: Vector2 = _mid_arriba(COL_A, RECT_SALA.position.y)
	_colocar_pieza_externa(profundo, RUTA_DOOR_A % 0, punto_a)
	_etiqueta(mundo, "A door_A", punto_a + Vector2(-16.0, -70.0))

	# B: muro NORTE, col COL_B -- KayKit door_B, rotación 0°.
	var punto_b: Vector2 = _mid_arriba(COL_B, RECT_SALA.position.y)
	_colocar_pieza_externa(profundo, RUTA_DOOR_B % 0, punto_b)
	_etiqueta(mundo, "B door_B", punto_b + Vector2(-16.0, -70.0))

	# C: muro NORTE, col COL_C -- marco ARQ_004, rotación 0°.
	var punto_c: Vector2 = _mid_arriba(COL_C, RECT_SALA.position.y)
	_colocar_pieza_externa(profundo, RUTA_ARQ004 % 0, punto_c)
	_etiqueta(mundo, "C marco ARQ_004", punto_c + Vector2(-24.0, -70.0))

	# D: muro NORTE, col COL_D -- ventana ARQ_009 (suelo a techo), rotación 0°.
	var punto_d: Vector2 = _mid_arriba(COL_D, RECT_SALA.position.y)
	_colocar_pieza_externa(profundo, RUTA_ARQ009 % 0, punto_d)
	_etiqueta(mundo, "D ventana ARQ_009", punto_d + Vector2(-30.0, -70.0))

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta: String = CARPETA_SCRATCH + "hoja_puertas_escala.png"
	var err: Error = imagen.save_png(ruta)
	if err != OK:
		push_error("[HOJA ESCALA] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[HOJA ESCALA] %dx%d px -> %s" % [imagen.get_width(), imagen.get_height(), ruta])
	print("[HOJA ESCALA] hecho.")
	get_tree().quit()


## Punto medio del tramo de muro "arriba" (norte) de la celda (columna `col`, fila `fila`), en
## pantalla, al nivel de SUELO (mismo criterio que `_hoja_puertas_ventanas.gd`).
func _mid_arriba(col: int, fila: int) -> Vector2:
	return (ProyeccionScript.esquina_iso(col, fila) + ProyeccionScript.esquina_iso(col + 1, fila)) * 0.5


## Un muñeco de 44 px plantado en la celda (col, `RECT_SALA.position.y + 1` -- justo dentro de la
## sala, pegado al tramo de muro que ilustra su columna vecina).
func _muneco_junto_a(padre: Node2D, col: int) -> void:
	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = ProyeccionScript.centro_iso(Vector2i(col, RECT_SALA.position.y + 1))
	padre.add_child(muneco)


## Un `Sprite2D` cargado desde un PNG EXTERNO del scratchpad (no recurso importado), anclado por su
## base con `AnclajeSprite` (auto-ancla, mide el PNG) y plantado en `punto` (pantalla).
func _colocar_pieza_externa(padre: Node2D, ruta_absoluta: String, punto: Vector2) -> void:
	var img: Image = Image.load_from_file(ruta_absoluta)
	if img == null:
		push_error("[HOJA ESCALA] no se pudo cargar '%s'" % ruta_absoluta)
		return
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	AnclajeSpriteScript.aplicar(sprite, Vector2i.ZERO, 1)
	var raiz := Node2D.new()
	raiz.position = punto
	raiz.add_child(sprite)
	padre.add_child(raiz)
	print("[HOJA ESCALA] pieza '%s' en %s -- textura %dx%d px (alto vs ALTO_PARED %.1f: delta=%+.1f)" % [
		ruta_absoluta.get_file(), punto, tex.get_width(), tex.get_height(),
		ParedesSalasScript.ALTO_PARED, float(tex.get_height()) - ParedesSalasScript.ALTO_PARED
	])


## Etiqueta pequeña (Label con contorno) en un punto de pantalla YA calculado.
func _etiqueta(mundo: Node2D, texto: String, punto: Vector2) -> void:
	var label := Label.new()
	label.text = texto
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	label.position = punto
	mundo.add_child(label)
