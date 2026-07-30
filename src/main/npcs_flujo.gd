class_name NPCsFlujo extends Node2D
## NPCsFlujo — la capa COSMÉTICA de ciudadanos (story flujo-008): spawnea un NPC por persona
## admitida, reparte destinos según el estado lógico (asiento o hueco de pie en la espera, la
## ventanilla al ser llamado, la calle al resolverse) y POSEE la navegación: un NavigationRegion2D
## bakeado del layout REAL de Construcción con `NavigationServer2D.bake_from_source_geometry_data`
## (patrón validado en el slice, Escalón 1) y re-bakeado SOLO al cambiar el layout (hook de
## Construcción, coalescido a un bake por frame como máximo — nunca por frame, manifiesto).
##
## COSMÉTICO PURO (FL5/ADR-0001): LEE Flujo y Construcción; jamás los muta. El aforo lógico no
## sabe nada de estos muñecos.
##
## Story: production/epics/flujo/story-008-comisaria-viva-npcs.md · TR-flow-005 · ADR-0004

const NPCScript := preload("res://src/main/npc_ciudadano.gd")

## Colores placeholder por servicio (los mismos tonos que las salas de Construcción).
const COLOR_DOC := Color(0.35, 0.55, 0.9)
const COLOR_ODAC := Color(0.95, 0.6, 0.25)
## TIE (feedback flujo-008): un azul Doc ACLARADO para distinguir de un DNI/Pasaporte de un vistazo.
## Literal precalculado de COLOR_DOC.lightened(0.45) — las const no evalúan métodos entre sí.
const COLOR_TIE := Color(0.6425, 0.7525, 0.945)

## Rótulos de estado del puesto (texto SIEMPRE, respaldo daltónico) + su color de acento.
const ROTULO_ESTADO: Dictionary[StringName, String] = {
	&"cerrado": "CERRADO",
	&"abierto_sin_agente": "SIN AGENTE",
	&"libre": "LIBRE",
	&"en_camino": "EN CAMINO",   # enmienda 2026-07-25: llamada emitida, el ciudadano aún camina
	&"atendiendo": "ATENDIENDO",
	&"descansando": "☕ DESCANSO",   # Bienestar #13: su titular se ha ido a por su café
}
const COLOR_ESTADO: Dictionary[StringName, Color] = {
	&"cerrado": Color(0.6, 0.6, 0.6),
	&"abierto_sin_agente": Color(1.0, 0.8, 0.35),
	&"libre": Color(0.55, 0.9, 0.55),
	&"en_camino": Color(0.6, 0.7, 0.9),
	&"atendiendo": Color(0.5, 0.75, 1.0),
	&"descansando": Color(0.85, 0.7, 0.45),   # ámbar tostado: ni alarma ni normalidad
}
## Uniforme del policía (torso azul marino, cabeza clara — estilo npc_ciudadano).
const COLOR_POLICIA_TORSO := Color(0.10, 0.14, 0.30)
## Colores del ÁNIMO de quien espera (story paciencia-008). Sobrios, nada caricaturesco (art bible):
## el descontento se ve, pero esto es una comisaría, no un parque de atracciones.
const COLOR_ANIMO: Dictionary[StringName, Color] = {
	&"contento": Color(0.45, 0.80, 0.45),
	&"impaciente": Color(0.95, 0.78, 0.30),
	&"al_limite": Color(0.90, 0.35, 0.35),
}
## A quien el jugador ha COLADO se le pinta la barra en AZUL: se ve de un vistazo a quién le has
## hecho el favor y por qué se le llama antes que al resto (mecánica del 2026-07-26).
const COLOR_COLADO := Color(0.45, 0.75, 1.0)
## Sentinela de "sin celda" (fuera de todo rect de sala: las celdas del edificio son ≥ 0).
const CELDA_NULA := Vector2i(-1, -1)

## Barra de cansancio sobre el puesto (bienestar-013, feedback ANTICIPATORIO 2026-07-29): hoy el
## cansancio existe en el modelo y afecta al juego (ralentiza, manda al café) pero no se veía en
## ninguna parte — el jugador solo se enteraba cuando YA era demasiado tarde (rótulo ☕ DESCANSO).
## Tamaño fijo (no depende de a qué % esté el agente), bajo la etiqueta de nombre.
const ANCHO_BARRA_CANSANCIO: float = 50.0
const ALTO_BARRA_CANSANCIO: float = 4.0
const POS_Y_BARRA_CANSANCIO: float = 23.0
## Tramos de color (mismo criterio que Bienestar #13 usa para mandar al café): normal hasta 70,
## ámbar de aviso de 70 a 90, rojo crítico desde 90 — así se ve "está a punto de irse" ANTES del
## rótulo de café, que solo aparece cuando ya se ha ido.
const UMBRAL_CANSANCIO_AVISO: float = 70.0
const UMBRAL_CANSANCIO_CRITICO: float = 90.0
## `POS_Y_BARRA_CANSANCIO` la comparte TAMBIÉN la etiqueta "Extra" (minutos de descanso restantes,
## ver `_asegurar_visual_puesto`): son mutuamente excluyentes (la barra solo se ve dotado/activo; el
## extra solo con el titular de café, que es justo cuando la barra está oculta), así que reusar la
## misma franja no las hace competir por el espacio — evita solape #2026-07-29 sin sumar altura.

var _flujo: Node = null
var _construccion: Node = null
var _personal: Node = null
var _paciencia: Node = null
var _tam_celda: int = 40
var _pos_suelo: Vector2 = Vector2.ZERO
var _columnas: int = 24
var _filas: int = 13
var _region: NavigationRegion2D = null
var _rebake_pendiente: bool = false
## Celda de la sala de espera (banco o hueco de pie) → NPC que la ocupa. UNA CELDA, UNA PERSONA:
## solo estética de "sentarse/esperar de pie" — el aforo de verdad es de Flujo (F3).
var _plaza_de: Dictionary[Vector2i, Node] = {}
## Puesto_id → Node2D contenedor de su visual (muñeco policía + etiqueta nombre + rótulo estado).
## Se crea/borra/actualiza por DIFF (meta en el contenedor) — cero trabajo por frame si nada cambia.
var _visual_de_puesto: Dictionary[StringName, Node2D] = {}
## Segunda línea del rótulo de un puesto (hoy: los minutos que le quedan al que está de café).
var _rotulo_extra: Dictionary[StringName, String] = {}
## Capa donde cuelgan los muñecos que caminan al descanso (hereda el z_index 1 de `configurar`, así
## se dibujan por encima de las salas como el resto de NPCs).
var _capa_descansos: Node2D = null
## Desplazamiento del muñeco del funcionario respecto de la celda de SU mostrador: una casilla
## "hacia atrás" en el eje Y de la rejilla, que proyectada es medio rombo arriba y a la derecha.
## Es lo que coloca al policía DETRÁS de la mesa en vez de encima (ver `_asegurar_visual_puesto`).
const _POLICIA_DETRAS := Vector2(Proyeccion.MEDIO_ANCHO, -Proyeccion.MEDIO_ALTO)
## ISOMÉTRICO (2026-07-30): el plano lógico CUADRADO (oculto — navegación y cuerpos que andan) y la
## capa de escena ISOMÉTRICA (lo que se ve, ordenado por profundidad). Ver `configurar()`.
var _capa_logica: Node2D = null
var _capa_escena: Node2D = null

# ── Trayecto cosmético del descanso (feedback demo 2026-07-29: *"debe estar la animación del
# abandono del puesto y estar en la sala de descanso sin el puesto atendido"*) ───────────────────
## `agente` (RefCounted de Personal) → Dictionary del viaje EN CURSO. Se crea UNA vez al empezar el
## descanso y se REUSA hasta que vuelve — nunca se reconstruye por frame (regla de rendimiento del
## archivo: si nada cambió, cero toques a nodos; aquí "nada cambió" es "sigue siendo el mismo viaje",
## así que el muñeco simplemente se MUEVE, nunca se recrea). Claves de cada viaje:
##   "muneco": CharacterBody2D — el cuerpo que anda (torso+cabeza+NavigationAgent2D hijo, "Nav").
##   "nav": NavigationAgent2D  — su agente de navegación (mismo patrón que npc_ciudadano).
##   "fase": StringName        — &"yendo" (mostrador→sala/calle), &"en_sala" (quieto con su taza)
##                                o &"volviendo" (sala/calle→mostrador).
##   "puesto_id": StringName   — a qué mostrador pertenece y a qué punto vuelve.
##   "celda_sala": Vector2i    — su asiento reservado en la sala de descanso (CELDA_NULA sin sala).
##   "listo": bool             — false en su primer physics frame (gotcha del NavigationServer: no
##                                sincroniza hasta ahí — engine-reference/.../navigation.md).
##   "destino_pendiente": Vector2 (opcional) — target aún no aplicado a `nav` (se aplica en el primer
##                                frame ya "listo", o de inmediato si el viaje ya llevaba rato andando).
## Dictionary SIN TIPAR a propósito (valores mixtos) — mismo criterio que `Personal._descansando`.
var _camino_descanso: Dictionary = {}
## Celdas de la sala de descanso YA ocupadas por alguien que llegó o va de camino → su agente. Se
## libera al empezar la vuelta. Dict APARTE de `_plaza_de`: son dos salas distintas (espera/descanso)
## y aquí el ocupante es un Agente de Personal, no un NPC de Flujo.
var _asiento_descanso: Dictionary[Vector2i, RefCounted] = {}
## Puestos cuyo titular ya terminó su descanso PERO el muñeco aún no ha llegado de vuelta: mientras
## esté aquí, `_actualizar_visual_puesto` mantiene el mostrador VACÍO aunque el modelo ya diga que el
## agente está `asignado` — si no, se verían DOS policías a la vez (el fijo del mostrador + el que
## todavía anda). Se pone en `_iniciar_vuelta` y se quita en `_cerrar_camino_descanso`.
var _regreso_en_curso: Dictionary[StringName, bool] = {}

# ── Trayecto cosmético de la INCORPORACIÓN (petición del usuario 2026-07-29: *"que entren los
# funcionarios antes del turno para ver la animación... hay que calcular cuánto tardan a su puesto
# y que entren ese tiempo antes"*) ────────────────────────────────────────────────────────────────
## El MODELO (`Personal.va_de_camino_al_puesto` / `minutos_para_incorporarse`) ya decide CUÁNDO sale
## de casa cada uno y cuánto tarda — esta sección SOLO lo pinta, reutilizando el mismo andamiaje que
## el descanso (`_crear_muneco_caminante`, el paso genérico `_mover_paso` — extraído de
## `_avanzar_camino_descanso` para que sirvan los DOS casos — y la capa `_capa_descansos`). Un único
## tramo por agente (puerta → su ventanilla; sin fase "en_sala" ni "volviendo": aquí no hay a dónde
## volver). `agente` → Dictionary del viaje, mismas claves que `_camino_descanso` salvo
## "fase"/"celda_sala".
var _camino_incorporacion: Dictionary = {}
## Puestos con una incorporación EN CURSO (el muñeco aún anda hacia el mostrador): mientras esté
## aquí, `_actualizar_visual_puesto` mantiene el mostrador VACÍO — mismo motivo y mismo patrón que
## `_regreso_en_curso`, para que nunca se vean DOS policías a la vez. Se pone en
## `_iniciar_camino_incorporacion` y se quita en `_cerrar_camino_incorporacion`.
var _incorporacion_en_curso: Dictionary[StringName, bool] = {}


## El objeto que esta persona está usando ahora (`&""` si ninguno) — lo LEE el NPC para saber si
## tiene que acercarse a la máquina. Cosmético puro: aquí no se decide nada (FL5).
func comodidad_de(persona: RefCounted) -> StringName:
	if _paciencia == null or not _paciencia.has_method("comodidad_en_uso"):
		return &""
	return _paciencia.comodidad_en_uso(persona)


func usar_paciencia(paciencia: Node) -> void:
	_paciencia = paciencia


## El ánimo que debe mostrar esta persona, o `&""` si no procede enseñarlo (ya la han llamado, o no
## hay sistema de paciencia). COSMÉTICO: solo LEE (FL5).
func animo_de(persona: RefCounted) -> StringName:
	if _paciencia == null or persona == null:
		return &""
	if persona.estado != &"esperando_dentro" and persona.estado != &"esperando_fuera":
		return &""
	if not _paciencia.tiene(persona):
		return &""
	if persona.colado:
		return &"colado"
	return _paciencia.animo_de_persona(persona)


## El ciudadano ESPERANDO más cercano a un punto del mundo (para el clic derecho de "colar"), o null
## si no hay ninguno a tiro. Radio generoso: los muñecos son pequeños y el jugador no tiene por qué
## clavar el píxel.
func ciudadano_en(punto: Vector2, radio: float = 22.0) -> Node:
	var mejor: Node = null
	var mejor_dist: float = radio
	# ISOMÉTRICO (2026-07-30): los cuerpos viven en el plano lógico (oculto), así que ahora se
	# buscan ahí — pero la distancia se mide en PANTALLA, contra el muñeco que el jugador está
	# viendo. Comparar contra el cuerpo daría aciertos en un sitio donde no hay nadie dibujado.
	for hijo: Node in _capa_logica.get_children():
		if not (hijo is CharacterBody2D) or hijo.get("persona") == null:
			continue
		if animo_de(hijo.persona) == &"":
			continue   # solo se puede colar a quien está esperando (a quien ya llamaron, no)
		var dist: float = a_pantalla((hijo as Node2D).position).distance_to(punto)
		if dist < mejor_dist:
			mejor_dist = dist
			mejor = hijo
	return mejor


## Qué fracción de su paciencia le queda [0, 1] — el ANCHO de su barra. Sin dato → llena (no se
## enseña una barra medio vacía a quien no estamos midiendo).
func fraccion_paciencia(persona: RefCounted) -> float:
	if _paciencia == null or persona == null:
		return 1.0
	var valor: float = _paciencia.paciencia_de(persona)
	if valor < 0.0:
		return 1.0
	return clampf(valor / _paciencia.PACIENCIA_INICIAL, 0.0, 1.0)


## Color del aro de ánimo (texto+forma no aplican a un indicador de 3 px: el respaldo daltónico de
## esta información vive en el HUD, que da los números de satisfacción y colas).
func color_de_animo(animo: StringName) -> Color:
	if animo == &"colado":
		return COLOR_COLADO
	return COLOR_ANIMO.get(animo, Color(1, 1, 1, 0.5))


func configurar(
	flujo: Node,
	construccion: Node,
	personal: Node,
	tam_celda: int,
	pos_suelo: Vector2,
	columnas: int,
	filas: int,
) -> void:
	# Gotcha de orden de dibujo: las capas visuales de Construcción cuelgan de un nodo NO-CanvasItem
	# → son RAÍCES de canvas aparte que se pintan después del bloque de Main (donde vivimos). Sin
	# esto, los NPCs se dibujan DEBAJO de las salas al cruzarlas. z_index 1 los pone encima.
	z_index = 2   # sobre el suelo (0) y sobre las paredes (1): la gente nunca queda tapada
	_flujo = flujo
	_construccion = construccion
	_personal = personal
	_tam_celda = tam_celda
	_pos_suelo = pos_suelo
	_columnas = columnas
	_filas = filas
	# ── ISOMÉTRICO (2026-07-30): DOS capas, y esta separación es la clave de toda la conversión ──
	#
	# `_capa_logica` es el PLANO DEL ARQUITECTO: la comisaría vista desde arriba, celdas cuadradas
	# de 40 px. Aquí viven la navegación y los cuerpos que andan. **Está oculta**: no se dibuja
	# nunca, solo se calcula en ella. Sigue exactamente igual que antes de la conversión, y por eso
	# ni las velocidades ni los cronómetros ni los 643 tests se han tenido que tocar.
	#
	# `_capa_escena` es LO QUE SE VE: la misma comisaría en rombos. Cada cuerpo de la capa lógica
	# tiene aquí su muñeco, al que se le copia la posición ya proyectada en cada physics frame.
	_capa_logica = Node2D.new()
	_capa_logica.name = "PlanoLogico"
	_capa_logica.visible = false
	add_child(_capa_logica)
	_capa_escena = Node2D.new()
	_capa_escena.name = "Escena"
	_capa_escena.position = pos_suelo
	# Orden de dibujo por PROFUNDIDAD (nuevo con el isométrico): dentro de esta capa, quien está
	# más abajo en pantalla tapa a quien está detrás — que es justo lo que hace que una vista
	# isométrica se lea como un espacio y no como un collage. ⚠️ Verificado en la doc de Godot 4.6:
	# `y_sort_enabled` NO es recursivo (solo ordena los hijos DIRECTOS) y solo desempata entre
	# nodos del MISMO z_index. Por eso los muñecos cuelgan de aquí directamente, y no metidos cada
	# uno en un subnodo suyo.
	_capa_escena.y_sort_enabled = true
	add_child(_capa_escena)
	_region = NavigationRegion2D.new()
	_region.name = "Navegacion"
	_capa_logica.add_child(_region)
	# Capa de los que están de café (Bienestar #13): son CUERPOS que andan, así que van al plano
	# lógico; sus muñecos visibles se registran aparte en `_capa_escena`.
	_capa_descansos = Node2D.new()
	_capa_descansos.name = "Descansos"
	_capa_logica.add_child(_capa_descansos)
	_rebake_pendiente = true


## Cuelga un muñeco de la capa que SE VE. Lo llaman los cuerpos al nacer (npc_ciudadano) y los
## viajes de descanso/incorporación: el cuerpo se queda en el plano lógico y su muñeco viene aquí.
func registrar_muneco(muneco: Node2D) -> void:
	_capa_escena.add_child(muneco)


## Un punto del plano lógico cuadrado, llevado a coordenadas de PANTALLA (globales). Lo usan el
## acierto del clic derecho y cualquier cosa que tenga que comparar "dónde se ve" con "dónde está".
func a_pantalla(punto_cuadrado: Vector2) -> Vector2:
	return _pos_suelo + Proyeccion.proyectar(punto_cuadrado)


## Hook del cambio de layout (lo cablea Main): coalescido — como mucho un bake por frame.
func solicitar_rebake() -> void:
	_rebake_pendiente = true


## Minutos de camino que le quedan a la persona de este NPC (0.0 si su puesto ya no existe o la
## lógica ya lo dio por llegado) — para el paso ADAPTATIVO del muñeco (ver npc_ciudadano).
func camino_restante_min(persona: RefCounted) -> float:
	var puesto_id: StringName = _flujo.puesto_de(persona)
	# BUG corregido 2026-07-29 (el usuario: "en la odac siempre hay un ciudadano sentado o bien tarda
	# mucho en irse"): desde la LLAMADA ANTICIPADA, `puesto_de` tambien devuelve el puesto del
	# RESERVADO — pero `camino_restante_de` da el camino de quien YA esta siendo atendido, que casi
	# siempre es 0 porque ya llego. El reservado leia "me queda 0", el paso adaptativo lo interpretaba
	# como "ya casi estas, remata" y le ponia a 1,5x: llegaba corriendo y se quedaba congelado junto al
	# mostrador hasta 60 min (lo que dura una denuncia gorda de ODAC). Su dato de verdad es otro.
	if _flujo.siguiente_de(puesto_id) == persona:
		return _flujo.siguiente_camino_restante_de(puesto_id)
	return _flujo.camino_restante_de(puesto_id)


func _physics_process(_delta: float) -> void:
	if _rebake_pendiente:
		_rebake_pendiente = false
		_bakear_navegacion()
	_refrescar_puestos()
	_refrescar_descansos()
	_refrescar_incorporaciones()
	_sincronizar_caminantes()


## Bake del polígono navegable: el suelo del edificio + dos celdas de "calle" a la izquierda
## (spawn, cola exterior y salida) como área transitable; cada PUESTO se recorta como obstáculo
## (el NPC rodea el mostrador y se detiene en su borde). Los asientos NO se recortan: pisar la
## celda del banco es "sentarse".
func _bakear_navegacion() -> void:
	# ISOMÉTRICO (2026-07-30): la navegación vive en el PLANO LÓGICO CUADRADO, cuyo origen es la
	# esquina (0,0) de la rejilla a secas — ya no se le suma `_pos_suelo`. Ese desplazamiento es de
	# PANTALLA y ahora lo aplica la capa de escena al dibujar; metiéndolo aquí, los destinos (que
	# salen de `Construccion.centro_de_celda`, sin desplazar) habrían caído fuera del polígono
	# navegable y nadie habría podido moverse.
	var datos := NavigationMeshSourceGeometryData2D.new()
	var origen := Vector2(-2.0 * _tam_celda, 0.0)
	var fin := Vector2(_columnas * _tam_celda, _filas * _tam_celda)
	datos.add_traversable_outline(PackedVector2Array([
		origen, Vector2(fin.x, origen.y), fin, Vector2(origen.x, fin.y),
	]))
	for servicio: String in ["Documentacion", "ODAC", "Seguridad"]:
		for puesto_id: StringName in _construccion.puestos_de_servicio(servicio):
			var esquina: Vector2 = Vector2(_construccion.posicion_de(puesto_id)) * float(_tam_celda)
			var lado := float(_tam_celda)
			datos.add_obstruction_outline(PackedVector2Array([
				esquina, esquina + Vector2(lado, 0), esquina + Vector2(lado, lado), esquina + Vector2(0, lado),
			]))
	# FASE E (2026-07-30): los MUROS bloquean de verdad. Cada tabique se recorta como una franja fina
	# de obstáculo sobre su arista — las PUERTAS no se recortan, y por eso son lo único por donde se
	# puede entrar en una sala cerrada. Las ventanas SÍ bloquean (se ve a través, no se pasa).
	#
	# El grosor es de un tercio de celda a propósito: si fuera un pelo, el agente (radio 8 px) se
	# colaría entre dos tabiques contiguos por el hueco de la esquina; si fuera de una celda entera,
	# se comería el suelo útil de las dos celdas vecinas y la gente no podría pegarse a la pared.
	var grosor: float = float(_tam_celda) / 3.0
	for clave: String in _construccion.muros():
		var partes: PackedStringArray = clave.split(":")
		if partes.size() != 3:
			continue
		if _construccion.tipo_muro_de_clave(clave) == &"puerta":
			continue   # por la puerta SE PASA: no se recorta
		var cx: int = int(partes[1])
		var cy: int = int(partes[2])
		var esq: Vector2 = Vector2(float(cx), float(cy)) * float(_tam_celda)
		var largo := float(_tam_celda)
		var a0: Vector2
		var a1: Vector2
		if partes[0] == "h":
			a0 = esq - Vector2(0.0, grosor / 2.0)          # arista de ARRIBA: franja horizontal
			a1 = a0 + Vector2(largo, grosor)
		else:
			a0 = esq - Vector2(grosor / 2.0, 0.0)          # arista IZQUIERDA: franja vertical
			a1 = a0 + Vector2(grosor, largo)
		datos.add_obstruction_outline(PackedVector2Array([
			a0, Vector2(a1.x, a0.y), a1, Vector2(a0.x, a1.y),
		]))
	var poligono := NavigationPolygon.new()
	poligono.agent_radius = 8.0
	NavigationServer2D.bake_from_source_geometry_data(poligono, datos)
	_region.navigation_polygon = poligono


## Nace el NPC de una persona recién admitida: aparece en la calle; su primer destino se lo dará
## su estado (dentro/fuera) en su siguiente physics frame (nunca en _ready — gotcha del server).
func spawn(persona: RefCounted) -> void:
	var npc: CharacterBody2D = NPCScript.new()
	var color: Color
	if persona.tramite_id() == &"tie":
		color = COLOR_TIE   # feedback flujo-008: el TIE se distingue del DNI/Pasaporte de un vistazo
	elif persona.servicio() == &"Documentacion":
		color = COLOR_DOC
	else:
		color = COLOR_ODAC
	npc.position = _punto_calle(persona.numero_turno)
	# El cuerpo va al plano lógico (oculto); su muñeco se registra solo en la capa de escena desde
	# `configurar`. ⚠️ ORDEN: primero `add_child` y luego `configurar` — `configurar` llama a
	# `registrar_muneco`, y la posición del muñeco se copia del cuerpo, que ya debe estar colocado.
	_capa_logica.add_child(npc)
	npc.configurar(persona, self, _flujo.velocidad_npc_px_s, color)
	npc.muneco.position = Proyeccion.proyectar(npc.position)


## El NPC llegó a la salida (Resuelta/Abandonando): libera su asiento y desaparece.
func despachar(npc: Node) -> void:
	_liberar_plaza(npc)
	npc.queue_free()


## El destino según el estado LÓGICO de su persona (el NPC lo pide SOLO al cambiar de estado).
func destino_de(npc: Node) -> Vector2:
	var persona: RefCounted = npc.persona
	match persona.estado:
		&"esperando_dentro":
			# ¿Se ha levantado a por un café? (story com-003) Entonces su destino es la máquina; al
			# terminar vuelve a su sitio de siempre (`_sitio_en_espera` es idempotente: le devuelve
			# la plaza que tenía reservada, no le busca otra).
			var comodidad: StringName = comodidad_de(persona)
			if comodidad != &"":
				return _construccion.centro_de_celda(_construccion.posicion_de(comodidad))
			return _sitio_en_espera(npc)
		&"esperando_fuera":
			return _punto_calle(persona.numero_turno)
		&"llamada", &"en_atencion":
			_liberar_plaza(npc)
			# El RESERVADO de la llamada anticipada no va al mismo sitio que quien esta siendo atendido:
			# espera de pie A UN LADO del mostrador, como en una oficina de verdad cuando ya te han
			# llamado pero el de delante sigue. Sin esto los dos munecos se pintaban SUPERPUESTOS.
			var suyo: StringName = _flujo.puesto_de(persona)
			if _flujo.siguiente_de(suyo) == persona:
				# LA LÍNEA DE DISCRECIÓN (petición del usuario, 2026-07-30: *"queda mal que esté un
				# ciudadano denunciando y otro al lado pudiendo escuchar todo"*). Antes el llamado
				# por anticipado esperaba a UN LADO del mostrador, pegado a quien estaba siendo
				# atendido — que en una comisaría de verdad es justo lo que no puede pasar: nadie
				# pone la oreja mientras otro pone una denuncia.
				#
				# Ahora espera DOS CASILLAS más atrás, en la línea que hay pintada en el suelo de
				# cualquier ventanilla real. Es una decisión de DIBUJO, no de modelo: el turno, el
				# cronómetro y el momento de la llamada no cambian; solo dónde se planta el muñeco.
				return _frente_del_puesto(persona) + Vector2(0.0, float(_tam_celda) * 2.0)
			return _frente_del_puesto(persona)
		_:
			# Resuelta / Abandonando (o cualquier raro): a la calle; despawn al llegar.
			_liberar_plaza(npc)
			return _punto_calle(persona.numero_turno)


## Un punto de la calle (el margen izquierdo, FUERA del edificio): entrada, cola exterior y
## salida. Repartido en vertical por turno para que la cola exterior se vea como grupito.
func _punto_calle(turno: int) -> Vector2:
	var base := Vector2(-1.0 * _tam_celda, 6.5 * _tam_celda)
	return base + Vector2(0.0, float(turno % 6) * 18.0 - 54.0)


## Sitio en la espera: PRIMERO un asiento libre de sus salas; sin asiento libre, un hueco de pie
## LIBRE (una celda de la sala que no sea banco y que no tenga ya a otro). Una celda = una persona:
## la plaza se RESERVA en `_plaza_de` hasta que el NPC la suelta (llamada/salida/despacho).
## Feedback 2026-07-25: antes el hueco de pie se calculaba solo por turno sobre el rect de la sala
## (que INCLUYE las celdas de los bancos) → un de-pie podía plantarse encima de un sentado.
## Solo si la sala está físicamente a tope (aforo F3 admite hasta 1,2 personas/celda) se apretujan:
## misma celda con un desvío sub-celda determinista, para que se vean dos cuerpos y no uno.
func _sitio_en_espera(npc: Node) -> Vector2:
	var persona: RefCounted = npc.persona
	var propia: Vector2i = _plaza_reservada_de(npc)
	if propia != CELDA_NULA:   # idempotente: quien ya tiene plaza no se muda al re-preguntar
		return _construccion.centro_de_celda(propia)
	var salas: Array[StringName] = _construccion.salas_de_espera_de(persona.servicio())
	for sala_id: StringName in salas:
		for asiento_id: StringName in _construccion.asientos_de_sala(sala_id):
			var celda_asiento: Vector2i = _construccion.posicion_de(asiento_id)
			if _plaza_libre(celda_asiento):
				_plaza_de[celda_asiento] = npc
				return _construccion.centro_de_celda(celda_asiento)
	for sala_id: StringName in salas:
		var celda_pie: Vector2i = _hueco_de_pie_libre(sala_id, persona.numero_turno)
		if celda_pie != CELDA_NULA:
			_plaza_de[celda_pie] = npc
			return _construccion.centro_de_celda(celda_pie)
	if not salas.is_empty():
		return _sitio_apretujado(salas[0], persona.numero_turno)
	return _punto_calle(persona.numero_turno)


## Primera celda LIBRE de la sala que no sea un banco, barriendo desde un origen determinista por
## turno (y dando la vuelta) para que la gente se reparta en vez de amontonarse en una esquina.
func _hueco_de_pie_libre(sala_id: StringName, turno: int) -> Vector2i:
	var rect: Rect2i = _construccion.rect_de_sala(sala_id)
	var area: int = rect.get_area()
	if area <= 0:
		return CELDA_NULA
	var bancos: Dictionary = {}
	for asiento_id: StringName in _construccion.asientos_de_sala(sala_id):
		bancos[_construccion.posicion_de(asiento_id)] = true
	var origen: int = turno % area
	for salto: int in range(area):
		var celda: Vector2i = _celda_del_rect(rect, (origen + salto) % area)
		if not bancos.has(celda) and _plaza_libre(celda):
			return celda
	return CELDA_NULA


## Sala a REVENTAR: se comparte celda (el aforo lógico lo permite), pero con un desvío sub-celda
## determinista por turno para que no queden dos cuerpos exactamente superpuestos.
func _sitio_apretujado(sala_id: StringName, turno: int) -> Vector2:
	var rect: Rect2i = _construccion.rect_de_sala(sala_id)
	var celda: Vector2i = _celda_del_rect(rect, turno % maxi(rect.get_area(), 1))
	var desvio := Vector2(
		float(turno % 3) * 7.0 - 7.0, float((turno / 3) % 3) * 7.0 - 7.0
	)
	return _construccion.centro_de_celda(celda) + desvio


## Celda i-ésima de un rect, en orden de lectura (fila a fila).
func _celda_del_rect(rect: Rect2i, indice: int) -> Vector2i:
	return rect.position + Vector2i(indice % rect.size.x, indice / rect.size.x)


## Una celda está libre si nadie la reservó o su ocupante ya desapareció (purga de plazas fantasma).
func _plaza_libre(celda: Vector2i) -> bool:
	if not _plaza_de.has(celda):
		return true
	if is_instance_valid(_plaza_de[celda]):
		return false
	_plaza_de.erase(celda)
	return true


## La celda que este NPC tiene reservada (CELDA_NULA si ninguna).
func _plaza_reservada_de(npc: Node) -> Vector2i:
	for celda: Vector2i in _plaza_de:
		if _plaza_de[celda] == npc:
			return celda
	return CELDA_NULA


## La celda FRENTE al mostrador (el puesto está recortado del polígono navegable).
func _frente_del_puesto(persona: RefCounted) -> Vector2:
	var puesto_id: StringName = _flujo.puesto_de(persona)
	if puesto_id == &"":
		return _punto_calle(persona.numero_turno)
	var celda: Vector2i = _construccion.posicion_de(puesto_id)
	return _construccion.centro_de_celda(celda + Vector2i(0, 1))


## Suelta la plaza del NPC (y de paso purga las de NPCs ya desaparecidos): TODAS sus entradas, no
## solo la primera — si alguna vez reservase dos, la segunda quedaría bloqueada para siempre.
func _liberar_plaza(npc: Node) -> void:
	var sueltas: Array[Vector2i] = []
	for celda: Vector2i in _plaza_de:
		var ocupante: Node = _plaza_de[celda]
		if ocupante == npc or not is_instance_valid(ocupante):
			sueltas.append(celda)
	for celda: Vector2i in sueltas:
		_plaza_de.erase(celda)


# ── Visual de puestos: policía + rótulo de estado (feedback flujo-008) ───────────────────────
## Refresco COSMÉTICO por PULL de getters (FL5/ADR-0001: jamás muta la simulación). Corre en
## _physics_process TRAS el rebake (el layout ya está estable). Cero allocs por frame: un Node2D
## contenedor por puesto que persiste; el DIFF (metas `nombre`/`estado` en el contenedor) toca
## los nodos SOLO cuando el operativo o el estado cambian. El RÓTULO se muestra para TODOS los
## puestos registrados (también SIN AGENTE/CERRADO — un puesto sin dotar debe verse); el MUÑECO
## del policía solo si el puesto está dotado.
func _refrescar_puestos() -> void:
	if _flujo == null:
		return
	var vivos: Dictionary[StringName, bool] = {}
	for puesto_id: StringName in _flujo.puestos_registrados():
		var celda: Vector2i = _construccion.posicion_de(puesto_id)
		if celda == Vector2i(-1, -1):
			continue   # puesto sin posición en el layout (raro): sin visual
		vivos[puesto_id] = true
		var dotado: bool = _personal != null and _personal.puesto_dotado(puesto_id)
		var nombre: String = ""
		var cansancio: float = 0.0
		if dotado:
			var agente: RefCounted = _personal.agente_de(puesto_id)
			nombre = agente.nombre if agente != null else ""
			cansancio = agente.cansancio if agente != null else 0.0
		var estado: StringName = _flujo.estado_de_puesto(puesto_id)
		# Bienestar #13: si su titular está de café, se DICE — y con los minutos que le quedan. Una
		# ventanilla parada sin explicación parece un bug; con el motivo delante, es una decisión de
		# gestión (¿monto una sala de descanso? ¿contrato a alguien que cubra?).
		var de_cafe: RefCounted = (
			_personal.agente_descansando_en(puesto_id)
			if _personal != null and _personal.has_method("agente_descansando_en") else null
		)
		if de_cafe != null:
			estado = &"descansando"
			nombre = de_cafe.nombre
			var quedan: int = roundi(_personal.minutos_de_descanso_restantes(de_cafe))
			_rotulo_extra[puesto_id] = "☕ %d min" % quedan
		_asegurar_visual_puesto(puesto_id, celda)
		# Si el puesto se MUEVE (modo obra), su visual le sigue (DIFF por celda vista).
		var contenedor: Node2D = _visual_de_puesto[puesto_id]
		if contenedor.get_meta(&"celda", Vector2i(-9999, -9999)) != celda:
			contenedor.set_meta(&"celda", celda)
			# ISOMETRICO: el mostrador se DIBUJA, asi que va en pantalla; y se ancla por la BASE
			# (el centro del rombo de su celda), no flotando media celda por encima como antes.
			# OJO al origen: el contenedor cuelga de `_capa_escena`, que YA esta puesta en
			# `pos_suelo` — asi que aqui va la proyeccion PELADA (`Proyeccion.centro_iso`) y NO
			# `Construccion.centro_en_pantalla`, que ademas suma el origen. Sumarlo dos veces fue
			# el bug que reporto el usuario nada mas abrir la ventana: "los funcionarios no estan
			# en sus puestos, estan fuera de la comisaria" — los mostradores se iban un tablero
			# entero hacia abajo a la derecha, y con ellos los policias que los atienden.
			contenedor.position = Proyeccion.centro_iso(celda)
		_actualizar_visual_puesto(
			puesto_id, dotado, nombre, estado, _rotulo_extra.get(puesto_id, ""), cansancio,
			_regreso_en_curso.has(puesto_id), _incorporacion_en_curso.has(puesto_id)
		)
		if de_cafe == null:
			_rotulo_extra.erase(puesto_id)
	# Retira los visuales de puestos que ya no están registrados (demolidos / cargados fuera).
	for puesto_id: StringName in _visual_de_puesto.keys():
		if not vivos.has(puesto_id):
			_visual_de_puesto[puesto_id].queue_free()
			_visual_de_puesto.erase(puesto_id)


## El trayecto cosmético del descanso (Bienestar #13 + feedback demo 2026-07-29). YA NO se reconstruye
## por firma de conteo (ese patrón creaba un muñeco NUEVO directamente puesto dentro de la sala → el
## teletransporte que reportó el usuario en la demo). Ahora cada agente tiene COMO MUCHO un viaje
## activo en `_camino_descanso`, creado una vez al empezar el descanso y REUSADO (solo se MUEVE) hasta
## que vuelve. Tres pasadas, cada una O(agentes activos), nunca O(reconstruir la sala entera):
##   1) ALTAS   — quien acaba de pasar a `descansando` sin viaje todavía → nace en su mostrador.
##   2) BAJAS   — quien ya no está `descansando` pero su viaje seguía "yendo"/"en_sala" → media
##                vuelta hacia el mostrador (si aún iba de camino a la sala, gira EN EL SITIO: el
##                viaje es solo visual, no espera a "llegar" para empezar a volver — no alarga ni
##                acorta la pausa, que sigue siendo 100% de `Personal`).
##   3) AVANCE  — cada viaje vivo se mueve un paso (mismo NavigationAgent2D + get_next_path_position
##                + move_and_slide que npc_ciudadano), o se cierra si ya ha llegado del todo.
## Sin sala construida: el viaje de ida termina en la calle y el muñeco desaparece ahí — sin sala no
## se pinta a nadie dentro (esa ausencia informa; no se inventa una sala fantasma). La vuelta, en ese
## caso, NO se anima (no hay desde dónde) y el mostrador recupera a su titular de golpe, igual que
## pasa hoy — el teletransporte que se elimina aquí es el de la sala, no el de la calle.
func _refrescar_descansos() -> void:
	if _personal == null or _construccion == null:
		return
	for agente: RefCounted in _personal.plantilla:
		if agente.estado == &"descansando" and not _camino_descanso.has(agente):
			_iniciar_camino_descanso(agente)
	for agente: RefCounted in _camino_descanso:
		var viaje: Dictionary = _camino_descanso[agente]
		var sigue_descansando: bool = agente.estado == &"descansando" and _personal.plantilla.has(agente)
		if not sigue_descansando and viaje["fase"] != &"volviendo":
			_iniciar_vuelta(viaje)
	var terminados: Array[RefCounted] = []
	for agente: RefCounted in _camino_descanso:
		if _avanzar_camino_descanso(_camino_descanso[agente]):
			terminados.append(agente)
	for agente: RefCounted in terminados:
		_cerrar_camino_descanso(_camino_descanso[agente])
		_camino_descanso.erase(agente)


## La primera sala de tipo "descanso" construida (`&""` si no hay ninguna).
func _sala_de_descanso() -> StringName:
	var salas: Array[StringName] = _construccion.salas_de_tipo("descanso")
	return salas[0] if not salas.is_empty() else &""


## Arranca el viaje de IDA: crea el muñeco caminante UNA vez, exactamente en el punto al que ya
## navegan los ciudadanos que van a esa ventanilla (`_punto_de_su_puesto`) — el mismo punto garantiza
## que el arranque cae dentro del polígono navegable (el mostrador en sí está recortado como
## obstáculo en `_bakear_navegacion`; el punto EXACTO donde se planta el muñeco quieto del mostrador
## no lo está, y no vale para pathfinding). El target real se aplica un frame más tarde (`listo`,
## gotcha del NavigationServer) — este frame solo se deja el viaje listo para que lo recoja
## `_avanzar_camino_descanso`.
func _iniciar_camino_descanso(agente: RefCounted) -> void:
	var puesto_id: StringName = agente.puesto_id
	var muneco: CharacterBody2D = _crear_muneco_caminante()
	muneco.position = _punto_de_su_puesto(puesto_id)
	_capa_descansos.add_child(muneco)
	var sala: StringName = _sala_de_descanso()
	var celda_sala: Vector2i = CELDA_NULA
	var destino: Vector2
	if sala != &"":
		celda_sala = _asiento_descanso_libre(sala)
		_asiento_descanso[celda_sala] = agente
		destino = _construccion.centro_de_celda(celda_sala)
	else:
		# Sin sala: a la calle, con reparto determinista por la fila de su puesto para que varios sin
		# sala a la vez no salgan pegados unos a otros.
		destino = _punto_calle(_construccion.posicion_de(puesto_id).y)
	_camino_descanso[agente] = {
		"muneco": muneco,
		"nav": muneco.get_node("Nav") as NavigationAgent2D,
		"fase": &"yendo",
		"puesto_id": puesto_id,
		"celda_sala": celda_sala,
		"listo": false,
		"destino_pendiente": destino,
	}


## Da la vuelta a un viaje YA EXISTENTE (nunca crea un muñeco nuevo): libera el asiento si lo tenía y
## le quita la taza, y reapunta su destino al mostrador. Si aún iba "yendo" (la pausa terminó antes de
## llegar a la sala), gira desde donde esté — no hace falta que "llegue" primero.
func _iniciar_vuelta(viaje: Dictionary) -> void:
	if viaje["celda_sala"] != CELDA_NULA:
		_asiento_descanso.erase(viaje["celda_sala"])
		_quitar_taza(viaje["muneco"])
		viaje["celda_sala"] = CELDA_NULA
	viaje["fase"] = &"volviendo"
	viaje["destino_pendiente"] = _punto_de_su_puesto(viaje["puesto_id"])
	_regreso_en_curso[viaje["puesto_id"]] = true


## Un paso GENÉRICO de cualquier trayecto cosmético de este archivo (descanso E incorporación):
## aplica el gotcha del primer physics frame del NavigationServer (el target no sincroniza hasta
## entonces — engine-reference/.../navigation.md), consume el `destino_pendiente` que aún no se
## haya aplicado y mueve el muñeco un paso — MISMO patrón que npc_ciudadano (NavigationAgent2D +
## get_next_path_position + move_and_slide, respetando la Pausa/velocidad de Tiempo: en Pausa nadie
## anda, igual que el resto de NPCs de este archivo). Devuelve `true` SOLO cuando la navegación ha
## llegado a su destino ESTE frame — qué significa "llegar" lo decide quien llama (para el descanso,
## pasar a "en_sala"; para la incorporación, cerrar el viaje del todo).
func _mover_paso(viaje: Dictionary) -> bool:
	var nav: NavigationAgent2D = viaje["nav"] as NavigationAgent2D
	if not viaje["listo"]:
		viaje["listo"] = true   # el NavigationServer sincroniza EN este frame: el target va al siguiente
		return false
	if viaje.has("destino_pendiente"):
		nav.target_position = viaje["destino_pendiente"]
		viaje.erase("destino_pendiente")
	var mult: float = Tiempo.multiplicador_velocidad
	if mult <= 0.0:
		return false
	var muneco: CharacterBody2D = viaje["muneco"] as CharacterBody2D
	if nav.is_navigation_finished():
		return true
	var siguiente: Vector2 = nav.get_next_path_position()
	muneco.velocity = muneco.global_position.direction_to(siguiente) * _flujo.velocidad_npc_px_s * mult
	muneco.move_and_slide()
	return false


## Avanza un viaje de DESCANSO un paso (delega el movimiento en `_mover_paso`, compartido con la
## incorporación). Devuelve `true` si el viaje ha terminado del todo (se cierra fuera, en
## `_refrescar_descansos`, para no borrar del dict mientras se itera).
func _avanzar_camino_descanso(viaje: Dictionary) -> bool:
	if viaje["fase"] == &"en_sala":
		return false   # quieto con su taza: nada que mover ni que comprobar
	if not _mover_paso(viaje):
		return false
	# Llegó: "yendo" CON sala → se queda ("en_sala", con su taza); "yendo" SIN sala o "volviendo" →
	# viaje completo.
	if viaje["fase"] == &"yendo" and viaje["celda_sala"] != CELDA_NULA:
		viaje["fase"] = &"en_sala"
		_poner_taza(viaje["muneco"])
		return false
	return true


## Cierra un viaje terminado: borra el muñeco y, si terminaba una VUELTA, libera la supresión del
## mostrador (`_regreso_en_curso`) — a partir de aquí el DIFF de `_actualizar_visual_puesto` decide si
## el mostrador vuelve a enseñar a su titular real. (La entrada en `_camino_descanso` la borra el
## llamador — este método no toca ese dict, solo lo que cuelga del viaje.)
func _cerrar_camino_descanso(viaje: Dictionary) -> void:
	if viaje["fase"] == &"volviendo":
		_regreso_en_curso.erase(viaje["puesto_id"])
	_borrar_caminante(viaje["muneco"] as Node)


## El punto al que YA navegan los ciudadanos atendidos en este puesto (`_frente_del_puesto`, pero sin
## necesitar una `persona`): el mostrador en sí está recortado como obstáculo, así que este es el
## único punto garantizado dentro del polígono navegable para ese puesto. Puesto inexistente
## (despedido/desasignado/demolido mientras descansaba) → un punto de calle, como cualquier NPC sin
## destino real.
func _punto_de_su_puesto(puesto_id: StringName) -> Vector2:
	if puesto_id == &"":
		return _punto_calle(0)
	var celda: Vector2i = _construccion.posicion_de(puesto_id)
	if celda == CELDA_NULA:
		return _punto_calle(0)
	return _construccion.centro_de_celda(celda + Vector2i(0, 1))


## Primera celda LIBRE de la sala de descanso (mismo barrido en lectura que usa `_hueco_de_pie_libre`
## para la sala de espera, pero en su propio dict — son salas distintas). Sin hueco no debería pasar
## nunca (`Personal.hay_sitio_para_descansar` ya limita el aforo antes de mandar a nadie aquí); si
## pasara, mejor una superposición rara en la esquina que un crash.
func _asiento_descanso_libre(sala_id: StringName) -> Vector2i:
	var rect: Rect2i = _construccion.rect_de_sala(sala_id)
	if rect.get_area() <= 0:
		return rect.position
	for indice: int in range(rect.get_area()):
		var celda: Vector2i = _celda_del_rect(rect, indice)
		if not _asiento_descanso.has(celda):
			return celda
	return rect.position


## Añade la taza (☕) al llegar a la sala — el mismo indicador que ya existía, ahora sobre el muñeco
## que de verdad caminó hasta allí en vez de uno recién creado en el sitio.
func _poner_taza(cuerpo: Node2D) -> void:
	var muneco: Node2D = _visual_caminante(cuerpo)
	if muneco == null:
		return
	var taza := Label.new()
	taza.name = "Taza"
	taza.text = "☕"
	taza.add_theme_font_size_override("font_size", 10)
	taza.position = Vector2(-6, -34)
	taza.mouse_filter = Control.MOUSE_FILTER_IGNORE
	muneco.add_child(taza)


## Quita la taza al levantarse a volver (defensivo: si el viaje era sin sala, nunca la tuvo — no hay
## nada que hacer).
func _quitar_taza(cuerpo: Node2D) -> void:
	var muneco: Node2D = _visual_caminante(cuerpo)
	if muneco == null:
		return
	var taza: Node = muneco.get_node_or_null("Taza")
	if taza != null:
		taza.queue_free()


## El trayecto cosmético de la LLEGADA (ver comentario de `_camino_incorporacion`). Dos pasadas,
## mismo espíritu que `_refrescar_descansos` pero sin fases intermedias — un único tramo puerta→
## puesto:
##   1) ALTAS — quien el modelo ya dice que viene (`va_de_camino_al_puesto`) y aún no tiene viaje.
##   2) AVANCE — cada viaje vivo se mueve un paso; se cierra si YA LLEGÓ (nav) o si perdió el puesto
##      por el que venía mientras andaba (despido/reasignación/demolición — `Personal` ya lo saca
##      solo de `_viniendo_a_trabajar`; aquí basta con comparar `agente.puesto_id` contra el puesto
##      del viaje). Cerrar por NAV (no por el aviso del modelo de "ya ha llegado") es a propósito:
##      el modelo cronometra con minutos, el muñeco con píxeles — si se cerrase por el modelo, el
##      mostrador fijo podría reaparecer ANTES de que el muñeco llegara de verdad y se verían dos
##      policías a la vez (el mismo motivo que ya cubre `_regreso_en_curso` en el descanso).
func _refrescar_incorporaciones() -> void:
	if _personal == null or _construccion == null:
		return
	for agente: RefCounted in _personal.plantilla:
		if _personal.va_de_camino_al_puesto(agente) and not _camino_incorporacion.has(agente):
			_iniciar_camino_incorporacion(agente)
	var terminados: Array[RefCounted] = []
	for agente: RefCounted in _camino_incorporacion:
		var viaje: Dictionary = _camino_incorporacion[agente]
		var perdio_el_puesto: bool = agente.puesto_id != viaje["puesto_id"]
		if perdio_el_puesto or _mover_paso(viaje):
			terminados.append(agente)
	for agente: RefCounted in terminados:
		_cerrar_camino_incorporacion(_camino_incorporacion[agente])
		_camino_incorporacion.erase(agente)


## Arranca el viaje de LLEGADA: crea el muñeco caminante UNA vez, en la calle junto a la puerta —
## MISMO punto que usa el descanso sin sala construida (`_punto_calle`, con la fila del puesto como
## clave determinista para que varias incorporaciones a la vez no nazcan pegadas unas a otras) — y
## lo manda al punto frente a su ventanilla (`_punto_de_su_puesto`, ya usado por el descanso: dentro
## del polígono navegable, a diferencia del mostrador en sí, que está recortado como obstáculo). El
## target real se aplica un frame más tarde (gotcha del NavigationServer, ver `_mover_paso`).
func _iniciar_camino_incorporacion(agente: RefCounted) -> void:
	var puesto_id: StringName = agente.puesto_id
	var muneco: CharacterBody2D = _crear_muneco_caminante()
	muneco.position = _punto_calle(_construccion.posicion_de(puesto_id).y)
	_capa_descansos.add_child(muneco)
	_camino_incorporacion[agente] = {
		"muneco": muneco,
		"nav": muneco.get_node("Nav") as NavigationAgent2D,
		"puesto_id": puesto_id,
		"listo": false,
		"destino_pendiente": _punto_de_su_puesto(puesto_id),
	}
	_incorporacion_en_curso[puesto_id] = true


## Cierra un viaje de incorporación terminado (llegó, o perdió el puesto por el camino): borra el
## muñeco y libera la supresión del mostrador — a partir de aquí el DIFF de `_actualizar_visual_
## puesto` decide si el mostrador enseña a su titular real (si el puesto ya no es suyo, no lo hará:
## `dotado`/`agente_de` ya no lo devuelven).
func _cerrar_camino_incorporacion(viaje: Dictionary) -> void:
	_incorporacion_en_curso.erase(viaje["puesto_id"])
	_borrar_caminante(viaje["muneco"] as Node)


## Torso + cabeza del uniforme (las mismas piezas, pixel a pixel) añadidas a `destino`: lo comparten
## el muñeco QUIETO del mostrador (`_asegurar_visual_puesto`) y el CAMINANTE de esta sección
## (`_crear_muneco_caminante`), para que sea el mismo cuerpo se mire donde se mire.
## ISOMÉTRICO (2026-07-30): ANCLADO POR LA BASE — los pies caen en (0,0) del nodo, que es el punto
## de la celda donde de verdad está de pie. Antes iba centrado a media altura (torso en y=-8): en
## cenital daba igual, en isométrico el policía parecería flotar por encima de su mostrador.
func _anadir_cuerpo_policia(destino: Node2D) -> void:
	var torso := ColorRect.new()
	torso.color = COLOR_POLICIA_TORSO
	torso.size = Vector2(12, 16)
	torso.position = Vector2(-6, -16)
	torso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	destino.add_child(torso)
	var cabeza := ColorRect.new()
	cabeza.color = COLOR_POLICIA_TORSO.lightened(0.55)
	cabeza.size = Vector2(8, 6)
	cabeza.position = Vector2(-4, -22)
	cabeza.mouse_filter = Control.MOUSE_FILTER_IGNORE
	destino.add_child(cabeza)


## Un muñeco de policía que CAMINA: mismo cuerpo que el fijo del mostrador, pero sobre un
## CharacterBody2D con NavigationAgent2D hijo — el MISMO sistema que npc_ciudadano (ADR-0004): fantasma
## (collision_layer/mask 0, sin avoidance — MVP) y movido a mano desde `_avanzar_camino_descanso` con
## get_next_path_position + move_and_slide (no tiene su propio `_physics_process`: lo empuja este
## archivo, que es quien controla la cadencia del DIFF).
func _crear_muneco_caminante() -> CharacterBody2D:
	var muneco := CharacterBody2D.new()
	muneco.collision_layer = 0
	muneco.collision_mask = 0
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 7.0
	forma.shape = circulo
	muneco.add_child(forma)
	var nav := NavigationAgent2D.new()
	nav.name = "Nav"
	nav.radius = 7.0
	nav.path_desired_distance = 4.0
	nav.target_desired_distance = 6.0
	nav.avoidance_enabled = false   # manifiesto: OFF (Experimental en 4.6), igual que npc_ciudadano
	muneco.add_child(nav)
	# ISOMÉTRICO (2026-07-30): el CUERPO (esto) anda por el plano lógico cuadrado y no se dibuja;
	# lo que se ve es este otro nodo, que cuelga de la capa de escena y al que se le copia la
	# posición ya proyectada en `_sincronizar_caminantes`. Mismo reparto que en npc_ciudadano.
	var visual := Node2D.new()
	visual.name = "MunecoPolicia"
	_anadir_cuerpo_policia(visual)
	registrar_muneco(visual)
	muneco.set_meta(&"visual", visual)
	return muneco


## El muñeco VISIBLE de un cuerpo caminante (null si ya no existe). Todo lo que sea DIBUJO sobre un
## caminante (la taza del café, y mañana su sprite) va aquí, nunca en el cuerpo.
func _visual_caminante(cuerpo: Node) -> Node2D:
	if cuerpo == null or not is_instance_valid(cuerpo):
		return null
	var visual: Variant = cuerpo.get_meta(&"visual", null)
	if visual == null or not is_instance_valid(visual):
		return null
	return visual as Node2D


## Borra un cuerpo caminante Y su muñeco. Siempre por aquí: soltar solo el cuerpo dejaría el muñeco
## dibujado para siempre en el sitio donde murió (un policía fantasma junto a la máquina de café).
func _borrar_caminante(cuerpo: Node) -> void:
	var visual: Node2D = _visual_caminante(cuerpo)
	if visual != null:
		visual.queue_free()
	if cuerpo != null and is_instance_valid(cuerpo):
		cuerpo.queue_free()


## Copia la posición de cada cuerpo caminante a su muñeco, ya proyectada. Una pasada por physics
## frame sobre los viajes VIVOS (descansos + incorporaciones): son unos pocos, no la plantilla
## entera. Es el equivalente del `muneco.position = ...` que npc_ciudadano hace en su propio
## `_physics_process` — los caminantes no tienen script propio, así que lo hace este archivo.
func _sincronizar_caminantes() -> void:
	for cuerpo: Node in _capa_descansos.get_children():
		var visual: Node2D = _visual_caminante(cuerpo)
		if visual != null:
			visual.position = Proyeccion.proyectar((cuerpo as Node2D).position)


## Crea (una vez) el contenedor del puesto con sus piezas hijas fijas: muñeco policía (torso +
## cabeza), etiqueta de nombre (font 8, bajo el muñeco), rótulo de estado (font 9, sobre el
## mostrador) y etiqueta "Extra" (font 9, minutos de descanso restantes — franja compartida con la
## barra de cansancio, ver su comentario de const). El contenedor se ancla sobre la celda del
## puesto; las piezas van en local.
func _asegurar_visual_puesto(puesto_id: StringName, celda: Vector2i) -> void:
	if _visual_de_puesto.has(puesto_id):
		return
	var contenedor := Node2D.new()
	contenedor.name = "Puesto_%s" % puesto_id
	contenedor.position = Proyeccion.centro_iso(celda)
	# El muñeco policía (torso + cabeza, estilo npc_ciudadano); se muestra solo si el puesto está dotado.
	var policia := Node2D.new()
	policia.name = "Policia"
	# LA VENTANILLA SON TRES CASILLAS EN FILA (petición del usuario, 2026-07-30, viendo el
	# isométrico: *"la mesa de atención debe ser como 3 casillas: 1 donde está el policía, otra la
	# mesa y otra la silla con el ciudadano; ahora veo encima de la mesa al funcionario"*):
	#
	#     [ funcionario ]  ←  celda - (0,1),  DETRÁS del mostrador
	#     [   MESA      ]  ←  la celda del puesto en el modelo
	#     [  ciudadano  ]  ←  celda + (0,1),  donde ya le manda `_frente_del_puesto`
	#
	# El ciudadano ya iba a su casilla desde antes; lo que faltaba era sacar al funcionario de
	# ENCIMA de la mesa. Se mueve solo el DIBUJO: el modelo sigue teniendo el puesto en una celda,
	# así que ni costes, ni validación de colocación, ni un solo test cambian.
	policia.position = _POLICIA_DETRAS
	contenedor.add_child(policia)
	# Etiqueta de nombre (bajo el muñeco). Ancho fijo 60 + centrado para no depender del texto. Font
	# 8 (un punto menos que el resto): entre nombre/estado/minutos, el nombre es el dato MENOS
	# accionable (feedback 2026-07-29 de solape) — si algo tiene que ceder espacio, es él.
	var lbl_nombre := _label_centrada(8, Vector2(-30, 10))
	lbl_nombre.name = "Nombre"
	contenedor.add_child(lbl_nombre)
	# Barra de cansancio (bienestar-013, feedback anticipatorio): bajo la etiqueta de nombre. Dos
	# piezas — un FONDO oscuro que marca dónde está el 100 % (respaldo NO cromático: en escala de
	# grises se sigue viendo cuánto le falta al relleno para llegar al borde) y un RELLENO que se
	# encoge y cambia de color según el cansancio real. Ambas nacen ocultas: `_actualizar_visual_
	# puesto` decide si procede enseñarlas (puesto dotado, no cerrado, agente no está de café).
	var pos_barra := Vector2(-ANCHO_BARRA_CANSANCIO * 0.5, POS_Y_BARRA_CANSANCIO)
	var barra_fondo := ColorRect.new()
	barra_fondo.name = "BarraCansancioFondo"
	barra_fondo.color = Color(0.08, 0.08, 0.08, 0.85)
	barra_fondo.size = Vector2(ANCHO_BARRA_CANSANCIO, ALTO_BARRA_CANSANCIO)
	barra_fondo.position = pos_barra
	barra_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_fondo.visible = false
	contenedor.add_child(barra_fondo)
	var barra_relleno := ColorRect.new()
	barra_relleno.name = "BarraCansancioRelleno"
	barra_relleno.color = COLOR_ESTADO[&"libre"]
	barra_relleno.size = Vector2(ANCHO_BARRA_CANSANCIO, ALTO_BARRA_CANSANCIO)
	barra_relleno.position = pos_barra
	barra_relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_relleno.visible = false
	contenedor.add_child(barra_relleno)
	# Minutos de descanso restantes, en SU PROPIA etiqueta (feedback 2026-07-29: *"el tiempo restante
	# que le queda de descanso se sobrepone con otras letras"*). Antes se concatenaba como segunda
	# línea de "Estado" con un salto de línea — esa línea extra crecía hacia abajo e invadía el
	# nombre. Con etiqueta propia, "Estado" mide SIEMPRE una sola línea (ver `_actualizar_visual_
	# puesto`) y esta ocupa la franja de la barra de cansancio (mutuamente excluyentes, ver la const).
	var lbl_extra := _label_centrada(9, Vector2(-30, POS_Y_BARRA_CANSANCIO))
	lbl_extra.name = "Extra"
	lbl_extra.visible = false
	contenedor.add_child(lbl_extra)
	# Rótulo de estado (sobre el mostrador). Texto SIEMPRE + color de acento (respaldo daltónico).
	var lbl_estado := _label_centrada(9, Vector2(-30, -_tam_celda * 0.5))
	lbl_estado.name = "Estado"
	contenedor.add_child(lbl_estado)
	_capa_escena.add_child(contenedor)
	_visual_de_puesto[puesto_id] = contenedor


## Aplica el estado por DIFF: solo toca los nodos si el nombre, estado, extra o el TRAMO de
## cansancio vistos cambiaron (metas en el contenedor). El muñeco se muestra/oculta con `dotado`;
## el rótulo siempre visible. `extra` (minutos de descanso) vive en SU PROPIA etiqueta ("Extra"),
## nunca concatenado a "Estado" — feedback 2026-07-29: la línea extra invadía el nombre de abajo.
##
## `cansancio` se CUANTIZA a pasos del 5 % (`int(cansancio / 5.0)`) antes de entrar en la firma:
## el cansancio del agente sube cada physics_process (bienestar-013), así que meterlo crudo (float)
## en la comparación rompería el DIFF por completo — cualquier variación de una centésima ya sería
## "distinto", y el contenedor se repintaría 60 veces por segundo en vez de cero. Cuantizado, la
## barra solo se toca ~20 veces en TODA la vida útil del agente (100 % / 5 % por paso), que es
## exactamente la cadencia con la que tiene sentido que el jugador la vea moverse.
func _actualizar_visual_puesto(
	puesto_id: StringName, dotado: bool, nombre: String, estado: StringName, extra: String,
	cansancio: float = 0.0, oculto_por_regreso: bool = false, oculto_por_llegada: bool = false
) -> void:
	var contenedor: Node2D = _visual_de_puesto[puesto_id]
	var visto_dotado: bool = contenedor.get_meta(&"dotado", false)
	var visto_nombre: String = contenedor.get_meta(&"nombre", "")
	var visto_estado: StringName = contenedor.get_meta(&"estado", &"")
	var visto_extra: String = contenedor.get_meta(&"extra", "")
	var paso_cansancio: int = int(cansancio / 5.0)
	var visto_paso_cansancio: int = contenedor.get_meta(&"paso_cansancio", -1)
	var visto_regreso: bool = contenedor.get_meta(&"oculto_por_regreso", false)
	var visto_llegada: bool = contenedor.get_meta(&"oculto_por_llegada", false)
	if (
		visto_dotado == dotado and visto_nombre == nombre and visto_estado == estado
		and visto_extra == extra and visto_paso_cansancio == paso_cansancio
		and visto_regreso == oculto_por_regreso and visto_llegada == oculto_por_llegada
	):
		return   # nada cambió (ni siquiera el TRAMO de cansancio ni el regreso/llegada): cero toques
	contenedor.set_meta(&"dotado", dotado)
	contenedor.set_meta(&"nombre", nombre)
	contenedor.set_meta(&"estado", estado)
	contenedor.set_meta(&"extra", extra)
	contenedor.set_meta(&"paso_cansancio", paso_cansancio)
	contenedor.set_meta(&"oculto_por_regreso", oculto_por_regreso)
	contenedor.set_meta(&"oculto_por_llegada", oculto_por_llegada)
	# Horario provisional 2026-07-25 "los funcionarios se van": con el puesto cerrado (por horario o
	# por el jugador) el muñeco y su nombre desaparecen del mostrador — caminar a casa es juice futuro.
	var policia: Node2D = contenedor.get_node("Policia")
	# De café, el mostrador se queda VACÍO (quien se ve es el muñeco CAMINANTE de `_refrescar_descansos`)
	# pero el nombre sigue: es SU ventanilla, solo que ahora mismo no hay nadie. `oculto_por_regreso`
	# (feedback demo 2026-07-29) tapa el hueco entre "el modelo ya dice que ha vuelto" y "el muñeco
	# caminante todavía no ha llegado": sin esto se verían DOS policías un instante (el fijo del
	# mostrador + el que aún anda) si le llaman justo al terminar la pausa. `oculto_por_llegada`
	# (petición del usuario 2026-07-29: que se les vea ENTRAR) es el mismo tapaagujeros pero para la
	# incorporación: mientras el muñeco camina desde la puerta hasta su ventanilla, el mostrador debe
	# seguir VACÍO aunque el puesto ya esté `dotado` en el modelo (lo está desde que se le asignó).
	var en_activo: bool = (
		dotado and estado != &"cerrado" and estado != &"descansando"
		and not oculto_por_regreso and not oculto_por_llegada
	)
	policia.visible = en_activo
	var lbl_nombre: Label = contenedor.get_node("Nombre")
	lbl_nombre.visible = estado == &"descansando" or (dotado and estado != &"cerrado")
	lbl_nombre.text = nombre
	var lbl_estado: Label = contenedor.get_node("Estado")
	lbl_estado.text = ROTULO_ESTADO.get(estado, String(estado).to_upper())
	lbl_estado.modulate = COLOR_ESTADO.get(estado, Color.WHITE)
	# Los minutos van en SU PROPIA etiqueta (ver comentario en `_asegurar_visual_puesto`): "Estado" ya
	# NO le añade un salto de línea — así su bloque mide siempre una línea, dotado o no de café, y no
	# puede crecer hacia la franja del nombre.
	var lbl_extra: Label = contenedor.get_node("Extra")
	lbl_extra.visible = extra != ""
	lbl_extra.text = extra
	lbl_extra.modulate = COLOR_ESTADO.get(estado, Color.WHITE)
	# Barra de cansancio: MISMA condición que el muñeco (`en_activo`) — quien está de café ya tiene
	# su rótulo con la cuenta atrás, y un puesto sin dotar o cerrado no tiene a nadie a quien medir.
	var barra_fondo: ColorRect = contenedor.get_node("BarraCansancioFondo")
	var barra_relleno: ColorRect = contenedor.get_node("BarraCansancioRelleno")
	barra_fondo.visible = en_activo
	barra_relleno.visible = en_activo
	if en_activo:
		var fraccion: float = clampf(cansancio, 0.0, 100.0) / 100.0
		barra_relleno.size.x = ANCHO_BARRA_CANSANCIO * fraccion
		barra_relleno.color = _color_cansancio(cansancio)


## Color del RELLENO de la barra de cansancio, por tramo. Reutiliza tonos que YA existen en este
## archivo — nunca uno nuevo: el ámbar es LITERALMENTE `COLOR_ESTADO[&"descansando"]`, el mismo que
## pinta el rótulo "☕ DESCANSO" (un único "ámbar de aviso" en toda la pantalla, no dos matices para
## la misma idea); el rojo crítico es el mismo que el ánimo "al_limite" de paciencia (mismo
## significado: cuidado, esto se acaba). Por debajo del umbral de aviso, el verde de "LIBRE".
func _color_cansancio(cansancio: float) -> Color:
	if cansancio >= UMBRAL_CANSANCIO_CRITICO:
		return COLOR_ANIMO[&"al_limite"]
	elif cansancio >= UMBRAL_CANSANCIO_AVISO:
		return COLOR_ESTADO[&"descansando"]
	return COLOR_ESTADO[&"libre"]


## Una Label decorativa de ancho fijo (60 px) y centrada: mismo tamaño ocupe lo que ocupe el texto
## (evita saltos de layout entre "LIBRE" y "ATENDIENDO"). IGNORA el ratón (gotcha de construcción).
func _label_centrada(tam_fuente: int, pos: Vector2) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", tam_fuente)
	lbl.size = Vector2(60, 0)
	lbl.position = pos
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl
