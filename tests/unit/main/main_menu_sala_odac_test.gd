# MENÚ CONTEXTUAL DE LA SALA — el acceso nuevo a la dedicación de ODAC y la limpieza de emojis
# (F4, 2026-08-18). Dos contratos:
#   1. "Dedicación de ODAC" se ofrece SOLO en salas del servicio ODAC (la oficina de denuncias y su
#      sala de espera) y NUNCA en las de Documentación o descanso. La regla vive en
#      `Main._sala_es_de_odac` y se prueba con los recursos REALES del catálogo (`datos/salas/*.tres`),
#      no con dobles: si mañana una sala cambia de servicio, este test lo canta.
#   2. Los ítems de los DOS menús contextuales (sala y ciudadano) van SIN emojis — regla del proyecto
#      (los emojis arrastran la fuente color del sistema, ignoran `modulate` y salen como tofu).
#
# `Main` se instancia SIN `add_child` (mismo patrón que `main_camara_clamp_test.gd`): la función es
# pura y así no se dispara el `_ready()` pesado de todo el juego.
#
# Tipo: Unit. DETERMINISTA: sin azar, sin reloj, sin GPU.
extends GdUnitTestSuite

const MainScript := preload("res://src/main/main.gd")

## Las salas del catálogo real y si su menú debe ofrecer la dedicación de ODAC.
const SALAS_ODAC: Array[String] = ["sala_odac", "sala_espera_odac"]
const SALAS_NO_ODAC: Array[String] = ["sala_documentacion", "sala_espera_doc", "sala_descanso"]

## Rango de caracteres que NO puede aparecer en un ítem de menú (emojis y pictogramas).
const CODIGO_EMOJI_MIN := 0x2190


func _main() -> Node2D:
	return auto_free(MainScript.new())


func _tipo_sala(id: String) -> Resource:
	return load("res://datos/salas/%s.tres" % id)


func test_las_salas_de_odac_ofrecen_la_dedicacion() -> void:
	var main: Node2D = _main()
	for id: String in SALAS_ODAC:
		var tipo: Resource = _tipo_sala(id)
		assert_object(tipo).is_not_null()
		assert_bool(main._sala_es_de_odac(tipo)).override_failure_message(
			"La sala '%s' es del servicio ODAC y su menú debe ofrecer la dedicación" % id
		).is_true()


func test_las_demas_salas_no_ofrecen_la_dedicacion() -> void:
	var main: Node2D = _main()
	for id: String in SALAS_NO_ODAC:
		var tipo: Resource = _tipo_sala(id)
		assert_object(tipo).is_not_null()
		assert_bool(main._sala_es_de_odac(tipo)).override_failure_message(
			"La sala '%s' NO es de ODAC: el menú no debe ofrecer esa opción" % id
		).is_false()


func test_una_sala_desconocida_no_rompe_el_menu() -> void:
	# Un clic sobre una celda sin tipo (o un catálogo incompleto) deja `tipo == null`: la opción
	# simplemente no se ofrece, nunca un error.
	assert_bool(_main()._sala_es_de_odac(null)).is_false()


func test_el_menu_de_sala_cablea_la_opcion_con_su_propio_id() -> void:
	# El id de la opción existe, es único y cae fuera de los rangos con base (110/130/160), que se
	# comparan con `>=` en `_al_elegir_del_menu_sala`.
	# El script como RECURSO (no como tipo): llamarlo sobre la constante `MainScript` el parser lo
	# leería como una llamada estática a la clase y no compila.
	var script: GDScript = load("res://src/main/main.gd")
	var constantes: Dictionary = script.get_script_constant_map()
	assert_bool(constantes.has("ID_SALA_ODAC")).is_true()
	var id: int = constantes["ID_SALA_ODAC"]
	assert_int(id).is_less(constantes["ID_SALA_PUESTO_BASE"])
	for otra: String in ["ID_SALA_TITULO", "ID_SALA_AMPLIAR", "ID_SALA_ASIENTOS",
			"ID_SALA_DEMOLER", "ID_SALA_CANCELAR", "ID_SALA_PAREDES"]:
		assert_int(constantes[otra]).is_not_equal(id)


func test_los_items_de_los_menus_contextuales_no_llevan_emojis() -> void:
	var fuente: String = FileAccess.get_file_as_string("res://src/main/main.gd")
	assert_str(fuente).is_not_empty()
	var sucias: Array[String] = []
	for linea: String in fuente.split("\n"):
		if not linea.contains("add_item("):
			continue
		for i: int in linea.length():
			if linea.unicode_at(i) >= CODIGO_EMOJI_MIN:
				sucias.append(linea.strip_edges())
				break
	assert_array(sucias).override_failure_message(
		"Ítems de menú con emoji (regla del proyecto: texto limpio): %s" % str(sucias)
	).is_empty()
