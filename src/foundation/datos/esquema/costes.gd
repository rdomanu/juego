class_name Costes extends Resource
## Costes — definición (read-only) de la tabla de costes/retornos globales de la economía.
##
## Agrupa parámetros económicos transversales (peonadas, retorno de la DGP). Solo estructura (`@export`):
## CERO lógica. Carga en Story 002, contenido en Story 004.
##
## Nota de implementación: se añade `id` (no pedido explícitamente por el GDD para esta tabla) para que el
## autoload Datos de la Story 002 pueda indexar TODAS las definiciones del catálogo de forma UNIFORME por
## `id`, sin un caso especial para Costes. Su valor será un id fijo (p. ej. &"costes_global").
##
## Story: production/epics/datos/story-001-esquema-clases-resource.md (TR-data-002) · ADR-0003

## Identificador único de la definición (clave de lookup uniforme en el autoload Datos — ver nota arriba).
@export var id: StringName
## Coste de la peonada (hora extraordinaria de agente), en euros por hora.
@export var peonada_eur_hora: float
## Fracción [0,1] de la tarifa que la DGP (Dirección General de la Policía) devuelve con satisfacción 0 (suelo fijo).
@export var retorno_dgp_min: float
## Fracción [0,1] de la tarifa que la DGP devuelve con satisfacción 100 (siempre retiene el resto).
@export var retorno_dgp_max: float
