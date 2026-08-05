# PINTURA DE PAREDES Y SUELOS (2026-08-04 · quick-spec `construccion-pintura-puertas-preview`
# §2). Tipo: Integration. DETERMINISTA (sin azar, sin reloj, sin GPU: el modelo y `ParedesSalas`
# funcionan igual en headless).
#
# Lo que se demuestra aquí, uno por uno, es el enunciado del usuario:
#   · una pared construida nace BLANCA y pintar un tramo cambia SOLO ese tramo;
#   · la FACHADA no se pinta (es el plano de la comisaría, de ladrillo);
#   · MAYÚS pinta la SALA ENTERA (paredes y suelo) — se prueba por el camino REAL, el mismo que
#     invoca la UI (`pintar_sala_muros` / `pintar_sala_suelo`);
#   · el suelo se pinta por celda y cae al tinte de sala cuando no está pintado;
#   · todo eso sobrevive a un save/load por JSON de verdad;
#   · una VENTANA pintada conserva su cristal (se pinta el muro y las jambas, no el vidrio).
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const PaletaPinturaScript := preload("res://src/core/construccion/paleta_pintura.gd")

const TAM_CELDA: int = 40
## La sala de pruebas (columnas 3..6, filas 3..5): pequeña, con perímetro entero y lejos de la
## fachada, para que ningún tramo suyo sea muro fijo.
const RECT_SALA := Rect2i(3, 3, 4, 3)
## Dos colores de la paleta REAL (nunca inventados a mano: si la paleta cambia, el test sigue).
const VERDE_SALVIA := &"verde_salvia"
const TERRACOTA := &"terracota"


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────

## Construcción cableada con caja de sobra (pintar es gratis, pero levantar los muros no lo es).
func _construccion() -> Node:
	var eco: Node = auto_free(EconomiaScript.new())
	eco.aplicar_config(ConfigEconomiaScript.new())
	eco.abonar(50000.0)
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(eco)
	return construccion


## Una sala CERRADA (todo su perímetro con muro) y la fachada levantada. Devuelve su id.
func _sala_cerrada(construccion: Node) -> StringName:
	construccion.levantar_fachada()
	var sala: StringName = construccion.construir_de_oficio_sala(&"sala_documentacion", RECT_SALA)
	construccion.fijar_paredes_de_sala(sala, true)
	return sala


## La clave de modelo de un tramo del perímetro norte de la sala de pruebas.
func _clave_norte(construccion: Node, columna: int) -> String:
	return construccion.clave_de_muro(Vector2i(columna, RECT_SALA.position.y), &"arriba")


## Round-trip por JSON real con full_precision (el camino exacto del SaveManager).
func _por_json(estado: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(estado, "", true, true))


## ¿Dos colores son EL MISMO? Comparación aproximada a propósito: los colores viajan al save como
## hex de 8 bits por canal, así que un `==` exacto fallaría por el redondeo del round-trip aunque el
## color sea, a todos los efectos, idéntico.
func _igual(a: Color, b: Color) -> bool:
	return a.is_equal_approx(b)


# ── 1. Una pared nace con el color POR DEFECTO (azul suave de la paleta clara, 2026-08-05);
#      pintar un tramo cambia SOLO ese tramo ───────────────────────────────────────────────
func test_pared_nace_con_color_por_defecto_y_pintar_un_tramo_solo_cambia_ese_tramo() -> void:
	# Arrange
	var construccion: Node = _construccion()
	_sala_cerrada(construccion)
	var clave: String = _clave_norte(construccion, 4)
	var vecina: String = _clave_norte(construccion, 5)
	assert_bool(_igual(construccion.color_muro_de(clave), construccion.COLOR_PARED_POR_DEFECTO)) \
		.override_failure_message("una pared recien construida tiene que nacer con el color por defecto") \
		.is_true()
	assert_bool(construccion.muro_pintado(clave)).is_false()

	# Act
	var verde: Color = PaletaPinturaScript.color_de(VERDE_SALVIA)
	var pintado: bool = construccion.pintar_muro(clave, verde)

	# Assert — ese tramo cambia, el de al lado sigue blanco (nada se pinta "de propina").
	assert_bool(pintado).is_true()
	assert_bool(_igual(construccion.color_muro_de(clave), verde)).is_true()
	assert_bool(construccion.muro_pintado(clave)).is_true()
	assert_bool(_igual(construccion.color_muro_de(vecina), construccion.COLOR_PARED_POR_DEFECTO)) \
		.override_failure_message("pintar un tramo NO puede teñir a su vecino") \
		.is_true()


# ── 2. Fallback: un tramo que nunca se pintó responde el color por defecto, aunque no exista ─
func test_color_de_un_tramo_sin_pintar_es_el_color_por_defecto() -> void:
	var construccion: Node = _construccion()
	_sala_cerrada(construccion)
	assert_bool(_igual(construccion.color_muro_de("v:99:99"), construccion.COLOR_PARED_POR_DEFECTO)) \
		.override_failure_message("el fallback de color de pared es el POR DEFECTO, nunca basura") \
		.is_true()


# ── 3. La FACHADA SÍ se pinta (2026-08-05, orden del usuario) — pero sigue sin poderse demoler ──
func test_la_fachada_si_se_pinta() -> void:
	# Arrange — la fachada de arriba del edificio, que `levantar_fachada` marca como fija.
	var construccion: Node = _construccion()
	construccion.levantar_fachada()
	var clave_fachada: String = construccion.clave_de_muro(Vector2i(5, 0), &"arriba")
	assert_bool(construccion.es_muro_fijo(clave_fachada)) \
		.override_failure_message("el fixture necesita que ese tramo SEA fachada") \
		.is_true()

	# Act
	var pintado: bool = construccion.pintar_muro(clave_fachada, Color.RED)

	# Assert — se acepta, el color se guarda y el tramo queda marcado como pintado: la fachada es
	# obra pintable como cualquier tabique.
	assert_bool(pintado).is_true()
	assert_bool(_igual(construccion.color_muro_de(clave_fachada), Color.RED)).is_true()
	assert_bool(construccion.muro_pintado(clave_fachada)).is_true()

	# Pero sigue siendo el PLANO del edificio, no obra tuya: pintarla no la vuelve demolible (misma
	# API que ya cubre `construccion_fachada_rotacion_test.gd` para la fachada sin pintar).
	assert_bool(construccion.demoler_muro(Vector2i(5, 0), &"arriba")) \
		.override_failure_message("pintar la fachada NO la convierte en demolible") \
		.is_false()


# ── 3b. Pintar donde NO hay pared se rechaza (no se guarda pintura "en el aire") ──────────
func test_pintar_donde_no_hay_pared_se_rechaza() -> void:
	var construccion: Node = _construccion()
	var clave: String = construccion.clave_de_muro(Vector2i(10, 10), &"arriba")
	assert_bool(construccion.pintar_muro(clave, Color.RED)).is_false()
	assert_bool(construccion.muro_pintado(clave)).is_false()


# ── 4. MAYÚS: la SALA ENTERA (paredes), fachada del perímetro incluida (2026-08-05) ────────
func test_pintar_sala_muros_tine_todo_el_perimetro_incluida_la_fachada() -> void:
	# Arrange — la sala pegada a la fachada IZQUIERDA: así su perímetro incluye un tramo fijo.
	var construccion: Node = _construccion()
	construccion.levantar_fachada()
	var sala: StringName = construccion.construir_de_oficio_sala(
		&"sala_documentacion", Rect2i(0, 0, 4, 3)
	)
	construccion.fijar_paredes_de_sala(sala, true)
	var terracota: Color = PaletaPinturaScript.color_de(TERRACOTA)

	# Act
	var pintados: int = construccion.pintar_sala_muros(sala, terracota)

	# Assert — se pintó algo, un tramo INTERIOR quedó terracota...
	assert_int(pintados).is_greater(0)
	assert_bool(_igual(construccion.color_muro_de(
		construccion.clave_de_muro(Vector2i(2, 2), &"abajo")
	), terracota)).is_true()
	# ...y el tramo de FACHADA del propio perímetro TAMBIÉN (2026-08-05: pintar la sala entera ya no
	# deja fuera su lado de fachada — la fachada se pinta como cualquier tramo).
	var clave_fachada: String = construccion.clave_de_muro(Vector2i(0, 1), &"izquierda")
	assert_bool(construccion.es_muro_fijo(clave_fachada)) \
		.override_failure_message("el fixture necesita que ese tramo del perimetro SEA fachada") \
		.is_true()
	assert_bool(_igual(construccion.color_muro_de(clave_fachada), terracota)) \
		.override_failure_message("pintar la sala entera SI pinta su lado de fachada") \
		.is_true()


# ── 4b. MAYÚS sobre un tramo de FACHADA: pinta EL EDIFICIO ENTERO (2026-08-05) ─────────────
func test_pintar_edificio_muros_pinta_fachada_y_tabiques() -> void:
	# Arrange — una sala con paredes (tabiques interiores) + la fachada levantada, para que el
	# edificio tenga las DOS familias de tramos que `pintar_edificio_muros` debe alcanzar.
	var construccion: Node = _construccion()
	var sala: StringName = _sala_cerrada(construccion)
	var tramos_de_la_sala: int = construccion.pintar_sala_muros(sala, Color.WHITE)
	var azul: Color = PaletaPinturaScript.color_de(&"azul_institucional")

	# Act
	var pintados: int = construccion.pintar_edificio_muros(azul)

	# Assert — pinta MÁS que el perímetro de una sola sala (fachada + tabiques de otras salas
	# incluidos) y CADA tramo del edificio queda con el color nuevo.
	assert_int(pintados) \
		.override_failure_message("pintar el edificio tiene que alcanzar mas tramos que una sola sala") \
		.is_greater(tramos_de_la_sala)
	for clave: String in construccion.muros():
		assert_bool(_igual(construccion.color_muro_de(clave), azul)).is_true()
	# Y la fachada, en concreto, también quedó pintada (es la pieza que antes se quedaba fuera).
	var clave_fachada: String = construccion.clave_de_muro(Vector2i(5, 0), &"arriba")
	assert_bool(construccion.es_muro_fijo(clave_fachada)).is_true()
	assert_bool(construccion.muro_pintado(clave_fachada)).is_true()


# ── 5. Suelo: por celda, con fallback al tinte de sala, y la sala entera con MAYÚS ────────
func test_suelo_por_celda_y_sala_entera_con_fallback_al_tinte_de_sala() -> void:
	# Arrange
	var construccion: Node = _construccion()
	var sala: StringName = _sala_cerrada(construccion)
	var celda := Vector2i(4, 4)
	var otra := Vector2i(5, 4)
	var tinte_de_sala: Color = construccion.color_suelo_de(celda)
	assert_bool(construccion.suelo_pintado(celda)) \
		.override_failure_message("el suelo empieza SIN pintar (cae al tinte de su sala)") \
		.is_false()

	# Act 1 — una sola celda.
	var verde: Color = PaletaPinturaScript.color_de(VERDE_SALVIA)
	assert_bool(construccion.pintar_suelo(celda, verde)).is_true()

	# Assert 1 — cambia esa celda; la de al lado sigue en el tinte de la sala.
	assert_bool(_igual(construccion.color_suelo_de(celda), verde)).is_true()
	assert_bool(_igual(construccion.color_suelo_de(otra), tinte_de_sala)) \
		.override_failure_message("pintar una celda NO puede teñir a su vecina") \
		.is_true()

	# Act 2 — la sala entera (el gesto de MAYÚS).
	var terracota: Color = PaletaPinturaScript.color_de(TERRACOTA)
	var pintadas: int = construccion.pintar_sala_suelo(sala, terracota)

	# Assert 2 — TODAS las celdas de la sala, incluida la que ya estaba pintada de otro color.
	assert_int(pintadas).is_equal(construccion.area_de_sala(sala))
	for c: Vector2i in construccion.celdas_de_sala(sala):
		assert_bool(_igual(construccion.color_suelo_de(c), terracota)).is_true()


# ── 5b. En la calle no se pinta ───────────────────────────────────────────────────────────
func test_pintar_suelo_fuera_del_edificio_se_rechaza() -> void:
	var construccion: Node = _construccion()
	assert_bool(construccion.pintar_suelo(Vector2i(-1, 4), Color.RED)).is_false()
	assert_bool(construccion.suelo_pintado(Vector2i(-1, 4))).is_false()


# ── 5c. MAYÚS sobre una celda SIN sala: pinta TODAS las baldosas del edificio (2026-08-05) ─
func test_pintar_edificio_suelos_pinta_todas_las_celdas_del_edificio() -> void:
	# Arrange — dos salas separadas por un pasillo, para que "todo el edificio" cruce varias salas
	# Y celdas sin ninguna sala (el pasillo).
	var construccion: Node = _construccion()
	construccion.levantar_fachada()
	var sala_a: StringName = construccion.construir_de_oficio_sala(
		&"sala_documentacion", Rect2i(1, 1, 4, 3)
	)
	var sala_b: StringName = construccion.construir_de_oficio_sala(
		&"sala_odac", Rect2i(6, 1, 4, 3)
	)
	var celda_pasillo := Vector2i(1, 7)
	var celda_fuera := Vector2i(-1, 7)
	var celeste: Color = PaletaPinturaScript.color_de(&"celeste_apagado")

	# Act
	var pintadas: int = construccion.pintar_edificio_suelos(celeste)

	# Assert — el contador coincide con TODA la rejilla del edificio…
	assert_int(pintadas).is_equal(construccion.edificio_columnas * construccion.edificio_filas)
	# …celdas de las dos salas quedan pintadas…
	for c: Vector2i in construccion.celdas_de_sala(sala_a):
		assert_bool(_igual(construccion.color_suelo_de(c), celeste)).is_true()
	for c: Vector2i in construccion.celdas_de_sala(sala_b):
		assert_bool(_igual(construccion.color_suelo_de(c), celeste)).is_true()
	# …y el pasillo (celda SIN sala) también.
	assert_bool(_igual(construccion.color_suelo_de(celda_pasillo), celeste)) \
		.override_failure_message("el pasillo (sin sala) tambien es del edificio: tiene que pintarse") \
		.is_true()
	# Pero una celda FUERA del edificio se queda sin pintar: la calle no es del edificio.
	assert_bool(construccion.suelo_pintado(celda_fuera)) \
		.override_failure_message("una celda fuera del edificio NO puede quedar pintada") \
		.is_false()


# ── 5d. ACABADO DEL SUELO (2026-08-05 · quick-spec §3d, tarea 4): pintar LISO se guarda y
#      sobrevive a un save/load real por JSON, junto a su color ──────────────────────────
func test_pintar_suelo_liso_sobrevive_a_save_load_json() -> void:
	# Arrange — una celda pintada de LISO (no el acabado por defecto, que es baldosa).
	var a: Node = _construccion()
	var sala: StringName = _sala_cerrada(a)
	var celda: Vector2i = a.celdas_de_sala(sala)[0]
	var terracota: Color = PaletaPinturaScript.color_de(TERRACOTA)
	assert_bool(a.pintar_suelo(celda, terracota, a.ACABADO_LISO)).is_true()
	assert_bool(a.acabado_suelo_de(celda) == a.ACABADO_LISO) \
		.override_failure_message("pintar_suelo con acabado LISO tiene que guardarlo en el modelo") \
		.is_true()

	# Act — round-trip por JSON real (el camino exacto del SaveManager).
	var b: Node = _construccion()
	b.load_state(_por_json(a.save()))

	# Assert — color Y acabado sobreviven juntos.
	assert_bool(_igual(b.color_suelo_de(celda), terracota)).is_true()
	assert_bool(b.acabado_suelo_de(celda) == a.ACABADO_LISO) \
		.override_failure_message("el acabado LISO tiene que sobrevivir al save/load, igual que el color") \
		.is_true()


# ── 5e. Un save VIEJO (sin el 4º campo de acabado) carga esa celda como BALDOSA ───────────
# Retrocompatibilidad (ADR-0002): un save de antes de esta fecha solo trae [x, y, hex] — nunca
# hubo otra cosa que baldosa antes de que existiera el concepto de acabado.
func test_save_viejo_sin_campo_acabado_carga_como_baldosa() -> void:
	# Arrange — un dict de save "a mano", con el formato de ANTES (3 elementos, sin acabado).
	var construccion: Node = _construccion()
	var celda := Vector2i(4, 4)
	var estado: Dictionary = {
		"salas": [], "elementos": [], "contador_ids": 0, "muros": [], "colores_muros": [],
		"colores_suelos": [[celda.x, celda.y, PaletaPinturaScript.a_hex(Color.RED)]],
	}

	# Act
	construccion.load_state(_por_json(estado))

	# Assert — el color carga bien y el acabado cae al valor de siempre: baldosa.
	assert_bool(construccion.suelo_pintado(celda)).is_true()
	assert_bool(construccion.acabado_suelo_de(celda) == construccion.ACABADO_BALDOSA) \
		.override_failure_message("un save sin campo de acabado tiene que cargar esa celda como BALDOSA") \
		.is_true()


# ── 5f. `pintar_edificio_suelos` respeta el acabado que se le pasa (MAYÚS de suelo con LISO) ──
func test_pintar_edificio_suelos_respeta_el_acabado() -> void:
	# Arrange
	var construccion: Node = _construccion()
	construccion.levantar_fachada()
	var celeste: Color = PaletaPinturaScript.color_de(&"celeste_apagado")

	# Act
	var pintadas: int = construccion.pintar_edificio_suelos(celeste, construccion.ACABADO_LISO)

	# Assert — TODO el edificio queda con el acabado pedido, no solo con el color.
	assert_int(pintadas).is_equal(construccion.edificio_columnas * construccion.edificio_filas)
	assert_bool(construccion.acabado_suelo_de(Vector2i(0, 0)) == construccion.ACABADO_LISO) \
		.override_failure_message("pintar_edificio_suelos tiene que respetar el acabado pasado") \
		.is_true()
	assert_bool(construccion.acabado_suelo_de(Vector2i(10, 5)) == construccion.ACABADO_LISO).is_true()
	# Y sin pasar acabado, el comportamiento de SIEMPRE (retrocompatible): baldosa por defecto.
	var b: Node = _construccion()
	b.levantar_fachada()
	b.pintar_edificio_suelos(celeste)
	assert_bool(b.acabado_suelo_de(Vector2i(0, 0)) == b.ACABADO_BALDOSA) \
		.override_failure_message("sin acabado explicito, pintar_edificio_suelos sigue pintando baldosa") \
		.is_true()


# ── 6. PERSISTENCIA: paredes y suelos pintados sobreviven al round-trip por JSON ──────────
func test_guardar_y_cargar_conserva_la_pintura_de_paredes_y_suelos() -> void:
	# Arrange — mundo A con un tramo pintado a mano y una sala con el suelo entero pintado.
	var a: Node = _construccion()
	var sala: StringName = _sala_cerrada(a)
	var verde: Color = PaletaPinturaScript.color_de(VERDE_SALVIA)
	var terracota: Color = PaletaPinturaScript.color_de(TERRACOTA)
	var clave: String = _clave_norte(a, 4)
	a.pintar_muro(clave, verde)
	a.pintar_sala_suelo(sala, terracota)
	var celda_muestra: Vector2i = a.celdas_de_sala(sala)[0]

	# Act — save → JSON real → load en un mundo B nuevo.
	var b: Node = _construccion()
	b.load_state(_por_json(a.save()))

	# Assert — el color del tramo, el del suelo y el "sin pintar" del vecino, campo a campo.
	assert_bool(_igual(b.color_muro_de(clave), verde)) \
		.override_failure_message("el color de la pared tiene que sobrevivir al save/load") \
		.is_true()
	assert_bool(_igual(b.color_suelo_de(celda_muestra), terracota)).is_true()
	assert_bool(b.muro_pintado(_clave_norte(a, 5))) \
		.override_failure_message("un tramo que nunca se pinto no puede aparecer pintado al cargar") \
		.is_false()


# ── 6b. La pintura de una pared DERRIBADA no resucita al cargar ───────────────────────────
func test_la_pintura_de_una_pared_derribada_no_vuelve_al_cargar() -> void:
	# Arrange
	var a: Node = _construccion()
	_sala_cerrada(a)
	var celda := Vector2i(4, RECT_SALA.position.y)
	var clave: String = a.clave_de_muro(celda, &"arriba")
	a.pintar_muro(clave, PaletaPinturaScript.color_de(TERRACOTA))

	# Act — se derriba ese tramo y se hace el round-trip.
	a.demoler_muro(celda, &"arriba")
	var b: Node = _construccion()
	b.load_state(_por_json(a.save()))

	# Assert — ni en el modelo de A ni tras cargar queda rastro de aquella pintura.
	assert_bool(a.muro_pintado(clave)).is_false()
	assert_bool(b.muro_pintado(clave)).is_false()


# ── 7. DIBUJO: el color del modelo llega al tramo dibujado ────────────────────────────────
func test_el_tramo_pintado_se_dibuja_con_su_color() -> void:
	# Arrange — el modelo + la capa de paredes cableada como en Main (hook de layout incluido).
	var construccion: Node = _construccion()
	_sala_cerrada(construccion)
	var paredes: Node2D = auto_free(ParedesSalasScript.new())
	add_child(paredes)
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	construccion.fijar_hook_layout(Callable(paredes, "actualizar"))
	var celda := Vector2i(4, RECT_SALA.position.y)
	var verde: Color = PaletaPinturaScript.color_de(VERDE_SALVIA)

	# Act — se pinta por el modelo; el hook debe disparar el repintado solo.
	construccion.pintar_muro_en(celda, &"arriba", verde)

	# Assert — hay al menos un tramo DIBUJADO con ese color exacto, y sigue habiendo tramos con
	# el color por defecto (las paredes sin pintar) — o sea: se pintó ese tramo, no la sala entera.
	var con_color: int = 0
	var sin_pintar: int = 0
	for tramo: Dictionary in paredes._tramos:
		var color: Color = tramo["color"]
		if color.is_equal_approx(verde):
			con_color += 1
		elif color.is_equal_approx(construccion.COLOR_PARED_POR_DEFECTO):
			sin_pintar += 1
	assert_int(con_color) \
		.override_failure_message("el tramo pintado tiene que DIBUJARSE con su color") \
		.is_greater(0)
	assert_int(sin_pintar) \
		.override_failure_message("los tramos sin pintar siguen con el color por defecto") \
		.is_greater(0)


# ── 8. Una VENTANA pintada conserva su CRISTAL ────────────────────────────────────────────
# El usuario: *"las ventanas conservan su cristal; si el tramo está pintado, se pinta la parte de
# muro/jambas, no el cristal"*. Se comprueba sobre lo REALMENTE dibujado: en ese mismo tramo tiene
# que haber a la vez piezas con el color pintado (los muñones de muro) y una con `COLOR_VENTANA`
# (el vidrio), y el CENTRO del tramo tiene que seguir siendo cristal.
func test_una_ventana_pintada_conserva_su_cristal() -> void:
	# Arrange
	var construccion: Node = _construccion()
	_sala_cerrada(construccion)
	var paredes: Node2D = auto_free(ParedesSalasScript.new())
	add_child(paredes)
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	construccion.fijar_hook_layout(Callable(paredes, "actualizar"))
	var celda := Vector2i(4, RECT_SALA.position.y)
	assert_bool(construccion.fijar_tipo_de_muro(celda, &"arriba", construccion.VENTANA)).is_true()

	# Act — se pinta ESE tramo (el que es ventana).
	var terracota: Color = PaletaPinturaScript.color_de(TERRACOTA)
	assert_bool(construccion.pintar_muro_en(celda, &"arriba", terracota)).is_true()

	# Assert — sobre la geometría de ese tramo: muñones pintados + cristal intacto en el centro.
	var desde: Vector2 = construccion.esquina_en_pantalla(celda.x, celda.y)
	var hasta: Vector2 = construccion.esquina_en_pantalla(celda.x + 1, celda.y)
	var color_centro: Color = _color_dibujado_en(paredes, desde.lerp(hasta, 0.5))
	# 12 % del tramo: dentro del muñón de muro (que llega al 25 %) y lo bastante lejos del vértice
	# como para no confundirse con el tramo perpendicular que enlaza en esa esquina.
	var color_extremo: Color = _color_dibujado_en(paredes, desde.lerp(hasta, 0.12))
	assert_bool(_igual(color_centro, ParedesSalasScript.COLOR_VENTANA)) \
		.override_failure_message("el CRISTAL de la ventana no se pinta: conserva COLOR_VENTANA") \
		.is_true()
	assert_bool(_igual(color_extremo, terracota)) \
		.override_failure_message("el MURO de los extremos de la ventana SI se pinta") \
		.is_true()


## El color de la primera pieza dibujada que pasa por ese punto (transparente si no hay ninguna).
## Se mide contra `_tramos` (la lista de trabajo de `ParedesSalas`), que es lo que se entrega a los
## nodos `TramoPared` — el mismo criterio que ya usan los tests de puertas y ventanas.
func _color_dibujado_en(paredes: Node2D, punto: Vector2) -> Color:
	for tramo: Dictionary in paredes._tramos:
		var cercano: Vector2 = Geometry2D.get_closest_point_to_segment(
			punto, tramo["desde"], tramo["hasta"]
		)
		if punto.distance_to(cercano) <= 1.0:
			return tramo["color"]
	return Color.TRANSPARENT


# ── 9c. EL RODAPIÉ SE MUDÓ A LA PARED (2026-08-05 · quick-spec §3c) ───────────────────────
# Orden del usuario: *"rodapié (zócalo) más pequeño y EN LA PARED, no en el suelo"*. Se comprueba
# por los dos lados: que la BALDOSA del suelo ya no lleva ninguna tira de zócalo (su atlas es de
# una sola fila y sin el blanco roto dentro) y que los TRAMOS DE MURO interiores sí la llevan.
func test_la_baldosa_del_suelo_ya_no_lleva_zocalo_ni_filas_de_mascara() -> void:
	# Arrange — el atlas de una baldosa, generado por el código real para un color cualquiera.
	var construccion: Node = _construccion()
	var textura: Texture2D = construccion._textura_de_celda(Color(0.4, 0.5, 0.6))

	# Assert 1 — el atlas es una TIRA: `VARIACIONES_BALDOSA` de ancho por UNA baldosa de alto (antes
	# eran 16 filas, una por máscara de "qué lados de la celda tocan pared").
	var lado: int = construccion._tam_celda
	assert_int(textura.get_height()) \
		.override_failure_message("el atlas de baldosa tiene que ser de UNA fila (murio la mascara)") \
		.is_equal(lado)
	assert_int(textura.get_width()).is_equal(lado * ConstruccionScript.VARIACIONES_BALDOSA)

	# Assert 2 — ni un solo píxel del blanco roto del rodapié dentro de la baldosa.
	var imagen: Image = textura.get_image()
	var pixeles_de_rodapie: int = 0
	for y: int in imagen.get_height():
		for x: int in imagen.get_width():
			if imagen.get_pixel(x, y).is_equal_approx(ParedesSalasScript.COLOR_RODAPIE):
				pixeles_de_rodapie += 1
	assert_int(pixeles_de_rodapie) \
		.override_failure_message("el suelo NO puede llevar rodapie pintado dentro de la baldosa") \
		.is_equal(0)


func test_los_muros_interiores_llevan_rodapie_y_la_fachada_no() -> void:
	# Arrange — sala cerrada + fachada levantada, dibujadas por el código real.
	var construccion: Node = _construccion()
	_sala_cerrada(construccion)
	var paredes: Node2D = auto_free(ParedesSalasScript.new())
	add_child(paredes)
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)

	# Act — se cuentan las piezas dibujadas CON rodapié (los muros interiores de la sala).
	var con_rodapie: int = 0
	for tramo: Dictionary in paredes._tramos:
		var rodapie: Color = tramo.get("rodapie", Color.TRANSPARENT)
		if rodapie.a <= 0.0:
			continue
		con_rodapie += 1
		assert_bool(_igual(rodapie, ParedesSalasScript.COLOR_RODAPIE)).is_true()

	# Assert 1 — los muros de la sala lo llevan.
	assert_int(con_rodapie) \
		.override_failure_message("los tramos de muro interior tienen que llevar rodapie") \
		.is_greater(0)

	# Assert 2 — un tramo de FACHADA, identificado por el MODELO (`es_muro_fijo`) y no por su color
	# —desde 2026-08-05 la fachada se pinta como cualquier tramo, así que el color ya no la delata—,
	# sigue sin llevar rodapié: es estructura del edificio, no carpintería de interior.
	var clave_fachada: String = construccion.clave_de_muro(Vector2i(5, 0), &"arriba")
	assert_bool(construccion.es_muro_fijo(clave_fachada)) \
		.override_failure_message("el fixture necesita que ese tramo SEA fachada") \
		.is_true()
	var desde: Vector2 = construccion.esquina_en_pantalla(5, 0)
	var hasta: Vector2 = construccion.esquina_en_pantalla(6, 0)
	assert_bool(_igual(
		_rodapie_dibujado_en(paredes, desde.lerp(hasta, 0.5)), Color.TRANSPARENT
	)).override_failure_message("la fachada (fija) NO lleva rodapie").is_true()


func test_el_rodapie_no_cruza_el_hueco_de_una_puerta() -> void:
	# Arrange — una puerta REAL en el tramo norte de la sala.
	var construccion: Node = _construccion()
	_sala_cerrada(construccion)
	var paredes: Node2D = auto_free(ParedesSalasScript.new())
	add_child(paredes)
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	construccion.fijar_hook_layout(Callable(paredes, "actualizar"))
	var celda := Vector2i(4, RECT_SALA.position.y)
	assert_bool(construccion.fijar_tipo_de_muro(celda, &"arriba", construccion.PUERTA)).is_true()

	# Act — geometría de ESE tramo: centro (el hueco) y un extremo (el muñón de muro).
	var desde: Vector2 = construccion.esquina_en_pantalla(celda.x, celda.y)
	var hasta: Vector2 = construccion.esquina_en_pantalla(celda.x + 1, celda.y)

	# Assert — en el centro no hay NINGUNA pieza (por eso se pasa), así que tampoco rodapié; en el
	# muñón (12 % del tramo, dentro del 25 % que sigue siendo pared) el rodapié está.
	assert_bool(_hay_pieza_en(paredes, desde.lerp(hasta, 0.5))) \
		.override_failure_message("el hueco de la puerta tiene que seguir siendo hueco") \
		.is_false()
	assert_bool(_igual(
		_rodapie_dibujado_en(paredes, desde.lerp(hasta, 0.12)), ParedesSalasScript.COLOR_RODAPIE
	)).override_failure_message("los muñones de la puerta SI llevan rodapie").is_true()


## ¿Pasa alguna pieza dibujada por ese punto? (mismo criterio de cercanía que `_color_dibujado_en`).
func _hay_pieza_en(paredes: Node2D, punto: Vector2) -> bool:
	return _color_dibujado_en(paredes, punto) != Color.TRANSPARENT


## El rodapié de la primera pieza dibujada que pasa por ese punto (transparente si no hay ninguna,
## o si esa pieza no lleva rodapié).
func _rodapie_dibujado_en(paredes: Node2D, punto: Vector2) -> Color:
	for tramo: Dictionary in paredes._tramos:
		var cercano: Vector2 = Geometry2D.get_closest_point_to_segment(
			punto, tramo["desde"], tramo["hasta"]
		)
		if punto.distance_to(cercano) <= 1.0:
			return tramo.get("rodapie", Color.TRANSPARENT)
	return Color.TRANSPARENT


# ── 9. La PALETA: 30 colores, blanco el primero, todos válidos y sin ids repetidos ────────
func test_la_paleta_tiene_30_colores_con_el_blanco_el_primero() -> void:
	assert_int(PaletaPinturaScript.COLORES.size()).is_equal(30)
	assert_bool(_igual(PaletaPinturaScript.por_defecto(), Color.WHITE)).is_true()
	assert_bool(_igual(PaletaPinturaScript.colores()[0], Color.WHITE)).is_true()
	var ids: Dictionary = {}
	for entrada: Dictionary in PaletaPinturaScript.COLORES:
		var id: StringName = entrada["id"]
		assert_bool(ids.has(id)) \
			.override_failure_message("id de color repetido en la paleta: %s" % id) \
			.is_false()
		ids[id] = true
		assert_bool(Color.html_is_valid(String(entrada["hex"]))) \
			.override_failure_message("hex invalido en la paleta: %s" % entrada["hex"]) \
			.is_true()
		assert_bool(entrada["familia"] in PaletaPinturaScript.FAMILIAS) \
			.override_failure_message("familia desconocida: %s" % entrada["familia"]) \
			.is_true()


# ── 9b. El hex del save es de ida y vuelta ────────────────────────────────────────────────
func test_hex_ida_y_vuelta_devuelve_el_mismo_color() -> void:
	for color: Color in PaletaPinturaScript.colores():
		assert_bool(_igual(PaletaPinturaScript.desde_hex(PaletaPinturaScript.a_hex(color)), color)) \
			.is_true()
	# Y un hex corrupto NO revienta la carga: cae al blanco por defecto (ADR-0002).
	assert_bool(_igual(PaletaPinturaScript.desde_hex("no-es-un-color"), Color.WHITE)).is_true()
