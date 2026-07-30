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
## Story 005: el AFORO (F6/FL6) y las MATEMÁTICAS de colas (F2-F5) — la sala de espera es finita:
## al encolar se clasifica dentro/fuera comparando la ocupación con el aforo REAL de Construcción
## (los ASIENTOS mandan — `aforo_de_servicio`; Flujo compara, NO recalcula — manifiesto); al
## liberarse una plaza entra de fuera la de MENOR turno. La cola exterior crece SIN tope de Flujo
## (FL7 — la válvula es el abandono, Paciencia #10). F2-F5 son funciones PURAS para la UI y el
## sanity R5 (centinela -1.0 = "sin servicio"/"indefinida", NUNCA ∞ ni división por cero).
##
## Story 006: COMPROMISO DE SERVICIO y gestión en caliente — nada se interrumpe a medias (regla
## dura del manifiesto): cerrar (`cierre_pendiente`), retirar (`retirada_pendiente`) y demoler
## (AC-CO13, pendientes en Construcción que Flujo reintenta al terminar cada atención) ESPERAN al
## fin de la atención en curso; `forzar_abandono` (la API que Paciencia #10 llamará) devuelve
## false en Llamada/En atención. `reconfigurar_puesto` (FL9, solo tipos `reconfigurable`) cambia
## el filtro para la PRÓXIMA llamada. **Horario de Doc (AC-FL24): Flujo lo EJECUTA, Documentación #8
## lo POSEE** (mudanza de la story doc-002 — antes vivía prestado aquí como knob del `.tres`). Su
## dueño lo empuja con `fijar_horario_doc(apertura, cierre, ultima_admision)`; Flujo lo aplica:
## fuera de `[apertura, ultima_admision)` la puerta no admite NUEVAS personas Doc, la cola ya
## admitida se atiende hasta vaciarse y, al vaciarse, los puestos Doc cierran solos ("los
## funcionarios se van", `_gestionar_horario_doc`) y REABREN solos en la apertura; el cierre MANUAL
## del jugador (`cerrar_puesto`) NO se reabre solo — el jugador manda. La Pausa congela por
## construcción (Tiempo no empuja el tick — FL8).
##
## Story 007: PERSISTENCIA (ADR-0002) — `save()`/`load_state()` + grupo Persist (clave "Flujo"):
## personas por campos + turno + estado (las colas y el dentro/fuera se RE-DERIVAN del estado),
## puestos por id (el mundo los registra ANTES de cargar — patrón Personal) y contadores de
## turno. Carga defensiva (corrupto → descartado con aviso), 0 señales, sin eventos retroactivos.
##
## La LÓGICA jamás lee la posición de un sprite (FL5/ADR-0004): el movimiento es cosmético (008).
##
## Story: production/epics/flujo/story-001-persona-estados-turnos.md · TR-flow-001/002 · ADR-0001

## Ruta del config de tuning (generado por tools/build_config_flujo.gd; fallback a defaults).
const RUTA_CONFIG := "res://datos/config/flujo.tres"
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
## La persona del flujo (preload por RUTA — gotcha del headless en frío).
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
## La ficha de Demanda (para RECONSTRUIRLA al cargar — story 007; PersonaFlujo ya la envuelve).
const PersonaScript := preload("res://src/core/demanda/persona.gd")

## Claves de servicio (coinciden con la ficha de Demanda y el catálogo).
const SERVICIO_DOC := &"Documentacion"
const SERVICIO_ODAC := &"ODAC"

## Punto FIJO de entrada del edificio en celdas (CO11 — borde izquierdo a media altura, el lado por
## el que entra la gente). Lo usa el cálculo del camino cuando la persona AÚN no llegó a su sala
## (3ª calibración). Provisional aquí; migrará a Escenario/Construcción con la multi-comisaría.
const CELDA_ENTRADA := Vector2i(0, 6)

## Transiciones VÁLIDAS de la máquina de estados (GDD §States A). Lo que no está aquí, se rechaza.
const TRANSICIONES_VALIDAS: Dictionary[StringName, Array] = {
	PersonaFlujoScript.ESTADO_LLEGANDO:
		[PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO, PersonaFlujoScript.ESTADO_ESPERANDO_FUERA],
	PersonaFlujoScript.ESTADO_ESPERANDO_FUERA:
		[PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO, PersonaFlujoScript.ESTADO_ABANDONANDO],
	PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO:
		[PersonaFlujoScript.ESTADO_LLAMADA, PersonaFlujoScript.ESTADO_ABANDONANDO],
	# LLAMADA → ESPERANDO_DENTRO existe por la LLAMADA ANTICIPADA (2026-07-29): al siguiente ya
	# llamado se le puede devolver a la cola si su ventanilla cierra, se queda sin agente (café) o se
	# demuele ANTES de que llegue. Es una reserva blanda: todavía no le han empezado a atender, así
	# que devolverlo a la cola no rompe el compromiso de servicio (el que SÍ está siendo atendido
	# nunca recorre esta ruta — sale por EN_ATENCION → RESUELTA como siempre).
	PersonaFlujoScript.ESTADO_LLAMADA: [
		PersonaFlujoScript.ESTADO_EN_ATENCION, PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO,
	],
	PersonaFlujoScript.ESTADO_EN_ATENCION: [PersonaFlujoScript.ESTADO_RESUELTA],
	PersonaFlujoScript.ESTADO_RESUELTA: [],
	PersonaFlujoScript.ESTADO_ABANDONANDO: [],
}

# ── Tuning knobs (copiados del config con clamp; ver aplicar_config) ─────────────────────────
## Velocidad del camino Llamada→puesto en CELDAS de juego por MINUTO de juego (enmienda 2026-07-25
## "en camino no se tramita"). 0 = camino instantáneo (compat). Ver `_minutos_de_camino`.
var velocidad_camino_celdas_min: float = 0.375
## LLAMADA ANTICIPADA (2026-07-29): margen EXTRA, en minutos, con el que se llama al siguiente antes
## de que el actual termine. Se llama cuando `restante <= camino_estimado + este margen`, asi que 0
## ya significa "justo a tiempo": sale de la cola con el tiempo exacto para llegar al terminar.
## Existe porque medimos que el agente pasaba 17 min PARADO por cada cliente (mas que los 13 que
## tardaba en atenderle): llamaba solo cuando ya estaba libre y se quedaba mirando como venia.
## Negativo lo desactiva de hecho (nunca se adelanta) — util para aislar la variable en tests.
var margen_llamada_anticipada_min: float = 0.0
var habilitar_aging_odac: bool = false
var tope_cola_exterior: int = 0
## ── El horario de Documentación (lo POSEE Documentación #8; Flujo solo lo EJECUTA) ──────────
## Desde la story doc-002 estos tres valores **no salen del `.tres` de Flujo**: los empuja su dueño
## por `fijar_horario_doc()`. Los defaults son los del horario base (08:00–14:30, sin margen) para
## que Flujo **sin Documentación cableada** se comporte igual que antes de la mudanza — así los
## tests de flujo siguen siendo la red de seguridad de la migración.
## Minuto del día en que cierra Documentación: los puestos Doc se cierran solos al vaciar su cola.
var cierre_doc_min: int = 870
## Minuto del día en que abre Documentación: los puestos Doc cerrados POR HORARIO reabren solos.
var apertura_doc_min: int = 480
## Minuto del día hasta el que se DA NÚMERO (F3 de Documentación: `cierre − margen`). Con margen 0
## coincide con el cierre (comportamiento previo a la mudanza). Lo ya admitido se atiende siempre.
var ultima_admision_doc_min: int = 870
## La hora a la que acaba la jornada BASE de Doc (sin peonada). A partir de aquí, atender cansa más
## (Bienestar #13). Lo empuja Documentación; por defecto, el cierre base del catálogo.
var cierre_base_doc_min: int = 870
var velocidad_npc_px_s: float = 90.0
var k_equipamiento: float = 0.02
var mult_equipamiento_min: float = 0.8

# ── El estado del flujo ──────────────────────────────────────────────────────────────────────
## Estados del PUESTO (GDD §States B — derivados, nunca almacenados como verdad).
const PUESTO_CERRADO := &"cerrado"
const PUESTO_ABIERTO_SIN_AGENTE := &"abierto_sin_agente"
const PUESTO_LIBRE := &"libre"
const PUESTO_EN_CAMINO := &"en_camino"   # enmienda 2026-07-25: llamada emitida, la persona aún camina
const PUESTO_ATENDIENDO := &"atendiendo"

## Contador de turnos por servicio (FL2): único, creciente, NUNCA se reusa (se serializa en la 007).
var _turnos: Dictionary[StringName, int] = {}
## Puestos del flujo: `puesto_id (de Construcción) -> {tipo: StringName, abierto: bool,
## persona: PersonaFlujo|null, restante: float, camino_restante: float}` (restante lo usa la
## atención — story 004; camino_restante los minutos que la persona aún camina — enmienda 2026-07-25).
## El ORDEN DE INSERCIÓN es el desempate de AC-FL23 (el primero registrado llama primero).
var _puestos_flujo: Dictionary[StringName, Dictionary] = {}
## Personal inyectado (gate FL4: `puesto_dotado`). En runtime lo enchufa Main (008).
var _personal: Node = null
## Construcción inyectada (story 005: el aforo por asientos es SUYO). Sin ella → sin límite (tests).
var _construccion: Node = null
## ⚠️ El hook de peonada (`fijar_hook_horas_extra`) se RETIRÓ en la story doc-003: cobraba euros por
## los minutos trabajados tras el cierre, y el GDD dice lo contrario (DO4/DO5) — la peonada se paga
## por **ampliar el horario** (la calcula Documentación #8) y terminar a los rezagados cuesta **moral,
## no dinero**. No volver a añadirlo aquí: el horario y su coste son de Documentación.
## Puestos a retirar tras completar su atención (retirada_pendiente) — pre-alocado (regla hot path).
var _puestos_a_retirar: Array[StringName] = []
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
	add_to_group("Persist")   # ADR-0002 (story 007): el SaveManager recolecta por este grupo


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
## en estado Llegando. (`encolar` la clasifica después dentro/fuera por aforo — F6.)
## AC-FL24: con la puerta de Documentación CERRADA (pasada `cierre_doc_min`) una ficha Doc "en
## camino" ya NO se admite → devuelve null (el caller lo descarta). ODAC es 24 h.
func admitir(ficha: RefCounted) -> RefCounted:
	var servicio: StringName = ficha.servicio
	if servicio == SERVICIO_DOC and not puerta_doc_abierta():
		return null
	var turno: int = _turnos.get(servicio, 0) + 1
	_turnos[servicio] = turno
	return PersonaFlujoScript.new(ficha, turno)


## AC-FL24: la puerta de Doc a NUEVAS admisiones, DERIVADA del reloj. Se da número dentro de
## `[apertura_doc_min, ultima_admision_doc_min)` — el horario lo fija Documentación #8 (story
## doc-002), Flujo solo lo ejecuta. Fuera de esa franja `admitir` devuelve null: Demanda ya corta el
## grifo en su ventana, y esto cubre a las que ya venían "en camino". Lo YA admitido se atiende
## siempre (compromiso de servicio). Sin reloj inyectado (tests unitarios) → siempre abierta.
func puerta_doc_abierta() -> bool:
	if _tiempo == null:
		return true
	var min_dia: float = fposmod(_tiempo.minutos_juego, 1440.0)
	return min_dia >= float(apertura_doc_min) and min_dia < float(ultima_admision_doc_min)


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

## Encola a una persona recién llegada en la cola lógica de su servicio (FL2) clasificándola por
## aforo (F6/FL6): con plaza en la sala de espera → Esperando (dentro); sin plaza → Esperando
## (fuera). La cola exterior crece SIN tope de Flujo (FL7 — la válvula es el abandono, Paciencia).
func encolar(persona: RefCounted) -> void:
	var servicio: StringName = persona.servicio()
	if hay_plaza_dentro(ocupacion_dentro(servicio), _aforo_de(servicio)):
		_transicionar(persona, PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO)
	else:
		_transicionar(persona, PersonaFlujoScript.ESTADO_ESPERANDO_FUERA)
	if not _colas.has(servicio):
		_colas[servicio] = []
	_colas[servicio].append(persona)


## F7 — la selección del puesto libre: entre las personas EN ESPERA (dentro) de la cola del
## servicio cuyas atenciones el puesto admite, la de clave `(rango_prioridad, numero_turno)`
## MÍNIMA. Sin compatible → null (FL3: el puesto espera; nunca adelanta a una incompatible).
## PURA: no muta la cola (retirar es `retirar_de_cola` — lo usará el emparejamiento, 003).
func elegir_de_cola(servicio: StringName, atenciones_admitidas: Array[StringName]) -> RefCounted:
	var mejor: RefCounted = null
	var mejor_rango: int = 0
	for persona: RefCounted in _colas.get(servicio, []):
		if persona.estado != PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO:
			continue   # las de fuera aún no han "entrado" (FL6)
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


## Retira a una persona de su cola (el emparejamiento al tomarla — 003; el abandono — 006). Si con
## ello se libera plaza dentro, promociona de la cola exterior (F6 — el hueco no se desperdicia).
func retirar_de_cola(persona: RefCounted) -> void:
	var cola: Array = _colas.get(persona.servicio(), [])
	cola.erase(persona)
	_promover_de_fuera(persona.servicio())


## Personas en la cola lógica de un servicio (getter para F5/UI).
func personas_en_cola(servicio: StringName) -> int:
	return _colas.get(servicio, []).size()


## Las personas de la cola de un servicio, en el orden estable de la cola (getter de SOLO LECTURA
## para Paciencia #10, que necesita recorrer a quien espera para drenar su barra). Devuelve una
## COPIA: nadie muta la cola desde fuera — para eso está la API (`retirar_de_cola`, `forzar_abandono`).
func personas_de_cola(servicio: StringName) -> Array:
	return (_colas.get(servicio, []) as Array).duplicate()


## COLAR a alguien: lo pone el PRIMERO de su cola, para que sea el siguiente al que llamen (mecánica
## pedida por el usuario 2026-07-26: *"con el botón derecho estaría bien colar a alguien que lleva
## mucho tiempo esperando, pero eso afectaría a la paciencia del resto"*).
##
## Aquí solo se mueve el sitio en la cola —el precio social (el cabreo de los demás) lo cobra
## Paciencia #10, que es quien posee esa escala—. Solo se puede colar a quien ESPERA: a quien ya han
## llamado no hay que colarlo, y a quien está fuera por aforo no se le puede dar un sitio que no hay.
## Devuelve false si no procede.
func colar(persona: RefCounted) -> bool:
	if persona == null or persona.colado:
		return false   # ya estaba colada: no se cuela dos veces (ni se cobra dos veces el cabreo)
	# Vale tanto para quien espera DENTRO como para quien se quedó FUERA por aforo: colar a alguien
	# de la calle es justamente el favor más útil (y el más caro en cabreo ajeno). Al que está fuera
	# se le mete dentro en cuanto haya plaza, con prioridad sobre el orden de turno.
	if (
		persona.estado != PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO
		and persona.estado != PersonaFlujoScript.ESTADO_ESPERANDO_FUERA
	):
		return false
	persona.colado = true
	_promover_de_fuera(persona.servicio())   # si hay hueco, el colado entra ya
	return true


## Trámites que hay esperando y que **ningún puesto construido puede atender**: `tramite_id -> cuántos`
## (acción #2 de la retrospectiva del Sprint 2).
##
## Nació de un fallo real de partida —el "misterio de las 22:00"—: había gente pidiendo el TIE y
## ninguna ventanilla que lo tramitara, así que esperaban **para siempre** sin que nada lo dijera. Es
## un estado perfectamente legal del juego (has construido mal), pero **tiene que verse**: un juego no
## debe dejarte perder por algo que no puedes ni saber que está pasando.
##
## Se mira lo que cada puesto ADMITE de verdad: su override de reconfiguración (FL9) si lo tiene, o
## sus atenciones del catálogo. Los puestos cerrados o sin agente **sí cuentan** como capaces: son un
## problema distinto (y el rótulo del puesto ya lo grita) — aquí se avisa solo de lo que NADIE puede
## atender, se ponga como se ponga.
func tramites_sin_servicio() -> Dictionary:
	var atendibles: Dictionary = {}
	for puesto_id: StringName in _puestos_flujo:
		var puesto: Dictionary = _puestos_flujo[puesto_id]
		var tipo: Resource = Datos.obtener(&"TipoPuesto", puesto["tipo"])
		if tipo == null:
			continue
		var admitidas: Array[StringName] = puesto["override"]
		if admitidas.is_empty():
			admitidas = tipo.atenciones_admitidas
		for atencion: StringName in admitidas:
			atendibles[atencion] = true
	var huerfanos: Dictionary = {}
	for servicio: StringName in _colas:
		for persona: RefCounted in _colas[servicio]:
			var tramite: StringName = persona.tramite_id()
			if atendibles.has(tramite):
				continue
			huerfanos[tramite] = int(huerfanos.get(tramite, 0)) + 1
	return huerfanos


## Las personas que están AHORA en un puesto (llamadas o en atención). Ya NO están en ninguna cola
## —el emparejamiento las retira—, así que sin este getter serían invisibles para Paciencia #10, que
## necesita seguir reconociéndolas al recargar una partida. Solo lectura, en orden de puesto.
func personas_en_puestos() -> Array:
	var resultado: Array = []
	for puesto_id: StringName in _puestos_flujo:
		var persona: RefCounted = _puestos_flujo[puesto_id]["persona"]
		if persona != null:
			resultado.append(persona)
	return resultado


## Atenciones EN CURSO ahora mismo (getter para el HUD — pull, story 008). Cuenta SOLO personas en
## `en_atencion`: el rótulo del HUD dice "Atendiendo" y una persona aún de camino (`llamada`) no lo
## está (enmienda 2026-07-25 "en camino no se tramita").
func atendiendo_total() -> int:
	var total: int = 0
	for puesto_id: StringName in _puestos_flujo:
		var persona: RefCounted = _puestos_flujo[puesto_id]["persona"]
		if persona != null and persona.estado == PersonaFlujoScript.ESTADO_EN_ATENCION:
			total += 1
	return total


## El puesto que tiene a esta persona (en Llamada o En atención); `&""` si ninguno. Lo usa el NPC
## visible (story 008) para saber A QUÉ ventanilla caminar — lectura cosmética, jamás decide (FL5).
func puesto_de(persona: RefCounted) -> StringName:
	for puesto_id: StringName in _puestos_flujo:
		# Tambien el reservado por la LLAMADA ANTICIPADA: ya va andando hacia ESA ventanilla, asi que
		# el NPC visible tiene que poder preguntar hacia donde camina (lectura cosmetica, FL5).
		if _puestos_flujo[puesto_id]["persona"] == persona 				or _puestos_flujo[puesto_id]["siguiente"] == persona:
			return puesto_id
	return &""


## F7 — rango de prioridad: Documentación no tiene prioridad (todas 1, FIFO puro); en ODAC la
## `DenunciaODAC.prioridad` del catálogo manda ("Prioritaria" = 0 antes que "Normal" = 1).
func _rango_prioridad(persona: RefCounted) -> int:
	# A quien el jugador ha COLADO se le llama antes que a nadie, sea el servicio que sea: es una
	# orden explícita suya y debe verse cumplida al instante (mecánica del 2026-07-26).
	if persona.colado:
		return -1
	if persona.servicio() != SERVICIO_ODAC:
		return 1
	var denuncia: Resource = Datos.obtener(&"DenunciaODAC", persona.tramite_id())
	if denuncia != null and denuncia.prioridad == "Prioritaria":
		return 0
	return 1


# ── Aforo F6 y cola exterior (Story 005 · TR-flow-002 · FL6/FL7) ─────────────────────────────

## Inyecta Construcción (el aforo por ASIENTOS es suyo — manifiesto: Flujo compara, no recalcula).
func usar_construccion(construccion: Node) -> void:
	_construccion = construccion


## F6 — ¿queda plaza en la sala de espera? PURA (AC-FL12: 39/40 sí, 40/40 no). Un aforo negativo
## significa "sin límite" (modo sin Construcción inyectada — tests unitarios de colas).
func hay_plaza_dentro(ocupacion: int, aforo: int) -> bool:
	return aforo < 0 or ocupacion < aforo


## Ocupación real de la sala de espera: personas ESPERANDO (dentro) en la cola del servicio (las
## que ya están en un puesto no ocupan asiento).
func ocupacion_dentro(servicio: StringName) -> int:
	var total: int = 0
	for persona: RefCounted in _colas.get(servicio, []):
		if persona.estado == PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO:
			total += 1
	return total


## El aforo del servicio según Construcción (`aforo_de_servicio` — F3 por asientos, suma de todas
## sus salas de espera). Sin Construcción inyectada → -1 ("sin límite": todos dentro — el
## comportamiento de las stories 001-004 y sus tests).
## Sin NINGUNA sala de espera del servicio → aforo 0: nadie entra ni es llamado (la UI/R5 lo
## harán visible). Con sala pero sin asientos se entra DE PIE (enmienda F3 — `densidad_de_pie`).
func _aforo_de(servicio: StringName) -> int:
	if _construccion == null:
		return -1
	return _construccion.aforo_de_servicio(servicio)


## FL6 — al liberarse plaza dentro entra desde fuera la de MENOR turno. En bucle por si se liberan
## varias plazas de golpe (p. ej. tras ampliar la sala de espera). Determinista: solo turnos.
func _promover_de_fuera(servicio: StringName) -> void:
	while hay_plaza_dentro(ocupacion_dentro(servicio), _aforo_de(servicio)):
		var candidata: RefCounted = null
		for persona: RefCounted in _colas.get(servicio, []):
			if persona.estado != PersonaFlujoScript.ESTADO_ESPERANDO_FUERA:
				continue
			# A quien el jugador ha COLADO se le hace sitio antes que a nadie; entre iguales, el
			# menor turno (FL6 intacto: sigue siendo determinista, solo cambia la clave de orden).
			if (
				candidata == null
				or (persona.colado and not candidata.colado)
				or (persona.colado == candidata.colado and persona.numero_turno < candidata.numero_turno)
			):
				candidata = persona
		if candidata == null:
			return
		_transicionar(candidata, PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO)


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
	var sin_override: Array[StringName] = []
	_puestos_flujo[puesto_id] = {
		"tipo": tipo_puesto_id,
		"abierto": true,
		"persona": null,
		"restante": 0.0,
		"camino_restante": 0.0,        # enmienda 2026-07-25: minutos que la persona aún camina al puesto
		# LLAMADA ANTICIPADA (2026-07-29): el SIGUIENTE ciudadano, llamado mientras aun se atiende al
		# actual, para que vaya andando y no haya tiempo muerto. Es una RESERVA BLANDA: si la
		# ventanilla cierra, se queda sin agente o se demuele antes de que llegue, vuelve a la cola.
		"siguiente": null,
		"siguiente_camino": 0.0,
		"cierre_pendiente": false,     # story 006: cerrar espera al fin de la atención
		"retirada_pendiente": false,   # story 006: retirar (demoler) espera al fin de la atención
		"override": sin_override,      # story 006: reconfiguración FL9 (vacío = catálogo)
		"cierre_horario": false,       # cerrado por HORARIO (se reabre solo en apertura_doc_min); el
		                               # cierre MANUAL del jugador NO
		"cierre_propio": 0,            # story doc-006: hora de cierre propia (0 = la del servicio)
	}


## Minutos de camino que le quedan a la persona de un puesto (getter read-only para que el NPC
## visible ADAPTE su paso y llegue a la mesa justo al agotarse — enmienda 2026-07-25, 2ª calibración).
## LLAMADA ANTICIPADA: la persona reservada como SIGUIENTE de este puesto (null si no hay). Getter
## de solo lectura, para los tests y para que la capa visual sepa quien viene de camino.
## ¿Este puesto tiene un CIERRE PENDIENTE? (story 006: cerrar con alguien delante no interrumpe la
## atencion — la persiana baja al terminar). Lo consulta el panel de horario para poder decirle al
## jugador "cerrara al acabar" en vez de dejarle pensando que su clic no ha hecho nada.
func cierre_pendiente_de(puesto_id: StringName) -> bool:
	if not _puestos_flujo.has(puesto_id):
		return false
	return bool(_puestos_flujo[puesto_id]["cierre_pendiente"])


func siguiente_de(puesto_id: StringName) -> RefCounted:
	if not _puestos_flujo.has(puesto_id):
		return null
	return _puestos_flujo[puesto_id]["siguiente"]


## Minutos de camino que le quedan a esa reserva (0.0 si no hay ninguna). Gemelo de
## `camino_restante_de`, pero para el siguiente en vez de para la persona ya asignada.
func siguiente_camino_restante_de(puesto_id: StringName) -> float:
	if not _puestos_flujo.has(puesto_id):
		return 0.0
	return float(_puestos_flujo[puesto_id]["siguiente_camino"])


func camino_restante_de(puesto_id: StringName) -> float:
	if not _puestos_flujo.has(puesto_id):
		return 0.0
	return float(_puestos_flujo[puesto_id]["camino_restante"])


## Ids de los puestos registrados en el flujo (getter para sincronizar con Construcción — 008).
func puestos_registrados() -> Array[StringName]:
	var resultado: Array[StringName] = []
	for puesto_id: StringName in _puestos_flujo:
		resultado.append(puesto_id)
	return resultado


## Retira un puesto del flujo (demolición). COMPROMISO (story 006): con atención en curso queda
## `retirada_pendiente` — termina el trámite y ENTONCES desaparece. Devuelve si se retiró YA.
func quitar_puesto_flujo(puesto_id: StringName) -> bool:
	if not _puestos_flujo.has(puesto_id):
		return true
	# LLAMADA ANTICIPADA: si demuelen la ventanilla, el reservado vuelve a la cola. Si no, se quedaria
	# caminando hacia un mostrador que ya no existe (y su entrada del diccionario se borra abajo).
	_liberar_siguiente(puesto_id)
	if _puestos_flujo[puesto_id]["persona"] != null:
		_puestos_flujo[puesto_id]["retirada_pendiente"] = true
		return false
	_puestos_flujo.erase(puesto_id)
	return true


## Abre un puesto (FL10 — API del jugador/horarios). Reabrir CANCELA un cierre pendiente y, por si
## venía de un cierre por horario (provisional 2026-07-25), limpia también esa marca.
func abrir_puesto(puesto_id: StringName) -> void:
	if _puestos_flujo.has(puesto_id):
		_puestos_flujo[puesto_id]["abierto"] = true
		_puestos_flujo[puesto_id]["cierre_pendiente"] = false
		_puestos_flujo[puesto_id]["cierre_horario"] = false


## Cierra un puesto: deja de llamar a nuevas. AC-FL17 (story 006): con una atención EN CURSO no se
## interrumpe — queda `cierre_pendiente` y pasa a Cerrado al emitir su `tramite_completado`.
func cerrar_puesto(puesto_id: StringName) -> void:
	if not _puestos_flujo.has(puesto_id):
		return
	# LLAMADA ANTICIPADA: al reservado se le devuelve a la cola YA, tanto si el cierre es inmediato
	# como si queda pendiente del fin de la atencion. No tiene compromiso de servicio (aun no le han
	# atendido) y dejarle caminando hacia una ventanilla que va a cerrar seria mandarle a nada.
	_liberar_siguiente(puesto_id)
	if _puestos_flujo[puesto_id]["persona"] != null:
		_puestos_flujo[puesto_id]["cierre_pendiente"] = true
		return
	_puestos_flujo[puesto_id]["abierto"] = false


## FL9 (AC-FL16) — reconfigura las atenciones que el puesto admite: override LOCAL sobre las
## `atenciones_admitidas` del catálogo (la operativa completa la poseerá ODAC #9). SOLO tipos
## `reconfigurable`; la atención EN CURSO no se interrumpe (el filtro aplica a la PRÓXIMA
## llamada). Ids fuera del catálogo del tipo se descartan con aviso; si no queda ninguno válido
## no se aplica. Lista vacía = LIMPIAR el override (vuelve al catálogo). Devuelve si se aplicó.
func reconfigurar_puesto(puesto_id: StringName, atenciones: Array[StringName]) -> bool:
	if not _puestos_flujo.has(puesto_id):
		push_warning("Flujo: reconfigurar un puesto no registrado ('%s') -> ignorado" % puesto_id)
		return false
	var puesto: Dictionary = _puestos_flujo[puesto_id]
	var tipo: Resource = Datos.obtener(&"TipoPuesto", puesto["tipo"])
	if tipo == null or not tipo.reconfigurable:
		push_warning("Flujo: el puesto '%s' (tipo '%s') no es reconfigurable -> ignorado" % [puesto_id, puesto["tipo"]])
		return false
	var filtradas: Array[StringName] = []
	if atenciones.is_empty():
		puesto["override"] = filtradas
		return true
	for atencion: StringName in atenciones:
		if atencion in tipo.atenciones_admitidas:
			filtradas.append(atencion)
		else:
			push_warning("Flujo: atencion '%s' no admitida por '%s' -> descartada" % [atencion, puesto["tipo"]])
	if filtradas.is_empty():
		push_warning("Flujo: reconfiguracion de '%s' sin ninguna atencion valida -> ignorada" % puesto_id)
		return false
	puesto["override"] = filtradas
	return true


## AC-CO13 — el gate que Main cablea en Construcción (`fijar_puede_demoler`): un puesto solo se
## demuele YA si NO está atendiendo (compromiso de servicio). No registrado en el flujo → sí.
func puede_demoler_puesto(puesto_id: StringName) -> bool:
	if not _puestos_flujo.has(puesto_id):
		return true
	return _puestos_flujo[puesto_id]["persona"] == null


## AC-FL18 — la API que Paciencia #10 llamará (interfaz PROVISIONAL: en este epic solo la usan
## los tests): en Esperando (dentro/fuera) → sale de la cola (si libera plaza entra el de fuera),
## pasa a Abandonando y emite `abandono(persona)` en el bus. En Llamada/En atención → COMPROMISO
## DE SERVICIO (regla dura del manifiesto): false y nada cambia. Otros estados → false.
func forzar_abandono(persona: RefCounted) -> bool:
	if (
		persona.estado != PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO
		and persona.estado != PersonaFlujoScript.ESTADO_ESPERANDO_FUERA
	):
		return false
	retirar_de_cola(persona)
	_transicionar(persona, PersonaFlujoScript.ESTADO_ABANDONANDO)
	if _bus != null:
		_bus.abandono.emit(persona)
	return true


## **El horario de Documentación, empujado por su dueño** (Documentación #8 · story doc-002).
## Flujo lo EJECUTA: abre y cierra los puestos de Doc a esa hora y deja de dar número en
## `ultima_admision_min`. Todo en minutos del día [0, 1439]. Se sanea defensivamente (un horario
## imposible no puede dejar la comisaría sin atender): el cierre nunca antes de la apertura, y la
## última admisión dentro de `[apertura, cierre]`. Sin esta llamada valen los defaults del horario
## base — así los tests previos a la mudanza siguen midiendo lo mismo.
func fijar_horario_doc(apertura_min: int, cierre_min: int, ultima_admision_min: int) -> void:
	apertura_doc_min = clampi(apertura_min, 0, 1439)
	cierre_doc_min = clampi(cierre_min, apertura_doc_min + 1, 1439)
	ultima_admision_doc_min = clampi(ultima_admision_min, apertura_doc_min, cierre_doc_min)


## ¿La hora actual está en las horas extra de Documentación? (Bienestar #13: atender en peonada cansa
## más). Sin reloj o sin cierre base empujado, no hay peonada que valga.
func _en_horas_extra_doc() -> bool:
	if _tiempo == null:
		return false
	return fposmod(_tiempo.minutos_juego, 1440.0) >= float(cierre_base_doc_min)


## Le dice a Flujo cuál es la jornada BASE de Documentación (lo empuja su dueño): a partir de esa
## hora, atender es peonada y cansa más. Story bien-003.
func fijar_cierre_base_doc(minuto_del_dia: int) -> void:
	cierre_base_doc_min = clampi(minuto_del_dia, 0, 1439)


## **El horario propio de UNA ventanilla** (story doc-006): su hora de cierre puede ser distinta de la
## del servicio — "esta se queda hasta las 18:00 y esta otra cierra a las 14:30". `0` = sigue el
## horario global (lo normal). Lo empuja Documentación #8; Flujo solo lo ejecuta.
func fijar_cierre_de_puesto(puesto_id: StringName, cierre_min: int) -> void:
	if not _puestos_flujo.has(puesto_id):
		return
	_puestos_flujo[puesto_id]["cierre_propio"] = clampi(cierre_min, 0, 1439)


## La hora a la que cierra ESE puesto: la suya propia si la tiene, o la del servicio.
func cierre_de_puesto(puesto_id: StringName) -> int:
	if not _puestos_flujo.has(puesto_id):
		return cierre_doc_min
	var propio: int = int(_puestos_flujo[puesto_id].get("cierre_propio", 0))
	return propio if propio > 0 else cierre_doc_min


## Estado DERIVADO del puesto (States B): Cerrado → Abierto-sin-agente (gate FL4 de Personal) →
## En camino (persona llamada, aún caminando) / Atendiendo (persona en atención) → Libre. Puesto no
## registrado → Cerrado con aviso. States B gana el valor "En camino" con la enmienda 2026-07-25
## "en camino no se tramita" (el GDD se propaga en C2-7): una persona en `llamada` está de camino;
## solo `en_atencion` es "Atendiendo" de verdad.
func estado_de_puesto(puesto_id: StringName) -> StringName:
	if not _puestos_flujo.has(puesto_id):
		push_warning("Flujo: estado de un puesto no registrado ('%s') -> cerrado" % puesto_id)
		return PUESTO_CERRADO
	var puesto: Dictionary = _puestos_flujo[puesto_id]
	if not puesto["abierto"]:
		return PUESTO_CERRADO
	if _personal == null or not _personal.puesto_dotado(puesto_id):
		return PUESTO_ABIERTO_SIN_AGENTE
	var persona: RefCounted = puesto["persona"]
	if persona != null:
		if persona.estado == PersonaFlujoScript.ESTADO_LLAMADA:
			return PUESTO_EN_CAMINO
		return PUESTO_ATENDIENDO
	return PUESTO_LIBRE


## El emparejamiento automático (FL3, anti-micromanejo): cada puesto LIBRE, en ORDEN ESTABLE de
## registro (el primero gana — AC-FL23), toma de su cola la persona F7. Al tomarla: sale de la
## cola, pasa a Llamada, el puesto la referencia (una persona solo puede estar en UN puesto — la
## doble asignación es imposible por construcción) y se cronometra su CAMINO al puesto (enmienda
## 2026-07-25: mientras camina la atención aún no arranca). La transición a En atención y el avance
## con delta son de la story 004 / `_avanzar_caminos`.
func _emparejar() -> void:
	for puesto_id: StringName in _puestos_flujo:
		if estado_de_puesto(puesto_id) != PUESTO_LIBRE:
			continue
		var puesto: Dictionary = _puestos_flujo[puesto_id]
		var tipo: Resource = Datos.obtener(&"TipoPuesto", puesto["tipo"])
		var admitidas: Array[StringName] = puesto["override"]   # FL9: override local (006)…
		if admitidas.is_empty():
			admitidas = tipo.atenciones_admitidas               # …vacío = catálogo
		var persona: RefCounted = elegir_de_cola(StringName(tipo.servicio), admitidas)
		if persona == null:
			continue
		var camino: float = _minutos_de_camino(StringName(tipo.servicio), puesto_id, persona)
		if camino < 0.0:
			continue   # ventanilla incomunicada: no se llama a nadie que no pueda llegar
		retirar_de_cola(persona)
		_transicionar(persona, PersonaFlujoScript.ESTADO_LLAMADA)
		puesto["persona"] = persona
		puesto["camino_restante"] = camino
	_llamar_a_los_siguientes()


## LLAMADA ANTICIPADA: a los puestos que ESTAN ATENDIENDO y les queda poco se les adelanta el
## siguiente ciudadano, para que camine MIENTRAS. Asi, al terminar el tramite, el siguiente ya esta
## llegando en vez de empezar entonces a andar. Es lo que hace una oficina de verdad: se llama al
## siguiente numero mientras se termina con el anterior.
##
## Usa EXACTAMENTE la misma seleccion de cola que `_emparejar` (`elegir_de_cola` con las atenciones
## admitidas del puesto): Documentacion FIFO, ODAC por prioridad. No hay criterio nuevo, asi que no
## se puede colar nadie por esta via.
func _llamar_a_los_siguientes() -> void:
	for puesto_id: StringName in _puestos_flujo:
		var puesto: Dictionary = _puestos_flujo[puesto_id]
		if puesto["siguiente"] != null:
			continue                                  # ya tiene a alguien de camino
		if estado_de_puesto(puesto_id) != PUESTO_ATENDIENDO:
			continue                                  # solo se adelanta desde una atencion en curso
		if puesto["cierre_pendiente"] or puesto["retirada_pendiente"]:
			continue                                  # va a cerrar: no se llama a nadie mas
		var tipo: Resource = Datos.obtener(&"TipoPuesto", puesto["tipo"])
		if tipo == null:
			continue
		var admitidas: Array[StringName] = puesto["override"]
		if admitidas.is_empty():
			admitidas = tipo.atenciones_admitidas
		var candidata: RefCounted = elegir_de_cola(StringName(tipo.servicio), admitidas)
		if candidata == null:
			continue
		# Se calcula su camino ANTES de sacarla de la cola: si todavia no toca, se queda donde estaba
		# y otro puesto podra elegirla. `elegir_de_cola` no retira, solo mira.
		var camino: float = _minutos_de_camino(StringName(tipo.servicio), puesto_id, candidata)
		if camino < 0.0:
			continue   # incomunicada: tampoco se adelanta a nadie
		if float(puesto["restante"]) > camino + margen_llamada_anticipada_min:
			continue                                  # aun le queda demasiado tramite: todavia no
		retirar_de_cola(candidata)
		_transicionar(candidata, PersonaFlujoScript.ESTADO_LLAMADA)
		puesto["siguiente"] = candidata
		puesto["siguiente_camino"] = camino


## Minutos de JUEGO que la persona tarda en llegar al puesto tras la Llamada (enmienda 2026-07-25
## "en camino no se tramita"). DETERMINISTA y del MODELO, JAMÁS del sprite (FL5/ADR-0001): el origen
## es el CENTRO GEOMÉTRICO del rect de la sala de espera del servicio MÁS CERCANA al puesto — o la
## ENTRADA del edificio si la persona AÚN no tuvo tiempo de llegar a sentarse (3ª calibración: se
## deriva de su minuto de llegada y el reloj, ambos datos lógicos; el caso "ODAC libre te llama al
## entrar"). La distancia euclídea en celdas / la velocidad da los minutos. Devuelve 0.0 (camino
## instantáneo) si: no hay Construcción inyectada (tests de lógica pura), la velocidad es ≤ 0
## (knob "teleport"), o el servicio no tiene ninguna sala de espera (sin origen del que partir).
func _minutos_de_camino(servicio: StringName, puesto_id: StringName, persona: RefCounted) -> float:
	if _construccion == null or velocidad_camino_celdas_min <= 0.0:
		return 0.0
	var salas: Array[StringName] = _construccion.salas_de_espera_de(servicio)
	if salas.is_empty():
		return 0.0
	var destino: Vector2 = Vector2(_construccion.posicion_de(puesto_id))
	var origen: Vector2 = Vector2.ZERO
	var mejor_dist: float = -1.0
	for sala_id: StringName in salas:
		var rect: Rect2i = _construccion.rect_de_sala(sala_id)
		var centro: Vector2 = Vector2(rect.position) + Vector2(rect.size) / 2.0
		var dist: float = centro.distance_to(destino)
		if mejor_dist < 0.0 or dist < mejor_dist:
			mejor_dist = dist
			origen = centro
	if _tiempo != null:
		var min_dia: float = fposmod(_tiempo.minutos_juego, 1440.0)
		var esperado: float = fposmod(min_dia - float(persona.ficha.minuto_llegada), 1440.0)
		var entrada: Vector2 = Vector2(CELDA_ENTRADA)
		var camino_a_sala: float = entrada.distance_to(origen) / velocidad_camino_celdas_min
		if esperado < camino_a_sala:
			origen = entrada   # recién llegada/promovida: viene aún de la ENTRADA, no de la sala
	# CUADRICULAS REALES del recorrido, esquivando muros (peticion del usuario 2026-07-30). Antes se
	# media la distancia EUCLIDEA: con una pared de por medio, el reloj decia que el ciudadano tardaba
	# menos de lo que de verdad tarda, y la ventanilla se quedaba esperando a alguien que aun venia
	# dando la vuelta. Si no hay camino (sala incomunicada por muros sin puerta) se cae a la recta,
	# para no dejar a nadie en camino eterno.
	if _construccion.has_method("distancia_en_celdas"):
		var celdas: int = _construccion.distancia_en_celdas(
			Vector2i(roundi(origen.x), roundi(origen.y)), Vector2i(roundi(destino.x), roundi(destino.y))
		)
		if celdas >= 0:
			return float(celdas) / velocidad_camino_celdas_min
		# 🐛 SIN CAMINO (2026-07-30). El usuario: "el agente atiende como en la distancia aunque haya
		# cerrado la sala por completo y no pueda acceder el ciudadano a realizar el tramite".
		# Lo causaba MI salvaguarda anterior: cuando no habia ruta, se caia a la distancia en linea
		# recta... y entonces el ciudadano "llegaba" atravesando la pared. Ahora se devuelve -1 y
		# `_emparejar` NO llama a nadie: una ventanilla tapiada no atiende, que es lo unico coherente.
		return -1.0
	return origen.distance_to(destino) / velocidad_camino_celdas_min


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
	return maxf(1.0, base * modificador * mult_equipamiento(puesto_id))


## **Comodidades #15 (story com-002)** · Lo que acelera al puesto el material instalado en su sala:
## `clamp(1 − k_equipamiento × rendimiento, mult_equipamiento_min, 1.0)`. Se multiplica **sobre** el
## modificador del agente (F1), no lo sustituye: un agente rápido con buen equipo va aún más rápido.
##
## Reparto de propiedad: Construcción dice **cuánto material hay**; la conversión es de Flujo, porque
## la duración de la atención es SU fórmula (ADR-0001). Sin Construcción inyectada devuelve 1.0.
func mult_equipamiento(puesto_id: StringName) -> float:
	if _construccion == null or not _construccion.has_method("equipamiento_de_puesto"):
		return 1.0
	var rendimiento: float = _construccion.equipamiento_de_puesto(puesto_id)
	return clampf(1.0 - k_equipamiento * rendimiento, mult_equipamiento_min, 1.0)


## El tick de simulación (recibe `delta_juego` en MINUTOS; en Pausa Tiempo no empuja → FL8).
## ORDEN FIJO del contrato determinista: (1) avanzar/completar atenciones — el puesto liberado
## queda Libre (o Cerrado/retirado si tenía un pendiente, story 006); (2) reintentar demoliciones
## pendientes de Construcción (AC-CO13 — antes de emparejar: un puesto demolido no llama);
## (3) emparejar — los libres llaman EN el mismo tick; (4) avanzar caminos — la persona recorre el
## trayecto al puesto (enmienda 2026-07-25 "en camino no se tramita") y, al llegar, arranca la
## atención; con camino 0 (knob 0 / sin Construcción) arranca ese mismo tick (compat).
func _al_tick(delta_juego_min: float) -> void:
	_avanzar_atenciones(delta_juego_min)
	_reintentar_demoliciones()
	_emparejar()
	_avanzar_caminos(delta_juego_min)
	_gestionar_horario_doc()


## Resta delta a cada atención en curso; al cumplirse la duración: emite `tramite_completado`
## (tramite + agente REAL del puesto — Economía cobra, Paciencia cerrará visita) UNA sola vez,
## la Persona pasa a Resuelta (despawn lógico) y el puesto queda Libre — salvo pendientes de la
## story 006: `cierre_pendiente` → Cerrado; `retirada_pendiente` → fuera del flujo.
## Los minutos trabajados tras el cierre YA NO generan euros (doc-003): quien termina fuera de hora
## cuesta MORAL, y de eso se encarga Documentación #8 escuchando `tramite_completado`.
func _avanzar_atenciones(delta_min: float) -> void:
	_puestos_a_retirar.clear()
	for puesto_id: StringName in _puestos_flujo:
		var puesto: Dictionary = _puestos_flujo[puesto_id]
		var persona: RefCounted = puesto["persona"]
		if persona == null or persona.estado != PersonaFlujoScript.ESTADO_EN_ATENCION:
			# 🐛 Bienestar #13 (2026-07-29): el puesto está LIBRE y aquí no había nada que hacer, así
			# que un agente con la barra llena pero sin cola **no se iba nunca** al café — el descanso
			# solo se comprobaba al COMPLETAR un trámite (más abajo), y sin cliente no se completa
			# ninguno. Se quedaba en rojo indefinidamente. Y es justo al revés: sin nadie esperando es
			# el MEJOR momento para irse, porque no deja a nadie plantado.
			_pedir_cafe_si_toca(puesto_id)
			continue
		# Atender CANSA (Bienestar #13): quien despacha se desgasta; quien espera cliente, no. En
		# horas extra desgasta más (lo modula el precio que el jugador paga por la peonada).
		if _personal != null and _personal.has_method("cansar"):
			_personal.cansar(_personal.agente_de(puesto_id), delta_min, _en_horas_extra_doc())
		puesto["restante"] = float(puesto["restante"]) - delta_min
		if puesto["restante"] > 0.0:
			continue
		var agente: RefCounted = _personal.agente_de(puesto_id) if _personal != null else null
		if _bus != null:
			_bus.tramite_completado.emit(persona.tramite_id(), agente)
		_transicionar(persona, PersonaFlujoScript.ESTADO_RESUELTA)
		puesto["persona"] = null
		puesto["restante"] = 0.0
		if puesto["cierre_pendiente"]:
			puesto["abierto"] = false
			puesto["cierre_pendiente"] = false
		if puesto["retirada_pendiente"]:
			_puestos_a_retirar.append(puesto_id)   # no se borra DENTRO de la iteración
		# El café se pide AL TERMINAR una atención, nunca a media (compromiso de servicio): quien
		# tiene la barra llena se levanta ahora, con el ciudadano ya despachado. Su puesto deja de
		# estar dotado solo — el gate FL4 exige ASIGNADO, y descansando ya no lo está.
		if _personal != null and _personal.has_method("necesita_descanso") 				and _personal.necesita_descanso(agente):
			_personal.enviar_a_descansar(agente)
		# LLAMADA ANTICIPADA: el cafe se pide ANTES de esto a proposito. Si el agente se acaba de
		# levantar, la ventanilla ya no puede atender y al reservado hay que devolverle a la cola en
		# vez de mandarle a un mostrador vacio. `estado_de_puesto` resuelve las tres causas de un
		# golpe (cerrado por horario o por el jugador / sin agente por el cafe / retirado): solo si
		# queda LIBRE —abierto Y dotado— puede empalmar con el siguiente.
		if estado_de_puesto(puesto_id) == PUESTO_LIBRE:
			_promover_siguiente(puesto_id)
		else:
			_liberar_siguiente(puesto_id)
	for puesto_id: StringName in _puestos_a_retirar:
		_puestos_flujo.erase(puesto_id)


## Le pide el café al titular de este puesto si le toca (Bienestar #13). Se llama desde DOS sitios y
## por motivos distintos: al **completar** un trámite (el compromiso de servicio: nunca a media
## atención) y con el puesto **libre** (sin cliente no hay a quien dejar plantado, así que es el mejor
## momento). Personal decide de verdad — aquí solo se pregunta.
func _pedir_cafe_si_toca(puesto_id: StringName) -> void:
	if _personal == null or not _personal.has_method("necesita_descanso"):
		return
	var agente: RefCounted = _personal.agente_de(puesto_id)
	if agente != null and _personal.necesita_descanso(agente):
		_personal.enviar_a_descansar(agente)


## Devuelve a la cola al SIGUIENTE reservado de un puesto (llamada anticipada), si lo hay. Se usa
## cuando la ventanilla deja de poder atenderle ANTES de que llegue: cierra, la demuelen, o su
## agente se va al cafe. La reserva es blanda a proposito — todavia no le han empezado a atender,
## asi que devolverle a la cola no rompe ningun compromiso de servicio. Conserva su numero de turno,
## asi que no pierde su sitio: vuelve por donde estaba.
func _liberar_siguiente(puesto_id: StringName) -> void:
	if not _puestos_flujo.has(puesto_id):
		return
	var puesto: Dictionary = _puestos_flujo[puesto_id]
	var reservada: RefCounted = puesto["siguiente"]
	if reservada == null:
		return
	puesto["siguiente"] = null
	puesto["siguiente_camino"] = 0.0
	if _transicionar(reservada, PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO):
		encolar(reservada)


## Promueve al SIGUIENTE a persona del puesto: hereda el camino que le quedara. Si ya habia llegado
## (camino 0), `_avanzar_caminos` arrancara su atencion en ESTE MISMO tick — que es justo el punto
## de todo esto: empalmar sin tiempo muerto.
func _promover_siguiente(puesto_id: StringName) -> void:
	var puesto: Dictionary = _puestos_flujo[puesto_id]
	if puesto["siguiente"] == null:
		return
	puesto["persona"] = puesto["siguiente"]
	puesto["camino_restante"] = puesto["siguiente_camino"]
	puesto["siguiente"] = null
	puesto["siguiente_camino"] = 0.0


## AC-CO13: si Construcción tiene demoliciones PENDIENTES (el gate `puede_demoler` las frenó por
## atención en curso), reintentarlas — las que caigan salen también del registro del flujo. En el
## camino común (sin pendientes) no aloca nada.
func _reintentar_demoliciones() -> void:
	if _construccion == null or not _construccion.has_method("hay_demoliciones_pendientes"):
		return
	if not _construccion.hay_demoliciones_pendientes():
		return
	for puesto_id: StringName in _construccion.reintentar_demoliciones_pendientes():
		_puestos_flujo.erase(puesto_id)


## Avanza el CAMINO de las personas en Llamada (enmienda 2026-07-25 "en camino no se tramita"): resta
## `delta_min` a `camino_restante` y, al agotarse (≤ 0), la persona LLEGA → pasa a En atención con su
## `duracion_efectiva` (F1). El camino descuenta EN el mismo tick de la Llamada (se llama tras
## `_emparejar` dentro del tick): con `camino_restante == 0.0` (knob 0, sin Construcción o sin sala)
## la atención arranca ese mismo tick — el comportamiento previo a la enmienda, compat total. El
## viaje NO descuenta trámite: el `restante` de la atención solo empieza a bajar al LLEGAR.
func _avanzar_caminos(delta_min: float) -> void:
	for puesto_id: StringName in _puestos_flujo:
		var puesto: Dictionary = _puestos_flujo[puesto_id]
		# El SIGUIENTE (llamada anticipada) tambien anda, aunque el puesto siga ocupado. No transiciona
		# al llegar: se queda en Llamada, esperando a que su ventanilla se libere y le promueva.
		if puesto["siguiente"] != null:
			puesto["siguiente_camino"] = maxf(float(puesto["siguiente_camino"]) - delta_min, 0.0)
		var persona: RefCounted = puesto["persona"]
		if persona == null or persona.estado != PersonaFlujoScript.ESTADO_LLAMADA:
			continue
		puesto["camino_restante"] = float(puesto["camino_restante"]) - delta_min
		if puesto["camino_restante"] > 0.0:
			continue
		_transicionar(persona, PersonaFlujoScript.ESTADO_EN_ATENCION)
		puesto["restante"] = duracion_efectiva(persona.servicio(), persona.tramite_id(), puesto_id)
		puesto["camino_restante"] = 0.0


## Horario provisional 2026-07-25 (PROVISIONAL en Flujo hasta Documentación #8): "los funcionarios se
## van al cierre". Corre AL FINAL de `_al_tick` (tras `_avanzar_caminos`) para que la cola admitida se
## haya podido vaciar ANTES de cerrar (AC-FL24: nada se interrumpe a medias). Reglas:
##   • EN horario [apertura_doc_min, cierre_doc_min) y el puesto está cerrado POR HORARIO → reabre solo.
##   • FUERA de horario, el puesto Doc está abierto, LIBRE (sin persona en curso) y ya NO le queda
##     nadie admitido en su cola (mismo criterio que `_emparejar`) → cierra por HORARIO.
## Solo toca puestos de servicio Documentación (ODAC es 24 h). NUNCA reabre un cierre MANUAL del
## jugador (`cierre_horario == false`): esa marca distingue "cerró la persiana el horario" de "lo cerró
## el jugador". Sin reloj inyectado (tests unitarios sin hora) → no-op.
func _gestionar_horario_doc() -> void:
	if _tiempo == null:
		return
	var min_dia: float = fposmod(_tiempo.minutos_juego, 1440.0)
	for puesto_id: StringName in _puestos_flujo:
		var puesto: Dictionary = _puestos_flujo[puesto_id]
		var tipo: Resource = Datos.obtener(&"TipoPuesto", puesto["tipo"])
		if tipo == null or tipo.servicio != String(SERVICIO_DOC):
			continue
		# Cada ventanilla puede tener SU hora de cierre (story doc-006): "esta se queda por la tarde".
		var cierre: int = cierre_de_puesto(puesto_id)
		var en_horario: bool = min_dia >= float(apertura_doc_min) and min_dia < float(cierre)
		if en_horario and puesto["cierre_horario"]:
			puesto["abierto"] = true
			puesto["cierre_horario"] = false
		elif not en_horario and puesto["abierto"] and puesto["persona"] == null:
			var admitidas: Array[StringName] = puesto["override"]   # mismo criterio que _emparejar
			if admitidas.is_empty():
				admitidas = tipo.atenciones_admitidas
			if elegir_de_cola(SERVICIO_DOC, admitidas) == null:
				puesto["abierto"] = false
				puesto["cierre_horario"] = true


# ── Matemáticas de colas F2-F5 (Story 005 · PURAS — las llama la UI/R5 bajo demanda, NO el tick) ──

## F2: trámites que un puesto saca por jornada = floor(minutos operativos / duración media).
## `minutos_operativos` es entrada PROVISIONAL (Documentación/Horarios #8 la poseerá). Duración
## ≤ 0 (dato corrupto) → 0 con aviso: un puesto que no procesa, NUNCA división por cero.
func throughput_puesto(minutos_operativos: float, duracion_media_min: float) -> int:
	if duracion_media_min <= 0.0:
		push_warning("Flujo: F2 con duracion media <= 0 -> throughput 0")
		return 0
	return int(floorf(minutos_operativos / duracion_media_min))


## F3: capacidad de un servicio = puestos operativos × throughput por puesto (F2). Negativos → 0.
func capacidad_servicio(n_puestos: int, throughput_por_puesto: int) -> int:
	return maxi(n_puestos, 0) * maxi(throughput_por_puesto, 0)


## F4: factor de carga ρ = tasa de llegadas / capacidad (misma unidad de tiempo). Capacidad ≤ 0 →
## -1.0, el centinela "sin servicio" (la UI muestra texto; NUNCA ∞ ni división por cero).
func factor_carga(tasa_llegadas: float, capacidad: float) -> float:
	if capacidad <= 0.0:
		return -1.0
	return tasa_llegadas / capacidad


## F5: espera estimada (min) = personas delante × duración media / puestos operativos. Se ESTIMA,
## no se simula (ADR-0001). Sin puestos o duración ≤ 0 → -1.0 ("indefinida" — la UI pone texto).
func espera_estimada(personas_delante: int, n_puestos: int, duracion_media_min: float) -> float:
	if n_puestos <= 0 or duracion_media_min <= 0.0:
		return -1.0
	return float(personas_delante) * duracion_media_min / float(n_puestos)


# ── Persistencia (Story 007 · TR-flow-006 · ADR-0002 — "cargar sitúa": 0 señales) ────────────

## Estado serializable del flujo (contrato `Persist`; clave = node.name "Flujo"). SOLO estado
## lógico NO derivado: personas (campos de su ficha + turno + estado — la pertenencia a colas y
## el dentro/fuera se RE-DERIVAN del estado al cargar: una sola verdad), puestos (su estado de
## runtime; el REGISTRO lo hace el mundo ANTES de cargar — patrón Personal) y contadores de
## turno. NUNCA posiciones de sprites (FL5) ni el RNG (Flujo no usa azar). JSON-safe.
func save() -> Dictionary:
	var personas: Array = []
	for servicio: StringName in _colas:
		for persona: RefCounted in _colas[servicio]:
			personas.append(_persona_a_dict(persona))
	var puestos: Array = []
	for puesto_id: StringName in _puestos_flujo:
		var puesto: Dictionary = _puestos_flujo[puesto_id]
		var persona_turno: int = -1
		if puesto["persona"] != null:
			personas.append(_persona_a_dict(puesto["persona"]))
			persona_turno = puesto["persona"].numero_turno
		# El RESERVADO de la llamada anticipada no esta en ninguna cola (se le retiro al llamarle) ni es
		# `puesto["persona"]`: si no se serializa AQUI, al cargar no existe en ninguna parte y se PIERDE
		# — un ciudadano borrado del mundo por haber guardado en el momento justo. Lo cazo el test de
		# persistencia: guardaba su numero de turno pero no a la persona a la que ese numero apunta.
		var siguiente_turno: int = -1
		if puesto["siguiente"] != null:
			personas.append(_persona_a_dict(puesto["siguiente"]))
			siguiente_turno = puesto["siguiente"].numero_turno
		var override_json: Array = []
		for atencion: StringName in puesto["override"]:
			override_json.append(String(atencion))
		puestos.append({
			"id": String(puesto_id),
			"abierto": puesto["abierto"],
			"cierre_pendiente": puesto["cierre_pendiente"],
			"retirada_pendiente": puesto["retirada_pendiente"],   # no estaba en la story: el
			"override": override_json,                            # diseño de la 006 lo exige
			"cierre_horario": puesto["cierre_horario"],            # horario provisional 2026-07-25
			"persona_turno": persona_turno,
			"restante": float(puesto["restante"]),
			"camino_restante": float(puesto["camino_restante"]),   # enmienda 2026-07-25 (en camino)
			# LLAMADA ANTICIPADA (2026-07-29): el reservado se guarda por su NUMERO DE TURNO, igual que
			# la persona atendida. Asi al cargar se le vuelve a atar a SU ventanilla y no se pierde ni
			# se duplica — que es lo unico innegociable de un save.
			"siguiente_turno": siguiente_turno,
			"siguiente_camino": float(puesto["siguiente_camino"]),
		})
	var turnos: Dictionary = {}
	for servicio: StringName in _turnos:
		turnos[String(servicio)] = _turnos[servicio]
	return {"personas": personas, "puestos": puestos, "turnos": turnos}


## La persona serializada por CAMPOS (su ficha de Demanda son 3 campos — se reconstruye al
## cargar; StringName → String para JSON).
func _persona_a_dict(persona: RefCounted) -> Dictionary:
	return {
		"servicio": String(persona.servicio()),
		"tramite": String(persona.tramite_id()),
		"minuto_llegada": float(persona.ficha.minuto_llegada),
		"turno": persona.numero_turno,
		"estado": String(persona.estado),
		"colado": persona.colado,
	}


## Restaura el estado (AC-FL26): "cargar sitúa" — 0 señales, sin eventos retroactivos (la Pausa
## la pone el SaveManager). DEFENSIVO (patrón Personal): una entrada corrupta se DESCARTA con
## aviso y el resto carga — jamás invalida el save entero. INVARIANTE del caller: los puestos
## registrados ANTES de cargar (Construcción y Personal cargan primero — orden de hijos en Main).
func load_state(d: Dictionary) -> void:
	# 1) Limpiar runtime: colas y contadores fuera; los puestos REGISTRADOS se resetean a default.
	_colas.clear()
	_turnos.clear()
	for puesto_id: StringName in _puestos_flujo:
		var puesto: Dictionary = _puestos_flujo[puesto_id]
		puesto["abierto"] = true
		puesto["persona"] = null
		puesto["restante"] = 0.0
		puesto["camino_restante"] = 0.0   # enmienda 2026-07-25 (en camino): default limpio
		puesto["cierre_pendiente"] = false
		puesto["retirada_pendiente"] = false
		puesto["cierre_horario"] = false   # horario provisional 2026-07-25: default limpio
		var sin_override: Array[StringName] = []
		puesto["override"] = sin_override
	# 2) Contadores de turno (el paso 3 los refuerza: jamás por debajo de un turno visto — FL2).
	var turnos: Dictionary = d.get("turnos", {})
	for servicio: String in turnos:
		_turnos[StringName(servicio)] = maxi(int(turnos[servicio]), 0)
	# 3) Personas: reconstruir y RE-DERIVAR su sitio del estado (esperando → cola; en atención /
	#    llamada → a la espera de que su puesto la reclame por servicio+turno en el paso 4).
	var atendidas: Dictionary = {}   # "servicio/turno" -> PersonaFlujo
	for entrada: Variant in d.get("personas", []):
		var persona: RefCounted = _persona_desde_dict(entrada)
		if persona == null:
			continue
		var servicio: StringName = persona.servicio()
		if (
			persona.estado == PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO
			or persona.estado == PersonaFlujoScript.ESTADO_ESPERANDO_FUERA
		):
			if not _colas.has(servicio):
				_colas[servicio] = []
			_colas[servicio].append(persona)
		elif (
			persona.estado == PersonaFlujoScript.ESTADO_EN_ATENCION
			or persona.estado == PersonaFlujoScript.ESTADO_LLAMADA
		):
			atendidas["%s/%d" % [servicio, persona.numero_turno]] = persona
		else:
			push_warning("Flujo: persona en estado '%s' en el save -> descartada" % persona.estado)
			continue
		_turnos[servicio] = maxi(_turnos.get(servicio, 0), persona.numero_turno)
	# 4) Puestos: aplicar el save SOLO a los registrados; re-atar la atención por servicio+turno.
	for entrada: Variant in d.get("puestos", []):
		if not (entrada is Dictionary) or not entrada.has("id"):
			push_warning("Flujo: entrada de puesto corrupta en el save -> descartada")
			continue
		var puesto_id: StringName = StringName(String(entrada["id"]))
		if not _puestos_flujo.has(puesto_id):
			push_warning("Flujo: puesto '%s' del save no esta registrado -> descartado" % puesto_id)
			continue
		var puesto: Dictionary = _puestos_flujo[puesto_id]
		puesto["abierto"] = bool(entrada.get("abierto", true))
		puesto["cierre_pendiente"] = bool(entrada.get("cierre_pendiente", false))
		puesto["retirada_pendiente"] = bool(entrada.get("retirada_pendiente", false))
		puesto["cierre_horario"] = bool(entrada.get("cierre_horario", false))   # horario provisional 2026-07-25
		puesto["restante"] = maxf(float(entrada.get("restante", 0.0)), 0.0)
		# enmienda 2026-07-25 (en camino): los minutos de camino que faltaban al guardar.
		puesto["camino_restante"] = maxf(float(entrada.get("camino_restante", 0.0)), 0.0)
		var override_cargado: Array[StringName] = []
		for atencion: Variant in entrada.get("override", []):
			override_cargado.append(StringName(String(atencion)))
		puesto["override"] = override_cargado
		puesto["siguiente_camino"] = maxf(float(entrada.get("siguiente_camino", 0.0)), 0.0)
		var siguiente_turno: int = int(entrada.get("siguiente_turno", -1))
		if siguiente_turno >= 0:
			var tipo_s: Resource = Datos.obtener(&"TipoPuesto", puesto["tipo"])
			var clave_s: String = "%s/%d" % [StringName(tipo_s.servicio), siguiente_turno]
			if atendidas.has(clave_s):
				puesto["siguiente"] = atendidas[clave_s]
				atendidas.erase(clave_s)
			else:
				# No esta en el save: la reserva se descarta y el puesto queda sin siguiente. Nadie se
				# pierde — si esa persona sigue en la cola, se le volvera a llamar en el proximo tick.
				push_warning(
					"Flujo: el siguiente del puesto '%s' (turno %d) no esta en el save -> sin reserva"
					% [puesto_id, siguiente_turno]
				)
		var persona_turno: int = int(entrada.get("persona_turno", -1))
		if persona_turno >= 0:
			var tipo: Resource = Datos.obtener(&"TipoPuesto", puesto["tipo"])
			var clave: String = "%s/%d" % [StringName(tipo.servicio), persona_turno]
			if atendidas.has(clave):
				puesto["persona"] = atendidas[clave]
				atendidas.erase(clave)
			else:
				push_warning(
					"Flujo: la persona del puesto '%s' (turno %d) no esta en el save -> puesto libre"
					% [puesto_id, persona_turno]
				)
				puesto["restante"] = 0.0
				puesto["camino_restante"] = 0.0   # sin persona no hay camino en curso (enmienda 2026-07-25)
	# 5) Atendidas que ningún puesto reclamó → descartadas con aviso (no hay dónde situarlas).
	for clave: String in atendidas:
		push_warning("Flujo: persona en atencion sin puesto en el save ('%s') -> descartada" % clave)


## Reconstruye una PersonaFlujo desde el save. Corrupta (servicio desconocido, trámite fuera del
## catálogo, turno/estado inválidos) → null con aviso (el caller la descarta y sigue).
func _persona_desde_dict(entrada: Variant) -> RefCounted:
	if not (entrada is Dictionary):
		push_warning("Flujo: entrada de persona corrupta en el save -> descartada")
		return null
	var servicio: StringName = StringName(String(entrada.get("servicio", "")))
	if servicio != SERVICIO_DOC and servicio != SERVICIO_ODAC:
		push_warning("Flujo: persona con servicio '%s' en el save -> descartada" % servicio)
		return null
	var tramite: StringName = StringName(String(entrada.get("tramite", "")))
	var tipo_catalogo: StringName = &"TramiteDoc" if servicio == SERVICIO_DOC else &"DenunciaODAC"
	if Datos.obtener(tipo_catalogo, tramite) == null:
		push_warning("Flujo: persona con tramite '%s' fuera del catalogo -> descartada" % tramite)
		return null
	var turno: int = int(entrada.get("turno", 0))
	var estado: StringName = StringName(String(entrada.get("estado", "")))
	if turno <= 0 or not TRANSICIONES_VALIDAS.has(estado):
		push_warning("Flujo: persona con turno/estado invalido en el save -> descartada")
		return null
	var ficha: RefCounted = PersonaScript.new(
		servicio, tramite, float(entrada.get("minuto_llegada", 0.0))
	)
	var persona: RefCounted = PersonaFlujoScript.new(ficha, turno)
	persona.estado = estado
	persona.colado = bool(entrada.get("colado", false))   # colar es decisión del jugador: sobrevive al save
	return persona


# ── Config (patrón del proyecto: aplicar con clamp defensivo + carga con fallback) ───────────

## Copia los knobs del config con clamp defensivo. Config nulo/de otro tipo → defaults.
func aplicar_config(config: Resource) -> void:
	if config == null or not (config is ConfigFlujoScript):
		push_warning("Flujo: config invalido -> defaults")
		config = ConfigFlujoScript.new()
	velocidad_camino_celdas_min = clampf(config.velocidad_camino_celdas_min, 0.0, 100.0)
	habilitar_aging_odac = config.habilitar_aging_odac
	tope_cola_exterior = maxi(config.tope_cola_exterior, 0)
	velocidad_npc_px_s = clampf(config.velocidad_npc_px_s, 10.0, 600.0)
	k_equipamiento = clampf(config.k_equipamiento, 0.0, 1.0)
	mult_equipamiento_min = clampf(config.mult_equipamiento_min, 0.1, 1.0)
	# El horario de Doc YA NO se lee de aquí (doc-002): lo empuja Documentación #8 con
	# `fijar_horario_doc()`. Sin ella, valen los defaults del horario base.


## Carga el `.tres` real con fallback seguro (falta/inválido → defaults con aviso; no peta).
func _cargar_config() -> void:
	var config: Resource = null
	if ResourceLoader.exists(RUTA_CONFIG):
		config = load(RUTA_CONFIG)
	if config == null:
		push_warning("Flujo: no se pudo cargar '%s' -> defaults" % RUTA_CONFIG)
	aplicar_config(config)
