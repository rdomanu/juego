# Story 001 (epic event-bus) — TR-bus-001 · ADR-0001
# Prueba el mecanismo emit/connect del EventBus (autoload + senales de aviso).
# Tipo: Integration (senales cross-system). DETERMINISTA (sin RNG ni reloj real).
# Convenciones: test_[escenario]_[esperado] (ver tests/README.md).
extends GdUnitTestSuite

const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

var _bus: Node


func before_test() -> void:
	# El EventBus es un Node; las senales funcionan en un nodo suelto (no hace falta arbol).
	_bus = auto_free(EventBusScript.new())


# AC-1: connect + emit -> el oyente recibe con los argumentos correctos.
func test_tramite_completado_entrega_argumentos_al_oyente() -> void:
	# Arrange
	var recibido: Array = []
	_bus.tramite_completado.connect(func(tid: StringName, _ag): recibido.append(tid))
	# Act
	_bus.tramite_completado.emit(&"dni", null)
	# Assert
	assert_array(recibido).contains_exactly([&"dni"])


# AC-2: las firmas tipadas entregan los valores correctos.
func test_senales_tipadas_entregan_los_valores_correctos() -> void:
	# Arrange
	var turnos: Array = []
	var noches: Array = []
	var saldos: Array = []
	_bus.cambio_de_turno.connect(func(t: int): turnos.append(t))
	_bus.cambio_dia_noche.connect(func(n: bool): noches.append(n))
	_bus.saldo_cambiado.connect(func(s: float): saldos.append(s))
	# Act
	_bus.cambio_de_turno.emit(1)
	_bus.cambio_dia_noche.emit(true)
	_bus.saldo_cambiado.emit(3000.0)
	# Assert
	assert_array(turnos).contains_exactly([1])
	assert_array(noches).contains_exactly([true])
	assert_array(saldos).contains_exactly([3000.0])


# AC-1 (edge): dos oyentes reciben; emitir sin oyentes no falla.
func test_varios_oyentes_reciben_y_sin_oyentes_no_falla() -> void:
	# Arrange (un Array, no un int: las lambdas capturan locales por valor)
	var golpes: Array = []
	_bus.abandono.connect(func(_p): golpes.append(1))
	_bus.abandono.connect(func(_p): golpes.append(1))
	# Act
	_bus.abandono.emit(null)
	# Assert
	assert_int(golpes.size()).is_equal(2)
	# Edge: emitir una senal sin oyentes no debe fallar.
	_bus.persona_generada.emit(null)
