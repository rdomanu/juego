# Categorías completas de la barra de construcción (2026-08-07, remate del reskin del kit): ninguna
# herramienta registrada se queda sin pestaña donde vivir -- regresión honesta de un olvido fácil:
# añadir una herramienta nueva a `_ready()` sin pasarle `categoria` la deja fuera de las 5 pestañas
# (Apéndice B de `plan-maestro-ui.md`, "LA BARRA NUEVA") y el jugador nunca la encuentra.
#
# Tipo: Logic/UI (sin GPU, sin ratón -- lee el estado que deja `_crear_ui()` al construir la barra:
# `_botones_herramienta`/`_categoria_de_herramienta`/`_pestanas_categoria`). DETERMINISTA.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")

const TAM_CELDA: int = 40
## Herramientas ancladas FUERA de las pestañas a propósito (Apéndice B, Fitts's Law) -- no cuentan
## como "olvidadas": Demoler vive anclada al borde derecho, siempre visible pase lo que pase la
## categoría activa (ver el comentario "LA BARRA NUEVA" en `_crear_ui`).
const HERRAMIENTAS_FUERA_DE_PESTANA: Array[StringName] = [&"demoler"]


## Un `ModoConstruccion` REAL colgado del árbol -- a propósito CON `add_child` (a diferencia de
## `construccion_picking_muros_test.gd`, que lo evita para no montar la barra): este test necesita
## que `_ready()` corra `_crear_ui()` y deje pobladas las tres estructuras que se comprueban abajo.
func _modo() -> Node2D:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.montar_visual(TAM_CELDA, Vector2.ZERO)
	var modo: Node2D = auto_free(ModoConstruccionScript.new())
	modo.configurar(construccion, TAM_CELDA, null)
	add_child(modo)   # ORDEN: configurar() ANTES -- mismo contrato que `Main`.
	return modo


## AC central: cada id de `_botones_herramienta` está o bien en la lista de excepciones (anclada
## fuera de pestañas) o bien tiene categoría asignada en `_categoria_de_herramienta` -- ninguna
## herramienta se queda huérfana, invisible detrás de las 5 pestañas.
func test_ninguna_herramienta_registrada_se_queda_sin_pestana() -> void:
	# Arrange
	var modo: Node2D = _modo()
	var huerfanas: Array[StringName] = []

	# Act
	for id: StringName in modo._botones_herramienta.keys():
		if HERRAMIENTAS_FUERA_DE_PESTANA.has(id):
			continue
		if not modo._categoria_de_herramienta.has(id):
			huerfanas.append(id)

	# Assert
	assert_array(huerfanas).override_failure_message(
		"Herramientas sin categoría asignada (no aparecen en ninguna pestaña): %s" % [huerfanas]
	).is_empty()


## La otra mitad del contrato: toda categoría que una herramienta declara existe de verdad como
## pestaña en `CATEGORIAS` -- un id mal escrito en `_anadir_herramienta` crearía tarjetas que
## `_mostrar_categoria` nunca alcanza (ninguna pestaña las pide nunca).
func test_toda_categoria_usada_por_una_herramienta_tiene_su_pestana() -> void:
	# Arrange
	var modo: Node2D = _modo()
	var ids_categoria: Array = []
	for categoria: Dictionary in ModoConstruccionScript.CATEGORIAS:
		ids_categoria.append(categoria["id"])

	# Act / Assert
	for id: StringName in modo._categoria_de_herramienta.keys():
		var categoria: StringName = modo._categoria_de_herramienta[id]
		assert_bool(ids_categoria.has(categoria)).override_failure_message(
			"'%s' (herramienta '%s') no es ninguna de las 5 pestañas de CATEGORIAS" % [categoria, id]
		).is_true()


## Una pestaña por categoría declarada -- ni de más ni de menos (`_construir_pestana_categoria` se
## llama una vez por entrada de `CATEGORIAS`, ver el bucle en `_crear_ui`).
func test_hay_una_pestana_por_cada_categoria_declarada() -> void:
	# Arrange
	var modo: Node2D = _modo()

	# Assert
	assert_int(modo._pestanas_categoria.size()).is_equal(ModoConstruccionScript.CATEGORIAS.size())
