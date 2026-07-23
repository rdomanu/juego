# Story 001 (epic economia) — núcleo: config data-driven, saldo y gates · TR-economy-004 · ADR-0001/0002.
# Tipo: Logic. DETERMINISTA (sin azar, sin reloj, config inyectado; solo un test toca el .tres real).
# Aislamiento: bus ESPÍA propio (instancia fresca del script del bus vía usar_bus); nodo con .new() sin
# árbol (no corre _ready → no carga el .tres real salvo en el test que lo verifica).
extends GdUnitTestSuite

const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Economía fresca con config default aplicado y bus espía propio.
func _economia(bus: Node = null) -> Node:
	var eco: Node = auto_free(EconomiaScript.new())
	if bus != null:
		eco.usar_bus(bus)
	eco.aplicar_config(ConfigEconomiaScript.new())
	return eco


# ── AC-1 / AC-E17: el saldo inicial viene del config (data-driven, sin tocar código) ──────
func test_saldo_inicial_viene_del_config() -> void:
	# Arrange — config custom con caja 5000.
	var config: Resource = ConfigEconomiaScript.new()
	config.caja_inicial_eur = 5000.0
	var eco: Node = auto_free(EconomiaScript.new())

	# Act
	eco.aplicar_config(config)

	# Assert
	assert_float(eco.saldo_eur).is_equal_approx(5000.0, 0.0001)


# ── AC-3 / AC-E07: sin caja suficiente, el gasto voluntario se rechaza y el saldo no muta ─
func test_cobrar_sin_caja_se_rechaza_y_no_muta() -> void:
	# Arrange — saldo 400, coste 500.
	var eco: Node = _economia()
	eco.saldo_eur = 400.0

	# Act
	var resultado: bool = eco.cobrar(500.0)

	# Assert — rechazado, saldo intacto.
	assert_bool(resultado).is_false()
	assert_float(eco.saldo_eur).is_equal_approx(400.0, 0.0001)
	assert_bool(eco.puede_pagar(500.0)).is_false()


# ── AC-4 / AC-E08: con caja, el gasto descuenta ───────────────────────────────────────────
func test_cobrar_con_caja_descuenta() -> void:
	# Arrange — saldo 600, coste 500.
	var eco: Node = _economia()
	eco.saldo_eur = 600.0

	# Act
	var resultado: bool = eco.cobrar(500.0)

	# Assert
	assert_bool(resultado).is_true()
	assert_float(eco.saldo_eur).is_equal_approx(100.0, 0.0001)


# ── AC-5: abonar suma y emite saldo_cambiado por el bus inyectado ─────────────────────────
func test_abonar_suma_y_emite_saldo_cambiado() -> void:
	# Arrange — bus espía propio; los lambdas capturan por valor → Array por referencia.
	var bus: Node = auto_free(EventBusScript.new())
	var saldos: Array = []
	bus.saldo_cambiado.connect(func(s: float) -> void: saldos.append(s))
	var eco: Node = _economia(bus)

	# Act
	eco.abonar(100.0)

	# Assert — saldo 3000 (default) + 100, y UNA emisión con el nuevo saldo.
	assert_float(eco.saldo_eur).is_equal_approx(3100.0, 0.0001)
	assert_array(saldos).contains_exactly([3100.0])


# ── AC-2 (clamp): un knob corrupto se clampa a 0 con aviso, sin romper ────────────────────
func test_config_fuera_de_rango_clampa_con_aviso() -> void:
	# Arrange — interés negativo (dato corrupto).
	var config: Resource = ConfigEconomiaScript.new()
	config.interes_deuda_diario = -0.5
	var eco: Node = auto_free(EconomiaScript.new())

	# Act — el push_warning esperado es intencional.
	eco.aplicar_config(config)

	# Assert
	assert_float(eco.interes_deuda_diario).is_equal_approx(0.0, 0.0001)


# ── AC-2: el .tres real existe y carga los 9 valores semilla del GDD ──────────────────────
func test_tres_real_existe_y_carga_defaults() -> void:
	# Arrange / Act — cargar el recurso real generado por la herramienta.
	var config: Resource = load("res://datos/config/economia.tres")

	# Assert — existe, es del tipo correcto y trae las semillas exactas del GDD.
	assert_object(config).is_not_null()
	assert_bool(config is ConfigEconomiaScript).is_true()
	assert_float(config.caja_inicial_eur).is_equal_approx(3000.0, 0.0001)
	assert_float(config.interes_deuda_diario).is_equal_approx(0.02, 0.0001)
	assert_float(config.deuda_max_eur).is_equal_approx(1000.0, 0.0001)
	assert_float(config.importe_prestamo_eur).is_equal_approx(1500.0, 0.0001)
	assert_float(config.penalizacion_fija_prestamo).is_equal_approx(30.0, 0.0001)
	assert_float(config.pct_ingreso_prestamo).is_equal_approx(0.20, 0.0001)
	assert_int(config.num_prestamos_max).is_equal(3)
	assert_float(config.ventana_gracia_insolvencia_horas).is_equal_approx(12.0, 0.0001)
	assert_float(config.umbral_holgura_ui).is_equal_approx(500.0, 0.0001)
