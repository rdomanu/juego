extends Node2D
## SONDA DESECHABLE (2026-08-09): construye la MISMA ventanilla en las 4 orientaciones para
## comprobar que gira ENTERA — mostrador, silla del funcionario y sitio del ciudadano.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/94657f06-d182-4b83-a1b4-9a4ad8a17e9b/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var construccion: Node = main._construccion
	# Sala de pruebas amplia y vacia (los puestos SOLO viven dentro de salas, CO4).
	var sala: StringName = construccion.construir_de_oficio_sala(&"sala_odac", Rect2i(14, 6, 8, 5))
	print("[VENTANILLA] sala de pruebas: ", sala)
	# Buscar celdas donde SI se pueda construir el puesto, una por orientacion.
	var orientaciones: Array[int] = [0, 90, 180, 270]
	var puestos: Array = []
	for orientacion: int in orientaciones:
		var colocado := false
		for y: int in range(6, 11):
			for x: int in range(14, 22):
				var celda := Vector2i(x, y)
				if not construccion.validar_elemento(&"puesto_odac", celda, &"", orientacion):
					continue
				var id: StringName = construccion.construir_elemento(&"puesto_odac", celda, orientacion)
				if id != &"":
					puestos.append({"id": id, "celda": celda, "orientacion": orientacion})
					print("[VENTANILLA] rot ", orientacion, " en ", celda, " frente=",
						construccion.frente_de_orientacion(orientacion))
					colocado = true
					break
			if colocado:
				break
		if not colocado:
			print("[VENTANILLA] rot ", orientacion, ": sin sitio libre")
	for _i in 30:
		await get_tree().physics_frame
	main._camara.position = (
		main._construccion.centro_de_celda(Vector2i(18, 7)) - get_viewport_rect().size / 2.0
	)
	main._camara.zoom = Vector2(0.75, 0.75)
	main._camara.position = (
		main._construccion.centro_de_celda(Vector2i(18, 7))
		- get_viewport_rect().size / 2.0 / 0.75
	)
	Tiempo.fijar_velocidad(Tiempo.Velocidad.PAUSA)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(CARPETA_SALIDA + "ventanillas_rotadas.png")
	print("[VENTANILLA] -> ventanillas_rotadas.png")
	get_tree().quit()
