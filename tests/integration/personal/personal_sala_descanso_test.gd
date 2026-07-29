# Story bien-005 (Bienestar #13) — los MUEBLES de la sala de descanso: la calidad instalada acorta
# la pausa (con suelo), y las plazas compradas deciden cuánta gente cabe a la vez tomando el café.
# Tipo: Integration. DETERMINISTA: ticks manuales, sin azar. Petición del usuario 2026-07-29: "no hay
# objetos para esa sala, sillas, sofás, nevera, revistas... cosas que puedan hacer descansar, agua".
extends GdUnitTestSuite

const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")


# ── Fixture (mismo molde que personal_descanso_test.gd) ──────────────────────────────────────────
## Personal con un agente asignado a `doc_1`. `con_sala` monta la sala de descanso; `muebles` coloca
## esos objetos del catálogo dentro de ella (celdas correlativas — su Rect2i de 4x3 tiene hueco de
## sobra para los 6 del catálogo). `doc_2`/`doc_3` quedan registrados y libres, listos para los tests
## de aforo que necesitan un segundo o tercer agente. Devuelve [personal, agente, construccion].
func _mundo(motivacion: int = 3, con_sala: bool = true, muebles: Array[StringName] = []) -> Array:
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	economia.saldo_eur = 100000.0
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(economia)
	construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(1, 1, 6, 4))
	if con_sala:
		construccion.construir_de_oficio_sala(&"sala_descanso", Rect2i(9, 1, 4, 3))
		var x: int = 9
		var y: int = 1
		for mueble: StringName in muebles:
			construccion.construir_de_oficio_elemento(mueble, Vector2i(x, y))
			x += 1
			if x >= 13:
				x = 9
				y += 1
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.usar_construccion(construccion)
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	personal.registrar_puesto(&"doc_2", &"puesto_doc_general")
	personal.registrar_puesto(&"doc_3", &"puesto_doc_general")
	var agente: RefCounted = AgenteScript.new(
		"Ana Ruiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, motivacion
	)
	personal.plantilla.append(agente)
	personal.asignar(agente, &"doc_1")
	return [personal, agente, construccion]


## Añade un segundo agente (motivación estándar) asignado a `doc_2` al mundo ya montado — lo usan los
## tests de aforo: con la sala pelada (plaza base = 1) el segundo se queda esperando su turno.
func _sumar_segundo_agente(personal: Node) -> RefCounted:
	var segundo: RefCounted = AgenteScript.new(
		"Carlos Vega", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3
	)
	personal.plantilla.append(segundo)
	personal.asignar(segundo, &"doc_2")
	return segundo


## Y un tercero a `doc_3` — para el test de "sin sala no hay tope" (caben todos en la calle a la vez).
func _sumar_tercer_agente(personal: Node) -> RefCounted:
	var tercero: RefCounted = AgenteScript.new(
		"Lucia Ortega", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3
	)
	personal.plantilla.append(tercero)
	personal.asignar(tercero, &"doc_3")
	return tercero


# ── Los tres tramos de mult_pausa_por_sala() ──────────────────────────────────────────────────────
func test_sin_sala_de_descanso_la_pausa_sigue_alargandose() -> void:
	# El comportamiento viejo (story bien-003) no se ha roto al añadir los muebles.
	var mundo: Array = _mundo(3, false)
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	assert_float(personal.mult_pausa_por_sala()).is_equal(1.5)

	personal.cansar(agente, 180.0)
	assert_float(personal.enviar_a_descansar(agente)).is_equal_approx(45.0, 0.001)


func test_sala_pelada_sin_muebles_la_pausa_es_la_reglamentaria() -> void:
	var mundo: Array = _mundo(3, true, [])
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	assert_bool(personal.hay_sala_descanso()).is_true()
	assert_float(personal.mult_pausa_por_sala()).is_equal(1.0)

	personal.cansar(agente, 180.0)
	assert_float(personal.enviar_a_descansar(agente)).is_equal(30.0)


func test_con_muebles_la_pausa_se_acorta_en_proporcion_a_lo_instalado() -> void:
	# Una sola prensa diaria: calidad 1.0 -> 1.0 - 0.03*1.0 = 0.97.
	var mundo: Array = _mundo(3, true, [&"prensa_diaria"])
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	assert_float(personal.mult_pausa_por_sala()).is_equal_approx(0.97, 0.001)

	personal.cansar(agente, 180.0)
	assert_float(personal.enviar_a_descansar(agente)).is_equal_approx(29.1, 0.001)


func test_por_muchos_muebles_que_se_metan_la_pausa_no_baja_del_suelo() -> void:
	# Los 6 objetos del catálogo: calidad 1.0+1.0+1.5+2.0+3.0+4.0 = 12.5 -> muy por debajo del suelo.
	var mundo: Array = _mundo(3, true, [
		&"prensa_diaria", &"sillas_office", &"dispensador_agua",
		&"nevera", &"maquina_cafe", &"sofa_descanso",
	])
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	assert_float(personal.mult_pausa_por_sala()).is_equal(0.7)

	personal.cansar(agente, 180.0)
	assert_float(personal.enviar_a_descansar(agente)).is_equal(21.0)


# ── Plazas de descanso: cuánta gente cabe a la vez ───────────────────────────────────────────────
func test_un_sofa_da_tres_plazas_mas_la_base_son_cuatro() -> void:
	var mundo: Array = _mundo(3, true, [&"sofa_descanso"])
	var personal: Node = mundo[0]
	assert_int(personal.plazas_de_descanso()).is_equal(4)


func test_con_la_sala_llena_el_siguiente_no_se_va_sigue_asignado() -> void:
	# Sala pelada: plaza base = 1. El primero ocupa la única plaza; al segundo no le toca sitio.
	var mundo: Array = _mundo(3, true, [])
	var personal: Node = mundo[0]
	var primero: RefCounted = mundo[1]
	var segundo: RefCounted = _sumar_segundo_agente(personal)

	personal.cansar(primero, 180.0)
	personal.cansar(segundo, 180.0)
	assert_float(personal.enviar_a_descansar(primero)).is_equal(30.0)
	assert_bool(personal.hay_sitio_para_descansar()).is_false()

	assert_float(personal.enviar_a_descansar(segundo)).is_equal(0.0)
	assert_str(String(segundo.estado)).is_equal("asignado")
	assert_int(segundo.pausas_gastadas).is_equal(0)          # no ha gastado una pausa por no encontrar sitio
	assert_bool(personal.puesto_dotado(&"doc_2")).is_true()  # sigue atendiendo, no ha perdido su puesto


func test_al_volver_uno_del_cafe_el_que_esperaba_ya_puede_irse() -> void:
	var mundo: Array = _mundo(3, true, [])
	var personal: Node = mundo[0]
	var primero: RefCounted = mundo[1]
	var segundo: RefCounted = _sumar_segundo_agente(personal)

	personal.cansar(primero, 180.0)
	personal.cansar(segundo, 180.0)
	personal.enviar_a_descansar(primero)
	assert_float(personal.enviar_a_descansar(segundo)).is_equal(0.0)   # todavia sin sitio

	personal._al_tick(30.0)                                  # el primero termina su cafe y vuelve
	assert_str(String(primero.estado)).is_equal("asignado")

	assert_float(personal.enviar_a_descansar(segundo)).is_equal(30.0)
	assert_str(String(segundo.estado)).is_equal("descansando")


func test_sin_sala_construida_no_hay_tope_de_aforo() -> void:
	# 0 = "sin tope" (lo interpreta hay_sitio_para_descansar): caben todos en la calle a la vez.
	var mundo: Array = _mundo(3, false)
	var personal: Node = mundo[0]
	var primero: RefCounted = mundo[1]
	var segundo: RefCounted = _sumar_segundo_agente(personal)
	var tercero: RefCounted = _sumar_tercer_agente(personal)
	assert_int(personal.plazas_de_descanso()).is_equal(0)

	for agente: RefCounted in [primero, segundo, tercero]:
		personal.cansar(agente, 180.0)
		assert_float(personal.enviar_a_descansar(agente)).is_equal_approx(45.0, 0.001)
		assert_str(String(agente.estado)).is_equal("descansando")


# ── Config corrupta: se sanea, no se rompe (patrón del proyecto) ─────────────────────────────────
func test_los_knobs_de_la_sala_se_clampan_sin_romper_la_formula() -> void:
	var config: Resource = ConfigPersonalScript.new()
	config.k_confort_pausa = 5.0          # sin clamp, un solo mueble dejaria la pausa en negativo
	config.mult_pausa_min = 0.0           # por debajo del minimo permitido (0.1)
	config.plazas_descanso_base = -3      # un dato absurdo no debe restar plazas
	var mundo: Array = _mundo(3, true, [&"prensa_diaria"])
	var personal: Node = mundo[0]
	personal.aplicar_config(config)

	assert_float(personal.k_confort_pausa).is_equal(1.0)
	assert_float(personal.mult_pausa_min).is_equal(0.1)
	assert_int(personal.plazas_descanso_base).is_equal(0)
	# Calidad 1.0 (una prensa) x k 1.0 tocaria 0.0, pero el suelo clampado (0.1) frena el cafe en seco.
	assert_float(personal.mult_pausa_por_sala()).is_equal_approx(0.1, 0.001)
	assert_int(personal.plazas_de_descanso()).is_equal(0)    # base 0 + 0 comprado (la prensa no da plazas)
