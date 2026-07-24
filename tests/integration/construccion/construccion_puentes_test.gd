# Story 003 (epic construccion) — puentes a Personal + aforo F3 + puestos útiles F5 ·
# TR-construction-004 · ADR-0004/0001. Tipo: Integration. DETERMINISTA (sin azar; Personal y
# Economía REALES; catálogo real). Aislamiento: nodos con .new() sin árbol.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Mundo cableado: Construcción + Economía real + Personal real. Devuelve [construccion, eco, personal].
func _mundo(saldo: float = 3000.0) -> Array:
	var eco: Node = auto_free(EconomiaScript.new())
	eco.aplicar_config(ConfigEconomiaScript.new())
	eco.saldo_eur = saldo
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(eco)
	construccion.usar_personal(personal)
	return [construccion, eco, personal]


func _policia_doc(nombre: String = "Ana Ruiz") -> RefCounted:
	return AgenteScript.new(nombre, &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)


# ── AC-CO15: un puesto CONSTRUIDO es usable por Personal (gate FL4); sin construir, no ────
func test_puesto_construido_usable_por_personal() -> void:
	# Arrange
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var personal: Node = mundo[2]
	construccion._crear_sala(&"sala_documentacion", Rect2i(0, 0, 4, 4))
	var agente: RefCounted = _policia_doc()
	personal.plantilla.append(agente)

	# Act — construir registra el puesto en Personal (puente).
	var id_puesto: StringName = construccion.construir_elemento(&"puesto_doc_general", Vector2i(1, 1))

	# Assert — Personal lo conoce, se puede asignar y el gate FL4 responde.
	assert_str(personal.servicio_de_puesto(id_puesto)).is_equal("Documentacion")
	assert_bool(personal.asignar(agente, id_puesto)).is_true()
	assert_bool(personal.puesto_dotado(id_puesto)).is_true()
	# Un id NO construido no existe para Personal (aviso esperado: puesto no registrado).
	assert_bool(personal.asignar(_policia_doc("Carlos Vega"), &"puesto_fantasma")).is_false()


# ── AC-CO07: F3 — caben floor(20×0.7)=14; con 10 asientos aforo 10; el 15.º se rechaza ────
func test_aforo_por_asientos_con_tope() -> void:
	# Arrange — sala de espera 5×4 (20 celdas) y caja de sobra (asientos a 25 €).
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var eco: Node = mundo[1]
	construccion._crear_sala(&"sala_espera_doc", Rect2i(0, 0, 5, 4))

	# Act / Assert — 10 asientos → aforo 10.
	for i: int in range(10):
		var celda := Vector2i(i % 5, floori(float(i) / 5.0))
		assert_bool(construccion.construir_elemento(construccion.ASIENTO_BASICO, celda) != &"").is_true()
	assert_int(construccion.aforo_de_sala(&"sala_1")).is_equal(10)
	# Hasta el tope físico 14 → aforo 14.
	for i: int in range(10, 14):
		var celda := Vector2i(i % 5, floori(float(i) / 5.0))
		assert_bool(construccion.construir_elemento(construccion.ASIENTO_BASICO, celda) != &"").is_true()
	assert_int(construccion.aforo_de_sala(&"sala_1")).is_equal(14)
	# El 15.º NO cabe (boundary intencional): rechazado sin cobrar.
	var saldo_antes: float = eco.saldo_eur
	assert_str(String(construccion.construir_elemento(construccion.ASIENTO_BASICO, Vector2i(4, 2)))).is_equal("")
	assert_int(construccion.aforo_de_sala(&"sala_1")).is_equal(14)
	assert_float(eco.saldo_eur).is_equal_approx(saldo_antes, 0.0001)


# ── AC-CO08: sala de espera sin asientos → aforo 0 (el dato que Flujo consumirá) ──────────
func test_sala_sin_asientos_aforo_cero() -> void:
	# Arrange
	var construccion: Node = _mundo()[0]
	var sala_id: StringName = construccion._crear_sala(&"sala_espera_odac", Rect2i(0, 0, 3, 3))

	# Act / Assert
	assert_int(construccion.aforo_de_sala(sala_id)).is_equal(0)
	# Sala inexistente → 0 con aviso (robustez).
	assert_int(construccion.aforo_de_sala(&"sala_fantasma")).is_equal(0)


# ── AC-CO09: sin tope de puestos — 10 ventanillas con 5 útiles es LEGAL ───────────────────
func test_sin_tope_de_puestos() -> void:
	# Arrange — oficina alargada y caja para 10 × 500 €.
	var mundo: Array = _mundo(6000.0)
	var construccion: Node = mundo[0]
	var personal: Node = mundo[2]
	construccion._crear_sala(&"sala_documentacion", Rect2i(0, 0, 10, 2))

	# Act — 10 puestos, uno por celda de la fila superior.
	var construidos: int = 0
	for x: int in range(10):
		if construccion.construir_elemento(&"puesto_doc_general", Vector2i(x, 0)) != &"":
			construidos += 1

	# Assert — los 10 constan, registrados en Personal y visibles para Flujo por servicio.
	assert_int(construidos).is_equal(10)
	assert_int(construccion.puestos_de_servicio("Documentacion").size()).is_equal(10)
	assert_str(personal.servicio_de_puesto(construccion.puestos_de_servicio("Documentacion")[9])).is_equal("Documentacion")
	assert_float(mundo[1].saldo_eur).is_equal_approx(1000.0, 0.0001)


# ── AC-CO10: F5 — ceil(17.6/4) = 5 puestos útiles (informativo, división defendida) ───────
func test_puestos_utiles_f5() -> void:
	# Arrange
	var construccion: Node = _mundo()[0]

	# Act / Assert
	assert_int(construccion.puestos_utiles(17.6, 4.0)).is_equal(5)
	assert_int(construccion.puestos_utiles(0.0, 4.0)).is_equal(0)
	assert_int(construccion.puestos_utiles(16.0, 4.0)).is_equal(4)   # exacto, sin redondeo extra
	# Throughput 0 → 0 con aviso (división por cero defendida; push_warning intencional).
	assert_int(construccion.puestos_utiles(10.0, 0.0)).is_equal(0)


# ── Getters para Flujo: posición por celda y robustez ─────────────────────────────────────
func test_posicion_de_elemento() -> void:
	# Arrange
	var construccion: Node = _mundo()[0]
	construccion._crear_sala(&"sala_documentacion", Rect2i(0, 0, 4, 4))
	var id_puesto: StringName = construccion.construir_elemento(&"puesto_doc_general", Vector2i(2, 3))

	# Act / Assert
	assert_bool(construccion.posicion_de(id_puesto) == Vector2i(2, 3)).is_true()
	# Inexistente → centinela (-1,-1) con aviso.
	assert_bool(construccion.posicion_de(&"nada") == Vector2i(-1, -1)).is_true()
