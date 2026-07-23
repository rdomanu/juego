# Story 004 (epic tiempo) — AC-T19 [Integration]: un oyente suscrito al EventBus REAL recibe exactamente
# UNA notificación de cambio_de_turno(TARDE) cuando el reloj cruza 15:00. · TR-time-006 · ADR-0001
# Usa el AUTOLOAD real `EventBus` (integración de verdad) -> el test DESCONECTA su oyente al terminar
# para no contaminar otros tests (aislamiento, test-standards).
extends GdUnitTestSuite

const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")

const TARDE: int = 1


func test_oyente_del_bus_real_recibe_un_solo_aviso_tarde() -> void:
	# Arrange — reloj apuntando al autoload real; oyente conectado a la señal real.
	var t: Node = auto_free(TiempoScript.new())
	t.usar_bus(EventBus)
	t.minutos_juego = 899.7
	t.sincronizar_umbrales()
	var recibidos: Array = []
	var oyente: Callable = func(turno: int) -> void: recibidos.append(turno)
	EventBus.cambio_de_turno.connect(oyente)

	# Act — cruza 15:00 (el par avanzar+procesar que ejecutará el tick real).
	var antes: float = t.minutos_juego
	t.minutos_juego = 900.3
	t._procesar_cruces(antes)

	# Cleanup ANTES de assertar (si un assert falla, el oyente no debe quedar colgado en el autoload).
	EventBus.cambio_de_turno.disconnect(oyente)

	# Assert — exactamente una notificación, con TARDE.
	assert_array(recibidos).contains_exactly([TARDE])
