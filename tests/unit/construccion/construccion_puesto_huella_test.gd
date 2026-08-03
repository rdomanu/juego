# Huella del PUESTO = 2×3 = 6 celdas (decisión de diseño 2026-08-03) · epic construccion · ADR-0004.
# Tipo: Logic. DETERMINISTA (sin azar, sin reloj, sin I/O: los saves son diccionarios en memoria).
# Aislamiento: nodo con .new() sin árbol; salas/elementos sembrados con el registro directo del modelo.
#
# Cubre las DOS preguntas que la decisión separó a propósito (ver la cabecera de `Construccion`):
#   · COLOCACIÓN (`celdas_de_elemento`): las 6 celdas que el puesto RESERVA.
#   · OBSTÁCULO  (`celdas_obstaculo_de`): las 2 del mostrador, lo único que corta el paso.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")

# ── Fixture (sin números mágicos sueltos: cada celda dice para qué está elegida) ───────────
## Oficina de Documentación de 6×6 en la esquina: x 0..5, y 0..5 (sitio para dos ventanillas).
const OFICINA := &"sala_documentacion"
const RECT_OFICINA := Rect2i(0, 0, 6, 6)
const PUESTO := &"puesto_doc_general"
const PUESTO_TIE := &"puesto_tie"
## Lo que mide un puesto desde la decisión: 2 de ancho × 3 de fondo = 6 celdas reservadas...
const CELDAS_PUESTO: int = 6
## ...de las cuales solo el MOSTRADOR (la fila del ancla) bloquea el paso.
const CELDAS_MOSTRADOR: int = 2
## Ancla con sitio de sobra: su bloque 2×3 cae entero dentro de la oficina.
const ANCLA_LIBRE := Vector2i(1, 1)
## Las otras cinco celdas que reserva un puesto anclado en `ANCLA_LIBRE`.
const CELDA_MOSTRADOR_ESTE := Vector2i(2, 1)
const CELDA_SILLA_FUNCIONARIO := Vector2i(1, 0)   # fila NORTE (detrás del mostrador)
const CELDA_SILLA_FUNCIONARIO_ESTE := Vector2i(2, 0)
const CELDA_SILLA_CIUDADANO := Vector2i(1, 2)     # fila SUR (delante), donde Flujo planta al ciudadano
const CELDA_SILLA_CIUDADANO_ESTE := Vector2i(2, 2)
## Ancla pegada al borde NORTE: la fila del funcionario (y = -1) se sale de la sala, el mostrador no
## → escalón intermedio (2 celdas).
const ANCLA_BORDE_NORTE := Vector2i(1, 0)
## Ancla pegada al borde ESTE: ni el mostrador cabe (x = 6 se sale) → escalón mínimo (1 celda).
const ANCLA_BORDE_ESTE := Vector2i(5, 1)
## Ancla de un segundo puesto que sí cabe entero, lejos del primero.
const ANCLA_LEJOS := Vector2i(4, 4)
## Ancla de una ventanilla puesta JUSTO DETRÁS de otra: sus filas de sillas se pisan.
const ANCLA_PEGADA_AL_SUR := Vector2i(1, 3)
## Comodidad de 1 celda válida en una oficina (para ocupar una celda suelta del bloque).
const TRASTO := &"equipo_informatico"
const ID_A := &"puesto_a"
const ID_B := &"puesto_b"
const ID_C := &"puesto_c"


## Construcción aislada con los defaults del config (edificio 24×13).
func _construccion() -> Node:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	return construccion


## Fixture con la oficina de Documentación ya en el modelo (registro directo, sin coste).
func _con_oficina() -> Node:
	var construccion: Node = _construccion()
	construccion._crear_sala(OFICINA, RECT_OFICINA)
	return construccion


## Un save del layout con puestos: `anclas` = `id -> celda`. Es EL MISMO formato de siempre — el save
## nunca ha guardado la huella, solo el ancla (ver `Construccion.save`), así que una partida de cuando
## el mostrador medía 1 celda, otra de cuando medía 2 y otra de hoy son este mismo diccionario.
func _save_con(anclas: Dictionary) -> Dictionary:
	var elementos: Array = []
	for elemento_id: StringName in anclas:
		var celda: Vector2i = anclas[elemento_id]
		elementos.append({
			"id": String(elemento_id), "catalogo": String(PUESTO),
			"celda": [celda.x, celda.y], "coste_pagado": 0.0,
		})
	return {
		"salas": [{
			"id": "sala_1", "tipo": String(OFICINA),
			"rect": [
				RECT_OFICINA.position.x, RECT_OFICINA.position.y,
				RECT_OFICINA.size.x, RECT_OFICINA.size.y,
			],
			"coste_pagado": 0.0,
		}],
		"elementos": elementos, "contador_ids": elementos.size(), "muros": [],
	}


# ── El dato vive en el CATÁLOGO, no en el código (data-driven) ────────────────────────────
func test_catalogo_puestos_declara_huella_2x3() -> void:
	# Arrange / Act — la huella es una propiedad del objeto, igual que la `superficie` 3 del sofá.
	var ids_puesto: Array[StringName] = [PUESTO, PUESTO_TIE, &"puesto_odac"]

	# Assert
	for id_puesto: StringName in ids_puesto:
		var ficha: Resource = Datos.obtener(&"TipoPuesto", id_puesto)
		assert_int(ficha.superficie).is_equal(2)              # ancho del mostrador
		assert_int(ficha.fondo_detras).is_equal(1)            # fila del funcionario
		assert_int(ficha.fondo_delante).is_equal(1)           # fila del ciudadano
		# 2 × (1 + 1 + 1) = las 6 cuadrículas que pidió el usuario.
		assert_int(
			ficha.superficie * (ficha.fondo_detras + 1 + ficha.fondo_delante)
		).is_equal(CELDAS_PUESTO)


# ── Colocación: reserva 6 celdas y la de TRABAJO sigue siendo el ancla (invariante de Flujo) ─
func test_construccion_puesto_reserva_seis_celdas_con_ancla_en_la_de_trabajo() -> void:
	# Arrange
	var construccion: Node = _con_oficina()

	# Act
	var puesto_id: StringName = construccion.construir_elemento(PUESTO, ANCLA_LIBRE)

	# Assert — el bloque 2×3 entero, con el ancla la PRIMERA (hay código que depende de celdas[0]).
	var celdas: Array = construccion.celdas_de_elemento(puesto_id)
	assert_int(celdas.size()).is_equal(CELDAS_PUESTO)
	assert_vector(celdas[0]).is_equal(ANCLA_LIBRE)
	for celda: Vector2i in [
		ANCLA_LIBRE, CELDA_MOSTRADOR_ESTE,
		CELDA_SILLA_FUNCIONARIO, CELDA_SILLA_FUNCIONARIO_ESTE,
		CELDA_SILLA_CIUDADANO, CELDA_SILLA_CIUDADANO_ESTE,
	]:
		assert_bool(celda in celdas).is_true()
	# La celda de trabajo (la única que miran Flujo y Personal) NO se mueve.
	assert_vector(construccion.celda_de_trabajo(puesto_id)).is_equal(ANCLA_LIBRE)
	assert_vector(construccion.posicion_de(puesto_id)).is_equal(ANCLA_LIBRE)
	assert_int(construccion.nivel_de_huella(puesto_id)).is_equal(construccion.HUELLA_COMPLETA)
	assert_bool(construccion.es_huella_legado(puesto_id)).is_false()
	# La ventanilla es UNA cosa: un clic en la celda de cualquiera de sus sillas la encuentra.
	assert_str(String(construccion.elemento_en(CELDA_SILLA_CIUDADANO))).is_equal(String(puesto_id))
	assert_str(String(construccion.elemento_en(CELDA_SILLA_FUNCIONARIO))).is_equal(String(puesto_id))


# ── NAVEGACIÓN: obstáculo = SOLO el mostrador; las filas de las sillas se PISAN ────────────
# Si esto se rompe, el policía y el ciudadano se quedan sin camino a su silla y la ventanilla no
# atiende a nadie. Es el contrato que consume `NPCsFlujo._bakear_navegacion`.
func test_navegacion_obstaculo_del_puesto_es_solo_el_mostrador() -> void:
	# Arrange
	var construccion: Node = _con_oficina()
	var puesto_id: StringName = construccion.construir_elemento(PUESTO, ANCLA_LIBRE)

	# Act
	var obstaculo: Array = construccion.celdas_obstaculo_de(puesto_id)

	# Assert — las 2 del mostrador y ninguna más.
	assert_int(obstaculo.size()).is_equal(CELDAS_MOSTRADOR)
	assert_vector(obstaculo[0]).is_equal(ANCLA_LIBRE)
	assert_vector(obstaculo[1]).is_equal(CELDA_MOSTRADOR_ESTE)
	for celda: Vector2i in [
		CELDA_SILLA_FUNCIONARIO, CELDA_SILLA_FUNCIONARIO_ESTE,
		CELDA_SILLA_CIUDADANO, CELDA_SILLA_CIUDADANO_ESTE,
	]:
		assert_bool(celda in obstaculo).is_false()
	# Y siguen RESERVADAS: obstáculo y colocación son dos conjuntos distintos, no el mismo.
	var colocacion: Array = construccion.celdas_de_elemento(puesto_id)
	for celda: Vector2i in obstaculo:
		assert_bool(celda in colocacion).is_true()
	assert_int(colocacion.size()).is_greater(obstaculo.size())


# ── Inválido: una celda de SILLA ocupada basta para rechazar (el bloque es de una pieza) ───
func test_validacion_puesto_con_celda_de_silla_ocupada_es_invalida() -> void:
	# Arrange — un trasto justo donde iría la silla del funcionario.
	var construccion: Node = _con_oficina()
	assert_str(
		String(construccion.construir_elemento(TRASTO, CELDA_SILLA_FUNCIONARIO))
	).is_not_equal("")

	# Act / Assert — el mostrador cabría, pero el bloque no: inválido.
	assert_bool(construccion.validar_elemento(PUESTO, ANCLA_LIBRE)).is_false()
	assert_str(String(construccion.construir_elemento(PUESTO, ANCLA_LIBRE))).is_equal("")
	# Lejos del trasto sigue valiendo (no se ha roto la colocación normal).
	assert_bool(construccion.validar_elemento(PUESTO, ANCLA_LEJOS)).is_true()


# ── Y al revés: puesto el puesto, sus celdas de silla quedan RESERVADAS ────────────────────
func test_validacion_celdas_del_puesto_quedan_reservadas_para_todo_lo_demas() -> void:
	# Arrange
	var construccion: Node = _con_oficina()
	construccion.construir_elemento(PUESTO, ANCLA_LIBRE)

	# Act / Assert — ninguna de las 6 admite nada encima.
	for celda: Vector2i in [
		ANCLA_LIBRE, CELDA_MOSTRADOR_ESTE,
		CELDA_SILLA_FUNCIONARIO, CELDA_SILLA_FUNCIONARIO_ESTE,
		CELDA_SILLA_CIUDADANO, CELDA_SILLA_CIUDADANO_ESTE,
	]:
		assert_bool(construccion.validar_elemento(TRASTO, celda)).is_false()
	# Ni otra ventanilla solapada, ni una pegada por detrás (sus filas de sillas se pisarían).
	assert_bool(construccion.validar_elemento(PUESTO, CELDA_MOSTRADOR_ESTE)).is_false()
	assert_bool(construccion.validar_elemento(PUESTO, ANCLA_PEGADA_AL_SUR)).is_false()


# ── Inválido: el fondo se sale de la sala (las 6 celdas, en la MISMA sala) ─────────────────
func test_validacion_puesto_con_fondo_fuera_de_la_sala_es_invalida() -> void:
	# Arrange
	var construccion: Node = _con_oficina()

	# Act / Assert — el ancla y el mostrador están dentro, pero la fila del funcionario (y = -1) no.
	assert_bool(construccion.validar_elemento(PUESTO, ANCLA_BORDE_NORTE)).is_false()
	assert_str(String(construccion.construir_elemento(PUESTO, ANCLA_BORDE_NORTE))).is_equal("")
	# Y por el este, donde ni el mostrador cabe.
	assert_bool(construccion.validar_elemento(PUESTO, ANCLA_BORDE_ESTE)).is_false()


# ── Rotación: el bloque gira ENTERO y rígido (la R del modo construcción) ─────────────────
func test_rotacion_del_puesto_gira_el_bloque_entero() -> void:
	# Arrange
	var construccion: Node = _con_oficina()

	# Act — girado, el mostrador crece hacia +Y y el fondo pasa a este/oeste.
	var puesto_id: StringName = construccion.construir_elemento(
		PUESTO, ANCLA_LIBRE, construccion.VERTICAL
	)

	# Assert — mismas 6 celdas, otro rectángulo: 3 columnas (x 0..2) × 2 filas (y 1..2).
	var celdas: Array = construccion.celdas_de_elemento(puesto_id)
	assert_int(celdas.size()).is_equal(CELDAS_PUESTO)
	assert_vector(celdas[0]).is_equal(ANCLA_LIBRE)
	assert_int(construccion.orientacion_de(puesto_id)).is_equal(construccion.VERTICAL)
	for celda: Vector2i in [
		Vector2i(1, 1), Vector2i(1, 2),    # el mostrador, ahora en vertical
		Vector2i(2, 1), Vector2i(2, 2),    # detrás: el funcionario, al este
		Vector2i(0, 1), Vector2i(0, 2),    # delante: el ciudadano, al oeste
	]:
		assert_bool(celda in celdas).is_true()
	# El obstáculo también gira: sigue siendo SOLO el mostrador.
	var obstaculo: Array = construccion.celdas_obstaculo_de(puesto_id)
	assert_int(obstaculo.size()).is_equal(CELDAS_MOSTRADOR)
	assert_vector(obstaculo[1]).is_equal(Vector2i(1, 2))


# ── Demolición: libera LAS SEIS celdas ────────────────────────────────────────────────────
func test_demolicion_del_puesto_libera_las_seis_celdas() -> void:
	# Arrange
	var construccion: Node = _con_oficina()
	var puesto_id: StringName = construccion.construir_elemento(PUESTO, ANCLA_LIBRE)
	var reservadas: Array = construccion.celdas_de_elemento(puesto_id)
	assert_int(reservadas.size()).is_equal(CELDAS_PUESTO)

	# Act
	assert_bool(construccion.demoler_elemento(puesto_id)).is_true()

	# Assert — ninguna de las 6 tiene ya dueño, y en todas se puede volver a construir.
	for celda: Vector2i in reservadas:
		assert_str(String(construccion.elemento_en(celda))).is_equal("")
		assert_bool(construccion.validar_elemento(TRASTO, celda)).is_true()
	assert_bool(construccion.validar_elemento(PUESTO, ANCLA_LIBRE)).is_true()


# ── MIGRACIÓN v2: el save solo trae el ANCLA → la huella se vuelve a deducir, y es idempotente ─
func test_migracion_v2_save_con_sitio_expande_a_2x3_y_es_idempotente() -> void:
	# Arrange — un save cualquiera (de 1 celda, de 2 o de hoy: el JSON es el mismo). Los push_warning
	# de "sin Personal" son intencionales: el puente no está inyectado en un test unitario.
	var construccion: Node = _construccion()
	var save: Dictionary = _save_con({ID_A: ANCLA_LIBRE})

	# Act
	construccion.load_state(save)
	var tras_una_carga: Array = construccion.celdas_de_elemento(ID_A)
	construccion.load_state(save)           # cargar OTRA VEZ el mismo save
	construccion.migrar_huella_puestos()    # y volver a migrar: la operación es idempotente

	# Assert — 2×3, celda de trabajo intacta, y el mismo resultado las dos veces.
	assert_int(tras_una_carga.size()).is_equal(CELDAS_PUESTO)
	assert_array(construccion.celdas_de_elemento(ID_A)).is_equal(tras_una_carga)
	assert_vector(construccion.celda_de_trabajo(ID_A)).is_equal(ANCLA_LIBRE)
	assert_int(construccion.nivel_de_huella(ID_A)).is_equal(construccion.HUELLA_COMPLETA)
	assert_bool(construccion.es_huella_legado(ID_A)).is_false()


# ── MIGRACIÓN v2, escalón INTERMEDIO: no cabe el bloque, sí el mostrador ──────────────────
func test_migracion_v2_sin_sitio_para_el_fondo_baja_al_escalon_del_mostrador() -> void:
	# Arrange — pegado al borde norte: la fila del funcionario se saldría de la sala.
	var construccion: Node = _construccion()
	var save: Dictionary = _save_con({ID_A: ANCLA_BORDE_NORTE})

	# Act
	construccion.load_state(save)
	var tras_una_carga: Array = construccion.celdas_de_elemento(ID_A)
	construccion.load_state(save)

	# Assert — se queda con su mostrador de 2 celdas (NO es "legado": el mueble está entero).
	assert_int(tras_una_carga.size()).is_equal(CELDAS_MOSTRADOR)
	assert_int(construccion.nivel_de_huella(ID_A)).is_equal(construccion.HUELLA_SIN_FONDO)
	assert_bool(construccion.es_huella_legado(ID_A)).is_false()
	assert_vector(construccion.celda_de_trabajo(ID_A)).is_equal(ANCLA_BORDE_NORTE)
	assert_array(construccion.celdas_de_elemento(ID_A)).is_equal(tras_una_carga)
	# Y su obstáculo sigue siendo el mostrador: no se ha quedado sin bloquear nada.
	assert_int(construccion.celdas_obstaculo_de(ID_A).size()).is_equal(CELDAS_MOSTRADOR)


# ── MIGRACIÓN v2, escalón MÍNIMO: ni el mostrador cabe → su sola celda de trabajo ─────────
func test_migracion_v2_sin_sitio_para_el_mostrador_baja_al_escalon_minimo() -> void:
	# Arrange — pegado al borde este: la 2ª celda del mostrador se saldría de la sala.
	var construccion: Node = _construccion()
	var save: Dictionary = _save_con({ID_A: ANCLA_BORDE_ESTE})

	# Act
	construccion.load_state(save)
	var tras_una_carga: Array = construccion.celdas_de_elemento(ID_A)
	construccion.load_state(save)

	# Assert — 1 celda, la de trabajo; y el resultado no cambia al recargar.
	assert_int(tras_una_carga.size()).is_equal(1)
	assert_vector(tras_una_carga[0]).is_equal(ANCLA_BORDE_ESTE)
	assert_int(construccion.nivel_de_huella(ID_A)).is_equal(construccion.HUELLA_MINIMA)
	assert_bool(construccion.es_huella_legado(ID_A)).is_true()
	assert_array(construccion.celdas_de_elemento(ID_A)).is_equal(tras_una_carga)
	assert_vector(construccion.celda_de_trabajo(ID_A)).is_equal(ANCLA_BORDE_ESTE)


# ── Dos ventanillas que se estorban: reparto determinista, sin montar una encima de otra ──
func test_migracion_v2_dos_puestos_que_se_pisan_reparten_igual_siempre() -> void:
	# Arrange — una detrás de la otra: la fila del ciudadano de la 1ª es la fila del funcionario de
	# la 2ª. En el save (que solo trae anclas) no hay conflicto; al deducir la huella, sí.
	var construccion: Node = _construccion()
	var save: Dictionary = _save_con({ID_A: ANCLA_LIBRE, ID_B: ANCLA_PEGADA_AL_SUR})

	# Act
	construccion.load_state(save)
	var celdas_a: Array = construccion.celdas_de_elemento(ID_A)
	var celdas_b: Array = construccion.celdas_de_elemento(ID_B)
	construccion.load_state(save)

	# Assert — la primera cede (se queda con su mostrador) y la segunda se expande entera.
	assert_int(construccion.nivel_de_huella(ID_A)).is_equal(construccion.HUELLA_SIN_FONDO)
	assert_int(construccion.nivel_de_huella(ID_B)).is_equal(construccion.HUELLA_COMPLETA)
	assert_int(celdas_a.size()).is_equal(CELDAS_MOSTRADOR)
	assert_int(celdas_b.size()).is_equal(CELDAS_PUESTO)
	# Ninguna celda compartida: la ley del juego (nada montado encima de nada) se mantiene.
	for celda: Vector2i in celdas_a:
		assert_bool(celda in celdas_b).is_false()
	# Recargar no cambia el reparto (idempotencia con dos puestos en conflicto).
	assert_array(construccion.celdas_de_elemento(ID_A)).is_equal(celdas_a)
	assert_array(construccion.celdas_de_elemento(ID_B)).is_equal(celdas_b)


# ── Trazado de oficio: el que cabe va 2×3; el que no, baja escalón en vez de perderse ─────
func test_de_oficio_monta_2x3_y_baja_escalon_cuando_no_cabe() -> void:
	# Arrange
	var construccion: Node = _con_oficina()

	# Act — el primero cabe entero; el del borde norte solo con su mostrador; el del este, ni eso.
	var cabe: StringName = construccion.construir_de_oficio_elemento(PUESTO, ANCLA_LEJOS, ID_A)
	var a_medias: StringName = construccion.construir_de_oficio_elemento(
		PUESTO_TIE, ANCLA_BORDE_NORTE, ID_B
	)
	var minimo: StringName = construccion.construir_de_oficio_elemento(
		PUESTO_TIE, ANCLA_BORDE_ESTE, ID_C
	)

	# Assert — los tres EXISTEN (una comisaría entregada no pierde una ventanilla por una celda).
	assert_int(construccion.celdas_de_elemento(cabe).size()).is_equal(CELDAS_PUESTO)
	assert_int(construccion.nivel_de_huella(cabe)).is_equal(construccion.HUELLA_COMPLETA)
	assert_int(construccion.celdas_de_elemento(a_medias).size()).is_equal(CELDAS_MOSTRADOR)
	assert_int(construccion.nivel_de_huella(a_medias)).is_equal(construccion.HUELLA_SIN_FONDO)
	assert_int(construccion.celdas_de_elemento(minimo).size()).is_equal(1)
	assert_bool(construccion.es_huella_legado(minimo)).is_true()
	assert_vector(construccion.celda_de_trabajo(minimo)).is_equal(ANCLA_BORDE_ESTE)


# ── Mover un puesto recortado a un sitio con espacio le devuelve su huella entera ──────────
func test_mover_un_puesto_recortado_recupera_la_huella_completa() -> void:
	# Arrange — puesto montado en el escalón del mostrador (pegado al borde norte).
	var construccion: Node = _con_oficina()
	var puesto_id: StringName = construccion.construir_de_oficio_elemento(
		PUESTO, ANCLA_BORDE_NORTE, ID_A
	)
	assert_int(construccion.nivel_de_huella(puesto_id)).is_equal(construccion.HUELLA_SIN_FONDO)

	# Act — el jugador lo lleva a un hueco con sitio de sobra.
	assert_bool(construccion.mover_elemento(puesto_id, ANCLA_LEJOS)).is_true()

	# Assert
	assert_int(construccion.nivel_de_huella(puesto_id)).is_equal(construccion.HUELLA_COMPLETA)
	assert_int(construccion.celdas_de_elemento(puesto_id).size()).is_equal(CELDAS_PUESTO)
	assert_vector(construccion.celda_de_trabajo(puesto_id)).is_equal(ANCLA_LEJOS)


# ── Lo que NO declara fondo se comporta EXACTAMENTE igual que antes (no-regresión) ────────
func test_pieza_sin_fondo_ocupa_solo_su_fila() -> void:
	# Arrange
	var construccion: Node = _con_oficina()

	# Act — una comodidad de 1 celda: su huella y su obstáculo son la misma celda.
	var trasto_id: StringName = construccion.construir_elemento(TRASTO, ANCLA_LEJOS)

	# Assert
	assert_int(construccion.celdas_de_elemento(trasto_id).size()).is_equal(1)
	assert_int(construccion.celdas_obstaculo_de(trasto_id).size()).is_equal(1)
	assert_vector(construccion.celdas_de_elemento(trasto_id)[0]).is_equal(ANCLA_LEJOS)
	# La celda de al lado sigue libre: nada de fondo fantasma.
	assert_bool(construccion.validar_elemento(TRASTO, ANCLA_LEJOS + Vector2i(0, 1))).is_true()
