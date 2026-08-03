# REGRESIÓN — "sin camino ⇒ sin teletransporte" (bug reportado por el usuario 2026-08-03: *"las
# personas, si no pueden acceder a una sala porque hay paredes, SALTAN"*).
#
# `NPCsFlujo.hay_camino` es la ÚNICA puerta por la que pasa cualquier cambio de destino de un NPC
# (ciudadano o funcionario) antes de tocar al agente de navegación — ver `NPCCiudadano.
# _actualizar_destino` y `NPCsFlujo._fijar_destino_caminante`. Este test cubre esa función
# DIRECTAMENTE (BFS puro sobre `Construccion`, sin escena ni NavigationServer): es la misma verdad
# que consultan los dos sitios de arriba, así que probarla aquí es determinista y no depende de que
# el NavigationServer haya sincronizado (gotcha del 1er physics frame, ver engine-reference/godot/
# modules/navigation.md) ni de ningún reloj.
#
# Caso 2 es la REGRESIÓN encontrada al verificar el arreglo con `tools/_diag_bloqueo.gd`: el origen
# real de un ciudadano que ACABA de ser admitido es un punto de la CALLE (`_punto_calle`), fuera a
# propósito de la rejilla del edificio. Antes del arreglo, `hay_camino` exigía que el origen TAMBIÉN
# estuviera "en edificio" — así que CUALQUIER entrada desde la calle se marcaba BLOQUEADA para
# siempre, aunque la comisaría estuviera abierta de par en par.
#
# Tipo: Integration (Construccion REAL, sin mocks). DETERMINISTA: BFS sobre un layout fijo.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const NPCsFlujoScript := preload("res://src/main/npcs_flujo.gd")

const TAM_CELDA: int = 40
## La sala sellada de la regresión original: 2×2 celdas, SIN puerta en ninguno de sus 4 lados.
const SALA_RECT := Rect2i(4, 2, 2, 2)


## Construcción real con la sala sellada (8 muros, sin puerta) + NPCsFlujo enganchado a ella (sin
## navegación ni personal — `hay_camino` solo necesita `Construccion`).
func _mundo() -> Array:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.construir_de_oficio_sala(&"sala_espera_doc", SALA_RECT)
	for x: int in range(SALA_RECT.position.x, SALA_RECT.position.x + SALA_RECT.size.x):
		construccion.construir_muro(Vector2i(x, SALA_RECT.position.y), &"arriba")
		construccion.construir_muro(Vector2i(x, SALA_RECT.position.y + SALA_RECT.size.y - 1), &"abajo")
	for y: int in range(SALA_RECT.position.y, SALA_RECT.position.y + SALA_RECT.size.y):
		construccion.construir_muro(Vector2i(SALA_RECT.position.x, y), &"izquierda")
		construccion.construir_muro(Vector2i(SALA_RECT.position.x + SALA_RECT.size.x - 1, y), &"derecha")
	var npcs: Node = auto_free(NPCsFlujoScript.new())
	npcs.configurar(null, construccion, null, TAM_CELDA, Vector2.ZERO, 24, 13, null)
	return [construccion, npcs]


## Un punto dentro de la sala sellada (celda (5,2), esquina más alejada de la futura puerta norte).
func _punto_dentro_de_la_sala() -> Vector2:
	return Proyeccion.centro_cuadrado(Vector2i(5, 2))


# ── 1. Sala sellada sin puerta: NO hay camino ─────────────────────────────────────────────────
func test_sala_sellada_sin_puerta_no_tiene_camino() -> void:
	var mundo: Array = _mundo()
	var npcs: Node = mundo[1]
	var origen: Vector2 = Proyeccion.centro_cuadrado(Vector2i(10, 6))   # otra zona del edificio
	assert_bool(npcs.hay_camino(origen, _punto_dentro_de_la_sala())).is_false()


# ── 2. LA REGRESIÓN: origen en la CALLE (fuera de rejilla) + destino alcanzable ⇒ SÍ hay camino ──
# Antes del arreglo esto daba `false` siempre (el origen fuera de rejilla tumbaba el BFS entero),
# así que CUALQUIER ciudadano recién admitido se quedaba plantado en la calle para siempre.
func test_origen_en_la_calle_con_destino_alcanzable_no_se_bloquea() -> void:
	var mundo: Array = _mundo()
	var npcs: Node = mundo[1]
	var punto_calle := Vector2(-1.0 * TAM_CELDA, 6.5 * TAM_CELDA)   # misma fórmula que `_punto_calle`
	var destino_alcanzable: Vector2 = Proyeccion.centro_cuadrado(Vector2i(10, 6))   # fuera de la sala sellada
	assert_bool(npcs.hay_camino(punto_calle, destino_alcanzable)).is_true()


# ── 3. Origen en la calle + destino DENTRO de la sala sellada: sigue bloqueado ────────────────
# El ajuste de la calle no debe "colar" un camino inventado hacia un sitio real inalcanzable.
func test_origen_en_la_calle_con_destino_en_sala_sellada_sigue_bloqueado() -> void:
	var mundo: Array = _mundo()
	var npcs: Node = mundo[1]
	var punto_calle := Vector2(-1.0 * TAM_CELDA, 6.5 * TAM_CELDA)
	assert_bool(npcs.hay_camino(punto_calle, _punto_dentro_de_la_sala())).is_false()


# ── 4. Al abrir la puerta: la MISMA pregunta pasa a SÍ ────────────────────────────────────────
func test_abrir_la_puerta_desbloquea_el_camino() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var npcs: Node = mundo[1]
	var origen: Vector2 = Proyeccion.centro_cuadrado(Vector2i(10, 6))
	assert_bool(npcs.hay_camino(origen, _punto_dentro_de_la_sala())).is_false()

	var abierta: bool = construccion.fijar_tipo_de_muro(
		Vector2i(SALA_RECT.position.x, SALA_RECT.position.y), &"arriba", construccion.PUERTA
	)
	assert_bool(abierta).is_true()
	assert_bool(npcs.hay_camino(origen, _punto_dentro_de_la_sala())).is_true()
