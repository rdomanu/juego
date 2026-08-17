# PanelPersonal — "El Tablón de Destinos" (F3, 2026-08-17; maqueta
# `design/ux/maquetas-menu-2026-08/maqueta_personal.png`). Cubre el contrato que `main.gd` da por
# hecho (el árbol nace poblado tras `configurar()` + `_reconstruir()`), la norma de nombres visibles
# (NUNCA un id técnico en pantalla) y que las órdenes de la UI llaman a la API pública de Personal
# (ADR-0001: la UI lee y ordena, jamás muta estado por su cuenta).
#
# Tipo: Logic/UI. DETERMINISTA — sin reloj real, sin azar, sin arte (los avatares son iniciales).
# `Flujo` se sustituye por un doble mínimo (`FlujoFalso`): el panel solo le pide
# `puestos_registrados()` y arrastrar el Flujo real aquí metería navegación y físicas en un test
# de UI (regla de aislamiento del proyecto).
extends GdUnitTestSuite

const PanelPersonalScript := preload("res://src/main/panel_personal.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")


## Doble mínimo de Flujo: la ÚNICA llamada que el panel le hace.
class FlujoFalso extends Node:
	var puestos: Array[StringName] = []

	func puestos_registrados() -> Array[StringName]:
		return puestos


func _personal() -> Node:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	personal.registrar_puesto(&"doc_2", &"puesto_doc_general")
	personal.registrar_puesto(&"odac_1", &"puesto_odac")
	return personal


func _policia_doc(nombre: String = "Ana Ruiz") -> RefCounted:
	return AgenteScript.new(nombre, &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)


## Panel montado y ABIERTO contra un Personal real y el doble de Flujo (economía/construcción a
## null: el panel los tolera — arranque parcial, mismo criterio que el HUD).
func _panel(personal: Node) -> CanvasLayer:
	var flujo := FlujoFalso.new()
	flujo.puestos = [&"doc_1", &"doc_2", &"odac_1"]
	auto_free(flujo)
	add_child(flujo)
	var panel: CanvasLayer = auto_free(PanelPersonalScript.new())
	add_child(panel)
	panel.configurar(personal, null, null, flujo)
	panel.visible = true
	panel._reconstruir()
	return panel


# ── La norma de nombres visibles (vale para TODO el juego) ──────────────────────────────────────

## doc_1 con tipo de catálogo conocido → "DNI 1"; el ordinal es el que manda, no el sufijo del id.
func test_nombre_visible_mapea_por_tipo_y_ordinal() -> void:
	assert_str(
		PanelPersonalScript.nombre_visible_de_puesto(&"doc_1", &"puesto_doc_general", 1)
	).is_equal("DNI 1")
	assert_str(
		PanelPersonalScript.nombre_visible_de_puesto(&"cualquier_id", &"puesto_odac", 2)
	).is_equal("ODAC 2")
	assert_str(
		PanelPersonalScript.nombre_visible_de_puesto(&"puesto_9", &"puesto_tie", 1)
	).is_equal("TIE 1")


## Un tipo fuera de la tabla devuelve el id TAL CUAL — feo a propósito: delata la tabla incompleta
## en la primera captura en vez de inventarse un nombre bonito y equivocado.
func test_nombre_visible_de_tipo_desconocido_delata_el_id_tecnico() -> void:
	assert_str(
		PanelPersonalScript.nombre_visible_de_puesto(&"raro_3", &"puesto_inventado", 1)
	).is_equal("raro_3")


# ── Estructura: el tablón nace poblado ──────────────────────────────────────────────────────────

## Un slot por puesto registrado, y las tres zonas con su cabecera. La academia enseña una tarjeta
## por candidato del mercado real (lo que haya generado Personal con su config por defecto).
func test_el_tablon_nace_con_un_slot_por_puesto() -> void:
	var personal: Node = _personal()
	personal.mercado.append(_policia_doc("Laura Gomez"))
	var panel: CanvasLayer = _panel(personal)

	assert_int(panel._slots.size()).is_equal(3)
	assert_object(panel._lista_puestos).is_not_null()
	assert_object(panel._lista_banquillo).is_not_null()
	assert_object(panel._lista_academia).is_not_null()
	# El candidato sembrado a mano pinta SU tarjeta (con mercado vacio la lista pinta un
	# placeholder, no cero hijos -- por eso se siembra en vez de asertar contra el tamano real).
	assert_int(panel._lista_academia.get_child_count()).is_equal(1)


# ── Órdenes: la UI llama a la API pública (ADR-0001) ────────────────────────────────────────────

## Soltar a un agente del banquillo sobre un puesto compatible y VACANTE lo asigna de verdad
## (el drop termina en `Personal.asignar`, no en estado propio de la UI).
func test_soltar_en_puesto_vacante_asigna() -> void:
	var personal: Node = _personal()
	var agente: RefCounted = _policia_doc()
	personal.plantilla.append(agente)
	var panel: CanvasLayer = _panel(personal)

	panel._soltar_en_puesto({"agente": agente, "origen": "banquillo"}, &"doc_1")

	assert_str(String(agente.estado)).is_equal("asignado")
	assert_str(String(agente.puesto_id)).is_equal("doc_1")
	assert_bool(personal.puesto_dotado(&"doc_1")).is_true()


## Soltar sobre un puesto que su tipo NO opera se rechaza SIN mover al agente y con motivo visible
## en el aviso de cabecera (un rechazo nunca es silencioso — regla del proyecto).
func test_soltar_en_puesto_incompatible_se_rechaza_con_motivo() -> void:
	var personal: Node = _personal()
	var agente: RefCounted = _policia_doc()
	personal.plantilla.append(agente)
	var panel: CanvasLayer = _panel(personal)

	panel._soltar_en_puesto({"agente": agente, "origen": "banquillo"}, &"odac_1")

	assert_str(String(agente.estado)).is_equal("libre")
	assert_bool(personal.puesto_dotado(&"odac_1")).is_false()
	assert_bool(panel._lbl_aviso.visible).is_true()
	assert_str(panel._lbl_aviso.text).is_not_empty()


## Mover a un agente YA asignado a otro puesto vacante = desasignar + asignar por la API pública
## (no hay intercambio en el Core y la UI no lo inventa).
func test_soltar_un_asignado_en_otro_puesto_lo_mueve() -> void:
	var personal: Node = _personal()
	var agente: RefCounted = _policia_doc()
	personal.plantilla.append(agente)
	assert_bool(personal.asignar(agente, &"doc_1")).is_true()
	var panel: CanvasLayer = _panel(personal)

	panel._soltar_en_puesto({"agente": agente, "origen": "puesto"}, &"doc_2")

	assert_str(String(agente.puesto_id)).is_equal("doc_2")
	assert_bool(personal.puesto_dotado(&"doc_1")).is_false()
	assert_bool(personal.puesto_dotado(&"doc_2")).is_true()


## Soltar sobre un puesto OCUPADO por alguien compatible = INTERCAMBIO compuesto con la API
## pública (2026-08-17, petición del usuario: con la plantilla al completo no se podía mover a
## nadie): cada uno acaba en el puesto del otro.
func test_soltar_sobre_ocupado_intercambia_los_puestos() -> void:
	var personal: Node = _personal()
	var ana: RefCounted = _policia_doc("Ana Ruiz")
	var carlos: RefCounted = _policia_doc("Carlos Vega")
	personal.plantilla.append(ana)
	personal.plantilla.append(carlos)
	assert_bool(personal.asignar(ana, &"doc_1")).is_true()
	assert_bool(personal.asignar(carlos, &"doc_2")).is_true()
	var panel: CanvasLayer = _panel(personal)

	panel._soltar_en_puesto({"agente": ana, "origen": "puesto", "puesto_origen": &"doc_1"}, &"doc_2")

	assert_str(String(ana.puesto_id)).is_equal("doc_2")
	assert_str(String(carlos.puesto_id)).is_equal("doc_1")


## Soltar desde el banquillo sobre un puesto ocupado = SUSTITUCIÓN: el titular pasa al banquillo
## (no hay puesto de origen al que devolverlo) y se avisa — nunca en silencio.
func test_soltar_desde_banquillo_sobre_ocupado_sustituye() -> void:
	var personal: Node = _personal()
	var ana: RefCounted = _policia_doc("Ana Ruiz")
	var nuevo: RefCounted = _policia_doc("Noa Ferrer")
	personal.plantilla.append(ana)
	personal.plantilla.append(nuevo)
	assert_bool(personal.asignar(ana, &"doc_1")).is_true()
	var panel: CanvasLayer = _panel(personal)

	panel._soltar_en_puesto({"agente": nuevo, "origen": "banquillo"}, &"doc_1")

	assert_str(String(nuevo.puesto_id)).is_equal("doc_1")
	assert_str(String(ana.estado)).is_equal("libre")
	assert_bool(panel._lbl_aviso.visible).is_true()


## La línea de impacto enseña el antes → después de las medias de Rapidez y Trato del servicio
## destino (petición del usuario: "DNI tiene rapidez 4 y al cambiar tendría 3,5 — eso es info
## útil"). Con doc_1 dotado (4/3) y un banquillo 2/5 entrando en doc_2: medias 4,0→3,0 y 3,0→4,0.
func test_texto_impacto_calcula_las_medias_del_servicio() -> void:
	var personal: Node = _personal()
	var titular: RefCounted = AgenteScript.new(
		"Ana Ruiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 4, 3, 3, 3
	)
	var entrante: RefCounted = AgenteScript.new(
		"Noa Ferrer", &"ag_doc", AgenteScript.RANGO_POLICIA, 2, 5, 3, 3
	)
	personal.plantilla.append(titular)
	personal.plantilla.append(entrante)
	assert_bool(personal.asignar(titular, &"doc_1")).is_true()
	var panel: CanvasLayer = _panel(personal)

	assert_str(panel._texto_impacto(entrante, &"doc_2")).is_equal(
		"Rapidez 4,0 → 3,0 · Trato 3,0 → 4,0"
	)


## Desasignar y despedir desde la ficha pasan por la API y el tablón se repinta sin reventar.
func test_ordenes_de_ficha_llaman_a_la_api() -> void:
	var personal: Node = _personal()
	var agente: RefCounted = _policia_doc()
	personal.plantilla.append(agente)
	assert_bool(personal.asignar(agente, &"doc_1")).is_true()
	var panel: CanvasLayer = _panel(personal)

	panel._ordenar_desasignar(agente)
	assert_str(String(agente.estado)).is_equal("libre")

	panel._ordenar_despedir(agente)
	assert_bool(personal.plantilla.has(agente)).is_false()
