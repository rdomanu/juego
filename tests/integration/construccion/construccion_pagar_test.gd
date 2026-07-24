# Story 002 (epic construccion) — construir y pagar: F1/F2 + gate E4 · TR-construction-004 ·
# ADR-0004/0001. Tipo: Integration. DETERMINISTA (sin azar; Economía REAL con saldo conocido;
# catálogo REAL para costes). Aislamiento: nodos con .new() sin árbol.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Construcción + Economía real (saldo 3000 por defecto) cableadas. Devuelve [construccion, eco].
func _mundo() -> Array:
	var eco: Node = auto_free(EconomiaScript.new())
	eco.aplicar_config(ConfigEconomiaScript.new())
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(eco)
	return [construccion, eco]


# ── AC-CO04: F1 — sala 3×3 = 380 · 5×4 = 600 (base 200 del catálogo + 20/celda) ───────────
func test_coste_sala_f1() -> void:
	# Arrange
	var construccion: Node = _mundo()[0]

	# Act / Assert
	assert_float(construccion.coste_sala(&"sala_espera_doc", Rect2i(0, 0, 3, 3))).is_equal_approx(380.0, 0.001)
	assert_float(construccion.coste_sala(&"sala_espera_doc", Rect2i(0, 0, 5, 4))).is_equal_approx(600.0, 0.001)
	# Una oficina (base 0 en el catálogo): solo el área.
	assert_float(construccion.coste_sala(&"sala_documentacion", Rect2i(0, 0, 3, 3))).is_equal_approx(180.0, 0.001)


# ── AC-CO05: sin caja se rechaza y el saldo queda INTACTO (E4 — no te endeudas) ───────────
func test_sin_caja_rechazado_saldo_intacto() -> void:
	# Arrange — saldo 100, un doc_general cuesta 500.
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var eco: Node = mundo[1]
	eco.saldo_eur = 100.0
	construccion._crear_sala(&"sala_documentacion", Rect2i(0, 0, 4, 4))

	# Act
	var id_puesto: StringName = construccion.construir_elemento(&"puesto_doc_general", Vector2i(1, 1))

	# Assert — rechazo silencioso: sin id, sin registro, saldo intacto.
	assert_str(String(id_puesto)).is_equal("")
	assert_float(eco.saldo_eur).is_equal_approx(100.0, 0.0001)
	assert_bool(construccion.validar_elemento(&"puesto_doc_general", Vector2i(1, 1))).is_true()


# ── AC-CO06: saldo 600 − doc_general (500) = 100 ──────────────────────────────────────────
func test_construir_descuenta_el_coste() -> void:
	# Arrange
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var eco: Node = mundo[1]
	eco.saldo_eur = 600.0
	construccion._crear_sala(&"sala_documentacion", Rect2i(0, 0, 4, 4))

	# Act
	var id_puesto: StringName = construccion.construir_elemento(&"puesto_doc_general", Vector2i(1, 1))

	# Assert — construido, cobrado y con el coste PAGADO guardado (lo usará el reembolso F4).
	assert_bool(id_puesto != &"").is_true()
	assert_float(eco.saldo_eur).is_equal_approx(100.0, 0.0001)
	assert_float(float(construccion._elementos[id_puesto]["coste_pagado"])).is_equal_approx(500.0, 0.0001)


# ── Sala válida + pago: 3000 − 380 = 2620 y la sala consta en el modelo ───────────────────
func test_construir_sala_paga_y_registra() -> void:
	# Arrange
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var eco: Node = mundo[1]

	# Act
	var sala_id: StringName = construccion.construir_sala(&"sala_espera_doc", Rect2i(0, 6, 3, 3))

	# Assert
	assert_bool(sala_id != &"").is_true()
	assert_float(eco.saldo_eur).is_equal_approx(2620.0, 0.0001)
	assert_str(String(construccion.sala_en(Vector2i(1, 7)))).is_equal(String(sala_id))
	# Una sala INVÁLIDA (solapa) no cobra nada.
	assert_str(String(construccion.construir_sala(&"sala_espera_odac", Rect2i(1, 7, 3, 3)))).is_equal("")
	assert_float(eco.saldo_eur).is_equal_approx(2620.0, 0.0001)


# ── Enmienda 007 (feedback usuario): dibujar pegado a una sala del MISMO tipo la AMPLÍA ───
func test_ampliar_sala_pegada_cobra_solo_celdas_nuevas() -> void:
	# Arrange — espera 3×3 construida (380 €): saldo 2620.
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var eco: Node = mundo[1]
	var sala_id: StringName = construccion.construir_sala(&"sala_espera_doc", Rect2i(0, 0, 3, 3))
	assert_float(eco.saldo_eur).is_equal_approx(2620.0, 0.0001)

	# Act 1 — dibujar PEGADO (misma altura, a la derecha): amplía la MISMA sala, sin base (6×20=120).
	assert_str(String(construccion.construir_sala(&"sala_espera_doc", Rect2i(3, 0, 2, 3)))).is_equal(String(sala_id))
	assert_float(eco.saldo_eur).is_equal_approx(2500.0, 0.0001)
	assert_str(String(construccion.sala_en(Vector2i(4, 2)))).is_equal(String(sala_id))

	# Act 2 — dibujar SOLAPANDO pero con unión rectangular (una fila más abajo, ancho completo):
	# solo cobra las 5 celdas nuevas (100 €). Sala final 5×4 → el tope de aforo crece a 14.
	assert_str(String(construccion.construir_sala(&"sala_espera_doc", Rect2i(0, 2, 5, 2)))).is_equal(String(sala_id))
	assert_float(eco.saldo_eur).is_equal_approx(2400.0, 0.0001)
	assert_bool((construccion._salas[sala_id]["rect"] as Rect2i) == Rect2i(0, 0, 5, 4)).is_true()


# ── Enmienda 007: tipo distinto o unión en "L" NO amplían — crean sala aparte ─────────────
func test_pegada_tipo_distinto_o_en_l_crea_sala_nueva() -> void:
	# Arrange
	var construccion: Node = _mundo()[0]
	var espera: StringName = construccion.construir_sala(&"sala_espera_doc", Rect2i(0, 0, 3, 3))

	# Act / Assert — OTRO tipo pegado: sala nueva (no se fusionan tipos distintos).
	var odac: StringName = construccion.construir_sala(&"sala_espera_odac", Rect2i(3, 0, 3, 3))
	assert_bool(odac != &"" and odac != espera).is_true()
	# El MISMO tipo pero formando "L" (no rectangular exacta): sala nueva separada (CO3).
	var ele: StringName = construccion.construir_sala(&"sala_espera_doc", Rect2i(0, 3, 2, 2))
	assert_bool(ele != &"" and ele != espera).is_true()


# ── AC-CO18: un coste corrupto (negativo) se clampa a ≥ 0 con aviso ───────────────────────
func test_coste_corrupto_clampado() -> void:
	# Arrange — el push_warning esperado es intencional.
	var construccion: Node = _mundo()[0]

	# Act / Assert — el clamp del coste (usado por F1/F2) nunca devuelve negativo.
	assert_float(construccion._clamp_coste(-100.0, &"corrupto")).is_equal_approx(0.0, 0.0001)
	assert_float(construccion._clamp_coste(500.0, &"sano")).is_equal_approx(500.0, 0.0001)
	# El asiento básico sale de config (F2) y también queda clampado por aplicar_config.
	assert_float(construccion.coste_elemento(construccion.ASIENTO_BASICO)).is_equal_approx(25.0, 0.0001)
