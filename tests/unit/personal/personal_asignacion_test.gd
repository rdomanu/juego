# Story 003 (epic personal) — asignación a puestos + gate FL4 · TR-staff-002 · ADR-0001/0003.
# Tipo: Logic. DETERMINISTA (sin azar: agentes construidos a mano, sin mercado; catálogo REAL para
# `puestos_operables` y `servicio`).
# Aislamiento: nodo con .new() sin árbol.
extends GdUnitTestSuite

const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Personal con la dotación de puestos estándar del esqueleto registrada.
func _personal() -> Node:
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	personal.registrar_puesto(&"doc_2", &"puesto_doc_general")
	personal.registrar_puesto(&"odac_1", &"puesto_odac")
	return personal


func _policia_doc(nombre: String = "Ana Ruiz") -> RefCounted:
	return AgenteScript.new(nombre, &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)


func _oficial(tipo: StringName, nombre: String) -> RefCounted:
	return AgenteScript.new(nombre, tipo, AgenteScript.RANGO_OFICIAL, 3, 3, 3, 3, 4)


# ── AC-PE08: opera lo suyo (gate FL4 en marcha); lo ajeno se rechaza sin moverlo ──────────
func test_asignar_valida_puestos_operables() -> void:
	# Arrange
	var personal: Node = _personal()
	var agente: RefCounted = _policia_doc()

	# Act / Assert — ag_doc a doc_1: aceptado y el puesto queda DOTADO (gate FL4 listo para Flujo).
	assert_bool(personal.asignar(agente, &"doc_1")).is_true()
	assert_bool(personal.puesto_dotado(&"doc_1")).is_true()
	assert_str(String(agente.estado)).is_equal("asignado")

	# ag_doc a odac_1: rechazado (puestos_operables del catálogo) y NO se movió de doc_1.
	assert_bool(personal.asignar(agente, &"odac_1")).is_false()
	assert_str(String(agente.puesto_id)).is_equal("doc_1")
	assert_bool(personal.puesto_dotado(&"odac_1")).is_false()


# ── AC-PE02: máx. 1 Oficial por servicio (el 2.º se rechaza; otro servicio sí puede) ──────
func test_max_un_oficial_por_servicio() -> void:
	# Arrange — Oficial de Documentación ya al mando en doc_1.
	var personal: Node = _personal()
	assert_bool(personal.asignar(_oficial(&"ag_doc", "Óscar Delgado"), &"doc_1")).is_true()

	# Act / Assert — 2.º Oficial al MISMO servicio (doc_2): rechazado.
	var oficial_2: RefCounted = _oficial(&"ag_doc", "Nuria Blanco")
	assert_bool(personal.asignar(oficial_2, &"doc_2")).is_false()
	assert_str(String(oficial_2.puesto_id)).is_equal("")

	# Un Oficial de ODAC a odac_1 (OTRO servicio): aceptado — la regla es por servicio.
	assert_bool(personal.asignar(_oficial(&"ag_odac", "Raúl Cano"), &"odac_1")).is_true()


# ── AC-PE09: reasignar MUEVE (libera el anterior; nunca está en dos sitios) ───────────────
func test_reasignar_mueve_sin_duplicar() -> void:
	# Arrange
	var personal: Node = _personal()
	var agente: RefCounted = _policia_doc()
	personal.asignar(agente, &"doc_1")

	# Act
	assert_bool(personal.asignar(agente, &"doc_2")).is_true()

	# Assert — doc_1 libre, doc_2 dotado, el agente consta SOLO en doc_2.
	assert_bool(personal.puesto_dotado(&"doc_1")).is_false()
	assert_bool(personal.puesto_dotado(&"doc_2")).is_true()
	assert_object(personal.agente_de(&"doc_2")).is_same(agente)
	assert_object(personal.agente_de(&"doc_1")).is_null()


# ── plazas_agente = 1: un puesto ocupado rechaza al segundo ───────────────────────────────
func test_doble_ocupacion_rechazada() -> void:
	# Arrange
	var personal: Node = _personal()
	var titular: RefCounted = _policia_doc("Ana Ruiz")
	personal.asignar(titular, &"doc_1")

	# Act / Assert — el 2.º se rechaza y el titular sigue.
	assert_bool(personal.asignar(_policia_doc("Carlos Vega"), &"doc_1")).is_false()
	assert_object(personal.agente_de(&"doc_1")).is_same(titular)
	# Idempotencia: re-asignar el titular a su propio puesto es true sin efectos.
	assert_bool(personal.asignar(titular, &"doc_1")).is_true()


# ── TR-staff-002: los modificadores del puesto (lo que consumirá Flujo) ───────────────────
func test_modificadores_por_puesto() -> void:
	# Arrange — una crack (R5/M4, Trato 5) en doc_1.
	var personal: Node = _personal()
	var crack: RefCounted = AgenteScript.new("Lucía Ortega", &"ag_doc", AgenteScript.RANGO_POLICIA, 5, 5, 3, 4)
	personal.asignar(crack, &"doc_1")

	# Act / Assert — F2 del puesto ≈ 0.76; F3 con Trato 5/Mot 4 = 1 + 0.5×1.1 = 1.55 → clamp 1.5.
	assert_float(personal.modificador_produccion_de(&"doc_1")).is_equal_approx(0.76, 0.001)
	assert_float(personal.factor_trato_de(&"doc_1")).is_equal_approx(1.5, 0.001)
	# Puesto sin agente → 1.0 neutro (el push_warning esperado es intencional).
	assert_float(personal.modificador_produccion_de(&"doc_2")).is_equal_approx(1.0, 0.0001)


# ── Robustez: puesto no registrado / tipo de puesto inexistente ───────────────────────────
func test_puestos_invalidos_no_revientan() -> void:
	# Arrange — los push_warning esperados son intencionales.
	var personal: Node = _personal()

	# Act / Assert — asignar a un puesto que no existe: false con aviso.
	assert_bool(personal.asignar(_policia_doc(), &"no_existe")).is_false()
	# Registrar un puesto de tipo inexistente en el catálogo: se ignora.
	personal.registrar_puesto(&"raro_1", &"puesto_inventado")
	assert_bool(personal.asignar(_policia_doc(), &"raro_1")).is_false()


# ── Integración con la 002: despedir LIBERA el puesto; quitar_puesto libera al agente ─────
func test_despedir_y_quitar_puesto_liberan() -> void:
	# Arrange — un contratado a mano en plantilla y asignado.
	var personal: Node = _personal()
	var agente: RefCounted = _policia_doc()
	personal.plantilla.append(agente)
	personal.asignar(agente, &"doc_1")

	# Act 1 — despedir: fuera de plantilla Y doc_1 sin dotar (completa el hueco de la 002).
	personal.despedir(agente)
	assert_bool(personal.puesto_dotado(&"doc_1")).is_false()
	assert_int(personal.plantilla.size()).is_equal(0)

	# Act 2 — quitar un puesto con agente: el agente queda libre (demolición futura).
	var otro: RefCounted = _policia_doc("Carlos Vega")
	personal.asignar(otro, &"doc_2")
	personal.quitar_puesto(&"doc_2")
	assert_str(String(otro.estado)).is_equal("libre")
	assert_bool(personal.asignar(otro, &"doc_2")).is_false()   # ya no existe
