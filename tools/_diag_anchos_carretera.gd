extends Node2D
## SONDA GPU DESECHABLE (2026-08-08): 3 anchos candidatos de carretera (4,4 / 4,8 / 5,2 celdas)
## con los 2 coches N-S encima, lado a lado, para el veredicto del usuario ("dame opciones para
## verlo y elegir la mejor"). Los TEST_carretera_* se borran tras elegir.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/1f7d5694-02c7-4fc1-9a44-a8546d82445c/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")

const VARIANTES: Array[String] = ["TEST_carretera_44", "TEST_carretera_48", "TEST_carretera_52"]


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var modo: Node2D = main._modo_disenador_entorno
	modo.alternar()
	modo.set_process(false)
	await get_tree().process_frame

	# Una composición por variante, separadas 10 celdas en X: carretera N-S (rot 90) + coche al
	# Sur (carril oeste) + coche al Norte (carril este) — la composición aprobada por el usuario.
	var fila: int = 41
	var col_base: int = -66
	for i: int in VARIANTES.size():
		var col: int = col_base + i * 10
		modo._fijar_herramienta(StringName(VARIANTES[i]))
		modo._orientacion = 90
		modo._colocar_pieza_en(Vector2i(col, fila))
		modo._fijar_herramienta(&"coche_sedan")
		modo._orientacion = 0
		modo._colocar_pieza_en(Vector2i(col - 1, fila))
		modo._orientacion = 180
		modo._colocar_pieza_en(Vector2i(col + 1, fila))
	modo._fijar_herramienta(&"")
	# La paleta fuera durante la foto: solo las 3 composiciones, sin UI tapando.
	modo._capa_ui.visible = false
	await get_tree().process_frame

	var centro_mundo: Vector2 = (modo._nodos_pieza.get(Vector2i(col_base + 10, fila)) as Sprite2D).global_position
	var viewport: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	main._camara.zoom = Vector2(0.85, 0.85)
	main._camara.position = centro_mundo - (viewport * 0.5) / 0.85
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = get_viewport().get_texture().get_image()
	imagen.save_png(CARPETA_SALIDA + "opciones_ancho_carretera.png")
	print("[DIAG ANCHOS] -> opciones_ancho_carretera.png")
	get_tree().quit()
