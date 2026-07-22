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


## Elige un índice con probabilidad proporcional a `pesos` (usa el MISMO RNG sembrado → determinista).
## Normalización DEFENSIVA: usa la suma real (no exige que sumen 1); un peso ≤ 0 nunca se elige.
## Edge: lista vacía o sin pesos positivos → devuelve -1. Lo usan Demanda (mezcla de trámites) y Personal.
## Story: production/epics/rng-service/story-002-eleccion-ponderada.md · ADR-0002 / TR-demand-002
func elegir_ponderado(pesos: Array[float]) -> int:
	var total: float = 0.0
	for p in pesos:
		if p > 0.0:
			total += p
	if total <= 0.0:
		push_warning("elegir_ponderado: sin pesos positivos -> -1")
		return -1
	# OJO: `self.randf()` cualificado a propósito. Sin `self.`, GDScript resolvería `randf()` a la
	# función GLOBAL de Godot (@GlobalScope, RNG sin sembrar) en vez de a nuestro método sembrado →
	# rompería el determinismo. El nombre `randf` colisiona con la utilidad global (footgun).
	var r: float = self.randf() * total
	var acumulado: float = 0.0
	for i in pesos.size():
		var p: float = pesos[i]
		if p <= 0.0:
			continue
		acumulado += p
		if r < acumulado:
			return i
	return pesos.size() - 1   # salvaguarda por redondeo de coma flotante (inalcanzable: r < total)
