extends Node2D
## SONDA DESECHABLE (2026-08-18): verifica VISUALMENTE la ficha de ventanilla (F3, maqueta
## `design/ux/maquetas-menu-2026-08/maqueta_ventanilla.png`). Arranca `Main`, abre la ficha de la
## primera ventanilla de Documentación por el MISMO camino que el clic (`mostrar`) y se queda 20 s
## quieta imprimiendo "[VENTANA] quieta" para capturar con `captura_ventana.ps1`. Imprime si el
## MARCADOR del mundo está encendido (el halo sobre la mesa es parte de lo que se audita).
##
## Mismo patrón que `tools/_diag_panel_personal.gd`.

func _ready() -> void:
	# `load()` en `_ready()`, NO `preload()` a nivel de clase (trampa conocida: autoloads aún sin
	# registrar cuando `-s` compila este fichero).
	var main: Node2D = load("res://src/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel: CanvasLayer = main._panel_ventanilla
	panel.mostrar(&"doc_1")
	await get_tree().process_frame
	print(
		"[SONDA] visible=", panel.visible, " puesto=", panel._puesto_id,
		" marcador_encendido=",
		main._marcador_ventanilla != null and main._marcador_ventanilla.esta_encendido()
	)
	print(
		"[MEDIDAS] ventana=", DisplayServer.window_get_size(),
		" viewport=", panel._panel.get_viewport_rect().size,
		" pantalla=", DisplayServer.screen_get_size(),
		" escala=", DisplayServer.screen_get_scale(),
		" panel_pos=", panel._panel.position, " panel_size=", panel._panel.size
	)

	var t0: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t0 < 20.0:
		print("[VENTANA] quieta (ficha de ventanilla)")
		await get_tree().create_timer(1.0).timeout

	get_tree().quit()
