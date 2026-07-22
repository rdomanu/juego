extends Node
## RNGService — la fuente central de aleatoriedad SEMBRADA del juego (autoload "RNGService", el 2º).
##
## TODA la aleatoriedad de juego pasa por aquí (nadie usa `randi()`/`randf()` global). Envuelve un
## `RandomNumberGenerator` sembrado, de modo que **misma semilla + misma secuencia de llamadas → mismos
## resultados** — la base del determinismo del proyecto ("misma partida = mismo resultado", testeable).
##
## La elección ponderada (`elegir_ponderado`) es la Story 002; la serialización (`save`/`load_state`) es la
## Story 003 — ambas viven en este mismo autoload.
##
## Story: production/epics/rng-service/story-001-autoload-sembrado.md · ADR-0002

## El generador interno. Su `state` avanza con cada llamada; se siembra con `sembrar(...)`.
var _rng := RandomNumberGenerator.new()


## Fija la semilla del generador (reinicia la secuencia de forma reproducible).
func sembrar(semilla: int) -> void:
	_rng.seed = semilla


## Devuelve un entero en el rango [desde, hasta], **inclusive en ambos extremos** (API de Godot 4).
func randi_rango(desde: int, hasta: int) -> int:
	return _rng.randi_range(desde, hasta)


## Devuelve un flotante en [0.0, 1.0).
func randf() -> float:
	return _rng.randf()
