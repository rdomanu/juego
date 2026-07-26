# Story documentacion-004 (TR-doc-002 + TR-doc-001) — los comunicados de la División y el guardado
# del servicio. Tipo: Integration. DETERMINISTA: los eventos se activan por MES (sin RNG), reloj
# inyectado sin árbol, catálogo REAL (`datos/eventos/`).
extends GdUnitTestSuite

const DocumentacionScript := preload("res://src/feature/documentacion/documentacion.gd")
const ConfigDocumentacionScript := preload("res://src/feature/documentacion/config_documentacion.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")


# ── Fixture ──────────────────────────────────────────────────────────────────────────────
## Documentación con reloj y bus reales (sin árbol) en el mes `mes`. Devuelve [doc, tiempo, bus].
func _servicio(mes: int = 1) -> Array:
	var tiempo: Node = auto_free(TiempoScript.new())
	tiempo.mes = mes
	tiempo.minutos_juego = 600.0
	var bus: Node = auto_free(EventBusScript.new())
	var doc: Node = auto_free(DocumentacionScript.new())
	doc.usar_tiempo(tiempo)
	doc.usar_bus(bus)
	doc.aplicar_config(ConfigDocumentacionScript.new())
	doc.revisar_eventos()
	return [doc, tiempo, bus]


# ── AC-DC09 · La División AUTORIZA, no obliga ────────────────────────────────────────────
func test_en_vacaciones_se_autoriza_cerrar_a_las_veintiuna_treinta() -> void:
	var doc: Node = _servicio(7)[0]                # julio: periodo vacacional

	assert_str(String(doc.evento_activo_id)).is_equal("vacaciones")
	assert_int(doc.tope_autorizado()).is_equal(1290)          # 21:30
	# ...pero el horario NO se amplía solo: el jugador decide (y paga la peonada).
	assert_int(doc.hora_cierre_min).is_equal(870)
	assert_int(doc.fijar_hora_cierre(1290)).is_equal(1290)


func test_el_colapso_de_extranjeria_destaca_el_tie() -> void:
	var doc: Node = _servicio(2)[0]                # febrero
	assert_str(String(doc.evento_activo_id)).is_equal("colapso_extranjeria")
	assert_str(String(doc.evento_activo().tramite_destacado)).is_equal("tie")


func test_un_mes_sin_comunicado_deja_el_tope_ordinario() -> void:
	var doc: Node = _servicio(5)[0]                # mayo: sin evento
	assert_str(String(doc.evento_activo_id)).is_equal("")
	assert_object(doc.evento_activo()).is_null()
	assert_int(doc.tope_autorizado()).is_equal(1200)          # 20:00
	assert_int(doc.fijar_hora_cierre(1290)).is_equal(1200)


# ── AC-DC10 · Al acabar el evento se recoge la ampliación ────────────────────────────────
func test_al_terminar_el_evento_el_cierre_vuelve_al_tope_ordinario() -> void:
	var mundo: Array = _servicio(8)                # agosto: vacaciones
	var doc: Node = mundo[0]
	var tiempo: Node = mundo[1]
	doc.fijar_hora_cierre(1290)                    # el jugador aprovecha y cierra a las 21:30

	tiempo.mes = 9                                 # septiembre: se acabó lo que se daba
	doc._al_nuevo_mes()

	assert_str(String(doc.evento_activo_id)).is_equal("")
	assert_int(doc.tope_autorizado()).is_equal(1200)
	assert_int(doc.hora_cierre_min).is_equal(1200)            # el horario se recoge solo


func test_un_cierre_por_debajo_del_tope_no_se_toca_al_acabar_el_evento() -> void:
	var mundo: Array = _servicio(7)
	var doc: Node = mundo[0]
	doc.fijar_hora_cierre(1080)                    # 18:00, dentro del tope ordinario

	mundo[1].mes = 9
	doc._al_nuevo_mes()

	assert_int(doc.hora_cierre_min).is_equal(1080)


# ── El aviso sale UNA vez, no en cada tick ───────────────────────────────────────────────
func test_el_comunicado_se_anuncia_una_sola_vez_al_activarse_y_al_apagarse() -> void:
	# ⚠️ Contador en Array: las lambdas de GDScript capturan los locales por VALOR.
	var mundo: Array = _servicio(5)                # arranca sin evento
	var doc: Node = mundo[0]
	var tiempo: Node = mundo[1]
	var avisos: Array = []
	mundo[2].aviso_division.connect(
		func(id: StringName, _nombre: String, activo: bool) -> void:
			avisos.append([String(id), activo])
	)

	tiempo.mes = 7
	for i: int in range(10):                       # el mes entero, revisando una y otra vez
		doc.revisar_eventos()
	assert_int(avisos.size()).is_equal(1)
	assert_array(avisos[0]).contains_exactly(["vacaciones", true])

	tiempo.mes = 9
	for i: int in range(10):
		doc.revisar_eventos()
	assert_int(avisos.size()).is_equal(2)
	assert_array(avisos[1]).contains_exactly(["vacaciones", false])


func test_encadenar_dos_eventos_avisa_del_apagado_y_del_nuevo() -> void:
	var mundo: Array = _servicio(8)                # vacaciones
	var doc: Node = mundo[0]
	var avisos: Array = []
	mundo[2].aviso_division.connect(
		func(id: StringName, _nombre: String, activo: bool) -> void:
			avisos.append([String(id), activo])
	)

	mundo[1].mes = 2                               # salta directo a febrero (extranjería)
	doc._al_nuevo_mes()

	assert_int(avisos.size()).is_equal(2)
	assert_array(avisos[0]).contains_exactly(["vacaciones", false])
	assert_array(avisos[1]).contains_exactly(["colapso_extranjeria", true])


# ── AC-DC16 · El save recuerda el servicio ───────────────────────────────────────────────
func test_el_horario_y_el_evento_sobreviven_al_guardado() -> void:
	var mundo: Array = _servicio(7)
	var doc: Node = mundo[0]
	doc.fijar_hora_cierre(1290)
	doc.fijar_margen_ultima_admision(5)

	# Round-trip REAL por JSON (así viaja el save de verdad — ADR-0002).
	var json: String = JSON.stringify(doc.save())
	var recuperado: Dictionary = JSON.parse_string(json)
	var otro: Array = _servicio(7)
	var doc2: Node = otro[0]
	doc2.load_state(recuperado)

	assert_int(doc2.hora_cierre_min).is_equal(1290)
	assert_int(doc2.margen_ultima_admision_min).is_equal(5)
	assert_str(String(doc2.evento_activo_id)).is_equal("vacaciones")
	assert_int(doc2.hora_ultima_admision()).is_equal(1285)


func test_al_cargar_se_vuelve_a_empujar_el_horario_a_quien_lo_ejecuta() -> void:
	# Flujo arranca con sus defaults; si el load no reemitiera, la partida cargada abriría con el
	# horario base aunque el jugador hubiera guardado con la tarde ampliada.
	var mundo: Array = _servicio(7)
	var doc: Node = mundo[0]
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	doc.horario_cambiado.connect(
		func(apertura: int, cierre: int, ultima: int) -> void:
			flujo.fijar_horario_doc(apertura, cierre, ultima)
	)
	assert_int(flujo.cierre_doc_min).is_equal(870)

	doc.load_state({"hora_cierre_min": 1080, "margen_ultima_admision_min": 15, "evento_activo_id": ""})

	assert_int(flujo.cierre_doc_min).is_equal(1080)
	assert_int(flujo.ultima_admision_doc_min).is_equal(1065)


func test_un_save_manipulado_se_sanea_igual_que_en_partida() -> void:
	var doc: Node = _servicio(5)[0]                # sin evento: tope 20:00
	doc.load_state({
		"hora_cierre_min": 1400,                   # 23:20 — nadie ha autorizado eso
		"margen_ultima_admision_min": -5,
		"evento_activo_id": "fiesta_mayor",        # evento que no existe en el catálogo
	})
	assert_int(doc.hora_cierre_min).is_equal(1200)
	assert_int(doc.margen_ultima_admision_min).is_equal(0)
	assert_str(String(doc.evento_activo_id)).is_equal("")


func test_un_save_viejo_sin_las_claves_carga_con_los_valores_del_catalogo() -> void:
	var doc: Node = _servicio(5)[0]
	doc.fijar_hora_cierre(1080)
	doc.load_state({})
	assert_int(doc.hora_cierre_min).is_equal(870)
	assert_int(doc.margen_ultima_admision_min).is_equal(15)


# ── AC-DC11 · El MVP va sin cita ─────────────────────────────────────────────────────────
func test_ningun_tramite_del_catalogo_exige_cita_en_el_mvp() -> void:
	var doc: Node = _servicio(1)[0]
	for tramite: Resource in doc.tramites():
		assert_bool(doc.requiere_cita(tramite.id)).is_false()


# ── El catálogo de eventos existe y es coherente ─────────────────────────────────────────
func test_el_catalogo_trae_los_dos_eventos_del_mvp() -> void:
	var doc: Node = _servicio(1)[0]
	assert_object(doc.evento_de(&"vacaciones")).is_not_null()
	assert_object(doc.evento_de(&"colapso_extranjeria")).is_not_null()
	assert_array(doc.evento_de(&"vacaciones").meses).contains_exactly([7, 8])
	assert_int(doc.evento_de(&"colapso_extranjeria").cierre_max_min).is_equal(1290)
	# El trámite que destaca cada comunicado existe de verdad en el catálogo (integridad referencial).
	for id: StringName in [&"vacaciones", &"colapso_extranjeria"]:
		assert_object(doc.tramite(doc.evento_de(id).tramite_destacado)).is_not_null()
