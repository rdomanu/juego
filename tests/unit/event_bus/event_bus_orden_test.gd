# Story 002 (epic event-bus) — TR-bus-002 · ADR-0001
# Dispatcher de eventos ordenados por prioridad (registrar_ordenado / disparar_ordenado).
# Tipo: Logic (algoritmo de orden determinista). DETERMINISTA (sin RNG ni reloj real).
extends GdUnitTestSuite

const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

var _bus: Node


func before_test() -> void:
	_bus = auto_free(EventBusScript.new())


# AC-1: disparar_ordenado invoca en orden de prioridad ascendente.
func test_disparar_ordenado_invoca_en_prioridad_ascendente() -> void:
	# Arrange (registrados en orden 30, 10, 20 -> deben correr 10, 20, 30)
	var orden: Array = []
	_bus.registrar_ordenado(&"nuevo_dia", 30, func(): orden.append(30))
	_bus.registrar_ordenado(&"nuevo_dia", 10, func(): orden.append(10))
	_bus.registrar_ordenado(&"nuevo_dia", 20, func(): orden.append(20))
	# Act
	_bus.disparar_ordenado(&"nuevo_dia")
	# Assert
	assert_array(orden).contains_exactly([10, 20, 30])


# AC-1 (edge): los 4 handlers reales (10/20/30/40) en orden; evento sin registros no falla.
func test_cuatro_handlers_en_orden_y_evento_sin_registros_no_falla() -> void:
	# Arrange
	var orden: Array = []
	_bus.registrar_ordenado(&"nuevo_dia", 40, func(): orden.append(40))
	_bus.registrar_ordenado(&"nuevo_dia", 20, func(): orden.append(20))
	_bus.registrar_ordenado(&"nuevo_dia", 10, func(): orden.append(10))
	_bus.registrar_ordenado(&"nuevo_dia", 30, func(): orden.append(30))
	# Act
	_bus.disparar_ordenado(&"nuevo_dia")
	# Assert
	assert_array(orden).contains_exactly([10, 20, 30, 40])
	# Edge: disparar un evento sin callables registrados no debe fallar.
	_bus.disparar_ordenado(&"evento_inexistente")


# AC-2: misma prioridad -> desempate por orden de registro (estable, determinista).
func test_misma_prioridad_desempata_por_orden_de_registro() -> void:
	# Arrange (A, B, C todos con prioridad 20)
	var orden: Array = []
	_bus.registrar_ordenado(&"nuevo_mes", 20, func(): orden.append("A"))
	_bus.registrar_ordenado(&"nuevo_mes", 20, func(): orden.append("B"))
	_bus.registrar_ordenado(&"nuevo_mes", 20, func(): orden.append("C"))
	# Act
	_bus.disparar_ordenado(&"nuevo_mes")
	# Assert
	assert_array(orden).contains_exactly(["A", "B", "C"])


# AC-3: la senal de notificacion se emite DESPUES de los callables ordenados.
func test_senal_notificacion_se_emite_tras_los_callables_ordenados() -> void:
	# Arrange
	var secuencia: Array = []
	_bus.registrar_ordenado(&"nuevo_dia", 10, func(): secuencia.append("ordenado"))
	_bus.nuevo_dia.connect(func(): secuencia.append("senal"))
	# Act
	_bus.disparar_ordenado(&"nuevo_dia")
	# Assert
	assert_array(secuencia).contains_exactly(["ordenado", "senal"])


# AC-4: determinismo — la misma configuracion produce el mismo orden en ejecuciones repetidas.
func test_determinismo_mismo_orden_en_repeticiones() -> void:
	var ejecutar := func() -> Array:
		var bus2: Node = EventBusScript.new()
		var o: Array = []
		bus2.registrar_ordenado(&"nuevo_dia", 30, func(): o.append(30))
		bus2.registrar_ordenado(&"nuevo_dia", 10, func(): o.append(10))
		bus2.registrar_ordenado(&"nuevo_dia", 20, func(): o.append(20))
		bus2.disparar_ordenado(&"nuevo_dia")
		bus2.free()
		return o
	assert_array(ejecutar.call()).is_equal(ejecutar.call())
