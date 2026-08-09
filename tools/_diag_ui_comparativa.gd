extends Node2D
## SONDA GPU DESECHABLE (2026-08-08): capturas del juego real para la COMPARATIVA arte del kit de
## UI (hojas Summer aprobadas, capturas/fuentes/ui_kit_summer/) vs lo implementado en pantalla.
## La pidió el usuario: "enséñame la comparación [...] con los diferentes menús diseñados".
##
## Tres capturas al scratchpad de la sesión:
##  1. `ui_ingame_hud.png` -- el HUD de partida tal cual (barra superior PROVISIONAL de código,
##     fase 2 del kit pendiente de cablear -- se enseña para el contraste honesto).
##  2. `ui_ingame_barra_construccion.png` -- ModoConstruccion activo (tecla B): pestañas + tarjetas
##     + Demoler del kit (fase 1 implementada).
##  3. `ui_ingame_disenador.png` -- ModoDisenadorEntorno activo (F12): paleta con Theme del kit y
##     HUD oculto por la señal `activado_cambiado` (fix del solape). ⚠️ SOLO sale si la sonda se
##     lanza con `-- --disenador` (Main no instancia el modo sin el flag).
##
## Se borra tras usarla -- no es parte del pipeline final.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/94657f06-d182-4b83-a1b4-9a4ad8a17e9b/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# 1) HUD de partida tal cual.
	await _capturar("ui_ingame_hud.png")

	# 2) Barra de construcción nueva (lo que abre la tecla B). Gotcha documentado en
	# _diag_ux_pintura.gd: el _process del modo pisa el estado forzado con el ratón real fuera del
	# tablero -- se apaga para que la captura no dependa de dónde esté el cursor.
	main._modo_construccion._alternar_modo()
	main._modo_construccion.set_process(false)
	await get_tree().process_frame
	await _capturar("ui_ingame_barra_construccion.png")
	main._modo_construccion._alternar_modo()
	await get_tree().process_frame

	# 3) Paleta del modo diseñador (F12) con el HUD oculto por la señal del fix del solape.
	if main._modo_disenador_entorno != null:
		main._modo_disenador_entorno.alternar()
		main._modo_disenador_entorno.set_process(false)
		await get_tree().process_frame
		await _capturar("ui_ingame_disenador.png")
	else:
		print("[DIAG UI COMPARATIVA] sin --disenador: no hay captura de la paleta del diseñador")

	print("[DIAG UI COMPARATIVA] hecho.")
	get_tree().quit()


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = get_viewport().get_texture().get_image()
	imagen.save_png(CARPETA_SALIDA + nombre)
	print("[DIAG UI COMPARATIVA] -> " + nombre)
