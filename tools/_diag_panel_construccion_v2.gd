extends Node2D
## SONDA DESECHABLE (2026-08-15): verifica VISUALMENTE el panel de construcción v2 (F0/F1, reskin
## claro con tarjetas de sombra — maquetas `design/ux/maquetas-menu-2026-08/`). Arranca `Main`, abre
## el modo construcción con un asiento de catálogo YA en la mano (para que la ficha enseñe las tres
## barras: Confort/Nota al salir/Paciencia extra) y se queda 15s quieta imprimiendo
## "[VENTANA] quieta" para dar tiempo a capturar con `captura_ventana.ps1`.
##
## Mismo patrón que `tools/_diag_fantasma_trazo_muro.gd`.

func _ready() -> void:
	# `load()` en `_ready()`, NO `preload()` a nivel de clase (TRAMPA CONOCIDA del proyecto): un
	# `-s script.gd` compila este fichero ANTES de que el motor termine de registrar los autoloads
	# (`Tiempo`, `EventBus`...) que `main.gd` referencia por nombre -- un `preload` a nivel de clase
	# fuerza esa compilación demasiado pronto ("Identifier not found: Tiempo"). Cargar en `_ready()`
	# corre ya con la `SceneTree` lista.
	var main: Node2D = load("res://src/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var modo: Node = main._modo_construccion
	modo.activar_con_herramienta(&"silla_espera_azul", false)
	print(
		"[SONDA] activo=", modo._activo, " herramienta=", modo._herramienta,
		" categoria_activa=", modo._categoria_activa,
		" ficha_confort_visible=", modo._ficha_fila_confort.visible
	)
	await get_tree().process_frame

	var t0: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t0 < 15.0:
		print("[VENTANA] quieta (panel de construcción v2)")
		await get_tree().create_timer(1.0).timeout

	get_tree().quit()
