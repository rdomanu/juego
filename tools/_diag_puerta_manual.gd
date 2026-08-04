extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — LA PUERTA LA PONE EL JUGADOR (2026-08-04 · §3).
##
## Comprueba EN EL MOTOR, por el camino del CLIC (no llamando al modelo por atajo), que:
##   1. Amurallar una sala la deja CERRADA: cero aristas transitables en todo su perímetro y -1
##      (inalcanzable) desde fuera con el BFS de `distancia_en_celdas`.
##   2. Un clic con el pincel de puerta en el tramo que elige el jugador abre EXACTAMENTE ese tramo:
##      una sola arista transitable, y es la clicada.
##   3. Lo que se dibuja coincide con el modelo: antes, ni un hueco en el perímetro; después, el
##      hueco solo en la puerta abierta.
##
## Capturas con REJILLA (las líneas de celda del edificio, como el suelo del juego) para poder
## contar celdas sobre el PNG. Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 24
const FILAS: int = 13
const TAM_RENDER := Vector2i(1520, 800)
## La sala de pruebas y el tramo donde el jugador pondrá su puerta (lado ESTE, celda (8,5)).
const RECT_SALA := Rect2i(3, 3, 6, 5)
const PUERTA_CELDA := Vector2i(8, 5)
const PUERTA_LADO := &"derecha"
const CELDA_DENTRO := Vector2i(5, 5)
const CELDA_FUERA := Vector2i(15, 5)

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"

var _fallos: int = 0


func _ready() -> void:
	await _caso()
	print("[DIAG PUERTA MANUAL] hecho — fallos=%d" % _fallos)
	get_tree().quit(0 if _fallos == 0 else 1)


func _caso() -> void:
	var origen: Vector2 = ProyeccionScript.origen_centrado(COLUMNAS, FILAS, Vector2(TAM_RENDER))
	var piezas: Array = _montar(origen)
	var sub: SubViewport = piezas[0]
	var mundo: Node2D = piezas[1]
	var construccion: Node = piezas[2]
	var paredes: Node = piezas[3]

	construccion.levantar_fachada()
	var sala: StringName = construccion.construir_de_oficio_sala(&"sala_documentacion", RECT_SALA)
	construccion.fijar_paredes_de_sala(sala, true)
	paredes.configurar(construccion, TAM_CELDA, origen)
	construccion.fijar_hook_layout(Callable(paredes, "actualizar"))

	var modo: Node2D = ModoConstruccionScript.new()
	modo.configurar(construccion, TAM_CELDA)
	mundo.add_child(modo)
	# El gesto real: al amurallar, el modo se pone SOLO el pincel de puerta y lo dice arriba.
	modo.pedir_puerta_de_sala()

	# ── 1) Sala recién amurallada: recinto CERRADO ──────────────────────────────────────────
	var transitables: Array[String] = _aristas_transitables(construccion, sala)
	print("[DIAG PUERTA MANUAL] aristas transitables del perimetro tras amurallar: %d %s" % [
		transitables.size(), transitables
	])
	print("[DIAG PUERTA MANUAL] puerta_de_sala = %s | sala_amurallada_sin_puerta = %s" % [
		construccion.puerta_de_sala(sala), construccion.sala_amurallada_sin_puerta(sala)
	])
	var distancia_antes: int = construccion.distancia_en_celdas(CELDA_FUERA, CELDA_DENTRO)
	print("[DIAG PUERTA MANUAL] distancia fuera(%s) -> dentro(%s) = %d" % [
		CELDA_FUERA, CELDA_DENTRO, distancia_antes
	])
	_afirmar(transitables.is_empty(), "amurallar no deja NINGUNA arista transitable")
	_afirmar(distancia_antes == -1, "desde fuera no hay camino (-1): la sala esta cerrada")
	_afirmar(
		not _hay_hueco_dibujado(construccion, paredes, sala),
		"ningun tramo del perimetro se DIBUJA con hueco (murio el hueco automatico)"
	)
	await _capturar(sub, "puerta_manual_1_cerrada", origen)

	# ── 2) El clic del jugador en el tramo que elige ────────────────────────────────────────
	_clic_izquierdo(modo, construccion, origen, PUERTA_CELDA, PUERTA_LADO)
	var transitables_2: Array[String] = _aristas_transitables(construccion, sala)
	var distancia_despues: int = construccion.distancia_en_celdas(CELDA_FUERA, CELDA_DENTRO)
	print("[DIAG PUERTA MANUAL] tras el clic en %s/%s: transitables=%d %s | distancia=%d" % [
		PUERTA_CELDA, PUERTA_LADO, transitables_2.size(), transitables_2, distancia_despues
	])
	_afirmar(
		transitables_2 == [construccion.clave_de_muro(PUERTA_CELDA, PUERTA_LADO)],
		"se pasa por UNA sola arista, y es exactamente la clicada"
	)
	_afirmar(distancia_despues > 0, "ahora SI hay camino desde fuera")
	_afirmar(
		construccion.puerta_de_sala(sala) == PUERTA_CELDA,
		"el modelo reconoce esa celda como la puerta de la sala"
	)
	_afirmar(
		_dibujada_como_puerta(construccion, paredes, PUERTA_CELDA, PUERTA_LADO),
		"la puerta se DIBUJA con su hueco y sus dos munones"
	)
	await _capturar(sub, "puerta_manual_2_con_puerta", origen)


# ── Lecturas ──────────────────────────────────────────────────────────────────────────────────

## Las claves de las aristas del perímetro de la sala por las que SE PUEDE PASAR (las que la
## navegación no recorta). En una sala recién amurallada tiene que estar vacía.
func _aristas_transitables(construccion: Node, sala: StringName) -> Array[String]:
	var salida: Array[String] = []
	for x: int in range(RECT_SALA.position.x, RECT_SALA.end.x):
		for y: int in range(RECT_SALA.position.y, RECT_SALA.end.y):
			var celda := Vector2i(x, y)
			for paso: Array in [
				[&"izquierda", Vector2i(-1, 0)], [&"derecha", Vector2i(1, 0)],
				[&"arriba", Vector2i(0, -1)], [&"abajo", Vector2i(0, 1)],
			]:
				if construccion.sala_en(celda + (paso[1] as Vector2i)) == sala:
					continue   # arista interior, no es perímetro
				if construccion.deja_pasar(celda, paso[0]):
					salida.append(construccion.clave_de_muro(celda, paso[0]))
	salida.sort()
	return salida


## ¿Algún tramo del perímetro está dibujado con el centro LIBRE (o sea, como un hueco)?
func _hay_hueco_dibujado(construccion: Node, paredes: Node, sala: StringName) -> bool:
	for x: int in range(RECT_SALA.position.x, RECT_SALA.end.x):
		for y: int in range(RECT_SALA.position.y, RECT_SALA.end.y):
			var celda := Vector2i(x, y)
			for lado: StringName in [&"izquierda", &"derecha", &"arriba", &"abajo"]:
				if not construccion.hay_muro(celda, lado):
					continue
				if construccion.es_muro_fijo(construccion.clave_de_muro(celda, lado)):
					continue
				var geo: Array = _geometria_de_arista(construccion, celda, lado)
				if not _cubierto(paredes, (geo[0] as Vector2).lerp(geo[1] as Vector2, 0.5)):
					print("[DIAG PUERTA MANUAL]   hueco dibujado en %s/%s" % [celda, lado])
					return true
	return false


## Firma completa de una puerta dibujada: extremos pintados y centro libre.
func _dibujada_como_puerta(
	construccion: Node, paredes: Node, celda: Vector2i, lado: StringName
) -> bool:
	var geo: Array = _geometria_de_arista(construccion, celda, lado)
	var desde: Vector2 = geo[0]
	var hasta: Vector2 = geo[1]
	return (
		_cubierto(paredes, desde.lerp(hasta, 0.10))
		and not _cubierto(paredes, desde.lerp(hasta, 0.50))
		and _cubierto(paredes, desde.lerp(hasta, 0.90))
	)


func _geometria_de_arista(construccion: Node, celda: Vector2i, lado: StringName) -> Array:
	match lado:
		&"izquierda":
			return [
				construccion.esquina_en_pantalla(celda.x, celda.y),
				construccion.esquina_en_pantalla(celda.x, celda.y + 1),
			]
		&"derecha":
			return [
				construccion.esquina_en_pantalla(celda.x + 1, celda.y),
				construccion.esquina_en_pantalla(celda.x + 1, celda.y + 1),
			]
		&"arriba":
			return [
				construccion.esquina_en_pantalla(celda.x, celda.y),
				construccion.esquina_en_pantalla(celda.x + 1, celda.y),
			]
		_:
			return [
				construccion.esquina_en_pantalla(celda.x, celda.y + 1),
				construccion.esquina_en_pantalla(celda.x + 1, celda.y + 1),
			]


func _cubierto(paredes: Node, punto: Vector2) -> bool:
	for tramo: Dictionary in paredes._tramos:
		if punto.distance_to(
			Geometry2D.get_closest_point_to_segment(punto, tramo["desde"], tramo["hasta"])
		) <= 1.0:
			return true
	return false


func _afirmar(condicion: bool, que: String) -> void:
	if condicion:
		print("[DIAG PUERTA MANUAL] ✓ %s" % que)
		return
	_fallos += 1
	print("[DIAG PUERTA MANUAL] ✗ FALLA: %s" % que)


# ── El camino del CLIC (el mismo del jugador) ─────────────────────────────────────────────────

func _clic_izquierdo(
	modo: Node2D, construccion: Node, origen: Vector2, celda: Vector2i, lado: StringName
) -> void:
	var punto_mundo: Vector2 = _punto_junto_al_lado(origen, celda, lado)
	if construccion.celda_de_punto(punto_mundo) != celda:
		push_error("[DIAG PUERTA MANUAL] el punto de %s no cae en su celda" % celda)
		_fallos += 1
	for pulsado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = pulsado
		evento.position = modo.get_canvas_transform() * punto_mundo
		modo._unhandled_input(evento)


func _punto_junto_al_lado(origen: Vector2, celda: Vector2i, lado: StringName) -> Vector2:
	var base := Vector2(celda) * float(TAM_CELDA)
	var dentro: Vector2 = Vector2(0.5, 0.5) * float(TAM_CELDA)
	match lado:
		&"izquierda":
			dentro = Vector2(0.1, 0.5) * float(TAM_CELDA)
		&"derecha":
			dentro = Vector2(0.9, 0.5) * float(TAM_CELDA)
		&"arriba":
			dentro = Vector2(0.5, 0.1) * float(TAM_CELDA)
		&"abajo":
			dentro = Vector2(0.5, 0.9) * float(TAM_CELDA)
	return origen + ProyeccionScript.proyectar(base + dentro)


# ── Montaje, REJILLA y captura ────────────────────────────────────────────────────────────────

## La rejilla del edificio dibujada a mano (el `TileMapLayer` del juego no está aquí): sirve para
## contar celdas sobre el PNG y comprobar que la puerta cae donde se dijo.
class Rejilla extends Node2D:
	var origen: Vector2 = Vector2.ZERO

	func _draw() -> void:
		var color := Color(1, 1, 1, 0.12)
		for x: int in range(COLUMNAS + 1):
			draw_line(
				origen + ProyeccionScript.esquina_iso(x, 0),
				origen + ProyeccionScript.esquina_iso(x, FILAS), color, 1.0
			)
		for y: int in range(FILAS + 1):
			draw_line(
				origen + ProyeccionScript.esquina_iso(0, y),
				origen + ProyeccionScript.esquina_iso(COLUMNAS, y), color, 1.0
			)


func _montar(origen: Vector2) -> Array:
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
	var mundo := Node2D.new()
	sub.add_child(mundo)
	var rejilla := Rejilla.new()
	rejilla.origen = origen
	rejilla.z_index = -2
	mundo.add_child(rejilla)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)
	var paredes := ParedesSalasScript.new()
	profundo.add_child(paredes)
	var construccion := ConstruccionScript.new()
	construccion.aplicar_config(ConfigConstruccionScript.new())
	mundo.add_child(construccion)
	construccion.montar_visual(TAM_CELDA, origen, profundo)
	return [sub, mundo, construccion, paredes, profundo]


func _capturar(sub: SubViewport, nombre: String, origen: Vector2) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	_guardar(imagen, nombre)
	var esquinas: Array[Vector2] = [
		origen + ProyeccionScript.esquina_iso(RECT_SALA.position.x, RECT_SALA.position.y),
		origen + ProyeccionScript.esquina_iso(RECT_SALA.end.x, RECT_SALA.position.y),
		origen + ProyeccionScript.esquina_iso(RECT_SALA.end.x, RECT_SALA.end.y),
		origen + ProyeccionScript.esquina_iso(RECT_SALA.position.x, RECT_SALA.end.y),
	]
	var caja := Rect2(esquinas[0], Vector2.ZERO)
	for punto: Vector2 in esquinas:
		caja = caja.expand(punto)
	caja = caja.grow(60.0)
	var recorte: Rect2i = Rect2i(caja).intersection(Rect2i(Vector2i.ZERO, TAM_RENDER))
	var trozo: Image = imagen.get_region(recorte)
	trozo.resize(recorte.size.x * 2, recorte.size.y * 2, Image.INTERPOLATE_NEAREST)
	_guardar(trozo, nombre + "_zoom")


func _guardar(imagen: Image, nombre: String) -> void:
	var ruta: String = CARPETA_SALIDA + nombre + ".png"
	var err: Error = imagen.save_png(ruta)
	if err != OK:
		push_error("[DIAG PUERTA MANUAL] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DIAG PUERTA MANUAL] %s -> %s" % [nombre, ruta])
