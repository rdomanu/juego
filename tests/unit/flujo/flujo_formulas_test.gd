# Story 005 (epic flujo) — aforo F6 (AC-FL12) y matemáticas de colas F2-F5 · TR-flow-002 ·
# ADR-0001. Tipo: Logic. PURO y determinista (sin catálogo, sin árbol, sin azar): los valores
# exactos del GDD (26 · 52/260 · 2→1 · 120/60/-1) y los centinelas -1.0 (nunca ∞ ni div/0).
extends GdUnitTestSuite

const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")


func _flujo() -> Node:
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	return flujo


# ── AC-FL12: frontera exacta del aforo — 39/40 entra, 40/40 no ────────────────────────────
func test_hay_plaza_dentro_frontera_exacta() -> void:
	# Arrange
	var flujo: Node = _flujo()

	# Act / Assert — boundary exacto; aforo negativo = "sin límite" (modo sin Construcción).
	assert_bool(flujo.hay_plaza_dentro(39, 40)).is_true()
	assert_bool(flujo.hay_plaza_dentro(40, 40)).is_false()
	assert_bool(flujo.hay_plaza_dentro(1000, -1)).is_true()


# ── AC-FL19: F2 — 390 min operativos / 15 min de media = 26 trámites por puesto ───────────
func test_throughput_puesto_f2() -> void:
	# Arrange
	var flujo: Node = _flujo()

	# Act / Assert — el valor exacto del GDD + el corrupto (duración 0 → 0 con aviso, no ∞).
	assert_int(flujo.throughput_puesto(390.0, 15.0)).is_equal(26)
	assert_int(flujo.throughput_puesto(390.0, 0.0)).is_equal(0)


# ── AC-FL20: F3 — 2 puestos a 26 = 52; a tope Doc (10 puestos) = 260 ──────────────────────
func test_capacidad_servicio_f3() -> void:
	# Arrange
	var flujo: Node = _flujo()

	# Act / Assert
	assert_int(flujo.capacidad_servicio(2, 26)).is_equal(52)
	assert_int(flujo.capacidad_servicio(10, 26)).is_equal(260)
	assert_int(flujo.capacidad_servicio(0, 26)).is_equal(0)


# ── AC-FL21: F4 — 8/h contra capacidad 4/h → ρ=2; con el 2.º puesto → ρ=1; cap 0 → -1.0 ───
func test_factor_carga_f4() -> void:
	# Arrange
	var flujo: Node = _flujo()

	# Act / Assert — el centinela "sin servicio" en vez de ∞.
	assert_float(flujo.factor_carga(8.0, 4.0)).is_equal_approx(2.0, 0.0001)
	assert_float(flujo.factor_carga(8.0, 8.0)).is_equal_approx(1.0, 0.0001)
	assert_float(flujo.factor_carga(8.0, 0.0)).is_equal_approx(-1.0, 0.0001)


# ── AC-FL22: F5 — 8 delante × 15 min: 1 puesto → 120; 2 → 60; 0 puestos → indefinida ──────
func test_espera_estimada_f5() -> void:
	# Arrange
	var flujo: Node = _flujo()

	# Act / Assert — el centinela "indefinida" (-1.0), nunca división por cero.
	assert_float(flujo.espera_estimada(8, 1, 15.0)).is_equal_approx(120.0, 0.0001)
	assert_float(flujo.espera_estimada(8, 2, 15.0)).is_equal_approx(60.0, 0.0001)
	assert_float(flujo.espera_estimada(8, 0, 15.0)).is_equal_approx(-1.0, 0.0001)
