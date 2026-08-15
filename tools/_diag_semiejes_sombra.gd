# SONDA DESECHABLE (2026-08-14): ¿qué devuelve semiejes_base para los sprites con sombra?
# Uso: godot --headless --path ... -s res://tools/_diag_semiejes_sombra.gd
extends SceneTree

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

const RUTAS: Array[String] = [
	"res://assets/sprites/mobiliario/silla_espera_0.png",
	"res://assets/sprites/mobiliario/comodidad_banco_espera_medio_0.png",
	"res://assets/sprites/mobiliario/comodidad_banco_espera_pro_0.png",
	"res://assets/sprites/mobiliario/comodidad_banco_espera_basico_0.png",
	"res://assets/sprites/mobiliario/comodidad_estanteria_suelta_90.png",
	"res://assets/sprites/mobiliario/comodidad_silla_espera_madera_180.png",
]


func _init() -> void:
	for ruta: String in RUTAS:
		var textura: Texture2D = load(ruta)
		print("[SEMIEJES] ", ruta.get_file(), " tam_png=", textura.get_size(),
			" semiejes=", AnclajeSpriteScript.semiejes_base(textura))
	quit()
