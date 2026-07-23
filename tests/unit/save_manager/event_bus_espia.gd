# Espía del EventBus para el test de distribución de SaveManager (Story 005, AC-DT04).
#
# Es una INSTANCIA PROPIA del script del EventBus (NO el autoload real: no contaminamos el bus global; patrón de
# los tests de event-bus, que hacen `EventBusScript.new()`). El espía se conecta a TODAS las señales definidas por
# el usuario en el bus y cuenta cuántas emisiones se producen. La distribución del manager NO debe emitir nada:
# el contador debe quedar en 0 (el manager "sitúa, no reproduce"; y los espías Persist tampoco emiten).
#
# Robusto a la aridad: cada señal se conecta con `_contar.unbind(n)` para descartar sus argumentos (las señales
# del bus tienen 0..2 parámetros). Robusto a nuevas señales: enumera con `get_signal_list()` filtrando las
# heredadas de Object/Node (las del usuario NO tienen el flag METHOD_FLAG_OBJECT_CORE... — se filtran por nombre
# comparando contra las de un Node pelado).
extends Node

const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

## La instancia propia del bus (no el autoload). Los tests emiten/observan sobre ESTA.
var bus: Node

## Cuántas emisiones ha recibido el espía a través de CUALQUIER señal del usuario del bus.
var emisiones: int = 0

## Nombres de las señales a las que nos conectamos (para desconectar limpio en teardown).
var _conectadas: Array[String] = []


func _init() -> void:
	bus = EventBusScript.new()
	add_child(bus)   # el bus es hijo del espía → auto_free del espía lo libera con él.
	_conectar_todas()


## Conecta el contador a cada señal declarada por el USUARIO en el script del bus (no las heredadas de Node).
func _conectar_todas() -> void:
	var propias: Dictionary = _nombres_senales_heredadas()
	for info in bus.get_signal_list():
		var nombre: String = info["name"]
		if propias.has(nombre):
			continue   # señal heredada de Object/Node → no es del bus de juego.
		var n_args: int = (info["args"] as Array).size()
		# `.unbind(n_args)` descarta los argumentos de la señal → el contador acepta 0 args para todas.
		var cb: Callable = Callable(self, "_contar")
		if n_args > 0:
			cb = cb.unbind(n_args)
		bus.connect(nombre, cb)
		_conectadas.append(nombre)


## Devuelve el conjunto de nombres de señal que un `Node` pelado ya trae (heredadas) para poder EXCLUIRLAS.
func _nombres_senales_heredadas() -> Dictionary:
	var base := Node.new()
	var set_nombres: Dictionary = {}
	for info in base.get_signal_list():
		set_nombres[info["name"]] = true
	base.free()
	return set_nombres


## Incrementa el contador (cualquier emisión del bus pasa por aquí, sin importar la señal).
func _contar() -> void:
	emisiones += 1


## Desconecta todas las señales (aislamiento; aunque el bus sea una instancia propia, se limpia por higiene).
func desconectar() -> void:
	for nombre in _conectadas:
		var cb: Callable = Callable(self, "_contar")
		# Reconstruir el mismo callable con el mismo unbind para poder desconectar.
		var n_args: int = 0
		for info in bus.get_signal_list():
			if info["name"] == nombre:
				n_args = (info["args"] as Array).size()
				break
		if n_args > 0:
			cb = cb.unbind(n_args)
		if bus.is_connected(nombre, cb):
			bus.disconnect(nombre, cb)
	_conectadas.clear()
