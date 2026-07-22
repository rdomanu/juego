extends Node
## Tiempo — el reloj base de la simulación (autoload "Tiempo", el 4º).
##
## Mantiene un acumulador `minutos_juego` (float) que representa el minuto del día en curso, en el
## rango [0, 1440). NO cuenta frames: `avanzar(delta_real)` acumula el `delta` REAL que entrega el
## motor → mismo delta acumulado ⇒ mismo resultado a cualquier FPS (determinismo, la base del proyecto).
##
## Esta story implementa SOLO el acumulador puro y testeable: `avanzar()` recibe el `delta` por
## parámetro (inyección) — NO lee la hora del sistema ni se engancha a `_physics_process` todavía
## (eso es H7). El módulo 1440 solo ENVUELVE el valor al cruzar medianoche; NO emite eventos de
## cruce (`nuevo_dia`, `cambio_de_turno`, …) — eso es H4/H5.
##
## Story: production/epics/tiempo/story-001-reloj-base.md · TR-time-001 / TR-time-005 · ADR-0001

## Minutos del día en curso, en [0, 1440). Es `float` para acumular sin errores de truncado antes de
## convertir a HH:MM (GDD F2). El módulo 1440 lo envuelve al pasar de medianoche.
var minutos_juego: float = 0.0

## Minutos de juego por segundo real a velocidad 1× (default fijo en esta story; en H2 pasa a venir del
## config `ConfigTiempo`, con clamp a [3, 12]).
var escala_tiempo: float = 4.0

## Multiplicador de la máquina de velocidad (Pausa=0 / 1× / 2× / 3×). Aquí es una var simple con default
## 1×; la lógica de la máquina de velocidad es H6.
var multiplicador_velocidad: int = 1

## Techo del `delta` real aceptado por frame, en segundos (clamp anti-salto TR-time-005). Tras un alt-tab
## o un pico de lag el motor puede entregar un `delta` enorme; se recorta ANTES de acumular para que el
## reloj no pegue un salto. Default fijo aquí; en H2 pasa a ser data-driven.
var delta_max_por_frame: float = 0.5

## Minutos en un día (24 h × 60 min). El acumulador envuelve al alcanzarlo.
const MINUTOS_POR_DIA: float = 1440.0


## Avanza el reloj acumulando el `delta` REAL entregado por el motor (función pura y determinista).
##
## El `delta` se CLAMPA a `delta_max_por_frame` ANTES de acumular (anti-salto, TR-time-005), luego se
## escala por `escala_tiempo * multiplicador_velocidad` y se suma a `minutos_juego`. Al cruzar 1440 el
## valor ENVUELVE por módulo (medianoche → 00:00 del día siguiente); esta story NO emite eventos de cruce.
##
## En Pausa (`multiplicador_velocidad == 0`) el incremento es 0 → el reloj no cambia (AC-T04).
## TR-time-001: acumula `delta` real, no frames → mismo resultado a cualquier FPS.
func avanzar(delta_real: float) -> void:
	var delta_clampado: float = min(delta_real, delta_max_por_frame)
	minutos_juego += escala_tiempo * multiplicador_velocidad * delta_clampado
	minutos_juego = fposmod(minutos_juego, MINUTOS_POR_DIA)
