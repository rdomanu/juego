class_name DenunciaODAC extends "res://src/foundation/datos/esquema/atencion.gd"
## DenunciaODAC — definición de una denuncia de la ODAC (Oficina De Atención al Ciudadano).
##
## Extiende `Atencion` con lo propio de ODAC: prioridad de gestión y si admite cita. Las denuncias NO
## cobran tarifa (por eso NO añade `tarifa_eur`, a diferencia de `TramiteDoc`). Hereda `id`, `nombre`,
## `servicio`, `duracion_min`, `tipo_puesto`, `icono`.
##
## `extends` por RUTA LITERAL (no por `class_name Atencion`) a propósito: al preload-arse la clase hija en
## headless "en frío" (GdUnit4 discovery), el registro global de `class_name` aún no conoce a `Atencion`, así
## que `extends Atencion` falla con "Could not resolve script". La ruta literal no depende de ese registro.
##
## Solo estructura (`@export`): CERO lógica. Contenido en Story 004.
##
## Story: production/epics/datos/story-001-esquema-clases-resource.md (TR-data-002) · ADR-0003

## Prioridad de gestión de la denuncia (afecta al orden de atención en cola).
@export_enum("Normal", "Prioritaria") var prioridad: String
## Si la denuncia puede tramitarse con cita previa.
@export var admite_cita: bool
