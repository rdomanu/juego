# Story 006 (epic economia) — balance mensual + save/load + Persist · TR-economy-002 · ADR-0001/0002.
# Tipo: Logic. DETERMINISTA. Bus espía propio; métodos de ciclo llamados directos.
extends GdUnitTestSuite

const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

const CLAVES_SAVE: Array[String] = [
	"saldo_eur", "prestamos_usados", "prestamos_vivos", "ingreso_doc_dia", "ingresos_mes",
	"gastos_mes", "balance_mes", "en_gracia", "gracia_restante_min", "sat_cierre_doc", "horas_extra_dia",
]


# ── Helper de fixture ────────────────────────────────────────────────────────────────────
func _economia(bus: Node = null) -> Node:
	var eco: Node = auto_free(EconomiaScript.new())
	eco.usar_bus(bus if bus != null else auto_free(EventBusScript.new()))
	eco.aplicar_config(ConfigEconomiaScript.new())
	return eco


# ── AC-E16: balance mensual = ingresos − gastos, con reset de acumuladores ────────────────
func test_balance_mensual_y_reset() -> void:
	# Arrange
	var eco: Node = _economia()
	eco.ingresos_mes = 3000.0
	eco.gastos_mes = 2600.0

	# Act
	eco._al_nuevo_mes()

	# Assert — +400 y acumuladores a cero.
	assert_float(eco.balance_mes).is_equal_approx(400.0, 0.0001)
	assert_float(eco.ingresos_mes).is_equal_approx(0.0, 0.0001)
	assert_float(eco.gastos_mes).is_equal_approx(0.0, 0.0001)


# ── Los acumuladores del mes suman TODO: ingresos DGP y gastos del cierre (recargo incluido) ─
func test_acumuladores_de_mes_suman_todo() -> void:
	# Arrange — un ingreso (dni a sat 50 = 3,6) y un cierre con deuda de apertura + nómina.
	var bus: Node = auto_free(EventBusScript.new())
	var eco: Node = _economia(bus)
	bus.tramite_completado.emit(&"dni", null)
	eco.saldo_eur = -500.0
	eco._estado_anterior = eco.EstadoFinanciero.ROJOS
	eco.fijar_plantilla([&"ag_doc", &"ag_doc", &"ag_odac"] as Array[StringName])

	# Act — cierre: recargo 10 (2 % de 500) + nómina 190.
	eco._al_nuevo_dia()

	# Assert — ingresos_mes 3,6 · gastos_mes 200 (el recargo ES gasto).
	assert_float(eco.ingresos_mes).is_equal_approx(3.6, 0.0001)
	assert_float(eco.gastos_mes).is_equal_approx(200.0, 0.0001)


# ── AC-E18: cargar restaura tal cual, sin señales ni cobros retroactivos ──────────────────
func test_load_restaura_sin_senales_ni_cobros() -> void:
	# Arrange — espías de TODAS las señales que la carga no debe disparar.
	var bus: Node = auto_free(EventBusScript.new())
	var eco: Node = _economia(bus)
	var eventos: Array = []
	bus.saldo_cambiado.connect(func(_s: float) -> void: eventos.append("saldo"))
	bus.entro_en_deuda.connect(func(_s: float) -> void: eventos.append("deuda"))
	bus.insolvencia.connect(func(_s: float, _r: int) -> void: eventos.append("insolvencia"))

	# Act — cargar un save en números rojos con préstamos.
	eco.load_state({
		"saldo_eur": -300.0, "prestamos_usados": 2, "prestamos_vivos": 1, "sat_cierre_doc": 40.0,
	})

	# Assert — restaurado tal cual, 0 señales durante la carga ("cargar sitúa, no reproduce").
	assert_float(eco.saldo_eur).is_equal_approx(-300.0, 0.0001)
	assert_int(eco.prestamos_usados).is_equal(2)
	assert_int(eco.prestamos_vivos).is_equal(1)
	assert_float(eco.sat_cierre_doc).is_equal_approx(40.0, 0.0001)
	assert_array(eventos).is_empty()

	# Act 2 — el primer movimiento tras cargar NO re-emite la entrada en deuda (la guarda quedó situada).
	eco.abonar(50.0)

	# Assert 2 — solo el aviso de saldo del movimiento; sin "deuda" retroactiva.
	assert_array(eventos).contains_exactly(["saldo"])


# ── AC-E19: determinismo — la misma secuencia produce el mismo saldo ──────────────────────
func test_determinismo_misma_secuencia() -> void:
	# Arrange — dos economías idénticas.
	var resultados: Array = []
	for i in 2:
		var bus: Node = auto_free(EventBusScript.new())
		var eco: Node = _economia(bus)
		eco.fijar_plantilla([&"ag_doc", &"ag_odac"] as Array[StringName])
		# Act — misma secuencia: 2 trámites, préstamo, cierre, hora extra, cierre.
		bus.tramite_completado.emit(&"dni", null)
		bus.tramite_completado.emit(&"pasaporte", null)
		eco.pedir_prestamo()
		eco._al_nuevo_dia()
		eco.registrar_horas_extra(2.0)
		eco._al_nuevo_dia()
		resultados.append(eco.saldo_eur)

	# Assert — idénticos.
	assert_float(resultados[0]).is_equal_approx(resultados[1], 0.000001)


# ── Persist: el nodo entra al grupo en _ready y su save() lleva SOLO estado no derivado ───
func test_grupo_persist_y_save_sin_derivados() -> void:
	# Arrange — con árbol (dispara _ready); bus/tiempo espías inyectados ANTES para no tocar autoloads.
	var bus: Node = auto_free(EventBusScript.new())
	var eco: Node = EconomiaScript.new()
	eco.usar_bus(bus)
	eco.usar_tiempo(auto_free(preload("res://src/foundation/tiempo/tiempo.gd").new()))
	add_child(eco)

	# Act
	var d: Dictionary = eco.save()

	# Assert — grupo Persist + claves exactas (sin estado derivado ni plantilla).
	assert_bool(eco.is_in_group("Persist")).is_true()
	for clave in CLAVES_SAVE:
		assert_bool(d.has(clave)).is_true()
	assert_int(d.size()).is_equal(CLAVES_SAVE.size())
	assert_bool(d.has("estado")).is_false()

	# Cleanup — fuera del árbol y liberado (aislamiento).
	remove_child(eco)
	eco.free()
