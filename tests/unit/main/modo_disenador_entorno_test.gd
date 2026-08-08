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
	# AISLAMIENTO (2026-08-08): `_ready()` autocarga de `ruta_guardado` -- sin esto, una partida REAL
	# guardada por el usuario en `user://entorno_disenado.json` se cuela en el test (pasó: sus 3
	# piezas + 1 del test = "expected 1 but was 4"). Los tests solo miran su scratch.
	nodo.ruta_guardado = RUTA_SCRATCH
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


# ── PLAYTEST 2026-08-08 (encargo 1): "los objetos guardados no los puedo modificar ni quitar; si
# le doy a F12 directamente desaparecen" -- causa raíz real: `alternar()` recargaba del disco SIN
# CONDICIÓN cada vez que se activaba, pisando cualquier edición hecha en memoria desde la última
# vez que se guardó (F8). Ver el fix con fecha de hoy en `alternar()`.

func test_alternar_no_descarta_una_pieza_borrada_sin_guardar() -> void:
	var modo: ModoDisenadorEntorno = _modo()
	var celda := Vector2i(-10, 5)
	modo._fijar_herramienta(&"farola")
	modo._colocar_pieza_en(celda)
	modo.guardar_en_disco()   # esto SÍ queda en disco -- 1 farola

	modo.alternar()   # activa (F12) -- _piezas NO está vacío, no debe recargar
	assert_int(modo._piezas.size()).is_equal(1)

	# Editar SIN guardar (F8): borrar la farola con la goma, con el modo YA activo.
	modo._fijar_herramienta(ModoDisenadorEntorno.HERRAMIENTA_BORRAR)
	modo._pintar_o_borrar_en(celda)
	assert_int(modo._piezas.size()).is_equal(0)

	# 🔒 AC: desactivar y reactivar (dos F12 más) NO debe resucitar la farola del disco -- antes de
	# el fix, la reactivación llamaba `cargar_desde_disco()` a lo bruto y la traía de vuelta.
	modo.alternar()   # desactiva
	modo.alternar()   # reactiva
	assert_int(modo._piezas.size()).is_equal(0)
	assert_bool(modo._piezas.has(celda)).is_false()


# 🔄 REESCRITO (2026-08-08, encargo 3 -- "arreglar el agujero del fix de alternar()"): esta prueba
# codificaba el contrato VIEJO ("`alternar()` recarga si `_piezas`/`_superficies` están vacíos"),
# justo el que se acaba de retirar por agujero (ver el comentario "SEGUNDO FIX" en `alternar()`):
# con esa regla, borrar la ÚLTIMA pieza dejaba `_piezas` vacío por un motivo LEGÍTIMO (el usuario la
# quitó) y la siguiente reactivación lo confundía con "arranque limpio", resucitando del disco lo
# que se acababa de borrar. La única autocarga fiable es "una vez por instancia, en `_ready()`"
# (`_autocargado`) -- `alternar()` ya no vuelve a mirar el disco nunca. Esta prueba ahora fija ESE
# contrato: una instancia nueva recoge en el momento de construirse (`add_child()` → `_ready()`,
# síncrono) lo que YA hubiera en disco, y `alternar()` no la toca.
func test_ready_autocarga_una_vez_lo_que_ya_hay_en_disco_y_alternar_no_lo_repite() -> void:
	var origen: ModoDisenadorEntorno = _modo()
	origen._fijar_herramienta(&"casa_a")
	origen._colocar_pieza_en(Vector2i(-12, 6))
	origen.guardar_en_disco()

	var destino: ModoDisenadorEntorno = _modo()   # `_ready()` ya deja cargada la pieza de `origen`
	assert_int(destino._piezas.size()).is_equal(1)
	assert_bool(destino._piezas.has(Vector2i(-12, 6))).is_true()

	destino.alternar()   # activa -- no debe recargar (ya autocargado en `_ready()`), pero tampoco pierde nada
	assert_int(destino._piezas.size()).is_equal(1)
	assert_bool(destino._piezas.has(Vector2i(-12, 6))).is_true()


## 🔒 AC central del encargo: una pieza CARGADA DEL DISCO (no colocada en esta sesión) es
## seleccionable/borrable con la goma igual que una recién colocada -- las piezas del layout del
## usuario viven en las capas propias del diseñador (`_piezas`/`_nodos_pieza`), nunca en una capa
## ajena e inaccesible.
func test_pieza_cargada_del_disco_es_borrable_con_el_modo_activo() -> void:
	var origen: ModoDisenadorEntorno = _modo()
	origen._fijar_herramienta(&"coche_policia")
	origen._colocar_pieza_en(Vector2i(16, 16))
	origen.guardar_en_disco()

	var destino: ModoDisenadorEntorno = _modo()   # `_ready()` ya autocarga la pieza guardada por `origen`
	destino.alternar()   # activa -- no recarga (ya autocargado en `_ready()`), la pieza sigue ahí
	assert_int(destino._piezas.size()).is_equal(1)
	assert_bool(destino._nodos_pieza.has(Vector2i(16, 16))).is_true()   # visual real, no solo dato

	destino._fijar_herramienta(ModoDisenadorEntorno.HERRAMIENTA_BORRAR)
	destino._pintar_o_borrar_en(Vector2i(16, 16))
	assert_int(destino._piezas.size()).is_equal(0)
	assert_bool(destino._nodos_pieza.has(Vector2i(16, 16))).is_false()


# ── PLAYTEST 2026-08-08 (encargo 2): "clic y arrastrar tampoco se puede en las superficies como
# el asfalto" -- prueba el CAMINO REAL de entrada (`_unhandled_input`, eventos sintéticos de
# ratón), no solo las llamadas directas de arriba: así se detectaría una regresión de RUTEO
# (p.ej. el gesto de arrastre dejando de propagarse) que las llamadas directas nunca verían.
# Verificado con `tools/_probe_arrastre_disenador.gd` (sonda desechable de esta tarea) contra el
# código actual: superficie/pieza/goma arrastran correctamente las 3 -- este test lo deja fijado
# como contrato permanente.

func _evento_boton(pos: Vector2, pulsado: bool) -> InputEventMouseButton:
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = pulsado
	evento.position = pos
	return evento


func _evento_movimiento(pos: Vector2) -> InputEventMouseMotion:
	var evento := InputEventMouseMotion.new()
	evento.position = pos
	return evento


## Pulsar en A, arrastrar (motion) por B y C, soltar -- las 3 posiciones caen en 3 celdas lógicas
## distintas (mover +80px en X cambia columna Y fila de `Proyeccion.celda_de_iso`) y las 3 fuera
## del rect jugable 24×13.
func _simular_arrastre(modo: ModoDisenadorEntorno) -> void:
	var a := Vector2(2000.0, 2000.0)
	modo._unhandled_input(_evento_boton(a, true))
	modo._unhandled_input(_evento_movimiento(a + Vector2(80.0, 0.0)))
	modo._unhandled_input(_evento_movimiento(a + Vector2(160.0, 0.0)))
	modo._unhandled_input(_evento_boton(a + Vector2(160.0, 0.0), false))


func test_arrastre_real_pinta_3_celdas_de_superficie() -> void:
	var modo: ModoDisenadorEntorno = _modo()
	modo._activo = true   # `_unhandled_input` exige el modo activo, mismo guardián que F12
	modo._fijar_herramienta(&"asfalto")
	_simular_arrastre(modo)
	assert_int(modo._superficies.size()).is_equal(3)


func test_arrastre_real_coloca_3_piezas() -> void:
	var modo: ModoDisenadorEntorno = _modo()
	modo._activo = true
	modo._fijar_herramienta(&"farola")
	_simular_arrastre(modo)
	assert_int(modo._piezas.size()).is_equal(3)


func test_arrastre_real_con_goma_borra_lo_pintado() -> void:
	var modo: ModoDisenadorEntorno = _modo()
	modo._activo = true
	modo._fijar_herramienta(&"asfalto")
	_simular_arrastre(modo)
	assert_int(modo._superficies.size()).is_equal(3)

	modo._fijar_herramienta(ModoDisenadorEntorno.HERRAMIENTA_BORRAR)
	_simular_arrastre(modo)
	assert_int(modo._superficies.size()).is_equal(0)
