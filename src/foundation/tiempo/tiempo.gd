extends Node
## Tiempo — el reloj base de la simulación (autoload "Tiempo", el 4º).
##
## Mantiene un acumulador `minutos_juego` (float) que representa el minuto del día en curso, en el
## rango [0, 1440). NO cuenta frames: `avanzar(delta_real)` acumula el `delta` REAL que entrega el
## motor → mismo delta acumulado ⇒ mismo resultado a cualquier FPS (determinismo, la base del proyecto).
##
## `avanzar()` recibe el `delta` por parámetro (inyección) — NO lee la hora del sistema ni se engancha a
## `_physics_process` todavía (eso es H7). El módulo 1440 solo ENVUELVE el valor al cruzar medianoche; NO
## emite eventos de cruce (`nuevo_dia`, `cambio_de_turno`, …) — eso es H4/H5.
##
## Config data-driven (Story 002): la escala, los límites de turno y el techo de delta se LEEN de un
## `ConfigTiempo` (`res://datos/config/tiempo.tres`) — nunca están incrustados en el código. La escala
## SIEMPRE pasa por clamp [3, 12] con aviso si llega fuera. Si el `.tres` falta o es inválido → defaults
## seguros con aviso (no peta). Los tests inyectan un `ConfigTiempo` en memoria vía `aplicar_config()`.
##
## Derivaciones (Story 003): turno y `es_de_noche` son datos DERIVADOS de la hora con funciones puras —
## NUNCA se almacenan como estado paralelo (fuente única, TR-time-006/007). El enum `Turno` es coherente
## con `EventBus.cambio_de_turno(turno: int)` (0=mañana, 1=tarde, 2=noche).
##
## Story: production/epics/tiempo/story-001-reloj-base.md · story-002-escala-configurable.md ·
##        story-003-conversiones-turnos.md · TR-time-001/005/006/007 · ADR-0001 / ADR-0002

## Turno del día. El valor entero es el que viaja en `EventBus.cambio_de_turno(turno: int)` (coherencia con
## el bus, H4): 0=mañana, 1=tarde, 2=noche.
enum Turno { MANANA = 0, TARDE = 1, NOCHE = 2 }

## Minutos en un día (24 h × 60 min). El acumulador envuelve al alcanzarlo. NO es un tuning knob de gameplay
## (es la definición de "día de 24 h") → constante del código, no del config.
const MINUTOS_POR_DIA: float = 1440.0

## Minutos por hora — para las conversiones hora↔minutos (Story 003). Constante del código (aritmética base).
const MINUTOS_POR_HORA: int = 60

## Rango seguro de la escala del tiempo (GDD Edge Case): nunca ≤0 (reloj congelado/hacia atrás) ni >12.
## El clamp protege el motor de un dato corrupto/mod. NO es tuning knob: es el guardarraíl del propio knob.
const ESCALA_MIN: float = 3.0
const ESCALA_MAX: float = 12.0

## Ruta del `.tres` de config del desarrollador (generado por `tools/build_config_tiempo.gd`, no a mano).
const RUTA_CONFIG := "res://datos/config/tiempo.tres"

const ConfigTiempoScript := preload("res://src/foundation/tiempo/config_tiempo.gd")

## Minutos del día en curso, en [0, 1440). Es `float` para acumular sin errores de truncado antes de
## convertir a HH:MM (GDD F2). El módulo 1440 lo envuelve al pasar de medianoche.
var minutos_juego: float = 0.0

## Minutos de juego por segundo real a velocidad 1×. Se LEE del config (Story 002) y SIEMPRE queda dentro
## de [3, 12] tras el clamp. Default 4.0 antes de aplicar config (fallback seguro).
var escala_tiempo: float = 4.0

## Multiplicador de la máquina de velocidad (Pausa=0 / 1× / 2× / 3×). Var simple con default 1×; la lógica
## de la máquina de velocidad es H6.
var multiplicador_velocidad: int = 1

## Techo del `delta` real aceptado por frame, en segundos (clamp anti-salto TR-time-005). Se LEE del config.
var delta_max_por_frame: float = 0.5

## Inicio de cada turno en minutos del día [0, 1440). Se LEEN del config (Story 002/003) — nunca constantes.
## Defaults del GDD F3: mañana 07:00, tarde 15:00, noche 23:00.
var inicio_manana: int = 420
var inicio_tarde: int = 900
var inicio_noche: int = 1380

## Jornadas por mes de calendario. Se LEE del config; su uso es H5. Default 4 (GDD Core Rules 7).
var jornadas_por_mes: int = 4


func _ready() -> void:
	_cargar_config()


## Avanza el reloj acumulando el `delta` REAL entregado por el motor (función pura y determinista).
##
## El `delta` se CLAMPA a `delta_max_por_frame` ANTES de acumular (anti-salto, TR-time-005), luego se
## escala por `escala_tiempo * multiplicador_velocidad` y se suma a `minutos_juego`. Al cruzar 1440 el
## valor ENVUELVE por módulo (medianoche → 00:00 del día siguiente); esta story NO emite eventos de cruce.
##
## En Pausa (`multiplicador_velocidad == 0`) el incremento es 0 → el reloj no cambia (AC-T04).
## TR-time-001: acumula `delta` real, no frames → mismo resultado a cualquier FPS.
func avanzar(delta_real: float) -> void:
	var delta_clampado: float = min(delta_real, delta_max_por_frame)
	minutos_juego += escala_tiempo * multiplicador_velocidad * delta_clampado
	minutos_juego = fposmod(minutos_juego, MINUTOS_POR_DIA)


## Aplica un `ConfigTiempo` al reloj (inyección de dependencia → testeable sin tocar disco).
##
## Copia los tuning knobs del config a las vars del reloj. La escala SIEMPRE pasa por clamp [3, 12]: si el
## valor original está fuera de rango, se registra un aviso (AC-T28/T29 — GDD Edge Case). El resto de campos
## se copian tal cual (los límites de turno se validan por el propio esquema/generador). Si `config` es null
## → defaults seguros con aviso.
##
## `config` se tipa como `Resource` (no `ConfigTiempo`) a propósito: en el parse EN FRÍO de headless el
## `class_name` global aún no está registrado y romper aquí impediría cargar el autoload. Se valida en runtime
## con `is ConfigTiempoScript` (constante preload) — mismo gotcha del `class_name` en frío del proyecto.
func aplicar_config(config: Resource) -> void:
	if config == null:
		push_warning("Tiempo.aplicar_config: config null → se mantienen los defaults seguros (escala 4.0, límites 420/900/1380).")
		return
	if not (config is ConfigTiempoScript):
		push_warning("Tiempo.aplicar_config: el recurso no es un ConfigTiempo → se mantienen los defaults seguros.")
		return

	var escala_pedida: float = config.escala_tiempo
	escala_tiempo = clampf(escala_pedida, ESCALA_MIN, ESCALA_MAX)
	if not is_equal_approx(escala_pedida, escala_tiempo):
		push_warning("Tiempo: escala_tiempo=%s fuera de [%s, %s] → clampada a %s." % [
			escala_pedida, ESCALA_MIN, ESCALA_MAX, escala_tiempo,
		])

	inicio_manana = config.inicio_manana
	inicio_tarde = config.inicio_tarde
	inicio_noche = config.inicio_noche
	jornadas_por_mes = config.jornadas_por_mes
	delta_max_por_frame = config.delta_max_por_frame


# ── Conversiones hora↔minutos (Story 003 — funciones puras, sin estado) ──────────────────────

## Convierte un minuto del día [0, 1440) a texto "HH:MM" (AC-T06: 567 → "09:27"; AC-T08: 0 → "00:00").
##
## Nunca produce "24:00": trabaja con `int(min_dia)` envuelto por `fposmod` a [0, 1440), de modo que la hora
## derivada está en [0, 23]. `min_dia` puede ser `float` (el acumulador lo es); se usa el minuto entero (piso)
## para la hora mostrada (GDD F2/F3).
func hhmm(min_dia: float) -> String:
	var m: int = int(fposmod(floorf(min_dia), MINUTOS_POR_DIA))
	return "%02d:%02d" % [m / MINUTOS_POR_HORA, m % MINUTOS_POR_HORA]


## Convierte (hora, minuto) a minutos del día (AC-T07: 14:30 → 870). `hora * 60 + minuto` (GDD F3).
func a_minutos(hora: int, minuto: int) -> int:
	return hora * MINUTOS_POR_HORA + minuto


# ── Turno y ciclo día/noche (Story 003 — DERIVADOS, nunca almacenados) ───────────────────────

## Calcula el turno para un minuto del día, leyendo los límites del config (data-driven, NO constantes).
##
## MAÑANA si [inicio_manana, inicio_tarde); TARDE si [inicio_tarde, inicio_noche); NOCHE en cualquier otro
## caso (el restante [inicio_noche, 1440) ∪ [0, inicio_manana), porque NOCHE cruza medianoche). El `min_dia`
## se envuelve a [0, 1440) por robustez. (AC-T09..T12: 420→MAÑANA, 900→TARDE, 1395→NOCHE, 200→NOCHE.)
func turno_de(min_dia: float) -> int:
	var m: int = int(fposmod(floorf(min_dia), MINUTOS_POR_DIA))
	if m >= inicio_manana and m < inicio_tarde:
		return Turno.MANANA
	elif m >= inicio_tarde and m < inicio_noche:
		return Turno.TARDE
	else:
		return Turno.NOCHE


## `true` si el minuto del día cae en el turno de NOCHE (MVP: noche = turno Noche, GDD Core Rules 5).
##
## DERIVADO del turno → fuente única, sin estado paralelo (TR-time-006/007). (AC-T13..T15: 1381→true,
## 419→true, 420→false.)
func es_de_noche(min_dia: float) -> bool:
	return turno_de(min_dia) == Turno.NOCHE


# ── Carga del config (privado) ───────────────────────────────────────────────────────────────

## Carga `res://datos/config/tiempo.tres` con `load()` y lo aplica. Fallback SEGURO: si falta el recurso o no
## es un `ConfigTiempo` válido → mantiene los defaults y registra un aviso (no peta). ADR-0002: `load()` de un
## `.tres` del desarrollador es seguro (a diferencia del save del jugador).
func _cargar_config() -> void:
	if not ResourceLoader.exists(RUTA_CONFIG):
		push_warning("Tiempo: no existe '%s' → defaults seguros (escala 4.0, límites 420/900/1380)." % RUTA_CONFIG)
		return
	var recurso: Resource = load(RUTA_CONFIG)
	if recurso == null or not (recurso is ConfigTiempoScript):
		push_warning("Tiempo: '%s' no es un ConfigTiempo válido → defaults seguros." % RUTA_CONFIG)
		return
	aplicar_config(recurso)
