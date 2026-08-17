extends Node2D
## SONDA DESECHABLE (2026-08-18): verifica VISUALMENTE la pantalla de HORARIO (F3, maqueta
## `design/ux/maquetas-menu-2026-08/maqueta_horario.png`). Arranca `Main`, abre el panel por el mismo
## camino que la píldora del HUD (`Main._abrir_horario`) y se queda quieta imprimiendo
## "[VENTANA] quieta" para dar tiempo a capturar con `tools/captura_ventana.ps1`.
##
## FASE 1 (8 s): el panel RECIÉN ABIERTO, con el horario de partida (sin horas extra) — el estado en el
## que lo ve el jugador al pulsar H.
## FASE 2 (12 s): el escenario de la maqueta forzado POR CÓDIGO — comunicado de la División activo
## (tope ampliado a 21:30, que dibuja la marca del tope ordinario), cierre a las 17:00 movido por el
## PROPIO slider (pasa por `value_changed`, como el arrastre del jugador) y peonada a 22 €/hora, para
## que las líneas de consecuencia y el coste total tengan cifras que auditar.
##
## Mismo patrón que `tools/_diag_panel_personal.gd`.

func _ready() -> void:
	# `load()` en `_ready()`, NO `preload()` a nivel de clase (TRAMPA CONOCIDA del proyecto): un
	# `-s script.gd` compila este fichero ANTES de que el motor registre los autoloads que `main.gd`
	# referencia por nombre. Cargar en `_ready()` corre ya con la `SceneTree` lista.
	var main: Node2D = load("res://src/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel: CanvasLayer = main._panel_horario
	main._abrir_horario()
	await get_tree().process_frame
	var doc: Node = main._documentacion
	print(
		"[SONDA] fase1 visible=", panel.visible, " ventanillas=",
		panel._lista_ventanillas.get_child_count(), " cierre=", doc.hora_cierre_min,
		" agentes=", doc.num_agentes_doc()
	)
	# Diagnóstico de layout: quién manda el tamaño del modal (min combinado vs viewport).
	print(
		"[LAYOUT] viewport=", panel._panel.get_viewport_rect().size,
		" panel.size=", panel._panel.size, " panel.min=", panel._panel.get_combined_minimum_size()
	)
	var cuerpo: Node = panel._ctrl_cierre.get_parent().get_parent().get_parent().get_parent()
	for hijo: Node in cuerpo.get_children():
		if hijo is Control:
			print(
				"[LAYOUT] columna ", hijo.name, " size=", (hijo as Control).size,
				" min=", (hijo as Control).get_combined_minimum_size()
			)
	print(
		"[LAYOUT] tarjeta cierre min=", panel._ctrl_cierre.get_combined_minimum_size(),
		" consecuencia min=", panel._ctrl_cierre.lbl_consecuencia.get_combined_minimum_size(),
		" valor min=", panel._ctrl_cierre.lbl_valor.get_combined_minimum_size(),
		" sub min=", panel._ctrl_cierre.lbl_sub.get_combined_minimum_size()
	)
	var t1: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t1 < 8.0:
		print("[VENTANA] quieta (horario recien abierto)")
		await get_tree().create_timer(1.0).timeout

	# FASE 2 — el escenario de la maqueta: comunicado activo + tarde ampliada + peonada generosa.
	doc.evento_activo_id = &"vacaciones"
	var evento: Resource = doc.evento_activo()
	if evento != null:
		doc.tope_evento_min = evento.cierre_max_min
	panel._refrescar()
	panel._ctrl_precio.slider.value = 22.0
	panel._ctrl_cierre.slider.value = 1020.0   # 17:00 → 2,5 h extra
	await get_tree().process_frame
	print(
		"[SONDA] fase2 cierre=", doc.hora_cierre_min, " tope=", doc.tope_autorizado(),
		" peonada=", doc.peonada_eur_hora, " coste=", doc.coste_peonada_estimado(),
		" banner=", panel._banner.visible, " consecuencia='",
		panel._ctrl_cierre.lbl_consecuencia.text, "'"
	)
	var t2: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t2 < 12.0:
		print("[VENTANA] quieta (horario con peonada)")
		await get_tree().create_timer(1.0).timeout

	get_tree().quit()
