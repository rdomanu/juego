# TIER DE VENTANILLA MEDIA/PRO EN EL MOSTRADOR (2026-08-08 — playtest: "no puedo elegir los
# puestos medio o pro para construir"). El arte de Summer para las dos mesas superiores YA vivía en
# `assets/sprites/mobiliario/` (`ventanilla_media_*`/`ventanilla_pro_*`), pero `MesaAtencion.
# construir()` solo sabía pintar `ID_SPRITE_MOSTRADOR_2` ("ventanilla_basica") — no había forma de
# pedirle el tier de encima aunque el jugador comprara el `TipoPuesto` correspondiente.
# Tipo: Logic. DETERMINISTA: solo lee constantes y ficheros ya importados en `assets/`.
extends GdUnitTestSuite

const MesaAtencionScript := preload("res://src/main/mesa_atencion.gd")


func test_hay_sprite_de_mostrador_para_los_tres_tiers() -> void:
	assert_bool(MesaAtencionScript.hay_sprite_mostrador("ventanilla_basica")).is_true()
	assert_bool(MesaAtencionScript.hay_sprite_mostrador("ventanilla_media")).is_true()
	assert_bool(MesaAtencionScript.hay_sprite_mostrador("ventanilla_pro")).is_true()


## `construir(false, "ventanilla_media")` tiene que usar el PNG de la media, no el básico.
func test_construir_con_tier_media_usa_el_sprite_de_la_media() -> void:
	var mesa: Node2D = MesaAtencionScript.construir(false, "ventanilla_media")
	auto_free(mesa)
	var sprite: Sprite2D = mesa.get_node("Tablero").get_node("Sprite")
	assert_str(sprite.texture.resource_path).contains("ventanilla_media")


func test_construir_con_tier_pro_usa_el_sprite_de_la_pro() -> void:
	var mesa: Node2D = MesaAtencionScript.construir(false, "ventanilla_pro")
	auto_free(mesa)
	var sprite: Sprite2D = mesa.get_node("Tablero").get_node("Sprite")
	assert_str(sprite.texture.resource_path).contains("ventanilla_pro")


## Sin tier (el camino de SIEMPRE) sigue siendo básica — cero cambio para los puestos que no tienen
## tier propio (doc general, TIE, ODAC).
func test_construir_sin_tier_sigue_usando_basica() -> void:
	var mesa: Node2D = MesaAtencionScript.construir()
	auto_free(mesa)
	var sprite: Sprite2D = mesa.get_node("Tablero").get_node("Sprite")
	assert_str(sprite.texture.resource_path).contains("ventanilla_basica")


## Un tier que no tiene PNG (dato corrupto o un id inventado) NO revienta: cae al básico, la misma
## red de seguridad que ya usa el resto del catálogo de sprites de este fichero.
func test_construir_con_tier_desconocido_cae_a_basica() -> void:
	var mesa: Node2D = MesaAtencionScript.construir(false, "ventanilla_platino_inexistente")
	auto_free(mesa)
	var sprite: Sprite2D = mesa.get_node("Tablero").get_node("Sprite")
	assert_str(sprite.texture.resource_path).contains("ventanilla_basica")


## Una huella LEGADO ignora el tier: siempre es el mostrador de 1 celda, tier o no tier.
func test_huella_legado_ignora_el_tier() -> void:
	var mesa: Node2D = MesaAtencionScript.construir(true, "ventanilla_pro")
	auto_free(mesa)
	var sprite: Sprite2D = mesa.get_node("Tablero").get_node("Sprite")
	assert_str(sprite.texture.resource_path).contains(MesaAtencionScript.ID_SPRITE_MOSTRADOR)
