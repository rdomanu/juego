# FASE C del modelo de MUROS LIBRES (2026-07-30): "primero levantas tabiques, y el hueco que queda
# encerrado ES la zona" (petición del usuario). `recinto_de` (relleno por inundación en 4 direcciones,
# el perímetro del edificio cuenta como muro implícito) y `designar_zona` (convierte un recinto en
# sala, cobrando). Tipo: Integration (Construccion + Economia reales, sin mocks).
# DETERMINISTA: sin azar; catálogo REAL (`sala_documentacion`, coste base 0 € en su .tres — así el
# cobro esperado es SIEMPRE solo `coste_por_celda × celdas`, sin una base que rastrear aparte).
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")

## Tipo de sala usado en todos los tests (coste_construccion_eur = 0 en su .tres — ver cabecera).
const TIPO_SALA := &"sala_documentacion"


# ── Fixture ──────────────────────────────────────────────────────────────────────────────────
## Comisaría vacía (edificio 24×13 por defecto, sin muros) con caja de sobra para pintar tabiques y
## designar zonas. Cada test la vuelve a montar (GdUnit corta la suite tras el primer FAIL, así que
## nada de estado compartido entre tests — regla del proyecto).
func _mundo(saldo: float = 100000.0) -> Array:
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	economia.saldo_eur = saldo
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(economia)
	return [construccion, economia]


## Encierra un rectángulo con muro por sus 4 lados (2×ancho + 2×alto tramos, sin duplicar aristas):
## el molde que reutilizan los tests de subdivisión para dejar un recinto TOTALMENTE aislado.
func _encerrar(construccion: Node, rect: Rect2i) -> void:
	for x: int in range(rect.position.x, rect.end.x):
		construccion.construir_muro(Vector2i(x, rect.position.y), &"arriba")
		construccion.construir_muro(Vector2i(x, rect.end.y - 1), &"abajo")
	for y: int in range(rect.position.y, rect.end.y):
		construccion.construir_muro(Vector2i(rect.position.x, y), &"izquierda")
		construccion.construir_muro(Vector2i(rect.end.x - 1, y), &"derecha")


## Las celdas de un rectángulo, como lista — para comparar contra `recinto_de`/`celdas_de_sala`.
func _celdas_de(rect: Rect2i) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	for x: int in range(rect.position.x, rect.end.x):
		for y: int in range(rect.position.y, rect.end.y):
			celdas.append(Vector2i(x, y))
	return celdas


## ¿`actual` tiene EXACTAMENTE las mismas celdas que `esperado`, sin importar el orden? El relleno
## por inundación usa una pila (LIFO): el orden de salida no es el de lectura obvio, así que
## comparar como CONJUNTO es lo único determinista de verdad.
func _mismo_conjunto(actual: Array[Vector2i], esperado: Array[Vector2i]) -> bool:
	if actual.size() != esperado.size():
		return false
	for celda: Vector2i in esperado:
		if not actual.has(celda):
			return false
	return true


# ── 1. Sin ningún muro, todo el edificio es un único recinto ─────────────────────────────────
func test_sin_muros_todo_el_edificio_es_un_solo_recinto() -> void:
	var construccion: Node = _mundo()[0]
	var total: int = construccion.edificio_columnas * construccion.edificio_filas

	# Desde una esquina, desde la otra y desde el centro: el mismo recinto único da igual el origen —
	# el perímetro del edificio es el único "muro" que hay, así que nada lo subdivide.
	assert_int(construccion.recinto_de(Vector2i(0, 0)).size()).is_equal(total)
	assert_int(construccion.recinto_de(Vector2i(23, 12)).size()).is_equal(total)
	assert_int(construccion.recinto_de(Vector2i(12, 6)).size()).is_equal(total)


# ── 2. Un tabique CERRADO subdivide el edificio en dos recintos ──────────────────────────────
func test_tabique_cerrado_subdivide_el_edificio() -> void:
	var construccion: Node = _mundo()[0]
	var total: int = construccion.edificio_columnas * construccion.edificio_filas
	var cuadrado: Rect2i = Rect2i(5, 5, 3, 3)   # 3×3 = 9 celdas, lejos de los bordes del edificio.

	_encerrar(construccion, cuadrado)

	var dentro: Array[Vector2i] = construccion.recinto_de(Vector2i(6, 6))
	var fuera: Array[Vector2i] = construccion.recinto_de(Vector2i(0, 0))
	assert_bool(_mismo_conjunto(dentro, _celdas_de(cuadrado))).is_true()
	assert_int(fuera.size()).is_equal(total - 9)


# ── 3. Un tabique con UN hueco no cierra nada — la propiedad más importante del sistema ──────
func test_tabique_con_un_hueco_no_cierra_nada() -> void:
	var construccion: Node = _mundo()[0]
	var total: int = construccion.edificio_columnas * construccion.edificio_filas
	var cuadrado: Rect2i = Rect2i(5, 5, 3, 3)

	_encerrar(construccion, cuadrado)
	# Se abre UN solo hueco: la celda central del tabique de arriba.
	assert_bool(construccion.demoler_muro(Vector2i(6, 5), &"arriba")).is_true()

	# Con un único hueco basta: el recinto de DENTRO vuelve a ser el edificio ENTERO — no encierra nada.
	assert_int(construccion.recinto_de(Vector2i(6, 6)).size()).is_equal(total)


# ── 4. No se pasa en diagonal: dos recintos que solo se tocan por una esquina son distintos ──
func test_no_se_pasa_en_diagonal_por_una_esquina() -> void:
	var construccion: Node = _mundo()[0]
	var celda_a: Vector2i = Vector2i(2, 2)
	var celda_b: Vector2i = Vector2i(3, 3)   # vecina en DIAGONAL de A: solo se tocan por la esquina.

	_encerrar(construccion, Rect2i(celda_a, Vector2i.ONE))
	_encerrar(construccion, Rect2i(celda_b, Vector2i.ONE))

	var recinto_a: Array[Vector2i] = construccion.recinto_de(celda_a)
	var recinto_b: Array[Vector2i] = construccion.recinto_de(celda_b)
	assert_int(recinto_a.size()).is_equal(1)
	assert_int(recinto_b.size()).is_equal(1)
	# Si el relleno pasara por la esquina, ambos recintos se habrían fundido en uno de 2 celdas.
	assert_bool(recinto_a.has(celda_b)).is_false()
	assert_bool(recinto_b.has(celda_a)).is_false()


# ── 5. Designar una zona crea la sala con EXACTAMENTE las celdas del recinto, y cobra ────────
func test_designar_zona_crea_sala_con_las_celdas_del_recinto_y_cobra() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var economia: Node = mundo[1]
	var cuadrado: Rect2i = Rect2i(5, 5, 3, 3)   # 9 celdas.
	_encerrar(construccion, cuadrado)
	var saldo_antes: float = economia.saldo_eur

	var sala_id: StringName = construccion.designar_zona(Vector2i(6, 6), TIPO_SALA)

	assert_str(String(sala_id)).is_not_equal("")
	assert_int(construccion.area_de_sala(sala_id)).is_equal(9)
	assert_bool(_mismo_conjunto(construccion.celdas_de_sala(sala_id), _celdas_de(cuadrado))).is_true()
	# TIPO_SALA tiene coste base 0 € en su catálogo: el cobro es SOLO coste_por_celda × 9 celdas.
	assert_float(economia.saldo_eur).is_equal_approx(saldo_antes - construccion.coste_por_celda * 9.0, 0.001)


# ── 6. Un recinto demasiado pequeño (< area_min_sala) no se designa, y no cobra ──────────────
func test_recinto_demasiado_pequeno_no_se_designa() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var economia: Node = mundo[1]
	var pasillo: Rect2i = Rect2i(2, 2, 2, 1)   # 2 celdas: por debajo de area_min_sala (4).
	_encerrar(construccion, pasillo)
	var saldo_antes: float = economia.saldo_eur

	var sala_id: StringName = construccion.designar_zona(Vector2i(2, 2), TIPO_SALA)

	assert_str(String(sala_id)).is_equal("")
	assert_float(economia.saldo_eur).is_equal_approx(saldo_antes, 0.001)


# ── 7. No se pisa una sala ya designada: la segunda designación no cobra ni pisa nada ────────
func test_no_se_pisa_una_sala_ya_designada() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var economia: Node = mundo[1]
	var cuadrado: Rect2i = Rect2i(5, 5, 3, 3)
	_encerrar(construccion, cuadrado)
	var primera: StringName = construccion.designar_zona(Vector2i(6, 6), TIPO_SALA)
	assert_str(String(primera)).is_not_equal("")   # arranque: la primera SÍ se designa.
	var saldo_antes: float = economia.saldo_eur

	# Mismo recinto (los muros no cambiaron): sus celdas ya son de `primera` — no hay solape silencioso.
	var segunda: StringName = construccion.designar_zona(Vector2i(6, 6), TIPO_SALA)

	assert_str(String(segunda)).is_equal("")
	assert_float(economia.saldo_eur).is_equal_approx(saldo_antes, 0.001)


# ── 8. Sin caja no se designa nada (gate E4, igual que el resto de la construcción) ──────────
func test_sin_caja_no_se_designa() -> void:
	# Saldo a 0: el recinto entero del edificio (sin muros) cuesta de sobra (coste_por_celda × 312).
	var construccion: Node = _mundo(0.0)[0]

	var sala_id: StringName = construccion.designar_zona(Vector2i(0, 0), TIPO_SALA)

	assert_str(String(sala_id)).is_equal("")


# ── 9. Fuera del edificio: recinto_de devuelve vacío ─────────────────────────────────────────
func test_recinto_de_fuera_del_edificio_esta_vacio() -> void:
	var construccion: Node = _mundo()[0]

	assert_bool(construccion.recinto_de(Vector2i(-1, 5)).is_empty()).is_true()
