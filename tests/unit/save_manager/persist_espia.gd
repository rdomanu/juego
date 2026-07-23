# Nodo-espía Persist para los tests de SaveManager: recolección (Story 002) y distribución (Story 005).
# Un `Node` con `name` fijado por el test, un `save()` que devuelve un dict CONSTANTE conocido y un
# `load_state(d)` que REGISTRA lo recibido para que el test verifique qué sub-dict le tocó.
#
# Se usa un script real (no un lambda) porque el manager comprueba `has_method("save")`/`has_method("load_state")`:
# un método declarado en el script SÍ cuenta como método del nodo; un lambda asignado a una var NO lo haría.
extends Node

## Dict constante que devolverá `save()`. El test lo fija antes de recolectar (Story 002).
var datos_save: Dictionary = {}

## Espionaje de la distribución (Story 005): último dict recibido por `load_state` y cuántas veces se llamó.
## Empiezan en "no llamado" para poder distinguir "recibió {} " de "no fue llamado" (AC-DT02).
var estado_recibido: Dictionary = {}
var load_state_llamado: bool = false
var load_state_veces: int = 0


## Contrato Persist (recolección): devuelve el estado serializable de este nodo (el dict inyectado por el test).
func save() -> Dictionary:
	return datos_save


## Contrato Persist (distribución): registra el sub-dict recibido para que el test lo verifique. NO emite nada
## (blinda AC-DT04: el manager no re-dispara eventos y este espía tampoco añade emisiones espurias).
func load_state(d: Dictionary) -> void:
	estado_recibido = d
	load_state_llamado = true
	load_state_veces += 1
