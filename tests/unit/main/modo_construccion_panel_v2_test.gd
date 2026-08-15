# Panel de construcción v2 (F1, 2026-08-15 — maquetas `design/ux/maquetas-menu-2026-08/`): cubre el
# CABLEADO entre `ModoConstruccion` y `LogicaPanelConstruccion` que no se puede probar como función
# pura -- el mapeo catálogo→tarjeta real (`_datos_ficha`/`_nombre_por_herramienta`), el buscador
# aplicado sobre botones de verdad, y qué barras de la ficha se muestran/ocultan según el objeto.
#
# Tipo: Logic/UI. DETERMINISTA: catálogo real + `ModoConstruccion._crear_ui()`, sin ratón ni GPU
# (mismo patrón que `modo_construccion_barra_categorias_test.gd`).
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")

const TAM_CELDA: int = 40


func _modo() -> Node2D:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.montar_visual(TAM_CELDA, Vector2.ZERO)
	var modo: Node2D = auto_free(ModoConstruccionScript.new())
	modo.configurar(construccion, TAM_CELDA, null)
	add_child(modo)   # ORDEN: configurar() ANTES -- mismo contrato que `Main`.
	return modo


# ── El nombre de la tarjeta ya NO lleva el precio incrustado (F1: el precio es su propia etiqueta) ──
func test_nombre_de_herramienta_no_lleva_precio_incrustado() -> void:
	# Arrange
	var modo: Node2D = _modo()

	# Act
	var nombre: String = String(modo._nombre_por_herramienta.get(&"puesto_doc_general", ""))

	# Assert: ni paréntesis ni el símbolo de euro -- el reskin anterior concatenaba "Nombre (500 €)".
	assert_str(nombre).not_contains("€")
	assert_str(nombre).not_contains("(")


# ── `_datos_ficha` trae la huella REAL del catálogo, no un número puesto a mano ──────────────────
func test_datos_ficha_de_un_asiento_trae_huella_y_precio_del_catalogo() -> void:
	# Arrange
	var modo: Node2D = _modo()
	var comodidad: Resource = Datos.obtener_silencioso(&"Comodidad", &"silla_espera_azul")

	# Act
	var ficha: Dictionary = modo._datos_ficha.get(&"silla_espera_azul", {})

	# Assert
	assert_bool(ficha.has("comodidad")).is_true()
	assert_str(String(ficha.get("precio", ""))).contains(str(comodidad.coste_construccion_eur))
	assert_str(String(ficha.get("huella", ""))).contains("celda")


## Un puesto (TipoPuesto) NO es una `Comodidad` -- su ficha no debe traer la clave "comodidad" (sin
## eso, `_actualizar_ficha` mostraría barras de Confort sobre un mostrador, un campo que no tiene).
func test_datos_ficha_de_un_puesto_no_trae_comodidad() -> void:
	var modo: Node2D = _modo()
	var ficha: Dictionary = modo._datos_ficha.get(&"puesto_doc_general", {})
	assert_bool(ficha.has("comodidad")).is_false()


# ── El buscador (aplicado sobre botones reales) ──────────────────────────────────────────────────
func test_buscador_oculta_tarjetas_que_no_casan_con_el_texto() -> void:
	# Arrange
	var modo: Node2D = _modo()
	modo._mostrar_categoria(&"muebles")

	# Act: como si el jugador escribiera "premium" -- ver la conexión `text_changed` en `_crear_ui`.
	modo._texto_busqueda = "esto_no_existe_en_ningun_nombre_del_catalogo"
	modo._refrescar_tarjetas_visibles()

	# Assert: ninguna tarjeta de "muebles" queda visible, y el aviso de vacío se enciende.
	var alguna_visible: bool = false
	for id: StringName in modo._categoria_de_herramienta.keys():
		if modo._categoria_de_herramienta[id] != &"muebles":
			continue
		if (modo._botones_herramienta[id] as Button).visible:
			alguna_visible = true
	assert_bool(alguna_visible).is_false()
	assert_bool(modo._lbl_categoria_vacia.visible).is_true()


func test_buscador_vacio_muestra_toda_la_categoria_activa() -> void:
	# Arrange
	var modo: Node2D = _modo()
	modo._mostrar_categoria(&"muebles")

	# Act
	modo._texto_busqueda = ""
	modo._refrescar_tarjetas_visibles()

	# Assert: todas las tarjetas de "muebles" quedan visibles otra vez.
	for id: StringName in modo._categoria_de_herramienta.keys():
		if modo._categoria_de_herramienta[id] != &"muebles":
			continue
		assert_bool((modo._botones_herramienta[id] as Button).visible).override_failure_message(
			"'%s' debería estar visible con el buscador vacío" % id
		).is_true()
	assert_bool(modo._lbl_categoria_vacia.visible).is_false()


# ── La ficha del seleccionado ─────────────────────────────────────────────────────────────────
func test_fijar_herramienta_con_un_asiento_muestra_las_tres_barras() -> void:
	# Arrange
	var modo: Node2D = _modo()

	# Act
	modo._fijar_herramienta(&"silla_espera_azul", false)

	# Assert
	assert_bool(modo._ficha_fila_confort.visible).is_true()
	assert_bool(modo._ficha_fila_nota.visible).is_true()
	assert_bool(modo._ficha_fila_paciencia.visible).is_true()
	assert_bool(modo._ficha_vacia_lbl.visible).is_false()


## Un puesto no trae confort/nota/paciencia -- las tres filas se ocultan (instrucción de la tarea:
## "si una comodidad no tiene un campo, oculta esa barra").
func test_fijar_herramienta_con_un_puesto_oculta_las_tres_barras() -> void:
	var modo: Node2D = _modo()
	modo._fijar_herramienta(&"puesto_doc_general", false)
	assert_bool(modo._ficha_fila_confort.visible).is_false()
	assert_bool(modo._ficha_fila_nota.visible).is_false()
	assert_bool(modo._ficha_fila_paciencia.visible).is_false()


## Sin nada en la mano (herramienta &""), la ficha vuelve al aviso vacío.
func test_fijar_herramienta_vacia_muestra_el_aviso_vacio() -> void:
	var modo: Node2D = _modo()
	modo._fijar_herramienta(&"silla_espera_azul", false)   # primero algo...
	modo._fijar_herramienta(&"", false)                     # ...luego se suelta
	assert_bool(modo._ficha_vacia_lbl.visible).is_true()
	assert_bool(modo._ficha_fila_confort.visible).is_false()
