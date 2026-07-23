# Story 001 (epic personal) — el Agente y sus fórmulas F1-F4 · TR-staff-001 · ADR-0003/0002.
# Tipo: Logic. DETERMINISTA (sin azar, sin reloj; config inyectado; el catálogo REAL solo para los
# salarios base — Datos autoload de la suite).
# Aislamiento: nodo con .new() sin árbol (no corre _ready → no carga el .tres real salvo donde se quiere).
extends GdUnitTestSuite

const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Personal fresco con config default aplicado.
func _personal() -> Node:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	return personal


## Agente ag_doc Policía con los 4 atributos dados (orden: rapidez, trato, salud, motivacion).
func _agente(r: int, t: int, s: int, m: int) -> RefCounted:
	return AgenteScript.new("Test García", &"ag_doc", AgenteScript.RANGO_POLICIA, r, t, s, m)


# ── AC-PE01: la instancia lleva identidad completa; Mando solo en Oficiales ───────────────
func test_agente_tiene_identidad_completa() -> void:
	# Arrange / Act — un Oficial y un Policía.
	var oficial: RefCounted = AgenteScript.new(
		"Elena Castro", &"ag_odac", AgenteScript.RANGO_OFICIAL, 4, 3, 4, 4, 4
	)
	var policia: RefCounted = _agente(3, 3, 3, 3)

	# Assert — campos completos; el Oficial lleva Mando ≥ 1; el Policía SIEMPRE 0 (aunque se intente).
	assert_str(oficial.nombre).is_equal("Elena Castro")
	assert_str(String(oficial.tipo_id)).is_equal("ag_odac")
	assert_str(String(oficial.rango)).is_equal("oficial")
	assert_int(oficial.mando).is_equal(4)
	assert_int(policia.mando).is_equal(0)
	policia.mando = 5
	assert_int(policia.mando).is_equal(0)
	assert_str(String(policia.estado)).is_equal("libre")


# ── AC-PE03: F2 — crack 0.76, torpe 1.26, medio 1.0 ───────────────────────────────────────
func test_modificador_produccion_f2() -> void:
	# Arrange
	var personal: Node = _personal()

	# Act / Assert — Rapidez 5/Mot 4 → 0.8×0.95 = 0.76; Rapidez 1/Mot 2 → 1.2×1.05 = 1.26; medio → 1.0.
	assert_float(personal.modificador_produccion(_agente(5, 3, 3, 4))).is_equal_approx(0.76, 0.001)
	assert_float(personal.modificador_produccion(_agente(1, 3, 3, 2))).is_equal_approx(1.26, 0.001)
	assert_float(personal.modificador_produccion(_agente(3, 3, 3, 3))).is_equal_approx(1.0, 0.001)


# ── AC-PE04: F1 — el salario sale del catálogo REAL × primas ──────────────────────────────
func test_salario_dia_f1() -> void:
	# Arrange
	var personal: Node = _personal()

	# Act / Assert — ag_doc (base 60 del catálogo): media 5 → 90; media 2 → 45; medio → 60.
	assert_float(personal.salario_dia(_agente(5, 5, 5, 5))).is_equal_approx(90.0, 0.001)
	assert_float(personal.salario_dia(_agente(2, 2, 2, 2))).is_equal_approx(45.0, 0.001)
	assert_float(personal.salario_dia(_agente(3, 3, 3, 3))).is_equal_approx(60.0, 0.001)

	# Oficial ag_doc media 4 → 60 × 1.25 × 1.3 = 97.5 (el mando cuesta más).
	var oficial: RefCounted = AgenteScript.new(
		"Óscar Delgado", &"ag_doc", AgenteScript.RANGO_OFICIAL, 4, 4, 4, 4, 3
	)
	assert_float(personal.salario_dia(oficial)).is_equal_approx(97.5, 0.001)

	# ag_odac usa SU base del catálogo (70): medio → 70.
	var odac: RefCounted = AgenteScript.new("Sara Medina", &"ag_odac", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)
	assert_float(personal.salario_dia(odac)).is_equal_approx(70.0, 0.001)


# ── AC-PE11: F3 — Trato 5 → ×1.5 · Trato 3 → ×1.0 (neutro con CUALQUIER Motivación) · Trato 1 → ×0.5 ─
func test_factor_trato_f3() -> void:
	# Arrange
	var personal: Node = _personal()

	# Act / Assert
	assert_float(personal.factor_trato(_agente(3, 5, 3, 3))).is_equal_approx(1.5, 0.001)
	assert_float(personal.factor_trato(_agente(3, 1, 3, 3))).is_equal_approx(0.5, 0.001)
	# Neutro: Trato 3 da 1.0 sea cual sea la Motivación (la modulación multiplica el DESVÍO).
	assert_float(personal.factor_trato(_agente(3, 3, 3, 1))).is_equal_approx(1.0, 0.001)
	assert_float(personal.factor_trato(_agente(3, 3, 3, 5))).is_equal_approx(1.0, 0.001)


# ── AC-PE12: F4 — Salud 5 → 0 (clamp) · Salud 3 → 3 % · Salud 1 → 7 % ─────────────────────
func test_prob_ausencia_f4() -> void:
	# Arrange
	var personal: Node = _personal()

	# Act / Assert
	assert_float(personal.prob_ausencia(_agente(3, 3, 5, 3))).is_equal_approx(0.0, 0.0001)
	assert_float(personal.prob_ausencia(_agente(3, 3, 3, 3))).is_equal_approx(0.03, 0.0001)
	assert_float(personal.prob_ausencia(_agente(3, 3, 1, 3))).is_equal_approx(0.07, 0.0001)


# ── AC-PE18: la Motivación modula LEVE (MVP base, sin fatiga dinámica) ────────────────────
func test_motivacion_modula_leve() -> void:
	# Arrange
	var personal: Node = _personal()

	# Act — mismo agente medio, motivación en los extremos.
	var animado: float = personal.modificador_produccion(_agente(3, 3, 3, 5))
	var desanimado: float = personal.modificador_produccion(_agente(3, 3, 3, 1))

	# Assert — la modulación existe pero es leve (≤ ±10 % sobre el 1.0 del agente medio).
	# Epsilon en la frontera: 0.05×2 no es exactamente 0.1 en binario (coma flotante).
	assert_float(animado).is_equal_approx(0.9, 0.001)
	assert_float(desanimado).is_equal_approx(1.1, 0.001)
	assert_bool(absf(animado - 1.0) <= 0.1001 and absf(desanimado - 1.0) <= 0.1001).is_true()


# ── AC-PE20: atributos corruptos se clampan; los derivados nunca salen de sus rangos ──────
func test_clamps_de_atributos_y_derivados() -> void:
	# Arrange — atributos imposibles (dato corrupto).
	var personal: Node = _personal()
	var corrupto: RefCounted = _agente(9, -2, 100, 0)

	# Assert — clampados a [1,5] en el setter…
	assert_int(corrupto.rapidez).is_equal(5)
	assert_int(corrupto.trato).is_equal(1)
	assert_int(corrupto.salud).is_equal(5)
	assert_int(corrupto.motivacion).is_equal(1)
	# …y los derivados dentro de sus rangos seguros (F2 [0.5,1.3] · F3 [0.5,1.5] · F4 [0,1]).
	var f2: float = personal.modificador_produccion(corrupto)
	var f3: float = personal.factor_trato(corrupto)
	var f4: float = personal.prob_ausencia(corrupto)
	assert_bool(f2 >= 0.5 and f2 <= 1.3).is_true()
	assert_bool(f3 >= 0.5 and f3 <= 1.5).is_true()
	assert_bool(f4 >= 0.0 and f4 <= 1.0).is_true()


# ── Clamp de knobs: un config corrupto se sanea con aviso ─────────────────────────────────
func test_config_fuera_de_rango_clampa_con_aviso() -> void:
	# Arrange — knobs corruptos (los push_warning esperados son intencionales).
	var config: Resource = ConfigPersonalScript.new()
	config.k_calidad = -1.0
	config.prima_rango_oficial = 0.5
	var pool_vacio: Array[String] = []
	config.pool_nombres = pool_vacio
	var personal: Node = auto_free(PersonalScript.new())

	# Act
	personal.aplicar_config(config)

	# Assert — k a 0; la prima nunca baja de 1.0; el pool vacío recibe un genérico.
	assert_float(personal.k_calidad).is_equal_approx(0.0, 0.0001)
	assert_float(personal.prima_rango_oficial).is_equal_approx(1.0, 0.0001)
	assert_int(personal.pool_nombres.size()).is_equal(1)


# ── Data-driven: el .tres real existe y trae las semillas del GDD ─────────────────────────
func test_tres_real_existe_y_carga_semillas() -> void:
	# Arrange / Act — cargar el recurso real generado por la herramienta.
	var config: Resource = load("res://datos/config/personal.tres")

	# Assert
	assert_object(config).is_not_null()
	assert_bool(config is ConfigPersonalScript).is_true()
	assert_float(config.k_calidad).is_equal_approx(0.5, 0.0001)
	assert_float(config.prima_rango_oficial).is_equal_approx(1.3, 0.0001)
	assert_float(config.k_rapidez).is_equal_approx(0.1, 0.0001)
	assert_float(config.k_motivacion_rapidez).is_equal_approx(0.05, 0.0001)
	assert_float(config.k_trato).is_equal_approx(0.25, 0.0001)
	assert_float(config.k_motivacion_trato).is_equal_approx(0.1, 0.0001)
	assert_float(config.base_ausencia).is_equal_approx(0.03, 0.0001)
	assert_float(config.k_salud).is_equal_approx(0.02, 0.0001)
	assert_float(config.coste_despido).is_equal_approx(0.0, 0.0001)
	assert_int(config.n_candidatos).is_equal(4)
	assert_int(config.refresco_mercado_jornadas).is_equal(3)
	assert_float(config.prob_candidato_oficial).is_equal_approx(0.2, 0.0001)
	assert_bool(config.pool_nombres.size() >= 20).is_true()
