# Story 005 (epic flujo) — aforo F6 dentro/fuera con Construcción REAL (AC-FL13/FL14 + enmienda
# F3: sentados + de pie) · TR-flow-002 · ADR-0001. Tipo: Integration. DETERMINISTA (sin azar;
# catálogo real; el aforo sale de la sala construida de verdad — Flujo compara, Construcción posee).
extends GdUnitTestSuite

const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Mundo con sala de espera Doc REAL 2×2 + oficina con doc_1 (puente completo: Construcción
## construye → Personal registra → Flujo compara aforo). Con el default (1 asiento) el aforo es
## 3: 1 sentado + floor(4×0.5)=2 de pie (enmienda F3). Devuelve [flujo, personal, construccion].
func _mundo_con_espera(asientos: int = 1) -> Array:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_personal(personal)
	construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(0, 0, 2, 2))
	for i: int in range(asientos):
		construccion.construir_de_oficio_elemento(construccion.ASIENTO_BASICO, Vector2i(i, 0))
	construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(4, 0, 4, 4))
	construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(5, 1), &"doc_1")
	var flujo: Node = auto_free(FlujoScript.new())
	flujo.aplicar_config(ConfigFlujoScript.new())
	flujo.usar_personal(personal)
	flujo.usar_construccion(construccion)
	flujo.registrar_puesto_flujo(&"doc_1", &"puesto_doc_general")
	return [flujo, personal, construccion]


func _dni_admitido(flujo: Node) -> RefCounted:
	var persona: RefCounted = flujo.admitir(PersonaScript.new(&"Documentacion", &"dni", 511.0))
	flujo.encolar(persona)
	return persona


func _asignar_agente(personal: Node, puesto: StringName) -> RefCounted:
	var agente: RefCounted = AgenteScript.new(
		"Ana Ruiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3
	)
	personal.plantilla.append(agente)
	personal.asignar(agente, puesto)
	return agente


# ── AC-FL13: sala a aforo → la siguiente espera FUERA; al liberarse plaza entra por turno ─
func test_aforo_manda_y_entra_por_turno() -> void:
	# Arrange — aforo real 3 (1 asiento + 2 de pie); 6 llegadas: turnos 1-3 dentro, 4-6 fuera.
	var mundo: Array = _mundo_con_espera()
	var flujo: Node = mundo[0]
	var personas: Array = []
	for i: int in range(6):
		personas.append(_dni_admitido(flujo))
	assert_int(flujo.ocupacion_dentro(&"Documentacion")).is_equal(3)
	assert_str(String(personas[2].estado)).is_equal("esperando_dentro")
	assert_str(String(personas[3].estado)).is_equal("esperando_fuera")
	assert_str(String(personas[4].estado)).is_equal("esperando_fuera")
	assert_str(String(personas[5].estado)).is_equal("esperando_fuera")

	# Act — doc_1 se dota y llama: el turno 1 pasa a Llamada → se libera UNA plaza dentro.
	_asignar_agente(mundo[1], &"doc_1")
	flujo._emparejar()

	# Assert — entra el turno 4 (el MENOR de los de fuera); 5 y 6 siguen fuera; sala llena.
	assert_str(String(personas[0].estado)).is_equal("llamada")
	assert_str(String(personas[3].estado)).is_equal("esperando_dentro")
	assert_str(String(personas[4].estado)).is_equal("esperando_fuera")
	assert_str(String(personas[5].estado)).is_equal("esperando_fuera")
	assert_int(flujo.ocupacion_dentro(&"Documentacion")).is_equal(3)


# ── Enmienda F3 (petición del usuario): SIN asientos se entra igual, DE PIE, por área ─────
func test_sin_asientos_entran_de_pie() -> void:
	# Arrange — sala 2×2 SIN asientos → aforo = 0 sentados + floor(4×0.5)=2 de pie.
	var mundo: Array = _mundo_con_espera(0)
	var flujo: Node = mundo[0]

	# Act — 3 llegadas.
	var personas: Array = []
	for i: int in range(3):
		personas.append(_dni_admitido(flujo))

	# Assert — 2 dentro (de pie) + 1 fuera: la sala sin bancos NO deja a todos en la calle.
	assert_int(flujo.ocupacion_dentro(&"Documentacion")).is_equal(2)
	assert_str(String(personas[0].estado)).is_equal("esperando_dentro")
	assert_str(String(personas[1].estado)).is_equal("esperando_dentro")
	assert_str(String(personas[2].estado)).is_equal("esperando_fuera")


# ── AC-FL14: la cola exterior crece SIN tope de Flujo y el ritmo de atención no se frena ──
func test_cola_exterior_sin_tope_ni_freno() -> void:
	# Arrange — aforo 3, doc_1 dotado; 20 admisiones de golpe (sin cita — FL7).
	var mundo: Array = _mundo_con_espera()
	var flujo: Node = mundo[0]
	_asignar_agente(mundo[1], &"doc_1")
	for i: int in range(20):
		_dni_admitido(flujo)
	assert_int(flujo.personas_en_cola(&"Documentacion")).is_equal(20)
	assert_int(flujo.ocupacion_dentro(&"Documentacion")).is_equal(3)

	# Act / Assert — 1.ª atención completa (1 tick de arranque + 12 del dni con agente estándar):
	# atiende al mismo ritmo que sin cola exterior (patrón DM16 — sin freno).
	flujo._al_tick(1.0)
	for i: int in range(12):
		flujo._al_tick(1.0)
	assert_int(flujo.personas_en_cola(&"Documentacion")).is_equal(18)

	# 2.ª atención completa: mismo ritmo; cada plaza liberada la ocupa el siguiente de fuera.
	for i: int in range(12):
		flujo._al_tick(1.0)
	assert_int(flujo.personas_en_cola(&"Documentacion")).is_equal(17)
	assert_int(flujo.ocupacion_dentro(&"Documentacion")).is_equal(3)


# ── Aforo agregado: dos salas de espera del MISMO servicio suman; la de ODAC no cuenta ────
func test_aforo_de_servicio_suma_salas() -> void:
	# Arrange — espera Doc (aforo 3) + 2.ª espera Doc (aforo 3) + espera ODAC (aforo 3, aparte).
	var mundo: Array = _mundo_con_espera()
	var construccion: Node = mundo[2]
	construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(0, 5, 2, 2))
	construccion.construir_de_oficio_elemento(construccion.ASIENTO_BASICO, Vector2i(0, 5))
	construccion.construir_de_oficio_sala(&"sala_espera_odac", Rect2i(4, 5, 2, 2))
	construccion.construir_de_oficio_elemento(construccion.ASIENTO_BASICO, Vector2i(4, 5))

	# Act / Assert — Doc = 3 + 3; ODAC = 3 (cada servicio ve SOLO sus salas de espera).
	assert_int(construccion.aforo_de_servicio(&"Documentacion")).is_equal(6)
	assert_int(construccion.aforo_de_servicio(&"ODAC")).is_equal(3)
