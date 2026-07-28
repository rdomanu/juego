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

const COLOR_TITULO := Color(1.0, 0.85, 0.35)
const COLOR_AVISO := Color(0.95, 0.4, 0.4)
const COLOR_TENUE := Color(1, 1, 1, 0.75)

var _economia: Node = null
var _panel: PanelContainer
var _lbl_titulo: Label
var _lbl_cuerpo: Label
var _btn_aceptar: Button
var _btn_rechazar: Button


## Inyecta Economía y se engancha a los tres momentos que tiene que contar: la insolvencia (decisión),
## la ventana de gracia (aviso) y el fin de partida.
func configurar(economia: Node, bus: Node) -> void:
	_economia = economia
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
	_lbl_titulo.text = "📞 El Comisario al teléfono"
	_lbl_titulo.modulate = COLOR_TITULO
	_lbl_cuerpo.text = (
		"La comisaría está en números rojos: %s €.\n\n"
		+ "«Te saco del apuro con %s €, pero esto no sale gratis: te queda%s %d aviso%s más.»\n\n"
		+ "Si rechazas, tienes un margen para arreglarlo tú — y si no lo arreglas, te sacan igual."
	) % [
		_num(saldo), _num(_economia.importe_prestamo_eur if _economia != null else 0.0),
		"n" if prestamos_restantes != 1 else "", prestamos_restantes,
		"s" if prestamos_restantes != 1 else "",
	]
	_btn_aceptar.text = "Aceptar el rescate (%s €)" % _num(
		_economia.importe_prestamo_eur if _economia != null else 0.0
	)
	_btn_aceptar.visible = true
	_btn_rechazar.text = "Rechazar — lo arreglo yo"
	_btn_rechazar.visible = true
	visible = true


## El jugador rechazó: se cierra el modal y corre el contrarreloj (Economía ya reanudó el juego).
func _al_empezar_la_gracia(minutos: float) -> void:
	visible = false
	_ultimo_aviso_gracia = minutos


## Fin de la partida: no hay decisión que tomar, solo enterarse. El botón cierra el modal para poder
## seguir mirando la comisaría (el juego ya no avanza; el reinicio será cosa del menú principal).
func _al_perder_la_partida(motivo: StringName) -> void:
	_lbl_titulo.text = "🚫 Te han relevado del puesto"
	_lbl_titulo.modulate = COLOR_AVISO
	_lbl_cuerpo.text = (
		"La comisaría no puede seguir así (%s).\n\n"
		+ "Se acabaron los avisos del Comisario: otro ocupará tu despacho."
	) % String(motivo)
	_btn_aceptar.visible = false
	_btn_rechazar.text = "Entendido"
	_btn_rechazar.visible = true
	visible = true


## Minutos de gracia del último aviso (informativo, para el HUD si algún día lo pinta).
var _ultimo_aviso_gracia: float = 0.0


# ── UI (por código, patrón del resto de paneles) ─────────────────────────────────────────────
func _crear_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(560, 240)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	_panel.add_child(caja)

	_lbl_titulo = Label.new()
	_lbl_titulo.add_theme_font_size_override("font_size", 16)
	_lbl_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_lbl_titulo)

	_lbl_cuerpo = Label.new()
	_lbl_cuerpo.add_theme_font_size_override("font_size", 13)
	_lbl_cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD
	_lbl_cuerpo.custom_minimum_size = Vector2(520, 0)
	_lbl_cuerpo.modulate = COLOR_TENUE
	_lbl_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_lbl_cuerpo)

	var botones := HFlowContainer.new()
	botones.add_theme_constant_override("h_separation", 8)
	caja.add_child(botones)
	_btn_aceptar = _boton("Aceptar", _al_aceptar)
	botones.add_child(_btn_aceptar)
	_btn_rechazar = _boton("Rechazar", _al_rechazar)
	botones.add_child(_btn_rechazar)


func _boton(texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.focus_mode = Control.FOCUS_NONE   # si no, Espacio lo repulsa en vez de pausar
	boton.pressed.connect(accion)
	return boton


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


## Euros en formato corto (GDScript no admite "%.*f").
func _num(valor: float) -> String:
	return "%d" % roundi(valor)
