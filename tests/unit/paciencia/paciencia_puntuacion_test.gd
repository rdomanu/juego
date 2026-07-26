# Story paciencia-003 (F2) — cuánto puntúa cada visita. Tipo: Logic.
# DETERMINISTA: fórmula pura con entradas explícitas. Los esperados son los EJEMPLOS DEL GDD,
# calculados a mano (80×1.0×1.0 · 80×0.75×1.0 · 80×0.5×0.7 · 80×1.0×1.3 → clamp).
extends GdUnitTestSuite

const PacienciaScript := preload("res://src/feature/paciencia/paciencia.gd")
const ConfigPacienciaScript := preload("res://src/feature/paciencia/config_paciencia.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")


func _paciencia() -> Node:
	var sistema: Node = auto_free(PacienciaScript.new())
	sistema.aplicar_config(ConfigPacienciaScript.new())
	return sistema


# ── AC-PS06 · Atendida sin esperar y con trato normal ────────────────────────────────────
func test_atendida_sin_espera_trato_neutro_puntua_80() -> void:
	assert_float(_paciencia().puntuacion_atendida(0.0, 1.0)).is_equal(80.0)


# ── AC-PS07 · Al límite y con mal trato ──────────────────────────────────────────────────
func test_atendida_al_limite_con_mal_trato_puntua_28() -> void:
	# Consumió los 100 puntos → factor_espera = 1 − 0.5 = 0.5 → 80 × 0.5 × 0.7 = 28.
	assert_float(_paciencia().puntuacion_atendida(100.0, 0.7)).is_equal_approx(28.0, 0.01)


func test_espera_media_puntua_sesenta() -> void:
	# Consumió 50 → factor_espera = 0.75 → 80 × 0.75 × 1.0 = 60 (ejemplo del GDD).
	assert_float(_paciencia().puntuacion_atendida(50.0, 1.0)).is_equal_approx(60.0, 0.01)


# ── AC-PS09 · El techo es 100 ────────────────────────────────────────────────────────────
func test_puntuacion_por_encima_de_cien_se_clampa() -> void:
	# 80 × 1.0 × 1.3 = 104 → 100.
	assert_float(_paciencia().puntuacion_atendida(0.0, 1.3)).is_equal(100.0)


func test_puntuacion_nunca_es_negativa() -> void:
	assert_float(_paciencia().puntuacion_atendida(100.0, -5.0)).is_equal(0.0)


func test_consumida_fuera_de_rango_se_acota() -> void:
	var sistema: Node = _paciencia()
	assert_float(sistema.puntuacion_atendida(500.0, 1.0)).is_equal(40.0)   # como si fuera 100
	assert_float(sistema.puntuacion_atendida(-20.0, 1.0)).is_equal(80.0)   # como si fuera 0


# ── AC-PS08 · El abandono puntúa CERO ────────────────────────────────────────────────────
func test_abandono_puntua_cero() -> void:
	assert_float(_paciencia().puntuacion_de_visita(_persona_abandonando())).is_equal(0.0)


## Una PersonaFlujo REAL puesta en estado Abandonando (sin dobles: la clase es barata y así el test
## comprueba el contrato de verdad).
func _persona_abandonando() -> RefCounted:
	var persona: RefCounted = PersonaFlujoScript.new(PersonaScript.new(&"Documentacion", &"dni", 480), 1)
	persona.estado = PersonaFlujoScript.ESTADO_ABANDONANDO
	return persona


# ── La espera consumida se mide con lo que le quedaba AL SER LLAMADA ─────────────────────
func test_consumida_de_persona_desconocida_es_total() -> void:
	assert_float(_paciencia().paciencia_consumida_de(_persona_abandonando())).is_equal(100.0)


# ── Config ───────────────────────────────────────────────────────────────────────────────
func test_knobs_de_puntuacion_se_clampan() -> void:
	var sistema: Node = auto_free(PacienciaScript.new())
	var config: Resource = ConfigPacienciaScript.new()
	config.puntuacion_base = 500.0
	config.k_espera = 9.0
	sistema.aplicar_config(config)
	assert_float(sistema.puntuacion_base).is_equal(100.0)
	assert_float(sistema.k_espera).is_equal(1.0)
