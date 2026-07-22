class_name TipoAgente extends Resource
## TipoAgente — definición (read-only) de un tipo/perfil de agente contratable.
##
## Describe un puesto orgánico del CNP (unidad, escala/rango, salario, horario) y qué puestos puede operar.
## Referencia los puestos operables por `id` (`Array[StringName]`), NUNCA anidando Resources (ADR-0003).
##
## Solo estructura (`@export`): CERO lógica. Carga en Story 002, contenido en Story 004.
##
## Story: production/epics/datos/story-001-esquema-clases-resource.md (TR-data-002) · ADR-0003

## Identificador único de la definición (clave de lookup en el autoload Datos — Story 002).
@export var id: StringName
## Puesto orgánico (p. ej. "Funcionario de Documentación"); hace también de nombre visible del perfil.
@export var puesto_organico: String
## Unidad a la que pertenece el agente.
@export var unidad: String
## Escala y rango del agente (jerarquía del CNP).
@export var escala_rango: String
## Salario diario del agente, en euros.
@export var salario_dia_eur: int
## Régimen horario del agente.
@export_enum("turnos", "complementario", "guardia") var tipo_horario: String
## `id`s de los `TipoPuesto` que este perfil de agente puede operar (referencias por id, no Resources anidados).
@export var puestos_operables: Array[StringName]
