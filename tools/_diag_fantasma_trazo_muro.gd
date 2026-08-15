extends Node2D
## SONDA DESECHABLE (2026-08-15): verifica VISUALMENTE el fantasma del TRAZO COMPLETO del pincel de
## muro (modo construcción "estilo Los Sims" — tarea de fase 1). Inyecta un press + varios motion
## REALES (sin soltar) sobre un tramo de pared nuevo, se queda 15s quieta imprimiendo
## "[VENTANA] quieta" para dar tiempo a capturar con el .ps1 de PrintWindow, luego suelta, espera y
## se vuelve a quedar quieta otros 15s con el muro ya construido.
##
## Mismo patrón que `tools/_diag_arrastre_real.gd` (Input.parse_input_event, no `_unhandled_input` a
## mano) y que `tools/_diag_puertas.gd` para la pausa larga con print periódico.

const MainEscena := preload("res://src/main/Main.tscn")


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var modo: Node = main._modo_construccion
	modo.activar_con_herramienta(&"muro", false)
	print("[SONDA] herramienta=", modo._herramienta, " activo=", modo._activo)

	# Un tramo de pared NUEVO, dentro del edificio: fila 6, columnas 2..6 (arista de ARRIBA de esa
	# fila) -- lejos de la fachada y de cualquier sala ya montada de oficio.
	var construccion: Node = main._construccion
	var celda_ini := Vector2i(2, 6)
	var p0: Vector2 = construccion.esquina_en_pantalla(celda_ini.x, celda_ini.y) + Vector2(20.0, -10.0)

	var pulsar := InputEventMouseButton.new()
	pulsar.button_index = MOUSE_BUTTON_LEFT
	pulsar.pressed = true
	pulsar.position = p0
	Input.parse_input_event(pulsar)
	await get_tree().process_frame

	for i in 4:
		var mover := InputEventMouseMotion.new()
		mover.position = p0 + Vector2(40.0 * float(i + 1), 0.0)
		mover.relative = Vector2(40.0, 0.0)
		Input.parse_input_event(mover)
		await get_tree().process_frame

	print("[SONDA] trazo vivo: arrastrando_muro=", modo._arrastrando_muro,
		" aristas=", modo._aristas_de_la_linea().size())

	# 15s QUIETA con el fantasma del trazo completo en pantalla (SIN soltar) -- tiempo para capturar
	# con el .ps1 de PrintWindow.
	var t0: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t0 < 15.0:
		print("[VENTANA] quieta (fantasma del trazo)")
		await get_tree().create_timer(1.0).timeout

	var soltar := InputEventMouseButton.new()
	soltar.button_index = MOUSE_BUTTON_LEFT
	soltar.pressed = false
	soltar.position = p0 + Vector2(160.0, 0.0)
	Input.parse_input_event(soltar)
	await get_tree().process_frame
	await get_tree().process_frame

	print("[SONDA] tras soltar: hay_muro(2,6,arriba)=", construccion.hay_muro(Vector2i(2, 6), &"arriba"),
		" hay_muro(6,6,arriba)=", construccion.hay_muro(Vector2i(6, 6), &"arriba"),
		" estado=", modo._lbl_estado.text)

	# 15s QUIETA con el muro YA construido -- segunda captura.
	var t1: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t1 < 15.0:
		print("[VENTANA] quieta (muro construido)")
		await get_tree().create_timer(1.0).timeout

	get_tree().quit()
