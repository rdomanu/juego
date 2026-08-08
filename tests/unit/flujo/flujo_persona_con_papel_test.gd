# PersonaFlujo.con_papel + Flujo._completar_atencion (GDD impresora-documentos-tramite.md). Bug
# reportado por el usuario (2026-08-08): "el ciudadano no sale con su papel" — faltaba el DATO que
# `NPCCiudadano` pudiera leer para colgarle el documento visible en la salida (el dibujo en sí es otra
# story, cubierta en `tests/integration/impresora/impresora_papel_visible_test.gd`).
#
# El punto fino que este archivo vigila es el ORDEN: `Flujo._completar_atencion` tiene que leer
# `ImpresoraDocumentos.con_papel(puesto_id)` ANTES de `consumir_viaje(puesto_id)` — esa llamada BORRA
# el registro del viaje, así que preguntar después siempre daría `false` (el bug de orden que un
# refactor descuidado podría reintroducir sin que ningún test lo note).
#
# Tipo: Logic. DETERMINISTA: catálogo real, ticks empujados a mano (sin reloj, sin azar). Ningún nodo
# necesita estar en el árbol de escena — `_al_tick` es lógica pura.
extends GdUnitTestSuite

const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ImpresoraScript := preload("res://src/core/impresora/impresora_documentos.gd")
const ConfigImpresoraScript := preload("res://src/core/impresora/config_impresora.gd")

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
const TOPE_TICS: int = 400


# ── Helpers de fixture (mismo patrón que `tests/integration/impresora/viaje_del_papel_test.gd`) ──
func _mundo(con_impresora: bool) -> Dictionary:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.k_cansancio_rendimiento = 0.0   # se apaga para aislar la variable bajo prueba
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_personal(personal)
	construccion.construir_de_oficio_sala(SALA_ODAC, RECT_ODAC)
	construccion.construir_de_oficio_sala(SALA_ESPERA_ODAC, RECT_ESPERA_ODAC)
	construccion.construir_de_oficio_elemento(PUESTO_ODAC, ANCLA_ODAC, ID_ODAC)
	var flujo: Node = auto_free(FlujoScript.new())
	var config_flujo: Resource = ConfigFlujoScript.new()
	config_flujo.velocidad_camino_celdas_min = 0.0   # se mide el viaje del PAPEL, no el paseo del cliente
	config_flujo.k_equipamiento = 0.0
	flujo.aplicar_config(config_flujo)
	flujo.usar_personal(personal)
	flujo.usar_construccion(construccion)
	var impresora: Node = null
	if con_impresora:
		impresora = auto_free(ImpresoraScript.new())
		var config: Resource = ConfigImpresoraScript.new()
		config.velocidad_celdas_min = VELOCIDAD
		config.t_recogida_min = RECOGIDA
		config.t_aviso_min = T_AVISO
		impresora.aplicar_config(config)
		impresora.usar_construccion(construccion)
		construccion.construir_de_oficio_elemento(ImpresoraScript.ID_CATALOGO, CELDA_IMPRESORA)
		flujo.usar_impresora(impresora)
	flujo.registrar_puesto_flujo(ID_ODAC, PUESTO_ODAC)
	var agente: RefCounted = AgenteScript.new(
		"Ana Ruiz", &"ag_odac", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3
	)
	personal.plantilla.append(agente)
	personal.asignar(agente, ID_ODAC)
	return {"flujo": flujo, "impresora": impresora}


func _admitir(flujo: Node) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(SERVICIO_ODAC, DENUNCIA, MINUTO_LLEGADA))
	flujo.encolar(persona)
	return persona


## Empuja ticks de 1 minuto hasta que la persona quede Resuelta; devuelve cuántos hicieron falta
## (-1 si no termina en `TOPE_TICS`, para que un fallo se vea como fallo y no como cuelgue).
func _tics_hasta_resuelta(flujo: Node, persona: RefCounted) -> int:
	for i: int in range(TOPE_TICS):
		flujo._al_tick(1.0)
		if persona.estado == PersonaFlujoScript.ESTADO_RESUELTA:
			return i + 1
	return -1


# ── AC · el campo nace en `false` (mismo patrón que `colado`) ────────────────────────────
func test_persona_flujo_con_papel_nace_en_false() -> void:
	# Arrange / Act
	var persona: RefCounted = PersonaFlujoScript.new(
		PersonaScript.new(SERVICIO_ODAC, DENUNCIA, 0.0), 1
	)
	# Assert
	assert_bool(persona.con_papel).is_false()


# ── AC · `_completar_atencion` marca `con_papel = true` cuando la impresora entregó de verdad ────
func test_completar_atencion_con_impresora_con_papel_marca_persona_con_papel() -> void:
	# Arrange — una denuncia (lleva papel, P2) con la impresora instalada y a distancia real.
	var mundo: Dictionary = _mundo(true)
	var persona: RefCounted = _admitir(mundo["flujo"])
	# Act
	var tics: int = _tics_hasta_resuelta(mundo["flujo"], persona)
	# Assert — se resolvió (el viaje del papel no la deja colgada en ESPERANDO_DOCUMENTO para
	# siempre) y salió con el documento marcado. Si `_completar_atencion` preguntara DESPUÉS de
	# `consumir_viaje` (el bug de orden que este test vigila), `ImpresoraDocumentos.con_papel` ya no
	# tendría el viaje que mirar —lo borra `consumir_viaje`— y esto daría `false`.
	assert_int(tics).is_greater(0)
	assert_bool(persona.con_papel).is_true()


# ── Edge case · sin impresora inyectada, nunca se marca (aunque el trámite lleve papel) ──────────
func test_completar_atencion_sin_impresora_no_marca_con_papel() -> void:
	# Arrange — MISMO trámite (con papel, P2) pero en el mundo SIN la mecánica instalada (tests de
	# Flujo puros, o una partida sin la impresora construida).
	var mundo: Dictionary = _mundo(false)
	var persona: RefCounted = _admitir(mundo["flujo"])
	# Act
	var tics: int = _tics_hasta_resuelta(mundo["flujo"], persona)
	# Assert — se resuelve igual (sin la mecánica, ni retiene ni marca nada) y sale con las manos
	# vacías: `_impresora == null` corta la marca antes de preguntar nada.
	assert_int(tics).is_greater(0)
	assert_bool(persona.con_papel).is_false()
