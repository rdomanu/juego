# Story documentacion-002 (TR-doc-001) — LA MUDANZA: el horario deja de vivir prestado en Flujo.
# Tipo: Integration. Documentación DECIDE; Flujo EJECUTA (abre/cierra puestos y da número) y Demanda
# RESPETA (no fabrica gente fuera de la ventana). El cableado replica el de Main: la señal
# `horario_cambiado` es el ÚNICO camino por el que ese dato viaja.
# DETERMINISTA: ticks manuales de 1 min, reloj inyectado sin árbol, catálogo y Personal REALES.
extends GdUnitTestSuite

const DocumentacionScript := preload("res://src/feature/documentacion/documentacion.gd")
const ConfigDocumentacionScript := preload("res://src/feature/documentacion/config_documentacion.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const DemandaScript := preload("res://src/core/demanda/demanda.gd")
const ConfigDemandaScript := preload("res://src/core/demanda/config_demanda.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")

const DOC := &"Documentacion"


# ── Fixture: el mundo cableado como en Main ──────────────────────────────────────────────
## Devuelve [documentacion, flujo, demanda, tiempo] con doc_1 dotado y el reloj a `min_dia`.
func _mundo(min_dia: float) -> Array:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.velocidad_camino_celdas_min = 0.0   # aísla la variable del horario (camino instantáneo)
	flujo.usar_personal(personal)
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")
	var agente: RefCounted = AgenteScript.new("Ana Ruiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)
	personal.plantilla.append(agente)
	personal.asignar(agente, &"doc_1")
	var tiempo: Node = auto_free(TiempoScript.new())   # SIN árbol: no empuja, solo da la hora
	tiempo.minutos_juego = min_dia
	flujo.usar_tiempo(tiempo)
	var demanda: Node = auto_free(DemandaScript.new())
	demanda.aplicar_config(ConfigDemandaScript.new())
	demanda.fijar_poblacion(90000)
	var doc: Node = auto_free(DocumentacionScript.new())
	doc.aplicar_config(ConfigDocumentacionScript.new())
	# El cableado de Main: el horario viaja por la señal y por ningún otro sitio.
	doc.horario_cambiado.connect(
		func(apertura: int, cierre: int, ultima: int) -> void:
			flujo.fijar_horario_doc(apertura, cierre, ultima)
			demanda.fijar_ventana_doc(apertura, ultima)
	)
	doc.refrescar_horario()   # empuje inicial (Main lo hace al terminar de instanciar el mundo)
	return [doc, flujo, demanda, tiempo]


func _dni(minuto: float) -> RefCounted:
	return PersonaScript.new(DOC, &"dni", minuto)


# ── AC-DC02 · Fuera de horario no hay servicio ───────────────────────────────────────────
func test_a_las_quince_no_se_admite_ni_se_genera_documentacion() -> void:
	var mundo: Array = _mundo(900.0)          # 15:00
	var flujo: Node = mundo[1]
	var demanda: Node = mundo[2]

	# La puerta de Flujo no da número y Demanda no fabrica a nadie de Doc a esa hora.
	assert_bool(flujo.puerta_doc_abierta()).is_false()
	assert_object(flujo.admitir(_dni(900.0))).is_null()
	assert_float(demanda.llegadas_esperadas_hora(900.0, DOC)).is_equal_approx(0.0, 0.0001)


func test_el_puesto_de_doc_se_cierra_solo_al_pasar_la_hora() -> void:
	var mundo: Array = _mundo(600.0)          # 10:00, en horario
	var flujo: Node = mundo[1]
	var tiempo: Node = mundo[3]
	flujo._al_tick(1.0)
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("libre")

	tiempo.minutos_juego = 900.0              # 15:00: los funcionarios se van
	flujo._al_tick(1.0)
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("cerrado")


# ── AC-DC03 · El cierre ampliado manda (Flujo y Demanda obedecen) ────────────────────────
func test_ampliar_a_las_dieciocho_mantiene_el_servicio_abierto() -> void:
	var mundo: Array = _mundo(600.0)
	var doc: Node = mundo[0]
	var flujo: Node = mundo[1]
	var demanda: Node = mundo[2]
	var tiempo: Node = mundo[3]

	doc.fijar_hora_cierre(1080)               # 18:00 — la orden del jugador
	# Los tres sistemas hablan del mismo horario, sin que nadie haya tocado a nadie por dentro.
	assert_int(flujo.cierre_doc_min).is_equal(1080)
	assert_int(flujo.ultima_admision_doc_min).is_equal(1065)     # 17:45 (margen 15)
	assert_int(demanda.ventana_doc_fin_min).is_equal(1065)

	tiempo.minutos_juego = 960.0              # 16:00: antes de la mudanza aquí ya estaba cerrado
	flujo._al_tick(1.0)
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("libre")
	assert_bool(flujo.puerta_doc_abierta()).is_true()
	assert_object(flujo.admitir(_dni(960.0))).is_not_null()


func test_al_volver_al_horario_base_el_servicio_vuelve_a_cerrar_pronto() -> void:
	var mundo: Array = _mundo(960.0)          # 16:00
	var doc: Node = mundo[0]
	var flujo: Node = mundo[1]
	doc.fijar_hora_cierre(1080)
	assert_bool(flujo.puerta_doc_abierta()).is_true()

	doc.fijar_hora_cierre(870)                # el jugador se echa atrás: jornada base
	assert_bool(flujo.puerta_doc_abierta()).is_false()
	assert_int(flujo.cierre_doc_min).is_equal(870)


# ── La última admisión, aplicada de verdad (F3 · DO5) ────────────────────────────────────
func test_pasada_la_ultima_admision_no_se_da_numero_pero_se_termina_lo_admitido() -> void:
	var mundo: Array = _mundo(850.0)          # 14:10 — aún se da número (última admisión 14:15)
	var flujo: Node = mundo[1]
	var tiempo: Node = mundo[3]
	var admitido: RefCounted = flujo.admitir(_dni(850.0))
	assert_object(admitido).is_not_null()
	flujo.encolar(admitido)
	flujo._al_tick(1.0)                        # lo llama y arranca la atención (dni = 12 min)

	tiempo.minutos_juego = 856.0              # 14:16 — la puerta ya no da número...
	assert_bool(flujo.puerta_doc_abierta()).is_false()
	assert_object(flujo.admitir(_dni(856.0))).is_null()
	# ...pero al que ya tenía número se le termina (compromiso de servicio), aunque pase del cierre.
	# 12 ticks: el tick del emparejamiento arranca la atención pero NO descuenta (orden del tick).
	for i: int in range(12):
		flujo._al_tick(1.0)
	assert_str(String(admitido.estado)).is_equal("resuelta")


func test_con_margen_cero_se_admite_hasta_el_cierre() -> void:
	var mundo: Array = _mundo(865.0)          # 14:25
	var doc: Node = mundo[0]
	var flujo: Node = mundo[1]
	assert_object(flujo.admitir(_dni(865.0))).is_null()          # margen 15 → puerta cerrada

	doc.fijar_margen_ultima_admision(0)                          # exprimir hasta el final
	assert_int(flujo.ultima_admision_doc_min).is_equal(870)
	assert_object(flujo.admitir(_dni(865.0))).is_not_null()


func test_antes_de_abrir_tampoco_se_da_numero() -> void:
	# Agujero que la mudanza cierra: antes, la puerta solo miraba el cierre — a las 03:00 admitía.
	var mundo: Array = _mundo(180.0)          # 03:00
	assert_bool(mundo[1].puerta_doc_abierta()).is_false()


# ── AC-DC13 · Sin agente no se atiende (sigue valiendo tras la mudanza, FL4) ─────────────
func test_puesto_sin_agente_no_atiende_aunque_este_en_horario() -> void:
	var mundo: Array = _mundo(600.0)
	var flujo: Node = mundo[1]
	flujo.registrar_puesto_flujo(&"doc_2", &"puesto_doc_general")   # registrado pero SIN dotar
	var persona: RefCounted = flujo.admitir(_dni(600.0))
	flujo.encolar(persona)
	assert_str(String(flujo.estado_de_puesto(&"doc_2"))).is_equal("abierto_sin_agente")


# ── Fuente única: el horario ya no vive en las configs de Flujo ni de Demanda ────────────
func test_el_horario_ya_no_es_un_knob_de_flujo_ni_de_demanda() -> void:
	var config_flujo: Resource = ConfigFlujoScript.new()
	var config_demanda: Resource = ConfigDemandaScript.new()
	var propiedades_flujo: PackedStringArray = []
	for propiedad: Dictionary in config_flujo.get_property_list():
		propiedades_flujo.append(propiedad["name"])
	var propiedades_demanda: PackedStringArray = []
	for propiedad: Dictionary in config_demanda.get_property_list():
		propiedades_demanda.append(propiedad["name"])

	assert_bool("cierre_doc_min" in propiedades_flujo).is_false()
	assert_bool("apertura_doc_min" in propiedades_flujo).is_false()
	assert_bool("ventana_doc_inicio_min" in propiedades_demanda).is_false()
	assert_bool("ventana_doc_fin_min" in propiedades_demanda).is_false()


func test_sin_documentacion_cableada_flujo_se_comporta_como_antes_de_la_mudanza() -> void:
	# La razón de que los tests viejos sigan siendo red de seguridad: los defaults son el horario base.
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	assert_int(flujo.apertura_doc_min).is_equal(480)
	assert_int(flujo.cierre_doc_min).is_equal(870)
	assert_int(flujo.ultima_admision_doc_min).is_equal(870)   # sin margen: como antes


func test_un_horario_imposible_se_sanea_en_flujo() -> void:
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.fijar_horario_doc(600, 300, 900)     # cierra antes de abrir y admite después de cerrar
	assert_int(flujo.apertura_doc_min).is_equal(600)
	assert_int(flujo.cierre_doc_min).is_equal(601)
	assert_int(flujo.ultima_admision_doc_min).is_equal(601)
