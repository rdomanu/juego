extends Node2D
## SONDA DESECHABLE (2026-08-14): ¿se VE la sombra de contacto en aislamiento?
## Fondo plano + una sombra suelta grande + un muñeco de sprite recién construido.
## Imprime el árbol y los datos de la textura para separar "no se genera" de "no se ve".

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/aad5e0e0-a0be-4878-b068-20ca5cee13c8/scratchpad/"
const SombraContactoScript := preload("res://src/foundation/proyeccion/sombra_contacto.gd")
const MunecoScript := preload("res://src/main/muneco.gd")


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.87, 0.84, 0.78)
	fondo.size = Vector2(640, 360)
	add_child(fondo)
	# 1) Sombra suelta, grande (semiejes 20,20 = una celda entera)
	var sombra: Sprite2D = SombraContactoScript.crear_sprite(Vector2(20, 20))
	sombra.position = Vector2(160, 180)
	add_child(sombra)
	var tex: Texture2D = sombra.texture
	var img: Image = tex.get_image()
	print("[AISLADA] textura: ", tex, " tam=", tex.get_size(),
		" alfa_centro=", img.get_pixel(32, 32).a, " alfa_borde=", img.get_pixel(0, 0).a)
	print("[AISLADA] sombra transform=", sombra.transform, " modulate=", sombra.modulate,
		" visible=", sombra.visible)
	# 2) Muñeco de sprite con su sombra integrada
	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = Vector2(420, 200)
	add_child(muneco)
	for hijo: Node in muneco.get_children():
		print("[AISLADA] hijo del muneco: ", hijo.name, " class=", hijo.get_class(),
			" visible=", (hijo as CanvasItem).visible if hijo is CanvasItem else "-")
	# REPRODUCCIÓN del árbol real del juego CON DOS y-sort anidados Y EL REPARENTEO de arranque
	# (como Construccion crea Elementos bajo sí misma y Main la RE-CUELGA de MundoProfundo):
	# capa (y-sort) nace bajo un padre provisional, se puebla, y DESPUÉS pasa a la bolsa (y-sort).
	var bolsa := Node2D.new()
	bolsa.y_sort_enabled = true
	add_child(bolsa)
	var padre_provisional := Node2D.new()
	add_child(padre_provisional)
	var capa := Node2D.new()
	capa.y_sort_enabled = true
	padre_provisional.add_child(capa)
	var raiz_mueble := Node2D.new()
	raiz_mueble.position = Vector2(160, 280)
	capa.add_child(raiz_mueble)
	raiz_mueble.add_child(SombraContactoScript.crear_sprite(Vector2(20, 20)))
	var silla := Sprite2D.new()
	silla.texture = load("res://assets/sprites/mobiliario/comodidad_silla_espera_madera_180.png")
	silla.centered = false
	silla.offset = Vector2(-10, -28)
	raiz_mueble.add_child(silla)
	# control: mismo montaje SIN y-sort en la bolsa
	var bolsa2 := Node2D.new()
	add_child(bolsa2)
	var raiz2 := Node2D.new()
	raiz2.position = Vector2(300, 280)
	bolsa2.add_child(raiz2)
	raiz2.add_child(SombraContactoScript.crear_sprite(Vector2(20, 20)))
	var silla2 := Sprite2D.new()
	silla2.texture = silla.texture
	silla2.centered = false
	silla2.offset = Vector2(-10, -28)
	raiz2.add_child(silla2)
	# EL REPARENTEO de arranque: la capa poblada pasa del padre provisional a la bolsa y-sort
	# EN EL MISMO FRAME de su creación (como hace el juego), sin esperar un process_frame.
	padre_provisional.remove_child(capa)
	bolsa.add_child(capa)
	# CÁMARA como la del juego: anclaje esquina y desplazada (el mundo se ve corrido +300,+150)
	var camara := Camera2D.new()
	camara.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camara.position = Vector2(-300, -150)
	add_child(camara)
	camara.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(CARPETA_SALIDA + "sombra_aislada.png")
	var img_v: Image = get_viewport().get_texture().get_image()
	# los puntos del mundo se ven ahora en pantalla en (x+300, y+150)
	print("[AISLADA] pixel bajo silla y-sort: ", img_v.get_pixel(460, 440),
		"  pixel bajo silla control: ", img_v.get_pixel(600, 440),
		"  suelo: ", img_v.get_pixel(530, 440))
	get_tree().quit()
