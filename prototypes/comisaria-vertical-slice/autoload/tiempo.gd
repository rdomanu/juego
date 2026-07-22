# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: ¿es divertido y construible el bucle core de la Oficina de Denuncias?
# Date: 2026-07-22
extends Node
## Tiempo — la fuente ÚNICA del reloj de juego (ADR-0001).
## Corre en _physics_process (paso fijo, 60 Hz → determinismo). Nadie más lleva reloj.
## Detecta eventos por CRUCE / cambio de estado (no por ==) y avisa vía EventBus.

enum Turno { MANANA, TARDE, NOCHE }

const MINUTOS_POR_DIA: int = 1440
const ESCALA_TIEMPO: float = 4.0          # min de juego por segundo real a 1× (GDD Tiempo #1; rango 3–12)
const MAX_DELTA_REAL: float = 1.0 / 20.0  # clamp anti-salto (alt-tab / lag)

# Umbrales de turno CNP (min del día): Mañana [07-15) · Tarde [15-23) · Noche [23-07)
const TURNO_MANANA_INICIO: int = 7 * 60
const TURNO_TARDE_INICIO: int = 15 * 60
const TURNO_NOCHE_INICIO: int = 23 * 60
# Ciclo visual día/noche (altera afluencia): noche entre 21:00 y 07:00
const NOCHE_VISUAL_INICIO: int = 21 * 60
const DIA_VISUAL_INICIO: int = 7 * 60

var delta_juego: float = 0.0   # min de juego avanzados en el último physics-tick (0 si Pausa)

var _minuto_del_dia: float = float(8 * 60)   # arranca a las 08:00 (apertura Documentación)
var _dia: int = 1
var _velocidad: int = 1                       # partida nueva arranca a 1×
var _turno_actual: int = Turno.MANANA
var _es_de_noche: bool = false

func _ready() -> void:
	_turno_actual = _calcular_turno(int(_minuto_del_dia))
	_es_de_noche = _calcular_es_de_noche(int(_minuto_del_dia))

func _physics_process(delta: float) -> void:
	if _velocidad <= 0:
		delta_juego = 0.0
		return
	var d: float = minf(delta, MAX_DELTA_REAL)
	delta_juego = d * ESCALA_TIEMPO * float(_velocidad)
	_avanzar(delta_juego)

func _avanzar(min_juego: float) -> void:
	_minuto_del_dia += min_juego
	# Cruce de medianoche (while defensivo por si hubo un salto de varios días)
	while _minuto_del_dia >= float(MINUTOS_POR_DIA):
		_minuto_del_dia -= float(MINUTOS_POR_DIA)
		_dia += 1
		EventBus.nuevo_dia.emit()
	# Cambio de turno (por cambio de estado, no por ==)
	var turno_nuevo: int = _calcular_turno(int(_minuto_del_dia))
	if turno_nuevo != _turno_actual:
		_turno_actual = turno_nuevo
		EventBus.cambio_de_turno.emit(turno_nuevo)
	# Cambio día/noche
	var noche_nueva: bool = _calcular_es_de_noche(int(_minuto_del_dia))
	if noche_nueva != _es_de_noche:
		_es_de_noche = noche_nueva
		EventBus.cambio_dia_noche.emit(noche_nueva)

func _calcular_turno(minuto: int) -> int:
	if minuto >= TURNO_MANANA_INICIO and minuto < TURNO_TARDE_INICIO:
		return Turno.MANANA
	elif minuto >= TURNO_TARDE_INICIO and minuto < TURNO_NOCHE_INICIO:
		return Turno.TARDE
	else:
		return Turno.NOCHE

func _calcular_es_de_noche(minuto: int) -> bool:
	return minuto >= NOCHE_VISUAL_INICIO or minuto < DIA_VISUAL_INICIO

# --- API pública (lectura) ---
func minutos_del_dia() -> int:
	return int(_minuto_del_dia)

func hora_texto() -> String:
	var m: int = int(_minuto_del_dia)
	return "%02d:%02d" % [m / 60, m % 60]

func turno() -> int:
	return _turno_actual

func turno_texto() -> String:
	match _turno_actual:
		Turno.MANANA: return "Mañana"
		Turno.TARDE: return "Tarde"
		_: return "Noche"

func es_de_noche() -> bool:
	return _es_de_noche

func dia() -> int:
	return _dia

func esta_en_pausa() -> bool:
	return _velocidad <= 0

func get_velocidad() -> int:
	return _velocidad

# --- API pública (comandos, desde la UI) ---
func set_velocidad(v: int) -> void:
	_velocidad = clampi(v, 0, 3)
