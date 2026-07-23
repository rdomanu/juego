# Nodo-espía Persist para los tests de recolección de SaveManager (Story 002).
# Un `Node` con `name` fijado por el test y un `save()` que devuelve un dict CONSTANTE conocido.
#
# Se usa un script real (no un lambda) porque el manager comprueba `has_method("save")`: un método declarado
# en el script SÍ cuenta como método del nodo; un lambda asignado a una var NO lo haría.
extends Node

## Dict constante que devolverá `save()`. El test lo fija antes de recolectar.
var datos_save: Dictionary = {}


## Contrato Persist: devuelve el estado serializable de este nodo (aquí, el dict inyectado por el test).
func save() -> Dictionary:
	return datos_save
