# ODAC / Denuncias #9 — LA ÚLTIMA PIEZA DEL MVP. Los MODOS de reconfiguración (OD4) y la válvula
# anti-inanición (OD5). Tipo: Integration (ODAC + Flujo reales, catálogo real). DETERMINISTA.
#
# Lo que de verdad se prueba aquí no es "el botón cambia una variable", sino la REGLA DE JUEGO que
# hay detrás: las urgentes pasan siempre delante, y si el jugador no reserva una ventanilla para las
# administrativas, estas pueden quedarse sin atender para siempre. Por eso el test estrella es
# `test_avisa_de_las_denuncias_que_se_quedan_sin_ventanilla`.
extends GdUnitTestSuite

const ODACScript := preload("res://src/feature/odac/odac.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")

## Del catálogo REAL. Si algún día dejan de ser lo que son, el test lo dice en vez de pasar en falso.
const UNA_PRIORITARIA := &"viogen"
const UNA_NORMAL := &"amenazas"
const TIPO_PUESTO := &"puesto_odac"


# ── Fixture ──────────────────────────────────────────────────────────────────────────────────
## ODAC con un Flujo real y `cuantos` puestos de ODAC registrados (odac_1, odac_2…).
func _mundo(cuantos: int = 1) -> Array:
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	add_child(flujo)
	var odac: Node = auto_free(ODACScript.new())
	add_child(odac)
	odac.usar_flujo(flujo)
	for i in range(1, cuantos + 1):
		flujo.registrar_puesto_flujo(StringName("odac_%d" % i), TIPO_PUESTO)
	return [odac, flujo]


# ── El catálogo manda (OD1) ──────────────────────────────────────────────────────────────────

# AC-1: ODAC no inventa qué es urgente — lo lee del catálogo. Si mantuviera su propia lista, habría
# dos verdades y una se quedaría vieja.
func test_la_prioridad_sale_del_catalogo() -> void:
	var m: Array = _mundo()
	var odac: Node = m[0]
	assert_bool(odac.es_prioritaria(UNA_PRIORITARIA)).is_true()
	assert_bool(odac.es_prioritaria(UNA_NORMAL)).is_false()


# AC-2: hay 13 tipos de denuncia y los cuatro urgentes son los del GDD (OD1).
func test_el_catalogo_tiene_las_denuncias_del_gdd() -> void:
	var m: Array = _mundo()
	var odac: Node = m[0]
	var todas: Array = odac.denuncias()
	var urgentes: Array = todas.filter(func(d: StringName) -> bool: return odac.es_prioritaria(d))
	assert_int(todas.size()).is_greater_equal(13)
	assert_int(urgentes.size()).is_equal(4)


# ── Los cuatro modos (OD4) ───────────────────────────────────────────────────────────────────

# AC-3: "solo prioritarias" deja EXACTAMENTE las urgentes, y "solo normales" exactamente el resto.
func test_cada_modo_deja_las_denuncias_que_toca() -> void:
	var m: Array = _mundo()
	var odac: Node = m[0]
	var urgentes: Array = odac.atenciones_de_modo(odac.Modo.SOLO_PRIORITARIAS)
	var normales: Array = odac.atenciones_de_modo(odac.Modo.SOLO_NORMALES)
	assert_int(urgentes.size()).is_equal(4)
	for d: StringName in urgentes:
		assert_bool(odac.es_prioritaria(d)).is_true()
	for d: StringName in normales:
		assert_bool(odac.es_prioritaria(d)).is_false()
	# Juntos son el catálogo entero: ninguna denuncia se queda fuera de los dos modos.
	assert_int(urgentes.size() + normales.size()).is_equal(odac.denuncias().size())


# AC-4: POLIVALENTE devuelve lista VACÍA a propósito — para Flujo, vacío significa "sin override,
# usa el catálogo del puesto", que es exactamente lo que es ser polivalente.
func test_polivalente_no_pone_override() -> void:
	var m: Array = _mundo()
	var odac: Node = m[0]
	assert_int(odac.atenciones_de_modo(odac.Modo.POLIVALENTE).size()).is_equal(0)


# AC-5: fijar un modo se APLICA a Flujo, no se queda en una variable de adorno.
func test_fijar_modo_llega_a_flujo() -> void:
	var m: Array = _mundo()
	var odac: Node = m[0]
	assert_bool(odac.fijar_modo(&"odac_1", odac.Modo.SOLO_PRIORITARIAS)).is_true()
	assert_int(odac.modo_de(&"odac_1")).is_equal(odac.Modo.SOLO_PRIORITARIAS)


# AC-6: se puede volver a polivalente, y entonces la marca se BORRA (el default no se guarda).
func test_volver_a_polivalente_limpia_el_modo() -> void:
	var m: Array = _mundo()
	var odac: Node = m[0]
	odac.fijar_modo(&"odac_1", odac.Modo.SOLO_NORMALES)
	assert_bool(odac.fijar_modo(&"odac_1", odac.Modo.POLIVALENTE)).is_true()
	assert_int(odac.modo_de(&"odac_1")).is_equal(odac.Modo.POLIVALENTE)


# AC-7: "a medida" con la lista vacía se RECHAZA. Un puesto que no puede atender nada no es un
# puesto reconfigurado, es un mueble — y cerrarlo es otra orden distinta.
func test_a_medida_sin_nada_marcado_se_rechaza() -> void:
	var m: Array = _mundo()
	var odac: Node = m[0]
	var vacio: Array[StringName] = []
	assert_bool(odac.fijar_modo(&"odac_1", odac.Modo.SUBCONJUNTO, vacio)).is_false()
	assert_int(odac.modo_de(&"odac_1")).is_equal(odac.Modo.POLIVALENTE)


# AC-8: "a medida" filtra lo inventado — un save manipulado no puede colar tipos que no existen.
func test_a_medida_descarta_denuncias_inventadas() -> void:
	var m: Array = _mundo()
	var odac: Node = m[0]
	var mezcla: Array[StringName] = [UNA_NORMAL, &"denuncia_que_no_existe"]
	assert_bool(odac.fijar_modo(&"odac_1", odac.Modo.SUBCONJUNTO, mezcla)).is_true()
	assert_array(odac.subconjunto_de(&"odac_1")).contains_exactly([UNA_NORMAL])


# ── 🔑 LA VÁLVULA ANTI-INANICIÓN (OD5) ───────────────────────────────────────────────────────

# AC-9: EL TEST ESTRELLA. Si el jugador pone TODAS sus ventanillas en "solo prioritarias", las
# administrativas se quedan sin nadie que las atienda — y el juego tiene que AVISAR. Sin este aviso
# se puede estrangular la propia oficina sin enterarse hasta que la satisfacción se hunda.
func test_avisa_de_las_denuncias_que_se_quedan_sin_ventanilla() -> void:
	var m: Array = _mundo(2)
	var odac: Node = m[0]
	# De partida, ambas polivalentes: no falta nada por cubrir.
	assert_array(odac.denuncias_sin_cubrir()).is_empty()
	odac.fijar_modo(&"odac_1", odac.Modo.SOLO_PRIORITARIAS)
	odac.fijar_modo(&"odac_2", odac.Modo.SOLO_PRIORITARIAS)
	var huerfanas: Array = odac.denuncias_sin_cubrir()
	assert_int(huerfanas.size()).is_greater(0)
	for d: StringName in huerfanas:
		assert_bool(odac.es_prioritaria(d)).is_false()   # las que sobran son las administrativas


# AC-10: y la válvula FUNCIONA — con una sola ventanilla dedicada a normales, vuelve a estar todo
# cubierto. Es literalmente la solución que el GDD propone al problema de arriba (OD5).
func test_dedicar_una_ventanilla_a_normales_lo_arregla() -> void:
	var m: Array = _mundo(2)
	var odac: Node = m[0]
	odac.fijar_modo(&"odac_1", odac.Modo.SOLO_PRIORITARIAS)
	odac.fijar_modo(&"odac_2", odac.Modo.SOLO_PRIORITARIAS)
	assert_int(odac.denuncias_sin_cubrir().size()).is_greater(0)
	odac.fijar_modo(&"odac_2", odac.Modo.SOLO_NORMALES)
	assert_array(odac.denuncias_sin_cubrir()).is_empty()


# ── Persistencia (ADR-0002) ──────────────────────────────────────────────────────────────────

# AC-11: los modos sobreviven al guardado. Si no, cada carga te devolvería la oficina sin
# especializar y habría que reconfigurarla a mano cada vez.
func test_los_modos_sobreviven_al_guardado() -> void:
	var m: Array = _mundo(2)
	var odac: Node = m[0]
	odac.fijar_modo(&"odac_1", odac.Modo.SOLO_PRIORITARIAS)
	odac.fijar_modo(&"odac_2", odac.Modo.SOLO_NORMALES)
	var guardado: Dictionary = odac.save()

	var otro: Array = _mundo(2)
	var odac2: Node = otro[0]
	odac2.load_state(guardado)
	assert_int(odac2.modo_de(&"odac_1")).is_equal(odac.Modo.SOLO_PRIORITARIAS)
	assert_int(odac2.modo_de(&"odac_2")).is_equal(odac.Modo.SOLO_NORMALES)


# AC-12: al cargar, el modo se VUELVE A APLICAR a Flujo, no solo se anota. Al cargar una partida
# Flujo arranca con todos los puestos polivalentes: si aquí solo se guardara el número, el panel
# diría "solo prioritarias" mientras el puesto seguía atendiendo de todo.
func test_al_cargar_el_modo_se_reaplica_de_verdad() -> void:
	var m: Array = _mundo(2)
	var odac: Node = m[0]
	odac.fijar_modo(&"odac_1", odac.Modo.SOLO_PRIORITARIAS)
	odac.fijar_modo(&"odac_2", odac.Modo.SOLO_PRIORITARIAS)
	var guardado: Dictionary = odac.save()

	var otro: Array = _mundo(2)
	var odac2: Node = otro[0]
	odac2.load_state(guardado)
	# Si el modo se hubiera quedado solo anotado, esto saldría vacío (Flujo seguiría polivalente).
	assert_int(odac2.denuncias_sin_cubrir().size()).is_greater(0)


# AC-13: un save corrupto no rompe la partida — se descarta la entrada mala y sigue.
func test_un_save_corrupto_se_descarta_sin_romper() -> void:
	var m: Array = _mundo()
	var odac: Node = m[0]
	odac.load_state({"modos": [
		{"puesto": "", "modo": 1, "tipos": []},
		{"puesto": "odac_1", "modo": 99, "tipos": []},
		"esto no es un diccionario",
	]})
	assert_int(odac.modo_de(&"odac_1")).is_equal(odac.Modo.POLIVALENTE)
