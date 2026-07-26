class_name EventoDivision extends Resource
## EventoDivision — un comunicado estacional de la **División de Documentación** (el órgano superior
## que coordina las unidades de Doc de toda España, DO2). Cuando uno está activo, la División
## **AUTORIZA** ampliar el horario más allá del tope ordinario por un pico de trabajo previsto
## (vacaciones → pasaportes; colapso de extranjería → TIE).
##
## ⚠️ **Autoriza, no obliga**: el evento solo sube el techo del slider. Ampliar (y pagar la peonada)
## sigue siendo decisión del jugador — Pilar 4.
##
## Solo estructura (`@export`): CERO lógica (la activación por mes la hace Documentación #8).
##
## Story: production/epics/documentacion/story-004-eventos-division-persistencia.md · TR-doc-002 · ADR-0003

## Identificador único del evento (`vacaciones`, `colapso_extranjeria`…).
@export var id: StringName
## Nombre del comunicado tal y como se le enseña al jugador ("Periodo vacacional").
@export var nombre: String
## El texto del comunicado: qué pasa y qué autoriza la División.
@export var descripcion: String
## Meses del calendario [1, 12] en los que el evento está vigente. Determinista a propósito (decisión
## del usuario 2026-07-26): la estacionalidad se aprende, no se sortea.
@export var meses: Array[int] = []
## Trámite que provoca el pico (`pasaporte`, `tie`) — referencia por `id` al catálogo de trámites.
@export var tramite_destacado: StringName
## Hora máxima de cierre AUTORIZADA mientras dure, en minutos del día (1290 = 21:30). Sustituye al
## `slider_max_min` ordinario de la config mientras el evento esté activo.
@export var cierre_max_min: int = 1290
