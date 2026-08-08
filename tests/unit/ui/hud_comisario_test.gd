# HudComisario (reconstrucción total del HUD, 2026-08-08 -- `design/ux/hud-design.md`). Cubre el
# CONTRATO que `main.gd` da por hecho: el árbol de nodos nace poblado (mismo patrón que
# `modo_construccion_barra_categorias_test.gd`: instanciar, comprobar estructuras pobladas -- sin
# motor gráfico, sin capturas), los 5 botones de acción emiten sus señales (upward communication,
# coding standards del proyecto) y `ocultar_acciones()`/`refrescar()` no revientan sin sistemas
# inyectados (arranque parcial, tests).
#
# Tipo: Logic/UI. DETERMINISTA — sin reloj real, sin red, sin aleatoriedad.
extends GdUnitTestSuite

const HudComisarioScript := preload("res://src/ui/hud_comisario.gd")


func _hud() -> HudComisario:
	var hud: HudComisario = auto_free(HudComisarioScript.new())
	add_child(hud)   # dispara `_ready()` -> construye los dos paneles.
	return hud


# ── Árbol de nodos ────────────────────────────────────────────────────────────────────────────

## Los 7 grupos de la franja superior nacen poblados (Labels no nulos) sin necesitar `configurar()`
## -- el árbol de nodos no depende de tener sistemas Core inyectados, solo `refrescar()` los usa.
func test_construye_los_7_grupos_de_la_franja_superior() -> void:
	var hud := _hud()

	assert_object(hud._lbl_hora).is_not_null()
	assert_object(hud._lbl_fecha_turno).is_not_null()
	assert_int(hud._botones_velocidad.size()).is_equal(4)
	assert_int(hud._pips_velocidad.size()).is_equal(4)
	assert_object(hud._boton_3x).is_not_null()
	assert_object(hud._lbl_saldo).is_not_null()
	assert_object(hud._lbl_estado_fin).is_not_null()
	assert_object(hud._lbl_satisfaccion).is_not_null()
	assert_object(hud._lbl_reclamaciones).is_not_null()
	assert_object(hud._lbl_demanda_nivel).is_not_null()
	assert_object(hud._lbl_llegadas).is_not_null()
	assert_object(hud._lbl_plantilla).is_not_null()
	assert_object(hud._lbl_nomina).is_not_null()
	assert_object(hud._lbl_doc_cola).is_not_null()
	assert_object(hud._lbl_doc_atendiendo).is_not_null()


## Las 6 píldoras de la franja de acciones nacen en el orden del wireframe (spec §6 + opción A del
## veredicto 2026-08-09): Construir, Personal, Horario, Guardar, Cargar, Paredes.
func test_franja_de_acciones_tiene_las_6_pildoras_en_orden() -> void:
	var hud := _hud()

	assert_int(hud._botones_acciones.size()).is_equal(6)
	for boton: Button in hud._botones_acciones:
		assert_object(boton).is_not_null()
	assert_object(hud._lbl_aviso).is_not_null()
	assert_object(hud._lbl_paredes).is_not_null()


# ── Señales (upward communication, coding standards del proyecto) ───────────────────────────────

## Cada píldora emite SU señal -- `Main` las reconecta a los callbacks existentes
## (`_abrir_personal`/`_abrir_horario`/`_guardar_partida`/`_cargar_partida`/
## `_alternar_modo_paredes`), pero esta clase no debe ejecutar nada por sí misma (ADR-0001).
func test_las_6_pildoras_emiten_su_senal_al_pulsarlas() -> void:
	var hud := _hud()
	var recibidas: Array[StringName] = []
	hud.construccion_solicitada.connect(func() -> void: recibidas.append(&"construccion"))
	hud.personal_solicitado.connect(func() -> void: recibidas.append(&"personal"))
	hud.horario_solicitado.connect(func() -> void: recibidas.append(&"horario"))
	hud.guardar_solicitado.connect(func() -> void: recibidas.append(&"guardar"))
	hud.cargar_solicitado.connect(func() -> void: recibidas.append(&"cargar"))
	hud.paredes_solicitado.connect(func() -> void: recibidas.append(&"paredes"))

	for boton: Button in hud._botones_acciones:
		boton.pressed.emit()

	assert_array(recibidas).is_equal(
		[&"construccion", &"personal", &"horario", &"guardar", &"cargar", &"paredes"]
		as Array[StringName]
	)


# ── Visibilidad (spec §1: la franja superior NUNCA se oculta) ───────────────────────────────────

func test_ocultar_acciones_oculta_solo_la_franja_inferior() -> void:
	var hud := _hud()

	hud.ocultar_acciones(true)

	assert_bool(hud._panel_superior.visible).is_true()
	assert_bool(hud._panel_acciones.visible).is_false()

	hud.ocultar_acciones(false)

	assert_bool(hud._panel_acciones.visible).is_true()


# ── Refresco defensivo ────────────────────────────────────────────────────────────────────────

## Sin `configurar()` (sistemas Core todos `null`, arranque parcial / test aislado): `refrescar()`
## no revienta -- cada sección se protege por separado (ver la cabecera de `HudComisario.refrescar`).
func test_refrescar_sin_configurar_no_revienta() -> void:
	var hud := _hud()

	hud.refrescar()

	assert_str(hud._lbl_hora.text).is_not_empty()   # el reloj SÍ lee `Tiempo` (autoload), sin gap.


## `avisar()` pinta el mensaje transitorio (Guardar/Cargar/Paredes) en su propio Label -- mismo rol
## que el viejo `_lbl_guardado`, ahora encapsulado.
func test_avisar_escribe_el_texto_en_el_label_transitorio() -> void:
	var hud := _hud()

	hud.avisar("Guardado a las 12:00", Color.WHITE)

	assert_str(hud._lbl_aviso.text).is_equal("Guardado a las 12:00")
