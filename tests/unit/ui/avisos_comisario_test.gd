# AvisosComisario — la PILA DE AVISOS (toasts), F3 2026-08-18. Maqueta vinculante:
# `design/ux/maquetas-menu-2026-08/maqueta_avisos.png`. Este archivo cubre la ESTRUCTURA de una
# tarjeta por severidad (forma + color + texto: el color nunca es la única señal), el
# comportamiento de la PILA (aforo, cola de espera, compactado al cerrar) y la COLOCACIÓN (ancla
# bajo el HUD y el desplazamiento cuando la ficha de ventanilla está abierta).
#
# El MAPEO señal→aviso vive en `avisos_comisario_bus_test.gd` (archivos partidos por el límite de
# ~16 KB del escáner de GdUnit4 — gotcha del proyecto).
#
# Tipo: Logic/UI. DETERMINISTA — sin esperas de reloj real: el autodesvanecido se prueba emitiendo
# a mano el `timeout` del `Timer` de la tarjeta, nunca durmiendo segundos.
extends GdUnitTestSuite

const AvisosComisarioScript := preload("res://src/ui/avisos_comisario.gd")
const KitUIComisarioScript := preload("res://src/ui/kit_ui_comisario.gd")


## Doble mínimo de la ficha de ventanilla: solo lo que la pila le pregunta (si está visible y por
## dónde le pasa su borde izquierdo).
class FichaFalsa extends CanvasLayer:
	var borde: float = 700.0

	func borde_izquierdo() -> float:
		return borde


## Una pila de avisos ya en el árbol (su `_ready` construye la UI y se engancha al viewport).
func _crear_avisos() -> CanvasLayer:
	var avisos: CanvasLayer = auto_free(AvisosComisarioScript.new())
	add_child(avisos)
	return avisos


func _tarjeta(avisos: CanvasLayer, indice: int) -> PanelContainer:
	return avisos._pila.get_child(indice) as PanelContainer


func _texto(tarjeta: PanelContainer, nombre: String) -> String:
	var etiqueta: Label = tarjeta.find_child(nombre, true, false) as Label
	return "" if etiqueta == null else etiqueta.text


# ── Estructura de una tarjeta por severidad ──────────────────────────────────────────────────────
func test_el_critico_lleva_triangulo_borde_rojo_y_es_persistente() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	avisos.avisar_evento(
		AvisosComisarioScript.SEV_CRITICO, "Saldo en números rojos", "-1.240 €"
	)
	var tarjeta: PanelContainer = _tarjeta(avisos, 0)
	assert_bool(tarjeta.get_meta("persistente")).is_true()
	assert_str(_texto(tarjeta, "Titulo")).is_equal("Saldo en números rojos")
	assert_str(_texto(tarjeta, "Detalle")).is_equal("-1.240 €")
	# Forma: triángulo de alerta (no basta el color).
	var glifo: Control = tarjeta.find_child("Glifo", true, false)
	assert_int(glifo.tipo).is_equal(KitUIComisarioScript.GlifoModerno.Tipo.TRIANGULO_ALERTA)
	# Color de respaldo: borde rojo de 2 px en el marco de la tarjeta.
	var estilo: StyleBoxFlat = tarjeta.get_theme_stylebox("panel") as StyleBoxFlat
	assert_int(estilo.border_width_top).is_equal(2)
	assert_that(estilo.border_color).is_equal(KitUIComisarioScript.MOD_COLOR_ROJO)


func test_el_critico_dice_por_escrito_que_es_persistente_y_trae_su_cierre() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	avisos.avisar_evento(AvisosComisarioScript.SEV_CRITICO, "Insolvencia", "detalle")
	var tarjeta: PanelContainer = _tarjeta(avisos, 0)
	# El rótulo escrito, no solo el borde: explica POR QUÉ este aviso no se va solo.
	assert_str(_texto(tarjeta, "Persistente")).is_equal("Persistente")
	assert_object(tarjeta.find_child("BotonCerrar", true, false)).is_not_null()
	# Un persistente NO tiene reloj de autodesvanecido ni barra de progreso.
	assert_object(tarjeta.get_node_or_null("Reloj")).is_null()
	assert_object(tarjeta.get_node_or_null("Cuerpo/Barra")).is_null()


func test_el_aviso_lleva_globo_ambar_y_barra_de_autodesvanecido() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	avisos.avisar_evento(
		AvisosComisarioScript.SEV_AVISO, "Nueva reclamación", "Documentación · por una espera larga"
	)
	var tarjeta: PanelContainer = _tarjeta(avisos, 0)
	assert_bool(tarjeta.get_meta("persistente")).is_false()
	var glifo: Control = tarjeta.find_child("Glifo", true, false)
	assert_int(glifo.tipo).is_equal(KitUIComisarioScript.GlifoModerno.Tipo.GLOBO_AVISO)
	assert_that(glifo.color).is_equal(KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO)
	assert_object(tarjeta.get_node_or_null("Cuerpo/Barra")).is_not_null()
	var reloj: Timer = tarjeta.get_node_or_null("Reloj") as Timer
	assert_float(reloj.wait_time).is_equal(
		avisos.duraciones[AvisosComisarioScript.SEV_AVISO]
	)


func test_el_info_lleva_circulo_azul_y_dura_menos_que_un_aviso() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	avisos.avisar_evento(
		AvisosComisarioScript.SEV_INFO, "Elena Ortiz se va a descansar", "Deja DNI 1"
	)
	var tarjeta: PanelContainer = _tarjeta(avisos, 0)
	var glifo: Control = tarjeta.find_child("Glifo", true, false)
	assert_int(glifo.tipo).is_equal(KitUIComisarioScript.GlifoModerno.Tipo.CIRCULO_INFO)
	assert_that(glifo.color).is_equal(KitUIComisarioScript.MOD_COLOR_ACENTO)
	# Jerarquía de lectura de la maqueta: INFO se va antes que AVISO, y el CRÍTICO no se va.
	assert_float(avisos.duraciones[AvisosComisarioScript.SEV_INFO]).is_less(
		avisos.duraciones[AvisosComisarioScript.SEV_AVISO]
	)
	assert_float(avisos.duraciones[AvisosComisarioScript.SEV_CRITICO]).is_equal(0.0)


func test_un_aviso_sin_detalle_no_pinta_la_linea_gris() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	avisos.avisar_evento(AvisosComisarioScript.SEV_INFO, "Comunicado")
	assert_object(_tarjeta(avisos, 0).find_child("Detalle", true, false)).is_null()


func test_una_severidad_desconocida_cae_en_info_sin_reventar() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	avisos.avisar_evento(&"inventada", "Algo", "pasa")
	var tarjeta: PanelContainer = _tarjeta(avisos, 0)
	assert_str(String(tarjeta.get_meta("severidad"))).is_equal(
		String(AvisosComisarioScript.SEV_INFO)
	)


func test_cada_aviso_anuncia_su_aparicion_para_el_audio() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	var vistos: Array = []
	avisos.aviso_mostrado.connect(func(sev: StringName, titulo: String) -> void:
		vistos.append([String(sev), titulo])
	)
	avisos.avisar_evento(AvisosComisarioScript.SEV_AVISO, "Uno", "")
	assert_array(vistos).is_equal([["aviso", "Uno"]])


# ── La pila ──────────────────────────────────────────────────────────────────────────────────────
func test_el_nuevo_aviso_se_apila_debajo_del_que_ya_estabas_leyendo() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	avisos.avisar_evento(AvisosComisarioScript.SEV_CRITICO, "Primero", "")
	avisos.avisar_evento(AvisosComisarioScript.SEV_INFO, "Segundo", "")
	# Orden de la maqueta: el más viejo ARRIBA — una tarjeta que estás leyendo no cambia de sitio.
	assert_str(_texto(_tarjeta(avisos, 0), "Titulo")).is_equal("Primero")
	assert_str(_texto(_tarjeta(avisos, 1), "Titulo")).is_equal("Segundo")


func test_la_pila_se_compacta_al_cerrar_un_persistente_con_su_aspa() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	avisos.avisar_evento(AvisosComisarioScript.SEV_CRITICO, "Primero", "")
	avisos.avisar_evento(AvisosComisarioScript.SEV_CRITICO, "Segundo", "")
	var cerrar: Button = _tarjeta(avisos, 0).find_child("BotonCerrar", true, false) as Button
	# Un `Button` no se "pulsa" por código: la señal se emite a mano (gotcha del proyecto).
	cerrar.pressed.emit()
	assert_int(avisos.avisos_visibles()).is_equal(1)
	assert_str(_texto(_tarjeta(avisos, 0), "Titulo")).is_equal("Segundo")


func test_al_agotarse_el_tiempo_el_aviso_se_retira_solo() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	avisos.avisar_evento(AvisosComisarioScript.SEV_INFO, "Se va solo", "")
	var reloj: Timer = _tarjeta(avisos, 0).get_node_or_null("Reloj") as Timer
	reloj.timeout.emit()   # el mismo camino que el reloj real, sin dormir 6 segundos
	assert_int(avisos.avisos_visibles()).is_equal(0)


func test_pasado_el_aforo_los_avisos_esperan_turno_sin_perderse() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	for i in AvisosComisarioScript.MAX_VISIBLES + 2:
		avisos.avisar_evento(AvisosComisarioScript.SEV_CRITICO, "Aviso %d" % i, "")
	assert_int(avisos.avisos_visibles()).is_equal(AvisosComisarioScript.MAX_VISIBLES)
	assert_int(avisos.avisos_en_espera()).is_equal(2)


func test_al_cerrarse_uno_entra_el_que_estaba_esperando() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	for i in AvisosComisarioScript.MAX_VISIBLES + 1:
		avisos.avisar_evento(AvisosComisarioScript.SEV_CRITICO, "Aviso %d" % i, "")
	var cerrar: Button = _tarjeta(avisos, 0).find_child("BotonCerrar", true, false) as Button
	cerrar.pressed.emit()
	assert_int(avisos.avisos_en_espera()).is_equal(0)
	assert_int(avisos.avisos_visibles()).is_equal(AvisosComisarioScript.MAX_VISIBLES)
	# El que esperaba entra POR ABAJO (el orden de llegada se respeta).
	var ultimo: int = AvisosComisarioScript.MAX_VISIBLES - 1
	assert_str(_texto(_tarjeta(avisos, ultimo), "Titulo")).is_equal(
		"Aviso %d" % AvisosComisarioScript.MAX_VISIBLES
	)


func test_la_cola_de_espera_tiene_tope_y_descarta_lo_mas_viejo() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	var total: int = AvisosComisarioScript.MAX_VISIBLES + AvisosComisarioScript.MAX_ESPERA + 3
	for i in total:
		avisos.avisar_evento(AvisosComisarioScript.SEV_CRITICO, "Aviso %d" % i, "")
	assert_int(avisos.avisos_en_espera()).is_equal(AvisosComisarioScript.MAX_ESPERA)
	# Lo que sobrevive es lo RECIENTE: el último emitido sigue en la cola.
	assert_str(String(avisos._espera.back()["titulo"])).is_equal("Aviso %d" % (total - 1))


func test_limpiar_deja_la_pila_y_la_cola_a_cero() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	for i in AvisosComisarioScript.MAX_VISIBLES + 1:
		avisos.avisar_evento(AvisosComisarioScript.SEV_CRITICO, "Aviso %d" % i, "")
	avisos.limpiar()
	assert_int(avisos.avisos_visibles()).is_equal(0)
	assert_int(avisos.avisos_en_espera()).is_equal(0)


# ── Colocación y convivencia con la ficha de ventanilla ──────────────────────────────────────────
func test_la_pila_se_ancla_bajo_el_hud_pegada_al_borde_derecho() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	var vista: Vector2 = avisos._pila.get_viewport_rect().size
	assert_float(avisos._pila.position.y).is_equal(AvisosComisarioScript.Y0_PILA)
	assert_float(avisos._pila.position.x).is_equal(
		vista.x - AvisosComisarioScript.MARGEN - AvisosComisarioScript.ANCHO_PILA
	)
	assert_float(avisos._pila.size.x).is_equal(AvisosComisarioScript.ANCHO_PILA)


func test_con_la_ficha_abierta_la_pila_se_aparta_a_su_izquierda() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	var ficha: CanvasLayer = auto_free(FichaFalsa.new())
	add_child(ficha)
	ficha.visible = false
	avisos.usar_ficha(ficha)
	ficha.visible = true
	await get_tree().process_frame   # la recolocación va diferida (la ficha aún no se ha recolocado)
	assert_float(avisos._pila.position.x).is_equal(
		ficha.borde - AvisosComisarioScript.MARGEN - AvisosComisarioScript.ANCHO_PILA
	)
	# Nunca invade la columna de la ficha.
	assert_float(avisos._pila.position.x + AvisosComisarioScript.ANCHO_PILA).is_less(ficha.borde)


func test_al_cerrar_la_ficha_la_pila_vuelve_al_borde_de_la_ventana() -> void:
	var avisos: CanvasLayer = _crear_avisos()
	var ficha: CanvasLayer = auto_free(FichaFalsa.new())
	add_child(ficha)
	avisos.usar_ficha(ficha)   # nace visible
	await get_tree().process_frame
	ficha.visible = false
	await get_tree().process_frame
	var vista: Vector2 = avisos._pila.get_viewport_rect().size
	assert_float(avisos._pila.position.x).is_equal(
		vista.x - AvisosComisarioScript.MARGEN - AvisosComisarioScript.ANCHO_PILA
	)


func test_el_ancla_vertical_deja_libre_la_barra_del_hud() -> void:
	# La regla que costó una iteración de maqueta: la pila EMPIEZA por debajo del HUD, nunca encima.
	assert_float(AvisosComisarioScript.Y0_PILA).is_greater(
		AvisosComisarioScript.BORDE_INFERIOR_HUD
	)
