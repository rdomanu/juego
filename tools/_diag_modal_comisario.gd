extends Node2D
## SONDA DESECHABLE (2026-08-18): verifica VISUALMENTE el reskin F4 del modal del Comisario y de
## los menús contextuales. DOS FASES: (1) el menú de sala abierto con `popup()` programático (8 s);
## (2) el modal de rescate, disparado por el MISMO camino real que Economía (la señal
## `insolvencia` del bus). Capturar con `captura_ventana.ps1` a ~6 s y ~12 s.
##
## Mismo patrón que `tools/_diag_panel_personal.gd`.

func _ready() -> void:
	# `load()` en `_ready()`, NO `preload()` a nivel de clase (trampa conocida del proyecto).
	var main: Node2D = load("res://src/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# FASE 1: el menú contextual de sala, estilizado por el kit.
	var menu: PopupMenu = main._menu_sala
	menu.position = Vector2i(520, 320)
	# El menú real se puebla al abrirse sobre una sala; para AUDITAR EL ESTILO bastan ítems de
	# muestra con los textos reales del juego.
	if menu.item_count == 0:
		menu.add_item("Gestionar la sala")
		menu.add_separator()
		menu.add_item("Pintar paredes")
		menu.add_item("Pintar suelo")
	menu.popup()
	print("[SONDA] fase1 menu_visible=", menu.visible, " items=", menu.item_count)
	var t1: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t1 < 8.0:
		print("[VENTANA] quieta (menu de sala)")
		await get_tree().create_timer(1.0).timeout
	menu.hide()

	# FASE 2: el modal de rescate por el camino REAL (la señal del bus que emite Economía).
	EventBus.insolvencia.emit(-1240.0, 2)
	await get_tree().process_frame
	var modal: CanvasLayer = get_tree().root.find_child("ModalComisario", true, false)
	print("[SONDA] fase2 modal_visible=", modal.visible)
	for hijo: Node in modal.get_children():
		if hijo is Control:
			var c: Control = hijo
			print("[MEDIDA] ", c.get_class(), " '", c.name, "' min=", c.get_combined_minimum_size(), " size=", c.size, " pos=", c.position)
			for nieto: Node in c.get_children():
				if nieto is Control:
					var cc: Control = nieto
					print("[MEDIDA]   ", cc.get_class(), " '", cc.name, "' min=", cc.get_combined_minimum_size())
	var t2: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t2 < 12.0:
		print("[VENTANA] quieta (modal de rescate)")
		await get_tree().create_timer(1.0).timeout

	get_tree().quit()
