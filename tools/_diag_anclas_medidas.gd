extends SceneTree
## DIAGNÓSTICO DESECHABLE — compara las ANCLAS A MANO que hay hoy en el código contra el ancla que
## sale del AUTO-ANCLAJE POR LÍMITES (centro de la base medida + medio delta de la última celda).
## Sirve para saber, ANTES de tocar nada, cuánto se mueve cada mueble con la regla nueva.

const CASOS: Array[Dictionary] = [
	{"ruta": "res://assets/sprites/mobiliario/mostrador_atencion2_0.png", "ancla": Vector2(0.825, 0.703), "paso": Vector2i(1, 0), "celdas": 2, "que": "MOSTRADOR_2"},
	{"ruta": "res://assets/sprites/mobiliario/mostrador_atencion_0.png", "ancla": Vector2(0.521, 0.727), "paso": Vector2i(1, 0), "celdas": 1, "que": "MOSTRADOR_1 (legado)"},
	{"ruta": "res://assets/sprites/mobiliario/comodidad_equipo_informatico_0.png", "ancla": Vector2(0.479, 0.628), "paso": Vector2i(1, 0), "celdas": 1, "que": "equipo_informatico"},
	{"ruta": "res://assets/sprites/mobiliario/comodidad_papelera_0.png", "ancla": Vector2(0.508, 0.861), "paso": Vector2i(1, 0), "celdas": 1, "que": "papelera"},
	{"ruta": "res://assets/sprites/mobiliario/comodidad_dispensador_agua_0.png", "ancla": Vector2(0.444, 0.888), "paso": Vector2i(1, 0), "celdas": 1, "que": "dispensador_agua"},
	{"ruta": "res://assets/sprites/mobiliario/comodidad_radio_0.png", "ancla": Vector2(0.493, 0.803), "paso": Vector2i(1, 0), "celdas": 1, "que": "radio"},
	{"ruta": "res://assets/sprites/mobiliario/asiento_sofa3_180.png", "ancla": Vector2(0.284, 0.728), "paso": Vector2i(0, 1), "celdas": 2, "que": "sofa3 VERTICAL (rot180)"},
	{"ruta": "res://assets/sprites/mobiliario/asiento_sofa3_90.png", "ancla": Vector2(0.697, 0.728), "paso": Vector2i(1, 0), "celdas": 2, "que": "sofa3 HORIZONTAL (rot90)"},
	{"ruta": "res://assets/sprites/mobiliario/silla_funcionario_180.png", "ancla": Vector2(0.493, 0.824), "paso": Vector2i(1, 0), "celdas": 1, "que": "silla_funcionario (fuera de alcance)"},
	{"ruta": "res://assets/sprites/mobiliario/silla_espera_270.png", "ancla": Vector2(0.495, 0.797), "paso": Vector2i(1, 0), "celdas": 1, "que": "silla_espera (fuera de alcance)"},
]


func _initialize() -> void:
	for caso: Dictionary in CASOS:
		var tex: Texture2D = load(caso["ruta"])
		if tex == null:
			print("FALTA %s" % caso["ruta"])
			continue
		var ancho: int = tex.get_width()
		var alto: int = tex.get_height()
		var centro: Vector2 = AnclajeSprite.centro_base(tex)
		var auto: Vector2 = AnclajeSprite.ancla_px(tex, caso["paso"], caso["celdas"])
		var mano := Vector2(caso["ancla"].x * float(ancho), caso["ancla"].y * float(alto))
		var d: Vector2 = auto - mano
		print("%-36s %3dx%-3d centro_base=%s auto=%s frac=(%.4f, %.4f) | mano=%s | AUTO-MANO=(%.2f, %.2f) px" % [
			caso["que"], ancho, alto, centro, auto,
			auto.x / float(ancho), auto.y / float(alto), mano, d.x, d.y,
		])
	quit()
