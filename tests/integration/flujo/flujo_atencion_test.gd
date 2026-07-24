# Story 004 (epic flujo) — atención F1 + tramite_completado (el saldo SUBE) · TR-flow-003/004 ·
# ADR-0001. Tipo: Integration. DETERMINISTA (sin azar; ticks manuales de 1 min; Personal, Economía
# y catálogo REALES). Solo el test de Pausa mete nodos al árbol (physics real, multiplicador 0).
extends GdUnitTestSuite

const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Mundo: Flujo + Personal real (doc_1 dotado con un agente) + bus espía. Devuelve [flujo, personal, bus].
func _mundo(rapidez: int = 3, motivacion: int = 3) -> Array:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	var agente: RefCounted = AgenteScript.new(
		"Ana Ruiz", &"ag_doc", AgenteScript.RANGO_POLICIA, rapidez, 3, 3, motivacion
	)
	personal.plantilla.append(agente)
	personal.asignar(agente, &"doc_1")
	var bus: Node = auto_free(EventBusScript.new())
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.usar_personal(personal)
	flujo.usar_bus(bus)
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")
	return [flujo, personal, bus]


func _dni_en_cola(flujo: Node) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 511.0))
	flujo.encolar(persona)
	return persona


# ── AC-FL09: F1 — dni (12) × 1.0 = 12; con agente rápido (0.76) = 9.12 ────────────────────
func test_duracion_efectiva_f1() -> void:
	# Arrange — agente estándar (mod 1.0).
	var flujo: Node = _mundo()[0]

	# Act / Assert
	assert_float(flujo.duracion_efectiva(&"Documentacion", &"dni", &"doc_1")).is_equal_approx(12.0, 0.001)

	# Con una crack (R5/M4 → modificador 0.76, valor testeado en Personal): 12 × 0.76 = 9.12.
	var flujo_crack: Node = _mundo(5, 4)[0]
	assert_float(flujo_crack.duracion_efectiva(&"Documentacion", &"dni", &"doc_1")).is_equal_approx(9.12, 0.001)


# ── AC-FL10: dato corrupto (id inexistente → base 0) se clampa a 1 min ────────────────────
func test_duracion_corrupta_clampada() -> void:
	# Arrange — el push_warning de Datos por el id colgante es intencional.
	var flujo: Node = _mundo()[0]

	# Act / Assert — jamás una atención instantánea o negativa.
	assert_float(flujo.duracion_efectiva(&"Documentacion", &"tramite_inventado", &"doc_1")).is_equal_approx(1.0, 0.0001)


# ── AC-FL11: al cumplirse la duración — UNA emisión, Resuelta, puesto Libre, encadena ─────
func test_atencion_completa_emite_una_vez_y_encadena() -> void:
	# Arrange — 2 personas en cola, 1 puesto (dni = 12 min, agente estándar); espía del bus.
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	var bus: Node = mundo[2]
	var emisiones: Array = []
	bus.tramite_completado.connect(
		func(tramite_id: StringName, agente: RefCounted) -> void: emisiones.append([tramite_id, agente])
	)
	var p1: RefCounted = _dni_en_cola(flujo)
	var p2: RefCounted = _dni_en_cola(flujo)

	# Act 1 — tick de arranque: p1 emparejada y su atención EMPIEZA este mismo tick.
	flujo._al_tick(1.0)
	assert_str(String(p1.estado)).is_equal("en_atencion")
	assert_str(String(p2.estado)).is_equal("esperando_dentro")

	# Act 2 — 11 ticks más: aún no cumple (12 min exactos).
	for i: int in range(11):
		flujo._al_tick(1.0)
	assert_int(emisiones.size()).is_equal(0)

	# Act 3 — el tick 12 de la atención: emite UNA vez, p1 sale, p2 entra EN el mismo tick.
	flujo._al_tick(1.0)
	assert_int(emisiones.size()).is_equal(1)
	assert_str(String(emisiones[0][0])).is_equal("dni")
	assert_str(emisiones[0][1].nombre).is_equal("Ana Ruiz")   # el agente REAL viaja en el evento
	assert_str(String(p1.estado)).is_equal("resuelta")
	assert_str(String(p2.estado)).is_equal("en_atencion")

	# Act 4 — 12 ticks más: p2 completa (2.ª emisión) y NADA se re-emite después.
	for i: int in range(12):
		flujo._al_tick(1.0)
	assert_int(emisiones.size()).is_equal(2)
	flujo._al_tick(1.0)
	flujo._al_tick(1.0)
	assert_int(emisiones.size()).is_equal(2)
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("libre")


# ── E2E: EL SALDO SUBE — Economía real cobra el dni al completarse (E01: +3,6 €) ──────────
func test_el_saldo_sube() -> void:
	# Arrange — Economía real enganchada al MISMO bus (su ingreso E01 ya está testeado: dni → 3,6 €).
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	var bus: Node = mundo[2]
	var eco: Node = auto_free(EconomiaScript.new())
	eco.aplicar_config(ConfigEconomiaScript.new())
	eco.usar_bus(bus)
	_dni_en_cola(flujo)

	# Act — la atención completa (1 arranque + 12 de atención).
	for i: int in range(13):
		flujo._al_tick(1.0)

	# Assert — PRIMERA VEZ en el proyecto: el dinero SUBE por un trámite atendido.
	assert_float(eco.saldo_eur).is_equal_approx(3003.6, 0.001)


# ── FL8: en Pausa (mundo REAL en árbol) la atención no avanza ni se llama a nadie ─────────
func test_pausa_congela_la_atencion() -> void:
	# Arrange — reloj real en PAUSA empujando el tick de verdad; una atención a medias.
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	var bus: Node = mundo[2]
	var tiempo: Node = auto_free(TiempoScript.new())
	flujo.usar_tiempo(tiempo)
	var emisiones: Array = []
	bus.tramite_completado.connect(func(_t: StringName, _a: RefCounted) -> void: emisiones.append(_t))
	add_child(tiempo)
	add_child(flujo)
	_dni_en_cola(flujo)
	flujo._al_tick(1.0)
	flujo._al_tick(5.0)   # quedan 7 de 12
	var restante_antes: float = float(flujo._puestos_flujo[&"doc_1"]["restante"])
	tiempo.fijar_velocidad(TiempoScript.Velocidad.PAUSA)

	# Act — 30 frames de physics REALES en Pausa.
	for i: int in range(30):
		await get_tree().physics_frame

	# Assert — nada avanzó: mismos minutos restantes, 0 emisiones.
	assert_float(float(flujo._puestos_flujo[&"doc_1"]["restante"])).is_equal_approx(restante_antes, 0.0001)
	assert_int(emisiones.size()).is_equal(0)
