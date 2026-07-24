# Story 001 (epic flujo) — PersonaFlujo, máquina de 7 estados y turnos por servicio · TR-flow-001 ·
# ADR-0001/0003. Tipo: Logic. DETERMINISTA (sin azar; ficha REAL de Demanda envuelta).
# Aislamiento: nodo con .new() sin árbol.
extends GdUnitTestSuite

const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
func _flujo() -> Node:
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	return flujo


func _ficha(servicio: StringName = &"Documentacion", tramite: StringName = &"dni") -> RefCounted:
	return PersonaScript.new(servicio, tramite, 511.0)


# ── AC-FL01: la ficha de Demanda entra al flujo envuelta, con turno y estado Llegando ─────
func test_admitir_envuelve_la_ficha() -> void:
	# Arrange
	var flujo: Node = _flujo()
	var ficha: RefCounted = _ficha()

	# Act
	var persona: RefCounted = flujo.admitir(ficha)

	# Assert — misma REFERENCIA (no copia), campos accesibles, turno 1, Llegando, paciencia stub.
	assert_object(persona.ficha).is_same(ficha)
	assert_str(String(persona.servicio())).is_equal("Documentacion")
	assert_str(String(persona.tramite_id())).is_equal("dni")
	assert_int(persona.numero_turno).is_equal(1)
	assert_str(String(persona.estado)).is_equal("llegando")
	assert_object(persona.paciencia).is_null()


# ── AC-FL02: turnos consecutivos crecientes, contador INDEPENDIENTE por servicio ──────────
func test_turnos_consecutivos_por_servicio() -> void:
	# Arrange
	var flujo: Node = _flujo()

	# Act — 3 de Doc y 2 de ODAC intercaladas.
	var doc_1: RefCounted = flujo.admitir(_ficha(&"Documentacion", &"dni"))
	var odac_1: RefCounted = flujo.admitir(_ficha(&"ODAC", &"estafa"))
	var doc_2: RefCounted = flujo.admitir(_ficha(&"Documentacion", &"pasaporte"))
	var odac_2: RefCounted = flujo.admitir(_ficha(&"ODAC", &"hurto_robo"))
	var doc_3: RefCounted = flujo.admitir(_ficha(&"Documentacion", &"dni"))

	# Assert — Doc: 1,2,3 · ODAC: 1,2 (sin huecos, sin cruces).
	assert_int(doc_1.numero_turno).is_equal(1)
	assert_int(doc_2.numero_turno).is_equal(2)
	assert_int(doc_3.numero_turno).is_equal(3)
	assert_int(odac_1.numero_turno).is_equal(1)
	assert_int(odac_2.numero_turno).is_equal(2)


# ── States A: las transiciones válidas cambian; una inválida avisa y NO cambia ────────────
func test_maquina_de_estados_valida_e_invalida() -> void:
	# Arrange
	var flujo: Node = _flujo()
	var persona: RefCounted = flujo.admitir(_ficha())

	# Act / Assert — el camino feliz completo: llegando → dentro → llamada → atención → resuelta.
	assert_bool(flujo._transicionar(persona, PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO)).is_true()
	assert_bool(flujo._transicionar(persona, PersonaFlujoScript.ESTADO_LLAMADA)).is_true()
	assert_bool(flujo._transicionar(persona, PersonaFlujoScript.ESTADO_EN_ATENCION)).is_true()
	assert_bool(flujo._transicionar(persona, PersonaFlujoScript.ESTADO_RESUELTA)).is_true()
	# Inválida (resuelta → llamada): aviso intencional y el estado NO cambia.
	assert_bool(flujo._transicionar(persona, PersonaFlujoScript.ESTADO_LLAMADA)).is_false()
	assert_str(String(persona.estado)).is_equal("resuelta")
	# El camino del desbordamiento: llegando → fuera → dentro (FL6, lo usará la 005).
	var otra: RefCounted = flujo.admitir(_ficha())
	assert_bool(flujo._transicionar(otra, PersonaFlujoScript.ESTADO_ESPERANDO_FUERA)).is_true()
	assert_bool(flujo._transicionar(otra, PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO)).is_true()
	# El compromiso NO es transición: llamada → abandonando no existe en la tabla.
	flujo._transicionar(otra, PersonaFlujoScript.ESTADO_LLAMADA)
	assert_bool(flujo._transicionar(otra, PersonaFlujoScript.ESTADO_ABANDONANDO)).is_false()


# ── Config: clamps defensivos + el .tres real carga (patrón del proyecto) ─────────────────
func test_config_clamps_y_tres_real() -> void:
	# Arrange — knobs corruptos (push_warning esperado por el config inválido no aplica: es válido).
	var corrupto: Resource = ConfigFlujoScript.new()
	corrupto.duracion_desplazamiento_seg = 99.0
	corrupto.tope_cola_exterior = -5
	var flujo: Node = _flujo()

	# Act
	flujo.aplicar_config(corrupto)

	# Assert — clamps a rangos del GDD ([0,5] y ≥0).
	assert_float(flujo.duracion_desplazamiento_seg).is_equal_approx(5.0, 0.0001)
	assert_int(flujo.tope_cola_exterior).is_equal(0)

	# El .tres real generado por la herramienta carga con los valores semilla.
	var real: Resource = load("res://datos/config/flujo.tres")
	assert_object(real).is_not_null()
	var con_real: Node = _flujo()
	con_real.aplicar_config(real)
	assert_float(con_real.duracion_desplazamiento_seg).is_equal_approx(1.5, 0.0001)
	assert_bool(con_real.habilitar_aging_odac).is_false()
	assert_int(con_real.tope_cola_exterior).is_equal(0)
