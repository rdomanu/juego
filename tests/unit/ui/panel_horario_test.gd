# PanelHorario — la pantalla de HORARIO (F3, 2026-08-18; maqueta
# `design/ux/maquetas-menu-2026-08/maqueta_horario.png`). Cubre el contrato que `main.gd` da por hecho
# (el árbol nace poblado tras `configurar()` + `usar_flujo()` + `_refrescar()`), que mover un control
# ORDENA por la API pública de Documentación (ADR-0001: la UI lee y ordena, jamás muta) y que las
# líneas de consecuencia dicen las CIFRAS EXACTAS de la foto de la maqueta (cierre 17:00, peonada
# 22 €/h, 1 agente → 2,5 h extra y 55 €/día).
#
# Tipo: Logic/UI. DETERMINISTA — sin reloj real (Tiempo entra a `null` → el servicio se lee CERRADO),
# sin azar y sin arte. `Flujo` se sustituye por un doble mínimo (`FlujoFalso`): el panel solo le pide
# el estado de la persiana y le ordena abrir/cerrar; arrastrar el Flujo real aquí metería navegación y
# físicas en un test de UI (regla de aislamiento del proyecto).
extends GdUnitTestSuite

const PanelHorarioScript := preload("res://src/main/panel_horario.gd")
const DocumentacionScript := preload("res://src/feature/documentacion/documentacion.gd")
const ConfigDocumentacionScript := preload("res://src/feature/documentacion/config_documentacion.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")

## Horario del escenario retratado en la maqueta: cierre a las 17:00 sobre la jornada base de 14:30.
const CIERRE_MAQUETA_MIN := 1020
## Precio de la hora extra de la maqueta (22 €/h dentro del rango 15-30).
const PEONADA_MAQUETA_EUR := 22.0
## Tope que autoriza el comunicado de vacaciones (21:30) frente al ordinario (20:00).
const TOPE_EVENTO_MIN := 1290


## Doble mínimo de Flujo: las cuatro llamadas que el panel le hace, con registro de órdenes.
class FlujoFalso extends Node:
	var estados: Dictionary[StringName, StringName] = {}
	var pendientes: Dictionary[StringName, bool] = {}
	var ordenes: Array[String] = []

	func estado_de_puesto(puesto_id: StringName) -> StringName:
		return estados.get(puesto_id, &"abierto")

	func cierre_pendiente_de(puesto_id: StringName) -> bool:
		return pendientes.get(puesto_id, false)

	func abrir_puesto(puesto_id: StringName) -> void:
		ordenes.append("abrir:%s" % puesto_id)
		estados[puesto_id] = &"abierto"

	func cerrar_puesto(puesto_id: StringName) -> void:
		ordenes.append("cerrar:%s" % puesto_id)
		estados[puesto_id] = &"cerrado"


# ── Fixture ──────────────────────────────────────────────────────────────────────────────────────
## Personal con DOS ventanillas de Documentación: doc_1 dotada (Elena) y doc_2 vacante — el mismo
## reparto de la maqueta (solo se paga peonada por la que se queda Y está dotada).
func _personal() -> Node:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	personal.registrar_puesto(&"doc_2", &"puesto_doc_general")
	var elena: RefCounted = AgenteScript.new(
		"Elena Ortiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3
	)
	personal.plantilla.append(elena)
	assert_bool(personal.asignar(elena, &"doc_1")).is_true()
	return personal


## Documentación con la config de catálogo (08:00-14:30, tope 20:00, margen 15, peonada 15-30 €).
func _documentacion(personal: Node) -> Node:
	var doc: Node = auto_free(DocumentacionScript.new())
	doc.aplicar_config(ConfigDocumentacionScript.new())
	doc.usar_personal(personal)
	return doc


## Panel montado y ABIERTO (Tiempo y bus a null: el panel los tolera — arranque parcial, mismo
## criterio que el HUD y que el Tablón de Destinos).
func _panel(doc: Node, personal: Node, flujo: Node) -> CanvasLayer:
	var panel: CanvasLayer = auto_free(PanelHorarioScript.new())
	add_child(panel)
	panel.configurar(doc, null, null, personal)
	panel.usar_flujo(flujo)
	panel.visible = true
	panel._refrescar()
	return panel


func _flujo() -> Node:
	var flujo := FlujoFalso.new()
	auto_free(flujo)
	add_child(flujo)
	return flujo


## El escenario EXACTO de la maqueta: cierra a las 17:00 pagando 22 €/hora.
func _panel_de_la_maqueta() -> Array:
	var personal: Node = _personal()
	var doc: Node = _documentacion(personal)
	doc.fijar_hora_cierre(CIERRE_MAQUETA_MIN)
	doc.fijar_peonada_eur_hora(PEONADA_MAQUETA_EUR)
	var panel: CanvasLayer = _panel(doc, personal, _flujo())
	return [panel, doc, personal]


# ── Estructura: la pantalla nace poblada ─────────────────────────────────────────────────────────

## Las tres tarjetas de control, una tarjeta por ventanilla de Doc y el resumen del coste: el árbol
## que `Main._abrir_horario` da por construido.
func test_la_pantalla_nace_con_las_tres_decisiones_y_sus_ventanillas() -> void:
	var personal: Node = _personal()
	var panel: CanvasLayer = _panel(_documentacion(personal), personal, _flujo())

	assert_object(panel._ctrl_cierre).is_not_null()
	assert_object(panel._ctrl_precio).is_not_null()
	assert_object(panel._ctrl_margen).is_not_null()
	assert_object(panel._ctrl_cierre.slider).is_not_null()
	# Una tarjeta por ventanilla de Documentación (doc_1 y doc_2; ODAC no tiene horario aquí).
	assert_int(panel._lista_ventanillas.get_child_count()).is_equal(2)
	assert_int(panel._filas_ventanilla.size()).is_equal(2)
	assert_str(panel._lbl_total.text).is_not_empty()
	# Sin comunicado activo NO hay banner ocupando sitio (criterio de la maqueta).
	assert_bool(panel._banner.visible).is_false()


## El rótulo de cada ventanilla es el nombre VISIBLE del Tablón de Destinos ("DNI 1"/"DNI 2"), nunca
## el id técnico. Se comprueba sobre la lista de nombres que pinta la columna.
func test_las_ventanillas_usan_el_nombre_visible_no_el_id() -> void:
	var personal: Node = _personal()
	var panel: CanvasLayer = _panel(_documentacion(personal), personal, _flujo())

	# El array se declara TIPADO aparte: un `[]` suelto sería `Array` sin tipo y el parámetro
	# `Array[StringName]` del panel lo rechazaría en runtime.
	var puestos: Array[StringName] = [&"doc_1", &"doc_2"]
	var nombres: Array[String] = panel._nombres_visibles(puestos)
	assert_array(nombres).contains_exactly(["DNI 1", "DNI 2"])


# ── Órdenes: la UI llama a la API pública (ADR-0001) ─────────────────────────────────────────────

## Arrastrar el slider de cierre ORDENA la hora nueva a Documentación (por la señal real del control,
## no llamando al manejador a mano).
func test_mover_el_slider_de_cierre_ordena_la_hora() -> void:
	var personal: Node = _personal()
	var doc: Node = _documentacion(personal)
	var panel: CanvasLayer = _panel(doc, personal, _flujo())

	# El recorrido autorizado va de la jornada base (14:30) al tope ordinario (20:00).
	assert_float(panel._ctrl_cierre.slider.min_value).is_equal(870.0)
	assert_float(panel._ctrl_cierre.slider.max_value).is_equal(1200.0)

	panel._ctrl_cierre.slider.value = CIERRE_MAQUETA_MIN

	assert_int(doc.hora_cierre_min).is_equal(CIERRE_MAQUETA_MIN)
	assert_str(panel._ctrl_cierre.lbl_valor.text).is_equal("Cierra a las 17:00")


## El slider del precio ORDENA la peonada por `fijar_peonada_eur_hora`.
func test_mover_el_slider_de_precio_ordena_la_peonada() -> void:
	var personal: Node = _personal()
	var doc: Node = _documentacion(personal)
	var panel: CanvasLayer = _panel(doc, personal, _flujo())

	panel._ctrl_precio.slider.value = PEONADA_MAQUETA_EUR

	assert_float(doc.peonada_eur_hora).is_equal(PEONADA_MAQUETA_EUR)
	assert_str(panel._ctrl_precio.lbl_valor.text).is_equal("22 €/hora")


## El slider de última admisión ORDENA el margen (0 = exprimir: se da número hasta el cierre).
func test_mover_el_slider_de_ultima_admision_ordena_el_margen() -> void:
	var personal: Node = _personal()
	var doc: Node = _documentacion(personal)
	var panel: CanvasLayer = _panel(doc, personal, _flujo())

	panel._ctrl_margen.slider.value = 0.0

	assert_int(doc.margen_ultima_admision_min).is_equal(0)
	assert_str(panel._ctrl_margen.lbl_sub.text).is_equal("se da número hasta el cierre")


## La casilla "se queda por la tarde" ORDENA `fijar_puesto_de_tarde` y la línea de esa ventanilla pasa
## a decir a qué hora cierra en vez de lo que cuesta.
func test_desmarcar_la_tarde_ordena_a_documentacion_y_repinta_la_linea() -> void:
	var datos: Array = _panel_de_la_maqueta()
	var panel: CanvasLayer = datos[0]
	var doc: Node = datos[1]

	panel._al_marcar_ventanilla(&"doc_1", false)

	assert_bool(doc.puesto_de_tarde(&"doc_1")).is_false()
	var lbl: Label = panel._filas_ventanilla[0]["lbl_detalle"]
	assert_str(lbl.text).is_equal("cierra a las 14:30")


## El botón manual de la persiana es una acción DISTINTA de la casilla: pasa por Flujo, no por
## Documentación (cerrar y volver a abrir la misma ventanilla).
func test_el_boton_de_ventanilla_ordena_a_flujo_cerrar_y_abrir() -> void:
	var personal: Node = _personal()
	var flujo: Node = _flujo()
	var panel: CanvasLayer = _panel(_documentacion(personal), personal, flujo)

	panel._al_pulsar_ventanilla(&"doc_1")
	panel._al_pulsar_ventanilla(&"doc_1")

	assert_array(flujo.ordenes).contains_exactly(["cerrar:doc_1", "abrir:doc_1"])


# ── Las consecuencias EN VIVO, con las cifras de la maqueta ──────────────────────────────────────

## La línea de peonada de la maqueta, al carácter: 17:00 sobre una jornada base de 14:30 son 2,5 h
## extra; con 1 agente a 22 €/hora, 55 €/día. Coma decimal castellana y singular sin "(s)".
func test_texto_de_peonada_con_las_cifras_de_la_maqueta() -> void:
	var datos: Array = _panel_de_la_maqueta()
	var panel: CanvasLayer = datos[0]

	assert_str(panel._ctrl_cierre.lbl_consecuencia.text).is_equal(
		"+2,5 h extra × 1 agente  →  PEONADA 55 €/día"
	)
	assert_str(panel._lbl_total.text).is_equal("55 €/día")
	var lbl: Label = panel._filas_ventanilla[0]["lbl_detalle"]
	assert_str(lbl.text).is_equal("55 €/día de peonada")


## Sin horas extra no hay peonada que anunciar: la jornada base se dice en llano.
func test_sin_horas_extra_la_consecuencia_lo_dice_en_llano() -> void:
	var personal: Node = _personal()
	var panel: CanvasLayer = _panel(_documentacion(personal), personal, _flujo())

	assert_str(panel._ctrl_cierre.lbl_consecuencia.text).is_equal(
		"Sin horas extra: la jornada base no cuesta peonada."
	)
	assert_str(panel._lbl_total.text).is_equal("0 €/día")


## El efecto del precio se cuenta en el SENTIDO REAL de la mecánica (pagar mejor cansa MENOS): a
## 22 € de 15-30 el recargo es 1,27 → "un 27 % más", con el tope como referencia.
func test_texto_del_precio_dice_cuanto_cansa_de_mas() -> void:
	var datos: Array = _panel_de_la_maqueta()
	var panel: CanvasLayer = datos[0]

	assert_str(panel._ctrl_precio.lbl_consecuencia.text).is_equal(
		"A este precio la hora extra cansa un 27 % más que una normal · al tope (30 €) cansaría "
		+ "como una normal"
	)


## Al tope del rango la hora extra cansa como una normal (recargo 1,0) — sin porcentaje que enseñar.
func test_al_tope_del_rango_la_hora_extra_cansa_como_una_normal() -> void:
	var personal: Node = _personal()
	var doc: Node = _documentacion(personal)
	doc.fijar_peonada_eur_hora(doc.peonada_eur_hora_max)
	var panel: CanvasLayer = _panel(doc, personal, _flujo())

	assert_str(panel._ctrl_precio.lbl_consecuencia.text).is_equal(
		"A este precio la hora extra cansa como una normal"
	)


# ── El comunicado de la División amplía el recorrido (y se ve por qué) ───────────────────────────

## Con el tope ampliado por un comunicado, el slider llega más lejos Y se dibuja la marca del tope
## ordinario en su fracción exacta: (20:00 − 14:30) / (21:30 − 14:30) = 330/420.
func test_con_tope_ampliado_el_slider_llega_mas_lejos_y_marca_el_tope_ordinario() -> void:
	var personal: Node = _personal()
	var doc: Node = _documentacion(personal)
	var panel: CanvasLayer = _panel(doc, personal, _flujo())
	assert_float(panel._ctrl_cierre.marca.fraccion).is_equal(-1.0)   # sin comunicado, sin marca

	doc.tope_evento_min = TOPE_EVENTO_MIN
	panel._refrescar_cierre()

	assert_float(panel._ctrl_cierre.slider.max_value).is_equal(float(TOPE_EVENTO_MIN))
	assert_float(panel._ctrl_cierre.marca.fraccion).is_equal_approx(330.0 / 420.0, 0.0001)
	assert_str(panel._ctrl_cierre.marca.texto).is_equal("tope ordinario 20:00")
	assert_str(panel._ctrl_cierre.lbl_max.text).is_equal("21:30")
