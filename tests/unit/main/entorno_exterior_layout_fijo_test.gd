# EL ENTORNO FIJO (2026-08-07): si existe un layout guardado, `EntornoExterior.configurar()` lo
# aplica EN VEZ DE todo el scatter procedural (barrio de casas, valla+seto, árboles/farolas del
# recinto, coches) -- ver la cabecera "ENTORNO FIJO" de `entorno_exterior.gd`. El esqueleto
# (calle/recinto/plazas) se pinta SIEMPRE, con o sin layout.
#
# `ruta_layout_fijo` es un parámetro INYECTADO (nunca la constante `RUTA_LAYOUT_FIJO` real): estos
# tests escriben a un archivo de SCRATCH en `user://` y lo borran al terminar, sin tocar
# `res://datos/entorno_layout.json` -- ver el comentario de `configurar()`.
#
# Tipo: Logic + I/O de un archivo de scratch propio. DETERMINISTA.
extends GdUnitTestSuite

const EntornoExteriorScript := preload("res://src/main/entorno_exterior.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 24
const FILAS: int = 13
const RUTA_SCRATCH := "user://_test_entorno_layout_fijo.json"


func before_test() -> void:
	_borrar_scratch()


func after_test() -> void:
	_borrar_scratch()


func _borrar_scratch() -> void:
	if FileAccess.file_exists(RUTA_SCRATCH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_SCRATCH))


func _escribir_scratch(datos: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(RUTA_SCRATCH, FileAccess.WRITE)
	f.store_string(JSON.stringify(datos))
	f.close()


# AC-1: sin archivo -> el procedural de siempre (muchas piezas: casas/valla/seto/árboles/coches).
func test_sin_layout_fijo_usa_el_scatter_procedural() -> void:
	var nodo: EntornoExterior = auto_free(EntornoExteriorScript.new())
	nodo.configurar(TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS, null, RUTA_SCRATCH)
	# El procedural coloca de sobra: 5 coches + 5 farolas fijas + parterres + vallas/setos del
	# perímetro entero del recinto -- muy por encima de 20.
	assert_int(nodo.get_node("Decor").get_child_count()).is_greater(20)


# 🔒 AC-2 EL CASO QUE MOTIVA ESTE ARCHIVO: CON layout fijo, el procedural NO CORRE -- solo aparece
# EXACTAMENTE lo que trae el JSON (una farola suelta), nada de las 5 plazas con coche ni del barrio.
func test_con_layout_fijo_sustituye_el_scatter_procedural() -> void:
	_escribir_scratch({
		"version": 1,
		"piezas": [{"id": "farola", "celda": [-20, 5], "rotacion": 0}],
		"superficies": [],
	})
	var nodo: EntornoExterior = auto_free(EntornoExteriorScript.new())
	nodo.configurar(TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS, null, RUTA_SCRATCH)
	assert_int(nodo.get_node("Decor").get_child_count()).is_equal(1)
	assert_int(nodo.puntos_farolas().size()).is_equal(1)


# AC-3: una superficie pintada por el usuario deja una celda REALMENTE pintada en el TileMapLayer,
# fuera de cualquier rect del esqueleto (para que la pintura se note, no se confunda con el fondo).
func test_con_layout_fijo_pinta_las_superficies_guardadas() -> void:
	var celda_lejana := Vector2i(-40, 40)
	_escribir_scratch({
		"version": 1, "piezas": [],
		"superficies": [{"celda": [celda_lejana.x, celda_lejana.y], "tipo": "asfalto"}],
	})
	var nodo: EntornoExterior = auto_free(EntornoExteriorScript.new())
	nodo.configurar(TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS, null, RUTA_SCRATCH)
	assert_array(nodo.capa_suelo().get_used_cells()).contains([celda_lejana])


# AC-4: un id de pieza que ya no existe en el catálogo no revienta la carga (layout viejo).
func test_con_layout_fijo_pieza_desconocida_no_revienta() -> void:
	_escribir_scratch({
		"version": 1, "piezas": [{"id": "pieza_que_no_existe", "celda": [0, 0], "rotacion": 0}],
		"superficies": [],
	})
	var nodo: EntornoExterior = auto_free(EntornoExteriorScript.new())
	nodo.configurar(TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS, null, RUTA_SCRATCH)
	assert_int(nodo.get_node("Decor").get_child_count()).is_equal(0)


# ── `leer_layout` como lector puro ───────────────────────────────────────────────────────────────

func test_leer_layout_sin_archivo_devuelve_vacio() -> void:
	assert_dict(EntornoExterior.leer_layout(RUTA_SCRATCH)).is_empty()


func test_leer_layout_json_corrupto_devuelve_vacio() -> void:
	var f: FileAccess = FileAccess.open(RUTA_SCRATCH, FileAccess.WRITE)
	f.store_string("{ esto no es json valido")
	f.close()
	assert_dict(EntornoExterior.leer_layout(RUTA_SCRATCH)).is_empty()
