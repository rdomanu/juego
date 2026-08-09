extends SceneTree
## Sonda DESECHABLE (2026-08-08, veredicto del usuario: "los coches salían atravesados" en
## carreteras_v2.png): mide `AnclajeSprite.semiejes_base` (x=eje este/oeste, y=eje norte/sur) de
## coche_policia/coche_sedan en las 4 rotaciones -- la rotación con semiejes.y > semiejes.x es la
## que tiene el eje LARGO del coche (morro-cola) alineado NORTE-SUR, la que hace falta para la
## calle recta N-S de la sonda de verificación.

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const SALIDA_ENTORNO := "res://assets/sprites/entorno/"

func _initialize() -> void:
	for id: String in ["coche_policia", "coche_sedan"]:
		for rot: int in [0, 90, 180, 270]:
			var tex: Texture2D = load("%s%s_%d.png" % [SALIDA_ENTORNO, id, rot])
			var semiejes: Vector2 = AnclajeSpriteScript.semiejes_base(tex)
			var largo_eje: String = "Y (norte-sur)" if semiejes.y > semiejes.x else "X (este-oeste)"
			print("[DIAG COCHES] %s_%d: semiejes=(%.2f, %.2f) -> eje largo = %s" % [
				id, rot, semiejes.x, semiejes.y, largo_eje
			])
	quit()
