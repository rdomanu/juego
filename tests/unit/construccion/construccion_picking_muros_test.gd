# REGRESIÓN "cursor desviado" (bug reportado 2026-08-06, playtest: "es difícil jugar con el cursor
# desviado"). El picking EN VIVO de `ModoConstruccion` -- sala nueva/arrastre/AMPLIAR (`_process` y
# `_al_soltar`), puesto, asiento, comodidad, pincel de muro nuevo -- usaba
# `Construccion.celda_bajo_cursor()`, un picking de SUELO puro que ignora que las paredes suben
# `ParedesSalas.ALTO_PARED` (65px) en pantalla: un punto sobre la CARA VISIBLE de un muro caía en la
# celda de DETRÁS de esa pared. El fix del día anterior (`tramo_bajo_punto`, point-in-quad) solo
# estaba enchufado en `_celda_lado_de_muro_en` (pintar pared / puerta-ventana / demoler). El fix de
# HOY añade `ModoConstruccion._celda_bajo_cursor_consciente_de_muros()`, que REUTILIZA esa misma
# función para las demás herramientas, y la conecta en los DOS sitios que antes llamaban a
# `celda_bajo_cursor()`: el resaltado en vivo (`_process`, línea ~968) y la acción real de soltar el
# arrastre de una sala nueva (`_al_soltar`, línea ~619). Los dos sitios delegan en la MISMA función
# de una línea, así que un test de esa función cubre a los dos.
#
# Tipo: Unit/Integration (Construccion + ParedesSalas + ModoConstruccion reales, sin mocks).
# DETERMINISTA: sin azar, sin reloj, sin GPU (mismo patrón que `construccion_pintura_test.gd`).
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")

const TAM_CELDA: int = 40
const SALA := &"sala_documentacion"


## Construcción + ParedesSalas cableados (mismo patrón que `construccion_pintura_test.gd`), sin
## muros todavía -- cada test levanta los suyos. El HOOK DE LAYOUT (igual que `construccion_pintura_
## _test.gd`) es imprescindible: `ParedesSalas` no se auto-refresca, así que sin él los muros que un
## test construye DESPUÉS de este fixture nunca llegarían a `_tramos` y `tramo_bajo_punto` no
## acertaría nada (fallo real visto en la primera versión de este fichero).
func _mundo() -> Dictionary:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.montar_visual(TAM_CELDA, Vector2.ZERO)
	var paredes: Node2D = auto_free(ParedesSalasScript.new())
	add_child(paredes)
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	construccion.fijar_hook_layout(Callable(paredes, "actualizar"))
	return {"construccion": construccion, "paredes": paredes}


## Un `ModoConstruccion` cableado con la misma inyección de dependencias que usa `Main`
## (`configurar(construccion, tam_celda, paredes_salas)`). A PROPÓSITO sin `add_child`: `_ready()`
## monta la barra de herramientas completa (`_crear_ui`), que necesita más contexto del que este
## test de picking puro tiene por qué levantar (revienta por un `Nil` de config no inyectada) --
## `_celda_lado_de_muro_en` no toca el árbol ni la UI, así que no le hace falta estar dentro de él.
func _modo(construccion: Node, paredes: Node) -> Node2D:
	var modo: Node2D = auto_free(ModoConstruccionScript.new())
	modo.configurar(construccion, TAM_CELDA, paredes)
	return modo


## Sala de 1 celda de alto en `fila` (columnas 0..3), con muros de verdad -- así su tramo NORTE
## vive EXACTAMENTE en esa fila (no en el borde de una sala más grande, ver la sonda numérica).
func _sala_de_una_fila(construccion: Node, fila: int) -> StringName:
	var sala_id: StringName = construccion._crear_sala(SALA, Rect2i(0, fila, 4, 1))
	construccion.fijar_paredes_de_sala(sala_id, true)
	return sala_id


## El punto de pantalla a MEDIA ALTURA del tramo norte de la celda (1, fila) -- el mismo punto que
## usa la sonda `_diag_celda_bajo_cursor_vs_muro.gd`.
func _punto_cara_norte(construccion: Node, fila: int) -> Vector2:
	var desde: Vector2 = construccion.esquina_en_pantalla(1, fila)
	var hasta: Vector2 = construccion.esquina_en_pantalla(2, fila)
	return desde.lerp(hasta, 0.5) + Vector2(0.0, -ParedesSalasScript.ALTO_PARED * 0.5)


# ── 1. Sin muro bajo el punto: el fallback es IDÉNTICO al picking de suelo de siempre ─────────
func test_sin_muro_bajo_el_punto_cae_al_picking_de_suelo_de_siempre() -> void:
	# Arrange
	var mundo: Dictionary = _mundo()
	var modo: Node2D = _modo(mundo["construccion"], mundo["paredes"])
	var punto := Vector2(2000.0, 2000.0)   # lejos de cualquier pared

	# Act
	var esperado: Vector2i = mundo["construccion"].celda_de_punto(punto)
	var obtenido: Array = modo._celda_lado_de_muro_en(punto)

	# Assert
	assert_that(obtenido[0]).is_equal(esperado)


# ── 2. Punto sobre la CARA VISIBLE de un muro: la celda que el jugador VE, no la de detrás ────
func test_punto_sobre_cara_de_muro_acierta_la_celda_visible_no_la_de_detras() -> void:
	# Arrange
	var mundo: Dictionary = _mundo()
	var construccion: Node = mundo["construccion"]
	var fila := 3
	_sala_de_una_fila(construccion, fila)
	var punto_cara: Vector2 = _punto_cara_norte(construccion, fila)
	var modo: Node2D = _modo(construccion, mundo["paredes"])

	# Act — EL BUG: el picking de suelo puro (sin el fix) cae en la celda de DETRÁS del muro.
	var celda_bug: Vector2i = construccion.celda_de_punto(punto_cara)
	# Act — EL FIX: la función que ahora alimenta `_process`/`_al_soltar`.
	var par: Array = modo._celda_lado_de_muro_en(punto_cara)

	# Assert
	assert_int(celda_bug.y) \
		.override_failure_message("el fixture necesita reproducir el bug: el picking de suelo tiene que desviarse") \
		.is_not_equal(fila)
	assert_that(par[0]) \
		.override_failure_message("el picking consciente de muros tiene que acertar la celda VISIBLE (1,%d), salió %s" % [fila, par[0]]) \
		.is_equal(Vector2i(1, fila))


# ── 3. Varias filas de muros por delante: cada una resuelve a SU fila, sin arrastrar desfase ──
func test_varias_filas_de_muros_cada_una_resuelve_a_su_propia_fila() -> void:
	# Arrange
	var mundo: Dictionary = _mundo()
	var construccion: Node = mundo["construccion"]
	var modo: Node2D = _modo(construccion, mundo["paredes"])

	for fila: int in [1, 3, 6]:
		_sala_de_una_fila(construccion, fila)
		var punto: Vector2 = _punto_cara_norte(construccion, fila)

		# Act
		var par: Array = modo._celda_lado_de_muro_en(punto)

		# Assert — sin el fix, TODAS estas filas caerían en `fila - 1` (mismo desfase constante que
		# demuestra la sonda numérica); con el fix, cada una acierta la suya.
		assert_that(par[0]) \
			.override_failure_message("fila %d: se esperaba (1,%d), salio %s" % [fila, fila, par[0]]) \
			.is_equal(Vector2i(1, fila))


# ── 4. LA FUNCIÓN NUEVA es literalmente una línea que delega en `_celda_lado_de_muro_en` sobre
#      `get_global_mouse_position()` (ver el comentario en `modo_construccion.gd`) -- por eso NO se
#      instancia un `ModoConstruccion` completo dentro del árbol solo para mover el ratón (eso obliga
#      a levantar la barra de herramientas completa, `_crear_ui`, ajena a este bug de picking; ver el
#      comentario de `_modo()` arriba). La cobertura real de la función nueva son los tests 1-3: los
#      DOS sitios de consumo (`_process` línea ~968, `_al_soltar` línea ~619) llaman a la MISMA
#      función de una línea que ellos ejercitan.
