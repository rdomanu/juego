class_name Flujo extends Node
## Flujo — el motor de personas y colas (sistema Core; NODO del mundo, NO autoload — arq. §3.4).
## Es el BOTTLENECK del que depende casi todo lo visible: entrada → turno → espera → puesto →
## atención → salida.
##
## Story 001 del epic: el núcleo — config data-driven (`ConfigFlujo`), la `PersonaFlujo` (envuelve
## la ficha de Demanda) con su MÁQUINA DE 7 ESTADOS (tabla de transiciones válidas; una inválida
## avisa y no cambia) y los TURNOS por servicio (contador único, creciente, nunca se reusa — FL2).
## Story 002: las COLAS por servicio y la SELECCIÓN F7 — determinista y sin azar: entre las personas
## EN ESPERA compatibles con el puesto (`atenciones_admitidas`), gana la clave mínima
## `(rango_prioridad, numero_turno)`: Documentación FIFO puro (todas rango 1); ODAC sirve las
## Prioritarias del catálogo (VioGén) antes que las Normales. Sin compatible → null (el puesto
## espera, no adelanta a una incompatible).
##
## Story 003: los PUESTOS y el EMPAREJAMIENTO — el puesto de Flujo es ESTADO DERIVADO sobre el
## puesto físico (Construcción) y su dotación (gate FL4 de Personal): Cerrado / Abierto-sin-agente /
## Libre / Atendiendo. `_emparejar()` recorre los puestos LIBRES en orden estable de registro (el
## primero registrado gana — AC-FL23: sin dobles asignaciones por construcción) y cada uno toma de
## su cola la persona F7. Los puestos NACEN abiertos (decisión MVP; los horarios de Documentación #8
## los gobernarán).
##
## Story 004: la ATENCIÓN y el COBRO (FL5, F1) — el tick de Tiempo (suscrito DESPUÉS de Demanda:
## las fichas del tick entran antes de mover el flujo) avanza en orden FIJO: (1) avanzar atenciones
## (restar delta; al llegar a 0 → `tramite_completado(tramite_id, agente)` UNA vez → Resuelta →
## puesto Libre), (2) emparejar (el puesto liberado llama al siguiente EN el mismo tick), (3)
## arrancar llamadas (Llamada → En atención con `duracion_efectiva` F1 = duracion_min del catálogo ×
## modificador_produccion del agente, clamp ≥ 1). El viaje al puesto NO descuenta trámite (es
## cosmético); en la lógica la atención arranca el mismo tick del emparejamiento.
##
## La LÓGICA jamás lee la posición de un sprite (FL5/ADR-0004): el movimiento es cosmético (008).
##
## Story: production/epics/flujo/story-001-persona-estados-turnos.md · TR-flow-001/002 · ADR-0001

## Ruta del config de tuning (generado por tools/build_config_flujo.gd; fallback a defaults).
const RUTA_CONFIG := "res://datos/config/flujo.tres"
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
## La persona del flujo (preload por RUTA — gotcha del headless en frío).
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")

## Claves de servicio (coinciden con la ficha de Demanda y el catálogo).
const SERVICIO_DOC := &"Documentacion"
const SERVICIO_ODAC := &"ODAC"

## Transiciones VÁLIDAS de la máquina de estados (GDD §States A). Lo que no está aquí, se rechaza.
const TRANSICIONES_VALIDAS: Dictionary[StringName, Array] = {
	PersonaFlujoScript.ESTADO_LLEGANDO:
		[PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO, PersonaFlujoScript.ESTADO_ESPERANDO_FUERA],
	PersonaFlujoScript.ESTADO_ESPERANDO_FUERA:
		[PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO, PersonaFlujoScript.ESTADO_ABANDONANDO],
	PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO:
		[PersonaFlujoScript.ESTADO_LLAMADA, PersonaFlujoScript.ESTADO_ABANDONANDO],
	PersonaFlujoScript.ESTADO_LLAMADA: [PersonaFlujoScript.ESTADO_EN_ATENCION],
	PersonaFlujoScript.ESTADO_EN_ATENCION: [PersonaFlujoScript.ESTADO_RESUELTA],
	PersonaFlujoScript.ESTADO_RESUELTA: [],
	PersonaFlujoScript.ESTADO_ABANDONANDO: [],
}

# ── Tuning knobs (copiados del config con clamp; ver aplicar_config) ─────────────────────────
var duracion_desplazamiento_seg: float = 1.5
var habilitar_aging_odac: bool = false
var tope_cola_exterior: int = 0

# ── El estado del flujo ──────────────────────────────────────────────────────────────────────
## Estados del PUESTO (GDD §States B — derivados, nunca almacenados como verdad).
const PUESTO_CERRADO := &"cerrado"
const PUESTO_ABIERTO_SIN_AGENTE := &"abierto_sin_agente"
const PUESTO_LIBRE := &"libre"
const PUESTO_ATENDIENDO := &"atendiendo"

## Contador de turnos por servicio (FL2): único, creciente, NUNCA se reusa (se serializa en la 007).
var _turnos: Dictionary[StringName, int] = {}
## Puestos del flujo: `puesto_id (de Construcción) -> {tipo: StringName, abierto: bool,
## persona: PersonaFlujo|null, restante: float}` (restante lo usa la atención — story 004).
## El ORDEN DE INSERCIÓN es el desempate de AC-FL23 (el primero registrado llama primero).
var _puestos_flujo: Dictionary[StringName, Dictionary] = {}
## Personal inyectado (gate FL4: `puesto_dotado`). En runtime lo enchufa Main (008).
var _personal: Node = null
## Colas lógicas por servicio (FL2): personas en espera, en orden de inserción — el ORDEN de
## servicio lo impone la clave F7 al elegir, no la posición en el array (menos invariantes).
var _colas: Dictionary[StringName, Array] = {}


## EventBus inyectable (auto-resuelto en _ready): emite `tramite_completado` — Economía ya cobra.
var _bus: Node = null
## El reloj (inyectable; auto-resuelto): empuja el tick que mueve TODO el flujo (FL8: en Pausa no
## empuja → nada avanza, por construcción).
var _tiempo: Node = null


func _ready() -> void:
	if _bus == null:
		_bus = get_node_or_null("/root/EventBus")
	if _tiempo == null:
		_tiempo = get_node_or_null("/root/Tiempo")
	_suscribir_al_tick()
	_cargar_config()


## Inyecta el EventBus (dependency injection → testeable sin el autoload real).
func usar_bus(bus: Node) -> void:
	_bus = bus


## Inyecta el reloj y se suscribe a su tick (idempotente). ORDEN ADR-0001: Flujo debe suscribirse
## DESPUÉS de Demanda (Main instancia Flujo tras Demanda — story 008).
func usar_tiempo(tiempo: Node) -> void:
	_tiempo = tiempo
	_suscribir_al_tick()


func _suscribir_al_tick() -> void:
	if _tiempo != null and _tiempo.has_method("suscribir_tick"):
		_tiempo.suscribir_tick(_al_tick)


# ── Admisión y máquina de estados (Story 001 · FL1/FL2) ──────────────────────────────────────

## Admite una ficha de Demanda al flujo (FL1): la envuelve, le asigna turno de SU servicio y nace
## en estado Llegando. (El paso a Esperando dentro/fuera por aforo es de la story 005; la 002
## encola con `encolar`.)
func admitir(ficha: RefCounted) -> RefCounted:
	var servicio: StringName = ficha.servicio
	var turno: int = _turnos.get(servicio, 0) + 1
	_turnos[servicio] = turno
	return PersonaFlujoScript.new(ficha, turno)


## Transición de estado con guardia (States A): una transición inválida AVISA y no cambia nada
## (dato corrupto no rompe la simulación — patrón Agente). Devuelve si se aplicó.
func _transicionar(persona: RefCounted, estado_nuevo: StringName) -> bool:
	var validas: Array = TRANSICIONES_VALIDAS.get(persona.estado, [])
	if not (estado_nuevo in validas):
		push_warning(
			"Flujo: transicion invalida %s -> %s (turno %d) -> ignorada"
			% [persona.estado, estado_nuevo, persona.numero_turno]
		)
		return false
	persona.estado = estado_nuevo
	return true


# ── Colas y selección F7 (Story 002 · FL2/FL3) ───────────────────────────────────────────────

## Encola a una persona recién llegada en la cola lógica de su servicio (FL2). En el MVP de esta
## story entra directamente a Esperando (dentro); la story 005 (aforo) refinará dentro/fuera.
func encolar(persona: RefCounted) -> void:
	_transicionar(persona, PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO)
	if not _colas.has(persona.servicio()):
		_colas[persona.servicio()] = []
	_colas[persona.servicio()].append(persona)


## F7 — la selección del puesto libre: entre las personas EN ESPERA (dentro) de la cola del
## servicio cuyas atenciones el puesto admite, la de clave `(rango_prioridad, numero_turno)`
## MÍNIMA. Sin compatible → null (FL3: el puesto espera; nunca adelanta a una incompatible).
## PURA: no muta la cola (retirar es `retirar_de_cola` — lo usará el emparejamiento, 003).
func elegir_de_cola(servicio: StringName, atenciones_admitidas: Array[StringName]) -> RefCounted:
	var mejor: RefCounted = null
	var mejor_rango: int = 0
	for persona: RefCounted in _colas.get(servicio, []):
		if persona.estado != PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO:
			continue   # las de fuera aún no han "entrado" (FL6 — story 005)
		if not (persona.tramite_id() in atenciones_admitidas):
			continue
		var rango: int = _rango_prioridad(persona)
		if (
			mejor == null or rango < mejor_rango
			or (rango == mejor_rango and persona.numero_turno < mejor.numero_turno)
		):
			mejor = persona
			mejor_rango = rango
	return mejor


## Retira a una persona de su cola (la usará el emparejamiento al tomarla — story 003).
func retirar_de_cola(persona: RefCounted) -> void:
	var cola: Array = _colas.get(persona.servicio(), [])
	cola.erase(persona)


## Personas en la cola lógica de un servicio (getter para F5/UI).
func personas_en_cola(servicio: StringName) -> int:
	return _colas.get(servicio, []).size()


## F7 — rango de prioridad: Documentación no tiene prioridad (todas 1, FIFO puro); en ODAC la
## `DenunciaODAC.prioridad` del catálogo manda ("Prioritaria" = 0 antes que "Normal" = 1).
func _rango_prioridad(persona: RefCounted) -> int:
	if persona.servicio() != SERVICIO_ODAC:
		return 1
	var denuncia: Resource = Datos.obtener(&"DenunciaODAC", persona.tramite_id())
	if denuncia != null and denuncia.prioridad == "Prioritaria":
		return 0
	return 1


# ── Puestos, gate FL4 y emparejamiento (Story 003 · TR-flow-003 · FL3/FL4, States B) ─────────

## Inyecta Personal (dependency injection → testeable). Sin él, ningún puesto está dotado (FL4).
func usar_personal(personal: Node) -> void:
	_personal = personal


## Registra un puesto del mundo en el flujo (id de Construcción + su tipo del catálogo). Nace
## ABIERTO (decisión MVP — los horarios de Documentación #8 lo gobernarán). Idempotente por id.
func registrar_puesto_flujo(puesto_id: StringName, tipo_puesto_id: StringName) -> void:
	if Datos.obtener(&"TipoPuesto", tipo_puesto_id) == null:
		push_warning("Flujo: tipo de puesto '%s' no existe -> no registrado" % tipo_puesto_id)
		return
	if _puestos_flujo.has(puesto_id):
		return
	_puestos_flujo[puesto_id] = {"tipo": tipo_puesto_id, "abierto": true, "persona": null, "restante": 0.0}


## Retira un puesto del flujo (demolición). La atención en curso es contrato de la story 006
## (compromiso de servicio) — hoy retira directo; la 006 lo hará esperar al trámite.
func quitar_puesto_flujo(puesto_id: StringName) -> void:
	_puestos_flujo.erase(puesto_id)


## Abre un puesto (FL10 — API del jugador/horarios).
func abrir_puesto(puesto_id: StringName) -> void:
	if _puestos_flujo.has(puesto_id):
		_puestos_flujo[puesto_id]["abierto"] = true


## Cierra un puesto: deja de llamar a nuevas. El cierre DURANTE una atención (terminarla primero)
## es de la story 006.
func cerrar_puesto(puesto_id: StringName) -> void:
	if _puestos_flujo.has(puesto_id):
		_puestos_flujo[puesto_id]["abierto"] = false


## Estado DERIVADO del puesto (States B): Cerrado → Abierto-sin-agente (gate FL4 de Personal) →
## Atendiendo (tiene persona) → Libre. Puesto no registrado → Cerrado con aviso.
func estado_de_puesto(puesto_id: StringName) -> StringName:
	if not _puestos_flujo.has(puesto_id):
		push_warning("Flujo: estado de un puesto no registrado ('%s') -> cerrado" % puesto_id)
		return PUESTO_CERRADO
	var puesto: Dictionary = _puestos_flujo[puesto_id]
	if not puesto["abierto"]:
		return PUESTO_CERRADO
	if _personal == null or not _personal.puesto_dotado(puesto_id):
		return PUESTO_ABIERTO_SIN_AGENTE
	if puesto["persona"] != null:
		return PUESTO_ATENDIENDO
	return PUESTO_LIBRE


## El emparejamiento automático (FL3, anti-micromanejo): cada puesto LIBRE, en ORDEN ESTABLE de
## registro (el primero gana — AC-FL23), toma de su cola la persona F7. Al tomarla: sale de la
## cola, pasa a Llamada y el puesto la referencia (una persona solo puede estar en UN puesto —
## la doble asignación es imposible por construcción). La transición a En atención y el avance
## con delta son de la story 004.
func _emparejar() -> void:
	for puesto_id: StringName in _puestos_flujo:
		if estado_de_puesto(puesto_id) != PUESTO_LIBRE:
			continue
		var puesto: Dictionary = _puestos_flujo[puesto_id]
		var tipo: Resource = Datos.obtener(&"TipoPuesto", puesto["tipo"])
		var persona: RefCounted = elegir_de_cola(StringName(tipo.servicio), tipo.atenciones_admitidas)
		if persona == null:
			continue
		retirar_de_cola(persona)
		_transicionar(persona, PersonaFlujoScript.ESTADO_LLAMADA)
		puesto["persona"] = persona


# ── El ciclo de atención (Story 004 · TR-flow-003/004 · FL5, F1) ─────────────────────────────

## F1: `duracion_min (catálogo por servicio/id) × modificador_produccion(agente del puesto)`, con
## clamp ≥ 1 min (AC-FL10: un dato corrupto —id inexistente → 0, o modificador roto— jamás produce
## una atención instantánea o negativa). Sin Personal inyectado, modificador 1.0.
func duracion_efectiva(servicio: StringName, tramite_id: StringName, puesto_id: StringName) -> float:
	var tipo_catalogo: StringName = &"TramiteDoc" if servicio == SERVICIO_DOC else &"DenunciaODAC"
	var atencion: Resource = Datos.obtener(tipo_catalogo, tramite_id)
	var base: float = float(atencion.duracion_min) if atencion != null else 0.0
	var modificador: float = 1.0
	if _personal != null:
		modificador = _personal.modificador_produccion_de(puesto_id)
	return maxf(1.0, base * modificador)


## El tick de simulación (recibe `delta_juego` en MINUTOS; en Pausa Tiempo no empuja → FL8).
## ORDEN FIJO del contrato determinista: (1) avanzar/completar atenciones — el puesto liberado
## queda Libre; (2) emparejar — los libres llaman EN el mismo tick; (3) arrancar llamadas — la
## atención empieza el mismo tick del emparejamiento (el viaje es cosmético, no descuenta).
func _al_tick(delta_juego_min: float) -> void:
	_avanzar_atenciones(delta_juego_min)
	_emparejar()
	_arrancar_llamadas()


## Resta delta a cada atención en curso; al cumplirse la duración: emite `tramite_completado`
## (tramite + agente REAL del puesto — Economía cobra, Paciencia cerrará visita) UNA sola vez,
## la Persona pasa a Resuelta (despawn lógico) y el puesto queda Libre.
func _avanzar_atenciones(delta_min: float) -> void:
	for puesto_id: StringName in _puestos_flujo:
		var puesto: Dictionary = _puestos_flujo[puesto_id]
		var persona: RefCounted = puesto["persona"]
		if persona == null or persona.estado != PersonaFlujoScript.ESTADO_EN_ATENCION:
			continue
		puesto["restante"] = float(puesto["restante"]) - delta_min
		if puesto["restante"] > 0.0:
			continue
		var agente: RefCounted = _personal.agente_de(puesto_id) if _personal != null else null
		if _bus != null:
			_bus.tramite_completado.emit(persona.tramite_id(), agente)
		_transicionar(persona, PersonaFlujoScript.ESTADO_RESUELTA)
		puesto["persona"] = null
		puesto["restante"] = 0.0


## Las personas en Llamada empiezan su atención (F1): mismo tick del emparejamiento — FL5: el
## desplazamiento visible no descuenta trámite (cosmético, story 008).
func _arrancar_llamadas() -> void:
	for puesto_id: StringName in _puestos_flujo:
		var puesto: Dictionary = _puestos_flujo[puesto_id]
		var persona: RefCounted = puesto["persona"]
		if persona == null or persona.estado != PersonaFlujoScript.ESTADO_LLAMADA:
			continue
		_transicionar(persona, PersonaFlujoScript.ESTADO_EN_ATENCION)
		puesto["restante"] = duracion_efectiva(persona.servicio(), persona.tramite_id(), puesto_id)


# ── Config (patrón del proyecto: aplicar con clamp defensivo + carga con fallback) ───────────

## Copia los knobs del config con clamp defensivo. Config nulo/de otro tipo → defaults.
func aplicar_config(config: Resource) -> void:
	if config == null or not (config is ConfigFlujoScript):
		push_warning("Flujo: config invalido -> defaults")
		config = ConfigFlujoScript.new()
	duracion_desplazamiento_seg = clampf(config.duracion_desplazamiento_seg, 0.0, 5.0)
	habilitar_aging_odac = config.habilitar_aging_odac
	tope_cola_exterior = maxi(config.tope_cola_exterior, 0)


## Carga el `.tres` real con fallback seguro (falta/inválido → defaults con aviso; no peta).
func _cargar_config() -> void:
	var config: Resource = null
	if ResourceLoader.exists(RUTA_CONFIG):
		config = load(RUTA_CONFIG)
	if config == null:
		push_warning("Flujo: no se pudo cargar '%s' -> defaults" % RUTA_CONFIG)
	aplicar_config(config)
