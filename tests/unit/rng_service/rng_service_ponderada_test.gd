# Story 002 (epic rng-service) — base de TR-demand-002 · ADR-0002
# elegir_ponderado: elección proporcional a pesos, normalización defensiva. Tipo: Logic. DETERMINISTA.
# Casos degenerados (seed-independientes) + determinismo; se evitan tests de distribución (flaky).
extends GdUnitTestSuite

const RngScript := preload("res://src/foundation/rng_service/rng_service.gd")


# AC-1: un único peso positivo -> siempre ese índice (con cualquier semilla).
func test_peso_unico_siempre_devuelve_ese_indice() -> void:
	var a: Node = auto_free(RngScript.new())
	var pesos: Array[float] = [0.0, 0.0, 1.0]
	a.sembrar(1)
	for _i in 50:
		assert_int(a.elegir_ponderado(pesos)).is_equal(2)
	a.sembrar(999)
	for _i in 50:
		assert_int(a.elegir_ponderado(pesos)).is_equal(2)


# AC-2: un índice con peso 0 nunca se elige.
func test_peso_cero_nunca_se_elige() -> void:
	var a: Node = auto_free(RngScript.new())
	var pesos: Array[float] = [1.0, 0.0, 1.0]
	a.sembrar(42)
	for _i in 200:
		var idx: int = a.elegir_ponderado(pesos)
		assert_bool(idx == 0 or idx == 2).is_true()


# AC-3: normalización defensiva -> pesos que no suman 1 se aceptan usando la suma real.
func test_normalizacion_defensiva_pesos_no_suman_uno() -> void:
	var a: Node = auto_free(RngScript.new())
	var pesos: Array[float] = [0.0, 5.0]   # suma real 5.0
	a.sembrar(3)
	for _i in 50:
		assert_int(a.elegir_ponderado(pesos)).is_equal(1)


# AC-4: determinismo -> misma semilla + mismos pesos -> misma secuencia de elecciones.
func test_determinismo_misma_semilla_misma_secuencia() -> void:
	var a: Node = auto_free(RngScript.new())
	var b: Node = auto_free(RngScript.new())
	var pesos: Array[float] = [1.0, 1.0, 1.0]
	a.sembrar(777)
	b.sembrar(777)
	for _i in 20:
		# Capturar cada llamada en su propia variable: deja el orden de avance del RNG explícito
		# (evitar dos llamadas que avanzan el RNG dentro de una sola aserción).
		var va: int = a.elegir_ponderado(pesos)
		var vb: int = b.elegir_ponderado(pesos)
		assert_int(va).is_equal(vb)


# AC-5 (edge): lista vacía o todos los pesos 0 -> -1.
func test_lista_vacia_o_todos_cero_devuelve_menos_uno() -> void:
	var a: Node = auto_free(RngScript.new())
	var vacia: Array[float] = []
	var ceros: Array[float] = [0.0, 0.0]
	assert_int(a.elegir_ponderado(vacia)).is_equal(-1)
	assert_int(a.elegir_ponderado(ceros)).is_equal(-1)
