# PanelVentanilla — la FICHA de una ventanilla (F3, 2026-08-18; maqueta
# `design/ux/maquetas-menu-2026-08/maqueta_ventanilla.png`). Cubre las tres cosas que puede romper un
# reskin: (1) que la ficha nazca POBLADA con las seis secciones de la maqueta, (2) que las cifras de
# EFICACIA salgan con el formato castellano y los números REALES del desglose, y (3) que los mandos
# ORDENEN a quien manda (ADR-0001: la UI lee y ordena, jamás muta) — la casilla de la tarde sobre
# ESA ventanilla, los sliders sobre Documentación y los modos sobre ODAC.
#
# Tipo: Logic/UI. DETERMINISTA — sin reloj real, sin azar y sin arte. `Flujo` y `Construcción` se
# sustituyen por dobles mínimos (el panel solo les pide lectura); `Personal`, `Documentación` y
# `ODAC` son los sistemas REALES, porque lo que se audita aquí es justo cómo la ficha CUENTA sus
# fórmulas (cansancio, modificador de producción, peonada, modos).
extends GdUnitTestSuite

const PanelVentanillaScript := preload("res://src/main/panel_ventanilla.gd")
const MarcadorVentanillaScript := preload("res://src/main/marcador_ventanilla.gd")
const DocumentacionScript := preload("res://src/feature/documentacion/documentacion.gd")
const ConfigDocumentacionScript := preload("res://src/feature/documentacion/config_documentacion.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const ODACScript := preload("res://src/feature/odac/odac.gd")

## La FOTO CONOCIDA que retrata la maqueta: Elena Ortiz en DNI 1 atendiendo el turno 47, con el 48 ya
## llamado, 8 min de trámite restantes y 6 personas en la cola de Documentación.
const TURNO_ATENDIDO := 47
const TURNO_SIGUIENTE := 48
const RESTANTE_MIN := 8.0
const EN_COLA := 6
## Duración efectiva del DNI en esa ventanilla (catálogo 12 min + su desglose) y equipamiento −5 %.
const DURACION_EFECTIVA_MIN := 13.1
const MULT_EQUIPAMIENTO := 0.95
## Cansancio de Elena en la foto (el mismo de la maqueta).
const CANSANCIO_MAQUETA := 72.0


# ── Dobles mínimos ───────────────────────────────────────────────────────────────────────────────
## La persona atendida: las cuatro cosas que la ficha le pregunta.
class PersonaFalsa extends RefCounted:
	var numero_turno: int = 0
	var estado: StringName = &"atendiendo"
	var _servicio: StringName = &"Documentacion"
	var _tramite: StringName = &"dni"

	func servicio() -> StringName:
		return _servicio

	func tramite_id() -> StringName:
		return _tramite


## Doble de Flujo: SOLO lectura (la ficha no le ordena nada). Los números son de la foto conocida.
class FlujoFalso extends Node:
	var tipos: Dictionary[StringName, StringName] = {}
	var estados: Dictionary[StringName, StringName] = {}
	var atendida: RefCounted = null
	var siguiente: RefCounted = null
	var restante: float = 0.0
	var duracion: float = 0.0
	var equipamiento: float = 1.0
	var cola: int = 0

	func tipo_de_puesto_flujo(puesto_id: StringName) -> StringName:
		return tipos.get(puesto_id, &"")

	func estado_de_puesto(puesto_id: StringName) -> StringName:
		return estados.get(puesto_id, &"libre")

	func persona_en_puesto(_puesto_id: StringName) -> RefCounted:
		return atendida

	func siguiente_de(_puesto_id: StringName) -> RefCounted:
		return siguiente

	func restante_de_puesto(_puesto_id: StringName) -> float:
		return restante

	func duracion_efectiva(
		_servicio: StringName, _atencion: StringName, _puesto_id: StringName
	) -> float:
		return duracion

	func mult_equipamiento(_puesto_id: StringName) -> float:
		return equipamiento

	func personas_en_cola(_servicio: StringName) -> int:
		return cola

	# ── Lo que ODAC (real) le pide a Flujo para aceptar un cambio de modo ──────────────────────
	func puestos_registrados() -> Array[StringName]:
		var lista: Array[StringName] = []
		for puesto_id: StringName in tipos:
			lista.append(puesto_id)
		return lista

	func reconfigurar_puesto(_puesto_id: StringName, _atenciones: Array[StringName]) -> bool:
		return true


## Doble de Construcción: dónde está la mesa (para el realce) y si sigue existiendo.
class ConstruccionFalsa extends Node:
	var celdas: Array[Vector2i] = [Vector2i(4, 3), Vector2i(5, 3)]

	func celdas_de_elemento(_elemento_id: StringName) -> Array[Vector2i]:
		return celdas

	func centro_en_pantalla(celda: Vector2i) -> Vector2:
		return Vector2(celda.x * 40.0, celda.y * 20.0)


# ── Fixture ──────────────────────────────────────────────────────────────────────────────────────
## Personal con DOS ventanillas de Documentación (doc_1 dotada con Elena, doc_2 vacante) y una de
## ODAC — el mismo reparto que el resto de pantallas del proyecto.
func _personal() -> Node:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	personal.registrar_puesto(&"doc_2", &"puesto_doc_general")
	personal.registrar_puesto(&"odac_1", &"puesto_odac")
	var elena: RefCounted = AgenteScript.new(
		"Elena Ortiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 4, 3, 3
	)
	elena.cansancio = CANSANCIO_MAQUETA
	personal.plantilla.append(elena)
	assert_bool(personal.asignar(elena, &"doc_1")).is_true()
	return personal


func _documentacion(personal: Node) -> Node:
	var doc: Node = auto_free(DocumentacionScript.new())
	doc.aplicar_config(ConfigDocumentacionScript.new())
	doc.usar_personal(personal)
	return doc


## Flujo con la FOTO CONOCIDA de la maqueta montada encima.
func _flujo_de_la_maqueta() -> Node:
	var flujo := FlujoFalso.new()
	auto_free(flujo)
	add_child(flujo)
	flujo.tipos[&"doc_1"] = &"puesto_doc_general"
	flujo.tipos[&"doc_2"] = &"puesto_doc_general"
	flujo.tipos[&"odac_1"] = &"puesto_odac"
	flujo.estados[&"doc_1"] = &"atendiendo"
	var persona := PersonaFalsa.new()
	persona.numero_turno = TURNO_ATENDIDO
	flujo.atendida = persona
	var siguiente := PersonaFalsa.new()
	siguiente.numero_turno = TURNO_SIGUIENTE
	flujo.siguiente = siguiente
	flujo.restante = RESTANTE_MIN
	flujo.duracion = DURACION_EFECTIVA_MIN
	flujo.equipamiento = MULT_EQUIPAMIENTO
	flujo.cola = EN_COLA
	return flujo


func _odac() -> Node:
	var odac: Node = auto_free(ODACScript.new())
	add_child(odac)
	return odac


## La ficha montada y ABIERTA sobre `puesto_id`. Mismo orden que `Main`: `configurar()` ANTES de
## `add_child` (el `_ready` conecta la señal de ODAC), y `mostrar()` después.
func _ficha(
	puesto_id: StringName, flujo: Node, personal: Node, documentacion: Node,
	odac: Node = null, construccion: Node = null
) -> CanvasLayer:
	var panel: CanvasLayer = auto_free(PanelVentanillaScript.new())
	panel.configurar(flujo, personal, construccion, odac, documentacion)
	add_child(panel)
	panel.mostrar(puesto_id)
	return panel


## La ficha de la maqueta: DNI 1, Elena atendiendo, cola de 6.
func _ficha_de_la_maqueta() -> Array:
	var personal: Node = _personal()
	var doc: Node = _documentacion(personal)
	var flujo: Node = _flujo_de_la_maqueta()
	var panel: CanvasLayer = _ficha(&"doc_1", flujo, personal, doc)
	return [panel, doc, personal, flujo]


## TODOS los textos de la ficha (recorrido en profundidad): el guion completo que lee el jugador.
func _textos(nodo: Node) -> Array[String]:
	var lista: Array[String] = []
	if nodo is Label:
		lista.append((nodo as Label).text)
	for hijo: Node in nodo.get_children():
		lista.append_array(_textos(hijo))
	return lista


# ── Estructura: la ficha nace poblada ────────────────────────────────────────────────────────────

## Las SEIS secciones de la maqueta, en la misma foto: nada de una ficha a medias.
func test_la_ficha_nace_con_las_seis_secciones_de_la_maqueta() -> void:
	var montaje: Array = _ficha_de_la_maqueta()
	var textos: Array[String] = _textos(montaje[0])

	assert_array(textos).contains([
		"AHORA MISMO", "QUIÉN LA LLEVA", "EFICACIA", "EN COLA · DOCUMENTACIÓN",
		"QUÉ ATIENDE", "HORARIO DEL SERVICIO",
	])
	# Las dos cajas pobladas: las etiquetas vivas y los mandos (que se construyen aparte).
	assert_int((montaje[0] as CanvasLayer)._caja_viva.get_child_count()).is_greater(6)
	assert_int((montaje[0] as CanvasLayer)._caja_mandos.get_child_count()).is_greater(4)


## La cabecera dice el nombre del TIPO de puesto (catálogo) y el chip, el nombre VISIBLE de la
## ventanilla ("DNI 1"), NUNCA el id técnico "doc_1" — la deuda que arrastraba el andamio.
func test_la_cabecera_usa_el_catalogo_y_el_nombre_visible() -> void:
	var montaje: Array = _ficha_de_la_maqueta()
	var panel: CanvasLayer = montaje[0]

	assert_str(panel._lbl_titulo.text).is_equal("Ventanilla Documentación")
	assert_str(panel._lbl_chip.text).is_equal("DNI 1 · ATENDIENDO")
	assert_str(panel.nombre_visible()).is_equal("DNI 1")


## La segunda ventanilla del mismo prefijo es "DNI 2" (ordinal dentro de su prefijo, igual que en el
## Tablón y en el panel de Horario: la misma ventanilla se llama igual en las tres pantallas).
func test_la_segunda_ventanilla_de_doc_se_llama_dni_2() -> void:
	var personal: Node = _personal()
	var panel: CanvasLayer = _ficha(
		&"doc_2", _flujo_de_la_maqueta(), personal, _documentacion(personal)
	)

	assert_str(panel.nombre_visible()).is_equal("DNI 2")


## AHORA MISMO: el trámite en curso, su turno, lo que queda y el siguiente ya llamado.
func test_ahora_mismo_cuenta_el_tramite_el_turno_y_lo_que_queda() -> void:
	var montaje: Array = _ficha_de_la_maqueta()
	var textos: Array[String] = _textos(montaje[0])

	assert_array(textos).contains([
		"DNI", "Turno nº 47", "Quedan 8 min de trámite", "Siguiente ya llamado: turno nº 48",
	])


## Estados vacíos HONESTOS: una ventanilla cerrada no dice lo mismo que una abierta sin agente.
func test_los_estados_vacios_se_cuentan_distinto() -> void:
	var personal: Node = _personal()
	var flujo: Node = _flujo_de_la_maqueta()
	flujo.atendida = null
	flujo.siguiente = null
	flujo.estados[&"doc_2"] = &"cerrado"
	var panel: CanvasLayer = _ficha(&"doc_2", flujo, personal, _documentacion(personal))

	var textos: Array[String] = _textos(panel)
	assert_array(textos).contains(["Ventanilla cerrada"])
	# Y doc_2 está vacante: la ficha lo dice y manda al jugador a Personal.
	assert_array(textos).contains(["Sin agente asignado"])


## QUIÉN LA LLEVA: los atributos y el cansancio CON su consecuencia real (la fórmula de Personal,
## `mult_cansancio_rendimiento`) — un "72" a secas no es información.
func test_el_cansancio_se_cuenta_con_su_consecuencia_en_porcentaje() -> void:
	var montaje: Array = _ficha_de_la_maqueta()
	var personal: Node = montaje[2]
	var agente: RefCounted = personal.agente_de(&"doc_1")
	var lento: float = (personal.mult_cansancio_rendimiento(agente) - 1.0) * 100.0

	var textos: Array[String] = _textos(montaje[0])
	assert_array(textos).contains([
		"Elena Ortiz", "Rapidez 3 · Trato 4 · Motivación 3",
		"Cansancio 72 %%  (%+.0f %% más lento)" % lento,
	])
	# La consecuencia no puede salir en cero: con 72 de cansancio, la ficha tiene que doler.
	assert_float(lento).is_greater(0.0)


## EFICACIA descompuesta, con las CIFRAS EXACTAS y la coma castellana: sin el desglose, el jugador no
## sabe si tocar al agente o al equipamiento.
func test_la_eficacia_sale_descompuesta_y_con_coma_castellana() -> void:
	var montaje: Array = _ficha_de_la_maqueta()
	var personal: Node = montaje[2]
	var modificador: float = personal.modificador_produccion_de(&"doc_1")

	var textos: Array[String] = _textos(montaje[0])
	assert_array(textos).contains([
		"DNI: 13,1 min",                                        # 13.1 con COMA, nunca punto
		"De catálogo: 12 min",                                  # duracion_min de dni.tres
		"Por su agente: %+.0f %%" % ((modificador - 1.0) * 100.0),
		"Por el equipamiento: -5 %",                            # mult_equipamiento 0,95
		"≈ 4,6 atenciones/hora",                                # 60 / 13,1
	])


## EN COLA va etiquetada POR SERVICIO: esas 6 personas son de toda Documentación, no "las suyas".
func test_la_cola_se_etiqueta_por_servicio() -> void:
	var montaje: Array = _ficha_de_la_maqueta()
	var textos: Array[String] = _textos(montaje[0])

	assert_array(textos).contains(["EN COLA · DOCUMENTACIÓN", "6 personas esperando turno"])


## Cola vacía: se dice, no se deja el hueco en blanco (y en singular no sobra la "s").
func test_la_cola_vacia_y_la_de_una_persona_se_dicen_bien() -> void:
	var personal: Node = _personal()
	var flujo: Node = _flujo_de_la_maqueta()
	flujo.cola = 0
	var panel: CanvasLayer = _ficha(&"doc_1", flujo, personal, _documentacion(personal))
	assert_array(_textos(panel)).contains(["Nadie esperando turno"])

	flujo.cola = 1
	panel._refrescar_vivo()
	assert_array(_textos(panel)).contains(["1 persona esperando turno"])


## QUÉ ATIENDE: los trámites del catálogo con su nombre visible.
func test_que_atiende_lista_los_tramites_del_catalogo() -> void:
	var montaje: Array = _ficha_de_la_maqueta()

	assert_array(_textos(montaje[0])).contains(["DNI, Pasaporte"])


# ── Órdenes (ADR-0001: la UI ordena por la API pública, nunca muta) ──────────────────────────────

## La casilla "esta ventanilla se queda por la tarde" ordena sobre ESA ventanilla y solo esa.
func test_la_casilla_de_tarde_ordena_sobre_esta_ventanilla() -> void:
	var montaje: Array = _ficha_de_la_maqueta()
	var panel: CanvasLayer = montaje[0]
	var doc: Node = montaje[1]
	var casilla: Button = panel._caja_mandos.find_child("CasillaTarde", true, false) as Button

	assert_object(casilla).is_not_null()
	# Por defecto TODAS se quedan por la tarde: la casilla nace marcada.
	assert_bool(casilla.button_pressed).is_true()
	casilla.button_pressed = false      # emite `toggled`, como el clic del jugador

	assert_bool(doc.puesto_de_tarde(&"doc_1")).is_false()
	assert_bool(doc.puesto_de_tarde(&"doc_2")).is_true()   # la vecina NO se toca


## El slider de cierre es el MISMO horario del panel de la tecla H: ordena a Documentación y la línea
## de peonada se repinta con euros (formato único del kit).
func test_el_slider_de_cierre_ordena_el_horario_y_repinta_la_peonada() -> void:
	var montaje: Array = _ficha_de_la_maqueta()
	var panel: CanvasLayer = montaje[0]
	var doc: Node = montaje[1]
	var slider: HSlider = panel._caja_mandos.find_child("SliderCierre", true, false) as HSlider

	assert_object(slider).is_not_null()
	slider.value = 1020.0   # 17:00 — el escenario de la maqueta (2,5 h extra)

	assert_int(doc.hora_cierre_min).is_equal(1020)
	var lbl: Label = panel._caja_mandos.find_child("LblPeonada", true, false) as Label
	assert_str(lbl.text).contains("Peonada:")
	assert_str(lbl.text).contains("€/día")
	assert_str(lbl.text).contains("2,5 h extra")


## El slider del precio de la hora extra ordena a Documentación y su línea sale con el formato de
## dinero del kit (nunca "22.0").
func test_el_slider_de_precio_ordena_y_se_escribe_en_euros() -> void:
	var montaje: Array = _ficha_de_la_maqueta()
	var panel: CanvasLayer = montaje[0]
	var doc: Node = montaje[1]
	var slider: HSlider = panel._caja_mandos.find_child("SliderPrecio", true, false) as HSlider

	slider.value = 22.0

	assert_float(doc.peonada_eur_hora).is_equal_approx(22.0, 0.01)
	var lbl: Label = panel._caja_mandos.find_child("LblPrecio", true, false) as Label
	assert_str(lbl.text).is_equal("Precio de la hora extra: 22 €")


# ── La rama ODAC (existe y queda igual de moderna) ───────────────────────────────────────────────

## En ODAC la ficha enseña el MODO (pastilla segmentada del kit) y las denuncias UNA A UNA con la
## casilla dibujada del kit — nunca los `CheckBox` del tema global pixel-art.
func test_la_ficha_de_odac_trae_los_modos_y_las_denuncias() -> void:
	var personal: Node = _personal()
	var odac: Node = _odac()
	var panel: CanvasLayer = _ficha(
		&"odac_1", _flujo_de_la_maqueta(), personal, _documentacion(personal), odac
	)

	var pastilla: Node = panel._caja_mandos.find_child("ModosODAC", true, false)
	assert_object(pastilla).is_not_null()
	assert_int(pastilla.find_children("Opcion_modo_*", "Button", true, false).size()).is_equal(3)
	# Una casilla por denuncia del catálogo.
	var casillas: Array[Node] = panel._caja_mandos.find_children("Denuncia_*", "Button", true, false)
	assert_int(casillas.size()).is_equal(odac.denuncias().size())
	# Y NO se cuela el bloque de horario de Documentación en una ventanilla de ODAC.
	assert_object(panel._caja_mandos.find_child("SliderCierre", true, false)).is_null()


## Desmarcar una denuncia en una ventanilla POLIVALENTE la pasa a "a medida" con el resto: el
## jugador piensa en denuncias, no en modos.
func test_desmarcar_una_denuncia_ordena_el_modo_a_medida() -> void:
	var personal: Node = _personal()
	var odac: Node = _odac()
	# ODAC ignora fijar_modo sin Flujo inyectado (reconfigura el puesto a traves de el): el MISMO
	# doble que recibe la ficha se inyecta tambien en ODAC, como hace Main con el Flujo real.
	var flujo: Node = _flujo_de_la_maqueta()
	odac.usar_flujo(flujo)
	var panel: CanvasLayer = _ficha(
		&"odac_1", flujo, personal, _documentacion(personal), odac
	)
	var primera: StringName = odac.denuncias()[0]
	var casilla: Button = panel._caja_mandos.find_child(
		"Denuncia_%s" % primera, true, false
	) as Button

	assert_bool(casilla.button_pressed).is_true()   # polivalente = las coge todas
	# Asignar `button_pressed` por codigo NO emite `toggled` en Godot 4: se emite a mano, que es
	# lo que hace el clic real (mismo criterio que `pressed.emit()` en los tests del HUD).
	casilla.button_pressed = false
	casilla.toggled.emit(false)

	assert_int(odac.modo_de(&"odac_1")).is_equal(odac.Modo.SUBCONJUNTO)
	assert_array(odac.subconjunto_de(&"odac_1")).not_contains([primera])
