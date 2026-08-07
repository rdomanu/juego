# EL MARCO EXTERIOR NO JUGABLE (design/art/entorno-exterior.md, fase 1 — solo suelo/código).
#
# Este test prueba las TRES GARANTÍAS de la cabecera de `entorno_exterior.gd` ("no jugable" no es
# una promesa, es una propiedad verificable): ninguna zona invade el rect jugable 24×13, ninguna
# zona nueva pisa la franja de navegación que `NPCsFlujo` ya bakea (salvo el recinto, documentado
# a propósito) y la capa nunca crea colisión/navegación por sí misma. También prueba el reparto de
# las 5 plazas de aparcamiento y el determinismo de la variación de baldosa (sin randf, regla del
# proyecto).
#
# Tipo: Logic + Integration ligera (instancia el nodo real, sin `Main` completo, sin GPU, sin reloj).
# DETERMINISTA: rects y hash son matemática pura; `configurar()` no toca el reloj ni el azar.
extends GdUnitTestSuite

const EntornoExteriorScript := preload("res://src/main/entorno_exterior.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 24
const FILAS: int = 13

## El mismo rectángulo que bakea `NPCsFlujo._bakear_navegacion` (columnas [−2, COLUMNAS), filas
## [0, FILAS)) — reconstruido aquí a propósito, SIN importar ese fichero (es la capa cosmética de
## NPCs, no una dependencia de esta capa): si algún día cambia el margen de 2 columnas, este test
## debe romperse para forzar a revisar la franja también aquí.
const RECT_NAV_PEATONAL := Rect2i(-2, 0, COLUMNAS + 2, FILAS)


func _entorno() -> EntornoExterior:
	var nodo: EntornoExterior = auto_free(EntornoExteriorScript.new())
	nodo.configurar(TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS)
	return nodo


# ── Garantía 1 de la cabecera: nada invade el rect jugable ──────────────────────────────────────

# AC-1: ninguna de las cinco zonas toca el rectángulo 24×13 donde vive el edificio.
func test_ninguna_zona_invade_el_rect_jugable() -> void:
	var rect_jugable := Rect2i(0, 0, COLUMNAS, FILAS)
	for rect: Rect2i in [
		EntornoExterior.RECT_RECINTO, EntornoExterior.RECT_CONTROL, EntornoExterior.RECT_ACERA,
		EntornoExterior.RECT_CALZADA, EntornoExterior.RECT_CESPED,
	]:
		assert_bool(rect.intersects(rect_jugable)).is_false()


# AC-2: las 5 plazas de aparcamiento están DENTRO del recinto (no se salen a otra zona).
func test_las_plazas_de_aparcamiento_caen_dentro_del_recinto() -> void:
	for plaza: Dictionary in EntornoExterior.PLAZAS_APARCAMIENTO:
		assert_bool(EntornoExterior.RECT_RECINTO.encloses(plaza["rect"])).is_true()


# ── Garantía 3 de la cabecera: sin navegación nueva (salvo el recinto, documentado) ─────────────

# AC-3 🔒 EL CASO QUE MOTIVA EL TEST: control, acera, calzada y césped son zonas NUEVAS — ninguna
# puede colarse en la franja peatonal que `NPCsFlujo` ya bakea, o un ciudadano podría "aparecer"
# caminando sobre el aparcamiento o el césped sin que nadie lo pidiera.
func test_las_zonas_nuevas_no_pisan_la_franja_de_navegacion_existente() -> void:
	for rect: Rect2i in [
		EntornoExterior.RECT_CONTROL, EntornoExterior.RECT_ACERA, EntornoExterior.RECT_CALZADA,
		EntornoExterior.RECT_CESPED,
	]:
		assert_bool(rect.intersects(RECT_NAV_PEATONAL)).is_false()


# AC-4: el solapamiento del RECINTO con la franja peatonal es el ESPERADO (documentado en la
# cabecera) — las columnas −2/−1 son las únicas que se tocan; el resto del recinto (aparcamiento
# incluido) cae fuera.
func test_el_recinto_solapa_la_franja_peatonal_solo_en_sus_dos_columnas_pegadas_al_edificio() -> void:
	var interseccion: Rect2i = EntornoExterior.RECT_RECINTO.intersection(RECT_NAV_PEATONAL)
	assert_int(interseccion.position.x).is_equal(-2)
	assert_int(interseccion.size.x).is_equal(2)
	# Y ninguna plaza de coche (todas en columnas −7..−3) cae en esa franja compartida.
	for plaza: Dictionary in EntornoExterior.PLAZAS_APARCAMIENTO:
		assert_bool((plaza["rect"] as Rect2i).intersects(RECT_NAV_PEATONAL)).is_false()


# ── El reparto de plazas (diseño §2/§5: 3 patrulla + 2 visita) ──────────────────────────────────

# AC-5: exactamente 5 plazas, 3 patrulla y 2 visita — ni una más, ni una menos.
func test_cinco_plazas_tres_patrulla_dos_visita() -> void:
	assert_int(EntornoExterior.PLAZAS_APARCAMIENTO.size()).is_equal(5)
	var patrulla := 0
	var visita := 0
	for plaza: Dictionary in EntornoExterior.PLAZAS_APARCAMIENTO:
		if plaza["tipo"] == &"patrulla":
			patrulla += 1
		elif plaza["tipo"] == &"visita":
			visita += 1
	assert_int(patrulla).is_equal(3)
	assert_int(visita).is_equal(2)


# AC-6: cada plaza tiene una `celda_ancla` propia y sin repetir (el futuro sprite de cada coche
# necesita un sitio único donde clavarse).
func test_cada_plaza_tiene_una_celda_ancla_distinta() -> void:
	var anclas: Dictionary[Vector2i, bool] = {}
	for plaza: Dictionary in EntornoExterior.PLAZAS_APARCAMIENTO:
		var celda: Vector2i = plaza["celda_ancla"]
		assert_bool(anclas.has(celda)).is_false()
		anclas[celda] = true


# ── Determinismo (regla del proyecto: nada de randf) ─────────────────────────────────────────────

# AC-7: la misma celda da SIEMPRE la misma variación de tono, se pregunte lo que se pregunte antes.
func test_variacion_de_celda_es_determinista() -> void:
	var celda := Vector2i(-5, 8)
	var primera: int = EntornoExterior._variacion_de_celda(celda)
	for _i in 20:
		assert_int(EntornoExterior._variacion_de_celda(celda)).is_equal(primera)


# AC-8: la variación cae siempre dentro de rango, para negativos incluidos (la calle vive en x<0).
func test_variacion_de_celda_esta_siempre_en_rango() -> void:
	for x in range(-12, 1):
		for y in range(-2, 13):
			var variacion: int = EntornoExterior._variacion_de_celda(Vector2i(x, y))
			assert_int(variacion).is_greater_equal(0)
			assert_int(variacion).is_less(EntornoExterior.VARIACIONES)


# ── Estructural: la capa no puede crear colisión, navegación ni nada "pickeable" por sí misma ───

# AC-9 🔒 EL CASO QUE MOTIVA TODO ESTE ARCHIVO: `configurar()` no debe añadir NUNCA un
# `CollisionObject2D`/`CollisionShape2D`/`NavigationRegion2D`/`Area2D` en su árbol — si algún día
# alguien copia y pega un patrón de otro sistema y añade uno de estos por error, este test lo caza
# antes de que un jugador choque con la acera o un NPC navegue por el aparcamiento.
func test_configurar_no_crea_nodos_de_colision_ni_navegacion() -> void:
	var nodo: EntornoExterior = _entorno()
	var prohibidos: Array[Node] = []
	_recolectar_prohibidos(nodo, prohibidos)
	assert_array(prohibidos).is_empty()


func _recolectar_prohibidos(raiz: Node, encontrados: Array[Node]) -> void:
	for hijo: Node in raiz.get_children():
		if (
			hijo is CollisionObject2D or hijo is CollisionShape2D or hijo is NavigationRegion2D
			or hijo is Area2D
		):
			encontrados.append(hijo)
		_recolectar_prohibidos(hijo, encontrados)


# AC-10: el `TileSet` de la capa no lleva NINGUNA capa de física — sin eso, Godot no puede generar
# colisión para ninguna celda por mucho que alguien pinte encima en el futuro.
func test_el_tileset_no_tiene_capas_de_fisica() -> void:
	var nodo: EntornoExterior = _entorno()
	assert_int(nodo.capa_suelo().tile_set.get_physics_layers_count()).is_equal(0)


# ── La capa en sí: z_index y no invasión de lo pintado ───────────────────────────────────────────

# AC-11: el z_index de la capa (y de su suelo) queda POR DEBAJO del suelo interior de `Main`
# (`Main._crear_suelo`, z −3) — más negativo, para que el edificio SIEMPRE la tape.
func test_z_index_queda_por_debajo_del_suelo_interior() -> void:
	var nodo: EntornoExterior = _entorno()
	const Z_SUELO_INTERIOR := -3
	assert_int(EntornoExterior.Z_CAPA).is_less(Z_SUELO_INTERIOR)
	assert_int(nodo.z_index).is_equal(EntornoExterior.Z_CAPA)
	assert_int(nodo.capa_suelo().z_index).is_equal(EntornoExterior.Z_CAPA)


# AC-12: ninguna celda REALMENTE pintada por la capa (no solo el rect teórico) cae dentro del rect
# jugable — el juez final es lo que `set_cell` dejó en el `TileMapLayer`, no solo la aritmética.
func test_ninguna_celda_pintada_cae_dentro_del_rect_jugable() -> void:
	var nodo: EntornoExterior = _entorno()
	var rect_jugable := Rect2i(0, 0, COLUMNAS, FILAS)
	for celda: Vector2i in nodo.capa_suelo().get_used_cells():
		assert_bool(rect_jugable.has_point(celda)).is_false()
