# REQUISITOS MÍNIMOS DE SALA y la COLOCACIÓN de la impresora · GDD
# `design/gdd/impresora-documentos-tramite.md` (decisión P1 del usuario 2026-08-01: *"no existe el
# caso sala sin impresora"* + *"detrás del puesto o a un lado, pero siempre de la mesa hacia atrás —
# NUNCA hacia el lado del ciudadano"*). Tipo: Logic. DETERMINISTA (sin azar, sin reloj, sin I/O).
extends GdUnitTestSuite

const ImpresoraScript := preload("res://src/core/impresora/impresora_documentos.gd")
const ConfigImpresoraScript := preload("res://src/core/impresora/config_impresora.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")

# ── Fixture: EL TRAZADO DE OFICIO REAL (el mismo que monta `Main._montar_comisaria_inicial`) ──
# Se replica aquí a propósito: lo que se está probando es que, con el plano que la DGP entrega, la
# regla de colocación produce exactamente lo que el GDD describe. Si el plano cambia, este test
# tiene que volver a mirarse — y eso es justo lo que se quiere.
const SALA_DOC := &"sala_documentacion"
const RECT_DOC := Rect2i(1, 1, 6, 4)
const SALA_ODAC := &"sala_odac"
const RECT_ODAC := Rect2i(9, 1, 4, 3)
const SALA_ESPERA := &"sala_espera_doc"
const RECT_ESPERA := Rect2i(1, 6, 6, 4)
const ANCLA_DOC_1 := Vector2i(2, 2)
const ANCLA_DOC_2 := Vector2i(4, 2)
const ANCLA_TIE := Vector2i(6, 2)
const ANCLA_ODAC := Vector2i(10, 2)
## Lo que el GDD pide para Documentación: la impresora JUSTO DETRÁS del puesto de TIE.
const CELDA_ESPERADA_DOC := Vector2i(6, 1)
## Y en ODAC: detrás no cabe (la sala acaba en y=1), así que va al lado de la fila del funcionario.
const CELDA_ESPERADA_ODAC := Vector2i(9, 1)
## Una oficina limpia para probar la regla aislada, sin el ruido del trazado real: x 0..7, y 0..7.
const RECT_LIMPIA := Rect2i(0, 0, 8, 8)
## Ancla con sitio de sobra por los cuatro costados: mostrador (3,3)-(4,3), funcionario y=2,
## ciudadano y=4. La fila de DETRÁS del bloque entero es y=1.
const ANCLA_HOLGADA := Vector2i(3, 3)
const FILA_DETRAS_HOLGADA: int = 1
## La fila del CIUDADANO y todo lo que quede más adelante: ahí NO puede acabar la impresora nunca.
const FILA_CIUDADANO_HOLGADA: int = 4
const PUESTO_DOC := &"puesto_doc_general"
const PUESTO_TIE := &"puesto_tie"
const PUESTO_ODAC := &"puesto_odac"


# ── Helpers ───────────────────────────────────────────────────────────────────────────────
func _construccion() -> Node:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	return construccion


func _impresora(construccion: Node) -> Node:
	var impresora: Node = auto_free(ImpresoraScript.new())
	impresora.aplicar_config(ConfigImpresoraScript.new())
	impresora.usar_construccion(construccion)
	return impresora


## Réplica EXACTA del trazado de oficio de Main (salas + puestos, sin asientos: no pintan aquí).
func _trazado_de_oficio() -> Node:
	var construccion: Node = _construccion()
	construccion.construir_de_oficio_sala(SALA_DOC, RECT_DOC)
	construccion.construir_de_oficio_sala(SALA_ESPERA, RECT_ESPERA)
	construccion.construir_de_oficio_sala(SALA_ODAC, RECT_ODAC)
	construccion.construir_de_oficio_elemento(PUESTO_DOC, ANCLA_DOC_1, &"doc_1")
	construccion.construir_de_oficio_elemento(PUESTO_DOC, ANCLA_DOC_2, &"doc_2")
	construccion.construir_de_oficio_elemento(PUESTO_TIE, ANCLA_TIE, &"tie_1")
	construccion.construir_de_oficio_elemento(PUESTO_ODAC, ANCLA_ODAC, &"odac_1")
	return construccion


## La sala que contiene una celda (los ids de sala del trazado se autogeneran).
func _sala_en(construccion: Node, celda: Vector2i) -> StringName:
	return construccion.sala_en(celda)


# ── El catálogo manda: qué exige cada sala ────────────────────────────────────────────────
func test_documentacion_exige_impresora_y_un_puesto() -> void:
	# Arrange — sala recién designada, todavía vacía.
	var construccion: Node = _construccion()
	construccion.construir_de_oficio_sala(SALA_DOC, RECT_DOC)
	var impresora: Node = _impresora(construccion)
	var sala_id: StringName = _sala_en(construccion, ANCLA_DOC_1)
	# Act / Assert — GDD P1: 1 puesto (DNI o TIE) + 1 impresora de documentos.
	assert_array(impresora.comodidades_obligatorias_de(sala_id)).contains_exactly(
		[ImpresoraScript.ID_CATALOGO]
	)
	assert_array(impresora.comodidades_faltantes(sala_id)).contains_exactly(
		[ImpresoraScript.ID_CATALOGO]
	)
	assert_int(impresora.puestos_faltantes(sala_id)).is_equal(1)
	assert_bool(impresora.cumple_requisitos(sala_id)).is_false()


func test_odac_exige_impresora_y_un_puesto() -> void:
	var construccion: Node = _construccion()
	construccion.construir_de_oficio_sala(SALA_ODAC, RECT_ODAC)
	var impresora: Node = _impresora(construccion)
	var sala_id: StringName = _sala_en(construccion, ANCLA_ODAC)
	assert_array(impresora.comodidades_faltantes(sala_id)).contains_exactly(
		[ImpresoraScript.ID_CATALOGO]
	)
	assert_int(impresora.puestos_faltantes(sala_id)).is_equal(1)


func test_la_sala_de_espera_no_exige_nada() -> void:
	# Arrange — los requisitos son POR TIPO DE SALA: una sala de espera no lleva impresora.
	var construccion: Node = _construccion()
	construccion.construir_de_oficio_sala(SALA_ESPERA, RECT_ESPERA)
	var impresora: Node = _impresora(construccion)
	var sala_id: StringName = _sala_en(construccion, RECT_ESPERA.position)
	# Act / Assert
	assert_array(impresora.comodidades_obligatorias_de(sala_id)).is_empty()
	assert_bool(impresora.cumple_requisitos(sala_id)).is_true()
	assert_array(impresora.completar_requisitos(sala_id, true)).is_empty()


# ── La regla de colocación: hacia atrás, nunca hacia el ciudadano ─────────────────────────
func test_la_impresora_va_justo_detras_del_puesto_cuando_hay_sitio() -> void:
	# Arrange — puesto con sitio de sobra por los cuatro costados.
	var construccion: Node = _construccion()
	construccion._crear_sala(SALA_DOC, RECT_LIMPIA)
	construccion.construir_de_oficio_elemento(PUESTO_DOC, ANCLA_HOLGADA, &"doc_1")
	var impresora: Node = _impresora(construccion)
	var sala_id: StringName = _sala_en(construccion, ANCLA_HOLGADA)
	# Act
	var celda: Vector2i = impresora.celda_para_comodidad(sala_id, ImpresoraScript.ID_CATALOGO)
	# Assert — la fila de DETRÁS del bloque entero, alineada con el ancla: la opción preferente.
	assert_int(celda.y).is_equal(FILA_DETRAS_HOLGADA)
	assert_int(celda.x).is_equal(ANCLA_HOLGADA.x)


func test_la_impresora_nunca_cae_del_lado_del_ciudadano() -> void:
	# Arrange — la invariante que sostiene toda la regla, probada sobre TODAS las candidatas que el
	# módulo se plantea, no solo sobre la que acaba eligiendo.
	var construccion: Node = _construccion()
	construccion._crear_sala(SALA_DOC, RECT_LIMPIA)
	construccion.construir_de_oficio_elemento(PUESTO_DOC, ANCLA_HOLGADA, &"doc_1")
	var impresora: Node = _impresora(construccion)
	# Act / Assert
	for hacia_detras: bool in [true, false]:
		for celda: Vector2i in impresora._candidatas_de_puesto(&"doc_1", hacia_detras):
			assert_int(celda.y).is_less(FILA_CIUDADANO_HOLGADA)


func test_completar_requisitos_coloca_la_impresora_y_deja_la_sala_conforme() -> void:
	# Arrange
	var construccion: Node = _construccion()
	construccion._crear_sala(SALA_DOC, RECT_LIMPIA)
	construccion.construir_de_oficio_elemento(PUESTO_DOC, ANCLA_HOLGADA, &"doc_1")
	var impresora: Node = _impresora(construccion)
	var sala_id: StringName = _sala_en(construccion, ANCLA_HOLGADA)
	# Act
	var colocados: Array[StringName] = impresora.completar_requisitos(sala_id, true)
	# Assert — una impresora, y la sala ya cumple (el puesto mínimo también está).
	assert_int(colocados.size()).is_equal(1)
	assert_array(impresora.comodidades_faltantes(sala_id)).is_empty()
	assert_bool(impresora.cumple_requisitos(sala_id)).is_true()
	assert_int(impresora.impresoras().size()).is_equal(1)


func test_completar_requisitos_es_idempotente() -> void:
	# Arrange — el patrón que el GDD pide explícitamente para los saves antiguos (como la fachada).
	var construccion: Node = _construccion()
	construccion._crear_sala(SALA_DOC, RECT_LIMPIA)
	construccion.construir_de_oficio_elemento(PUESTO_DOC, ANCLA_HOLGADA, &"doc_1")
	var impresora: Node = _impresora(construccion)
	var sala_id: StringName = _sala_en(construccion, ANCLA_HOLGADA)
	impresora.completar_requisitos(sala_id, true)
	var primera: Vector2i = construccion.posicion_de(impresora.impresoras()[0])
	# Act — tres pasadas más.
	for _i: int in range(3):
		impresora.completar_requisitos(sala_id, true)
	# Assert — sigue habiendo UNA, y en la MISMA celda.
	assert_int(impresora.impresoras().size()).is_equal(1)
	assert_vector(construccion.posicion_de(impresora.impresoras()[0])).is_equal(primera)


# ── El trazado de oficio real (§decisión de colocación del usuario) ───────────────────────
func test_el_trazado_de_oficio_pone_la_impresora_detras_del_puesto_de_tie() -> void:
	# Arrange — el plano que entrega la DGP, con sus tres ventanillas de Documentación.
	var construccion: Node = _trazado_de_oficio()
	var impresora: Node = _impresora(construccion)
	# Act
	impresora.completar_todas_las_salas(true)
	# Assert — GDD: *"en Documentación, detrás del puesto de TIE"*. Sale de la regla, no a mano:
	# es el único puesto de la sala con la fila de detrás libre (los otros dos la tienen fuera).
	var sala_doc: StringName = _sala_en(construccion, ANCLA_DOC_1)
	var en_doc: Array[StringName] = []
	for id: StringName in construccion.contenido_de_sala(sala_doc):
		if construccion.catalogo_de_elemento(id) == ImpresoraScript.ID_CATALOGO:
			en_doc.append(id)
	assert_int(en_doc.size()).is_equal(1)
	assert_vector(construccion.posicion_de(en_doc[0])).is_equal(CELDA_ESPERADA_DOC)


func test_el_trazado_de_oficio_pone_la_impresora_de_odac_al_lado_hacia_atras() -> void:
	# Arrange
	var construccion: Node = _trazado_de_oficio()
	var impresora: Node = _impresora(construccion)
	# Act
	impresora.completar_todas_las_salas(true)
	# Assert — en ODAC la fila de detrás cae fuera de la sala, así que la regla baja al lado de la
	# fila del FUNCIONARIO: hacia atrás, nunca hacia el mostrador del ciudadano (y = 3).
	var sala_odac: StringName = _sala_en(construccion, ANCLA_ODAC)
	var en_odac: Array[StringName] = []
	for id: StringName in construccion.contenido_de_sala(sala_odac):
		if construccion.catalogo_de_elemento(id) == ImpresoraScript.ID_CATALOGO:
			en_odac.append(id)
	assert_int(en_odac.size()).is_equal(1)
	assert_vector(construccion.posicion_de(en_odac[0])).is_equal(CELDA_ESPERADA_ODAC)


func test_el_trazado_de_oficio_deja_las_dos_oficinas_conformes() -> void:
	# Arrange
	var construccion: Node = _trazado_de_oficio()
	var impresora: Node = _impresora(construccion)
	# Act
	impresora.completar_todas_las_salas(true)
	# Assert — "no existe el caso sala sin impresora": la comisaría se entrega conforme.
	assert_bool(impresora.cumple_requisitos(_sala_en(construccion, ANCLA_DOC_1))).is_true()
	assert_bool(impresora.cumple_requisitos(_sala_en(construccion, ANCLA_ODAC))).is_true()
	assert_int(impresora.impresoras().size()).is_equal(2)


# ── REGRESIÓN (playtest 2026-08-06 — silla del funcionario y fotocopiadora solapadas) ──────
## `ImpresoraDocumentos._paso_de`/`_delante_de` llevaban la codificación VIEJA de orientación
## (`orientacion == 1`, booleana) mientras `Construccion` ya usaba 4 estados reales en grados
## (HORIZONTAL=0/VERTICAL=90/HORIZONTAL_GIRADO=180/VERTICAL_GIRADO=270). Con un puesto HORIZONTAL
## (0) la comparación vieja seguía coincidiendo por accidente —de ahí que el bug no saliera en los
## tests de arriba, todos con la orientación por defecto—; con VERTICAL (90) caía siempre a la rama
## horizontal y calculaba "detrás" en el eje norte-sur en vez del este-oeste real del puesto, así
## que la impresora podía acabar pisando la silla del propio funcionario o fuera de toda sala.
func test_impresora_detras_de_puesto_vertical_no_pisa_su_propia_silla() -> void:
	# Arrange — puesto en VERTICAL (90°): mostrador norte-sur, ciudadano al OESTE (frente), así que
	# "detrás" —donde se sienta el funcionario, y donde debe ir la impresora un paso más allá— es el
	# ESTE. Sitio de sobra por los cuatro costados (misma sala limpia que el resto del fichero).
	var construccion: Node = _construccion()
	construccion._crear_sala(SALA_DOC, RECT_LIMPIA)
	construccion.construir_de_oficio_elemento(
		PUESTO_DOC, ANCLA_HOLGADA, &"doc_vertical", construccion.VERTICAL
	)
	var impresora: Node = _impresora(construccion)
	var sala_id: StringName = _sala_en(construccion, ANCLA_HOLGADA)
	# Act
	var celda: Vector2i = impresora.celda_para_comodidad(sala_id, ImpresoraScript.ID_CATALOGO)
	# Assert — nunca dentro de la huella del propio puesto (la silla del funcionario incluida)...
	var huella: Array[Vector2i] = construccion.celdas_de_elemento(&"doc_vertical")
	assert_bool(celda in huella).is_false()
	# ...y del lado correcto: DETRÁS es ESTE para VERTICAL (el ciudadano espera al OESTE, x menor).
	assert_int(celda.x).is_greater(ANCLA_HOLGADA.x)


func test_el_trazado_de_oficio_no_duplica_impresoras_al_repetirse() -> void:
	# Arrange — es la ruta de "cargar un save antiguo": se llama SIEMPRE, tenga o no impresoras.
	var construccion: Node = _trazado_de_oficio()
	var impresora: Node = _impresora(construccion)
	impresora.completar_todas_las_salas(true)
	# Act
	impresora.completar_todas_las_salas(true)
	impresora.completar_todas_las_salas(true)
	# Assert
	assert_int(impresora.impresoras().size()).is_equal(2)


func test_sala_sin_puestos_todavia_coloca_igual_su_impresora() -> void:
	# Arrange — sala recién designada por el jugador, aún sin ninguna ventanilla dentro.
	var construccion: Node = _construccion()
	construccion._crear_sala(SALA_DOC, RECT_LIMPIA)
	var impresora: Node = _impresora(construccion)
	var sala_id: StringName = _sala_en(construccion, RECT_LIMPIA.position)
	# Act
	var colocados: Array[StringName] = impresora.completar_requisitos(sala_id, true)
	# Assert — la impresora entra igual (no se queda esperando a que haya puesto); lo que falta es
	# el PUESTO, y eso se reporta, no se compra solo.
	assert_int(colocados.size()).is_equal(1)
	assert_array(impresora.comodidades_faltantes(sala_id)).is_empty()
	assert_int(impresora.puestos_faltantes(sala_id)).is_equal(1)
	assert_bool(impresora.cumple_requisitos(sala_id)).is_false()
