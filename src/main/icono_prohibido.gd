class_name IconoProhibido extends Node2D
## IconoProhibido — la señal de "prohibido" sobre la cabeza de quien está BLOQUEADO por un camino
## imposible (una sala amurallada sin puerta, un tabique recién levantado sobre su ruta...).
##
## Nace del bug reportado por el usuario 2026-08-03: *"las personas, si no pueden acceder a una
## sala porque hay paredes, SALTAN [se teletransportan]. No deben hacer eso; si no pueden entrar
## podrías poner una señal de prohibido encima de sus cabezas, así se puede ver que hay algún
## problema"*. El teletransporte se elimina en `NPCCiudadano._actualizar_destino` y en
## `NPCsFlujo._fijar_destino_caminante` (ver ambos): esta clase es SOLO el dibujo de la señal.
##
## Dibujada por CÓDIGO, sin asset de arte — mismo criterio que el resto de indicadores de esta capa
## (la barra de paciencia, la taza de café del descanso): un círculo rojo con una barra diagonal
## blanca, el símbolo universal de "no se puede". Se lee de un vistazo, a cualquier tamaño de
## cámara, y no cuesta un solo píxel de arte.
##
## Nace OCULTA (`visible = false`); quien la posee (`NPCCiudadano`, o el caminante de
## `NPCsFlujo` vía metadato `icono_bloqueo`) la muestra/oculta por DIFF, igual que la barra de
## ánimo: se dibuja UNA sola vez (`_draw` corre al entrar en el árbol) y nunca se reconstruye — lo
## único que cambia después es `visible`.
const RADIO: float = 6.5
const COLOR_CIRCULO := Color(0.85, 0.15, 0.15)
const COLOR_BARRA := Color(1.0, 1.0, 1.0)
const GROSOR_BARRA: float = 2.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIO, COLOR_CIRCULO)
	var punta: Vector2 = Vector2(RADIO, RADIO) * 0.75
	draw_line(-punta, punta, COLOR_BARRA, GROSOR_BARRA, true)
