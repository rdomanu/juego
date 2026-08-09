# EL PAPEL EN LA MANO — la geometria y las capas, sin escena ni fisica.
# Tipo: Logic. DETERMINISTA: aritmetica sobre las medidas del muneco, sin reloj ni RNG.
#
# BUG REPORTADO POR EL USUARIO (2026-08-09): "el papel que se les entrega va como pegado a la cara,
# deberia ir en la mano con el juego del movimiento de las manos y respetar las capas, si se gira se
# oculta el papel con el cuerpo o si pasa por delante de algun objeto".
#
# CAUSA: `POSICION_PAPEL` estaba en y = -22 y la CABEZA ocupa de -28 a -22 (Y_CADERA - ALTO_TORSO -
# ALTO_CABEZA) -- el papel caia justo sobre la cara. La MANO esta al final del brazo, que cuelga de
# Y_HOMBRO y mide ALTO_BRAZO.
#
# Lo que protege este test:
#   1. Que el papel este a la altura de la MANO y NO sobre la cabeza (el bug, con su margen medido).
#   2. Que se BALANCEE con el paso y se quede quieto al pararse ("el juego del movimiento").
#   3. Que de espaldas se dibuje DETRAS del cuerpo y de frente DELANTE (las capas que pidio).
extends GdUnitTestSuite

const MunecoScript := preload("res://src/main/muneco.gd")


## Un visual como el que arma `NPCCiudadano`: raiz + cuerpo (con el meta `direccion` que pone
## `orientar_sprite`) + el papel colgado al final.
func _visual_con_papel(direccion: int) -> Node2D:
	var raiz := Node2D.new()
	auto_free(raiz)
	var cuerpo := Node2D.new()
	cuerpo.name = "Cuerpo"
	cuerpo.set_meta(&"direccion", direccion)
	raiz.add_child(cuerpo)
	raiz.add_child(MunecoScript.papel())
	return raiz


# ── 1. En la mano, no en la cara ────────────────────────────────────────────────────────────────

## 🔒 EL CASO DEL BUG: la cabeza va de `Y_CADERA - ALTO_TORSO - ALTO_CABEZA` a
## `Y_CADERA - ALTO_TORSO`. El papel tiene que quedar POR DEBAJO de todo eso.
func test_el_papel_no_cae_sobre_la_cabeza() -> void:
	var techo_cabeza: float = MunecoScript.Y_CADERA - MunecoScript.ALTO_TORSO - MunecoScript.ALTO_CABEZA
	var barbilla: float = MunecoScript.Y_CADERA - MunecoScript.ALTO_TORSO
	assert_bool(MunecoScript.POSICION_PAPEL.y > barbilla).override_failure_message(
		"el papel (y=%.1f) sigue a la altura de la cabeza (%.1f..%.1f)"
		% [MunecoScript.POSICION_PAPEL.y, techo_cabeza, barbilla]
	).is_true()


## Y a la altura de la MANO: el extremo del brazo, que cuelga del hombro.
func test_el_papel_esta_a_la_altura_de_la_mano() -> void:
	var mano: float = MunecoScript.Y_HOMBRO + MunecoScript.ALTO_BRAZO
	assert_float(MunecoScript.POSICION_PAPEL.y).is_equal_approx(mano - 2.0, 0.01)


## Y por FUERA del torso (si no, se leeria pegado al pecho).
func test_el_papel_va_por_fuera_del_torso() -> void:
	assert_bool(
		absf(MunecoScript.POSICION_PAPEL.x) > MunecoScript.ANCHO_TORSO * 0.5
	).is_true()


# ── 2. Se mueve con la mano ─────────────────────────────────────────────────────────────────────

func test_el_papel_se_balancea_al_andar_y_se_para_al_pararse() -> void:
	var visual: Node2D = _visual_con_papel(1)
	var papel: Node2D = visual.get_node("Papel") as Node2D

	MunecoScript.colocar_papel(visual, PI * 0.5, 1.0)   # a media zancada, andando
	assert_bool(absf(papel.rotation) > 0.01).override_failure_message(
		"el papel deberia balancearse con el paso"
	).is_true()

	MunecoScript.colocar_papel(visual, PI * 0.5, 0.0)   # parado
	assert_float(papel.rotation).is_equal_approx(0.0, 0.001)


# ── 3. Las capas ────────────────────────────────────────────────────────────────────────────────

## 🐛 REGRESION (cazada in-game 2026-08-09): al mandar el papel detras, el papel pasaba a ser el
## PRIMER hijo y `colocar_papel` lo leia a el como "cuerpo" -- la capa oscilaba de un frame a otro.
## Por eso el cuerpo se BUSCA por su meta `direccion`, no por el indice. Este test llama DOS VECES
## seguidas: la segunda tiene que dar el mismo resultado que la primera.
func test_llamarlo_dos_veces_seguidas_no_cambia_la_capa() -> void:
	for direccion: int in [1, 6]:
		var visual: Node2D = _visual_con_papel(direccion)
		MunecoScript.colocar_papel(visual, 0.0, 0.0)
		var primera: int = (visual.get_node("Papel") as Node2D).get_index()
		MunecoScript.colocar_papel(visual, 0.0, 0.0)
		var segunda: int = (visual.get_node("Papel") as Node2D).get_index()
		assert_int(segunda).override_failure_message(
			"con direccion %d la capa del papel oscila entre frames (%d -> %d)"
			% [direccion, primera, segunda]
		).is_equal(primera)


## 🔒 "si se gira se oculta el papel con el cuerpo": de espaldas el papel pasa DETRAS (indice 0);
## de frente vuelve DELANTE (ultimo hijo). El orden del arbol ES el orden de dibujo.
func test_de_espaldas_el_papel_va_detras_del_cuerpo() -> void:
	for direccion: int in MunecoScript.DIRECCIONES_DE_ESPALDAS:
		var visual: Node2D = _visual_con_papel(direccion)
		MunecoScript.colocar_papel(visual, 0.0, 0.0)
		assert_int((visual.get_node("Papel") as Node2D).get_index()).override_failure_message(
			"con direccion %d (de espaldas) el papel deberia ir detras" % direccion
		).is_equal(0)


func test_de_frente_el_papel_va_delante_del_cuerpo() -> void:
	for direccion: int in [0, 1, 2, 3, 4]:
		var visual: Node2D = _visual_con_papel(direccion)
		MunecoScript.colocar_papel(visual, 0.0, 0.0)
		var papel: Node2D = visual.get_node("Papel") as Node2D
		assert_int(papel.get_index()).override_failure_message(
			"con direccion %d (se le ve la cara) el papel deberia ir delante" % direccion
		).is_equal(visual.get_child_count() - 1)


## Sin papel colgado la funcion no debe reventar (se llama CADA frame para todo el que anda).
func test_sin_papel_no_revienta() -> void:
	var visual := Node2D.new()
	auto_free(visual)
	visual.add_child(Node2D.new())
	MunecoScript.colocar_papel(visual, 1.0, 1.0)
	assert_int(visual.get_child_count()).is_equal(1)
