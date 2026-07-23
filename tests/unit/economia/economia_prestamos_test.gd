# Story 004 (epic economia) — préstamos del Comisario: strikes, penalización híbrida, devolución ·
# TR-economy-003 · ADR-0001. Tipo: Logic. DETERMINISTA. Bus espía propio; cierre llamado directo.
# Knobs del config default: importe 1500 · fija 30 · pct 0.20 · max 3.
extends GdUnitTestSuite

const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")


# ── Helper de fixture ────────────────────────────────────────────────────────────────────
func _economia(bus: Node = null) -> Node:
	var eco: Node = auto_free(EconomiaScript.new())
	eco.usar_bus(bus if bus != null else auto_free(EventBusScript.new()))
	eco.aplicar_config(ConfigEconomiaScript.new())
	return eco


# ── AC-E11 (+preventivo): pedir inyecta 1500, cuenta strike y emite prestamo_pedido ───────
func test_pedir_prestamo_inyecta_y_cuenta_strike() -> void:
	# Arrange — en POSITIVO (uso preventivo permitido, gasta strike igual — Edge Case del GDD).
	var bus: Node = auto_free(EventBusScript.new())
	var avisos: Array = []
	bus.prestamo_pedido.connect(func(usados: int, vivos: int) -> void: avisos.append([usados, vivos]))
	var eco: Node = _economia(bus)

	# Act
	var resultado: bool = eco.pedir_prestamo()

	# Assert — +1500, strike y vivo contados, aviso emitido una vez.
	assert_bool(resultado).is_true()
	assert_float(eco.saldo_eur).is_equal_approx(4500.0, 0.0001)
	assert_int(eco.prestamos_usados).is_equal(1)
	assert_int(eco.prestamos_vivos).is_equal(1)
	assert_array(avisos).contains_exactly([[1, 1]])


# ── Límite de strikes: con usados == max se rechaza ───────────────────────────────────────
func test_pedir_al_limite_se_rechaza() -> void:
	# Arrange — los 3 salvavidas ya gastados.
	var eco: Node = _economia()
	eco.prestamos_usados = 3

	# Act
	var resultado: bool = eco.pedir_prestamo()

	# Assert — rechazado, nada cambia.
	assert_bool(resultado).is_false()
	assert_float(eco.saldo_eur).is_equal_approx(3000.0, 0.0001)
	assert_int(eco.prestamos_usados).is_equal(3)


# ── AC-E12: penalización híbrida con 2 vivos e ingreso 230 → 152 € al cierre ──────────────
func test_penalizacion_hibrida_dos_vivos() -> void:
	# Arrange — 2 × (30 + 0.20 × 230) = 152.
	var eco: Node = _economia()
	eco.prestamos_usados = 2
	eco.prestamos_vivos = 2
	eco.ingreso_doc_dia = 230.0

	# Act
	eco._al_nuevo_dia()

	# Assert — 3000 − 152.
	assert_float(eco.saldo_eur).is_equal_approx(2848.0, 0.0001)


# ── AC-E12b: día sin ingresos → solo la parte fija (la mordida % auto-escala) ─────────────
func test_penalizacion_dia_sin_ingresos_solo_fija() -> void:
	# Arrange — 1 × (30 + 0.20 × 0) = 30.
	var eco: Node = _economia()
	eco.prestamos_usados = 1
	eco.prestamos_vivos = 1
	eco.ingreso_doc_dia = 0.0

	# Act
	eco._al_nuevo_dia()

	# Assert
	assert_float(eco.saldo_eur).is_equal_approx(2970.0, 0.0001)


# ── AC-E14f: saldar devuelve el principal y NO recupera el strike ─────────────────────────
func test_saldar_no_recupera_strike() -> void:
	# Arrange
	var eco: Node = _economia()
	eco.prestamos_usados = 2
	eco.prestamos_vivos = 2
	eco.saldo_eur = 1600.0

	# Act
	var resultado: bool = eco.saldar_prestamo()

	# Assert — saldo 100, un vivo menos, strikes intactos.
	assert_bool(resultado).is_true()
	assert_float(eco.saldo_eur).is_equal_approx(100.0, 0.0001)
	assert_int(eco.prestamos_vivos).is_equal(1)
	assert_int(eco.prestamos_usados).is_equal(2)


# ── AC-E14g: un préstamo saldado deja de penalizar en el siguiente cierre ─────────────────
func test_saldado_deja_de_penalizar() -> void:
	# Arrange — 1 vivo que se salda (3000 ≥ 1500).
	var eco: Node = _economia()
	eco.prestamos_usados = 1
	eco.prestamos_vivos = 1
	eco.saldar_prestamo()

	# Act — cierre sin plantilla ni horas: si aún penalizara, bajaría 30.
	eco._al_nuevo_dia()

	# Assert — 1500 intactos (0 vivos → 0 penalización).
	assert_float(eco.saldo_eur).is_equal_approx(1500.0, 0.0001)


# ── AC-E14h: saldar sin caja suficiente o sin vivos se rechaza ────────────────────────────
func test_saldar_sin_caja_o_sin_vivos_se_rechaza() -> void:
	# Arrange 1 — con vivo pero saldo 1400 (< 1500).
	var eco: Node = _economia()
	eco.prestamos_usados = 1
	eco.prestamos_vivos = 1
	eco.saldo_eur = 1400.0

	# Act + Assert 1
	assert_bool(eco.saldar_prestamo()).is_false()
	assert_float(eco.saldo_eur).is_equal_approx(1400.0, 0.0001)

	# Arrange 2 — con caja pero sin vivos.
	var eco2: Node = _economia()
	eco2.saldo_eur = 3000.0

	# Act + Assert 2
	assert_bool(eco2.saldar_prestamo()).is_false()
	assert_float(eco2.saldo_eur).is_equal_approx(3000.0, 0.0001)
