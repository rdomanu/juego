# BUG REPORTADO POR EL USUARIO (2026-08-08): "el ciudadano no sale con su papel" — el policía volvía
# de la impresora con las manos vacías (visualmente) y `persona.con_papel` no existía, así que
# `NPCCiudadano` no tenía de dónde leer si colgarle el documento a la salida.
#
# Cubre las DOS mitades del gesto de entrega (GDD impresora-documentos-tramite.md):
#   1. COSMÉTICA — el funcionario se ve CON el papel puesto durante la vuelta y el gesto de entrega
#      (`NPCsFlujo._poner_papel`/`_avanzar_entrega`), y sin él en cuanto el viaje se cierra.
#   2. DATO — `Flujo._completar_atencion` marca `persona.con_papel = true` (leído ANTES de
#      `ImpresoraDocumentos.consumir_viaje`, que borra el registro del viaje) cuando la impresora
#      entregó de verdad, así que el ciudadano sale marcado.
#
# Tipo: Integration (Construccion + Personal + Flujo + ImpresoraDocumentos + NPCsFlujo +
# NPCCiudadano reales, sin mocks — modelo y cosmético avanzan JUNTOS: un tick de Flujo por cada
# physics frame real).
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const ImpresoraScript := preload("res://src/core/impresora/impresora_documentos.gd")
const ConfigImpresoraScript := preload("res://src/core/impresora/config_impresora.gd")
const NPCsFlujoScript := preload("res://src/main/npcs_flujo.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 24
const FILAS: int = 13

const SALA_ODAC := &"sala_odac"
const RECT_ODAC := Rect2i(0, 0, 8, 4)
const SALA_ESPERA_ODAC := &"sala_espera_odac"
const RECT_ESPERA_ODAC := Rect2i(0, 5, 4, 3)
const PUESTO_ODAC := &"puesto_odac"
const ID_ODAC := &"odac_1"
const ANCLA_ODAC := Vector2i(1, 1)
## Impresora en la misma fila del mostrador, a 3 celdas de la celda de trabajo.
const CELDA_IMPRESORA := Vector2i(4, 1)

const VELOCIDAD := 1.0
const RECOGIDA := 2.0
const T_AVISO := 5.0

const DENUNCIA := &"hurto_robo"   # lleva papel (P2: todas las denuncias de ODAC)
const SERVICIO_ODAC := &"ODAC"
const MINUTO_LLEGADA := 511.0
## Tope de iteraciones: cada una es 1 minuto de MODELO + 1 physics frame REAL. De sobra para que el
## trámite se resuelva (modelo, decenas de minutos) Y para que el paseo del funcionario/ciudadano
## termine en píxeles reales (cosmético, unos pocos cientos de frames).
const TOPE_ITERACIONES: int = 500


## Mundo REAL (Construcción + Personal + Flujo + ImpresoraDocumentos + NPCsFlujo), enganchado entre
## sí igual que `Main`, sin capa visual. Se añade al árbol para que corran los `_physics_process`.
func _mundo() -> Dictionary:
	var personal: Node = auto_free(PersonalScript.new())
	add_child(personal)
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.k_cansancio_rendimiento = 0.0   # se apaga para aislar la variable bajo prueba
	var construccion: Node = auto_free(ConstruccionScript.new())
	add_child(construccion)
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_personal(personal)
	construccion.construir_de_oficio_sala(SALA_ODAC, RECT_ODAC)
	construccion.construir_de_oficio_sala(SALA_ESPERA_ODAC, RECT_ESPERA_ODAC)
	construccion.construir_de_oficio_elemento(PUESTO_ODAC, ANCLA_ODAC, ID_ODAC)
	var flujo: Node = auto_free(FlujoScript.new())
	add_child(flujo)
	var config_flujo: Resource = ConfigFlujoScript.new()
	config_flujo.k_equipamiento = 0.0
	flujo.aplicar_config(config_flujo)
	flujo.usar_personal(personal)
	flujo.usar_construccion(construccion)
	var impresora: Node = auto_free(ImpresoraScript.new())
	add_child(impresora)
	var config_impresora: Resource = ConfigImpresoraScript.new()
	config_impresora.velocidad_celdas_min = VELOCIDAD
	config_impresora.t_recogida_min = RECOGIDA
	config_impresora.t_aviso_min = T_AVISO
	impresora.aplicar_config(config_impresora)
	impresora.usar_construccion(construccion)
	construccion.construir_de_oficio_elemento(ImpresoraScript.ID_CATALOGO, CELDA_IMPRESORA)
	flujo.usar_impresora(impresora)
	flujo.registrar_puesto_flujo(ID_ODAC, PUESTO_ODAC)
	var agente: RefCounted = AgenteScript.new(
		"Ana Ruiz", &"ag_odac", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3
	)
	personal.plantilla.append(agente)
	personal.asignar(agente, ID_ODAC)
	var npcs: Node = auto_free(NPCsFlujoScript.new())
	add_child(npcs)
	npcs.configurar(flujo, construccion, personal, TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS, null)
	npcs.usar_impresora(impresora)
	return {
		"construccion": construccion, "flujo": flujo, "impresora": impresora, "npcs": npcs,
	}


func _admitir(flujo: Node) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(SERVICIO_ODAC, DENUNCIA, MINUTO_LLEGADA))
	flujo.encolar(persona)
	return persona


func test_papel_visible_en_la_vuelta_del_policia_y_con_papel_activo_en_la_salida_del_ciudadano() -> void:
	# Arrange
	var mundo: Dictionary = _mundo()
	var flujo: Node = mundo["flujo"]
	var npcs: Node = mundo["npcs"]
	var persona: RefCounted = _admitir(flujo)
	npcs.spawn(persona)   # el ciudadano visible, como haría Main al admitir

	# Act — modelo y cosmético avanzan JUNTOS.
	var visto_papel_en_vuelta_del_policia: bool = false
	for _i: int in range(TOPE_ITERACIONES):
		flujo._al_tick(1.0)
		await get_tree().physics_frame
		if npcs._camino_impresora.has(ID_ODAC):
			var viaje: Dictionary = npcs._camino_impresora[ID_ODAC]
			if viaje["fase"] == &"volviendo" or viaje["fase"] == &"entregando":
				var visual: Node2D = npcs._visual_caminante(viaje["muneco"])
				if visual != null and visual.get_node_or_null("Papel") != null:
					visto_papel_en_vuelta_del_policia = true
		if (
			persona.estado == PersonaFlujoScript.ESTADO_RESUELTA
			and not npcs._camino_impresora.has(ID_ODAC)
		):
			break

	# Assert — el policía SE VIO con el papel puesto durante la vuelta/entrega...
	assert_bool(visto_papel_en_vuelta_del_policia).is_true()
	# ...su viaje cosmético se cerró del todo (gesto de entrega hecho, sin papel colgando: lo quita
	# `_avanzar_entrega` antes de devolver `true`, y `_cerrar_camino_impresora` lo repite defensivo)...
	assert_bool(npcs._camino_impresora.has(ID_ODAC)).is_false()
	# ...y el ciudadano sale marcado `con_papel = true` — lo fija `Flujo._completar_atencion` LEYENDO
	# `ImpresoraDocumentos.con_papel` ANTES de `consumir_viaje` (que borra el registro del viaje; si el
	# orden se invirtiera, esto daría `false`).
	assert_str(String(persona.estado)).is_equal(String(PersonaFlujoScript.ESTADO_RESUELTA))
	assert_bool(persona.con_papel).is_true()
