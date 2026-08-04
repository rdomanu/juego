# LA PUERTA LA PONE EL JUGADOR (2026-08-04 · quick-spec §3): "Al poner paredes a una sala, el paso
# siguiente es ELEGIR LA UBICACIÓN DE LA PUERTA. No se deja ninguna puerta predeterminada (muere el
# hueco automático)."
#
# Este archivo es la regresión de esa decisión, medida donde de verdad importa: EL PASO. No se
# comprueba el dibujo (eso lo hace `construccion_puertas_visibles_test.gd`) sino si se puede ENTRAR,
# con el mismo BFS por aristas que usa la navegación (`distancia_en_celdas`, que solo cruza lo que
# `deja_pasar` deja cruzar). Amurallar ⇒ recinto cerrado (-1 desde fuera) hasta que alguien abre una
# puerta de verdad.
#
# Tipo: Integration (Construccion + Economia reales, sin mocks). DETERMINISTA: sin azar ni reloj.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")

const TIPO_SALA := &"sala_documentacion"
## La sala de pruebas y una celda de FUERA, en el mismo edificio y a la misma altura que su puerta.
const RECT_SALA := Rect2i(3, 3, 6, 5)
const CELDA_DENTRO := Vector2i(5, 5)
const CELDA_FUERA := Vector2i(1, 5)
## El tramo donde el jugador abrirá la puerta: el lado OESTE, a la altura de (3,5).
const PUERTA_CELDA := Vector2i(3, 5)
const PUERTA_LADO := &"izquierda"


func _construccion() -> Node:
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	economia.saldo_eur = 100000.0
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(economia)
	return construccion


# ── 1. Amurallar cierra el recinto: ni una sola arista transitable en todo el perímetro ───────
func test_sala_amurallada_no_tiene_ninguna_arista_transitable() -> void:
	# Arrange
	var construccion: Node = _construccion()
	var sala_id: StringName = construccion.construir_de_oficio_sala(TIPO_SALA, RECT_SALA)

	# Act
	construccion.fijar_paredes_de_sala(sala_id, true)

	# Assert — (i) el modelo no se inventa ninguna puerta; (ii) NINGUNA arista del perímetro deja
	# pasar; (iii) y por tanto no hay camino desde fuera (el BFS devuelve -1 = inalcanzable).
	assert_vector(construccion.puerta_de_sala(sala_id)).is_equal(construccion.CELDA_NULA_PUERTA)
	assert_bool(construccion.sala_amurallada_sin_puerta(sala_id)).is_true()
	var transitables: int = 0
	for x: int in range(RECT_SALA.position.x, RECT_SALA.end.x):
		for y: int in range(RECT_SALA.position.y, RECT_SALA.end.y):
			for lado: StringName in [&"izquierda", &"derecha", &"arriba", &"abajo"]:
				var celda := Vector2i(x, y)
				if construccion.sala_en(celda + _paso(lado)) == sala_id:
					continue   # arista interior: no es perímetro
				if construccion.deja_pasar(celda, lado):
					transitables += 1
	assert_int(transitables) \
		.override_failure_message("una sala recién amurallada NO puede tener aristas por las que pasar") \
		.is_equal(0)
	assert_int(construccion.distancia_en_celdas(CELDA_FUERA, CELDA_DENTRO)).is_equal(-1)


# ── 2. La puerta que abre el jugador es la que abre el paso, y solo esa ───────────────────────
func test_abrir_la_puerta_deja_pasar_exactamente_por_ese_tramo() -> void:
	# Arrange
	var construccion: Node = _construccion()
	var sala_id: StringName = construccion.construir_de_oficio_sala(TIPO_SALA, RECT_SALA)
	construccion.fijar_paredes_de_sala(sala_id, true)
	assert_int(construccion.distancia_en_celdas(CELDA_FUERA, CELDA_DENTRO)).is_equal(-1)

	# Act — el gesto del jugador con el pincel de puerta.
	var abierta: bool = construccion.fijar_tipo_de_muro(
		PUERTA_CELDA, PUERTA_LADO, construccion.PUERTA
	)

	# Assert — se pasa, y se pasa POR AHÍ: la única arista transitable del perímetro es la abierta,
	# y el modelo ya reconoce esa celda como puerta de la sala.
	assert_bool(abierta).is_true()
	assert_bool(construccion.deja_pasar(PUERTA_CELDA, PUERTA_LADO)).is_true()
	assert_bool(construccion.sala_amurallada_sin_puerta(sala_id)).is_false()
	assert_vector(construccion.puerta_de_sala(sala_id)).is_equal(PUERTA_CELDA)
	assert_bool(construccion.es_celda_de_puerta(PUERTA_CELDA)).is_true()
	assert_int(construccion.distancia_en_celdas(CELDA_FUERA, CELDA_DENTRO)).is_greater(0)


# ── 3. Una puerta no se tapia con un mueble ──────────────────────────────────────────────────
# La puerta ya no puede APARTARSE sola (es un tramo de pared del jugador), así que la única forma de
# que no se quede bloqueada es no dejar amueblar su celda.
func test_no_se_puede_colocar_un_mueble_en_la_celda_de_la_puerta() -> void:
	# Arrange
	var construccion: Node = _construccion()
	var sala_id: StringName = construccion.construir_de_oficio_sala(&"sala_espera_doc", RECT_SALA)
	construccion.fijar_paredes_de_sala(sala_id, true)
	construccion.fijar_tipo_de_muro(PUERTA_CELDA, PUERTA_LADO, construccion.PUERTA)

	# Act / Assert — en la celda de la puerta no; en la de al lado sí.
	assert_bool(construccion.validar_elemento(construccion.ASIENTO_BASICO, PUERTA_CELDA)).is_false()
	assert_bool(construccion.validar_elemento(construccion.ASIENTO_BASICO, CELDA_DENTRO)).is_true()


## El desplazamiento de un lado (mismo convenio que `Construccion.VECINOS_4`).
func _paso(lado: StringName) -> Vector2i:
	match lado:
		&"izquierda":
			return Vector2i(-1, 0)
		&"derecha":
			return Vector2i(1, 0)
		&"arriba":
			return Vector2i(0, -1)
		_:
			return Vector2i(0, 1)
