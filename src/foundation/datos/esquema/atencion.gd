class_name Atencion extends Resource
## Atencion — definición base (read-only) de un servicio que se atiende en un puesto de la comisaría.
##
## Es la RAÍZ de la jerarquía del catálogo de atenciones: `TramiteDoc` (Documentación) y `DenunciaODAC`
## (ODAC) heredan de aquí. NO se usa directa: agrupa los campos comunes a todo lo que un agente "despacha".
##
## Solo estructura (`class_name` + `@export`): CERO lógica. La carga/indexado es la Story 002; la
## validación de integridad, la Story 003; el contenido (`.tres` con valores), la Story 004.
##
## Referencias a otras definiciones SIEMPRE por `id` (`StringName`), NUNCA anidando Resources (ADR-0003:
## evita el `duplicate_deep` de 4.5 y permite validar integridad referencial en carga).
##
## Story: production/epics/datos/story-001-esquema-clases-resource.md (TR-data-002) · ADR-0003

## Identificador único de la definición (clave de lookup en el autoload Datos — Story 002).
@export var id: StringName
## Nombre visible (UI).
@export var nombre: String
## Servicio al que pertenece. La BASE solo distingue Documentación/ODAC (Seguridad es de puesto, no de atención).
@export_enum("Documentacion", "ODAC") var servicio: String
## Tiempo base de atención en minutos de juego. Default 1 = mínimo seguro (evita duraciones 0 sin definir).
@export var duracion_min: int = 1
## `id` del `TipoPuesto` capaz de despachar esta atención (referencia por id, no Resource anidado).
@export var tipo_puesto: StringName
## Icono para la UI.
@export var icono: Texture2D
