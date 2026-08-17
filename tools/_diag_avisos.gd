extends Node2D
## SONDA DESECHABLE (2026-08-18): verifica VISUALMENTE la PILA DE AVISOS (F3, maqueta
## `design/ux/maquetas-menu-2026-08/maqueta_avisos.png`). Arranca `Main`, abre la ficha de la primera
## ventanilla de Documentación (para retratar la CONVIVENCIA: la pila debe apartarse a su izquierda)
## y dispara por la API pública los TRES toasts de la maqueta, uno por severidad. Se queda 20 s
## quieta imprimiendo "[VENTANA] quieta" para capturar con `captura_ventana.ps1`.
##
## Las duraciones se alargan A PROPÓSITO (solo en la sonda): con las de juego, el INFO y el AVISO ya
## se habrían desvanecido cuando se dispara la captura (~9 s). Con 60 s y 20 s, a los 9 s las barras
## de progreso quedan justo en el 0,85 y el 0,55 que retrata la maqueta.
##
## Mismo patrón que `tools/_diag_panel_ventanilla.gd`.

func _ready() -> void:
	# `load()` en `_ready()`, NO `preload()` a nivel de clase (trampa conocida: autoloads aún sin
	# registrar cuando `-s` compila este fichero).
	var main: Node2D = load("res://src/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var ficha: CanvasLayer = main._panel_ventanilla
	ficha.mostrar(&"doc_1")
	await get_tree().process_frame

	var avisos: CanvasLayer = main._avisos
	avisos.duraciones[&"info"] = 60.0
	avisos.duraciones[&"aviso"] = 20.0
	avisos.avisar_evento(
		&"critico", "Saldo en números rojos",
		"-1.240 € · gasto voluntario bloqueado hasta salir de deuda"
	)
	avisos.avisar_evento(
		&"aviso", "Nueva reclamación", "Documentación · por una espera larga"
	)
	avisos.avisar_evento(
		&"info", "Elena Ortiz se va a descansar", "15 min · deja DNI 1"
	)
	await get_tree().process_frame
	await get_tree().process_frame

	print(
		"[SONDA] visibles=", avisos.avisos_visibles(), " en_espera=", avisos.avisos_en_espera(),
		" ficha_visible=", ficha.visible
	)
	print(
		"[MEDIDAS] ventana=", DisplayServer.window_get_size(),
		" viewport=", avisos._pila.get_viewport_rect().size,
		" pila_pos=", avisos._pila.position, " pila_size=", avisos._pila.size,
		" borde_izq_ficha=", ficha.borde_izquierdo()
	)
	for tarjeta: Node in avisos._pila.get_children():
		print(
			"[TARJETA] ", tarjeta.get_meta("severidad"), " pos=", tarjeta.position,
			" size=", tarjeta.size
		)

	var t0: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t0 < 90.0:
		print("[VENTANA] quieta (pila de avisos)")
		await get_tree().create_timer(1.0).timeout

	get_tree().quit()
