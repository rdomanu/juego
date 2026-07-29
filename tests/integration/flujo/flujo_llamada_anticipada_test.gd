# LLAMADA ANTICIPADA (decisión del usuario 2026-07-29): se llama al SIGUIENTE ciudadano mientras aún
# se atiende al anterior, para que vaya andando y no haya tiempo muerto — como en una oficina de
# verdad, donde el panel canta el siguiente número antes de que te levantes de la silla.
#
# POR QUÉ EXISTE, con los números que se midieron: un agente de Documentación pasaba 17 minutos
# PARADO por cada cliente (esperando a que cruzara la comisaría) y solo 13 atendiéndole — trabajaba
# el 44 % de su jornada. Efecto colateral: la barra de cansancio de Bienestar #13 no llegaba a
# agotarse nunca en ese servicio.
#
# Tipo: Integration. DETERMINISTA (ticks manuales; catálogo, Personal y Construcción REALES).
extends GdUnitTestSuite

const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

## Las atenciones de una ventanilla de Documentacion. TIPADO explicito: `elegir_de_cola` exige un
## `Array[StringName]` de verdad y rechaza un array literal sin tipo.
const ADMITIDAS_DOC: Array[StringName] = [&"dni", &"pasaporte"]


# ── Fixture ──────────────────────────────────────────────────────────────────────────────
## Misma geometría CONOCIDA que `flujo_camino_test.gd`: espera 2×2 en (0,0) → centro (1.0, 1.0);
## `doc_1` en (5,1) → distancia euclídea 4.0 celdas. Con velocidad 2.0 celdas/min el CAMINO es de
## **2.0 minutos exactos**, y un DNI dura **12 minutos**. Esos dos números son los que se usan a mano
## en todos los cálculos de abajo.
func _mundo() -> Array:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	# El cansancio ralentiza al agente segun avanza la jornada: se APAGA para aislar la variable bajo
	# prueba (mismo criterio que el resto de tests de Flujo que cuentan minutos exactos).
	personal.k_cansancio_rendimiento = 0.0
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_personal(personal)
	construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(0, 0, 2, 2))
	construccion.construir_de_oficio_elemento(construccion.ASIENTO_BASICO, Vector2i(0, 0))
	construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(4, 0, 4, 4))
	construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(5, 1), &"doc_1")
	var bus: Node = auto_free(EventBusScript.new())
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.velocidad_camino_celdas_min = 2.0        # camino = 2.0 min
	flujo.usar_personal(personal)
	flujo.usar_construccion(construccion)
	flujo.usar_bus(bus)
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")
	var agente: RefCounted = AgenteScript.new(
		"Ana Ruiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3
	)
	personal.plantilla.append(agente)
	personal.asignar(agente, &"doc_1")
	return [flujo, personal, bus, construccion]


## Mete a N personas de DNI en la cola de Documentación y las devuelve en orden.
func _encolar_dni(flujo: Node, cuantas: int) -> Array:
	var gente: Array = []
	for i: int in cuantas:
		var p: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 500.0))
		flujo.encolar(p)
		gente.append(p)
	return gente


# ── El corazón: se llama al siguiente CUANDO TOCA, ni antes ni después ────────────────────
func test_al_siguiente_se_le_llama_cuando_al_tramite_le_queda_justo_el_camino() -> void:
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	var gente: Array = _encolar_dni(flujo, 2)

	# Los 2 primeros minutos son el camino del primero; luego arrancan sus 12 min de DNI.
	flujo._al_tick(1.0)
	flujo._al_tick(1.0)
	assert_float(float(flujo._puestos_flujo[&"doc_1"]["restante"])).is_equal_approx(12.0, 0.0001)
	assert_object(flujo.siguiente_de(&"doc_1")).is_null()   # aún no: le quedan 12 min, el camino son 2

	# Se consume el trámite hasta dejar MÁS de 2 min: sigue sin llamarse a nadie.
	for i: int in range(9):
		flujo._al_tick(1.0)
	assert_float(float(flujo._puestos_flujo[&"doc_1"]["restante"])).is_equal_approx(3.0, 0.0001)
	assert_object(flujo.siguiente_de(&"doc_1")).is_null()   # 3.0 > 2.0 (camino): todavía no

	# Un tick más: quedan 2.0 = justo el camino -> AHORA se le llama.
	flujo._al_tick(1.0)
	assert_float(float(flujo._puestos_flujo[&"doc_1"]["restante"])).is_equal_approx(2.0, 0.0001)
	assert_object(flujo.siguiente_de(&"doc_1")).is_same(gente[1])
	assert_str(String((gente[1] as RefCounted).estado)).is_equal("llamada")
	# Y ya no está en la cola: se la ha llevado la reserva.
	assert_object(flujo.elegir_de_cola(&"Documentacion", ADMITIDAS_DOC)).is_null()


func test_al_terminar_el_siguiente_ya_ha_llegado_y_empalma_sin_tiempo_muerto() -> void:
	# ESTE es el objetivo de toda la funcionalidad: el segundo trámite arranca EN EL MISMO TICK en
	# que acaba el primero, sin los 2 min de camino de por medio.
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	var gente: Array = _encolar_dni(flujo, 2)

	for i: int in range(14):        # 2 de camino + 12 de DNI = el primero termina justo aquí
		flujo._al_tick(1.0)

	assert_str(String((gente[0] as RefCounted).estado)).is_equal("resuelta")
	# El segundo NO está en camino: ya llegó mientras el primero se atendía, así que está ATENDIDO
	# con sus 12 minutos íntegros por delante.
	assert_str(String((gente[1] as RefCounted).estado)).is_equal("en_atencion")
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("atendiendo")
	assert_float(float(flujo._puestos_flujo[&"doc_1"]["restante"])).is_equal_approx(12.0, 0.0001)
	assert_object(flujo.siguiente_de(&"doc_1")).is_null()   # la reserva se consumió


# ── Sin llamada anticipada, el mismo caso deja al agente parado ───────────────────────────
func test_con_el_margen_desactivado_vuelve_el_tiempo_muerto_de_antes() -> void:
	# La prueba de que la funcionalidad hace algo: con un margen muy negativo NUNCA se adelanta a
	# nadie, y al terminar el primero el segundo tiene que empezar entonces a andar (2 min parado).
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	flujo.margen_llamada_anticipada_min = -999.0
	var gente: Array = _encolar_dni(flujo, 2)

	for i: int in range(14):
		flujo._al_tick(1.0)

	assert_str(String((gente[0] as RefCounted).estado)).is_equal("resuelta")
	# El segundo acaba de ser llamado y AHORA empieza a caminar: el puesto no atiende.
	assert_str(String((gente[1] as RefCounted).estado)).is_equal("llamada")
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("en_camino")


# ── Nadie se queda tirado: los tres casos en que la reserva vuelve a la cola ──────────────
func test_si_cierran_la_ventanilla_el_reservado_vuelve_a_la_cola() -> void:
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	var gente: Array = _encolar_dni(flujo, 2)
	for i: int in range(12):        # deja al primero con 2.0 de trámite -> el segundo ya reservado
		flujo._al_tick(1.0)
	assert_object(flujo.siguiente_de(&"doc_1")).is_same(gente[1])

	flujo.cerrar_puesto(&"doc_1")

	assert_object(flujo.siguiente_de(&"doc_1")).is_null()
	assert_str(String((gente[1] as RefCounted).estado)).is_equal("esperando_dentro")
	# Y está OTRA VEZ en la cola, disponible para cualquier otra ventanilla.
	assert_object(flujo.elegir_de_cola(&"Documentacion", ADMITIDAS_DOC)).is_same(gente[1])


func test_si_demuelen_la_ventanilla_el_reservado_vuelve_a_la_cola() -> void:
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	var gente: Array = _encolar_dni(flujo, 2)
	for i: int in range(12):
		flujo._al_tick(1.0)
	assert_object(flujo.siguiente_de(&"doc_1")).is_same(gente[1])

	flujo.quitar_puesto_flujo(&"doc_1")

	assert_str(String((gente[1] as RefCounted).estado)).is_equal("esperando_dentro")
	assert_object(flujo.elegir_de_cola(&"Documentacion", ADMITIDAS_DOC)).is_same(gente[1])


func test_si_el_agente_se_va_al_cafe_al_terminar_el_reservado_vuelve_a_la_cola() -> void:
	# El caso de orden más delicado: el café se pide AL TERMINAR el trámite, justo antes de promover.
	# Si el agente se levanta, al reservado hay que devolverle a la cola en vez de mandarle a un
	# mostrador que se acaba de quedar vacío.
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	var personal: Node = mundo[1]
	var gente: Array = _encolar_dni(flujo, 2)
	for i: int in range(12):
		flujo._al_tick(1.0)
	assert_object(flujo.siguiente_de(&"doc_1")).is_same(gente[1])

	# Se agota al agente ANTES de que termine el trámite: al completarlo se irá al café.
	personal.cansar(personal.agente_de(&"doc_1"), 1000.0)
	assert_bool(personal.necesita_descanso(personal.agente_de(&"doc_1"))).is_true()

	flujo._al_tick(1.0)
	flujo._al_tick(1.0)             # aquí termina el trámite y el agente se levanta

	assert_str(String((gente[0] as RefCounted).estado)).is_equal("resuelta")
	assert_object(flujo.siguiente_de(&"doc_1")).is_null()
	assert_str(String((gente[1] as RefCounted).estado)).is_equal("esperando_dentro")
	assert_object(flujo.elegir_de_cola(&"Documentacion", ADMITIDAS_DOC)).is_same(gente[1])


# ── Guardar y cargar con alguien a medio camino: ni se pierde ni se duplica ───────────────
func test_el_reservado_sobrevive_al_guardado() -> void:
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	var gente: Array = _encolar_dni(flujo, 2)
	for i: int in range(12):
		flujo._al_tick(1.0)
	var turno_reservado: int = (flujo.siguiente_de(&"doc_1") as RefCounted).numero_turno

	# Round-trip por JSON real (full_precision), el camino del SaveManager.
	var foto: Dictionary = JSON.parse_string(JSON.stringify(flujo.save(), "", true, true))
	var otro: Array = _mundo()
	var flujo_b: Node = otro[0]
	flujo_b.load_state(foto)

	var reservado_b: RefCounted = flujo_b.siguiente_de(&"doc_1")
	assert_object(reservado_b).is_not_null()
	assert_int(reservado_b.numero_turno).is_equal(turno_reservado)
	# No se ha duplicado: el que está reservado NO sigue además en la cola.
	assert_object(flujo_b.elegir_de_cola(&"Documentacion", ADMITIDAS_DOC)).is_null()


# ── La reserva NO se salta la cola: usa el mismo criterio de siempre ──────────────────────
func test_el_reservado_sale_de_la_cola_por_el_orden_de_siempre() -> void:
	var mundo: Array = _mundo()
	var flujo: Node = mundo[0]
	var gente: Array = _encolar_dni(flujo, 3)
	for i: int in range(12):
		flujo._al_tick(1.0)
	# Documentación es FIFO puro: el reservado tiene que ser el SEGUNDO en llegar, no el tercero.
	assert_object(flujo.siguiente_de(&"doc_1")).is_same(gente[1])
