# Lote de integración de ventanillas — tier básico (2026-08-07): pin del arte nuevo de
# `MesaAtencion` (mesa + sillas del funcionario/ciudadano) y de la ruta de despiece de la silla de
# espera, que debe caer al camino de silla ENTERA con este arte (no tiene despiece propio).
# Tipo: Logic. DETERMINISTA: solo lee constantes y comprueba ficheros ya importados en `assets/`.
extends GdUnitTestSuite

const MesaAtencionScript := preload("res://src/main/mesa_atencion.gd")


func test_la_mesa_de_dos_celdas_usa_el_arte_tier_basico() -> void:
	assert_str(MesaAtencionScript.ID_SPRITE_MOSTRADOR_2).is_equal("ventanilla_basica")
	assert_bool(MesaAtencionScript.hay_sprite_mostrador(MesaAtencionScript.ID_SPRITE_MOSTRADOR_2)).is_true()


func test_las_sillas_del_puesto_usan_el_arte_tier_basico() -> void:
	assert_str(MesaAtencionScript.ID_SPRITE_SILLA_FUNCIONARIO).is_equal("comodidad_silla_oficina")
	assert_str(MesaAtencionScript.ID_SPRITE_SILLA_ESPERA).is_equal("comodidad_silla_espera_madera")
	assert_bool(MesaAtencionScript.hay_sprite_silla_funcionario()).is_true()
	assert_bool(MesaAtencionScript.hay_sprite_silla_espera()).is_true()


func test_la_silla_de_espera_nueva_no_tiene_despiece_y_cae_a_silla_entera() -> void:
	# El despiece asiento/respaldo es de la generación ANTERIOR (otro mueble): con el arte de hoy
	# `hay_silla_espera_partida()` debe dar false y `silla_ciudadano()` usar la silla entera.
	assert_bool(MesaAtencionScript.hay_silla_espera_partida()).is_false()


func test_las_piezas_de_sprite_se_anclan_sin_fraccion_a_mano() -> void:
	# LEY AnclajeSprite: la mesa y las sillas del puesto se posicionan con `AnclajeSprite`, no con
	# fracciones escritas a mano — comprobación de humo: las piezas se construyen sin errores y con
	# un Sprite2D `centered = false` (la marca de `AnclajeSprite.aplicar`).
	var mesa: Node2D = MesaAtencionScript.construir()
	auto_free(mesa)
	var tablero: Node2D = mesa.get_node("Tablero")
	var sprite_mesa: Sprite2D = tablero.get_node("Sprite")
	assert_bool(sprite_mesa.centered).is_false()

	var silla_funcionario: Node2D = MesaAtencionScript.silla_funcionario_o_defecto(Vector2.ZERO)
	auto_free(silla_funcionario)
	var sprite_funcionario: Sprite2D = silla_funcionario.get_node("Sprite")
	assert_bool(sprite_funcionario.centered).is_false()

	var silla_ciudadano: Node2D = MesaAtencionScript.silla_ciudadano()
	auto_free(silla_ciudadano)
	var sprite_ciudadano: Sprite2D = silla_ciudadano.get_node("Sprite")
	assert_bool(sprite_ciudadano.centered).is_false()
