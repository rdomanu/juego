# Story 002 (epic tiempo) — escala configurable data-driven + clamp [3, 12].
# Clases: los QA test cases de la story (AC-T28/T29/T34). Tipo: Logic. DETERMINISTA.
#
# Se INYECTA un `ConfigTiempo` en memoria (ConfigTiempo.new() vía preload por ruta literal) y se aplica con
# `aplicar_config()` → el test NO toca disco ni el `.tres` real (inyección de dependencia > singleton). El
# fixture del reloj se instancia con `.new()` SIN añadirlo al árbol (así NO corre su `_ready` → no carga el
# `.tres`) y con `auto_free(...)`. El caso "el `.tres` real existe y carga" es un assert simple aparte.
# Preload POR RUTA LITERAL, no por nombre de autoload (gotcha headless del proyecto).
extends GdUnitTestSuite

const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")
const ConfigTiempoScript := preload("res://src/foundation/tiempo/config_tiempo.gd")
const RUTA_CONFIG_REAL := "res://datos/config/tiempo.tres"


# ── Helpers de fixture ──────────────────────────────────────────────────────────────────────
## Instancia el autoload sin árbol → sin `_ready` (no carga el `.tres`). Defaults del código: escala 4,
## límites 420/900/1380. Cada test aplica el config que necesita.
func _nuevo_tiempo() -> Node:
	return auto_free(TiempoScript.new())


## Construye un `ConfigTiempo` en memoria con los campos indicados (fixture, sin I/O).
func _config(escala: float, i_manana: int, i_tarde: int, i_noche: int) -> Resource:
	var c: Resource = ConfigTiempoScript.new()
	c.escala_tiempo = escala
	c.inicio_manana = i_manana
	c.inicio_tarde = i_tarde
	c.inicio_noche = i_noche
	return c


# ── AC-T28: escala 0 (≤0) → clampa a 3.0 (mínimo) + aviso ──────────────────────────────────
func test_config_escala_cero_clampa_a_3() -> void:
	# Arrange — config con escala 0 (reloj congelado, prohibido).
	var tiempo: Node = _nuevo_tiempo()
	var config: Resource = _config(0.0, 420, 900, 1380)

	# Act
	tiempo.aplicar_config(config)

	# Assert — escala efectiva = 3.0 (mínimo del rango seguro).
	assert_float(tiempo.escala_tiempo).is_equal_approx(3.0, 0.001)


# ── AC-T29: escala 15 (fuera de 3–12) → clampa a 12.0 (máximo) + aviso ─────────────────────
func test_config_escala_alta_clampa_a_12() -> void:
	# Arrange — config con escala 15 (por encima del techo).
	var tiempo: Node = _nuevo_tiempo()
	var config: Resource = _config(15.0, 420, 900, 1380)

	# Act
	tiempo.aplicar_config(config)

	# Assert — escala efectiva = 12.0 (máximo del rango seguro).
	assert_float(tiempo.escala_tiempo).is_equal_approx(12.0, 0.001)


# ── Escala negativa → clampa a 3.0 (nunca reloj hacia atrás) ───────────────────────────────
func test_config_escala_negativa_clampa_a_3() -> void:
	# Arrange — escala -2: reloj hacia atrás, prohibido.
	var tiempo: Node = _nuevo_tiempo()
	var config: Resource = _config(-2.0, 420, 900, 1380)

	# Act
	tiempo.aplicar_config(config)

	# Assert — escala efectiva = 3.0.
	assert_float(tiempo.escala_tiempo).is_equal_approx(3.0, 0.001)


# ── AC-T34: config custom (escala 6, límites 360/840/1320) se respeta EXACTO (sin clamp) ────
func test_config_custom_se_respeta_exacto() -> void:
	# Arrange — escala 6 dentro de [3, 12] → sin clamp; límites custom leídos del config, no hardcodeados.
	var tiempo: Node = _nuevo_tiempo()
	var config: Resource = _config(6.0, 360, 840, 1320)

	# Act
	tiempo.aplicar_config(config)

	# Assert — el reloj usa exactamente esos valores.
	assert_float(tiempo.escala_tiempo).is_equal_approx(6.0, 0.001)
	assert_int(tiempo.inicio_manana).is_equal(360)
	assert_int(tiempo.inicio_tarde).is_equal(840)
	assert_int(tiempo.inicio_noche).is_equal(1320)


# ── Falta el config (null) → defaults seguros, sin petar ───────────────────────────────────
func test_config_null_usa_defaults() -> void:
	# Arrange — se simula "load devolvió null / ruta inexistente" pasando null a aplicar_config.
	var tiempo: Node = _nuevo_tiempo()

	# Act — no debe petar.
	tiempo.aplicar_config(null)

	# Assert — se mantienen los defaults del código: escala 4.0, límites 420/900/1380.
	assert_float(tiempo.escala_tiempo).is_equal_approx(4.0, 0.001)
	assert_int(tiempo.inicio_manana).is_equal(420)
	assert_int(tiempo.inicio_tarde).is_equal(900)
	assert_int(tiempo.inicio_noche).is_equal(1380)


# ── El `.tres` real del desarrollador existe y carga como ConfigTiempo con los defaults ────
func test_tres_real_existe_y_carga_defaults() -> void:
	# Assert — el recurso generado por la herramienta existe...
	assert_bool(ResourceLoader.exists(RUTA_CONFIG_REAL)).is_true()

	# ...y carga como un ConfigTiempo válido con los defaults del GDD (F1/F3).
	var recurso: Resource = load(RUTA_CONFIG_REAL)
	assert_object(recurso).is_not_null()
	assert_bool(recurso is ConfigTiempoScript).is_true()
	assert_float(recurso.escala_tiempo).is_equal_approx(4.0, 0.001)
	assert_int(recurso.inicio_manana).is_equal(420)
	assert_int(recurso.inicio_tarde).is_equal(900)
	assert_int(recurso.inicio_noche).is_equal(1380)
	assert_int(recurso.jornadas_por_mes).is_equal(4)
	assert_float(recurso.delta_max_por_frame).is_equal_approx(0.5, 0.001)
