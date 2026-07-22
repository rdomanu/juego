# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: ¿es divertido y construible el bucle core de la Oficina de Denuncias?
# Date: 2026-07-22
extends Node
## RNGService — aleatoriedad determinista y serializable (ADR-0002).
## TODA la aleatoriedad de juego pasa por aquí (nadie usa randi()/randf() global).
## Misma semilla + misma secuencia de llamadas → mismos resultados.

const SEMILLA_POR_DEFECTO: int = 12345   # fija en el slice → partidas reproducibles

var _rng := RandomNumberGenerator.new()
var _semilla: int = SEMILLA_POR_DEFECTO

func _ready() -> void:
	sembrar(_semilla)

func sembrar(semilla: int) -> void:
	_semilla = semilla
	_rng.seed = semilla

func randi_rango(desde: int, hasta: int) -> int:
	return _rng.randi_range(desde, hasta)

func randf() -> float:
	return _rng.randf()

## Devuelve un índice [0, pesos.size()) elegido proporcionalmente a los pesos.
func elegir_ponderado(pesos: Array[float]) -> int:
	var total: float = 0.0
	for p in pesos:
		total += p
	if total <= 0.0:
		return 0
	var r: float = _rng.randf() * total
	var acumulado: float = 0.0
	for i in pesos.size():
		acumulado += pesos[i]
		if r <= acumulado:
			return i
	return pesos.size() - 1

func save() -> Dictionary:
	return { "semilla": _semilla, "estado": _rng.state }

func load_state(d: Dictionary) -> void:
	_semilla = int(d.get("semilla", SEMILLA_POR_DEFECTO))
	_rng.seed = _semilla
	if d.has("estado"):
		_rng.state = int(d["estado"])
