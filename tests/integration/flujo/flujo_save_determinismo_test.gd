# Story 007 (epic flujo) — persistencia (AC-FL26) y el AC rey del determinismo (AC-FL27) ·
# TR-flow-006 · ADR-0002/0001. Tipo: Integration. DETERMINISTA (sin azar; ticks manuales;
# Construcción, Personal y catálogo REALES; round-trip por JSON con full_precision).
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


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Mundo completo Doc+ODAC: espera Doc aforo 3 (1 asiento + 2 de pie), espera ODAC aforo 2
## (de pie), doc_1 y odac_1 construidos, dotados y registrados. [flujo, personal, construccion, bus]
func _mundo() -> Array:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_personal(personal)
	construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(0, 0, 2, 2))
	construccion.construir_de_oficio_elemento(construccion.ASIENTO_BASICO, Vector2i(0, 0))
	construccion.construir_de_oficio_sala(&"sala_espera_odac", Rect2i(0, 3, 2, 2))
	construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(4, 0, 4, 4))
	construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(5, 1), &"doc_1")
	construccion.construir_de_oficio_sala(&"sala_odac", Rect2i(4, 5, 3, 3))
	construccion.construir_de_oficio_elemento(&"puesto_odac", Vector2i(5, 6), &"odac_1")
	var bus: Node = auto_free(EventBusScript.new())
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.usar_personal(personal)
	flujo.usar_construccion(construccion)
	flujo.usar_bus(bus)
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")
	flujo.registrar_puesto_flujo(&"odac_1", &"puesto_odac")
	_alta_agente(personal, &"doc_1", &"ag_doc", "Ana Ruiz")
	_alta_agente(personal, &"odac_1", &"ag_odac", "Carlos Vega")
	return [flujo, personal, construccion, bus]


func _alta_agente(personal: Node, puesto: StringName, tipo: StringName, nombre: String) -> void:
	var agente: RefCounted = AgenteScript.new(nombre, tipo, AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)
	personal.plantilla.append(agente)
	personal.asignar(agente, puesto)


func _admitir(flujo: Node, servicio: StringName, tramite: StringName) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(servicio, tramite, 500.0))
	flujo.encolar(persona)
	return persona


## Espía de eventos con payload (orden incluido): completados y abandonos en el MISMO registro.
func _espiar(bus: Node, eventos: Array) -> void:
	bus.tramite_completado.connect(
		func(tramite_id: StringName, agente: RefCounted) -> void:
			eventos.append(["completado", String(tramite_id), agente.nombre if agente != null else ""])
	)
	bus.abandono.connect(
		func(persona: RefCounted) -> void:
			eventos.append(["abandono", String(persona.servicio()), persona.numero_turno])
	)


## El GUION determinista del AC-FL27 (idéntico para los mundos A y B): admisiones al t=1,
## reconfiguración, un abandono forzado, cierre y reapertura de doc_1. Tras el save de t=15 no
## hay acciones sobre referencias de persona (el mundo cargado tiene instancias NUEVAS).
func _paso_guion(flujo: Node, personas: Array, t: int) -> void:
	if t == 1:
		for i: int in range(4):
			personas.append(_admitir(flujo, &"Documentacion", &"dni"))
		personas.append(_admitir(flujo, &"ODAC", &"estafa"))
		personas.append(_admitir(flujo, &"ODAC", &"viogen"))
	if t == 5:
		var solo_estafa: Array[StringName] = [&"estafa"]
		flujo.reconfigurar_puesto(&"odac_1", solo_estafa)
	if t == 8:
		flujo.forzar_abandono(personas[2])
	if t == 10:
		flujo.cerrar_puesto(&"doc_1")
	if t == 20:
		flujo.abrir_puesto(&"doc_1")
	flujo._al_tick(1.0)


func _json_round_trip(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d, "", false, true))   # full_precision (ADR-0002)


# ── AC-FL26: round-trip por JSON — N, estados, turnos y restante idénticos; 0 señales ─────
func test_round_trip_restaura_campo_a_campo() -> void:
	# Arrange — mundo A: 6 dni (3 dentro / 3 fuera), p1 en atención a 7.5 y cierre pendiente.
	var mundo_a: Array = _mundo()
	var flujo_a: Node = mundo_a[0]
	for i: int in range(6):
		_admitir(flujo_a, &"Documentacion", &"dni")
	flujo_a._al_tick(1.0)    # p1 → atención (12.0); la 4.ª entra de fuera
	flujo_a._al_tick(4.5)    # restante 7.5
	flujo_a.cerrar_puesto(&"doc_1")   # atendiendo → cierre PENDIENTE (006, debe sobrevivir)
	assert_float(float(flujo_a._puestos_flujo[&"doc_1"]["restante"])).is_equal_approx(7.5, 0.0001)

	# Act — save → JSON (full_precision) → load en un mundo B recién montado (puestos ANTES).
	var guardado: Dictionary = _json_round_trip(flujo_a.save())
	var mundo_b: Array = _mundo()
	var flujo_b: Node = mundo_b[0]
	var eventos_b: Array = []
	_espiar(mundo_b[3], eventos_b)
	flujo_b.load_state(guardado)

	# Assert — campo a campo y 0 señales durante la carga.
	assert_int(eventos_b.size()).is_equal(0)
	assert_int(flujo_b.personas_en_cola(&"Documentacion")).is_equal(5)
	assert_int(flujo_b.ocupacion_dentro(&"Documentacion")).is_equal(3)
	assert_str(String(flujo_b.estado_de_puesto(&"doc_1"))).is_equal("atendiendo")
	assert_float(float(flujo_b._puestos_flujo[&"doc_1"]["restante"])).is_equal_approx(7.5, 0.0001)
	assert_bool(flujo_b._puestos_flujo[&"doc_1"]["cierre_pendiente"]).is_true()
	assert_bool(flujo_b._puestos_flujo[&"doc_1"]["persona"].numero_turno == 1).is_true()
	# Los turnos en espera se conservan (dentro 2,3,4 · fuera 5,6) y el contador NO se reusa.
	var turnos_fuera: Array = []
	for persona: RefCounted in flujo_b._colas[&"Documentacion"]:
		if persona.estado == &"esperando_fuera":
			turnos_fuera.append(persona.numero_turno)
	assert_bool(turnos_fuera == [5, 6]).is_true()
	assert_int(flujo_b.admitir(PersonaScript.new(&"Documentacion", &"dni", 600.0)).numero_turno).is_equal(7)

	# El siguiente tick CONTINÚA desde 7.5: completa, emite UNA vez y aplica el cierre pendiente.
	flujo_b._al_tick(7.5)
	assert_int(eventos_b.size()).is_equal(1)
	assert_str(String(flujo_b.estado_de_puesto(&"doc_1"))).is_equal("cerrado")


# ── AC-FL27: mismo guion en A y B (con SAVE a mitad en B) → eventos y estado IDÉNTICOS ────
func test_determinismo_a_vs_b_con_save_a_mitad() -> void:
	# Arrange — mundo A: el guion completo del tirón (t = 1..40).
	var mundo_a: Array = _mundo()
	var flujo_a: Node = mundo_a[0]
	var eventos_a: Array = []
	_espiar(mundo_a[3], eventos_a)
	var personas_a: Array = []
	for t: int in range(1, 41):
		_paso_guion(flujo_a, personas_a, t)

	# Act — mundo B: guion hasta t=15, SAVE, y un mundo B2 recién montado CARGA y continúa.
	var mundo_b: Array = _mundo()
	var flujo_b: Node = mundo_b[0]
	var eventos_b: Array = []
	_espiar(mundo_b[3], eventos_b)
	var personas_b: Array = []
	for t: int in range(1, 16):
		_paso_guion(flujo_b, personas_b, t)
	var guardado: Dictionary = _json_round_trip(flujo_b.save())
	var mundo_b2: Array = _mundo()
	var flujo_b2: Node = mundo_b2[0]
	_espiar(mundo_b2[3], eventos_b)   # el registro de B CONTINÚA en B2
	flujo_b2.load_state(guardado)
	for t: int in range(16, 41):
		_paso_guion(flujo_b2, personas_b, t)

	# Assert — la prueba reina: eventos (orden y payload) y estado final IDÉNTICOS.
	assert_bool(eventos_a == eventos_b).is_true()
	assert_bool(flujo_a.save() == flujo_b2.save()).is_true()
	# Sanity de que el guion ejercitó de verdad: hubo completados Y un abandono.
	assert_bool(eventos_a.size() >= 3).is_true()
	assert_bool(eventos_a.any(func(e: Array) -> bool: return e[0] == "abandono")).is_true()


# ── Robustez: entradas corruptas se descartan con aviso y el resto carga ──────────────────
func test_save_corrupto_descarta_y_sigue() -> void:
	# Arrange — un save de mano con 1 persona válida + 3 corruptas + 1 puesto fantasma.
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	var d: Dictionary = {
		"personas": [
			{"servicio": "Documentacion", "tramite": "dni", "minuto_llegada": 500.0,
				"turno": 1, "estado": "esperando_dentro"},
			{"servicio": "Documentacion", "tramite": "no_existe", "minuto_llegada": 500.0,
				"turno": 2, "estado": "esperando_dentro"},   # trámite fuera del catálogo
			{"servicio": "Marte", "tramite": "dni", "minuto_llegada": 500.0,
				"turno": 3, "estado": "esperando_dentro"},   # servicio desconocido
			{"servicio": "Documentacion", "tramite": "dni", "minuto_llegada": 500.0,
				"turno": 4, "estado": "bailando"},           # estado inexistente
		],
		"puestos": [
			{"id": "puesto_fantasma", "abierto": false, "persona_turno": -1, "restante": 0.0},
		],
		"turnos": {"Documentacion": 6},
	}

	# Act — push_warning esperados (una por corrupta y por el puesto fantasma).
	flujo.load_state(d)

	# Assert — la válida está; las corruptas no; doc_1 intacto (dotado → libre); contador del save.
	assert_int(flujo.personas_en_cola(&"Documentacion")).is_equal(1)
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("libre")
	assert_int(flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 600.0)).numero_turno).is_equal(7)
