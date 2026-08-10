extends Node2D
## SONDA DESECHABLE (2026-08-10): comprobar que el banco al 75 % SIGUE CUBRIENDO SUS 3 PLAZAS.
##
## Por qué hace falta: los NPC no se sientan "en el dibujo del banco", se sientan en CELDAS, y dos
## celdas contiguas distan 40 px (medio rombo). Al bajar el banco de 108 a 81 px de ancho, la
## holgura sobre los 80 px que separan la 1.ª plaza de la 3.ª se queda en 1 px. Un montaje de
## Python no sirve para juzgarlo (el anclaje real lo hace el juego): hay que verlo EN EL MOTOR.
##
## A diferencia de `_diag_bancos`, esta espera a que los tres sentados estén EN LAS CELDAS DEL
## BANCO (no en las sillas sueltas de la sala) y centra la cámara sobre el banco.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/e2c7999d-e339-490c-a281-ff422a3ef574/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	var construccion: Node = main._construccion

	# Un solo banco de 3 plazas, para que los NPC no tengan dónde repartirse.
	var celda_banco := Vector2i(-1, -1)
	for y: int in range(5, 9):
		for x: int in range(9, 13):
			if construccion.validar_elemento(&"banco_espera_medio", Vector2i(x, y)):
				if construccion.construir_de_oficio_elemento(&"banco_espera_medio", Vector2i(x, y)) != &"":
					celda_banco = Vector2i(x, y)
					break
		if celda_banco.x >= 0:
			break
	if celda_banco.x < 0:
		print("[BANCO75] no se pudo colocar el banco")
		get_tree().quit()
		return
	print("[BANCO75] banco en ", celda_banco, " plazas=", construccion.plazas_sentadas_de(&"banco_espera_medio"))

	# Los SITIOS del banco: los da el propio mueble (2026-08-10, "que mande el mueble, no la celda"),
	# así que hay 3 sitios sobre 2 celdas. Se compara por distancia al sitio.
	var sala_banco: StringName = construccion.sala_en(celda_banco)
	var centros: Array[Vector2] = construccion.sitios_sentables_de_sala(sala_banco)
	print("[BANCO75] sitios que ofrece la sala: ", centros.size())

	Tiempo.fijar_velocidad(Tiempo.Velocidad.X3)
	var en_banco := 0
	for _i in 8000:
		await get_tree().physics_frame
		en_banco = 0
		var plano: Node2D = main._npcs.get_node_or_null("PlanoLogico")
		if plano != null:
			for npc: Node in plano.get_children():
				if not main._npcs.esta_sentado(npc):
					continue
				for centro: Vector2 in centros:
					if npc.position.distance_to(centro) < 22.0:
						en_banco += 1
						break
		if en_banco >= centros.size():
			break
	print("[BANCO75] sentados EN EL BANCO: ", en_banco, " de ", centros.size())

	Tiempo.fijar_velocidad(Tiempo.Velocidad.PAUSA)
	main._camara.position = (
		construccion.centro_de_celda(celda_banco) - get_viewport_rect().size / 2.0
	)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(CARPETA_SALIDA + "banco75_ingame.png")
	print("[BANCO75] -> banco75_ingame.png")
	get_tree().quit()
