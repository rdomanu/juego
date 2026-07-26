# Story paciencia-002 (TR-patience-002) — el tick, la Pausa y EL ABANDONO. Tipo: Integration.
# DETERMINISTA: ticks manuales con minutos exactos; Flujo, Personal y Construcción REALES (sin
# dobles), sin RNG. Los minutos esperados salen de F1 calculada a mano, no de la implementación.
extends GdUnitTestSuite

const PacienciaScript := preload("res://src/feature/paciencia/paciencia.gd")
const ConfigPacienciaScript := preload("res://src/feature/paciencia/config_paciencia.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")


# ── Fixture ──────────────────────────────────────────────────────────────────────────────
## Comisaría mínima: sala de espera Doc 3×3 con 3 asientos (aforo holgado: nadie se queda fuera ni
## hay hacinamiento) + un puesto Doc SIN agente → nadie es atendido, así la paciencia manda.
## Camino a 0.0 para que ningún trayecto enturbie los minutos contados (gotcha registrado).
func _mundo(con_agente: bool = false) -> Dictionary:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_personal(personal)
	construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(0, 0, 3, 3))
	for i: int in 3:
		construccion.construir_de_oficio_elemento(construccion.ASIENTO_BASICO, Vector2i(i, 0))
	construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(4, 0, 4, 4))
	construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(5, 1), &"doc_1")

	var bus: Node = auto_free(EventBusScript.new())
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.velocidad_camino_celdas_min = 0.0   # llegada instantánea: los minutos son solo de espera
	flujo.usar_bus(bus)
	flujo.usar_personal(personal)
	flujo.usar_construccion(construccion)
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")
	# Reloj SIN árbol (no empuja: solo da la hora) a las 08:20. Imprescindible: con el horario
	# provisional de Doc, a la hora por defecto (00:00) el puesto se cerraría solo y no llamaría
	# a nadie — el test no probaría lo que dice probar.
	var tiempo: Node = auto_free(TiempoScript.new())
	tiempo.minutos_juego = 500.0
	flujo.usar_tiempo(tiempo)
	if con_agente:
		var agente: RefCounted = AgenteScript.new("Ana Ruiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)
		personal.plantilla.append(agente)
		personal.asignar(agente, &"doc_1")

	var paciencia: Node = auto_free(PacienciaScript.new())
	paciencia.aplicar_config(ConfigPacienciaScript.new())
	paciencia.usar_flujo(flujo)
	paciencia.usar_construccion(construccion)
	return {"flujo": flujo, "paciencia": paciencia, "bus": bus, "personal": personal}


## Mete a una persona en la cola de Documentación y devuelve su PersonaFlujo.
func _encolar(flujo: Node, minuto: int = 480) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", minuto))
	flujo.encolar(persona)
	return persona


# ── El drenaje real por el tick ──────────────────────────────────────────────────────────
func test_el_tick_drena_a_quien_espera() -> void:
	var mundo: Dictionary = _mundo()
	var persona: RefCounted = _encolar(mundo["flujo"])
	mundo["paciencia"]._al_tick(15.0)   # 15 min neutros → 100 − 3.33×15 = 50
	assert_float(mundo["paciencia"].paciencia_de(persona)).is_equal_approx(50.0, 0.01)


func test_treinta_minutos_sin_ser_atendida_y_se_marcha() -> void:
	var mundo: Dictionary = _mundo()
	var persona: RefCounted = _encolar(mundo["flujo"])
	mundo["paciencia"]._al_tick(29.0)
	assert_str(persona.estado).is_equal(PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO)
	mundo["paciencia"]._al_tick(1.0)    # completa los 30 min: se harta
	assert_str(persona.estado).is_equal(PersonaFlujoScript.ESTADO_ABANDONANDO)
	assert_int(mundo["flujo"].personas_en_cola(&"Documentacion")).is_equal(0)


func test_el_abandono_avisa_por_el_bus() -> void:
	var mundo: Dictionary = _mundo()
	var avisos: Array = []
	(mundo["bus"] as Node).abandono.connect(func(p: RefCounted) -> void: avisos.append(p))
	var persona: RefCounted = _encolar(mundo["flujo"])
	mundo["paciencia"]._al_tick(30.0)
	assert_int(avisos.size()).is_equal(1)
	assert_object(avisos[0]).is_same(persona)


# ── AC-PS04 · La llamada CONGELA la paciencia ────────────────────────────────────────────
func test_llamada_congela_la_paciencia() -> void:
	var mundo: Dictionary = _mundo(true)   # con agente: a esta la llaman
	var persona: RefCounted = _encolar(mundo["flujo"])
	mundo["paciencia"]._al_tick(15.0)      # espera un rato: 100 → 50
	mundo["flujo"]._al_tick(0.1)      # el puesto la toma → estado llamada/en_atencion
	assert_str(persona.estado).is_not_equal(PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO)
	mundo["paciencia"]._al_tick(60.0)      # una hora más: NO debe drenar ni un punto
	assert_float(mundo["paciencia"].paciencia_de(persona)).is_equal_approx(50.0, 0.01)
	assert_str(persona.estado).is_not_equal(PersonaFlujoScript.ESTADO_ABANDONANDO)


# ── AC-PS19 · Empate: gana la llamada, no hay abandono ───────────────────────────────────
func test_empate_llamada_vence_al_abandono() -> void:
	var mundo: Dictionary = _mundo(true)
	var persona: RefCounted = _encolar(mundo["flujo"])
	# La dejamos al borde exacto (paciencia 0 tras este tick) pero Flujo la llama ANTES —
	# es el orden real del tick: Flujo se suscribe primero, Paciencia después.
	mundo["paciencia"]._al_tick(29.0)
	mundo["flujo"]._al_tick(0.1)      # Flujo llama primero (orden del ADR-0001)
	mundo["paciencia"]._al_tick(10.0)      # Paciencia mira después: ya está llamada → congelada
	assert_str(persona.estado).is_not_equal(PersonaFlujoScript.ESTADO_ABANDONANDO)


func test_forzar_abandono_rechazado_no_saca_a_la_persona() -> void:
	var mundo: Dictionary = _mundo(true)
	var persona: RefCounted = _encolar(mundo["flujo"])
	mundo["flujo"]._al_tick(0.1)      # la llaman de inmediato
	assert_bool(mundo["flujo"].forzar_abandono(persona)).is_false()   # regla dura de Flujo
	assert_str(persona.estado).is_not_equal(PersonaFlujoScript.ESTADO_ABANDONANDO)


# ── Determinismo del orden ───────────────────────────────────────────────────────────────
func test_dos_a_cero_el_mismo_tick_abandona_antes_el_de_menor_turno() -> void:
	var mundo: Dictionary = _mundo()
	var avisos: Array = []
	(mundo["bus"] as Node).abandono.connect(func(p: RefCounted) -> void: avisos.append(p.numero_turno))
	var primera: RefCounted = _encolar(mundo["flujo"], 480)
	var segunda: RefCounted = _encolar(mundo["flujo"], 481)
	mundo["paciencia"]._al_tick(30.0)      # los dos se hartan en el mismo tick
	assert_int(avisos.size()).is_equal(2)
	assert_int(avisos[0]).is_less(avisos[1])   # siempre primero el de menor turno


# ── AC-PS22 · En Pausa no drena (el reloj no entrega minutos) ────────────────────────────
func test_pausa_no_drena() -> void:
	var mundo: Dictionary = _mundo()
	var persona: RefCounted = _encolar(mundo["flujo"])
	mundo["paciencia"]._al_tick(10.0)      # espera de verdad: 100 − 3.33×10 = 66.67
	var antes: float = mundo["paciencia"].paciencia_de(persona)
	for i: int in 5:
		mundo["paciencia"]._al_tick(0.0)   # lo que entrega el reloj en Pausa: cero minutos
	assert_float(mundo["paciencia"].paciencia_de(persona)).is_equal(antes)


# ── Ciclo de vida: quien se va deja de ocupar sitio en el sistema ────────────────────────
func test_al_marcharse_deja_de_ser_vigilada() -> void:
	var mundo: Dictionary = _mundo()
	var persona: RefCounted = _encolar(mundo["flujo"])
	mundo["paciencia"]._al_tick(30.0)
	assert_bool(mundo["paciencia"].tiene(persona)).is_false()
	assert_int(mundo["paciencia"].personas_vigiladas()).is_equal(0)


func test_la_atendida_se_purga_del_sistema() -> void:
	var mundo: Dictionary = _mundo(true)
	var persona: RefCounted = _encolar(mundo["flujo"])
	mundo["paciencia"]._al_tick(1.0)
	assert_int(mundo["paciencia"].personas_vigiladas()).is_equal(1)
	mundo["flujo"]._al_tick(0.1)      # la toman
	mundo["flujo"]._al_tick(120.0)    # y termina el trámite
	assert_str(persona.estado).is_equal(PersonaFlujoScript.ESTADO_RESUELTA)
	mundo["paciencia"]._al_tick(1.0)       # el siguiente tick la suelta
	assert_int(mundo["paciencia"].personas_vigiladas()).is_equal(0)


# ── Sin Flujo inyectado no hace nada (dependencia blanda, patrón del proyecto) ───────────
func test_sin_flujo_el_tick_no_peta() -> void:
	var suelto: Node = auto_free(PacienciaScript.new())
	suelto.aplicar_config(ConfigPacienciaScript.new())
	suelto._al_tick(30.0)
	assert_int(suelto.personas_vigiladas()).is_equal(0)


# ── Story 003 · La puntuación usa el trato del agente REAL que atendió ───────────────────
func test_la_puntuacion_usa_el_trato_del_agente_que_atiende() -> void:
	var mundo: Dictionary = _mundo(true)
	mundo["paciencia"].usar_personal(mundo["personal"])
	var persona: RefCounted = _encolar(mundo["flujo"])
	mundo["paciencia"]._al_tick(15.0)      # espera media: consume 50 de paciencia
	mundo["flujo"]._al_tick(0.1)           # la llaman → su "recibo" de espera queda congelado
	mundo["paciencia"]._al_tick(1.0)       # el tick anota la paciencia con la que fue llamada
	assert_float(mundo["paciencia"].paciencia_consumida_de(persona)).is_equal_approx(50.0, 0.1)
	# Trato del agente (3/5 → factor 1.0 neutro con los knobs semilla) → 80 × 0.75 × 1.0 = 60.
	assert_float(mundo["paciencia"].puntuacion_de_visita(persona)).is_equal_approx(60.0, 0.5)


func test_quien_se_marcha_puntua_cero_aunque_hubiera_esperado_poco() -> void:
	var mundo: Dictionary = _mundo()
	mundo["paciencia"].usar_personal(mundo["personal"])
	var persona: RefCounted = _encolar(mundo["flujo"])
	mundo["paciencia"]._al_tick(30.0)      # se harta y se va
	assert_float(mundo["paciencia"].puntuacion_de_visita(persona)).is_equal(0.0)
