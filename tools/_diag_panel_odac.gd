extends Node2D
## SONDA DESECHABLE (2026-08-18): verifica VISUALMENTE la pantalla de dedicación de ODAC (F4, maqueta
## `design/ux/maquetas-menu-2026-08/maqueta_odac.png`). Arranca `Main`, abre el panel por el MISMO
## camino que la tecla O / el menú de la sala (`abrir()`) con el estado REAL del arranque, y se queda
## 20 s quieta imprimiendo "[VENTANA] quieta" para capturar con `captura_ventana.ps1`.
##
## Mismo patrón que `tools/_diag_panel_personal.gd`.

func _ready() -> void:
	# `load()` en `_ready()`, NO `preload()` a nivel de clase (trampa conocida: autoloads aún sin
	# registrar cuando `-s` compila este fichero).
	var main: Node2D = load("res://src/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel: CanvasLayer = main._panel_odac
	panel.abrir()
	await get_tree().process_frame
	await get_tree().process_frame
	print(
		"[SONDA] visible=", panel.visible,
		" ventanillas=", panel._rejilla.get_child_count(),
		" banner=", panel._banner.visible,
		" sin_cubrir=", main._odac.denuncias_sin_cubrir().size(),
		" cola='", panel._lbl_urgentes.text, "' / '", panel._lbl_administrativas.text, "'"
	)
	print(
		"[MEDIDAS] ventana=", DisplayServer.window_get_size(),
		" viewport=", panel._panel.get_viewport_rect().size,
		" panel_pos=", panel._panel.position, " panel_size=", panel._panel.size
	)

	var t0: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t0 < 20.0:
		print("[VENTANA] quieta (panel de ODAC)")
		await get_tree().create_timer(1.0).timeout

	get_tree().quit()
