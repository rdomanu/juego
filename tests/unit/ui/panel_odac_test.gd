# PANEL DE ODAC — la vista de CONJUNTO de la oficina de denuncias (F4, 2026-08-18; maqueta
# `design/ux/maquetas-menu-2026-08/maqueta_odac.png`). Cubre lo que puede romper el reskin:
#   1. Que la pantalla nazca POBLADA con la foto conocida de la maqueta (2 ventanillas: una en "solo
#      prioritarias" atendiendo y otra "a medida" libre) y con los nombres VISIBLES ("ODAC 1"/"ODAC 2").
#   2. Que el reparto de la cola por prioridad sea el AGREGADO real (Flujo + ODAC.es_prioritaria).
#   3. Que la pastilla de modos ORDENE a ODAC (ADR-0001: la UI lee y ordena, jamás muta) y sea HONESTA
#      en "a medida" (ningún segmento marcado).
#   4. Que el banner de cobertura aparezca y desaparezca según `ODAC.denuncias_sin_cubrir()`.
#
# Tipo: Logic/UI. DETERMINISTA — sin reloj, sin azar y sin arte. `Flujo` y `Personal` se sustituyen
# por dobles mínimos (el panel solo les pide lectura); `ODAC` es el sistema REAL, porque lo que se
# audita es justo cómo la pantalla cuenta y ordena SUS modos sobre el catálogo real de denuncias.
extends GdUnitTestSuite

const PanelODACScript := preload("res://src/main/panel_odac.gd")
const ODACScript := preload("res://src/feature/odac/odac.gd")

## La FOTO CONOCIDA que retrata la maqueta.
const PUESTO_1 := &"odac_1"
const PUESTO_2 := &"odac_2"
const TIPO_ODAC := &"puesto_odac"
## Los dos tipos que ODAC 2 coge "a medida" (los mismos de la maqueta).
const A_MEDIDA: Array[StringName] = [&"hurto_robo", &"danos"]
## Lo que atiende ODAC 1 ahora mismo y cuánto le queda.
const TURNO_ATENDIDO := 12
const RESTANTE_MIN := 22.0
## La cola de ODAC de la maqueta: 5 urgentes + 3 administrativas.
const URGENTES_EN_COLA := 5
const NORMALES_EN_COLA := 3


# ── Dobles mínimos ───────────────────────────────────────────────────────────────────────────────
class PersonaFalsa extends RefCounted:
	var numero_turno: int = 0
	var _tramite: StringName = &"viogen"

	func tramite_id() -> StringName:
		return _tramite


## Doble de Flujo: lectura para la pantalla + lo justo para que ODAC (real) acepte un cambio de modo.
class FlujoFalso extends Node:
	var estados: Dictionary[StringName, StringName] = {}
	var atendida: RefCounted = null
	var restante: float = 0.0
	var cola: Array = []
	var puestos: Array[StringName] = []
	var reconfiguraciones: Array = []

	func puestos_registrados() -> Array[StringName]:
		return puestos

	func tipo_de_puesto_flujo(_puesto_id: StringName) -> StringName:
		return TIPO_ODAC

	func estado_de_puesto(puesto_id: StringName) -> StringName:
		return estados.get(puesto_id, &"libre")

	func persona_en_puesto(puesto_id: StringName) -> RefCounted:
		return atendida if puesto_id == PUESTO_1 else null

	func restante_de_puesto(_puesto_id: StringName) -> float:
		return restante

	func personas_de_cola(_servicio: StringName) -> Array:
		return cola

	func reconfigurar_puesto(puesto_id: StringName, atenciones: Array[StringName]) -> bool:
		reconfiguraciones.append([puesto_id, atenciones])
		return true


class AgenteFalso extends RefCounted:
	var nombre: String = ""

	func _init(n: String) -> void:
		nombre = n


## Doble de Personal: solo lo que la pantalla le pregunta para el nombre visible y el operador.
class PersonalFalso extends Node:
	var agentes: Dictionary[StringName, RefCounted] = {}
	var puestos: Array[StringName] = []

	func puestos_de_servicio(_servicio: StringName) -> Array[StringName]:
		return puestos

	func tipo_de_puesto(_puesto_id: StringName) -> StringName:
		return TIPO_ODAC

	func servicio_de_puesto(_puesto_id: StringName) -> String:
		return "ODAC"

	func puesto_dotado(puesto_id: StringName) -> bool:
		return agentes.has(puesto_id)

	func agente_de(puesto_id: StringName) -> RefCounted:
		return agentes.get(puesto_id, null)


# ── Montaje de la foto conocida ──────────────────────────────────────────────────────────────────
var _flujo: FlujoFalso
var _personal: PersonalFalso
var _odac: Node
var _panel: CanvasLayer


func before_test() -> void:
	_flujo = auto_free(FlujoFalso.new())
	_flujo.puestos = [PUESTO_1, PUESTO_2]
	_flujo.estados = {PUESTO_1: &"atendiendo", PUESTO_2: &"libre"}
	var atendida := PersonaFalsa.new()
	atendida.numero_turno = TURNO_ATENDIDO
	_flujo.atendida = atendida
	_flujo.restante = RESTANTE_MIN
	_flujo.cola = _cola_de_la_maqueta()
	add_child(_flujo)

	_personal = auto_free(PersonalFalso.new())
	_personal.puestos = [PUESTO_1, PUESTO_2]
	_personal.agentes = {
		PUESTO_1: AgenteFalso.new("Marta Soler"), PUESTO_2: AgenteFalso.new("Javier Nieto"),
	}
	add_child(_personal)

	_odac = auto_free(ODACScript.new())
	add_child(_odac)
	_odac.usar_flujo(_flujo)
	_odac.fijar_modo(PUESTO_1, ODACScript.Modo.SOLO_PRIORITARIAS)
	_odac.fijar_modo(PUESTO_2, ODACScript.Modo.SUBCONJUNTO, A_MEDIDA)

	_panel = auto_free(PanelODACScript.new())
	_panel.configurar(_odac, _flujo, _personal)
	add_child(_panel)
	_panel.abrir()
	# Un frame para que se procesen los `queue_free` del repintado y el recolocado diferido (2ª
	# pasada del alto): sin él, los nodos del repintado anterior se quedan colgando como huérfanos.
	await get_tree().process_frame


## 5 personas con denuncia Prioritaria + 3 con Normal — el agregado que la pantalla tiene que contar.
func _cola_de_la_maqueta() -> Array:
	var cola: Array = []
	for i: int in URGENTES_EN_COLA:
		var p := PersonaFalsa.new()
		p._tramite = &"viogen"
		cola.append(p)
	for i: int in NORMALES_EN_COLA:
		var p := PersonaFalsa.new()
		p._tramite = &"amenazas"
		cola.append(p)
	return cola


func _tarjeta(puesto_id: StringName) -> Control:
	return _panel._panel.find_child("Tarjeta_%s" % puesto_id, true, false) as Control


func _texto(nodo: Node, nombre: String) -> String:
	var lbl: Label = nodo.find_child(nombre, true, false) as Label
	return lbl.text if lbl != null else ""


# ══ 1. Estructura: la pantalla nace poblada con la foto de la maqueta ════════════════════════════
func test_estructura_una_tarjeta_por_ventanilla_con_nombre_visible() -> void:
	assert_bool(_panel.visible).is_true()
	var t1: Control = _tarjeta(PUESTO_1)
	var t2: Control = _tarjeta(PUESTO_2)
	assert_object(t1).is_not_null()
	assert_object(t2).is_not_null()
	# NUNCA el id técnico: el helper único del Tablón de Destinos ("ODAC 1"/"ODAC 2").
	assert_str(_texto(t1, "Nombre")).is_equal("ODAC 1")
	assert_str(_texto(t2, "Nombre")).is_equal("ODAC 2")
	assert_str(_texto(t1, "Operador")).is_equal("Operada por Marta Soler")
	assert_str(_texto(t2, "Operador")).is_equal("Operada por Javier Nieto")


func test_estructura_ventanilla_que_atiende_dice_que_y_cuanto_queda() -> void:
	var t1: Control = _tarjeta(PUESTO_1)
	var ahora: String = _texto(t1, "AhoraMismo")
	assert_str(ahora).contains("turno nº %d" % TURNO_ATENDIDO)
	assert_str(ahora).contains("quedan %d min" % roundi(RESTANTE_MIN))
	# El nombre del catálogo, jamás el id "viogen".
	assert_str(ahora).not_contains("viogen")
	# La que está LIBRE no inventa una atención en curso.
	assert_str(_texto(_tarjeta(PUESTO_2), "AhoraMismo")).is_empty()


func test_estructura_cola_desglosada_por_prioridad() -> void:
	assert_str(_panel._lbl_urgentes.text).is_equal("%d urgentes esperando" % URGENTES_EN_COLA)
	assert_str(_panel._lbl_administrativas.text).is_equal(
		"%d administrativas esperando" % NORMALES_EN_COLA
	)


func test_estructura_chips_de_dedicacion_cuentan_las_ventanillas_de_cada_modo() -> void:
	var chips: HBoxContainer = _panel._chips_dedicacion
	assert_int(chips.get_child_count()).is_equal(4)   # los cuatro modos, siempre visibles
	assert_str(_texto(
		chips.find_child("ChipModo_%d" % ODACScript.Modo.SOLO_PRIORITARIAS, true, false), "Texto"
	)).is_equal("1 Solo prioritarias")
	assert_str(_texto(
		chips.find_child("ChipModo_%d" % ODACScript.Modo.SUBCONJUNTO, true, false), "Texto"
	)).is_equal("1 A medida")
	assert_str(_texto(
		chips.find_child("ChipModo_%d" % ODACScript.Modo.POLIVALENTE, true, false), "Texto"
	)).is_equal("0 Polivalente")


func test_estructura_a_medida_indica_cuantas_de_cuantas_y_remite_a_la_ficha() -> void:
	var t2: Control = _tarjeta(PUESTO_2)
	assert_str(_texto(t2, "LblAMedida")).is_equal(
		"A MEDIDA · elegidas %d de %d" % [A_MEDIDA.size(), _odac.denuncias().size()]
	)
	# Un chip por tipo elegido, con su nombre legible.
	var chips: HFlowContainer = t2.find_child("ChipsAMedida", true, false) as HFlowContainer
	assert_int(chips.get_child_count()).is_equal(A_MEDIDA.size())
	# La nota que remite a la ficha (allí viven las casillas tipo a tipo).
	assert_str(_texto(t2, "Ayuda")).contains("su ficha")


# ══ 2. La pastilla de modos ORDENA (ADR-0001) y es honesta ═══════════════════════════════════════
func test_pastilla_de_modo_ordena_fijar_modo() -> void:
	var pastilla: Control = _tarjeta(PUESTO_1).find_child("ModosODAC", true, false) as Control
	var boton: Button = pastilla.find_child(
		"Opcion_modo_%d" % ODACScript.Modo.SOLO_NORMALES, true, false
	) as Button
	# `button_pressed` por código NO emite señales: el clic se simula emitiendo `pressed` a mano.
	boton.emit_signal("pressed")
	await get_tree().process_frame
	assert_int(_odac.modo_de(PUESTO_1)).is_equal(ODACScript.Modo.SOLO_NORMALES)
	# Y la orden llegó a Flujo, que es quien aplica la reconfiguración de verdad.
	assert_int(_flujo.reconfiguraciones.size()).is_greater(2)


func test_pastilla_marca_el_modo_actual_y_ninguno_en_a_medida() -> void:
	var p1: Control = _tarjeta(PUESTO_1).find_child("ModosODAC", true, false) as Control
	for m: int in [
		ODACScript.Modo.POLIVALENTE, ODACScript.Modo.SOLO_PRIORITARIAS,
		ODACScript.Modo.SOLO_NORMALES,
	]:
		var b: Button = p1.find_child("Opcion_modo_%d" % m, true, false) as Button
		assert_bool(b.button_pressed).is_equal(m == ODACScript.Modo.SOLO_PRIORITARIAS)
	# HONESTIDAD: en SUBCONJUNTO ninguno de los tres rápidos está puesto — no se finge que sí.
	var p2: Control = _tarjeta(PUESTO_2).find_child("ModosODAC", true, false) as Control
	for m: int in [
		ODACScript.Modo.POLIVALENTE, ODACScript.Modo.SOLO_PRIORITARIAS,
		ODACScript.Modo.SOLO_NORMALES,
	]:
		assert_bool((p2.find_child("Opcion_modo_%d" % m, true, false) as Button).button_pressed
		).is_false()


# ══ 3. El banner de cobertura sigue a `denuncias_sin_cubrir()` ═══════════════════════════════════
func test_banner_aparece_con_los_tipos_sin_cubrir() -> void:
	# La foto de la maqueta deja huérfanas las normales que ODAC 2 no coge.
	var sin_cubrir: Array[StringName] = _odac.denuncias_sin_cubrir()
	assert_array(sin_cubrir).is_not_empty()
	assert_bool(_panel._banner.visible).is_true()
	assert_str(_panel._lbl_banner.text).contains("SIN COBERTURA")
	assert_str(_panel._lbl_banner.text).contains("%d tipos" % sin_cubrir.size())
	assert_int(_panel._chips_sin_cubrir.get_child_count()).is_equal(sin_cubrir.size())


func test_banner_desaparece_al_cubrirlo_todo() -> void:
	# Una polivalente coge TODO el catálogo → ya no queda ningún tipo huérfano.
	_odac.fijar_modo(PUESTO_1, ODACScript.Modo.POLIVALENTE)
	_odac.fijar_modo(PUESTO_2, ODACScript.Modo.POLIVALENTE)
	_panel._reconstruir()
	await get_tree().process_frame
	assert_array(_odac.denuncias_sin_cubrir()).is_empty()
	assert_bool(_panel._banner.visible).is_false()
	assert_int(_panel._chips_sin_cubrir.get_child_count()).is_equal(0)


func test_sin_ventanillas_lo_dice_en_vez_de_quedarse_en_blanco() -> void:
	_flujo.puestos = [] as Array[StringName]
	_personal.puestos = [] as Array[StringName]
	_panel._reconstruir()
	await get_tree().process_frame
	assert_int(_panel._rejilla.get_child_count()).is_equal(1)
	assert_object(_tarjeta(PUESTO_1)).is_null()
