# Acción #2 de la retrospectiva del Sprint 2 — avisar de la gente que NADIE puede atender (el
# "misterio de las 22:00": trámites TIE esperando sin ninguna ventanilla que los tramitase).
# Tipo: Integration. DETERMINISTA: catálogo real, sin reloj ni RNG.
extends GdUnitTestSuite

const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")


func _flujo(con_puesto_tie: bool = false) -> Node:
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")
	if con_puesto_tie:
		flujo.registrar_puesto_flujo(&"tie_1", &"puesto_tie")
	return flujo


func _encolar(flujo: Node, tramite: StringName) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", tramite, 500))
	flujo.encolar(persona)
	return persona


func test_sin_ventanilla_capaz_se_avisa_del_tramite_huerfano() -> void:
	var flujo: Node = _flujo()
	_encolar(flujo, &"tie")
	_encolar(flujo, &"tie")
	var huerfanos: Dictionary = flujo.tramites_sin_servicio()
	assert_int(huerfanos.get(&"tie", 0)).is_equal(2)


func test_con_la_ventanilla_construida_no_hay_aviso() -> void:
	var flujo: Node = _flujo(true)
	_encolar(flujo, &"tie")
	assert_bool(flujo.tramites_sin_servicio().is_empty()).is_true()


func test_lo_que_si_se_atiende_no_aparece() -> void:
	var flujo: Node = _flujo()
	_encolar(flujo, &"dni")
	_encolar(flujo, &"pasaporte")
	assert_bool(flujo.tramites_sin_servicio().is_empty()).is_true()


func test_un_puesto_cerrado_sigue_contando_como_capaz() -> void:
	# Cerrar una ventanilla es un problema DISTINTO (y el rótulo del puesto ya lo dice): aquí solo se
	# avisa de lo que NADIE puede atender se ponga como se ponga.
	var flujo: Node = _flujo(true)
	flujo.cerrar_puesto(&"tie_1")
	_encolar(flujo, &"tie")
	assert_bool(flujo.tramites_sin_servicio().is_empty()).is_true()


func test_sin_gente_esperando_no_hay_aviso() -> void:
	assert_bool(_flujo().tramites_sin_servicio().is_empty()).is_true()
