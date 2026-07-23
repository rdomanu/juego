class_name Persona extends RefCounted
## Persona — la FICHA de una visita generada por Demanda (DG1): a qué servicio viene, a qué trámite
## concreto y cuándo llegó. CERO lógica: es un objeto de datos.
##
## Decisión de diseño (usuario, 2026-07-23): mientras Flujo #4 no existe, la Persona es esta "ficha de
## papel" tipada. Cuando se construya Flujo, ÉL la envolverá en su nodo con movimiento y colas — el
## movimiento es capa cosmética (ADR-0004: la lógica nunca lee la posición del sprite). Nada se tira.
##
## Story: production/epics/demanda/story-002-generador-determinista.md · TR-demand-001/002 · ADR-0001

## Servicio al que viene: `Demanda.SERVICIO_DOC` (&"Documentacion") o `Demanda.SERVICIO_ODAC` (&"ODAC").
var servicio: StringName = &""
## Id del trámite/denuncia del catálogo Datos (elegido por la mezcla F3). Referencia por id (ADR-0003).
var tramite_id: StringName = &""
## Minuto del día de juego en que se generó (lo estampa el generador F4).
var minuto_llegada: float = 0.0


func _init(p_servicio: StringName = &"", p_tramite_id: StringName = &"", p_minuto_llegada: float = 0.0) -> void:
	servicio = p_servicio
	tramite_id = p_tramite_id
	minuto_llegada = p_minuto_llegada
