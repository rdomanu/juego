# EL HUECO QUE SE RESPETA ES EL QUE ELIGE EL JUGADOR (petición del usuario 2026-08-04: *"al poner
# una puerta, que se respete el hueco por donde entran"*).
#
# Verificado EN EL MOTOR con navegación física real (`tools/_diag_hueco_puerta.gd` — 2 casos,
# PASA/FALLA con intersección de segmentos, capturas en production/qa/evidence/): el NPC entra
# EXACTAMENTE por la arista de la puerta y no atraviesa ninguna otra pared de la sala.
#
# Este test cubre la MISMA propiedad en el MODELO LÓGICO (BFS sobre `Construccion.deja_pasar`),
# determinista y sin escena/NavigationServer — la verdad que consulta `NPCsFlujo.hay_camino` antes de
# tocar a ningún agente de navegación. No repite la física (eso ya lo prueba el diagnóstico); prueba
# que el CAMINO CELDA A CELDA reconstruido usa la arista exacta de la puerta y ninguna otra, y que
# cerrar esa arista concreta (sin abrir otra) deja la sala sin camino — es decir, que es EL ÚNICO
# hueco, no "uno cualquiera que coincidió".
#
# Tipo: Integration (Construccion REAL, sin mocks). DETERMINISTA: BFS puro sobre un layout fijo.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")

## Sala Documentación, puerta en el tramo SUR de (4,3) — el otro medio del mismo lado (sur de (5,3))
## se queda TABIQUE, para probar que el hueco elegido es ESE y no "cualquier punto de ese lado".
const SALA_SUR_RECT := Rect2i(4, 2, 2, 2)
const SALA_SUR_CELDA_PUERTA := Vector2i(4, 3)
const SALA_SUR_LADO_PUERTA := &"abajo"
const SALA_SUR_ORIGEN := Vector2i(4, 5)   # fuera de la sala, al sur de su puerta
const SALA_SUR_DESTINO := Vector2i(5, 2)  # esquina opuesta, dentro de la sala

## Sala ODAC, puerta en el tramo ESTE de (11,2) — el otro medio del mismo lado (este de (11,3)) se
## queda TABIQUE.
const SALA_ESTE_RECT := Rect2i(10, 2, 2, 2)
const SALA_ESTE_CELDA_PUERTA := Vector2i(11, 2)
const SALA_ESTE_LADO_PUERTA := &"derecha"
const SALA_ESTE_ORIGEN := Vector2i(13, 2)   # fuera de la sala, al este de su puerta
const SALA_ESTE_DESTINO := Vector2i(10, 3)  # esquina opuesta, dentro de la sala


## Construcción real con una sala amurallada ENTERA (8 tabiques) — sin puerta todavía.
func _construccion_con_sala_sellada(sala_id: StringName, rect: Rect2i) -> Node:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.construir_de_oficio_sala(sala_id, rect)
	for x: int in range(rect.position.x, rect.position.x + rect.size.x):
		construccion.construir_muro(Vector2i(x, rect.position.y), &"arriba")
		construccion.construir_muro(Vector2i(x, rect.position.y + rect.size.y - 1), &"abajo")
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		construccion.construir_muro(Vector2i(rect.position.x, y), &"izquierda")
		construccion.construir_muro(Vector2i(rect.position.x + rect.size.x - 1, y), &"derecha")
	return construccion


## BFS celda a celda sobre `Construccion.deja_pasar` (la MISMA regla que usa `distancia_en_celdas` y
## `hay_camino`), pero con reconstrucción de ruta — que la API pública de Construccion no expone
## (solo da la distancia). Usa `Construccion.VECINOS_4` (pública) como única fuente de los 4 pasos,
## para no duplicar la tabla lado→delta. Vacío si no hay camino.
func _bfs_camino(construccion: Node, origen: Vector2i, destino: Vector2i) -> Array[Vector2i]:
	if origen == destino:
		return [origen]
	var anterior: Dictionary[Vector2i, Vector2i] = {}
	var visitadas: Dictionary[Vector2i, bool] = {origen: true}
	var cola: Array[Vector2i] = [origen]
	var cabeza: int = 0
	var columnas: int = int(construccion.edificio_columnas)
	var filas: int = int(construccion.edificio_filas)
	while cabeza < cola.size():
		var celda: Vector2i = cola[cabeza]
		cabeza += 1
		for paso: Array in construccion.VECINOS_4:
			if not construccion.deja_pasar(celda, paso[0]):
				continue
			var vecina: Vector2i = celda + (paso[1] as Vector2i)
			if vecina.x < 0 or vecina.y < 0 or vecina.x >= columnas or vecina.y >= filas:
				continue
			if visitadas.has(vecina):
				continue
			visitadas[vecina] = true
			anterior[vecina] = celda
			if vecina == destino:
				var camino: Array[Vector2i] = [destino]
				var actual: Vector2i = destino
				while actual != origen:
					actual = anterior[actual]
					camino.push_front(actual)
				return camino
			cola.append(vecina)
	return []


## ¿El camino (lista de celdas consecutivas) da, en algún tramo, el paso EXACTO celda→lado descrito
## (en cualquiera de los dos sentidos)? Es la comprobación de "cruza esta arista concreta".
func _camino_cruza(camino: Array[Vector2i], celda: Vector2i, lado: StringName) -> bool:
	var delta: Vector2i = Vector2i.ZERO
	for paso: Array in Construccion.VECINOS_4:
		if paso[0] == lado:
			delta = paso[1]
	var vecina: Vector2i = celda + delta
	for i: int in range(camino.size() - 1):
		var a: Vector2i = camino[i]
		var b: Vector2i = camino[i + 1]
		if (a == celda and b == vecina) or (a == vecina and b == celda):
			return true
	return false


# ── CASO SUR: el camino cruza la puerta sur de (4,3) y ninguna otra arista de esa sala ──────────
func test_puerta_en_tramo_sur_el_camino_cruza_exactamente_esa_arista() -> void:
	# Arrange
	var construccion: Node = _construccion_con_sala_sellada(&"sala_espera_doc", SALA_SUR_RECT)
	assert_int(
		construccion.distancia_en_celdas(SALA_SUR_ORIGEN, SALA_SUR_DESTINO)
	).is_equal(-1)   # sellada: todavía sin camino
	var abierta: bool = construccion.fijar_tipo_de_muro(
		SALA_SUR_CELDA_PUERTA, SALA_SUR_LADO_PUERTA, construccion.PUERTA
	)
	assert_bool(abierta).is_true()

	# Act
	var camino: Array[Vector2i] = _bfs_camino(construccion, SALA_SUR_ORIGEN, SALA_SUR_DESTINO)

	# Assert: hay camino, coincide en longitud con `distancia_en_celdas` (misma verdad), cruza SU
	# puerta y NO cruza el otro medio del mismo lado (sur de (5,3): sigue siendo TABIQUE).
	assert_array(camino).is_not_empty()
	assert_int(camino.size() - 1).is_equal(
		construccion.distancia_en_celdas(SALA_SUR_ORIGEN, SALA_SUR_DESTINO)
	)
	assert_bool(
		_camino_cruza(camino, SALA_SUR_CELDA_PUERTA, SALA_SUR_LADO_PUERTA)
	).is_true()
	assert_bool(
		_camino_cruza(camino, Vector2i(5, 3), &"abajo")
	).is_false()

	# Y si se cierra esa arista concreta (sin abrir ninguna otra), la sala vuelve a quedar sin
	# camino: prueba que era LA ÚNICA puerta, no "una que coincidió con la ruta más corta".
	construccion.fijar_tipo_de_muro(SALA_SUR_CELDA_PUERTA, SALA_SUR_LADO_PUERTA, construccion.TABIQUE)
	assert_int(
		construccion.distancia_en_celdas(SALA_SUR_ORIGEN, SALA_SUR_DESTINO)
	).is_equal(-1)


# ── CASO ESTE: el camino cruza la puerta este de (11,2) y ninguna otra arista de esa sala ───────
func test_puerta_en_tramo_este_el_camino_cruza_exactamente_esa_arista() -> void:
	# Arrange
	var construccion: Node = _construccion_con_sala_sellada(&"sala_espera_odac", SALA_ESTE_RECT)
	assert_int(
		construccion.distancia_en_celdas(SALA_ESTE_ORIGEN, SALA_ESTE_DESTINO)
	).is_equal(-1)
	var abierta: bool = construccion.fijar_tipo_de_muro(
		SALA_ESTE_CELDA_PUERTA, SALA_ESTE_LADO_PUERTA, construccion.PUERTA
	)
	assert_bool(abierta).is_true()

	# Act
	var camino: Array[Vector2i] = _bfs_camino(construccion, SALA_ESTE_ORIGEN, SALA_ESTE_DESTINO)

	# Assert: hay camino, coincide en longitud con `distancia_en_celdas`, cruza SU puerta y NO cruza
	# el otro medio del mismo lado (este de (11,3): sigue siendo TABIQUE).
	assert_array(camino).is_not_empty()
	assert_int(camino.size() - 1).is_equal(
		construccion.distancia_en_celdas(SALA_ESTE_ORIGEN, SALA_ESTE_DESTINO)
	)
	assert_bool(
		_camino_cruza(camino, SALA_ESTE_CELDA_PUERTA, SALA_ESTE_LADO_PUERTA)
	).is_true()
	assert_bool(
		_camino_cruza(camino, Vector2i(11, 3), &"derecha")
	).is_false()

	construccion.fijar_tipo_de_muro(SALA_ESTE_CELDA_PUERTA, SALA_ESTE_LADO_PUERTA, construccion.TABIQUE)
	assert_int(
		construccion.distancia_en_celdas(SALA_ESTE_ORIGEN, SALA_ESTE_DESTINO)
	).is_equal(-1)
