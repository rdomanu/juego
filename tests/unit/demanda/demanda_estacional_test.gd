# Story 005 (epic demanda) — estacionalidad DG13 y eventos DG11 · TR-demand-001 · ADR-0001/0002.
# Tipo: Logic. DETERMINISTA: activación por calendario (sin azar) + RNGService re-sembrado donde se
# cuentan proporciones. Aislamiento: nodos con .new() sin árbol salvo el test de orden (dispatcher real).
extends GdUnitTestSuite

const DemandaScript := preload("res://src/core/demanda/demanda.gd")
const ConfigDemandaScript := preload("res://src/core/demanda/config_demanda.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")

const DOC := &"Documentacion"
const ODAC := &"ODAC"


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Demanda con reloj local inyectado (para leer `mes`) y bus espía opcional. Devuelve [demanda, tiempo].
func _mundo(poblacion: int = 90000, config: Resource = null, bus: Node = null) -> Array:
	var tiempo: Node = auto_free(TiempoScript.new())
	var demanda: Node = auto_free(DemandaScript.new())
	if bus != null:
		demanda.usar_bus(bus)
	demanda.usar_tiempo(tiempo)
	if config == null:
		config = ConfigDemandaScript.new()
	demanda.aplicar_config(config)
	demanda.fijar_poblacion(poblacion)
	return [demanda, tiempo]


## Cuenta la frecuencia de un trámite en N ticks equilibrados (3 fichas/tick) en el pico de las 08:30.
func _frecuencia_de(demanda: Node, id_tramite: StringName, ticks: int) -> float:
	var aciertos: int = 0
	var total: int = 0
	for i: int in range(ticks):
		for ficha: RefCounted in demanda.procesar_avance(1.0, 510.0):
			total += 1
			if ficha.tramite_id == id_tramite:
				aciertos += 1
	return float(aciertos) / float(total)


# ── DG13: el mes fija el multiplicador de Documentación (ODAC intacto) y mueve el nivel ───
func test_mult_estacional_por_mes() -> void:
	# Arrange — nivel asentado en MEDIA; espía de nivel conectado.
	var bus: Node = auto_free(EventBusScript.new())
	var niveles: Array = []
	bus.nivel_demanda_cambiado.connect(func(n: StringName) -> void: niveles.append(String(n)))
	var mundo: Array = _mundo(90000, null, bus)
	var demanda: Node = mundo[0]
	var tiempo: Node = mundo[1]
	demanda._recalcular_nivel()
	niveles.clear()

	# Act / Assert — junio ×1.5 → 67.5 y ALTA; enero ×0.6 → 27 y BAJA; abril ×1.0 → 45 y MEDIA.
	tiempo.mes = 6
	demanda._al_nuevo_mes()
	assert_float(demanda.demanda_dia(DOC)).is_equal_approx(67.5, 0.0001)
	assert_float(demanda.demanda_dia(ODAC)).is_equal_approx(36.0, 0.0001)

	tiempo.mes = 1
	demanda._al_nuevo_mes()
	assert_float(demanda.demanda_dia(DOC)).is_equal_approx(27.0, 0.0001)

	tiempo.mes = 4
	demanda._al_nuevo_mes()
	assert_float(demanda.demanda_dia(DOC)).is_equal_approx(45.0, 0.0001)
	assert_array(niveles).is_equal(["ALTA", "BAJA", "MEDIA"])


# ── Orden ADR-0001: el handler de Demanda corre en `nuevo_mes` con prioridad 30 ───────────
func test_nuevo_mes_en_prioridad_30() -> void:
	# Arrange — Demanda se registra sola al entrar al árbol; espías 29 y 31 leen el mult vigente.
	var bus: Node = auto_free(EventBusScript.new())
	var tiempo: Node = auto_free(TiempoScript.new())
	var demanda: Node = auto_free(DemandaScript.new())
	demanda.usar_bus(bus)
	demanda.usar_tiempo(tiempo)
	var capturas: Array = []
	bus.registrar_ordenado(&"nuevo_mes", 29, func() -> void: capturas.append(demanda.mult_estacional_vigente()))
	bus.registrar_ordenado(&"nuevo_mes", 31, func() -> void: capturas.append(demanda.mult_estacional_vigente()))
	tiempo.mes = 4   # el _ready deriva el mult del mes (abril ×1.0); LUEGO llega junio
	add_child(demanda)
	tiempo.mes = 6

	# Act
	bus.disparar_ordenado(&"nuevo_mes")

	# Assert — el espía 29 ve el mult AÚN a 1.0; el 31 ya ve el 1.5 de junio (Demanda corrió en 30).
	assert_array(capturas).is_equal([1.0, 1.5])


# ── DG11: el evento se activa por calendario y expira al agotar sus jornadas ──────────────
func test_evento_activa_y_expira() -> void:
	# Arrange
	var mundo: Array = _mundo()
	var demanda: Node = mundo[0]
	var tiempo: Node = mundo[1]
	tiempo.mes = 12

	# Act — diciembre dispara "vacaciones" (3 jornadas).
	demanda._al_nuevo_mes()

	# Assert — activo con 3 jornadas; sobrevive 2 medianoche y expira a la 3ª.
	assert_str(String(demanda.evento_activo())).is_equal("vacaciones")
	assert_int(demanda.evento_jornadas_restantes()).is_equal(3)
	demanda._al_nuevo_dia()
	demanda._al_nuevo_dia()
	assert_str(String(demanda.evento_activo())).is_equal("vacaciones")
	assert_int(demanda.evento_jornadas_restantes()).is_equal(1)
	demanda._al_nuevo_dia()
	assert_str(String(demanda.evento_activo())).is_equal("")


# ── AC-DM14 (Doc): "vacaciones" sube la proporción de pasaporte y vuelve al expirar ───────
func test_evento_sube_pasaporte_en_doc() -> void:
	# Arrange — solo Doc, densidad equilibrada (1.2M hab → 3/min); semilla fija.
	RNGService.sembrar(77)
	var config: Resource = ConfigDemandaScript.new()
	config.tasa_base_odac = 0.0
	var mundo: Array = _mundo(1200000, config)
	var demanda: Node = mundo[0]

	# Act — frecuencia sin evento, con evento (peso pasaporte ×2), y tras expirar.
	var sin_evento: float = _frecuencia_de(demanda, &"pasaporte", 700)
	demanda._activar_eventos_del_mes(12)
	var con_evento: float = _frecuencia_de(demanda, &"pasaporte", 700)
	for i: int in range(3):
		demanda._al_nuevo_dia()
	var tras_expirar: float = _frecuencia_de(demanda, &"pasaporte", 700)

	# Assert — base ≈0.35; con ×2 ≈ 0.70/1.35 ≈ 0.52; al expirar vuelve al perfil regular.
	assert_float(sin_evento).is_equal_approx(0.35, 0.05)
	assert_float(con_evento).is_equal_approx(0.518, 0.05)
	assert_bool(con_evento > sin_evento + 0.08).is_true()
	assert_float(tras_expirar).is_equal_approx(0.35, 0.05)


# ── AC-DM14 (ODAC): "vacaciones" sube permiso_viaje (peso ×3) ─────────────────────────────
func test_evento_sube_permiso_viaje_en_odac() -> void:
	# Arrange — solo ODAC, densidad equilibrada (10.8M hab → 3/min); semilla fija.
	RNGService.sembrar(88)
	var config: Resource = ConfigDemandaScript.new()
	config.tasa_base_doc = 0.0
	var mundo: Array = _mundo(10800000, config)
	var demanda: Node = mundo[0]

	# Act
	var sin_evento: float = _frecuencia_de(demanda, &"permiso_viaje", 700)
	demanda._activar_eventos_del_mes(12)
	var con_evento: float = _frecuencia_de(demanda, &"permiso_viaje", 700)

	# Assert — base ≈0.04; con ×3 ≈ 0.12/1.08 ≈ 0.111 (más del doble).
	assert_float(sin_evento).is_equal_approx(0.04, 0.02)
	assert_float(con_evento).is_equal_approx(0.111, 0.03)
	assert_bool(con_evento > sin_evento * 2.0).is_true()


# ── Edge: un evento que multiplica un trámite inexistente avisa y NO rompe la elección ────
func test_evento_con_tramite_inexistente_avisa_y_sigue() -> void:
	# Arrange — evento corrupto (el push_warning esperado es intencional); semilla fija.
	RNGService.sembrar(9)
	var config: Resource = ConfigDemandaScript.new()
	var eventos_corruptos: Array[Dictionary] = [
		{
			"id": &"raro",
			"meses_inicio": [3],
			"duracion_jornadas": 2,
			"mult_peso": {&"no_existe": 5.0},
		},
	]
	config.eventos = eventos_corruptos
	config.tasa_base_odac = 0.0
	var mundo: Array = _mundo(1200000, config)
	var demanda: Node = mundo[0]

	# Act — se activa (con aviso) y la generación sigue funcionando con el perfil regular.
	demanda._activar_eventos_del_mes(3)
	var fichas: Array = demanda.procesar_avance(1.0, 510.0)

	# Assert
	assert_str(String(demanda.evento_activo())).is_equal("raro")
	assert_int(fichas.size()).is_equal(3)
