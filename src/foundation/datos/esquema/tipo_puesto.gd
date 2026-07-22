class_name TipoPuesto extends Resource
## TipoPuesto — definición (read-only) de un tipo de puesto de trabajo de la comisaría.
##
## Un puesto es la estación donde un agente despacha `Atencion`es (p. ej. "puesto de Documentación general").
## Referencia las atenciones que admite por `id` (`Array[StringName]`), NUNCA anidando Resources (ADR-0003).
##
## Solo estructura (`@export`): CERO lógica. Carga en Story 002, contenido en Story 004.
##
## Story: production/epics/datos/story-001-esquema-clases-resource.md (TR-data-002) · ADR-0003

## Identificador único de la definición (clave de lookup en el autoload Datos — Story 002).
@export var id: StringName
## Nombre visible (UI).
@export var nombre: String
## Servicio del puesto. A diferencia de `Atencion`, aquí SÍ existe "Seguridad" (puesto_seguridad, GDD F3).
@export_enum("Documentacion", "ODAC", "Seguridad") var servicio: String
## `id`s de las `Atencion`es que este puesto puede despachar (referencias por id, no Resources anidados).
@export var atenciones_admitidas: Array[StringName]
## Si el puesto puede reconfigurarse (cambiar de servicio/atenciones) tras construirse.
@export var reconfigurable: bool
## Coste de construcción del puesto, en euros.
@export var coste_construccion_eur: int
## Nº de agentes que pueden operar el puesto simultáneamente. Default 1 (mínimo operable).
@export var plazas_agente: int = 1
## Superficie que ocupa en la rejilla, en celdas. Default 1.
@export var superficie: int = 1
## Icono para la UI.
@export var icono: Texture2D
