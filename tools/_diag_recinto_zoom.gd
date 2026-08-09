extends Node2D
## SONDA DESECHABLE (2026-08-07) -- captura el recinto de la comisaría de cerca (zoom 2.0, cámara
## centrada en RECT_RECINTO) para revisar la reforma de EntornoExterior con detalle.
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")

var _main: Node2D


func _ready() -> void:
	_main = MainEscena.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame

	var entorno_script := preload("res://src/main/entorno_exterior.gd")
	var centro_celda := Vector2i(-10, 6)
	var punto: Vector2 = _main.pos_suelo + Proyeccion.centro_iso(centro_celda)
	_main._camara.zoom = Vector2(1.6, 1.6)
	_main._camara.position = punto - (get_viewport().get_visible_rect().size / 2.0) / 1.6
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = get_viewport().get_texture().get_image()
	imagen.save_png(CARPETA_SALIDA + "recinto_zoom.png")
	print("[DIAG RECINTO ZOOM] guardado")
	get_tree().quit()
