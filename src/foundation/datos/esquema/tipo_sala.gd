class_name TipoSala extends Resource
## TipoSala — definición (read-only) de un tipo de sala/área de la comisaría.
##
## Una sala agrupa puestos y/o gestiona espera (GDD F4: sala de espera vs área lógica/oficina). Referencia
## los puestos que admite por `id` (`Array[StringName]`), NUNCA anidando Resources (ADR-0003).
##
## Solo estructura (`@export`): CERO lógica. Carga en Story 002, contenido en Story 004.
##
## Story: production/epics/datos/story-001-esquema-clases-resource.md (TR-data-002) · ADR-0003

## Identificador único de la definición (clave de lookup en el autoload Datos — Story 002).
@export var id: StringName
## Nombre visible (UI).
@export var nombre: String
## Rol de la sala: "espera" (aloja ciudadanos en cola) u "oficina" (área lógica que agrupa puestos). GDD F4.
@export_enum("espera", "oficina") var tipo: String
## Servicio de la sala. "Comun" = compartida entre servicios (GDD R2: "servicio|Comun").
@export_enum("Documentacion", "ODAC", "Comun") var servicio: String
## `id`s de los `TipoPuesto` que pueden colocarse en esta sala (referencias por id, no Resources anidados).
@export var puestos_admitidos: Array[StringName]
## Aforo de personas en espera que soporta la sala.
@export var aforo_espera: int
## Coste de construcción de la sala, en euros.
@export var coste_construccion_eur: int
## Superficie que ocupa en la rejilla, en celdas.
@export var superficie: int
## Icono para la UI.
@export var icono: Texture2D
