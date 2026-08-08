# BUG REPORTADO POR EL USUARIO (2026-08-08): "el policía salta la mesa hacia el ciudadano al ir a la
# impresora y vuelve sin nada". Causa raíz confirmada en `npcs_flujo.gd`: `_iniciar_camino_impresora`
# usaba `_punto_de_su_puesto` (celda + Vector2i(0,1) — el lado del CIUDADANO, idéntico a
# `_frente_del_puesto`) como origen del viaje de ida del FUNCIONARIO. El muñeco nacía teletransportado
# al otro lado del mostrador — de ahí el "salto de mesa".
#
# La corrección añade `_punto_puesto_funcionario` (celda + Vector2i(0,-1), el lado real del
# funcionario) y la usa como origen/destino de la ida y la vuelta. Este test cubre la propiedad que
# importa: el viaje NACE en el lado correcto y, con navegación real, jamás visita el lado del
# ciudadano durante el tramo de ida.
#
# Tipo: Integration (Construccion + Personal + Flujo + ImpresoraDocumentos + NPCsFlujo reales, sin
# mocks — ticks de Flujo a mano para llegar a FASE_IDA; physics frames reales para la navegación).
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
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
## Tope de ticks del bucle de simulación (minutos de modelo) hasta llegar a FASE_IDA.
const TOPE_TICS: int = 400
## Tope de physics frames reales para vigilar el tramo de ida (de sobra: unas pocas celdas).
const TOPE_FRAMES: int = 240


## Mundo REAL (Construcción + Personal + Flujo + ImpresoraDocumentos + NPCsFlujo), todo enganchado
## entre sí — igual que `Main`, sin capa visual. Se añade al árbol para que corran los
## `_physics_process` (NPCsFlujo levanta el viaje cosmético ahí, `_refrescar_impresora`).
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
	config_flujo.velocidad_camino_celdas_min = 0.0   # se mide el viaje del PAPEL, no el paseo del cliente
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


func test_el_viaje_de_impresora_nace_en_el_lado_del_funcionario_y_no_cruza_al_del_ciudadano() -> void:
	# Arrange
	var mundo: Dictionary = _mundo()
	var flujo: Node = mundo["flujo"]
	var impresora: Node = mundo["impresora"]
	var construccion: Node = mundo["construccion"]
	var npcs: Node = mundo["npcs"]
	_admitir(flujo)

	# Act 1 — ticks de MODELO hasta que el funcionario se levanta a por el papel (FASE_IDA).
	var en_ida: bool = false
	for _i: int in range(TOPE_TICS):
		flujo._al_tick(1.0)
		if impresora.fase_de(ID_ODAC) == ImpresoraScript.FASE_IDA:
			en_ida = true
			break
	assert_bool(en_ida).is_true()
	# Physics frames reales: `_refrescar_impresora` (dentro de `_physics_process`) levanta el viaje
	# cosmético en cuanto ve FASE_IDA. Varios frames de margen -- la señal `physics_frame` despierta
	# al test ANTES del paso de física de ese frame, así que con UN solo await el `_physics_process`
	# de NPCsFlujo puede no haber corrido aún (carrera vista en la 1ª ejecución de la suite).
	for _f: int in range(10):
		await get_tree().physics_frame
		if npcs._camino_impresora.has(ID_ODAC):
			break

	# Assert 1 — EL ORIGEN: la celda NORTE del puesto (el lado del FUNCIONARIO), NUNCA la SUR (el lado
	# del CIUDADANO, `_punto_de_su_puesto` — el punto que causaba el salto).
	assert_bool(npcs._camino_impresora.has(ID_ODAC)).is_true()
	var muneco: Node2D = npcs._camino_impresora[ID_ODAC]["muneco"]
	var lado_funcionario: Vector2 = construccion.centro_de_celda(ANCLA_ODAC + Vector2i(0, -1))
	var lado_ciudadano: Vector2 = construccion.centro_de_celda(ANCLA_ODAC + Vector2i(0, 1))
	assert_vector(muneco.position).is_equal_approx(lado_funcionario, Vector2(0.5, 0.5))
	assert_bool(muneco.position.distance_to(lado_ciudadano) > float(TAM_CELDA) * 0.5).is_true()

	# Act 2 — physics frames reales durante el tramo de IDA: se vigila el Y máximo que alcanza el
	# muñeco (plano lógico cuadrado; +Y es "hacia el sur", el lado del ciudadano).
	var limite_sur: float = construccion.centro_de_celda(ANCLA_ODAC).y + float(TAM_CELDA) * 0.5
	var maximo_y: float = muneco.position.y
	for _i: int in range(TOPE_FRAMES):
		await get_tree().physics_frame
		if not npcs._camino_impresora.has(ID_ODAC):
			break
		var viaje: Dictionary = npcs._camino_impresora[ID_ODAC]
		if viaje["fase"] != &"yendo":
			break
		maximo_y = maxf(maximo_y, (viaje["muneco"] as Node2D).position.y)

	# Assert 2 — LA RUTA REAL (NavigationServer2D): en ningún frame de la ida el muñeco pasa de la
	# fila del propio puesto — jamás llega a pisar la fila SUR (la del ciudadano), que es la lectura en
	# píxeles de "cruza el mostrador".
	assert_float(maximo_y).is_less(limite_sur)
