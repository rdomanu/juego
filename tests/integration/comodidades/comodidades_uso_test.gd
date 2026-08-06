# Story comodidades-003 — los objetos se USAN (petición del usuario 2026-07-28):
# "la gente tiene que acercarse a la máquina de vending y consumir algo, sacar de beneficio 1 euro".
# Ya no son decorados que suben un número: se va a ellos, calman de verdad y dejan dinero en caja.
# Tipo: Integration. DETERMINISTA: RNG sembrado; los gestos se fuerzan a mano donde el azar estorba.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const PacienciaScript := preload("res://src/feature/paciencia/paciencia.gd")
const ConfigPacienciaScript := preload("res://src/feature/paciencia/config_paciencia.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const RNGServiceScript := preload("res://src/foundation/rng_service/rng_service.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

const DOC := &"Documentacion"


# ── Fixture ──────────────────────────────────────────────────────────────────────────────
## Comisaría con sala de espera de Doc y caja de sobra. Devuelve [construccion, economia].
func _mundo() -> Array:
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	economia.saldo_eur = 100000.0
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(economia)
	construccion.usar_bus(auto_free(EventBusScript.new()))
	construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(1, 6, 6, 4))
	return [construccion, economia]


## Paciencia cableada a Construcción y Economía, con RNG sembrado (determinista).
func _paciencia_con(construccion: Node, economia: Node, semilla: int = 1) -> Node:
	var rng: Node = auto_free(RNGServiceScript.new())
	rng.sembrar(semilla)
	var paciencia: Node = auto_free(PacienciaScript.new())
	paciencia.aplicar_config(ConfigPacienciaScript.new())
	paciencia.usar_construccion(construccion)
	paciencia.usar_economia(economia)
	paciencia.usar_rng(rng)
	return paciencia


func _persona(turno: int = 1) -> RefCounted:
	return PersonaFlujoScript.new(PersonaScript.new(DOC, &"dni", 480), turno)


## Pone a `persona` a usar el primer objeto usable del servicio (el gesto, sin depender del azar).
func _ponerse_a_usar(
	paciencia: Node, construccion: Node, persona: RefCounted, catalogo: StringName, minutos: float
) -> void:
	paciencia._usando_comodidad[persona] = {
		"elemento": construccion.usables_de_servicio(DOC)[0],
		"catalogo": catalogo,
		"restante": minutos,
	}


# ── El catálogo distingue lo que se usa de lo que solo ambienta ──────────────────────────
func test_al_vending_se_va_pero_la_tele_se_ve_desde_el_asiento() -> void:
	var vending: Resource = Datos.obtener(&"Comodidad", &"vending")
	assert_bool(vending.usable).is_true()
	assert_float(vending.ingreso_por_uso_eur).is_equal(1.0)     # el euro que pidió el usuario
	assert_float(vending.recupera_paciencia).is_equal(15.0)
	# La tele y el hilo musical se disfrutan sentado: solo confort de ambiente.
	assert_bool(Datos.obtener(&"Comodidad", &"television").usable).is_false()
	assert_bool(Datos.obtener(&"Comodidad", &"radio").usable).is_false()
	# El revistero se usa, pero no cobra: da servicio, no dinero. (`fuente_agua` retirada 2026-08-06,
	# duplicado de `dispensador_agua`, que no es "usable" — ver `test_la_fuente_calma_pero_no_cobra`.)
	assert_bool(Datos.obtener(&"Comodidad", &"revistero").usable).is_true()
	assert_float(Datos.obtener(&"Comodidad", &"revistero").ingreso_por_uso_eur).is_equal(0.0)


func test_construccion_lista_los_usables_del_servicio() -> void:
	var construccion: Node = _mundo()[0]
	construccion.construir_elemento(&"television", Vector2i(2, 7))     # NO usable
	var vending: StringName = construccion.construir_elemento(&"vending", Vector2i(3, 7))
	assert_array(construccion.usables_de_servicio(DOC)).contains_exactly([vending])


# ── Usar el vending: entra 1 € y la barra sube ──────────────────────────────────────────
func test_una_consumicion_deja_un_euro_en_caja_y_calma_al_ciudadano() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var economia: Node = mundo[1]
	construccion.construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(construccion, economia)
	var persona: RefCounted = _persona()
	paciencia.registrar(persona)
	paciencia.drenar(persona, 12.0)                     # baja a 60: ya lleva un rato esperando
	var barra_antes: float = paciencia.paciencia_de(persona)
	var saldo_antes: float = economia.saldo_eur

	_ponerse_a_usar(paciencia, construccion, persona, &"vending", 3.0)
	assert_str(String(paciencia.comodidad_en_uso(persona))).is_not_equal("")
	paciencia._consumir_uso_comodidad(persona, 3.0)

	# Vuelve con 15 puntos más, deja su euro y ya no está en la máquina.
	assert_float(paciencia.paciencia_de(persona)).is_equal_approx(barra_antes + 15.0, 0.001)
	assert_float(economia.saldo_eur).is_equal_approx(saldo_antes + 1.0, 0.001)
	assert_float(economia.ingreso_comodidades_dia).is_equal(1.0)
	assert_str(String(paciencia.comodidad_en_uso(persona))).is_equal("")


func test_mientras_esta_en_la_maquina_no_gasta_paciencia() -> void:
	var mundo: Array = _mundo()
	mundo[0].construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(mundo[0], mundo[1])
	var persona: RefCounted = _persona()
	paciencia.registrar(persona)
	_ponerse_a_usar(paciencia, mundo[0], persona, &"vending", 3.0)

	# Un minuto en la máquina: la barra sigue clavada (está entretenido, no sufriendo la cola).
	assert_float(paciencia._consumir_uso_comodidad(persona, 1.0)).is_equal(0.0)
	assert_float(paciencia.paciencia_de(persona)).is_equal(100.0)


func test_los_minutos_que_sobran_del_gesto_cuentan_como_espera() -> void:
	var mundo: Array = _mundo()
	mundo[0].construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(mundo[0], mundo[1])
	var persona: RefCounted = _persona()
	paciencia.registrar(persona)
	_ponerse_a_usar(paciencia, mundo[0], persona, &"vending", 2.0)
	# Le quedaban 2 min de gesto y pasan 5: sobran 3 para la cola.
	assert_float(paciencia._consumir_uso_comodidad(persona, 5.0)).is_equal_approx(3.0, 0.001)


func test_la_barra_no_se_pasa_de_cien_al_volver() -> void:
	var mundo: Array = _mundo()
	mundo[0].construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(mundo[0], mundo[1])
	var persona: RefCounted = _persona()
	paciencia.registrar(persona)                        # entra con 100
	_ponerse_a_usar(paciencia, mundo[0], persona, &"vending", 1.0)
	paciencia._consumir_uso_comodidad(persona, 1.0)
	assert_float(paciencia.paciencia_de(persona)).is_equal(100.0)


func test_la_fuente_calma_pero_no_cobra() -> void:
	# `fuente_agua` retirada 2026-08-06 (duplicado de `dispensador_agua` — decisión del usuario de
	# unificar los objetos de agua; el dispensador que sobrevive NO es "usable"). El revistero cubre
	# el mismo caso de diseño que este test vigila ("hay objetos usables que calman gratis, no todo
	# es el vending"): `usable = true`, `ingreso_por_uso_eur = 0.0`, igual que tenía la fuente.
	var mundo: Array = _mundo()
	var economia: Node = mundo[1]
	mundo[0].construir_elemento(&"revistero", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(mundo[0], economia)
	var persona: RefCounted = _persona()
	paciencia.registrar(persona)
	paciencia.drenar(persona, 15.0)
	var saldo_antes: float = economia.saldo_eur
	_ponerse_a_usar(paciencia, mundo[0], persona, &"revistero", 2.0)
	paciencia._consumir_uso_comodidad(persona, 2.0)
	assert_float(economia.saldo_eur).is_equal(saldo_antes)     # gratis
	assert_float(economia.ingreso_comodidades_dia).is_equal(0.0)


# ── Quién se levanta: solo el que ya lleva rato, y va a lo que más le calma ─────────────
func test_recien_llegado_no_se_levanta_a_por_un_cafe() -> void:
	var mundo: Array = _mundo()
	mundo[0].construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(mundo[0], mundo[1])
	var persona: RefCounted = _persona()
	paciencia.registrar(persona)                        # paciencia 100 > umbral 75
	# Aunque la tirada saliera favorable, con la barra llena nadie se mueve del sitio.
	assert_bool(paciencia._quizas_ir_a_una_comodidad(persona, DOC, 1000.0)).is_false()


func test_el_que_lleva_rato_esperando_si_se_levanta() -> void:
	var mundo: Array = _mundo()
	mundo[0].construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(mundo[0], mundo[1])
	var persona: RefCounted = _persona()
	paciencia.registrar(persona)
	paciencia._consumidor_de[persona] = true            # aquí se mide el UMBRAL, no el rasgo
	paciencia.drenar(persona, 12.0)                     # 60 < umbral 75
	# `minutos` alto → la probabilidad por minuto satura y la tirada siempre entra: el gesto ocurre.
	assert_bool(paciencia._quizas_ir_a_una_comodidad(persona, DOC, 1000.0)).is_true()
	assert_str(String(paciencia.comodidad_en_uso(persona))).is_not_equal("")


func test_elige_la_comodidad_que_mas_le_calma() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	construccion.construir_elemento(&"revistero", Vector2i(2, 7))      # +8
	var vending: StringName = construccion.construir_elemento(&"vending", Vector2i(3, 7))   # +15
	var paciencia: Node = _paciencia_con(construccion, mundo[1])
	assert_str(String(paciencia._mejor_comodidad_usable(DOC))).is_equal(String(vending))


func test_sin_nada_usable_instalado_no_se_levanta_nadie() -> void:
	var mundo: Array = _mundo()
	mundo[0].construir_elemento(&"television", Vector2i(2, 7))         # confort, pero no se usa
	var paciencia: Node = _paciencia_con(mundo[0], mundo[1])
	var persona: RefCounted = _persona()
	paciencia.registrar(persona)
	paciencia.drenar(persona, 15.0)
	assert_bool(paciencia._quizas_ir_a_una_comodidad(persona, DOC, 1000.0)).is_false()


func test_sin_construccion_no_hay_gestos() -> void:
	var paciencia: Node = auto_free(PacienciaScript.new())
	paciencia.aplicar_config(ConfigPacienciaScript.new())
	var persona: RefCounted = _persona()
	paciencia.registrar(persona)
	paciencia.drenar(persona, 15.0)
	assert_bool(paciencia._quizas_ir_a_una_comodidad(persona, DOC, 1000.0)).is_false()


# ── El que estaba en la máquina al guardar, sigue en ella al cargar ─────────────────────
func test_el_gesto_sobrevive_al_guardado() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	construccion.construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(construccion, mundo[1])
	var persona: RefCounted = _persona(7)
	paciencia.registrar(persona)
	_ponerse_a_usar(paciencia, construccion, persona, &"vending", 2.0)

	var recuperado: Dictionary = JSON.parse_string(JSON.stringify(paciencia.save()))
	var otra: Node = _paciencia_con(construccion, mundo[1])
	otra.load_state(recuperado)
	var persona_nueva: RefCounted = _persona(7)        # al cargar, Flujo crea objetos NUEVOS

	otra.registrar(persona_nueva)
	assert_str(String(otra.comodidad_en_uso(persona_nueva))).is_not_equal("")


# ── Tope de viajes por visita (feedback del usuario 2026-07-28) ─────────────────────────
# "hay muchos que lo hacen varias veces, eso no es normal, vas 1 vez o 2 como mucho, he visto a 1
# hasta 4 veces". A la ventanilla se va a un trámite, no a merendar.
func test_nadie_va_a_la_maquina_mas_de_dos_veces() -> void:
	var mundo: Array = _mundo()
	mundo[0].construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(mundo[0], mundo[1])
	var persona: RefCounted = _persona()
	paciencia.registrar(persona)
	paciencia._consumidor_de[persona] = true            # aísla la variable: aquí se mide el TOPE
	paciencia.drenar(persona, 12.0)                     # 60: por debajo del umbral

	# Dos viajes: se le permiten (con `minutos` alto la tirada siempre entra).
	assert_bool(paciencia._quizas_ir_a_una_comodidad(persona, DOC, 1000.0)).is_true()
	paciencia._consumir_uso_comodidad(persona, 99.0)    # vuelve del primero
	paciencia.drenar(persona, 12.0)                     # vuelve a bajar del umbral
	assert_bool(paciencia._quizas_ir_a_una_comodidad(persona, DOC, 1000.0)).is_true()
	paciencia._consumir_uso_comodidad(persona, 99.0)
	paciencia.drenar(persona, 12.0)

	# El tercero NO: ya ha ido lo suyo, se queda esperando su turno como todo el mundo.
	assert_bool(paciencia._quizas_ir_a_una_comodidad(persona, DOC, 1000.0)).is_false()


func test_el_viaje_cuenta_aunque_le_llamen_a_media_consumicion() -> void:
	# Se cuenta al LEVANTARSE: si cortarle el café no contara, una llamada le regalaría un viaje.
	var mundo: Array = _mundo()
	mundo[0].construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(mundo[0], mundo[1])
	var persona: RefCounted = _persona()
	paciencia.registrar(persona)
	paciencia._consumidor_de[persona] = true
	paciencia.drenar(persona, 12.0)
	paciencia._quizas_ir_a_una_comodidad(persona, DOC, 1000.0)   # se levanta...
	paciencia.olvidar(persona)                                    # ...y le llaman / se resuelve

	# Otra persona distinta (misma clave lógica no importa aquí): el contador es POR persona.
	var otra: RefCounted = _persona(2)
	paciencia.registrar(otra)
	paciencia._consumidor_de[otra] = true
	paciencia.drenar(otra, 12.0)
	assert_bool(paciencia._quizas_ir_a_una_comodidad(otra, DOC, 1000.0)).is_true()


func test_los_viajes_ya_hechos_sobreviven_al_guardado() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	construccion.construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(construccion, mundo[1])
	var persona: RefCounted = _persona(9)
	paciencia.registrar(persona)
	paciencia._consumidor_de[persona] = true
	paciencia.drenar(persona, 12.0)
	paciencia._quizas_ir_a_una_comodidad(persona, DOC, 1000.0)
	paciencia._consumir_uso_comodidad(persona, 99.0)
	paciencia._quizas_ir_a_una_comodidad(persona, DOC, 1000.0)
	paciencia._consumir_uso_comodidad(persona, 99.0)              # ya lleva 2

	var recuperado: Dictionary = JSON.parse_string(JSON.stringify(paciencia.save()))
	var otra: Node = _paciencia_con(construccion, mundo[1])
	otra.load_state(recuperado)
	var persona_nueva: RefCounted = _persona(9)
	otra.registrar(persona_nueva)
	otra.drenar(persona_nueva, 20.0)

	# Cargar la partida NO le regala viajes nuevos.
	assert_bool(otra._quizas_ir_a_una_comodidad(persona_nueva, DOC, 1000.0)).is_false()


# ── No todo el mundo consume (feedback del usuario 2026-07-28) ──────────────────────────
# "no todos consumen por lo que sea; no todos los que baje la paciencia quieren tomar algo, al igual
# que el agua". Hay gente que no toma nada por muy larga que se le haga la espera.
func test_el_que_no_es_consumidor_no_se_levanta_nunca() -> void:
	var mundo: Array = _mundo()
	mundo[0].construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(mundo[0], mundo[1])
	var persona: RefCounted = _persona()
	paciencia.registrar(persona)
	paciencia.drenar(persona, 20.0)                     # 33: lleva un buen rato
	paciencia._consumidor_de[persona] = false           # de los que no toman nada

	# Ni con la tirada saturada: sencillamente no le apetece.
	assert_bool(paciencia._quizas_ir_a_una_comodidad(persona, DOC, 10000.0)).is_false()
	assert_bool(paciencia.es_consumidor(persona)).is_false()


func test_el_rasgo_no_cambia_a_media_visita() -> void:
	# El mismo ciudadano no puede pasar del vending un minuto y correr hacia él al siguiente.
	var mundo: Array = _mundo()
	mundo[0].construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(mundo[0], mundo[1])
	var persona: RefCounted = _persona()
	paciencia.registrar(persona)
	var primera: bool = paciencia.es_consumidor(persona)
	for i: int in range(20):
		assert_bool(paciencia.es_consumidor(persona)).is_equal(primera)


func test_no_todos_los_de_la_sala_son_consumidores() -> void:
	# Con 40 personas y prob 0.45, tiene que haber de los dos tipos (si salieran todos iguales, el
	# rasgo no estaría haciendo nada). RNG sembrado → resultado estable entre ejecuciones.
	var mundo: Array = _mundo()
	mundo[0].construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(mundo[0], mundo[1])
	var consumidores: int = 0
	for i: int in range(40):
		var persona: RefCounted = _persona(i + 1)
		paciencia.registrar(persona)
		if paciencia.es_consumidor(persona):
			consumidores += 1
	assert_bool(consumidores > 0).is_true()
	assert_bool(consumidores < 40).is_true()


func test_el_rasgo_sobrevive_al_guardado() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	construccion.construir_elemento(&"vending", Vector2i(3, 7))
	var paciencia: Node = _paciencia_con(construccion, mundo[1])
	var persona: RefCounted = _persona(11)
	paciencia.registrar(persona)
	paciencia._consumidor_de[persona] = false          # este no consume

	var recuperado: Dictionary = JSON.parse_string(JSON.stringify(paciencia.save()))
	var otra: Node = _paciencia_con(construccion, mundo[1])
	otra.load_state(recuperado)
	var persona_nueva: RefCounted = _persona(11)
	otra.registrar(persona_nueva)

	# Al cargar sigue sin apetecerle: el rasgo no se vuelve a sortear.
	assert_bool(otra.es_consumidor(persona_nueva)).is_false()
