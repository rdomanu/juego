# LogicaPanelConstruccion (F0/F1, 2026-08-15 — reskin del panel de construcción): las partes PURAS
# del panel nuevo (filtro del buscador, huella "N celda(s) · M plaza(s)", derivaciones de la ficha
# Confort/Nota al salir/Paciencia extra). Ver la cabecera de `src/ui/logica_panel_construccion.gd`.
#
# Tipo: Logic puro (RefCounted, sin Node ni escena). DETERMINISTA.
extends GdUnitTestSuite

const LogicaPanelConstruccionScript := preload("res://src/ui/logica_panel_construccion.gd")


# ── normalizar_busqueda / coincide_busqueda ──────────────────────────────────────────────────────

func test_normalizar_busqueda_recorta_espacios_y_pasa_a_minusculas() -> void:
	# Arrange / Act
	var normalizado: String = LogicaPanelConstruccionScript.normalizar_busqueda("  Banco Premium  ")

	# Assert
	assert_str(normalizado).is_equal("banco premium")


func test_coincide_busqueda_con_buscador_vacio_coincide_siempre() -> void:
	assert_bool(LogicaPanelConstruccionScript.coincide_busqueda("Banco premium", "")).is_true()
	assert_bool(LogicaPanelConstruccionScript.coincide_busqueda("Banco premium", "   ")).is_true()


func test_coincide_busqueda_encuentra_substring_sin_importar_mayusculas() -> void:
	assert_bool(LogicaPanelConstruccionScript.coincide_busqueda("Banco premium", "PREM")).is_true()
	assert_bool(LogicaPanelConstruccionScript.coincide_busqueda("Banco premium", "silla")).is_false()


# ── tarjeta_visible (el filtro completo: categoría + buscador) ──────────────────────────────────

func test_tarjeta_visible_categoria_distinta_nunca_se_ve() -> void:
	# Arrange
	var visible: bool = LogicaPanelConstruccionScript.tarjeta_visible(
		&"muebles", &"salas", "Banco premium", ""
	)

	# Assert
	assert_bool(visible).is_false()


func test_tarjeta_visible_categoria_vacia_nunca_es_la_activa() -> void:
	# Demoler y el resto del panel lateral se registran con categoría &"" (fuera de la rejilla) --
	# esta función nunca debe darlos por "visibles" aunque `categoria_activa` también fuera &"".
	var visible: bool = LogicaPanelConstruccionScript.tarjeta_visible(&"", &"", "Demoler", "")
	assert_bool(visible).is_false()


func test_tarjeta_visible_misma_categoria_sin_busqueda_se_ve() -> void:
	var visible: bool = LogicaPanelConstruccionScript.tarjeta_visible(
		&"muebles", &"muebles", "Banco premium", ""
	)
	assert_bool(visible).is_true()


func test_tarjeta_visible_misma_categoria_con_busqueda_que_no_casa_se_oculta() -> void:
	var visible: bool = LogicaPanelConstruccionScript.tarjeta_visible(
		&"muebles", &"muebles", "Banco premium", "escritorio"
	)
	assert_bool(visible).is_false()


func test_tarjeta_visible_misma_categoria_con_busqueda_que_casa_se_ve() -> void:
	var visible: bool = LogicaPanelConstruccionScript.tarjeta_visible(
		&"muebles", &"muebles", "Banco premium", "banco"
	)
	assert_bool(visible).is_true()


# ── texto_huella ──────────────────────────────────────────────────────────────────────────────

func test_texto_huella_singular_celda_y_plaza() -> void:
	assert_str(LogicaPanelConstruccionScript.texto_huella(1, 1)).is_equal("1 celda · 1 plaza")


func test_texto_huella_plural_celdas_y_plazas() -> void:
	assert_str(LogicaPanelConstruccionScript.texto_huella(2, 3)).is_equal("2 celdas · 3 plazas")


## Un escritorio (0 plazas) omite del todo la mitad de "plazas" -- no tiene sentido decir "0 plazas".
func test_texto_huella_sin_plazas_omite_esa_mitad() -> void:
	assert_str(LogicaPanelConstruccionScript.texto_huella(1, 0)).is_equal("1 celda")


# ── fraccion_confort ──────────────────────────────────────────────────────────────────────────

## Banco premium de la maqueta: aporte 7, tope 7 -> barra LLENA (fracción 1.0).
func test_fraccion_confort_con_aporte_igual_al_tope_llena_la_barra() -> void:
	var fraccion: float = LogicaPanelConstruccionScript.fraccion_confort(7.0)
	assert_float(fraccion).is_equal_approx(1.0, 0.001)


func test_fraccion_confort_a_mitad_de_tope_da_media_barra() -> void:
	var fraccion: float = LogicaPanelConstruccionScript.fraccion_confort(3.5)
	assert_float(fraccion).is_equal_approx(0.5, 0.001)


## Un aporte por encima del tope de presentación NO rompe la barra -- se queda llena (clamp).
func test_fraccion_confort_por_encima_del_tope_se_clampa_a_uno() -> void:
	var fraccion: float = LogicaPanelConstruccionScript.fraccion_confort(20.0)
	assert_float(fraccion).is_equal_approx(1.0, 0.001)


# ── porcentaje_nota_al_salir ──────────────────────────────────────────────────────────────────

## Banco premium de la maqueta: factor_satisfaccion 1.2 -> "+20%".
func test_porcentaje_nota_al_salir_banco_premium_da_20() -> void:
	var pct: int = LogicaPanelConstruccionScript.porcentaje_nota_al_salir(1.2)
	assert_int(pct).is_equal(20)


## Neutro (todo lo que no es asiento, o esperar de pie): factor_satisfaccion 1.0 -> 0.
func test_porcentaje_nota_al_salir_neutro_da_cero() -> void:
	var pct: int = LogicaPanelConstruccionScript.porcentaje_nota_al_salir(1.0)
	assert_int(pct).is_equal(0)


# ── porcentaje_paciencia_extra ────────────────────────────────────────────────────────────────

## Banco premium de la maqueta: aporte 7 × k_confort 0.02 × 100 = 14 -> "+14%".
func test_porcentaje_paciencia_extra_banco_premium_da_14() -> void:
	var pct: int = LogicaPanelConstruccionScript.porcentaje_paciencia_extra(7.0)
	assert_int(pct).is_equal(14)


func test_porcentaje_paciencia_extra_sin_aporte_da_cero() -> void:
	var pct: int = LogicaPanelConstruccionScript.porcentaje_paciencia_extra(0.0)
	assert_int(pct).is_equal(0)
