# Story 003 (epic flujo) — puestos, gate FL4 y emparejamiento sin dobles · TR-flow-003 · ADR-0001.
# Tipo: Integration. DETERMINISTA (sin azar; Personal y Construcción REALES; catálogo real).
# Aislamiento: nodos con .new() sin árbol.
extends GdUnitTestSuite

const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Mundo mínimo: Flujo + Personal real con doc_1/doc_2 registrados en AMBOS. Devuelve [flujo, personal].
func _mundo() -> Array:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	personal.registrar_puesto(&"doc_2", &"puesto_doc_general")
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.usar_personal(personal)
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")
	flujo.registrar_puesto_flujo(&"doc_2", &"puesto_doc_general")
	return [flujo, personal]


func _dni_en_cola(flujo: Node) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 511.0))
	flujo.encolar(persona)
	return persona


func _asignar_agente(personal: Node, puesto: StringName, nombre: String = "Ana Ruiz") -> RefCounted:
	var agente: RefCounted = AgenteScript.new(nombre, &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)
	personal.plantilla.append(agente)
	personal.asignar(agente, puesto)
	return agente


# ── AC-FL07: abierto SIN agente → NO atiende (gate FL4) ───────────────────────────────────
func test_sin_agente_no_atiende() -> void:
	# Arrange — cola con dni compatible; doc_1 abierto pero sin dotar.
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	var persona: RefCounted = _dni_en_cola(flujo)

	# Act
	flujo._emparejar()

	# Assert — la persona sigue en cola y el puesto en abierto_sin_agente.
	assert_int(flujo.personas_en_cola(&"Documentacion")).is_equal(1)
	assert_str(String(persona.estado)).is_equal("esperando_dentro")
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("abierto_sin_agente")


# ── AC-FL08: abierto CON agente → llama (persona a Llamada, puesto Atendiendo) ────────────
func test_con_agente_llama() -> void:
	# Arrange
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	_asignar_agente(mundo[1], &"doc_1")
	var persona: RefCounted = _dni_en_cola(flujo)

	# Act
	flujo._emparejar()

	# Assert
	assert_str(String(persona.estado)).is_equal("llamada")
	assert_int(flujo.personas_en_cola(&"Documentacion")).is_equal(0)
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("atendiendo")


# ── AC-FL23: dos puestos libres y UNA persona → la toma exactamente uno (el 1.º registrado) ─
func test_una_persona_dos_puestos_sin_dobles() -> void:
	# Arrange — doc_1 y doc_2 dotados y libres; una sola compatible.
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	_asignar_agente(mundo[1], &"doc_1", "Ana Ruiz")
	_asignar_agente(mundo[1], &"doc_2", "Carlos Vega")
	_dni_en_cola(flujo)

	# Act
	flujo._emparejar()

	# Assert — doc_1 (primero en orden estable de registro) la tiene; doc_2 sigue Libre.
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("atendiendo")
	assert_str(String(flujo.estado_de_puesto(&"doc_2"))).is_equal("libre")


# ── States B: cerrar no llama; reabrir vuelve; quitar agente → abierto_sin_agente ─────────
func test_estados_del_puesto() -> void:
	# Arrange
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	var personal: Node = mundo[1]
	var agente: RefCounted = _asignar_agente(personal, &"doc_1")
	flujo.cerrar_puesto(&"doc_2")
	assert_str(String(flujo.estado_de_puesto(&"doc_2"))).is_equal("cerrado")

	# Act / Assert — cerrado NO llama aunque haya cola y esté dotado el otro… doc_1 sí.
	flujo.cerrar_puesto(&"doc_1")
	_dni_en_cola(flujo)
	flujo._emparejar()
	assert_int(flujo.personas_en_cola(&"Documentacion")).is_equal(1)
	# Reabrir → llama.
	flujo.abrir_puesto(&"doc_1")
	flujo._emparejar()
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("atendiendo")
	# Quitar el agente de un puesto libre → abierto_sin_agente.
	personal.desasignar(agente)
	assert_str(String(flujo.estado_de_puesto(&"doc_2"))).is_equal("cerrado")
	flujo.abrir_puesto(&"doc_2")
	assert_str(String(flujo.estado_de_puesto(&"doc_2"))).is_equal("abierto_sin_agente")


# ── Puente completo: Construcción construye → Personal dota → Flujo atiende ───────────────
func test_puente_construccion_personal_flujo() -> void:
	# Arrange — un puesto NUEVO construido de verdad (de oficio: sin Economía en este test).
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_personal(personal)
	construccion._crear_sala(&"sala_documentacion", Rect2i(0, 0, 4, 4))
	var id_puesto: StringName = construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(1, 1))
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.usar_personal(personal)
	flujo.registrar_puesto_flujo(id_puesto, &"puesto_doc_general")
	_asignar_agente(personal, id_puesto)
	var persona: RefCounted = _dni_en_cola(flujo)

	# Act
	flujo._emparejar()

	# Assert — el hilo entero: construido → dotado → atendiendo.
	assert_str(String(flujo.estado_de_puesto(id_puesto))).is_equal("atendiendo")
	assert_str(String(persona.estado)).is_equal("llamada")


# ── Robustez: tipo inexistente / puesto no registrado no revientan ────────────────────────
func test_registro_invalido_no_revienta() -> void:
	# Arrange — push_warning esperados.
	var flujo: Node = _mundo()[0]

	# Act / Assert
	flujo.registrar_puesto_flujo(&"raro_1", &"puesto_inventado")
	assert_str(String(flujo.estado_de_puesto(&"raro_1"))).is_equal("cerrado")
	assert_str(String(flujo.estado_de_puesto(&"no_existe"))).is_equal("cerrado")
