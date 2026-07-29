# Story bien-006 (Bienestar #13) — dos funcionalidades:
#   1) El CAMINO a la sala de descanso: tiempo AÑADIDO (no descontado de la pausa). Petición del
#      usuario 2026-07-29: "empieza a contar el descanso durante el camino... cuando esté fuera de
#      la comisaría o en la sala de descanso, ahí es cuando tiene que empezar a contar".
#   2) El CUPO de cafés se renueva por TURNO de reloj (bug: en la ODAC, que no cierra nunca, el
#      funcionario se quedaba con la barra de cansancio al máximo hasta 18h de juego).
# Tipo: Integration. DETERMINISTA: ticks manuales, sin azar, sin reloj real.
extends GdUnitTestSuite

const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")


# ── Fixture ───────────────────────────────────────────────────────────────────────────────────
## `doc_1` se construye como elemento REAL de Construcción en (2,2) dentro de `sala_documentacion`
## (Rect2i(1,1,6,4) — mismo montaje que usa Main), porque `minutos_de_camino_al_descanso` necesita
## una posición de verdad (`posicion_de`), no solo el registro abstracto de Personal. Si `con_sala`
## es true se construye además `sala_descanso` en Rect2i(9,1,6,3): su centro cae en
## (9+6/2, 1+3/2) = (12,2), así que la distancia Chebyshev doc_1 -> centro es
## max(|12-2|, |2-2|) = 10 celdas EXACTAS. `min_celda` deja fijar el knob (2.67 real, para medir
## el camino; 0.0 para aislarlo, como hace el fixture hermano de bien-005). Devuelve
## [personal, agente, construccion].
func _mundo(motivacion: int = 3, con_sala: bool = true, min_celda: float = 2.67) -> Array:
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	economia.saldo_eur = 100000.0
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(economia)
	construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(1, 1, 6, 4))
	construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(2, 2), &"doc_1")
	if con_sala:
		construccion.construir_de_oficio_sala(&"sala_descanso", Rect2i(9, 1, 6, 3))
	var personal: Node = auto_free(PersonalScript.new())
	var config_p: Resource = ConfigPersonalScript.new()
	config_p.min_por_celda_a_descanso = min_celda
	personal.aplicar_config(config_p)
	personal.usar_construccion(construccion)
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	personal.registrar_puesto(&"doc_2", &"puesto_doc_general")
	var agente: RefCounted = AgenteScript.new(
		"Ana Ruiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, motivacion
	)
	personal.plantilla.append(agente)
	personal.asignar(agente, &"doc_1")
	return [personal, agente, construccion]


## Un segundo agente (motivación estándar) a `doc_2` — lo usa el test de aforo.
func _sumar_segundo_agente(personal: Node) -> RefCounted:
	var segundo: RefCounted = AgenteScript.new(
		"Carlos Vega", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3
	)
	personal.plantilla.append(segundo)
	personal.asignar(segundo, &"doc_2")
	return segundo


## Igual que `_mundo()` pero con un RELOJ inyectado a `minuto_del_dia` (mismo patrón que
## `personal_sala_descanso_test.gd`). Devuelve [personal, agente, construccion, tiempo].
func _mundo_con_reloj(
	minuto_del_dia: float, motivacion: int = 3, con_sala: bool = true, min_celda: float = 2.67
) -> Array:
	var mundo: Array = _mundo(motivacion, con_sala, min_celda)
	var personal: Node = mundo[0]
	var tiempo: Node = auto_free(TiempoScript.new())
	tiempo.minutos_juego = minuto_del_dia
	personal.usar_tiempo(tiempo)
	mundo.append(tiempo)
	return mundo


# ── El camino a la sala de descanso: tiempo AÑADIDO, no descontado de la pausa ───────────────────

func test_minutos_de_camino_al_descanso_calcula_distancia_chebyshev_por_el_knob() -> void:
	# doc_1 en (2,2); centro de sala_descanso (Rect2i(9,1,6,3)) en (9+3, 1+1) = (12,2). Distancia
	# Chebyshev = max(|12-2|, |2-2|) = 10 celdas. Con el knob semilla (2.67): 10 x 2.67 = 26.7 min.
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	assert_float(personal.minutos_de_camino_al_descanso(&"doc_1")).is_equal_approx(26.7, 0.001)


func test_al_enviar_a_descansar_el_agente_va_de_camino_y_su_puesto_deja_de_estar_dotado() -> void:
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]

	personal.cansar(agente, 180.0)
	var minutos: float = personal.enviar_a_descansar(agente)

	assert_float(minutos).is_equal(30.0)                                # la pausa reglamentaria
	assert_bool(personal.va_de_camino_al_descanso(agente)).is_true()
	assert_str(String(agente.estado)).is_equal("descansando")           # desde que se levanta
	assert_bool(personal.puesto_dotado(&"doc_1")).is_false()            # su ventanilla ya no atiende


func test_tras_cubrir_el_camino_pero_no_la_pausa_le_queda_la_pausa_entera() -> void:
	# El camino (26.7 min) es tiempo AÑADIDO: NO se resta de la pausa (30.0 min). La ausencia total
	# de la ventanilla es camino + pausa.
	#
	# Del tick que le hace LLEGAR solo puede comerse del café el SOBRANTE — los minutos que pasan ya
	# sentado —, nunca el trayecto. Aquí se comprueba con un tick que se pasa 1.0 min: llega y se le
	# resta ese 1.0, no los 3.0 del tick ni los 26.7 del camino.
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]

	var camino: float = personal.minutos_de_camino_al_descanso(&"doc_1")
	personal.cansar(agente, 180.0)
	personal.enviar_a_descansar(agente)

	personal._al_tick(camino - 2.0)                       # a falta de 2.0 min de camino, sigue andando
	assert_bool(personal.va_de_camino_al_descanso(agente)).is_true()
	assert_float(personal.minutos_de_descanso_restantes(agente)).is_equal(30.0)  # la pausa que le espera

	personal._al_tick(3.0)                                # le sobraba 2.0 de camino: se pasa 1.0 min
	assert_bool(personal.va_de_camino_al_descanso(agente)).is_false()   # ya llegó
	assert_str(String(agente.estado)).is_equal("descansando")
	assert_float(personal.minutos_de_descanso_restantes(agente)).is_equal_approx(29.0, 0.01)


func test_un_solo_tick_que_cubre_el_camino_justo_no_se_come_nada_de_la_pausa() -> void:
	# EL CASO LÍMITE, y la regresión de un bug real (2026-07-29): con UN SOLO tick que cubra el
	# camino de punta a punta, `_avanzar_caminos_al_descanso` sienta al agente y el bucle de
	# `_descansando` de ESE MISMO `_al_tick` le restaba el delta ENTERO a la pausa recién arrancada
	# -> quedaban 3.3 min en vez de 30.0, o sea, el camino SE DESCONTABA del café. Justo lo contrario
	# de la decisión de diseño del usuario (opción A: el camino es tiempo AÑADIDO).
	# En el juego real casi no se dispara (los deltas son fracciones de minuto), pero un error que
	# solo aparece en el caso límite sigue siendo un error.
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]

	var camino: float = personal.minutos_de_camino_al_descanso(&"doc_1")
	personal.cansar(agente, 180.0)
	personal.enviar_a_descansar(agente)

	personal._al_tick(camino)                             # llega EXACTAMENTE con este tick
	assert_bool(personal.va_de_camino_al_descanso(agente)).is_false()
	# Sobrante 0 -> la pausa sigue ENTERA: acaba de sentarse.
	assert_float(personal.minutos_de_descanso_restantes(agente)).is_equal_approx(30.0, 0.01)


func test_un_tick_enorme_solo_descuenta_del_cafe_lo_que_paso_ya_sentado() -> void:
	# La otra mitad del caso límite: un tick que se pasa MUCHO del camino. Debe descontarse del café
	# exactamente el exceso (5.0), ni el tick entero ni cero.
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]

	var camino: float = personal.minutos_de_camino_al_descanso(&"doc_1")
	personal.cansar(agente, 180.0)
	personal.enviar_a_descansar(agente)

	personal._al_tick(camino + 5.0)
	assert_bool(personal.va_de_camino_al_descanso(agente)).is_false()
	assert_float(personal.minutos_de_descanso_restantes(agente)).is_equal_approx(25.0, 0.01)


func test_con_el_knob_a_cero_se_sienta_al_instante_como_antes() -> void:
	var mundo: Array = _mundo(3, true, 0.0)
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]

	personal.cansar(agente, 180.0)
	var minutos: float = personal.enviar_a_descansar(agente)

	assert_float(minutos).is_equal(30.0)
	assert_bool(personal.va_de_camino_al_descanso(agente)).is_false()   # sin camino, ya sentado
	assert_float(personal.minutos_de_descanso_restantes(agente)).is_equal(30.0)


func test_el_aforo_cuenta_a_los_que_van_de_camino_no_solo_a_los_sentados() -> void:
	# Sala pelada -> 1 sola plaza (base). El primero sale hacia el café (aún caminando, sin llegar);
	# su plaza ya está reservada, así que al segundo no le toca sitio.
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var primero: RefCounted = mundo[1]
	var segundo: RefCounted = _sumar_segundo_agente(personal)

	personal.cansar(primero, 180.0)
	personal.cansar(segundo, 180.0)
	assert_float(personal.enviar_a_descansar(primero)).is_equal(30.0)
	assert_bool(personal.va_de_camino_al_descanso(primero)).is_true()       # aún caminando
	assert_bool(personal.hay_sitio_para_descansar()).is_false()

	assert_float(personal.enviar_a_descansar(segundo)).is_equal(0.0)
	assert_str(String(segundo.estado)).is_equal("asignado")


func test_si_le_cierran_la_ventanilla_mientras_camina_da_media_vuelta_y_queda_asignado() -> void:
	var mundo: Array = _mundo_con_reloj(500.0)
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	var tiempo: Node = mundo[3]
	personal.fijar_cierre_de_puesto(&"doc_1", 510)

	personal.cansar(agente, 180.0)
	assert_float(personal.enviar_a_descansar(agente)).is_equal(30.0)
	assert_bool(personal.va_de_camino_al_descanso(agente)).is_true()

	tiempo.minutos_juego = 511.0                          # el cierre le pilla a mitad de camino
	personal._al_tick(1.0)

	assert_bool(personal.va_de_camino_al_descanso(agente)).is_false()
	assert_str(String(agente.estado)).is_equal("asignado")


# ── El turno: el cupo de cafés se renueva por franja de reloj ────────────────────────────────────

func test_turno_actual_da_0_1_2_segun_la_hora_del_reloj() -> void:
	# horas_por_turno = 8 (semilla) -> franjas de 480 min: 00-08 / 08-16 / 16-24.
	var mundo_madrugada: Array = _mundo_con_reloj(120.0)    # 02:00
	var personal_madrugada: Node = mundo_madrugada[0]
	var mundo_manana: Array = _mundo_con_reloj(600.0)       # 10:00
	var personal_manana: Node = mundo_manana[0]
	var mundo_tarde: Array = _mundo_con_reloj(1200.0)       # 20:00
	var personal_tarde: Node = mundo_tarde[0]

	assert_int(personal_madrugada.turno_actual()).is_equal(0)
	assert_int(personal_manana.turno_actual()).is_equal(1)
	assert_int(personal_tarde.turno_actual()).is_equal(2)


func test_cruzar_de_turno_renueva_pausas_gastadas_y_no_toca_el_cansancio() -> void:
	var mundo: Array = _mundo_con_reloj(450.0)               # turno 0 (00-08), cerca del borde
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	var tiempo: Node = mundo[3]
	agente.pausas_gastadas = 1
	agente.cansancio = 55.0

	personal._al_tick(1.0)                                    # primer tick: solo anota el turno (guarda)
	assert_int(agente.pausas_gastadas).is_equal(1)

	tiempo.minutos_juego = 485.0                              # cruza a turno 1 (480-960)
	personal._al_tick(1.0)

	assert_int(personal.turno_actual()).is_equal(1)
	assert_int(agente.pausas_gastadas).is_equal(0)            # el cupo se renueva
	assert_float(agente.cansancio).is_equal(55.0)             # la barra NO se toca (la parte importante)


func test_el_primer_tick_no_renueva_el_cupo_ya_gastado() -> void:
	var mundo: Array = _mundo_con_reloj(100.0)
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	agente.cansancio = 100.0
	agente.pausas_gastadas = personal.pausas_de(agente)       # ya gastó su única pausa de hoy
	assert_bool(personal.necesita_descanso(agente)).is_false()

	personal._al_tick(1.0)                                     # el primer tick: guarda, NO regala cupo

	assert_bool(personal.necesita_descanso(agente)).is_false()
	assert_int(agente.pausas_gastadas).is_equal(personal.pausas_de(agente))


func test_sin_reloj_turno_actual_es_siempre_cero_y_nunca_renueva() -> void:
	var mundo: Array = _mundo()                                # sin _mundo_con_reloj -> _tiempo queda null
	var personal: Node = mundo[0]
	var agente: RefCounted = mundo[1]
	agente.pausas_gastadas = 1

	assert_int(personal.turno_actual()).is_equal(0)
	personal._al_tick(10.0)                                     # primer tick: guarda
	assert_int(agente.pausas_gastadas).is_equal(1)

	personal._al_tick(10.0)
	assert_int(personal.turno_actual()).is_equal(0)
	assert_int(agente.pausas_gastadas).is_equal(1)              # sigue igual: sin reloj no hay turno que cruzar
