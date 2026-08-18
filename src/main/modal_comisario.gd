class_name ModalComisario extends CanvasLayer
## ModalComisario — la pantalla que aparece cuando **te quedas sin dinero**: el Comisario te ofrece un
## rescate y tú decides. También anuncia el fin de la partida.
##
## 🐛 **POR QUÉ EXISTE (bug de bloqueo, 2026-07-28):** Economía ya hacía todo lo suyo — al tocar el
## suelo de deuda PAUSA el reloj, marca que espera una decisión y emite `insolvencia` por el bus— pero
## **nadie escuchaba esa señal**. El resultado era que la partida se quedaba pausada para siempre sin
## explicar nada: el jugador veía el reloj congelado y no tenía forma de continuar. Síntoma reportado:
## *"no avanza, se bloquea"*, y aparecía *"cuando pasa un tiempo"* porque los gastos (nómina,
## mantenimiento de las comodidades, peonada) tardan unos días en vaciar la caja.
##
## Reglas (control-manifest, Presentation): la UI LEE y ORDENA por la API pública de Economía
## (`aceptar_rescate` / `rechazar_rescate`); no toca el saldo ni el reloj — de reanudar el juego se
## encarga Economía, que es quien lo pausó (ADR-0001).
##
## **RESKIN F4 (2026-08-18)** — cambia SOLO el aspecto: velo oscuro + tarjeta de diálogo del kit
## moderno (`KitUIComisario`, mismo lenguaje que el HUD, el panel de construcción y Personal), glifo
## de alerta dibujado, cifras por `formato_euros` y botones-píldora. La lógica, los nombres de método
## y el contrato con Economía/EventBus están INTACTOS. Es la pantalla que PARA el juego, así que vive
## en `layer = 13`, por encima de los modales normales (Personal/Horario van en 12).
## Story: F4 reskin de oficio · nota `design/ux/reskin-modal-menus-nota.md`

## `class_name` no resuelve en headless frío (gotcha del proyecto) → SIEMPRE preload.
const KitUIComisarioScript := preload("res://src/ui/kit_ui_comisario.gd")

## Velo sobre el juego: el MISMO tono que `PanelPersonal.COLOR_VELO` pero más opaco — aquí el juego
## está PARADO esperando una decisión, no consultándose una pantalla de gestión.
const COLOR_VELO := Color(0.039, 0.055, 0.094, 0.88)
## Ancho fijo de la tarjeta: es un DIÁLOGO (una decisión, dos botones), no un tablón — bastante más
## estrecha que el modal de Personal, que ocupa casi toda la ventana.
const ANCHO_MODAL := 520.0
## Aire interior de la tarjeta y separación entre bloques.
const PADDING_MODAL := 28.0
const SEPARACION_BLOQUES := 16.0
## Lado del glifo de alerta de la cabecera (grande: es el golpe visual del momento).
const LADO_GLIFO := 44.0
## Alto de las píldoras de decisión (algo más altas que las de una ficha: son EL gesto de la
## pantalla).
const ALTO_BOTON := 40.0

## Motivo de derrota LEGIBLE. El bus emite un id técnico (`insolvencia_sin_prestamos`); en pantalla
## nunca se enseña un id (norma del proyecto). Un motivo que no esté aquí cae al id tal cual: feo y
## honesto, delata la tabla incompleta en la primera captura en vez de mentir.
const MOTIVO_LEGIBLE: Dictionary[StringName, String] = {
	&"insolvencia_sin_prestamos": "sin caja y sin más rescates del Comisario",
}

var _economia: Node = null
var _velo: ColorRect
var _panel: PanelContainer
var _glifo: KitUIComisarioScript.GlifoModerno = null
var _lbl_titulo: Label
var _lbl_antetitulo: Label
var _lbl_cuerpo: Label
var _fila_datos: HBoxContainer
var _btn_aceptar: Button
var _btn_rechazar: Button


## Inyecta Economía y se engancha a los tres momentos que tiene que contar: la insolvencia (decisión),
## la ventana de gracia (aviso) y el fin de partida.
func configurar(economia: Node, bus: Node) -> void:
	_economia = economia
	# Por ENCIMA de todo lo demás: los modales de gestión van en 12 (`PanelPersonal`), la brújula de
	# depuración en 10. Este modal PARA el juego — nada puede taparlo.
	layer = 13
	_crear_ui()
	if bus != null:
		bus.insolvencia.connect(_al_caer_en_insolvencia)
		bus.gracia_iniciada.connect(_al_empezar_la_gracia)
		bus.game_over.connect(_al_perder_la_partida)
	visible = false


# ── Los tres momentos ────────────────────────────────────────────────────────────────────────

## Sin caja y con salvavidas: el juego YA está pausado (lo hizo Economía) y aquí se explica y se
## ofrece la salida. Sin este modal, esa pausa era un bloqueo sin más.
func _al_caer_en_insolvencia(saldo: float, prestamos_restantes: int) -> void:
	var importe: float = _economia.importe_prestamo_eur if _economia != null else 0.0
	_glifo.color = KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO
	_glifo.queue_redraw()
	_lbl_antetitulo.text = "LA PARTIDA ESTÁ EN PAUSA — HAY QUE DECIDIR"
	_lbl_antetitulo.add_theme_color_override(
		"font_color", KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO
	)
	_lbl_titulo.text = "El Comisario al teléfono"
	_lbl_titulo.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_TINTA)
	_lbl_cuerpo.text = (
		"«Te saco del apuro, pero esto no sale gratis: te queda%s %d aviso%s más.»\n\n"
		+ "Si rechazas, tienes un margen para arreglarlo tú — y si no lo arreglas, te sacan igual."
	) % [
		"n" if prestamos_restantes != 1 else "", prestamos_restantes,
		"s" if prestamos_restantes != 1 else "",
	]
	_pintar_datos([
		{
			"rotulo": "CAJA AHORA",
			"valor": KitUIComisarioScript.formato_euros(saldo),
			"fondo": KitUIComisarioScript.MOD_COLOR_ROJO_SUAVE,
			"color": KitUIComisarioScript.MOD_COLOR_ROJO,
		},
		{
			"rotulo": "TE INYECTA",
			"valor": KitUIComisarioScript.formato_euros(importe),
			"fondo": KitUIComisarioScript.MOD_COLOR_ACENTO_SUAVE,
			"color": KitUIComisarioScript.MOD_COLOR_ACENTO,
		},
		{
			"rotulo": "AVISOS QUE TE QUEDAN",
			"valor": str(prestamos_restantes),
			"fondo": KitUIComisarioScript.MOD_COLOR_AMBAR_SUAVE,
			"color": KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO,
		},
	])
	_btn_aceptar.text = "Aceptar el rescate (%s)" % KitUIComisarioScript.formato_euros(importe)
	KitUIComisarioScript.moderno_vestir_boton_pastilla(
		_btn_aceptar, KitUIComisarioScript.MOD_BOTON_PRIMARIO, ALTO_BOTON, false, 14
	)
	_btn_aceptar.visible = true
	_btn_rechazar.text = "Rechazar — lo arreglo yo"
	KitUIComisarioScript.moderno_vestir_boton_pastilla(
		_btn_rechazar, KitUIComisarioScript.MOD_BOTON_SECUNDARIO, ALTO_BOTON, false, 14
	)
	_btn_rechazar.visible = true
	visible = true
	_recolocar_panel()
	_recolocar_panel.call_deferred()


## El jugador rechazó: se cierra el modal y corre el contrarreloj (Economía ya reanudó el juego).
func _al_empezar_la_gracia(minutos: float) -> void:
	visible = false
	_ultimo_aviso_gracia = minutos


## Fin de la partida: no hay decisión que tomar, solo enterarse. El botón cierra el modal para poder
## seguir mirando la comisaría (el juego ya no avanza; el reinicio será cosa del menú principal).
func _al_perder_la_partida(motivo: StringName) -> void:
	_glifo.color = KitUIComisarioScript.MOD_COLOR_ROJO
	_glifo.queue_redraw()
	_lbl_antetitulo.text = "FIN DE LA PARTIDA"
	_lbl_antetitulo.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_ROJO)
	_lbl_titulo.text = "Te han relevado del puesto"
	_lbl_titulo.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_ROJO)
	_lbl_cuerpo.text = (
		"La comisaría no puede seguir así: %s.\n\n"
		+ "Se acabaron los avisos del Comisario: otro ocupará tu despacho."
	) % MOTIVO_LEGIBLE.get(motivo, String(motivo))
	_pintar_datos([
		{
			"rotulo": "MOTIVO",
			"valor": MOTIVO_LEGIBLE.get(motivo, String(motivo)),
			"fondo": KitUIComisarioScript.MOD_COLOR_ROJO_SUAVE,
			"color": KitUIComisarioScript.MOD_COLOR_ROJO,
			"tam_valor": 15,
		},
	])
	_btn_aceptar.visible = false
	_btn_rechazar.text = "Entendido"
	KitUIComisarioScript.moderno_vestir_boton_pastilla(
		_btn_rechazar, KitUIComisarioScript.MOD_BOTON_PELIGRO, ALTO_BOTON, false, 14
	)
	_btn_rechazar.visible = true
	visible = true
	_recolocar_panel()
	_recolocar_panel.call_deferred()


## Minutos de gracia del último aviso (informativo, para el HUD si algún día lo pinta).
var _ultimo_aviso_gracia: float = 0.0


# ══ UI (por código, kit moderno — el proyecto no usa .tscn salvo Main) ═══════════════════════════
func _crear_ui() -> void:
	# EL VELO: bloquea el juego de debajo (MOUSE_FILTER_STOP). La tarjeta es un hermano POSTERIOR, así
	# que recibe el input antes que el velo (mismo montaje que `PanelPersonal`).
	_velo = ColorRect.new()
	_velo.name = "Velo"
	_velo.color = COLOR_VELO
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_velo)

	_panel = KitUIComisarioScript.moderno_tarjeta(false, 22.0)
	_panel.name = "TarjetaModal"
	# La fuente moderna baja por herencia a TODOS los hijos (mismo gesto que el resto de pantallas
	# modernas): un solo `theme` en la raíz en vez de un override por Label.
	_panel.theme = KitUIComisarioScript.moderno_tema()
	var estilo: StyleBoxFlat = _panel.get_theme_stylebox("panel") as StyleBoxFlat
	if estilo != null:
		# Sombra más marcada que la de una tarjeta normal: la pieza flota sobre un velo casi negro.
		estilo.shadow_size = 18
		estilo.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
		estilo.content_margin_left = PADDING_MODAL
		estilo.content_margin_right = PADDING_MODAL
		estilo.content_margin_top = PADDING_MODAL
		estilo.content_margin_bottom = PADDING_MODAL
	add_child(_panel)
	# Recolocar al redimensionar la ventana (la tarjeta va centrada a mano, no dentro de un
	# contenedor). Mismo patrón que `PanelPersonal._recolocar_panel`.
	get_viewport().size_changed.connect(_recolocar_panel)

	var caja := VBoxContainer.new()
	caja.name = "Caja"
	caja.add_theme_constant_override("separation", int(SEPARACION_BLOQUES))
	_panel.add_child(caja)

	caja.add_child(_crear_cabecera())

	_lbl_cuerpo = Label.new()
	_lbl_cuerpo.name = "Cuerpo"
	_lbl_cuerpo.add_theme_font_size_override("font_size", 14)
	_lbl_cuerpo.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_TINTA)
	_lbl_cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Gotcha del proyecto: autowrap SIN ancho disponible mide a una sola línea. Dentro de un VBox hay
	# que pedir el ancho EXPLÍCITAMENTE con EXPAND_FILL, no fiarse del contenedor.
	_lbl_cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_lbl_cuerpo)

	_fila_datos = HBoxContainer.new()
	_fila_datos.name = "Datos"
	_fila_datos.add_theme_constant_override("separation", 10)
	caja.add_child(_fila_datos)

	var botones := HBoxContainer.new()
	botones.name = "Botones"
	botones.alignment = BoxContainer.ALIGNMENT_END
	botones.add_theme_constant_override("separation", 10)
	caja.add_child(botones)
	# El orden manda: la salida "me lo guiso yo" a la izquierda y la ACEPTACIÓN destacada a la
	# derecha, que es donde el ojo termina de leer.
	_btn_rechazar = KitUIComisarioScript.moderno_boton_pastilla(
		"Rechazar", KitUIComisarioScript.MOD_BOTON_SECUNDARIO, ALTO_BOTON, false, 14
	)
	_btn_rechazar.name = "BotonRechazar"
	_btn_rechazar.pressed.connect(_al_rechazar)
	botones.add_child(_btn_rechazar)
	_btn_aceptar = KitUIComisarioScript.moderno_boton_pastilla(
		"Aceptar", KitUIComisarioScript.MOD_BOTON_PRIMARIO, ALTO_BOTON, false, 14
	)
	_btn_aceptar.name = "BotonAceptar"
	_btn_aceptar.pressed.connect(_al_aceptar)
	botones.add_child(_btn_aceptar)


## Cabecera: el glifo de alerta DIBUJADO (nunca un emoji — arrastra la fuente color del sistema e
## ignora `modulate`, gotcha ya cazado en el HUD) + antetítulo pequeño y titular contundente.
func _crear_cabecera() -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.name = "Cabecera"
	fila.add_theme_constant_override("separation", 14)

	_glifo = KitUIComisarioScript.moderno_glifo(
		KitUIComisarioScript.GlifoModerno.Tipo.TRIANGULO_ALERTA,
		KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO, LADO_GLIFO
	) as KitUIComisarioScript.GlifoModerno
	_glifo.name = "GlifoAlerta"
	_glifo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(_glifo)

	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 2)
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(textos)

	_lbl_antetitulo = Label.new()
	_lbl_antetitulo.name = "Antetitulo"
	_lbl_antetitulo.add_theme_font_override("font", KitUIComisarioScript.moderno_fuente(true))
	_lbl_antetitulo.add_theme_font_size_override("font_size", 11)
	_lbl_antetitulo.add_theme_color_override(
		"font_color", KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO
	)
	_lbl_antetitulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(_lbl_antetitulo)

	_lbl_titulo = Label.new()
	_lbl_titulo.name = "Titulo"
	_lbl_titulo.add_theme_font_override("font", KitUIComisarioScript.moderno_fuente(true))
	_lbl_titulo.add_theme_font_size_override("font_size", 22)
	_lbl_titulo.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_TINTA)
	_lbl_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD
	_lbl_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(_lbl_titulo)
	return fila


## Repuebla la fila de cifras. Cada entrada es
## `{"rotulo": String, "valor": String, "fondo": Color, "color": Color, "tam_valor": int}`
## (`tam_valor` opcional). Se reconstruye entera en cada momento porque son 1-3 tarjetas: mantener
## nodos vivos entre estados costaría más que rehacerlas.
func _pintar_datos(entradas: Array[Dictionary]) -> void:
	for hijo: Node in _fila_datos.get_children():
		_fila_datos.remove_child(hijo)
		hijo.queue_free()
	for entrada: Dictionary in entradas:
		_fila_datos.add_child(_tarjeta_cifra(entrada))


## Una cifra con su rótulo, en una tarjeta de fondo tenue del kit (la misma familia que la tarjeta
## "COSTE TOTAL DE PEONADA HOY" de la pantalla de Horario).
func _tarjeta_cifra(entrada: Dictionary) -> PanelContainer:
	var fondo: Color = entrada.get("fondo", KitUIComisarioScript.MOD_COLOR_PANEL)
	var color: Color = entrada.get("color", KitUIComisarioScript.MOD_COLOR_TINTA)
	var tarjeta: PanelContainer = KitUIComisarioScript.moderno_tarjeta(
		false, KitUIComisarioScript.MOD_RADIO_PEQUENO, fondo
	)
	tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tarjeta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo: StyleBoxFlat = tarjeta.get_theme_stylebox("panel") as StyleBoxFlat
	if estilo != null:
		# Sin sombra: son bloques planos DENTRO de la tarjeta, no piezas flotantes.
		estilo.shadow_size = 0
		estilo.content_margin_left = 14.0
		estilo.content_margin_right = 14.0
		estilo.content_margin_top = 10.0
		estilo.content_margin_bottom = 10.0
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta.add_child(caja)

	var rotulo := Label.new()
	rotulo.text = String(entrada.get("rotulo", ""))
	rotulo.add_theme_font_size_override("font_size", 10)
	rotulo.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_GRIS)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(rotulo)

	var valor := Label.new()
	valor.text = String(entrada.get("valor", ""))
	valor.add_theme_font_override("font", KitUIComisarioScript.moderno_fuente(true))
	valor.add_theme_font_size_override("font_size", int(entrada.get("tam_valor", 18)))
	valor.add_theme_color_override("font_color", color)
	valor.autowrap_mode = TextServer.AUTOWRAP_WORD
	valor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	valor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(valor)
	return tarjeta


## La tarjeta va CENTRADA a mano (no cuelga de un contenedor): ancho fijo y el alto que pida su
## contenido. Se llama al mostrarse y en cada `size_changed` del viewport. EN DOS PASADAS: el
## mínimo de un Label con autowrap depende del ancho YA repartido por el contenedor — medir el
## alto en el mismo frame en que se fija el ancho daba 1135 px (texto a ancho 0) y la tarjeta
## salía como una columna cortada por arriba y por abajo (cazado en captura, 2026-08-18).
func _recolocar_panel() -> void:
	if _panel == null:
		return
	var vista: Vector2 = _panel.get_viewport_rect().size
	_velo.position = Vector2.ZERO
	_velo.size = vista
	# 1ª pasada: fijar el ANCHO (el alto de esta pasada es provisional y acotado a la vista).
	var alto_provisional: float = minf(_panel.get_combined_minimum_size().y, vista.y)
	_panel.size = Vector2(ANCHO_MODAL, alto_provisional)
	_panel.position = ((vista - _panel.size) * 0.5).floor()
	_ajustar_alto_diferido.call_deferred()


## 2ª pasada (un frame después, con el ancho ya aplicado a los hijos): el alto REAL del contenido.
func _ajustar_alto_diferido() -> void:
	if _panel == null or not visible:
		return
	var vista: Vector2 = _panel.get_viewport_rect().size
	var alto: float = minf(_panel.get_combined_minimum_size().y, vista.y - 32.0)
	_panel.size = Vector2(ANCHO_MODAL, alto)
	_panel.position = ((vista - _panel.size) * 0.5).floor()


# ── Órdenes (la decisión la ejecuta Economía; reanudar el juego es cosa suya) ─────────────────
func _al_aceptar() -> void:
	visible = false
	if _economia != null:
		_economia.aceptar_rescate()


func _al_rechazar() -> void:
	visible = false
	if _economia == null:
		return
	# Si no había decisión pendiente (caso del fin de partida), el botón solo cierra el aviso.
	_economia.rechazar_rescate()
