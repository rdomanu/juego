# BUG REPORTADO POR EL USUARIO (2026-08-05): "aunque haya una puerta, la gente atraviesa la pared en
# algunas ocasiones" — al fijar las paredes de la sala ODAC él mismo y colocar la puerta a mano.
#
# Cubre la NAVEGACIÓN FÍSICA REAL (NavigationAgent2D + NavigationServer2D — el camino que anda el NPC
# en pantalla), no el BFS lógico de `Construccion.deja_pasar` (ya cubierto por
# `flujo_bloqueo_sin_camino_test.gd` y, en el motor pero con muros construidos ANTES de nacer el NPC,
# por `tools/_diag_hueco_puerta.gd`). Este archivo prueba dos cosas que esos NO cubrían:
#
#   1. Una sala levantada con el botón REAL del jugador (`fijar_paredes_de_sala`, no `construir_muro`
#      tabique a tabique) + una puerta manual (`fijar_tipo_de_muro`), navegada por el motor en LOS 4
#      LADOS — "en algunas ocasiones" sugiere que depende de la orientación del tramo.
#
#   2. EL SOSPECHOSO Nº1: un NPC que YA tiene una ruta calculada (su `NavigationAgent2D` ya está
#      navegando por una zona ABIERTA) y el jugador levanta un muro ENCIMA de esa ruta A MITAD DE
#      CAMINO. `NPCCiudadano._actualizar_destino` solo se reevalúa cuando cambia el ESTADO lógico de
#      la persona (ver `NPCCiudadano._physics_process`) — levantar un muro no cambia ese estado.
#
# Tipo: Integration (motor real: Construccion + NPCsFlujo + NPCCiudadano + NavigationServer2D, sin
# mocks). Corre physics frames reales (`await get_tree().physics_frame`); el layout, los turnos y los
# destinos son fijos, y la propiedad comprobada (cruza / no cruza una arista concreta) no depende de
# la variación en píxeles que pueda dar el propio NavigationServer.
extends GdUnitTestSuite

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
## Máximo de physics frames reales por caso (10 s a 60 fps: de sobra para ~150 px de trayecto).
const MAX_FRAMES: int = 600
## "Ha llegado" con el mismo criterio que `NPCCiudadano.DISTANCIA_LLEGADA` (12 px).
const DISTANCIA_LLEGADA: float = 12.0
## Sala de pruebas: interior del edificio (lejos de la fachada), x:400-480 y:200-280.
const RECT := Rect2i(10, 5, 2, 2)


## Un mundo completo (Construccion + Flujo + Personal + NPCsFlujo), todo real y enganchado entre sí
## — igual que `Main`, sin capa visual. Se añade al árbol para que corran los `_physics_process`.
func _mundo() -> Dictionary:
	var construccion: Node = auto_free(ConstruccionScript.new())
	add_child(construccion)
	construccion.aplicar_config(ConfigConstruccionScript.new())
	var personal: Node = auto_free(PersonalScript.new())
	add_child(personal)
	personal.aplicar_config(ConfigPersonalScript.new())
	construccion.usar_personal(personal)
	var flujo: Node = auto_free(FlujoScript.new())
	add_child(flujo)
	flujo.usar_personal(personal)
	flujo.usar_construccion(construccion)
	var npcs: Node = auto_free(NPCsFlujoScript.new())
	add_child(npcs)
	npcs.configurar(flujo, construccion, personal, TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS, null)
	return {"construccion": construccion, "flujo": flujo, "personal": personal, "npcs": npcs}


## Nace un ciudadano YA "esperando_dentro" de `servicio`, colocado A MANO en `posicion` (antes de que
## corra el primer physics frame — el NavigationServer no sincroniza hasta entonces, así que no hay
## ningún target pedido todavía). `turno` decide la celda de espera vía `_hueco_de_pie_libre`.
func _spawn_esperando_dentro(
	npcs: Node, servicio: StringName, tramite: StringName, turno: int, posicion: Vector2
) -> Node:
	var ficha: RefCounted = PersonaScript.new(servicio, tramite, 0.0)
	var persona: RefCounted = PersonaFlujoScript.new(ficha, turno)
	persona.estado = PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO
	npcs.spawn(persona)
	var plano_logico: Node2D = npcs.get_node("PlanoLogico")
	var npc: Node = plano_logico.get_child(plano_logico.get_child_count() - 1)
	npc.position = posicion
	return npc


## El segmento (plano lógico cuadrado) de una arista por su CLAVE ("h:x:y" / "v:x:y") — misma fórmula
## que `NPCsFlujo._bakear_navegacion` usa para recortar la navegación (sin el grosor: la LÍNEA de la
## arista, que es lo que un camino cruza o no cruza).
func _segmento_de_clave(clave: String) -> Array:
	var partes: PackedStringArray = clave.split(":")
	var cx: float = float(int(partes[1]))
	var cy: float = float(int(partes[2]))
	var t: float = float(TAM_CELDA)
	var a0: Vector2 = Vector2(cx, cy) * t
	if partes[0] == "h":
		return [a0, a0 + Vector2(t, 0.0)]
	return [a0, a0 + Vector2(0.0, t)]


## Intersección de segmentos [p1,p2] y [p3,p4] (paramétrica, producto cruzado). `null` si no cruzan.
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


## ¿La trayectoria (posiciones consecutivas) cruza ALGUNA de estas aristas en algún tramo? Devuelve
## el detalle del primer cruce (clave + frame + punto), o `{}` si ninguna se cruza.
func _primer_cruce(trayecto: Array[Vector2], claves: Array[String]) -> Dictionary:
	for clave: String in claves:
		var seg: Array = _segmento_de_clave(clave)
		for i: int in range(trayecto.size() - 1):
			var p0: Vector2 = trayecto[i]
			var p1: Vector2 = trayecto[i + 1]
			if p0.is_equal_approx(p1):
				continue
			var pi: Variant = _cruce(p0, p1, seg[0], seg[1])
			if pi != null:
				return {"clave": clave, "frame": i, "punto": pi}
	return {}


## Imprime la trayectoria CELDA A CELDA (solo cuando cambia de celda, para no inundar el log).
func _imprimir_trayecto_por_celdas(etiqueta: String, trayecto: Array[Vector2]) -> void:
	var celda_previa := Vector2i(-9999, -9999)
	print("[%s] trayecto celda a celda:" % etiqueta)
	for i: int in trayecto.size():
		var celda: Vector2i = Proyeccion.celda_de_cuadrado(trayecto[i])
		if celda != celda_previa:
			print("  frame %d: %s (px %s)" % [i, celda, trayecto[i]])
			celda_previa = celda


# ══════════════════════════════════════════════════════════════════════════════════════════════
# CASO 1 — sala DE JUGADOR (`fijar_paredes_de_sala` + puerta manual), en los 4 lados
# ══════════════════════════════════════════════════════════════════════════════════════════════

## Por lado: celda+lado de la puerta, punto de partida FUERA de ese lado, esquina opuesta DENTRO
## (destino) y el turno que hace que `_hueco_de_pie_libre` reparta justo esa esquina opuesta.
const LADOS := {
	"norte": {
		"celda": Vector2i(10, 5), "muro_lado": &"arriba",
		"spawn": Vector2(420.0, 185.0), "destino_celda": Vector2i(11, 6), "turno": 3,
	},
	"sur": {
		"celda": Vector2i(10, 6), "muro_lado": &"abajo",
		"spawn": Vector2(420.0, 295.0), "destino_celda": Vector2i(11, 5), "turno": 1,
	},
	"este": {
		"celda": Vector2i(11, 5), "muro_lado": &"derecha",
		"spawn": Vector2(495.0, 220.0), "destino_celda": Vector2i(10, 6), "turno": 2,
	},
	"oeste": {
		"celda": Vector2i(10, 5), "muro_lado": &"izquierda",
		"spawn": Vector2(385.0, 220.0), "destino_celda": Vector2i(11, 6), "turno": 3,
	},
}


func test_sala_de_jugador_puerta_manual_norte_se_entra_por_el_hueco() -> void:
	await _verificar_lado_con_puerta("norte")


func test_sala_de_jugador_puerta_manual_sur_se_entra_por_el_hueco() -> void:
	await _verificar_lado_con_puerta("sur")


func test_sala_de_jugador_puerta_manual_este_se_entra_por_el_hueco() -> void:
	await _verificar_lado_con_puerta("este")


func test_sala_de_jugador_puerta_manual_oeste_se_entra_por_el_hueco() -> void:
	await _verificar_lado_con_puerta("oeste")


func _verificar_lado_con_puerta(lado: String) -> void:
	# Arrange — sala DE JUGADOR: se designa (como el pincel de sala) y se cierra con el botón real
	# "Paredes" (`fijar_paredes_de_sala`), luego se abre a mano UN tramo (el gesto de la puerta manual).
	var datos: Dictionary = LADOS[lado]
	var mundo: Dictionary = _mundo()
	var construccion: Node = mundo["construccion"]
	var npcs: Node = mundo["npcs"]
	var sala_id: StringName = construccion.construir_de_oficio_sala(&"sala_espera_odac", RECT)
	assert_str(String(sala_id)).is_not_equal("")
	construccion.fijar_paredes_de_sala(sala_id, true)
	var abierta: bool = construccion.fijar_tipo_de_muro(
		datos["celda"], datos["muro_lado"], construccion.PUERTA
	)
	assert_bool(abierta).is_true()
	var clave_puerta: String = construccion.clave_de_muro(datos["celda"], datos["muro_lado"])
	var otras: Array[String] = []
	for clave: String in construccion.muros():
		if clave != clave_puerta and construccion.tipo_muro_de_clave(clave) != construccion.PUERTA:
			otras.append(clave)
	assert_int(otras.size()).is_equal(7)   # las 8 aristas del perímetro menos la puerta

	var npc: Node = _spawn_esperando_dentro(
		npcs, &"ODAC", &"cita_previa", datos["turno"], datos["spawn"]
	)
	var destino: Vector2 = construccion.centro_de_celda(datos["destino_celda"])

	# Act — physics frames reales hasta llegar (o tope).
	var trayecto: Array[Vector2] = []
	var frame: int = 0
	while frame < MAX_FRAMES:
		await get_tree().physics_frame
		frame += 1
		trayecto.append(npc.position)
		if npc.position.distance_to(destino) < DISTANCIA_LLEGADA:
			break
	_imprimir_trayecto_por_celdas("lado %s" % lado, trayecto)

	# Assert — llegó, cruzó SU puerta, y NINGUNA otra arista amurallada de la sala.
	assert_bool(trayecto.back().distance_to(destino) < DISTANCIA_LLEGADA * 2.0).is_true()
	var cruce_puerta: Dictionary = _primer_cruce(trayecto, [clave_puerta])
	assert_bool(cruce_puerta.is_empty()).is_false()
	var cruce_otra: Dictionary = _primer_cruce(trayecto, otras)
	if not cruce_otra.is_empty():
		print(
			"  [FALLO %s] atraviesa la arista %s (SIN puerta) en el frame %d, punto %s"
			% [lado, cruce_otra["clave"], cruce_otra["frame"], cruce_otra["punto"]]
		)
	assert_bool(cruce_otra.is_empty()).is_true()


# ══════════════════════════════════════════════════════════════════════════════════════════════
# CASO 2 — EL SOSPECHOSO Nº1: el muro se levanta DESPUÉS de que el NPC ya tenga ruta calculada
# ══════════════════════════════════════════════════════════════════════════════════════════════

## Sala ABIERTA (sin muros): el NPC traza una ruta hacia dentro con la sala vacía. A los pocos frames
## (con el NPC todavía LEJOS de la arista, ruta ya pedida al NavigationAgent2D) el jugador levanta las
## 4 paredes SIN puerta (`fijar_paredes_de_sala`) — el estado lógico de la persona NO cambia, así que
## `NPCCiudadano._actualizar_destino` no se reevalúa por sí solo. Si el NPC sigue su ruta vieja en
## línea recta, atraviesa el muro nuevo.
func test_muro_construido_tras_ruta_ya_calculada_no_lo_atraviesa() -> void:
	# Arrange — sala designada pero SIN muros todavía: terreno abierto de verdad.
	var mundo: Dictionary = _mundo()
	var construccion: Node = mundo["construccion"]
	var npcs: Node = mundo["npcs"]
	var sala_id: StringName = construccion.construir_de_oficio_sala(&"sala_espera_odac", RECT)
	assert_str(String(sala_id)).is_not_equal("")
	var destino_celda := Vector2i(11, 6)   # esquina opuesta al punto de partida (turno 3, ver CASO 1)
	var destino: Vector2 = construccion.centro_de_celda(destino_celda)
	var npc: Node = _spawn_esperando_dentro(
		npcs, &"ODAC", &"cita_previa", 3, Vector2(420.0, 185.0)
	)

	# Act 1 — unos pocos frames CON LA SALA ABIERTA: el NavigationAgent2D ya pide y sigue una ruta
	# hacia el destino. Se comprueba que se ha movido pero SIGUE fuera (y < 200, la futura arista
	# norte de la sala) — no le ha dado tiempo a cruzarla todavía.
	var trayecto: Array[Vector2] = []
	for _i in 5:
		await get_tree().physics_frame
		trayecto.append(npc.position)
	assert_bool(npc.position.y < 200.0).is_true()

	# Act 2 — EL JUGADOR levanta las 4 paredes de la sala, SIN puerta, con el NPC a mitad de camino.
	construccion.fijar_paredes_de_sala(sala_id, true)
	var otras: Array[String] = []
	for clave: String in construccion.muros():
		if construccion.tipo_muro_de_clave(clave) != construccion.PUERTA:
			otras.append(clave)
	assert_int(otras.size()).is_equal(8)   # las 8 aristas del perímetro, ninguna es puerta

	# Act 3 — sigue corriendo el motor: sin puerta no hay ruta posible hasta `destino`, así que lo
	# correcto es que se quede bloqueado FUERA — pero NUNCA que cruce el muro nuevo.
	var frame: int = 0
	while frame < MAX_FRAMES:
		await get_tree().physics_frame
		frame += 1
		trayecto.append(npc.position)
		if npc.position.distance_to(destino) < DISTANCIA_LLEGADA:
			break
	_imprimir_trayecto_por_celdas("muro tras ruta", trayecto)

	# Assert — LA PROPIEDAD QUE IMPORTA: nunca atraviesa ninguna de las 8 aristas amuralladas. Y, como
	# está sellada sin puerta, tampoco debería "llegar" — si llegó fue atravesando el muro por dentro
	# del corredor viejo, lo cual es justo el bug.
	var cruce: Dictionary = _primer_cruce(trayecto, otras)
	if not cruce.is_empty():
		print(
			"  [FALLO] el NPC atraviesa la arista %s (recién construida) en el frame %d, punto %s"
			% [cruce["clave"], cruce["frame"], cruce["punto"]]
		)
	assert_bool(cruce.is_empty()).is_true()
	assert_bool(npc.position.distance_to(destino) < DISTANCIA_LLEGADA).is_false()
