# Story bien-001 (Bienestar #13) — la barra de cansancio y el patrón de descanso de cada uno.
# Tipo: Logic. DETERMINISTA: matemática pura, sin reloj y SIN AZAR — el patrón sale de la motivación
# del agente a propósito (así el mismo funcionario se comporta igual siempre y se le puede aprender).
extends GdUnitTestSuite

const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")


# ── Fixture ──────────────────────────────────────────────────────────────────────────────
func _personal() -> Node:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	return personal


## Un agente con la motivación pedida (el resto de atributos, estándar).
func _agente(motivacion: int) -> RefCounted:
	return AgenteScript.new(
		"Agente %d" % motivacion, &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, motivacion
	)


# ── AC-BI02 · El patrón sale de la MOTIVACIÓN ────────────────────────────────────────────
func test_el_cumplidor_parte_su_descanso_en_dos() -> void:
	var personal: Node = _personal()
	var agente: RefCounted = _agente(5)
	assert_str(String(personal.patron_de(agente))).is_equal("dos_cafes")
	assert_int(personal.pausas_de(agente)).is_equal(2)
	assert_int(personal.minutos_de_pausa(agente)).is_equal(15)


func test_lo_normal_es_la_media_hora_de_un_tiron() -> void:
	var personal: Node = _personal()
	for motivacion: int in [3, 4]:
		var agente: RefCounted = _agente(motivacion)
		assert_str(String(personal.patron_de(agente))).is_equal("un_cafe")
		assert_int(personal.pausas_de(agente)).is_equal(1)
		assert_int(personal.minutos_de_pausa(agente)).is_equal(30)


func test_el_caradura_se_toma_una_hora() -> void:
	var personal: Node = _personal()
	for motivacion: int in [1, 2]:
		var agente: RefCounted = _agente(motivacion)
		assert_str(String(personal.patron_de(agente))).is_equal("caradura")
		assert_int(personal.pausas_de(agente)).is_equal(1)
		assert_int(personal.minutos_de_pausa(agente)).is_equal(60)   # el doble de lo que puede


func test_desmotivar_a_un_cumplidor_lo_convierte_en_caradura() -> void:
	# El bucle con Documentación #8: exprimir el cierre baja la motivación (−1 por día), y con ella
	# el funcionario ejemplar acaba tomándose una hora de café. Exprimir sale caro dos veces.
	var personal: Node = _personal()
	var agente: RefCounted = _agente(5)
	assert_str(String(personal.patron_de(agente))).is_equal("dos_cafes")
	agente.motivacion = 3
	assert_str(String(personal.patron_de(agente))).is_equal("un_cafe")
	agente.motivacion = 2
	assert_str(String(personal.patron_de(agente))).is_equal("caradura")


# ── AC-BI03 · El aguante se reparte entre las pausas ─────────────────────────────────────
func test_quien_hace_dos_pausas_se_agota_a_la_mitad() -> void:
	var personal: Node = _personal()
	# 180 min de presupuesto: el de dos cafés se agota a los 90; el de uno, a los 180.
	assert_float(personal.aguante_efectivo(_agente(5))).is_equal_approx(90.0, 0.001)
	assert_float(personal.aguante_efectivo(_agente(3))).is_equal_approx(180.0, 0.001)
	assert_float(personal.aguante_efectivo(_agente(1))).is_equal_approx(180.0, 0.001)


# ── AC-BI01 · La barra sube atendiendo, y solo atendiendo ────────────────────────────────
func test_atender_media_hora_cansa_lo_esperado() -> void:
	var personal: Node = _personal()
	var agente: RefCounted = _agente(3)                 # aguante 180
	personal.cansar(agente, 30.0)
	# 100/180 = 0,5556 por minuto × 30 = 16,67.
	assert_float(agente.cansancio).is_equal_approx(16.67, 0.01)


func test_estar_parado_no_cansa() -> void:
	var personal: Node = _personal()
	var agente: RefCounted = _agente(3)
	personal.cansar(agente, 0.0)
	assert_float(agente.cansancio).is_equal(0.0)


func test_la_jornada_entera_atendiendo_agota_al_de_un_cafe() -> void:
	var personal: Node = _personal()
	var agente: RefCounted = _agente(3)
	personal.cansar(agente, 180.0)
	assert_float(agente.cansancio).is_equal(100.0)
	assert_bool(personal.necesita_descanso(agente)).is_true()


func test_la_barra_no_pasa_de_cien() -> void:
	var personal: Node = _personal()
	var agente: RefCounted = _agente(3)
	personal.cansar(agente, 500.0)
	assert_float(agente.cansancio).is_equal(100.0)


func test_las_horas_extra_queman_mas() -> void:
	# La peonada de Documentación #8 no solo cuesta dinero: consume a la gente (×1.5).
	var personal: Node = _personal()
	var normal: RefCounted = _agente(3)
	var en_peonada: RefCounted = _agente(3)
	personal.cansar(normal, 60.0)
	personal.cansar(en_peonada, 60.0, true)
	assert_float(en_peonada.cansancio).is_equal_approx(normal.cansancio * 1.5, 0.01)


# ── AC-BI04 / AC-BI05 · Cuándo toca levantarse ───────────────────────────────────────────
func test_con_la_barra_a_medias_no_se_levanta_nadie() -> void:
	var personal: Node = _personal()
	var agente: RefCounted = _agente(3)
	personal.cansar(agente, 179.0)                      # 99,4: casi, pero no
	assert_bool(personal.necesita_descanso(agente)).is_false()


func test_gastadas_sus_pausas_aguanta_hasta_el_cierre() -> void:
	var personal: Node = _personal()
	var agente: RefCounted = _agente(3)                 # le toca UNA pausa
	personal.cansar(agente, 180.0)
	agente.pausas_gastadas = 1                          # ya se la ha tomado
	assert_float(agente.cansancio).is_equal(100.0)
	assert_bool(personal.necesita_descanso(agente)).is_false()


func test_el_de_dos_cafes_puede_pedir_la_segunda() -> void:
	var personal: Node = _personal()
	var agente: RefCounted = _agente(5)                 # le tocan DOS
	personal.cansar(agente, 90.0)
	agente.pausas_gastadas = 1                          # ya se tomó la primera
	assert_bool(personal.necesita_descanso(agente)).is_true()
	agente.pausas_gastadas = 2
	assert_bool(personal.necesita_descanso(agente)).is_false()


func test_un_agente_nulo_no_rompe_nada() -> void:
	var personal: Node = _personal()
	assert_bool(personal.necesita_descanso(null)).is_false()
	assert_float(personal.cansar(null, 10.0)).is_equal(0.0)


# ── AC-BI06 · Config corrupta: se sanea, no se rompe ─────────────────────────────────────
func test_config_fuera_de_rango_se_clampa_con_aviso() -> void:
	var config: Resource = ConfigPersonalScript.new()
	config.minutos_aguante = 0                          # dividiría por cero al repartir el aguante
	config.min_pausa_corta = 0
	config.mult_cansancio_horas_extra = 99.0
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(config)

	assert_int(personal.minutos_aguante).is_equal(1)
	assert_int(personal.min_pausa_corta).is_equal(1)
	assert_float(personal.mult_cansancio_horas_extra).is_equal(5.0)
	# Y con el aguante saneado, cansar sigue siendo una operación válida.
	var agente: RefCounted = _agente(3)
	personal.cansar(agente, 1.0)
	assert_float(agente.cansancio).is_equal(100.0)


# ── Pagar mejor la hora extra cansa menos (story bien-002) ──────────────────────────────
# Petición del usuario 2026-07-28: "por defecto cansa 1,5 pero si se paga más esa penalización va
# bajando". El precio lo elige el jugador en Documentación; la conversión pago→cansancio es de
# Personal, porque el cansancio es suyo.
func test_con_el_pago_minimo_la_hora_extra_cansa_lo_maximo() -> void:
	var personal: Node = _personal()
	personal.fijar_generosidad_peonada(0.0)             # el convenio pelado
	assert_float(personal.mult_cansancio_efectivo()).is_equal_approx(1.5, 0.001)


func test_pagando_el_tope_la_hora_extra_cansa_como_una_normal() -> void:
	var personal: Node = _personal()
	personal.fijar_generosidad_peonada(1.0)
	assert_float(personal.mult_cansancio_efectivo()).is_equal_approx(1.0, 0.001)
	# Y se nota en la barra: la misma hora de peonada cansa lo mismo que una hora corriente.
	var bien_pagado: RefCounted = _agente(3)
	var normal: RefCounted = _agente(3)
	personal.cansar(bien_pagado, 60.0, true)
	personal.cansar(normal, 60.0, false)
	assert_float(bien_pagado.cansancio).is_equal_approx(normal.cansancio, 0.001)


func test_a_medio_camino_el_recargo_es_intermedio() -> void:
	var personal: Node = _personal()
	personal.fijar_generosidad_peonada(0.5)
	assert_float(personal.mult_cansancio_efectivo()).is_equal_approx(1.25, 0.001)


func test_la_generosidad_se_clampa_a_su_rango() -> void:
	var personal: Node = _personal()
	personal.fijar_generosidad_peonada(5.0)             # un dato absurdo no rompe la fórmula
	assert_float(personal.mult_cansancio_efectivo()).is_equal_approx(1.0, 0.001)
	personal.fijar_generosidad_peonada(-3.0)
	assert_float(personal.mult_cansancio_efectivo()).is_equal_approx(1.5, 0.001)
