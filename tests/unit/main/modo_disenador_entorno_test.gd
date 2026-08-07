# EL MODO DISEÑADOR DE ENTORNO (2026-08-07): "¿podría hacerlo yo con esos objetos, como si fuera un
# builder?". Este test prueba el CONTRATO de datos (guardar/cargar hace roundtrip exacto, con el
# MISMO esquema que `EntornoExterior.leer_layout` consume) y las dos garantías de la herramienta:
# nunca coloca nada DENTRO del rect jugable 24×13, y borrar quita pieza+superficie de una celda.
#
# Los métodos privados (`_colocar_pieza_en`, `_pintar_superficie_en`, `_borrar_en`,
# `_fijar_herramienta`) se llaman DIRECTAMENTE (sin simular eventos de ratón/teclado) -- mismo
# patrón que el resto de la suite con clases "andamio" (`ModoConstruccion` en
# `construccion_picking_muros_test.gd`): la ACCIÓN se prueba aparte de la ENTRADA que la dispara.
#
# Tipo: Logic + I/O de un archivo de scratch en `user://` (propio, no `RUTA_GUARDADO` real) — se
# borra en `after_test`. DETERMINISTA.
extends GdUnitTestSuite

const ModoDisenadorEntornoScript := preload("res://src/main/modo_disenador_entorno.gd")

const RUTA_SCRATCH := "user://_test_entorno_disenado.json"


func before_test() -> void:
	_borrar_scratch()


func after_test() -> void:
	_borrar_scratch()


func _borrar_scratch() -> void:
	if FileAccess.file_exists(RUTA_SCRATCH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_SCRATCH))


func _modo() -> ModoDisenadorEntorno:
	var nodo: ModoDisenadorEntorno = auto_free(ModoDisenadorEntornoScript.new())
	# `configurar()` ANTES de `add_child()` -- mismo contrato que `Main` (ver su comentario): `_ready()`
	# construye las capas con los datos que deja `configurar()`.
	nodo.configurar(40, Vector2.ZERO, null)
	add_child(nodo)
	return nodo


# ── Colocación: fuera del rect jugable, sí; dentro, nunca ───────────────────────────────────────

func test_coloca_una_pieza_fuera_del_rect_jugable() -> void:
	var modo: ModoDisenadorEntorno = _modo()
	modo._fijar_herramienta(&"farola")
	modo._colocar_pieza_en(Vector2i(-5, 5))
	assert_int(modo._piezas.size()).is_equal(1)
	assert_bool(modo._piezas.has(Vector2i(-5, 5))).is_true()


# 🔒 AC EL CASO QUE MOTIVA LA GARANTÍA: un clic DENTRO del rect 24×13 (el edificio) no coloca nada.
func test_no_coloca_nada_dentro_del_rect_jugable() -> void:
	var modo: ModoDisenadorEntorno = _modo()
	modo._fijar_herramienta(&"farola")
	modo._colocar_pieza_en(Vector2i(10, 5))   # dentro de 0..24 × 0..13
	assert_int(modo._piezas.size()).is_equal(0)


func test_pintar_superficie_dentro_del_rect_jugable_no_hace_nada() -> void:
	var modo: ModoDisenadorEntorno = _modo()
	modo._fijar_herramienta(&"cesped")
	modo._pintar_o_borrar_en(Vector2i(2, 2))
	assert_int(modo._superficies.size()).is_equal(0)


# ── Rotación (R cicla las 4 orientaciones, sin repetir) ──────────────────────────────────────────

func test_orientaciones_ciclo_pasa_por_las_4_sin_repetir() -> void:
	var vistas: Dictionary = {}
	var actual := 0
	for _i in 4:
		vistas[actual] = true
		actual = ModoDisenadorEntorno.ORIENTACIONES_CICLO[
			(ModoDisenadorEntorno.ORIENTACIONES_CICLO.find(actual) + 1)
			% ModoDisenadorEntorno.ORIENTACIONES_CICLO.size()
		]
	assert_int(vistas.size()).is_equal(4)
	assert_int(actual).is_equal(0)   # a la quinta vuelta al punto de partida


# ── Borrar quita pieza Y superficie de la misma celda ────────────────────────────────────────────

func test_borrar_quita_pieza_y_superficie_de_la_celda() -> void:
	var modo: ModoDisenadorEntorno = _modo()
	var celda := Vector2i(-5, 5)
	modo._fijar_herramienta(&"farola")
	modo._colocar_pieza_en(celda)
	modo._fijar_herramienta(&"cesped")
	modo._pintar_o_borrar_en(celda)
	assert_int(modo._piezas.size()).is_equal(1)
	assert_int(modo._superficies.size()).is_equal(1)

	modo._fijar_herramienta(ModoDisenadorEntorno.HERRAMIENTA_BORRAR)
	modo._pintar_o_borrar_en(celda)
	assert_int(modo._piezas.size()).is_equal(0)
	assert_int(modo._superficies.size()).is_equal(0)


# ── Guardar/Cargar: ROUNDTRIP exacto (AC central de la tarea) ────────────────────────────────────

func test_guardar_y_cargar_hace_roundtrip_exacto() -> void:
	var origen: ModoDisenadorEntorno = _modo()
	origen._fijar_herramienta(&"casa_a")
	origen._orientacion = 90
	origen._colocar_pieza_en(Vector2i(-30, 10))
	origen._fijar_herramienta(&"farola")
	origen._orientacion = 0
	origen._colocar_pieza_en(Vector2i(-25, 10))
	origen._fijar_herramienta(&"cesped")
	origen._pintar_o_borrar_en(Vector2i(-30, 11))
	origen._fijar_herramienta(&"asfalto")
	origen._pintar_o_borrar_en(Vector2i(-29, 11))

	assert_bool(origen.guardar_en_disco(RUTA_SCRATCH)).is_true()
	assert_bool(FileAccess.file_exists(RUTA_SCRATCH)).is_true()

	var destino: ModoDisenadorEntorno = _modo()
	assert_bool(destino.cargar_desde_disco(RUTA_SCRATCH)).is_true()

	assert_int(destino._piezas.size()).is_equal(2)
	assert_dict(destino._piezas[Vector2i(-30, 10)]).is_equal({"id": &"casa_a", "rotacion": 90})
	assert_dict(destino._piezas[Vector2i(-25, 10)]).is_equal({"id": &"farola", "rotacion": 0})
	assert_int(destino._superficies.size()).is_equal(2)
	assert_that(destino._superficies[Vector2i(-30, 11)]).is_equal(&"cesped")
	assert_that(destino._superficies[Vector2i(-29, 11)]).is_equal(&"asfalto")


## El JSON que se guarda es EL MISMO esquema que `EntornoExterior.leer_layout` consume -- esto es lo
## que hace posible el "flujo de congelado" (copiar el archivo a `res://datos/`).
func test_el_formato_guardado_lo_entiende_entornoexterior_leer_layout() -> void:
	const EntornoExteriorScript := preload("res://src/main/entorno_exterior.gd")
	var modo: ModoDisenadorEntorno = _modo()
	modo._fijar_herramienta(&"seto")
	modo._colocar_pieza_en(Vector2i(-40, 3))
	modo.guardar_en_disco(RUTA_SCRATCH)

	var datos: Dictionary = EntornoExteriorScript.leer_layout(RUTA_SCRATCH)
	assert_bool(datos.is_empty()).is_false()
	# `JSON.parse_string` devuelve TODO número como `float` (JSON no distingue int/float) -- `int()`
	# antes de comparar, mismo criterio que usa `EntornoExterior._aplicar_layout_fijo`.
	assert_int(int(datos["version"])).is_equal(1)
	assert_int((datos["piezas"] as Array).size()).is_equal(1)


func test_cargar_sin_archivo_devuelve_false_y_no_revienta() -> void:
	var modo: ModoDisenadorEntorno = _modo()
	assert_bool(modo.cargar_desde_disco(RUTA_SCRATCH)).is_false()
	assert_int(modo._piezas.size()).is_equal(0)


## F12 sin `--disenador`: `Main._modo_disenador_entorno` se queda `null` y esta clase nunca se
## instancia -- verificado como CONTRATO de `Main`, no de esta clase (no hay nada que instanciar
## aquí sin el flag: el propio `Main.gd` es el guardián, ver `_ready`/`_unhandled_input`).
func test_activo_arranca_en_false() -> void:
	var modo: ModoDisenadorEntorno = _modo()
	assert_bool(modo._activo).is_false()
