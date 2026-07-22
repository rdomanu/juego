# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: ¿es divertido y construible el bucle core de la Oficina de Denuncias?
# Date: 2026-07-22
extends Node
## EventBus — el "tablón de anuncios" del juego (ADR-0001).
## Solo emite / retransmite señales cross-system; NUNCA contiene lógica de juego.
## Se accede como singleton global: EventBus.<senal>.emit(...) / EventBus.<senal>.connect(...)

# --- Señales de Tiempo (emisor: Tiempo) ---
signal nuevo_dia
signal nuevo_mes
signal cambio_de_turno(turno: int)
signal cambio_dia_noche(es_de_noche: bool)

# --- Señales de simulación (se empiezan a usar en el Escalón 1+) ---
signal persona_generada(persona: Node)
signal tramite_completado(tramite_id: StringName, agente: Node)
signal abandono(persona: Node)
signal saldo_cambiado(nuevo_saldo: int)
signal reclamacion_generada(origen: StringName)
signal ascenso(rango: String)                # (objetivo cumplido → progresión de carrera)
