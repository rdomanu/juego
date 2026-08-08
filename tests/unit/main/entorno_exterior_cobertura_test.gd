# COBERTURA COMPLETA DEL PERÍMETRO (2026-08-07, "que se vea toda la comisaría alrededor... como
# Theme Hospital"). Prueba la mitad de `EntornoExterior` en la pareja de encargos: que
# `rect_cobertura_logico()` -- lo que de verdad se PINTA -- cubre POR COMPLETO
# `limites_iso_cubiertos()` -- lo que la cámara de `Main` puede llegar a enseñar (ver
# `main_camara_clamp_test.gd`, que prueba la otra mitad del contrato: que el clamp nunca se sale de
# esos mismos límites) -- para cualquier punto de la ventana, al zoom más alejado permitido, en
# cualquier esquina del área cubierta.
#
# Tipo: Unit + Integration ligera (instancia el nodo real, pinta de verdad, lee `get_used_cells()`/
# `get_cell_source_id()`). DETERMINISTA: geometría pura + hash, sin azar, sin reloj, sin GPU.
extends GdUnitTestSuite

const EntornoExteriorScript := preload("res://src/main/entorno_exterior.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 24
const FILAS: int = 13


func _entorno() -> EntornoExterior:
	var nodo: EntornoExterior = auto_free(EntornoExteriorScript.new())
	nodo.configurar(TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS)
	return nodo


# ── La geometría: tamaño y forma de lo que hay que cubrir ────────────────────────────────────────

func test_limites_iso_cubiertos_alcanza_al_menos_el_minimo_estricto_a_zoom_min() -> void:
	var area: Rect2 = EntornoExterior.limites_iso_cubiertos()
	var minimo_estricto: Vector2 = (
		EntornoExterior.VENTANA_REFERENCIA / EntornoExterior.ZOOM_MIN_CAMARA
	)
	assert_float(area.size.x).is_greater_equal(minimo_estricto.x)
	assert_float(area.size.y).is_greater_equal(minimo_estricto.y)


## Cota floja SOLO para cazar un error de unidades (p.ej. olvidar dividir por `Proyeccion.TAM_CELDA`,
## que dispararía esto a miles de celdas) -- no es una medida de diseño.
func test_rect_cobertura_logico_tiene_un_tamano_razonable() -> void:
	var cobertura: Rect2i = EntornoExterior.rect_cobertura_logico()
	assert_int(cobertura.size.x).is_less(400)
	assert_int(cobertura.size.y).is_less(400)
	assert_int(cobertura.size.x).is_greater(COLUMNAS)
	assert_int(cobertura.size.y).is_greater(FILAS)


## El caso que motiva TODO este fichero: cada punto de la ventana de cámara (muestreado en una
## rejilla fina, incluidas las 4 esquinas EXACTAS -- las puntas del rombo son el peor caso, ver la
## cabecera de `EntornoExterior.rect_cobertura_logico()`) cae dentro del rectángulo lógico que de
## verdad se pinta.
func test_rect_cobertura_logico_contiene_toda_la_rejilla_de_limites_iso_cubiertos() -> void:
	var area: Rect2 = EntornoExterior.limites_iso_cubiertos()
	var cobertura: Rect2i = EntornoExterior.rect_cobertura_logico()
	var pasos := 12
	var fuera: Array[Vector2] = []
	for i: int in range(pasos + 1):
		for j: int in range(pasos + 1):
			var punto: Vector2 = area.position + Vector2(
				area.size.x * float(i) / float(pasos), area.size.y * float(j) / float(pasos)
			)
			var logico: Vector2 = Proyeccion.desproyectar(punto) / float(Proyeccion.TAM_CELDA)
			var celda := Vector2i(int(floor(logico.x)), int(floor(logico.y)))
			if not cobertura.has_point(celda):
				fuera.append(punto)
	assert_array(fuera).override_failure_message(
		"%d puntos de la ventana caen fuera de rect_cobertura_logico(): %s" % [fuera.size(), fuera]
	).is_empty()


# ── Integración: el suelo REALMENTE pintado cubre esa misma rejilla, sin huecos ──────────────────

## La prueba final: para las 4 ESQUINAS del clamp (donde la cámara podría llegar a estar, al zoom
## más alejado) más el centro, cada punto de la ventana de esa vista cae en una celda REALMENTE
## pintada (`get_cell_source_id != -1`) -- no solo dentro del rectángulo teórico de arriba.
func test_el_suelo_pintado_cubre_las_4_esquinas_de_la_vista_a_zoom_minimo() -> void:
	var entorno: EntornoExterior = _entorno()
	var capa: TileMapLayer = entorno.capa_suelo()
	var area: Rect2 = EntornoExterior.limites_iso_cubiertos()
	var visible: Vector2 = EntornoExterior.VENTANA_REFERENCIA / EntornoExterior.ZOOM_MIN_CAMARA
	# Las 4 esquinas del CLAMP (la vista queda pegada a cada borde de `area`, del tamaño exacto que
	# se ve a zoom mínimo) + el centro -- el mismo repertorio que pide el encargo ("las 4 esquinas").
	var origenes_vista: Array[Vector2] = [
		area.position, Vector2(area.position.x + area.size.x - visible.x, area.position.y),
		Vector2(area.position.x, area.position.y + area.size.y - visible.y),
		area.position + area.size - visible,
		area.position + (area.size - visible) * 0.5,
	]
	# El rect JUGABLE (0,0,24,13) lo pinta `Main._crear_suelo` -- una capa DISTINTA (el suelo
	# interior del edificio) -- no esta: EntornoExterior nunca pinta ahí a propósito (garantía de la
	# cabecera). Se descuenta aquí para no confundir "es de otra capa" con "queda un hueco".
	var rect_jugable := Rect2i(0, 0, COLUMNAS, FILAS)
	var pasos := 10
	var sin_pintar: Array[Vector2i] = []
	for origen_vista: Vector2 in origenes_vista:
		for i: int in range(pasos + 1):
			for j: int in range(pasos + 1):
				var punto: Vector2 = origen_vista + Vector2(
					visible.x * float(i) / float(pasos), visible.y * float(j) / float(pasos)
				)
				var logico: Vector2 = Proyeccion.desproyectar(punto) / float(Proyeccion.TAM_CELDA)
				var celda := Vector2i(int(floor(logico.x)), int(floor(logico.y)))
				if rect_jugable.has_point(celda):
					continue
				if capa.get_cell_source_id(celda) == -1:
					sin_pintar.append(celda)
	assert_array(sin_pintar).override_failure_message(
		"%d celdas de la vista (a zoom mínimo, 4 esquinas + centro) quedan SIN pintar: %s"
		% [sin_pintar.size(), sin_pintar]
	).is_empty()


# ── Determinismo del relleno de manzanas (SIN randf, regla del proyecto) ────────────────────────

func test_pintar_celda_manzana_es_determinista() -> void:
	var uno: EntornoExterior = _entorno()
	var otro: EntornoExterior = _entorno()
	var celdas_de_prueba: Array[Vector2i] = [
		Vector2i(40, 40), Vector2i(-30, -30), Vector2i(60, -20), Vector2i(-20, 50),
	]
	for celda: Vector2i in celdas_de_prueba:
		assert_int(uno.capa_suelo().get_cell_source_id(celda)) \
			.is_equal(otro.capa_suelo().get_cell_source_id(celda))
		assert_that(uno.capa_suelo().get_cell_atlas_coords(celda)) \
			.is_equal(otro.capa_suelo().get_cell_atlas_coords(celda))


# ── Las zonas nuevas respetan las mismas garantías que las de fase 1 (cabecera del fichero) ─────

func test_ninguna_zona_perimetral_nueva_invade_el_rect_jugable() -> void:
	var rect_jugable := Rect2i(0, 0, COLUMNAS, FILAS)
	for rect: Rect2i in [
		EntornoExterior.RECT_ACERA_NORTE, EntornoExterior.RECT_ACERA_OESTE, EntornoExterior.RECT_ACERA_ESTE,
	]:
		assert_bool(rect.intersects(rect_jugable)).is_false()


## GARANTÍA 3 de la cabecera del fichero, extendida: ninguna celda REALMENTE pintada dentro de la
## franja peatonal que `NPCsFlujo` bakea puede ser una manzana/tejado de fondo -- solo las zonas ya
## documentadas como excepción (recinto, control, el relleno de acera de la franja).
func test_ninguna_celda_pintada_dentro_de_la_franja_peatonal_es_manzana_de_fondo() -> void:
	var entorno: EntornoExterior = _entorno()
	var capa: TileMapLayer = entorno.capa_suelo()
	var sin_documentar: Array[Vector2i] = []
	for celda: Vector2i in capa.get_used_cells():
		if not EntornoExterior.RECT_NAV_PEATONAL.has_point(celda):
			continue
		var es_zona_documentada: bool = (
			EntornoExterior.RECT_RECINTO.has_point(celda)
			or EntornoExterior.RECT_CONTROL.has_point(celda)
			or EntornoExterior.RECT_ACERA_NAV_OESTE.has_point(celda)
			or EntornoExterior.RECT_ACERA_NAV_ESTE.has_point(celda)
		)
		if not es_zona_documentada:
			sin_documentar.append(celda)
	assert_array(sin_documentar).override_failure_message(
		"celdas en la franja peatonal SIN ser zona documentada: %s" % sin_documentar
	).is_empty()


func test_configurar_sigue_sin_crear_nodos_de_colision_ni_navegacion() -> void:
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
