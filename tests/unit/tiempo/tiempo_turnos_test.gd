# Story 003 (epic tiempo) — conversiones hora↔minutos + turno + es_de_noche (funciones puras derivadas).
# Clases: los QA test cases de la story (AC-T06..T15 + bordes de turno). Tipo: Logic. DETERMINISTA.
#
# Las funciones son PURAS: reciben `min_dia` y no mutan estado ni corren `_physics_process`. El fixture se
# instancia con `.new()` SIN árbol (sin `_ready` → sin cargar el `.tres`) → usa los defaults de límites de
# turno del código (420/900/1380), que son exactamente los que exigen los AC. Preload POR RUTA LITERAL.
extends GdUnitTestSuite

const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")


## Fixture: reloj sin árbol (sin `_ready`), límites de turno en sus defaults 420/900/1380.
func _nuevo_tiempo() -> Node:
	return auto_free(TiempoScript.new())


# ── Conversión minutos → HH:MM (AC-T06/T08) ────────────────────────────────────────────────
func test_hhmm_567_es_0927() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Act / Assert — 567 min = 09 h 27 min (AC-T06).
	assert_str(tiempo.hhmm(567.0)).is_equal("09:27")


func test_hhmm_0_es_0000_nunca_2400() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Act
	var texto: String = tiempo.hhmm(0.0)
	# Assert — 0 → "00:00", explícitamente NUNCA "24:00" (AC-T08).
	assert_str(texto).is_equal("00:00")
	assert_str(texto).is_not_equal("24:00")


# ── Conversión (hora, minuto) → minutos del día (AC-T07) ───────────────────────────────────
func test_a_minutos_14_30_es_870() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Act / Assert — 14:30 = 14*60+30 = 870 (AC-T07).
	assert_int(tiempo.a_minutos(14, 30)).is_equal(870)


# ── Cálculo de turno (AC-T09..T12 + bordes) ────────────────────────────────────────────────
func test_turno_420_es_manana() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Act / Assert — 07:00 → MAÑANA (borde inferior inclusivo) (AC-T09).
	assert_int(tiempo.turno_de(420.0)).is_equal(tiempo.Turno.MANANA)


func test_turno_900_es_tarde() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Act / Assert — 15:00 → TARDE (borde inferior inclusivo) (AC-T10).
	assert_int(tiempo.turno_de(900.0)).is_equal(tiempo.Turno.TARDE)


func test_turno_1395_es_noche() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Act / Assert — 23:15 → NOCHE (AC-T11).
	assert_int(tiempo.turno_de(1395.0)).is_equal(tiempo.Turno.NOCHE)


func test_turno_200_es_noche_cruza_medianoche() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Act / Assert — 03:20 → NOCHE (caso restante que cruza medianoche) (AC-T12).
	assert_int(tiempo.turno_de(200.0)).is_equal(tiempo.Turno.NOCHE)


func test_turno_899_borde_es_manana() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Act / Assert — 14:59 → MAÑANA (borde superior exclusivo de tarde-1).
	assert_int(tiempo.turno_de(899.0)).is_equal(tiempo.Turno.MANANA)


func test_turno_1379_borde_es_tarde() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Act / Assert — 22:59 → TARDE (borde superior exclusivo de noche-1).
	assert_int(tiempo.turno_de(1379.0)).is_equal(tiempo.Turno.TARDE)


func test_turno_1380_borde_es_noche() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Act / Assert — 23:00 → NOCHE (borde inferior inclusivo de noche).
	assert_int(tiempo.turno_de(1380.0)).is_equal(tiempo.Turno.NOCHE)


# ── es_de_noche (AC-T13..T15) ──────────────────────────────────────────────────────────────
func test_es_de_noche_1381_es_true() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Act / Assert — 23:01 → true (AC-T13).
	assert_bool(tiempo.es_de_noche(1381.0)).is_true()


func test_es_de_noche_419_es_true() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Act / Assert — 06:59 → true (aún noche, antes del inicio de mañana) (AC-T14).
	assert_bool(tiempo.es_de_noche(419.0)).is_true()


func test_es_de_noche_420_es_false() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Act / Assert — 07:00 → false (empieza mañana) (AC-T15).
	assert_bool(tiempo.es_de_noche(420.0)).is_false()


# ── Coherencia del enum con EventBus.cambio_de_turno(turno: int) (0/1/2) ───────────────────
func test_enum_turno_valores_coherentes_con_bus() -> void:
	# Arrange
	var tiempo: Node = _nuevo_tiempo()
	# Assert — 0=mañana, 1=tarde, 2=noche (el int que viaja por el bus, H4).
	assert_int(tiempo.Turno.MANANA).is_equal(0)
	assert_int(tiempo.Turno.TARDE).is_equal(1)
	assert_int(tiempo.Turno.NOCHE).is_equal(2)
