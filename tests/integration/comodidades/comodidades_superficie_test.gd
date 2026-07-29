# Bug corregido 2026-07-29 (petición del usuario, jugando): "el sofá de 3 plazas debe ocupar 3
# huecos, ahora solo ocupa 1, se amontonan". El esquema `Comodidad` ya tenía `superficie`
# (celdas que ocupa) pero NADIE lo leía: todo ocupaba 1 celda sin importar el valor. Tipo:
# Integration. DETERMINISTA (catálogo REAL, sin azar ni reloj).
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")

const SOFA := &"sofa_descanso"      # superficie 3 (3 plazas)
const SILLAS := &"sillas_office"    # superficie 2 (2 plazas)


# ── Fixture ──────────────────────────────────────────────────────────────────────────────
## Comisaría mínima: una sala de descanso (0,0)-(4,3) (12 celdas, columnas 0..3) con caja de sobra.
## Devuelve [construccion, economia].
func _mundo() -> Array:
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	economia.saldo_eur = 100000.0
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(economia)
	construccion.construir_de_oficio_sala(&"sala_descanso", Rect2i(0, 0, 4, 3))
	return [construccion, economia]


# ── El catálogo trae las superficies pedidas por el usuario ──────────────────────────────
func test_el_catalogo_trae_las_superficies_pedidas() -> void:
	assert_int(Datos.obtener(&"Comodidad", SOFA).superficie).is_equal(3)
	assert_int(Datos.obtener(&"Comodidad", SILLAS).superficie).is_equal(2)
	# El resto del catálogo se queda en el default 1 (muestreo de un par).
	assert_int(Datos.obtener(&"Comodidad", &"nevera").superficie).is_equal(1)
	assert_int(Datos.obtener(&"Comodidad", &"television").superficie).is_equal(1)


# ── Un sofá de superficie 3 ocupa las 3 celdas de su cuerpo, no solo el ancla ─────────────
func test_el_sofa_ocupa_las_tres_celdas_no_solo_el_ancla() -> void:
	var construccion: Node = _mundo()[0]

	var id: StringName = construccion.construir_elemento(SOFA, Vector2i(0, 0))

	assert_str(String(id)).is_not_equal("")
	# Las 3 celdas del cuerpo (0,0)-(2,0) quedan ocupadas: nada más (misma familia "descanso") cabe ahí.
	assert_bool(construccion.validar_elemento(&"nevera", Vector2i(0, 0))).is_false()
	assert_bool(construccion.validar_elemento(&"nevera", Vector2i(1, 0))).is_false()
	assert_bool(construccion.validar_elemento(&"nevera", Vector2i(2, 0))).is_false()
	# La celda 3 (fuera del cuerpo del sofá) sigue libre.
	assert_bool(construccion.validar_elemento(&"nevera", Vector2i(3, 0))).is_true()


# ── Las sillas de superficie 2 ocupan 2 celdas (no 3, no 1) ───────────────────────────────
func test_las_sillas_ocupan_dos_celdas() -> void:
	var construccion: Node = _mundo()[0]

	var id: StringName = construccion.construir_elemento(SILLAS, Vector2i(0, 0))

	assert_str(String(id)).is_not_equal("")
	assert_bool(construccion.validar_elemento(&"nevera", Vector2i(0, 0))).is_false()
	assert_bool(construccion.validar_elemento(&"nevera", Vector2i(1, 0))).is_false()
	assert_bool(construccion.validar_elemento(&"nevera", Vector2i(2, 0))).is_true()


# ── No se puede colocar si no caben las 3 celdas: ni saliéndose de la sala ni pisando otro objeto ──
func test_no_se_puede_colocar_si_no_caben_las_tres_celdas() -> void:
	var construccion: Node = _mundo()[0]

	# Pegado al borde derecho de la sala (columnas 0..3): el cuerpo (ancla + 2) se saldría fuera.
	assert_bool(construccion.validar_elemento(SOFA, Vector2i(2, 0))).is_false()

	# Otro objeto ya ocupa una celda del MEDIO del cuerpo: rechazado aunque el ancla esté libre.
	construccion.construir_elemento(&"nevera", Vector2i(1, 0))
	assert_bool(construccion.validar_elemento(SOFA, Vector2i(0, 0))).is_false()


# ── Al demoler se liberan las 3 celdas, no solo el ancla ──────────────────────────────────
func test_demoler_libera_las_tres_celdas() -> void:
	var construccion: Node = _mundo()[0]
	var id: StringName = construccion.construir_elemento(SOFA, Vector2i(0, 0))

	assert_bool(construccion.demoler_elemento(id)).is_true()

	assert_bool(construccion.validar_elemento(&"nevera", Vector2i(0, 0))).is_true()
	assert_bool(construccion.validar_elemento(&"nevera", Vector2i(1, 0))).is_true()
	assert_bool(construccion.validar_elemento(&"nevera", Vector2i(2, 0))).is_true()


# ── El precio NO cambia por ocupar más celdas (gate E4 de Economía — 550 € ocupe lo que ocupe) ──
func test_el_precio_no_cambia_por_ocupar_mas_celdas() -> void:
	var mundo: Array = _mundo()
	var construccion: Node = mundo[0]
	var economia: Node = mundo[1]
	var saldo_antes: float = economia.saldo_eur

	construccion.construir_elemento(SOFA, Vector2i(0, 0))

	assert_float(economia.saldo_eur).is_equal_approx(saldo_antes - 550.0, 0.001)


# ── Persistencia: el cuerpo se RECALCULA desde el catálogo al cargar, no se guarda ────────
func test_sofa_sobrevive_a_guardar_y_cargar() -> void:
	var a: Node = _mundo()[0]
	var id: StringName = a.construir_elemento(SOFA, Vector2i(0, 0))
	# Round-trip por JSON real (full_precision), el camino del SaveManager.
	var foto: Dictionary = JSON.parse_string(JSON.stringify(a.save(), "", true, true))

	var economia_b: Node = auto_free(EconomiaScript.new())
	economia_b.aplicar_config(ConfigEconomiaScript.new())
	var b: Node = auto_free(ConstruccionScript.new())
	b.aplicar_config(ConfigConstruccionScript.new())
	b.usar_economia(economia_b)
	b.load_state(foto)

	# El sofá cargado SIGUE ocupando sus 3 celdas: el cuerpo se recalcula desde `superficie` del
	# catálogo vigente (no se guardó — ver el comentario de `save()` en construccion.gd).
	assert_bool(b._elementos.has(id)).is_true()
	assert_bool(b.validar_elemento(&"nevera", Vector2i(1, 0))).is_false()
	assert_bool(b.validar_elemento(&"nevera", Vector2i(3, 0))).is_true()
