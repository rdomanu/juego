# Story 006 (epic flujo) — compromiso de servicio y gestión en caliente · TR-flow-003 + AC-CO13 ·
# ADR-0001. Tipo: Integration. DETERMINISTA (sin azar; ticks manuales de 1 min; Personal, Economía,
# Construcción y catálogo REALES). Solo el test de Pausa mete nodos al árbol (physics real).
extends GdUnitTestSuite

const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Mundo Doc: Flujo + Personal real con N puestos doc_i DOTADOS + bus espía. [flujo, personal, bus]
func _mundo_doc(n_puestos: int = 1) -> Array:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	var bus: Node = auto_free(EventBusScript.new())
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.usar_personal(personal)
	flujo.usar_bus(bus)
	for i: int in range(n_puestos):
		var id: StringName = StringName("doc_%d" % (i + 1))
		personal.registrar_puesto(id, &"puesto_doc_general")
		flujo.registrar_puesto_flujo(id, &"puesto_doc_general")
		_asignar_agente(personal, id, &"ag_doc", "Agente %d" % (i + 1))
	return [flujo, personal, bus]


func _asignar_agente(
	personal: Node, puesto: StringName, tipo: StringName = &"ag_doc", nombre: String = "Ana Ruiz"
) -> RefCounted:
	var agente: RefCounted = AgenteScript.new(nombre, tipo, AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)
	personal.plantilla.append(agente)
	personal.asignar(agente, puesto)
	return agente


func _dni_admitido(flujo: Node) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 511.0))
	flujo.encolar(persona)
	return persona


func _odac_admitido(flujo: Node, tramite: StringName) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(&"ODAC", tramite, 511.0))
	flujo.encolar(persona)
	return persona


func _espia_completados(bus: Node) -> Array:
	var emisiones: Array = []
	bus.tramite_completado.connect(
		func(tramite_id: StringName, _agente: RefCounted) -> void: emisiones.append(tramite_id)
	)
	return emisiones


# ── AC-FL17: cerrar en caliente → TERMINA la atención, LUEGO Cerrado, y no llama a nadie ──
func test_cerrar_en_caliente_termina_luego_cierra() -> void:
	# Arrange — p1 en atención (dni 12 min), p2 esperando.
	var mundo: Array = _mundo_doc()
	var flujo: Node = mundo[0]
	var emisiones: Array = _espia_completados(mundo[2])
	var p1: RefCounted = _dni_admitido(flujo)
	var p2: RefCounted = _dni_admitido(flujo)
	flujo._al_tick(1.0)
	assert_str(String(p1.estado)).is_equal("en_atencion")

	# Act — cerrar con la atención EN CURSO: no se interrumpe (compromiso de servicio).
	flujo.cerrar_puesto(&"doc_1")
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("atendiendo")

	# La atención completa sus 12 min → emite y ENTONCES cierra; p2 no es llamada jamás.
	for i: int in range(12):
		flujo._al_tick(1.0)
	assert_int(emisiones.size()).is_equal(1)
	assert_str(String(p1.estado)).is_equal("resuelta")
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("cerrado")
	for i: int in range(3):
		flujo._al_tick(1.0)
	assert_str(String(p2.estado)).is_equal("esperando_dentro")

	# Reabrir cancela el cierre y vuelve a llamar.
	flujo.abrir_puesto(&"doc_1")
	flujo._al_tick(1.0)
	assert_str(String(p2.estado)).is_equal("en_atencion")


# ── AC-FL16: reconfigurar NO interrumpe y la PRÓXIMA llamada usa el filtro nuevo ──────────
func test_reconfigurar_no_interrumpe_y_filtra() -> void:
	# Arrange — puesto ODAC real (reconfigurable) atendiendo viogen (60 min); cola con
	# [estafa (Normal), viogen (Prioritaria)] detrás.
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.registrar_puesto(&"odac_1", &"puesto_odac")
	var bus: Node = auto_free(EventBusScript.new())
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.usar_personal(personal)
	flujo.usar_bus(bus)
	flujo.registrar_puesto_flujo(&"odac_1", &"puesto_odac")
	_asignar_agente(personal, &"odac_1", &"ag_odac")
	var p_viogen1: RefCounted = _odac_admitido(flujo, &"viogen")
	var p_estafa: RefCounted = _odac_admitido(flujo, &"estafa")
	var p_viogen2: RefCounted = _odac_admitido(flujo, &"viogen")
	flujo._al_tick(1.0)
	assert_str(String(p_viogen1.estado)).is_equal("en_atencion")

	# Act — reconfigurar a solo estafa: la atención de viogen NO se corta.
	var solo_estafa: Array[StringName] = [&"estafa"]
	assert_bool(flujo.reconfigurar_puesto(&"odac_1", solo_estafa)).is_true()
	assert_str(String(p_viogen1.estado)).is_equal("en_atencion")

	# La viogen acaba (60 min) y la PRÓXIMA llamada salta a la estafa — la 2.ª viogen
	# (Prioritaria, turno menor) ya no es compatible con el puesto.
	for i: int in range(60):
		flujo._al_tick(1.0)
	assert_str(String(p_viogen1.estado)).is_equal("resuelta")
	assert_str(String(p_estafa.estado)).is_equal("en_atencion")
	assert_str(String(p_viogen2.estado)).is_equal("esperando_dentro")


# ── FL9 robustez: no reconfigurable / ids inválidos / limpiar override ────────────────────
func test_reconfigurar_rechazos_y_limpieza() -> void:
	# Arrange — doc_1 (puesto_doc_general NO es reconfigurable) y odac_1 (sí).
	var mundo: Array = _mundo_doc()
	var flujo: Node = mundo[0]
	flujo.registrar_puesto_flujo(&"odac_1", &"puesto_odac")

	# Act / Assert — tipo no reconfigurable → false (aviso esperado).
	var solo_dni: Array[StringName] = [&"dni"]
	assert_bool(flujo.reconfigurar_puesto(&"doc_1", solo_dni)).is_false()
	# Ids fuera del catálogo del tipo se DESCARTAN (aviso) y quedan solo los válidos.
	var mezcla: Array[StringName] = [&"estafa", &"dni"]
	assert_bool(flujo.reconfigurar_puesto(&"odac_1", mezcla)).is_true()
	assert_bool(flujo._puestos_flujo[&"odac_1"]["override"] == [&"estafa"]).is_true()
	# Sin NINGUNA válida → false y el override anterior no cambia.
	assert_bool(flujo.reconfigurar_puesto(&"odac_1", solo_dni)).is_false()
	assert_bool(flujo._puestos_flujo[&"odac_1"]["override"] == [&"estafa"]).is_true()
	# Lista vacía LIMPIA el override (vuelve al catálogo completo).
	var vacia: Array[StringName] = []
	assert_bool(flujo.reconfigurar_puesto(&"odac_1", vacia)).is_true()
	assert_bool((flujo._puestos_flujo[&"odac_1"]["override"] as Array).is_empty()).is_true()


# ── AC-FL18: el abandono respeta el COMPROMISO (Llamada/atención NO abandonan) ────────────
func test_abandono_compromiso_de_servicio() -> void:
	# Arrange — aforo REAL 3 (Construcción: 1 asiento + 2 de pie); 4 personas (p4 fuera).
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_personal(personal)
	construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(0, 0, 2, 2))
	construccion.construir_de_oficio_elemento(construccion.ASIENTO_BASICO, Vector2i(0, 0))
	construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(4, 0, 4, 4))
	construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(5, 1), &"doc_1")
	var bus: Node = auto_free(EventBusScript.new())
	var abandonos: Array = []
	bus.abandono.connect(func(persona: RefCounted) -> void: abandonos.append(persona))
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.usar_personal(personal)
	flujo.usar_construccion(construccion)
	flujo.usar_bus(bus)
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")
	var personas: Array = []
	for i: int in range(4):
		personas.append(_dni_admitido(flujo))
	assert_str(String(personas[3].estado)).is_equal("esperando_fuera")

	# Act / Assert — abandona una de DENTRO: true + señal + la de fuera ocupa su plaza.
	assert_bool(flujo.forzar_abandono(personas[1])).is_true()
	assert_str(String(personas[1].estado)).is_equal("abandonando")
	assert_int(abandonos.size()).is_equal(1)
	assert_str(String(personas[3].estado)).is_equal("esperando_dentro")

	# En LLAMADA (emparejada sin arrancar aún) → compromiso: false, 0 señales nuevas.
	_asignar_agente(personal, &"doc_1")
	flujo._emparejar()
	assert_str(String(personas[0].estado)).is_equal("llamada")
	assert_bool(flujo.forzar_abandono(personas[0])).is_false()
	# En ATENCIÓN → igual: false y la atención sigue.
	flujo._arrancar_llamadas()
	assert_str(String(personas[0].estado)).is_equal("en_atencion")
	assert_bool(flujo.forzar_abandono(personas[0])).is_false()
	assert_int(abandonos.size()).is_equal(1)


# ── AC-FL24: puerta Doc cerrada a NUEVAS; la cola admitida se vacía con peonada al hook ───
func test_cierre_doc_puerta_y_peonada() -> void:
	# Arrange — reloj manual a las 14:20 (860); 3 dni admitidas; Economía real via hook.
	var mundo: Array = _mundo_doc()
	var flujo: Node = mundo[0]
	var emisiones: Array = _espia_completados(mundo[2])
	var tiempo: Node = auto_free(TiempoScript.new())   # SIN árbol: no empuja, solo da la hora
	tiempo.minutos_juego = 860.0
	flujo.usar_tiempo(tiempo)
	var eco: Node = auto_free(EconomiaScript.new())
	eco.aplicar_config(ConfigEconomiaScript.new())
	flujo.fijar_hook_horas_extra(eco.registrar_horas_extra)
	for i: int in range(3):
		assert_object(_dni_admitido(flujo)).is_not_null()

	# Act — el reloj cruza el cierre (871 ≥ 870): puerta cerrada a nuevas Doc; ODAC sigue 24 h.
	tiempo.minutos_juego = 871.0
	assert_object(flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 871.0))).is_null()
	assert_object(flujo.admitir(PersonaScript.new(&"ODAC", &"estafa", 871.0))).is_not_null()

	# La cola ADMITIDA se atiende hasta vaciarse (1 puesto, 3 × 12 min): 1 arranque + 36.
	for i: int in range(37):
		flujo._al_tick(1.0)

	# Assert — 3 atendidas, cola Doc vacía y 36 min = 0.6 h de peonada registradas en Economía.
	assert_int(emisiones.size()).is_equal(3)
	assert_int(flujo.personas_en_cola(&"Documentacion")).is_equal(0)
	assert_float(eco._horas_extra_dia).is_equal_approx(0.6, 0.0001)


# ── AC-CO13: demoler un puesto ATENDIENDO espera al trámite; luego demuele + reembolsa ────
func test_demolicion_pendiente_espera_al_tramite() -> void:
	# Arrange — mundo completo: puesto PAGADO (500 €), dotado y atendiendo un dni.
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	var eco: Node = auto_free(EconomiaScript.new())
	eco.aplicar_config(ConfigEconomiaScript.new())
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(eco)
	construccion.usar_personal(personal)
	construccion._crear_sala(&"sala_documentacion", Rect2i(0, 0, 4, 4))
	# Sala de espera: con Construcción inyectada en Flujo el aforo MANDA (F6) — sin ella la
	# persona se quedaría fuera y el puesto jamás estaría "atendiendo".
	construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(0, 5, 2, 2))
	var id_puesto: StringName = construccion.construir_elemento(&"puesto_doc_general", Vector2i(1, 1))
	assert_float(eco.saldo_eur).is_equal_approx(2500.0, 0.0001)
	var bus: Node = auto_free(EventBusScript.new())
	var emisiones: Array = _espia_completados(bus)
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.usar_personal(personal)
	flujo.usar_bus(bus)
	flujo.usar_construccion(construccion)
	flujo.registrar_puesto_flujo(id_puesto, &"puesto_doc_general")
	construccion.fijar_puede_demoler(flujo.puede_demoler_puesto)
	var agente: RefCounted = _asignar_agente(personal, id_puesto)
	_dni_admitido(flujo)
	flujo._al_tick(1.0)
	assert_str(String(flujo.estado_de_puesto(id_puesto))).is_equal("atendiendo")

	# Act — demoler EN CALIENTE: el gate lo frena → pendiente, sin reembolso, sigue atendiendo.
	assert_bool(construccion.demoler_elemento(id_puesto)).is_false()
	assert_bool(construccion._elementos.has(id_puesto)).is_true()
	assert_str(String(flujo.estado_de_puesto(id_puesto))).is_equal("atendiendo")
	assert_float(eco.saldo_eur).is_equal_approx(2500.0, 0.0001)

	# La atención completa sus 12 min → EN ese tick el trámite emite y la demolición cae.
	for i: int in range(12):
		flujo._al_tick(1.0)
	assert_int(emisiones.size()).is_equal(1)
	assert_bool(construccion._elementos.has(id_puesto)).is_false()
	assert_bool(flujo._puestos_flujo.has(id_puesto)).is_false()
	assert_float(eco.saldo_eur).is_equal_approx(2750.0, 0.0001)   # 2500 + 250 de reembolso F4
	assert_str(String(agente.puesto_id)).is_equal("")             # el agente, al banquillo


# ── Contrato 003→006: quitar_puesto_flujo con atención en curso espera al trámite ─────────
func test_quitar_puesto_en_caliente_espera() -> void:
	# Arrange
	var mundo: Array = _mundo_doc()
	var flujo: Node = mundo[0]
	var emisiones: Array = _espia_completados(mundo[2])
	_dni_admitido(flujo)
	var p2: RefCounted = _dni_admitido(flujo)
	flujo._al_tick(1.0)

	# Act / Assert — retirada pendiente: el puesto sigue hasta terminar; después desaparece.
	assert_bool(flujo.quitar_puesto_flujo(&"doc_1")).is_false()
	assert_str(String(flujo.estado_de_puesto(&"doc_1"))).is_equal("atendiendo")
	for i: int in range(12):
		flujo._al_tick(1.0)
	assert_int(emisiones.size()).is_equal(1)
	assert_bool(flujo._puestos_flujo.has(&"doc_1")).is_false()
	assert_str(String(p2.estado)).is_equal("esperando_dentro")   # sin puesto, nadie la llama


# ── AC-FL15/AC-FL25: la Pausa congela EXACTO (ni avanza ni asigna) y reanudar continúa ────
func test_pausa_congela_y_reanuda_exacto() -> void:
	# Arrange — mundo REAL en árbol con 2 puestos dotados; p1 a mitad (quedan 5.0 de 12).
	var mundo: Array = _mundo_doc(2)
	var flujo: Node = mundo[0]
	var emisiones: Array = _espia_completados(mundo[2])
	var tiempo: Node = auto_free(TiempoScript.new())
	flujo.usar_tiempo(tiempo)
	add_child(tiempo)
	add_child(flujo)
	_dni_admitido(flujo)
	flujo._al_tick(1.0)
	flujo._al_tick(7.0)
	assert_float(float(flujo._puestos_flujo[&"doc_1"]["restante"])).is_equal_approx(5.0, 0.0001)
	tiempo.fijar_velocidad(TiempoScript.Velocidad.PAUSA)
	# p2 llega DURANTE la pausa con doc_2 libre y dotado: sin tick, nadie la llama (FL8).
	var p2: RefCounted = _dni_admitido(flujo)

	# Act — 30 frames de physics REALES en Pausa.
	for i: int in range(30):
		await get_tree().physics_frame

	# Assert — 5.0 EXACTOS (sin pérdida), p2 sigue esperando, 0 emisiones.
	assert_float(float(flujo._puestos_flujo[&"doc_1"]["restante"])).is_equal_approx(5.0, 0.0001)
	assert_str(String(p2.estado)).is_equal("esperando_dentro")
	assert_int(emisiones.size()).is_equal(0)

	# Act 2 — reanudar a 1×: la atención CONTINÚA desde 5.0 (sin reinicio) y doc_2 llama a p2.
	tiempo.fijar_velocidad(TiempoScript.Velocidad.X1)
	for i: int in range(3):
		await get_tree().physics_frame
	assert_float(float(flujo._puestos_flujo[&"doc_1"]["restante"])).is_between(4.0, 4.9999)
	assert_str(String(p2.estado)).is_equal("en_atencion")
	tiempo.fijar_velocidad(TiempoScript.Velocidad.PAUSA)
