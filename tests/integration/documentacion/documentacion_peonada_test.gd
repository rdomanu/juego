# Story documentacion-003 (TR-doc-001) — la peonada (F1/F2) y el precio en MORAL de exprimir el
# cierre (DO4/DO5). Tipo: Integration. DETERMINISTA: reloj inyectado sin árbol, catálogo y Personal
# REALES, sin RNG.
#
# ⚠️ La regla que este test fija (decisión del usuario 2026-07-26, GDD DO4/DO5):
#   · AMPLIAR el horario  → cuesta DINERO (peonada, voluntaria y pagada; la motivación NO baja).
#   · REZAGADOS al cierre → cuesta MORAL (sin peonada: se termina fuera de hora sin cobrar extra).
extends GdUnitTestSuite

const DocumentacionScript := preload("res://src/feature/documentacion/documentacion.gd")
const ConfigDocumentacionScript := preload("res://src/feature/documentacion/config_documentacion.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const DemandaScript := preload("res://src/core/demanda/demanda.gd")
const ConfigDemandaScript := preload("res://src/core/demanda/config_demanda.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

## Coste de una hora extra por funcionario en el catálogo real (`costes_global`).
const PEONADA_EUR_HORA := 15.0


# ── Fixture ──────────────────────────────────────────────────────────────────────────────
## Mundo con `puestos_doc` puestos de Doc DOTADOS, Economía/Personal/Bus reales y el reloj a `min_dia`.
## Devuelve [documentacion, flujo, economia, personal, tiempo, bus].
func _mundo(puestos_doc: int = 2, min_dia: float = 600.0) -> Array:
	var bus: Node = auto_free(EventBusScript.new())
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.velocidad_camino_celdas_min = 0.0
	flujo.usar_personal(personal)
	flujo.usar_bus(bus)
	for i: int in range(puestos_doc):
		var puesto_id: StringName = StringName("doc_%d" % (i + 1))
		personal.registrar_puesto(puesto_id, &"puesto_doc_general")
		flujo.registrar_puesto_flujo(puesto_id, &"puesto_doc_general")
		var agente: RefCounted = AgenteScript.new(
			"Agente %d" % (i + 1), &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3
		)
		personal.plantilla.append(agente)
		personal.asignar(agente, puesto_id)
	var tiempo: Node = auto_free(TiempoScript.new())
	tiempo.minutos_juego = min_dia
	flujo.usar_tiempo(tiempo)
	var doc: Node = auto_free(DocumentacionScript.new())
	doc.usar_tiempo(tiempo)
	doc.usar_bus(bus)
	doc.usar_economia(economia)
	doc.usar_personal(personal)
	doc.aplicar_config(ConfigDocumentacionScript.new())
	# El cableado de Main (story doc-006): el horario del servicio **y** el de cada ventanilla.
	doc.horario_cambiado.connect(
		func(apertura: int, cierre: int, ultima: int) -> void:
			flujo.fijar_horario_doc(apertura, cierre, ultima)
			for id: StringName in doc.puestos_de_doc():
				flujo.fijar_cierre_de_puesto(
					id, cierre if doc.puesto_de_tarde(id) else doc.cierre_base_min
				)
	)
	doc.refrescar_horario()
	return [doc, flujo, economia, personal, tiempo, bus]


func _dni_admitido(flujo: Node, minuto: float) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", minuto))
	if persona != null:
		flujo.encolar(persona)
	return persona


# ── AC-DC04 · F1: la cuenta de la peonada ────────────────────────────────────────────────
func test_cerrar_a_las_dieciocho_con_dos_agentes_cuesta_105() -> void:
	var mundo: Array = _mundo(2)
	var doc: Node = mundo[0]

	doc.fijar_hora_cierre(1080)                       # 18:00 → 3,5 h extra
	assert_int(doc.num_agentes_doc()).is_equal(2)
	# 15 €/h × 3,5 h × 2 agentes = 105 €/día (el ejemplo literal del GDD, F1).
	assert_float(doc.coste_peonada_estimado()).is_equal_approx(105.0, 0.001)


func test_la_jornada_base_no_cuesta_peonada() -> void:
	var doc: Node = _mundo(2)[0]
	assert_float(doc.coste_peonada_estimado()).is_equal(0.0)
	assert_float(doc.horas_agente_extra()).is_equal(0.0)


func test_sin_agentes_dotados_no_hay_peonada_que_pagar() -> void:
	var mundo: Array = _mundo(0)                      # puestos sin dotar: nadie cobra por no venir
	var doc: Node = mundo[0]
	doc.fijar_hora_cierre(1200)
	assert_int(doc.num_agentes_doc()).is_equal(0)
	assert_float(doc.coste_peonada_estimado()).is_equal(0.0)


func test_un_solo_agente_paga_la_mitad() -> void:
	var doc: Node = _mundo(1)[0]
	doc.fijar_hora_cierre(1080)
	assert_float(doc.coste_peonada_estimado()).is_equal_approx(52.5, 0.001)


func test_el_coste_se_puede_previsualizar_sin_aplicarlo() -> void:
	# Lo que el panel del slider enseñará en vivo mientras se arrastra (story 005).
	var doc: Node = _mundo(2)[0]
	assert_float(doc.coste_peonada_estimado(1200)).is_equal_approx(165.0, 0.001)  # 5,5 h × 15 × 2
	assert_int(doc.hora_cierre_min).is_equal(870)     # ...y el horario NO se ha tocado


# ── El cierre del día: Economía recibe las horas ANTES de pasar la factura ───────────────
func test_al_cerrar_el_dia_economia_recibe_las_horas_agente() -> void:
	var mundo: Array = _mundo(2)
	var doc: Node = mundo[0]
	var economia: Node = mundo[2]

	doc.fijar_hora_cierre(1080)                       # 3,5 h × 2 agentes = 7 horas-agente
	doc._al_nuevo_dia()
	assert_float(economia._horas_extra_dia).is_equal_approx(7.0, 0.0001)
	# Economía pone el precio (aquí no se duplica el euro/hora): 7 × 15 = 105 €.
	assert_float(economia._horas_extra_dia * PEONADA_EUR_HORA).is_equal_approx(105.0, 0.001)


func test_con_jornada_base_no_se_le_registra_nada_a_economia() -> void:
	var mundo: Array = _mundo(2)
	mundo[0]._al_nuevo_dia()
	assert_float(mundo[2]._horas_extra_dia).is_equal(0.0)


func test_la_peonada_se_registra_en_prioridad_15_entre_paciencia_y_economia() -> void:
	# El orden importa: si Documentación registrara DESPUÉS de Economía (20), la peonada del día se
	# cobraría un día tarde. ⚠️ Contador en Array: las lambdas capturan por valor.
	var mundo: Array = _mundo(2)
	var doc: Node = mundo[0]
	var bus: Node = mundo[5]
	var orden: Array = []
	bus.registrar_ordenado(&"nuevo_dia", 14, func() -> void: orden.append("antes"))
	bus.registrar_ordenado(&"nuevo_dia", 16, func() -> void: orden.append("despues"))
	doc.fijar_hora_cierre(1080)

	bus.disparar_ordenado(&"nuevo_dia")

	assert_array(orden).contains_exactly(["antes", "despues"])
	assert_float(mundo[2]._horas_extra_dia).is_equal_approx(7.0, 0.0001)


# ── AC-DC06 · La peonada NO desmotiva (es voluntaria y pagada) ───────────────────────────
func test_atender_dentro_del_horario_ampliado_no_baja_la_motivacion() -> void:
	var mundo: Array = _mundo(1, 600.0)
	var doc: Node = mundo[0]
	var flujo: Node = mundo[1]
	var personal: Node = mundo[3]
	var tiempo: Node = mundo[4]
	doc.fijar_hora_cierre(1080)                       # la tarde va pagada
	var agente: RefCounted = personal.agente_de(&"doc_1")
	var motivacion_antes: int = agente.motivacion

	tiempo.minutos_juego = 1000.0                     # 16:40 — DENTRO del horario ampliado
	_dni_admitido(flujo, 1000.0)
	for i: int in range(13):
		flujo._al_tick(1.0)

	assert_int(agente.motivacion).is_equal(motivacion_antes)


# ── AC-DC08 · Los rezagados desmotivan, y son gratis en euros ────────────────────────────
func test_terminar_fuera_de_hora_desmotiva_sin_cobrar_peonada() -> void:
	var mundo: Array = _mundo(1, 865.0)               # 14:25, jornada base (cierra 14:30)
	var doc: Node = mundo[0]
	var flujo: Node = mundo[1]
	var economia: Node = mundo[2]
	var personal: Node = mundo[3]
	var tiempo: Node = mundo[4]
	doc.fijar_margen_ultima_admision(0)               # exprimir: se da número hasta el cierre
	var agente: RefCounted = personal.agente_de(&"doc_1")
	assert_int(agente.motivacion).is_equal(3)
	_dni_admitido(flujo, 865.0)                       # entra a las 14:25: terminará a las 14:38

	# Act — se le atiende hasta el final (compromiso de servicio), ya pasado el cierre.
	for i: int in range(13):
		tiempo.minutos_juego += 1.0
		flujo._al_tick(1.0)

	# Assert — el agente se lleva el disgusto; la caja no se entera (el coste es moral, DO5).
	assert_int(agente.motivacion).is_equal(2)
	assert_float(economia._horas_extra_dia).is_equal(0.0)


func test_la_desmotivacion_es_una_sola_vez_al_dia_por_agente() -> void:
	var mundo: Array = _mundo(1, 865.0)
	var doc: Node = mundo[0]
	var flujo: Node = mundo[1]
	var personal: Node = mundo[3]
	var tiempo: Node = mundo[4]
	doc.fijar_margen_ultima_admision(0)
	var agente: RefCounted = personal.agente_de(&"doc_1")
	# Dos rezagados seguidos del MISMO agente: una tarde mala no puede dejarlo a 1 de motivación.
	_dni_admitido(flujo, 865.0)
	_dni_admitido(flujo, 866.0)
	for i: int in range(30):
		tiempo.minutos_juego += 1.0
		flujo._al_tick(1.0)

	assert_int(agente.motivacion).is_equal(2)         # −1, no −2
	# Al día siguiente vuelve a poder llevarse otro disgusto (la lista se vacía en el cierre).
	doc._al_nuevo_dia()
	tiempo.minutos_juego = 865.0
	var rezagado: RefCounted = _dni_admitido(flujo, 865.0)
	assert_object(rezagado).is_not_null()
	for i: int in range(20):
		tiempo.minutos_juego += 1.0
		flujo._al_tick(1.0)
	assert_str(String(rezagado.estado)).is_equal("resuelta")
	assert_int(agente.motivacion).is_equal(1)


func test_la_motivacion_nunca_baja_de_uno() -> void:
	var mundo: Array = _mundo(1, 865.0)
	var doc: Node = mundo[0]
	var personal: Node = mundo[3]
	var agente: RefCounted = personal.agente_de(&"doc_1")
	agente.motivacion = 1
	doc._al_tramite_completado(&"dni", agente)        # ya fuera de horario (14:25 < 14:30 → no)
	mundo[4].minutos_juego = 900.0                    # 15:00: ahora sí está cerrado
	doc._al_tramite_completado(&"dni", agente)
	assert_int(agente.motivacion).is_equal(1)


func test_una_denuncia_de_odac_no_desmotiva_a_nadie() -> void:
	# ODAC es 24 h: no tiene horario que incumplir (el trámite ni siquiera es de Doc).
	var mundo: Array = _mundo(1, 900.0)               # 15:00, Doc cerrada
	var doc: Node = mundo[0]
	var agente: RefCounted = mundo[3].agente_de(&"doc_1")
	doc._al_tramite_completado(&"estafa", agente)
	assert_int(agente.motivacion).is_equal(3)


## Regresión (bug de la impresora, 2026-08-06): `_al_tramite_completado` consultaba el catálogo
## TramiteDoc SIN FILTRAR (`tramite()` → `Datos.obtener`, ruidoso) con el id de CUALQUIER trámite
## cerrado — una denuncia ODAC ("estafa" no existe en TramiteDoc) disparaba `push_warning` en
## CADA cierre (ruido de log; el comportamiento ya era correcto, sin horario que incumplir). El fix
## usa `Datos.obtener_silencioso` (mismo patrón que `datos.gd` ya ofrece para "¿es de este tipo?").
func test_documentacion_tramite_odac_completado_no_genera_aviso() -> void:
	# Arrange — Doc cerrada (900 = 15:00): si la consulta ruidosa colara, este es el minuto que la
	# dispara (la rama de DO5 solo se evalúa fuera de horario).
	var mundo: Array = _mundo(1, 900.0)
	var doc: Node = mundo[0]
	var agente: RefCounted = mundo[3].agente_de(&"doc_1")

	# Act + Assert — la comprobación "¿es de Doc?" debe ser SILENCIOSA: cero push_warning/push_error.
	await assert_error(func() -> void: doc._al_tramite_completado(&"estafa", agente)).is_success()


## Companion del test de arriba: el fix no debe silenciar de más — un trámite de Doc genuino
## (id VÁLIDO en el catálogo) también cierra sin ningún aviso y el DO5 (desmotivación por rezago
## fuera de horario) sigue intacto.
func test_documentacion_tramite_doc_completado_no_genera_aviso_y_desmotiva() -> void:
	# Arrange
	var mundo: Array = _mundo(1, 900.0)               # 15:00, Doc cerrada
	var doc: Node = mundo[0]
	var agente: RefCounted = mundo[3].agente_de(&"doc_1")

	# Act + Assert
	await assert_error(func() -> void: doc._al_tramite_completado(&"dni", agente)).is_success()
	assert_int(agente.motivacion).is_equal(2)   # DO5 intacto: sigue desmotivando 1 punto


# ── AC-DC05 / DO12 · La brújula: el nivel de demanda ─────────────────────────────────────
func test_el_nivel_de_demanda_se_delega_en_demanda() -> void:
	var doc: Node = _mundo(1)[0]
	var demanda: Node = auto_free(DemandaScript.new())
	demanda.aplicar_config(ConfigDemandaScript.new())
	demanda.fijar_poblacion(90000)
	doc.usar_demanda(demanda)
	assert_str(String(doc.nivel_demanda())).is_equal(String(demanda.nivel_demanda()))


func test_sin_demanda_inyectada_el_nivel_es_neutro() -> void:
	assert_str(String(_mundo(1)[0].nivel_demanda())).is_equal("MEDIA")


func test_con_demanda_alta_la_ampliacion_puede_pagarse_y_con_baja_no() -> void:
	# F2 en su forma comprobable: la decisión compara el ingreso extra ESPERADO con el coste fijo de
	# la peonada. Con 1 agente y 3,5 h de tarde, el coste es 52,5 € — atender ~10 dni (12 € × retorno
	# 0.30 ≈ 3,6 €) da ~36 €: con la cola vacía (demanda BAJA) se pierde; hace falta cola que vaciar.
	var mundo: Array = _mundo(1)
	var doc: Node = mundo[0]
	var economia: Node = mundo[2]
	doc.fijar_hora_cierre(1080)
	var coste: float = doc.coste_peonada_estimado()
	var tarifa: float = float(doc.tramite(&"dni").tarifa_eur)
	var ingreso_por_dni: float = tarifa * economia.retorno_dgp(economia.sat_cierre_doc)

	assert_float(coste).is_equal_approx(52.5, 0.001)
	# Con la cola vacía (demanda BAJA) no se atiende a nadie extra: ingreso 0 < 52,5 € → se PIERDE
	# dinero. Está permitido: el nivel BAJA/MEDIA/ALTA es la brújula que lo avisa, no un muro.
	assert_bool(0.0 < coste).is_true()
	# Con cola que vaciar (demanda ALTA) compensa a partir de N trámites en esas 3,5 h.
	var minimo_rentable: int = int(ceil(coste / ingreso_por_dni))
	assert_bool(float(minimo_rentable) * ingreso_por_dni >= coste).is_true()
	assert_bool(float(minimo_rentable - 1) * ingreso_por_dni < coste).is_true()


# ══ Story doc-006 · Peonada POR VENTANILLA (feedback del usuario 2026-07-28) ══════════════
# "En temporada baja no es rentable abrir todos los puestos pero sí unos pocos." Antes, ampliar
# el horario cobraba por TODAS las ventanillas dotadas: la decisión no se podía tomar.

# ── AC-DC17 · Se paga por la que se queda, no por la plantilla ───────────────────────────
func test_solo_una_ventanilla_de_tarde_cuesta_la_peonada_de_una() -> void:
	var mundo: Array = _mundo(3)                      # 3 ventanillas dotadas
	var doc: Node = mundo[0]
	doc.fijar_hora_cierre(1080)                       # 18:00 → 3,5 h extra
	assert_float(doc.coste_peonada_estimado()).is_equal_approx(157.5, 0.001)   # las 3

	doc.fijar_puesto_de_tarde(&"doc_2", false)
	doc.fijar_puesto_de_tarde(&"doc_3", false)        # solo se queda doc_1

	assert_int(doc.num_agentes_doc()).is_equal(1)
	assert_float(doc.coste_peonada_estimado()).is_equal_approx(52.5, 0.001)
	assert_float(doc.coste_peonada_por_ventanilla()).is_equal_approx(52.5, 0.001)


func test_una_ventanilla_sin_agente_no_cuenta_aunque_se_quede() -> void:
	var mundo: Array = _mundo(2)
	var doc: Node = mundo[0]
	var personal: Node = mundo[3]
	personal.registrar_puesto(&"doc_9", &"puesto_doc_general")   # existe, pero sin dotar
	doc.fijar_hora_cierre(1080)
	assert_int(doc.num_agentes_doc()).is_equal(2)                # las 2 dotadas, no 3


# ── AC-DC19 · Sin nadie de tarde, es como no haber ampliado ──────────────────────────────
func test_sin_ventanillas_de_tarde_el_servicio_vuelve_al_horario_base() -> void:
	var mundo: Array = _mundo(2)
	var doc: Node = mundo[0]
	var flujo: Node = mundo[1]
	doc.fijar_hora_cierre(1080)
	assert_int(doc.hora_cierre_efectiva()).is_equal(1080)

	doc.fijar_puesto_de_tarde(&"doc_1", false)
	doc.fijar_puesto_de_tarde(&"doc_2", false)        # nadie hace la tarde

	assert_int(doc.hora_cierre_efectiva()).is_equal(870)         # como si no hubiera ampliado
	assert_float(doc.horas_extra()).is_equal(0.0)
	assert_float(doc.coste_peonada_estimado()).is_equal(0.0)
	assert_int(doc.hora_ultima_admision()).is_equal(855)         # la puerta cierra a la hora de siempre
	assert_int(flujo.ultima_admision_doc_min).is_equal(855)
	# ...y el slider NO se ha movido: el jugador sigue viendo su elección de las 18:00.
	assert_int(doc.hora_cierre_min).is_equal(1080)


# ── AC-DC18 · La que se queda atiende; la que no, cierra ─────────────────────────────────
func test_pasado_el_cierre_base_solo_sigue_abierta_la_ventanilla_de_tarde() -> void:
	var mundo: Array = _mundo(2, 600.0)
	var doc: Node = mundo[0]
	var flujo: Node = mundo[1]
	var tiempo: Node = mundo[4]
	doc.fijar_hora_cierre(1080)                       # el servicio abre hasta las 18:00...
	doc.fijar_puesto_de_tarde(&"doc_2", false)        # ...pero doc_2 se va a su hora

	tiempo.minutos_juego = 900.0                      # 15:00
	flujo._al_tick(1.0)

	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("libre")      # sigue de guardia
	assert_str(String(flujo.estado_de_puesto(&"doc_2"))).is_equal("cerrado")    # se fue a casa
	assert_int(flujo.cierre_de_puesto(&"doc_1")).is_equal(1080)
	assert_int(flujo.cierre_de_puesto(&"doc_2")).is_equal(870)


func test_volver_a_marcar_la_ventanilla_la_reabre() -> void:
	var mundo: Array = _mundo(2, 900.0)               # 15:00, con el servicio ampliado
	var doc: Node = mundo[0]
	var flujo: Node = mundo[1]
	doc.fijar_hora_cierre(1080)
	doc.fijar_puesto_de_tarde(&"doc_2", false)
	flujo._al_tick(1.0)
	assert_str(String(flujo.estado_de_puesto(&"doc_2"))).is_equal("cerrado")

	doc.fijar_puesto_de_tarde(&"doc_2", true)         # el jugador cambia de idea
	flujo._al_tick(1.0)
	assert_str(String(flujo.estado_de_puesto(&"doc_2"))).is_equal("libre")


# ── AC-DC22 · Las ventanillas de tarde sobreviven al guardado ────────────────────────────
func test_las_ventanillas_de_tarde_se_guardan_y_se_restauran() -> void:
	var mundo: Array = _mundo(3)
	var doc: Node = mundo[0]
	doc.fijar_hora_cierre(1080)
	doc.fijar_puesto_de_tarde(&"doc_2", false)

	var recuperado: Dictionary = JSON.parse_string(JSON.stringify(doc.save()))
	var otro: Array = _mundo(3)
	var doc2: Node = otro[0]
	doc2.load_state(recuperado)

	assert_bool(doc2.puesto_de_tarde(&"doc_1")).is_true()
	assert_bool(doc2.puesto_de_tarde(&"doc_2")).is_false()
	assert_bool(doc2.puesto_de_tarde(&"doc_3")).is_true()
	assert_float(doc2.coste_peonada_estimado()).is_equal_approx(105.0, 0.001)


func test_un_save_anterior_a_esta_story_deja_a_todas_haciendo_la_tarde() -> void:
	var doc: Node = _mundo(2)[0]
	doc.load_state({"hora_cierre_min": 1080, "margen_ultima_admision_min": 15, "evento_activo_id": ""})
	assert_bool(doc.puesto_de_tarde(&"doc_1")).is_true()
	assert_bool(doc.puesto_de_tarde(&"doc_2")).is_true()


func test_una_ventanilla_nueva_hace_la_tarde_sin_darla_de_alta() -> void:
	# Se guarda la EXCEPCIÓN, no la norma: construir una ventanilla no obliga a acordarse de nada.
	var mundo: Array = _mundo(1)
	var doc: Node = mundo[0]
	mundo[3].registrar_puesto(&"doc_nueva", &"puesto_doc_general")
	assert_bool(doc.puesto_de_tarde(&"doc_nueva")).is_true()


# ══ Story bien-002 · El precio de la hora extra lo elige el jugador ═══════════════════════
# "el pago por hora de peonadas se podría cambiar con un slider... habría que calcular cuál es el
# coste máximo que se podría poner, para evitar pagarles 1000 euros por hora" (usuario 2026-07-28).

func test_el_precio_arranca_en_el_convenio_y_se_puede_subir_hasta_el_tope() -> void:
	var doc: Node = _mundo(2)[0]
	assert_float(doc.peonada_eur_hora).is_equal(15.0)              # el mínimo reglamentario
	assert_float(doc.generosidad_peonada()).is_equal(0.0)
	assert_float(doc.fijar_peonada_eur_hora(30.0)).is_equal(30.0)  # el techo
	assert_float(doc.generosidad_peonada()).is_equal(1.0)


func test_nadie_puede_pagar_mil_euros_la_hora_ni_bajar_del_convenio() -> void:
	var doc: Node = _mundo(2)[0]
	assert_float(doc.fijar_peonada_eur_hora(1000.0)).is_equal(30.0)   # el tope manda
	assert_float(doc.fijar_peonada_eur_hora(1.0)).is_equal(15.0)      # el convenio también


func test_pagar_mas_sale_mas_caro_en_la_cuenta_del_dia() -> void:
	var mundo: Array = _mundo(2)
	var doc: Node = mundo[0]
	doc.fijar_hora_cierre(1080)                                   # 3,5 h extra, 2 agentes
	assert_float(doc.coste_peonada_estimado()).is_equal_approx(105.0, 0.001)   # a 15 €/h
	doc.fijar_peonada_eur_hora(30.0)
	assert_float(doc.coste_peonada_estimado()).is_equal_approx(210.0, 0.001)   # a 30 €/h: el doble


func test_el_precio_avisa_a_quien_le_afecta() -> void:
	# ⚠️ Contador en Array: las lambdas capturan por valor.
	var doc: Node = _mundo(2)[0]
	var avisos: Array = []
	doc.peonada_cambiada.connect(
		func(eur: float, generosidad: float) -> void: avisos.append([eur, generosidad])
	)
	doc.fijar_peonada_eur_hora(30.0)
	doc.fijar_peonada_eur_hora(30.0)                              # mismo precio: no vuelve a avisar
	assert_int(avisos.size()).is_equal(1)
	assert_float(avisos[0][0]).is_equal(30.0)
	assert_float(avisos[0][1]).is_equal(1.0)


func test_el_precio_elegido_sobrevive_al_guardado() -> void:
	var doc: Node = _mundo(2)[0]
	doc.fijar_peonada_eur_hora(24.0)
	var recuperado: Dictionary = JSON.parse_string(JSON.stringify(doc.save()))
	var otro: Node = _mundo(2)[0]
	otro.load_state(recuperado)
	assert_float(otro.peonada_eur_hora).is_equal(24.0)
	assert_float(otro.generosidad_peonada()).is_equal_approx(0.6, 0.001)
