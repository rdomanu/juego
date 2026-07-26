# Story paciencia-007 — persistencia y LA PRUEBA REINA del determinismo con abandonos.
# Tipo: Integration. DETERMINISTA: ticks manuales, RNG sembrado, cero dependencia de la hora real.
extends GdUnitTestSuite

const PacienciaScript := preload("res://src/feature/paciencia/paciencia.gd")
const ConfigPacienciaScript := preload("res://src/feature/paciencia/config_paciencia.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")
const RNGScript := preload("res://src/foundation/rng_service/rng_service.gd")


## Mundo mínimo determinista: Flujo con un puesto SIN agente (nadie atiende → manda la paciencia),
## Paciencia enganchada y reloj a las 08:20 (dentro del horario de Doc — gotcha registrado).
func _mundo() -> Dictionary:
	var bus: Node = auto_free(EventBusScript.new())
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.velocidad_camino_celdas_min = 0.0
	flujo.usar_bus(bus)
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")
	var tiempo: Node = auto_free(TiempoScript.new())
	tiempo.minutos_juego = 500.0
	flujo.usar_tiempo(tiempo)
	var rng: Node = auto_free(RNGScript.new())
	rng.sembrar(4242)
	var paciencia: Node = auto_free(PacienciaScript.new())
	paciencia.aplicar_config(ConfigPacienciaScript.new())
	paciencia.usar_flujo(flujo)
	paciencia.usar_bus(bus)
	paciencia.usar_rng(rng)
	return {"flujo": flujo, "paciencia": paciencia, "bus": bus, "tiempo": tiempo, "rng": rng}


func _encolar(flujo: Node, minuto: int) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", minuto))
	flujo.encolar(persona)
	return persona


# ── AC-PS21 · Guardar y cargar restaura barras, acumulador y contadores ─────────────────
func test_guardar_y_cargar_restaura_paciencias_y_contadores() -> void:
	var a: Dictionary = _mundo()
	_encolar(a["flujo"], 480)
	_encolar(a["flujo"], 481)
	a["paciencia"]._al_tick(12.0)          # 100 − 3.33×12 = 60 en cada una
	a["paciencia"].reclamaciones_mes = 7   # un mes con historia
	var guardado_flujo: Dictionary = a["flujo"].save()
	var guardado_pac: Dictionary = a["paciencia"].save()

	# Partida nueva: se cargan los dos sistemas (Flujo primero — él reconstruye a las personas).
	var b: Dictionary = _mundo()
	b["flujo"].load_state(guardado_flujo)
	b["paciencia"].load_state(guardado_pac)
	assert_int(b["paciencia"].reclamaciones_mes).is_equal(7)
	# Las barras se reenganchan en cuanto se vuelve a ver a sus dueñas (el primer tick).
	b["paciencia"]._al_tick(0.001)
	for persona: RefCounted in b["flujo"].personas_de_cola(&"Documentacion"):
		assert_float(b["paciencia"].paciencia_de(persona)).is_equal_approx(60.0, 0.2)


func test_la_media_del_dia_a_medias_sobrevive_al_guardado() -> void:
	var a: Dictionary = _mundo()
	var persona: RefCounted = _encolar(a["flujo"], 480)
	a["paciencia"]._al_tick(30.0)          # se marcha → un 0 en la media del día
	var sat_antes: float = a["paciencia"].sat_actual_de(&"Documentacion")
	var b: Dictionary = _mundo()
	b["paciencia"].load_state(a["paciencia"].save())
	assert_float(b["paciencia"].sat_actual_de(&"Documentacion")).is_equal(sat_antes)


func test_los_cierres_de_ayer_sobreviven() -> void:
	var a: Dictionary = _mundo()
	var persona: RefCounted = _encolar(a["flujo"], 480)
	a["paciencia"]._al_tick(30.0)
	a["paciencia"].cerrar_jornada()
	var b: Dictionary = _mundo()
	b["paciencia"].load_state(a["paciencia"].save())
	assert_float(b["paciencia"].sat_cierre_de(&"Documentacion")).is_equal(
		a["paciencia"].sat_cierre_de(&"Documentacion")
	)


# ── AC-PS23 · LA PRUEBA REINA: A (guardada y recargada) == B (continua) ─────────────────
func test_a_vs_b_con_abandonos_misma_secuencia_de_eventos() -> void:
	# Partida A: 10 ticks, se guarda, se recarga en un mundo nuevo y se siguen otros 10.
	var a: Dictionary = _mundo()
	var eventos_a: Array = []
	(a["bus"] as Node).abandono.connect(func(p: RefCounted) -> void: eventos_a.append(p.numero_turno))
	for i: int in 3:
		_encolar(a["flujo"], 480 + i)
	for i: int in 10:
		a["flujo"]._al_tick(1.0)
		a["paciencia"]._al_tick(1.0)
	var save_flujo: Dictionary = a["flujo"].save()
	var save_pac: Dictionary = a["paciencia"].save()

	var recargada: Dictionary = _mundo()
	var eventos_recarga: Array = []
	(recargada["bus"] as Node).abandono.connect(
		func(p: RefCounted) -> void: eventos_recarga.append(p.numero_turno)
	)
	recargada["flujo"].load_state(save_flujo)
	recargada["paciencia"].load_state(save_pac)
	for i: int in 30:
		recargada["flujo"]._al_tick(1.0)
		recargada["paciencia"]._al_tick(1.0)

	# Partida B: los mismos 40 ticks del tirón, sin guardar nunca.
	var b: Dictionary = _mundo()
	var eventos_b: Array = []
	(b["bus"] as Node).abandono.connect(func(p: RefCounted) -> void: eventos_b.append(p.numero_turno))
	for i: int in 3:
		_encolar(b["flujo"], 480 + i)
	for i: int in 40:
		b["flujo"]._al_tick(1.0)
		b["paciencia"]._al_tick(1.0)

	# A (10 + recarga + 30) debe haber vivido EXACTAMENTE lo mismo que B (40 del tirón).
	var eventos_totales_a: Array = eventos_a + eventos_recarga
	assert_array(eventos_totales_a).is_equal(eventos_b)
	assert_int(eventos_b.size()).is_greater(0)   # que de verdad hubo abandonos que comparar


func test_misma_semilla_mismos_abandonos() -> void:
	var primera: Array = _corrida()
	var segunda: Array = _corrida()
	assert_array(primera).is_equal(segunda)


## Una partida completa de 40 ticks; devuelve los turnos que abandonaron, en orden.
func _corrida() -> Array:
	var mundo: Dictionary = _mundo()
	# Gotcha del proyecto: las lambdas capturan por VALOR → el acumulador debe ser un Array.
	var abandonos: Array = []
	(mundo["bus"] as Node).abandono.connect(
		func(p: RefCounted) -> void: abandonos.append(p.numero_turno)
	)
	for i: int in 4:
		_encolar(mundo["flujo"], 480 + i)
	for i: int in 40:
		mundo["flujo"]._al_tick(1.0)
		mundo["paciencia"]._al_tick(1.0)
	return abandonos
