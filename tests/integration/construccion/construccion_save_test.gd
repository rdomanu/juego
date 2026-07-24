# Story 005 (epic construccion) — pausa CO12 + persistencia del layout · TR-construction-004 ·
# ADR-0002. Tipo: Integration. DETERMINISTA. Round-trip por JSON real (full_precision, como
# SaveManager). ⚠️ ORDEN de carga verificado: Construcción ANTES que Personal (invariante de
# personal-006). Solo el test de Pausa mete nodos al árbol (physics real, multiplicador 0).
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Mundo cableado (saldo 3000). Devuelve [construccion, eco, personal].
func _mundo() -> Array:
	var eco: Node = auto_free(EconomiaScript.new())
	eco.aplicar_config(ConfigEconomiaScript.new())
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(eco)
	construccion.usar_personal(personal)
	return [construccion, eco, personal]


## Layout rico construido por la API real: 2 oficinas + espera con 3 asientos + 3 puestos.
## Devuelve [id_espera, id_puesto_doc] para los asserts.
func _layout_rico(construccion: Node) -> Array:
	construccion.construir_sala(&"sala_documentacion", Rect2i(0, 0, 4, 4))
	var id_puesto: StringName = construccion.construir_elemento(&"puesto_doc_general", Vector2i(0, 0))
	construccion.construir_elemento(&"puesto_doc_general", Vector2i(1, 0))
	var id_espera: StringName = construccion.construir_sala(&"sala_espera_doc", Rect2i(0, 6, 3, 3))
	for i: int in range(3):
		construccion.construir_elemento(construccion.ASIENTO_BASICO, Vector2i(i, 6))
	construccion.construir_sala(&"sala_odac", Rect2i(6, 0, 4, 4))
	construccion.construir_elemento(&"puesto_odac", Vector2i(7, 1))
	return [id_espera, id_puesto]


## Round-trip por JSON real con full_precision (el camino del SaveManager).
func _por_json(estado: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(estado, "", true, true))


# ── AC-CO17: el layout se restaura campo a campo (rejilla, salas, puestos, objetos) ───────
func test_roundtrip_campo_a_campo() -> void:
	# Arrange
	var a: Node = _mundo()[0]
	var ids: Array = _layout_rico(a)

	# Act — save → JSON → load en un mundo B nuevo.
	var mundo_b: Array = _mundo()
	var b: Node = mundo_b[0]
	b.load_state(_por_json(a.save()))

	# Assert — salas y elementos idénticos campo a campo.
	assert_int(b._salas.size()).is_equal(a._salas.size())
	for sala_id: StringName in a._salas:
		assert_bool(b._salas.has(sala_id)).is_true()
		assert_str(String(b._salas[sala_id]["tipo"])).is_equal(String(a._salas[sala_id]["tipo"]))
		assert_bool(b._salas[sala_id]["rect"] == a._salas[sala_id]["rect"]).is_true()
		assert_float(float(b._salas[sala_id]["coste_pagado"])).is_equal_approx(
			float(a._salas[sala_id]["coste_pagado"]), 0.0001
		)
	assert_int(b._elementos.size()).is_equal(a._elementos.size())
	for elemento_id: StringName in a._elementos:
		assert_bool(b._elementos.has(elemento_id)).is_true()
		assert_str(String(b._elementos[elemento_id]["catalogo"])).is_equal(String(a._elementos[elemento_id]["catalogo"]))
		assert_bool(b._elementos[elemento_id]["celda"] == a._elementos[elemento_id]["celda"]).is_true()
	# El aforo (derivado) revive idéntico y el contador de ids no colisiona al seguir construyendo.
	assert_int(b.aforo_de_sala(ids[0])).is_equal(a.aforo_de_sala(ids[0]))
	var nuevo: StringName = b.construir_elemento(b.ASIENTO_BASICO, Vector2i(0, 7))
	assert_bool(nuevo != &"").is_true()
	assert_bool(a._elementos.has(nuevo)).is_false()   # id fresco, no pisa ninguno cargado


# ── El puente revive: los puestos cargados quedan re-registrados en Personal ──────────────
func test_carga_reregistra_puestos_en_personal() -> void:
	# Arrange
	var a: Node = _mundo()[0]
	var ids: Array = _layout_rico(a)
	var mundo_b: Array = _mundo()
	var b: Node = mundo_b[0]
	var personal_b: Node = mundo_b[2]

	# Act
	b.load_state(_por_json(a.save()))

	# Assert — Personal B conoce el puesto cargado y se puede asignar.
	var agente: RefCounted = AgenteScript.new("Ana Ruiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)
	personal_b.plantilla.append(agente)
	assert_bool(personal_b.asignar(agente, ids[1])).is_true()


# ── Round-trip COMBINADO en el orden correcto: Construcción ANTES que Personal ────────────
func test_roundtrip_combinado_construccion_antes_que_personal() -> void:
	# Arrange — mundo A: puesto construido + agente contratado y ASIGNADO a él.
	var mundo_a: Array = _mundo()
	var a: Node = mundo_a[0]
	var personal_a: Node = mundo_a[2]
	a.construir_sala(&"sala_documentacion", Rect2i(0, 0, 4, 4))
	var id_puesto: StringName = a.construir_elemento(&"puesto_doc_general", Vector2i(1, 1))
	var agente: RefCounted = AgenteScript.new("Ana Ruiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)
	personal_a.incorporar(agente)
	personal_a.asignar(agente, id_puesto)
	var foto_construccion: Dictionary = _por_json(a.save())
	var foto_personal: Dictionary = _por_json(personal_a.save())

	# Act — cargar en B en el ORDEN del invariante: Construcción primero, Personal después.
	var mundo_b: Array = _mundo()
	var b: Node = mundo_b[0]
	var personal_b: Node = mundo_b[2]
	b.load_state(foto_construccion)
	personal_b.load_state(foto_personal)

	# Assert — la asignación sobrevive el viaje: el puesto existe, su titular está al pie.
	assert_bool(personal_b.puesto_dotado(id_puesto)).is_true()
	assert_str(personal_b.plantilla[0].nombre).is_equal("Ana Ruiz")
	assert_str(String(personal_b.plantilla[0].puesto_id)).is_equal(String(id_puesto))


# ── ADR-0002: cargar sitúa — ni cobros ni reembolsos ni señales ───────────────────────────
func test_carga_sin_dinero_ni_senales() -> void:
	# Arrange — B con saldo virgen 3000 (Construcción no tiene señales propias: se verifica el saldo).
	var a: Node = _mundo()[0]
	_layout_rico(a)
	var mundo_b: Array = _mundo()
	var b: Node = mundo_b[0]
	var eco_b: Node = mundo_b[1]

	# Act
	b.load_state(_por_json(a.save()))

	# Assert — el layout entró y el dinero de B ni se movió.
	assert_int(b._salas.size()).is_equal(3)
	assert_float(eco_b.saldo_eur).is_equal_approx(3000.0, 0.0001)


# ── Corrupto: la entrada mala se descarta con aviso; el resto del save carga ──────────────
func test_entrada_corrupta_descartada() -> void:
	# Arrange — un save a mano: 1 sala válida, 1 elemento huérfano y 1 válido (avisos esperados).
	var construccion: Node = _mundo()[0]
	var foto: Dictionary = {
		"salas": [
			{"id": "sala_1", "tipo": "sala_documentacion", "rect": [0, 0, 4, 4], "coste_pagado": 320.0},
			{"id": "sala_2", "tipo": "sala_inventada", "rect": [6, 0, 3, 3], "coste_pagado": 100.0},
		],
		"elementos": [
			{"id": "p1", "catalogo": "puesto_inventado", "celda": [1, 1], "coste_pagado": 500.0},
			{"id": "p2", "catalogo": "puesto_doc_general", "celda": [2, 2], "coste_pagado": 500.0},
		],
		"contador_ids": 4,
	}

	# Act
	construccion.load_state(foto)

	# Assert — solo lo válido entra; el save NUNCA se invalida entero.
	assert_int(construccion._salas.size()).is_equal(1)
	assert_int(construccion._elementos.size()).is_equal(1)
	assert_bool(construccion._elementos.has(&"p2")).is_true()


# ── AC-CO16: en Pausa (mundo REAL en árbol) se construye y reorganiza con normalidad ──────
func test_pausa_permite_construir() -> void:
	# Arrange — reloj real en PAUSA; Construcción y Economía de verdad en el árbol.
	var tiempo: Node = auto_free(TiempoScript.new())
	var eco: Node = auto_free(EconomiaScript.new())
	eco.aplicar_config(ConfigEconomiaScript.new())
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.usar_economia(eco)
	add_child(tiempo)
	add_child(construccion)   # _ready: carga el .tres real y entra a Persist
	tiempo.fijar_velocidad(TiempoScript.Velocidad.PAUSA)

	# Act — construir, mover y demoler CON el juego en Pausa, entre frames de physics reales.
	var sala_id: StringName = construccion.construir_sala(&"sala_espera_doc", Rect2i(0, 0, 3, 3))
	for i: int in range(15):
		await get_tree().physics_frame
	var id_asiento: StringName = construccion.construir_elemento(construccion.ASIENTO_BASICO, Vector2i(0, 0))
	assert_bool(construccion.mover_elemento(id_asiento, Vector2i(1, 1))).is_true()
	assert_bool(construccion.demoler_elemento(id_asiento)).is_true()
	for i: int in range(15):
		await get_tree().physics_frame

	# Assert — todo funcionó y el reloj NO avanzó (la construcción no depende del tiempo).
	assert_bool(sala_id != &"").is_true()
	assert_float(tiempo.minutos_juego).is_equal_approx(0.0, 0.0001)
