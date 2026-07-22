class_name Escenario extends Resource
## Escenario — definición (read-only) de un escenario/nivel jugable (p. ej. la comisaría de Pozuelo).
##
## Fija el marco de una partida: población, servicios activos, rango requerido y los topes de construcción
## por tipo de puesto. Referencia puestos/servicios por `id` (`StringName`), NUNCA anidando Resources (ADR-0003).
##
## Solo estructura (`@export`): CERO lógica. Carga en Story 002, contenido en Story 004.
##
## Story: production/epics/datos/story-001-esquema-clases-resource.md (TR-data-002) · ADR-0003

## Identificador único de la definición (clave de lookup en el autoload Datos — Story 002).
@export var id: StringName
## Nombre visible (UI).
@export var nombre: String
## Nivel/dificultad narrativa del escenario (p. ej. "Nivel 1 — Comisaría Local").
@export var nivel: String
## Población del municipio que atiende (dimensiona la demanda).
@export var poblacion: int
## Tope de unidades construibles por `id` de `TipoPuesto` (p. ej. {&"puesto_doc_general": 8}). Dictionary
## tipado `[StringName, int]` (estable desde Godot 4.4): clave = id del puesto, valor = máximo permitido.
@export var tope_construible: Dictionary[StringName, int]
## Rango del jugador requerido para desbloquear/jugar el escenario (p. ej. "Subinspector").
@export var rango_requerido: String
## `id`s de los servicios activos en el escenario (referencias por id).
@export var servicios_activos: Array[StringName]
