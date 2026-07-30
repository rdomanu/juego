class_name PiezaIso extends Node2D
## PiezaIso — un objeto del mundo dibujado como CAJA ISOMÉTRICA sobre su huella de celdas.
##
## Nace de un fallo que cazó el usuario nada más ver el juego en isométrico (2026-07-30): *"los
## objetos deben seguir la dirección de las cuadrículas, ahora mismo se superponen y se ponen en
## horizontal sin seguir las cuadrículas"*. Tenía razón: los mostradores, asientos y comodidades se
## dibujaban con un `ColorRect`, que es un rectángulo RECTO de pantalla. Sobre una rejilla cuadrada
## eso coincidía con la celda; sobre rombos, no — un sofá de 3 celdas salía como una barra
## horizontal atravesando el suelo en una dirección que no existe en el juego.
##
## Lo que dibuja, de abajo arriba:
##  1. la **tapa**: la huella real de las celdas que ocupa, subida `alto` píxeles;
##  2. las dos **caras frontales**, que son las que se ven desde esta cámara;
##  3. el **contorno**, que la despega del suelo.
##
## Con eso, un objeto de 3 celdas se estira en DIAGONAL siguiendo la rejilla, como el suelo, y dos
## objetos contiguos encajan en vez de solaparse.
##
## Sin dependencias de juego (celdas, alto y color entran por fuera): por eso vive junto a
## `Proyeccion`, en `foundation/`.

## Celdas que ocupa la pieza, contadas desde su celda ancla (siempre ≥ 1). El cuerpo crece hacia
## +X / +Y, la misma convención que usa `Construccion` para reservar el espacio en el modelo.
var celdas_x: int = 1
var celdas_y: int = 1
## Alto de la caja en píxeles. 0 = pieza PLANA (solo la huella en el suelo, sin cuerpo).
var alto: float = 18.0
## Color de la tapa. Las dos caras frontales se derivan oscureciéndolo (sombreado isométrico
## clásico: la tapa recibe la luz, la cara izquierda algo menos, la derecha menos todavía).
var color: Color = Color(0.5, 0.5, 0.5)


func _draw() -> void:
	var base: PackedVector2Array = _huella()
	if alto <= 0.0:
		draw_colored_polygon(base, color)
		_contorno(base, color.darkened(0.45))
		return
	var subir := Vector2(0.0, -alto)
	var tapa := PackedVector2Array([
		base[0] + subir, base[1] + subir, base[2] + subir, base[3] + subir,
	])
	# Las dos caras que MIRAN a la cámara son las que salen del vértice de abajo (base[2]) hacia
	# los laterales: la izquierda va al vértice izquierdo (base[3]) y la derecha al derecho
	# (base[1]). Las otras dos quedan escondidas detrás de la propia pieza y no se pintan.
	draw_colored_polygon(
		PackedVector2Array([base[3], base[2], tapa[2], tapa[3]]), color.darkened(0.22)
	)
	draw_colored_polygon(
		PackedVector2Array([base[2], base[1], tapa[1], tapa[2]]), color.darkened(0.38)
	)
	draw_colored_polygon(tapa, color)
	_contorno(tapa, color.lightened(0.25))


## Los cuatro vértices de la huella, en coordenadas LOCALES (el nodo se coloca en el centro del
## rombo de su celda ancla). Orden: arriba, derecha, abajo, izquierda.
##
## La cuenta: el vértice de rejilla (i, j) medido desde el CENTRO de la celda ancla cae en
## `proyectar((i - 0.5) × celda, (j - 0.5) × celda)` — el medio de resta es porque el ancla es el
## centro de la celda y los vértices son sus esquinas.
func _huella() -> PackedVector2Array:
	var w: float = float(maxi(celdas_x, 1))
	var h: float = float(maxi(celdas_y, 1))
	var t: float = float(Proyeccion.TAM_CELDA)
	return PackedVector2Array([
		Proyeccion.proyectar(Vector2(-0.5 * t, -0.5 * t)),
		Proyeccion.proyectar(Vector2((w - 0.5) * t, -0.5 * t)),
		Proyeccion.proyectar(Vector2((w - 0.5) * t, (h - 0.5) * t)),
		Proyeccion.proyectar(Vector2(-0.5 * t, (h - 0.5) * t)),
	])


func _contorno(vertices: PackedVector2Array, tono: Color) -> void:
	var cerrado: PackedVector2Array = vertices.duplicate()
	cerrado.append(vertices[0])
	draw_polyline(cerrado, tono, 1.0, true)


## Cambia lo que dibuja y pide repintado. Se llama una vez al crear la pieza — nunca por frame (el
## layout solo cambia cuando el jugador construye, demuele o carga partida).
func configurar(p_celdas_x: int, p_celdas_y: int, p_alto: float, p_color: Color) -> void:
	celdas_x = p_celdas_x
	celdas_y = p_celdas_y
	alto = p_alto
	color = p_color
	queue_redraw()
