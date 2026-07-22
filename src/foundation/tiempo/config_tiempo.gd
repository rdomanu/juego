class_name ConfigTiempo extends Resource
## ConfigTiempo — definición (read-only) de la config data-driven del reloj de juego.
##
## Agrupa los tuning knobs del reloj que NO deben estar incrustados en el código (coding-standards:
## gameplay data-driven): la escala del tiempo, los límites de turno (mañana/tarde/noche) y el techo de
## delta anti-salto. Solo estructura tipada (`@export`): CERO lógica. La carga y el clamp de la escala
## los hace `Tiempo` (autoload); esta clase es únicamente el contenedor de datos.
##
## Es un Resource del DESARROLLADOR (`res://datos/config/tiempo.tres`), no del save del jugador (ADR-0002):
## `load()` de este `.tres` es seguro. El `.tres` se materializa con `tools/build_config_tiempo.gd`, NUNCA
## a mano (uids/ext_resource frágiles — misma regla que el catálogo de Datos).
##
## Story: production/epics/tiempo/story-002-escala-configurable.md · TR-time-001 · ADR-0001 (prim.) / ADR-0002 (sec.)

## Minutos de juego por segundo real a velocidad 1× (driver nº1 del ritmo). `Tiempo` la clampa a [3, 12]
## al aplicar el config (rango seguro: nunca ≤0 = reloj congelado, nunca >12). Default 4.0 (GDD F1).
@export var escala_tiempo: float = 4.0

## Inicio del turno de MAÑANA, en minutos del día [0, 1440). Default 420 = 07:00 (GDD F3).
@export var inicio_manana: int = 420

## Inicio del turno de TARDE, en minutos del día [0, 1440). Default 900 = 15:00 (GDD F3).
@export var inicio_tarde: int = 900

## Inicio del turno de NOCHE, en minutos del día [0, 1440). Default 1380 = 23:00 (GDD F3).
## NOCHE es el caso restante ([inicio_noche, 1440) ∪ [0, inicio_manana)) porque cruza medianoche.
@export var inicio_noche: int = 1380

## Jornadas (días de juego) por mes de calendario. Default 4 (GDD Core Rules 7). Su uso es H5 (calendario).
@export var jornadas_por_mes: int = 4

## Techo del delta real aceptado por frame, en segundos (clamp anti-salto TR-time-005). Tras un alt-tab o
## un pico de lag el motor puede entregar un delta enorme; se recorta ANTES de acumular. Default 0.5.
@export var delta_max_por_frame: float = 0.5
