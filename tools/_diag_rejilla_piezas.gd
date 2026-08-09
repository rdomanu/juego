extends Node2D
## SONDA DESECHABLE (2026-08-09): comprueba EN EL JUEGO la alineación a la cuadrícula del encargo
## del usuario ("las casas empiezan en mitad de una celda"). Coloca una casa, un coche, una farola
## y una fila de 4 muros del kit con la REJILLA del diseñador visible, y captura.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/94657f06-d182-4b83-a1b4-9a4ad8a17e9b/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var modo: Node = main._modo_disenador_entorno
	modo.alternar()
	modo.set_process(false)
	# lienzo limpio: fuera el entorno base
	modo._fijar_base_visible(false)
	var muestras: Array = [
		# ESQUINA: tramo por el eje X (rot 90) que gira a un tramo por el eje Y (rot 0)
		{"id": &"bk_muro", "celda": Vector2i(-16, 4), "rot": 90},
		{"id": &"bk_muro", "celda": Vector2i(-15, 4), "rot": 90},
		{"id": &"bk_muro", "celda": Vector2i(-14, 4), "rot": 90},
		{"id": &"bk_muro", "celda": Vector2i(-13, 4), "rot": 0},
		{"id": &"bk_muro", "celda": Vector2i(-13, 5), "rot": 0},
		{"id": &"bk_muro", "celda": Vector2i(-13, 6), "rot": 0},
		{"id": &"bk_ventana", "celda": Vector2i(-15, 4), "rot": 90},
	]
	for m: Dictionary in muestras:
		modo._fijar_herramienta(m["id"])
		modo._orientacion = int(m["rot"])
		modo._colocar_pieza_en(m["celda"])
	modo._capa_ui.visible = false
	var ref: Node2D = modo._nodos_pieza[Vector2i(-14, 4)] as Node2D
	main._camara.position = ref.global_position - get_viewport_rect().size / 2.0 + Vector2(100, 60)
	for m2: Dictionary in muestras:
		var c: Vector2i = m2["celda"]
		var nodo: Node2D = modo._nodos_pieza.get(c) as Node2D
		if nodo != null:
			var centro_celda: Vector2 = modo._origen + Proyeccion.centro_iso(c)
			print("[POS] celda ", c, " rot ", m2["rot"],
				" | centro_celda=", centro_celda,
				" | sprite.position=", nodo.position,
				" | delta=", nodo.position - centro_celda)
	# rejilla de celdas dibujada encima (rombos de cada celda de la zona de prueba)
	var rejilla := Node2D.new()
	rejilla.z_index = 4000
	rejilla.set_script(preload("res://tools/_diag_rejilla_dibujo.gd"))
	rejilla.set("origen", modo._origen)
	add_child(rejilla)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(CARPETA_SALIDA + "rejilla_piezas.png")
	print("[REJILLA] -> rejilla_piezas.png")
	get_tree().quit()
