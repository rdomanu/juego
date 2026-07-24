# Story 005 (epic personal) — el Oficial: cobertura F6 y canalización F7 al `nuevo_dia` ·
# TR-staff-003 · ADR-0001. Tipo: Integration. DETERMINISTA: knobs SELECTIVOS boundary
# (base_ausencia 1.0 + k_salud 0.5 → Salud 1 cae SEGURO, Salud 5 no cae NUNCA — F4 clampada a 1/0;
# boundary values intencionales) y cobertura sin azar (por reglas). RNGService re-sembrado por test.
extends GdUnitTestSuite

const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

## Con los knobs de la fixture: prob_ausencia(Salud 1) = 1.0 (cae seguro) · prob(Salud 5) = 0.0.
const SALUD_CAE := 1
const SALUD_FIRME := 5


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Personal aislado con knobs selectivos y 4 puestos Doc + 1 ODAC (doc_1 será del Oficial).
func _personal() -> Node:
	var config: Resource = ConfigPersonalScript.new()
	config.base_ausencia = 1.0
	config.k_salud = 0.5
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(config)
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	personal.registrar_puesto(&"doc_2", &"puesto_doc_general")
	personal.registrar_puesto(&"doc_3", &"puesto_doc_general")
	personal.registrar_puesto(&"doc_4", &"puesto_doc_general")
	personal.registrar_puesto(&"odac_1", &"puesto_odac")
	return personal


## Un policía EN PLANTILLA (Salud elige su destino: SALUD_CAE cae hoy seguro, SALUD_FIRME nunca).
func _contratado(personal: Node, nombre: String, salud: int, tipo: StringName = &"ag_doc") -> RefCounted:
	var agente: RefCounted = AgenteScript.new(nombre, tipo, AgenteScript.RANGO_POLICIA, 3, 3, salud, 3)
	personal.plantilla.append(agente)
	return agente


## Un Oficial EN PLANTILLA y ASIGNADO a un puesto (por defecto firme: no cae).
func _oficial_en(personal: Node, puesto: StringName, mando: int, salud: int = SALUD_FIRME) -> RefCounted:
	var oficial: RefCounted = AgenteScript.new(
		"Óscar Delgado", &"ag_doc", AgenteScript.RANGO_OFICIAL, 3, 3, salud, 3, mando
	)
	personal.plantilla.append(oficial)
	personal.asignar(oficial, puesto)
	return oficial


## Bus espía enchufado a Personal. Devuelve [partes, individuales] (Arrays que se van llenando).
func _espia(personal: Node) -> Array:
	var bus: Node = auto_free(EventBusScript.new())
	personal.usar_bus(bus)
	var partes: Array = []
	var individuales: Array = []
	bus.parte_personal.connect(func(resumen: Dictionary) -> void: partes.append(resumen))
	bus.incidencia_personal.connect(
		func(texto: String, puesto: StringName) -> void: individuales.append([texto, puesto])
	)
	return [partes, individuales]


# ── AC-PE14: Mando 4 → cubre 2 bajas con libres compatibles (F6 = tabla del GDD) ──────────
func test_mando_4_cubre_dos_bajas() -> void:
	# Arrange — Oficial Mando 4 + 2 titulares que caen + 2 libres firmes.
	RNGService.sembrar(42)
	var personal: Node = _personal()
	var oficial: RefCounted = _oficial_en(personal, &"doc_1", 4)
	var titular_a: RefCounted = _contratado(personal, "Ana Ruiz", SALUD_CAE)
	var titular_b: RefCounted = _contratado(personal, "Carlos Vega", SALUD_CAE)
	personal.asignar(titular_a, &"doc_2")
	personal.asignar(titular_b, &"doc_3")
	var libre_1: RefCounted = _contratado(personal, "Lucía Ortega", SALUD_FIRME)
	var libre_2: RefCounted = _contratado(personal, "Javier Molina", SALUD_FIRME)

	# Act
	personal._al_nuevo_dia()

	# Assert — presupuesto ceil(4/2)=2: ambos puestos cubiertos en orden estable (doc_2←L1, doc_3←L2).
	assert_bool(personal.puesto_dotado(&"doc_2")).is_true()
	assert_bool(personal.puesto_dotado(&"doc_3")).is_true()
	assert_object(personal.agente_de(&"doc_2")).is_same(libre_1)
	assert_object(personal.agente_de(&"doc_3")).is_same(libre_2)
	assert_str(String(libre_1.estado)).is_equal("cubriendo")
	assert_str(String(libre_2.estado)).is_equal("cubriendo")
	# El cubridor cubre DE PRESTADO (sin titularidad); el ausente la conserva.
	assert_str(String(libre_1.puesto_id)).is_equal("")
	assert_str(String(titular_a.puesto_id)).is_equal("doc_2")
	assert_str(String(oficial.estado)).is_equal("asignado")


# ── AC-PE14 (parte 2): Mando 1 → cubre solo 1 (la tabla F6: 1-2 → 1); la otra baja queda ──
func test_mando_1_cubre_solo_una() -> void:
	# Arrange — mismo escenario con Mando 1.
	RNGService.sembrar(42)
	var personal: Node = _personal()
	_oficial_en(personal, &"doc_1", 1)
	var titular_a: RefCounted = _contratado(personal, "Ana Ruiz", SALUD_CAE)
	var titular_b: RefCounted = _contratado(personal, "Carlos Vega", SALUD_CAE)
	personal.asignar(titular_a, &"doc_2")
	personal.asignar(titular_b, &"doc_3")
	var libre_1: RefCounted = _contratado(personal, "Lucía Ortega", SALUD_FIRME)
	var libre_2: RefCounted = _contratado(personal, "Javier Molina", SALUD_FIRME)

	# Act
	personal._al_nuevo_dia()

	# Assert — presupuesto agotado tras doc_2: doc_3 queda vacante y el 2.º libre sin tocar.
	assert_bool(personal.puesto_dotado(&"doc_2")).is_true()
	assert_object(personal.agente_de(&"doc_2")).is_same(libre_1)
	assert_bool(personal.puesto_dotado(&"doc_3")).is_false()
	assert_str(String(libre_2.estado)).is_equal("libre")


# ── AC-PE15: sin Oficial no hay cobertura automática — los puestos quedan vacantes ────────
func test_sin_oficial_no_cubre() -> void:
	# Arrange — 2 titulares que caen y 2 libres disponibles, pero NADIE al mando.
	RNGService.sembrar(8)
	var personal: Node = _personal()
	var titular_a: RefCounted = _contratado(personal, "Ana Ruiz", SALUD_CAE)
	var titular_b: RefCounted = _contratado(personal, "Carlos Vega", SALUD_CAE)
	personal.asignar(titular_a, &"doc_2")
	personal.asignar(titular_b, &"doc_3")
	var libre_1: RefCounted = _contratado(personal, "Lucía Ortega", SALUD_FIRME)

	# Act
	personal._al_nuevo_dia()

	# Assert — cobertura manual o nada (PA8): vacantes y el libre sigue en el banquillo.
	assert_bool(personal.puesto_dotado(&"doc_2")).is_false()
	assert_bool(personal.puesto_dotado(&"doc_3")).is_false()
	assert_str(String(libre_1.estado)).is_equal("libre")


# ── AC-PE16: con Oficial las N incidencias del servicio se agrupan en UN parte; sin él, N ─
func test_parte_agrupado_con_oficial_individuales_sin() -> void:
	# Arrange (a) — Oficial Mando 5 y 3 bajas SIN libres para cubrir.
	RNGService.sembrar(21)
	var con_oficial: Node = _personal()
	_oficial_en(con_oficial, &"doc_1", 5)
	for i: int in range(3):
		var titular: RefCounted = _contratado(con_oficial, "Titular %d" % i, SALUD_CAE)
		con_oficial.asignar(titular, [&"doc_2", &"doc_3", &"doc_4"][i])
	var avisos_a: Array = _espia(con_oficial)

	# Act (a)
	con_oficial._al_nuevo_dia()

	# Assert (a) — exactamente 1 parte del día con las 3 ausencias; CERO avisos individuales.
	var partes: Array = avisos_a[0]
	assert_int(partes.size()).is_equal(1)
	assert_int(avisos_a[1].size()).is_equal(0)
	var resumen: Dictionary = partes[0]
	assert_str(String(resumen["servicio"])).is_equal(con_oficial.servicio_de_puesto(&"doc_2"))
	assert_int(int(resumen["ausencias"])).is_equal(3)

	# Arrange (b) — el MISMO escenario sin Oficial.
	var sin_oficial: Node = _personal()
	for i: int in range(3):
		var titular: RefCounted = _contratado(sin_oficial, "Titular %d" % i, SALUD_CAE)
		sin_oficial.asignar(titular, [&"doc_2", &"doc_3", &"doc_4"][i])
	var avisos_b: Array = _espia(sin_oficial)

	# Act (b)
	sin_oficial._al_nuevo_dia()

	# Assert (b) — 3 avisos individuales, ningún parte (PA9: carga de microgestión).
	assert_int(avisos_b[0].size()).is_equal(0)
	assert_int(avisos_b[1].size()).is_equal(3)


# ── AC-PE17: Oficial sin nadie que reasignar → escala al jugador (no cubre, no inventa) ───
func test_oficial_sin_libres_escala() -> void:
	# Arrange — Mando 5 (presupuesto de sobra) pero banquillo vacío.
	RNGService.sembrar(3)
	var personal: Node = _personal()
	_oficial_en(personal, &"doc_1", 5)
	var titular: RefCounted = _contratado(personal, "Ana Ruiz", SALUD_CAE)
	personal.asignar(titular, &"doc_2")
	var avisos: Array = _espia(personal)

	# Act
	personal._al_nuevo_dia()

	# Assert — 0 coberturas y el parte marca la baja como escalada (requiere decisión).
	assert_bool(personal.puesto_dotado(&"doc_2")).is_false()
	var resumen: Dictionary = avisos[0][0]
	assert_int(int(resumen["cubiertas"])).is_equal(0)
	assert_int(int(resumen["escaladas"])).is_equal(1)


# ── Edge del GDD: el propio Oficial ausente NO cubre (ese día no hay mando) ───────────────
func test_oficial_ausente_no_cubre() -> void:
	# Arrange — el Oficial también cae hoy; hay libre compatible que PODRÍA cubrir.
	RNGService.sembrar(17)
	var personal: Node = _personal()
	var oficial: RefCounted = _oficial_en(personal, &"doc_1", 5, SALUD_CAE)
	var titular: RefCounted = _contratado(personal, "Ana Ruiz", SALUD_CAE)
	personal.asignar(titular, &"doc_2")
	var libre_1: RefCounted = _contratado(personal, "Lucía Ortega", SALUD_FIRME)
	var avisos: Array = _espia(personal)

	# Act
	personal._al_nuevo_dia()

	# Assert — sin mando presente: vacantes, libre sin tocar y avisos INDIVIDUALES (2), sin parte.
	assert_str(String(oficial.estado)).is_equal("ausente")
	assert_bool(personal.puesto_dotado(&"doc_1")).is_false()
	assert_bool(personal.puesto_dotado(&"doc_2")).is_false()
	assert_str(String(libre_1.estado)).is_equal("libre")
	assert_int(avisos[0].size()).is_equal(0)
	assert_int(avisos[1].size()).is_equal(2)


# ── PA7/States: al reincorporarse el titular, la cobertura se deshace (cubridor → libre) ──
func test_reincorporacion_deshace_cobertura() -> void:
	# Arrange — día 1: baja cubierta por el libre.
	RNGService.sembrar(29)
	var personal: Node = _personal()
	_oficial_en(personal, &"doc_1", 4)
	var titular: RefCounted = _contratado(personal, "Ana Ruiz", SALUD_CAE)
	personal.asignar(titular, &"doc_2")
	var libre_1: RefCounted = _contratado(personal, "Lucía Ortega", SALUD_FIRME)
	personal._al_nuevo_dia()
	assert_str(String(libre_1.estado)).is_equal("cubriendo")

	# Act — día 2: nadie enferma (knobs a 0) → el titular vuelve.
	personal.base_ausencia = 0.0
	personal.k_salud = 0.0
	personal._al_nuevo_dia()

	# Assert — el titular recupera SU puesto y el cubridor vuelve al banquillo.
	assert_str(String(titular.estado)).is_equal("asignado")
	assert_object(personal.agente_de(&"doc_2")).is_same(titular)
	assert_bool(personal.puesto_dotado(&"doc_2")).is_true()
	assert_str(String(libre_1.estado)).is_equal("libre")


# ── Compatibilidad: un libre ag_odac NO cubre un puesto Doc (puestos_operables manda) ─────
func test_cobertura_respeta_compatibilidad() -> void:
	# Arrange — la única opción del banquillo es de OTRO palo.
	RNGService.sembrar(35)
	var personal: Node = _personal()
	_oficial_en(personal, &"doc_1", 5)
	var titular: RefCounted = _contratado(personal, "Ana Ruiz", SALUD_CAE)
	personal.asignar(titular, &"doc_2")
	var libre_odac: RefCounted = _contratado(personal, "Raúl Cano", SALUD_FIRME, &"ag_odac")
	var avisos: Array = _espia(personal)

	# Act
	personal._al_nuevo_dia()

	# Assert — no se usa al incompatible: vacante + escalada en el parte.
	assert_bool(personal.puesto_dotado(&"doc_2")).is_false()
	assert_str(String(libre_odac.estado)).is_equal("libre")
	assert_int(int(avisos[0][0]["escaladas"])).is_equal(1)
