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
## ⚠️ El horario de Documentación (apertura / cierre / última admisión) YA NO VIVE AQUÍ: se mudó a
## `ConfigDocumentacion` en la story doc-002 (Documentación #8 lo posee, Flujo solo lo ejecuta vía
## `Flujo.fijar_horario_doc`). No volver a añadirlo: una sola fuente de verdad.

## Cuánto acelera la atención cada punto de rendimiento instalado en la sala del puesto
## (Comodidades #15, story com-002): `mult = clamp(1 − k_equipamiento × rendimiento, min, 1.0)`.
## Con 0.02, un equipo informático (4) + una impresora de DNI (6) dejan el multiplicador en 0.8 →
## se atiende un 20 % más rápido.
@export var k_equipamiento: float = 0.02
## Suelo del multiplicador de equipamiento: por mucho material que compres, el trámite tiene un
## mínimo (hay que hablar con la persona, comprobar papeles...). 0.8 = como mucho un 20 % más rápido.
@export var mult_equipamiento_min: float = 0.8
## Velocidad de paseo del NPC visible, en px/s a velocidad 1× (story 008 — COSMÉTICO puro, FL5:
## jamás afecta a la simulación; escala con el multiplicador del reloj). Semilla 90.
@export var velocidad_npc_px_s: float = 90.0
