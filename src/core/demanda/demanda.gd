class_name Demanda extends Node
## Demanda — el grifo de la comisaría (sistema Core; NODO del mundo, NO autoload — arquitectura §3.4).
##
## Story 001 del epic: el núcleo — config data-driven (`ConfigDemanda`) y las FÓRMULAS DE VOLUMEN puras
## (F1 volumen diario por población · F2 perfil intradía + valle nocturno ODAC + ventana de Documentación).
## Story 002: el GENERADOR determinista (F4 acumulador + tope de ráfaga · F3 mezcla ponderada vía
## RNGService sembrado) que produce fichas `Persona`.
## Story 003: la CONEXIÓN al mundo — suscripción al tick de Tiempo (ADR-0001: Tiempo EMPUJA el tick en
## orden Tiempo→Demanda→Flujo→Paciencia), emisión de `persona_generada` al bus, reset del acumulador
## Doc al cruzar el cierre (DG6) y reset del contador diario al `nuevo_dia` (prioridad 40). La Pausa
## congela por construcción: Tiempo no empuja el tick con multiplicador 0 (DG9).
## Story 004: el NIVEL de demanda BAJA/MEDIA/ALTA (DG12) — señal `nivel_demanda_cambiado` solo al
## cambiar de tramo. Story 005: ESTACIONALIDAD (DG13, `nuevo_mes` prio 30) y EVENTOS multi-día (DG11).
## Story 006: PERSISTENCIA — `save()`/`load_state()` + grupo `Persist` (ADR-0002); el RNG lo serializa
## RNGService en su propia entrada; el mult estacional se RE-DERIVA del mes al cargar (fuente única).
##
## La `poblacion` viene SIEMPRE del `Escenario` del catálogo (Datos) — nunca hardcodeada: cada comisaría
## tiene la suya y el mismo código escala (AC-DM20, petición del usuario 2026-07-23). Los tests inyectan
## población con `fijar_poblacion()` (determinismo sin catálogo) o escenario real con `fijar_escenario()`.
##
## Story: production/epics/demanda/story-001-nucleo-config-volumen.md · TR-demand-001 · ADR-0003/0001

## Ruta del config de tuning (generado por tools/build_config_demanda.gd; fallback a defaults si falta).
const RUTA_CONFIG := "res://datos/config/demanda.tres"
const ConfigDemandaScript := preload("res://src/core/demanda/config_demanda.gd")
## La ficha que produce el generador (preload por RUTA — gotcha del headless en frío; ver Datos 001).
const PersonaScript := preload("res://src/core/demanda/persona.gd")

## Claves de servicio — coinciden con `Escenario.servicios_activos` del catálogo.
const SERVICIO_DOC := &"Documentacion"
const SERVICIO_ODAC := &"ODAC"
## Escenario por defecto del MVP (Nivel 1). El mundo puede fijar otro con `fijar_escenario()`.
const ESCENARIO_DEFAULT := &"pozuelo"

## Tramos del nivel de demanda de Documentación (DG12, story 004): la brújula futura de la peonada.
const NIVEL_BAJA := &"BAJA"
const NIVEL_MEDIA := &"MEDIA"
const NIVEL_ALTA := &"ALTA"

## Constantes de diseño (no tuning): minutos por hora y fin de la franja de valle nocturno de ODAC
## (00:00–07:00, GDD F2/DG3 — la franja es fija; el KNOB es `mult_nocturno_odac`).
const MINUTOS_POR_HORA := 60
const HORA_FIN_VALLE_ODAC := 7
const MINUTOS_POR_DIA := 1440.0
## Umbral del aviso "el acumulador no drena" (edge del GDD F4: mal tuning, tasa sostenida > tope de
## ráfaga), en múltiplos de `max_llegadas_por_tick`.
const UMBRAL_AVISO_ACUMULADOR := 3.0

# ── Tuning knobs (copiados del config con clamp; ver aplicar_config) ─────────────────────────
var tasa_base_doc: float = 0.5
var tasa_base_odac: float = 0.4
var perfil_hora_doc: Dictionary[int, float] = {}
var perfil_hora_odac: Dictionary[int, float] = {}
var mult_nocturno_odac: float = 0.5
var mult_dia_semana: float = 1.0
var max_llegadas_por_tick: int = 3
var factor_crecimiento_nivel: float = 1.0
var ventana_doc_inicio_min: int = 480
var ventana_doc_fin_min: int = 870
var mezcla_doc: Dictionary[StringName, float] = {}
var mezcla_odac: Dictionary[StringName, float] = {}
var umbral_nivel_bajo: float = 40.0
var umbral_nivel_alto: float = 60.0
var mult_estacional: Dictionary[int, float] = {}
var eventos: Array[Dictionary] = []

## Población del escenario activo (F1). 0 = grifo cerrado (config válida, AC-DM19) hasta que el mundo
## fije escenario/población. NUNCA lleva un default de juego: el valor vive en el catálogo.
var _poblacion: int = 0
## Id del escenario activo (informativo; lo fija `fijar_escenario`).
var _escenario_id: StringName = &""

# ── Cableado al mundo (Story 003 · TR-demand-001 · ADR-0001) ─────────────────────────────────
## El EventBus al que se emite `persona_generada` (inyectable; auto-resuelto en _ready). Demanda SOLO
## emite — no escucha señales de aviso (los eventos ordenados van por registro, no por señal).
var _bus: Node = null
## El reloj del juego (inyectable; auto-resuelto en _ready): provee `minutos_juego` y el hook del tick.
var _tiempo: Node = null
## Llegadas generadas en la jornada en curso (contador para el HUD, story 007). Lo resetea `nuevo_dia`.
var llegadas_hoy: int = 0
## Guarda del cruce del cierre de Documentación (patrón de cruces de Tiempo: valor anterior vs. nuevo,
## nunca `==` — robusto a floats y a saltos grandes).
var _min_dia_anterior: float = 0.0

# ── Nivel de demanda BAJA/MEDIA/ALTA (Story 004 · TR-demand-003 · GDD DG12) ──────────────────
## Tramo vigente (guarda anti-duplicado, patrón Economía `_estado_anterior`: la señal se emite SOLO
## al CAMBIAR de tramo). `&""` = aún sin calcular (el getter deriva sin efectos laterales).
var _nivel: StringName = &""

# ── Estacionalidad y eventos (Story 005 · TR-demand-001 · GDD DG13/DG11) ─────────────────────
## Multiplicador estacional del mes en curso (DG13), aplicado SOLO a Documentación. DERIVADO del mes
## de Tiempo (no se serializa: al cargar se recalcula del reloj — fuente única).
var _mult_estacional_vigente: float = 1.0
## Evento de demanda activo (DG11): `&""` = ninguno. Un solo evento a la vez en el MVP (si otro
## coincide, gana el activo y se avisa). SÍ se serializa (junto a sus jornadas restantes — story 006).
var _evento_activo: StringName = &""
var _evento_jornadas_restantes: int = 0
## Pesos de mezcla EFECTIVOS (base × `mult_peso` del evento activo, si lo hay) — los que consume
## `_elegir_tramite`. Se reconstruyen al aplicar config y al activar/expirar un evento (nunca por
## tick: cero asignaciones en el camino caliente).
var _pesos_efectivos_doc: Array[float] = []
var _pesos_efectivos_odac: Array[float] = []

# ── Estado del generador (Story 002 · TR-demand-001/002 · GDD F3/F4, DG1/DG4/DG5) ────────────
## Acumuladores de fracciones de llegada pendientes, por servicio (F4). El residuo se CONSERVA entre
## ticks: no se pierde demanda por redondeo, y el goteo nocturno de ODAC sale espaciado por diseño.
var _acumulador: Dictionary[StringName, float] = {SERVICIO_DOC: 0.0, SERVICIO_ODAC: 0.0}
## Guarda anti-spam del aviso "no drena" por servicio (se emite al cruzar el umbral, no cada tick).
var _aviso_acumulador: Dictionary[StringName, bool] = {SERVICIO_DOC: false, SERVICIO_ODAC: false}
## Cachés de la mezcla F3 como arrays PARALELOS (ids + pesos) en el ORDEN DE INSERCIÓN del config
## (estable → determinista): `RNGService.elegir_ponderado` trabaja por índice. Los reconstruye
## `aplicar_config`; la story 005 aplicará aquí los `mult_peso` de los eventos.
var _mezcla_ids_doc: Array[StringName] = []
var _mezcla_pesos_doc: Array[float] = []
var _mezcla_ids_odac: Array[StringName] = []
var _mezcla_pesos_odac: Array[float] = []


func _ready() -> void:
	if _bus == null:
		_bus = get_node_or_null("/root/EventBus")
	if _tiempo == null:
		_tiempo = get_node_or_null("/root/Tiempo")
	_suscribir_al_tick()
	_cargar_config()
	# En runtime real, la población sale del catálogo. Los tests (sin árbol → sin _ready) inyectan.
	if _poblacion == 0:
		fijar_escenario(ESCENARIO_DEFAULT)
	# El mult estacional se deriva del mes TAMBIÉN en el arranque (DG13 es un calendario, no un evento:
	# empezar en enero ES temporada baja). Misma derivación que hace load_state — coherencia save/arranque.
	if _tiempo != null:
		_fijar_mult_estacional(_tiempo.mes)
	_recalcular_nivel()
	# Reset diario por el DISPATCHER (orden crítico ADR-0001, `nuevo_dia`: Paciencia 10 → Economía 20 →
	# Personal 30 → **Demanda 40**). Solo en runtime real (árbol); los tests llaman el método directo.
	if _bus != null and _bus.has_method("registrar_ordenado"):
		_bus.registrar_ordenado(&"nuevo_dia", 40, _al_nuevo_dia)
		# Perfil estacional al `nuevo_mes` (orden ADR-0001: Economía 10 → Paciencia 20 → Demanda 30).
		_bus.registrar_ordenado(&"nuevo_mes", 30, _al_nuevo_mes)
	# Contrato de persistencia (ADR-0002): el SaveManager recoge por el grupo, clave = node.name.
	add_to_group("Persist")


# ── Cableado (Story 003 — inyección testeable, patrón Economía) ──────────────────────────────

## Inyecta el EventBus (dependency injection → testeable sin el autoload real). Demanda solo emite.
func usar_bus(bus: Node) -> void:
	_bus = bus


## Inyecta el reloj y se suscribe a su hook del tick (idempotente: `suscribir_tick` ignora duplicados).
func usar_tiempo(tiempo: Node) -> void:
	_tiempo = tiempo
	_suscribir_al_tick()


## Suscripción al tick de simulación que EMPUJA Tiempo (ADR-0001). Nota de orden: cuando existan
## Flujo/Paciencia deben suscribirse DESPUÉS de Demanda (orden fijo Tiempo→Demanda→Flujo→Paciencia);
## hoy Demanda es el único sistema de simulación suscrito.
func _suscribir_al_tick() -> void:
	if _tiempo != null and _tiempo.has_method("suscribir_tick"):
		_tiempo.suscribir_tick(_al_tick)


## El tick de simulación (recibe `delta_juego` en MINUTOS de juego; en Pausa Tiempo no empuja → DG9).
## Detecta el cruce del cierre de Doc (reset del acumulador, DG6), genera con F4 y ENTREGA cada ficha
## al bus (`persona_generada`, DG1). El grifo NO se autolimita por colas/capacidad (DG10): esa válvula
## será Paciencia. La hora se evalúa AL FINAL del avance (regla de cruces del GDD).
func _al_tick(delta_juego_min: float) -> void:
	if _tiempo == null:
		return
	var min_dia: float = fposmod(_tiempo.minutos_juego, MINUTOS_POR_DIA)
	_detectar_cierre_doc(min_dia)
	for ficha: RefCounted in procesar_avance(delta_juego_min, min_dia):
		llegadas_hoy += 1
		if _bus != null:
			_bus.persona_generada.emit(ficha)


## Cruce del cierre de Documentación (14:30 base): el acumulador Doc fraccional se REINICIA — la
## demanda del día no se arrastra al siguiente (edge del GDD: la gente que no vino hoy no "se guarda").
## En el wrap de medianoche (min_dia cae) no hay falso cruce: la guarda queda por encima del cierre.
func _detectar_cierre_doc(min_dia: float) -> void:
	var fin: float = float(ventana_doc_fin_min)
	if _min_dia_anterior < fin and min_dia >= fin:
		_acumulador[SERVICIO_DOC] = 0.0
	_min_dia_anterior = min_dia


## Handler del evento ordenado `nuevo_dia` (prioridad 40, el ÚLTIMO tras Paciencia/Economía/Personal):
## resetea el contador diario del HUD y reevalúa el nivel de demanda (DG12). (La story 005 descontará
## aquí la duración de los eventos estacionales.)
func _al_nuevo_dia() -> void:
	llegadas_hoy = 0
	# Decremento del evento de demanda activo (DG11, story 005): expira al agotar sus jornadas.
	if _evento_activo != &"":
		_evento_jornadas_restantes -= 1
		if _evento_jornadas_restantes <= 0:
			_desactivar_evento()
	_recalcular_nivel()


# ── DG12 · Nivel de demanda BAJA/MEDIA/ALTA (Story 004) ──────────────────────────────────────

## Clasifica un volumen diario de Documentación en su tramo (función PURA; umbrales del config,
## Open Q9). Regla de bordes fijada: `< bajo` → BAJA · `≥ alto` → ALTA · resto → MEDIA.
func clasificar_nivel(volumen_dia: float) -> StringName:
	if volumen_dia < umbral_nivel_bajo:
		return NIVEL_BAJA
	if volumen_dia >= umbral_nivel_alto:
		return NIVEL_ALTA
	return NIVEL_MEDIA


## El tramo vigente (lectura pull para UI/tests, sin efectos laterales). Si aún no se recalculó
## nunca, deriva del volumen actual sin fijar estado ni emitir.
func nivel_demanda() -> StringName:
	if _nivel == &"":
		return clasificar_nivel(demanda_dia(SERVICIO_DOC))
	return _nivel


## Reevalúa el tramo a partir del volumen diario EFECTIVO de Documentación y emite
## `nivel_demanda_cambiado` por el bus SOLO si cambió (guarda anti-duplicado). Lo llaman el arranque,
## el `nuevo_dia` (prio 40) y —desde la story 005— el cambio estacional del `nuevo_mes`.
func _recalcular_nivel() -> void:
	var nuevo: StringName = clasificar_nivel(demanda_dia(SERVICIO_DOC))
	if nuevo == _nivel:
		return
	_nivel = nuevo
	if _bus != null:
		_bus.nivel_demanda_cambiado.emit(_nivel)


# ── Población (F1 — la posee el Escenario del catálogo) ──────────────────────────────────────

## Fija la población leyendo el `Escenario` del catálogo por id (runtime real y futuros niveles).
## Si el id no existe, avisa y deja la población como estaba (el grifo no revienta).
func fijar_escenario(escenario_id: StringName) -> void:
	var escenario: Resource = Datos.obtener(&"Escenario", escenario_id)
	if escenario == null:
		push_warning("Demanda: escenario '%s' no existe en el catalogo -> poblacion sin cambios" % escenario_id)
		return
	_escenario_id = escenario_id
	_poblacion = escenario.poblacion


## Inyección directa de población para tests y herramientas (sin catálogo). ≥ 0 (clamp con aviso).
func fijar_poblacion(poblacion: int) -> void:
	if poblacion < 0:
		push_warning("Demanda: poblacion negativa (%d) -> 0" % poblacion)
		poblacion = 0
	_poblacion = poblacion


## Población del escenario activo (read-only para UI/tests).
func poblacion() -> int:
	return _poblacion


# ── F1 · Volumen diario por servicio ─────────────────────────────────────────────────────────

## Tasa efectiva del servicio (llegadas por 1.000 hab/día): base × crecimiento por nivel (DG8)
## × multiplicador estacional del mes (DG13 — SOLO Documentación; verano/Navidad suben, invierno baja).
func tasa_efectiva(servicio: StringName) -> float:
	var base: float = tasa_base_doc if servicio == SERVICIO_DOC else tasa_base_odac
	var estacional: float = _mult_estacional_vigente if servicio == SERVICIO_DOC else 1.0
	return base * factor_crecimiento_nivel * estacional


## F1: llegadas totales esperadas del servicio en un día = `poblacion × tasa_efectiva / 1000`.
## Con población 0 o tasa 0 devuelve 0 (grifo cerrado = config válida, AC-DM19).
func demanda_dia(servicio: StringName) -> float:
	return float(_poblacion) * tasa_efectiva(servicio) / 1000.0


# ── F2 · Perfil intradía (llegadas esperadas y densidad por minuto) ──────────────────────────

## F2: llegadas esperadas del servicio en la FRANJA horaria que contiene `min_dia` (minutos del día,
## [0, 1440)): `demanda_dia × peso_franja × mult_dia_semana`. Documentación fuera de su ventana
## [inicio, fin) devuelve 0 (DG6: la gente conoce el horario — no hay demanda "fantasma").
func llegadas_esperadas_hora(min_dia: float, servicio: StringName) -> float:
	min_dia = fposmod(min_dia, MINUTOS_POR_DIA)
	if servicio == SERVICIO_DOC and not _en_ventana_doc(min_dia):
		return 0.0
	var hora: int = int(min_dia) / MINUTOS_POR_HORA
	return demanda_dia(servicio) * _peso_franja(servicio, hora) * mult_dia_semana


## Densidad de llegadas POR MINUTO de juego en `min_dia` — lo que consumirá el acumulador (story 002):
## `llegadas_esperadas_hora / duracion_franja_min`. La franja 14 de Documentación dura 30 min (hasta el
## cierre 14:30), no 60: sin este ajuste se perdería la mitad de su demanda.
func densidad_por_minuto(min_dia: float, servicio: StringName) -> float:
	var llegadas: float = llegadas_esperadas_hora(min_dia, servicio)
	if llegadas <= 0.0:
		return 0.0
	var hora: int = int(fposmod(min_dia, MINUTOS_POR_DIA)) / MINUTOS_POR_HORA
	var duracion: float = _duracion_franja_min(servicio, hora)
	if duracion <= 0.0:
		return 0.0
	return llegadas / duracion


## Peso del perfil para la franja `hora` del servicio. A ODAC en el valle 00:00–07:00 se le aplica
## `mult_nocturno_odac` (F2): el valle lo crea el multiplicador, no los pesos base (semilla uniforme).
func _peso_franja(servicio: StringName, hora: int) -> float:
	if servicio == SERVICIO_DOC:
		return perfil_hora_doc.get(hora, 0.0)
	var peso: float = perfil_hora_odac.get(hora, 0.0)
	if hora < HORA_FIN_VALLE_ODAC:
		peso *= mult_nocturno_odac
	return peso


## ¿`min_dia` cae dentro de la ventana de apertura de Documentación [inicio, fin)? (DG6)
func _en_ventana_doc(min_dia: float) -> bool:
	return min_dia >= float(ventana_doc_inicio_min) and min_dia < float(ventana_doc_fin_min)


## Duración REAL en minutos de la franja `hora` para el servicio: Documentación recorta la franja al
## solapamiento con su ventana (la franja 14 → 30 min); ODAC siempre 60.
func _duracion_franja_min(servicio: StringName, hora: int) -> float:
	if servicio != SERVICIO_DOC:
		return float(MINUTOS_POR_HORA)
	var inicio: int = maxi(hora * MINUTOS_POR_HORA, ventana_doc_inicio_min)
	var fin: int = mini((hora + 1) * MINUTOS_POR_HORA, ventana_doc_fin_min)
	return float(maxi(fin - inicio, 0))


# ── F4 · Generador determinista por tick (Story 002 — el corazón del grifo) ──────────────────

## F4: acumula `densidad × delta_min` por servicio y drena el acumulador en fichas `Persona` hasta el
## tope de ráfaga GLOBAL del tick (`max_llegadas_por_tick`, DG5 anti-avalancha); el excedente se
## CONSERVA para los ticks siguientes. `min_dia` = minutos del día AL FINAL del avance (regla de
## cruces del GDD). Orden fijo Doc → ODAC (parte del contrato determinista).
## Determinismo: mismo estado + misma semilla del RNGService + misma secuencia (delta_min, min_dia)
## → exactamente las mismas fichas (AC-DM06). Sin bus aquí: la emisión llega en la story 003.
func procesar_avance(delta_min: float, min_dia: float) -> Array[RefCounted]:
	var fichas: Array[RefCounted] = []
	if delta_min <= 0.0:
		return fichas
	_acumulador[SERVICIO_DOC] += densidad_por_minuto(min_dia, SERVICIO_DOC) * delta_min
	_acumulador[SERVICIO_ODAC] += densidad_por_minuto(min_dia, SERVICIO_ODAC) * delta_min
	_drenar(SERVICIO_DOC, fichas, min_dia)
	_drenar(SERVICIO_ODAC, fichas, min_dia)
	_avisar_si_no_drena(SERVICIO_DOC)
	_avisar_si_no_drena(SERVICIO_ODAC)
	return fichas


## Acumulador pendiente del servicio (read-only: lo consultan tests, el reset de ventana de la
## story 003 y la serialización de la 006).
func acumulador_de(servicio: StringName) -> float:
	return _acumulador.get(servicio, 0.0)


## Drena el acumulador del servicio en fichas mientras haya ≥ 1 llegada entera Y quede hueco en el
## tope de ráfaga global del tick.
func _drenar(servicio: StringName, fichas: Array[RefCounted], min_dia: float) -> void:
	while _acumulador[servicio] >= 1.0 and fichas.size() < max_llegadas_por_tick:
		var tramite: StringName = _elegir_tramite(servicio)
		if tramite == &"":
			return   # mezcla vacía/corrupta (elegir_ponderado ya avisó): no consumir el acumulador
		fichas.append(PersonaScript.new(servicio, tramite, min_dia))
		_acumulador[servicio] -= 1.0


## F3: elige el trámite de la visita con la mezcla ponderada EFECTIVA del servicio (base × evento
## activo, story 005), vía RNGService SEMBRADO (la normalización defensiva de pesos que no suman 1
## la hace `elegir_ponderado` — AC-DM17; por eso los `mult_peso` no exigen renormalizar a mano).
func _elegir_tramite(servicio: StringName) -> StringName:
	var ids: Array[StringName] = _mezcla_ids_doc if servicio == SERVICIO_DOC else _mezcla_ids_odac
	var pesos: Array[float] = _pesos_efectivos_doc if servicio == SERVICIO_DOC else _pesos_efectivos_odac
	var indice: int = RNGService.elegir_ponderado(pesos)
	if indice < 0:
		return &""
	return ids[indice]


## Aviso (una vez por cruce, no cada tick) si el acumulador crece sin drenar nunca — mal tuning:
## tasa sostenida > tope de ráfaga (edge del GDD F4).
func _avisar_si_no_drena(servicio: StringName) -> void:
	var umbral: float = float(max_llegadas_por_tick) * UMBRAL_AVISO_ACUMULADOR
	if _acumulador[servicio] >= umbral:
		if not _aviso_acumulador[servicio]:
			push_warning(
				"Demanda: el acumulador de '%s' (%.1f) no drena (tasa sostenida > tope de rafaga?)"
				% [servicio, _acumulador[servicio]]
			)
			_aviso_acumulador[servicio] = true
	else:
		_aviso_acumulador[servicio] = false


## Reconstruye las cachés de mezcla (arrays paralelos id/peso) desde los Dictionary del config,
## en su orden de inserción (estable → determinista), y los pesos efectivos derivados.
func _reconstruir_mezclas() -> void:
	_mezcla_ids_doc.clear()
	_mezcla_pesos_doc.clear()
	for id_tramite: StringName in mezcla_doc:
		_mezcla_ids_doc.append(id_tramite)
		_mezcla_pesos_doc.append(mezcla_doc[id_tramite])
	_mezcla_ids_odac.clear()
	_mezcla_pesos_odac.clear()
	for id_denuncia: StringName in mezcla_odac:
		_mezcla_ids_odac.append(id_denuncia)
		_mezcla_pesos_odac.append(mezcla_odac[id_denuncia])
	_reconstruir_pesos_efectivos()


# ── DG13/DG11 · Estacionalidad y eventos de demanda (Story 005) ──────────────────────────────

## Handler del evento ordenado `nuevo_mes` (prioridad 30, tras Economía 10 y Paciencia 20): fija el
## multiplicador estacional del mes (DG13), dispara los eventos cuyo `meses_inicio` incluye el mes
## (DG11 — activación DETERMINISTA por calendario, sin azar) y reevalúa el nivel (DG12).
func _al_nuevo_mes() -> void:
	if _tiempo == null:
		return
	_fijar_mult_estacional(_tiempo.mes)
	_activar_eventos_del_mes(_tiempo.mes)
	_recalcular_nivel()


## Fija el multiplicador estacional para `mes` (1-12; meses sin entrada en config → 1.0).
func _fijar_mult_estacional(mes: int) -> void:
	_mult_estacional_vigente = mult_estacional.get(mes, 1.0)


## Multiplicador estacional vigente (read-only para UI/tests).
func mult_estacional_vigente() -> float:
	return _mult_estacional_vigente


## Evento de demanda activo (`&""` si ninguno) y sus jornadas restantes (read-only).
func evento_activo() -> StringName:
	return _evento_activo


func evento_jornadas_restantes() -> int:
	return _evento_jornadas_restantes


## Activa el primer evento del config cuyo `meses_inicio` incluye `mes`. Un solo evento a la vez
## (MVP): si ya hay uno activo, se mantiene y se avisa (simplificación explícita de la story).
func _activar_eventos_del_mes(mes: int) -> void:
	for evento: Dictionary in eventos:
		var meses: Array = evento.get("meses_inicio", [])
		if not (mes in meses):
			continue
		var id_evento: StringName = evento.get("id", &"")
		if _evento_activo != &"":
			push_warning(
				"Demanda: evento '%s' coincide con '%s' ya activo -> se mantiene el activo"
				% [id_evento, _evento_activo]
			)
			continue
		_evento_activo = id_evento
		_evento_jornadas_restantes = maxi(int(evento.get("duracion_jornadas", 1)), 1)
		_reconstruir_pesos_efectivos()


## Expira el evento activo (llamado por el decremento diario) y devuelve la mezcla al perfil regular.
func _desactivar_evento() -> void:
	_evento_activo = &""
	_evento_jornadas_restantes = 0
	_reconstruir_pesos_efectivos()


## Recalcula los pesos efectivos = base × `mult_peso` del evento activo (si lo hay). Un `tramite_id`
## del evento que no exista en la mezcla se ignora con aviso (no rompe la elección — edge de la story).
func _reconstruir_pesos_efectivos() -> void:
	_pesos_efectivos_doc = _mezcla_pesos_doc.duplicate()
	_pesos_efectivos_odac = _mezcla_pesos_odac.duplicate()
	if _evento_activo == &"":
		return
	var evento: Dictionary = _buscar_evento(_evento_activo)
	var mult_peso: Dictionary = evento.get("mult_peso", {})
	for id_tramite: StringName in mult_peso:
		var indice_doc: int = _mezcla_ids_doc.find(id_tramite)
		var indice_odac: int = _mezcla_ids_odac.find(id_tramite)
		if indice_doc >= 0:
			_pesos_efectivos_doc[indice_doc] *= float(mult_peso[id_tramite])
		elif indice_odac >= 0:
			_pesos_efectivos_odac[indice_odac] *= float(mult_peso[id_tramite])
		else:
			push_warning(
				"Demanda: el evento '%s' multiplica '%s', que no esta en ninguna mezcla -> ignorado"
				% [_evento_activo, id_tramite]
			)


## Busca la definición de un evento por id en el config (Dictionary vacío si no existe).
func _buscar_evento(id_evento: StringName) -> Dictionary:
	for evento: Dictionary in eventos:
		if evento.get("id", &"") == id_evento:
			return evento
	return {}


# ── Persistencia (Story 006 · TR-demand-002 · ADR-0002) ──────────────────────────────────────

## Estado serializable de Demanda (contrato `Persist`). SOLO estado mutable no derivable: el RNG lo
## serializa RNGService (su propia entrada del save — NUNCA duplicarlo aquí), el mult estacional se
## re-deriva del mes de Tiempo al cargar, y la config/catálogo/escenario los posee el arranque.
func save() -> Dictionary:
	return {
		"acumulador_doc": _acumulador[SERVICIO_DOC],
		"acumulador_odac": _acumulador[SERVICIO_ODAC],
		"llegadas_hoy": llegadas_hoy,
		"nivel": String(_nivel),
		"evento_activo": String(_evento_activo),
		"evento_jornadas_restantes": _evento_jornadas_restantes,
	}


## Restaura el estado desde un Dictionary (p. ej. parseado de JSON). Defensivo ante claves ausentes
## (saves viejos → defaults sanos). SIN señales ni generación retroactiva ("cargar sitúa, no
## reproduce" — ADR-0002): el nivel se restaura en silencio y la guarda del cierre se sitúa en la
## hora cargada para no detectar un cruce espurio en el primer tick.
func load_state(d: Dictionary) -> void:
	_acumulador[SERVICIO_DOC] = float(d.get("acumulador_doc", 0.0))
	_acumulador[SERVICIO_ODAC] = float(d.get("acumulador_odac", 0.0))
	llegadas_hoy = int(d.get("llegadas_hoy", 0))
	_nivel = StringName(String(d.get("nivel", "")))
	_evento_activo = StringName(String(d.get("evento_activo", "")))
	_evento_jornadas_restantes = int(d.get("evento_jornadas_restantes", 0))
	if _tiempo != null:
		_fijar_mult_estacional(_tiempo.mes)
		_min_dia_anterior = fposmod(_tiempo.minutos_juego, MINUTOS_POR_DIA)
	_reconstruir_pesos_efectivos()


# ── Config (patrón Economía: aplicar con clamp defensivo + carga con fallback) ───────────────

## Copia los knobs del config con clamp defensivo y aviso. Config nulo/de otro tipo → defaults.
## Los Dictionary/Array se DUPLICAN (el Resource del catálogo es plantilla compartida read-only).
func aplicar_config(config: Resource) -> void:
	if config == null or not (config is ConfigDemandaScript):
		push_warning("Demanda: config invalido -> defaults")
		config = ConfigDemandaScript.new()
	tasa_base_doc = _clamp_knob(config.tasa_base_doc, "tasa_base_doc")
	tasa_base_odac = _clamp_knob(config.tasa_base_odac, "tasa_base_odac")
	perfil_hora_doc = config.perfil_hora_doc.duplicate()
	perfil_hora_odac = config.perfil_hora_odac.duplicate()
	mult_nocturno_odac = _clamp_knob(config.mult_nocturno_odac, "mult_nocturno_odac")
	mult_dia_semana = _clamp_knob(config.mult_dia_semana, "mult_dia_semana")
	max_llegadas_por_tick = maxi(config.max_llegadas_por_tick, 1)
	if config.max_llegadas_por_tick < 1:
		push_warning("Demanda: knob 'max_llegadas_por_tick' fuera de rango (%d) -> 1" % config.max_llegadas_por_tick)
	factor_crecimiento_nivel = _clamp_knob(config.factor_crecimiento_nivel, "factor_crecimiento_nivel")
	ventana_doc_inicio_min = config.ventana_doc_inicio_min
	ventana_doc_fin_min = config.ventana_doc_fin_min
	if ventana_doc_fin_min <= ventana_doc_inicio_min:
		push_warning(
			"Demanda: ventana Doc invalida [%d, %d) -> default [480, 870)"
			% [ventana_doc_inicio_min, ventana_doc_fin_min]
		)
		ventana_doc_inicio_min = 480
		ventana_doc_fin_min = 870
	mezcla_doc = config.mezcla_doc.duplicate()
	mezcla_odac = config.mezcla_odac.duplicate()
	umbral_nivel_bajo = _clamp_knob(config.umbral_nivel_bajo, "umbral_nivel_bajo")
	umbral_nivel_alto = _clamp_knob(config.umbral_nivel_alto, "umbral_nivel_alto")
	if umbral_nivel_alto <= umbral_nivel_bajo:
		push_warning(
			"Demanda: umbrales de nivel incoherentes (bajo %f >= alto %f) -> defaults 40/60"
			% [umbral_nivel_bajo, umbral_nivel_alto]
		)
		umbral_nivel_bajo = 40.0
		umbral_nivel_alto = 60.0
	mult_estacional = config.mult_estacional.duplicate()
	eventos = config.eventos.duplicate(true)
	_avisar_si_no_suma_1(perfil_hora_doc, "perfil_hora_doc")
	_avisar_si_no_suma_1(perfil_hora_odac, "perfil_hora_odac")
	_avisar_si_no_suma_1(mezcla_doc, "mezcla_doc")
	_avisar_si_no_suma_1(mezcla_odac, "mezcla_odac")
	_reconstruir_mezclas()


## Carga el `.tres` real con fallback seguro (falta/inválido → defaults con aviso; no peta).
func _cargar_config() -> void:
	var config: Resource = null
	if ResourceLoader.exists(RUTA_CONFIG):
		config = load(RUTA_CONFIG)
	if config == null:
		push_warning("Demanda: no se pudo cargar '%s' -> defaults" % RUTA_CONFIG)
	aplicar_config(config)


## Clampa un knob a ≥ 0 con aviso si venía fuera de rango (patrón Datos/Tiempo/Economía).
func _clamp_knob(valor: float, nombre: String) -> float:
	if valor < 0.0:
		push_warning("Demanda: knob '%s' fuera de rango (%f) -> 0" % [nombre, valor])
		return 0.0
	return valor


## Aviso (sin abortar, patrón Datos) si una distribución no suma ≈ 1.0 — restricción del GDD (§Tuning).
## Para las MEZCLAS es defensivo (elegir_ponderado normaliza igualmente, story 002); para los PERFILES
## un Σ≠1 desplaza el volumen diario real respecto a F1.
func _avisar_si_no_suma_1(distribucion: Dictionary, nombre: String) -> void:
	var suma: float = 0.0
	for peso: float in distribucion.values():
		suma += peso
	if absf(suma - 1.0) > 0.001:
		push_warning("Demanda: la distribucion '%s' suma %f (deberia sumar 1.0)" % [nombre, suma])
