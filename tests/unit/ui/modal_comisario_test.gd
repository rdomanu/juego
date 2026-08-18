# ModalComisario — la pantalla que aparece al tocar el suelo de deuda (Economía PAUSA y espera una
# decisión) y en el fin de partida. Este test cubre el CONTRATO que main.gd y Economía dan por hecho
# tras el reskin F4 (2026-08-18): el modal nace oculto y en la capa 13, se muestra con los datos del
# momento, sus dos botones ORDENAN por la API pública de Economía (ADR-0001: la UI lee y ordena,
# jamás muta) y el aspecto nuevo no rompe ninguna de esas costuras.
#
# Tipo: Logic/UI. DETERMINISTA — Economía y el bus se sustituyen por dobles mínimos (`EconomiaFalsa`,
# `BusFalso`): arrastrar la Economía real metería reloj, catálogo y nómina en un test de UI (regla de
# aislamiento del proyecto). Sin azar, sin reloj, sin arte.
extends GdUnitTestSuite

const ModalComisarioScript := preload("res://src/main/modal_comisario.gd")
const KitUIComisarioScript := preload("res://src/ui/kit_ui_comisario.gd")

## Saldo y préstamo del escenario retratado: caja en -2.500 € y un rescate de 1.500 € (el importe por
## defecto del catálogo de Economía).
const SALDO_ROJO := -2500.0
const IMPORTE_RESCATE := 1500.0


## Doble mínimo de Economía: el dato que el modal LEE y las dos órdenes que puede darle.
class EconomiaFalsa extends Node:
	var importe_prestamo_eur: float = 1500.0
	var ordenes: Array[String] = []

	func aceptar_rescate() -> bool:
		ordenes.append("aceptar")
		return true

	func rechazar_rescate() -> bool:
		ordenes.append("rechazar")
		return true


## Doble del bus con las TRES señales que el modal escucha (mismas firmas que `EventBus`).
class BusFalso extends Node:
	signal insolvencia(saldo: float, prestamos_restantes: int)
	signal gracia_iniciada(minutos: float)
	signal game_over(motivo: StringName)


# ── Fixture ──────────────────────────────────────────────────────────────────────────────────────
## Modal ya configurado y dentro del árbol (necesita viewport: se engancha a `size_changed`).
func _modal(economia: Node, bus: Node) -> CanvasLayer:
	var modal: CanvasLayer = auto_free(ModalComisarioScript.new())
	add_child(modal)
	modal.configurar(economia, bus)
	return modal


## Todos los `Label` del modal, en orden de árbol — para comprobar textos sin acoplarse a la
## jerarquía exacta de contenedores (que es aspecto, y el aspecto puede volver a cambiar).
func _labels(nodo: Node, acumulado: Array[Label] = []) -> Array[Label]:
	for hijo: Node in nodo.get_children():
		if hijo is Label:
			acumulado.append(hijo as Label)
		_labels(hijo, acumulado)
	return acumulado


func _todos_los_textos(modal: CanvasLayer) -> String:
	var junto: String = ""
	for etiqueta: Label in _labels(modal):
		junto += etiqueta.text + "\n"
	return junto


# ── Estado inicial ───────────────────────────────────────────────────────────────────────────────

## Nace OCULTO (nadie lo ve hasta que hay una crisis) y en la capa 13: por encima de los modales de
## gestión (12) y de la brújula (10) — es la pantalla que para el juego, nada puede taparla.
func test_configurar_deja_el_modal_oculto_en_la_capa_13() -> void:
	# Act
	var modal: CanvasLayer = _modal(auto_free(EconomiaFalsa.new()), auto_free(BusFalso.new()))

	# Assert
	assert_bool(modal.visible).is_false()
	assert_int(modal.layer).is_equal(13)


## El velo bloquea el ratón del juego de debajo (si no, se podía seguir construyendo con el modal
## abierto) y la tarjeta es un hermano POSTERIOR, que es quien recibe el clic antes.
func test_el_velo_bloquea_el_raton_y_la_tarjeta_va_encima() -> void:
	# Arrange
	var modal: CanvasLayer = _modal(auto_free(EconomiaFalsa.new()), auto_free(BusFalso.new()))

	# Act
	var velo: ColorRect = modal.get_node("Velo") as ColorRect
	var tarjeta: PanelContainer = modal.get_node("TarjetaModal") as PanelContainer

	# Assert
	assert_object(velo).is_not_null()
	assert_int(velo.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_int(tarjeta.get_index()).is_greater(velo.get_index())


# ── Insolvencia: la decisión ─────────────────────────────────────────────────────────────────────

## La señal del bus abre el modal con los DOS botones: aceptar el rescate o apañárselas solo.
func test_insolvencia_abre_el_modal_con_las_dos_decisiones() -> void:
	# Arrange
	var bus: Node = auto_free(BusFalso.new())
	var modal: CanvasLayer = _modal(auto_free(EconomiaFalsa.new()), bus)

	# Act
	bus.insolvencia.emit(SALDO_ROJO, 2)

	# Assert
	assert_bool(modal.visible).is_true()
	assert_bool(modal.get_node("TarjetaModal/%s" % _ruta_boton("BotonAceptar")).visible).is_true()
	assert_bool(modal.get_node("TarjetaModal/%s" % _ruta_boton("BotonRechazar")).visible).is_true()


## Ruta del botón dentro de la tarjeta (VBox > fila de botones). Vive en una función para que el día
## que cambie la jerarquía se toque UN sitio.
func _ruta_boton(nombre: String) -> String:
	return "Caja/Botones/%s" % nombre


## El dinero se pinta con el formato de TODA la UI (miles con punto, sin decimales): "-2.500 €" y
## "1.500 €", nunca "-2500" a pelo como hacía el modal viejo.
func test_insolvencia_pinta_el_dinero_con_separador_de_miles() -> void:
	# Arrange
	var economia: Node = auto_free(EconomiaFalsa.new())
	economia.importe_prestamo_eur = IMPORTE_RESCATE
	var bus: Node = auto_free(BusFalso.new())
	var modal: CanvasLayer = _modal(economia, bus)

	# Act
	bus.insolvencia.emit(SALDO_ROJO, 2)
	var textos: String = _todos_los_textos(modal)

	# Assert
	assert_str(textos).contains(KitUIComisarioScript.formato_euros(SALDO_ROJO))
	assert_str(textos).contains(KitUIComisarioScript.formato_euros(IMPORTE_RESCATE))


## Los avisos restantes se dicen con NÚMERO y en la concordancia correcta (uno / varios): el jugador
## tiene que saber cuántas balas le quedan antes de decidir.
func test_insolvencia_dice_cuantos_avisos_quedan() -> void:
	# Arrange
	var bus: Node = auto_free(BusFalso.new())
	var modal: CanvasLayer = _modal(auto_free(EconomiaFalsa.new()), bus)

	# Act
	bus.insolvencia.emit(SALDO_ROJO, 1)
	var textos: String = _todos_los_textos(modal)

	# Assert
	assert_str(textos).contains("1 aviso más")


## Regresión de un gotcha del proyecto: un `Label` con autowrap y SIN ancho pedido mide a una sola
## línea y el texto se sale de la tarjeta. El cuerpo debe pedir el ancho con EXPAND_FILL.
func test_el_cuerpo_hace_autowrap_con_expand_fill() -> void:
	# Arrange
	var modal: CanvasLayer = _modal(auto_free(EconomiaFalsa.new()), auto_free(BusFalso.new()))

	# Act
	var cuerpo: Label = modal.get_node("TarjetaModal/Caja/Cuerpo") as Label

	# Assert
	assert_int(cuerpo.autowrap_mode).is_equal(TextServer.AUTOWRAP_WORD)
	assert_bool(cuerpo.size_flags_horizontal & Control.SIZE_EXPAND != 0).is_true()


## Cero emojis en pantalla (norma del proyecto: arrastran la fuente COLOR del sistema e ignoran el
## color del tema). El aviso lo da el glifo DIBUJADO de la cabecera, no un 📞 ni un 🚫.
func test_los_textos_del_modal_no_traen_emojis() -> void:
	# Arrange
	var bus: Node = auto_free(BusFalso.new())
	var modal: CanvasLayer = _modal(auto_free(EconomiaFalsa.new()), bus)

	# Act
	bus.insolvencia.emit(SALDO_ROJO, 2)
	var textos: String = _todos_los_textos(modal)

	# Assert
	assert_bool(textos.contains("📞")).is_false()
	assert_bool(textos.contains("🚫")).is_false()


## La cabecera lleva el glifo de alerta del kit (dibujado con `_draw`, no un PNG ni un carácter).
func test_la_cabecera_lleva_el_glifo_de_alerta_del_kit() -> void:
	# Arrange
	var modal: CanvasLayer = _modal(auto_free(EconomiaFalsa.new()), auto_free(BusFalso.new()))

	# Act
	var glifo: Node = modal.get_node("TarjetaModal/Caja/Cabecera/GlifoAlerta")

	# Assert
	assert_object(glifo).is_not_null()
	assert_int(glifo.tipo).is_equal(KitUIComisarioScript.GlifoModerno.Tipo.TRIANGULO_ALERTA)


# ── Las dos órdenes (lo que NO puede cambiar nunca) ──────────────────────────────────────────────

## Aceptar ORDENA el rescate a Economía y cierra el modal. Reanudar el juego es cosa de Economía.
func test_aceptar_ordena_el_rescate_y_cierra_el_modal() -> void:
	# Arrange
	var economia: Node = auto_free(EconomiaFalsa.new())
	var bus: Node = auto_free(BusFalso.new())
	var modal: CanvasLayer = _modal(economia, bus)
	bus.insolvencia.emit(SALDO_ROJO, 2)

	# Act
	(modal.get_node("TarjetaModal/%s" % _ruta_boton("BotonAceptar")) as Button).pressed.emit()

	# Assert
	assert_array(economia.ordenes).is_equal(["aceptar"])
	assert_bool(modal.visible).is_false()


## Rechazar ORDENA el rechazo (Economía abre la ventana de gracia) y cierra el modal.
func test_rechazar_ordena_el_rechazo_y_cierra_el_modal() -> void:
	# Arrange
	var economia: Node = auto_free(EconomiaFalsa.new())
	var bus: Node = auto_free(BusFalso.new())
	var modal: CanvasLayer = _modal(economia, bus)
	bus.insolvencia.emit(SALDO_ROJO, 2)

	# Act
	(modal.get_node("TarjetaModal/%s" % _ruta_boton("BotonRechazar")) as Button).pressed.emit()

	# Assert
	assert_array(economia.ordenes).is_equal(["rechazar"])
	assert_bool(modal.visible).is_false()


## La ventana de gracia cierra el modal: el contrarreloj corre con el juego a la vista.
func test_la_gracia_cierra_el_modal() -> void:
	# Arrange
	var bus: Node = auto_free(BusFalso.new())
	var modal: CanvasLayer = _modal(auto_free(EconomiaFalsa.new()), bus)
	bus.insolvencia.emit(SALDO_ROJO, 2)

	# Act
	bus.gracia_iniciada.emit(720.0)

	# Assert
	assert_bool(modal.visible).is_false()


# ── Fin de partida ───────────────────────────────────────────────────────────────────────────────

## Ya no hay nada que decidir: desaparece el botón de aceptar y queda uno solo, de cierre.
func test_game_over_deja_un_unico_boton_de_cierre() -> void:
	# Arrange
	var bus: Node = auto_free(BusFalso.new())
	var modal: CanvasLayer = _modal(auto_free(EconomiaFalsa.new()), bus)

	# Act
	bus.game_over.emit(&"insolvencia_sin_prestamos")

	# Assert
	assert_bool(modal.visible).is_true()
	assert_bool(modal.get_node("TarjetaModal/%s" % _ruta_boton("BotonAceptar")).visible).is_false()
	var cierre: Button = modal.get_node("TarjetaModal/%s" % _ruta_boton("BotonRechazar")) as Button
	assert_bool(cierre.visible).is_true()
	assert_str(cierre.text).is_equal("Entendido")


## El motivo se cuenta en CASTELLANO, nunca con el id técnico del bus (norma del proyecto: en
## pantalla no se enseña un id).
func test_game_over_traduce_el_motivo_tecnico() -> void:
	# Arrange
	var bus: Node = auto_free(BusFalso.new())
	var modal: CanvasLayer = _modal(auto_free(EconomiaFalsa.new()), bus)

	# Act
	bus.game_over.emit(&"insolvencia_sin_prestamos")
	var textos: String = _todos_los_textos(modal)

	# Assert
	assert_str(textos).contains("sin caja y sin más rescates del Comisario")
	assert_bool(textos.contains("insolvencia_sin_prestamos")).is_false()


## Un motivo que la tabla no conoce NO revienta: se enseña tal cual (honesto y feo, delata la tabla
## incompleta) — mismo criterio que el nombre visible de un puesto sin prefijo.
func test_game_over_con_motivo_desconocido_no_revienta() -> void:
	# Arrange
	var bus: Node = auto_free(BusFalso.new())
	var modal: CanvasLayer = _modal(auto_free(EconomiaFalsa.new()), bus)

	# Act
	bus.game_over.emit(&"motivo_que_no_existe")

	# Assert
	assert_bool(modal.visible).is_true()
	assert_str(_todos_los_textos(modal)).contains("motivo_que_no_existe")


## El botón de cierre del fin de partida sigue llamando a `rechazar_rescate` (Economía se lo come sin
## decisión pendiente): el contrato con Economía no cambió con el reskin.
func test_el_boton_de_cierre_del_game_over_sigue_llamando_a_economia() -> void:
	# Arrange
	var economia: Node = auto_free(EconomiaFalsa.new())
	var bus: Node = auto_free(BusFalso.new())
	var modal: CanvasLayer = _modal(economia, bus)
	bus.game_over.emit(&"insolvencia_sin_prestamos")

	# Act
	(modal.get_node("TarjetaModal/%s" % _ruta_boton("BotonRechazar")) as Button).pressed.emit()

	# Assert
	assert_array(economia.ordenes).is_equal(["rechazar"])
	assert_bool(modal.visible).is_false()
