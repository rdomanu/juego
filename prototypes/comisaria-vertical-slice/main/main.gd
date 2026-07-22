# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: ¿es divertido y construible el bucle core de la Oficina de Denuncias?
# Date: 2026-07-22
extends Node2D
## Escena raíz del slice (E0..E3c). HUD compacto pegado ABAJO-IZQUIERDA.
## Modos de edición: Construir puesto · Trazar cola (barandillas) · Borrar (demoler).
## Capas: Fondo (día/noche, detrás) < Mundo < HUD (encima).

const COLOR_DIA: Color = Color(0.82, 0.86, 0.92)
const COLOR_NOCHE: Color = Color(0.10, 0.12, 0.20)
const MundoScript := preload("res://mundo/mundo.gd")

var _mundo
var _fondo: ColorRect
var _panel: PanelContainer
var _lbl_tiempo: Label
var _lbl_recursos: Label
var _lbl_flujo: Label
var _lbl_objetivo: Label
var _lbl_perf: Label
var _overlay: CanvasLayer
var _overlay_panel: PanelContainer
var _overlay_lbl: Label
var _lbl_vel: Label
var _lbl_ayuda: Label
var _boton_puesto: Button
var _boton_barandilla: Button
var _boton_demoler: Button
var _boton_agente: Button
var _boton_estres: Button
var _vel_previa: int = 1

func _ready() -> void:
	_crear_fondo()
	_crear_mundo()
	_crear_hud()
	_crear_overlay()
	EventBus.ascenso.connect(_on_ascenso)

func _crear_fondo() -> void:
	var capa := CanvasLayer.new()
	capa.layer = -1
	add_child(capa)
	_fondo = ColorRect.new()
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo.color = COLOR_DIA
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_fondo)

func _crear_mundo() -> void:
	_mundo = MundoScript.new()
	add_child(_mundo)

func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)

	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 16)   # la Y real se ajusta cada frame en _process (pegado abajo)
	capa.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	_panel.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "COMISARIO — Vertical Slice (E3c)"
	vbox.add_child(titulo)

	_lbl_tiempo = _nueva_label(vbox)
	_lbl_recursos = _nueva_label(vbox)
	_lbl_flujo = _nueva_label(vbox)
	_lbl_objetivo = _nueva_label(vbox)
	_lbl_perf = _nueva_label(vbox)

	var fila_vel := HBoxContainer.new()
	fila_vel.add_theme_constant_override("separation", 8)
	vbox.add_child(fila_vel)
	_nuevo_boton_vel(fila_vel, "Pausa", 0)
	_nuevo_boton_vel(fila_vel, "1x", 1)
	_nuevo_boton_vel(fila_vel, "2x", 2)
	_nuevo_boton_vel(fila_vel, "3x", 3)
	_lbl_vel = _nueva_label(fila_vel)

	var fila_edit := HBoxContainer.new()
	fila_edit.add_theme_constant_override("separation", 8)
	vbox.add_child(fila_edit)
	_boton_puesto = _nuevo_boton(fila_edit, _on_puesto)
	_boton_barandilla = _nuevo_boton(fila_edit, _on_barandilla)
	_boton_demoler = _nuevo_boton(fila_edit, _on_demoler)
	_boton_agente = _nuevo_boton(fila_edit, _on_agente)
	_boton_estres = _nuevo_boton(fila_edit, _on_estres)

	_lbl_ayuda = _nueva_label(vbox)

	var leyenda := Label.new()
	leyenda.text = "Azul = DNI · Naranja = denuncia   |   Espacio = Pausa · 1/2/3 = velocidad"
	vbox.add_child(leyenda)

func _nueva_label(padre: Node) -> Label:
	var l := Label.new()
	padre.add_child(l)
	return l

func _nuevo_boton_vel(padre: Node, texto: String, vel: int) -> void:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_set_vel.bind(vel))
	padre.add_child(b)

func _nuevo_boton(padre: Node, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	padre.add_child(b)
	return b

func _on_puesto() -> void:
	_mundo.activar_modo_puesto()

func _on_barandilla() -> void:
	_mundo.activar_modo_barandilla()

func _on_demoler() -> void:
	_mundo.activar_modo_demoler()

func _on_agente() -> void:
	_mundo.activar_modo_agente()

func _on_estres() -> void:
	_mundo.activar_estres()

func _crear_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	_overlay.visible = false
	add_child(_overlay)
	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0, 0, 0, 0.55)
	_overlay.add_child(fondo)
	_overlay_panel = PanelContainer.new()
	_overlay.add_child(_overlay_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_overlay_panel.add_child(vb)
	var t := Label.new()
	t.text = "¡ASCENSO!"
	vb.add_child(t)
	_overlay_lbl = Label.new()
	vb.add_child(_overlay_lbl)
	var btn := Button.new()
	btn.text = "Seguir jugando"
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_seguir)
	vb.add_child(btn)

func _on_ascenso(rango: String) -> void:
	_overlay_lbl.text = "Has ascendido a %s.\nTu comisaría marcha bien: sigue creciendo." % rango
	_overlay.visible = true
	_vel_previa = maxi(1, Tiempo.get_velocidad())
	_set_vel(0)

func _on_seguir() -> void:
	_overlay.visible = false
	_set_vel(1)

func _process(delta: float) -> void:
	var ciclo: String = "Noche" if Tiempo.es_de_noche() else "Día"
	_lbl_tiempo.text = "Hora %s · Día %d · %s · %s" % [Tiempo.hora_texto(), Tiempo.dia(), Tiempo.turno_texto(), ciclo]
	_lbl_recursos.text = "Presupuesto: %d €   ·   Puestos: %d   ·   Agentes: %d/%d" % [Economia.saldo_eur, _mundo.num_puestos(), _mundo.agentes_asignados(), _mundo.num_agentes()]

	var cap: int = _mundo.capacidad_cola()
	var de_pie_txt: String = "%d/%d" % [_mundo.de_pie(), cap] if cap > 0 else str(_mundo.de_pie())
	_lbl_flujo.text = "En cola: %d · De pie: %s · Espera: %.0f min · Atendidos: %d" % [_mundo.en_cola(), de_pie_txt, _mundo.espera_media(), _mundo.atendidos()]
	_lbl_objetivo.text = "Rango: %s   ·   Objetivo: %d / %d atendidos" % [_mundo.rango_texto(), _mundo.atendidos(), _mundo.objetivo()]
	_lbl_perf.text = "NPCs vivos: %d   ·   FPS: %d" % [_mundo.npcs_vivos(), int(Engine.get_frames_per_second())]

	var v: int = Tiempo.get_velocidad()
	_lbl_vel.text = "  Velocidad: %s" % ("Pausa" if v == 0 else "%dx" % v)

	_boton_puesto.text = "◼ Puesto" if _mundo.en_modo_puesto() else "Construir puesto (500 €)"
	_boton_barandilla.text = "◼ Cola" if _mundo.en_modo_barandilla() else "Trazar cola"
	_boton_demoler.text = "◼ Borrar" if _mundo.en_modo_demoler() else "Borrar"
	_boton_agente.text = "◼ Agentes" if _mundo.en_modo_agente() else "Agentes"
	_boton_estres.text = "◼ Estrés" if _mundo.en_estres() else "Test rendimiento"

	if _mundo.en_modo_puesto():
		_lbl_ayuda.text = "Construir: clic izq = colocar · R = rotar · clic der = salir"
	elif _mundo.en_modo_barandilla():
		_lbl_ayuda.text = "Cola: clic izq = poste (empieza por la cabeza) · Z = deshacer · clic der = salir"
	elif _mundo.en_modo_demoler():
		_lbl_ayuda.text = "Borrar: clic izq sobre un puesto (devuelve 250 €) o un poste · clic der = salir"
	elif _mundo.en_modo_agente():
		_lbl_ayuda.text = "Agentes: clic en un agente y luego en un puesto · clic fuera = a disponibles · clic der = salir"
	else:
		_lbl_ayuda.text = ""

	var objetivo: Color = COLOR_NOCHE if Tiempo.es_de_noche() else COLOR_DIA
	_fondo.color = _fondo.color.lerp(objetivo, clampf(delta * 2.0, 0.0, 1.0))

	var alto: float = get_viewport().get_visible_rect().size.y
	_panel.position = Vector2(16.0, alto - _panel.size.y - 16.0)

	if _overlay.visible:
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_overlay_panel.position = (vp - _overlay_panel.size) * 0.5

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_SPACE: _toggle_pausa()
			KEY_1: _set_vel(1)
			KEY_2: _set_vel(2)
			KEY_3: _set_vel(3)

func _toggle_pausa() -> void:
	if Tiempo.esta_en_pausa():
		_set_vel(maxi(1, _vel_previa))
	else:
		_vel_previa = Tiempo.get_velocidad()
		_set_vel(0)

func _set_vel(v: int) -> void:
	Tiempo.set_velocidad(v)
