extends Node2D
## SONDA GPU DESECHABLE (2026-08-09): una única captura del juego SIN la barra de construcción
## (se oculta su CanvasLayer entera) — sirve de base limpia para el fotomontaje de las opciones
## de la franja "CONSTRUIR (B)" (veredicto del usuario pendiente). Se borra tras usarla.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/94657f06-d182-4b83-a1b4-9a4ad8a17e9b/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var capa_ui: CanvasLayer = main._modo_construccion.get_node("UIConstruccion") as CanvasLayer
	capa_ui.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = get_viewport().get_texture().get_image()
	imagen.save_png(CARPETA_SALIDA + "franja_base_limpia.png")
	print("[DIAG FRANJA BASE] -> franja_base_limpia.png")
	get_tree().quit()
