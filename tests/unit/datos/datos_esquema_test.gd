# Story 001 (epic datos) — esquema del catálogo · ADR-0003 / TR-data-002
# Clases Resource del catálogo: SOLO estructura (jerarquía + campos). Tipo: Logic. DETERMINISTA.
# No verifica valores (eso es la Story 004): comprueba herencia y presencia de propiedades.
# Gotcha: `class_name` puede no resolverse en headless "en frío" -> se usa preload como const
# y `obj is <ConstScript>` (funciona con la constante preloaded).
extends GdUnitTestSuite

const AtencionScript := preload("res://src/foundation/datos/esquema/atencion.gd")
const TramiteDocScript := preload("res://src/foundation/datos/esquema/tramite_doc.gd")
const DenunciaODACScript := preload("res://src/foundation/datos/esquema/denuncia_odac.gd")
const TipoPuestoScript := preload("res://src/foundation/datos/esquema/tipo_puesto.gd")
const TipoSalaScript := preload("res://src/foundation/datos/esquema/tipo_sala.gd")
const TipoAgenteScript := preload("res://src/foundation/datos/esquema/tipo_agente.gd")
const CostesScript := preload("res://src/foundation/datos/esquema/costes.gd")
const EscenarioScript := preload("res://src/foundation/datos/esquema/escenario.gd")


# AC-1: la jerarquía es correcta — TramiteDoc y DenunciaODAC son Atencion; Atencion es Resource.
func test_jerarquia_atenciones_es_correcta() -> void:
	# Arrange + Act
	var atencion: Resource = AtencionScript.new()
	var tramite: Resource = TramiteDocScript.new()
	var denuncia: Resource = DenunciaODACScript.new()
	# Assert
	assert_bool(atencion is Resource).is_true()
	assert_bool(tramite is AtencionScript).is_true()
	assert_bool(denuncia is AtencionScript).is_true()


# AC-2: TramiteDoc tiene sus campos propios (tarifa_eur, requiere_cita) y los heredados de Atencion.
func test_tramite_doc_tiene_campos_propios_y_heredados() -> void:
	# Arrange
	var t: Resource = TramiteDocScript.new()
	# Assert — propios
	assert_bool("tarifa_eur" in t).is_true()
	assert_bool("requiere_cita" in t).is_true()
	# Assert — heredados de Atencion
	assert_bool("id" in t).is_true()
	assert_bool("nombre" in t).is_true()
	assert_bool("servicio" in t).is_true()
	assert_bool("duracion_min" in t).is_true()
	assert_bool("tipo_puesto" in t).is_true()
	assert_bool("icono" in t).is_true()


# AC-3: DenunciaODAC tiene prioridad y admite_cita, y NO tiene tarifa_eur (las denuncias no cobran).
func test_denuncia_odac_tiene_prioridad_y_no_tarifa() -> void:
	# Arrange
	var d: Resource = DenunciaODACScript.new()
	# Assert — propios
	assert_bool("prioridad" in d).is_true()
	assert_bool("admite_cita" in d).is_true()
	# Assert — hereda Atencion pero NO tarifa_eur
	assert_bool("id" in d).is_true()
	assert_bool("tarifa_eur" in d).is_false()


# AC-4: atenciones_admitidas acepta un Array[StringName] de ids y se lee igual (referencias por id).
func test_tipo_puesto_referencia_atenciones_por_id() -> void:
	# Arrange
	var puesto: Resource = TipoPuestoScript.new()
	var ids: Array[StringName] = [&"dni", &"pasaporte"]
	# Act
	puesto.atenciones_admitidas = ids
	# Assert
	assert_array(puesto.atenciones_admitidas).contains_exactly([&"dni", &"pasaporte"])


# Estructural: TipoPuesto expone todos sus campos del esquema.
func test_tipo_puesto_expone_sus_campos() -> void:
	# Arrange
	var p: Resource = TipoPuestoScript.new()
	# Assert
	for campo in ["id", "nombre", "servicio", "atenciones_admitidas", "reconfigurable",
			"coste_construccion_eur", "plazas_agente", "superficie", "icono"]:
		assert_bool(campo in p).is_true()


# Estructural: TipoSala expone todos sus campos del esquema.
func test_tipo_sala_expone_sus_campos() -> void:
	# Arrange
	var s: Resource = TipoSalaScript.new()
	# Assert
	for campo in ["id", "nombre", "tipo", "servicio", "puestos_admitidos", "aforo_espera",
			"coste_construccion_eur", "superficie", "icono"]:
		assert_bool(campo in s).is_true()


# Estructural: TipoAgente expone todos sus campos del esquema.
func test_tipo_agente_expone_sus_campos() -> void:
	# Arrange
	var a: Resource = TipoAgenteScript.new()
	# Assert
	for campo in ["id", "puesto_organico", "unidad", "escala_rango", "salario_dia_eur",
			"tipo_horario", "puestos_operables"]:
		assert_bool(campo in a).is_true()


# Estructural: Costes expone sus campos (incluido el id añadido para indexado uniforme en Story 002).
func test_costes_expone_sus_campos() -> void:
	# Arrange
	var c: Resource = CostesScript.new()
	# Assert
	for campo in ["id", "peonada_eur_hora", "retorno_dgp_min", "retorno_dgp_max"]:
		assert_bool(campo in c).is_true()


# Estructural: Escenario expone todos sus campos del esquema.
func test_escenario_expone_sus_campos() -> void:
	# Arrange
	var e: Resource = EscenarioScript.new()
	# Assert
	for campo in ["id", "nombre", "nivel", "poblacion", "tope_construible", "rango_requerido",
			"servicios_activos"]:
		assert_bool(campo in e).is_true()
