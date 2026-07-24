# Story 002 (epic flujo) — colas FIFO + prioridad ODAC + compatibilidad (F7) · TR-flow-002 ·
# ADR-0001/0003. Tipo: Logic. DETERMINISTA (sin azar — F7 es una clave de orden pura; catálogo REAL
# para `atenciones_admitidas` y `prioridad`). Aislamiento: nodo con .new() sin árbol.
extends GdUnitTestSuite

const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
func _flujo() -> Node:
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	return flujo


## Admite y encola una persona; devuelve la PersonaFlujo (turno = orden de admisión).
func _encolada(flujo: Node, servicio: StringName, tramite: StringName) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(servicio, tramite, 511.0))
	flujo.encolar(persona)
	return persona


## Las atenciones admitidas del tipo de puesto REAL del catálogo.
func _admitidas(tipo_puesto_id: StringName) -> Array[StringName]:
	return Datos.obtener(&"TipoPuesto", tipo_puesto_id).atenciones_admitidas


# ── AC-FL03: Documentación es FIFO PURO — sirve por menor turno aunque la cola esté revuelta ─
func test_doc_fifo_puro_por_turno() -> void:
	# Arrange — 3 admitidas en orden (turnos 1,2,3) pero ENCOLADAS revueltas: 3,1,2.
	var flujo: Node = _flujo()
	var p1: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 511.0))
	var p2: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 512.0))
	var p3: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 513.0))
	for persona: RefCounted in [p3, p1, p2]:
		flujo.encolar(persona)

	# Act / Assert — sirve 1, 2, 3 (la CLAVE manda, no la posición en el array).
	var admitidas: Array[StringName] = _admitidas(&"puesto_doc_general")
	for esperada: RefCounted in [p1, p2, p3]:
		var elegida: RefCounted = flujo.elegir_de_cola(&"Documentacion", admitidas)
		assert_object(elegida).is_same(esperada)
		flujo.retirar_de_cola(elegida)
	assert_int(flujo.personas_en_cola(&"Documentacion")).is_equal(0)


# ── AC-FL04: ODAC sirve la Prioritaria (VioGén, catálogo real) antes que la Normal ────────
func test_odac_prioritaria_primero() -> void:
	# Arrange — la Normal llegó ANTES (turno 1); la VioGén después (turno 2).
	var flujo: Node = _flujo()
	var normal: RefCounted = _encolada(flujo, &"ODAC", &"estafa")
	var prioritaria: RefCounted = _encolada(flujo, &"ODAC", &"viogen")

	# Act / Assert — VioGén primero (rango 0 < 1); después la Normal.
	var admitidas: Array[StringName] = _admitidas(&"puesto_odac")
	assert_object(flujo.elegir_de_cola(&"ODAC", admitidas)).is_same(prioritaria)
	flujo.retirar_de_cola(prioritaria)
	assert_object(flujo.elegir_de_cola(&"ODAC", admitidas)).is_same(normal)


# ── AC-FL05: sin compatible, el puesto ESPERA (no llama a nadie) ──────────────────────────
func test_sin_compatible_no_llama() -> void:
	# Arrange — cola Doc solo con DNI y Pasaporte; el puesto es de TIE.
	var flujo: Node = _flujo()
	_encolada(flujo, &"Documentacion", &"dni")
	_encolada(flujo, &"Documentacion", &"pasaporte")

	# Act / Assert
	assert_object(flujo.elegir_de_cola(&"Documentacion", _admitidas(&"puesto_tie"))).is_null()


# ── AC-FL06: toma la primera COMPATIBLE por turno (se salta a la tie, no la adelanta) ─────
func test_toma_primera_compatible_por_turno() -> void:
	# Arrange — cola [tie(t1), dni(t2), pasaporte(t3)]; el puesto es doc_general (dni/pasaporte).
	var flujo: Node = _flujo()
	_encolada(flujo, &"Documentacion", &"tie")
	var dni: RefCounted = _encolada(flujo, &"Documentacion", &"dni")
	_encolada(flujo, &"Documentacion", &"pasaporte")

	# Act / Assert — elige el dni (turno 2): la tie del turno 1 NO es suya y no bloquea.
	assert_object(flujo.elegir_de_cola(&"Documentacion", _admitidas(&"puesto_doc_general"))).is_same(dni)


# ── Bordes: cola vacía / servicio sin cola → null sin reventar ────────────────────────────
func test_bordes_cola_vacia() -> void:
	# Arrange
	var flujo: Node = _flujo()

	# Act / Assert
	assert_object(flujo.elegir_de_cola(&"Documentacion", _admitidas(&"puesto_doc_general"))).is_null()
	assert_object(flujo.elegir_de_cola(&"ODAC", _admitidas(&"puesto_odac"))).is_null()
	assert_int(flujo.personas_en_cola(&"Documentacion")).is_equal(0)
