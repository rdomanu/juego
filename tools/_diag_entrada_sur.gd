extends Node2D
## SONDA GPU DESECHABLE (2026-08-08): captura la fachada SUR de la comisaría tras mover la entrada
## del lado oeste (corto) al sur (largo, centrada) -- ver Construccion.CELDA_PUERTA_EDIFICIO y
## EntornoExterior (RECT_RECINTO/RECT_CONTROL/RECT_ACERA/RECT_CALZADA reorientados al sur).
##
## Cámara centrada en la celda de la puerta, en coordenadas de mundo (Proyeccion.centro_iso +
## pos_suelo, el mismo origen que usa el resto del juego -- ver Main.pos_suelo), con zoom que
## enseñe fachada + recinto + calle. PNG al scratchpad de la sesión.
##
## Se borra tras usarla -- no es parte del pipeline final.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/1f7d5694-02c7-4fc1-9a44-a8546d82445c/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")
const ZOOM_SONDA: float = 0.55


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# La celda de la puerta (fachada sur): CELDA_PUERTA_EDIFICIO = (11,12) es la celda INTERIOR justo
	# al norte del hueco; el hueco en sí (arista "abajo") cae en la fila 13, centrado entre las
	# columnas 11 y 12 -- se apunta al punto medio (12,13) para encuadrar el hueco en el centro.
	var celda_puerta := Vector2i(12, 13)
	var punto_mundo: Vector2 = main.pos_suelo + Proyeccion.centro_iso(celda_puerta)

	var camara: Camera2D = main._camara
	camara.zoom = Vector2(ZOOM_SONDA, ZOOM_SONDA)
	var visible_size: Vector2 = get_viewport().get_visible_rect().size / camara.zoom
	camara.position = main._clamp_posicion_camara(
		punto_mundo - visible_size * 0.5, get_viewport().get_visible_rect().size
	)
	await get_tree().process_frame
	await get_tree().process_frame

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = get_viewport().get_texture().get_image()
	imagen.save_png(CARPETA_SALIDA + "entrada_sur.png")
	print("[DIAG ENTRADA SUR] -> entrada_sur.png (celda_puerta=%s, punto_mundo=%s, camara.position=%s)" % [celda_puerta, punto_mundo, camara.position])
	get_tree().quit()
