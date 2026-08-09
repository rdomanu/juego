extends SceneTree
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
func _initialize() -> void:
	var tex: Texture2D = load("res://assets/sprites/mobiliario/mostrador_atencion2_0.png")
	var semiejes: Vector2 = AnclajeSpriteScript.semiejes_base(tex)
	print("mostrador2: semiejes=%s -> %.2f x %.2f celdas" % [semiejes, semiejes.x*2.0/40.0, semiejes.y*2.0/40.0])
	quit()
