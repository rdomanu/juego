# Story 003 (epic demanda) — integración: tick de Tiempo, ventana DG6, Pausa DG9, entrega al bus DG1 ·
# TR-demand-001 · ADR-0001/0002. Tipo: Integration. DETERMINISTA: reloj INYECTADO (instancia local de
# tiempo.gd, fuera del árbol → sin physics) manejado a mano; RNGService re-sembrado por test.
# Solo el test de Pausa mete nodos al árbol (physics real con multiplicador 0 → no empuja nada).
extends GdUnitTestSuite

const DemandaScript := preload("res://src/core/demanda/demanda.gd")
const ConfigDemandaScript := preload("res://src/core/demanda/config_demanda.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")

const DOC := &"Documentacion"
const ODAC := &"ODAC"


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Mundo mínimo inyectado: bus espía + reloj local (SIN árbol → sin physics; se maneja a mano).
## Devuelve [demanda, tiempo, bus].
func _mundo(poblacion: int = 90000, config: Resource = null) -> Array:
	var bus: Node = auto_free(EventBusScript.new())
	var tiempo: Node = auto_free(TiempoScript.new())
	var demanda: Node = auto_free(DemandaScript.new())
	demanda.usar_bus(bus)
	demanda.usar_tiempo(tiempo)
	if config == null:
		config = ConfigDemandaScript.new()
	demanda.aplicar_config(config)
	demanda.fijar_poblacion(poblacion)
	return [demanda, tiempo, bus]


## Un tick manual: fija la hora del reloj (minuto AL FINAL del avance) y empuja el delta a Demanda.
func _tick(demanda: Node, tiempo: Node, delta_min: float, min_dia_final: float) -> void:
	tiempo.minutos_juego = min_dia_final
	demanda._al_tick(delta_min)


# ── AC-DM05: la ficha se ENTREGA por el bus con servicio + trámite del catálogo ───────────
func test_persona_generada_llega_por_el_bus() -> void:
	# Arrange — una hora de mañana pico; listener del bus (lambdas capturan por valor → Array).
	RNGService.sembrar(42)
	var mundo: Array = _mundo()
	var demanda: Node = mundo[0]
	var tiempo: Node = mundo[1]
	var bus: Node = mundo[2]
	var recibidas: Array = []
	bus.persona_generada.connect(func(p: RefCounted) -> void: recibidas.append(p))

	# Act — 60 ticks de 1 min desde las 08:31 (Doc acumula 0.225/min → ~13 fichas).
	for i: int in range(60):
		_tick(demanda, tiempo, 1.0, 511.0 + float(i))

	# Assert — llegaron fichas por el bus, válidas contra el catálogo REAL (Datos).
	assert_bool(recibidas.size() > 0).is_true()
	assert_int(demanda.llegadas_hoy).is_equal(recibidas.size())
	for ficha: RefCounted in recibidas:
		assert_bool(ficha is PersonaScript).is_true()
		assert_bool(ficha.servicio in [DOC, ODAC]).is_true()
		var tipo_catalogo: StringName = &"TramiteDoc" if ficha.servicio == DOC else &"DenunciaODAC"
		assert_object(Datos.obtener(tipo_catalogo, ficha.tramite_id)).is_not_null()
		assert_bool(ficha.minuto_llegada > 510.0 and ficha.minuto_llegada <= 571.0).is_true()


# ── AC-DM09: a las 15:00 Documentación NO genera (cerrada); ODAC sí (24 h) ────────────────
func test_doc_cerrada_no_genera_y_odac_si() -> void:
	# Arrange
	RNGService.sembrar(8)
	var mundo: Array = _mundo()
	var demanda: Node = mundo[0]
	var tiempo: Node = mundo[1]
	var bus: Node = mundo[2]
	var por_servicio: Dictionary = {DOC: 0, ODAC: 0}
	bus.persona_generada.connect(
		func(p: RefCounted) -> void: por_servicio[p.servicio] = int(por_servicio[p.servicio]) + 1
	)

	# Act — una hora entera de tarde (15:01 → 16:00); el goteo ODAC (0.025/min) llega a 1.5.
	for i: int in range(60):
		_tick(demanda, tiempo, 1.0, 901.0 + float(i))

	# Assert — cero ciudadanos de Doc (y su acumulador NI CRECE); al menos una denuncia ODAC.
	assert_int(int(por_servicio[DOC])).is_equal(0)
	assert_float(demanda.acumulador_de(DOC)).is_equal_approx(0.0, 0.0001)
	assert_bool(int(por_servicio[ODAC]) >= 1).is_true()


# ── AC-DM10: al cruzar el cierre (14:30), el acumulador Doc fraccional se reinicia a 0 ────
func test_cierre_reinicia_acumulador_doc() -> void:
	# Arrange — acumular fracción en la última franja (14:0x → 0.045/min, sin llegar a 1).
	RNGService.sembrar(15)
	var mundo: Array = _mundo()
	var demanda: Node = mundo[0]
	var tiempo: Node = mundo[1]
	for i: int in range(5):
		_tick(demanda, tiempo, 1.0, 841.0 + float(i))
	assert_bool(demanda.acumulador_de(DOC) > 0.1).is_true()

	# Act — el tick cruza el cierre (869 → 871).
	_tick(demanda, tiempo, 1.0, 869.0)
	_tick(demanda, tiempo, 2.0, 871.0)

	# Assert — la demanda del día NO se arrastra.
	assert_float(demanda.acumulador_de(DOC)).is_equal_approx(0.0, 0.0001)


# ── AC-DM11: en Pausa (mundo REAL en el árbol) no se genera nada — Tiempo no empuja el tick ─
func test_pausa_no_genera_nada() -> void:
	# Arrange — Tiempo y Demanda de verdad en el árbol; el reloj en PAUSA (multiplicador 0).
	RNGService.sembrar(21)
	var bus: Node = auto_free(EventBusScript.new())
	var tiempo: Node = auto_free(TiempoScript.new())
	var demanda: Node = auto_free(DemandaScript.new())
	demanda.usar_bus(bus)
	demanda.usar_tiempo(tiempo)
	var recibidas: Array = []
	bus.persona_generada.connect(func(p: RefCounted) -> void: recibidas.append(p))
	add_child(tiempo)
	add_child(demanda)
	tiempo.fijar_velocidad(TiempoScript.Velocidad.PAUSA)

	# Act — 30 frames de physics REALES con el juego en Pausa.
	for i: int in range(30):
		await get_tree().physics_frame

	# Assert — ni fichas, ni contador, ni acumuladores.
	assert_int(recibidas.size()).is_equal(0)
	assert_int(demanda.llegadas_hoy).is_equal(0)
	assert_float(demanda.acumulador_de(DOC)).is_equal_approx(0.0, 0.0001)
	assert_float(demanda.acumulador_de(ODAC)).is_equal_approx(0.0, 0.0001)


# ── AC-DM16: sin nadie que atienda, el grifo NO se autolimita (sigue al ritmo de F2) ──────
func test_sin_atencion_no_se_autolimita() -> void:
	# Arrange — 800k hab, solo Doc (2 llegadas/min en el pico, por debajo del tope de ráfaga);
	# nadie escucha ni atiende: la cola "crecería" — la válvula es Paciencia, no Demanda.
	RNGService.sembrar(33)
	var config: Resource = ConfigDemandaScript.new()
	config.tasa_base_odac = 0.0
	var mundo: Array = _mundo(800000, config)
	var demanda: Node = mundo[0]
	var tiempo: Node = mundo[1]

	# Act — 3 horas de pico sostenido (misma franja: densidad constante 2.0/min).
	var total: int = 0
	var ultimo_tick: int = 0
	for i: int in range(180):
		tiempo.minutos_juego = 510.0
		var fichas: Array = demanda.procesar_avance(1.0, 510.0)
		ultimo_tick = fichas.size()
		total += fichas.size()

	# Assert — 2/min × 180 min = 360 exactas, y el ÚLTIMO tick sigue al mismo ritmo (sin freno).
	assert_int(total).is_equal(360)
	assert_int(ultimo_tick).is_equal(2)


# ── Orden ADR-0001: el reset diario de Demanda corre en prioridad 40 (entre 39 y 41) ──────
func test_nuevo_dia_reset_en_prioridad_40() -> void:
	# Arrange — bus real; Demanda se registra sola al entrar al árbol (_ready); espías 39 y 41.
	RNGService.sembrar(2)
	var bus: Node = auto_free(EventBusScript.new())
	var tiempo: Node = auto_free(TiempoScript.new())
	var demanda: Node = auto_free(DemandaScript.new())
	demanda.usar_bus(bus)
	demanda.usar_tiempo(tiempo)
	var capturas: Array = []
	bus.registrar_ordenado(&"nuevo_dia", 39, func() -> void: capturas.append(demanda.llegadas_hoy))
	bus.registrar_ordenado(&"nuevo_dia", 41, func() -> void: capturas.append(demanda.llegadas_hoy))
	add_child(demanda)
	demanda.llegadas_hoy = 5

	# Act
	bus.disparar_ordenado(&"nuevo_dia")

	# Assert — el espía 39 ve el contador AÚN a 5; el 41 lo ve ya reseteado (Demanda corrió en 40).
	assert_array(capturas).is_equal([5, 0])
	assert_int(demanda.llegadas_hoy).is_equal(0)
