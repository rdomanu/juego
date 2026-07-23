# Story 008 (epic tiempo) — save()/load_state() + "cargar sitúa, no reproduce" (Pausa, sin eventos) ·
# TR-time-008 · ADR-0002. save() devuelve solo estado NO derivado; load_state fija el estado, fuerza Pausa,
# sincroniza los umbrales y NO re-dispara eventos pasados. Tipo: Logic. DETERMINISTA (round-trip de un
# Dictionary + espías del bus; sin reloj real, sin azar, sin disco).
#
# Aislamiento: el reloj bajo test recibe un EventBus PROPIO (instancia fresca vía `usar_bus()`) → nunca se
# toca el autoload real. Espías sobre Arrays locales (por referencia — gotcha de lambdas del proyecto).
# Preload por ruta literal. NUNCA hora real del sistema.
extends GdUnitTestSuite

const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

const TARDE: int = 1
const PAUSA: int = 0

# 15:30 = 15*60 + 30 = 930 min del día — TARDE según las franjas del GDD ([900,1380)). El ejemplo del
# AC-T26 decía "14:30, turno Tarde", pero 14:30 (870) es MAÑANA según la propia tabla de turnos del GDD
# (errata del ejemplo del GDD — mezcla el horario laboral de Documentación con el turno del reloj;
# anotada en el cierre de la story). Se usa 15:30 para que hora y turno derivado sean coherentes.
const MIN_15_30: float = 930.0


# ── Helper de fixture ────────────────────────────────────────────────────────────────────
## Reloj fresco con bus propio inyectado (sin árbol → sin `_ready`).
func _tiempo(bus: Node) -> Node:
	var t: Node = auto_free(TiempoScript.new())
	t.usar_bus(bus)
	return t


## Conecta espías a los 4 eventos de cruce/calendario (los que la carga NO debe re-disparar).
func _conectar_espias_cruces(bus: Node, destino: Array) -> void:
	bus.cambio_de_turno.connect(func(turno: int) -> void: destino.append("turno:%d" % turno))
	bus.cambio_dia_noche.connect(func(noche: bool) -> void: destino.append("noche:%s" % noche))
	bus.nuevo_dia.connect(func() -> void: destino.append("nuevo_dia"))
	bus.nuevo_mes.connect(func() -> void: destino.append("nuevo_mes"))


# ── Round-trip: load_state(save()) deja el mismo estado; los derivados se recalculan iguales ─
func test_roundtrip_estado_identico() -> void:
	# Arrange — reloj a 15:30 (Tarde), semana 3, mes 2, año 1.
	var bus: Node = auto_free(EventBusScript.new())
	var origen: Node = _tiempo(bus)
	origen.minutos_juego = MIN_15_30
	origen.semana = 3
	origen.mes = 2
	origen.anio = 1

	# Act — serializar y restaurar en un reloj NUEVO.
	var d: Dictionary = origen.save()
	var bus2: Node = auto_free(EventBusScript.new())
	var cargado: Node = _tiempo(bus2)
	cargado.load_state(d)

	# Assert — mismo estado no derivado…
	assert_float(cargado.minutos_juego).is_equal_approx(MIN_15_30, 0.0001)
	assert_int(cargado.semana).is_equal(3)
	assert_int(cargado.mes).is_equal(2)
	assert_int(cargado.anio).is_equal(1)
	# …y los DERIVADOS recalculados iguales (turno Tarde, HH:MM "15:30").
	assert_int(cargado.turno_de(cargado.minutos_juego)).is_equal(TARDE)
	assert_str(cargado.hhmm(cargado.minutos_juego)).is_equal("15:30")


# ── AC-T26: cargar NO emite señales de turno / día-noche / nuevo_dia (ni el 1er tick tras cargar) ─
func test_carga_no_emite_eventos() -> void:
	# Arrange — reloj nuevo a 07:00 (Noche→Mañana sería un cruce si se procesara); espías de los 4 eventos.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo(bus)
	var eventos: Array = []
	_conectar_espias_cruces(bus, eventos)

	# Act — cargar 15:30 (Tarde derivado), semana 5.
	t.load_state({"minutos_juego": MIN_15_30, "semana": 5, "mes": 1, "anio": 1})

	# Assert (durante la carga) — 0 emisiones de cruce/calendario ("cargar sitúa, no reproduce").
	assert_array(eventos).is_empty()

	# Act 2 — un _physics_process INMEDIATO tras cargar (en Pausa: mult 0 → avance 0).
	t._physics_process(1.0 / 60.0)

	# Assert 2 — sigue sin cruces espurios (la sincronización del umbral + Pausa lo garantizan).
	assert_array(eventos).is_empty()


# ── AC-T27: cargar arranca SIEMPRE en Pausa; el reloj no avanza hasta elegir velocidad ──────
func test_carga_arranca_en_pausa() -> void:
	# Arrange — reloj que estaba a 3× (velocidad de juego alta antes de cargar).
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo(bus)
	t.fijar_velocidad(t.Velocidad.X3)

	# Act — cargar (la velocidad guardada da igual: al cargar SIEMPRE arranca en Pausa).
	t.load_state({"minutos_juego": MIN_15_30, "semana": 1, "mes": 1, "anio": 1})

	# Assert — velocidad activa PAUSA y multiplicador 0.
	assert_int(t.velocidad_actual).is_equal(PAUSA)
	assert_int(t.multiplicador_velocidad).is_equal(0)

	# Act 2 — un tick: el reloj NO debe avanzar hasta que el jugador elija velocidad.
	var antes: float = t.minutos_juego
	t._physics_process(1.0)

	# Assert 2 — minutos_juego intacto.
	assert_float(t.minutos_juego).is_equal_approx(antes, 0.0001)


# ── save() no incluye datos derivados ni el RNG ─────────────────────────────────────────────
func test_save_no_incluye_derivados() -> void:
	# Arrange — reloj a una hora cualquiera.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo(bus)
	t.minutos_juego = MIN_15_30

	# Act
	var d: Dictionary = t.save()

	# Assert — claves EXACTAS: solo estado no derivado; sin turno/es_de_noche/velocidad/rng/config.
	assert_bool(d.has("minutos_juego")).is_true()
	assert_bool(d.has("semana")).is_true()
	assert_bool(d.has("mes")).is_true()
	assert_bool(d.has("anio")).is_true()
	assert_bool(d.has("turno")).is_false()
	assert_bool(d.has("es_de_noche")).is_false()
	assert_bool(d.has("velocidad")).is_false()
	assert_bool(d.has("rng")).is_false()
	assert_int(d.size()).is_equal(4)


# ── load_state con claves ausentes → defaults seguros (no peta) ──────────────────────────────
func test_load_state_claves_ausentes_defaults_seguros() -> void:
	# Arrange — reloj con un estado conocido; se carga un Dictionary PARCIAL (solo minutos_juego).
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo(bus)
	t.semana = 3
	t.mes = 2
	t.anio = 1

	# Act — carga parcial: solo minutos_juego (falta semana/mes/anio).
	t.load_state({"minutos_juego": MIN_15_30})

	# Assert — minutos_juego se fija; el resto conserva el valor previo (default seguro, no peta) y Pausa.
	assert_float(t.minutos_juego).is_equal_approx(MIN_15_30, 0.0001)
	assert_int(t.semana).is_equal(3)
	assert_int(t.mes).is_equal(2)
	assert_int(t.anio).is_equal(1)
	assert_int(t.velocidad_actual).is_equal(PAUSA)
