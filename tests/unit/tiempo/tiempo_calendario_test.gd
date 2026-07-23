# Story 005 (epic tiempo) — medianoche -> calendario semanal + nuevo_dia/nuevo_mes por dispatcher ·
# TR-time-004/006 · ADR-0001. Cada jornada = 1 semana; 4 semanas = 1 mes; 48 jornadas = 1 año.
# nuevo_dia/nuevo_mes SIEMPRE vía disparar_ordenado (el dispatcher emite la señal homónima al final,
# que es la que espían estos tests). Tipo: Logic. DETERMINISTA.
#
# Aislamiento: bus PROPIO inyectado con `usar_bus()` (nunca el autoload real). Espías sobre Arrays
# locales (por referencia — gotcha de lambdas del proyecto).
extends GdUnitTestSuite

const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

const NOCHE: int = 2


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
func _tiempo_en(min_dia: float, bus: Node) -> Node:
	var t: Node = auto_free(TiempoScript.new())
	t.usar_bus(bus)
	t.minutos_juego = min_dia
	t.sincronizar_umbrales()
	return t


## Lleva el reloj hasta `hasta` (envuelve por módulo 1440) y procesa cruces (par avanzar+procesar del tick).
func _cruzar(t: Node, hasta: float) -> void:
	var antes: float = t.minutos_juego
	t.minutos_juego = fposmod(hasta, 1440.0)
	t._procesar_cruces(antes)


# ── AC-T20: cruzar 00:00 dispara nuevo_dia (1 vez) y avanza la semana ─────────────────────
func test_medianoche_dispara_nuevo_dia_y_semana_mas_1() -> void:
	# Arrange — 23:59.8, semana 1 de un mes cualquiera.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en(1439.8, bus)
	var dias: Array = []
	bus.nuevo_dia.connect(func() -> void: dias.append("dia"))

	# Act — cruza medianoche (1440.3 envuelve a 0.3).
	_cruzar(t, 1440.3)

	# Assert — 1 nuevo_dia; semana +1; el mes no cambia.
	assert_int(dias.size()).is_equal(1)
	assert_int(t.semana).is_equal(2)
	assert_int(t.mes).is_equal(1)


# ── AC-T21: medianoche NO es cambio de turno (00:00 sigue en Noche) ───────────────────────
func test_medianoche_no_dispara_cambio_de_turno() -> void:
	# Arrange — 23:59.8 (turno Noche), espías de nuevo_dia Y cambio_de_turno.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en(1439.8, bus)
	var dias: Array = []
	var turnos: Array = []
	bus.nuevo_dia.connect(func() -> void: dias.append("dia"))
	bus.cambio_de_turno.connect(func(turno: int) -> void: turnos.append(turno))

	# Act
	_cruzar(t, 1440.3)

	# Assert — nuevo_dia SÍ; cambio_de_turno NO (el turno derivado sigue NOCHE).
	assert_int(dias.size()).is_equal(1)
	assert_array(turnos).is_empty()
	assert_int(t.turno_de(t.minutos_juego)).is_equal(NOCHE)


# ── AC-T22: la Semana 4 cruza medianoche -> nuevo_dia + nuevo_mes, mes+1, semana=1 ────────
func test_semana4_cruza_a_mes_mas_1_y_semana_1() -> void:
	# Arrange — última semana del mes (semana 4), 23:59.8.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en(1439.8, bus)
	t.semana = 4
	var eventos: Array = []
	bus.nuevo_dia.connect(func() -> void: eventos.append("dia"))
	bus.nuevo_mes.connect(func() -> void: eventos.append("mes"))

	# Act
	_cruzar(t, 1440.3)

	# Assert — nuevo_dia y DESPUÉS nuevo_mes; mes 1->2; semana vuelve a 1.
	assert_array(eventos).contains_exactly(["dia", "mes"])
	assert_int(t.mes).is_equal(2)
	assert_int(t.semana).is_equal(1)


# ── AC-T22b: Diciembre · Semana 4 -> año+1, mes=1, semana=1 (48 jornadas = 1 año) ─────────
func test_diciembre_semana4_avanza_anio() -> void:
	# Arrange — mes 12, semana 4, 23:59.8.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en(1439.8, bus)
	t.mes = 12
	t.semana = 4
	var eventos: Array = []
	bus.nuevo_dia.connect(func() -> void: eventos.append("dia"))
	bus.nuevo_mes.connect(func() -> void: eventos.append("mes"))

	# Act
	_cruzar(t, 1440.3)

	# Assert — cruce de año: anio+1, mes vuelve a 1, semana a 1; nuevo_dia + nuevo_mes.
	assert_array(eventos).contains_exactly(["dia", "mes"])
	assert_int(t.anio).is_equal(2)
	assert_int(t.mes).is_equal(1)
	assert_int(t.semana).is_equal(1)


# ── AC-T23 (orden COMPLETO del multi-cruce): turno -> día/noche -> nuevo_dia ──────────────
func test_multicruce_orden_turno_dianoche_nuevodia() -> void:
	# Arrange — 22:59 (Tarde); un delta grande cruza 23:00 Y 00:00 en el mismo frame. Los 3 espías
	# apuntan al MISMO Array para registrar el orden real de invocación (más robusto que medir tiempos).
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en(1379.0, bus)
	var orden: Array = []
	bus.cambio_de_turno.connect(func(_turno: int) -> void: orden.append("turno"))
	bus.cambio_dia_noche.connect(func(_noche: bool) -> void: orden.append("dianoche"))
	bus.nuevo_dia.connect(func() -> void: orden.append("nuevo_dia"))

	# Act — hasta 1441.0 (envuelve a 1.0).
	_cruzar(t, 1441.0)

	# Assert — el orden determinista del GDD, uno cada uno.
	assert_array(orden).contains_exactly(["turno", "dianoche", "nuevo_dia"])
