# Enmienda 2026-07-25 (epic flujo) — "EN CAMINO no se tramita": el trámite arranca cuando la
# persona LLEGA al puesto; el camino dura distancia_real / velocidad (del MODELO de Construcción,
# jamás del sprite — FL5/ADR-0001). Tipo: Integration. DETERMINISTA (ticks manuales; catálogo,
# Personal y Construcción REALES).
extends GdUnitTestSuite

const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")


# ── Fixture ──────────────────────────────────────────────────────────────────────────────
## Mundo con GEOMETRÍA CONOCIDA para el cálculo a mano del camino:
## espera doc 2×2 en (0,0) → centro (1.0, 1.0) · doc_1 en (5,1) → distancia euclídea
## sqrt((5-1)² + (1-1)²) = 4.0 celdas · velocidad 2.0 celdas/min → CAMINO = 2.0 MINUTOS.
func _mundo(velocidad_camino: float) -> Array:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_personal(personal)
	construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(0, 0, 2, 2))
	construccion.construir_de_oficio_elemento(construccion.ASIENTO_BASICO, Vector2i(0, 0))
	construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(4, 0, 4, 4))
	construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(5, 1), &"doc_1")
	var bus: Node = auto_free(EventBusScript.new())
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.velocidad_camino_celdas_min = velocidad_camino
	flujo.usar_personal(personal)
	flujo.usar_construccion(construccion)
	flujo.usar_bus(bus)
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")
	var agente: RefCounted = AgenteScript.new(
		"Ana Ruiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3
	)
	personal.plantilla.append(agente)
	personal.asignar(agente, &"doc_1")
	return [flujo, personal, bus]


# ── El camino se cronometra del MODELO y el trámite NO corre hasta llegar ─────────────────
func test_camino_descuenta_antes_de_tramitar() -> void:
	# Arrange — velocidad 2.0 → camino 2.0 min (cálculo en el doc del fixture); dni = 12 min.
	var mundo: Array = _mundo(2.0)
	var flujo: Node = mundo[0]
	var emisiones: Array = []
	(mundo[2] as Node).tramite_completado.connect(
		func(tramite_id: StringName, _agente: RefCounted) -> void: emisiones.append(tramite_id)
	)
	var persona: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 500.0))
	flujo.encolar(persona)

	# Act 1 — tick de la llamada: el camino empieza a contar EN este tick (2.0 − 1.0 = 1.0).
	flujo._al_tick(1.0)

	# Assert — EN CAMINO: la persona sigue en llamada, el trámite NO ha empezado (restante 0).
	assert_str(String(persona.estado)).is_equal("llamada")
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("en_camino")
	assert_float(float(flujo._puestos_flujo[&"doc_1"]["camino_restante"])).is_equal_approx(1.0, 0.0001)
	assert_float(float(flujo._puestos_flujo[&"doc_1"]["restante"])).is_equal_approx(0.0, 0.0001)
	assert_int(emisiones.size()).is_equal(0)

	# Act 2 — el camino se agota: LLEGA y arranca la atención con sus 12 min ÍNTEGROS.
	flujo._al_tick(1.0)
	assert_str(String(persona.estado)).is_equal("en_atencion")
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("atendiendo")
	assert_float(float(flujo._puestos_flujo[&"doc_1"]["restante"])).is_equal_approx(12.0, 0.0001)

	# Act 3 — la atención dura lo de siempre: 11 ticks sin emitir, el 12.º emite UNA vez.
	for i: int in range(11):
		flujo._al_tick(1.0)
	assert_int(emisiones.size()).is_equal(0)
	flujo._al_tick(1.0)
	assert_int(emisiones.size()).is_equal(1)
	assert_str(String(persona.estado)).is_equal("resuelta")


# ── Compat: knob a 0 → camino instantáneo (el comportamiento previo a la enmienda) ────────
func test_velocidad_cero_arranca_el_mismo_tick() -> void:
	# Arrange
	var mundo: Array = _mundo(0.0)
	var flujo: Node = mundo[0]
	var persona: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 500.0))
	flujo.encolar(persona)

	# Act — un solo tick: llamada + llegada + arranque de atención.
	flujo._al_tick(1.0)

	# Assert
	assert_str(String(persona.estado)).is_equal("en_atencion")
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("atendiendo")
	assert_float(float(flujo._puestos_flujo[&"doc_1"]["restante"])).is_equal_approx(12.0, 0.0001)
