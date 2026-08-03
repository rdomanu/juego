class_name CapaParedes extends Node2D
## CapaParedes — SOLO pinta los tramos/jambas que `ParedesSalas` le entrega ya calculados. No lee el
## modelo, no decide alturas ni colores: eso sigue siendo trabajo exclusivo de `ParedesSalas` (la
## única que conoce a Construcción — ADR-0004).
##
## Nace de partir `ParedesSalas` en DOS pasadas (2026-08-03, "PAREDES FRONTALES BAJITAS" — bug con
## captura del usuario: un sofá de 3 celdas pegado a la pared SUR de una sala se dibujaba sangrando
## POR ENCIMA de ella). La solución clásica del género (Theme Hospital / Two Point): las aristas que
## dan a cámara (sur/este de cada sala) se dibujan a MEDIA altura y en una capa POR ENCIMA del
## mobiliario estático; las traseras (norte/oeste) siguen enteras, en su capa de siempre. Dos
## instancias de esta MISMA clase —una por pasada— hacen ese reparto: `ParedesSalas.configurar()`
## las crea con el `z_index` que corresponde a cada una (ver ese fichero para el porqué del reparto).

## Grosor por defecto si un tramo llega sin "grosor" en su diccionario (red de seguridad — hoy
## `ParedesSalas` siempre lo rellena, así que esta rama no debería pisarse nunca en partida).
const GROSOR_POR_DEFECTO: float = 4.0
## Grosor del remate superior de la pared (la franja clara de arriba — da la sensación de espesor).
## Puramente de DIBUJO (no de geometría/modelo), así que vive aquí y no en `ParedesSalas`.
const GROSOR_REMATE: float = 3.0

var tramos: Array[Dictionary] = []
var jambas: Array[Dictionary] = []


func _draw() -> void:
	# Los tramos ya llegan ORDENADOS de fondo a frente (los calcula y ordena `ParedesSalas` antes de
	# repartirlos): en isométrico el orden de pintado ES la profundidad, y pintar algo del fondo
	# DESPUÉS de algo de delante lo taparía sin motivo.
	for tramo: Dictionary in tramos:
		var desde: Vector2 = tramo["desde"]
		var hasta: Vector2 = tramo["hasta"]
		var color: Color = tramo["color"]
		var alto: float = tramo.get("alto", 0.0) as float
		if alto <= 0.0:
			draw_line(desde, hasta, color, tramo.get("grosor", GROSOR_POR_DEFECTO) as float, true)
			continue
		# TODAS las paredes suben; lo que cambia entre pasadas es CUÁNTO (lo decide `ParedesSalas`).
		var subir := Vector2(0.0, -alto)
		draw_colored_polygon(
			PackedVector2Array([desde, hasta, hasta + subir, desde + subir]), color
		)
		draw_line(desde + subir, hasta + subir, color.lightened(0.35), GROSOR_REMATE, true)
		draw_line(desde, hasta, color.darkened(0.4), 1.5, true)
	for jamba: Dictionary in jambas:
		draw_line(
			jamba["desde"] as Vector2, jamba["hasta"] as Vector2, jamba["color"] as Color,
			jamba.get("grosor", GROSOR_POR_DEFECTO) as float, true
		)


## Sustituye el contenido de esta pasada y repinta. Único punto de entrada desde `ParedesSalas` —
## así ninguna pasada se queda con datos viejos por olvidar el `queue_redraw()` correspondiente.
func fijar(nuevos_tramos: Array[Dictionary], nuevas_jambas: Array[Dictionary]) -> void:
	tramos = nuevos_tramos
	jambas = nuevas_jambas
	queue_redraw()
