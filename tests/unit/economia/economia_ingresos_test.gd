# Story 002 (epic economia) — ingresos: retorno DGP + ingreso instantáneo · TR-economy-001 · ADR-0001.
# Tipo: Logic. DETERMINISTA (sin azar; sat inyectada; valores del CATÁLOGO REAL: tarifa dni=12,
# retorno_dgp 0.15/0.45 — si el catálogo cambia, estos tests deben fallar: detectan divergencia).
# Aislamiento: bus ESPÍA propio inyectado con usar_bus (los trámites se emiten por él a mano).
extends GdUnitTestSuite

const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")


# ── Helper de fixture ────────────────────────────────────────────────────────────────────
## Economía fresca (config default: caja 3000) con bus espía propio conectado.
func _economia_con_bus(bus: Node) -> Node:
	var eco: Node = auto_free(EconomiaScript.new())
	eco.usar_bus(bus)
	eco.aplicar_config(ConfigEconomiaScript.new())
	return eco


# ── AC-E01: dni (tarifa 12) a sat 50 → +3,6 € al instante ─────────────────────────────────
func test_dni_a_sat50_abona_3_60() -> void:
	# Arrange — sat default 50 (provisional = sat_inicial).
	var bus: Node = auto_free(EventBusScript.new())
	var eco: Node = _economia_con_bus(bus)

	# Act — Flujo (futuro) emitiría esto; aquí lo emite el test por el bus espía.
	bus.tramite_completado.emit(&"dni", null)

	# Assert — 12 × 0.30 = 3,6 abonados al instante + acumulados en el día.
	assert_float(eco.saldo_eur).is_equal_approx(3003.6, 0.0001)
	assert_float(eco.ingreso_doc_dia).is_equal_approx(3.6, 0.0001)


# ── AC-E02: extremos de F1 con los params del catálogo ────────────────────────────────────
func test_retorno_extremos_015_y_045() -> void:
	# Arrange
	var eco: Node = _economia_con_bus(auto_free(EventBusScript.new()))

	# Act + Assert
	assert_float(eco.retorno_dgp(0.0)).is_equal_approx(0.15, 0.0001)
	assert_float(eco.retorno_dgp(100.0)).is_equal_approx(0.45, 0.0001)


# ── AC-E03: sat fuera de rango se clampa (nunca fuera de [min, max]) ──────────────────────
func test_sat_fuera_de_rango_clampa() -> void:
	# Arrange
	var eco: Node = _economia_con_bus(auto_free(EventBusScript.new()))

	# Act + Assert — 150 → como 100; −20 → como 0.
	assert_float(eco.retorno_dgp(150.0)).is_equal_approx(0.45, 0.0001)
	assert_float(eco.retorno_dgp(-20.0)).is_equal_approx(0.15, 0.0001)


# ── AC-E03b: el retorno es constante intra-jornada (solo cambia al fijar la sat de cierre) ─
func test_retorno_constante_intra_jornada() -> void:
	# Arrange — dos trámites con la sat vigente (50) y uno tras el "cambio de jornada" a 0.
	var bus: Node = auto_free(EventBusScript.new())
	var eco: Node = _economia_con_bus(bus)

	# Act — dos dni a sat 50 (3,6 cada uno)…
	bus.tramite_completado.emit(&"dni", null)
	bus.tramite_completado.emit(&"dni", null)
	# …Paciencia (futura) cierra la jornada con sat 0 → los SIGUIENTES aplican 0.15.
	eco.fijar_sat_cierre(0.0)
	bus.tramite_completado.emit(&"dni", null)

	# Assert — 3,6 + 3,6 + 1,8: los ya acreditados no cambian; el nuevo usa el retorno nuevo.
	assert_float(eco.ingreso_doc_dia).is_equal_approx(9.0, 0.0001)
	assert_float(eco.saldo_eur).is_equal_approx(3009.0, 0.0001)


# ── AC-E04: una denuncia ODAC NO genera ingreso ───────────────────────────────────────────
func test_denuncia_odac_no_genera_ingreso() -> void:
	# Arrange
	var bus: Node = auto_free(EventBusScript.new())
	var eco: Node = _economia_con_bus(bus)

	# Act — se "completa" una denuncia (id real del catálogo, tipo DenunciaODAC).
	bus.tramite_completado.emit(&"lesiones", null)

	# Assert — ODAC es obligación: ni saldo ni acumulador se mueven.
	assert_float(eco.saldo_eur).is_equal_approx(3000.0, 0.0001)
	assert_float(eco.ingreso_doc_dia).is_equal_approx(0.0, 0.0001)
