# LA SILLA DEL CIUDADANO EN LA VENTANILLA, ORIENTADA AL NORTE (2026-08-08 — playtest: "las sillas
# de las ventanillas tienen orientacion noroeste y debe tener el asiento orientado al norte, como
# en la sala de espera"). Causa raiz: `silla_ciudadano()` usaba su PROPIO sprite/rotacion
# ("comodidad_silla_espera_madera_ventanilla" a 225 grados, verificado con la entrada NORTE/OESTE de
# antes) en vez de la MISMA vista que ya usa la sala de espera. Fix: `silla_ciudadano()` pasa a
# llamar a `silla_espera_o_defecto()` -- la MISMA funcion, MISMO sprite, MISMA rotacion (180 grados)
# que la sala de espera, que el usuario da por buena.
# Tipo: Logic. DETERMINISTA: construye el nodo y lee su textura/anclaje, sin motor ni GPU.
extends GdUnitTestSuite

const MesaAtencionScript := preload("res://src/main/mesa_atencion.gd")


## La silla del ciudadano en la ventanilla usa el MISMO sprite que la silla de espera -- ya no el
## "_ventanilla_225" propio.
func test_silla_ciudadano_usa_el_mismo_sprite_que_la_silla_de_espera() -> void:
	var silla_ventanilla: Node2D = MesaAtencionScript.silla_ciudadano()
	auto_free(silla_ventanilla)
	var silla_espera: Node2D = MesaAtencionScript.silla_espera_o_defecto(Vector2.ZERO)
	auto_free(silla_espera)

	var sprite_ventanilla: Sprite2D = silla_ventanilla.get_node("Sprite")
	var sprite_espera: Sprite2D = silla_espera.get_node("Sprite")
	assert_str(sprite_ventanilla.texture.resource_path).is_equal(sprite_espera.texture.resource_path)


## Y esa ruta es LITERALMENTE la del sprite de espera a `ROT_SILLA_ESPERA` (180°) -- ya no
## `ID_SPRITE_SILLA_ESPERA_VENTANILLA` a 225°, que es la vista que el usuario reportó como "noroeste".
func test_silla_ciudadano_ya_no_usa_la_vista_225_de_la_ventanilla() -> void:
	var silla_ventanilla: Node2D = MesaAtencionScript.silla_ciudadano()
	auto_free(silla_ventanilla)
	var ruta: String = (silla_ventanilla.get_node("Sprite") as Sprite2D).texture.resource_path

	assert_str(ruta).contains(MesaAtencionScript.ID_SPRITE_SILLA_ESPERA)
	assert_str(ruta).contains("_%d.png" % MesaAtencionScript.ROT_SILLA_ESPERA)
	assert_bool(ruta.contains("_ventanilla_")) \
		.override_failure_message("silla_ciudadano() no puede seguir usando el sprite propio de la ventanilla") \
		.is_false()
