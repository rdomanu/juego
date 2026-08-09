extends Node2D
## SONDA DESECHABLE (2026-08-09): coloca en el DISEÑADOR una calle N-S de carretera_90 con la
## barrera nueva (barrera_seguridad rot 0) cruzándola y un coche patrulla esperando — captura
## para verificar el anclaje y la escala EN EL JUEGO REAL. Se borra tras usarse.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/94657f06-d182-4b83-a1b4-9a4ad8a17e9b/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var modo: Node = main._modo_disenador_entorno
	if modo == null:
		push_error("[BARRERA INGAME] sin --disenador")
		get_tree().quit()
		return
	modo.alternar()
	modo.set_process(false)
	# calle N-S al oeste del recinto: carretera_90 en diagonal + barrera + coche
	var sitios: Array = [
		{"rot": 0, "celda": Vector2i(-16, 2)}, {"rot": 90, "celda": Vector2i(-16, 10)},
		{"rot": 180, "celda": Vector2i(-6, 2)}, {"rot": 270, "celda": Vector2i(-6, 10)},
	]
	for s: Dictionary in sitios:
		modo._fijar_herramienta(&"barrera_seguridad")
		modo._orientacion = int(s["rot"])
		modo._colocar_pieza_en(s["celda"])
	modo._capa_ui.visible = false
	main._camara.position = (
		main._construccion.centro_de_celda(Vector2i(-11, 6)) - get_viewport_rect().size / 2.0
	)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	print("[BARRERA INGAME] camara en ", main._camara.global_position)
	var imagen: Image = get_viewport().get_texture().get_image()
	imagen.save_png(CARPETA_SALIDA + "barrera_ingame.png")
	print("[BARRERA INGAME] -> barrera_ingame.png")
	get_tree().quit()
