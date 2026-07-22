# Story 004 (epic datos) — Catálogo MVP de Pozuelo · TR-data-001 · ADR-0003
# Smoke de integración: carga el catálogo REAL de `res://datos/` (generado por tools/build_catalogo.gd),
# lo valida limpio y hace spot-check de los valores semilla del GDD (data-config.md F1–F7 + AC-D16/D18/D20).
# Tipo: Integration (carga real desde disco + singleton). DETERMINISTA (sin RNG ni reloj real).
# Convenciones: test_[escenario]_[esperado], Arrange/Act/Assert (ver tests/README.md y .claude/rules).
#
# Acceso al autoload: por NOMBRE (`Datos`), no por instancia nueva — igual que datos_carga_lookup_test.gd.
# El runner de GdUnit4 arranca el proyecto completo, así que el autoload registrado en project.godot está
# vivo y ya cargó e indexó su catálogo en `_ready`. Es la MISMA instancia compartida (fuente única, R1): una
# instancia nueva del script daría otra referencia y no probaría el catálogo real cargado en arranque.
extends GdUnitTestSuite


# AC-1 (AC-D20, limpio): con el catálogo real cargado, la validación de integridad devuelve `[]` — 0 refs
# colgantes, 0 ids duplicados, 0 valores fuera de rango, todo servicio activo con puesto que lo atienda.
# NOTA R5: `validar()` con el `demanda_max_odac=0` por defecto NO evalúa el invariante de solvencia R5
# (AC-D12/D13): la fórmula de demanda vive fuera de Datos. R5 se comprobará cuando exista Demanda y pase su
# estimación real; para el smoke del catálogo, `[]` con demanda 0 es la condición correcta.
func test_validar_catalogo_real_no_devuelve_problemas() -> void:
	# Act
	var problemas: Array[String] = Datos.validar()
	# Assert
	assert_array(problemas).is_empty()


# AC-2 (AC-D01): el trámite `dni` (F1) tiene sus valores exactos tras cargar del catálogo real.
func test_obtener_tramite_dni_devuelve_valores_de_f1() -> void:
	# Act
	var dni: Resource = Datos.obtener(&"TramiteDoc", &"dni")
	# Assert
	assert_object(dni).is_not_null()
	assert_int(dni.duracion_min).is_equal(12)
	assert_int(dni.tarifa_eur).is_equal(12)


# AC-3 (conteo): hay 14 DenunciaODAC = 13 ciudadanas (F2) + 1 interna `reclamacion` (Hoja de reclamaciones,
# 14ª — decisión usuario 2026-07-22; la genera Paciencia PS13, NO la demanda ciudadana). La `reclamacion`
# existe como definición con `duracion_min=30` y `prioridad="Normal"` (F2 "Atención especial").
func test_obtener_todos_denuncias_hay_catorce_con_reclamacion() -> void:
	# Act
	var denuncias: Array = Datos.obtener_todos(&"DenunciaODAC")
	var reclamacion: Resource = Datos.obtener(&"DenunciaODAC", &"reclamacion")
	# Assert
	assert_int(denuncias.size()).is_equal(14)
	assert_object(reclamacion).is_not_null()
	assert_int(reclamacion.duracion_min).is_equal(30)
	assert_str(reclamacion.prioridad).is_equal("Normal")


# AC-4 (AC-D16): el Escenario `pozuelo` (F7) tiene población, servicios activos, nivel y topes de F7.
func test_obtener_escenario_pozuelo_devuelve_valores_de_f7() -> void:
	# Act
	var pozuelo: Resource = Datos.obtener(&"Escenario", &"pozuelo")
	# Assert
	assert_object(pozuelo).is_not_null()
	assert_int(pozuelo.poblacion).is_equal(90000)
	assert_str(pozuelo.nivel).is_equal("Nivel 1 — Comisaría Local")
	assert_array(pozuelo.servicios_activos).contains([&"Documentacion", &"ODAC"])
	# Topes de construcción por id de TipoPuesto (F7): Doc≤8 · TIE≤2 · ODAC≤4 · Entrada 1.
	assert_dict(pozuelo.tope_construible).contains_key_value(&"puesto_doc_general", 8)
	assert_dict(pozuelo.tope_construible).contains_key_value(&"puesto_tie", 2)
	assert_dict(pozuelo.tope_construible).contains_key_value(&"puesto_odac", 4)
	assert_dict(pozuelo.tope_construible).contains_key_value(&"puesto_seguridad", 1)


# AC-5 (AC-D18): la sala de espera de Documentación tiene aforo 40 (F4).
func test_obtener_sala_espera_doc_aforo_es_cuarenta() -> void:
	# Act
	var sala: Resource = Datos.obtener(&"TipoSala", &"sala_espera_doc")
	# Assert
	assert_object(sala).is_not_null()
	assert_int(sala.aforo_espera).is_equal(40)


# Extra (integridad de la decisión `reclamacion`): `puesto_odac` DEBE admitir las 14 atenciones de ODAC
# (13 ciudadanas + `reclamacion`) y ser reconfigurable. Que admita `reclamacion` es lo que hace que la
# validación de integridad referencial pase (AC-1) y que Paciencia (PS13) pueda encolarla en ODAC.
func test_puesto_odac_admite_las_catorce_atenciones_incluida_reclamacion() -> void:
	# Arrange — las 14 atenciones de ODAC esperadas (13 denuncias ciudadanas + la interna `reclamacion`).
	var esperadas: Array[StringName] = [
		&"viogen", &"lesiones", &"estafa", &"hurto_robo", &"amenazas", &"danos",
		&"perdida_sustraccion", &"permiso_viaje", &"desaparecidos", &"agresion_sexual",
		&"robo_violencia", &"okupacion", &"ciberestafa", &"reclamacion",
	]
	# Act
	var puesto_odac: Resource = Datos.obtener(&"TipoPuesto", &"puesto_odac")
	# Assert
	assert_object(puesto_odac).is_not_null()
	assert_bool(puesto_odac.reconfigurable).is_true()
	assert_int(puesto_odac.atenciones_admitidas.size()).is_equal(14)
	assert_array(puesto_odac.atenciones_admitidas).contains(esperadas)
