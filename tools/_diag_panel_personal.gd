extends Node2D
## SONDA DESECHABLE (2026-08-17): verifica VISUALMENTE el Tablón de Destinos (panel Personal, F3,
## maqueta `design/ux/maquetas-menu-2026-08/maqueta_personal.png`). Arranca `Main`, abre el panel
## por el mismo camino que la píldora del HUD (`Main._abrir_personal`), selecciona al primer agente
## de la plantilla (para que la ficha inferior se vea poblada) y se queda 20s quieta imprimiendo
## "[VENTANA] quieta" para dar tiempo a capturar con `captura_ventana.ps1`.
##
## Mismo patrón que `tools/_diag_panel_construccion_v2.gd`.

func _ready() -> void:
	# `load()` en `_ready()`, NO `preload()` a nivel de clase (TRAMPA CONOCIDA del proyecto): un
	# `-s script.gd` compila este fichero ANTES de que el motor registre los autoloads que `main.gd`
	# referencia por nombre. Cargar en `_ready()` corre ya con la `SceneTree` lista.
	var main: Node2D = load("res://src/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel: CanvasLayer = main._panel_personal
	main._abrir_personal()
	await get_tree().process_frame
	# FASE 1 (8 s): recién abierto, SIN selección — el estado de la ficha vacía (bug de la captura
	# `capturas/error.PNG`: el texto guía salía a una palabra por línea).
	var t_vacio: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t_vacio < 8.0:
		print("[VENTANA] quieta (ficha vacia, sin seleccion)")
		await get_tree().create_timer(1.0).timeout

	# FASE 2: selección + arrastre simulado.
	var personal: Node = main._personal
	if personal.plantilla.size() > 0:
		panel._seleccionar(personal.plantilla[0])
		# Simula el ARRASTRE del primer agente (sin ratón): los slots pintan su veredicto en vivo —
		# iluminado/intercambio con impacto/atenuado con motivo — que es lo que hay que auditar.
		var agente: RefCounted = personal.plantilla[0]
		panel._arrastre = {
			"agente": agente, "origen": "puesto", "puesto_origen": agente.puesto_id,
		}
		panel._pintar_estado_arrastre()
	print(
		"[SONDA] visible=", panel.visible, " slots=", panel._slots.size(),
		" plantilla=", personal.plantilla.size(), " seleccionado=",
		panel._agente_seleccionado != null, " arrastre_simulado=", not panel._arrastre.is_empty()
	)
	await get_tree().process_frame

	var t0: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t0 < 20.0:
		print("[VENTANA] quieta (tablon de destinos)")
		await get_tree().create_timer(1.0).timeout

	get_tree().quit()
