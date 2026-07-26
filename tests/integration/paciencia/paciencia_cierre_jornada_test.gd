# Story paciencia-004 (TR-patience-003 · F3) — la media del día y su cierre. Tipo: Integration.
# DETERMINISTA: visitas anotadas con estados explícitos; catálogo REAL para los pesos de ODAC.
extends GdUnitTestSuite

const PacienciaScript := preload("res://src/feature/paciencia/paciencia.gd")
const ConfigPacienciaScript := preload("res://src/feature/paciencia/config_paciencia.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")


func _paciencia() -> Node:
	var sistema: Node = auto_free(PacienciaScript.new())
	sistema.aplicar_config(ConfigPacienciaScript.new())
	return sistema


## Una visita YA TERMINADA, tal y como la ve el sistema: atendida (con la paciencia que le quedaba al
## ser LLAMADA — 100 = no esperó nada) o marchada. Se le apunta su "recibo" de espera igual que haría
## el tick real, para que la puntuación sea la de verdad y no el caso conservador de una desconocida.
func _visita(
	sistema: Node, servicio: StringName, tramite: StringName, atendida: bool,
	paciencia_al_llamar: float = 100.0
) -> RefCounted:
	var persona: RefCounted = PersonaFlujoScript.new(PersonaScript.new(servicio, tramite, 480), 1)
	persona.estado = (
		PersonaFlujoScript.ESTADO_RESUELTA if atendida else PersonaFlujoScript.ESTADO_ABANDONANDO
	)
	sistema._paciencia_al_llamar[persona] = paciencia_al_llamar
	return persona


# ── AC-PS10 · Antes de la primera jornada, 50 ────────────────────────────────────────────
func test_primera_jornada_sin_datos_sat_50() -> void:
	var sistema: Node = _paciencia()
	assert_float(sistema.sat_cierre_de(&"Documentacion")).is_equal(50.0)
	assert_float(sistema.sat_cierre_de(&"ODAC")).is_equal(50.0)
	assert_float(sistema.sat_actual_de(&"Documentacion")).is_equal(50.0)


# ── AC-PS11 · La media se calcula y el acumulador se resetea ─────────────────────────────
func test_cierre_calcula_media_y_resetea_acumulador() -> void:
	var sistema: Node = _paciencia()
	# Dos visitas atendidas sin espera (80 cada una) y un abandono (0) → media (80+80+0)/3 = 53.33
	sistema.anotar_visita(_visita(sistema, &"Documentacion", &"dni", true))
	sistema.anotar_visita(_visita(sistema, &"Documentacion", &"dni", true))
	sistema.anotar_visita(_visita(sistema, &"Documentacion", &"dni", false))
	assert_float(sistema.sat_actual_de(&"Documentacion")).is_equal_approx(53.33, 0.01)
	sistema.cerrar_jornada()
	assert_float(sistema.sat_cierre_de(&"Documentacion")).is_equal_approx(53.33, 0.01)
	# Acumulador reseteado: la media viva del día nuevo vuelve a ser "lo de ayer".
	assert_float(sistema.sat_actual_de(&"Documentacion")).is_equal_approx(53.33, 0.01)
	sistema.anotar_visita(_visita(sistema, &"Documentacion", &"dni", false))   # un abandono el día nuevo
	assert_float(sistema.sat_actual_de(&"Documentacion")).is_equal(0.0)


# ── AC-PS12 · En ODAC, una Prioritaria pesa 2.5 ──────────────────────────────────────────
func test_odac_pondera_prioritaria_2_5_a_1() -> void:
	var sistema: Node = _paciencia()
	# Prioritaria BIEN atendida (80, peso 2.5) + Normal abandonada (0, peso 1.0)
	# → (80×2.5 + 0×1) / 3.5 = 57.14 (si pesaran igual saldría 40: la urgencia manda más).
	sistema.anotar_visita(_visita(sistema, &"ODAC", &"agresion_sexual", true))
	sistema.anotar_visita(_visita(sistema, &"ODAC", &"hurto", false))
	assert_float(sistema.sat_actual_de(&"ODAC")).is_equal_approx(57.14, 0.05)


func test_prioritaria_abandonada_hunde_mas_que_una_normal() -> void:
	var grave: Node = _paciencia()
	grave.anotar_visita(_visita(grave, &"ODAC", &"agresion_sexual", false))   # urgencia fallada
	grave.anotar_visita(_visita(grave, &"ODAC", &"hurto", true))
	var leve: Node = _paciencia()
	leve.anotar_visita(_visita(leve, &"ODAC", &"hurto", false))              # papeleo fallado
	leve.anotar_visita(_visita(leve, &"ODAC", &"agresion_sexual", true))
	assert_float(grave.sat_actual_de(&"ODAC")).is_less(leve.sat_actual_de(&"ODAC"))


func test_documentacion_no_pondera_por_tipo() -> void:
	var sistema: Node = _paciencia()
	assert_float(sistema.peso_de_visita(_visita(sistema, &"Documentacion", &"dni", true))).is_equal(1.0)
	assert_float(sistema.peso_de_visita(_visita(sistema, &"Documentacion", &"pasaporte", true))).is_equal(1.0)


func test_tipo_desconocido_no_infla_el_peso() -> void:
	var sistema: Node = _paciencia()
	assert_float(sistema.peso_de_visita(_visita(sistema, &"ODAC", &"no_existe_en_el_catalogo", true))).is_equal(1.0)


# ── AC-PS13 · Jornada sin visitas: el cierre NO cambia (ni divide por cero) ──────────────
func test_jornada_sin_visitas_mantiene_el_sat_anterior() -> void:
	var sistema: Node = _paciencia()
	sistema.anotar_visita(_visita(sistema, &"ODAC", &"hurto", true))   # día 1: una visita buena (80)
	sistema.cerrar_jornada()
	assert_float(sistema.sat_cierre_de(&"ODAC")).is_equal(80.0)
	sistema.cerrar_jornada()                                   # día 2: NADIE vino a ODAC
	assert_float(sistema.sat_cierre_de(&"ODAC")).is_equal(80.0)   # sigue el de ayer, no un 0


# ── F5 · La global pondera por volumen (solo HUD) ────────────────────────────────────────
func test_sat_global_pondera_por_volumen_de_visitas() -> void:
	var sistema: Node = _paciencia()
	# Doc: 3 visitas a 80. ODAC: 1 abandono (0, peso 1). Global = (80×3 + 0×1)/4 = 60.
	for i: int in 3:
		sistema.anotar_visita(_visita(sistema, &"Documentacion", &"dni", true))
	sistema.anotar_visita(_visita(sistema, &"ODAC", &"hurto", false))
	assert_float(sistema.sat_global()).is_equal_approx(60.0, 0.01)


func test_sat_global_sin_visitas_es_la_media_de_los_cierres() -> void:
	assert_float(_paciencia().sat_global()).is_equal(50.0)


# ── El orden del cierre: Paciencia (10) ANTES que Economía (20) ──────────────────────────
func test_paciencia_cierra_antes_de_que_economia_cobre() -> void:
	var bus: Node = auto_free(EventBusScript.new())
	var orden: Array = []
	var sistema: Node = _paciencia()
	sistema.usar_bus(bus)
	bus.registrar_ordenado(&"nuevo_dia", 9, func() -> void: orden.append("antes"))
	bus.registrar_ordenado(&"nuevo_dia", 20, func() -> void: orden.append("economia"))
	bus.registrar_ordenado(&"nuevo_dia", 11, func() -> void: orden.append("despues"))
	sistema.anotar_visita(_visita(sistema, &"Documentacion", &"dni", true))
	bus.disparar_ordenado(&"nuevo_dia")
	# El cierre de Paciencia (prio 10) ocurrió entre el espía 9 y el 11, y ANTES del cobro (20).
	assert_array(orden).is_equal(["antes", "despues", "economia"])
	assert_float(sistema.sat_cierre_de(&"Documentacion")).is_equal(80.0)
