# Las VENTANAS funcionan de punta a punta en el juego (fase D/E, 2026-07-30) pero no tenían NI UN
# test dedicado — toda su cobertura era de rebote en `construccion_puertas_visibles_test.gd` (un
# único caso: "se dibuja maciza, no como hueco"). Este archivo cierra ese hueco: modelo (conversión,
# rechazo sin tabique previo, fachada intocable, bloqueo de paso, persistencia) y dibujo (color de
# cristal en cualquier lado de una sala).
#
# Tipo: Integration (Construccion + Economia + ParedesSalas REALES, sin mocks). DETERMINISTA: sin
# azar, sin reloj, sin capa visual montada al árbol (funciona headless).
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")

const TAM_CELDA: int = 40
## Tipo de sala usado en todos los tests (coste base 0 € en su .tres) — mismo que
## `construccion_puertas_visibles_test.gd`, para que el fixture sea idéntico y fácil de comparar.
const TIPO_SALA := &"sala_documentacion"
## La sala de pruebas: columnas 3..8, filas 3..7. Su puerta automática cae en (3,6) —la celda del
## perímetro más cercana a la puerta del edificio (0,6)—, así que ninguna arista de las que se
## prueban aquí coincide con ese hueco.
const RECT_SALA := Rect2i(3, 3, 6, 5)
## Las cuatro aristas de prueba, una por lado de la sala: [nombre, celda, lado].
const ARISTAS: Array = [
	["norte", Vector2i(5, 3), &"arriba"],
	["sur", Vector2i(5, 7), &"abajo"],
	["este", Vector2i(8, 5), &"derecha"],
	["oeste", Vector2i(3, 5), &"izquierda"],
]


# ── Fixtures ─────────────────────────────────────────────────────────────────────────────────
## Mundo mínimo (sin sala): Construcción + Economía con caja de sobra. Devuelve [construccion, eco].
func _mundo_construccion() -> Array:
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	economia.saldo_eur = 100000.0
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(economia)
	return [construccion, economia]


## La sala de pruebas YA con las cuatro paredes de su perímetro levantadas (tabiques). Sin capa
## visual — para los tests de modelo puro (persistencia, paso, rodeo). Devuelve [construccion, sala_id].
func _sala_construida_con_paredes() -> Array:
	var mundo: Array = _mundo_construccion()
	var construccion: Node = mundo[0]
	var sala_id: StringName = construccion.construir_de_oficio_sala(TIPO_SALA, RECT_SALA)
	construccion.fijar_paredes_de_sala(sala_id, true)
	return [construccion, sala_id]


## La misma sala con paredes, más `ParedesSalas` enganchada al hook de layout (el mismo cableado
## que hace Main): a partir de aquí, cada cambio del modelo repinta las paredes. Para los tests de
## dibujo. Devuelve [construccion, paredes, sala_id].
func _sala_con_paredes() -> Array:
	var mundo: Array = _sala_construida_con_paredes()
	var construccion: Node = mundo[0]
	var paredes: Node2D = auto_free(ParedesSalasScript.new())
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	construccion.fijar_hook_layout(Callable(paredes, "actualizar"))
	return [construccion, paredes, mundo[1]]


## Round-trip por JSON real (el camino del SaveManager), como en `construccion_save_test.gd`.
func _por_json(estado: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(estado, "", true, true))


## Los dos extremos (en coordenadas de dibujo) de la arista `lado` de `celda`. Misma cuenta que usa
## `ParedesSalas._esquina`, con desplazamiento cero (copiado de `construccion_puertas_visibles_test.gd`).
func _extremos(celda: Vector2i, lado: StringName) -> Array:
	match lado:
		&"izquierda":
			return [Proyeccion.esquina_iso(celda.x, celda.y), Proyeccion.esquina_iso(celda.x, celda.y + 1)]
		&"derecha":
			return [
				Proyeccion.esquina_iso(celda.x + 1, celda.y),
				Proyeccion.esquina_iso(celda.x + 1, celda.y + 1),
			]
		&"arriba":
			return [Proyeccion.esquina_iso(celda.x, celda.y), Proyeccion.esquina_iso(celda.x + 1, celda.y)]
		_:
			return [
				Proyeccion.esquina_iso(celda.x, celda.y + 1),
				Proyeccion.esquina_iso(celda.x + 1, celda.y + 1),
			]


## El nodo `TramoPared` (si lo hay) que cubre ese punto del mundo — mismo criterio geométrico que
## `_cubierto` en el test de puertas, pero devolviendo el NODO en vez de un booleano: aquí hace
## falta leer su color, no solo saber si hay algo pintado.
func _nodo_en(paredes: Node2D, punto: Vector2) -> Node2D:
	for hijo: Node in paredes.get_children():
		var nodo := hijo as Node2D
		var desde: Vector2 = nodo.position + (nodo.get("_desde") as Vector2)
		var hasta: Vector2 = nodo.position + (nodo.get("_hasta") as Vector2)
		if punto.distance_to(Geometry2D.get_closest_point_to_segment(punto, desde, hasta)) <= 1.0:
			return nodo
	return null


## ¿Esa arista está dibujada como VENTANA? La firma es su COLOR: `ParedesSalas` pinta el cristal
## con `COLOR_VENTANA` (distinto del gris del tabique y del color de sala de una puerta) — se
## comprueba esa propiedad directamente en vez de inferirla por geometría (huecos, muñones), que es
## la firma de una PUERTA, no la de una ventana (una ventana es maciza: cubre el centro igual que un
## tabique, ver `test_ventana_en_el_perimetro_se_dibuja_maciza_no_como_hueco` en el test de puertas).
func _dibujada_como_ventana(paredes: Node2D, celda: Vector2i, lado: StringName) -> bool:
	var extremos: Array = _extremos(celda, lado)
	var centro: Vector2 = (extremos[0] as Vector2).lerp(extremos[1] as Vector2, 0.5)
	var nodo: Node2D = _nodo_en(paredes, centro)
	if nodo == null:
		return false
	var color: Variant = nodo.get("_color")
	return color is Color and (color as Color).is_equal_approx(ParedesSalasScript.COLOR_VENTANA)


# ── 1. Conversión tabique → ventana: el modelo la acepta y cambia de tipo ─────────────────────
func test_convertir_tabique_existente_en_ventana_acepta_y_cambia_el_tipo() -> void:
	# Arrange
	var mundo: Array = _mundo_construccion()
	var construccion: Node = mundo[0]
	var celda := Vector2i(5, 5)
	var lado := &"arriba"
	assert_bool(construccion.construir_muro(celda, lado)).is_true()

	# Act
	var convertido: bool = construccion.fijar_tipo_de_muro(celda, lado, construccion.VENTANA)

	# Assert
	assert_bool(convertido).is_true()
	assert_str(String(construccion.tipo_de_muro(celda, lado))).is_equal(String(construccion.VENTANA))


# ── 2. Sin tabique previo: se rechaza y NO crea pared de la nada ──────────────────────────────
func test_convertir_sin_tabique_previo_no_crea_pared() -> void:
	# Arrange
	var mundo: Array = _mundo_construccion()
	var construccion: Node = mundo[0]
	var celda := Vector2i(5, 5)
	var lado := &"arriba"

	# Act
	var convertido: bool = construccion.fijar_tipo_de_muro(celda, lado, construccion.VENTANA)

	# Assert — ni se acepta ni deja rastro: sigue sin haber muro ahí.
	assert_bool(convertido).is_false()
	assert_bool(construccion.hay_muro(celda, lado)).is_false()
	assert_str(String(construccion.tipo_de_muro(celda, lado))).is_equal("")


# ── 3. La fachada es intocable: no se abre una ventana en ella ────────────────────────────────
func test_convertir_fachada_en_ventana_se_rechaza() -> void:
	# Arrange
	var mundo: Array = _mundo_construccion()
	var construccion: Node = mundo[0]
	construccion.levantar_fachada()
	var celda := Vector2i(0, 0)
	var lado := &"arriba"
	var antes: StringName = construccion.tipo_de_muro(celda, lado)

	# Act
	var convertido: bool = construccion.fijar_tipo_de_muro(celda, lado, construccion.VENTANA)

	# Assert
	assert_bool(convertido).is_false()
	assert_str(String(construccion.tipo_de_muro(celda, lado))).is_equal(String(antes))


# ── 4a. La ventana NO deja pasar (a diferencia de la puerta) ──────────────────────────────────
func test_ventana_no_deja_pasar_por_esa_arista() -> void:
	# Arrange
	var mundo: Array = _mundo_construccion()
	var construccion: Node = mundo[0]
	var celda := Vector2i(5, 5)
	var lado := &"arriba"
	assert_bool(construccion.construir_muro(celda, lado)).is_true()

	# Act
	assert_bool(construccion.fijar_tipo_de_muro(celda, lado, construccion.VENTANA)).is_true()

	# Assert
	assert_bool(construccion.deja_pasar(celda, lado)).is_false()


# ── 4b. EL CASO JUGOSO: sala amurallada con VENTANA en vez de puerta sigue INCOMUNICADA ───────
# Si el jugador quería una puerta y puso una ventana por error, la sala NO gana un acceso: sigue
# sellada. `deja_pasar` ya lo garantiza arista a arista (4a); este test lo comprueba a nivel de
# CAMINO real con `distancia_en_celdas`, que es lo que consultan los cronómetros de NPCs.
func test_sala_amurallada_con_ventana_en_vez_de_puerta_sigue_incomunicada() -> void:
	# Arrange — sala con las cuatro paredes YA levantadas (tabique en todo el perímetro).
	var mundo: Array = _sala_construida_con_paredes()
	var construccion: Node = mundo[0]
	var celda_borde := Vector2i(5, 3)   # lado norte de la sala (arista ["norte", (5,3), "arriba"])
	var lado := &"arriba"

	# Act — se convierte ese tramo del perímetro en ventana (no en puerta).
	assert_bool(construccion.fijar_tipo_de_muro(celda_borde, lado, construccion.VENTANA)).is_true()

	# Assert — de dentro de la sala a fuera de ella no hay camino: la ventana no cuenta como acceso.
	var dentro := Vector2i(5, 5)
	var fuera := Vector2i(5, 1)
	assert_int(construccion.distancia_en_celdas(dentro, fuera)).is_equal(-1)


# ── 4c. Con una puerta alternativa, la distancia REFLEJA EL RODEO alrededor de la ventana ─────
# Una sala partida en dos por un tabique interior con dos aristas convertidas: una a PUERTA (el
# único paso real) y otra a VENTANA (bloqueada). El camino más corto entre las dos celdas que
# CONFRONTAN la ventana no es 1 (cruzarla) sino el rodeo hasta la puerta y vuelta.
func test_distancia_en_celdas_rodea_una_ventana_cuando_hay_puerta_alternativa() -> void:
	# Arrange — sala con paredes + tabique interior en x=6 (columnas 3-5 oeste / 6-8 este), filas 3..7.
	var mundo: Array = _sala_construida_con_paredes()
	var construccion: Node = mundo[0]
	for y: int in range(3, 8):
		assert_bool(construccion.construir_muro(Vector2i(5, y), &"derecha")).is_true()
	# La única puerta real del tabique interior está en la fila 5...
	assert_bool(
		construccion.fijar_tipo_de_muro(Vector2i(5, 5), &"derecha", construccion.PUERTA)
	).is_true()
	# ...y en la fila 3 hay una ventana: separa (5,3) de (6,3) sin dejarlas pasar directamente.
	assert_bool(
		construccion.fijar_tipo_de_muro(Vector2i(5, 3), &"derecha", construccion.VENTANA)
	).is_true()

	# Act
	var distancia: int = construccion.distancia_en_celdas(Vector2i(5, 3), Vector2i(6, 3))

	# Assert — ni 1 (cruzar la ventana) ni -1 (incomunicado): el rodeo real hasta la puerta y vuelta,
	# (5,3)→(5,4)→(5,5)→[puerta]→(6,5)→(6,4)→(6,3) = 5 tramos.
	assert_int(distancia).is_equal(5)


# ── 5. Ida y vuelta ventana → puerta → ventana: SIEMPRE el tipo correcto y SIEMPRE gratis ─────
func test_conversiones_de_ida_y_vuelta_ventana_puerta_ventana_no_cuestan_nada() -> void:
	# Arrange
	var mundo: Array = _mundo_construccion()
	var construccion: Node = mundo[0]
	var economia: Node = mundo[1]
	var celda := Vector2i(5, 5)
	var lado := &"arriba"
	assert_bool(construccion.construir_muro(celda, lado)).is_true()
	var saldo_tras_construir: float = economia.saldo_eur

	# Act / Assert — ventana
	assert_bool(construccion.fijar_tipo_de_muro(celda, lado, construccion.VENTANA)).is_true()
	assert_str(String(construccion.tipo_de_muro(celda, lado))).is_equal(String(construccion.VENTANA))

	# Act / Assert — puerta
	assert_bool(construccion.fijar_tipo_de_muro(celda, lado, construccion.PUERTA)).is_true()
	assert_str(String(construccion.tipo_de_muro(celda, lado))).is_equal(String(construccion.PUERTA))

	# Act / Assert — ventana otra vez
	assert_bool(construccion.fijar_tipo_de_muro(celda, lado, construccion.VENTANA)).is_true()
	assert_str(String(construccion.tipo_de_muro(celda, lado))).is_equal(String(construccion.VENTANA))

	# Assert — ninguna de las tres conversiones tocó la caja: abrir/cerrar huecos es gratis.
	assert_float(economia.saldo_eur).is_equal_approx(saldo_tras_construir, 0.0001)


# ── 6. Persistencia: save → JSON → load conserva el tipo VENTANA ──────────────────────────────
func test_guardar_y_cargar_conserva_el_tipo_ventana() -> void:
	# Arrange — mundo A con una ventana ya abierta en el perímetro de la sala.
	var mundo_a: Array = _sala_construida_con_paredes()
	var a: Node = mundo_a[0]
	var celda := Vector2i(5, 3)
	var lado := &"arriba"
	assert_bool(a.fijar_tipo_de_muro(celda, lado, a.VENTANA)).is_true()

	# Act — save → JSON real (full_precision, el camino del SaveManager) → load en un mundo B nuevo.
	var mundo_b: Array = _mundo_construccion()
	var b: Node = mundo_b[0]
	b.load_state(_por_json(a.save()))

	# Assert — la arista revive como VENTANA, no como tabique ni como puerta.
	assert_str(String(b.tipo_de_muro(celda, lado))).is_equal(String(a.VENTANA))


# ── 7. Dibujo: una ventana en CUALQUIER lado de la sala se pinta como cristal ──────────────────
# Mismo espíritu que `test_puerta_en_cualquier_lado_de_la_sala_se_dibuja_como_puerta` del test de
# puertas (el bug de origen era justo que solo UN lado se dibujaba bien): aquí se comprueba que el
# camino de dibujo trata la ventana igual en los cuatro lados del perímetro de una sala.
func test_ventana_en_cualquier_lado_de_la_sala_se_dibuja_como_ventana() -> void:
	for arista: Array in ARISTAS:
		# Arrange — sala nueva por cada lado: ningún lado depende de lo que hiciera el anterior.
		var mundo: Array = _sala_con_paredes()
		var construccion: Node = mundo[0]
		var paredes: Node2D = mundo[1]
		var celda: Vector2i = arista[1]
		var lado: StringName = arista[2]

		# Act
		var puesta: bool = construccion.fijar_tipo_de_muro(celda, lado, construccion.VENTANA)

		# Assert
		assert_bool(puesta) \
			.override_failure_message("el modelo debe aceptar la ventana en el lado %s" % arista[0]) \
			.is_true()
		assert_bool(_dibujada_como_ventana(paredes, celda, lado)) \
			.override_failure_message("la ventana del lado %s tiene que verse como cristal" % arista[0]) \
			.is_true()
