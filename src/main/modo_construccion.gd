class_name ModoConstruccion extends Node2D
## ModoConstruccion — el ANDAMIO de interacción del modo construcción (story const-007).
##
## Herramientas de ratón sobre el modelo de Construcción: preview fantasma verde/rojo (F6 en vivo,
## con TEXTO además del color — daltónicos), dibujar salas arrastrando (área y coste en vivo, F1),
## colocar elementos con clic (paga por el gate E4) y demoler con confirmación de cascada.
##
## Reglas (control-manifest, Presentation): la UI LEE el estado y ORDENA por la API pública de
## Construcción (`validar_*`/`construir_*`/`demoler_*`) — NUNCA muta el modelo ni el saldo
## directamente. El dibujo del preview corre en `_process` con guarda de celda (cero trabajo si el
## cursor no cambia de celda). Este andamio NO es la UI real (condición 3 del gate: /ux-design
## antes del panel definitivo — UI/HUD #11 lo sustituirá).
##
## Story: production/epics/construccion/story-007-modo-construccion-raton.md · TR-construction-002 · ADR-0004/0001

const COLOR_VALIDO := Color(0.4, 1.0, 0.4, 0.4)
const COLOR_INVALIDO := Color(1.0, 0.35, 0.35, 0.4)
const COLOR_DEMOLER := Color(1.0, 0.6, 0.2, 0.4)
const COLOR_BOTON_ACTIVO := Color(1.0, 0.85, 0.35)
## Hueco reservado para la barra de info de Main (abajo del todo): esta barra se apoya ENCIMA.
const HUECO_BARRA_INFO := 84.0

var _construccion: Node = null
var _tam_celda: int = 40

# ── Estado de la interacción ─────────────────────────────────────────────────────────────────
var _activo: bool = false
## Herramienta en mano: &"" ninguna · &"demoler" · un id de TipoSala/TipoPuesto/ASIENTO_BASICO.
var _herramienta: StringName = &""
var _es_sala: bool = false
var _arrastrando: bool = false
var _celda_inicio: Vector2i = Vector2i.ZERO
## Guardas del refresco del preview (solo se redibuja al CAMBIAR de celda/herramienta — cero alloc
## por frame con el cursor quieto).
var _celda_anterior: Vector2i = Vector2i(-999, -999)
var _herramienta_anterior: StringName = &"-"
var _arrastre_anterior: bool = false

# ── Nodos de UI (construidos por código, patrón del HUD del esqueleto) ───────────────────────
var _atenuador: ColorRect
## HFlowContainer (no HBox): con los nombres del catálogo la fila supera el ancho de la ventana y
## los últimos botones (Asiento, Demoler) quedaban FUERA de pantalla — el flow envuelve en filas.
var _fila_herramientas: HFlowContainer
var _lbl_estado: Label
var _boton_modo: Button
var _botones_herramienta: Dictionary = {}
var _preview_caja: Panel
var _estilo_preview: StyleBoxFlat
var _preview_texto: Label
var _dialogo_cascada: ConfirmationDialog
var _sala_a_demoler: StringName = &""


## Inyección de dependencias (la llama Main ANTES de add_child).
func configurar(construccion: Node, tam_celda: int) -> void:
	_construccion = construccion
	_tam_celda = tam_celda


func _ready() -> void:
	_crear_ui()
	_actualizar_visibilidad()


# ── Entrada (la UI ordena por la API pública; atajos: B modo · clic dcho/Esc cancela) ────────
func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not (evento as InputEventKey).echo:
		match (evento as InputEventKey).keycode:
			KEY_B:
				_alternar_modo()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if _activo:
					_cancelar()
					get_viewport().set_input_as_handled()
		return
	if not _activo or not (evento is InputEventMouseButton):
		return
	var boton := evento as InputEventMouseButton
	if boton.button_index == MOUSE_BUTTON_RIGHT and boton.pressed:
		_cancelar()
	elif boton.button_index == MOUSE_BUTTON_LEFT:
		if boton.pressed:
			_al_pulsar()
		else:
			_al_soltar()


func _al_pulsar() -> void:
	var celda: Vector2i = _construccion.celda_bajo_cursor()
	if _herramienta == &"":
		return
	if _herramienta == &"demoler":
		_demoler_en(celda)
	elif _es_sala:
		_arrastrando = true
		_celda_inicio = celda
	else:
		_construccion.construir_elemento(_herramienta, celda)


func _al_soltar() -> void:
	if not _arrastrando:
		return
	_arrastrando = false
	_construccion.construir_sala(_herramienta, _rect_entre(_celda_inicio, _construccion.celda_bajo_cursor()))


## Demoler con la cascada del GDD: un elemento directo; una sala VACÍA directa; una sala con
## contenido pide CONFIRMACIÓN (paso 1 `contenido_de_sala` + reembolso; paso 2 al confirmar).
func _demoler_en(celda: Vector2i) -> void:
	var elemento_id: StringName = _construccion.elemento_en(celda)
	if elemento_id != &"":
		_construccion.demoler_elemento(elemento_id)
		return
	var sala_id: StringName = _construccion.sala_en(celda)
	if sala_id == &"":
		return
	var contenido: Array = _construccion.contenido_de_sala(sala_id)
	if contenido.is_empty():
		_construccion.demoler_sala(sala_id)
		return
	_sala_a_demoler = sala_id
	_dialogo_cascada.dialog_text = (
		"Demoler la sala y sus %d elementos.\nReembolso total: %.0f €"
		% [contenido.size(), _construccion.reembolso_de_sala(sala_id)]
	)
	_dialogo_cascada.popup_centered()


## Cancela por capas: primero el arrastre, luego suelta la herramienta, luego sale del modo.
func _cancelar() -> void:
	if _arrastrando:
		_arrastrando = false
	elif _herramienta != &"":
		_fijar_herramienta(&"", false)
	else:
		_alternar_modo()


func _alternar_modo() -> void:
	_activo = not _activo
	_arrastrando = false
	_fijar_herramienta(&"", false)
	_actualizar_visibilidad()


func _fijar_herramienta(id: StringName, es_sala: bool) -> void:
	_herramienta = id
	_es_sala = es_sala
	for boton_id: StringName in _botones_herramienta:
		(_botones_herramienta[boton_id] as Button).modulate = (
			COLOR_BOTON_ACTIVO if boton_id == id else Color.WHITE
		)


# ── Preview fantasma (dibujo en _process con guarda de celda — ADR-0001) ─────────────────────
func _process(_delta: float) -> void:
	if not _activo or _herramienta == &"":
		_preview_caja.visible = false
		_preview_texto.visible = false
		_celda_anterior = Vector2i(-999, -999)
		return
	var celda: Vector2i = _construccion.celda_bajo_cursor()
	if (
		celda == _celda_anterior and _herramienta == _herramienta_anterior
		and _arrastrando == _arrastre_anterior
	):
		return
	_celda_anterior = celda
	_herramienta_anterior = _herramienta
	_arrastre_anterior = _arrastrando
	_preview_caja.visible = true
	_preview_texto.visible = true
	if _herramienta == &"demoler":
		_refrescar_preview_demoler(celda)
	elif _es_sala and _arrastrando:
		_refrescar_preview_sala(_rect_entre(_celda_inicio, celda))
	else:
		_refrescar_preview_elemento(celda)


func _refrescar_preview_demoler(celda: Vector2i) -> void:
	_colocar_caja(celda, Vector2i.ONE, COLOR_DEMOLER)
	var elemento_id: StringName = _construccion.elemento_en(celda)
	var sala_id: StringName = _construccion.sala_en(celda)
	if elemento_id != &"":
		_preview_texto.text = "Demoler elemento"
	elif sala_id != &"":
		_preview_texto.text = "Demoler sala (+%.0f €)" % _construccion.reembolso_de_sala(sala_id)
	else:
		_preview_texto.text = "Nada que demoler"


func _refrescar_preview_sala(rect: Rect2i) -> void:
	# Enmienda 007: pegado/solapado a una sala del mismo tipo = AMPLIACIÓN (solo celdas nuevas).
	var ampliable: StringName = _construccion.sala_ampliable(_herramienta, rect)
	var coste: float
	var valido: bool
	var accion: String
	if ampliable != &"":
		coste = _construccion.coste_ampliacion(ampliable, rect)
		valido = true
		accion = "AMPLIAR sala"
	else:
		coste = _construccion.coste_sala(_herramienta, rect)
		valido = _construccion.validar_sala(_herramienta, rect)
		accion = "Sala nueva"
	var con_caja: bool = _construccion.puede_pagar(coste)
	_colocar_caja(rect.position, rect.size, COLOR_VALIDO if valido and con_caja else COLOR_INVALIDO)
	_preview_texto.text = "%s · %d celdas · %.0f € · %s" % [
		accion, rect.get_area(), coste,
		"Suelta para confirmar" if valido and con_caja else ("Sin caja" if valido else "No válido"),
	]


func _refrescar_preview_elemento(celda: Vector2i) -> void:
	var coste: float = _construccion.coste_elemento(_herramienta)
	var valido: bool = _construccion.validar_elemento(_herramienta, celda)
	var con_caja: bool = _construccion.puede_pagar(coste)
	if _es_sala:
		# Herramienta de sala sin arrastrar aún: pista de uso sobre la celda.
		_colocar_caja(celda, Vector2i.ONE, COLOR_VALIDO)
		_preview_texto.text = "Arrastra para dibujar (pegado a una sala igual, la amplía)"
		return
	_colocar_caja(celda, Vector2i.ONE, COLOR_VALIDO if valido and con_caja else COLOR_INVALIDO)
	_preview_texto.text = "%.0f € · %s" % [
		coste, "Válido" if valido and con_caja else ("Sin caja" if valido else "No válido"),
	]


## Coloca la caja del preview cubriendo `tam` celdas desde `celda` (coordenadas de mundo). El color
## se aplica como relleno translúcido + BORDE casi opaco (visible sobre cualquier sala).
func _colocar_caja(celda: Vector2i, tam: Vector2i, color: Color) -> void:
	var esquina: Vector2 = _construccion.centro_de_celda(celda) - Vector2(_tam_celda, _tam_celda) / 2.0
	_preview_caja.position = esquina
	_preview_caja.size = Vector2(tam * _tam_celda)
	_estilo_preview.bg_color = Color(color.r, color.g, color.b, 0.30)
	_estilo_preview.border_color = Color(color.r, color.g, color.b, 0.95)
	_preview_texto.position = esquina + Vector2(2, -20)


func _rect_entre(a: Vector2i, b: Vector2i) -> Rect2i:
	var origen := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var fin := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(origen, fin - origen + Vector2i.ONE)


# ── UI del andamio (barra inferior por código; botones con focus_mode NONE — gotcha Espacio) ─
func _crear_ui() -> void:
	var capa := CanvasLayer.new()
	capa.name = "UIConstruccion"
	add_child(capa)
	# Atenuador del mundo en modo construcción (deja pasar el ratón).
	_atenuador = ColorRect.new()
	_atenuador.color = Color(0.0, 0.0, 0.0, 0.18)
	_atenuador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atenuador.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(_atenuador)

	# Preview fantasma POR ENCIMA del atenuador (feedback del usuario: no se veía dónde iba a caer).
	# Sin cámara, las coordenadas de mundo y de pantalla coinciden → puede vivir en la CanvasLayer.
	# Borde grueso + relleno translúcido: se distingue sobre cualquier color de sala.
	_preview_caja = Panel.new()
	_estilo_preview = StyleBoxFlat.new()
	_estilo_preview.set_border_width_all(3)
	_preview_caja.add_theme_stylebox_override("panel", _estilo_preview)
	_preview_caja.visible = false
	_preview_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_preview_caja)
	_preview_texto = Label.new()
	_preview_texto.visible = false
	_preview_texto.add_theme_font_size_override("font_size", 13)
	_preview_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_preview_texto.add_theme_constant_override("outline_size", 4)
	capa.add_child(_preview_texto)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# Gotcha de anclas (el bug del "menú invisible"): anclada abajo, la barra debe CRECER HACIA
	# ARRIBA; sin esto se dibuja POR DEBAJO del borde de la pantalla. Y se apoya sobre la barra de
	# info de Main (hueco fijo — andamio; la UI real de /ux-design lo hará bien).
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = -HUECO_BARRA_INFO
	panel.offset_bottom = -HUECO_BARRA_INFO
	capa.add_child(panel)
	var caja := VBoxContainer.new()
	panel.add_child(caja)
	var fila_superior := HBoxContainer.new()
	fila_superior.add_theme_constant_override("separation", 8)
	caja.add_child(fila_superior)
	_boton_modo = Button.new()
	_boton_modo.text = "🔨 Construir (B)"
	_boton_modo.focus_mode = Control.FOCUS_NONE
	_boton_modo.pressed.connect(_alternar_modo)
	fila_superior.add_child(_boton_modo)
	_lbl_estado = Label.new()
	_lbl_estado.add_theme_font_size_override("font_size", 11)
	_lbl_estado.modulate = Color(1, 1, 1, 0.7)
	fila_superior.add_child(_lbl_estado)

	_fila_herramientas = HFlowContainer.new()
	_fila_herramientas.add_theme_constant_override("h_separation", 6)
	_fila_herramientas.add_theme_constant_override("v_separation", 4)
	caja.add_child(_fila_herramientas)
	# Los tipos se LEEN del catálogo — la UI nunca hardcodea costes/nombres (regla del GDD).
	for tipo_sala: Resource in Datos.obtener_todos(&"TipoSala"):
		_anadir_herramienta("▦ %s" % tipo_sala.nombre, tipo_sala.id, true)
	for tipo_puesto: Resource in Datos.obtener_todos(&"TipoPuesto"):
		if tipo_puesto.servicio == "Seguridad":
			continue   # la entrada/seguridad es fija (CO11) — no construible en el MVP
		_anadir_herramienta(
			"%s (%d €)" % [tipo_puesto.nombre, tipo_puesto.coste_construccion_eur], tipo_puesto.id, false
		)
	_anadir_herramienta(
		"Asiento (%.0f €)" % _construccion.coste_asiento_basico, _construccion.ASIENTO_BASICO, false
	)
	_anadir_herramienta("❌ Demoler", &"demoler", false)

	_dialogo_cascada = ConfirmationDialog.new()
	_dialogo_cascada.title = "Demolición en cascada"
	_dialogo_cascada.confirmed.connect(func() -> void: _construccion.demoler_sala(_sala_a_demoler))
	capa.add_child(_dialogo_cascada)


func _anadir_herramienta(texto: String, id: StringName, es_sala: bool) -> void:
	var boton := Button.new()
	boton.text = texto
	boton.focus_mode = Control.FOCUS_NONE
	boton.pressed.connect(func() -> void: _fijar_herramienta(id, es_sala))
	_fila_herramientas.add_child(boton)
	_botones_herramienta[id] = boton


func _actualizar_visibilidad() -> void:
	_fila_herramientas.visible = _activo
	_atenuador.visible = _activo
	_boton_modo.modulate = COLOR_BOTON_ACTIVO if _activo else Color.WHITE
	_lbl_estado.text = (
		"Elige herramienta · clic coloca · arrastra dibuja salas · clic dcho/Esc cancela"
		if _activo else "Modo construcción apagado"
	)
	if not _activo:
		_preview_caja.visible = false
		_preview_texto.visible = false
