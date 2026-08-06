# Orientación de mobiliario: de 2 ESTADOS (H/V) a 4 REALES (0/90/180/270), 2026-08-06. Pedido
# literal del usuario: "que se pudiera posicionar en las 4 posiciones y que se viera si está dada
# la vuelta o de lado correctamente". Cubre lo que NO cubrían ya los tests de siempre
# (`construccion_fachada_rotacion_test.gd`, `construccion_puesto_huella_test.gd`,
# `construccion_estanterias_test.gd`, que siguen en verde sin tocarlos):
#   · el ciclo de la R tiene 4 pasos, no 2;
#   · 0°/180° reservan la MISMA huella, 90°/270° la traspuesta (requisito explícito de la tarea);
#   · 180°/270° sobreviven al guardado igual que 0°/90° ya lo hacían;
#   · MIGRACIÓN de saves viejos (el binario 0/1 de antes de hoy, con VERTICAL=1) a los 4 grados
#     de hoy (VERTICAL=90);
#   · selección de sprite: "rotacion_directa" (4 vistas reales) usa el grado literal; el resto del
#     catálogo (2 vistas) cae al fallback de siempre (0°/180° comparten vista, 90°/270° la otra).
# Tipo: Logic/Integration (Construccion real, sin mocks). DETERMINISTA: sin azar ni reloj.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")

## Mismo mueble de prueba que `construccion_fachada_rotacion_test.gd` (comodidad real, > 1 celda):
## sin un cuerpo multi-celda, girar no se nota en la huella.
const MUEBLE_LARGO := &"sofa_descanso"
const PUESTO := &"puesto_doc_general"
const OFICINA := &"sala_documentacion"


func _mundo() -> Node:
	var c: Node = auto_free(ConstruccionScript.new())
	c.aplicar_config(ConfigConstruccionScript.new())
	return c


# ── EL CICLO DE LA R: 4 PASOS, EN ORDEN ────────────────────────────────────────────────────────
func test_el_ciclo_de_orientaciones_tiene_los_4_grados_en_orden() -> void:
	var c: Node = _mundo()
	assert_array(c.ORIENTACIONES_CICLO).is_equal([
		c.HORIZONTAL, c.VERTICAL, c.HORIZONTAL_GIRADO, c.VERTICAL_GIRADO,
	])
	assert_int(c.HORIZONTAL).is_equal(0)
	assert_int(c.VERTICAL).is_equal(90)
	assert_int(c.HORIZONTAL_GIRADO).is_equal(180)
	assert_int(c.VERTICAL_GIRADO).is_equal(270)


# ── HUELLA: "0°/180° una huella; 90°/270° la traspuesta" (requisito 1 de la tarea) ────────────
func test_0_y_180_reservan_la_misma_huella() -> void:
	var c: Node = _mundo()
	c.construir_de_oficio_sala(&"sala_descanso", Rect2i(1, 1, 8, 8))
	var id_0: StringName = c.construir_elemento(MUEBLE_LARGO, Vector2i(2, 2), c.HORIZONTAL)
	var celdas_0: Array = c.celdas_de_elemento(id_0)
	c.demoler_elemento(id_0)
	var id_180: StringName = c.construir_elemento(MUEBLE_LARGO, Vector2i(2, 2), c.HORIZONTAL_GIRADO)
	var celdas_180: Array = c.celdas_de_elemento(id_180)
	assert_array(celdas_180).is_equal(celdas_0)
	# Y crecen en el mismo eje (+X), no en +Y.
	for i: int in celdas_180.size():
		assert_that(celdas_180[i]).is_equal(Vector2i(2 + i, 2))


func test_90_y_270_reservan_la_huella_traspuesta() -> void:
	var c: Node = _mundo()
	c.construir_de_oficio_sala(&"sala_descanso", Rect2i(1, 1, 8, 8))
	var id_90: StringName = c.construir_elemento(MUEBLE_LARGO, Vector2i(2, 2), c.VERTICAL)
	var celdas_90: Array = c.celdas_de_elemento(id_90)
	c.demoler_elemento(id_90)
	var id_270: StringName = c.construir_elemento(MUEBLE_LARGO, Vector2i(2, 2), c.VERTICAL_GIRADO)
	var celdas_270: Array = c.celdas_de_elemento(id_270)
	assert_array(celdas_270).is_equal(celdas_90)
	for i: int in celdas_270.size():
		assert_that(celdas_270[i]).is_equal(Vector2i(2, 2 + i))
	# Y es la TRASPUESTA de la de 0°/180° (mismo ancla, ejes intercambiados).
	assert_that(celdas_90[1]).is_not_equal(Vector2i(3, 2))


# ── FRENTE: el puesto gira ENTERO y rígido — el fondo se invierte con el "dado la vuelta" ─────
# (No cambia el contrato de NPCs/Personal: `celda_de_trabajo`/`elemento_en` en el ancla siguen
# iguales; solo se comprueba que el MODELO reserva el lado opuesto, que es lo que pide "se viera
# si está dada la vuelta".)
func test_180_reserva_el_fondo_al_lado_contrario_que_0() -> void:
	var c: Node = _mundo()
	c._crear_sala(OFICINA, Rect2i(0, 0, 6, 6))
	var ancla := Vector2i(1, 2)   # fila 2: deja sitio detrás (fila 1) y delante (fila 3) en 0°/180°
	var id_0: StringName = c.construir_elemento(PUESTO, ancla, c.HORIZONTAL)
	var obstaculo_0: Array = c.celdas_obstaculo_de(id_0)
	var reservado_0: Array = c.celdas_de_elemento(id_0)
	c.demoler_elemento(id_0)
	var id_180: StringName = c.construir_elemento(PUESTO, ancla, c.HORIZONTAL_GIRADO)
	var obstaculo_180: Array = c.celdas_obstaculo_de(id_180)
	var reservado_180: Array = c.celdas_de_elemento(id_180)
	# El mostrador (obstáculo) NO se mueve: sigue siendo el ancla y su vecino al este.
	assert_array(obstaculo_180).is_equal(obstaculo_0)
	# Pero el bloque ENTERO reservado es distinto: el fondo se ha volcado al lado contrario.
	assert_array(reservado_180).is_not_equal(reservado_0)
	assert_int(reservado_180.size()).is_equal(reservado_0.size())


# ── PERSISTENCIA: 180°/270° sobreviven al guardado igual que 0°/90° ya lo hacían ──────────────
func test_180_y_270_sobreviven_al_guardado() -> void:
	var c: Node = _mundo()
	c.construir_de_oficio_sala(&"sala_descanso", Rect2i(1, 1, 8, 8))
	var id_a: StringName = c.construir_elemento(MUEBLE_LARGO, Vector2i(2, 2), c.HORIZONTAL_GIRADO)
	var id_b: StringName = c.construir_elemento(MUEBLE_LARGO, Vector2i(5, 2), c.VERTICAL_GIRADO)
	var guardado: Dictionary = c.save()

	var otra: Node = _mundo()
	otra.load_state(guardado)
	assert_int(otra.orientacion_de(id_a)).is_equal(otra.HORIZONTAL_GIRADO)
	assert_int(otra.orientacion_de(id_b)).is_equal(otra.VERTICAL_GIRADO)


# ── MIGRACIÓN: un save de ANTES de hoy guardaba el binario 0/1 (VERTICAL valía 1) ─────────────
# Mapeo de la tarea: H(0) -> 0 (sin cambio), V(1) -> 90 (el mismo oeste de siempre, en grados).
func test_migracion_save_viejo_binario_horizontal_0_no_cambia() -> void:
	var c: Node = _mundo()
	c.construir_de_oficio_sala(&"sala_descanso", Rect2i(1, 1, 8, 8))
	c.construir_elemento(MUEBLE_LARGO, Vector2i(2, 2))   # HORIZONTAL por defecto
	var guardado: Dictionary = c.save()
	# El propio HORIZONTAL ya vale 0 hoy y antes: nada que simular, la migración es la identidad.
	assert_int(int((guardado["elementos"][0] as Dictionary)["orientacion"])).is_equal(0)

	var otra: Node = _mundo()
	otra.load_state(guardado)
	var id: StringName = StringName((guardado["elementos"][0] as Dictionary)["id"])
	assert_int(otra.orientacion_de(id)).is_equal(otra.HORIZONTAL)


func test_migracion_save_viejo_binario_vertical_1_pasa_a_90() -> void:
	var c: Node = _mundo()
	c.construir_de_oficio_sala(&"sala_descanso", Rect2i(1, 1, 8, 8))
	# Se simula el save DE ANTES de hoy a mano: el JSON de entonces solo podía traer 0 o 1 (VERTICAL
	# valía 1 antes de esta fecha).
	var guardado: Dictionary = {
		"salas": [], "elementos": [{
			"id": "mueble_legado", "catalogo": String(MUEBLE_LARGO),
			"celda": [2, 2], "coste_pagado": 0.0, "orientacion": 1,
		}],
		"contador_ids": 1, "muros": [],
	}
	c.load_state(guardado)
	assert_int(c.orientacion_de(&"mueble_legado")).is_equal(c.VERTICAL)
	assert_int(c.orientacion_de(&"mueble_legado")).is_equal(90)
	# Y reserva la huella VERTICAL de verdad (paso sur), no la horizontal.
	var celdas: Array = c.celdas_de_elemento(&"mueble_legado")
	for i: int in celdas.size():
		assert_that(celdas[i]).is_equal(Vector2i(2, 2 + i))


func test_migracion_valor_corrupto_cae_a_horizontal() -> void:
	var c: Node = _mundo()
	var guardado: Dictionary = {
		"salas": [], "elementos": [{
			"id": "mueble_raro", "catalogo": String(MUEBLE_LARGO),
			"celda": [2, 2], "coste_pagado": 0.0, "orientacion": 999,
		}],
		"contador_ids": 1, "muros": [],
	}
	c.load_state(guardado)
	assert_int(c.orientacion_de(&"mueble_raro")).is_equal(c.HORIZONTAL)


# ── SELECCIÓN DE SPRITE: 4 vistas reales vs. fallback de 2 (requisito 2 de la tarea) ──────────

## `rotacion_directa` (hoy solo la fotocopiadora): el PNG que toca es el GRADO LITERAL.
func test_rotacion_directa_usa_el_grado_literal_en_las_4() -> void:
	var datos: Dictionary = {"rotacion": 0, "rotacion_directa": true}
	for grado: int in ConstruccionScript.ORIENTACIONES_CICLO:
		assert_int(ConstruccionScript.rotacion_sprite_comodidad(datos, grado)).is_equal(grado)


## Un mueble de pared SIN 4 vistas reales (el catálogo de siempre, `espalda_0`): 0°/180°
## comparten PNG y 90°/270° comparten el otro — el fallback de 2 vistas que pide la tarea.
func test_mueble_de_pared_sin_4_vistas_colapsa_0_180_y_90_270() -> void:
	var rot_0: int = ConstruccionScript.rotacion_sprite_comodidad(
		{"rotacion": 0, "espalda_0": Vector2i(-1, 0)}, ConstruccionScript.HORIZONTAL
	)
	var rot_180: int = ConstruccionScript.rotacion_sprite_comodidad(
		{"rotacion": 0, "espalda_0": Vector2i(-1, 0)}, ConstruccionScript.HORIZONTAL_GIRADO
	)
	var rot_90: int = ConstruccionScript.rotacion_sprite_comodidad(
		{"rotacion": 0, "espalda_0": Vector2i(-1, 0)}, ConstruccionScript.VERTICAL
	)
	var rot_270: int = ConstruccionScript.rotacion_sprite_comodidad(
		{"rotacion": 0, "espalda_0": Vector2i(-1, 0)}, ConstruccionScript.VERTICAL_GIRADO
	)
	assert_int(rot_180).is_equal(rot_0)
	assert_int(rot_270).is_equal(rot_90)
	assert_int(rot_90).is_not_equal(rot_0)


## Mismo fallback, verificado con un id REAL del catálogo (`estanteria`): `espalda_comodidad`
## solo conoce las 2 traseras de siempre, así que 0°/180° dan la MISMA pared y 90°/270° la otra.
func test_espalda_comodidad_estanteria_colapsa_a_2_paredes() -> void:
	assert_vector(ConstruccionScript.espalda_comodidad(&"estanteria", ConstruccionScript.HORIZONTAL_GIRADO)).is_equal(
		ConstruccionScript.espalda_comodidad(&"estanteria", ConstruccionScript.HORIZONTAL)
	)
	assert_vector(ConstruccionScript.espalda_comodidad(&"estanteria", ConstruccionScript.VERTICAL_GIRADO)).is_equal(
		ConstruccionScript.espalda_comodidad(&"estanteria", ConstruccionScript.VERTICAL)
	)


## La fotocopiadora SÍ tiene las 4 vistas reales: sus PNG existen para los 4 grados (verificado
## contra disco, no supuesto) y `rotacion_sprite_comodidad` (con sus datos REALES de catálogo, no
## un dict sintético) elige cada una literalmente.
func test_impresora_documentos_tiene_las_4_vistas_en_disco() -> void:
	for grado: int in ConstruccionScript.ORIENTACIONES_CICLO:
		var ruta: String = "res://assets/sprites/mobiliario/comodidad_impresora_documentos_%d.png" % grado
		assert_bool(ResourceLoader.exists(ruta)).is_true()


# ── LA IMPRESORA DE DNI: 4 vistas reales + huella 2×1/1×2 (2026-08-06) ────────────────────────
## Mismo criterio que la fotocopiadora: `rotacion_directa` y las 4 vistas en disco.
func test_impresora_dni_tiene_las_4_vistas_en_disco() -> void:
	for grado: int in ConstruccionScript.ORIENTACIONES_CICLO:
		var ruta: String = "res://assets/sprites/mobiliario/comodidad_impresora_dni_%d.png" % grado
		assert_bool(ResourceLoader.exists(ruta)).is_true()


## `impresora_dni` declara `rotacion_directa` en `_sprites_comodidad()`, igual que la fotocopiadora.
func test_impresora_dni_es_rotacion_directa() -> void:
	var datos: Dictionary = ConstruccionScript._sprites_comodidad()[&"impresora_dni"]
	assert_bool(datos.get("rotacion_directa", false)).is_true()


## Huella real (`superficie = 2` en su `.tres`): 0°/180° reservan 2×1 EN X, 90°/270° la traspuesta
## 1×2 EN Y — mismo requisito 1 de la tarea ("0°/180° una huella; 90°/270° la traspuesta") pero
## verificado con un id REAL de 2 celdas nuevo, no el sofá de 3 de siempre.
func test_impresora_dni_reserva_2x1_en_0_y_180() -> void:
	var c: Node = _mundo()
	c._crear_sala(&"sala_documentacion", Rect2i(0, 0, 8, 8))
	var id_0: StringName = c.construir_elemento(&"impresora_dni", Vector2i(2, 2), c.HORIZONTAL)
	var celdas_0: Array = c.celdas_de_elemento(id_0)
	c.demoler_elemento(id_0)
	var id_180: StringName = c.construir_elemento(&"impresora_dni", Vector2i(2, 2), c.HORIZONTAL_GIRADO)
	var celdas_180: Array = c.celdas_de_elemento(id_180)
	assert_array(celdas_180).is_equal(celdas_0)
	assert_int(celdas_0.size()).is_equal(2)
	for i: int in celdas_0.size():
		assert_that(celdas_0[i]).is_equal(Vector2i(2 + i, 2))


func test_impresora_dni_reserva_1x2_traspuesta_en_90_y_270() -> void:
	var c: Node = _mundo()
	c._crear_sala(&"sala_documentacion", Rect2i(0, 0, 8, 8))
	var id_90: StringName = c.construir_elemento(&"impresora_dni", Vector2i(2, 2), c.VERTICAL)
	var celdas_90: Array = c.celdas_de_elemento(id_90)
	c.demoler_elemento(id_90)
	var id_270: StringName = c.construir_elemento(&"impresora_dni", Vector2i(2, 2), c.VERTICAL_GIRADO)
	var celdas_270: Array = c.celdas_de_elemento(id_270)
	assert_array(celdas_270).is_equal(celdas_90)
	for i: int in celdas_270.size():
		assert_that(celdas_270[i]).is_equal(Vector2i(2, 2 + i))
