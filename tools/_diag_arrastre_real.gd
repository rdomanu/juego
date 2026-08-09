extends Node2D
## SONDA DESECHABLE (2026-08-09): prueba el ARRASTRE del diseñador con eventos de ratón REALES
## inyectados en el árbol (`Input.parse_input_event`, no llamando a `_unhandled_input` a mano como
## hacen los tests) — el usuario reporta que "hacer clic en una pared y arrastrar no funciona".

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/94657f06-d182-4b83-a1b4-9a4ad8a17e9b/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var modo: Node = main._modo_disenador_entorno
	modo.alternar()
	modo._fijar_base_visible(false)
	modo._fijar_herramienta(&"bk_muro")
	modo._orientacion = 90
	var antes: int = modo._piezas.size()
	# espía: ¿llega el evento al diseñador?
	var espia := Node.new()
	espia.set_script(GDScript.new())
	print("[ARRASTRE] herramienta=", modo._herramienta, " activo=", modo._activo,
		" process_unhandled_input=", modo.is_processing_unhandled_input())
	print("[ARRASTRE] celda bajo (700,500) = ", modo._celda_de_evento(Vector2(700, 500)),
		" valida=", modo._celda_valida(modo._celda_de_evento(Vector2(700, 500))))

	# Arrastre REAL: pulsar en un punto y mover el ratón por 4 posiciones antes de soltar.
	# apuntar a una celda FUERA del edificio (el diseñador veta el rect jugable 24x13 a propósito)
	var celda_ini := Vector2i(-16, 4)
	main._camara.position = (
		modo._origen + Proyeccion.centro_iso(celda_ini) - get_viewport_rect().size / 2.0
	)
	await get_tree().process_frame
	var p0: Vector2 = (
		modo._origen + Proyeccion.centro_iso(celda_ini) - main._camara.position
	)
	print("[ARRASTRE] celda destino ", celda_ini, " -> pantalla ", p0,
		" valida=", modo._celda_valida(modo._celda_de_evento(p0)))
	var pulsar := InputEventMouseButton.new()
	pulsar.button_index = MOUSE_BUTTON_LEFT
	pulsar.pressed = true
	pulsar.position = p0
	Input.parse_input_event(pulsar)
	await get_tree().process_frame
	for i in 4:
		var mover := InputEventMouseMotion.new()
		mover.position = p0 + Vector2(40.0 * float(i + 1), 20.0 * float(i + 1))
		mover.relative = Vector2(40.0, 20.0)
		Input.parse_input_event(mover)
		await get_tree().process_frame
	var soltar := InputEventMouseButton.new()
	soltar.button_index = MOUSE_BUTTON_LEFT
	soltar.pressed = false
	soltar.position = p0 + Vector2(160.0, 80.0)
	Input.parse_input_event(soltar)
	await get_tree().process_frame

	print("[ARRASTRE] piezas antes=%d despues=%d  (colocadas: %d)" % [
		antes, modo._piezas.size(), modo._piezas.size() - antes
	])
	print("[ARRASTRE] _pintando quedo en: ", modo._pintando)
	modo._capa_ui.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(CARPETA_SALIDA + "arrastre_real.png")
	get_tree().quit()
