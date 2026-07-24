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
## Contador de turnos por servicio (FL2): único, creciente, NUNCA se reusa (se serializa en la 007).
var _turnos: Dictionary[StringName, int] = {}
## Colas lógicas por servicio (FL2): personas en espera, en orden de inserción — el ORDEN de
## servicio lo impone la clave F7 al elegir, no la posición en el array (menos invariantes).
var _colas: Dictionary[StringName, Array] = {}


func _ready() -> void:
	_cargar_config()


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
