# EL VIAJE DEL PAPEL de punta a punta: Flujo + Construcción + Personal + ImpresoraDocumentos ·
# GDD `design/gdd/impresora-documentos-tramite.md` (§Acceptance Criteria). Tipo: Integration.
# DETERMINISTA: catálogo real, layout real, ticks empujados a mano (sin reloj, sin azar).
#
# Lo que se demuestra aquí es la promesa entera de la mecánica:
#   · un trámite CON papel termina exactamente `t_viaje − T_AVISO` más tarde que sin la mecánica,
#   · el ciudadano NO abandona mientras espera el documento (sigue En atención),
#   · un trámite SIN papel (DNI) va exactamente igual que antes, y
#   · el viaje no dispara una segunda incorporación (invariante de entrada única).
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

# ── Fixture ───────────────────────────────────────────────────────────────────────────────
const SALA_ODAC := &"sala_odac"
const RECT_ODAC := Rect2i(0, 0, 8, 4)
const SALA_ESPERA_ODAC := &"sala_espera_odac"
const RECT_ESPERA_ODAC := Rect2i(0, 5, 4, 3)
const SALA_DOC := &"sala_documentacion"
const RECT_DOC := Rect2i(10, 0, 6, 4)
const SALA_ESPERA_DOC := &"sala_espera_doc"
const RECT_ESPERA_DOC := Rect2i(10, 5, 4, 3)
const PUESTO_ODAC := &"puesto_odac"
const ID_ODAC := &"odac_1"
const ANCLA_ODAC := Vector2i(1, 1)
const PUESTO_DOC := &"puesto_doc_general"
const ID_DOC := &"doc_1"
const ANCLA_DOC := Vector2i(11, 1)
## Impresora en la misma fila del mostrador, a 3 celdas de la celda de trabajo (1,1).
const CELDA_IMPRESORA := Vector2i(4, 1)
const DISTANCIA: int = 3

## Knobs de laboratorio: 1 celda/min y 2 min de recogida → t_viaje = 2×3/1 + 2 = 8 min.
const VELOCIDAD := 1.0
const RECOGIDA := 2.0
const T_AVISO := 5.0
const T_VIAJE := 8.0
## Retraso que la mecánica añade al trámite: el viaje empieza cuando quedan T_AVISO, así que solo se
## nota lo que el viaje excede a ese margen (§Detailed Rules 1 + 3).
const RETRASO_ESPERADO := T_VIAJE - T_AVISO   # 3 min

## Denuncia ODAC del catálogo real (lleva papel — P2: TODAS las denuncias).
const DENUNCIA := &"hurto_robo"
const SERVICIO_ODAC := &"ODAC"
const TRAMITE_DNI := &"dni"
const SERVICIO_DOC := &"Documentacion"
## Tope de ticks del bucle de simulación: cualquier trámite del catálogo cabe de sobra y evita que un
## fallo cuelgue la suite en un `while` infinito.
const TOPE_TICS: int = 400
const MINUTO_LLEGADA := 511.0


# ── Helpers de fixture ────────────────────────────────────────────────────────────────────
## Mundo REAL (Construcción + Personal + Flujo) con una ventanilla de ODAC y otra de Documentación.
## `con_impresora` decide si la mecánica está en juego: con `false` se obtiene el mundo de ANTES,
## que es el que da la línea base contra la que se mide el retraso.
func _mundo(con_impresora: bool) -> Dictionary:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.k_cansancio_rendimiento = 0.0   # se apaga para aislar la variable bajo prueba
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_personal(personal)
	construccion.construir_de_oficio_sala(SALA_ODAC, RECT_ODAC)
	construccion.construir_de_oficio_sala(SALA_ESPERA_ODAC, RECT_ESPERA_ODAC)
	construccion.construir_de_oficio_sala(SALA_DOC, RECT_DOC)
	construccion.construir_de_oficio_sala(SALA_ESPERA_DOC, RECT_ESPERA_DOC)
	construccion.construir_de_oficio_elemento(PUESTO_ODAC, ANCLA_ODAC, ID_ODAC)
	construccion.construir_de_oficio_elemento(PUESTO_DOC, ANCLA_DOC, ID_DOC)
	var flujo: Node = auto_free(FlujoScript.new())
	var config_flujo: Resource = ConfigFlujoScript.new()
	# El camino Llamada→puesto se apaga (0 = instantáneo): lo que se mide aquí es el viaje del PAPEL,
	# no el paseo del ciudadano. Mismo recurso que ya usan los tests de flujo para aislar variables.
	config_flujo.velocidad_camino_celdas_min = 0.0
	# Y el equipamiento de la sala tampoco puede acelerar la atención: con la impresora instalada la
	# sala sube 2,0 de rendimiento, y sin esto los dos mundos no serían comparables minuto a minuto.
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
	flujo.registrar_puesto_flujo(ID_DOC, PUESTO_DOC)
	_asignar(personal, ID_ODAC, &"ag_odac")
	_asignar(personal, ID_DOC, &"ag_doc")
	return {"flujo": flujo, "personal": personal, "construccion": construccion, "impresora": impresora}


## Agente de atributos MEDIOS (3/3/3/3): su `modificador_produccion` es neutro, así que la duración
## efectiva del trámite es la del catálogo y los dos mundos son comparables.
func _asignar(personal: Node, puesto_id: StringName, tipo: StringName) -> RefCounted:
	var agente: RefCounted = AgenteScript.new("Ana Ruiz", tipo, AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)
	personal.plantilla.append(agente)
	personal.asignar(agente, puesto_id)
	return agente


func _admitir(flujo: Node, servicio: StringName, tramite: StringName) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(servicio, tramite, MINUTO_LLEGADA))
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


# ── AC · "termina exactamente t_viaje después de lo que terminaría sin mecánica" ──────────
func test_denuncia_odac_con_impresora_termina_mas_tarde_por_el_viaje_del_papel() -> void:
	# Arrange — el MISMO trámite, en dos mundos idénticos salvo por la impresora.
	var sin_mecanica: Dictionary = _mundo(false)
	var con_mecanica: Dictionary = _mundo(true)
	var persona_base: RefCounted = _admitir(sin_mecanica["flujo"], SERVICIO_ODAC, DENUNCIA)
	var persona_papel: RefCounted = _admitir(con_mecanica["flujo"], SERVICIO_ODAC, DENUNCIA)
	# Act
	var tics_base: int = _tics_hasta_resuelta(sin_mecanica["flujo"], persona_base)
	var tics_papel: int = _tics_hasta_resuelta(con_mecanica["flujo"], persona_papel)
	# Assert — el viaje arranca cuando quedan T_AVISO minutos y se solapa con ellos: lo que se paga
	# es solo lo que el viaje excede a ese margen (GDD §Detailed Rules 1 y 3).
	assert_int(tics_base).is_greater(0)
	assert_int(tics_papel).is_equal(tics_base + int(RETRASO_ESPERADO))


func test_una_impresora_mas_lejos_retrasa_mas_el_tramite() -> void:
	# Arrange — la promesa de diseño ("colocar bien la impresora IMPORTA") medida de verdad: se aleja
	# la impresora una celda y el trámite tiene que tardar 2 minutos más (ida + vuelta).
	var mundo: Dictionary = _mundo(true)
	var construccion: Node = mundo["construccion"]
	var cerca: StringName = construccion.elementos_de_catalogo(ImpresoraScript.ID_CATALOGO)[0]
	construccion.demoler_elemento(cerca)
	construccion.construir_de_oficio_elemento(
		ImpresoraScript.ID_CATALOGO, CELDA_IMPRESORA + Vector2i(1, 0)
	)
	var lejos: Dictionary = _mundo(true)
	var persona_cerca: RefCounted = _admitir(lejos["flujo"], SERVICIO_ODAC, DENUNCIA)
	var persona_lejos: RefCounted = _admitir(mundo["flujo"], SERVICIO_ODAC, DENUNCIA)
	# Act
	var tics_cerca: int = _tics_hasta_resuelta(lejos["flujo"], persona_cerca)
	var tics_lejos: int = _tics_hasta_resuelta(mundo["flujo"], persona_lejos)
	# Assert — una celda más de distancia = 2 minutos más de viaje (ida y vuelta a 1 celda/min).
	assert_int(tics_lejos).is_equal(tics_cerca + 2)


# ── AC · "el ciudadano no abandona durante ESPERANDO_DOCUMENTO" ──────────────────────────
func test_el_ciudadano_sigue_en_atencion_mientras_espera_el_documento() -> void:
	# Arrange
	var mundo: Dictionary = _mundo(true)
	var flujo: Node = mundo["flujo"]
	var impresora: Node = mundo["impresora"]
	var persona: RefCounted = _admitir(flujo, SERVICIO_ODAC, DENUNCIA)
	# Act — se avanza hasta que el trámite está a 0 pero el funcionario aún no ha vuelto.
	var visto_esperando: bool = false
	for _i: int in range(TOPE_TICS):
		flujo._al_tick(1.0)
		if persona.estado == PersonaFlujoScript.ESTADO_RESUELTA:
			break
		if flujo.restante_de_puesto(ID_ODAC) <= 0.0 and impresora.retiene(ID_ODAC):
			visto_esperando = true
			# Assert (en el momento exacto) — sigue EN ATENCIÓN: Paciencia la tiene parada desde la
			# llamada, así que no drena ni abandona. Y la ventanilla lo cuenta.
			assert_str(String(persona.estado)).is_equal(
				String(PersonaFlujoScript.ESTADO_EN_ATENCION)
			)
			assert_str(String(flujo.estado_de_puesto(ID_ODAC))).is_equal("atendiendo")
			assert_str(impresora.texto_ventanilla(ID_ODAC)).is_equal(
				ImpresoraScript.TEXTO_A_POR_EL_DOCUMENTO
			)
	# Assert — la fase ESPERANDO_DOCUMENTO ha existido de verdad, y el trámite acabó cerrándose.
	assert_bool(visto_esperando).is_true()
	assert_str(String(persona.estado)).is_equal(String(PersonaFlujoScript.ESTADO_RESUELTA))


# ── P2 · un trámite SIN papel va exactamente igual que antes de la mecánica ──────────────
func test_el_dni_no_dispara_ningun_viaje() -> void:
	# Arrange — el DNI no lleva papel (GDD P2), así que la impresora no debe tocarlo.
	var sin_mecanica: Dictionary = _mundo(false)
	var con_mecanica: Dictionary = _mundo(true)
	var persona_base: RefCounted = _admitir(sin_mecanica["flujo"], SERVICIO_DOC, TRAMITE_DNI)
	var persona: RefCounted = _admitir(con_mecanica["flujo"], SERVICIO_DOC, TRAMITE_DNI)
	# Act
	var tics_base: int = _tics_hasta_resuelta(sin_mecanica["flujo"], persona_base)
	var tics: int = _tics_hasta_resuelta(con_mecanica["flujo"], persona)
	# Assert — mismo número de minutos y ni un viaje registrado.
	assert_int(tics).is_equal(tics_base)
	assert_bool((con_mecanica["impresora"] as Node).hay_viaje(ID_DOC)).is_false()


# ── AC · invariante de ENTRADA ÚNICA: el viaje no incorpora a nadie por segunda vez ──────
func test_el_viaje_no_dispara_una_segunda_incorporacion() -> void:
	# Arrange — dos denuncias seguidas por la misma ventanilla.
	var mundo: Dictionary = _mundo(true)
	var flujo: Node = mundo["flujo"]
	var impresora: Node = mundo["impresora"]
	var primera: RefCounted = _admitir(flujo, SERVICIO_ODAC, DENUNCIA)
	var segunda: RefCounted = _admitir(flujo, SERVICIO_ODAC, DENUNCIA)
	# Act — se simula hasta que las dos quedan resueltas, vigilando que nunca haya dos personas
	# a la vez en el mismo mostrador ni un viaje huérfano sin cliente.
	for _i: int in range(TOPE_TICS):
		flujo._al_tick(1.0)
		if flujo.persona_en_puesto(ID_ODAC) == null:
			assert_bool(impresora.retiene(ID_ODAC)).is_false()
		if segunda.estado == PersonaFlujoScript.ESTADO_RESUELTA:
			break
	# Assert — las dos despachadas, en orden, y la ventanilla queda limpia (sin viaje colgado).
	assert_str(String(primera.estado)).is_equal(String(PersonaFlujoScript.ESTADO_RESUELTA))
	assert_str(String(segunda.estado)).is_equal(String(PersonaFlujoScript.ESTADO_RESUELTA))
	assert_bool(impresora.hay_viaje(ID_ODAC)).is_false()
	assert_int(flujo.personas_en_cola(SERVICIO_ODAC)).is_equal(0)


# ── Edge case · demoler la impresora a mitad de viaje no cuelga el trámite ───────────────
func test_demoler_la_impresora_a_media_atencion_no_deja_el_tramite_colgado() -> void:
	# Arrange
	var mundo: Dictionary = _mundo(true)
	var flujo: Node = mundo["flujo"]
	var impresora: Node = mundo["impresora"]
	var construccion: Node = mundo["construccion"]
	var persona: RefCounted = _admitir(flujo, SERVICIO_ODAC, DENUNCIA)
	# Act — en cuanto el funcionario se levanta, se demuele la impresora bajo sus pies.
	var demolida: bool = false
	for _i: int in range(TOPE_TICS):
		flujo._al_tick(1.0)
		if not demolida and impresora.fase_de(ID_ODAC) == ImpresoraScript.FASE_IDA:
			var id_impresora: StringName = impresora.impresora_de(ID_ODAC)
			construccion.demoler_elemento(id_impresora)
			impresora.impresora_demolida(id_impresora)
			demolida = true
		if persona.estado == PersonaFlujoScript.ESTADO_RESUELTA:
			break
	# Assert — vuelve con las manos vacías y el trámite se cierra igual (§Edge Cases del GDD).
	assert_bool(demolida).is_true()
	assert_str(String(persona.estado)).is_equal(String(PersonaFlujoScript.ESTADO_RESUELTA))


# ── Mantenimiento POR USO cableado de verdad: atender anota el turno de la sala ──────────
func test_atender_anota_el_turno_de_la_sala_para_el_mantenimiento() -> void:
	# Arrange
	var mundo: Dictionary = _mundo(true)
	var flujo: Node = mundo["flujo"]
	var impresora: Node = mundo["impresora"]
	var construccion: Node = mundo["construccion"]
	impresora.usar_tiempo(auto_free(RelojFijo.new()))
	var persona: RefCounted = _admitir(flujo, SERVICIO_ODAC, DENUNCIA)
	# Act
	_tics_hasta_resuelta(flujo, persona)
	# Assert — la sala de ODAC ha atendido en 1 turno → 2 € (la de Documentación, en ninguno → 0 €).
	var sala_odac: StringName = construccion.sala_de_elemento(ID_ODAC)
	var sala_doc: StringName = construccion.sala_de_elemento(ID_DOC)
	assert_int(impresora.turnos_usados_de(sala_odac)).is_equal(1)
	assert_int(impresora.turnos_usados_de(sala_doc)).is_equal(0)
	assert_float(impresora.coste_mantenimiento_uso()).is_equal_approx(2.0, 0.001)


## Reloj de mentira parado en el turno de mañana: el mantenimiento por uso necesita saber el turno,
## y aquí lo que se prueba es el CABLEADO (que atender anota), no el paso de las horas.
class RelojFijo extends Node:
	var minutos_juego: float = 540.0

	func turno_de(_min_dia: float) -> int:
		return 0
