# Horario provisional 2026-07-25 (epic flujo) — "los funcionarios se van al cierre": pasada la hora
# (cierre_doc_min) los puestos Doc cierran solos AL VACIAR su cola admitida y REABREN solos en
# apertura_doc_min; el cierre MANUAL del jugador NO se reabre solo. PROVISIONAL en Flujo hasta
# Documentación #8. Tipo: Integration. DETERMINISTA (ticks manuales de 1 min; catálogo, Personal y
# reloj REALES; el reloj SIN árbol solo da la hora vía minutos_juego). SIN Construcción: sin ella el
# aforo es ilimitado y todos entran dentro (aísla la variable del horario).
extends GdUnitTestSuite

const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")


# ── Fixture ──────────────────────────────────────────────────────────────────────────────
## Mundo con doc_1 (puesto_doc_general) y odac_1 (puesto_odac) registrados y DOTADOS, y un reloj
## inyectado (sin árbol) a la hora `min_dia`. Devuelve [flujo, tiempo].
func _mundo(min_dia: float) -> Array:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	# El cansancio (Bienestar #13) ralentiza al agente segun avanza la jornada: aqui se APAGA
	# para aislar la variable bajo prueba, igual que `velocidad_camino_celdas_min = 0.0`.
	personal.k_cansancio_rendimiento = 0.0
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.velocidad_camino_celdas_min = 0.0   # aísla la variable: el camino se testea en flujo_camino_test
	flujo.usar_personal(personal)
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")
	_asignar_agente(personal, &"doc_1", &"ag_doc", "Ana Ruiz")
	personal.registrar_puesto(&"odac_1", &"puesto_odac")
	flujo.registrar_puesto_flujo(&"odac_1", &"puesto_odac")
	_asignar_agente(personal, &"odac_1", &"ag_odac", "Bea Soto")
	var tiempo: Node = auto_free(TiempoScript.new())   # SIN árbol: no empuja, solo da la hora
	tiempo.minutos_juego = min_dia
	flujo.usar_tiempo(tiempo)
	return [flujo, tiempo]


func _asignar_agente(
	personal: Node, puesto: StringName, tipo: StringName, nombre: String
) -> RefCounted:
	var agente: RefCounted = AgenteScript.new(nombre, tipo, AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)
	personal.plantilla.append(agente)
	personal.asignar(agente, puesto)
	return agente


func _dni_admitido(flujo: Node) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 511.0))
	flujo.encolar(persona)
	return persona


# ── (a) NO cierra con cola admitida; cierra AL vaciarse; (b) REABRE a la apertura ─────────
func test_horario_doc_cierra_al_vaciar_y_reabre_en_apertura() -> void:
	# Arrange — reloj a las 14:20 (860, dentro de horario) para que la puerta admita 1 dni.
	var mundo: Array = _mundo(860.0)
	var flujo: Node = mundo[0]
	var tiempo: Node = mundo[1]
	var p1: RefCounted = _dni_admitido(flujo)

	# Act — 1er tick EN horario: doc_1 la empareja y (camino 0) arranca la atención el mismo tick.
	flujo._al_tick(1.0)
	assert_str(String(p1.estado)).is_equal("en_atencion")

	# El reloj cruza el cierre (871 ≥ 870): FUERA de horario, pero con atención EN CURSO el puesto
	# NO cierra a medias (AC-FL24) — sigue atendiendo hasta vaciar la cola admitida.
	tiempo.minutos_juego = 871.0
	for i: int in range(11):
		flujo._al_tick(1.0)
		assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("atendiendo")

	# El tick 12 completa la atención: cola vacía + fuera de horario → los funcionarios se van.
	flujo._al_tick(1.0)
	assert_str(String(p1.estado)).is_equal("resuelta")
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("cerrado")
	# Un tick más fuera de horario lo mantiene cerrado (idempotente).
	flujo._al_tick(1.0)
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("cerrado")

	# (b) — al llegar la apertura (480 = 08:00) el puesto reabre SOLO → Libre (dotado, sin persona).
	tiempo.minutos_juego = 480.0
	flujo._al_tick(1.0)
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("libre")


# ── (c) El cierre MANUAL del jugador NO se reabre solo (el jugador manda) ──────────────────
func test_cierre_manual_no_lo_reabre_el_horario() -> void:
	# Arrange — reloj en horario (500 = 08:20); el jugador cierra doc_1 (sin atención en curso).
	var mundo: Array = _mundo(500.0)
	var flujo: Node = mundo[0]
	var tiempo: Node = mundo[1]
	flujo.cerrar_puesto(&"doc_1")
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("cerrado")

	# Act / Assert — pasa la hora de cierre: sigue cerrado (nada que cerrar, ya estaba).
	tiempo.minutos_juego = 871.0
	flujo._al_tick(1.0)
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("cerrado")
	# Vuelve la hora de horario: el horario NO reabre un cierre manual (cierre_horario == false).
	tiempo.minutos_juego = 500.0
	flujo._al_tick(1.0)
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("cerrado")


# ── (d) ODAC es 24 h: el horario Doc no lo afecta ────────────────────────────────────────
func test_odac_no_le_afecta_el_horario_doc() -> void:
	# Arrange — reloj fuera del horario Doc (871); odac_1 sin cola.
	var mundo: Array = _mundo(871.0)
	var flujo: Node = mundo[0]

	# Act / Assert — el tick no cierra odac_1 (servicio ODAC ≠ Documentación) → sigue Libre.
	flujo._al_tick(1.0)
	assert_str(String(flujo.estado_de_puesto(&"odac_1"))).is_equal("libre")
