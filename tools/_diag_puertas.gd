extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — LOS DOS BUGS DE PUERTAS (2026-08-03).
##
## Reproduce con el CÓDIGO REAL (`Construccion` + `ParedesSalas` + `ModoConstruccion`, sin mocks) lo
## que reportó el usuario jugando:
##
##  (a) *"la puerta SOLO se deja colocar en una única zona de la pared que aparece blanca"*.
##  (b) PUERTAS FANTASMA: *"lo intenté en varios sitios (parecía que no dejaba), la puse en la zona
##      blanca… y DESPUÉS aparecieron puertas donde había hecho los clics rechazados"*.
##
## ⚠️ Las puertas se colocan POR EL MISMO CAMINO QUE EL CLIC DEL JUGADOR: se fabrica un
## `InputEventMouseButton` y se mete por `ModoConstruccion._unhandled_input` — nunca llamando a
## `Construccion.fijar_tipo_de_muro` por atajo. Si el bug estuviera en la traducción clic → arista,
## un atajo por el modelo lo taparía.
##
## Sin cámara y a escala 1:1 (como Main): así el fantasma del modo construcción —que vive en una
## `CanvasLayer`— cae exactamente donde caería en el juego.
##
## VEREDICTO PROGRAMÁTICO (no "a ojo" sobre el PNG): se compara el MODELO (`muros()` + tipo) contra
## la GEOMETRÍA REALMENTE DIBUJADA (`ParedesSalas._tramos`). Una puerta dibujada deja el centro del
## tramo LIBRE y los dos extremos pintados; un tabique cubre el centro.
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")

const TAM_CELDA: int = 40
## El edificio entero (24×13) proyectado mide 1480×740: el viewport lo encuadra sin cámara, para
## que mundo y pantalla coincidan igual que en Main.
const TAM_RENDER := Vector2i(1520, 800)
## La sala de pruebas: columnas 3..8, filas 3..7.
const RECT_SALA := Rect2i(3, 3, 6, 5)

## Carpeta del scratchpad de esta sesión (fuera del repo — PROHIBIDO escribir en assets/capturas/).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"

## Sufijo de los PNG de esta pasada ("antes"/"despues"): lo pasa el runner (`-- antes`).
var _sufijo: String = "antes"
## Se pone a true en cuanto una comprobación falla: decide el código de salida del proceso.
var _fallos: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg != "":
			_sufijo = arg
	await _caso_tres_puertas()
	print("[DIAG PUERTAS] hecho (%s) — fallos=%d — ver %spuertas_*_%s.png" % [
		_sufijo, _fallos, CARPETA_SALIDA, _sufijo
	])
	get_tree().quit(0 if _fallos == 0 else 1)


# ── EL CASO ───────────────────────────────────────────────────────────────────────────────────

## Una sala con paredes, tres puertas colocadas con el ratón en TRES tramos distintos (norte, sur y
## este) y un cuarto clic INVÁLIDO (una arista interior, donde no hay pared que convertir).
##
## Lo que se demuestra, en este orden:
##   1. El estado de muros ANTES de tocar nada.
##   2. Los tres clics válidos → ¿aparecen las tres puertas DIBUJADAS?
##   3. El clic inválido → ¿el volcado del modelo queda BIT A BIT idéntico?
##   4. El disparador del fantasma: se derriba UN tramo del perímetro (la sala deja de estar "con
##      paredes") y se vuelve a fotografiar. Si en esa foto aparecen puertas que antes no se veían,
##      es que estaban guardadas en el modelo sin haberse dibujado nunca.
func _caso_tres_puertas() -> void:
	var origen: Vector2 = ProyeccionScript.origen_centrado(24, 13, Vector2(TAM_RENDER))
	var piezas: Array = _montar(origen)
	var sub: SubViewport = piezas[0]
	var mundo: Node2D = piezas[1]
	var construccion: Node = piezas[2]
	var paredes: Node = piezas[3]

	construccion.levantar_fachada()
	var sala: StringName = construccion.construir_de_oficio_sala(&"sala_documentacion", RECT_SALA)
	construccion.fijar_paredes_de_sala(sala, true)
	paredes.configurar(construccion, TAM_CELDA, origen)
	# El hook de layout es lo que en Main repinta las paredes tras CADA cambio del modelo.
	construccion.fijar_hook_layout(Callable(paredes, "actualizar"))

	var modo: Node2D = ModoConstruccionScript.new()
	modo.configurar(construccion, TAM_CELDA)
	mundo.add_child(modo)
	modo.activar_con_herramienta(&"puerta", false)

	# ── 1) Estado de partida ────────────────────────────────────────────────────────────────
	var muros_inicio: String = _volcar_muros(construccion)
	print("[DIAG PUERTAS] muros al empezar: %d aristas" % construccion.muros().size())
	print("[DIAG PUERTAS] hueco automatico de la sala (clave modelo): %s" % _clave_puerta_auto(paredes, sala))
	await _capturar(sub, "0_sala_cerrada", origen, false)

	# ── 2) Tres puertas en tres tramos distintos, por el camino del clic ────────────────────
	var objetivos: Array = [
		["norte", Vector2i(5, 3), &"arriba"],
		["sur", Vector2i(5, 7), &"abajo"],
		["este", Vector2i(8, 5), &"derecha"],
	]
	for objetivo: Array in objetivos:
		_clic_izquierdo(modo, construccion, origen, objetivo[1], objetivo[2])
		print("[DIAG PUERTAS] clic %s -> celda=%s lado=%s | tipo en el modelo='%s'" % [
			objetivo[0], objetivo[1], objetivo[2],
			construccion.tipo_de_muro(objetivo[1], objetivo[2]),
		])
	await _capturar(sub, "1_tres_puertas", origen, true)

	# ── 3) Clic INVÁLIDO: arista interior, sin pared que convertir ──────────────────────────
	var muros_antes_invalido: String = _volcar_muros(construccion)
	_clic_izquierdo(modo, construccion, origen, Vector2i(5, 5), &"arriba")
	var muros_despues_invalido: String = _volcar_muros(construccion)
	_afirmar(
		muros_antes_invalido == muros_despues_invalido,
		"el clic INVALIDO no deja rastro en el modelo (volcado identico)"
	)
	await _capturar(sub, "2_tras_clic_invalido", origen, true)

	# ── VEREDICTO: modelo contra lo que de verdad está pintado ──────────────────────────────
	_auditar(construccion, paredes, sala, objetivos, origen)

	# ── 4) El disparador del fantasma: la sala deja de estar "con paredes" ──────────────────
	# Se derriba UN tramo del perímetro (lo que haría el jugador con la herramienta de demoler).
	# Si las puertas de arriba estaban guardadas y NO dibujadas, aquí es donde aparecen de golpe.
	var dibujadas_antes: int = _puertas_dibujadas(construccion, paredes, objetivos, origen)
	construccion.demoler_muro(Vector2i(3, 5), &"izquierda")
	var dibujadas_despues: int = _puertas_dibujadas(construccion, paredes, objetivos, origen)
	print("[DIAG PUERTAS] FANTASMA: puertas DIBUJADAS antes de romper el perimetro=%d, despues=%d" % [
		dibujadas_antes, dibujadas_despues
	])
	_afirmar(
		dibujadas_antes == dibujadas_despues,
		"ninguna puerta APARECE de golpe al romper el perimetro (sin estado fantasma)"
	)
	await _capturar(sub, "3_fantasma", origen, true)
	print("[DIAG PUERTAS] (muros al empezar, para el diff manual)\n%s" % muros_inicio)


# ── AUDITORÍA: el modelo contra los píxeles ───────────────────────────────────────────────────

## Compara, arista a arista, lo que dice el MODELO con lo que `ParedesSalas` ha puesto a dibujar.
func _auditar(
	construccion: Node, paredes: Node, sala: StringName, objetivos: Array, origen: Vector2
) -> void:
	var clave_hueco: String = _clave_puerta_auto(paredes, sala)
	var puertas_modelo: int = 0
	var puertas_con_hueco: int = 0
	var tabiques_solidos: int = 0
	var tabiques_agujereados: Array[String] = []
	for clave: String in construccion.muros():
		var tipo: StringName = construccion.tipo_muro_de_clave(clave)
		var geo: Array = _geometria_de_clave(clave, origen)
		var medio: Vector2 = (geo[0] as Vector2).lerp(geo[1] as Vector2, 0.5)
		var hay_hueco: bool = not _cubierto(paredes, medio)
		if tipo == &"puerta":
			puertas_modelo += 1
			if hay_hueco:
				puertas_con_hueco += 1
			else:
				print("[DIAG PUERTAS]   ✗ PUERTA en el modelo pero DIBUJADA MACIZA: %s" % clave)
		elif clave != clave_hueco:
			if hay_hueco:
				tabiques_agujereados.append(clave)
			else:
				tabiques_solidos += 1
	print("[DIAG PUERTAS] MODELO: %d puertas | DIBUJADAS con hueco: %d" % [
		puertas_modelo, puertas_con_hueco
	])
	print("[DIAG PUERTAS] tabiques solidos: %d | tabiques con hueco indebido: %s" % [
		tabiques_solidos, tabiques_agujereados
	])
	# Esperado: 2 puertas de fachada (el acceso, `levantar_fachada`) + las 3 del jugador.
	_afirmar(puertas_modelo == 5, "el modelo tiene 5 puertas (2 de fachada + 3 colocadas), no mas")
	_afirmar(puertas_con_hueco == puertas_modelo, "TODAS las puertas del modelo se DIBUJAN como puerta")
	_afirmar(tabiques_agujereados.is_empty(), "ningun tabique se dibuja con hueco")
	# Y las tres del jugador, una a una, con su firma completa de puerta (extremos pintados + centro
	# libre): así no cuela un tramo que simplemente no se haya dibujado.
	for objetivo: Array in objetivos:
		var geo: Array = _geometria_de_arista(construccion, objetivo[1], objetivo[2])
		var desde: Vector2 = geo[0]
		var hasta: Vector2 = geo[1]
		var firma_ok: bool = (
			_cubierto(paredes, desde.lerp(hasta, 0.10))
			and not _cubierto(paredes, desde.lerp(hasta, 0.50))
			and _cubierto(paredes, desde.lerp(hasta, 0.90))
		)
		_afirmar(firma_ok, "la puerta %s se dibuja con sus dos jambas y su hueco" % objetivo[0])


## Cuántas de las puertas colocadas por el jugador están AHORA MISMO dibujadas como puerta.
func _puertas_dibujadas(
	construccion: Node, paredes: Node, objetivos: Array, _origen: Vector2
) -> int:
	var total: int = 0
	for objetivo: Array in objetivos:
		if construccion.tipo_de_muro(objetivo[1], objetivo[2]) != &"puerta":
			continue
		var geo: Array = _geometria_de_arista(construccion, objetivo[1], objetivo[2])
		if not _cubierto(paredes, (geo[0] as Vector2).lerp(geo[1] as Vector2, 0.5)):
			total += 1
	return total


func _afirmar(condicion: bool, que: String) -> void:
	if condicion:
		print("[DIAG PUERTAS] ✓ %s" % que)
		return
	_fallos += 1
	print("[DIAG PUERTAS] ✗ FALLA: %s" % que)


# ── El camino del CLIC (el mismo del jugador) ─────────────────────────────────────────────────

## Un clic izquierdo (pulsar + soltar) sobre el punto de la celda pegado a `lado`. Entra por
## `_unhandled_input`, así que pasa por `_punto_mundo_del_evento`, `celda_de_punto` y
## `_lado_mas_cercano` exactamente igual que el del jugador.
func _clic_izquierdo(
	modo: Node2D, construccion: Node, origen: Vector2, celda: Vector2i, lado: StringName
) -> void:
	var punto_mundo: Vector2 = _punto_junto_al_lado(origen, celda, lado)
	# Comprobación del propio diagnóstico: el punto elegido tiene que volver a dar ESA celda y ESE
	# lado. Si no, el clic estaría probando otra arista y el veredicto no valdría nada.
	var celda_leida: Vector2i = construccion.celda_de_punto(punto_mundo)
	if celda_leida != celda:
		push_error("[DIAG PUERTAS] el punto de %s cae en la celda %s" % [celda, celda_leida])
		_fallos += 1
	for pulsado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = pulsado
		evento.position = modo.get_canvas_transform() * punto_mundo
		modo._unhandled_input(evento)


## Un punto de MUNDO dentro de `celda` y pegado a `lado` (el sitio donde pincharía el jugador para
## apuntar a esa arista): 10 % del lado hacia dentro, medido en el plano cuadrado.
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


# ── Lectura del modelo y de lo dibujado ───────────────────────────────────────────────────────

## Volcado ORDENADO y estable del modelo de muros: "clave=tipo" por línea. Dos volcados iguales =
## el modelo no se movió ni un bit.
func _volcar_muros(construccion: Node) -> String:
	var claves: Array[String] = construccion.muros()
	claves.sort()
	var lineas: PackedStringArray = PackedStringArray()
	for clave: String in claves:
		lineas.append("%s=%s" % [clave, construccion.tipo_muro_de_clave(clave)])
	return "\n".join(lineas)


## Los dos extremos (en MUNDO) de la arista `lado` de `celda`.
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


## Los dos extremos (en MUNDO) de una arista dada por su CLAVE de modelo ("v:col:row"/"h:col:row").
func _geometria_de_clave(clave: String, origen: Vector2) -> Array:
	var partes: PackedStringArray = clave.split(":")
	var a: int = int(partes[1])
	var b: int = int(partes[2])
	if partes[0] == "v":
		return [
			origen + ProyeccionScript.esquina_iso(a, b),
			origen + ProyeccionScript.esquina_iso(a, b + 1),
		]
	return [
		origen + ProyeccionScript.esquina_iso(a, b),
		origen + ProyeccionScript.esquina_iso(a + 1, b),
	]


## ¿Hay ALGÚN tramo de pared pintado sobre ese punto? (tolerancia de 1 px: los tramos son segmentos
## exactos de la rejilla, no hace falta más).
func _cubierto(paredes: Node, punto: Vector2) -> bool:
	for tramo: Dictionary in paredes._tramos:
		if _distancia_a_segmento(punto, tramo["desde"], tramo["hasta"]) <= 1.0:
			return true
	return false


func _distancia_a_segmento(punto: Vector2, a: Vector2, b: Vector2) -> float:
	return punto.distance_to(Geometry2D.get_closest_point_to_segment(punto, a, b))


## La clave de MODELO del hueco automático de la sala (el que `ParedesSalas` deja sin pintar). Se
## pide a `ParedesSalas` y se traduce a la convención de `Construccion` (la traducción es la misma
## en los dos sentidos: solo intercambia los dos números en las aristas "h").
func _clave_puerta_auto(paredes: Node, sala: StringName) -> String:
	var clave_paredes: String = paredes._clave_de_puerta(sala)
	if clave_paredes == "":
		return ""
	return paredes._clave_equivalente_en_paredes(clave_paredes)


# ── Montaje y captura ─────────────────────────────────────────────────────────────────────────

## Un SubViewport montado como Main: SIN cámara (mundo == pantalla) y con la bolsa de y-sort
## compartida. Devuelve [sub, mundo, construccion, paredes, profundo].
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


## Guarda el PNG completo y, si `zoom`, además un recorte ampliado (×3, vecino más próximo) alrededor
## de la sala de pruebas: el hueco de una puerta mide 40 px de los 80 del rombo y en plano general se
## juzga mal.
func _capturar(sub: SubViewport, nombre: String, origen: Vector2, zoom: bool) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	_guardar(imagen, nombre)
	if not zoom:
		return
	var esquinas: Array[Vector2] = [
		origen + ProyeccionScript.esquina_iso(RECT_SALA.position.x, RECT_SALA.position.y),
		origen + ProyeccionScript.esquina_iso(RECT_SALA.end.x, RECT_SALA.position.y),
		origen + ProyeccionScript.esquina_iso(RECT_SALA.end.x, RECT_SALA.end.y),
		origen + ProyeccionScript.esquina_iso(RECT_SALA.position.x, RECT_SALA.end.y),
	]
	var caja := Rect2(esquinas[0], Vector2.ZERO)
	for punto: Vector2 in esquinas:
		caja = caja.expand(punto)
	caja = caja.grow(50.0)
	var recorte: Rect2i = Rect2i(caja).intersection(Rect2i(Vector2i.ZERO, TAM_RENDER))
	var trozo: Image = imagen.get_region(recorte)
	trozo.resize(recorte.size.x * 3, recorte.size.y * 3, Image.INTERPOLATE_NEAREST)
	_guardar(trozo, nombre + "_zoom")


func _guardar(imagen: Image, nombre: String) -> void:
	var ruta: String = "%spuertas_%s_%s.png" % [CARPETA_SALIDA, nombre, _sufijo]
	var err: Error = imagen.save_png(ruta)
	if err != OK:
		push_error("[DIAG PUERTAS] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DIAG PUERTAS] %s -> %s" % [nombre, ruta])
