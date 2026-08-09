extends Node2D
## SONDA DESECHABLE (2026-08-09): comprueba EN EL JUEGO los dos arreglos del encargo del usuario:
##  1. El ciudadano atendido MIRA AL MOSTRADOR (antes se quedaba de espaldas).
##  2. El papel va EN LA MANO (antes sobre la cara) y respeta las capas.
## Deja el juego correr hasta que alguien esté en atención y captura.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/94657f06-d182-4b83-a1b4-9a4ad8a17e9b/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	Tiempo.fijar_velocidad(Tiempo.Velocidad.X3)
	var npcs: Node = main._npcs
	var atendido: Node = null
	for _i in 3000:
		await get_tree().physics_frame
		var plano: Node2D = npcs.get_node_or_null("PlanoLogico")
		if plano == null:
			continue
		for npc: Node in plano.get_children():
			if npc.get("persona") != null and npc.persona.estado == &"en_atencion":
				atendido = npc
				break
		if atendido != null:
			break
	if atendido == null:
		print("[CIUDADANO] nadie llego a atencion")
		get_tree().quit()
		return
	# marcar que lleva papel para ver dónde cae
	atendido.persona.con_papel = true
	for _i in 30:
		await get_tree().physics_frame
	var visual: Node2D = atendido.muneco
	var cuerpo: Node = visual.get_child(0)
	var papel: Node2D = visual.get_node_or_null("Papel") as Node2D
	print("[CIUDADANO] cuerpo=", cuerpo.name, " tiene_prefijo=", cuerpo.has_meta(&"prefijo"),
		" metas=", cuerpo.get_meta_list())
	print("[CIUDADANO] direccion del sprite = ", cuerpo.get_meta(&"direccion", -1),
		" (DIRECCION_SENTADO mira al norte)")
	print("[CIUDADANO] papel en ", papel.position if papel != null else "SIN PAPEL",
		"  indice=", papel.get_index() if papel != null else -1,
		" de ", visual.get_child_count(), " hijos")
	Tiempo.fijar_velocidad(Tiempo.Velocidad.PAUSA)
	var vis: Node2D = atendido.muneco
	main._camara.position = vis.global_position - get_viewport_rect().size / 2.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(CARPETA_SALIDA + "ciudadano_papel.png")
	print("[CIUDADANO] -> ciudadano_papel.png")
	get_tree().quit()
