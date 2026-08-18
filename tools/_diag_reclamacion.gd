extends Node2D
## SONDA DESECHABLE (2026-08-18): demuestra EN VIVO el circuito completo de la mejora ① — un
## ciudadano quemado abandona, con probabilidad forzada a 1 pone su HOJA DE RECLAMACIONES, y eso
## significa: el toast "Nueva reclamación · <servicio>" suena Y una persona nueva entra por la
## puerta hacia la cola de ODAC (la hoja se pone EN la ODAC — realismo confirmado por el usuario).
## Se queda 60 s para que el jugador lo vea pasar. Todo por el cableado REAL (Paciencia → bus →
## Main admite y encola), nada simulado.

func _ready() -> void:
	# `load()` en `_ready()`, NO `preload()` a nivel de clase (trampa conocida del proyecto).
	var main: Node2D = load("res://src/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# Esperar a que la mañana traiga a alguien a la cola de Documentación (llegadas reales).
	var flujo: Node = main._flujo
	var paciencia: Node = main._paciencia
	paciencia.prob_reclamacion = 1.0
	# El toast de aviso se desvanece en segundos y esta demo es para MIRARLA: se alarga su vida.
	main._avisos.duraciones[&"aviso"] = 45.0
	var intentos: int = 0
	while flujo.personas_en_cola(&"Documentacion") == 0 and intentos < 120:
		intentos += 1
		await get_tree().create_timer(0.5).timeout
	if flujo.personas_en_cola(&"Documentacion") == 0:
		print("[SONDA] SIN cola tras 60 s — no se puede demostrar el abandono")
	else:
		var victima: RefCounted = flujo.personas_de_cola(&"Documentacion")[0]
		flujo.forzar_abandono(victima)
		paciencia.procesar_abandono(victima)
		print(
			"[SONDA] abandono forzado en Documentacion -> reclamaciones_jornada=",
			paciencia.reclamaciones_jornada, " · mira el toast y la puerta: entra la hoja a ODAC"
		)

	var t0: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t0 < 60.0:
		print("[VENTANA] quieta (reclamacion en vivo)")
		await get_tree().create_timer(1.0).timeout

	get_tree().quit()
