class_name Documentacion extends Node
## Documentación (#8) — el servicio de DNI / Pasaporte / TIE: la **ventanilla que da de comer** a la
## comisaría (única fuente de ingresos del MVP) y, sobre todo, **el dueño de su horario**.
##
## Documentación no inventa el flujo ni la gente (eso son Flujo #4 y Demanda #5): posee la **operativa**
## — a qué hora abre, a qué hora cierra (slider del jugador), hasta qué minuto se da número (última
## admisión) y qué política de cita rige. Es un **Feature configurador**: fija los horarios que **Flujo
## ejecuta** al abrir/cerrar los puestos y la ventana que **Demanda respeta** al generar llegadas.
##
## Story 001 (esta): el objeto, su config del catálogo y las fórmulas puras (F3 última admisión, la
## parte pura de F1 horas extra, y el estado del servicio). **Todo función pura**: recibe la hora, no
## la busca — así se testea sin reloj y sin árbol. El cableado real a Flujo/Demanda es la story 002.
##
## Reparto de propiedad (arquitectura): Documentación **ordena por API pública** (ADR-0001), nunca muta
## el estado interno de Flujo ni de Demanda; los valores salen del catálogo (ADR-0003), jamás del código.
##
## Stories: documentacion 001 (núcleo+config+F3) · TR-doc-001 · ADR-0001 / ADR-0003

const RUTA_CONFIG := "res://datos/config/documentacion.tres"
const ConfigDocumentacionScript := preload("res://src/feature/documentacion/config_documentacion.gd")

## El servicio que gobierna (misma clave que Flujo, Demanda y el catálogo).
const SERVICIO := &"Documentacion"
## Tipo del catálogo con los trámites que presta (DNI, Pasaporte, TIE).
const TIPO_TRAMITE := &"TramiteDoc"

const MINUTOS_POR_HORA := 60.0
const MINUTOS_POR_DIA := 1440.0

## Estados del servicio (DO3 · §States and Transitions). Texto + color en la UI, nunca solo color.
## CERRADO   — fuera de horario: ni se da número ni se atiende.
## ABIERTO   — en horario y **dando número**.
## CERRANDO  — ya NO se da número (pasó la última admisión); se termina a los admitidos.
const ESTADO_CERRADO := &"cerrado"
const ESTADO_ABIERTO := &"abierto"
const ESTADO_CERRANDO := &"cerrando"

## Política de cita del MVP (DO8): el juego arranca **sin cita**. La cita previa como regulador de la
## demanda es el sistema #14 (Vertical Slice); el flag `requiere_cita` del catálogo existe para él.
const CITA_ACTIVA := false

## El horario ha cambiado: quien lo EJECUTA (Flujo) y quien lo RESPETA (Demanda) deben enterarse.
## Los tres valores son minutos del día. La conexión la hace Main en la story 002.
signal horario_cambiado(apertura_min: int, cierre_min: int, ultima_admision_min: int)

# ── Tuning (del `.tres`; ver ConfigDocumentacion — lo fija la División, DO2) ──────────────────
var apertura_base_min: int = 480
var cierre_base_min: int = 870
var slider_min_min: int = 480
var slider_max_min: int = 1200
var margen_ultima_admision_min: int = 15
var peonada_activa_por_defecto: bool = false

# ── Estado del servicio (lo que decide el JUGADOR dentro del marco de la División) ────────────
## Hora de cierre elegida con el slider. Arranca en el cierre base (jornada de mañana, sin peonada);
## `peonada_activa_por_defecto` la sube al tope ordinario al aplicar la config.
var hora_cierre_min: int = 870
## Tope EXTRA autorizado por un evento de la División (DO7), en minutos del día. 0 = sin evento
## (manda `slider_max_min`). Lo activa la story 004; aquí solo se respeta si alguien lo pone.
var tope_evento_min: int = 0


func _ready() -> void:
	_cargar_config()


# ── Config (ADR-0003: los valores SOLO del catálogo, con clamps y aviso) ─────────────────────

## Aplica un `ConfigDocumentacion` clampando cada knob a su rango seguro. Un `.tres` corrupto o
## contradictorio AVISA y se corrige, nunca deja el servicio en un estado imposible (patrón del
## proyecto). Restricciones del GDD: `slider_min ≤ apertura_base` · `cierre_base ≤ slider_max` ·
## `margen ∈ [0, 30]` · el cierre siempre DESPUÉS de la apertura.
func aplicar_config(config: Resource) -> void:
	if config == null or not (config is ConfigDocumentacionScript):
		push_warning("Documentacion: config invalido -> defaults")
		config = ConfigDocumentacionScript.new()
	apertura_base_min = _clamp_knob(config.apertura_base_min, 0, 1439, "apertura_base_min")
	# El cierre base SIEMPRE después de la apertura: una jornada de 0 minutos no es un horario.
	cierre_base_min = _clamp_knob(
		config.cierre_base_min, apertura_base_min + 1, 1439, "cierre_base_min"
	)
	slider_min_min = _clamp_knob(config.slider_min_min, 0, apertura_base_min, "slider_min_min")
	slider_max_min = _clamp_knob(config.slider_max_min, cierre_base_min, 1439, "slider_max_min")
	margen_ultima_admision_min = _clamp_knob(
		config.margen_ultima_admision_min, 0, 30, "margen_ultima_admision_min"
	)
	peonada_activa_por_defecto = config.peonada_activa_por_defecto
	# El horario de partida: base, o ya ampliado al tope si el jugador lo dejó activado por defecto.
	hora_cierre_min = slider_max_min if peonada_activa_por_defecto else cierre_base_min
	horario_cambiado.emit(apertura_base_min, hora_cierre_min, hora_ultima_admision())


## Carga el `.tres` real con fallback seguro (falta/inválido → defaults con aviso; no peta).
func _cargar_config() -> void:
	var config: Resource = null
	if ResourceLoader.exists(RUTA_CONFIG):
		config = load(RUTA_CONFIG)
	if config == null:
		push_warning("Documentacion: no se pudo cargar '%s' -> defaults" % RUTA_CONFIG)
	aplicar_config(config)


## Clampa un knob entero avisando SOLO si el valor venía fuera de rango (un `.tres` sano no ensucia
## la consola; uno roto se delata con el nombre del knob).
func _clamp_knob(valor: int, minimo: int, maximo: int, nombre: String) -> int:
	var limitado: int = clampi(valor, minimo, maximo)
	if limitado != valor:
		push_warning(
			"Documentacion: '%s' fuera de rango (%d) -> %d [%d, %d]"
			% [nombre, valor, limitado, minimo, maximo]
		)
	return limitado


# ── El horario: lo que decide el jugador (DO3, DO5) ──────────────────────────────────────────

## Hora máxima a la que se puede cerrar HOY (minutos del día): el tope ordinario de la División
## (`slider_max_min`, 20:00) o el del evento activo si autoriza más (DO7 — vacaciones hasta 21:30).
## Nunca por debajo del tope ordinario: un evento amplía, no recorta.
func tope_autorizado() -> int:
	return maxi(slider_max_min, tope_evento_min)


## Orden del jugador: "cierra a esta hora". Clampa al rango autorizado
## `[cierre_base_min, tope_autorizado()]` **con aviso** y devuelve la hora que ha quedado.
## Cerrar antes del cierre base no está autorizado por la División (la jornada de mañana es fija);
## pasarse del tope tampoco (AC-DC10). Emite `horario_cambiado` solo si el horario cambia de verdad.
func fijar_hora_cierre(minuto_del_dia: int) -> int:
	var nuevo: int = _clamp_knob(
		minuto_del_dia, cierre_base_min, tope_autorizado(), "hora_cierre_min"
	)
	if nuevo == hora_cierre_min:
		return hora_cierre_min
	hora_cierre_min = nuevo
	horario_cambiado.emit(apertura_base_min, hora_cierre_min, hora_ultima_admision())
	return hora_cierre_min


## Orden del jugador: "deja de dar número N minutos antes de cerrar" (la palanca exprimir vs cuidar).
## Clampa a [0, 30] con aviso y devuelve el margen aplicado.
func fijar_margen_ultima_admision(minutos: int) -> int:
	var nuevo: int = _clamp_knob(minutos, 0, 30, "margen_ultima_admision_min")
	if nuevo == margen_ultima_admision_min:
		return margen_ultima_admision_min
	margen_ultima_admision_min = nuevo
	horario_cambiado.emit(apertura_base_min, hora_cierre_min, hora_ultima_admision())
	return margen_ultima_admision_min


## **F3** · `hora_ultima_admision = hora_cierre − margen_ultima_admision_min` (minutos del día).
## Cierre 14:30 con margen 15 → 14:15: quien coge número a las 14:15 se atiende; después, puerta
## cerrada. Nunca antes de la apertura (un margen absurdo no puede cerrar la puerta antes de abrirla).
func hora_ultima_admision() -> int:
	return maxi(apertura_base_min, hora_cierre_min - margen_ultima_admision_min)


## **F1 (parte pura)** · Horas que se alargan más allá de la jornada base — las que cuestan peonada.
## `max(0, hora_cierre − cierre_base) / 60`. Cerrar a las 18:00 → 3,5 h. El COSTE en euros y su cobro
## son la story 003 (Documentación no mueve dinero: se lo registra a Economía).
func horas_extra() -> float:
	return maxf(0.0, float(hora_cierre_min - cierre_base_min)) / MINUTOS_POR_HORA


## ¿Hay peonada hoy? (el horario está ampliado por encima de la jornada base).
func hay_horas_extra() -> bool:
	return hora_cierre_min > cierre_base_min


## Estado del servicio a esa hora del día (DO3 · §States and Transitions). Función **pura**: recibe la
## hora (minutos del día, admite el acumulado del reloj → se normaliza), no la busca. Con margen 0 no
## existe la franja CERRANDO (se admite hasta el cierre) — es exactamente lo que significa "exprimir".
func estado_servicio(minuto_del_dia: float) -> StringName:
	var min_dia: float = fposmod(minuto_del_dia, MINUTOS_POR_DIA)
	if min_dia < float(apertura_base_min) or min_dia >= float(hora_cierre_min):
		return ESTADO_CERRADO
	if min_dia >= float(hora_ultima_admision()):
		return ESTADO_CERRANDO
	return ESTADO_ABIERTO


## ¿Se da número a esa hora? (ABIERTO sí; CERRANDO y CERRADO no). Es lo que Flujo consultará en la
## story 002 para su puerta de admisiones.
func admite_a_esa_hora(minuto_del_dia: float) -> bool:
	return estado_servicio(minuto_del_dia) == ESTADO_ABIERTO


# ── Los trámites y la política de cita (DO1, DO8) ────────────────────────────────────────────

## Los trámites que presta el servicio, **leídos del catálogo** (DNI, Pasaporte, TIE): Documentación
## no los inventa ni los muta — posee su operativa, no su definición (ADR-0003).
func tramites() -> Array:
	return Datos.obtener_todos(TIPO_TRAMITE)


## Definición de un trámite por id (`null` + aviso si no existe, sin romper la simulación).
func tramite(tramite_id: StringName) -> Resource:
	return Datos.obtener(TIPO_TRAMITE, tramite_id)


## ¿Exige cita este trámite? (DO8) En el MVP **siempre false**: la cita previa es el sistema #14. Si el
## catálogo trae `requiere_cita = true` se **degrada a "sin cita" con aviso** — el flag existe para #14,
## pero mientras no esté implementado nadie puede quedarse sin ser atendido por culpa de una cita que
## el juego no sabe dar.
func requiere_cita(tramite_id: StringName) -> bool:
	if CITA_ACTIVA:
		var definicion: Resource = tramite(tramite_id)
		return definicion != null and definicion.requiere_cita
	var pedida: Resource = tramite(tramite_id)
	if pedida != null and pedida.requiere_cita:
		push_warning(
			"Documentacion: el tramite '%s' pide cita, pero el MVP va SIN cita (#14) -> sin cita"
			% tramite_id
		)
	return false
