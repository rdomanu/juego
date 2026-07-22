# Story 003 (epic datos) — validación en carga del catálogo · TR-data-003 / ADR-0003.
# Clases: los 7 chequeos de `Datos.validar()` (integridad referencial, ids duplicados, clamp de rangos,
# invariante R5, catálogo limpio). Tipo: Logic. DETERMINISTA (sin azar, sin reloj, sin tocar disco).
#
# Estrategia de fixtures EN MEMORIA: se instancia el script del autoload `datos.gd` con `.new()` SIN
# añadirlo al árbol (así NO corre su `_ready`, que cargaría el catálogo real de `res://datos/`), se pone en
# `modo_desarrollo = false` (modo jugador: degradación segura y determinista), se construyen definiciones
# con los scripts del esquema preload-ados POR RUTA (mismo gotcha del `class_name` en frío que Story 001/002),
# se indexan con `_indexar(...)` y se llama `validar(...)`. `auto_free(...)` libera cada Resource/Node.
extends GdUnitTestSuite

const DatosScript := preload("res://src/foundation/datos/datos.gd")
const TramiteDocScript := preload("res://src/foundation/datos/esquema/tramite_doc.gd")
const DenunciaODACScript := preload("res://src/foundation/datos/esquema/denuncia_odac.gd")
const TipoPuestoScript := preload("res://src/foundation/datos/esquema/tipo_puesto.gd")
const TipoSalaScript := preload("res://src/foundation/datos/esquema/tipo_sala.gd")
const CostesScript := preload("res://src/foundation/datos/esquema/costes.gd")
const EscenarioScript := preload("res://src/foundation/datos/esquema/escenario.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Instancia el autoload en modo jugador (degradación), sin árbol → sin `_ready` → índice vacío.
func _nuevo_datos() -> Node:
	var datos: Node = auto_free(DatosScript.new())
	datos.modo_desarrollo = false
	return datos


## TramiteDoc mínimo coherente.
func _tramite(id: StringName, dur: int = 12, tarifa: int = 12, tipo_puesto: StringName = &"") -> Resource:
	var t: Resource = auto_free(TramiteDocScript.new())
	t.id = id
	t.nombre = String(id)
	t.servicio = "Documentacion"
	t.duracion_min = dur
	t.tarifa_eur = tarifa
	t.tipo_puesto = tipo_puesto
	return t


## DenunciaODAC mínima coherente.
func _denuncia(id: StringName, dur: int = 30, tipo_puesto: StringName = &"") -> Resource:
	var d: Resource = auto_free(DenunciaODACScript.new())
	d.id = id
	d.nombre = String(id)
	d.servicio = "ODAC"
	d.duracion_min = dur
	d.prioridad = "Normal"
	d.tipo_puesto = tipo_puesto
	return d


## TipoPuesto mínimo coherente.
func _puesto(
	id: StringName, servicio: String = "Documentacion",
	atenciones: Array[StringName] = [], coste: int = 500
) -> Resource:
	var p: Resource = auto_free(TipoPuestoScript.new())
	p.id = id
	p.nombre = String(id)
	p.servicio = servicio
	p.atenciones_admitidas = atenciones
	p.coste_construccion_eur = coste
	return p


## Escenario mínimo coherente.
func _escenario(
	id: StringName, servicios: Array[StringName] = [],
	tope: Dictionary[StringName, int] = {}
) -> Resource:
	var e: Resource = auto_free(EscenarioScript.new())
	e.id = id
	e.nombre = String(id)
	e.poblacion = 90000
	e.servicios_activos = servicios
	e.tope_construible = tope
	return e


## Costes mínimo coherente.
func _costes(peonada: float = 15.0, dgp_min: float = 0.15, dgp_max: float = 0.45) -> Resource:
	var c: Resource = auto_free(CostesScript.new())
	c.id = &"costes_global"
	c.peonada_eur_hora = peonada
	c.retorno_dgp_min = dgp_min
	c.retorno_dgp_max = dgp_max
	return c


## True si algún mensaje de la lista contiene la subcadena buscada.
func _contiene(msgs: Array, aguja: String) -> bool:
	for m: String in msgs:
		if m.contains(aguja):
			return true
	return false


# ── AC-1 (AC-D06): referencia colgante en atenciones_admitidas ────────────────────────────
func test_atencion_admitida_inexistente_reporta_referencia_colgante() -> void:
	# Arrange — un puesto que admite una atención que no existe en el catálogo.
	var datos: Node = _nuevo_datos()
	datos._indexar(_puesto(&"puesto_x", "Documentacion", [&"no_existe"]))

	# Act
	var msgs: Array[String] = datos.validar()

	# Assert — se reporta y el mensaje nombra el id colgante.
	assert_bool(_contiene(msgs, "no_existe")).is_true()


# ── AC-2 (AC-D07): id duplicado dentro de un tipo ─────────────────────────────────────────
func test_tramite_duplicado_reporta_duplicado_y_gana_el_primero() -> void:
	# Arrange — dos TramiteDoc con el mismo id 'dni'; el primero tiene tarifa 12, el segundo 99.
	var datos: Node = _nuevo_datos()
	var primero: Resource = _tramite(&"dni", 12, 12)
	var segundo: Resource = _tramite(&"dni", 15, 99)
	datos._indexar(primero)
	datos._indexar(segundo)

	# Act
	var msgs: Array[String] = datos.validar()

	# Assert — se reporta el duplicado y `obtener` devuelve la PRIMERA definición (gana el primero).
	assert_bool(_contiene(msgs, "duplicado")).is_true()
	assert_bool(_contiene(msgs, "dni")).is_true()
	assert_object(datos.obtener(&"TramiteDoc", &"dni")).is_same(primero)


# ── AC-3 (AC-D09): duracion_min = 0 → clamp a 1 ───────────────────────────────────────────
func test_duracion_cero_se_clampa_a_uno_con_aviso() -> void:
	# Arrange
	var datos: Node = _nuevo_datos()
	var tramite: Resource = _tramite(&"dni", 0)
	datos._indexar(tramite)

	# Act
	var msgs: Array[String] = datos.validar()

	# Assert — el valor queda en 1 y hay aviso.
	assert_int(tramite.duracion_min).is_equal(1)
	assert_bool(_contiene(msgs, "duracion_min")).is_true()


# ── AC-4 (AC-D10): retorno_dgp fuera de [0,1] → clamp ─────────────────────────────────────
func test_retorno_dgp_fuera_de_rango_se_clampa_con_aviso() -> void:
	# Arrange — min negativo, max > 1.
	var datos: Node = _nuevo_datos()
	var costes: Resource = _costes(15.0, -0.2, 1.5)
	datos._indexar(costes)

	# Act
	var msgs: Array[String] = datos.validar()

	# Assert — quedan 0.0 y 1.0 con aviso.
	assert_float(costes.retorno_dgp_min).is_equal_approx(0.0, 0.0001)
	assert_float(costes.retorno_dgp_max).is_equal_approx(1.0, 0.0001)
	assert_bool(_contiene(msgs, "retorno_dgp")).is_true()


# ── AC-5 (AC-D11): coste_construccion_eur negativo → 0 ────────────────────────────────────
func test_coste_construccion_negativo_se_clampa_a_cero_con_aviso() -> void:
	# Arrange
	var datos: Node = _nuevo_datos()
	var puesto: Resource = _puesto(&"puesto_x", "Documentacion", [], -100)
	datos._indexar(puesto)

	# Act
	var msgs: Array[String] = datos.validar()

	# Assert — el coste queda en 0 y hay aviso.
	assert_int(puesto.coste_construccion_eur).is_equal(0)
	assert_bool(_contiene(msgs, "coste_construccion_eur")).is_true()


# ── AC-6 (AC-D13, R5): capacidad < D → WARNING nombrando el escenario, sin abortar ────────
func test_r5_capacidad_insuficiente_emite_warning_sin_abortar() -> void:
	# Arrange — 1 puesto ODAC (tope 1) y una denuncia de 30 min → capacidad ≈ 1×(960/30)=32/día.
	# Con una demanda estimada de 500/día, la capacidad es insuficiente y debe avisar.
	var datos: Node = _nuevo_datos()
	datos._indexar(_puesto(&"puesto_odac", "ODAC", [&"lesiones"]))
	datos._indexar(_denuncia(&"lesiones", 30, &"puesto_odac"))
	var tope: Dictionary[StringName, int] = {&"puesto_odac": 1}
	datos._indexar(_escenario(&"pozuelo", [&"ODAC"], tope))

	# Act — se pasa una estimación de demanda alta.
	var msgs: Array[String] = datos.validar(500)

	# Assert — hay un WARNING de R5 que nombra el escenario; `validar` devolvió la lista (no rompió).
	assert_bool(_contiene(msgs, "R5")).is_true()
	assert_bool(_contiene(msgs, "pozuelo")).is_true()


# ── AC-7 (limpio): fixture coherente → validar() devuelve [] ──────────────────────────────
func test_catalogo_coherente_valida_sin_problemas() -> void:
	# Arrange — un mini-catálogo internamente consistente: un puesto que admite un trámite existente,
	# el trámite apunta a ese puesto, una sala que admite el puesto, un escenario con tope válido y
	# servicio operable, y unos costes en rango. R5 no se evalúa (demanda_max_odac por defecto = 0).
	var datos: Node = _nuevo_datos()
	datos._indexar(_puesto(&"puesto_doc_general", "Documentacion", [&"dni"]))
	datos._indexar(_tramite(&"dni", 12, 12, &"puesto_doc_general"))
	var sala: Resource = auto_free(TipoSalaScript.new())
	sala.id = &"sala_documentacion"
	sala.nombre = "Oficina de Documentación"
	sala.tipo = "oficina"
	sala.servicio = "Documentacion"
	sala.puestos_admitidos = [&"puesto_doc_general"] as Array[StringName]
	datos._indexar(sala)
	datos._indexar(_costes())
	var tope: Dictionary[StringName, int] = {&"puesto_doc_general": 8}
	datos._indexar(_escenario(&"pozuelo", [&"Documentacion"], tope))

	# Act
	var msgs: Array[String] = datos.validar()

	# Assert — catálogo limpio: sin mensajes.
	assert_array(msgs).is_empty()


# ── AC-8 (dev NO degrada): modo desarrollo reporta ref colgante pero NO filtra la lista ────
func test_modo_desarrollo_reporta_sin_degradar() -> void:
	# Arrange — en modo desarrollo el fallo es RUIDOSO pero NO oculta: la ref colgante se reporta
	# y la lista NO se filtra (contraste con modo jugador, que la descartaría). Un puesto que admite
	# una atención inexistente.
	var datos: Node = _nuevo_datos()
	datos.modo_desarrollo = true
	var puesto: Resource = _puesto(&"puesto_x", "Documentacion", [&"no_existe"])
	datos._indexar(puesto)

	# Act
	var msgs: Array[String] = datos.validar()

	# Assert — se reporta la ref colgante nombrándola PERO la lista sigue conteniéndola (no degrada).
	assert_bool(_contiene(msgs, "no_existe")).is_true()
	assert_array(puesto.atenciones_admitidas).contains([&"no_existe"])


# ── AC-9 (AC-D12, R5): capacidad >= D → NO avisa (el "sii" de R5) ──────────────────────────
func test_r5_capacidad_suficiente_no_avisa() -> void:
	# Arrange — fixture coherente (sin refs colgantes): puesto ODAC que admite la denuncia, la denuncia
	# apunta al puesto, escenario con servicio ODAC operable y tope 4. Denuncia de 30 min →
	# capacidad ≈ 4×(960/30) = 128/día. El único foco es R5.
	var datos: Node = _nuevo_datos()
	datos._indexar(_puesto(&"puesto_odac", "ODAC", [&"lesiones"]))
	datos._indexar(_denuncia(&"lesiones", 30, &"puesto_odac"))
	var tope: Dictionary[StringName, int] = {&"puesto_odac": 4}
	datos._indexar(_escenario(&"pozuelo", [&"ODAC"], tope))

	# Act — demanda D=60 < capacidad ≈ 128 → R5 se cumple (AC-D12: "avisa sii capacidad < D").
	var msgs: Array[String] = datos.validar(60)

	# Assert — NO hay aviso de R5 ni de capacidad (fixture coherente: sin ningún mensaje espurio).
	assert_bool(_contiene(msgs, "R5")).is_false()
	assert_bool(_contiene(msgs, "capacidad")).is_false()
