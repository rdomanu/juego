# Story 004 (epic demanda) — nivel BAJA/MEDIA/ALTA (DG12) · TR-demand-003 · ADR-0001. Tipo: Logic.
# DETERMINISTA (sin azar: clasificación pura + guarda anti-duplicado de la señal).
# Aislamiento: nodo con .new() sin árbol; bus ESPÍA propio (instancia fresca del script del bus).
extends GdUnitTestSuite

const DemandaScript := preload("res://src/core/demanda/demanda.gd")
const ConfigDemandaScript := preload("res://src/core/demanda/config_demanda.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

const DOC := &"Documentacion"


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Demanda fresca (Pozuelo inyectado) con bus espía opcional.
func _demanda(bus: Node = null) -> Node:
	var demanda: Node = auto_free(DemandaScript.new())
	if bus != null:
		demanda.usar_bus(bus)
	demanda.aplicar_config(ConfigDemandaScript.new())
	demanda.fijar_poblacion(90000)
	return demanda


# ── AC-DM15: los tres tramos con los umbrales del config (40/60) ──────────────────────────
func test_clasifica_los_tres_tramos() -> void:
	# Arrange
	var demanda: Node = _demanda()

	# Act / Assert — enero 27 → BAJA · base 45 → MEDIA · verano 67.5 → ALTA.
	assert_str(String(demanda.clasificar_nivel(27.0))).is_equal("BAJA")
	assert_str(String(demanda.clasificar_nivel(45.0))).is_equal("MEDIA")
	assert_str(String(demanda.clasificar_nivel(67.5))).is_equal("ALTA")


# ── AC-DM15 (bordes): la regla fijada es `< bajo` → BAJA · `≥ alto` → ALTA ────────────────
func test_bordes_de_umbral() -> void:
	# Arrange
	var demanda: Node = _demanda()

	# Act / Assert — exactamente EN el umbral: 40 ya no es BAJA; 60 ya es ALTA.
	assert_str(String(demanda.clasificar_nivel(40.0))).is_equal("MEDIA")
	assert_str(String(demanda.clasificar_nivel(60.0))).is_equal("ALTA")
	assert_str(String(demanda.clasificar_nivel(39.999))).is_equal("BAJA")


# ── La señal se emite SOLO al cambiar de tramo (guarda anti-duplicado) ────────────────────
func test_senal_solo_al_cambiar() -> void:
	# Arrange — bus espía; asentar el nivel inicial (MEDIA) y limpiar la captura.
	var bus: Node = auto_free(EventBusScript.new())
	var niveles: Array = []
	bus.nivel_demanda_cambiado.connect(func(n: StringName) -> void: niveles.append(String(n)))
	var demanda: Node = _demanda(bus)
	demanda._recalcular_nivel()
	niveles.clear()

	# Act 1 — recalcular 3 veces con el MISMO volumen.
	demanda._recalcular_nivel()
	demanda._recalcular_nivel()
	demanda._recalcular_nivel()

	# Assert 1 — cero emisiones (nada cambió).
	assert_int(niveles.size()).is_equal(0)

	# Act 2 — el volumen sube de tramo (factor ×1.5 → 67.5, ALTA).
	demanda.factor_crecimiento_nivel = 1.5
	demanda._recalcular_nivel()

	# Assert 2 — exactamente UNA emisión con el tramo nuevo.
	assert_array(niveles).is_equal(["ALTA"])


# ── El getter deriva el tramo sin efectos laterales (lectura pull para la UI) ─────────────
func test_getter_deriva_sin_efectos() -> void:
	# Arrange — sin bus y sin recalcular nunca.
	var demanda: Node = _demanda()

	# Act / Assert — deriva MEDIA (45/día con umbrales 40/60), estable entre llamadas.
	assert_str(String(demanda.nivel_demanda())).is_equal("MEDIA")
	assert_str(String(demanda.nivel_demanda())).is_equal("MEDIA")


# ── El `nuevo_dia` (prio 40) reevalúa el nivel además de resetear el contador ─────────────
func test_nuevo_dia_reevalua_nivel() -> void:
	# Arrange — nivel asentado en MEDIA; el volumen cambia antes de la medianoche.
	var bus: Node = auto_free(EventBusScript.new())
	var niveles: Array = []
	bus.nivel_demanda_cambiado.connect(func(n: StringName) -> void: niveles.append(String(n)))
	var demanda: Node = _demanda(bus)
	demanda._recalcular_nivel()
	niveles.clear()
	demanda.llegadas_hoy = 12
	demanda.factor_crecimiento_nivel = 1.5

	# Act
	demanda._al_nuevo_dia()

	# Assert — contador reseteado y UNA emisión con el tramo nuevo.
	assert_int(demanda.llegadas_hoy).is_equal(0)
	assert_array(niveles).is_equal(["ALTA"])


# ── Clamp: umbrales incoherentes (bajo ≥ alto) → defaults 40/60 con aviso ─────────────────
func test_umbrales_incoherentes_clampan() -> void:
	# Arrange — config corrupto (el push_warning esperado es intencional).
	var config: Resource = ConfigDemandaScript.new()
	config.umbral_nivel_bajo = 80.0
	config.umbral_nivel_alto = 50.0
	var demanda: Node = auto_free(DemandaScript.new())

	# Act
	demanda.aplicar_config(config)

	# Assert
	assert_float(demanda.umbral_nivel_bajo).is_equal_approx(40.0, 0.0001)
	assert_float(demanda.umbral_nivel_alto).is_equal_approx(60.0, 0.0001)
