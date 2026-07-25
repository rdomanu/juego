class_name ConfigPaciencia extends Resource
## ConfigPaciencia — los tuning knobs de Paciencia y Satisfacción (GDD patience-satisfaction
## §Tuning Knobs). Esta story (001) trae los del DRENAJE y los umbrales de ánimo; los de puntuación
## (003) y reclamación (006) se añaden en sus stories.
##
## El `.tres` (`res://datos/config/paciencia.tres`) se genera SIEMPRE por herramienta
## (`tools/build_config_paciencia.gd`), nunca a mano. Paciencia lo carga con fallback + clamps.
##
## ⚠️ Estos números son SEMILLA (GDD: "provisional, a validar en playtest"). `tolerancia_base_min` es
## el knob más importante del balance del juego hasta ahora: es cuánto aguanta la gente antes de
## largarse. Se calibra CON el usuario en la ventana (tarea C3-4 del Sprint 3).
##
## Story: production/epics/paciencia/story-001-nucleo-config-drenaje.md · TR-patience-001 · ADR-0003

## Minutos que aguanta una persona en condiciones NEUTRAS antes de que su paciencia llegue a 0
## (F1: la tasa de drenaje es `100 / tolerancia_base_min` puntos por minuto). Semilla 30.
@export var tolerancia_base_min: float = 30.0
## Cuánto acelera el drenaje que la sala esté por encima de su aforo (F1:
## `mult_hacinamiento = 1 + k_hacinamiento × (ocupacion − aforo) / aforo`). Con 1.0, una sala al 150 %
## de su aforo drena ×1.5 (la gente aguanta 20 min en vez de 30). Semilla 1.0.
@export var k_hacinamiento: float = 1.0
## Multiplicador de comodidad de la sala (F1). <1 = la gente aguanta MÁS. Lo bajará Comodidades #15;
## en el MVP es neutro. Semilla 1.0.
@export var mult_comodidad: float = 1.0
## Multiplicador de hora punta (F1): la aglomeración puede crispar más. Opcional, neutro en el MVP.
@export var mult_horapunta: float = 1.0
## Umbral de ánimo CONTENTO (🟢): paciencia por ENCIMA de este valor. Cross-fact 66 (ui-hud F2).
@export var umbral_animo_alto: float = 66.0
## Umbral de ánimo AL LÍMITE (🔴): paciencia por DEBAJO de este valor; entre ambos, impaciente (🟡).
## Cross-fact 33 (ui-hud F2). La UI LEE estos umbrales — nunca los hardcodea.
@export var umbral_animo_bajo: float = 33.0
