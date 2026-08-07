# EL FIX DE CAPAS DEL ENTORNO (2026-08-07): los props CON ALTURA de `EntornoExterior`
# (farola/seto/casas/coches/valla) tienen que colgar de `MundoProfundo` (la bolsa y-sort de `Main`)
# para COMPETIR por profundidad con las paredes del edificio -- antes vivían SIEMPRE a
# `z_index = Z_CAPA` (−5), muy por debajo del z=0 de las paredes/mobiliario/gente, así que ningún
# prop del entorno podía dibujarse jamás delante de un muro (bug real: una farola pegada al SUR del
# edificio se veía siempre cortada a la mitad, detrás de la fachada).
#
# Tipo: Logic/estructural. DETERMINISTA: solo comprueba el árbol de nodos que deja `configurar()`.
extends GdUnitTestSuite

const EntornoExteriorScript := preload("res://src/main/entorno_exterior.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 24
const FILAS: int = 13


func _entorno_con_mundo_profundo() -> Array:
	var mundo_profundo: Node2D = auto_free(Node2D.new())
	mundo_profundo.name = "MundoProfundo"
	mundo_profundo.y_sort_enabled = true
	var nodo: EntornoExterior = auto_free(EntornoExteriorScript.new())
	# `mundo_profundo` tiene que estar EN EL ÁRBOL antes de `configurar()` (mismo orden que `Main`).
	add_child(mundo_profundo)
	add_child(nodo)
	auto_free(nodo)
	nodo.configurar(TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS, mundo_profundo)
	return [nodo, mundo_profundo]


# ── CASO 1: CON `mundo_profundo` inyectado -- los props CON ALTURA cuelgan de ÉL, no de la capa ──
func test_capa_decor_cuelga_de_mundo_profundo_cuando_se_inyecta() -> void:
	var par: Array = _entorno_con_mundo_profundo()
	var nodo: EntornoExterior = par[0]
	var mundo_profundo: Node2D = par[1]
	var decor: Node2D = mundo_profundo.get_node("Decor")
	assert_object(decor).is_not_null()
	assert_object(decor.get_parent()).is_equal(mundo_profundo)
	# 🔒 EL CASO QUE MOTIVA TODO ESTE ARCHIVO: z_index en 0 (el default), NUNCA `Z_CAPA` -- si
	# alguien reintroduce `decor.z_index = Z_CAPA` aquí, esta línea lo caza: un z_index negativo
	# volvería a ganarle SIEMPRE al orden por Y, exactamente el bug original.
	assert_int(decor.z_index).is_equal(0)
	assert_bool(decor.y_sort_enabled).is_true()
	# Las SUPERFICIES (suelo/marcas/overlays planos) se QUEDAN en el fondo -- no se mueven.
	assert_int(nodo.z_index).is_equal(EntornoExteriorScript.Z_CAPA)
	assert_object(nodo.get_node("Decor")).is_null()


# ── CASO 2: SIN `mundo_profundo` (tests/herramientas sueltas) -- cae al patrón viejo, sin romper
# nada de lo que ya dependía de él. ──────────────────────────────────────────────────────────────
func test_capa_decor_cae_al_patron_viejo_sin_mundo_profundo() -> void:
	var nodo: EntornoExterior = auto_free(EntornoExteriorScript.new())
	nodo.configurar(TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS)
	var decor: Node2D = nodo.get_node("Decor")
	assert_object(decor).is_not_null()
	assert_object(decor.get_parent()).is_equal(nodo)
	assert_int(decor.z_index).is_equal(EntornoExteriorScript.Z_CAPA)


# ── Farolas rastreadas para `LucesObjetos.usar_farolas` (procedural: 3 anclas de recinto + 6 del
# perímetro = 9). ───────────────────────────────────────────────────────────────────────────────
func test_puntos_farolas_procedural_devuelve_las_9_anclas() -> void:
	var par: Array = _entorno_con_mundo_profundo()
	var nodo: EntornoExterior = par[0]
	assert_int(nodo.puntos_farolas().size()).is_equal(
		EntornoExterior.ANCLAS_FAROLAS.size() + EntornoExterior.ANCLAS_FAROLAS_PERIMETRO.size()
	)
