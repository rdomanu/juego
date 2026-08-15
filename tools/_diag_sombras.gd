extends Node2D
## SONDA DESECHABLE (2026-08-14, v2 tras el rediseño CapaSombras): verificación NUMÉRICA de las
## sombras de contacto en el juego real. Coloca los tres bancos, deja llegar gente, y MUESTREA
## PÍXELES de la captura: el anillo alrededor de la base de cada pieza debe salir claramente más
## oscuro que el suelo lejano. También guarda dos capturas para la revisión visual.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/aad5e0e0-a0be-4878-b068-20ca5cee13c8/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	var construccion: Node = main._construccion
	# Un banco de cada tier en la sala de espera de ODAC (mismo barrido que _diag_bancos)
	var bancos: Array[Vector2] = []
	for id: StringName in [&"banco_espera_medio", &"banco_espera_pro", &"banco_espera_basico"]:
		var colocado := false
		for y: int in range(5, 9):
			for x: int in range(9, 13):
				if not construccion.validar_elemento(id, Vector2i(x, y)):
					continue
				if construccion.construir_de_oficio_elemento(id, Vector2i(x, y)) != &"":
					bancos.append(construccion.centro_de_celda(Vector2i(x, y)))
					colocado = true
					break
			if colocado:
				break
	Tiempo.fijar_velocidad(Tiempo.Velocidad.X3)
	var sentados := 0
	var andando := 0
	var visual_andante: Node2D = null
	for _i in 4000:
		await get_tree().physics_frame
		sentados = 0
		andando = 0
		var plano: Node2D = main._npcs.get_node_or_null("PlanoLogico")
		if plano == null:
			continue
		for npc: Node in plano.get_children():
			if main._npcs.esta_sentado(npc):
				sentados += 1
			else:
				andando += 1
		if sentados >= 2 and andando >= 2:
			break
	print("[SOMBRAS] sentados=", sentados, " andando=", andando)
	Tiempo.fijar_velocidad(Tiempo.Velocidad.PAUSA)

	# Un visual andante con sombra visible, para muestrear bajo sus pies
	var capa_escena: Node2D = main._npcs._capa_escena
	for hijo: Node in capa_escena.get_children():
		var v := hijo as Node2D
		if v != null and bool(v.get_meta(&"sombra_visible", false)) and v.has_meta(&"pos_suelo_sombra"):
			visual_andante = v
			break

	# Captura 1: vista general centrada en la zona de bancos
	main._camara.position = (
		construccion.centro_de_celda(Vector2i(12, 7)) - get_viewport_rect().size / 2.0
	)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(CARPETA_SALIDA + "sombras_general.png")
	var cam: Vector2 = -main._camara.position

	# ── MUESTREO NUMÉRICO ────────────────────────────────────────────────────────────────────────
	# Bancos: extremo del eje largo (fuera del dibujo, dentro de la elipse) contra suelo lejano.
	for centro: Vector2 in bancos:
		var p: Vector2 = centro + cam
		print("[MEDIDA] banco centro_mundo=", centro,
			" anillo=", img.get_pixel(int(p.x) - 26, int(p.y) + 13),
			" lejos=", img.get_pixel(int(p.x) - 70, int(p.y) + 35))
	# Muñeco andante: justo al lado de sus pies contra suelo lejano.
	if visual_andante != null:
		var ps: Vector2 = (visual_andante.get_meta(&"pos_suelo_sombra") as Vector2) + cam
		print("[MEDIDA] muneco suelo_mundo=", visual_andante.get_meta(&"pos_suelo_sombra"),
			" anillo=", img.get_pixel(int(ps.x) + 12, int(ps.y) + 2),
			" lejos=", img.get_pixel(int(ps.x) + 55, int(ps.y) + 8))
	else:
		print("[MEDIDA] SIN muñeco andante con sombra que medir")
	# Registro de la capa
	print("[MEDIDA] registros de CapaSombras (muebles, munecos): ", main._capa_sombras.numero_registrados())

	# VENTANA QUIETA 15 s con la cámara conocida: la captura REAL se hace desde fuera con
	# PrintWindow (el volcado get_image() del viewport en Compatibility PIERDE contenido —
	# fue el origen de toda la cacería fantasma del 2026-08-14/15).
	print("[VENTANA] quieta 15 s: camara=", main._camara.position, " zoom=", main._camara.zoom)
	await get_tree().create_timer(15.0, true).timeout
	# Captura 2 (por el camino roto, solo como referencia del bug): plano con zoom del juego
	main._camara.zoom = Vector2(1.6, 1.6)
	main._camara.position = (
		construccion.centro_de_celda(Vector2i(10, 6)) - get_viewport_rect().size / (2.0 * 1.6)
	)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(CARPETA_SALIDA + "sombras_sala.png")
	get_tree().quit()
