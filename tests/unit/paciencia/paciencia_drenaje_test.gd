# Story paciencia-001 (TR-patience-001) — la barra individual y F1, el drenaje. Tipo: Logic.
# DETERMINISTA: matemática pura con minutos inyectados a mano (ni reloj ni RNG en esta story).
# Los valores esperados están calculados A MANO desde el GDD, no copiados de la implementación.
extends GdUnitTestSuite

const PacienciaScript := preload("res://src/feature/paciencia/paciencia.gd")
const ConfigPacienciaScript := preload("res://src/feature/paciencia/config_paciencia.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")


# ── Fixture ──────────────────────────────────────────────────────────────────────────────
## Paciencia con los valores SEMILLA del GDD (tolerancia 30, multiplicadores neutros).
func _paciencia() -> Node:
	var sistema: Node = auto_free(PacienciaScript.new())
	sistema.aplicar_config(ConfigPacienciaScript.new())
	return sistema


## Una persona DEL FLUJO (el contrato real de Paciencia: de ella lee servicio, turno y estado; la
## ficha de Demanda suelta no vale como clave — desde la story 007 se necesita `servicio()`+turno
## para poder reenganchar su barra al cargar una partida).
func _persona(turno: int = 1) -> RefCounted:
	return PersonaFlujoScript.new(PersonaScript.new(&"Documentacion", &"dni", 480), turno)


# ── AC-PS01 · Entra con la barra llena ───────────────────────────────────────────────────
func test_coge_turno_paciencia_100() -> void:
	var sistema: Node = _paciencia()
	var persona: RefCounted = _persona()
	sistema.registrar(persona)
	assert_float(sistema.paciencia_de(persona)).is_equal(100.0)
	assert_bool(sistema.tiene(persona)).is_true()


func test_registrar_dos_veces_no_regala_paciencia() -> void:
	var sistema: Node = _paciencia()
	var persona: RefCounted = _persona()
	sistema.registrar(persona)
	sistema.drenar(persona, 10.0)          # 10 min neutros → 100 − 3.33×10 = 66.67
	sistema.registrar(persona)             # re-registro accidental: NO debe rellenar la barra
	assert_float(sistema.paciencia_de(persona)).is_equal_approx(66.67, 0.01)


func test_persona_no_registrada_devuelve_centinela() -> void:
	var sistema: Node = _paciencia()
	assert_float(sistema.paciencia_de(_persona())).is_equal(sistema.SIN_PACIENCIA)


# ── AC-PS02 · Neutro: 30 minutos y a la calle ────────────────────────────────────────────
func test_neutro_treinta_minutos_llega_a_cero() -> void:
	var sistema: Node = _paciencia()
	var persona: RefCounted = _persona()
	sistema.registrar(persona)
	# Tasa = 100/30 = 3.333 puntos/min → en 30 min consume exactamente los 100.
	assert_float(sistema.tasa_drenaje()).is_equal_approx(3.3333, 0.001)
	assert_float(sistema.drenar(persona, 30.0)).is_equal(0.0)
	assert_float(sistema.minutos_hasta_agotar()).is_equal_approx(30.0, 0.001)


func test_la_paciencia_no_baja_de_cero() -> void:
	var sistema: Node = _paciencia()
	var persona: RefCounted = _persona()
	sistema.registrar(persona)
	sistema.drenar(persona, 100.0)   # muchísimo más de lo que aguanta
	assert_float(sistema.paciencia_de(persona)).is_equal(0.0)


# ── AC-PS03 · Hacinamiento: la misma espera se hace más larga ────────────────────────────
func test_hacinamiento_uno_y_medio_llega_a_cero_en_veinte() -> void:
	var sistema: Node = _paciencia()
	# Sala de aforo 10 con 15 dentro → exceso 5 → mult = 1 + 1.0 × 5/10 = 1.5 (k semilla 1.0).
	var mult: float = sistema.mult_hacinamiento(15, 10)
	assert_float(mult).is_equal_approx(1.5, 0.001)
	# Con ×1.5 la tasa es 5.0 puntos/min → 100/5 = 20 minutos exactos.
	assert_float(sistema.minutos_hasta_agotar(mult)).is_equal_approx(20.0, 0.001)
	var persona: RefCounted = _persona()
	sistema.registrar(persona)
	assert_float(sistema.drenar(persona, 20.0, mult)).is_equal(0.0)


func test_sala_dentro_de_aforo_no_acelera() -> void:
	var sistema: Node = _paciencia()
	assert_float(sistema.mult_hacinamiento(10, 10)).is_equal(1.0)   # justo a aforo
	assert_float(sistema.mult_hacinamiento(3, 10)).is_equal(1.0)    # holgada


func test_sin_aforo_medible_no_acelera() -> void:
	var sistema: Node = _paciencia()
	assert_float(sistema.mult_hacinamiento(5, 0)).is_equal(1.0)     # sin sala que medir


# ── AC-PS05 · El ánimo derivado (umbrales 66/33 — los tres casos del GDD) ────────────────
func test_animo_por_umbrales_66_33() -> void:
	var sistema: Node = _paciencia()
	assert_str(sistema.animo_de(80.0)).is_equal(sistema.ANIMO_CONTENTO)     # 80 > 66  → 🟢
	assert_str(sistema.animo_de(50.0)).is_equal(sistema.ANIMO_IMPACIENTE)   # 33-66    → 🟡
	assert_str(sistema.animo_de(20.0)).is_equal(sistema.ANIMO_AL_LIMITE)    # 20 < 33  → 🔴


func test_animo_en_los_bordes_exactos() -> void:
	var sistema: Node = _paciencia()
	# El umbral alto NO es contento (contento es ESTRICTAMENTE por encima) y el bajo NO es al límite.
	assert_str(sistema.animo_de(66.0)).is_equal(sistema.ANIMO_IMPACIENTE)
	assert_str(sistema.animo_de(33.0)).is_equal(sistema.ANIMO_IMPACIENTE)
	assert_str(sistema.animo_de(0.0)).is_equal(sistema.ANIMO_AL_LIMITE)


func test_animo_de_persona_no_registrada_es_conservador() -> void:
	var sistema: Node = _paciencia()
	assert_str(sistema.animo_de_persona(_persona())).is_equal(sistema.ANIMO_AL_LIMITE)


# ── Config: clamps y fallbacks (patrón del proyecto) ─────────────────────────────────────
func test_config_invalida_cae_a_defaults_con_aviso() -> void:
	var sistema: Node = auto_free(PacienciaScript.new())
	sistema.aplicar_config(null)
	assert_float(sistema.tolerancia_base_min).is_equal(30.0)
	assert_float(sistema.umbral_animo_alto).is_equal(66.0)


func test_config_fuera_de_rango_se_clampa() -> void:
	var sistema: Node = auto_free(PacienciaScript.new())
	var config: Resource = ConfigPacienciaScript.new()
	config.tolerancia_base_min = -5.0     # imposible: sería división por cero
	config.k_hacinamiento = 99.0          # fuera del rango razonable
	sistema.aplicar_config(config)
	assert_float(sistema.tolerancia_base_min).is_equal(1.0)
	assert_float(sistema.k_hacinamiento).is_equal(10.0)


func test_umbrales_cruzados_se_ordenan() -> void:
	var sistema: Node = auto_free(PacienciaScript.new())
	var config: Resource = ConfigPacienciaScript.new()
	config.umbral_animo_alto = 20.0
	config.umbral_animo_bajo = 70.0       # cruzados: dejarían una franja imposible
	sistema.aplicar_config(config)
	assert_float(sistema.umbral_animo_alto).is_equal(70.0)
	assert_float(sistema.umbral_animo_bajo).is_equal(20.0)


func test_tolerancia_cero_no_divide_por_cero() -> void:
	var sistema: Node = auto_free(PacienciaScript.new())
	sistema.aplicar_config(ConfigPacienciaScript.new())
	sistema.tolerancia_base_min = 0.0     # forzado a mano (el clamp no lo permitiría)
	assert_float(sistema.tasa_drenaje()).is_equal(0.0)
	assert_float(sistema.minutos_hasta_agotar()).is_equal(-1.0)   # centinela, nunca ∞


# ── Alta y baja ──────────────────────────────────────────────────────────────────────────
func test_olvidar_saca_a_la_persona_del_sistema() -> void:
	var sistema: Node = _paciencia()
	var persona: RefCounted = _persona()
	sistema.registrar(persona)
	assert_int(sistema.personas_vigiladas()).is_equal(1)
	sistema.olvidar(persona)
	assert_bool(sistema.tiene(persona)).is_false()
	assert_int(sistema.personas_vigiladas()).is_equal(0)


func test_el_drenaje_es_independiente_por_persona() -> void:
	var sistema: Node = _paciencia()
	var primera: RefCounted = _persona(1)
	var segunda: RefCounted = _persona(2)
	sistema.registrar(primera)
	sistema.registrar(segunda)
	sistema.drenar(primera, 15.0)   # media espera: 100 − 3.33×15 = 50
	assert_float(sistema.paciencia_de(primera)).is_equal_approx(50.0, 0.01)
	assert_float(sistema.paciencia_de(segunda)).is_equal(100.0)
