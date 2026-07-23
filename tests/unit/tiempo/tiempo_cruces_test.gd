# Story 004 (epic tiempo) — cruce de umbrales -> señales de turno y día/noche · TR-time-003/004/006 · ADR-0001
# Detección de cruce por CAMBIO DEL VALOR DERIVADO (nunca ==): 1 emisión por cruce, orden turno -> día/noche,
# sin duplicados por jitter. Tipo: Logic. DETERMINISTA (sin reloj real, sin azar).
#
# Aislamiento: el reloj bajo test recibe un EventBus PROPIO (instancia fresca del script del bus vía
# `usar_bus()`) -> nunca se toca el autoload real. Las lambdas espía apuntan a un Array local (las lambdas
# capturan locales POR VALOR -> el Array, por referencia, sí acumula — gotcha del proyecto).
extends GdUnitTestSuite

const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

const MANANA: int = 0
const TARDE: int = 1
const NOCHE: int = 2


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Reloj en la hora dada, con bus propio inyectado y guardas anti-jitter sincronizadas.
func _tiempo_en(min_dia: float, bus: Node) -> Node:
	var t: Node = auto_free(TiempoScript.new())
	t.usar_bus(bus)
	t.minutos_juego = min_dia
	t.sincronizar_umbrales()
	return t


## Lleva el reloj hasta `hasta` (envuelve por módulo 1440 como hace `avanzar()`) y procesa los cruces —
## el mismo par avanzar+procesar que ejecutará el tick real (H7).
func _cruzar(t: Node, hasta: float) -> void:
	var antes: float = t.minutos_juego
	t.minutos_juego = fposmod(hasta, 1440.0)
	t._procesar_cruces(antes)


# ── AC-T16: cruzar 15:00 emite cambio_de_turno(TARDE) una sola vez ────────────────────────
func test_cruce_15h_emite_cambio_turno_tarde_una_vez() -> void:
	# Arrange — 899.7 (14:59, Mañana), espía de cambio_de_turno.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en(899.7, bus)
	var turnos: Array = []
	bus.cambio_de_turno.connect(func(turno: int) -> void: turnos.append(turno))

	# Act — cruza 15:00.
	_cruzar(t, 900.3)

	# Assert — exactamente 1 emisión con TARDE, y el turno derivado registrado es TARDE.
	assert_array(turnos).contains_exactly([TARDE])
	assert_int(t.turno_de(t.minutos_juego)).is_equal(TARDE)


# ── AC-T17: cruzar 23:00 emite turno y día/noche, una vez cada uno, EN ORDEN ──────────────
func test_cruce_23h_turno_y_dianoche_en_orden() -> void:
	# Arrange — 1379.8 (22:59, Tarde), espías que apuntan al MISMO Array para registrar el orden.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en(1379.8, bus)
	var eventos: Array = []
	bus.cambio_de_turno.connect(func(turno: int) -> void: eventos.append("turno:%d" % turno))
	bus.cambio_dia_noche.connect(func(noche: bool) -> void: eventos.append("noche:%s" % noche))

	# Act — cruza 23:00.
	_cruzar(t, 1380.5)

	# Assert — turno ANTES que día/noche, uno cada uno.
	assert_array(eventos).contains_exactly(["turno:%d" % NOCHE, "noche:true"])


# ── AC-T18: cruzar 07:00 emite turno(MAÑANA) y día/noche(día), en orden ───────────────────
func test_cruce_7h_turno_y_dianoche_en_orden() -> void:
	# Arrange — 419.8 (06:59, Noche).
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en(419.8, bus)
	var eventos: Array = []
	bus.cambio_de_turno.connect(func(turno: int) -> void: eventos.append("turno:%d" % turno))
	bus.cambio_dia_noche.connect(func(noche: bool) -> void: eventos.append("noche:%s" % noche))

	# Act — cruza 07:00.
	_cruzar(t, 420.5)

	# Assert — MAÑANA y día, en ese orden.
	assert_array(eventos).contains_exactly(["turno:%d" % MANANA, "noche:false"])


# ── AC-T23 (parte turno+día/noche) / AC-T24: multi-cruce en un frame, sin omitir ni duplicar ─
func test_multicruce_turno_y_dianoche_sin_duplicar() -> void:
	# Arrange — 1379.0 (22:59, Tarde); un delta grande cruza 23:00 Y 00:00 en el mismo frame.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en(1379.0, bus)
	var eventos: Array = []
	bus.cambio_de_turno.connect(func(turno: int) -> void: eventos.append("turno:%d" % turno))
	bus.cambio_dia_noche.connect(func(noche: bool) -> void: eventos.append("noche:%s" % noche))

	# Act — hasta 1441.0 (envuelve a 1.0: cruzó 23:00 y medianoche).
	_cruzar(t, 1441.0)

	# Assert — UN cambio_de_turno(NOCHE) seguido de UN cambio_dia_noche(true); nada omitido ni duplicado.
	# (El nuevo_dia de este mismo frame se verifica en la Story 005.)
	assert_array(eventos).contains_exactly(["turno:%d" % NOCHE, "noche:true"])


# ── Jitter: avanzar poco a poco tras un cruce ya emitido NO re-emite ──────────────────────
func test_jitter_no_reemite() -> void:
	# Arrange — cruza 15:00 una vez (1 emisión legítima) y limpia el registro.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en(899.7, bus)
	var turnos: Array = []
	bus.cambio_de_turno.connect(func(turno: int) -> void: turnos.append(turno))
	_cruzar(t, 900.3)
	turnos.clear()

	# Act — pequeños avances alrededor del umbral YA cruzado (el turno derivado no cambia).
	_cruzar(t, 900.35)
	_cruzar(t, 900.4)
	_cruzar(t, 900.5)

	# Assert — 0 emisiones nuevas (la guarda del valor derivado impide duplicados por jitter).
	assert_array(turnos).is_empty()
