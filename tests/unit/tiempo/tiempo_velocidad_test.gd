# Story 006 (epic tiempo) — máquina de velocidad {PAUSA, X1, X2, X3} + velocidad_cambiada ·
# TR-time-002 · ADR-0001. Selector directo; multiplicador DERIVADO del estado (PAUSA→0); cambiar de
# velocidad NO altera minutos_juego; reanudar vuelve a la última velocidad de juego. Tipo: Logic.
# DETERMINISTA (máquina de estados pura + espía del bus; sin reloj real, sin azar).
#
# Aislamiento: el reloj bajo test recibe un EventBus PROPIO (instancia fresca del script del bus vía
# `usar_bus()`) → nunca se toca el autoload real. Las lambdas espía apuntan a un Array local (las lambdas
# capturan locales POR VALOR → el Array, por referencia, sí acumula — gotcha del proyecto).
extends GdUnitTestSuite

const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

const PAUSA: int = 0
const X1: int = 1
const X2: int = 2
const X3: int = 3


# ── Helper de fixture ────────────────────────────────────────────────────────────────────
## Reloj fresco con bus propio inyectado. Sin árbol (no corre `_ready`); arranca con los defaults
## (velocidad_actual X1, mult 1). Cada test ajusta lo que necesite.
func _tiempo(bus: Node) -> Node:
	var t: Node = auto_free(TiempoScript.new())
	t.usar_bus(bus)
	return t


# ── AC-T04: PAUSA deriva multiplicador 0 → avanzar no mueve minutos_juego ──────────────────
func test_pausa_deriva_mult_0_no_avanza() -> void:
	# Arrange — reloj a alguna hora; se fija PAUSA.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo(bus)
	t.minutos_juego = 100.0
	t.fijar_velocidad(t.Velocidad.PAUSA)

	# Assert (parcial) — el multiplicador derivado de PAUSA es 0.
	assert_int(t.multiplicador_velocidad).is_equal(0)

	# Act — cualquier delta positivo.
	t.avanzar(1.0)

	# Assert — minutos_juego no cambia (mult 0 → incremento 0).
	assert_float(t.minutos_juego).is_equal_approx(100.0, 0.001)


# ── AC-T30: cambiar de 3× a 1× NO altera minutos_juego ya transcurrido ─────────────────────
func test_cambiar_velocidad_no_altera_minutos() -> void:
	# Arrange — 3× con 500,0 min ya transcurridos.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo(bus)
	t.fijar_velocidad(t.Velocidad.X3)
	t.minutos_juego = 500.0

	# Act — el jugador cambia a 1×.
	t.fijar_velocidad(t.Velocidad.X1)

	# Assert — sigue en 500,0 (ni pierde ni gana) y el multiplicador pasa a 1.
	assert_float(t.minutos_juego).is_equal_approx(500.0, 0.001)
	assert_int(t.multiplicador_velocidad).is_equal(1)
	assert_int(t.velocidad_actual).is_equal(X1)


# ── AC-T31: reanudar desde Pausa vuelve a la ÚLTIMA velocidad de juego (3×) ─────────────────
func test_reanudar_vuelve_a_ultima_velocidad() -> void:
	# Arrange — estaba en 3×, entra en Pausa.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo(bus)
	t.fijar_velocidad(t.Velocidad.X3)
	t.fijar_velocidad(t.Velocidad.PAUSA)
	assert_int(t.velocidad_actual).is_equal(PAUSA)   # sanity: está en Pausa

	# Act — reanuda.
	t.reanudar()

	# Assert — vuelve a 3× (entrar en Pausa no pisó la última velocidad de juego).
	assert_int(t.velocidad_actual).is_equal(X3)
	assert_int(t.multiplicador_velocidad).is_equal(3)


# ── AC-T31 (excepción): sin velocidad previa (default) → reanudar va a 1× ───────────────────
func test_reanudar_sin_velocidad_previa_va_a_1x() -> void:
	# Arrange — reloj recién puesto en Pausa sin haber elegido antes una velocidad de juego
	# (simula el estado tras cargar, H8: arranca en Pausa, _ultima_velocidad_de_juego en default X1).
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo(bus)
	t.fijar_velocidad(t.Velocidad.PAUSA)

	# Act — reanuda sin haber fijado nunca una velocidad de juego en esta sesión.
	t.reanudar()

	# Assert — va a 1× (default de _ultima_velocidad_de_juego).
	assert_int(t.velocidad_actual).is_equal(X1)
	assert_int(t.multiplicador_velocidad).is_equal(1)


# ── AC-T32: cambiar de velocidad emite velocidad_cambiada UNA vez, con el nuevo valor ───────
func test_cambio_velocidad_emite_una_vez() -> void:
	# Arrange — espía del bus propio (Array local por referencia).
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo(bus)
	var indices: Array = []
	bus.velocidad_cambiada.connect(func(indice: int) -> void: indices.append(indice))

	# Act — X1 (default) → X2 → PAUSA.
	t.fijar_velocidad(t.Velocidad.X2)
	t.fijar_velocidad(t.Velocidad.PAUSA)

	# Assert — exactamente 2 emisiones, en orden, con los nuevos valores (una por acción efectiva).
	assert_array(indices).contains_exactly([X2, PAUSA])


# ── AC-T32 (una vez por acción): re-seleccionar la MISMA velocidad no re-emite ──────────────
func test_reseleccionar_misma_velocidad_no_reemite() -> void:
	# Arrange — espía; se fija X2.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo(bus)
	var indices: Array = []
	bus.velocidad_cambiada.connect(func(indice: int) -> void: indices.append(indice))
	t.fijar_velocidad(t.Velocidad.X2)

	# Act — re-seleccionar X2 (sin cambio efectivo).
	t.fijar_velocidad(t.Velocidad.X2)

	# Assert — solo la primera emisión (X2); la re-selección no re-emite.
	assert_array(indices).contains_exactly([X2])


# ── Contrato del bus: la señal velocidad_cambiada existe con la firma esperada ──────────────
func test_bus_expone_senal_velocidad_cambiada() -> void:
	# Arrange — instancia fresca del bus.
	var bus: Node = auto_free(EventBusScript.new())

	# Assert — la señal existe (evita regresiones del contrato añadido en la Story 006).
	assert_bool(bus.has_signal("velocidad_cambiada")).is_true()
