class_name ImpresoraDocumentos extends Node
## Impresora de documentos y EL VIAJE DEL PAPEL (sistema Core; NODO del mundo, NO autoload — arq. §3.4).
##
## Implementa `design/gdd/impresora-documentos-tramite.md` (diseño CERRADO por el usuario 2026-08-01,
## números APROBADOS el mismo día). La mecánica, en una frase: **ciertos trámites terminan con un
## papel que hay que ir a buscar**, así que cerca del final de la atención el funcionario se levanta,
## va a la impresora más cercana ACCESIBLE, coge el documento y vuelve a su mesa — y el trámite no se
## cierra hasta que ha vuelto. Colocar bien la impresora IMPORTA: una lejos es cola que se acumula.
##
## Este nodo posee TRES cosas y nada más (ADR-0001 — cada sistema con SU fórmula):
##
##   1. **EL VIAJE** (§Detailed Rules 1-4): la máquina de fases `ida → recogida → vuelta → entregado`
##      con su tabla de transiciones válidas, cronometrada sobre el MODELO (celdas de Construcción /
##      velocidad), NUNCA sobre píxeles (ADR-0004). Flujo pregunta `retiene()` y no cierra el trámite
##      mientras la respuesta sea `true` — eso es la fase ESPERANDO_DOCUMENTO del GDD.
##   2. **LOS REQUISITOS MÍNIMOS DE SALA** (§decisión P1): *"no existe el caso 'sala sin impresora'"*.
##      Lo que cada sala exige vive en el catálogo (`TipoSala.comodidades_obligatorias` /
##      `puestos_minimos`), y `completar_requisitos()` coloca lo que falte de forma IDEMPOTENTE —
##      mismo patrón que `levantar_fachada`, que es justo lo que el GDD pide para los saves antiguos.
##   3. **EL MANTENIMIENTO POR USO** (§números aprobados): 2 € por cada TURNO del día en que la sala
##      de la impresora estuvo atendiendo. Sala cerrada = 0 €. Es la primera comodidad que se paga
##      por uso y no por tarifa plana (el knob `Comodidad.coste_mantenimiento_turno_eur` es general).
##
## Lo que este nodo NO hace, a propósito: no mueve sprites (el muñeco que se ve ir y volver lo pone la
## capa visual leyendo `fase_de()`), no toca la paciencia del ciudadano (sigue En atención, así que
## Paciencia ya la tiene parada desde la llamada) y no cobra nada por su cuenta (le REGISTRA el gasto
## a Economía, que es quien cierra las cuentas del día).
##
## Todo por INYECCIÓN (`usar_*`): sin Construcción no hay distancias ni impresoras (degrada a "no hay
## papel que buscar"), sin Economía no se cobra, sin reloj no se cuentan turnos. Así se prueba entero
## en headless sin levantar el juego.
##
## GDD: design/gdd/impresora-documentos-tramite.md · ADR-0001 / ADR-0003 / ADR-0004

## Ruta del config de tuning (fallback a los defaults del Resource si no existe — patrón ConfigFlujo).
const RUTA_CONFIG := "res://datos/config/impresora.tres"
const ConfigImpresoraScript := preload("res://src/core/impresora/config_impresora.gd")

## Id de catálogo de la comodidad. Es un objeto NUEVO y distinto de `impresora_dni` (GDD P3: aquella
## se queda como comodidad de confort no funcional; ESTA es la que da el papel).
const ID_CATALOGO := &"impresora_documentos"

# ── Las fases del viaje del papel (§Detailed Rules 2) ────────────────────────────────────────
## No hay viaje en curso (o ya se consumió): el puesto trabaja como toda la vida.
const FASE_SIN_VIAJE := &"sin_viaje"
## El funcionario va hacia la impresora. Dura `distancia / velocidad`.
const FASE_IDA := &"ida"
## La pausa breve delante de la impresora. Dura `t_recogida_min`.
const FASE_RECOGIDA := &"recogida"
## Vuelve a su mesa con el documento. Dura `distancia / velocidad` (el mismo camino).
const FASE_VUELTA := &"vuelta"
## Ya está de vuelta: el trámite PUEDE cerrarse. Es la única fase que no retiene.
const FASE_ENTREGADO := &"entregado"

## Transiciones VÁLIDAS de la máquina de fases. Lo que no está aquí se rechaza con aviso y no cambia
## nada (mismo patrón que la máquina de estados de Flujo: un dato corrupto no rompe la simulación).
## `IDA/RECOGIDA → VUELTA` cubre el edge case del GDD *"impresora demolida a mitad de viaje: el
## funcionario vuelve con las manos vacías"* — se salta lo que quede y regresa, sin papel.
const TRANSICIONES_VALIDAS: Dictionary[StringName, Array] = {
	FASE_SIN_VIAJE: [FASE_IDA],
	FASE_IDA: [FASE_RECOGIDA, FASE_VUELTA],
	FASE_RECOGIDA: [FASE_VUELTA],
	FASE_VUELTA: [FASE_ENTREGADO],
	FASE_ENTREGADO: [FASE_SIN_VIAJE],
}

## Lo que ve el jugador en la ventanilla mientras el funcionario está fuera (§Detailed Rules 5 —
## mismo patrón que el "☕ DESCANSO"). Vacío = no hay nada que contar.
const TEXTO_A_POR_EL_DOCUMENTO := "🖨 a por el documento"
const TEXTO_SIN_VIAJE := ""

## Prioridad de este sistema en el `nuevo_dia` ordenado del bus: **17**, entre el mantenimiento plano
## de Construcción (16) y el cierre de cuentas de Economía (20). El gasto por uso tiene que estar
## anotado antes de que Economía pase la factura.
const PRIORIDAD_NUEVO_DIA: int = 17

# ── Tuning knobs (copiados del config con clamp — ver aplicar_config) ────────────────────────
var t_aviso_min: float = 5.0
var t_recogida_min: float = 1.0
var velocidad_celdas_min: float = 0.375
var servicios_con_papel: Array[StringName] = [&"ODAC"]
var tramites_con_papel: Array[StringName] = [&"tie"]

# ── Estado ───────────────────────────────────────────────────────────────────────────────────
## Viajes en curso, `puesto_id -> {fase, restante_fase, restante_total, impresora, distancia,
## con_papel}`. Un puesto tiene como mucho UN viaje: el del ciudadano que está atendiendo.
var _viajes: Dictionary[StringName, Dictionary] = {}
## Turnos del día en que cada sala ATENDIÓ, `sala_id -> {turno: true}`. Es lo que factura el
## mantenimiento por uso. Se vacía en cada `nuevo_dia`, después de cobrar.
var _turnos_usados: Dictionary[StringName, Dictionary] = {}

## Construcción inyectada: de ella salen las impresoras colocadas, las distancias en celdas y la
## colocación de los requisitos. Sin ella no hay mecánica (degrada a "ningún trámite lleva papel").
var _construccion: Node = null
## Economía inyectada: recibe el gasto del mantenimiento por uso (`registrar_mantenimiento`).
var _economia: Node = null
## El bus: por él llega el `nuevo_dia` en que se factura el uso.
var _bus: Node = null
## El reloj: de él sale el TURNO actual para la cuenta del mantenimiento por uso.
var _tiempo: Node = null


func _ready() -> void:
	if _bus == null:
		usar_bus(get_node_or_null("/root/EventBus"))
	_cargar_config()


# ── Inyección de dependencias (todo testeable sin levantar el juego) ─────────────────────────

## Inyecta Construcción (dueña del layout: impresoras colocadas, distancias, colocación).
func usar_construccion(construccion: Node) -> void:
	_construccion = construccion


## Inyecta Economía (le REGISTRA el gasto del mantenimiento por uso; el saldo no se toca aquí).
func usar_economia(economia: Node) -> void:
	_economia = economia


## Inyecta el reloj (de él sale el turno actual para la cuenta del mantenimiento por uso).
func usar_tiempo(tiempo: Node) -> void:
	_tiempo = tiempo


## Inyecta el bus y registra el cobro del uso en el dispatcher ordenado con `PRIORIDAD_NUEVO_DIA`.
func usar_bus(bus: Node) -> void:
	_bus = bus
	if _bus != null and _bus.has_method("registrar_ordenado"):
		_bus.registrar_ordenado(&"nuevo_dia", PRIORIDAD_NUEVO_DIA, _al_nuevo_dia)


# ── P2: qué trámites llevan papel (GDD, decisión del usuario) ────────────────────────────────

## ¿Este trámite termina con un DOCUMENTO que hay que ir a buscar? *"TODAS las denuncias (ODAC) y la
## EXPEDICIÓN de TIE"* — el resto (DNI, pasaporte, consultas) no hace el viaje. Data-driven: la
## respuesta sale de los knobs `servicios_con_papel` / `tramites_con_papel`, nunca de un `if` con
## nombres escritos a mano.
func es_tramite_con_papel(servicio: StringName, tramite_id: StringName) -> bool:
	if servicio in servicios_con_papel:
		return true
	return tramite_id in tramites_con_papel


## ¿Le toca ya levantarse? (§Detailed Rules 1: al trámite le quedan `T_AVISO` minutos o menos).
func necesita_aviso(restante_tramite_min: float) -> bool:
	return restante_tramite_min <= t_aviso_min


# ── Las impresoras colocadas y la distancia hasta ellas ──────────────────────────────────────

## Las impresoras de documentos que hay construidas, en orden estable de construcción.
func impresoras() -> Array[StringName]:
	if _construccion == null or not _construccion.has_method("elementos_de_catalogo"):
		return []
	return _construccion.elementos_de_catalogo(ID_CATALOGO)


## La impresora más cercana ACCESIBLE desde una celda (§Detailed Rules 1: *"mismo criterio de paso
## que el resto de viajes: `distancia_en_celdas`"*). Las inalcanzables (BFS = -1: al otro lado de un
## tabique sin puerta) NO cuentan. Empate → gana la construida antes (determinista, sin azar).
## `&""` si no hay ninguna alcanzable.
func impresora_mas_cercana(origen: Vector2i) -> StringName:
	var mejor: StringName = &""
	var mejor_distancia: int = -1
	for impresora_id: StringName in impresoras():
		var distancia: int = _construccion.distancia_en_celdas(
			origen, _construccion.posicion_de(impresora_id)
		)
		if distancia < 0:
			continue   # incomunicada: por ahí no se llega andando
		if mejor == &"" or distancia < mejor_distancia:
			mejor = impresora_id
			mejor_distancia = distancia
	return mejor


## Celdas hasta la impresora más cercana (-1 si no hay ninguna alcanzable).
func distancia_a_impresora(origen: Vector2i) -> int:
	var impresora_id: StringName = impresora_mas_cercana(origen)
	if impresora_id == &"":
		return -1
	return _construccion.distancia_en_celdas(origen, _construccion.posicion_de(impresora_id))


# ── F1 · La fórmula del viaje (§Formulas) ────────────────────────────────────────────────────

## `t_viaje = (2 × distancia_celdas / velocidad_celdas_por_min) + t_recogida`.
##
## Sale del MODELO, no de los píxeles (ADR-0004): el visual solo lo interpreta, igual que los viajes
## al café. Con `velocidad_celdas_min <= 0` el trayecto es INSTANTÁNEO y el viaje cuesta solo la
## recogida — no se divide por cero jamás (mismo convenio que el camino 0 de Flujo).
## Distancia negativa (sin camino) → solo la recogida: no se inventa un tiempo de un viaje imposible.
func minutos_de_viaje(distancia_celdas: int) -> float:
	if distancia_celdas <= 0 or velocidad_celdas_min <= 0.0:
		return t_recogida_min
	return (2.0 * float(distancia_celdas) / velocidad_celdas_min) + t_recogida_min


## Minutos de UNA de las dos patas del trayecto (ida o vuelta). La recogida va aparte.
func _minutos_de_trayecto(distancia_celdas: int) -> float:
	if distancia_celdas <= 0 or velocidad_celdas_min <= 0.0:
		return 0.0
	return float(distancia_celdas) / velocidad_celdas_min


# ── El viaje del papel (máquina de fases) ────────────────────────────────────────────────────

## Arranca el viaje de un puesto desde su celda de trabajo. Devuelve `false` —y no pasa nada— si ya
## hay uno en curso o si no hay ninguna impresora alcanzable (con la regla de requisitos mínimos ese
## segundo caso no debería existir; si aparece, el trámite se cierra como antes en vez de colgarse).
func iniciar_viaje(puesto_id: StringName, origen: Vector2i) -> bool:
	if _viajes.has(puesto_id) and _viajes[puesto_id]["fase"] != FASE_SIN_VIAJE:
		return false
	var impresora_id: StringName = impresora_mas_cercana(origen)
	if impresora_id == &"":
		return false
	var distancia: int = _construccion.distancia_en_celdas(
		origen, _construccion.posicion_de(impresora_id)
	)
	var viaje: Dictionary = {
		"fase": FASE_SIN_VIAJE,
		"restante_fase": 0.0,
		"restante_total": minutos_de_viaje(distancia),
		"impresora": impresora_id,
		"distancia": distancia,
		"con_papel": false,
	}
	_viajes[puesto_id] = viaje
	_transicionar(puesto_id, FASE_IDA)
	return true


## Avanza TODOS los viajes en curso `delta_min` minutos de juego. El sobrante de una fase se arrastra
## a la siguiente (`while`), así que el viaje entero dura EXACTAMENTE `minutos_de_viaje` aunque el
## tick sea grande o la fase corta — sin depender del tamaño del delta (determinismo).
func avanzar(delta_min: float) -> void:
	for puesto_id: StringName in _viajes:
		var viaje: Dictionary = _viajes[puesto_id]
		var fase: StringName = viaje["fase"]
		if fase == FASE_ENTREGADO or fase == FASE_SIN_VIAJE:
			continue
		viaje["restante_total"] = maxf(float(viaje["restante_total"]) - delta_min, 0.0)
		var restante: float = float(viaje["restante_fase"]) - delta_min
		while restante <= 0.0 and viaje["fase"] != FASE_ENTREGADO:
			if not _transicionar(puesto_id, _siguiente_fase(viaje["fase"])):
				break
			restante += _duracion_de_fase(viaje, viaje["fase"])
		viaje["restante_fase"] = maxf(restante, 0.0)


## ¿Este puesto NO puede cerrar su trámite todavía porque el funcionario sigue a por el papel?
## Es la fase **ESPERANDO_DOCUMENTO** del GDD (§Detailed Rules 3) vista desde Flujo: mientras esto
## sea `true`, el trámite se queda a 0 de restante sin completarse — y el ciudadano NO abandona,
## porque para Paciencia sigue En atención (que es exactamente lo que el GDD pide).
func retiene(puesto_id: StringName) -> bool:
	if not _viajes.has(puesto_id):
		return false
	var fase: StringName = _viajes[puesto_id]["fase"]
	return fase != FASE_ENTREGADO and fase != FASE_SIN_VIAJE


## ¿Hay un viaje registrado para este puesto (en curso o ya entregado y sin consumir)?
func hay_viaje(puesto_id: StringName) -> bool:
	return _viajes.has(puesto_id) and _viajes[puesto_id]["fase"] != FASE_SIN_VIAJE


## Fase actual del viaje de un puesto (`FASE_SIN_VIAJE` si no tiene ninguno).
func fase_de(puesto_id: StringName) -> StringName:
	if not _viajes.has(puesto_id):
		return FASE_SIN_VIAJE
	return _viajes[puesto_id]["fase"]


## Minutos que le quedan al viaje ENTERO (0 si no hay viaje o ya llegó).
func restante_de(puesto_id: StringName) -> float:
	if not _viajes.has(puesto_id):
		return 0.0
	return float(_viajes[puesto_id]["restante_total"])


## ¿Volvió CON el documento? `false` si la impresora se demolió a mitad de viaje (§Edge Cases:
## *"el funcionario vuelve con las manos vacías"*) — el trámite se cierra igual, no se cuelga.
func con_papel(puesto_id: StringName) -> bool:
	if not _viajes.has(puesto_id):
		return false
	return bool(_viajes[puesto_id]["con_papel"])


## La impresora a la que fue (o va) este viaje (`&""` si no hay viaje).
func impresora_de(puesto_id: StringName) -> StringName:
	if not _viajes.has(puesto_id):
		return &""
	return _viajes[puesto_id]["impresora"]


## Consume el viaje: el papel ya se entregó con el trámite, el puesto queda limpio para el siguiente
## ciudadano. Lo llama Flujo justo después de completar la atención.
func consumir_viaje(puesto_id: StringName) -> void:
	if not _viajes.has(puesto_id):
		return
	_viajes.erase(puesto_id)


## Cancela el viaje de un puesto sin más (el ciudadano se fue, el puesto se demolió, se cerró...).
func cancelar_viaje(puesto_id: StringName) -> void:
	_viajes.erase(puesto_id)


## Una impresora ha sido DEMOLIDA: los viajes que iban a ella dan media vuelta CON LAS MANOS VACÍAS
## (§Edge Cases). No se cancelan —el funcionario está a medio camino y tiene que volver andando—,
## pero pierden el papel y saltan directos a la vuelta.
func impresora_demolida(impresora_id: StringName) -> void:
	for puesto_id: StringName in _viajes:
		var viaje: Dictionary = _viajes[puesto_id]
		if viaje["impresora"] != impresora_id:
			continue
		if viaje["fase"] != FASE_IDA and viaje["fase"] != FASE_RECOGIDA:
			continue
		viaje["con_papel"] = false
		if _transicionar(puesto_id, FASE_VUELTA):
			viaje["restante_fase"] = _duracion_de_fase(viaje, FASE_VUELTA)
			viaje["restante_total"] = viaje["restante_fase"]


## Lo que enseña la ventanilla mientras el funcionario está fuera (§Detailed Rules 5).
func texto_ventanilla(puesto_id: StringName) -> String:
	return TEXTO_A_POR_EL_DOCUMENTO if retiene(puesto_id) else TEXTO_SIN_VIAJE


## Transición de fase con GUARDIA (misma política que Flujo): una transición que no está en la tabla
## AVISA y no cambia nada. Devuelve si se aplicó.
func _transicionar(puesto_id: StringName, fase_nueva: StringName) -> bool:
	var viaje: Dictionary = _viajes[puesto_id]
	var fase_actual: StringName = viaje["fase"]
	if not (fase_nueva in TRANSICIONES_VALIDAS.get(fase_actual, [] as Array)):
		push_warning(
			"ImpresoraDocumentos: transicion invalida '%s' -> '%s' en el puesto '%s' (se ignora)"
			% [fase_actual, fase_nueva, puesto_id]
		)
		return false
	viaje["fase"] = fase_nueva
	if fase_nueva == FASE_IDA:
		viaje["restante_fase"] = _duracion_de_fase(viaje, FASE_IDA)
	elif fase_nueva == FASE_VUELTA and fase_actual == FASE_RECOGIDA:
		viaje["con_papel"] = true   # salió de la impresora con el documento en la mano
	return true


## La fase que sigue en el recorrido normal del viaje.
func _siguiente_fase(fase: StringName) -> StringName:
	match fase:
		FASE_SIN_VIAJE:
			return FASE_IDA
		FASE_IDA:
			return FASE_RECOGIDA
		FASE_RECOGIDA:
			return FASE_VUELTA
		_:
			return FASE_ENTREGADO


## Cuánto dura cada fase (la de llegada dura 0: es el final del viaje, no un tramo).
func _duracion_de_fase(viaje: Dictionary, fase: StringName) -> float:
	match fase:
		FASE_IDA, FASE_VUELTA:
			return _minutos_de_trayecto(int(viaje["distancia"]))
		FASE_RECOGIDA:
			return t_recogida_min
		_:
			return 0.0


# ── Requisitos mínimos de sala (§decisión P1 del usuario) ────────────────────────────────────

## Las comodidades OBLIGATORIAS de una sala, según su tipo del catálogo (vacío si no exige nada).
func comodidades_obligatorias_de(sala_id: StringName) -> Array[StringName]:
	var vacio: Array[StringName] = []
	if _construccion == null:
		return vacio
	var tipo: Resource = Datos.obtener_silencioso(&"TipoSala", _construccion.tipo_de_sala(sala_id))
	if tipo == null:
		return vacio
	var lista: Array[StringName] = []
	for id_catalogo: StringName in tipo.comodidades_obligatorias:
		lista.append(id_catalogo)
	return lista


## Las comodidades obligatorias que TODAVÍA no están colocadas en esa sala.
func comodidades_faltantes(sala_id: StringName) -> Array[StringName]:
	var faltan: Array[StringName] = []
	for id_catalogo: StringName in comodidades_obligatorias_de(sala_id):
		if _cuantas_hay(sala_id, id_catalogo) == 0:
			faltan.append(id_catalogo)
	return faltan


## Cuántos PUESTOS le faltan a la sala para su mínimo (0 = cumple). No se colocan solos: un puesto
## cuesta dinero Y necesita un funcionario asignado, así que esto se REPORTA para que lo cuente la UI.
func puestos_faltantes(sala_id: StringName) -> int:
	if _construccion == null:
		return 0
	var tipo: Resource = Datos.obtener_silencioso(&"TipoSala", _construccion.tipo_de_sala(sala_id))
	if tipo == null:
		return 0
	return maxi(int(tipo.puestos_minimos) - _puestos_de(sala_id).size(), 0)


## ¿La sala cumple TODOS sus requisitos mínimos (comodidades + puestos)?
func cumple_requisitos(sala_id: StringName) -> bool:
	return comodidades_faltantes(sala_id).is_empty() and puestos_faltantes(sala_id) == 0


## Coloca las comodidades obligatorias que falten en una sala. **IDEMPOTENTE**: llamarlo mil veces
## seguidas da exactamente el mismo resultado (mismo patrón que `levantar_fachada`), que es lo que el
## GDD pide para los saves antiguos y la comisaría de arranque.
##
## `de_oficio = true` → montaje inicial / recolocación de un save: no se cobra (la DGP lo entrega
## pagado, y a un save viejo no se le puede pasar factura retroactiva). `false` → construcción normal
## del jugador: pasa por el gate E4 de Economía como cualquier compra.
##
## Devuelve los `elemento_id` colocados (vacío si ya estaba todo o si no cabía en ningún sitio).
func completar_requisitos(sala_id: StringName, de_oficio: bool = true) -> Array[StringName]:
	var colocados: Array[StringName] = []
	if _construccion == null:
		return colocados
	for id_catalogo: StringName in comodidades_faltantes(sala_id):
		var celda: Vector2i = celda_para_comodidad(sala_id, id_catalogo)
		if celda == CELDA_NULA:
			push_warning(
				"ImpresoraDocumentos: la sala '%s' no tiene sitio valido para su '%s' obligatorio"
				% [sala_id, id_catalogo]
			)
			continue
		var elemento_id: StringName = (
			_construccion.construir_de_oficio_elemento(id_catalogo, celda) if de_oficio
			else _construccion.construir_elemento(id_catalogo, celda)
		)
		if elemento_id != &"":
			colocados.append(elemento_id)
	return colocados


## Repasa TODAS las salas construidas y completa lo que les falte. Es el punto de entrada de la
## recolocación tras cargar un save antiguo (*"se recolocan si faltan"*, GDD): idempotente y barato.
func completar_todas_las_salas(de_oficio: bool = true) -> Array[StringName]:
	var colocados: Array[StringName] = []
	if _construccion == null or not _construccion.has_method("salas_construidas"):
		return colocados
	for sala_id: StringName in _construccion.salas_construidas():
		colocados.append_array(completar_requisitos(sala_id, de_oficio))
	return colocados


## Centinela de "no hay celda válida" (ninguna celda del edificio es negativa).
const CELDA_NULA := Vector2i(-1, -1)


## DÓNDE va la comodidad obligatoria de una sala (§decisión de colocación del usuario): **detrás del
## puesto o a un lado, pero siempre de la mesa hacia atrás — NUNCA hacia el lado del ciudadano**.
##
## El orden de preferencia es literalmente el del GDD y se resuelve en DOS PASADAS sobre los puestos
## de la sala (orden estable de construcción):
##   1. **DETRÁS**: la fila que queda justo por detrás del bloque entero del puesto. Es la opción
##      buena y por eso se prueba en todos los puestos antes de conformarse con un lado.
##   2. **AL LADO, hacia atrás**: las celdas laterales de las filas que van desde la del funcionario
##      hasta la del mostrador — nunca más adelante, que ahí es donde se sienta el ciudadano.
## Sin ningún puesto todavía (sala recién designada): la primera celda válida de la sala, en orden
## de rejilla, para que la sala no se quede sin su objeto obligatorio esperando a tener ventanilla.
## `CELDA_NULA` si no hay ni una celda válida.
func celda_para_comodidad(sala_id: StringName, id_catalogo: StringName) -> Vector2i:
	var puestos: Array[StringName] = _puestos_de(sala_id)
	for detras: bool in [true, false]:
		for puesto_id: StringName in puestos:
			for celda: Vector2i in _candidatas_de_puesto(puesto_id, detras):
				if _construccion.validar_elemento(id_catalogo, celda):
					return celda
	for celda: Vector2i in _construccion.celdas_de_sala(sala_id):
		if _construccion.validar_elemento(id_catalogo, celda):
			return celda
	return CELDA_NULA


## Las celdas candidatas alrededor de un puesto, en el marco de SU orientación. `detras = true`
## devuelve la fila de detrás del bloque; `false`, los laterales de la mesa hacia atrás. Nunca
## devuelve nada del lado del ciudadano — esa es la invariante que sostiene toda la regla.
func _candidatas_de_puesto(puesto_id: StringName, detras: bool) -> Array[Vector2i]:
	var candidatas: Array[Vector2i] = []
	var ancla: Vector2i = _construccion.posicion_de(puesto_id)
	var orientacion: int = _construccion.orientacion_de(puesto_id)
	var paso: Vector2i = _paso_de(orientacion)
	var delante: Vector2i = _delante_de(orientacion)
	# Medida REAL del bloque tal como está colocado (un puesto que no cupo entero mide menos).
	var largo: int = 1
	var fila_min: int = 0
	for celda: Vector2i in _construccion.celdas_de_elemento(puesto_id):
		var offset: Vector2i = celda - ancla
		largo = maxi(largo, offset.x * paso.x + offset.y * paso.y + 1)
		fila_min = mini(fila_min, offset.x * delante.x + offset.y * delante.y)
	if detras:
		for i: int in range(largo):
			candidatas.append(ancla + delante * (fila_min - 1) + paso * i)
		return candidatas
	for fila: int in range(fila_min, 1):        # de la fila del funcionario a la del mostrador
		candidatas.append(ancla + delante * fila - paso)          # lado "antes" del mostrador
		candidatas.append(ancla + delante * fila + paso * largo)  # lado "después" del mostrador
	return candidatas


## El vector de UNA celda a lo largo del mostrador según su orientación. MISMA cuenta que
## `Construccion._paso_de` (no se puede llamar: es privada) — si aquella cambia, esta también.
func _paso_de(orientacion: int) -> Vector2i:
	return Vector2i(0, 1) if orientacion == 1 else Vector2i(1, 0)


## El vector de UNA celda hacia DELANTE (el lado del ciudadano); hacia detrás es el mismo en
## negativo. MISMA cuenta que `Construccion._perpendicular_de`.
func _delante_de(orientacion: int) -> Vector2i:
	return Vector2i(-1, 0) if orientacion == 1 else Vector2i(0, 1)


## Los PUESTOS colocados en una sala, en orden estable de construcción.
func _puestos_de(sala_id: StringName) -> Array[StringName]:
	var puestos: Array[StringName] = []
	if _construccion == null:
		return puestos
	for elemento_id: StringName in _construccion.contenido_de_sala(sala_id):
		var catalogo: StringName = _construccion.catalogo_de_elemento(elemento_id)
		if Datos.obtener_silencioso(&"TipoPuesto", catalogo) != null:
			puestos.append(elemento_id)
	return puestos


## Cuántos ejemplares de un id de catálogo hay colocados en una sala.
func _cuantas_hay(sala_id: StringName, id_catalogo: StringName) -> int:
	var total: int = 0
	if _construccion == null:
		return total
	for elemento_id: StringName in _construccion.contenido_de_sala(sala_id):
		if _construccion.catalogo_de_elemento(elemento_id) == id_catalogo:
			total += 1
	return total


# ── Mantenimiento POR USO (§números aprobados por el usuario) ────────────────────────────────

## Anota que la sala de este puesto ESTÁ ATENDIENDO en el turno actual. Lo llama Flujo en cada tick
## por cada puesto que despacha; anotar un turno ya anotado no hace nada (el diccionario es un
## conjunto), así que no aloca en el camino común. Sin reloj inyectado no se cuenta nada.
func registrar_atencion(puesto_id: StringName) -> void:
	if _tiempo == null or _construccion == null:
		return
	var sala_id: StringName = _construccion.sala_de_elemento(puesto_id)
	if sala_id == &"":
		return
	if not _turnos_usados.has(sala_id):
		_turnos_usados[sala_id] = {}
	_turnos_usados[sala_id][_tiempo.turno_de(fposmod(_tiempo.minutos_juego, 1440.0))] = true


## En cuántos turnos del día ha atendido esta sala (0-3). Es el multiplicador de la factura.
func turnos_usados_de(sala_id: StringName) -> int:
	return (_turnos_usados.get(sala_id, {}) as Dictionary).size()


## F2 · `coste_dia = Σ (mantenimiento_por_turno del objeto × turnos operativos de su sala)`.
##
## La regla aprobada: *"2 € por TURNO en que su sala atiende"* — ODAC 24 h = 3 turnos = 6 €/día;
## TIE solo mañana = 2 €/día; con peonada de tarde = 4 €/día; **sala cerrada = 0 €**. Recorre TODAS
## las comodidades colocadas, no solo las impresoras: el knob es general (`Comodidad
## .coste_mantenimiento_turno_eur`), así que el día que otro objeto se cobre por uso, entra solo.
func coste_mantenimiento_uso() -> float:
	var total: float = 0.0
	if _construccion == null or not _construccion.has_method("salas_construidas"):
		return total
	for sala_id: StringName in _construccion.salas_construidas():
		var turnos: int = turnos_usados_de(sala_id)
		if turnos == 0:
			continue   # sala cerrada: no paga nada (regla explícita del GDD)
		for elemento_id: StringName in _construccion.contenido_de_sala(sala_id):
			var comodidad: Resource = Datos.obtener_silencioso(
				&"Comodidad", _construccion.catalogo_de_elemento(elemento_id)
			)
			if comodidad != null:
				total += float(comodidad.coste_mantenimiento_turno_eur) * float(turnos)
	return total


## Handler del `nuevo_dia` (prioridad 17, entre el mantenimiento plano de Construcción y el cierre de
## Economía): registra el gasto por uso del día que termina y REINICIA la cuenta de turnos. El saldo
## no se toca aquí — Economía es quien mueve dinero (ADR-0001).
func _al_nuevo_dia() -> void:
	var coste: float = coste_mantenimiento_uso()
	if coste > 0.0 and _economia != null and _economia.has_method("registrar_mantenimiento"):
		_economia.registrar_mantenimiento(coste)
	_turnos_usados.clear()


# ── Config (data-driven, con clamps: un dato corrupto no revienta la mecánica) ───────────────

## Copia los knobs del config con clamps de sanidad. `config == null` → deja los defaults.
func aplicar_config(config: Resource) -> void:
	if config == null:
		return
	t_aviso_min = maxf(float(config.t_aviso_min), 0.0)
	t_recogida_min = maxf(float(config.t_recogida_min), 0.0)
	velocidad_celdas_min = float(config.velocidad_celdas_min)
	servicios_con_papel = config.servicios_con_papel.duplicate()
	tramites_con_papel = config.tramites_con_papel.duplicate()


func _cargar_config() -> void:
	var config: Resource = null
	if ResourceLoader.exists(RUTA_CONFIG):
		config = load(RUTA_CONFIG)
	aplicar_config(config)
