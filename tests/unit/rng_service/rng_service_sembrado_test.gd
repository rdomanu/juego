# Story 001 (epic rng-service) — determinismo global · ADR-0002
# RNGService sembrado: sembrar / randi_rango / randf. Tipo: Logic. DETERMINISTA.
extends GdUnitTestSuite

const RngScript := preload("res://src/foundation/rng_service/rng_service.gd")


# AC-1: misma semilla + misma secuencia de llamadas -> misma salida.
func test_misma_semilla_reproduce_la_secuencia() -> void:
	# Arrange
	var a: Node = auto_free(RngScript.new())
	var b: Node = auto_free(RngScript.new())
	a.sembrar(12345)
	b.sembrar(12345)
	# Act + Assert (mismo orden de llamadas en ambos)
	for _i in 10:
		assert_int(a.randi_rango(1, 100)).is_equal(b.randi_rango(1, 100))
		assert_float(a.randf()).is_equal(b.randf())


# AC-1 (edge): semillas distintas producen secuencias distintas.
func test_semillas_distintas_producen_secuencias_distintas() -> void:
	# Arrange
	var a: Node = auto_free(RngScript.new())
	var b: Node = auto_free(RngScript.new())
	a.sembrar(12345)
	b.sembrar(999)
	# Act: comparar 20 tiradas; basta que UNA difiera
	var todas_iguales := true
	for _i in 20:
		if a.randi_rango(1, 1_000_000) != b.randi_rango(1, 1_000_000):
			todas_iguales = false
			break
	# Assert
	assert_bool(todas_iguales).is_false()


# AC-2: randi_rango cae dentro de [desde, hasta] inclusive.
func test_randi_rango_dentro_de_limites() -> void:
	# Arrange
	var a: Node = auto_free(RngScript.new())
	a.sembrar(7)
	# Act + Assert
	for _i in 200:
		var v: int = a.randi_rango(5, 10)
		assert_bool(v >= 5 and v <= 10).is_true()


# AC-3: randf cae dentro de [0.0, 1.0).
func test_randf_dentro_de_cero_uno() -> void:
	# Arrange
	var a: Node = auto_free(RngScript.new())
	a.sembrar(7)
	# Act + Assert
	for _i in 200:
		var v: float = a.randf()
		assert_bool(v >= 0.0 and v < 1.0).is_true()
