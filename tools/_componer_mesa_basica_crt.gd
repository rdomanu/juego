extends Node2D
## _componer_mesa_basica_crt — DESECHABLE (2026-08-06). Última pieza del lote: monta el CRT
## antiguo (`assets/sprites/mobiliario/comodidad_equipo_informatico_0.png`, SOLO LECTURA -- el
## cluster de monitores ya existente en el catálogo) encima de `mesa_basica_<rot>.png`
## (`_render_mesa_ventanilla_lote.gd`, este scratchpad), CENTRADO en el lado del POLICÍA (sur en
## la vista 0) -- mismo patrón "sobremesa" que `_demo_props_pipeline.gd::_plantar_sobremesa`
## (medir la fila-tope REAL de la columna donde cae el aparato, no una altura fija a mano) +
## `AnclajeSprite.semiejes_base` (para saber CUÁNTO mide el fondo norte/sur de la mesa y así situar
## el punto "centrado en la mitad sur", en vez de a ojo).
##
## El CRT tiene 1 SOLA vista (norma actual de piezas de 1 vista, ver `mesa_ventanilla_pro`
## reutilizando su propio monitor horneado): se reutiliza el MISMO PNG en las 4 salidas, solo
## cambia DÓNDE cae -- la posición "sur" se recalcula por rotación con `semiejes_base` de CADA PNG
## de mesa (footprint rectangular, sigue alineado a los ejes del plano cuadrado en las 4
## rotaciones, así que "sur" sale bien sin distinguir casos).
##
## Escribe SOLO `mesa_basica_compuesta_{0,90,180,270}.png` al scratchpad.

const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"
const RUTA_CRT := "res://assets/sprites/mobiliario/comodidad_equipo_informatico_0.png"

const ROTACIONES: Array[int] = [0, 90, 180, 270]

## "Centrado en el lado sur": a mitad de camino entre el centro de la base y su borde sur --
## el CENTRO de la mitad sur del fondo de la mesa, no el borde.
const FRACCION_SUR: float = 0.5

const MARGEN_LIENZO_PX: int = 8


func _ready() -> void:
	var tex_crt: Texture2D = load(RUTA_CRT)
	if tex_crt == null:
		push_error("[COMPONER MESA CRT] no se pudo cargar %s" % RUTA_CRT)
		get_tree().quit(1)
		return
	var img_crt: Image = tex_crt.get_image()
	if img_crt.is_compressed():
		img_crt.decompress()
	var centro_crt: Vector2 = AnclajeSpriteScript.centro_base(tex_crt)

	for rot: int in ROTACIONES:
		_componer_uno(rot, img_crt, centro_crt)

	print("[COMPONER MESA CRT] hecho.")
	get_tree().quit()


func _componer_uno(rot: int, img_crt: Image, centro_crt: Vector2) -> void:
	var ruta_mesa: String = "%smesa_basica_%d.png" % [CARPETA_SCRATCH, rot]
	var img_mesa: Image = Image.load_from_file(ruta_mesa)
	if img_mesa == null:
		push_error("[COMPONER MESA CRT] no se pudo cargar '%s'" % ruta_mesa)
		return
	var tex_mesa: ImageTexture = ImageTexture.create_from_image(img_mesa)

	# 1) El punto de SUELO "centrado en la mitad sur" del footprint de la mesa (AnclajeSprite, sin
	#    nada a mano): centro de la base + medio semieje sur, proyectado igual que `desvio_arrimado`.
	var centro_base_mesa: Vector2 = AnclajeSpriteScript.centro_base(tex_mesa)
	var semiejes_mesa: Vector2 = AnclajeSpriteScript.semiejes_base(tex_mesa)
	var delta_sur: Vector2 = ProyeccionScript.proyectar(Vector2(0.0, 1.0) * semiejes_mesa.y * FRACCION_SUR)
	var punto_suelo_sur: Vector2 = centro_base_mesa + delta_sur

	# 2) La ALTURA real del tablero en ESA columna exacta -- medida de la silueta de la mesa (misma
	#    técnica que `_demo_props_pipeline._medir_superficie_tablero`/`_fila_en`, "patrón sobremesa"):
	#    la fila opaca más alta de esa columna, amortiguada con la mediana de una ventana vecina.
	var x_local: int = clampi(roundi(punto_suelo_sur.x), 0, img_mesa.get_width() - 1)
	var fila_tope: int = _fila_tope_en(img_mesa, x_local)
	var punto_superficie: Vector2 = Vector2(float(x_local), float(fila_tope))

	# 3) Coloca el CRT con SU centro de base exactamente en ese punto de superficie.
	var offset_crt: Vector2 = punto_superficie - centro_crt

	var min_x: float = minf(0.0, offset_crt.x)
	var min_y: float = minf(0.0, offset_crt.y)
	var max_x: float = maxf(float(img_mesa.get_width()), offset_crt.x + float(img_crt.get_width()))
	var max_y: float = maxf(float(img_mesa.get_height()), offset_crt.y + float(img_crt.get_height()))
	var ancho: int = ceili(max_x - min_x) + MARGEN_LIENZO_PX * 2
	var alto: int = ceili(max_y - min_y) + MARGEN_LIENZO_PX * 2
	var origen := Vector2i(MARGEN_LIENZO_PX - roundi(min_x), MARGEN_LIENZO_PX - roundi(min_y))

	var lienzo := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	lienzo.blit_rect(img_mesa, Rect2i(Vector2i.ZERO, img_mesa.get_size()), origen)
	var destino_crt_px := Vector2i(origen) + Vector2i(roundi(offset_crt.x), roundi(offset_crt.y))
	lienzo.blend_rect(img_crt, Rect2i(Vector2i.ZERO, img_crt.get_size()), destino_crt_px)

	var ruta_salida: String = "%smesa_basica_compuesta_%d.png" % [CARPETA_SCRATCH, rot]
	var err: Error = lienzo.save_png(ruta_salida)
	if err != OK:
		push_error("[COMPONER MESA CRT] save_png '%s' fallo (error %d)" % [ruta_salida, err])
	else:
		print("[COMPONER MESA CRT] %d: mesa %dx%d + CRT %dx%d -> %dx%d | semiejes_mesa=%s x_local=%d fila_tope=%d punto_superficie=%s offset_crt=%s -> %s" % [
			rot, img_mesa.get_width(), img_mesa.get_height(), img_crt.get_width(), img_crt.get_height(),
			ancho, alto, semiejes_mesa, x_local, fila_tope, punto_superficie, offset_crt, ruta_salida
		])


## La fila opaca más alta de la columna `x`, amortiguada con la MEDIANA de una ventana de columnas
## vecinas (mismo patrón que `_demo_props_pipeline._fila_en`, sin depender de una tabla precalculada
## por columna -- aquí solo hace falta UNA columna por rotación, así que se mide bajo demanda).
func _fila_tope_en(img: Image, x: int, ventana: int = 6) -> int:
	var ancho: int = img.get_width()
	var alto: int = img.get_height()
	var muestras: Array[int] = []
	for dx: int in range(-ventana, ventana + 1):
		var cx: int = clampi(x + dx, 0, ancho - 1)
		for py: int in range(alto):
			if img.get_pixel(cx, py).a > 0.05:
				muestras.append(py)
				break
	if muestras.is_empty():
		return 0
	muestras.sort()
	return muestras[muestras.size() / 2]
