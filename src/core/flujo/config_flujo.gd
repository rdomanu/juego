class_name ConfigFlujo extends Resource
## ConfigFlujo — los tuning knobs PROPIOS de Flujo (GDD flow-queues §Tuning Knobs: pocos y de
## política MVP — el reto del cuello de botella se tunea en OTROS sistemas; Flujo los consume).
##
## El `.tres` (`res://datos/config/flujo.tres`) se genera SIEMPRE por herramienta
## (`tools/build_config_flujo.gd`), nunca a mano. Flujo lo carga con fallback + clamps.
##
## Story: production/epics/flujo/story-001-persona-estados-turnos.md · TR-flow-001 · ADR-0003

## Velocidad del camino de la persona a la ventanilla al ser llamada, en CELDAS de juego por MINUTO
## de juego (enmienda 2026-07-25 "en camino no se tramita": el trayecto de la Llamada al puesto SÍ
## descuenta tiempo antes de que arranque la atención — deriva del MODELO, no del sprite, FL5). El
## camino se cronometra por la distancia real (celdas de Construcción) / esta velocidad. 0 =
## instantáneo (compat con el comportamiento previo: la atención arranca el mismo tick).
## ⚠️ Calibración 3ª (tras demo): semilla 0.375 = EXACTAMENTE el paso cosmético de 90 px/s a 1×
## (90 px/s ÷ 40 px/celda ÷ 6 min juego/s). Así el cronómetro lógico y el muñeco a paso normal
## miden lo mismo y el muñeco apenas necesita ajustar (±50% como mucho — nunca esprinta).
@export var velocidad_camino_celdas_min: float = 0.375
## Anti-inanición de Normales en ODAC (las Normales suben de prioridad al esperar mucho). MVP: OFF.
@export var habilitar_aging_odac: bool = false
## Tope de la cola exterior. 0 = SIN tope (MVP, FL7 — la válvula es la paciencia, no un muro).
@export var tope_cola_exterior: int = 0
## Minuto del día en que Documentación cierra la puerta a NUEVAS admisiones (AC-FL24, PROVISIONAL
## en Flujo hasta Documentación #8). MISMO valor que `ventana_doc_fin_min` de Demanda (cross-fact
## 870 = 14:30; el dueño real será Horarios/Documentación). Semilla 870.
@export var cierre_doc_min: int = 870
## Minuto del día en que Documentación ABRE (los funcionarios llegan y los puestos Doc se reabren
## solos — etiqueta "horario provisional 2026-07-25", PROVISIONAL en Flujo hasta Documentación #8).
## MISMO valor que `ventana_doc_inicio` de Demanda (cross-fact 480 = 08:00; el dueño real será
## Horarios/Documentación). Semilla 480.
@export var apertura_doc_min: int = 480
## Velocidad de paseo del NPC visible, en px/s a velocidad 1× (story 008 — COSMÉTICO puro, FL5:
## jamás afecta a la simulación; escala con el multiplicador del reloj). Semilla 90.
@export var velocidad_npc_px_s: float = 90.0
