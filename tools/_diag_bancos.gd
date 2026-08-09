extends Node2D
## SONDA DESECHABLE (2026-08-09): AC1+AC2 de la quick-spec de bancos multi-plaza EN EL JUEGO —
## coloca un banco de 3 plazas en la sala de espera y deja llegar gente para ver a TRES sentados.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/94657f06-d182-4b83-a1b4-9a4ad8a17e9b/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	var construccion: Node = main._construccion
	# Un banco de cada tier en la sala de espera de ODAC
	var puestos: Array = []
	for id: StringName in [&"banco_espera_medio", &"banco_espera_pro", &"banco_espera_basico"]:
		var colocado := false
		for y: int in range(5, 9):
			for x: int in range(9, 13):
				if not construccion.validar_elemento(id, Vector2i(x, y)):
					continue
				var e: StringName = construccion.construir_de_oficio_elemento(id, Vector2i(x, y))
				if e != &"":
					print("[BANCOS] ", id, " en ", Vector2i(x, y), " plazas=",
						construccion.plazas_sentadas_de(id))
					puestos.append(Vector2i(x, y))
					colocado = true
					break
			if colocado:
				break
	var sala: StringName = construccion.sala_en(puestos[0]) if not puestos.is_empty() else &""
	print("[BANCOS] celdas sentables de la sala: ",
		construccion.celdas_sentables_de_sala(sala).size())
	Tiempo.fijar_velocidad(Tiempo.Velocidad.X3)
	var sentados := 0
	for _i in 4000:
		await get_tree().physics_frame
		sentados = 0
		var plano: Node2D = main._npcs.get_node_or_null("PlanoLogico")
		if plano != null:
			for npc: Node in plano.get_children():
				if main._npcs.esta_sentado(npc):
					sentados += 1
		if sentados >= 3:
			break
	print("[BANCOS] NPCs SENTADOS a la vez: ", sentados)
	Tiempo.fijar_velocidad(Tiempo.Velocidad.PAUSA)
	main._camara.position = (
		construccion.centro_de_celda(Vector2i(10, 6)) - get_viewport_rect().size / 2.0
	)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(CARPETA_SALIDA + "bancos_ingame.png")
	print("[BANCOS] -> bancos_ingame.png")
	get_tree().quit()
