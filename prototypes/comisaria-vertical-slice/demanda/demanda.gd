# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: ¿es divertido y construible el bucle core de la Oficina de Denuncias?
# Date: 2026-07-22
extends Node
## Demanda (Core) — genera llegadas de ciudadanos con un ritmo + azar SEMBRADO (RNGService).
## Más gente de día, menos de noche. No posee a las Personas (eso es Flujo/Mundo): solo emite
## "llega uno de tipo X". El intervalo y los pesos pasarán al catálogo (Datos) más adelante.

signal generar(tipo: StringName)

const INTERVALO_DIA_MIN: float = 10.0     # min de juego entre llegadas (día)
const INTERVALO_NOCHE_MIN: float = 40.0   # de noche llega mucha menos gente
const PESO_DNI: float = 0.6
const PESO_DENUNCIA: float = 0.4

var _acumulado: float = 0.0
var _proximo: float = INTERVALO_DIA_MIN

func _physics_process(_delta: float) -> void:
	_acumulado += Tiempo.delta_juego     # avanza con el reloj (0 en Pausa; más rápido a 2×/3×)
	if _acumulado < _proximo:
		return
	_acumulado = 0.0
	_proximo = INTERVALO_NOCHE_MIN if Tiempo.es_de_noche() else INTERVALO_DIA_MIN
	var tipo: StringName
	if Tiempo.es_de_noche():
		tipo = &"denuncia"                     # de noche el DNI (Documentación) cierra; ODAC es 24h
	else:
		var idx: int = RNGService.elegir_ponderado([PESO_DNI, PESO_DENUNCIA])
		tipo = &"dni" if idx == 0 else &"denuncia"
	generar.emit(tipo)
