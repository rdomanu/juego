# Story 002 (epic datos) — TR-data-001/002/004 · ADR-0003
# Carga del catálogo desde disco (res://datos/) + lookup por `id` vía el autoload `Datos`.
# Tipo: Integration (carga real desde disco + singleton). DETERMINISTA (sin RNG ni reloj real).
# Convenciones: test_[escenario]_[esperado], Arrange/Act/Assert (ver tests/README.md).
#
# Acceso al autoload: por NOMBRE (`Datos`), no por instancia nueva. El runner de GdUnit4 arranca el
# proyecto completo, así que el autoload registrado en project.godot está vivo y ya cargó su catálogo en
# `_ready`. Es lo que exige AC-4: la MISMA instancia compartida (fuente única) — una instancia nueva del
# script daría otra referencia y no probaría el singleton real.
extends GdUnitTestSuite


# AC-1 (AC-D01): cargado el catálogo, los 3 trámites tienen sus valores exactos de F1.
func test_obtener_tramite_dni_devuelve_valores_de_f1() -> void:
	# Act
	var dni: Resource = Datos.obtener(&"TramiteDoc", &"dni")
	# Assert
	assert_object(dni).is_not_null()
	assert_int(dni.duracion_min).is_equal(12)
	assert_int(dni.tarifa_eur).is_equal(12)


func test_obtener_tramite_pasaporte_devuelve_valores_de_f1() -> void:
	# Act
	var pasaporte: Resource = Datos.obtener(&"TramiteDoc", &"pasaporte")
	# Assert
	assert_object(pasaporte).is_not_null()
	assert_int(pasaporte.duracion_min).is_equal(15)
	assert_int(pasaporte.tarifa_eur).is_equal(30)


func test_obtener_tramite_tie_devuelve_valores_de_f1() -> void:
	# Act
	var tie: Resource = Datos.obtener(&"TramiteDoc", &"tie")
	# Assert
	assert_object(tie).is_not_null()
	assert_int(tie.duracion_min).is_equal(15)
	assert_int(tie.tarifa_eur).is_equal(18)


# AC-2 (lookup inexistente): un id que no existe devuelve null SIN romper (registra warning).
func test_obtener_id_inexistente_devuelve_null_sin_romper() -> void:
	# Act
	var faltante: Resource = Datos.obtener(&"TramiteDoc", &"no_existe")
	# Assert
	assert_object(faltante).is_null()


# AC-3 (obtener_todos): el catálogo MVP tiene 14 DenunciaODAC = 13 ciudadanas de F2 + 1 interna
# `reclamacion` (Hoja de reclamaciones, modelada como 14ª DenunciaODAC — decisión usuario 2026-07-22;
# la genera Paciencia PS13, no la demanda ciudadana).
func test_obtener_todos_denuncias_hay_catorce() -> void:
	# Act
	var denuncias: Array = Datos.obtener_todos(&"DenunciaODAC")
	# Assert
	assert_int(denuncias.size()).is_equal(14)


# AC-4 (AC-D03, fuente única): dos llamadas al mismo id devuelven LA MISMA instancia (referencia única).
func test_obtener_dos_veces_dni_devuelve_la_misma_instancia() -> void:
	# Act
	var a: Resource = Datos.obtener(&"TramiteDoc", &"dni")
	var b: Resource = Datos.obtener(&"TramiteDoc", &"dni")
	# Assert
	assert_object(a).is_same(b)
