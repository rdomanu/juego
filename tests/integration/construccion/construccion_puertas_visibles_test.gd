# REGRESIÓN DE LOS DOS BUGS DE PUERTAS (2026-08-03, el usuario jugando):
#   (a) *"la puerta SOLO se deja colocar en una única zona de la pared que aparece blanca"*.
#   (b) PUERTAS FANTASMA: *"lo intenté en varios sitios (parecía que no dejaba), la puse en la zona
#       blanca… y DESPUÉS aparecieron puertas donde había hecho los clics rechazados"*.
#
# CAUSA ÚNICA de los dos: `ParedesSalas` tenía DOS caminos de dibujo para la misma arista física. El
# del PERÍMETRO DE UNA SALA pintaba siempre un tramo macizo (miraba el `rect` de la sala, jamás el
# tipo del muro) y además RECLAMABA la arista, así que el camino de MUROS LIBRES —el único que sabía
# de puertas y ventanas— se la saltaba. Abrir una puerta en la pared de una sala funcionaba en el
# MODELO y no se veía; las puertas se quedaban guardadas y aparecían de golpe en cuanto la sala
# dejaba de estar "con paredes" (basta con derribar un tramo).
#
# Tipo: Integration (Construccion + Economia + ParedesSalas REALES, sin mocks). Se comprueba la
# GEOMETRÍA QUE SE VA A DIBUJAR (los nodos `TramoPared` que cuelgan de `ParedesSalas`), no el modelo:
# el modelo ya estaba bien — lo que fallaba era el dibujo, y un test sobre el modelo no habría cazado
# nada. DETERMINISTA: sin azar, sin reloj, sin capa visual montada (funciona headless).
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")

const TAM_CELDA: int = 40
## Tipo de sala usado en todos los tests (coste base 0 € en su .tres).
const TIPO_SALA := &"sala_documentacion"
## La sala de pruebas: columnas 3..8, filas 3..7. (Hasta 2026-08-04 su puerta automática caía en
## (3,6); ese hueco ya no existe — la sala nace cerrada y la puerta la abre quien juega.)
const RECT_SALA := Rect2i(3, 3, 6, 5)
## Las cuatro aristas de prueba, una por lado de la sala: [nombre, celda, lado].
const ARISTAS: Array = [
	["norte", Vector2i(5, 3), &"arriba"],
	["sur", Vector2i(5, 7), &"abajo"],
	["este", Vector2i(8, 5), &"derecha"],
	["oeste", Vector2i(3, 5), &"izquierda"],
]


# ── Fixture ──────────────────────────────────────────────────────────────────────────────────
## Una sala con TODAS sus paredes levantadas y su capa de dibujo enganchada al hook de layout (el
## mismo cableado que hace Main): a partir de aquí, cada cambio del modelo repinta las paredes.
## Devuelve [construccion, paredes, sala_id].
func _sala_con_paredes() -> Array:
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	economia.saldo_eur = 100000.0
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(economia)
	var sala_id: StringName = construccion.construir_de_oficio_sala(TIPO_SALA, RECT_SALA)
	construccion.fijar_paredes_de_sala(sala_id, true)
	var paredes: Node2D = auto_free(ParedesSalasScript.new())
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	construccion.fijar_hook_layout(Callable(paredes, "actualizar"))
	return [construccion, paredes, sala_id]


## Los dos extremos (en coordenadas de dibujo) de la arista `lado` de `celda`. Misma cuenta que usa
## `ParedesSalas._esquina`, con desplazamiento cero.
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


## ¿Hay ALGÚN tramo de pared dibujado sobre ese punto? Se leen los NODOS que `ParedesSalas` ha creado
## (lo que de verdad se va a pintar), no una lista intermedia: cada `TramoPared` guarda su base en
## coordenadas locales y su `position` es el punto de orden, así que el segmento en mundo es
## `position + _desde` … `position + _hasta`.
func _cubierto(paredes: Node2D, punto: Vector2) -> bool:
	for hijo: Node in paredes.get_children():
		var nodo := hijo as Node2D
		var desde: Vector2 = nodo.position + (nodo.get("_desde") as Vector2)
		var hasta: Vector2 = nodo.position + (nodo.get("_hasta") as Vector2)
		if punto.distance_to(Geometry2D.get_closest_point_to_segment(punto, desde, hasta)) <= 1.0:
			return true
	return false


## ¿Esa arista está dibujada como PUERTA? La firma de una puerta es inconfundible: los dos extremos
## pintados (los muñones que la mantienen leyéndose como el mismo tabique) y el CENTRO LIBRE (el
## hueco por el que se pasa). Se piden las tres cosas a la vez para que no cuele un tramo que
## simplemente no se haya dibujado.
func _dibujada_como_puerta(paredes: Node2D, celda: Vector2i, lado: StringName) -> bool:
	var extremos: Array = _extremos(celda, lado)
	var desde: Vector2 = extremos[0]
	var hasta: Vector2 = extremos[1]
	return (
		_cubierto(paredes, desde.lerp(hasta, 0.10))
		and not _cubierto(paredes, desde.lerp(hasta, 0.50))
		and _cubierto(paredes, desde.lerp(hasta, 0.90))
	)


## ¿Esa arista está dibujada como tabique MACIZO? (el centro cubierto).
func _dibujada_como_muro(paredes: Node2D, celda: Vector2i, lado: StringName) -> bool:
	var extremos: Array = _extremos(celda, lado)
	return _cubierto(paredes, (extremos[0] as Vector2).lerp(extremos[1] as Vector2, 0.5))


## Volcado ORDENADO y estable del modelo de muros ("clave=tipo" por línea): dos volcados iguales
## significan que el modelo no se movió ni un bit.
func _volcado(construccion: Node) -> String:
	var claves: Array[String] = construccion.muros()
	claves.sort()
	var lineas: PackedStringArray = PackedStringArray()
	for clave: String in claves:
		lineas.append("%s=%s" % [clave, construccion.tipo_muro_de_clave(clave)])
	return "\n".join(lineas)


# ── 1. EL BUG (a): una puerta se VE en CUALQUIER lado de la sala, no solo en uno ──────────────
# Antes del arreglo este test fallaba en los cuatro lados: el modelo aceptaba la conversión y el
# dibujo seguía pintando un tramo macizo.
func test_puerta_en_cualquier_lado_de_la_sala_se_dibuja_como_puerta() -> void:
	for arista: Array in ARISTAS:
		# Arrange — sala nueva por cada lado: así ningún lado depende de lo que hiciera el anterior.
		var mundo: Array = _sala_con_paredes()
		var construccion: Node = mundo[0]
		var paredes: Node2D = mundo[1]
		var celda: Vector2i = arista[1]
		var lado: StringName = arista[2]
		assert_bool(_dibujada_como_muro(paredes, celda, lado)) \
			.override_failure_message("de partida el lado %s tiene que ser pared maciza" % arista[0]) \
			.is_true()

		# Act — abrir la puerta ahí (lo que hace el clic del jugador vía `_convertir_arista_en`).
		var abierta: bool = construccion.fijar_tipo_de_muro(celda, lado, construccion.PUERTA)

		# Assert — aceptada por el modelo Y dibujada como puerta.
		assert_bool(abierta) \
			.override_failure_message("el modelo debe aceptar la puerta en el lado %s" % arista[0]) \
			.is_true()
		assert_bool(_dibujada_como_puerta(paredes, celda, lado)) \
			.override_failure_message("la puerta del lado %s tiene que VERSE" % arista[0]) \
			.is_true()


# ── 2. EL BUG (b): ninguna puerta aparece de golpe al romperse el perímetro ───────────────────
# El disparador real del fantasma: la sala deja de estar "con paredes" (basta derribar un tramo) y el
# dibujo pasa al camino de muros libres. Antes, las tres puertas guardadas se materializaban ahí.
func test_romper_el_perimetro_no_materializa_puertas_ocultas() -> void:
	# Arrange — tres puertas en tres lados distintos, ya abiertas y (tras el arreglo) ya visibles.
	var mundo: Array = _sala_con_paredes()
	var construccion: Node = mundo[0]
	var paredes: Node2D = mundo[1]
	var puestas: Array = [ARISTAS[0], ARISTAS[1], ARISTAS[2]]
	for arista: Array in puestas:
		construccion.fijar_tipo_de_muro(arista[1], arista[2], construccion.PUERTA)
	var visibles_antes: int = 0
	for arista: Array in puestas:
		if _dibujada_como_puerta(paredes, arista[1], arista[2]):
			visibles_antes += 1

	# Act — se derriba UN tramo del perímetro ajeno a las tres puertas: la sala deja de tener paredes
	# completas y el dibujo cambia de camino.
	assert_bool(construccion.demoler_muro(Vector2i(6, 3), &"arriba")).is_true()
	assert_bool(construccion.sala_con_paredes(mundo[2])).is_false()

	# Assert — el recuento NO cambia. Las tres ya se veían antes (no había nada oculto que revelar).
	var visibles_despues: int = 0
	for arista: Array in puestas:
		if _dibujada_como_puerta(paredes, arista[1], arista[2]):
			visibles_despues += 1
	assert_int(visibles_antes).is_equal(3)
	assert_int(visibles_despues).is_equal(visibles_antes)


# ── 3. Un intento INVÁLIDO no deja rastro en el modelo ────────────────────────────────────────
# "Ningún clic se guarda para luego": convertir una arista donde no hay pared (o la fachada, que es
# intocable) devuelve false y el modelo queda BIT A BIT idéntico.
func test_conversion_invalida_no_deja_rastro_en_el_modelo() -> void:
	# Arrange
	var mundo: Array = _sala_con_paredes()
	var construccion: Node = mundo[0]
	construccion.levantar_fachada()
	var antes: String = _volcado(construccion)

	# Act — (i) arista interior de la sala, sin pared que convertir; (ii) la fachada del edificio.
	var sin_pared: bool = construccion.fijar_tipo_de_muro(Vector2i(5, 5), &"arriba", construccion.PUERTA)
	var fachada: bool = construccion.fijar_tipo_de_muro(Vector2i(0, 0), &"arriba", construccion.PUERTA)

	# Assert
	assert_bool(sin_pared).is_false()
	assert_bool(fachada).is_false()
	assert_str(_volcado(construccion)).is_equal(antes)


# ── 4. MURIÓ EL HUECO AUTOMÁTICO: una sala amurallada se dibuja CERRADA ──────────────────────
# Antes, toda sala nacía con una "puerta" elegida sola y el dibujo pintaba ahí un vano… por el que no
# se pasaba (en el modelo era tabique macizo). Desde la quick-spec §3 la puerta la elige el jugador,
# así que amurallar no deja ningún hueco: NINGUNA unidad del perímetro puede verse como puerta, y el
# modelo no declara puerta ninguna.
func test_amurallar_no_deja_ningun_hueco_dibujado() -> void:
	# Arrange / Act
	var mundo: Array = _sala_con_paredes()
	var construccion: Node = mundo[0]
	var paredes: Node2D = mundo[1]

	# Assert — el modelo no tiene puerta, y el dibujo tampoco: los cuatro lados macizos, incluida la
	# celda donde caía el viejo hueco automático (el borde oeste, el más cercano al acceso (0,6)).
	assert_vector(construccion.puerta_de_sala(mundo[2])).is_equal(construccion.CELDA_NULA_PUERTA)
	assert_bool(_dibujada_como_muro(paredes, Vector2i(RECT_SALA.position.x, 6), &"izquierda")).is_true()
	for arista: Array in ARISTAS:
		assert_bool(_dibujada_como_puerta(paredes, arista[1], arista[2])) \
			.override_failure_message("el lado %s no puede tener hueco sin que nadie lo abra" % arista[0]) \
			.is_false()


# ── 5. Una VENTANA no se confunde con una puerta: es pared con cristal, no un hueco ──────────
# El mismo camino de dibujo atiende los tres tipos; si se cruzaran, una ventana dejaría pasar a la
# gente por donde no debe (`deja_pasar` solo abre las puertas).
func test_ventana_en_el_perimetro_se_dibuja_maciza_no_como_hueco() -> void:
	# Arrange
	var mundo: Array = _sala_con_paredes()
	var construccion: Node = mundo[0]
	var paredes: Node2D = mundo[1]

	# Act
	var puesta: bool = construccion.fijar_tipo_de_muro(Vector2i(5, 3), &"arriba", construccion.VENTANA)

	# Assert
	assert_bool(puesta).is_true()
	assert_bool(_dibujada_como_muro(paredes, Vector2i(5, 3), &"arriba")).is_true()
	assert_bool(_dibujada_como_puerta(paredes, Vector2i(5, 3), &"arriba")).is_false()
	assert_bool(construccion.deja_pasar(Vector2i(5, 3), &"arriba")).is_false()
