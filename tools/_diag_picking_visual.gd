extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — BUG "cursor desviado" (2026-08-06). DOS rondas:
##
## RONDA 1 (picking): verifica que el resaltado en vivo de `ModoConstruccion` acierta la celda que
## el jugador VE cuando el punto cae sobre la CARA VISIBLE de un muro (65px, `ParedesSalas.
## ALTO_PARED`), en vez de la celda de DETRÁS. Ya PASA 4/4 (ver sesión previa) — se mantiene igual.
##
## RONDA 2 (dibujo, ESTA REVISIÓN — "sigue desviado, no tanto como antes" jugando con zoom/pan):
## el bug real de la ronda 2 no era de PICKING sino de DIBUJO — el fantasma vivía en una
## `CanvasLayer` de transform identidad, ajena a la cámara del juego (`Main._camara`, zoom/pan
## desde 2026-08-04); con zoom≠1 el rombo se pintaba en coordenadas de MUNDO dentro de un lienzo
## que las trataba como PANTALLA directa. Fix: `ModoConstruccion._capa_preview` (nueva
## `CanvasLayer`) con `.transform` igualado a `get_canvas_transform()` cada frame — ver
## `modo_construccion.gd::_crear_ui`/`_process`. Esta sonda fuerza la MISMA cámara (zoom=1.65,
## pan=(-137,58)) que ya usa `tools/_diag_celda_bajo_cursor_vs_muro.gd::_probar_camino_real_con_
## camara`, y dibuja una CRUZ ROJA en el punto de pantalla "del cursor" (en una CanvasLayer aparte,
## de transform identidad — la representación fiel de "aquí está el ratón" en la textura final) al
## lado del rombo verde del fantasma: si el fix es correcto, la cruz cae DENTRO del rombo en las 4
## capturas. El número ±3px no es una medida de píxeles de la imagen (evitar image-diffing en una
## sonda desechable): compara la transformada REAL del motor (`_modo.get_canvas_transform()`, la
## MISMA que usa `_capa_preview` tras el fix) contra la fórmula documentada en `Main._cambiar_zoom`
## (`mundo = pantalla·zoom + posición`) — si coinciden, el rombo (dibujado con esa transformada) y
## la cruz (puesta con la fórmula) caen en el MISMO sitio por construcción matemática, y la imagen
## solo hace falta para el vistazo humano, no para el veredicto numérico.
##
## Mismo patrón que `_diag_ux_pintura.gd`: SubViewport, `ModoConstruccion.set_process(false)` (sin
## `_process` en vivo, así que `_capa_preview.transform` NO se actualiza sola -- esta sonda hace a
## mano lo que `_process` haría: `_modo._capa_preview.transform = _modo.get_canvas_transform()`).
##
## La CELDA (qué tramo se selecciona) se sigue leyendo con `_celda_lado_de_muro_en(punto_mundo)`
## directo (ronda 1, sin tocar): `warp_mouse` en un `SubViewport` suelto no da la posición real
## (1er intento de la ronda 1, descartado — ver el historial de este fichero). Esta ronda 2 SOLO
## añade la cámara y la verificación de DIBUJO; la lógica de picking no cambia.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(900, 700)
const COLUMNAS: int = 6
const FILAS: int = 10
const TOLERANCIA_PX: float = 3.0

## MISMOS valores que `_diag_celda_bajo_cursor_vs_muro.gd::_probar_camino_real_con_camara` (pedido
## explícito: comparar la misma cámara en la sonda numérica y en la visual).
const CAMARA_ZOOM: float = 1.65
const CAMARA_POS := Vector2(-137.0, 58.0)

## Carpeta del scratchpad de ESTA sesión (fuera del repo — PROHIBIDO escribir en assets/capturas/).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

## Una sala de 1 celda de alto por fila de prueba (mismo fixture que la sonda numérica y el test de
## regresión): así cada una tiene su PROPIO tramo norte exactamente en su fila.
const FILAS_DE_PRUEBA: Array[int] = [1, 3, 6, 8]

## La cruz que marca "aquí está el cursor" -- CanvasLayer de transform IDENTIDAD (screen space de
## verdad, la misma naturaleza que tenía el fantasma ANTES del fix, a propósito: es el testigo fijo
## contra el que se compara el rombo, que ahora SÍ seguirá la cámara).
class Cruz extends Node2D:
	const COLOR := Color(1.0, 0.15, 0.1, 0.95)
	const RADIO := 12.0
	func _draw() -> void:
		draw_line(Vector2(-RADIO, 0), Vector2(RADIO, 0), COLOR, 3.0)
		draw_line(Vector2(0, -RADIO), Vector2(0, RADIO), COLOR, 3.0)
		draw_circle(Vector2.ZERO, 3.0, COLOR)

var _sub: SubViewport
var _construccion: Node
var _paredes: Node2D
var _modo: Node2D
var _camara: Camera2D
var _cruz: Cruz
var _origen: Vector2


func _ready() -> void:
	_montar()
	await RenderingServer.frame_post_draw
	var resultados: Array[bool] = []
	for i: int in FILAS_DE_PRUEBA.size():
		resultados.append(await _capturar_fila(FILAS_DE_PRUEBA[i], i + 1))
	var pasa_todo: bool = not resultados.has(false)
	print("[DIAG PICKING VISUAL] RESUMEN: %d/%d PASA -> %s" % [
		resultados.count(true), resultados.size(), "PASA" if pasa_todo else "FALLA",
	])
	get_tree().quit()


## Una sala por fila de prueba (tira de `COLUMNAS` de ancho, 1 celda de alto), con muros reales, más
## la cámara con zoom/pan forzados y la cruz testigo.
func _montar() -> void:
	_sub = SubViewport.new()
	_sub.size = TAM_RENDER
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)
	var capa_fondo := CanvasLayer.new()
	capa_fondo.layer = -1
	_sub.add_child(capa_fondo)
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.14, 0.16)
	fondo.size = Vector2(TAM_RENDER)
	capa_fondo.add_child(fondo)
	var mundo := Node2D.new()
	_sub.add_child(mundo)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)
	_paredes = ParedesSalasScript.new()
	profundo.add_child(_paredes)

	var eco: Node = EconomiaScript.new()
	mundo.add_child(eco)
	eco.aplicar_config(ConfigEconomiaScript.new())
	eco.abonar(500000.0)
	_construccion = ConstruccionScript.new()
	mundo.add_child(_construccion)
	_construccion.aplicar_config(ConfigConstruccionScript.new())
	_construccion.usar_economia(eco)
	_construccion.edificio_columnas = COLUMNAS
	_construccion.edificio_filas = FILAS

	_origen = ProyeccionScript.origen_centrado(COLUMNAS, FILAS, Vector2(TAM_RENDER))
	_construccion.montar_visual(TAM_CELDA, _origen, profundo)

	for fila: int in FILAS_DE_PRUEBA:
		var sala: StringName = _construccion.construir_de_oficio_sala(
			&"sala_documentacion", Rect2i(0, fila, COLUMNAS, 1)
		)
		_construccion.fijar_paredes_de_sala(sala, true)

	_paredes.configurar(_construccion, TAM_CELDA, _origen)
	_construccion.fijar_hook_layout(Callable(_paredes, "actualizar"))

	# LA CÁMARA (RONDA 2) -- mismo `ANCHOR_MODE_FIXED_TOP_LEFT` que `Main._crear_camara`, hija de
	# `mundo` (el MISMO padre que `_modo`, igual que en `main.gd` los dos cuelgan de `Main`): así
	# `_modo.get_canvas_transform()` refleja esta cámara.
	_camara = Camera2D.new()
	_camara.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	_camara.zoom = Vector2(CAMARA_ZOOM, CAMARA_ZOOM)
	_camara.position = CAMARA_POS
	mundo.add_child(_camara)
	_camara.make_current()

	_modo = ModoConstruccionScript.new()
	_modo.configurar(_construccion, TAM_CELDA, _paredes)
	mundo.add_child(_modo)   # dispara _ready(): crea la UI, la rejilla, el velo de zonas y `_capa_preview`
	# `_process` OFF a propósito (ver cabecera): el ratón real de la sonda no está sobre el
	# tablero, y `_process` en vivo apagaría el fantasma cada frame. Como consecuencia, NADIE
	# actualiza `_capa_preview.transform` solo -- esta sonda lo hace a mano por cada captura
	# (`_capturar_fila`), justo lo que haría la primera línea de `_process` si estuviera encendido.
	_modo.set_process(false)
	_modo._activo = true
	_modo._actualizar_visibilidad()

	# LA CRUZ testigo: CanvasLayer APARTE de transform identidad (screen space real), por ENCIMA de
	# todo (layer alto) para que se vea siempre sobre el rombo.
	var capa_cruz := CanvasLayer.new()
	capa_cruz.layer = 10
	_sub.add_child(capa_cruz)
	_cruz = Cruz.new()
	capa_cruz.add_child(_cruz)


## Un punto de prueba (media altura del tramo norte de la celda (2, fila)): dibuja el rombo del
## fantasma (con la cámara aplicada, tras el fix) y la cruz testigo en el punto de pantalla
## correspondiente, y compara AMBAS transformadas mundo→pantalla (la fórmula documentada vs. la
## real del motor) para el veredicto PASA/FALLA ±3px.
func _capturar_fila(fila: int, indice: int) -> bool:
	var celda_columna := 2
	var desde: Vector2 = _construccion.esquina_en_pantalla(celda_columna, fila)
	var hasta: Vector2 = _construccion.esquina_en_pantalla(celda_columna + 1, fila)
	var punto_mundo: Vector2 = (
		desde.lerp(hasta, 0.5) + Vector2(0.0, -ParedesSalasScript.ALTO_PARED * 0.5)
	)

	# 1) LA CELDA (ronda 1, sin cambios): picking directo, camera-independiente -- ver la cabecera.
	var celda_obtenida: Vector2i = (_modo._celda_lado_de_muro_en(punto_mundo) as Array)[0]
	var celda_esperada := Vector2i(celda_columna, fila)

	# 2) EL DIBUJO (ronda 2): lo que haría `_process` cada frame si estuviera encendido.
	_modo._capa_preview.transform = _modo.get_canvas_transform()
	_modo._preview_caja.visible = true
	_modo._preview_texto.visible = false
	_modo._colocar_caja(celda_obtenida, Vector2i.ONE, Color(0.2, 0.9, 0.3, 0.55))
	_modo._preview_caja.queue_redraw()

	# 3) LA CRUZ: dónde "está el cursor" en pantalla. 🐛 FIX (2026-08-06): la fórmula estaba al
	#    revés -- comprobado contra `get_canvas_transform()` real del motor, con
	#    `ANCHOR_MODE_FIXED_TOP_LEFT` es `mundo = pantalla/zoom + posición` -> `pantalla = (mundo -
	#    posición) * zoom` (MULTIPLICAR). El comentario viejo de `Main._cambiar_zoom` decía lo
	#    contrario -- YA CORREGIDO ahí (bug real de juego: cada zoom con la rueda desviaba la vista).
	var punto_pantalla_formula: Vector2 = (punto_mundo - CAMARA_POS) * CAMARA_ZOOM
	_cruz.position = punto_pantalla_formula
	_cruz.queue_redraw()

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	# 4) EL VEREDICTO NUMÉRICO: la transformada REAL del motor (la misma que ahora usa
	#    `_capa_preview` tras el fix) contra la fórmula de arriba, sobre el MISMO punto de mundo. Si
	#    coinciden, rombo y cruz caen en el mismo sitio en la imagen por construcción.
	var punto_pantalla_motor: Vector2 = _modo.get_canvas_transform() * punto_mundo
	var distancia: float = punto_pantalla_motor.distance_to(punto_pantalla_formula)
	var pasa: bool = distancia <= TOLERANCIA_PX and celda_obtenida == celda_esperada
	print(
		(
			"[DIAG PICKING VISUAL] fila=%d celda_obtenida=%s celda_esperada=%s "
			+ "cruz(formula)=%s rombo(motor)=%s distancia_px=%.2f -> %s"
		)
		% [
			fila, celda_obtenida, celda_esperada,
			punto_pantalla_formula, punto_pantalla_motor, distancia,
			"PASA" if pasa else "FALLA",
		]
	)
	_guardar("picking_visual_camara_%d_fila%d.png" % [indice, fila])
	return pasa


func _guardar(nombre: String) -> void:
	var ruta: String = CARPETA_SALIDA + nombre
	var err: Error = _sub.get_texture().get_image().save_png(ruta)
	if err != OK:
		push_error("[DIAG PICKING VISUAL] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DIAG PICKING VISUAL] -> %s" % ruta)
