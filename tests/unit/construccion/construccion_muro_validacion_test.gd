# PURA API de validación de muros — `puede_construir_muro`/`puede_demoler_muro` (2026-08-15, modo
# construcción "estilo Los Sims": el fantasma del trazo completo necesita preguntar "¿esto se podría
# construir/demoler?" arista por arista SIN mutar nada ni cobrar — antes esa cuenta vivía duplicada
# a medias entre `Construccion.construir_muro` y `ModoConstruccion._arista_en_edificio`).
#
# `construir_muro`/`demoler_muro` pasan a usar estas dos por dentro (única fuente de verdad) — los
# tests de comportamiento REAL (cobra, muta el modelo) siguen en el resto de la suite de
# construcción; aquí se cubre el contrato PURO: dentro/fuera del edificio, ya hay muro, sin dinero,
# muro fijo (fachada).
#
# Tipo: Logic. DETERMINISTA: sin azar, sin reloj, sin GPU.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")


## Construcción con Economía real inyectada (para poder simular "sin caja" con `saldo_eur`) y la
## fachada ya levantada (`levantar_fachada`, idempotente) — así hay una arista FIJA de verdad con la
## que probar "muro fijo" sin tener que fabricar una a mano.
func _mundo() -> Dictionary:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	construccion.usar_economia(economia)
	construccion.levantar_fachada()
	return {"construccion": construccion, "economia": economia}


# ── puede_construir_muro ──────────────────────────────────────────────────────────────────────

func test_puede_construir_muro_dentro_del_edificio_con_caja_es_valido() -> void:
	# Arrange
	var construccion: Node = _mundo()["construccion"]

	# Act / Assert — una arista suelta en mitad de la rejilla, sin nada construido todavía.
	assert_bool(construccion.puede_construir_muro(Vector2i(5, 5), &"izquierda")).is_true()


func test_puede_construir_muro_fuera_del_edificio_es_invalido() -> void:
	# Arrange — la rejilla del config por defecto es 24×13 (ver `construccion_validacion_test.gd`).
	var construccion: Node = _mundo()["construccion"]

	# Act / Assert — una arista en plena calle, lejos de cualquier celda del edificio.
	assert_bool(construccion.puede_construir_muro(Vector2i(500, 500), &"izquierda")).is_false()


func test_puede_construir_muro_donde_ya_hay_uno_es_invalido() -> void:
	# Arrange
	var construccion: Node = _mundo()["construccion"]
	assert_bool(construccion.construir_muro(Vector2i(5, 5), &"izquierda")).is_true()

	# Act / Assert — la misma arista, ya construida.
	assert_bool(construccion.puede_construir_muro(Vector2i(5, 5), &"izquierda")).is_false()


func test_puede_construir_muro_sin_caja_es_invalido() -> void:
	# Arrange — saldo insuficiente para el coste de un tramo.
	var mundo: Dictionary = _mundo()
	var construccion: Node = mundo["construccion"]
	(mundo["economia"] as Node).saldo_eur = 0.0

	# Act / Assert
	assert_bool(construccion.puede_construir_muro(Vector2i(5, 5), &"izquierda")).is_false()
	# Y `construir_muro` (que la reconsulta por dentro) tampoco levanta nada ni descuenta saldo.
	assert_bool(construccion.construir_muro(Vector2i(5, 5), &"izquierda")).is_false()
	assert_bool(construccion.hay_muro(Vector2i(5, 5), &"izquierda")).is_false()


## 🔒 REGRESIÓN: antes de esta API, `ModoConstruccion._arista_en_edificio` duplicaba a mano la
## comprobación de "dentro del edificio" — este test fija que `construir_muro` YA NO puede levantar
## un tramo fuera de la rejilla, con la MISMA función que usa el fantasma de la UI.
func test_construir_muro_respeta_puede_construir_muro_para_aristas_fuera_del_edificio() -> void:
	var construccion: Node = _mundo()["construccion"]
	assert_bool(construccion.construir_muro(Vector2i(500, 500), &"izquierda")).is_false()


# ── puede_demoler_muro ────────────────────────────────────────────────────────────────────────

func test_puede_demoler_muro_donde_hay_uno_normal_es_valido() -> void:
	# Arrange
	var construccion: Node = _mundo()["construccion"]
	construccion.construir_muro(Vector2i(5, 5), &"izquierda")

	# Act / Assert
	assert_bool(construccion.puede_demoler_muro(Vector2i(5, 5), &"izquierda")).is_true()


func test_puede_demoler_muro_donde_no_hay_nada_es_invalido() -> void:
	# Arrange
	var construccion: Node = _mundo()["construccion"]

	# Act / Assert — arista suelta, nunca se construyó nada ahí.
	assert_bool(construccion.puede_demoler_muro(Vector2i(5, 5), &"izquierda")).is_false()


## El muro FIJO (fachada) no se demuele — es el plano de la comisaría, no obra del jugador.
func test_puede_demoler_muro_fijo_de_fachada_es_invalido() -> void:
	# Arrange — `levantar_fachada()` (en `_mundo()`) ya dejó fija la arista norte, columna 0.
	var construccion: Node = _mundo()["construccion"]
	assert_bool(construccion.es_muro_fijo(construccion.clave_de_muro(Vector2i(0, 0), &"arriba"))).is_true()

	# Act / Assert
	assert_bool(construccion.puede_demoler_muro(Vector2i(0, 0), &"arriba")).is_false()
	# Y `demoler_muro` (que la reconsulta por dentro) tampoco la tira.
	assert_bool(construccion.demoler_muro(Vector2i(0, 0), &"arriba")).is_false()
	assert_bool(construccion.hay_muro(Vector2i(0, 0), &"arriba")).is_true()
