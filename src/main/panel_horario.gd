class_name PanelHorario extends CanvasLayer
## PanelHorario — la pantalla **HORARIO**: donde el jugador decide cuándo cierra Documentación y
## cuánto le cuesta esa decisión. Se abre y cierra con la tecla **H** (o desde la píldora del HUD,
## `Main._abrir_horario`).
##
## Es la cara visible del epic Documentación #8: aquí "más horas = más trámites = más peonada" deja
## de ser una tabla del GDD y se convierte en un número con euros delante.
##
## **F3 (2026-08-18)**: el andamio de sliders sueltos se sustituye por la maqueta APROBADA
## `design/ux/maquetas-menu-2026-08/maqueta_horario.png` (script de referencia, vinculante:
## `maqueta_horario.py`) — mismo lenguaje moderno que el Tablón de Destinos (`panel_personal.gd`):
## velo oscuro + modal claro a pantalla casi completa, tarjetas blancas con sombra, un único acento
## azul, y **cero hex sueltos** (todo sale de `KitUIComisario`). El contrato con `Main` NO cambia:
## misma clase, mismo archivo, `configurar(documentacion, tiempo, bus, personal)`, `usar_flujo(flujo)`
## y `_refrescar()`.
##
## Reglas que gobiernan este archivo:
## - **ADR-0001 (Presentation)**: la UI **LEE** estado y **ORDENA** por la API pública de
##   Documentación (`fijar_hora_cierre`, `fijar_peonada_eur_hora`, `fijar_margen_ultima_admision`,
##   `fijar_puesto_de_tarde`) y de Flujo (`abrir_puesto`/`cerrar_puesto`). No calcula ni guarda nada:
##   el coste se le **pide** a Documentación (`coste_peonada_estimado`), nunca se recalcula aquí — si
##   mañana cambia la fórmula, esta pantalla no puede quedarse mintiendo.
## - Refresco **PULL**: se repinta al abrir y después de CADA orden. Lo único que se mira por frame
##   (`_process`) es el estado del servicio y la demanda, que cambian con el reloj.
## - **Se puede operar EN PAUSA** (DO11).
## - El comunicado de la División llega por el **bus** (`aviso_division`), no preguntando cada frame.
## - Accesibilidad: los estados van con **punto de color + texto** (nunca solo color) y todo botón con
##   `focus_mode = FOCUS_NONE` (gotcha: si no, Espacio "pulsa" el botón enfocado en vez de pausar).
##
## Story: production/epics/documentacion/story-005-panel-horario-demo.md · TR-doc-001 · ADR-0001 ·
## spec `design/ux/menu-horario-spec.md`

## `class_name` no resuelve en headless frío (gotcha del proyecto) → SIEMPRE `preload`.
const KitUIComisarioScript := preload("res://src/ui/kit_ui_comisario.gd")
## El nombre VISIBLE de una ventanilla ("DNI 1") sale de UNA sola fuente en todo el juego: el helper
## estático del Tablón de Destinos. Aquí NO se duplica la tabla de prefijos.
const PanelPersonalScript := preload("res://src/main/panel_personal.gd")

# ── Geometría (todos los números salen de `maqueta_horario.py`) ───────────────────────────────────
## Margen del modal contra el borde de la ventana (maqueta: 48 en horizontal, 40 en vertical).
const MARGEN_MODAL := Vector2(48.0, 40.0)
## Aire interior del modal (maqueta: `pad = 32`).
const PADDING_MODAL := 32.0
## Velo oscuro sobre el juego (maqueta: 10,14,24 con alfa 205/255) — el mismo que el Tablón.
const COLOR_VELO := Color(0.039, 0.055, 0.094, 0.804)
## Tarjeta de control grande (maqueta: `alto_ctrl = 172`, `rounded_rectangle(..., 18)`, `pad = 26`).
## Es el alto DESEADO: las tres tarjetas se reparten el hueco de la columna (`SIZE_EXPAND_FILL`) y
## nunca bajan de `ALTO_MIN_TARJETA_CONTROL`. La maqueta está compuesta a 1616×939; en una ventana de
## 1280×720 las tres a 172 px fijos no caben y se salían del modal (auditado en captura).
const ALTO_TARJETA_CONTROL := 172.0
const ALTO_MIN_TARJETA_CONTROL := 132.0
const RADIO_TARJETA_CONTROL := 18.0
const PAD_TARJETA_CONTROL := 26.0
## Alto de la banda del slider y de la banda de la marca del tope ordinario que va debajo.
const ALTO_ZONA_SLIDER := 22.0
const ALTO_ZONA_MARCA := 18.0
## Reparto horizontal de las dos columnas — los anchos EXACTOS de la maqueta (940 / 490) usados como
## `stretch_ratio`, así la proporción se conserva a cualquier tamaño de ventana.
const RATIO_COLUMNA_DECISION := 940.0
const RATIO_COLUMNA_VENTANILLAS := 490.0
## Tarjeta de ventanilla y tarjeta del coste total (maqueta: `alto_vent = 96`, `alto_total = 78`).
const ALTO_TARJETA_VENTANILLA := 96.0
const ALTO_TARJETA_TOTAL := 78.0
const RADIO_TARJETA_PEQUENA := 14.0
const PAD_TARJETA_PEQUENA := 18.0
## Casilla "se queda por la tarde" (maqueta: lado 20).
const LADO_CASILLA := 20.0
## Banner del comunicado de la División (maqueta: alto 44, radio 12, franja de 4 px).
const ALTO_BANNER := 44.0
const RADIO_BANNER := 12.0
const ANCHO_FRANJA_BANNER := 4.0
## Paso del slider de cierre, en minutos (cuartos de hora: el horario de una ventanilla no se ajusta
## al minuto).
const PASO_CIERRE_MIN := 15
## Paso y tope del control de última admisión, en minutos (el rango que autoriza Documentación).
const PASO_MARGEN_MIN := 5
const MARGEN_MAX_MIN := 30
## Recargo de cansancio de una hora extra según lo que se pague (fórmula de `personal.gd`, leída, no
## inventada): **1,5 pagando el convenio · 1,0 al tope autorizado** — pagar MEJOR cansa MENOS.
const RECARGO_CANSANCIO_CONVENIO := 1.5
const RECARGO_CANSANCIO_TOPE := 1.0
## Umbral a partir del cual el precio de la hora extra se considera generoso (la maqueta pinta el
## efecto en verde por encima de la mitad del recorrido).
const GENEROSIDAD_GENEROSA := 0.5

# ── Refs a los sistemas (inyectadas por Main; la UI solo lee y ordena — ADR-0001) ────────────────
var _documentacion: Node = null
var _tiempo: Node = null
## Flujo: para poder ABRIR y CERRAR cada ventanilla desde aquí (petición del usuario 2026-07-29). Es
## una acción DISTINTA de la casilla "se queda por la tarde": esa decide el horario, esta baja la
## persiana AHORA MISMO.
var _flujo: Node = null
## Personal: de él salen el tipo de cada ventanilla, si está dotada y QUIÉN la opera (solo LECTURA).
var _personal: Node = null

# ── Nodos de UI (construidos en `configurar`; el panel nace oculto) ──────────────────────────────
var _velo: ColorRect
var _panel: PanelContainer
## Cabecera: estado del servicio y demanda, cada uno como punto de color + texto.
var _punto_estado: Panel
var _lbl_estado: Label
var _punto_demanda: Panel
var _lbl_demanda: Label
## Banner del comunicado de la División (solo visible si hay evento activo).
var _banner: PanelContainer
var _lbl_banner_titulo: Label
var _lbl_banner_cuerpo: Label
## Las tres tarjetas de control de la columna izquierda.
var _ctrl_cierre: TarjetaControl
var _ctrl_precio: TarjetaControl
var _ctrl_margen: TarjetaControl
## Columna derecha: una tarjeta por ventanilla + el resumen del coste.
var _lista_ventanillas: VBoxContainer
var _tarjeta_total: PanelContainer
var _estilo_total: StyleBoxFlat
var _lbl_total_titulo: Label
var _lbl_total: Label
## Una entrada por ventanilla pintada: `{"puesto_id": StringName, "lbl_detalle": Label}` — para
## repintar SOLO su línea de coste al mover un slider (reconstruir la lista entera mientras el jugador
## arrastra tiraría su propia casilla al suelo).
var _filas_ventanilla: Array[Dictionary] = []


## Inyección de dependencias + construcción de la UI (la llama Main tras `add_child`). El panel nace
## OCULTO y se repuebla al abrirlo (foto fresca), nunca por frame.
func configurar(documentacion: Node, tiempo: Node, bus: Node = null, personal: Node = null) -> void:
	_documentacion = documentacion
	_tiempo = tiempo
	_personal = personal
	# Por ENCIMA de la brújula de depuración (layer 10, `Main._crear_brujula_orientacion`): un modal a
	# pantalla completa debe tapar TODO (misma decisión que el Tablón de Destinos).
	layer = 12
	_crear_ui()
	if bus != null:
		bus.aviso_division.connect(_al_aviso_division)
	visible = false


## Inyecta Flujo DESPUÉS de `configurar`: Main crea el panel antes que Flujo, así que en el momento de
## configurarlo todavía no existe (se le pasaba `null` y el botón de abrir/cerrar no aparecía).
func usar_flujo(flujo: Node) -> void:
	_flujo = flujo
	_refrescar_ventanillas()


# ── Entrada (toggle con H) ───────────────────────────────────────────────────────────────────────
## Tecla H alterna la visibilidad; Esc cierra. Al ABRIR se refresca (el horario puede haber cambiado
## por el panel DEV o por un evento de la División) y se recoloca el modal. El input se marca
## consumido para no arrastrar la tecla a otros manejadores.
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


# ══ Construcción de la UI (por código — el proyecto no usa .tscn salvo Main) ═════════════════════
func _crear_ui() -> void:
	# EL VELO: bloquea el juego de debajo (MOUSE_FILTER_STOP) pero NO se come los clics del panel — el
	# modal es un HERMANO POSTERIOR, así que recibe el input antes que el velo.
	_velo = ColorRect.new()
	_velo.color = COLOR_VELO
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_velo)

	_panel = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_PANEL
	estilo.set_corner_radius_all(22)   # maqueta: marco del modal con radio 22
	estilo.shadow_size = 14
	estilo.shadow_color = Color(0.039, 0.055, 0.094, 0.24)
	estilo.shadow_offset = Vector2(0.0, 8.0)
	estilo.content_margin_left = PADDING_MODAL
	estilo.content_margin_right = PADDING_MODAL
	estilo.content_margin_top = PADDING_MODAL
	estilo.content_margin_bottom = PADDING_MODAL
	_panel.add_theme_stylebox_override("panel", estilo)
	# La tipografía moderna de golpe: el Theme del kit pone Segoe UI a TODO lo que cuelgue del panel
	# (sin él cada Label hereda la pixelada en mayúsculas del tema global — gotcha ya cazado en F1).
	_panel.theme = KitUIComisarioScript.moderno_tema()
	add_child(_panel)
	# Las anclas de un Control bajo CanvasLayer no son fiables en este proyecto (gotcha) y los
	# contenedores OCULTOS no re-miden: el tamaño y la posición se fijan a mano al mostrar y en cada
	# resize de la ventana. Mismo patrón que `PanelPersonal._recolocar_panel`.
	get_viewport().size_changed.connect(_recolocar_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	_panel.add_child(caja)

	caja.add_child(_crear_cabecera())

	var fila_estado: HBoxContainer = _crear_fila_punto(14, 6.0)
	_punto_estado = fila_estado.get_child(0) as Panel
	_lbl_estado = fila_estado.get_child(1) as Label
	caja.add_child(fila_estado)

	var fila_demanda: HBoxContainer = _crear_fila_punto(13, 6.0)
	_punto_demanda = fila_demanda.get_child(0) as Panel
	_lbl_demanda = fila_demanda.get_child(1) as Label
	caja.add_child(fila_demanda)

	caja.add_child(_crear_banner())
	caja.add_child(_linea())

	var cuerpo := HBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 26)   # maqueta: `gap_col = 26`
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(cuerpo)
	cuerpo.add_child(_crear_columna_decision())
	cuerpo.add_child(_crear_columna_ventanillas())


## Cabecera: título + subtítulo a la izquierda, botón "Cerrar (H)" a la derecha.
func _crear_cabecera() -> HBoxContainer:
	var fila := HBoxContainer.new()
	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 2)
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(textos)
	textos.add_child(_etiqueta("Horario", 24, KitUIComisarioScript.MOD_COLOR_TINTA, true))
	textos.add_child(_etiqueta(
		"Documentación — decide cuándo cierra el servicio y cuánto cuesta",
		12, KitUIComisarioScript.MOD_COLOR_GRIS
	))
	var cerrar: Button = KitUIComisarioScript.moderno_boton_pastilla(
		"Cerrar (H)", KitUIComisarioScript.MOD_BOTON_SECUNDARIO, 30.0
	)
	cerrar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cerrar.pressed.connect(func() -> void: visible = false)
	fila.add_child(cerrar)
	return fila


## El banner del comunicado de la División: franja de acento + titular + cuerpo. Nace OCULTO; solo lo
## enseña `_refrescar_comunicado` si hay evento activo (sin comunicado no hay banner vacío ocupando
## sitio — criterio de la maqueta).
func _crear_banner() -> PanelContainer:
	_banner = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_ACENTO_SUAVE
	estilo.set_corner_radius_all(int(RADIO_BANNER))
	_banner.add_theme_stylebox_override("panel", estilo)
	_banner.custom_minimum_size.y = ALTO_BANNER
	_banner.visible = false

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 0)
	_banner.add_child(fila)

	var franja := Panel.new()
	franja.custom_minimum_size.x = ANCHO_FRANJA_BANNER
	franja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo_franja := StyleBoxFlat.new()
	estilo_franja.bg_color = KitUIComisarioScript.MOD_COLOR_ACENTO
	estilo_franja.set_corner_radius_all(2)
	franja.add_theme_stylebox_override("panel", estilo_franja)
	fila.add_child(franja)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 14)
	margen.add_theme_constant_override("margin_right", 14)
	margen.add_theme_constant_override("margin_top", 6)
	margen.add_theme_constant_override("margin_bottom", 6)
	margen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(margen)
	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 2)
	margen.add_child(textos)
	_lbl_banner_titulo = _etiqueta("", 11, KitUIComisarioScript.MOD_COLOR_ACENTO, true)
	textos.add_child(_lbl_banner_titulo)
	_lbl_banner_cuerpo = _etiqueta("", 11, KitUIComisarioScript.MOD_COLOR_TINTA)
	# Con autowrap el ancho MÍNIMO de un Label es 0: sin EXPAND_FILL el texto sale a una palabra por
	# línea (bug cazado en la ficha del Tablón, `capturas/error.PNG`).
	_lbl_banner_cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD
	_lbl_banner_cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_child(_lbl_banner_cuerpo)
	return _banner


## Columna izquierda — "LA DECISIÓN DEL DÍA": las tres tarjetas de control grandes.
func _crear_columna_decision() -> VBoxContainer:
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.size_flags_stretch_ratio = RATIO_COLUMNA_DECISION
	columna.add_child(_etiqueta("LA DECISIÓN DEL DÍA", 13, KitUIComisarioScript.MOD_COLOR_TINTA, true))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 20)   # maqueta: 20 px entre tarjetas de control
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)

	# 1 · HORARIO DE CIERRE — el recorrido llega hasta el tope autorizado HOY, y si un comunicado lo
	# ha ampliado se DIBUJA dónde estaba el tope ordinario (honestidad: se ve POR QUÉ llega más lejos).
	_ctrl_cierre = _crear_tarjeta_control(
		"HORARIO DE CIERRE", KitUIComisarioScript.MOD_COLOR_AMBAR, true
	)
	_ctrl_cierre.slider.step = PASO_CIERRE_MIN
	_ctrl_cierre.slider.value_changed.connect(_al_mover_cierre)
	lista.add_child(_ctrl_cierre)

	# 2 · PRECIO DE LA HORA EXTRA — pagar mejor cansa menos (story bien-002).
	_ctrl_precio = _crear_tarjeta_control(
		"PRECIO DE LA HORA EXTRA", KitUIComisarioScript.MOD_COLOR_ACENTO, false
	)
	_ctrl_precio.slider.step = 1.0
	_ctrl_precio.slider.value_changed.connect(_al_mover_precio)
	lista.add_child(_ctrl_precio)

	# 3 · ÚLTIMA ADMISIÓN — exprimir vs cuidar.
	_ctrl_margen = _crear_tarjeta_control(
		"ÚLTIMA ADMISIÓN — hasta cuándo se da número", KitUIComisarioScript.MOD_COLOR_ACENTO, false
	)
	_ctrl_margen.slider.min_value = 0.0
	_ctrl_margen.slider.max_value = float(MARGEN_MAX_MIN)
	_ctrl_margen.slider.step = PASO_MARGEN_MIN
	_ctrl_margen.slider.value_changed.connect(_al_mover_margen)
	_ctrl_margen.lbl_min.text = "0 min (exprimir)"
	_ctrl_margen.lbl_max.text = "%d min (cuidar)" % MARGEN_MAX_MIN
	_ctrl_margen.lbl_consecuencia.text = (
		"Margen alto = tu gente sale a su hora. Margen 0 = más trámites, pero quien se queda "
		+ "terminando fuera de hora se desmotiva."
	)
	lista.add_child(_ctrl_margen)
	return columna


## Una tarjeta de control grande: rótulo pequeño, VALOR GRANDE + su pista, slider (con marca opcional
## del tope ordinario) con sus extremos rotulados, y la línea de consecuencia EN VIVO.
func _crear_tarjeta_control(
	etiqueta: String, color_relleno: Color, con_marca: bool
) -> TarjetaControl:
	var tarjeta := TarjetaControl.new()
	tarjeta.custom_minimum_size.y = ALTO_MIN_TARJETA_CONTROL
	tarjeta.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tarjeta.size_flags_stretch_ratio = ALTO_TARJETA_CONTROL   # las tres piden lo mismo: se reparten
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_TARJETA
	estilo.set_corner_radius_all(int(RADIO_TARJETA_CONTROL))
	estilo.shadow_size = 9
	estilo.shadow_color = Color(0.02, 0.03, 0.06, 0.11)
	estilo.shadow_offset = Vector2(0.0, 3.0)
	estilo.content_margin_left = PAD_TARJETA_CONTROL
	estilo.content_margin_right = PAD_TARJETA_CONTROL
	estilo.content_margin_top = 18.0
	estilo.content_margin_bottom = 20.0
	tarjeta.add_theme_stylebox_override("panel", estilo)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	tarjeta.add_child(caja)

	caja.add_child(_etiqueta(etiqueta, 12, KitUIComisarioScript.MOD_COLOR_GRIS, true))

	var fila_valor := HBoxContainer.new()
	fila_valor.add_theme_constant_override("separation", 14)
	caja.add_child(fila_valor)
	tarjeta.lbl_valor = _etiqueta("", 27, KitUIComisarioScript.MOD_COLOR_TINTA, true)
	fila_valor.add_child(tarjeta.lbl_valor)
	# La pista del rango va con autowrap: así su ancho MÍNIMO es 0 y en una ventana estrecha la tarjeta
	# puede encogerse en vez de desbordar el modal (a 1616 px, como la maqueta, cabe en una línea).
	tarjeta.lbl_sub = _etiqueta("", 12, KitUIComisarioScript.MOD_COLOR_GRIS, false, true)
	tarjeta.lbl_sub.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	tarjeta.lbl_sub.size_flags_vertical = Control.SIZE_SHRINK_END
	fila_valor.add_child(tarjeta.lbl_sub)

	# Hueco elástico: empuja el slider y la consecuencia al tercio inferior de la tarjeta (la maqueta
	# los coloca por coordenada absoluta; aquí manda el contenedor).
	var hueco := Control.new()
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hueco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(hueco)

	tarjeta.slider = HSlider.new()
	KitUIComisarioScript.moderno_estilizar_slider(tarjeta.slider, color_relleno)
	var zona := Control.new()
	zona.custom_minimum_size.y = ALTO_ZONA_SLIDER + (ALTO_ZONA_MARCA if con_marca else 0.0)
	# El contenedor no recibe el ratón; el slider hijo sí (los hijos siguen recibiendo input).
	zona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(zona)
	tarjeta.slider.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tarjeta.slider.offset_bottom = ALTO_ZONA_SLIDER
	zona.add_child(tarjeta.slider)
	if con_marca:
		tarjeta.marca = MarcaTope.new()
		tarjeta.marca.fuente = KitUIComisarioScript.moderno_fuente()
		tarjeta.marca.color = KitUIComisarioScript.MOD_COLOR_GRIS
		tarjeta.marca.alto_linea = ALTO_ZONA_SLIDER
		tarjeta.marca.margen_grabber = KitUIComisarioScript.MOD_LADO_GRABBER_SLIDER / 2.0
		tarjeta.marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tarjeta.marca.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		zona.add_child(tarjeta.marca)

	var fila_extremos := HBoxContainer.new()
	caja.add_child(fila_extremos)
	tarjeta.lbl_min = _etiqueta("", 10, KitUIComisarioScript.MOD_COLOR_GRIS)
	tarjeta.lbl_min.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_extremos.add_child(tarjeta.lbl_min)
	tarjeta.lbl_max = _etiqueta("", 10, KitUIComisarioScript.MOD_COLOR_GRIS)
	tarjeta.lbl_max.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila_extremos.add_child(tarjeta.lbl_max)

	tarjeta.lbl_consecuencia = _etiqueta("", 13, KitUIComisarioScript.MOD_COLOR_GRIS, true)
	tarjeta.lbl_consecuencia.autowrap_mode = TextServer.AUTOWRAP_WORD
	tarjeta.lbl_consecuencia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(tarjeta.lbl_consecuencia)
	return tarjeta


## Columna derecha — "VENTANILLAS DE TARDE": una tarjeta por ventanilla de Doc y el coste total.
func _crear_columna_ventanillas() -> VBoxContainer:
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 4)
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.size_flags_stretch_ratio = RATIO_COLUMNA_VENTANILLAS
	columna.add_child(_etiqueta(
		"VENTANILLAS DE TARDE", 13, KitUIComisarioScript.MOD_COLOR_TINTA, true
	))
	columna.add_child(_etiqueta(
		"Solo se paga peonada por las que se quedan", 10, KitUIComisarioScript.MOD_COLOR_GRIS
	))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(scroll)
	_lista_ventanillas = VBoxContainer.new()
	_lista_ventanillas.add_theme_constant_override("separation", 16)
	_lista_ventanillas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lista_ventanillas)

	columna.add_child(_crear_tarjeta_total())
	return columna


## La tarjeta del coste total: fondo rojizo suave con la cifra grande (maqueta). Cuando hoy no hay
## peonada se apaga a gris — un cartel rojo diciendo "0 €" asusta sin motivo (decisión propia,
## anotada en `design/ux/menu-horario-spec.md`).
func _crear_tarjeta_total() -> PanelContainer:
	_tarjeta_total = PanelContainer.new()
	_tarjeta_total.custom_minimum_size.y = ALTO_TARJETA_TOTAL
	_estilo_total = StyleBoxFlat.new()
	_estilo_total.bg_color = KitUIComisarioScript.MOD_COLOR_ROJO_SUAVE
	_estilo_total.set_corner_radius_all(int(RADIO_TARJETA_PEQUENA))
	_estilo_total.content_margin_left = PAD_TARJETA_PEQUENA
	_estilo_total.content_margin_right = PAD_TARJETA_PEQUENA
	_estilo_total.content_margin_top = 12.0
	_estilo_total.content_margin_bottom = 12.0
	_tarjeta_total.add_theme_stylebox_override("panel", _estilo_total)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	_tarjeta_total.add_child(caja)
	_lbl_total_titulo = _etiqueta(
		"COSTE TOTAL DE PEONADA HOY", 11, KitUIComisarioScript.MOD_COLOR_ROJO, true
	)
	caja.add_child(_lbl_total_titulo)
	_lbl_total = _etiqueta("", 22, KitUIComisarioScript.MOD_COLOR_ROJO, true)
	caja.add_child(_lbl_total)
	return _tarjeta_total


## Recoloca el modal (y el velo) contra el tamaño REAL del viewport. Explícito porque las anclas de un
## Control bajo CanvasLayer ya han fallado en este proyecto y porque un contenedor oculto no re-mide a
## sus hijos: al pasar de oculto a visible el tamaño de antes se quedaba pegado.
func _recolocar_panel() -> void:
	if _panel == null or not visible:
		return
	var vista: Vector2 = _panel.get_viewport_rect().size
	_velo.position = Vector2.ZERO
	_velo.size = vista
	_panel.position = MARGEN_MODAL
	_panel.size = vista - MARGEN_MODAL * 2.0


# ══ Órdenes al dueño (la UI nunca calcula ni guarda: ordena y relee) ═════════════════════════════

## El jugador mueve el slider de cierre: se le ORDENA a Documentación y se repinta con lo que ella
## haya aceptado (puede haber clampado al tope autorizado — manda el dueño, no la barra).
func _al_mover_cierre(valor: float) -> void:
	if _documentacion == null:
		return
	_documentacion.fijar_hora_cierre(int(valor))
	_refrescar_cierre()
	_refrescar_margen()      # la última admisión cuelga de la hora de cierre
	_refrescar_estado()
	_repintar_costes()


## El jugador mueve el precio de la hora extra: se le ORDENA a Documentación y se relee (ella puede
## haber clampado al rango que autoriza la División).
func _al_mover_precio(valor: float) -> void:
	if _documentacion == null:
		return
	_documentacion.fijar_peonada_eur_hora(valor)
	_refrescar_precio()
	_refrescar_cierre()      # la peonada del día cambia de cifra
	_repintar_costes()


func _al_mover_margen(valor: float) -> void:
	if _documentacion == null:
		return
	_documentacion.fijar_margen_ultima_admision(int(valor))
	_refrescar_margen()
	_refrescar_estado()


## El jugador marca o desmarca una ventanilla ("se queda por la tarde"): se le ORDENA a Documentación
## y se relee todo el coste (el total cambia, y si no se queda ninguna el servicio vuelve de facto al
## horario base).
func _al_marcar_ventanilla(puesto_id: StringName, se_queda: bool) -> void:
	if _documentacion == null:
		return
	_documentacion.fijar_puesto_de_tarde(puesto_id, se_queda)
	_refrescar_cierre()
	_refrescar_margen()
	_refrescar_estado()
	_repintar_costes()


## Abrir / cerrar esa ventanilla AHORA MISMO (acción distinta de la casilla de la tarde).
## `cerrar_puesto` respeta el compromiso de servicio: si está atendiendo, Flujo deja el cierre
## PENDIENTE y la persiana baja al terminar con ese ciudadano — por eso el botón dice "Cerrará al
## acabar" en ese caso, para que el jugador no crea que su clic no ha hecho nada.
func _al_pulsar_ventanilla(puesto_id: StringName) -> void:
	if _flujo == null:
		return
	if _flujo.estado_de_puesto(puesto_id) == &"cerrado":
		_flujo.abrir_puesto(puesto_id)
	else:
		_flujo.cerrar_puesto(puesto_id)
	_refrescar_ventanillas()


## Comunicado de la División (oyente del bus): la UI **escucha**, no pregunta cada frame.
func _al_aviso_division(_evento_id: StringName, _nombre: String, _activo: bool) -> void:
	_refrescar_comunicado()
	_refrescar_cierre()   # el tope autorizado ha cambiado → el slider tiene otro recorrido


# ══ Repintado (al abrir y tras CADA orden; NUNCA por frame) ══════════════════════════════════════

## Foto completa: la llama `Main._abrir_horario` y el toggle de la tecla H (contrato con Main — el
## nombre NO cambia).
func _refrescar() -> void:
	if _documentacion == null:
		return
	_recolocar_panel()
	# Y otra vez al final del frame: al pasar de OCULTO a visible los contenedores todavía no han
	# re-medido a sus hijos (bug del "menú fantasma" ya cazado en `ModoConstruccion._recolocar_panel`).
	_recolocar_panel.call_deferred()
	_refrescar_ventanillas()
	_refrescar_precio()
	_refrescar_cierre()
	_refrescar_margen()
	_refrescar_estado()
	_refrescar_demanda()
	_refrescar_comunicado()


## Tarjeta 1: la hora de cierre, su recorrido autorizado y lo que cuesta esa decisión (en vivo).
func _refrescar_cierre() -> void:
	var doc: Node = _documentacion
	var base: int = doc.cierre_base_min
	var tope: int = doc.tope_autorizado()
	var slider: HSlider = _ctrl_cierre.slider
	slider.set_block_signals(true)          # reposicionar la barra no es una orden del jugador
	slider.min_value = base
	slider.max_value = tope
	slider.value = doc.hora_cierre_min
	slider.set_block_signals(false)
	_ctrl_cierre.lbl_valor.text = "Cierra a las %s" % _hhmm(doc.hora_cierre_min)
	_ctrl_cierre.lbl_sub.text = "(jornada base %s · máximo autorizado hoy %s)" % [
		_hhmm(base), _hhmm(tope),
	]
	_ctrl_cierre.lbl_min.text = _hhmm(base)
	_ctrl_cierre.lbl_max.text = _hhmm(tope)

	# La marca del tope ORDINARIO: solo cuando un comunicado ha ampliado el recorrido más allá.
	if tope > doc.slider_max_min and tope > base:
		_ctrl_cierre.marca.fraccion = float(doc.slider_max_min - base) / float(tope - base)
		_ctrl_cierre.marca.texto = "tope ordinario %s" % _hhmm(doc.slider_max_min)
	else:
		_ctrl_cierre.marca.fraccion = -1.0
		_ctrl_cierre.marca.texto = ""
	_ctrl_cierre.marca.queue_redraw()

	_ctrl_cierre.lbl_consecuencia.text = _texto_peonada()
	_ctrl_cierre.lbl_consecuencia.add_theme_color_override("font_color", (
		KitUIComisarioScript.MOD_COLOR_GRIS if doc.horas_extra() <= 0.0
		else KitUIComisarioScript.MOD_COLOR_ROJO
	))


## La consecuencia de alargar, con las cifras de Documentación: "+2,5 h extra × 1 agente → PEONADA
## 55 €/día" (singular sin "(s)", coma decimal castellana y el dinero por el formato único del kit).
func _texto_peonada() -> String:
	var doc: Node = _documentacion
	var horas: float = doc.horas_extra()
	if horas <= 0.0:
		return "Sin horas extra: la jornada base no cuesta peonada."
	var agentes: int = doc.num_agentes_doc()
	return "+%s h extra × %d agente%s  →  PEONADA %s/día" % [
		_num(horas), agentes, "" if agentes == 1 else "s",
		KitUIComisarioScript.formato_euros(doc.coste_peonada_estimado()),
	]


## Tarjeta 2: el precio de la hora extra y lo que compra — MENOS cansancio. Se dice en el sentido real
## de la mecánica (`personal.gd`): pagar MEJOR cansa MENOS; al tope, la hora extra cansa como una
## normal. (La primera redacción del andamio se leía justo al revés.)
func _refrescar_precio() -> void:
	var doc: Node = _documentacion
	var slider: HSlider = _ctrl_precio.slider
	slider.set_block_signals(true)
	slider.min_value = doc.peonada_eur_hora_min
	slider.max_value = doc.peonada_eur_hora_max
	slider.value = doc.peonada_eur_hora
	slider.set_block_signals(false)
	_ctrl_precio.lbl_valor.text = "%s/hora" % KitUIComisarioScript.formato_euros(doc.peonada_eur_hora)
	_ctrl_precio.lbl_sub.text = "(convenio %s · tope %s)" % [
		KitUIComisarioScript.formato_euros(doc.peonada_eur_hora_min),
		KitUIComisarioScript.formato_euros(doc.peonada_eur_hora_max),
	]
	_ctrl_precio.lbl_min.text = KitUIComisarioScript.formato_euros(doc.peonada_eur_hora_min)
	_ctrl_precio.lbl_max.text = KitUIComisarioScript.formato_euros(doc.peonada_eur_hora_max)
	var generosidad: float = doc.generosidad_peonada()
	_ctrl_precio.lbl_consecuencia.text = _texto_efecto_precio(generosidad)
	_ctrl_precio.lbl_consecuencia.add_theme_color_override("font_color", (
		KitUIComisarioScript.MOD_COLOR_GRIS if generosidad < GENEROSIDAD_GENEROSA
		else KitUIComisarioScript.MOD_COLOR_VERDE
	))


## El efecto del precio en llano ("cansa un 27 % más que una normal"), con el tope como referencia de
## a dónde se puede llegar. El recargo es la fórmula de Personal, no una invención de la UI.
func _texto_efecto_precio(generosidad: float) -> String:
	var recargo: float = lerpf(RECARGO_CANSANCIO_CONVENIO, RECARGO_CANSANCIO_TOPE, generosidad)
	if recargo <= 1.01:
		return "A este precio la hora extra cansa como una normal"
	return (
		"A este precio la hora extra cansa un %d %% más que una normal · al tope (%s) cansaría como "
		+ "una normal"
	) % [
		roundi((recargo - 1.0) * 100.0),
		KitUIComisarioScript.formato_euros(_documentacion.peonada_eur_hora_max),
	]


## Tarjeta 3: la última admisión (el texto de ayuda es fijo — se pone al construir la tarjeta).
func _refrescar_margen() -> void:
	var doc: Node = _documentacion
	var slider: HSlider = _ctrl_margen.slider
	slider.set_block_signals(true)
	slider.value = doc.margen_ultima_admision_min
	slider.set_block_signals(false)
	_ctrl_margen.lbl_valor.text = _hhmm(doc.hora_ultima_admision())
	_ctrl_margen.lbl_sub.text = (
		"se da número hasta el cierre" if doc.margen_ultima_admision_min == 0
		else "se deja de dar número %d min antes de cerrar" % doc.margen_ultima_admision_min
	)


## Estado del servicio AHORA: punto de color + TEXTO (el color solo refuerza — respaldo daltónico).
func _refrescar_estado() -> void:
	var doc: Node = _documentacion
	var minuto: float = _tiempo.minutos_juego if _tiempo != null else 0.0
	match doc.estado_servicio(minuto):
		doc.ESTADO_ABIERTO:
			_lbl_estado.text = "Ahora: ABIERTA — dando número (hasta las %s)" % _hhmm(
				doc.hora_ultima_admision()
			)
			_fijar_color_punto(_punto_estado, KitUIComisarioScript.MOD_COLOR_VERDE)
		doc.ESTADO_CERRANDO:
			_lbl_estado.text = "Ahora: CERRANDO — ya no se da número; se termina a los admitidos"
			_fijar_color_punto(_punto_estado, KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO)
		_:
			_lbl_estado.text = "Ahora: CERRADA — abre a las %s" % _hhmm(doc.apertura_base_min)
			_fijar_color_punto(_punto_estado, KitUIComisarioScript.MOD_COLOR_GRIS)


## El semáforo de demanda (DO12): la brújula de la peonada, con punto + texto + consejo.
func _refrescar_demanda() -> void:
	var nivel: StringName = _documentacion.nivel_demanda()
	var consejo: String = "ampliar suele salir a pérdidas" if nivel == &"BAJA" else (
		"ajustado: depende de la cola que te quede al cierre" if nivel == &"MEDIA"
		else "hay cola de sobra: alargar suele compensar"
	)
	_lbl_demanda.text = "Demanda %s — %s" % [String(nivel), consejo]
	_fijar_color_punto(_punto_demanda, _color_demanda(nivel))


## Color de refuerzo del nivel de demanda (nunca la única señal: al lado va siempre el texto).
func _color_demanda(nivel: StringName) -> Color:
	match nivel:
		&"BAJA":
			return KitUIComisarioScript.MOD_COLOR_VERDE
		&"ALTA":
			return KitUIComisarioScript.MOD_COLOR_ROJO
		_:
			return KitUIComisarioScript.MOD_COLOR_AMBAR


## El banner del comunicado: SOLO si hay evento activo, con su texto real de catálogo.
func _refrescar_comunicado() -> void:
	var evento: Resource = _documentacion.evento_activo()
	if evento == null:
		_banner.visible = false
		return
	_banner.visible = true
	_lbl_banner_titulo.text = "COMUNICADO DE LA DIVISIÓN · %s" % evento.nombre
	# El cuerpo es la descripción REAL del catálogo + los dos topes en cifras. No se repite la
	# autorización con otras palabras: el `.tres` de vacaciones ya la cuenta, y duplicarla dejaba la
	# frase diciendo dos veces lo mismo (cazado al montar la sonda visual).
	_lbl_banner_cuerpo.text = "%s Tope ordinario %s → autorizado hoy %s." % [
		evento.descripcion, _hhmm(_documentacion.slider_max_min), _hhmm(evento.cierre_max_min),
	]


# ── Columna de ventanillas ──────────────────────────────────────────────────────────────────────
## Reconstruye la lista de ventanillas de Documentación (una tarjeta por puesto). Solo al abrir el
## panel, al inyectar Flujo o tras abrir/cerrar una ventanilla: NUNCA mientras se arrastra un slider.
func _refrescar_ventanillas() -> void:
	if _lista_ventanillas == null or _documentacion == null:
		return
	# `remove_child` ANTES de `queue_free`: la liberación es diferida, así que si esta función se llama
	# dos veces en el mismo frame (Main inyecta Flujo y acto seguido abre el panel) los hijos viejos
	# todavía cuelgan del contenedor y la lista sale duplicada (cazado en el test de estructura).
	for hijo: Node in _lista_ventanillas.get_children():
		_lista_ventanillas.remove_child(hijo)
		hijo.queue_free()
	_filas_ventanilla.clear()
	var puestos: Array[StringName] = _documentacion.puestos_de_doc()
	if puestos.is_empty():
		_lista_ventanillas.add_child(_etiqueta(
			"No hay ventanillas de Documentación construidas — constrúyelas en el modo Construcción (B).",
			11, KitUIComisarioScript.MOD_COLOR_GRIS, false, true
		))
		_refrescar_total()
		return
	var nombres: Array[String] = _nombres_visibles(puestos)
	for i: int in puestos.size():
		_lista_ventanillas.add_child(_crear_tarjeta_ventanilla(puestos[i], nombres[i]))
	_refrescar_total()


## El nombre VISIBLE de cada ventanilla ("DNI 1", "TIE 1"), por el helper único del Tablón de
## Destinos: prefijo por TIPO de puesto + ordinal dentro de su propio prefijo, en el orden estable de
## registro de Personal (el mismo que recorre el Tablón).
func _nombres_visibles(puestos: Array[StringName]) -> Array[String]:
	var nombres: Array[String] = []
	var cuenta: Dictionary[String, int] = {}
	for puesto_id: StringName in puestos:
		var tipo: StringName = _personal.tipo_de_puesto(puesto_id) if _personal != null else &""
		var prefijo: String = PanelPersonalScript.PREFIJO_POR_TIPO_PUESTO.get(tipo, "")
		var clave: String = prefijo if prefijo != "" else "otros"
		cuenta[clave] = int(cuenta.get(clave, 0)) + 1
		nombres.append(
			PanelPersonalScript.nombre_visible_de_puesto(puesto_id, tipo, cuenta[clave])
		)
	return nombres


## Una tarjeta de ventanilla: casilla "se queda por la tarde" + nombre + quién la opera + el botón
## manual Abrir/Cerrar + su línea de coste. Son DOS acciones REALES distintas (horario vs persiana).
func _crear_tarjeta_ventanilla(puesto_id: StringName, nombre_visible: String) -> PanelContainer:
	var tarjeta: PanelContainer = KitUIComisarioScript.moderno_tarjeta(false, RADIO_TARJETA_PEQUENA)
	tarjeta.custom_minimum_size.y = ALTO_TARJETA_VENTANILLA
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", int(PAD_TARJETA_PEQUENA))
	margen.add_theme_constant_override("margin_right", int(PAD_TARJETA_PEQUENA))
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_bottom", 12)
	tarjeta.add_child(margen)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	margen.add_child(caja)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	caja.add_child(fila)
	var casilla: Button = KitUIComisarioScript.moderno_casilla(
		_documentacion.puesto_de_tarde(puesto_id), LADO_CASILLA
	)
	casilla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	casilla.tooltip_text = "Se queda por la tarde (cobra peonada por las horas extra)"
	casilla.toggled.connect(
		func(activa: bool) -> void: _al_marcar_ventanilla(puesto_id, activa)
	)
	fila.add_child(casilla)

	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 0)
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(textos)
	textos.add_child(_etiqueta(nombre_visible, 15, KitUIComisarioScript.MOD_COLOR_TINTA, true))
	textos.add_child(_etiqueta(
		_texto_operador(puesto_id), 10, KitUIComisarioScript.MOD_COLOR_GRIS
	))

	if _flujo != null:
		fila.add_child(_boton_ventanilla(puesto_id))

	var detalle: Dictionary = _detalle_ventanilla(puesto_id)
	var lbl_detalle: Label = _etiqueta(
		String(detalle["texto"]), 11, detalle["color"], true, true
	)
	lbl_detalle.size_flags_vertical = Control.SIZE_SHRINK_END
	caja.add_child(lbl_detalle)
	_filas_ventanilla.append({"puesto_id": puesto_id, "lbl_detalle": lbl_detalle})
	return tarjeta


## "Operada por Elena Ortiz" — o el aviso de que ahí no hay nadie (una ventanilla sin agente no
## atiende ni cobra peonada, y eso hay que verlo antes de dejarla de tarde).
func _texto_operador(puesto_id: StringName) -> String:
	if _personal == null:
		return ""
	var agente: RefCounted = _personal.agente_de(puesto_id)
	if agente == null:
		return "Sin agente asignado"
	return "Operada por %s" % agente.nombre


## El botón manual de la persiana: "Abrir" si está cerrada, "Cerrar" si está abierta, y "Cerrará al
## acabar" DESHABILITADO si Flujo ya tiene el cierre pendiente (está terminando con un ciudadano).
func _boton_ventanilla(puesto_id: StringName) -> Button:
	var cerrada: bool = _flujo.estado_de_puesto(puesto_id) == &"cerrado"
	var pendiente: bool = not cerrada and _flujo.cierre_pendiente_de(puesto_id)
	var texto: String = "Abrir" if cerrada else ("Cerrará al acabar" if pendiente else "Cerrar")
	var estilo: StringName = KitUIComisarioScript.MOD_BOTON_SECUNDARIO
	if pendiente:
		estilo = KitUIComisarioScript.MOD_BOTON_DESHABILITADO
	elif not cerrada:
		estilo = KitUIComisarioScript.MOD_BOTON_PELIGRO
	var boton: Button = KitUIComisarioScript.moderno_boton_pastilla(texto, estilo, 26.0, false, 11)
	boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boton.tooltip_text = (
		"Terminando con quien tiene delante; la persiana baja al acabar" if pendiente
		else ("Abre la ventanilla ahora mismo" if cerrada else "Cierra la ventanilla ahora mismo")
	)
	if not pendiente:
		boton.pressed.connect(func() -> void: _al_pulsar_ventanilla(puesto_id))
	return boton


## Lo que le pasa HOY a esa ventanilla: su coste de peonada, o por qué no cuesta.
## Devuelve `{"texto": String, "color": Color}` — el color es refuerzo del texto, nunca su sustituto.
func _detalle_ventanilla(puesto_id: StringName) -> Dictionary:
	if _personal != null and not _personal.puesto_dotado(puesto_id):
		return {
			"texto": "sin agente asignado — no atiende ni cobra peonada",
			"color": KitUIComisarioScript.MOD_COLOR_GRIS,
		}
	if not _documentacion.puesto_de_tarde(puesto_id):
		return {
			"texto": "cierra a las %s" % _hhmm(_documentacion.cierre_base_min),
			"color": KitUIComisarioScript.MOD_COLOR_GRIS,
		}
	if _documentacion.horas_extra() <= 0.0:
		return {"texto": "sin horas extra", "color": KitUIComisarioScript.MOD_COLOR_GRIS}
	return {
		"texto": "%s/día de peonada" % KitUIComisarioScript.formato_euros(
			_documentacion.coste_peonada_por_ventanilla()
		),
		"color": KitUIComisarioScript.MOD_COLOR_ROJO,
	}


## Repinta SOLO las cifras de coste (líneas de ventanilla + total): lo que cambia al mover un slider.
## No toca los nodos interactivos, así el arrastre del jugador no se interrumpe.
func _repintar_costes() -> void:
	for fila: Dictionary in _filas_ventanilla:
		var lbl: Label = fila["lbl_detalle"]
		if not is_instance_valid(lbl):
			continue
		var detalle: Dictionary = _detalle_ventanilla(fila["puesto_id"])
		lbl.text = String(detalle["texto"])
		lbl.add_theme_color_override("font_color", detalle["color"])
	_refrescar_total()


## El coste total de peonada de hoy, tal y como lo calcula Documentación (nunca sumado aquí).
func _refrescar_total() -> void:
	var coste: float = _documentacion.coste_peonada_estimado()
	_lbl_total.text = "%s/día" % KitUIComisarioScript.formato_euros(coste)
	var hay_gasto: bool = coste > 0.0
	_estilo_total.bg_color = (
		KitUIComisarioScript.MOD_COLOR_ROJO_SUAVE if hay_gasto
		else KitUIComisarioScript.MOD_COLOR_GRIS_MUY_SUAVE
	)
	var color: Color = (
		KitUIComisarioScript.MOD_COLOR_ROJO if hay_gasto else KitUIComisarioScript.MOD_COLOR_GRIS
	)
	_lbl_total_titulo.add_theme_color_override("font_color", color)
	_lbl_total.add_theme_color_override("font_color", color)


# ══ Utilidades de construcción y formato ═════════════════════════════════════════════════════════

## Un Label del lenguaje moderno (tamaño, color y peso explícitos; la fuente la hereda del Theme).
## `con_autowrap` añade el envoltorio por palabras Y el `EXPAND_FILL` que necesita para tener ancho
## (sin él un Label con autowrap sale a UNA PALABRA POR LÍNEA — gotcha cazado en el Tablón).
func _etiqueta(
	texto: String, tam: int, color: Color, negrita: bool = false, con_autowrap: bool = false
) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", tam)
	lbl.add_theme_color_override("font_color", color)
	if negrita:
		lbl.add_theme_font_override("font", KitUIComisarioScript.moderno_fuente(true))
	if con_autowrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


## Línea divisoria de 1 px del color de raíl del kit (la maqueta separa cabecera y cuerpo).
func _linea() -> Panel:
	var linea := Panel.new()
	linea.custom_minimum_size.y = 1.0
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_LINEA
	linea.add_theme_stylebox_override("panel", estilo)
	return linea


## Fila "punto de color + texto" de la cabecera: el hijo 0 es el punto (`Panel`) y el 1 la etiqueta.
## SIEMPRE los dos (respaldo daltónico, regla transversal del proyecto).
func _crear_fila_punto(tam: int, radio: float) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var punto := Panel.new()
	punto.custom_minimum_size = Vector2(radio * 2.0, radio * 2.0)
	punto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_GRIS
	estilo.set_corner_radius_all(int(radio))
	punto.add_theme_stylebox_override("panel", estilo)
	fila.add_child(punto)
	fila.add_child(_etiqueta("", tam, KitUIComisarioScript.MOD_COLOR_TINTA, true))
	return fila


## Recolorea un punto de estado en caliente (su StyleBox es propio, no compartido).
func _fijar_color_punto(punto: Panel, color: Color) -> void:
	var estilo: StyleBoxFlat = punto.get_theme_stylebox("panel") as StyleBoxFlat
	if estilo != null:
		estilo.bg_color = color


## Minutos del día → "HH:MM" (el reloj del juego tiene su propio helper; aquí se recibe un int puro).
func _hhmm(minuto_del_dia: int) -> String:
	return "%02d:%02d" % [int(minuto_del_dia / 60.0) % 24, minuto_del_dia % 60]


## Número corto EN CASTELLANO: sin decimales si es redondo, con uno y COMA si no ("2,5"). El dinero no
## pasa por aquí — va por `KitUIComisario.formato_euros` (fuente única, con su punto de millares).
func _num(valor: float) -> String:
	if is_equal_approx(valor, roundf(valor)):
		return "%d" % int(roundf(valor))
	return ("%.1f" % valor).replace(".", ",")


# ══ Clases internas ══════════════════════════════════════════════════════════════════════════════
## La marca del TOPE ORDINARIO sobre el raíl del slider de cierre: una línea vertical + su rótulo
## debajo (la maqueta). Se dibuja a mano porque un `Slider` no tiene "marca con etiqueta" nativa (sus
## `ticks` son todos iguales y sin texto), y porque el dato que cuenta —"hasta aquí llegaba el tope
## antes del comunicado"— es una explicación, no una parada del control.
## `fraccion < 0` = no hay marca (el recorrido no está ampliado).
class MarcaTope extends Control:
	var fraccion: float = -1.0
	var texto: String = ""
	var color: Color = Color(0.478, 0.533, 0.612, 1.0)
	## Alto de la línea vertical = alto de la banda del slider.
	var alto_linea: float = 22.0
	## Media anchura del tirador: el recorrido REAL del grabber está metido esa cantidad por cada lado,
	## así la marca cae justo donde caería el tirador con ese valor.
	var margen_grabber: float = 11.0
	var fuente: Font = null
	## Tamaño del rótulo. La maqueta usa 9 px; en pantalla se sube a 10 para que se lea sin forzar la
	## vista (única desviación de medida de esta pantalla, anotada en la spec).
	const TAM_ROTULO := 10
	## Ancho de la caja de texto centrada bajo la marca.
	const ANCHO_ROTULO := 180.0

	func _draw() -> void:
		if fraccion < 0.0:
			return
		var util: float = maxf(size.x - margen_grabber * 2.0, 1.0)
		var x: float = margen_grabber + util * clampf(fraccion, 0.0, 1.0)
		draw_line(Vector2(x, 0.0), Vector2(x, alto_linea), color, 2.0)
		if fuente == null or texto == "":
			return
		draw_string(
			fuente, Vector2(x - ANCHO_ROTULO / 2.0, alto_linea + TAM_ROTULO + 2.0), texto,
			HORIZONTAL_ALIGNMENT_CENTER, ANCHO_ROTULO, TAM_ROTULO, color
		)


## Una tarjeta de control grande de la columna izquierda. Es una clase (y no un diccionario de nodos)
## para que sus piezas estén TIPADAS: quien repinta accede a `lbl_valor`/`slider`/… sin castings.
class TarjetaControl extends PanelContainer:
	var lbl_valor: Label
	var lbl_sub: Label
	var slider: HSlider
	## Marca del tope ordinario; `null` en las tarjetas que no la piden.
	var marca: MarcaTope
	var lbl_min: Label
	var lbl_max: Label
	var lbl_consecuencia: Label
