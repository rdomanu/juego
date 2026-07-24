class_name ConfigFlujo extends Resource
## ConfigFlujo — los tuning knobs PROPIOS de Flujo (GDD flow-queues §Tuning Knobs: pocos y de
## política MVP — el reto del cuello de botella se tunea en OTROS sistemas; Flujo los consume).
##
## El `.tres` (`res://datos/config/flujo.tres`) se genera SIEMPRE por herramienta
## (`tools/build_config_flujo.gd`), nunca a mano. Flujo lo carga con fallback + clamps.
##
## Story: production/epics/flujo/story-001-persona-estados-turnos.md · TR-flow-001 · ADR-0003

## Segundos de JUEGO del desplazamiento cosmético (coger número / ir al puesto / salir). NO cuenta
## para el balance (FL5); 0 = teleport. Semilla 1.5.
@export var duracion_desplazamiento_seg: float = 1.5
## Anti-inanición de Normales en ODAC (las Normales suben de prioridad al esperar mucho). MVP: OFF.
@export var habilitar_aging_odac: bool = false
## Tope de la cola exterior. 0 = SIN tope (MVP, FL7 — la válvula es la paciencia, no un muro).
@export var tope_cola_exterior: int = 0
## Minuto del día en que Documentación cierra la puerta a NUEVAS admisiones (AC-FL24, PROVISIONAL
## en Flujo hasta Documentación #8). MISMO valor que `ventana_doc_fin_min` de Demanda (cross-fact
## 870 = 14:30; el dueño real será Horarios/Documentación). Semilla 870.
@export var cierre_doc_min: int = 870
