# Story 002 (epic demanda) — generador determinista: acumulador F4 + mezcla F3 · TR-demand-001/002 ·
# ADR-0002/0001. Tipo: Logic. DETERMINISTA: cada test re-siembra el autoload RNGService (semilla fija)
# → misma secuencia de fichas en cada ejecución (sin flakiness estadística: el "azar" es reproducible).
# Aislamiento: nodo con .new() sin árbol (no corre _ready → no carga el .tres real); población inyectada.
extends GdUnitTestSuite

const DemandaScript := preload("res://src/core/demanda/demanda.gd")
const ConfigDemandaScript := preload("res://src/core/demanda/config_demanda.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")

const DOC := &"Documentacion"
const ODAC := &"ODAC"


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Demanda fresca con config (default u override) y población inyectada.
func _demanda(poblacion: int, config: Resource = null) -> Node:
	var demanda: Node = auto_free(DemandaScript.new())
	if config == null:
		config = ConfigDemandaScript.new()
	demanda.aplicar_config(config)
	demanda.fijar_poblacion(poblacion)
	return demanda


## Codifica una ficha para comparar secuencias completas (servicio + trámite + minuto).
func _codificar(ficha: RefCounted) -> String:
	return "%s:%s:%.3f" % [ficha.servicio, ficha.tramite_id, ficha.minuto_llegada]


## Corre una mañana simulada (ticks de 1 min desde las 08:00) y devuelve la secuencia codificada.
func _correr_manana(demanda: Node, ticks: int) -> Array[String]:
	var secuencia: Array[String] = []
	for i: int in range(ticks):
		var min_dia: float = 480.0 + float(i + 1)   # minuto AL FINAL de cada avance
		for ficha: RefCounted in demanda.procesar_avance(1.0, min_dia):
			secuencia.append(_codificar(ficha))
	return secuencia


# ── AC-DM06: misma semilla + misma secuencia de Δh → llegadas y trámites IDÉNTICOS ────────
func test_determinismo_misma_semilla_misma_secuencia() -> void:
	# Arrange / Act — dos mundos independientes, misma semilla, misma mañana (2 h).
	RNGService.sembrar(42)
	var secuencia_a: Array[String] = _correr_manana(_demanda(90000), 120)
	RNGService.sembrar(42)
	var secuencia_b: Array[String] = _correr_manana(_demanda(90000), 120)

	# Assert — secuencias no vacías e idénticas elemento a elemento (llegadas Y trámites).
	assert_bool(secuencia_a.size() > 0).is_true()
	assert_array(secuencia_b).is_equal(secuencia_a)


# ── AC-DM07: tope de ráfaga — con acumulador ≥ 5 salen 3 y el excedente SE CONSERVA ───────
func test_tope_de_rafaga_conserva_excedente() -> void:
	# Arrange — densidad brutal (2M hab → 5 llegadas Doc/min en el pico); ODAC cerrado para aislar.
	RNGService.sembrar(7)
	var config: Resource = ConfigDemandaScript.new()
	config.tasa_base_odac = 0.0
	var demanda: Node = _demanda(2000000, config)

	# Act — un tick de 1 min a las 08:30 mete +5.0 en el acumulador.
	var fichas: Array = demanda.procesar_avance(1.0, 510.0)

	# Assert — salen exactamente 3 (tope) y quedan ≈ 2.0 pendientes (no se pierde demanda).
	assert_int(fichas.size()).is_equal(3)
	assert_float(demanda.acumulador_de(DOC)).is_equal_approx(2.0, 0.001)

	# Edge — el siguiente tick (casi sin avance) drena el excedente conservado.
	var fichas_2: Array = demanda.procesar_avance(0.001, 510.0)
	assert_int(fichas_2.size()).is_equal(2)
	assert_float(demanda.acumulador_de(DOC)).is_equal_approx(0.0, 0.01)


# ── AC-DM08: con N grande, las proporciones de la mezcla Doc ≈ dni 0.45 / pas 0.35 / tie 0.20 ─
func test_proporciones_mezcla_doc() -> void:
	# Arrange — densidad equilibrada con el tope (3/min exacto → sin residuo creciente): 1.2M hab.
	# ODAC cerrado para que no compita por el tope de ráfaga.
	RNGService.sembrar(1234)
	var config: Resource = ConfigDemandaScript.new()
	config.tasa_base_odac = 0.0
	var demanda: Node = _demanda(1200000, config)

	# Act — 700 ticks × 3 fichas = 2100 elecciones con semilla fija.
	var conteo: Dictionary = {}
	for i: int in range(700):
		for ficha: RefCounted in demanda.procesar_avance(1.0, 510.0):
			conteo[ficha.tramite_id] = int(conteo.get(ficha.tramite_id, 0)) + 1
	var total: float = 2100.0

	# Assert — frecuencias ≈ pesos F3 (±0.05; determinista con la semilla fija).
	assert_float(int(conteo.get(&"dni", 0)) / total).is_equal_approx(0.45, 0.05)
	assert_float(int(conteo.get(&"pasaporte", 0)) / total).is_equal_approx(0.35, 0.05)
	assert_float(int(conteo.get(&"tie", 0)) / total).is_equal_approx(0.20, 0.05)


# ── AC-DM17: pesos [2,1,1] (no suman 1) se normalizan → frecuencias ≈ [0.5, 0.25, 0.25] ───
func test_normalizacion_defensiva_pesos_2_1_1() -> void:
	# Arrange — mezcla artificial que suma 4 (el push_warning "no suma 1.0" es intencional);
	# la normalización la hace elegir_ponderado (RNGService) — aquí se verifica end-to-end.
	RNGService.sembrar(99)
	var config: Resource = ConfigDemandaScript.new()
	config.tasa_base_odac = 0.0
	# El literal debe declararse TIPADO: un Dictionary suelto no se asigna a Dictionary[StringName, float].
	var mezcla_artificial: Dictionary[StringName, float] = {&"a": 2.0, &"b": 1.0, &"c": 1.0}
	config.mezcla_doc = mezcla_artificial
	var demanda: Node = _demanda(1200000, config)

	# Act — 2100 elecciones.
	var conteo: Dictionary = {}
	for i: int in range(700):
		for ficha: RefCounted in demanda.procesar_avance(1.0, 510.0):
			conteo[ficha.tramite_id] = int(conteo.get(ficha.tramite_id, 0)) + 1
	var total: float = 2100.0

	# Assert
	assert_float(int(conteo.get(&"a", 0)) / total).is_equal_approx(0.50, 0.05)
	assert_float(int(conteo.get(&"b", 0)) / total).is_equal_approx(0.25, 0.05)
	assert_float(int(conteo.get(&"c", 0)) / total).is_equal_approx(0.25, 0.05)


# ── DG1: la ficha lleva servicio + trámite del catálogo + minuto de llegada, y es una Persona ─
func test_ficha_lleva_servicio_tramite_y_minuto() -> void:
	# Arrange — Pozuelo real; 5 min del pico acumulan 1.125 llegadas Doc → exactamente 1 ficha.
	RNGService.sembrar(5)
	var demanda: Node = _demanda(90000)

	# Act
	var fichas: Array = demanda.procesar_avance(5.0, 510.0)

	# Assert
	assert_int(fichas.size()).is_equal(1)
	var ficha: RefCounted = fichas[0]
	assert_bool(ficha is PersonaScript).is_true()
	assert_str(String(ficha.servicio)).is_equal(String(DOC))
	assert_bool(ficha.tramite_id in [&"dni", &"pasaporte", &"tie"]).is_true()
	assert_float(ficha.minuto_llegada).is_equal_approx(510.0, 0.0001)


# ── DG5: el tope de ráfaga es GLOBAL por tick (ambos servicios comparten el embudo) ───────
func test_tope_global_entre_servicios() -> void:
	# Arrange — los dos grifos a tope (2M hab: Doc 5/min + ODAC ~0.56/min).
	RNGService.sembrar(11)
	var demanda: Node = _demanda(2000000)

	# Act — dos ticks de 2 min cada uno (inflow >> tope).
	var fichas_1: Array = demanda.procesar_avance(2.0, 510.0)
	var fichas_2: Array = demanda.procesar_avance(2.0, 512.0)

	# Assert — nunca más de 3 por tick (el excedente espera, no se pierde).
	assert_int(fichas_1.size()).is_equal(3)
	assert_int(fichas_2.size()).is_equal(3)
	assert_bool(demanda.acumulador_de(DOC) > 0.0).is_true()


# ── Edge: delta 0 (Pausa aguas arriba) no acumula ni genera ───────────────────────────────
func test_delta_cero_no_genera() -> void:
	# Arrange
	RNGService.sembrar(3)
	var demanda: Node = _demanda(90000)

	# Act
	var fichas: Array = demanda.procesar_avance(0.0, 510.0)

	# Assert
	assert_int(fichas.size()).is_equal(0)
	assert_float(demanda.acumulador_de(DOC)).is_equal_approx(0.0, 0.0001)
	assert_float(demanda.acumulador_de(ODAC)).is_equal_approx(0.0, 0.0001)
