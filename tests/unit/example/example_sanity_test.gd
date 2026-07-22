# Prueba de muestra (PLANTILLA) — confirma que el sistema de tests (GdUnit4) arranca
# y sirve de referencia de sintaxis. Reemplazar por tests reales cuando exista el primer
# sistema (p. ej. Economía: retorno_dgp). Requiere el plugin GdUnit4 instalado.
#
# Convenciones (ver tests/README.md):
#   - Archivo:  [system]_[feature]_test.gd
#   - Función:  test_[scenario]_[expected]
#   - Determinismo (coding-standards): sin aleatoriedad sin sembrar, sin depender del reloj real.
extends GdUnitTestSuite


# Sanity: el suite se ejecuta y las aserciones básicas funcionan.
func test_sanity_dos_mas_dos_son_cuatro() -> void:
	assert_int(2 + 2).is_equal(4)


# Ilustra el principio de DETERMINISMO del proyecto (ADR-0002): misma semilla -> misma
# secuencia. En el juego, toda aleatoriedad pasará por RNGService sembrado; este test usa
# el RandomNumberGenerator nativo solo para demostrar el patrón sin depender de código de juego.
func test_rng_sembrado_con_misma_semilla_reproduce_la_secuencia() -> void:
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 12345
	rng_b.seed = 12345
	assert_int(rng_a.randi()).is_equal(rng_b.randi())
	assert_int(rng_a.randi()).is_equal(rng_b.randi())


# ─── EJEMPLO de test REAL (comentado hasta que exista Economía #3) ───────────────
# Muestra cómo se probará una fórmula del juego con su clamp de rango (GDD Economía / ADR-0003):
#
# func test_retorno_dgp_con_sat_50_esta_dentro_del_rango() -> void:
#     var r: float = Economia.retorno_dgp(50.0)          # sat en 0..100
#     assert_float(r).is_between(0.15, 0.45)             # suelo/techo del retorno DGP
