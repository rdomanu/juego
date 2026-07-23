# Story 001 (epic demanda) — núcleo: config data-driven y fórmulas de volumen F1/F2 · TR-demand-001 ·
# ADR-0003/0001. Tipo: Logic. DETERMINISTA (sin azar, sin reloj; población inyectada; solo dos tests
# tocan el catálogo/.tres reales para verificar el cableado data-driven).
# Aislamiento: nodo con .new() sin árbol (no corre _ready → no carga el .tres real salvo donde se quiere).
extends GdUnitTestSuite

const DemandaScript := preload("res://src/core/demanda/demanda.gd")
const ConfigDemandaScript := preload("res://src/core/demanda/config_demanda.gd")

const DOC := &"Documentacion"
const ODAC := &"ODAC"


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Demanda fresca con config default aplicado y población de Pozuelo inyectada (sin catálogo).
func _demanda(poblacion: int = 90000) -> Node:
	var demanda: Node = auto_free(DemandaScript.new())
	demanda.aplicar_config(ConfigDemandaScript.new())
	demanda.fijar_poblacion(poblacion)
	return demanda


# ── AC-DM01: F1 — 90.000 hab × 0.5/1000 = 45 trámites/día de Documentación ────────────────
func test_demanda_dia_doc_es_45() -> void:
	# Arrange
	var demanda: Node = _demanda()

	# Act / Assert
	assert_float(demanda.demanda_dia(DOC)).is_equal_approx(45.0, 0.0001)


# ── AC-DM02: F1 — ODAC 0.4/1000 = 36 denuncias/día (< Documentación) ──────────────────────
func test_demanda_dia_odac_es_36_y_menor_que_doc() -> void:
	# Arrange
	var demanda: Node = _demanda()

	# Act
	var dia_odac: float = demanda.demanda_dia(ODAC)

	# Assert
	assert_float(dia_odac).is_equal_approx(36.0, 0.0001)
	assert_bool(dia_odac < demanda.demanda_dia(DOC)).is_true()


# ── AC-DM03a: el perfil de Documentación es una distribución (Σ pesos = 1.0) ──────────────
func test_perfil_doc_suma_1() -> void:
	# Arrange
	var demanda: Node = _demanda()

	# Act
	var suma: float = 0.0
	for peso: float in demanda.perfil_hora_doc.values():
		suma += peso

	# Assert
	assert_float(suma).is_equal_approx(1.0, 0.0001)


# ── AC-DM03b: F2 — pico de apertura (peso 0.30) con jornada cargada ×1.3 ≈ 17,6 llegadas ──
func test_pico_apertura_con_jornada_cargada_es_17_6() -> void:
	# Arrange — config con la jornada al ×1.3 del ejemplo del GDD.
	var config: Resource = ConfigDemandaScript.new()
	config.mult_dia_semana = 1.3
	var demanda: Node = auto_free(DemandaScript.new())
	demanda.aplicar_config(config)
	demanda.fijar_poblacion(90000)

	# Act — 08:30 (minuto 510, dentro de la franja pico 08-09).
	var llegadas: float = demanda.llegadas_esperadas_hora(510.0, DOC)

	# Assert — 45 × 0.30 × 1.3 = 17.55.
	assert_float(llegadas).is_equal_approx(17.55, 0.01)


# ── AC-DM04: el valle nocturno ODAC es DERIVADO de config (36 × 7/24 × 0.5 = 5.25), no un
# número fijo. (Errata GDD anotada en la story: el "≈10" viene del ancla vieja.) ───────────
func test_valle_nocturno_odac_derivado_de_config() -> void:
	# Arrange
	var demanda: Node = _demanda()

	# Act — sumar las llegadas esperadas de las 7 franjas del valle (00:00–07:00).
	var total_valle: float = 0.0
	for hora: int in range(7):
		total_valle += demanda.llegadas_esperadas_hora(float(hora * 60), ODAC)

	# Assert — 36/día × (7/24 uniforme) × mult 0.5 = 5.25.
	assert_float(total_valle).is_equal_approx(5.25, 0.01)

	# Edge — sin valle (mult 1.0) la misma franja da 10.5 (el knob ES el valle).
	demanda.mult_nocturno_odac = 1.0
	var total_sin_valle: float = 0.0
	for hora: int in range(7):
		total_sin_valle += demanda.llegadas_esperadas_hora(float(hora * 60), ODAC)
	assert_float(total_sin_valle).is_equal_approx(10.5, 0.01)


# ── AC-DM04/AC-DM20: con el doble de población, el valle escala proporcional (sin hardcode) ─
func test_valle_nocturno_escala_con_poblacion() -> void:
	# Arrange — municipio del doble de habitantes.
	var demanda: Node = _demanda(180000)

	# Act
	var total_valle: float = 0.0
	for hora: int in range(7):
		total_valle += demanda.llegadas_esperadas_hora(float(hora * 60), ODAC)

	# Assert — el doble exacto de 5.25.
	assert_float(total_valle).is_equal_approx(10.5, 0.01)


# ── AC-DM12: calibración R5 — la demanda semilla queda MUY por debajo de la capacidad máxima
# construible (Doc 260/día, ODAC 128/día — topes del GDD F5; el guardián en carga es Datos). ─
func test_r5_semillas_bajo_capacidad_maxima() -> void:
	# Arrange
	var demanda: Node = _demanda()

	# Act / Assert — los literales SON el punto (boundary values del GDD F5).
	assert_bool(demanda.demanda_dia(DOC) <= 260.0).is_true()
	assert_bool(demanda.demanda_dia(ODAC) <= 128.0).is_true()


# ── AC-DM13: DG8 — factor de crecimiento ×1.5 sube la tasa efectiva y el volumen ──────────
func test_factor_crecimiento_sube_tasa() -> void:
	# Arrange
	var config: Resource = ConfigDemandaScript.new()
	config.factor_crecimiento_nivel = 1.5
	var demanda: Node = auto_free(DemandaScript.new())
	demanda.aplicar_config(config)
	demanda.fijar_poblacion(90000)

	# Act / Assert — tasa 0.5 × 1.5 = 0.75 → 67.5/día.
	assert_float(demanda.tasa_efectiva(DOC)).is_equal_approx(0.75, 0.0001)
	assert_float(demanda.demanda_dia(DOC)).is_equal_approx(67.5, 0.0001)


# ── AC-DM19: tasa 0 = grifo cerrado (config válida, sin error) ────────────────────────────
func test_grifo_cerrado_con_tasa_cero() -> void:
	# Arrange
	var config: Resource = ConfigDemandaScript.new()
	config.tasa_base_doc = 0.0
	var demanda: Node = auto_free(DemandaScript.new())
	demanda.aplicar_config(config)
	demanda.fijar_poblacion(90000)

	# Act / Assert — ni volumen ni densidad en el pico.
	assert_float(demanda.demanda_dia(DOC)).is_equal_approx(0.0, 0.0001)
	assert_float(demanda.densidad_por_minuto(510.0, DOC)).is_equal_approx(0.0, 0.0001)


# ── AC-DM19: población 0 = grifo cerrado para TODOS los servicios ─────────────────────────
func test_grifo_cerrado_con_poblacion_cero() -> void:
	# Arrange
	var demanda: Node = _demanda(0)

	# Act / Assert
	assert_float(demanda.demanda_dia(DOC)).is_equal_approx(0.0, 0.0001)
	assert_float(demanda.demanda_dia(ODAC)).is_equal_approx(0.0, 0.0001)


# ── AC-DM20 (petición del usuario 2026-07-23): otra población → escala proporcional exacta ─
func test_proporcionalidad_con_poblacion_30000() -> void:
	# Arrange — un tercio de Pozuelo.
	var demanda: Node = _demanda(30000)

	# Act / Assert — 45/3 = 15 y 36/3 = 12.
	assert_float(demanda.demanda_dia(DOC)).is_equal_approx(15.0, 0.0001)
	assert_float(demanda.demanda_dia(ODAC)).is_equal_approx(12.0, 0.0001)


# ── DG6: fuera de la ventana [08:00, 14:30) Documentación no espera llegadas; ODAC sí ─────
func test_ventana_doc_fuera_devuelve_cero() -> void:
	# Arrange
	var demanda: Node = _demanda()

	# Act / Assert — 15:00 y 07:59 fuera; 14:29 dentro; ODAC genera a las 15:00.
	assert_float(demanda.llegadas_esperadas_hora(900.0, DOC)).is_equal_approx(0.0, 0.0001)
	assert_float(demanda.llegadas_esperadas_hora(479.0, DOC)).is_equal_approx(0.0, 0.0001)
	assert_bool(demanda.llegadas_esperadas_hora(869.0, DOC) > 0.0).is_true()
	assert_bool(demanda.llegadas_esperadas_hora(900.0, ODAC) > 0.0).is_true()


# ── F2: la densidad por minuto respeta la duración real de la franja (la 14 dura 30 min) ──
func test_densidad_franja_del_cierre_dura_30_min() -> void:
	# Arrange
	var demanda: Node = _demanda()

	# Act / Assert — franja 08-09 (60 min): 45×0.30/60 = 0.225/min; franja 14:00-14:30
	# (30 min): 45×0.03/30 = 0.045/min (con 60 min saldría la mitad: perdería demanda).
	assert_float(demanda.densidad_por_minuto(510.0, DOC)).is_equal_approx(0.225, 0.0001)
	assert_float(demanda.densidad_por_minuto(865.0, DOC)).is_equal_approx(0.045, 0.0001)


# ── AC-DM20: la población viene del Escenario del catálogo REAL (cero hardcode en src/) ───
func test_fijar_escenario_lee_poblacion_del_catalogo() -> void:
	# Arrange — nodo limpio SIN población inyectada.
	var demanda: Node = auto_free(DemandaScript.new())
	demanda.aplicar_config(ConfigDemandaScript.new())

	# Act — escenario real del catálogo (autoload Datos de la suite).
	demanda.fijar_escenario(&"pozuelo")

	# Assert — la población del .tres de Pozuelo alimenta F1.
	assert_int(demanda.poblacion()).is_equal(90000)
	assert_float(demanda.demanda_dia(DOC)).is_equal_approx(45.0, 0.0001)


# ── F3 (preparación story 002): las mezclas suman 1.0 y TODOS sus ids existen en el catálogo ─
func test_mezclas_suman_1_y_apuntan_a_ids_reales() -> void:
	# Arrange
	var demanda: Node = _demanda()

	# Act
	var suma_doc: float = 0.0
	for id_tramite: StringName in demanda.mezcla_doc:
		suma_doc += demanda.mezcla_doc[id_tramite]
		assert_object(Datos.obtener(&"TramiteDoc", id_tramite)).is_not_null()
	var suma_odac: float = 0.0
	for id_denuncia: StringName in demanda.mezcla_odac:
		suma_odac += demanda.mezcla_odac[id_denuncia]
		assert_object(Datos.obtener(&"DenunciaODAC", id_denuncia)).is_not_null()

	# Assert — Σ=1.0 por servicio y los 13 tipos de ODAC de F3 (sin `reclamacion`).
	assert_float(suma_doc).is_equal_approx(1.0, 0.0001)
	assert_float(suma_odac).is_equal_approx(1.0, 0.0001)
	assert_int(demanda.mezcla_odac.size()).is_equal(13)


# ── Clamp: knobs corruptos se sanean con aviso, sin romper ────────────────────────────────
func test_config_fuera_de_rango_clampa_con_aviso() -> void:
	# Arrange — tasa negativa y ventana imposible (los push_warning esperados son intencionales).
	var config: Resource = ConfigDemandaScript.new()
	config.tasa_base_doc = -1.0
	config.ventana_doc_inicio_min = 900
	config.ventana_doc_fin_min = 480
	var demanda: Node = auto_free(DemandaScript.new())

	# Act
	demanda.aplicar_config(config)

	# Assert — tasa a 0; ventana al default [480, 870).
	assert_float(demanda.tasa_base_doc).is_equal_approx(0.0, 0.0001)
	assert_int(demanda.ventana_doc_inicio_min).is_equal(480)
	assert_int(demanda.ventana_doc_fin_min).is_equal(870)


# ── Data-driven: el .tres real existe y trae las semillas del GDD ─────────────────────────
func test_tres_real_existe_y_carga_semillas() -> void:
	# Arrange / Act — cargar el recurso real generado por la herramienta.
	var config: Resource = load("res://datos/config/demanda.tres")

	# Assert — existe, es del tipo correcto y trae las semillas exactas.
	assert_object(config).is_not_null()
	assert_bool(config is ConfigDemandaScript).is_true()
	assert_float(config.tasa_base_doc).is_equal_approx(0.5, 0.0001)
	assert_float(config.tasa_base_odac).is_equal_approx(0.4, 0.0001)
	assert_float(config.mult_nocturno_odac).is_equal_approx(0.5, 0.0001)
	assert_int(config.perfil_hora_doc.size()).is_equal(7)
	assert_int(config.perfil_hora_odac.size()).is_equal(24)
	assert_int(config.max_llegadas_por_tick).is_equal(3)
	assert_int(config.ventana_doc_inicio_min).is_equal(480)
	assert_int(config.ventana_doc_fin_min).is_equal(870)
	assert_float(config.umbral_nivel_bajo).is_equal_approx(40.0, 0.0001)
	assert_float(config.umbral_nivel_alto).is_equal_approx(60.0, 0.0001)
	assert_float(config.mult_estacional[6]).is_equal_approx(1.5, 0.0001)
	assert_float(config.mult_estacional[1]).is_equal_approx(0.6, 0.0001)
	assert_int(config.eventos.size()).is_equal(1)
	assert_str(String(config.eventos[0]["id"])).is_equal("vacaciones")
