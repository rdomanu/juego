extends Node2D
## SONDA GPU DESECHABLE (2026-08-08): galería de TODOS los menús y submenús para el usuario
## ("pásame imagen de las ui... para ver los menús y submenús"). Captura cada pestaña de la barra
## de construcción (B) y cada categoría de la paleta del diseñador (F12, requiere lanzar la sonda
## con `-- --disenador`). Una captura por pestaña, al scratchpad de la sesión.
## Se borra tras usarla -- no es parte del pipeline final.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/1f7d5694-02c7-4fc1-9a44-a8546d82445c/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# ── Barra de construcción: las 5 pestañas, una captura por categoría ────────────────────────
	var construccion: Node2D = main._modo_construccion
	construccion._alternar_modo()
	construccion.set_process(false)   # gotcha _diag_ux_pintura: el ratón real pisa el estado
	await get_tree().process_frame
	for categoria: Dictionary in construccion.CATEGORIAS:
		construccion._mostrar_categoria(categoria["id"])
		await get_tree().process_frame
		await _capturar("menu_construccion_%s.png" % categoria["id"])
	construccion._alternar_modo()
	await get_tree().process_frame

	# ── Paleta del diseñador: las 5 categorías nuevas ───────────────────────────────────────────
	if main._modo_disenador_entorno != null:
		var disenador: Node2D = main._modo_disenador_entorno
		disenador.alternar()
		disenador.set_process(false)
		await get_tree().process_frame
		for categoria: Dictionary in disenador.CATEGORIAS:
			disenador._mostrar_categoria(categoria["id"])
			await get_tree().process_frame
			await _capturar("menu_disenador_%s.png" % categoria["id"])
	else:
		print("[DIAG UI MENUS] sin --disenador: paleta del diseñador no capturada")

	print("[DIAG UI MENUS] hecho.")
	get_tree().quit()


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = get_viewport().get_texture().get_image()
	imagen.save_png(CARPETA_SALIDA + nombre)
	print("[DIAG UI MENUS] -> " + nombre)
