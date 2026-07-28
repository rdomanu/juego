# Story bien-003 (Bienestar #13) — se levantan de verdad y se van a la sala de descanso.
# Tipo: Integration. DETERMINISTA: ticks manuales, sin azar. Petición del usuario 2026-07-28:
# "cuando la barra de cansancio del funcionario se agote se levantan y se van a descansar".
extends GdUnitTestSuite

const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")


# ── Fixture ──────────────────────────────────────────────────────────────────────────────
## Personal con un agente asignado a `doc_1`. `con_sala` monta también una sala de descanso.
## Devuelve [personal, agente, construccion].
func _mundo(motivacion: int = 3, con_sala: bool = true) -> Array:
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	economia.saldo_eur = 100000.0
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(economia)
	construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(1, 1, 6, 4))
	if con_sala:
		construccion.construir_de_oficio_sala(&"sala_descanso", Rect2i(9, 1, 4, 3))
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.usar_construccion(construccion)
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	var agente: RefCounted = AgenteScript.new(
		"Ana Ruiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, motivacion
	)
	personal.plantilla.append(agente)
	personal.asignar(agente, &"doc_1")
	return [personal, agente, construccion]


# ── Se levanta y su ventanilla deja de atender ───────────────────────────────────────────
func test_al_agotarse_la_barra_se_va_y_el_puesto_deja_de_estar_dotado() -> void:
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	assert_bool(personal.puesto_dotado(&"doc_1")).is_true()

	personal.cansar(agente, 180.0)                      # jornada entera despachando
	assert_bool(personal.necesita_descanso(agente)).is_true()
	var minutos: float = personal.enviar_a_descansar(agente)

	assert_float(minutos).is_equal(30.0)                # su patrón: media hora de un tirón
	assert_str(String(agente.estado)).is_equal("descansando")
	# El gate FL4 ya exigía ASIGNADO: descansando, la ventanilla no atiende sin tocar nada de Flujo.
	assert_bool(personal.puesto_dotado(&"doc_1")).is_false()
	assert_object(personal.agente_descansando_en(&"doc_1")).is_equal(agente)


func test_vuelve_a_su_puesto_con_la_barra_a_cero() -> void:
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	personal.cansar(agente, 180.0)
	personal.enviar_a_descansar(agente)

	personal._al_tick(20.0)                             # aún le quedan 10 min de café
	assert_str(String(agente.estado)).is_equal("descansando")
	assert_float(personal.minutos_de_descanso_restantes(agente)).is_equal_approx(10.0, 0.001)

	personal._al_tick(10.0)                             # se acabó
	assert_str(String(agente.estado)).is_equal("asignado")
	assert_float(agente.cansancio).is_equal(0.0)
	assert_bool(personal.puesto_dotado(&"doc_1")).is_true()


func test_el_cumplidor_se_va_dos_veces_y_menos_rato() -> void:
	var mundo: Array = _mundo(5)                        # motivación 5 → 15 + 15
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]

	personal.cansar(agente, 90.0)                       # su aguante es la mitad
	assert_bool(personal.necesita_descanso(agente)).is_true()
	assert_float(personal.enviar_a_descansar(agente)).is_equal(15.0)
	personal._al_tick(15.0)
	assert_str(String(agente.estado)).is_equal("asignado")

	personal.cansar(agente, 90.0)                       # segunda mitad de la jornada
	assert_bool(personal.necesita_descanso(agente)).is_true()   # le queda su segundo café
	assert_float(personal.enviar_a_descansar(agente)).is_equal(15.0)
	personal._al_tick(15.0)

	# Y ya no le quedan más: aguanta hasta el cierre aunque se vuelva a agotar.
	personal.cansar(agente, 90.0)
	assert_bool(personal.necesita_descanso(agente)).is_false()


func test_el_caradura_tiene_la_ventanilla_parada_una_hora() -> void:
	var mundo: Array = _mundo(1)                        # motivación 1 → 60 min
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	personal.cansar(agente, 180.0)
	assert_float(personal.enviar_a_descansar(agente)).is_equal(60.0)

	personal._al_tick(59.0)
	assert_bool(personal.puesto_dotado(&"doc_1")).is_false()    # una hora sin atender a nadie
	personal._al_tick(1.0)
	assert_bool(personal.puesto_dotado(&"doc_1")).is_true()


# ── La sala de descanso: sin ella se tarda más en volver ─────────────────────────────────
func test_sin_sala_de_descanso_la_pausa_se_alarga() -> void:
	var mundo: Array = _mundo(3, false)                 # sin sala construida
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	assert_bool(personal.hay_sala_descanso()).is_false()

	personal.cansar(agente, 180.0)
	# Los 30 min de café se convierten en 45: se van a la calle y tardan más en volver.
	assert_float(personal.enviar_a_descansar(agente)).is_equal_approx(45.0, 0.001)


func test_con_sala_construida_la_pausa_es_la_normal() -> void:
	var mundo: Array = _mundo(3, true)
	assert_bool(mundo[0].hay_sala_descanso()).is_true()
	mundo[0].cansar(mundo[1], 180.0)
	assert_float(mundo[0].enviar_a_descansar(mundo[1])).is_equal(30.0)


# ── Casos límite ─────────────────────────────────────────────────────────────────────────
func test_no_se_puede_mandar_a_descansar_a_quien_no_esta_en_su_puesto() -> void:
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	personal.desasignar(agente)
	assert_float(personal.enviar_a_descansar(agente)).is_equal(0.0)
	assert_float(personal.enviar_a_descansar(null)).is_equal(0.0)


func test_si_le_quitan_el_puesto_mientras_descansa_no_se_lo_devuelven() -> void:
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	personal.cansar(agente, 180.0)
	personal.enviar_a_descansar(agente)
	personal.desasignar(agente)                         # el jugador lo mueve mientras está fuera

	personal._al_tick(60.0)
	assert_str(String(agente.estado)).is_equal("libre")  # vuelve al banquillo, no a un puesto ajeno


func test_en_pausa_del_juego_nadie_vuelve_del_cafe() -> void:
	# El tick no corre en Pausa (Tiempo no empuja), así que el café tampoco: se comprueba que la
	# cuenta atrás depende SOLO del delta de juego.
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	personal.cansar(agente, 180.0)
	personal.enviar_a_descansar(agente)
	personal._al_tick(0.0)
	assert_str(String(agente.estado)).is_equal("descansando")
	assert_float(personal.minutos_de_descanso_restantes(agente)).is_equal(30.0)


# ── Integración con Flujo: atender cansa, y el café llega al terminar ────────────────────
func test_atender_cansa_y_el_cafe_se_pide_al_acabar_el_tramite() -> void:
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.velocidad_camino_celdas_min = 0.0
	flujo.usar_personal(personal)
	flujo.usar_bus(auto_free(EventBusScript.new()))
	var tiempo: Node = auto_free(TiempoScript.new())
	tiempo.minutos_juego = 600.0                        # 10:00, jornada normal
	flujo.usar_tiempo(tiempo)
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")

	# Deja al agente a un pelo de agotarse y que atienda un DNI entero (12 min).
	personal.cansar(agente, 179.0)
	var persona: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 600.0))
	flujo.encolar(persona)
	for i: int in range(20):        # va agotado: el DNI le cuesta ~15 min, no 12
		flujo._al_tick(1.0)

	# El trámite se completó (nadie se va a media atención) y ENTONCES se fue a su café.
	assert_str(String(persona.estado)).is_equal("resuelta")
	assert_str(String(agente.estado)).is_equal("descansando")


func test_estar_de_brazos_cruzados_no_cansa() -> void:
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.usar_personal(personal)
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")

	for i: int in range(60):                            # una hora con la ventanilla vacía
		flujo._al_tick(1.0)

	assert_float(agente.cansancio).is_equal(0.0)


# ── Jornada nueva, gente descansada ──────────────────────────────────────────────────────
func test_al_empezar_el_dia_la_barra_vuelve_a_cero_y_se_renuevan_los_cafes() -> void:
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	personal.cansar(agente, 180.0)
	personal.enviar_a_descansar(agente)

	personal._al_nuevo_dia()

	assert_float(agente.cansancio).is_equal(0.0)
	assert_int(agente.pausas_gastadas).is_equal(0)
	# A quien le pilló el cambio de día tomando café se le devuelve su puesto: la pausa no se arrastra.
	assert_str(String(agente.estado)).is_equal("asignado")
	assert_bool(personal.puesto_dotado(&"doc_1")).is_true()


func test_el_cansancio_sobrevive_al_guardado() -> void:
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	personal.cansar(agente, 90.0)                       # medio agotado
	agente.pausas_gastadas = 1

	var recuperado: Dictionary = JSON.parse_string(JSON.stringify(personal.save()))
	var otro: Node = auto_free(PersonalScript.new())
	otro.aplicar_config(ConfigPersonalScript.new())
	otro.registrar_puesto(&"doc_1", &"puesto_doc_general")
	otro.load_state(recuperado)

	var cargado: RefCounted = otro.agente_de(&"doc_1")
	assert_object(cargado).is_not_null()
	# Guardar y cargar NO es un chute de energía gratis para la plantilla.
	assert_float(cargado.cansancio).is_equal_approx(50.0, 0.01)
	assert_int(cargado.pausas_gastadas).is_equal(1)


func test_quien_estaba_de_cafe_sigue_de_cafe_al_cargar() -> void:
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	personal.cansar(agente, 180.0)
	personal.enviar_a_descansar(agente)
	personal._al_tick(10.0)                             # le quedan 20 min

	var recuperado: Dictionary = JSON.parse_string(JSON.stringify(personal.save()))
	var otro: Node = auto_free(PersonalScript.new())
	otro.aplicar_config(ConfigPersonalScript.new())
	otro.registrar_puesto(&"doc_1", &"puesto_doc_general")
	otro.load_state(recuperado)

	var cargado: RefCounted = otro.agente_de(&"doc_1")
	assert_str(String(cargado.estado)).is_equal("descansando")
	assert_float(otro.minutos_de_descanso_restantes(cargado)).is_equal_approx(20.0, 0.01)
	otro._al_tick(20.0)
	assert_str(String(cargado.estado)).is_equal("asignado")


# ── El cansancio se nota ANTES del café: quien va quemado atiende más despacio ──────────
func test_un_agente_agotado_atiende_mas_despacio() -> void:
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	var fresco: float = personal.modificador_produccion_de(&"doc_1")

	personal.cansar(agente, 180.0)                      # barra a tope
	var agotado: float = personal.modificador_produccion_de(&"doc_1")

	# Con la barra llena tarda un 25 % más en cada trámite.
	assert_float(agotado).is_equal_approx(fresco * 1.25, 0.001)
	assert_float(personal.mult_cansancio_rendimiento(agente)).is_equal_approx(1.25, 0.001)


func test_el_bajon_es_progresivo_no_de_golpe() -> void:
	# Que sea gradual es lo que permite VER venir el problema: la cola se alarga antes del café.
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	personal.cansar(agente, 90.0)                       # media barra
	assert_float(personal.mult_cansancio_rendimiento(agente)).is_equal_approx(1.125, 0.001)


func test_al_volver_del_cafe_rinde_como_al_principio() -> void:
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	var fresco: float = personal.modificador_produccion_de(&"doc_1")
	personal.cansar(agente, 180.0)
	personal.enviar_a_descansar(agente)
	personal._al_tick(30.0)
	assert_float(personal.modificador_produccion_de(&"doc_1")).is_equal_approx(fresco, 0.001)


func test_el_hud_puede_saber_quien_esta_de_cafe() -> void:
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	assert_int(personal.puestos_en_descanso().size()).is_equal(0)

	personal.cansar(agente, 180.0)
	personal.enviar_a_descansar(agente)
	assert_array(personal.puestos_en_descanso()).contains_exactly([&"doc_1"])

	personal._al_tick(30.0)
	assert_int(personal.puestos_en_descanso().size()).is_equal(0)
