# Story 006 (epic demanda) — persistencia: save/load + Persist + determinismo tras cargar ·
# TR-demand-002 · ADR-0002. Tipo: Integration. DETERMINISTA (RNGService re-sembrado/restaurado).
# Round-trip por JSON real (stringify -> parse: caza tipos no serializables); el round-trip por DISCO
# del save completo lo cubre la suite del SaveManager (savemanager roundtrip + smoke) — patrón Economía.
extends GdUnitTestSuite

const DemandaScript := preload("res://src/core/demanda/demanda.gd")
const ConfigDemandaScript := preload("res://src/core/demanda/config_demanda.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")

const DOC := &"Documentacion"
const ODAC := &"ODAC"

const CLAVES_SAVE: Array[String] = [
	"acumulador_doc", "acumulador_odac", "llegadas_hoy", "nivel",
	"evento_activo", "evento_jornadas_restantes",
]


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Mundo inyectado (bus + reloj local, sin árbol). Devuelve [demanda, tiempo, bus].
func _mundo() -> Array:
	var bus: Node = auto_free(EventBusScript.new())
	var tiempo: Node = auto_free(TiempoScript.new())
	var demanda: Node = auto_free(DemandaScript.new())
	demanda.usar_bus(bus)
	demanda.usar_tiempo(tiempo)
	demanda.aplicar_config(ConfigDemandaScript.new())
	demanda.fijar_poblacion(90000)
	return [demanda, tiempo, bus]


## Avanza `ticks` minutos de juego (1 min/tick) desde `min_inicio` recogiendo las fichas que salen
## por el bus; devuelve la secuencia codificada (servicio:trámite:minuto).
func _correr_con_bus(demanda: Node, tiempo: Node, bus: Node, min_inicio: float, ticks: int) -> Array[String]:
	var secuencia: Array[String] = []
	var cb: Callable = func(p: RefCounted) -> void:
		secuencia.append("%s:%s:%.3f" % [p.servicio, p.tramite_id, p.minuto_llegada])
	bus.persona_generada.connect(cb)
	for i: int in range(ticks):
		tiempo.minutos_juego = min_inicio + float(i + 1)
		demanda._al_tick(1.0)
	bus.persona_generada.disconnect(cb)
	return secuencia


# ── AC-DM18 (round-trip): save → JSON → load restaura los 6 campos idénticos ──────────────
func test_roundtrip_json_restaura_estado() -> void:
	# Arrange — estado no trivial: acumuladores fraccionales, contador, nivel ALTA, evento a medias.
	var mundo_a: Array = _mundo()
	var demanda_a: Node = mundo_a[0]
	var tiempo_a: Node = mundo_a[1]
	demanda_a._acumulador[DOC] = 0.4
	demanda_a._acumulador[ODAC] = 0.7
	demanda_a.llegadas_hoy = 12
	demanda_a.factor_crecimiento_nivel = 1.5
	demanda_a._recalcular_nivel()
	tiempo_a.mes = 12
	demanda_a._al_nuevo_mes()
	demanda_a._al_nuevo_dia()   # evento vacaciones: 3 -> 2 jornadas; llegadas_hoy vuelve a 0
	demanda_a.llegadas_hoy = 12

	# Act — por JSON REAL (como viajará en el save) a una instancia NUEVA.
	var json: String = JSON.stringify(demanda_a.save())
	var parseado: Dictionary = JSON.parse_string(json)
	var mundo_b: Array = _mundo()
	var demanda_b: Node = mundo_b[0]
	var tiempo_b: Node = mundo_b[1]
	tiempo_b.mes = 12
	demanda_b.load_state(parseado)

	# Assert — los 6 campos + el mult estacional re-derivado del mes.
	assert_float(demanda_b.acumulador_de(DOC)).is_equal_approx(0.4, 0.0001)
	assert_float(demanda_b.acumulador_de(ODAC)).is_equal_approx(0.7, 0.0001)
	assert_int(demanda_b.llegadas_hoy).is_equal(12)
	assert_str(String(demanda_b.nivel_demanda())).is_equal("ALTA")
	assert_str(String(demanda_b.evento_activo())).is_equal("vacaciones")
	assert_int(demanda_b.evento_jornadas_restantes()).is_equal(2)
	assert_float(demanda_b.mult_estacional_vigente()).is_equal_approx(1.5, 0.0001)


# ── AC-DM18 (determinismo): cargar a mitad de mañana continúa la MISMA secuencia futura ───
func test_determinismo_tras_cargar() -> void:
	# Arrange — mundo A: 2 h de mañana, guardado a las 10:00 (Demanda + RNG). Mes 4 (abril, ×1.0)
	# fijado en AMBOS mundos: la carga re-deriva el mult estacional del mes del reloj.
	RNGService.sembrar(4242)
	var mundo_a: Array = _mundo()
	var demanda_a: Node = mundo_a[0]
	var tiempo_a: Node = mundo_a[1]
	var bus_a: Node = mundo_a[2]
	tiempo_a.mes = 4
	_correr_con_bus(demanda_a, tiempo_a, bus_a, 480.0, 120)
	# full_precision=true — como el SaveManager real: sin él los floats pierden decimales y el
	# acumulador restaurado cruzaría umbrales en OTRO tick (adiós determinismo exacto).
	var save_demanda: Dictionary = JSON.parse_string(JSON.stringify(demanda_a.save(), "", true, true))
	var save_rng: Dictionary = RNGService.save()

	# Act — A sigue 3 h más (la referencia)…
	var futuro_a: Array[String] = _correr_con_bus(demanda_a, tiempo_a, bus_a, 600.0, 180)
	# …y B CARGA el save y recorre las mismas 3 h.
	var mundo_b: Array = _mundo()
	var demanda_b: Node = mundo_b[0]
	var tiempo_b: Node = mundo_b[1]
	var bus_b: Node = mundo_b[2]
	tiempo_b.mes = 4
	tiempo_b.minutos_juego = 600.0
	RNGService.load_state(save_rng)
	demanda_b.load_state(save_demanda)
	var futuro_b: Array[String] = _correr_con_bus(demanda_b, tiempo_b, bus_b, 600.0, 180)

	# Assert — la secuencia futura es IDÉNTICA ficha a ficha (sin llegadas retroactivas).
	assert_bool(futuro_a.size() > 0).is_true()
	assert_array(futuro_b).is_equal(futuro_a)


# ── "Cargar sitúa, no reproduce": la carga no emite NINGUNA señal ─────────────────────────
func test_carga_sin_senales() -> void:
	# Arrange — espías de las dos señales de Demanda.
	var mundo: Array = _mundo()
	var demanda: Node = mundo[0]
	var tiempo: Node = mundo[1]
	var bus: Node = mundo[2]
	var eventos: Array = []
	bus.persona_generada.connect(func(_p: RefCounted) -> void: eventos.append("persona"))
	bus.nivel_demanda_cambiado.connect(func(_n: StringName) -> void: eventos.append("nivel"))
	tiempo.mes = 6

	# Act — cargar un estado con nivel distinto del actual y evento activo.
	demanda.load_state({
		"acumulador_doc": 0.9, "llegadas_hoy": 30, "nivel": "ALTA",
		"evento_activo": "vacaciones", "evento_jornadas_restantes": 1,
	})

	# Assert — restaurado en silencio.
	assert_array(eventos).is_empty()
	assert_str(String(demanda.nivel_demanda())).is_equal("ALTA")


# ── Save viejo (claves ausentes) → defaults sanos, sin errores ────────────────────────────
func test_save_viejo_carga_con_defaults() -> void:
	# Arrange
	var mundo: Array = _mundo()
	var demanda: Node = mundo[0]

	# Act
	demanda.load_state({})

	# Assert — grifo en estado limpio.
	assert_float(demanda.acumulador_de(DOC)).is_equal_approx(0.0, 0.0001)
	assert_int(demanda.llegadas_hoy).is_equal(0)
	assert_str(String(demanda.evento_activo())).is_equal("")


# ── Persist: el nodo entra al grupo en _ready y su save() lleva SOLO estado no derivado ───
func test_grupo_persist_y_claves_exactas() -> void:
	# Arrange — con árbol (dispara _ready); bus/tiempo espías inyectados ANTES (no tocar autoloads).
	var demanda: Node = DemandaScript.new()
	demanda.usar_bus(auto_free(EventBusScript.new()))
	demanda.usar_tiempo(auto_free(TiempoScript.new()))
	add_child(demanda)

	# Act
	var d: Dictionary = demanda.save()

	# Assert — grupo Persist + claves exactas (sin RNG, sin mult estacional derivado).
	assert_bool(demanda.is_in_group("Persist")).is_true()
	for clave: String in CLAVES_SAVE:
		assert_bool(d.has(clave)).is_true()
	assert_int(d.size()).is_equal(CLAVES_SAVE.size())
	assert_bool(d.has("rng")).is_false()
	assert_bool(d.has("mult_estacional")).is_false()

	# Cleanup — fuera del árbol y liberado (aislamiento).
	remove_child(demanda)
	demanda.free()
