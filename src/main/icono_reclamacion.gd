class_name IconoReclamacion extends Node2D
## IconoReclamacion — la señal sobre la cabeza de quien viene A PONER UNA RECLAMACIÓN (mejora ①,
## petición del usuario 2026-08-18: *"debería quedarse en espera y señalar al ciudadano con una !
## en rojo o algo, para saber que ese ciudadano está ahí para reclamar"*).
##
## La hoja de reclamaciones entra por la ODAC como una persona más (ver
## `Paciencia._generar_reclamacion`): sin esta señal, el reclamante es indistinguible del resto de
## la cola y el jugador no ve el trabajo-castigo que le está entrando.
##
## Dibujada por CÓDIGO, sin asset de arte — mismo criterio que `IconoProhibido`, la barra de
## paciencia o la taza del descanso: un círculo rojo con una EXCLAMACIÓN blanca (palo + punto),
## legible a cualquier zoom. Se dibuja UNA vez y solo cambia `visible`.
const RADIO: float = 6.5
const COLOR_CIRCULO := Color(0.85, 0.15, 0.15)
const COLOR_SIGNO := Color(1.0, 1.0, 1.0)
## Palo de la exclamación: ancho y tramo vertical (del alto del círculo, con aire arriba y abajo).
const ANCHO_PALO: float = 2.0
const PALO_DESDE: float = -3.5
const PALO_HASTA: float = 1.0
## Punto inferior de la exclamación.
const RADIO_PUNTO: float = 1.3
const Y_PUNTO: float = 3.6


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIO, COLOR_CIRCULO)
	draw_line(
		Vector2(0.0, PALO_DESDE), Vector2(0.0, PALO_HASTA), COLOR_SIGNO, ANCHO_PALO, true
	)
	draw_circle(Vector2(0.0, Y_PUNTO), RADIO_PUNTO, COLOR_SIGNO)
