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

## Estados de la máquina de velocidad que controla el jugador (Story 006 — GDD Core Rules 2, TR-time-002).
## Es la ÚNICA máquina de estados que maneja el jugador y un SELECTOR DIRECTO (cualquier estado →
## cualquier otro, no una rueda secuencial). El valor entero de cada estado COINCIDE con su multiplicador
## (PAUSA=0, X1=1, X2=2, X3=3) → `multiplicador_velocidad` se DERIVA del estado sin tabla aparte.
enum Velocidad { PAUSA = 0, X1 = 1, X2 = 2, X3 = 3 }

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

## Estado ACTUAL de la máquina de velocidad (Story 006). Fuente de verdad de la velocidad; el
## multiplicador se DERIVA de aquí (`multiplicador_velocidad`), nunca se almacena desincronizado. Se cambia
## SOLO por `fijar_velocidad()`/`reanudar()`. Default X1 (partida nueva arranca en 1×; al CARGAR, H8 fuerza
## PAUSA). El índice viaja en `EventBus.velocidad_cambiada(indice: int)`.
var velocidad_actual: Velocidad = Velocidad.X1

## Última velocidad DE JUEGO (nunca PAUSA) — a la que vuelve `reanudar()` al salir de Pausa (AC-T31).
## Se actualiza al fijar cualquier velocidad ≠ PAUSA; entrar en Pausa NO la pisa. Default X1 → tras cargar
## (que arranca en Pausa sin velocidad previa en la sesión) reanudar va a 1× (AC-T31 excepción).
var _ultima_velocidad_de_juego: Velocidad = Velocidad.X1

## Multiplicador de la máquina de velocidad (Pausa=0 / 1× / 2× / 3×). DERIVADO de `velocidad_actual` —
## los valores enteros del enum `Velocidad` ya SON el multiplicador (PAUSA=0). Lo lee `avanzar()` (H1). NO
## se escribe directamente: cambiar de velocidad es `fijar_velocidad()`, que lo mantiene sincronizado.
var multiplicador_velocidad: int = Velocidad.X1

## Techo del `delta` real aceptado por frame, en segundos (clamp anti-salto TR-time-005). Se LEE del config.
var delta_max_por_frame: float = 0.5

## Inicio de cada turno en minutos del día [0, 1440). Se LEEN del config (Story 002/003) — nunca constantes.
## Defaults del GDD F3: mañana 07:00, tarde 15:00, noche 23:00.
var inicio_manana: int = 420
var inicio_tarde: int = 900
var inicio_noche: int = 1380

## Jornadas por mes de calendario. Se LEE del config; su uso es H5. Default 4 (GDD Core Rules 7).
var jornadas_por_mes: int = 4

# ── Calendario semanal (Story 005 — GDD Core Rules 7) ────────────────────────────────────────
## Cada jornada de 24 h (cruce de 00:00) ES una SEMANA del calendario. 4 semanas = 1 mes, 48 jornadas = 1
## año. Getters para UI/HUD y sistemas que gestionan ciclos (Economía, Demanda). Empiezan en 1 (partida
## nueva); la sincronización al CARGAR (fijarlos sin re-disparar) es H8.
## Mes de campaña [1, 12]. Avanza al completar la 4ª semana (`nuevo_mes`).
var mes: int = 1
## Semana del mes en curso [1, jornadas_por_mes]. Avanza en cada cruce de medianoche; vuelve a 1 al pasar
## la última semana del mes (mostrada como "Mes · Semana N", GDD Core Rules 7.2).
var semana: int = 1
## Año de campaña [1, ...]. Avanza al completar Diciembre (mes 12 · última semana).
var anio: int = 1

# ── Estado de detección de cruces (Story 004 — anti-jitter) ──────────────────────────────────
## Turno derivado la ÚLTIMA vez que se procesaron los cruces. Se compara contra el turno nuevo: solo se
## emite `cambio_de_turno` cuando el valor DERIVADO cambia (nunca por `==` contra un instante) → robusto a
## float y a saltos grandes (GDD Edge Case: 1 emisión por cruce). NO es un reloj paralelo: es la guarda
## anti-duplicado. Se inicializa desde `minutos_juego` en `_ready`/`sincronizar_umbrales`.
var _turno_anterior: int = Turno.NOCHE
## `es_de_noche` derivado la última vez que se procesaron los cruces (misma guarda que `_turno_anterior`).
var _era_de_noche_anterior: bool = true

## El EventBus al que se emiten los cruces. En runtime se auto-resuelve al autoload `EventBus` en `_ready`.
## Se tipa como `Node` (el bus no tiene `class_name`) y se INYECTA en los tests vía `usar_bus()` → los unit
## tests corren contra un bus propio (aislamiento; nunca contaminan el autoload real). Puede ser `null` si el
## objeto se usa sin árbol y sin inyección: en ese caso `_procesar_cruces` no emite (fallback seguro).
var _bus: Node = null

# ── Hook del tick de simulación (Story 007 — GDD Interacciones, ADR-0001) ────────────────────
## Suscriptores del tick de simulación, en el ORDEN de suscripción (ADR-0001: Tiempo EMPUJA el tick a
## Demanda → Flujo → Paciencia, en orden fijo). Cada `Callable` recibe el `delta_juego` (minutos de juego
## avanzados este frame, ya escalados por escala×mult; 0 en Pausa) y corre DESPUÉS de que el reloj avance y
## procese sus cruces. Es un HOOK GENÉRICO: se registran callables con `suscribir_tick()`; NUNCA se llama a
## Demanda/Flujo/Paciencia POR NOMBRE (aún no existen; violaría las capas — ADR-0001). Vacío en el MVP.
var _suscriptores_tick: Array[Callable] = []


func _ready() -> void:
	_cargar_config()
	# Auto-resolver el EventBus (autoload, el 1º → ya vivo aquí). Los autoloads NO son `Engine` singletons:
	# se acceden por ruta absoluta `/root/EventBus`. Inyectable en tests con `usar_bus()` (aislamiento).
	if _bus == null:
		_bus = get_node_or_null("/root/EventBus")
	# Sincronizar las guardas anti-jitter con la hora inicial → el 1er cruce real no dispara evento espurio.
	sincronizar_umbrales()
	# Persistencia (Story 008): SaveManager (epic aparte) recorre el grupo sin conocer el reloj por nombre.
	add_to_group("Persist")


## Tick de simulación (Story 007 — GDD Core Rules 1.3, TR-time-001/007 · ADR-0001). Toda la lógica del reloj
## corre aquí, en `_physics_process` (PASO FIJO ~1/60 s, independiente de los FPS de dibujado) → determinismo
## (misma secuencia de deltas ⇒ idéntico resultado; AC-T35) y compatibilidad con `NavigationAgent2D`. NUNCA
## en `_process` (variable → no determinista) ni leyendo la hora real del sistema.
##
## Orden del frame (idéntico al par manual que ejercitan los tests): capturar `minutos_antes` → `avanzar()`
## (H1: acumula `delta×escala×mult` clampado) → `_procesar_cruces()` (H4/H5: turno/día-noche/calendario) →
## empujar el tick a los suscriptores del hook. En Pausa (mult 0) el avance es 0 → sin cruces y sin empuje.
##
## El reloj es la FUENTE ÚNICA (TR-time-007, AC-T36): nadie más mantiene un contador; los consumidores LEEN
## los getters (`minutos_juego`, `turno_de`, `es_de_noche`, `mes`/`semana`/`anio`) y se enganchan al hook.
func _physics_process(delta: float) -> void:
	var minutos_antes: float = minutos_juego
	avanzar(delta)
	_procesar_cruces(minutos_antes)
	# Empuje del tick a los suscriptores (orden de suscripción). En Pausa el avance es 0 → no empujar.
	if multiplicador_velocidad != 0 and not _suscriptores_tick.is_empty():
		var delta_juego: float = _delta_a_minutos(delta)
		for cb: Callable in _suscriptores_tick:
			if cb.is_valid():
				cb.call(delta_juego)


## Registra un `callable` como suscriptor del tick de simulación (hook del ADR-0001). El callable recibe el
## `delta_juego` (minutos de juego del frame) y se invoca en orden de suscripción tras avanzar y procesar
## cruces. Los sistemas de Core (Demanda/Flujo/Paciencia) se registrarán aquí en SUS epics — Tiempo NUNCA los
## conoce por nombre. Idempotente frente a duplicados (no re-registra el mismo callable).
func suscribir_tick(cb: Callable) -> void:
	if not _suscriptores_tick.has(cb):
		_suscriptores_tick.append(cb)


## Minutos de juego que corresponden a `delta_real` segundos con la escala y el multiplicador ACTUALES,
## aplicando el mismo clamp anti-salto que `avanzar()`. Función PURA (no muta estado) — la usa el empuje del
## hook para pasar `delta_juego` a los suscriptores sin leerlo de `minutos_juego` (que ya envolvió por 1440).
func _delta_a_minutos(delta_real: float) -> float:
	var delta_clampado: float = min(delta_real, delta_max_por_frame)
	return escala_tiempo * multiplicador_velocidad * delta_clampado


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


# ── Máquina de velocidad (Story 006 — GDD Core Rules 2, TR-time-002 · ADR-0001) ──────────────

## Fija la velocidad de la simulación a `v` (SELECTOR DIRECTO: cualquier estado → cualquier otro, GDD).
##
## Deriva el multiplicador del estado (los enteros del enum ya SON el multiplicador; PAUSA=0) y, si `v` es
## una velocidad de juego (≠ PAUSA), la recuerda en `_ultima_velocidad_de_juego` para que `reanudar()`
## vuelva a ella (AC-T31). Entrar en Pausa NO pisa esa memoria. NO toca `minutos_juego`: solo cambia el ritmo
## de los SIGUIENTES frames → el tiempo ya transcurrido no se pierde ni se gana (AC-T30).
##
## Emisión "una vez por acción" (AC-T32): `EventBus.velocidad_cambiada(indice)` se emite SOLO si el estado
## CAMBIA (re-seleccionar la misma velocidad no re-emite). Sin bus inyectado (`_bus == null`) no emite
## (fallback seguro), pero el estado/multiplicador se actualizan igual.
func fijar_velocidad(v: Velocidad) -> void:
	if v != Velocidad.PAUSA:
		_ultima_velocidad_de_juego = v
	if v == velocidad_actual:
		return   # sin cambio efectivo → no re-emitir (una vez por acción)
	velocidad_actual = v
	multiplicador_velocidad = v   # derivado: el entero del enum ES el multiplicador (PAUSA=0)
	if _bus != null:
		_bus.velocidad_cambiada.emit(v)


## Reanuda desde Pausa volviendo a la última velocidad de juego (`_ultima_velocidad_de_juego`, nunca PAUSA;
## default X1 → tras cargar reanuda a 1×, AC-T31 excepción). Es azúcar sobre `fijar_velocidad` (misma
## emisión "una vez por acción" e igual respeto por `minutos_juego`).
func reanudar() -> void:
	fijar_velocidad(_ultima_velocidad_de_juego)


# ── Detección de cruces de umbral (Story 004 · 005 — GDD States/Transitions B + Edge Cases) ──

## Inyecta el EventBus al que se emiten los cruces (dependency injection → testeable sin el autoload real).
##
## Los unit tests pasan su PROPIO `EventBusScript.new()` para aislarse; el runtime usa el autoload
## (auto-resuelto en `_ready`). Idempotente y sin efectos: solo reasigna la referencia.
func usar_bus(bus: Node) -> void:
	_bus = bus


## Sincroniza las guardas anti-jitter (`_turno_anterior`, `_era_de_noche_anterior`) con la hora ACTUAL.
##
## Tras esto, `_procesar_cruces` no disparará un cruce espurio hasta que el turno/día-noche DERIVADO cambie
## de verdad. Se llama en `_ready` (arranque) y lo usará H8 al CARGAR (fijar la hora sin re-emitir eventos).
func sincronizar_umbrales() -> void:
	_turno_anterior = turno_de(minutos_juego)
	_era_de_noche_anterior = es_de_noche(minutos_juego)


## Detecta los cruces de umbral entre `minutos_antes` y `minutos_juego` (ya avanzado) y emite sus eventos
## en el ORDEN determinista del GDD: turno → día/noche → nuevo_dia (→ nuevo_mes).
##
## Regla de oro (GDD Edge Cases): NO se compara `hora == X`; se compara el VALOR DERIVADO anterior vs. el
## nuevo (turno/`es_de_noche`), equivalente a "cruzó el umbral" y robusto a float y a saltos grandes → 1
## emisión por cruce, sin duplicados por jitter (la guarda `_turno_anterior`/`_era_de_noche_anterior` lo
## garantiza). Un mismo frame puede cambiar ambos y además cruzar medianoche (delta grande, AC-T23).
##
## - `cambio_de_turno` / `cambio_dia_noche` son señales de AVISO → `.emit()` directo (orden entre oyentes
##   indiferente; NUNCA por el dispatcher — ADR-0001, Story 004).
## - `nuevo_dia` / `nuevo_mes` son eventos ORDENADOS → SIEMPRE `EventBus.disparar_ordenado(...)`, nunca
##   `.emit()` directo (respeta el orden crítico Paciencia→Economía→…; Story 005). El dispatcher ya emite
##   la señal de notificación homónima al final para los oyentes no críticos.
##
## `minutos_antes` es el acumulador ANTES de `avanzar()`; si el nuevo valor DECRECIÓ (`minutos_juego <
## minutos_antes`) el acumulador envolvió por módulo 1440 = cruzó medianoche (GDD Core Rules 7). Sin bus
## inyectado (`_bus == null`) no emite nada (fallback seguro), pero el calendario SÍ avanza igual.
func _procesar_cruces(minutos_antes: float) -> void:
	# (1) Cambio de turno (aviso). El turno DERIVADO cambió respecto a la última vez → 1 emisión por cruce.
	var turno_nuevo: int = turno_de(minutos_juego)
	if turno_nuevo != _turno_anterior:
		_turno_anterior = turno_nuevo
		if _bus != null:
			_bus.cambio_de_turno.emit(turno_nuevo)

	# (2) Cambio día/noche (aviso), DESPUÉS del turno (orden del GDD: turno → día/noche).
	var noche_nueva: bool = es_de_noche(minutos_juego)
	if noche_nueva != _era_de_noche_anterior:
		_era_de_noche_anterior = noche_nueva
		if _bus != null:
			_bus.cambio_dia_noche.emit(noche_nueva)

	# (3) Medianoche (evento ordenado), DESPUÉS de turno y día/noche. El acumulador decreció = envolvió 00:00.
	if minutos_juego < minutos_antes:
		_avanzar_calendario()


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


# ── Avance del calendario (privado — Story 005 · GDD Core Rules 7) ───────────────────────────

## Avanza el calendario un paso (una jornada = una semana) y dispara `nuevo_dia` (y `nuevo_mes` si toca)
## SIEMPRE por el dispatcher del bus. Se invoca desde `_procesar_cruces` al detectar el cruce de 00:00.
##
## Semana += 1; al superar `jornadas_por_mes` (default 4): Semana→1, Mes += 1 y hay `nuevo_mes`; al superar
## el mes 12 (Diciembre): Mes→1, Año += 1 (48 jornadas = 1 año). Medianoche dispara `nuevo_dia` PERO NO
## `cambio_de_turno` (00:00 sigue en Noche → el turno derivado no cambia; eso lo garantiza el paso (1) de
## `_procesar_cruces`). `nuevo_mes` se dispara DESPUÉS de `nuevo_dia`, en la misma jornada.
func _avanzar_calendario() -> void:
	semana += 1
	var hay_nuevo_mes: bool = false
	if semana > jornadas_por_mes:
		semana = 1
		mes += 1
		hay_nuevo_mes = true
		if mes > 12:
			mes = 1
			anio += 1

	# SIEMPRE por el dispatcher (NUNCA `.emit()` directo): respeta el orden crítico de los handlers ordenados
	# (Paciencia→Economía→Personal→Demanda) y emite la señal de notificación homónima al final.
	if _bus != null:
		_bus.disparar_ordenado(&"nuevo_dia")
		if hay_nuevo_mes:
			_bus.disparar_ordenado(&"nuevo_mes")


# ── Serialización del reloj (Story 008 — GDD Interacciones, TR-time-008 · ADR-0002) ──────────

## Devuelve el estado SERIALIZABLE del reloj para el save (patrón `save()`/`load_state()` del RNGService).
##
## Solo el estado NO DERIVADO: `minutos_juego` (float) + calendario `semana`/`mes`/`anio` (int). NO incluye
## `turno` ni `es_de_noche` (se recalculan de `minutos_juego` al cargar — fuente única, TR-time-006/007), NO
## la velocidad (al cargar SIEMPRE arranca en Pausa), NO el RNG (lo guarda `RNGService.save()`), NI la config
## (`ConfigTiempo` es del desarrollador, no del save). Enteros pequeños directos (sin el truco de string del
## RNG, que sí lo necesita por los int64). El `SaveManager` (epic aparte) recorre el grupo `Persist` y ensambla
## el JSON sin conocer el reloj por nombre (ADR-0002).
func save() -> Dictionary:
	return {
		"minutos_juego": minutos_juego,
		"semana": semana,
		"mes": mes,
		"anio": anio,
	}


## Restaura el estado del reloj desde un `Dictionary` (p. ej. cargado de JSON). "Cargar SITÚA, no reproduce"
## (GDD Edge Cases / ADR-0002): fija el estado, deja el reloj en Pausa y NO re-dispara NINGÚN evento pasado.
##
## Pasos (AC-T26/T27): (1) fija `minutos_juego`/`semana`/`mes`/`anio` desde `d` (defaults seguros si falta una
## clave, sobre el estado actual); (2) fuerza PAUSA con `fijar_velocidad(PAUSA)` → el reloj no avanza hasta que
## el jugador elija velocidad, y `_ultima_velocidad_de_juego` queda en su default X1 (reanudar irá a 1×);
## (3) `sincronizar_umbrales()` alinea las guardas anti-jitter (`_turno_anterior`/`_era_de_noche_anterior`) con
## la hora cargada, SIN emitir → el 1er `_physics_process` tras cargar NO detecta un cruce espurio. Durante toda
## la carga se emiten CERO eventos de cruce/calendario (no se llama a `_procesar_cruces`).
func load_state(d: Dictionary) -> void:
	minutos_juego = float(d.get("minutos_juego", minutos_juego))
	semana = int(d.get("semana", semana))
	mes = int(d.get("mes", mes))
	anio = int(d.get("anio", anio))
	fijar_velocidad(Velocidad.PAUSA)   # H6: cargar arranca SIEMPRE en Pausa (AC-T27)
	sincronizar_umbrales()             # alinea las guardas con la hora cargada → sin cruce espurio (AC-T26)


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
