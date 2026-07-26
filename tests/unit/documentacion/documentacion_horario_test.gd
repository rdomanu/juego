# Story documentacion-001 (TR-doc-001) — el servicio, su config y sus fórmulas puras. Tipo: Logic.
# DETERMINISTA: no hay reloj ni RNG; la hora entra como parámetro. Los valores esperados están
# calculados A MANO desde el GDD documentation.md (F1, F3, DO3, DO5, DO8), no copiados del código.
extends GdUnitTestSuite

const DocumentacionScript := preload("res://src/feature/documentacion/documentacion.gd")
const ConfigDocumentacionScript := preload("res://src/feature/documentacion/config_documentacion.gd")


# ── Fixture ──────────────────────────────────────────────────────────────────────────────
## El servicio con los valores que fija la División (08:00–14:30, tope 20:00, margen 15).
func _servicio() -> Node:
	var doc: Node = auto_free(DocumentacionScript.new())
	doc.aplicar_config(ConfigDocumentacionScript.new())
	return doc


# ── AC-DC01 · Los trámites salen del CATÁLOGO, no del código ─────────────────────────────
func test_tramites_del_catalogo_dni_pasaporte_tie() -> void:
	var doc: Node = _servicio()

	# El catálogo real de Pozuelo trae exactamente los tres trámites del GDD (DO1).
	assert_int(doc.tramites().size()).is_equal(3)
	assert_int(doc.tramite(&"dni").duracion_min).is_equal(12)
	assert_int(doc.tramite(&"dni").tarifa_eur).is_equal(12)
	assert_int(doc.tramite(&"pasaporte").duracion_min).is_equal(15)
	assert_int(doc.tramite(&"pasaporte").tarifa_eur).is_equal(30)
	assert_int(doc.tramite(&"tie").duracion_min).is_equal(15)
	assert_int(doc.tramite(&"tie").tarifa_eur).is_equal(18)


func test_tramite_inexistente_devuelve_null_sin_romper() -> void:
	assert_object(_servicio().tramite(&"pasaporte_diplomatico")).is_null()


# ── AC-DC07 · F3: la última admisión ─────────────────────────────────────────────────────
func test_ultima_admision_margen_quince_da_las_catorce_quince() -> void:
	var doc: Node = _servicio()
	# Cierre 870 (14:30) − margen 15 → 855 = 14:15.
	assert_int(doc.hora_ultima_admision()).is_equal(855)


func test_ultima_admision_margen_cero_admite_hasta_el_cierre() -> void:
	var doc: Node = _servicio()
	doc.fijar_margen_ultima_admision(0)
	assert_int(doc.hora_ultima_admision()).is_equal(870)   # exprimir: se da número hasta el cierre


func test_ultima_admision_margen_treinta_es_el_maximo_autorizado() -> void:
	var doc: Node = _servicio()
	doc.fijar_margen_ultima_admision(30)
	assert_int(doc.hora_ultima_admision()).is_equal(840)   # 14:00


func test_margen_fuera_de_rango_se_clampa_con_aviso() -> void:
	var doc: Node = _servicio()
	assert_int(doc.fijar_margen_ultima_admision(45)).is_equal(30)    # tope del rango seguro
	assert_int(doc.fijar_margen_ultima_admision(-10)).is_equal(0)


func test_la_ultima_admision_nunca_cae_antes_de_abrir() -> void:
	# Un margen enorme con una jornada corta no puede cerrar la puerta antes de abrirla.
	var config: Resource = ConfigDocumentacionScript.new()
	config.apertura_base_min = 480
	config.cierre_base_min = 500      # jornada de 20 min (absurda, pero el dato manda)
	config.slider_max_min = 1200
	config.margen_ultima_admision_min = 30
	var doc: Node = auto_free(DocumentacionScript.new())
	doc.aplicar_config(config)
	assert_int(doc.hora_ultima_admision()).is_equal(480)


# ── AC-DC10 · El rango lo fija la División ───────────────────────────────────────────────
func test_sin_evento_el_cierre_se_limita_a_las_veinte() -> void:
	var doc: Node = _servicio()
	# 1290 = 21:30, solo autorizado con evento de la División (story 004) → se limita a 20:00.
	assert_int(doc.fijar_hora_cierre(1290)).is_equal(1200)
	assert_int(doc.hora_cierre_min).is_equal(1200)


func test_no_se_puede_cerrar_antes_de_la_jornada_base() -> void:
	var doc: Node = _servicio()
	assert_int(doc.fijar_hora_cierre(600)).is_equal(870)   # la jornada de mañana no se recorta


func test_un_evento_de_la_division_amplia_el_tope() -> void:
	var doc: Node = _servicio()
	doc.tope_evento_min = 1290                              # lo pondrá la story 004
	assert_int(doc.tope_autorizado()).is_equal(1290)
	assert_int(doc.fijar_hora_cierre(1290)).is_equal(1290)  # 21:30 autorizado


func test_fijar_el_cierre_avisa_por_la_senal() -> void:
	var doc: Node = _servicio()
	# ⚠️ Contador en Array: las lambdas de GDScript capturan los locales por VALOR (footgun del proyecto).
	var recibido: Array = []
	doc.horario_cambiado.connect(
		func(apertura: int, cierre: int, ultima: int) -> void:
			recibido.append([apertura, cierre, ultima])
	)
	doc.fijar_hora_cierre(1080)                 # 18:00
	doc.fijar_hora_cierre(1080)                 # misma hora: NO debe volver a avisar
	assert_int(recibido.size()).is_equal(1)
	assert_array(recibido[0]).contains_exactly([480, 1080, 1065])


# ── F1 (parte pura) · Las horas que cuestan peonada ──────────────────────────────────────
func test_horas_extra_cierre_dieciocho_da_tres_y_media() -> void:
	var doc: Node = _servicio()
	doc.fijar_hora_cierre(1080)                  # 18:00 = 870 + 210 min = 3,5 h
	assert_float(doc.horas_extra()).is_equal_approx(3.5, 0.001)
	assert_bool(doc.hay_horas_extra()).is_true()


func test_jornada_base_no_tiene_horas_extra() -> void:
	var doc: Node = _servicio()
	assert_float(doc.horas_extra()).is_equal(0.0)
	assert_bool(doc.hay_horas_extra()).is_false()


func test_horas_extra_al_tope_son_cinco_y_media() -> void:
	var doc: Node = _servicio()
	doc.fijar_hora_cierre(1200)                  # 20:00 = 870 + 330 min = 5,5 h
	assert_float(doc.horas_extra()).is_equal_approx(5.5, 0.001)


# ── Estado del servicio (DO3 · Cerrado / Abierto / Cerrando) ─────────────────────────────
func test_estado_servicio_por_franjas() -> void:
	var doc: Node = _servicio()             # 08:00–14:30, última admisión 14:15
	assert_str(String(doc.estado_servicio(400.0))).is_equal("cerrado")     # 06:40, aún no abre
	assert_str(String(doc.estado_servicio(480.0))).is_equal("abierto")     # 08:00 en punto: abre
	assert_str(String(doc.estado_servicio(600.0))).is_equal("abierto")     # 10:00
	assert_str(String(doc.estado_servicio(855.0))).is_equal("cerrando")    # 14:15: deja de dar número
	assert_str(String(doc.estado_servicio(869.0))).is_equal("cerrando")
	assert_str(String(doc.estado_servicio(870.0))).is_equal("cerrado")     # 14:30 en punto: cerrado
	assert_str(String(doc.estado_servicio(1300.0))).is_equal("cerrado")    # 21:40


func test_con_margen_cero_no_existe_la_franja_cerrando() -> void:
	var doc: Node = _servicio()
	doc.fijar_margen_ultima_admision(0)
	assert_str(String(doc.estado_servicio(869.0))).is_equal("abierto")     # se admite hasta el final
	assert_bool(doc.admite_a_esa_hora(869.0)).is_true()
	assert_bool(doc.admite_a_esa_hora(870.0)).is_false()


func test_admite_solo_estando_abierto() -> void:
	var doc: Node = _servicio()
	assert_bool(doc.admite_a_esa_hora(600.0)).is_true()
	assert_bool(doc.admite_a_esa_hora(856.0)).is_false()   # cerrando: se atiende, pero ya no se admite
	assert_bool(doc.admite_a_esa_hora(300.0)).is_false()


func test_la_hora_acumulada_del_reloj_se_normaliza_al_dia() -> void:
	# El reloj del juego acumula minutos sin parar: el día 3 a las 10:00 son 4.920 min.
	var doc: Node = _servicio()
	assert_str(String(doc.estado_servicio(4920.0))).is_equal("abierto")


# ── Config: un `.tres` roto se corrige, no rompe el servicio ─────────────────────────────
func test_config_fuera_de_rango_se_clampa_con_aviso() -> void:
	var config: Resource = ConfigDocumentacionScript.new()
	config.apertura_base_min = 480
	config.cierre_base_min = 400        # cierra ANTES de abrir (imposible)
	config.slider_min_min = 900         # por encima de la apertura (viola la restricción del GDD)
	config.slider_max_min = 400         # por debajo del cierre base ya saneado (481)
	config.margen_ultima_admision_min = 99
	var doc: Node = auto_free(DocumentacionScript.new())
	doc.aplicar_config(config)

	assert_int(doc.cierre_base_min).is_equal(481)              # cierre SIEMPRE tras la apertura
	assert_int(doc.slider_min_min).is_equal(480)               # slider_min ≤ apertura_base
	assert_int(doc.slider_max_min).is_equal(481)               # slider_max ≥ cierre_base
	assert_int(doc.margen_ultima_admision_min).is_equal(30)
	assert_int(doc.hora_cierre_min).is_equal(481)              # arranca en el cierre base saneado


func test_config_nula_usa_los_valores_de_la_division() -> void:
	var doc: Node = auto_free(DocumentacionScript.new())
	doc.aplicar_config(null)
	assert_int(doc.apertura_base_min).is_equal(480)
	assert_int(doc.cierre_base_min).is_equal(870)
	assert_int(doc.hora_cierre_min).is_equal(870)


func test_peonada_activa_por_defecto_arranca_el_dia_ampliado() -> void:
	var config: Resource = ConfigDocumentacionScript.new()
	config.peonada_activa_por_defecto = true
	var doc: Node = auto_free(DocumentacionScript.new())
	doc.aplicar_config(config)
	assert_int(doc.hora_cierre_min).is_equal(1200)             # abre ya con la tarde pagada
	assert_float(doc.horas_extra()).is_equal_approx(5.5, 0.001)


# ── DO8 · El MVP va SIN cita ─────────────────────────────────────────────────────────────
func test_el_mvp_va_sin_cita_para_los_tres_tramites() -> void:
	var doc: Node = _servicio()
	assert_bool(doc.requiere_cita(&"dni")).is_false()
	assert_bool(doc.requiere_cita(&"pasaporte")).is_false()
	assert_bool(doc.requiere_cita(&"tie")).is_false()
	assert_bool(doc.CITA_ACTIVA).is_false()
