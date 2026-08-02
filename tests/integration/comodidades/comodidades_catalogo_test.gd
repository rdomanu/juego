# Story comodidades-001 y 002 — los objetos que se compran y se colocan, y lo que hacen.
# Tipo: Integration. DETERMINISTA: catálogo REAL, sin reloj ni RNG.
#
# Las dos familias y sus dos efectos:
#   · ciudadano  (sala de espera) → CONFORT     → Paciencia F1: la gente aguanta más.
#   · funcionario (sala con puestos) → RENDIMIENTO → Flujo F1: se atiende más rápido.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const PacienciaScript := preload("res://src/feature/paciencia/paciencia.gd")
const ConfigPacienciaScript := preload("res://src/feature/paciencia/config_paciencia.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

const DOC := &"Documentacion"


# ── Fixture ──────────────────────────────────────────────────────────────────────────────
## Comisaría mínima: una sala de espera de Doc (1,6)-(6,9) y una oficina de Doc (1,1)-(6,4), con
## caja de sobra. Devuelve [construccion, economia, bus].
func _mundo() -> Array:
	var bus: Node = auto_free(EventBusScript.new())
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	economia.saldo_eur = 100000.0
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(economia)
	construccion.usar_bus(bus)
	construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(1, 1, 6, 4))
	construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(1, 6, 6, 4))
	return [construccion, economia, bus]


func _sala_espera(construccion: Node) -> StringName:
	return construccion.sala_en(Vector2i(2, 7))


func _sala_oficina(construccion: Node) -> StringName:
	return construccion.sala_en(Vector2i(2, 2))


# ── AC-CM01 · El catálogo trae los 8 objetos de Comodidades #15 con sus números ──────────
# Cuenta las DOS familias de este epic, no el total del catálogo: Bienestar #13 (bien-005) añadió
# después una tercera familia ("descanso": sillas, sofá, nevera…). Contar el total hacía que este
# test se rompiera cada vez que OTRO epic añade objetos, que no es lo que quiere vigilar.
func test_el_catalogo_trae_los_ocho_objetos() -> void:
	var todos: Array = Datos.obtener_todos(&"Comodidad")
	var de_este_epic: Array = todos.filter(func(c: Resource) -> bool:
		return c.familia == "ciudadano" or c.familia == "funcionario"
	)
	assert_int(de_este_epic.size()).is_equal(8)

	var tele: Resource = Datos.obtener(&"Comodidad", &"television")
	assert_str(tele.familia).is_equal("ciudadano")
	assert_int(tele.coste_construccion_eur).is_equal(900)
	assert_int(tele.coste_mantenimiento_dia_eur).is_equal(4)
	assert_float(tele.aporte).is_equal(6.0)

	# La papelera no consume: se paga una vez y ya (frente a los aparatos, que sangran cada día).
	assert_int(Datos.obtener(&"Comodidad", &"papelera").coste_mantenimiento_dia_eur).is_equal(0)
	# El equipamiento es de la otra familia.
	assert_str(Datos.obtener(&"Comodidad", &"impresora_dni").familia).is_equal("funcionario")


func test_un_objeto_inexistente_no_rompe_ni_ensucia_la_consola() -> void:
	assert_object(Datos.obtener_silencioso(&"Comodidad", &"jacuzzi")).is_null()


# ── AC-CM02 · Colocar cobra y sube el confort ────────────────────────────────────────────
func test_poner_una_tele_cobra_900_y_sube_el_confort() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var economia: Node = mundo[1]
	var saldo_antes: float = economia.saldo_eur
	var sala: StringName = _sala_espera(construccion)
	assert_float(construccion.confort_de_sala(sala)).is_equal(0.0)

	var id: StringName = construccion.construir_elemento(&"television", Vector2i(2, 7))

	assert_str(String(id)).is_not_equal("")
	assert_float(economia.saldo_eur).is_equal_approx(saldo_antes - 900.0, 0.001)
	assert_float(construccion.confort_de_sala(sala)).is_equal(6.0)


func test_el_confort_de_varios_objetos_se_suma() -> void:
	var construccion: Node = _mundo()[0]
	construccion.construir_elemento(&"television", Vector2i(2, 7))     # 6
	construccion.construir_elemento(&"vending", Vector2i(3, 7))        # 5
	construccion.construir_elemento(&"papelera", Vector2i(4, 7))       # 1
	assert_float(construccion.confort_de_sala(_sala_espera(construccion))).is_equal(12.0)


# ── AC-CM03 · Cada familia va en su sitio ────────────────────────────────────────────────
func test_una_tele_no_va_en_la_oficina_ni_un_ordenador_en_la_sala_de_espera() -> void:
	var construccion: Node = _mundo()[0]
	# Familia "ciudadano" en una sala que no es de espera → rechazada.
	assert_bool(construccion.validar_elemento(&"television", Vector2i(2, 2))).is_false()
	# Familia "funcionario" en la sala de espera → rechazada.
	assert_bool(construccion.validar_elemento(&"equipo_informatico", Vector2i(2, 7))).is_false()
	# Y en su sitio, las dos valen.
	assert_bool(construccion.validar_elemento(&"television", Vector2i(2, 7))).is_true()
	assert_bool(construccion.validar_elemento(&"equipo_informatico", Vector2i(2, 2))).is_true()


# ── AC-CM04 · El mantenimiento se le registra a Economía en el cierre del día ────────────
func test_el_mantenimiento_diario_llega_a_economia_antes_de_pasar_la_factura() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var economia: Node = mundo[1]
	construccion.construir_elemento(&"radio", Vector2i(2, 7))          # 1 €/día
	construccion.construir_elemento(&"television", Vector2i(3, 7))     # 4 €/día
	construccion.construir_elemento(&"papelera", Vector2i(4, 7))       # 0 €/día
	assert_float(construccion.mantenimiento_dia()).is_equal(5.0)

	construccion._al_nuevo_dia()
	assert_float(economia._mantenimiento_dia).is_equal(5.0)


func test_sin_objetos_no_se_le_registra_nada_a_economia() -> void:
	var mundo: Array = _mundo()
	mundo[0]._al_nuevo_dia()
	assert_float(mundo[1]._mantenimiento_dia).is_equal(0.0)


func test_el_mantenimiento_se_cobra_en_prioridad_16_antes_que_economia() -> void:
	# ⚠️ Contador en Array: las lambdas capturan por valor.
	var mundo: Array = _mundo()
	var bus: Node = mundo[2]
	mundo[0].construir_elemento(&"television", Vector2i(2, 7))
	var orden: Array = []
	bus.registrar_ordenado(&"nuevo_dia", 15, func() -> void: orden.append("doc"))
	bus.registrar_ordenado(&"nuevo_dia", 20, func() -> void: orden.append("economia"))

	bus.disparar_ordenado(&"nuevo_dia")

	assert_array(orden).contains_exactly(["doc", "economia"])
	assert_float(mundo[1]._mantenimiento_dia).is_equal(4.0)   # se registró entre ambos


# ── AC-CM05 · Demoler quita confort y quita gasto ────────────────────────────────────────
func test_demoler_la_tele_baja_el_confort_y_el_mantenimiento() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var id: StringName = construccion.construir_elemento(&"television", Vector2i(2, 7))
	assert_float(construccion.confort_de_sala(_sala_espera(construccion))).is_equal(6.0)

	construccion.demoler_elemento(id)

	assert_float(construccion.confort_de_sala(_sala_espera(construccion))).is_equal(0.0)
	assert_float(construccion.mantenimiento_dia()).is_equal(0.0)


# ── AC-CM06 · El confort del servicio es la MEDIA de sus salas de espera ────────────────
func test_el_confort_del_servicio_es_la_media_de_sus_salas() -> void:
	var construccion: Node = _mundo()[0]
	construccion.construir_elemento(&"television", Vector2i(2, 7))     # confort 6 en la 1ª sala
	assert_float(construccion.confort_de_servicio(DOC)).is_equal(6.0)

	# Una segunda sala de espera SIN nada: la media baja (dos salas a medias no valen una buena).
	construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(9, 6, 3, 3))
	assert_float(construccion.confort_de_servicio(DOC)).is_equal(3.0)


func test_sin_salas_de_espera_el_confort_del_servicio_es_cero() -> void:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	assert_float(construccion.confort_de_servicio(DOC)).is_equal(0.0)


# ══ Story 002 · El EFECTO ═════════════════════════════════════════════════════════════════

# ── AC-CM07 / AC-CM08 · La gente aguanta más ────────────────────────────────────────────
func test_una_tele_hace_que_aguanten_treinta_y_cuatro_minutos() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	construccion.construir_elemento(&"television", Vector2i(2, 7))     # confort 6
	var paciencia: Node = auto_free(PacienciaScript.new())
	paciencia.aplicar_config(ConfigPacienciaScript.new())
	paciencia.usar_construccion(construccion)

	# 1 − 0.02 × 6 = 0.88 → 30 / 0.88 = 34,1 min de aguante (antes 30 clavados).
	var mult: float = paciencia.mult_comodidad_de(DOC)
	assert_float(mult).is_equal_approx(0.88, 0.0001)
	assert_float(paciencia.minutos_hasta_agotar(1.0, mult)).is_equal_approx(34.09, 0.01)


func test_la_sala_perfecta_toca_el_suelo_y_no_baja_mas() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	# Todo el catálogo de ciudadano: 6+5+3+3+2+1 = 20 → 1 − 0.4 = 0.6 (el suelo exacto).
	construccion.construir_elemento(&"television", Vector2i(2, 7))
	construccion.construir_elemento(&"vending", Vector2i(3, 7))
	construccion.construir_elemento(&"radio", Vector2i(4, 7))
	construccion.construir_elemento(&"fuente_agua", Vector2i(5, 7))
	construccion.construir_elemento(&"revistero", Vector2i(2, 8))
	construccion.construir_elemento(&"papelera", Vector2i(3, 8))
	var paciencia: Node = auto_free(PacienciaScript.new())
	paciencia.aplicar_config(ConfigPacienciaScript.new())
	paciencia.usar_construccion(construccion)

	assert_float(construccion.confort_de_sala(_sala_espera(construccion))).is_equal(20.0)
	assert_float(paciencia.mult_comodidad_de(DOC)).is_equal_approx(0.6, 0.0001)
	# 30 / 0.6 = 50 min: el tope de lo que se puede comprar con dinero.
	assert_float(
		paciencia.minutos_hasta_agotar(1.0, paciencia.mult_comodidad_de(DOC))
	).is_equal_approx(50.0, 0.01)


# ── AC-CM09 / AC-CM12 · Sin comodidades, todo sigue exactamente igual ───────────────────
func test_sin_comodidades_la_gente_aguanta_los_treinta_de_siempre() -> void:
	var mundo: Array = _mundo()
	var paciencia: Node = auto_free(PacienciaScript.new())
	paciencia.aplicar_config(ConfigPacienciaScript.new())
	paciencia.usar_construccion(mundo[0])
	assert_float(paciencia.mult_comodidad_de(DOC)).is_equal(1.0)
	assert_float(paciencia.minutos_hasta_agotar()).is_equal_approx(30.0, 0.01)


func test_sin_construccion_inyectada_paciencia_usa_su_knob_de_siempre() -> void:
	var paciencia: Node = auto_free(PacienciaScript.new())
	paciencia.aplicar_config(ConfigPacienciaScript.new())
	assert_float(paciencia.mult_comodidad_de(DOC)).is_equal(1.0)


# ── AC-CM10 / AC-CM11 · Se atiende más rápido ───────────────────────────────────────────
func test_el_equipamiento_acelera_la_atencion_hasta_un_veinte_por_ciento() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	construccion.usar_personal(personal)
	# El mostrador ocupa (2,2) y (3,2): mide 2 celdas desde el 2026-08-02.
	var puesto: StringName = construccion.construir_elemento(&"puesto_doc_general", Vector2i(2, 2))
	# Equipo (4) + impresora (6) = 10 → 1 − 0.02 × 10 = 0.8 (el suelo). Van DETRÁS del mostrador, en
	# las primeras celdas libres de la fila (antes iban en (3,2), que ahora es su segunda celda).
	construccion.construir_elemento(&"equipo_informatico", Vector2i(4, 2))
	construccion.construir_elemento(&"impresora_dni", Vector2i(5, 2))

	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.usar_construccion(construccion)
	flujo.usar_personal(personal)
	flujo.registrar_puesto_flujo(puesto, &"puesto_doc_general")
	var agente: RefCounted = AgenteScript.new("Ana", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)
	personal.plantilla.append(agente)
	personal.asignar(agente, puesto)

	assert_float(flujo.mult_equipamiento(puesto)).is_equal_approx(0.8, 0.0001)
	# dni = 12 min × 1.0 (agente estándar) × 0.8 = 9,6.
	assert_float(flujo.duracion_efectiva(DOC, &"dni", puesto)).is_equal_approx(9.6, 0.001)


func test_el_equipamiento_se_multiplica_sobre_el_agente_no_lo_sustituye() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	construccion.usar_personal(personal)
	# El mostrador ocupa (2,2) y (3,2) desde el 2026-08-02: el equipo va en la siguiente celda libre.
	var puesto: StringName = construccion.construir_elemento(&"puesto_doc_general", Vector2i(2, 2))
	construccion.construir_elemento(&"equipo_informatico", Vector2i(4, 2))   # rendimiento 4 → 0.92

	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.usar_construccion(construccion)
	flujo.usar_personal(personal)
	flujo.registrar_puesto_flujo(puesto, &"puesto_doc_general")
	# Agente RÁPIDO (rapidez 5): su modificador es < 1 y el equipo lo mejora AÚN MÁS.
	var agente: RefCounted = AgenteScript.new("Rápida", &"ag_doc", AgenteScript.RANGO_POLICIA, 5, 3, 3, 3)
	personal.plantilla.append(agente)
	personal.asignar(agente, puesto)

	var mod_agente: float = personal.modificador_produccion(agente)
	assert_bool(mod_agente < 1.0).is_true()
	assert_float(flujo.duracion_efectiva(DOC, &"dni", puesto)).is_equal_approx(
		12.0 * mod_agente * 0.92, 0.001
	)


func test_sin_construccion_inyectada_flujo_atiende_como_siempre() -> void:
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	assert_float(flujo.mult_equipamiento(&"doc_1")).is_equal(1.0)
