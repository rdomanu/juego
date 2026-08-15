# LA SOMBRA DE CONTACTO YA NO ES UN HIJO DEL MUÑECO — contrato del rediseño 2026-08-14.
# Tipo: Logic. DETERMINISTA: nodos recién creados, sin reloj, sin RNG, sin arte real (prefijo sin
# PNG: las funciones no revientan, solo no cambian la textura).
#
# HISTORIA (para que nadie lo "arregle" hacia atrás): la v1 colgaba un Sprite2D "Sombra" de cada
# muñeco. Los nodos existían perfectos y NO SE RENDERIZABAN — todo CanvasItem nacido en la carga
# dentro de la bolsa y-sort (`MundoProfundo`) queda sin pintar en este árbol (gotcha cazado con
# sondas y muestreo de píxeles; incurable). Ahora las pinta la capa única `CapaSombras` (hermana de
# la bolsa, z −1) leyendo metas del visual. Lo que protege este test:
#   1. `construir_sprite` NO cuelga ningún hijo "Sombra" (regresión del rediseño).
#   2. `CapaSombras`: registro de muebles/muñecos y purga sola de los muertos.
extends GdUnitTestSuite

const MunecoScript := preload("res://src/main/muneco.gd")
const CapaSombrasScript := preload("res://src/main/capa_sombras.gd")

## Un prefijo que no existe en `assets/`: de sobra para probar la GEOMETRÍA de nodos.
const PREFIJO_SIN_ARTE := "prefijo_de_prueba_sin_render"


# ── 1. El muñeco ya no lleva hijo de sombra ─────────────────────────────────────────────────────

## 🔒 REGRESIÓN DEL REDISEÑO: si alguien vuelve a colgar un hijo "Sombra" del muñeco, ese hijo no
## se renderiza en el juego real (gotcha de la bolsa) — este test lo para en seco.
func test_construir_sprite_no_cuelga_ningun_hijo_sombra() -> void:
	var raiz: Node2D = MunecoScript.construir_sprite(PREFIJO_SIN_ARTE, 44)
	auto_free(raiz)
	assert_object(raiz.get_node_or_null(^"Sombra")).override_failure_message(
		"el muñeco NO debe llevar hijo 'Sombra': las sombras las pinta CapaSombras (ver su cabecera)"
	).is_null()
	assert_str(raiz.get_child(0).name).is_equal("Sprite")


func test_construir_sprite_sentado_tampoco_cuelga_sombra() -> void:
	var raiz: Node2D = MunecoScript.construir_sprite_sentado(PREFIJO_SIN_ARTE, 44, Vector2(0.0, 1.0))
	auto_free(raiz)
	assert_object(raiz.get_node_or_null(^"Sombra")).is_null()


# ── 2. El registro de CapaSombras ───────────────────────────────────────────────────────────────

func _capa() -> Node2D:
	var capa: Node2D = auto_free(CapaSombrasScript.new())
	add_child(capa)
	return capa


func test_capa_sombras_registra_muebles_y_munecos() -> void:
	# Arrange
	var capa: Node2D = _capa()
	var mueble: Node2D = auto_free(Node2D.new())
	var visual: Node2D = auto_free(Node2D.new())
	add_child(mueble)
	add_child(visual)

	# Act
	capa.registrar_mueble(mueble, Vector2.ZERO, Vector2(9.0, 9.0))
	capa.registrar_muneco(visual)

	# Assert
	assert_that(capa.numero_registrados()).is_equal(Vector2i(1, 1))


func test_capa_sombras_purga_sola_los_registros_muertos() -> void:
	# Arrange: un mueble y un muñeco registrados y luego LIBERADOS (demolición / muñeco que se va)
	var capa: Node2D = _capa()
	var mueble: Node2D = Node2D.new()
	var visual: Node2D = Node2D.new()
	add_child(mueble)
	add_child(visual)
	capa.registrar_mueble(mueble, Vector2.ZERO, Vector2(9.0, 9.0))
	capa.registrar_muneco(visual)

	# Act
	mueble.free()
	visual.free()

	# Assert: contar purga los muertos — el registro no acumula basura
	assert_that(capa.numero_registrados()).is_equal(Vector2i(0, 0))


func test_capa_sombras_nace_por_debajo_de_todo_lo_de_pie() -> void:
	# El z −1 es EL contrato de la capa: sobre la tinta de salas (−2), bajo la bolsa y-sort (0).
	var capa: Node2D = _capa()
	assert_int(capa.z_index).is_equal(-1)
