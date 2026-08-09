# ALINEACION A LA CUADRICULA de las piezas del entorno — la geometria, sin nodos ni escena.
# Tipo: Logic. DETERMINISTA: mide PNG del repo (fijos) y hace aritmetica; sin reloj ni RNG.
#
# Encargo del usuario (2026-08-09, probando el disenador): "las casas tienen que colocarse en los
# bordes de las celdas, ahora empiezan en mitad de una celda", "los muros y puertas no se ajustan a
# las cuadriculas", "hay objetos que si quiero que esten en el centro como las farolas", "si algo
# ocupa 1,94 amplialo a 2".
#
# LA REGLA (ver el bloque largo en AnclajeSprite): la huella medida se REDONDEA a celdas enteras y,
# si el resultado es PAR, el ancla se corre media celda en ese eje (los bordes de la pieza caen
# sobre bordes de celda). Impar → sin desvio, la pieza sigue centrada en su celda.
#
# Lo que este test protege:
#   1. Que la huella se REDONDEE (el coche mide 1,94 celdas y tiene que contar como 2).
#   2. Que las piezas grandes de huella par (casas 6/8, carretera 6, coche 2) reciban desvio.
#   3. Que las piezas de 1 celda (farola, seto) NO lo reciban — siguen centradas.
#   4. Que el desvio valga exactamente media celda proyectada (ni una fraccion inventada).
extends GdUnitTestSuite

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

const CARPETA := "res://assets/sprites/entorno/"


func _tex(id: String) -> Texture2D:
	var ruta: String = CARPETA + id + "_0.png"
	assert_bool(ResourceLoader.exists(ruta)).override_failure_message(
		"falta el PNG '%s' — el test mide arte real del repo" % ruta
	).is_true()
	return load(ruta)


# ── 1. La huella se redondea a celdas enteras ───────────────────────────────────────────────────

## El coche patrulla mide ~1,94 celdas de ancho: cuenta como 2 ("amplialo a 2", orden del usuario).
func test_la_huella_del_coche_se_redondea_a_dos_celdas() -> void:
	assert_int(AnclajeSpriteScript.celdas_de_huella(_tex("coche_policia"))).is_equal(2)


## Las casas se calibraron a 6 y 8 celdas de rombo EXACTAS (ver render_entorno_urbano.gd: el ancho
## de su silueta es 480 y 640 px = 6 y 8 rombos de 80).
func test_las_casas_miden_las_celdas_con_las_que_se_calibraron() -> void:
	var pequena: int = AnclajeSpriteScript.celdas_de_huella(_tex("casa_a"))
	var grande: int = AnclajeSpriteScript.celdas_de_huella(_tex("casa_o"))
	assert_int(pequena).is_equal(6)
	assert_int(grande).is_equal(8)


## Ninguna huella baja de 1 celda, por pequena que sea la pieza (la farola mide 0,25).
func test_una_pieza_pequena_ocupa_al_menos_una_celda() -> void:
	assert_int(AnclajeSpriteScript.celdas_de_huella(_tex("farola"))).is_equal(1)


# ── 2 y 3. Quien recibe desvio y quien no ───────────────────────────────────────────────────────

## 🔒 EL CASO DEL ENCARGO: una casa de 6 celdas (par) NO puede quedarse centrada en una celda.
func test_las_piezas_de_huella_par_reciben_desvio() -> void:
	for id: String in ["casa_a", "casa_o", "coche_policia", "carretera_recta"]:
		var desvio: Vector2 = AnclajeSpriteScript.desvio_rejilla(_tex(id))
		assert_bool(desvio.is_equal_approx(Vector2.ZERO)).override_failure_message(
			"'%s' tiene huella par y deberia llevar desvio de rejilla" % id
		).is_false()


## 🔒 LA OTRA MITAD DEL ENCARGO ("hay objetos que si quiero que esten en el centro como las
## farolas"): huella impar = sin desvio, la pieza sigue clavada en el centro de su celda.
func test_las_piezas_de_una_celda_no_se_desvian() -> void:
	for id: String in ["farola", "seto", "arbol_urbano"]:
		var desvio: Vector2 = AnclajeSpriteScript.desvio_rejilla(_tex(id))
		assert_bool(desvio.is_equal_approx(Vector2.ZERO)).override_failure_message(
			"'%s' ocupa 1 celda: no debe desviarse del centro" % id
		).is_true()


# ── 4. El desvio es EXACTAMENTE media celda proyectada ──────────────────────────────────────────

## Nada de fracciones a ojo: el desvio de una pieza par en los dos ejes es la proyeccion del vector
## (medio, medio) del plano logico cuadrado.
func test_el_desvio_es_media_celda_proyectada() -> void:
	var textura: Texture2D = _tex("casa_a")
	assert_int(AnclajeSpriteScript.celdas_de_huella(textura) % 2).is_equal(0)
	var medio: float = float(Proyeccion.TAM_CELDA) * 0.5
	var esperado: Vector2 = Proyeccion.proyectar(Vector2(medio, medio))
	assert_bool(
		AnclajeSpriteScript.desvio_rejilla(textura).is_equal_approx(esperado)
	).is_true()
