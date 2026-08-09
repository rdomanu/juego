extends SceneTree
## Sonda de un solo uso: mide el semieje (en celdas) de los 3 coches recién re-renderizados,
## usando el MISMO `AnclajeSprite.semiejes_base` que usa el juego para anclar props. Corre en
## headless puro (solo lee píxeles de un PNG ya en disco, sin GPU).

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

func _initialize() -> void:
	for id: String in ["coche_policia", "coche_sedan", "coche_suv"]:
		var ruta: String = "res://assets/sprites/entorno/%s_90.png" % id
		var tex: Texture2D = load(ruta)
		var semiejes: Vector2 = AnclajeSpriteScript.semiejes_base(tex)
		var celdas_x: float = semiejes.x * 2.0 / 40.0
		var celdas_y: float = semiejes.y * 2.0 / 40.0
		print("%s_90: semiejes=%s -> footprint %.2f x %.2f celdas" % [id, semiejes, celdas_x, celdas_y])
	quit()
