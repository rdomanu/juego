class_name TramiteDoc extends "res://src/foundation/datos/esquema/atencion.gd"
## TramiteDoc — definición de un trámite de Documentación (DNI, Pasaporte, TIE…).
##
## Extiende `Atencion` con lo propio de Documentación: los trámites SÍ cobran tarifa y pueden requerir cita.
## Hereda `id`, `nombre`, `servicio`, `duracion_min`, `tipo_puesto`, `icono`.
##
## `extends` por RUTA LITERAL (no por `class_name Atencion`) a propósito: al preload-arse la clase hija en
## headless "en frío" (GdUnit4 discovery), el registro global de `class_name` aún no conoce a `Atencion`, así
## que `extends Atencion` falla con "Could not resolve script". La ruta literal no depende de ese registro.
##
## Solo estructura (`@export`): CERO lógica. Contenido en Story 004.
##
## Story: production/epics/datos/story-001-esquema-clases-resource.md (TR-data-002) · ADR-0003

## Tarifa que abona el ciudadano por el trámite, en euros (los trámites de Documentación cobran).
@export var tarifa_eur: int
## Si el trámite exige cita previa para ser atendido.
@export var requiere_cita: bool
