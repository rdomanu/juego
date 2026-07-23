# Story 005 (epic economia) — estados financieros e insolvencia · TR-economy-003 · ADR-0001.
# Tipo: Logic. DETERMINISTA: la gracia cuenta MINUTOS DE JUEGO inyectados (avanzar_gracia), nunca reloj
# real. Aislamiento: bus espía propio + RELOJ REAL INYECTADO como instancia propia (preload de tiempo.gd
# con .new() — permite assertar la pausa/reanudación de verdad sin tocar los autoloads).
# Para forzar movimientos se fija el saldo y se llama _emitir_saldo() (el punto de choque de transiciones).
extends GdUnitTestSuite

const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")

const PAUSA: int = 0
const X1: int = 1


# ── Helper de fixture ────────────────────────────────────────────────────────────────────
## Economía con bus espía y reloj propio (a 1×). Devuelve [eco, bus, tiempo].
func _fixture() -> Array:
	var bus: Node = auto_free(EventBusScript.new())
	var tiempo: Node = auto_free(TiempoScript.new())
	var eco: Node = auto_free(EconomiaScript.new())
	eco.usar_bus(bus)
	eco.usar_tiempo(tiempo)
	eco.aplicar_config(ConfigEconomiaScript.new())
	return [eco, bus, tiempo]


## Fuerza un movimiento del saldo por el punto de choque (procesa transiciones).
func _mover_saldo(eco: Node, nuevo_saldo: float) -> void:
	eco.saldo_eur = nuevo_saldo
	eco._emitir_saldo()


# ── Transiciones: entrar/salir de rojos emite UNA vez cada una ────────────────────────────
func test_transiciones_emiten_deuda_una_vez() -> void:
	# Arrange — espías de deuda; flujo REAL: nómina hunde, abono rescata.
	var f: Array = _fixture()
	var eco: Node = f[0]
	var eventos: Array = []
	f[1].entro_en_deuda.connect(func(_s: float) -> void: eventos.append("entra"))
	f[1].salio_de_deuda.connect(func(_s: float) -> void: eventos.append("sale"))
	eco.saldo_eur = 50.0
	eco.fijar_plantilla([&"ag_doc", &"ag_doc", &"ag_odac"] as Array[StringName])

	# Act — cierre (−140, entra en rojos) + otro movimiento en rojos + abono que rescata (+60).
	eco._al_nuevo_dia()
	eco.registrar_horas_extra(0.0)
	eco.abonar(200.0)

	# Assert — exactamente una entrada y una salida.
	assert_array(eventos).contains_exactly(["entra", "sale"])


# ── AC-E14: tocar el suelo con préstamos pausa el juego y emite `insolvencia` (no game over) ─
func test_suelo_con_prestamos_pausa_y_emite_insolvencia() -> void:
	# Arrange
	var f: Array = _fixture()
	var eco: Node = f[0]
	var insolvencias: Array = []
	var finales: Array = []
	f[1].insolvencia.connect(func(_s: float, restantes: int) -> void: insolvencias.append(restantes))
	f[1].game_over.connect(func(_m: StringName) -> void: finales.append("fin"))

	# Act — cruce del suelo (−1200 ≤ −1000).
	_mover_saldo(eco, -1200.0)

	# Assert — pausa real del reloj, modal ofrecido con 3 restantes, sin game over.
	assert_int(f[2].velocidad_actual).is_equal(PAUSA)
	assert_array(insolvencias).contains_exactly([3])
	assert_array(finales).is_empty()
	assert_bool(eco._esperando_decision).is_true()


# ── AC-E14a: aceptar el rescate inyecta el préstamo y reanuda ─────────────────────────────
func test_aceptar_rescate_inyecta_y_sale_del_suelo() -> void:
	# Arrange — en el suelo, modal ofrecido.
	var f: Array = _fixture()
	var eco: Node = f[0]
	_mover_saldo(eco, -1200.0)

	# Act
	var resultado: bool = eco.aceptar_rescate()

	# Assert — +1500 (sale del suelo), strike gastado, juego reanudado a la última velocidad (1×).
	assert_bool(resultado).is_true()
	assert_float(eco.saldo_eur).is_equal_approx(300.0, 0.0001)
	assert_int(eco.prestamos_usados).is_equal(1)
	assert_int(f[2].velocidad_actual).is_equal(X1)


# ── AC-E14b: rechazar → gracia de 720 min de juego; al expirar aún en el suelo → auto-préstamo ─
func test_gracia_expira_inyecta_automatico() -> void:
	# Arrange
	var f: Array = _fixture()
	var eco: Node = f[0]
	var gracias: Array = []
	f[1].gracia_iniciada.connect(func(minutos: float) -> void: gracias.append(minutos))
	_mover_saldo(eco, -1200.0)

	# Act — rechaza (12 h × 60 = 720 min) y el tiempo de juego pasa.
	eco.rechazar_rescate()
	eco.avanzar_gracia(719.0)
	var aun_en_gracia: bool = eco.en_gracia
	eco.avanzar_gracia(2.0)

	# Assert — gracia anunciada; a los 719 min seguía viva; al expirar, préstamo automático.
	assert_array(gracias).contains_exactly([720.0])
	assert_bool(aun_en_gracia).is_true()
	assert_bool(eco.en_gracia).is_false()
	assert_int(eco.prestamos_usados).is_equal(1)
	assert_float(eco.saldo_eur).is_equal_approx(300.0, 0.0001)


# ── AC-E14c: remontar durante la gracia cancela el rescate sin gastar préstamo ────────────
func test_gracia_remontada_cancela_rescate() -> void:
	# Arrange — en gracia.
	var f: Array = _fixture()
	var eco: Node = f[0]
	_mover_saldo(eco, -1200.0)
	eco.rechazar_rescate()

	# Act — entran ingresos que suben por encima del suelo.
	eco.abonar(2000.0)
	eco.avanzar_gracia(9999.0)

	# Assert — gracia cancelada, ningún strike gastado.
	assert_bool(eco.en_gracia).is_false()
	assert_int(eco.prestamos_usados).is_equal(0)


# ── AC-E13: el suelo sin préstamos es game over (sin modal ni gracia) ─────────────────────
func test_suelo_sin_prestamos_game_over() -> void:
	# Arrange — los 3 strikes gastados.
	var f: Array = _fixture()
	var eco: Node = f[0]
	eco.prestamos_usados = 3
	var insolvencias: Array = []
	var finales: Array = []
	f[1].insolvencia.connect(func(_s: float, _r: int) -> void: insolvencias.append("modal"))
	f[1].game_over.connect(func(motivo: StringName) -> void: finales.append(motivo))

	# Act
	_mover_saldo(eco, -1200.0)

	# Assert — game over directo, sin modal, juego pausado y partida terminada.
	assert_array(insolvencias).is_empty()
	assert_array(finales).contains_exactly([&"insolvencia_sin_prestamos"])
	assert_bool(eco.partida_terminada).is_true()
	assert_int(f[2].velocidad_actual).is_equal(PAUSA)


# ── AC-E14d: num_prestamos_max = 0 → game over al primer cruce (modo difícil válido) ──────
func test_max_cero_game_over_inmediato() -> void:
	# Arrange — config sin salvavidas.
	var config: Resource = ConfigEconomiaScript.new()
	config.num_prestamos_max = 0
	var bus: Node = auto_free(EventBusScript.new())
	var eco: Node = auto_free(EconomiaScript.new())
	eco.usar_bus(bus)
	eco.aplicar_config(config)
	var finales: Array = []
	bus.game_over.connect(func(_m: StringName) -> void: finales.append("fin"))

	# Act
	_mover_saldo(eco, -1200.0)

	# Assert
	assert_array(finales).contains_exactly(["fin"])


# ── AC-E14e: 3 preventivos en positivo agotan la red → el cruce posterior es game over ────
func test_preventivos_agotados_game_over() -> void:
	# Arrange — pide 3 en positivo (permitido; gasta strikes).
	var f: Array = _fixture()
	var eco: Node = f[0]
	eco.pedir_prestamo()
	eco.pedir_prestamo()
	eco.pedir_prestamo()
	var finales: Array = []
	f[1].game_over.connect(func(_m: StringName) -> void: finales.append("fin"))

	# Act — más tarde, el saldo cruza el suelo.
	_mover_saldo(eco, -1200.0)

	# Assert — agotó la red: te echan.
	assert_int(eco.prestamos_usados).is_equal(3)
	assert_array(finales).contains_exactly(["fin"])
