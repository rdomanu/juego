# Dos ampliaciones pedidas por el usuario el 2026-07-30, viendo el juego ya en isométrico:
#   · LA FACHADA — "deberíamos poner unos muros fijos que no se pueden modificar que es exactamente
#     el diseño de la comisaría... poniendo además una puerta de acceso donde entren y salgan los npc".
#   · ROTAR CON R — "debe poder rotarse un objeto con la R por ejemplo".
# Tipo: Integration (Construccion + Economia reales, sin mocks). DETERMINISTA: sin azar ni reloj.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")

const TIPO_SALA := &"sala_documentacion"
## Comodidad REAL del catálogo que ocupa MÁS DE UNA celda — es la única forma de que girar se note.
## Si algún día deja de medir 3, el propio test lo dice en vez de pasar en verde por casualidad.
const MUEBLE_LARGO := &"sofa_descanso"


# ── Fixture ──────────────────────────────────────────────────────────────────────────────────
## Comisaría vacía con caja de sobra. Se remonta en cada test (GdUnit corta la suite tras el primer
## FAIL, así que nada de estado compartido — regla del proyecto).
func _mundo(saldo: float = 100000.0) -> Node:
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	economia.saldo_eur = saldo
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_economia(economia)
	return construccion


# ── LA FACHADA ───────────────────────────────────────────────────────────────────────────────

# AC-F1: levantar la fachada cierra el edificio por sus CUATRO lados.
func test_la_fachada_cierra_las_cuatro_caras_del_edificio() -> void:
	var c: Node = _mundo()
	assert_int(c.muros().size()).is_equal(0)   # de partida, sin un solo tabique
	c.levantar_fachada()
	var cols: int = c.edificio_columnas
	var filas: int = c.edificio_filas
	# Una esquina de cada lado, para no depender del recuento exacto.
	assert_bool(c.hay_muro(Vector2i(0, 0), &"arriba")).is_true()
	assert_bool(c.hay_muro(Vector2i(0, 0), &"izquierda")).is_true()
	assert_bool(c.hay_muro(Vector2i(cols - 1, filas - 1), &"abajo")).is_true()
	assert_bool(c.hay_muro(Vector2i(cols - 1, filas - 1), &"derecha")).is_true()
	# Y el total: dos filas completas + dos columnas completas.
	assert_int(c.muros().size()).is_equal(2 * cols + 2 * filas)


# AC-F2: la puerta de acceso EXISTE y es del tipo que deja pasar. Sin esto la comisaría quedaría
# tapiada y no entraría nadie — es la diferencia entre un edificio y una caja.
func test_la_puerta_de_acceso_deja_pasar() -> void:
	var c: Node = _mundo()
	c.levantar_fachada()
	var fila: int = c.CELDA_PUERTA_EDIFICIO.y
	assert_that(c.tipo_de_muro(Vector2i(0, fila), &"izquierda")).is_equal(c.PUERTA)
	assert_bool(c.deja_pasar(Vector2i(0, fila), &"izquierda")).is_true()
	# Y el resto de la fachada NO deja pasar: se entra por la puerta o no se entra.
	assert_bool(c.deja_pasar(Vector2i(0, 0), &"izquierda")).is_false()


# AC-F3: la fachada NO se derriba. Es el plano del edificio, no obra del jugador.
func test_la_fachada_no_se_puede_demoler() -> void:
	var c: Node = _mundo()
	c.levantar_fachada()
	var antes: int = c.muros().size()
	assert_bool(c.demoler_muro(Vector2i(0, 0), &"arriba")).is_false()
	assert_bool(c.demoler_muro(Vector2i(0, c.CELDA_PUERTA_EDIFICIO.y), &"izquierda")).is_false()
	assert_int(c.muros().size()).is_equal(antes)   # sigue entera
	assert_bool(c.hay_muro(Vector2i(0, 0), &"arriba")).is_true()


# AC-F4: tampoco se convierte — ni se tapia la puerta ni se abren huecos nuevos en la fachada.
func test_la_fachada_no_se_puede_convertir() -> void:
	var c: Node = _mundo()
	c.levantar_fachada()
	assert_bool(c.fijar_tipo_de_muro(Vector2i(0, 0), &"arriba", c.PUERTA)).is_false()
	assert_that(c.tipo_de_muro(Vector2i(0, 0), &"arriba")).is_equal(c.TABIQUE)
	var fila: int = c.CELDA_PUERTA_EDIFICIO.y
	assert_bool(c.fijar_tipo_de_muro(Vector2i(0, fila), &"izquierda", c.TABIQUE)).is_false()
	assert_that(c.tipo_de_muro(Vector2i(0, fila), &"izquierda")).is_equal(c.PUERTA)


# AC-F5: un muro del JUGADOR sigue derribándose igual. La fachada es la excepción, no la regla.
func test_un_muro_del_jugador_si_se_demuele() -> void:
	var c: Node = _mundo()
	c.levantar_fachada()
	assert_bool(c.construir_muro(Vector2i(5, 5), &"arriba")).is_true()
	assert_bool(c.es_muro_fijo(c.clave_de_muro(Vector2i(5, 5), &"arriba"))).is_false()
	assert_bool(c.demoler_muro(Vector2i(5, 5), &"arriba")).is_true()
	assert_bool(c.hay_muro(Vector2i(5, 5), &"arriba")).is_false()


# AC-F6: levantarla dos veces deja lo mismo (hace falta: se llama al empezar Y al cargar partida).
func test_levantar_la_fachada_es_idempotente() -> void:
	var c: Node = _mundo()
	c.levantar_fachada()
	var muros_1: int = c.muros().size()
	var saldo_1: float = c.saldo_actual() if c.has_method("saldo_actual") else 0.0
	c.levantar_fachada()
	assert_int(c.muros().size()).is_equal(muros_1)
	var fila: int = c.CELDA_PUERTA_EDIFICIO.y
	assert_that(c.tipo_de_muro(Vector2i(0, fila), &"izquierda")).is_equal(c.PUERTA)
	if c.has_method("saldo_actual"):
		assert_float(c.saldo_actual()).is_equal_approx(saldo_1, 0.01)


# AC-F7: la fachada NO altera los recintos. El modelo ya trataba el perímetro como muro implícito,
# así que declararlo explícito no puede cambiar ninguna zona ya designada. (Si esto fallara, la
# fachada estaría rompiendo el sistema de zonas de la fase C.)
func test_la_fachada_no_cambia_los_recintos() -> void:
	var sin_fachada: Node = _mundo()
	var antes: int = sin_fachada.recinto_de(Vector2i(3, 3)).size()
	var con_fachada: Node = _mundo()
	con_fachada.levantar_fachada()
	assert_int(con_fachada.recinto_de(Vector2i(3, 3)).size()).is_equal(antes)


# ── ROTAR CON R ──────────────────────────────────────────────────────────────────────────────

# AC-R1: el mueble largo del catálogo mide más de una celda. Si dejara de medirlo, girar no
# probaría nada y los tests de abajo pasarían en verde sin comprobar nada real.
func test_el_mueble_de_prueba_ocupa_varias_celdas() -> void:
	var comodidad: Resource = Datos.obtener_silencioso(&"Comodidad", MUEBLE_LARGO)
	assert_object(comodidad).is_not_null()
	assert_int(comodidad.superficie).is_greater(1)


# AC-R2: sin girar, el cuerpo crece hacia +X — el comportamiento de SIEMPRE. Es la garantía de que
# la rotación es aditiva y no cambia nada de lo ya construido.
func test_sin_girar_el_cuerpo_crece_hacia_la_derecha() -> void:
	var c: Node = _mundo()
	c.construir_de_oficio_sala(&"sala_descanso", Rect2i(1, 1, 6, 6))
	var id: StringName = c.construir_elemento(MUEBLE_LARGO, Vector2i(2, 2))
	assert_that(id).is_not_equal(&"")
	assert_int(c.orientacion_de(id)).is_equal(c.HORIZONTAL)
	var celdas: Array = c.celdas_de_elemento(id)
	assert_int(celdas.size()).is_greater(1)
	for i: int in celdas.size():
		assert_that(celdas[i]).is_equal(Vector2i(2 + i, 2))


# AC-R3: girado, el MISMO mueble crece hacia +Y. Es lo que hace la R.
func test_girado_el_cuerpo_crece_hacia_abajo() -> void:
	var c: Node = _mundo()
	c.construir_de_oficio_sala(&"sala_descanso", Rect2i(1, 1, 6, 6))
	var id: StringName = c.construir_elemento(MUEBLE_LARGO, Vector2i(2, 2), c.VERTICAL)
	assert_that(id).is_not_equal(&"")
	assert_int(c.orientacion_de(id)).is_equal(c.VERTICAL)
	var celdas: Array = c.celdas_de_elemento(id)
	for i: int in celdas.size():
		assert_that(celdas[i]).is_equal(Vector2i(2, 2 + i))


# AC-R4: el hueco que ocupa girado es el que se reserva de verdad — no se puede meter otra cosa
# encima. Sin esto, girar sería solo un truco de dibujo y las piezas se solaparían.
func test_girado_reserva_las_celdas_de_abajo() -> void:
	var c: Node = _mundo()
	c.construir_de_oficio_sala(&"sala_descanso", Rect2i(1, 1, 6, 6))
	var id: StringName = c.construir_elemento(MUEBLE_LARGO, Vector2i(2, 2), c.VERTICAL)
	assert_that(id).is_not_equal(&"")
	# La celda de ABAJO está ocupada por su cuerpo; la de la DERECHA, libre (es el caso contrario
	# al de sin girar, y es justo la diferencia que introduce la R).
	assert_that(c.elemento_en(Vector2i(2, 3))).is_equal(id)
	assert_that(c.elemento_en(Vector2i(3, 2))).is_equal(&"")


# AC-R5: girado en el borde de la sala, NO cabe — la validación mide el cuerpo girado, no el de
# antes. (La sala llega hasta la fila 3; un mueble de 3 celdas puesto en la fila 2 se sale.)
func test_girado_no_cabe_si_se_sale_de_la_sala() -> void:
	var c: Node = _mundo()
	c.construir_de_oficio_sala(&"sala_descanso", Rect2i(1, 1, 6, 3))   # filas 1..3
	# Sin girar, en (2,2) cabe de sobra (columnas 2,3,4 dentro de la sala).
	assert_bool(c.validar_elemento(MUEBLE_LARGO, Vector2i(2, 2), &"", c.HORIZONTAL)).is_true()
	# Girado, en (2,2) se saldría por abajo (filas 2,3,4 y la sala acaba en la 3).
	assert_bool(c.validar_elemento(MUEBLE_LARGO, Vector2i(2, 2), &"", c.VERTICAL)).is_false()


# AC-R6: la orientación SOBREVIVE al guardar y cargar. Si no, girarías el sofá, guardarías, y al
# volver estaría atravesado — y encima ocupando otras celdas.
func test_la_orientacion_sobrevive_al_guardado() -> void:
	var c: Node = _mundo()
	c.construir_de_oficio_sala(&"sala_descanso", Rect2i(1, 1, 6, 6))
	var id: StringName = c.construir_elemento(MUEBLE_LARGO, Vector2i(2, 2), c.VERTICAL)
	assert_that(id).is_not_equal(&"")
	var guardado: Dictionary = c.save()

	var otra: Node = _mundo()
	otra.load_state(guardado)
	assert_int(otra.orientacion_de(id)).is_equal(otra.VERTICAL)
	assert_that(otra.elemento_en(Vector2i(2, 3))).is_equal(id)


# AC-R7: un save ANTIGUO (sin el campo `orientacion`) se carga como HORIZONTAL, que es como se
# colocaba todo hasta hoy — una partida vieja se ve exactamente igual que antes.
func test_un_save_antiguo_se_carga_sin_girar() -> void:
	var c: Node = _mundo()
	c.construir_de_oficio_sala(&"sala_descanso", Rect2i(1, 1, 6, 6))
	var id: StringName = c.construir_elemento(MUEBLE_LARGO, Vector2i(2, 2))
	var guardado: Dictionary = c.save()
	# Se simula el save viejo quitándole el campo a mano.
	for elemento: Variant in guardado.get("elementos", []):
		(elemento as Dictionary).erase("orientacion")

	var otra: Node = _mundo()
	otra.load_state(guardado)
	assert_int(otra.orientacion_de(id)).is_equal(otra.HORIZONTAL)
	assert_that(otra.elemento_en(Vector2i(3, 2))).is_equal(id)
