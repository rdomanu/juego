extends Node2D
## DIAGNÓSTICO DESECHABLE — verifica EN EL MOTOR la petición del usuario 2026-08-04: *"al poner una
## puerta, que se respete el hueco por donde entran"* — el camino REAL de un NPC (navegación física,
## no el BFS lógico) debe cruzar EXACTAMENTE la arista de la puerta que el jugador abrió, y NUNCA
## ninguna otra arista amurallada de la sala (ni el resto del mismo lado, que es TABIQUE aparte).
##
## Dos casos EN PARALELO (misma escena, dos salas, dos servicios para que `_sitio_en_espera` no
## cruce sus huecos de pie entre sí):
##   CASO SUR:  sala Documentación (4,2)-(6,4). Puerta en el tramo SUR de (4,3) (`h:4:4`).
##              El otro medio del mismo lado, sur de (5,3) (`h:5:4`), se queda TABIQUE.
##   CASO ESTE: sala ODAC (10,2)-(12,4). Puerta en el tramo ESTE de (11,2) (`v:12:2`).
##              El otro medio del mismo lado, este de (11,3) (`v:12:3`), se queda TABIQUE.
##
## Cada NPC nace JUNTO A SU PUERTA (fuera) con destino en la esquina OPUESTA de su sala (dentro): así
## el camino tiene que atravesar la sala entera y el único hueco posible es el que se abrió. Se
## registra la posición del cuerpo (plano lógico cuadrado, `NavigationAgent2D` real) cada physics
## frame y, al llegar, se comprueba NUMÉRICAMENTE con intersección de segmentos: la trayectoria cruza
## la arista de SU puerta y no cruza ninguna otra arista amurallada.
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const NPCsFlujoScript := preload("res://src/main/npcs_flujo.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 24
const FILAS: int = 13
const CARPETA_EVIDENCIA := "res://production/qa/evidence/"

## Distancia (px) a la que se considera "ha llegado" — igual criterio que `NPCCiudadano.
## DISTANCIA_LLEGADA` (12 px: un pelo por encima del `target_desired_distance` del agente, 6 px).
const DISTANCIA_LLEGADA: float = 12.0
## Tope de physics frames por caso (10 s a 60 fps): a 90 px/s de sobra para ~150 px de trayecto.
const MAX_FRAMES: int = 600

# ── CASO SUR: sala Documentación, puerta en el tramo sur de (4,3) ────────────────────────────
const SALA_A_RECT := Rect2i(4, 2, 2, 2)
const SALA_A_CELDA_PUERTA := Vector2i(4, 3)
const SALA_A_LADO_PUERTA := &"abajo"
const SALA_A_CLAVE_PUERTA := "h:4:4"
## Las OTRAS 7 aristas de la sala (con TABIQUE): deben quedar SIN CRUZAR.
const SALA_A_OTRAS: Array[String] = ["h:4:2", "h:5:2", "h:5:4", "v:4:2", "v:4:3", "v:6:2", "v:6:3"]
const SALA_A_SPAWN := Vector2(180.0, 210.0)     # justo al sur del hueco, fuera de la sala
const SALA_A_TURNO: int = 1                      # hueco de pie -> índice 1 -> celda (5,2), esquina opuesta

# ── CASO ESTE: sala ODAC, puerta en el tramo este de (11,2) ──────────────────────────────────
const SALA_B_RECT := Rect2i(10, 2, 2, 2)
const SALA_B_CELDA_PUERTA := Vector2i(11, 2)
const SALA_B_LADO_PUERTA := &"derecha"
const SALA_B_CLAVE_PUERTA := "v:12:2"
const SALA_B_OTRAS: Array[String] = ["h:10:2", "h:11:2", "h:10:4", "h:11:4", "v:10:2", "v:10:3", "v:12:3"]
const SALA_B_SPAWN := Vector2(530.0, 100.0)     # justo al este del hueco, fuera de la sala
const SALA_B_TURNO: int = 2                      # hueco de pie -> índice 2 -> celda (10,3), esquina opuesta

var _construccion: Node
var _npcs: Node2D
var _npc_a: Node
var _npc_b: Node
var _destino_a: Vector2
var _destino_b: Vector2
var _trayecto_a: Array[Vector2] = []
var _trayecto_b: Array[Vector2] = []
var _terminado_a: bool = false
var _terminado_b: bool = false
var _frame: int = 0
var _capa_debug: Node2D = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA_EVIDENCIA)
	_construccion = ConstruccionScript.new()
	add_child(_construccion)
	_construccion.aplicar_config(ConfigConstruccionScript.new())
	var personal: Node = PersonalScript.new()
	add_child(personal)
	personal.aplicar_config(ConfigPersonalScript.new())
	_construccion.usar_personal(personal)
	var flujo: Node = FlujoScript.new()
	add_child(flujo)
	flujo.usar_personal(personal)
	flujo.usar_construccion(_construccion)

	# Las dos salas, amuralladas ENTERAS (mismo mecanismo que `_diag_bloqueo`: `construir_muro` en
	# las 8 aristas del perímetro), y LUEGO se abre UN tramo concreto de cada una con
	# `fijar_tipo_de_muro` — exactamente el gesto del jugador al poner una puerta.
	var ok_a: bool = _amurallar_sala(SALA_A_RECT)
	var ok_b: bool = _amurallar_sala(SALA_B_RECT)
	print("[diag_hueco_puerta] sala A (Documentacion) amurallada: %s | sala B (ODAC) amurallada: %s" % [ok_a, ok_b])
	var sala_a: StringName = _construccion.construir_de_oficio_sala(&"sala_espera_doc", SALA_A_RECT)
	var sala_b: StringName = _construccion.construir_de_oficio_sala(&"sala_espera_odac", SALA_B_RECT)
	print("[diag_hueco_puerta] sala A id=%s | sala B id=%s" % [sala_a, sala_b])
	var puerta_a: bool = _construccion.fijar_tipo_de_muro(
		SALA_A_CELDA_PUERTA, SALA_A_LADO_PUERTA, _construccion.PUERTA
	)
	var puerta_b: bool = _construccion.fijar_tipo_de_muro(
		SALA_B_CELDA_PUERTA, SALA_B_LADO_PUERTA, _construccion.PUERTA
	)
	print("[diag_hueco_puerta] puerta A (%s) abierta: %s | puerta B (%s) abierta: %s" % [
		SALA_A_CLAVE_PUERTA, puerta_a, SALA_B_CLAVE_PUERTA, puerta_b
	])
	assert(puerta_a and puerta_b, "las dos puertas deben abrirse para que el diagnóstico tenga sentido")

	_npcs = NPCsFlujoScript.new()
	add_child(_npcs)
	_npcs.configurar(flujo, _construccion, personal, TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS, null)

	var ficha_a: RefCounted = PersonaScript.new(&"Documentacion", &"dni", 0.0)
	var persona_a: RefCounted = PersonaFlujoScript.new(ficha_a, SALA_A_TURNO)
	persona_a.estado = PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO
	_npcs.spawn(persona_a)
	var ficha_b: RefCounted = PersonaScript.new(&"ODAC", &"cita_previa", 0.0)
	var persona_b: RefCounted = PersonaFlujoScript.new(ficha_b, SALA_B_TURNO)
	persona_b.estado = PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO
	_npcs.spawn(persona_b)

	var plano_logico: Node2D = _npcs.get_node("PlanoLogico")
	# `spawn` añade el NPC al final de `PlanoLogico` — el último añadido es el segundo (B).
	_npc_b = plano_logico.get_child(plano_logico.get_child_count() - 1)
	_npc_a = plano_logico.get_child(plano_logico.get_child_count() - 2)
	# Se colocan EXACTAMENTE junto a su hueco (antes de que corra ningún physics frame — el
	# NavigationServer no sincroniza hasta el primero, así que el target aún no se ha pedido).
	_npc_a.position = SALA_A_SPAWN
	_npc_b.position = SALA_B_SPAWN
	_destino_a = _construccion.centro_de_celda(Vector2i(5, 2))   # esquina opuesta a la puerta A
	_destino_b = _construccion.centro_de_celda(Vector2i(10, 3))  # esquina opuesta a la puerta B
	print("[diag_hueco_puerta] NPC A en %s -> destino %s | NPC B en %s -> destino %s" % [
		_npc_a.position, _destino_a, _npc_b.position, _destino_b
	])

	_capa_debug = Node2D.new()
	_capa_debug.name = "TrayectoriaDebug"
	add_child(_capa_debug)

	var centro: Vector2 = Proyeccion.proyectar(Vector2(340.0, 140.0))
	var camara := Camera2D.new()
	camara.position = centro
	camara.zoom = Vector2(0.9, 0.9)
	add_child(camara)
	camara.make_current()


func _physics_process(_delta: float) -> void:
	_frame += 1
	_trayecto_a.append(_npc_a.position)
	_trayecto_b.append(_npc_b.position)
	if not _terminado_a and _npc_a.position.distance_to(_destino_a) < DISTANCIA_LLEGADA:
		_terminado_a = true
	if not _terminado_b and _npc_b.position.distance_to(_destino_b) < DISTANCIA_LLEGADA:
		_terminado_b = true
	if (_terminado_a and _terminado_b) or _frame >= MAX_FRAMES:
		await _finalizar()


## Levanta los 8 tabiques del perímetro de una sala rectangular (idéntico patrón a `_diag_bloqueo`).
func _amurallar_sala(rect: Rect2i) -> bool:
	var ok: bool = true
	for x: int in range(rect.position.x, rect.position.x + rect.size.x):
		ok = _construccion.construir_muro(Vector2i(x, rect.position.y), &"arriba") and ok
		ok = _construccion.construir_muro(
			Vector2i(x, rect.position.y + rect.size.y - 1), &"abajo"
		) and ok
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		ok = _construccion.construir_muro(Vector2i(rect.position.x, y), &"izquierda") and ok
		ok = _construccion.construir_muro(
			Vector2i(rect.position.x + rect.size.x - 1, y), &"derecha"
		) and ok
	return ok


## El segmento (en el plano lógico cuadrado) de una arista dada por su CLAVE ("h:x:y" / "v:x:y") —
## misma fórmula que usa `NPCsFlujo._bakear_navegacion` para recortar la navegación, sin el grosor.
func _segmento_de_clave(clave: String) -> Array:
	var partes: PackedStringArray = clave.split(":")
	var cx: float = float(int(partes[1]))
	var cy: float = float(int(partes[2]))
	var t: float = float(TAM_CELDA)
	var a0: Vector2 = Vector2(cx, cy) * t
	if partes[0] == "h":
		return [a0, a0 + Vector2(t, 0.0)]
	return [a0, a0 + Vector2(0.0, t)]


## Intersección de dos segmentos [p1,p2] y [p3,p4] (algoritmo paramétrico por producto cruzado).
## Devuelve el punto de cruce, o `null` si no se cruzan (o son paralelos).
func _cruce(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Variant:
	var r: Vector2 = p2 - p1
	var s: Vector2 = p4 - p3
	var rxs: float = r.cross(s)
	if absf(rxs) < 0.0001:
		return null
	var t: float = (p3 - p1).cross(s) / rxs
	var u: float = (p3 - p1).cross(r) / rxs
	if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
		return p1 + r * t
	return null


## Analiza una trayectoria contra la arista de SU puerta y las otras aristas amuralladas de su sala.
## Imprime PASA/FALLA con los números y devuelve si el caso pasó entero.
func _analizar_caso(
	nombre: String, trayecto: Array[Vector2], destino: Vector2,
	clave_puerta: String, otras: Array[String]
) -> bool:
	var seg_puerta: Array = _segmento_de_clave(clave_puerta)
	var cruces_puerta: Array = []
	var cruces_otros: Dictionary = {}
	for i: int in range(trayecto.size() - 1):
		var p0: Vector2 = trayecto[i]
		var p1: Vector2 = trayecto[i + 1]
		if p0.is_equal_approx(p1):
			continue
		var pi: Variant = _cruce(p0, p1, seg_puerta[0], seg_puerta[1])
		if pi != null:
			cruces_puerta.append({"frame": i, "punto": pi})
		for clave: String in otras:
			var seg: Array = _segmento_de_clave(clave)
			var pi2: Variant = _cruce(p0, p1, seg[0], seg[1])
			if pi2 != null:
				if not cruces_otros.has(clave):
					cruces_otros[clave] = []
				(cruces_otros[clave] as Array).append({"frame": i, "punto": pi2})
	var llego: bool = trayecto[trayecto.size() - 1].distance_to(destino) < DISTANCIA_LLEGADA * 2.0
	var cruza_su_puerta: bool = not cruces_puerta.is_empty()
	var cruza_otra_pared: bool = not cruces_otros.is_empty()
	print("── CASO %s ──────────────────────────────────────────" % nombre)
	print(
		"  llega=%s (dist final al destino=%.2f px, umbral=%.1f) | frames registrados=%d"
		% [llego, trayecto[trayecto.size() - 1].distance_to(destino), DISTANCIA_LLEGADA * 2.0, trayecto.size()]
	)
	if cruza_su_puerta:
		var primero: Dictionary = cruces_puerta[0]
		print(
			"  cruza SU puerta (%s): SI — %d cruce(s), primero en frame %d, punto %s"
			% [clave_puerta, cruces_puerta.size(), primero["frame"], primero["punto"]]
		)
	else:
		print("  cruza SU puerta (%s): NO — FALLO (nunca atravesó su propio hueco)" % clave_puerta)
	if cruza_otra_pared:
		print("  cruza OTRA pared: SI — FALLO. Detalle:")
		for clave: String in cruces_otros:
			for c: Dictionary in (cruces_otros[clave] as Array):
				print("    arista %s en frame %d, punto %s" % [clave, c["frame"], c["punto"]])
	else:
		print("  cruza OTRA pared de la sala: NO (correcto — %d aristas comprobadas)" % otras.size())
	var pasa: bool = llego and cruza_su_puerta and not cruza_otra_pared
	print("  VEREDICTO %s: %s" % [nombre, "PASA" if pasa else "FALLA"])
	return pasa


## Dibuja la trayectoria registrada como Line2D (proyección isométrica) — barato: una polilínea.
func _dibujar_trayecto(trayecto: Array[Vector2], color: Color) -> void:
	var linea := Line2D.new()
	linea.width = 2.0
	linea.default_color = color
	for punto: Vector2 in trayecto:
		linea.add_point(Proyeccion.proyectar(punto))
	_capa_debug.add_child(linea)


func _finalizar() -> void:
	set_physics_process(false)
	print("[diag_hueco_puerta] FIN DE REGISTRO — frame=%d terminado_a=%s terminado_b=%s" % [
		_frame, _terminado_a, _terminado_b
	])
	var pasa_a: bool = _analizar_caso(
		"SUR (Documentacion)", _trayecto_a, _destino_a, SALA_A_CLAVE_PUERTA, SALA_A_OTRAS
	)
	var pasa_b: bool = _analizar_caso(
		"ESTE (ODAC)", _trayecto_b, _destino_b, SALA_B_CLAVE_PUERTA, SALA_B_OTRAS
	)
	_dibujar_trayecto(_trayecto_a, Color(0.2, 0.9, 0.3))
	_dibujar_trayecto(_trayecto_b, Color(0.95, 0.55, 0.15))

	# Captura 1: caso SUR (encuadre sobre la sala A y su tramo de calle sur).
	var cam: Camera2D = get_viewport().get_camera_2d()
	cam.position = Proyeccion.proyectar(Vector2(200.0, 170.0))
	cam.zoom = Vector2(2.2, 2.2)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img_a: Image = get_viewport().get_texture().get_image()
	var ruta_a: String = "%shueco-puerta-2026-08-04-caso-sur.png" % CARPETA_EVIDENCIA
	img_a.save_png(ruta_a)
	print("[diag_hueco_puerta] captura guardada: %s" % ruta_a)

	# Captura 2: caso ESTE.
	cam.position = Proyeccion.proyectar(Vector2(480.0, 130.0))
	cam.zoom = Vector2(2.2, 2.2)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img_b: Image = get_viewport().get_texture().get_image()
	var ruta_b: String = "%shueco-puerta-2026-08-04-caso-este.png" % CARPETA_EVIDENCIA
	img_b.save_png(ruta_b)
	print("[diag_hueco_puerta] captura guardada: %s" % ruta_b)

	print("[diag_hueco_puerta] RESUMEN — caso SUR: %s | caso ESTE: %s" % [
		"PASA" if pasa_a else "FALLA", "PASA" if pasa_b else "FALLA"
	])
	get_tree().quit(0 if (pasa_a and pasa_b) else 1)
