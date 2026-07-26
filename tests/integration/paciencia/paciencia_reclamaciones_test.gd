# Story paciencia-006 (TR-patience-004) — reclamaciones: quien se va cabreado deja trabajo.
# Tipo: Integration. DETERMINISTA: la probabilidad se fuerza a 1.0 / 0.0 en los tests (nunca se
# depende del azar) y el RNG es el REAL (RNGService) con semilla fija donde importa.
extends GdUnitTestSuite

const PacienciaScript := preload("res://src/feature/paciencia/paciencia.gd")
const ConfigPacienciaScript := preload("res://src/feature/paciencia/config_paciencia.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")
const RNGScript := preload("res://src/foundation/rng_service/rng_service.gd")


func _sistema(prob: float = 1.0) -> Node:
	var sistema: Node = auto_free(PacienciaScript.new())
	var config: Resource = ConfigPacienciaScript.new()
	config.prob_reclamacion = prob
	sistema.aplicar_config(config)
	var rng: Node = auto_free(RNGScript.new())
	rng.sembrar(12345)
	sistema.usar_rng(rng)
	return sistema


## Una persona ya marchada (estado Abandonando) del servicio y trámite dados.
func _marchada(servicio: StringName, tramite: StringName) -> RefCounted:
	var persona: RefCounted = PersonaFlujoScript.new(PersonaScript.new(servicio, tramite, 600), 1)
	persona.estado = PersonaFlujoScript.ESTADO_ABANDONANDO
	return persona


# ── AC-PS15 · Los dos contadores suben ───────────────────────────────────────────────────
func test_abandono_suma_a_los_dos_contadores() -> void:
	var sistema: Node = _sistema(0.0)   # sin generar reclamación: aquí solo se cuenta
	sistema.procesar_abandono(_marchada(&"Documentacion", &"dni"))
	assert_int(sistema.reclamaciones_jornada).is_equal(1)
	assert_int(sistema.reclamaciones_mes).is_equal(1)


# ── AC-PS16 · Con probabilidad 1, la queja entra en la cola de ODAC ──────────────────────
func test_abandono_doc_con_prob_uno_encola_reclamacion_en_odac() -> void:
	var bus: Node = auto_free(EventBusScript.new())
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.usar_bus(bus)
	# El mundo (Main) es quien admite y encola a quien llega: aquí se replica ese cableado.
	bus.persona_generada.connect(func(ficha: RefCounted) -> void:
		var persona: RefCounted = flujo.admitir(ficha)
		if persona != null:
			flujo.encolar(persona)
	)
	var sistema: Node = _sistema(1.0)
	sistema.usar_bus(bus)
	sistema.procesar_abandono(_marchada(&"Documentacion", &"dni"))
	assert_int(flujo.personas_en_cola(&"ODAC")).is_equal(1)
	var encolada: RefCounted = flujo.personas_de_cola(&"ODAC")[0]
	assert_str(encolada.tramite_id()).is_equal(&"reclamacion")


func test_con_probabilidad_cero_no_se_genera_ninguna() -> void:
	var bus: Node = auto_free(EventBusScript.new())
	var generadas: Array = []
	bus.persona_generada.connect(func(f: RefCounted) -> void: generadas.append(f))
	var sistema: Node = _sistema(0.0)
	sistema.usar_bus(bus)
	for i: int in 10:
		sistema.procesar_abandono(_marchada(&"Documentacion", &"dni"))
	assert_int(generadas.size()).is_equal(0)
	assert_int(sistema.reclamaciones_jornada).is_equal(10)   # contarse, se cuentan igual


# ── AC-PS17 · Sin recursión: una reclamación abandonada NO engendra otra ─────────────────
func test_reclamacion_abandonada_no_genera_otra() -> void:
	var bus: Node = auto_free(EventBusScript.new())
	var generadas: Array = []
	bus.persona_generada.connect(func(f: RefCounted) -> void: generadas.append(f))
	var sistema: Node = _sistema(1.0)   # probabilidad MÁXIMA: si hubiera recursión, sería infinita
	sistema.usar_bus(bus)
	sistema.procesar_abandono(_marchada(&"ODAC", &"reclamacion"))
	assert_int(generadas.size()).is_equal(0)
	assert_int(sistema.reclamaciones_jornada).is_equal(1)   # pero la queja SÍ se cuenta


# ── AC-PS18 · Abandonar una urgencia es GRAVE ───────────────────────────────────────────
func test_abandono_de_prioritaria_marca_grave() -> void:
	var sistema: Node = _sistema(0.0)
	sistema.procesar_abandono(_marchada(&"ODAC", &"agresion_sexual"))
	assert_int(sistema.reclamaciones_graves_jornada).is_equal(1)
	assert_int(sistema.reclamaciones_graves_mes).is_equal(1)


func test_abandono_normal_no_es_grave() -> void:
	var sistema: Node = _sistema(0.0)
	sistema.procesar_abandono(_marchada(&"ODAC", &"hurto"))
	sistema.procesar_abandono(_marchada(&"Documentacion", &"dni"))
	assert_int(sistema.reclamaciones_graves_jornada).is_equal(0)
	assert_int(sistema.reclamaciones_jornada).is_equal(2)


# ── AC-PS20 · El contador mensual se resetea al nuevo mes ───────────────────────────────
func test_nuevo_mes_resetea_el_contador_mensual() -> void:
	var sistema: Node = _sistema(0.0)
	sistema.procesar_abandono(_marchada(&"ODAC", &"agresion_sexual"))
	sistema.procesar_abandono(_marchada(&"Documentacion", &"dni"))
	assert_int(sistema.reclamaciones_mes).is_equal(2)
	sistema._al_nuevo_mes()
	assert_int(sistema.reclamaciones_mes).is_equal(0)
	assert_int(sistema.reclamaciones_graves_mes).is_equal(0)


func test_cerrar_jornada_resetea_el_contador_diario_pero_no_el_mensual() -> void:
	var sistema: Node = _sistema(0.0)
	sistema.procesar_abandono(_marchada(&"Documentacion", &"dni"))
	sistema.cerrar_jornada()
	assert_int(sistema.reclamaciones_jornada).is_equal(0)
	assert_int(sistema.reclamaciones_mes).is_equal(1)   # el mes acumula hasta el nuevo_mes


# ── Determinismo del azar ───────────────────────────────────────────────────────────────
func test_misma_semilla_mismas_reclamaciones() -> void:
	var primera: Array = _tirada_con_semilla(777)
	var segunda: Array = _tirada_con_semilla(777)
	assert_array(primera).is_equal(segunda)
	assert_int(primera.size()).is_greater(0)   # con prob 0.4 y 20 abandonos, alguna cae seguro


## 20 abandonos con la misma semilla; devuelve en qué iteraciones salió reclamación.
func _tirada_con_semilla(semilla: int) -> Array:
	var bus: Node = auto_free(EventBusScript.new())
	var sistema: Node = auto_free(PacienciaScript.new())
	sistema.aplicar_config(ConfigPacienciaScript.new())   # prob semilla 0.4
	var rng: Node = auto_free(RNGScript.new())
	rng.sembrar(semilla)
	sistema.usar_rng(rng)
	sistema.usar_bus(bus)
	var salidas: Array = []
	# ⚠️ Gotcha registrado del proyecto: las lambdas capturan las locales POR VALOR — un `int`
	# contador nunca se actualizaría fuera. Se usa un Array (por referencia).
	var emitidas: Array = []
	bus.persona_generada.connect(func(_f: RefCounted) -> void: emitidas.append(1))
	for i: int in 20:
		var previo: int = emitidas.size()
		sistema.procesar_abandono(_marchada(&"Documentacion", &"dni"))
		if emitidas.size() > previo:
			salidas.append(i)
	return salidas
