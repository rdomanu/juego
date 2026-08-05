class_name ConfigImpresora extends Resource
## ConfigImpresora — los tuning knobs de LA IMPRESORA DE DOCUMENTOS y el viaje del papel.
##
## Implementa la sección "Formulas / Tuning knobs" de `design/gdd/impresora-documentos-tramite.md`
## (diseño CERRADO por el usuario 2026-08-01). Ni un número de esa mecánica vive en el código: todos
## salen de aquí, con fallback a estos defaults si el `.tres` no existe (mismo patrón que ConfigFlujo).
##
## El `.tres` (`res://datos/config/impresora.tres`) se genera por herramienta, nunca a mano.
##
## GDD: design/gdd/impresora-documentos-tramite.md · ADR-0003 (catálogo/config en Resource)

## T_AVISO — minutos de juego que le quedan al trámite cuando el funcionario **se levanta** a por el
## papel (GDD Detailed Rules §1: propuesto y aprobado en 5 min). Subirlo adelanta el viaje (menos
## cola, menos "respira la comisaría"); bajarlo lo retrasa y penaliza más una impresora lejana.
@export var t_aviso_min: float = 5.0
## `t_recogida` — la pausa BREVE delante de la impresora (coger el papel, graparlo). GDD §Formulas.
## El GDD no fijó su valor (solo lo declara knob): 1 minuto de juego es la semilla, a calibrar en
## balance. Es lo único del viaje que NO depende de la distancia, así que pone el suelo del coste:
## con la impresora pegada al puesto el viaje sigue costando esto.
@export var t_recogida_min: float = 1.0
## Velocidad del funcionario en CELDAS por MINUTO de juego. GDD §Formulas: *"velocidad (la ya
## existente de viajes)"* → misma semilla que `ConfigFlujo.velocidad_camino_celdas_min` (0.375 =
## el paso cosmético de 90 px/s a 1×). Se duplica aquí a propósito y no se lee de Flujo: el viaje
## del papel podría querer ir a otro ritmo el día que se calibre, y son knobs de sistemas distintos.
## **0 o negativo = viaje instantáneo** (solo cuesta `t_recogida_min`) — útil para aislar la variable
## en tests, igual que hace Flujo con su camino.
@export var velocidad_celdas_min: float = 0.375

# ── P2: qué trámites terminan CON PAPEL (GDD, decisión del usuario 2026-08-01) ────────────────
## Servicios cuyos trámites SIEMPRE acaban en un documento impreso. *"TODAS las denuncias (ODAC)"*.
@export var servicios_con_papel: Array[StringName] = [&"ODAC"]
## Trámites SUELTOS con papel, por `id` de atención, para servicios que no lo son enteros. *"y la
## EXPEDICIÓN de TIE"* — el resto de Documentación (DNI, pasaporte, consultas) no hace el viaje.
@export var tramites_con_papel: Array[StringName] = [&"tie"]
