# Huella del PUESTO = 2 celdas (decisión de diseño 2026-08-02) · epic construccion · ADR-0004.
# Tipo: Logic. DETERMINISTA (sin azar, sin reloj, sin I/O: los saves son diccionarios en memoria).
# Aislamiento: nodo con .new() sin árbol; salas/elementos sembrados con el registro directo del modelo.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")

# ── Fixture (sin números mágicos sueltos: cada celda dice para qué está elegida) ───────────
## Oficina de Documentación de 4×4 en la esquina: x 0..3, y 0..3.
const OFICINA := &"sala_documentacion"
const RECT_OFICINA := Rect2i(0, 0, 4, 4)
const PUESTO := &"puesto_doc_general"
const PUESTO_TIE := &"puesto_tie"
## Lo que mide un mostrador desde la decisión: 2 celdas (celda de trabajo + ocupación pura).
const CELDAS_MOSTRADOR: int = 2
## Ancla con sitio de sobra: su cuerpo (1,1)+(2,1) cae entero dentro de la oficina.
const ANCLA_LIBRE := Vector2i(1, 1)
## La celda extra que reserva un mostrador colocado en `ANCLA_LIBRE`.
const CELDA_EXTRA := Vector2i(2, 1)
## Ancla pegada al borde este: su 2ª celda (4,1) YA NO es de la sala.
const ANCLA_BORDE := Vector2i(3, 1)
## Ancla de un segundo mostrador que sí cabe, lejos del primero.
const ANCLA_LEJOS := Vector2i(0, 3)
## Ancla que solapa el cuerpo del mostrador puesto en `ANCLA_LIBRE`.
const ANCLA_SOLAPADA := Vector2i(2, 1)
const ID_A := &"puesto_a"
const ID_B := &"puesto_b"


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


## Un save COMO LOS VIEJOS: mostradores de 1 celda, sin `orientacion` ni `celdas` de sala (los campos
## que aún no existían). `anclas` = `id -> celda`.
func _save_viejo(anclas: Dictionary) -> Dictionary:
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
func test_el_catalogo_da_dos_celdas_a_los_mostradores() -> void:
	# Act / Assert — la huella es una propiedad del objeto, igual que la del sofá.
	assert_int(Datos.obtener(&"TipoPuesto", PUESTO).superficie).is_equal(CELDAS_MOSTRADOR)
	assert_int(Datos.obtener(&"TipoPuesto", PUESTO_TIE).superficie).is_equal(CELDAS_MOSTRADOR)
	assert_int(Datos.obtener(&"TipoPuesto", &"puesto_odac").superficie).is_equal(CELDAS_MOSTRADOR)


# ── Colocación: ocupa 2 celdas y la de TRABAJO sigue siendo el ancla (invariante de Flujo) ─
func test_puesto_ocupa_dos_celdas_y_la_de_trabajo_es_el_ancla() -> void:
	# Arrange
	var construccion: Node = _con_oficina()

	# Act
	var puesto_id: StringName = construccion.construir_elemento(PUESTO, ANCLA_LIBRE)

	# Assert — cuerpo de 2 celdas; la celda de trabajo (la que miran Flujo y Personal) es el ancla.
	var celdas: Array = construccion.celdas_de_elemento(puesto_id)
	assert_int(celdas.size()).is_equal(CELDAS_MOSTRADOR)
	assert_vector(celdas[0]).is_equal(ANCLA_LIBRE)
	assert_vector(celdas[1]).is_equal(CELDA_EXTRA)
	assert_vector(construccion.celda_de_trabajo(puesto_id)).is_equal(ANCLA_LIBRE)
	assert_vector(construccion.posicion_de(puesto_id)).is_equal(ANCLA_LIBRE)
	assert_bool(construccion.es_huella_legado(puesto_id)).is_false()
	# La 2ª celda es ocupación pura: un clic en ella encuentra el mismo mostrador.
	assert_str(String(construccion.elemento_en(CELDA_EXTRA))).is_equal(String(puesto_id))


# ── Inválido: la 2ª celda ya está ocupada (los objetos no se montan unos con otros) ────────
func test_rechaza_si_la_segunda_celda_esta_ocupada() -> void:
	# Arrange — un mostrador ya puesto ocupa (1,1) y (2,1).
	var construccion: Node = _con_oficina()
	construccion.construir_elemento(PUESTO, ANCLA_LIBRE)

	# Act / Assert — anclar sobre su celda extra es inválido, aunque esa celda no sea su ancla.
	assert_bool(construccion.validar_elemento(PUESTO, ANCLA_SOLAPADA)).is_false()
	# Y anclar a la izquierda también: el CUERPO (0,1)+(1,1) pisaría su celda de trabajo.
	assert_bool(construccion.validar_elemento(PUESTO, Vector2i(0, 1))).is_false()
	# Sitio limpio: sigue valiendo.
	assert_bool(construccion.validar_elemento(PUESTO, ANCLA_LEJOS)).is_true()


# ── Inválido: la 2ª celda se sale de la sala (las dos celdas, en la MISMA sala) ────────────
func test_rechaza_si_la_segunda_celda_se_sale_de_la_sala() -> void:
	# Arrange
	var construccion: Node = _con_oficina()

	# Act / Assert — el ancla está dentro, pero el cuerpo asoma fuera de la oficina.
	assert_bool(construccion.validar_elemento(PUESTO, ANCLA_BORDE)).is_false()
	assert_str(String(construccion.construir_elemento(PUESTO, ANCLA_BORDE))).is_equal("")


# ── Rotación: 2×1 ↔ 1×2 con el mecanismo de siempre (la R del modo construcción) ───────────
func test_rotacion_gira_la_huella() -> void:
	# Arrange
	var construccion: Node = _con_oficina()

	# Act — girado, el cuerpo crece hacia +Y en vez de hacia +X.
	var puesto_id: StringName = construccion.construir_elemento(
		PUESTO, ANCLA_LIBRE, construccion.VERTICAL
	)

	# Assert
	var celdas: Array = construccion.celdas_de_elemento(puesto_id)
	assert_int(celdas.size()).is_equal(CELDAS_MOSTRADOR)
	assert_vector(celdas[0]).is_equal(ANCLA_LIBRE)
	assert_vector(celdas[1]).is_equal(ANCLA_LIBRE + Vector2i(0, 1))
	assert_int(construccion.orientacion_de(puesto_id)).is_equal(construccion.VERTICAL)
	# La celda que reservaría en horizontal queda LIBRE: otro mostrador cabe justo al lado.
	assert_bool(construccion.validar_elemento(PUESTO, CELDA_EXTRA)).is_true()
	# Y en vertical no cabe pegado por abajo (su cuerpo pisaría el del primero).
	assert_bool(
		construccion.validar_elemento(PUESTO, ANCLA_LIBRE + Vector2i(0, 1), &"", construccion.VERTICAL)
	).is_false()


# ── Demolición: libera LAS DOS celdas ─────────────────────────────────────────────────────
func test_demoler_libera_las_dos_celdas() -> void:
	# Arrange
	var construccion: Node = _con_oficina()
	var puesto_id: StringName = construccion.construir_elemento(PUESTO, ANCLA_LIBRE)

	# Act
	assert_bool(construccion.demoler_elemento(puesto_id)).is_true()

	# Assert — ancla y celda extra vuelven a estar libres (ya no hay elemento en ninguna).
	assert_str(String(construccion.elemento_en(ANCLA_LIBRE))).is_equal("")
	assert_str(String(construccion.elemento_en(CELDA_EXTRA))).is_equal("")
	assert_bool(construccion.validar_elemento(PUESTO, ANCLA_LIBRE)).is_true()
	assert_bool(construccion.validar_elemento(PUESTO, CELDA_EXTRA)).is_true()


# ── Save viejo (mostradores de 1 celda): se EXPANDEN al cargar, y cargar dos veces da igual ─
func test_migracion_expande_el_save_viejo_y_es_idempotente() -> void:
	# Arrange — un save de cuando el mostrador medía 1 celda (los push_warning de "sin Personal" son
	# intencionales: el puente no está inyectado en un test unitario).
	var construccion: Node = _construccion()
	var save: Dictionary = _save_viejo({ID_A: ANCLA_LIBRE})

	# Act
	construccion.load_state(save)
	var tras_una_carga: Array = construccion.celdas_de_elemento(ID_A)
	construccion.load_state(save)          # cargar OTRA VEZ el mismo save
	construccion.migrar_huella_puestos()   # y volver a migrar: la operación es idempotente

	# Assert — 2 celdas, celda de trabajo intacta, y el mismo resultado las dos veces.
	assert_int(tras_una_carga.size()).is_equal(CELDAS_MOSTRADOR)
	assert_array(construccion.celdas_de_elemento(ID_A)).is_equal(tras_una_carga)
	assert_vector(construccion.celda_de_trabajo(ID_A)).is_equal(ANCLA_LIBRE)
	assert_bool(construccion.es_huella_legado(ID_A)).is_false()


# ── Save viejo que NO CABE: se queda LEGADO (1 celda), sin mover nada del jugador ──────────
func test_migracion_marca_legado_el_mostrador_que_no_cabe() -> void:
	# Arrange — el mostrador está pegado al borde este: su 2ª celda caería fuera de la sala.
	var construccion: Node = _construccion()
	var save: Dictionary = _save_viejo({ID_A: ANCLA_BORDE})

	# Act
	construccion.load_state(save)
	var tras_una_carga: Array = construccion.celdas_de_elemento(ID_A)
	construccion.load_state(save)

	# Assert — sigue ocupando SOLO su celda de trabajo, y el resultado no cambia al recargar.
	assert_int(tras_una_carga.size()).is_equal(1)
	assert_vector(tras_una_carga[0]).is_equal(ANCLA_BORDE)
	assert_bool(construccion.es_huella_legado(ID_A)).is_true()
	assert_array(construccion.celdas_de_elemento(ID_A)).is_equal(tras_una_carga)
	assert_vector(construccion.celda_de_trabajo(ID_A)).is_equal(ANCLA_BORDE)


# ── Dos mostradores PEGADOS en un save viejo: uno se expande, el otro cede (determinista) ──
func test_migracion_con_dos_mostradores_pegados_no_los_monta_uno_encima_de_otro() -> void:
	# Arrange — anclas contiguas: (0,1) y (1,1). En el save viejo cada uno ocupaba su celda.
	var construccion: Node = _construccion()
	var save: Dictionary = _save_viejo({ID_A: Vector2i(0, 1), ID_B: ANCLA_LIBRE})

	# Act
	construccion.load_state(save)
	var celdas_a: Array = construccion.celdas_de_elemento(ID_A)
	var celdas_b: Array = construccion.celdas_de_elemento(ID_B)
	construccion.load_state(save)

	# Assert — el de delante no puede crecer sobre el de detrás: se queda legado; el otro se expande.
	assert_bool(construccion.es_huella_legado(ID_A)).is_true()
	assert_bool(construccion.es_huella_legado(ID_B)).is_false()
	assert_int(celdas_a.size()).is_equal(1)
	assert_int(celdas_b.size()).is_equal(CELDAS_MOSTRADOR)
	# Ninguna celda compartida: la ley del juego (nada montado encima de nada) se mantiene.
	for celda: Vector2i in celdas_a:
		assert_bool(celda in celdas_b).is_false()
	# Recargar no cambia el reparto.
	assert_array(construccion.celdas_de_elemento(ID_A)).is_equal(celdas_a)
	assert_array(construccion.celdas_de_elemento(ID_B)).is_equal(celdas_b)


# ── Trazado de oficio: el que cabe va 2×1; el que no, se monta legado en vez de perderse ───
func test_de_oficio_monta_dos_celdas_y_cae_a_legado_si_no_cabe() -> void:
	# Arrange
	var construccion: Node = _con_oficina()

	# Act — el primero cabe; el del borde no (su 2ª celda se saldría de la sala).
	var cabe: StringName = construccion.construir_de_oficio_elemento(PUESTO, ANCLA_LIBRE, ID_A)
	var no_cabe: StringName = construccion.construir_de_oficio_elemento(PUESTO_TIE, ANCLA_BORDE, ID_B)

	# Assert — los dos EXISTEN (una partida nueva no pierde una ventanilla por una celda).
	assert_int(construccion.celdas_de_elemento(cabe).size()).is_equal(CELDAS_MOSTRADOR)
	assert_bool(construccion.es_huella_legado(cabe)).is_false()
	assert_int(construccion.celdas_de_elemento(no_cabe).size()).is_equal(1)
	assert_bool(construccion.es_huella_legado(no_cabe)).is_true()
	assert_vector(construccion.celda_de_trabajo(no_cabe)).is_equal(ANCLA_BORDE)


# ── Mover un legado a un sitio donde sí cabe lo devuelve a su huella entera ────────────────
func test_mover_un_legado_recupera_las_dos_celdas() -> void:
	# Arrange — mostrador legado pegado al borde.
	var construccion: Node = _con_oficina()
	var puesto_id: StringName = construccion.construir_de_oficio_elemento(PUESTO, ANCLA_BORDE, ID_A)

	# Act — el jugador lo lleva a un hueco con sitio.
	assert_bool(construccion.mover_elemento(puesto_id, ANCLA_LEJOS)).is_true()

	# Assert
	assert_bool(construccion.es_huella_legado(puesto_id)).is_false()
	assert_int(construccion.celdas_de_elemento(puesto_id).size()).is_equal(CELDAS_MOSTRADOR)
	assert_vector(construccion.celda_de_trabajo(puesto_id)).is_equal(ANCLA_LEJOS)
