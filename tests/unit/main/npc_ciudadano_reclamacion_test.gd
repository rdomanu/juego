# Mejora ① (2026-08-18) — la señal del RECLAMANTE: quien viene a poner la hoja de reclamaciones
# lleva un "¡!" rojo flotante SIEMPRE visible, para que el jugador sepa que ese ciudadano "está
# ahí para reclamar" (petición literal del usuario). Tipo: Logic/UI. DETERMINISTA — sin frames,
# sin azar; el manager es un doble mínimo (el real cuelga el muñeco de la capa isométrica, cosa
# que aquí no aplica).
extends GdUnitTestSuite

const NpcCiudadanoScript := preload("res://src/main/npc_ciudadano.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")


## Doble mínimo del manager: `configurar` registra el muñeco y el `_physics_process` del NPC
## (que corre en cuanto el nodo entra al árbol) le pregunta si está sentado.
class ManagerFalso extends Node2D:
	func registrar_muneco(_muneco: Node2D) -> void:
		pass

	func esta_sentado(_npc: Node) -> bool:
		return false


func _ciudadano(tramite: StringName) -> Node:
	var manager := ManagerFalso.new()
	auto_free(manager)
	add_child(manager)
	# El NPC se configura FUERA del árbol a propósito: dentro, su _physics_process arranca y
	# pide media API del manager real (esta_sentado, en_frente_del_puesto...) que este test no
	# necesita — la señal se cuelga en configurar(), sin frames.
	var npc: Node = auto_free(NpcCiudadanoScript.new())
	npc.configurar(
		PersonaFlujoScript.new(PersonaScript.new(&"ODAC", tramite, 600), 7),
		manager, 60.0, Color.WHITE
	)
	# El muñeco visible NO es hijo del NPC (el manager real lo cuelga de la capa isométrica; el
	# doble no lo hace) — sin esto queda huérfano y GdUnit lo delata.
	auto_free(npc.muneco)
	return npc


func test_el_reclamante_lleva_su_senal_roja() -> void:
	var npc: Node = _ciudadano(&"reclamacion")

	var icono: Node = npc.muneco.find_child("IconoReclamacion", false, false)

	assert_object(icono).is_not_null()
	assert_bool(icono.visible).is_true()


## Un trámite cualquiera NO lleva la señal: es exclusiva del reclamante (si la llevara todo el
## mundo, no señalaría nada).
func test_un_tramite_normal_no_lleva_senal() -> void:
	var npc: Node = _ciudadano(&"dni")

	assert_object(npc.muneco.find_child("IconoReclamacion", false, false)).is_null()
