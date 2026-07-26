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
}
const COLOR_ESTADO: Dictionary[StringName, Color] = {
	&"cerrado": Color(0.6, 0.6, 0.6),
	&"abierto_sin_agente": Color(1.0, 0.8, 0.35),
	&"libre": Color(0.55, 0.9, 0.55),
	&"en_camino": Color(0.6, 0.7, 0.9),
	&"atendiendo": Color(0.5, 0.75, 1.0),
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
## Sentinela de "sin celda" (fuera de todo rect de sala: las celdas del edificio son ≥ 0).
const CELDA_NULA := Vector2i(-1, -1)

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
	return _paciencia.animo_de_persona(persona)


## El ciudadano ESPERANDO más cercano a un punto del mundo (para el clic derecho de "colar"), o null
## si no hay ninguno a tiro. Radio generoso: los muñecos son pequeños y el jugador no tiene por qué
## clavar el píxel.
func ciudadano_en(punto: Vector2, radio: float = 22.0) -> Node:
	var mejor: Node = null
	var mejor_dist: float = radio
	for hijo: Node in get_children():
		if not (hijo is CharacterBody2D) or hijo.get("persona") == null:
			continue
		if animo_de(hijo.persona) == &"":
			continue   # solo se puede colar a quien está esperando (a quien ya llamaron, no)
		var dist: float = (hijo as Node2D).global_position.distance_to(punto)
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
	z_index = 1
	_flujo = flujo
	_construccion = construccion
	_personal = personal
	_tam_celda = tam_celda
	_pos_suelo = pos_suelo
	_columnas = columnas
	_filas = filas
	_region = NavigationRegion2D.new()
	_region.name = "Navegacion"
	add_child(_region)
	_rebake_pendiente = true


## Hook del cambio de layout (lo cablea Main): coalescido — como mucho un bake por frame.
func solicitar_rebake() -> void:
	_rebake_pendiente = true


## Minutos de camino que le quedan a la persona de este NPC (0.0 si su puesto ya no existe o la
## lógica ya lo dio por llegado) — para el paso ADAPTATIVO del muñeco (ver npc_ciudadano).
func camino_restante_min(persona: RefCounted) -> float:
	return _flujo.camino_restante_de(_flujo.puesto_de(persona))


func _physics_process(_delta: float) -> void:
	if _rebake_pendiente:
		_rebake_pendiente = false
		_bakear_navegacion()
	_refrescar_puestos()


## Bake del polígono navegable: el suelo del edificio + dos celdas de "calle" a la izquierda
## (spawn, cola exterior y salida) como área transitable; cada PUESTO se recorta como obstáculo
## (el NPC rodea el mostrador y se detiene en su borde). Los asientos NO se recortan: pisar la
## celda del banco es "sentarse".
func _bakear_navegacion() -> void:
	var datos := NavigationMeshSourceGeometryData2D.new()
	var origen: Vector2 = _pos_suelo + Vector2(-2.0 * _tam_celda, 0.0)
	var fin: Vector2 = _pos_suelo + Vector2(_columnas * _tam_celda, _filas * _tam_celda)
	datos.add_traversable_outline(PackedVector2Array([
		origen, Vector2(fin.x, origen.y), fin, Vector2(origen.x, fin.y),
	]))
	for servicio: String in ["Documentacion", "ODAC", "Seguridad"]:
		for puesto_id: StringName in _construccion.puestos_de_servicio(servicio):
			var esquina: Vector2 = _pos_suelo + Vector2(_construccion.posicion_de(puesto_id)) * float(_tam_celda)
			var lado := float(_tam_celda)
			datos.add_obstruction_outline(PackedVector2Array([
				esquina, esquina + Vector2(lado, 0), esquina + Vector2(lado, lado), esquina + Vector2(0, lado),
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
	npc.configurar(persona, self, _flujo.velocidad_npc_px_s, color)
	npc.position = _punto_calle(persona.numero_turno)
	add_child(npc)


## El NPC llegó a la salida (Resuelta/Abandonando): libera su asiento y desaparece.
func despachar(npc: Node) -> void:
	_liberar_plaza(npc)
	npc.queue_free()


## El destino según el estado LÓGICO de su persona (el NPC lo pide SOLO al cambiar de estado).
func destino_de(npc: Node) -> Vector2:
	var persona: RefCounted = npc.persona
	match persona.estado:
		&"esperando_dentro":
			return _sitio_en_espera(npc)
		&"esperando_fuera":
			return _punto_calle(persona.numero_turno)
		&"llamada", &"en_atencion":
			_liberar_plaza(npc)
			return _frente_del_puesto(persona)
		_:
			# Resuelta / Abandonando (o cualquier raro): a la calle; despawn al llegar.
			_liberar_plaza(npc)
			return _punto_calle(persona.numero_turno)


## Un punto de la calle (el margen izquierdo, FUERA del edificio): entrada, cola exterior y
## salida. Repartido en vertical por turno para que la cola exterior se vea como grupito.
func _punto_calle(turno: int) -> Vector2:
	var base: Vector2 = _pos_suelo + Vector2(-1.0 * _tam_celda, 6.5 * _tam_celda)
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
		if dotado:
			var agente: RefCounted = _personal.agente_de(puesto_id)
			nombre = agente.nombre if agente != null else ""
		var estado: StringName = _flujo.estado_de_puesto(puesto_id)
		_asegurar_visual_puesto(puesto_id, celda)
		# Si el puesto se MUEVE (modo obra), su visual le sigue (DIFF por celda vista).
		var contenedor: Node2D = _visual_de_puesto[puesto_id]
		if contenedor.get_meta(&"celda", Vector2i(-9999, -9999)) != celda:
			contenedor.set_meta(&"celda", celda)
			contenedor.position = _construccion.centro_de_celda(celda) + Vector2(0, -_tam_celda * 0.55)
		_actualizar_visual_puesto(puesto_id, dotado, nombre, estado)
	# Retira los visuales de puestos que ya no están registrados (demolidos / cargados fuera).
	for puesto_id: StringName in _visual_de_puesto.keys():
		if not vivos.has(puesto_id):
			_visual_de_puesto[puesto_id].queue_free()
			_visual_de_puesto.erase(puesto_id)


## Crea (una vez) el contenedor del puesto con sus tres piezas hijas fijas: muñeco policía (torso +
## cabeza), etiqueta de nombre (font 9, bajo el muñeco) y rótulo de estado (font 9, sobre el
## mostrador). El contenedor se ancla sobre la celda del puesto; las piezas van en local.
func _asegurar_visual_puesto(puesto_id: StringName, celda: Vector2i) -> void:
	if _visual_de_puesto.has(puesto_id):
		return
	var contenedor := Node2D.new()
	contenedor.name = "Puesto_%s" % puesto_id
	contenedor.position = _construccion.centro_de_celda(celda) + Vector2(0, -_tam_celda * 0.55)
	# El muñeco policía (torso + cabeza, estilo npc_ciudadano); se muestra solo si el puesto está dotado.
	var policia := Node2D.new()
	policia.name = "Policia"
	var torso := ColorRect.new()
	torso.color = COLOR_POLICIA_TORSO
	torso.size = Vector2(12, 16)
	torso.position = Vector2(-6, -8)
	torso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	policia.add_child(torso)
	var cabeza := ColorRect.new()
	cabeza.color = COLOR_POLICIA_TORSO.lightened(0.55)
	cabeza.size = Vector2(8, 6)
	cabeza.position = Vector2(-4, -14)
	cabeza.mouse_filter = Control.MOUSE_FILTER_IGNORE
	policia.add_child(cabeza)
	contenedor.add_child(policia)
	# Etiqueta de nombre (bajo el muñeco). Ancho fijo 60 + centrado para no depender del texto.
	var lbl_nombre := _label_centrada(9, Vector2(-30, 10))
	lbl_nombre.name = "Nombre"
	contenedor.add_child(lbl_nombre)
	# Rótulo de estado (sobre el mostrador). Texto SIEMPRE + color de acento (respaldo daltónico).
	var lbl_estado := _label_centrada(9, Vector2(-30, -_tam_celda * 0.5))
	lbl_estado.name = "Estado"
	contenedor.add_child(lbl_estado)
	add_child(contenedor)
	_visual_de_puesto[puesto_id] = contenedor


## Aplica el estado por DIFF: solo toca los nodos si el nombre visto o el estado visto cambiaron
## (metas en el contenedor). El muñeco se muestra/oculta con `dotado`; el rótulo siempre visible.
func _actualizar_visual_puesto(
	puesto_id: StringName, dotado: bool, nombre: String, estado: StringName
) -> void:
	var contenedor: Node2D = _visual_de_puesto[puesto_id]
	var visto_dotado: bool = contenedor.get_meta(&"dotado", false)
	var visto_nombre: String = contenedor.get_meta(&"nombre", "")
	var visto_estado: StringName = contenedor.get_meta(&"estado", &"")
	if visto_dotado == dotado and visto_nombre == nombre and visto_estado == estado:
		return   # nada cambió: cero toques a nodos este frame
	contenedor.set_meta(&"dotado", dotado)
	contenedor.set_meta(&"nombre", nombre)
	contenedor.set_meta(&"estado", estado)
	# Horario provisional 2026-07-25 "los funcionarios se van": con el puesto cerrado (por horario o
	# por el jugador) el muñeco y su nombre desaparecen del mostrador — caminar a casa es juice futuro.
	var policia: Node2D = contenedor.get_node("Policia")
	policia.visible = dotado and estado != &"cerrado"
	var lbl_nombre: Label = contenedor.get_node("Nombre")
	lbl_nombre.visible = dotado and estado != &"cerrado"
	lbl_nombre.text = nombre
	var lbl_estado: Label = contenedor.get_node("Estado")
	lbl_estado.text = ROTULO_ESTADO.get(estado, String(estado).to_upper())
	lbl_estado.modulate = COLOR_ESTADO.get(estado, Color.WHITE)


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
