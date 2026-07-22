# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: ¿es divertido y construible el bucle core de la Oficina de Denuncias?
# Date: 2026-07-22
extends Node
## Economía (Core) — versión mínima del slice: presupuesto que sube al completar un trámite.
## Escucha el bus (tramite_completado) y abona la tarifa SEGÚN el tipo. Las tarifas pasarán al
## catálogo (Datos) en un escalón posterior.

const SALDO_INICIAL: int = 3000
var TARIFA := { &"dni": 12, &"denuncia": 0 }   # € por trámite (Datos semilla: DNI 12€; denuncia sin tasa)

var saldo_eur: int = SALDO_INICIAL

func _ready() -> void:
	EventBus.tramite_completado.connect(_on_tramite_completado)

func _on_tramite_completado(tramite_id: StringName, _agente: Node) -> void:
	abonar(int(TARIFA.get(tramite_id, 0)))

func abonar(cantidad: int) -> void:
	if cantidad == 0:
		return
	saldo_eur += cantidad
	EventBus.saldo_cambiado.emit(saldo_eur)

## Gate de gasto: ¿hay saldo para pagar 'coste'? (Construcción pregunta antes de gastar.)
func puede_pagar(coste: int) -> bool:
	return saldo_eur >= coste

## Gasto voluntario (ya validado con puede_pagar).
func cobrar(coste: int) -> void:
	saldo_eur -= coste
	EventBus.saldo_cambiado.emit(saldo_eur)
