extends Node2D
## _componer_bloques_ventanilla — DESECHABLE (2026-08-07). Monta los 2 compuestos "sobremesa"
## que faltan para la hoja final, mismo patrón que `_componer_mesa_basica_crt.gd`
## (`AnclajeSprite` + fila-tope medida real de la columna, "patrón sobremesa"):
##
##  · `mesa_basica_0.png` + `crt_antiguo_180.png` (pantalla mirando NORTE -- verificado por
##    geometría, ver el informe: familia "visible/hacia cámara" = rotaciones {0°,90°} para TODAS
##    las piezas de este lote (silla_oficina, sillas candidatas, crt_antiguo, equipo_informatico) ->
##    únicamente consistente con el ciclo norte→oeste→sur→este si facing(0°)=SUR, de donde
##    facing(180°)=NORTE) -> `mesa_basica_compuesta_0.png`.
##  · `mesa_media_180.png` (mampara al SUR -- misma familia, el lado con cajonera/hueco de piernas
##    es el "visible" a {0°,90°}, así que facing(0°)=SUR para ESE lado y `mampara_facing(180°)` =
##    SUR, opuesto) + `comodidad_equipo_informatico_180.png` (pantalla NORTE, mismo argumento que
##    el CRT) -> `mesa_media_compuesta_0.png` (nombrado "_0" porque es la ÚNICA vista que pide la
##    hoja, la vista con la mampara ya orientada correctamente).
##
## Escribe SOLO al scratchpad -- PROHIBIDO tocar assets/sprites/mobiliario/.

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"
const CARPETA_MOBILIARIO := "res://assets/sprites/mobiliario/"

const FRACCION_SUR: float = 0.5
const MARGEN_LIENZO_PX: int = 8


func _ready() -> void:
	# Básica + CRT antiguo (nuevo, del scratchpad).
	_componer(
		"mesa_basica_0", CARPETA_SCRATCH + "mesa_basica_0.png",
		"crt_antiguo_180", CARPETA_SCRATCH + "crt_antiguo_180.png",
		"mesa_basica_compuesta_0"
	)
	# Media (mampara ya al sur, vista 180 de su propio render) + monitor INDIVIDUAL (no el cluster
	# de 2 pantallas -- asomaba por encima de la mampara, aviso del usuario 2026-08-07). Monitor
	# único de OBJ_021 (`_render_monitor_unico.gd`, del scratchpad): a 0° el propio
	# `mesa_atencion.gd` documenta que este monitor está "de espaldas a cámara" -- pantalla mirando
	# al NORTE, exactamente lo que pide el encargo, sin tener que volver a determinarlo a ojo.
	_componer(
		"mesa_media_180", CARPETA_SCRATCH + "mesa_media_180.png",
		"monitor_unico_0", CARPETA_SCRATCH + "monitor_unico_0.png",
		"mesa_media_compuesta_0", true
	)
	print("[COMPONER BLOQUES] hecho.")
	get_tree().quit()


func _cargar(ruta: String) -> Image:
	if ruta.begins_with("res://"):
		var tex: Texture2D = load(ruta)
		if tex == null:
			push_error("[COMPONER BLOQUES] no se pudo cargar '%s'" % ruta)
			return null
		return tex.get_image()
	var img: Image = Image.load_from_file(ruta)
	if img == null:
		push_error("[COMPONER BLOQUES] no se pudo cargar '%s'" % ruta)
	return img


func _componer(
	nombre_mesa: String, ruta_mesa: String, nombre_aparato: String, ruta_aparato: String, id_salida: String,
	anclar_por_arriba: bool = false
) -> void:
	var img_mesa: Image = _cargar(ruta_mesa)
	var img_aparato: Image = _cargar(ruta_aparato)
	if img_mesa == null or img_aparato == null:
		return
	var tex_aparato: Texture2D = ImageTexture.create_from_image(img_aparato)
	var centro_aparato: Vector2 = AnclajeSpriteScript.centro_base(tex_aparato)

	# 1) BUG corregido (2026-08-07, aviso del usuario: "el CRT sale flotando"): el primer intento
	# usaba `AnclajeSprite.centro_base`/`semiejes_base` (pensados para el footprint a NIVEL DE
	# SUELO) desplazado hacia el "sur" y luego miraba la fila-tope de ESA columna -- para una mesa
	# con forma en "V" (el borde norte+oeste del tablero, las dos únicas aristas visibles desde esta
	# cámara, se juntan en un VÉRTICE), ese punto caía casi exactamente EN el vértice (la esquina
	# MÁS ALTA de toda la silueta) en vez de en el CENTRO del tablero -- el aparato quedaba anclado
	# a una esquina, muy por encima de la superficie real de trabajo.
	#
	# Arreglo: se mide la fila-tope de CADA columna (silueta completa, mismo método que
	# `_demo_props_pipeline._medir_superficie_tablero`), se localiza el VÉRTICE (el mínimo -- la
	# esquina más lejana) y se coge el punto medio del brazo MÁS LARGO a partir de ahí -- el brazo
	# largo es la mitad del tablero con más superficie de trabajo real, lejos del vértice y lejos
	# del otro extremo (donde empiezan patas/cajonera, otra fuente de ruido).
	var ancho_mesa: int = img_mesa.get_width()
	var filas_por_columna: Array[int] = []
	var indice_vertice := 0
	var minimo := 999999
	for x: int in range(ancho_mesa):
		var f: int = _fila_tope_en(img_mesa, x, 0)  # sin ventana: valor crudo por columna, para hallar el vértice real
		filas_por_columna.append(f)
		if f < minimo:
			minimo = f
			indice_vertice = x
	var largo_izquierdo: int = indice_vertice
	var largo_derecho: int = ancho_mesa - 1 - indice_vertice
	var x_local: int
	if largo_derecho >= largo_izquierdo:
		x_local = indice_vertice + int(largo_derecho * 0.5)
	else:
		x_local = indice_vertice - int(largo_izquierdo * 0.5)
	x_local = clampi(x_local, 0, ancho_mesa - 1)

	# 2) La altura REAL del tablero en ESA columna -- fila-tope, amortiguada con ventana (ya lejos
	# del vértice, la ventana ya no se cuela por ninguna esquina).
	var fila_tope: int = _fila_tope_en(img_mesa, x_local)
	var punto_superficie := Vector2(float(x_local), float(fila_tope))

	# 3) Coloca el aparato.
	# Caso normal (CRT sobre mesa_basica): SU centro de base en el punto de superficie -- el
	# aparato se apoya EN el tablero y crece hacia arriba desde ahí.
	# Caso `anclar_por_arriba` (monitor sobre mesa_media, aviso del usuario 2026-08-07: "el monitor
	# asoma por encima de la mampara"): la fila-tope de esta mesa mide el borde de la MAMPARA (más
	# alta que el tablero, es lo primero opaco de arriba a abajo en esa columna), no el tablero --
	# anclar por la BASE pondría el monitor ENTERO por encima de la mampara. En su lugar se ancla
	# por el CENTRO SUPERIOR del propio sprite del monitor: su fila 0 (la parte más alta, la
	# pantalla) queda exactamente a la altura del borde de la mampara y el resto del cuerpo crece
	# hacia abajo (detrás/tras la mampara) -- nunca asoma por encima.
	var offset_aparato: Vector2
	if anclar_por_arriba:
		offset_aparato = Vector2(punto_superficie.x - float(img_aparato.get_width()) * 0.5, punto_superficie.y)
	else:
		offset_aparato = punto_superficie - centro_aparato

	var min_x: float = minf(0.0, offset_aparato.x)
	var min_y: float = minf(0.0, offset_aparato.y)
	var max_x: float = maxf(float(img_mesa.get_width()), offset_aparato.x + float(img_aparato.get_width()))
	var max_y: float = maxf(float(img_mesa.get_height()), offset_aparato.y + float(img_aparato.get_height()))
	var ancho: int = ceili(max_x - min_x) + MARGEN_LIENZO_PX * 2
	var alto: int = ceili(max_y - min_y) + MARGEN_LIENZO_PX * 2
	var origen := Vector2i(MARGEN_LIENZO_PX - roundi(min_x), MARGEN_LIENZO_PX - roundi(min_y))

	var lienzo := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	lienzo.blit_rect(img_mesa, Rect2i(Vector2i.ZERO, img_mesa.get_size()), origen)
	var destino_px := Vector2i(origen) + Vector2i(roundi(offset_aparato.x), roundi(offset_aparato.y))
	lienzo.blend_rect(img_aparato, Rect2i(Vector2i.ZERO, img_aparato.get_size()), destino_px)

	var ruta_salida: String = "%s%s.png" % [CARPETA_SCRATCH, id_salida]
	var err: Error = lienzo.save_png(ruta_salida)
	if err != OK:
		push_error("[COMPONER BLOQUES] save_png '%s' fallo (error %d)" % [ruta_salida, err])
	else:
		print("[COMPONER BLOQUES] %s (%s) + %s (%s) -> %dx%d | vertice_x=%d x_local=%d fila_tope=%d offset=%s -> %s" % [
			nombre_mesa, ruta_mesa, nombre_aparato, ruta_aparato, ancho, alto,
			indice_vertice, x_local, fila_tope, offset_aparato, ruta_salida
		])


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
