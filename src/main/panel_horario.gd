class_name PanelHorario extends CanvasLayer
## PanelHorario — la pantalla donde el jugador **decide el horario de Documentación**: el slider de
## cierre (con el coste de la peonada en vivo), la última admisión, el semáforo de demanda y la
## bandeja de comunicados de la División. Se abre y cierra con la tecla **H**.
##
## Es la cara visible del epic Documentación #8: aquí es donde "más horas = más trámites = más
## peonada" deja de ser una tabla del GDD y se convierte en una decisión con un número delante.
##
## Reglas (control-manifest, Presentation): la UI **LEE** estado y **ORDENA** por la API pública de
## Documentación (`fijar_hora_cierre` / `fijar_margen_ultima_admision`) — no calcula ni guarda nada
## (ADR-0001). El coste se le PIDE a Documentación (`coste_peonada_estimado`), no se recalcula aquí:
## si algún día cambia la fórmula, esta pantalla no puede quedarse mintiendo. Botones con
## `focus_mode = FOCUS_NONE` (gotcha: si no, Espacio "pulsa" el botón enfocado en vez de pausar) y
## todo lo decorativo con `MOUSE_FILTER_IGNORE`. **Se puede operar EN PAUSA** (DO11).
##
## El comunicado de la División llega por el **bus** (`aviso_division`), no preguntando cada frame.
##
## Story: production/epics/documentacion/story-005-panel-horario-demo.md · TR-doc-001 · ADR-0001

## Colores de estado (SIEMPRE con texto al lado — respaldo daltónico, regla del proyecto).
const COLOR_TITULO := Color(1.0, 0.85, 0.35)
const COLOR_TENUE := Color(1, 1, 1, 0.6)
const COLOR_ABIERTO := Color(0.55, 0.9, 0.55)
const COLOR_CERRANDO := Color(1.0, 0.8, 0.35)
const COLOR_CERRADO := Color(0.6, 0.6, 0.6)
const COLOR_GASTO := Color(1.0, 0.55, 0.55)
## Semáforo de demanda (DO12): el color es refuerzo; el icono y el texto son lo que se lee.
const SEMAFORO: Dictionary[StringName, Array] = {
	&"BAJA": ["🟢", "BAJA", Color(0.55, 0.9, 0.55)],
	&"MEDIA": ["🟡", "MEDIA", Color(1.0, 0.8, 0.35)],
	&"ALTA": ["🔴", "ALTA", Color(1.0, 0.5, 0.5)],
}
## Paso del slider de cierre, en minutos (cuartos de hora: el horario de una ventanilla no se ajusta
## al minuto).
const PASO_CIERRE_MIN := 15
## Paso del control de última admisión, en minutos.
const PASO_MARGEN_MIN := 5

# ── Refs a los sistemas (inyectadas por Main; la UI solo lee y ordena — ADR-0001) ────────────
var _documentacion: Node = null
var _tiempo: Node = null

# ── Nodos de UI (construidos en configurar; el panel nace oculto) ────────────────────────────
var _panel: PanelContainer
var _lbl_estado: Label
var _slider_cierre: HSlider
var _lbl_cierre: Label
var _lbl_peonada: Label
var _slider_margen: HSlider
var _lbl_margen: Label
var _lbl_demanda: Label
var _lbl_comunicado: Label


## Inyección de dependencias + construcción de la UI (la llama Main tras add_child). El panel nace
## OCULTO y se repuebla al abrirlo (foto fresca), nunca por frame.
func configurar(documentacion: Node, tiempo: Node, bus: Node = null) -> void:
	_documentacion = documentacion
	_tiempo = tiempo
	_crear_ui()
	if bus != null:
		bus.aviso_division.connect(_al_aviso_division)
	visible = false


# ── Entrada (toggle con H) ───────────────────────────────────────────────────────────────────
## Tecla H alterna la visibilidad; Esc cierra. Al ABRIR se refresca (el horario puede haber cambiado
## por el panel DEV o por un evento de la División). El input se marca consumido para no arrastrar la
## tecla a otros manejadores.
func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey and evento.pressed and not (evento as InputEventKey).echo):
		return
	var tecla: int = (evento as InputEventKey).keycode
	if tecla == KEY_H:
		visible = not visible
		if visible:
			_refrescar()
		get_viewport().set_input_as_handled()
	elif tecla == KEY_ESCAPE and visible:
		visible = false
		get_viewport().set_input_as_handled()


## El estado del servicio y el semáforo cambian con el reloj: se refrescan mientras el panel está
## abierto (en `_process`, tiempo real — sigue funcionando a 2×/3× y en Pausa). Los sliders NO se
## tocan aquí: el jugador podría estar arrastrándolos.
func _process(_delta: float) -> void:
	if not visible or _documentacion == null:
		return
	_refrescar_estado()
	_refrescar_demanda()


# ── Construcción de la UI (por código; patrón del resto de paneles del proyecto) ─────────────
func _crear_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(620, 420)
	# Anclado al centro, el preset deja el tamaño en 0×0 y crece por el minimum → recentrar el pivote.
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	_panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = "Documentación — horario del servicio (H para cerrar)"
	titulo.add_theme_font_size_override("font_size", 14)
	titulo.modulate = COLOR_TITULO
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(titulo)

	_lbl_estado = _etiqueta(caja, 13)

	# ── El slider de cierre: la decisión principal ───────────────────────────────────────
	_separador(caja, "HORARIO DE CIERRE")
	_lbl_cierre = _etiqueta(caja, 13)
	_slider_cierre = HSlider.new()
	_slider_cierre.step = PASO_CIERRE_MIN
	_slider_cierre.custom_minimum_size = Vector2(0, 20)
	_slider_cierre.focus_mode = Control.FOCUS_NONE
	_slider_cierre.value_changed.connect(_al_mover_cierre)
	caja.add_child(_slider_cierre)
	_lbl_peonada = _etiqueta(caja, 13)

	# ── La última admisión: exprimir vs cuidar ───────────────────────────────────────────
	_separador(caja, "ÚLTIMA ADMISIÓN (hasta cuándo se da número)")
	_lbl_margen = _etiqueta(caja, 13)
	_slider_margen = HSlider.new()
	_slider_margen.min_value = 0
	_slider_margen.max_value = 30
	_slider_margen.step = PASO_MARGEN_MIN
	_slider_margen.custom_minimum_size = Vector2(0, 20)
	_slider_margen.focus_mode = Control.FOCUS_NONE
	_slider_margen.value_changed.connect(_al_mover_margen)
	caja.add_child(_slider_margen)
	var ayuda_margen: Label = _etiqueta(caja, 11)
	ayuda_margen.text = (
		"Margen alto = tu gente sale a su hora.  ·  Margen 0 = más trámites, "
		+ "pero quien se queda terminando fuera de hora se desmotiva."
	)
	ayuda_margen.modulate = COLOR_TENUE

	# ── La brújula y la bandeja de la División ───────────────────────────────────────────
	_separador(caja, "NIVEL DE DEMANDA (¿compensa alargar?)")
	_lbl_demanda = _etiqueta(caja, 13)
	_separador(caja, "COMUNICADOS DE LA DIVISIÓN")
	_lbl_comunicado = _etiqueta(caja, 12)
	_lbl_comunicado.autowrap_mode = TextServer.AUTOWRAP_WORD

	var cerrar := Button.new()
	cerrar.text = "Cerrar (H)"
	cerrar.focus_mode = Control.FOCUS_NONE
	cerrar.pressed.connect(func() -> void: visible = false)
	caja.add_child(cerrar)


## Una etiqueta del panel (decorativa → nunca se traga los clics).
func _etiqueta(padre: VBoxContainer, tam: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.add_theme_font_size_override("font_size", tam)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(etiqueta)
	return etiqueta


## Cabecera de sección (sobria, estilo expediente).
func _separador(padre: VBoxContainer, texto: String) -> void:
	var etiqueta: Label = _etiqueta(padre, 11)
	etiqueta.text = "— " + texto
	etiqueta.modulate = COLOR_TENUE


# ── Órdenes al dueño (la UI nunca calcula ni guarda: ordena y relee) ─────────────────────────

## El jugador mueve el slider de cierre: se le ORDENA a Documentación y se refresca con lo que ella
## haya aceptado (puede haber clampado al tope autorizado — manda el dueño, no la barra).
func _al_mover_cierre(valor: float) -> void:
	if _documentacion == null:
		return
	_documentacion.fijar_hora_cierre(int(valor))
	_refrescar_cierre()
	_refrescar_estado()


func _al_mover_margen(valor: float) -> void:
	if _documentacion == null:
		return
	_documentacion.fijar_margen_ultima_admision(int(valor))
	_refrescar_margen()
	_refrescar_estado()


## Comunicado de la División (oyente del bus): la UI **escucha**, no pregunta cada frame.
func _al_aviso_division(_evento_id: StringName, _nombre: String, _activo: bool) -> void:
	_refrescar_comunicado()
	_refrescar_cierre()   # el tope autorizado ha cambiado → el slider tiene otro recorrido


# ── Refresco ─────────────────────────────────────────────────────────────────────────────────

## Foto completa (al abrir el panel y cuando cambia el marco).
func _refrescar() -> void:
	if _documentacion == null:
		return
	_refrescar_cierre()
	_refrescar_margen()
	_refrescar_estado()
	_refrescar_demanda()
	_refrescar_comunicado()


## El slider y sus dos números: la hora de cierre y lo que cuesta esa decisión (F1, en vivo).
func _refrescar_cierre() -> void:
	var doc: Node = _documentacion
	_slider_cierre.set_block_signals(true)          # reposicionar la barra no es una orden del jugador
	_slider_cierre.min_value = doc.cierre_base_min
	_slider_cierre.max_value = doc.tope_autorizado()
	_slider_cierre.value = doc.hora_cierre_min
	_slider_cierre.set_block_signals(false)
	var horas: float = doc.horas_extra()
	_lbl_cierre.text = "Cierra a las %s   (jornada base %s · máximo autorizado hoy %s)" % [
		_hhmm(doc.hora_cierre_min), _hhmm(doc.cierre_base_min), _hhmm(doc.tope_autorizado()),
	]
	if horas <= 0.0:
		_lbl_peonada.text = "Sin horas extra: la jornada base no cuesta peonada."
		_lbl_peonada.modulate = COLOR_TENUE
		return
	_lbl_peonada.text = "+%s h extra × %d agente(s)  →  PEONADA %s €/día" % [
		_num(horas), doc.num_agentes_doc(), _num(doc.coste_peonada_estimado()),
	]
	_lbl_peonada.modulate = COLOR_GASTO


func _refrescar_margen() -> void:
	var doc: Node = _documentacion
	_slider_margen.set_block_signals(true)
	_slider_margen.value = doc.margen_ultima_admision_min
	_slider_margen.set_block_signals(false)
	_lbl_margen.text = "Se deja de dar número %d min antes de cerrar  →  última admisión a las %s" % [
		doc.margen_ultima_admision_min, _hhmm(doc.hora_ultima_admision()),
	]


## Estado del servicio AHORA (texto siempre; el color solo refuerza).
func _refrescar_estado() -> void:
	var doc: Node = _documentacion
	var minuto: float = _tiempo.minutos_juego if _tiempo != null else 0.0
	match doc.estado_servicio(minuto):
		doc.ESTADO_ABIERTO:
			_lbl_estado.text = "Ahora: ABIERTA — dando número (hasta las %s)" % _hhmm(
				doc.hora_ultima_admision()
			)
			_lbl_estado.modulate = COLOR_ABIERTO
		doc.ESTADO_CERRANDO:
			_lbl_estado.text = "Ahora: CERRANDO — ya no se da número; se termina a los admitidos"
			_lbl_estado.modulate = COLOR_CERRANDO
		_:
			_lbl_estado.text = "Ahora: CERRADA — abre a las %s" % _hhmm(doc.apertura_base_min)
			_lbl_estado.modulate = COLOR_CERRADO


## El semáforo de demanda (DO12) con icono + texto: la brújula de la peonada, nunca solo color.
func _refrescar_demanda() -> void:
	var nivel: StringName = _documentacion.nivel_demanda()
	var pinta: Array = SEMAFORO.get(nivel, ["🟡", String(nivel), COLOR_TENUE])
	var consejo: String = "ampliar suele salir a pérdidas" if nivel == &"BAJA" else (
		"ajustado: depende de la cola que te quede al cierre" if nivel == &"MEDIA"
		else "hay cola de sobra: alargar suele compensar"
	)
	_lbl_demanda.text = "%s  Demanda %s — %s" % [pinta[0], pinta[1], consejo]
	_lbl_demanda.modulate = pinta[2]


## La bandeja de comunicados: el de la División vigente o "sin comunicados".
func _refrescar_comunicado() -> void:
	var evento: Resource = _documentacion.evento_activo()
	if evento == null:
		_lbl_comunicado.text = "Sin comunicados. El horario se puede ampliar hasta las %s." % _hhmm(
			_documentacion.slider_max_min
		)
		_lbl_comunicado.modulate = COLOR_TENUE
		return
	_lbl_comunicado.text = "📄 %s\n%s\n(Autoriza cerrar hasta las %s.)" % [
		evento.nombre, evento.descripcion, _hhmm(evento.cierre_max_min),
	]
	_lbl_comunicado.modulate = COLOR_TITULO


# ── Formato ──────────────────────────────────────────────────────────────────────────────────

## Minutos del día → "HH:MM" (el reloj del juego tiene su propio helper; aquí se recibe un int puro).
func _hhmm(minuto_del_dia: int) -> String:
	return "%02d:%02d" % [int(minuto_del_dia / 60.0) % 24, minuto_del_dia % 60]


## Número corto: sin decimales si es redondo, con uno si no (GDScript no admite "%.*f").
func _num(valor: float) -> String:
	if is_equal_approx(valor, roundf(valor)):
		return "%d" % int(roundf(valor))
	return "%.1f" % valor
