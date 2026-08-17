# MarcadorVentanilla + PanelVentanilla — el REALCE en el mundo de la ventanilla cuya ficha
# esta abierta (F3, 2026-08-18). SEPARADO de panel_ventanilla_test.gd A PROPOSITO: el escaner de
# GdUnit4 solo lee los primeros ~16 KB de un archivo de tests y estos dos casos caian mas alla
# (se ejecutaban 15 de 17 SIN NINGUN error — gotcha cazado con biseccion el 2026-08-18).
# Comparte fixtures con panel_ventanilla_test.gd por duplicacion deliberada: cada archivo de
# tests es autonomo (regla de aislamiento del proyecto).
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
# ── El realce en el mundo ────────────────────────────────────────────────────────────────────────

## Abrir la ficha enciende el marcador sobre la MESA REAL (sus celdas), y cerrarla lo apaga: el
## jugador tiene que ver CUÁL de las ventanillas está mirando, y no quedarse un halo huérfano.
func test_el_marcador_se_enciende_al_abrir_y_se_apaga_al_cerrar() -> void:
	var personal: Node = _personal()
	var construccion := ConstruccionFalsa.new()
	auto_free(construccion)
	add_child(construccion)
	var marcador: Node2D = auto_free(MarcadorVentanillaScript.new())
	add_child(marcador)
	var panel: CanvasLayer = _ficha(
		&"doc_1", _flujo_de_la_maqueta(), personal, _documentacion(personal), null, construccion
	)
	panel.usar_marcador(marcador)
	panel.mostrar(&"doc_1")

	assert_bool(marcador.esta_encendido()).is_true()

	panel.visible = false

	assert_bool(marcador.esta_encendido()).is_false()


## Si la ventanilla se demuele con la ficha abierta, la ficha se cierra con ella (y se lleva el
## halo): seguir enseñando los números de un mueble que ya no está sería mentir.
func test_demoler_la_ventanilla_cierra_la_ficha() -> void:
	var personal: Node = _personal()
	var construccion := ConstruccionFalsa.new()
	auto_free(construccion)
	add_child(construccion)
	var panel: CanvasLayer = _ficha(
		&"doc_1", _flujo_de_la_maqueta(), personal, _documentacion(personal), null, construccion
	)
	assert_bool(panel.visible).is_true()

	construccion.celdas = []
	panel._refrescar_vivo()

	assert_bool(panel.visible).is_false()
