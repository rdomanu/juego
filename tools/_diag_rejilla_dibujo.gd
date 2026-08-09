extends Node2D
## Sonda desechable: dibuja la rejilla de celdas (rombos) sobre la zona de prueba de muros.
var origen: Vector2 = Vector2.ZERO

func _draw() -> void:
	for cx: int in range(-20, -6):
		for cy: int in range(0, 12):
			var rombo: PackedVector2Array = Proyeccion.rombo_de_celda(Vector2i(cx, cy))
			for i: int in rombo.size():
				rombo[i] += origen
			draw_polyline(rombo + PackedVector2Array([rombo[0]]), Color(1, 0.9, 0.2, 0.85), 1.0)
