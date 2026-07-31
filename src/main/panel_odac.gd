class_name PanelODAC extends CanvasLayer
## PanelODAC — la pantalla de la oficina de denuncias (tecla **O**).
##
## Es la palanca de gestión de ODAC #9 (OD4/OD5): decidir **a qué se dedica cada ventanilla** de
## denuncias. Reglas del proyecto (control-manifest, Presentation): la UI **lee** el estado y
## **ordena** por la API pública de ODAC — nunca muta el modelo ni toca Flujo directamente.
##
## ── LO QUE ESTA PANTALLA TIENE QUE CONSEGUIR ──────────────────────────────────────────────────
## Que el jugador entienda, sin leer un manual, la disyuntiva de ODAC:
##
##   Las urgentes SIEMPRE pasan delante. Si todas tus ventanillas atienden de todo y llega una
##   racha de urgencias, las administrativas se quedan esperando para siempre. Dedicar una
##   ventanilla a "solo normales" es lo que hace que avancen.
##
## Por eso cada modo lleva su frase de consecuencia (no solo su nombre) y por eso hay un **aviso en
## rojo** cuando alguna denuncia se ha quedado sin ninguna ventanilla que la atienda. Sin ese aviso,
## el jugador puede estrangular su propia oficina y no enterarse hasta que la satisfacción se hunda.
##
## Andamio provisional, como el resto de paneles: la UI definitiva es UI/HUD #11.

const COLOR_TENUE := Color(1, 1, 1, 0.65)
const COLOR_ALERTA := Color(0.95, 0.45, 0.45)
const COLOR_URGENTE := Color(1.0, 0.72, 0.35)
const COLOR_OK := Color(0.55, 0.9, 0.55)

var _odac: Node = null
var _flujo: Node = null
var _personal: Node = null

var _panel: PanelContainer
var _lista: VBoxContainer
var _aviso: Label


## Inyección de dependencias (la llama Main antes de add_child).
func configurar(odac: Node, flujo: Node, personal: Node) -> void:
	_odac = odac
	_flujo = flujo
	_personal = personal


func _ready() -> void:
	_crear_ui()
	visible = false
	if _odac != null:
		# Al cambiar un modo se repinta sola: sin esto, cambiar una ventanilla no actualizaría el
		# aviso de denuncias sin cubrir hasta cerrar y abrir el panel.
		_odac.modo_cambiado.connect(func(_p: StringName, _m: int) -> void: _reconstruir())


## Tecla O alterna la visibilidad. Al ABRIR reconstruye (foto fresca del estado).
func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey and evento.pressed and not (evento as InputEventKey).echo):
		return
	if (evento as InputEventKey).keycode == KEY_O:
		visible = not visible
		if visible:
			_reconstruir()
		get_viewport().set_input_as_handled()


func _crear_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(760, 560)
	# Anclado al centro, el preset deja el tamaño en 0×0 y crece por el minimum → recentrar el pivote.
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	_panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = "ODAC · Oficina de Denuncias"
	titulo.add_theme_font_size_override("font_size", 20)
	caja.add_child(titulo)

	var explicacion := Label.new()
	explicacion.text = (
		"Las denuncias urgentes pasan siempre delante de las administrativas.\n"
		+ "Dedica una ventanilla a las normales si ves que no avanzan."
	)
	explicacion.add_theme_font_size_override("font_size", 12)
	explicacion.modulate = COLOR_TENUE
	caja.add_child(explicacion)

	_aviso = Label.new()
	_aviso.add_theme_font_size_override("font_size", 13)
	_aviso.modulate = COLOR_ALERTA
	_aviso.visible = false
	caja.add_child(_aviso)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 10)
	scroll.add_child(_lista)

	var cerrar := Button.new()
	cerrar.text = "Cerrar (O)"
	cerrar.focus_mode = Control.FOCUS_NONE   # gotcha: si coge foco, el Espacio deja de pausar
	cerrar.pressed.connect(func() -> void: visible = false)
	caja.add_child(cerrar)


## Repinta la lista entera desde el estado. Solo se llama al abrir o al cambiar un modo — nunca por
## frame (regla del proyecto: cero redibujado continuo).
func _reconstruir() -> void:
	for hijo: Node in _lista.get_children():
		hijo.queue_free()
	if _odac == null:
		return
	var sin_cubrir: Array[StringName] = _odac.denuncias_sin_cubrir()
	if sin_cubrir.is_empty():
		_aviso.visible = false
	else:
		_aviso.visible = true
		_aviso.text = "⚠ %d tipo(s) de denuncia sin ninguna ventanilla que los atienda: %s" % [
			sin_cubrir.size(), ", ".join(_nombres(sin_cubrir))
		]
	var puestos: Array[StringName] = _odac.puestos()
	if puestos.is_empty():
		var vacio := Label.new()
		vacio.text = "No hay ventanillas de ODAC construidas todavía."
		vacio.modulate = COLOR_TENUE
		_lista.add_child(vacio)
		return
	for puesto_id: StringName in puestos:
		_lista.add_child(_ficha_de_puesto(puesto_id))


## La ficha de una ventanilla: quién la lleva, en qué modo está y los cuatro botones de modo.
func _ficha_de_puesto(puesto_id: StringName) -> Control:
	var marco := PanelContainer.new()
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	marco.add_child(caja)

	var cabecera := Label.new()
	var quien: String = "sin agente"
	if _personal != null and _personal.puesto_dotado(puesto_id):
		var agente: RefCounted = _personal.agente_de(puesto_id)
		if agente != null:
			quien = agente.nombre
	var estado: String = ""
	if _flujo != null:
		estado = " · " + String(_flujo.estado_de_puesto(puesto_id)).to_upper()
	cabecera.text = "%s — %s%s" % [puesto_id, quien, estado]
	cabecera.add_theme_font_size_override("font_size", 14)
	caja.add_child(cabecera)

	var modo_actual: int = _odac.modo_de(puesto_id)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	caja.add_child(fila)
	# Los tres modos de un clic. El cuarto ("a medida") necesita elegir tipos uno a uno y es la UI
	# fina que llegará con UI/HUD #11 — se indica pero no se ofrece aquí a medias.
	for modo: int in [
		_odac.Modo.POLIVALENTE, _odac.Modo.SOLO_PRIORITARIAS, _odac.Modo.SOLO_NORMALES
	]:
		var boton := Button.new()
		boton.text = _odac.NOMBRES_MODO[modo]
		boton.focus_mode = Control.FOCUS_NONE
		boton.disabled = modo == modo_actual
		if modo == modo_actual:
			boton.modulate = COLOR_OK
		var id: StringName = puesto_id
		var m: int = modo
		boton.pressed.connect(func() -> void: _odac.fijar_modo(id, m))
		fila.add_child(boton)

	var ayuda := Label.new()
	ayuda.text = _odac.AYUDA_MODO.get(modo_actual, "")
	ayuda.add_theme_font_size_override("font_size", 11)
	ayuda.modulate = COLOR_URGENTE if modo_actual == _odac.Modo.SOLO_PRIORITARIAS else COLOR_TENUE
	caja.add_child(ayuda)
	return marco


## Nombres legibles de unas denuncias (el id si el catálogo no da nombre).
func _nombres(ids: Array[StringName]) -> Array[String]:
	var salida: Array[String] = []
	for id: StringName in ids:
		var d: Resource = Datos.obtener_silencioso(&"DenunciaODAC", id)
		salida.append(d.nombre if d != null and d.nombre != "" else String(id))
	return salida
