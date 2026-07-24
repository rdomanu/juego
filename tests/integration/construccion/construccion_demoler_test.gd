# Story 004 (epic construccion) — demoler y mover: F4 reembolso, cascada, reorganización libre ·
# TR-construction-004 · ADR-0004/0001. Tipo: Integration. DETERMINISTA (sin azar; Economía y
# Personal REALES; catálogo real). AC-CO13 (puesto atendiendo) DIFERIDO a Flujo (no existe atención).
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")


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


func _policia_doc(nombre: String = "Ana Ruiz") -> RefCounted:
	return AgenteScript.new(nombre, &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)


# ── AC-CO11: demoler devuelve coste_pagado × 0.5, libera la celda y retira el puente ──────
func test_demoler_reembolsa_y_libera() -> void:
	# Arrange — puesto de 500 construido y con agente asignado.
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var eco: Node = mundo[1]
	var personal: Node = mundo[2]
	construccion._crear_sala(&"sala_documentacion", Rect2i(0, 0, 4, 4))
	var id_puesto: StringName = construccion.construir_elemento(&"puesto_doc_general", Vector2i(1, 1))
	var agente: RefCounted = _policia_doc()
	personal.plantilla.append(agente)
	personal.asignar(agente, id_puesto)
	assert_float(eco.saldo_eur).is_equal_approx(2500.0, 0.0001)

	# Act
	assert_bool(construccion.demoler_elemento(id_puesto)).is_true()

	# Assert — +250 (F4), la celda vuelve a estar libre y Personal soltó puesto y agente.
	assert_float(eco.saldo_eur).is_equal_approx(2750.0, 0.0001)
	assert_bool(construccion.validar_elemento(&"puesto_doc_general", Vector2i(1, 1))).is_true()
	assert_str(personal.servicio_de_puesto(id_puesto)).is_equal("")
	assert_str(String(agente.estado)).is_equal("libre")


# ── AC-CO12: demolición de sala EN CASCADA — reembolsa contenido + sala (API en 2 pasos) ──
func test_demoler_sala_en_cascada() -> void:
	# Arrange — oficina CONSTRUIDA (4×4 = 320 €) con 2 ventanillas (1000 €): saldo 1680.
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var eco: Node = mundo[1]
	var sala_id: StringName = construccion.construir_sala(&"sala_documentacion", Rect2i(0, 0, 4, 4))
	construccion.construir_elemento(&"puesto_doc_general", Vector2i(0, 0))
	construccion.construir_elemento(&"puesto_doc_general", Vector2i(1, 0))
	assert_float(eco.saldo_eur).is_equal_approx(1680.0, 0.0001)

	# Act — paso 1: la UI listaría el contenido para confirmar; paso 2: cascada.
	assert_int(construccion.contenido_de_sala(sala_id).size()).is_equal(2)
	assert_bool(construccion.demoler_sala(sala_id)).is_true()

	# Assert — reembolso 250+250 (puestos) + 160 (sala) = +660; todo fuera del modelo.
	assert_float(eco.saldo_eur).is_equal_approx(2340.0, 0.0001)
	assert_str(String(construccion.sala_en(Vector2i(1, 1)))).is_equal("")
	assert_bool(construccion.validar_elemento(&"puesto_doc_general", Vector2i(0, 0))).is_false()


# ── AC-CO14: mover es gratis, conserva id/agente y reubica ────────────────────────────────
func test_mover_gratis_y_reubica() -> void:
	# Arrange
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var eco: Node = mundo[1]
	var personal: Node = mundo[2]
	construccion._crear_sala(&"sala_documentacion", Rect2i(0, 0, 4, 4))
	var id_puesto: StringName = construccion.construir_elemento(&"puesto_doc_general", Vector2i(1, 1))
	var agente: RefCounted = _policia_doc()
	personal.plantilla.append(agente)
	personal.asignar(agente, id_puesto)
	var saldo_antes: float = eco.saldo_eur

	# Act
	assert_bool(construccion.mover_elemento(id_puesto, Vector2i(2, 2))).is_true()

	# Assert — reubicado, gratis, y Personal ni se entera (agente sigue asignado y dotando).
	assert_bool(construccion.posicion_de(id_puesto) == Vector2i(2, 2)).is_true()
	assert_float(eco.saldo_eur).is_equal_approx(saldo_antes, 0.0001)
	assert_bool(personal.puesto_dotado(id_puesto)).is_true()
	# La celda vieja queda libre; la nueva, ocupada.
	assert_bool(construccion.validar_elemento(&"puesto_doc_general", Vector2i(1, 1))).is_true()
	assert_bool(construccion.validar_elemento(&"puesto_doc_general", Vector2i(2, 2))).is_false()


# ── Edge CO4: mover un puesto a una oficina incompatible se rechaza ───────────────────────
func test_mover_a_oficina_incompatible_rechazado() -> void:
	# Arrange — un odac en su casa; la oficina de Doc al lado.
	var construccion: Node = _mundo()[0]
	construccion._crear_sala(&"sala_documentacion", Rect2i(0, 0, 4, 4))
	construccion._crear_sala(&"sala_odac", Rect2i(6, 0, 4, 4))
	var id_odac: StringName = construccion.construir_elemento(&"puesto_odac", Vector2i(7, 1))

	# Act / Assert — a la oficina de Doc: rechazado sin moverse.
	assert_bool(construccion.mover_elemento(id_odac, Vector2i(1, 1))).is_false()
	assert_bool(construccion.posicion_de(id_odac) == Vector2i(7, 1)).is_true()


# ── F4: el reembolso es sobre lo PAGADO, no sobre el precio actual ────────────────────────
func test_reembolso_sobre_lo_pagado() -> void:
	# Arrange — asiento pagado a 25; luego el "precio de mercado" cambia a 999.
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var eco: Node = mundo[1]
	construccion._crear_sala(&"sala_espera_doc", Rect2i(0, 0, 3, 3))
	var id_asiento: StringName = construccion.construir_elemento(construccion.ASIENTO_BASICO, Vector2i(0, 0))
	assert_float(eco.saldo_eur).is_equal_approx(2975.0, 0.0001)
	construccion.coste_asiento_basico = 999.0

	# Act
	construccion.demoler_elemento(id_asiento)

	# Assert — +12.5 (25 × 0.5), no 499.5.
	assert_float(eco.saldo_eur).is_equal_approx(2987.5, 0.0001)


# ── Mover un asiento con la sala a TOPE: se vale a sí mismo sin contarse (ignorar) ────────
func test_mover_asiento_en_sala_a_tope() -> void:
	# Arrange — espera 3×3 (tope físico floor(9×0.7)=6) LLENA: 6 asientos.
	var construccion: Node = _mundo()[0]
	construccion._crear_sala(&"sala_espera_doc", Rect2i(0, 0, 3, 3))
	var primero: StringName = construccion.construir_elemento(construccion.ASIENTO_BASICO, Vector2i(0, 0))
	for i: int in range(1, 6):
		construccion.construir_elemento(construccion.ASIENTO_BASICO, Vector2i(i % 3, floori(float(i) / 3.0)))
	assert_int(construccion.aforo_de_sala(&"sala_1")).is_equal(10)   # 6 sentados + 4 de pie (F3 enm.)

	# Act / Assert — mover dentro de la misma sala: válido (no se cuenta a sí mismo en el tope).
	assert_bool(construccion.mover_elemento(primero, Vector2i(0, 2))).is_true()
	assert_int(construccion.aforo_de_sala(&"sala_1")).is_equal(10)


# ── Robustez: demoler/mover inexistentes no revientan ─────────────────────────────────────
func test_ids_inexistentes_no_revientan() -> void:
	# Arrange — los push_warning esperados son intencionales.
	var construccion: Node = _mundo()[0]

	# Act / Assert
	assert_bool(construccion.demoler_elemento(&"nada")).is_false()
	assert_bool(construccion.demoler_sala(&"nada")).is_false()
	assert_bool(construccion.mover_elemento(&"nada", Vector2i(0, 0))).is_false()
