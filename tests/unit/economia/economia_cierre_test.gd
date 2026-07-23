# Story 003 (epic economia) — cierre diario: recargo → gastos → reset · TR-economy-002 · ADR-0001.
# Tipo: Logic. DETERMINISTA. Los tests llaman `_al_nuevo_dia()` directo (patrón del proyecto; el registro
# en el dispatcher a prioridad 20 es de runtime). Salarios/peonada del CATÁLOGO REAL (60/70, 15 €/h).
extends GdUnitTestSuite

const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

## Dotación estándar del GDD: 2 ag_doc (60) + 1 ag_odac (70) = 190 €/jornada.
var PLANTILLA_ESTANDAR: Array[StringName] = [&"ag_doc", &"ag_doc", &"ag_odac"]


# ── Helper de fixture ────────────────────────────────────────────────────────────────────
func _economia() -> Node:
	var eco: Node = auto_free(EconomiaScript.new())
	eco.usar_bus(auto_free(EventBusScript.new()))
	eco.aplicar_config(ConfigEconomiaScript.new())
	return eco


# ── AC-E05: la nómina estándar descuenta 190 € al cierre ──────────────────────────────────
func test_nomina_estandar_descuenta_190() -> void:
	# Arrange
	var eco: Node = _economia()
	eco.fijar_plantilla(PLANTILLA_ESTANDAR)

	# Act
	eco._al_nuevo_dia()

	# Assert — 3000 − 190.
	assert_float(eco.saldo_eur).is_equal_approx(2810.0, 0.0001)


# ── AC-E06: 3 horas extra a 15 €/h son 45 € ───────────────────────────────────────────────
func test_tres_horas_extra_son_45() -> void:
	# Arrange — sin plantilla (solo peonada).
	var eco: Node = _economia()
	eco.registrar_horas_extra(3.0)

	# Act
	eco._al_nuevo_dia()

	# Assert — 3000 − 45.
	assert_float(eco.saldo_eur).is_equal_approx(2955.0, 0.0001)


# ── AC-E09: entrar en rojos por la nómina NO genera recargo ese día, y bloquea el gasto ───
func test_entrar_en_rojos_sin_recargo_el_primer_dia() -> void:
	# Arrange — apertura +50 (positiva), nómina 190.
	var eco: Node = _economia()
	eco.saldo_eur = 50.0
	eco.fijar_plantilla(PLANTILLA_ESTANDAR)

	# Act
	eco._al_nuevo_dia()

	# Assert — exactamente −140 (sin recargo: la apertura era ≥ 0) y gate bloqueado.
	assert_float(eco.saldo_eur).is_equal_approx(-140.0, 0.0001)
	assert_bool(eco.puede_pagar(100.0)).is_false()


# ── AC-E10: el recargo va sobre la deuda de APERTURA ──────────────────────────────────────
func test_recargo_sobre_apertura() -> void:
	# Arrange — apertura −500, sin obligaciones, interés 0.02.
	var eco: Node = _economia()
	eco.saldo_eur = -500.0

	# Act
	eco._al_nuevo_dia()

	# Assert — −500 − 10 = −510.
	assert_float(eco.saldo_eur).is_equal_approx(-510.0, 0.0001)


# ── AC-E10b: el recargo es COMPUESTO día a día ────────────────────────────────────────────
func test_recargo_compuesto_dos_dias() -> void:
	# Arrange
	var eco: Node = _economia()
	eco.saldo_eur = -500.0

	# Act — dos cierres consecutivos.
	eco._al_nuevo_dia()
	eco._al_nuevo_dia()

	# Assert — −510 → −520,20 (2 % sobre −510).
	assert_float(eco.saldo_eur).is_equal_approx(-520.2, 0.001)


# ── AC-E10c: ORDEN de F6 — el recargo se evalúa ANTES de los gastos de hoy ────────────────
func test_orden_recargo_antes_de_gastos() -> void:
	# Arrange — apertura +20 (positiva), nómina 190.
	var eco: Node = _economia()
	eco.saldo_eur = 20.0
	eco.fijar_plantilla(PLANTILLA_ESTANDAR)

	# Act
	eco._al_nuevo_dia()

	# Assert — recargo 0 (apertura ≥ 0) → gastos → −170 exacto; el recargo de esos −170 es de mañana.
	assert_float(eco.saldo_eur).is_equal_approx(-170.0, 0.0001)


# ── Reset: los acumuladores del día se reinician al cierre ────────────────────────────────
func test_reset_de_acumuladores_al_cierre() -> void:
	# Arrange — ingreso del día + horas extra pendientes.
	var bus: Node = auto_free(EventBusScript.new())
	var eco: Node = auto_free(EconomiaScript.new())
	eco.usar_bus(bus)
	eco.aplicar_config(ConfigEconomiaScript.new())
	bus.tramite_completado.emit(&"dni", null)
	eco.registrar_horas_extra(2.0)

	# Act
	eco._al_nuevo_dia()

	# Assert — ambos acumuladores a 0 (listos para el día siguiente).
	assert_float(eco.ingreso_doc_dia).is_equal_approx(0.0, 0.0001)
	assert_float(eco._horas_extra_dia).is_equal_approx(0.0, 0.0001)
