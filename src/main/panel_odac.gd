class_name PanelODAC extends CanvasLayer
## PanelODAC — la pantalla de la oficina de denuncias (tecla **O**, o "Dedicación de ODAC" en el menú
## contextual de una sala de ODAC).
##
## Es la palanca de gestión de ODAC #9 (OD4/OD5): decidir **a qué se dedica cada ventanilla** de
## denuncias. Reglas del proyecto (control-manifest, Presentation): la UI **lee** el estado y
## **ordena** por la API pública de ODAC — nunca muta el modelo ni toca Flujo directamente (ADR-0001).
##
## ── LO QUE ESTA PANTALLA TIENE QUE CONSEGUIR ──────────────────────────────────────────────────
## Que el jugador entienda, sin leer un manual, la disyuntiva de ODAC:
##
##   Las urgentes SIEMPRE pasan delante. Si todas tus ventanillas atienden de todo y llega una
##   racha de urgencias, las administrativas se quedan esperando para siempre. Dedicar una
##   ventanilla a "solo normales" es lo que hace que avancen.
##
## ── QUÉ APORTA LA VISTA DE CONJUNTO (y la ficha individual no puede dar) ──────────────────────
## La ficha de una ventanilla (`panel_ventanilla.gd::_bloque_odac`) solo sabe de SÍ MISMA. Esta
## pantalla añade las tres cosas que son propiedades del CONJUNTO:
##   1. **Reparto de la cola por prioridad** — agregando `Flujo.personas_de_cola(&"ODAC")` con
##      `ODAC.es_prioritaria(persona.tramite_id())`.
##   2. **Resumen de dedicación** — cuántas ventanillas hay en cada modo, de un vistazo.
##   3. **El aviso de cobertura** (`ODAC.denuncias_sin_cubrir`) — la válvula anti-inanición (OD5):
##      una denuncia está sin cubrir si NINGUNA ventanilla la coge.
##
## ── RESKIN F4 (2026-08-18) ────────────────────────────────────────────────────────────────────
## Sustituye por dentro al andamio de listas por la maqueta APROBADA
## `design/ux/maquetas-menu-2026-08/maqueta_odac.png` (script vinculante: `maqueta_odac.py`). Mismo
## lenguaje moderno que las hermanas (`KitUIComisario`): velo + tarjeta clara, esquinas redondeadas,
## un solo acento azul, cero emojis en Labels (el triángulo de alerta lo DIBUJA el kit).
##
## El modal es **COMPACTO y CENTRADO**: el ancho es fijo contra los bordes (como las hermanas) pero
## el ALTO se autoajusta al contenido real — esta pantalla es más modesta (2 ventanillas) y a
## pantalla completa dejaría medio modal en blanco. El alto se mide en DOS PASADAS (ver
## `_recolocar_panel`), el mismo patrón ya probado en `ModalComisario`.
##
## El contrato con `Main` NO cambia: misma clase, mismo archivo, `configurar(odac, flujo, personal)`
## y la tecla O sigue abriendo y cerrando. Se AÑADE `abrir()` para el menú contextual de la sala.
##
## Story: F4 reskin de oficio · maqueta aprobada 2026-08-18 · ADR-0001 · spec
## `design/ux/menu-odac-spec.md`

## `class_name` no resuelve en headless frío (gotcha del proyecto) → SIEMPRE preload.
const KitUIComisarioScript := preload("res://src/ui/kit_ui_comisario.gd")
const PanelPersonalScript := preload("res://src/main/panel_personal.gd")

# ── Geometría (todos los números salen de `maqueta_odac.py`; ninguno suelto sin comentario) ──────
## Margen horizontal del modal contra el borde de la ventana (maqueta: `MX0 = 48`).
const MARGEN_HORIZONTAL := 48.0
## Margen vertical MÍNIMO cuando el contenido no cabe centrado (maqueta: `max(40, ...)`).
const MARGEN_VERTICAL_MIN := 40.0
## Aire interior del modal (maqueta: `pad = 32`).
const PADDING_MODAL := 32.0
## Aire interior de una tarjeta de ventanilla (maqueta: `pad = 22` en `tarjeta_odac`).
const PADDING_TARJETA := 22.0
## Alto de la pastilla segmentada de modos (maqueta: `seg_alto = 40`).
const ALTO_SEGMENTADO := 40.0
## Separación entre las dos columnas de ventanillas (maqueta: `gap_col = 24`).
const SEPARACION_COLUMNAS := 24
## Velo oscuro sobre el juego (maqueta: 10,14,24 con alfa 205/255 — el mismo de `PanelPersonal`).
const COLOR_VELO := Color(0.039, 0.055, 0.094, 0.804)
## Diámetro del punto de la línea de cola (maqueta: `radio = 6` → 12 px) y del de estado (`radio 5`).
const LADO_PUNTO_COLA := 12.0
const LADO_PUNTO_ESTADO := 10.0
## Lado del triángulo de alerta del banner de cobertura (maqueta: `r = 10` sobre 20 px de lienzo).
const LADO_GLIFO_ALERTA := 22.0
## Alto de un chip de la fila de dedicación y de un chip de tipo de denuncia (maqueta: 28 y 24).
const ALTO_CHIP_RESUMEN := 28.0
const ALTO_CHIP_TIPO := 24.0
## Lado de la casilla marcada que acompaña a cada tipo elegido "a medida" (maqueta: 15 sobre 22).
const LADO_CASILLA_CHIP := 15.0
## A partir de cuántas ventanillas se apilan en dos columnas (maqueta: 2 lado a lado).
const COLUMNAS_VENTANILLAS := 2

## El servicio que gobierna esta pantalla (el mismo nombre que usan Datos, Flujo y ODAC).
const SERVICIO := &"ODAC"

# ── Refs a los sistemas Core (las inyecta Main; la UI solo lee y ordena — ADR-0001) ──────────────
var _odac: Node = null
var _flujo: Node = null
var _personal: Node = null

# ── Nodos de UI (se construyen en `_ready`; el panel nace oculto) ────────────────────────────────
var _velo: ColorRect
var _panel: PanelContainer
var _lbl_urgentes: Label
var _lbl_administrativas: Label
var _chips_dedicacion: HBoxContainer
var _banner: PanelContainer
var _lbl_banner: Label
var _chips_sin_cubrir: HFlowContainer
var _rejilla: GridContainer
var _lbl_nota: Label


## Inyección de dependencias (la llama Main antes de `add_child`).
func configurar(odac: Node, flujo: Node, personal: Node) -> void:
	_odac = odac
	_flujo = flujo
	_personal = personal


func _ready() -> void:
	# Por ENCIMA de la brújula de depuración (layer 10) y a la misma altura que las hermanas de
	# gestión (Personal/Horario van en 12). El modal de insolvencia, que PARA el juego, va en 13.
	layer = 12
	_crear_ui()
	visible = false
	if _odac != null:
		# Al cambiar un modo se repinta sola: sin esto, cambiar una ventanilla no actualizaría el
		# banner de denuncias sin cubrir hasta cerrar y abrir el panel.
		_odac.modo_cambiado.connect(func(_p: StringName, _m: int) -> void: _reconstruir())


# ── Entrada (tecla O; el menú de sala usa `abrir()`) ─────────────────────────────────────────────
## Tecla O alterna la visibilidad. Al ABRIR reconstruye (foto fresca del estado).
func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey and evento.pressed and not (evento as InputEventKey).echo):
		return
	if (evento as InputEventKey).keycode == KEY_O:
		if visible:
			_cerrar()
		else:
			abrir()
		get_viewport().set_input_as_handled()


## Abre la pantalla con una foto fresca del estado. Es el camino que usa el menú contextual de una
## sala de ODAC (`Main._al_elegir_del_menu_sala`) — el mismo que la tecla O.
func abrir() -> void:
	visible = true
	_reconstruir()


func _cerrar() -> void:
	visible = false


# ══ Construcción de la UI (por código — el proyecto no usa .tscn salvo Main) ═════════════════════
func _crear_ui() -> void:
	# EL VELO: bloquea el juego de debajo (MOUSE_FILTER_STOP) pero NO se come los clics del panel —
	# el modal es un HERMANO POSTERIOR, así que recibe el input antes que el velo.
	_velo = ColorRect.new()
	_velo.name = "Velo"
	_velo.color = COLOR_VELO
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_velo)

	_panel = PanelContainer.new()
	_panel.name = "TarjetaModal"
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_PANEL
	estilo.set_corner_radius_all(22)   # maqueta: `rounded_rectangle(..., 22)` del marco del modal
	estilo.shadow_size = 14
	estilo.shadow_color = Color(0.039, 0.055, 0.094, 0.32)
	estilo.shadow_offset = Vector2(0.0, 8.0)
	estilo.content_margin_left = PADDING_MODAL
	estilo.content_margin_right = PADDING_MODAL
	estilo.content_margin_top = PADDING_MODAL
	estilo.content_margin_bottom = PADDING_MODAL
	_panel.add_theme_stylebox_override("panel", estilo)
	# La tipografía moderna baja por herencia a TODOS los hijos: un solo `theme` en la raíz en vez de
	# un override por Label (sin él cada Label hereda la pixelada en mayúsculas del tema global).
	_panel.theme = KitUIComisarioScript.moderno_tema()
	add_child(_panel)
	# Las anclas de un Control bajo CanvasLayer no son fiables en este proyecto (gotcha): tamaño y
	# posición se fijan a mano al mostrar y en cada resize de la ventana.
	get_viewport().size_changed.connect(_recolocar_panel)

	var caja := VBoxContainer.new()
	caja.name = "Caja"
	caja.add_theme_constant_override("separation", 10)
	_panel.add_child(caja)

	caja.add_child(_crear_cabecera())
	caja.add_child(_crear_bloque_cola())
	caja.add_child(_crear_bloque_dedicacion())
	_banner = _crear_banner_cobertura()
	caja.add_child(_banner)

	caja.add_child(_rotulo("VENTANILLAS ODAC", 13, KitUIComisarioScript.MOD_COLOR_TINTA))
	_rejilla = GridContainer.new()
	_rejilla.name = "Ventanillas"
	_rejilla.columns = COLUMNAS_VENTANILLAS
	_rejilla.add_theme_constant_override("h_separation", SEPARACION_COLUMNAS)
	_rejilla.add_theme_constant_override("v_separation", SEPARACION_COLUMNAS)
	caja.add_child(_rejilla)

	_lbl_nota = _rotulo("", 10, KitUIComisarioScript.MOD_COLOR_GRIS, false)
	_lbl_nota.name = "NotaFicha"
	_lbl_nota.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Gotcha del proyecto: autowrap SIN ancho disponible mide a una sola línea (o a una palabra por
	# línea dentro de un contenedor) → hay que pedir el ancho EXPLÍCITAMENTE con EXPAND_FILL.
	_lbl_nota.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(_lbl_nota)


## Cabecera: título + subtítulo a la izquierda, "Cerrar (O)" a la derecha (maqueta).
func _crear_cabecera() -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.name = "Cabecera"
	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 2)
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(textos)
	textos.add_child(_rotulo("ODAC", 24, KitUIComisarioScript.MOD_COLOR_TINTA))
	textos.add_child(_rotulo(
		"Oficina de Denuncias — decide a qué se dedica cada ventanilla",
		12, KitUIComisarioScript.MOD_COLOR_GRIS, false
	))
	var cerrar: Button = KitUIComisarioScript.moderno_boton_pastilla(
		"Cerrar (O)", KitUIComisarioScript.MOD_BOTON_SECUNDARIO, 30.0, false, 12
	)
	cerrar.name = "BotonCerrar"
	cerrar.focus_mode = Control.FOCUS_NONE   # gotcha: si coge foco, el Espacio deja de pausar
	cerrar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cerrar.pressed.connect(_cerrar)
	fila.add_child(cerrar)
	return fila


## "EN COLA · ODAC" con el reparto por prioridad — el dato agregado que ninguna ficha puede dar.
func _crear_bloque_cola() -> VBoxContainer:
	var caja := VBoxContainer.new()
	caja.name = "BloqueCola"
	caja.add_theme_constant_override("separation", 6)
	caja.add_child(_rotulo("EN COLA · ODAC", 10, KitUIComisarioScript.MOD_COLOR_GRIS))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 34)
	caja.add_child(fila)
	var urgentes: HBoxContainer = _punto_con_texto(KitUIComisarioScript.MOD_COLOR_AMBAR, 14)
	# Columna fija para que la segunda cifra no baile al cambiar la primera (maqueta: x + 260).
	urgentes.custom_minimum_size.x = 226.0
	_lbl_urgentes = urgentes.get_node("Texto")
	fila.add_child(urgentes)
	var administrativas: HBoxContainer = _punto_con_texto(KitUIComisarioScript.MOD_COLOR_GRIS, 14)
	_lbl_administrativas = administrativas.get_node("Texto")
	fila.add_child(administrativas)
	return caja


## "DEDICACIÓN DE LA OFICINA": un chip por modo con cuántas ventanillas están en él.
func _crear_bloque_dedicacion() -> VBoxContainer:
	var caja := VBoxContainer.new()
	caja.name = "BloqueDedicacion"
	caja.add_theme_constant_override("separation", 6)
	caja.add_child(_rotulo("DEDICACIÓN DE LA OFICINA", 10, KitUIComisarioScript.MOD_COLOR_GRIS))
	_chips_dedicacion = HBoxContainer.new()
	_chips_dedicacion.name = "ChipsDedicacion"
	_chips_dedicacion.add_theme_constant_override("separation", 10)
	caja.add_child(_chips_dedicacion)
	return caja


## El banner rojizo de la válvula anti-inanición (OD5). Nace OCULTO: solo aparece si de verdad hay
## tipos huérfanos. El triángulo va DIBUJADO (forma, no solo color — accesibilidad transversal).
func _crear_banner_cobertura() -> PanelContainer:
	var banner: PanelContainer = KitUIComisarioScript.moderno_tarjeta(
		false, 14.0, KitUIComisarioScript.MOD_COLOR_ROJO_SUAVE
	)
	banner.name = "BannerCobertura"
	var estilo: StyleBoxFlat = banner.get_theme_stylebox("panel") as StyleBoxFlat
	if estilo != null:
		estilo.shadow_size = 0
		# La barra roja del borde izquierdo de la maqueta, como borde del propio StyleBox.
		estilo.border_width_left = 4
		estilo.border_color = KitUIComisarioScript.MOD_COLOR_ROJO
		estilo.content_margin_left = 18.0
		estilo.content_margin_right = 18.0
		estilo.content_margin_top = 12.0
		estilo.content_margin_bottom = 12.0
	banner.visible = false

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	banner.add_child(caja)

	var titulo := HBoxContainer.new()
	titulo.add_theme_constant_override("separation", 10)
	caja.add_child(titulo)
	var glifo: Control = KitUIComisarioScript.moderno_glifo(
		KitUIComisarioScript.GlifoModerno.Tipo.TRIANGULO_ALERTA,
		KitUIComisarioScript.MOD_COLOR_ROJO, LADO_GLIFO_ALERTA
	)
	glifo.name = "GlifoAlerta"
	glifo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titulo.add_child(glifo)
	_lbl_banner = _rotulo("", 12, KitUIComisarioScript.MOD_COLOR_ROJO)
	_lbl_banner.name = "TituloBanner"
	_lbl_banner.autowrap_mode = TextServer.AUTOWRAP_WORD
	_lbl_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.add_child(_lbl_banner)

	_chips_sin_cubrir = HFlowContainer.new()
	_chips_sin_cubrir.name = "ChipsSinCubrir"
	_chips_sin_cubrir.add_theme_constant_override("h_separation", 6)
	_chips_sin_cubrir.add_theme_constant_override("v_separation", 6)
	caja.add_child(_chips_sin_cubrir)
	return banner


## Recoloca el modal contra el tamaño REAL del viewport. **EN DOS PASADAS**: el mínimo de un Label
## con autowrap depende del ancho YA repartido por el contenedor — medir el alto en el mismo frame en
## que se fija el ancho infla el alto (texto medido a ancho 0) y el modal sale como una columna
## cortada (bug cazado en `ModalComisario._recolocar_panel`, 2026-08-18: se CALCA ese patrón).
func _recolocar_panel() -> void:
	if _panel == null or not visible:
		return
	var vista: Vector2 = _panel.get_viewport_rect().size
	_velo.position = Vector2.ZERO
	_velo.size = vista
	var ancho: float = maxf(320.0, vista.x - MARGEN_HORIZONTAL * 2.0)
	# 1ª pasada: fijar el ANCHO (el alto de esta pasada es provisional y acotado a la vista).
	var alto_provisional: float = minf(_panel.get_combined_minimum_size().y, vista.y)
	_panel.size = Vector2(ancho, alto_provisional)
	_panel.position = ((vista - _panel.size) * 0.5).floor()
	_ajustar_alto_diferido.call_deferred()


## 2ª pasada (un frame después, con el ancho ya aplicado a los hijos): el alto REAL del contenido.
## El modal queda CENTRADO con ese alto — compacto, no a pantalla completa (decisión de la maqueta).
func _ajustar_alto_diferido() -> void:
	if _panel == null or not visible:
		return
	var vista: Vector2 = _panel.get_viewport_rect().size
	var ancho: float = maxf(320.0, vista.x - MARGEN_HORIZONTAL * 2.0)
	var alto: float = minf(
		_panel.get_combined_minimum_size().y, vista.y - MARGEN_VERTICAL_MIN * 2.0
	)
	_panel.size = Vector2(ancho, alto)
	_panel.position = ((vista - _panel.size) * 0.5).floor()


# ══ Repintado (al abrir y tras CADA orden; NUNCA por frame) ══════════════════════════════════════
## Foto fresca del estado: cola, dedicación, cobertura y las tarjetas de ventanilla.
func _reconstruir() -> void:
	if _odac == null:
		return
	_pintar_cola()
	_pintar_dedicacion()
	_pintar_cobertura()
	_pintar_ventanillas()
	_lbl_nota.text = (
		"El detalle tipo a tipo (las %d casillas) se afina en la ficha de cada ventanilla — clic "
		+ "sobre ella en el mundo."
	) % _odac.denuncias().size()
	_recolocar_panel()
	# Y otra vez al final del frame: al pasar de OCULTO a visible los contenedores todavía no han
	# re-medido a sus hijos (bug del "menú fantasma" ya cazado en `ModoConstruccion`).
	_recolocar_panel.call_deferred()


## El reparto de la cola por prioridad — se agrega leyendo las personas REALES que esperan ODAC y
## preguntando al catálogo si su denuncia es urgente (`ODAC.es_prioritaria`).
func _pintar_cola() -> void:
	var urgentes: int = 0
	var normales: int = 0
	if _flujo != null:
		for persona: Variant in _flujo.personas_de_cola(SERVICIO):
			if persona == null:
				continue
			if _odac.es_prioritaria(persona.tramite_id()):
				urgentes += 1
			else:
				normales += 1
	_lbl_urgentes.text = "%d urgente%s esperando" % [urgentes, "" if urgentes == 1 else "s"]
	_lbl_administrativas.text = "%d administrativa%s esperando" % [
		normales, "" if normales == 1 else "s"
	]


## Cuántas ventanillas hay en cada modo. Un chip con 0 se queda en gris (la maqueta): el color vivo
## señala el modo que de verdad está en uso.
func _pintar_dedicacion() -> void:
	_vaciar(_chips_dedicacion)
	var cuenta: Dictionary[int, int] = {}
	for puesto_id: StringName in _puestos():
		var modo: int = _odac.modo_de(puesto_id)
		cuenta[modo] = int(cuenta.get(modo, 0)) + 1
	for modo: int in _modos_en_orden():
		var n: int = int(cuenta.get(modo, 0))
		var colores: Array = _colores_de_modo(modo) if n > 0 else [
			KitUIComisarioScript.MOD_COLOR_GRIS_SUAVE, KitUIComisarioScript.MOD_COLOR_TINTA
		]
		var chip: PanelContainer = _chip(
			"%d %s" % [n, String(_odac.NOMBRES_MODO[modo])],
			colores[0], colores[1], 12, ALTO_CHIP_RESUMEN
		)
		chip.name = "ChipModo_%d" % modo
		_chips_dedicacion.add_child(chip)


## El banner de cobertura: aparece SOLO si hay tipos que ninguna ventanilla coge.
func _pintar_cobertura() -> void:
	_vaciar(_chips_sin_cubrir)
	var sin_cubrir: Array[StringName] = _odac.denuncias_sin_cubrir()
	_banner.visible = not sin_cubrir.is_empty()
	if sin_cubrir.is_empty():
		return
	_lbl_banner.text = (
		"SIN COBERTURA · %d tipo%s de denuncia sin ninguna ventanilla que los atienda"
	) % [sin_cubrir.size(), "" if sin_cubrir.size() == 1 else "s"]
	for id: StringName in sin_cubrir:
		var chip: PanelContainer = _chip(
			_nombre_denuncia(id), KitUIComisarioScript.MOD_COLOR_TARJETA,
			KitUIComisarioScript.MOD_COLOR_ROJO, 10, ALTO_CHIP_TIPO
		)
		chip.name = "ChipSinCubrir_%s" % id
		_chips_sin_cubrir.add_child(chip)


## Las tarjetas de ventanilla, lado a lado (dos columnas de la maqueta; con una sola ventanilla la
## tarjeta ocupa el ancho entero, y a partir de tres se apilan en filas de dos).
func _pintar_ventanillas() -> void:
	_vaciar(_rejilla)
	var puestos: Array[StringName] = _puestos()
	_rejilla.columns = COLUMNAS_VENTANILLAS if puestos.size() > 1 else 1
	if puestos.is_empty():
		var vacio: Label = _rotulo(
			"No hay ventanillas de ODAC construidas todavía — móntalas en la oficina de ODAC "
			+ "(menú de la sala o modo Construcción).", 12, KitUIComisarioScript.MOD_COLOR_GRIS, false
		)
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD
		vacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rejilla.add_child(vacio)
		return
	for i: int in puestos.size():
		_rejilla.add_child(_tarjeta_de_puesto(puestos[i], _nombre_visible(puestos[i], i + 1)))


## Una tarjeta de ventanilla: identidad + estado + qué atiende ahora + la pastilla de modos rápidos
## (y, si está "a medida", los tipos elegidos con la nota que remite a su ficha).
func _tarjeta_de_puesto(puesto_id: StringName, nombre_visible: String) -> Control:
	var tarjeta: PanelContainer = KitUIComisarioScript.moderno_tarjeta(false, 16.0)
	tarjeta.name = "Tarjeta_%s" % puesto_id
	tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var estilo: StyleBoxFlat = tarjeta.get_theme_stylebox("panel") as StyleBoxFlat
	if estilo != null:
		estilo.content_margin_left = PADDING_TARJETA
		estilo.content_margin_right = PADDING_TARJETA
		estilo.content_margin_top = PADDING_TARJETA
		estilo.content_margin_bottom = PADDING_TARJETA
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	tarjeta.add_child(caja)

	# 1) Nombre visible + estado (punto de color + texto: el color nunca es la única señal).
	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 14)
	caja.add_child(cabecera)
	var lbl_nombre: Label = _rotulo(nombre_visible, 18, KitUIComisarioScript.MOD_COLOR_TINTA)
	lbl_nombre.name = "Nombre"
	cabecera.add_child(lbl_nombre)
	var estado: StringName = _estado_de(puesto_id)
	var punto: HBoxContainer = _punto_con_texto(
		_color_estado(estado), 11, KitUIComisarioScript.MOD_COLOR_GRIS, LADO_PUNTO_ESTADO
	)
	punto.name = "Estado"
	var lbl_estado: Label = punto.get_node("Texto")
	lbl_estado.text = String(estado).to_upper().replace("_", " ")
	cabecera.add_child(punto)

	# 2) Quién la lleva.
	var agente: RefCounted = _agente_de(puesto_id)
	var lbl_operador: Label = _rotulo(
		"Operada por %s" % agente.nombre if agente != null else "Sin agente asignado",
		12, KitUIComisarioScript.MOD_COLOR_GRIS if agente != null
		else KitUIComisarioScript.MOD_COLOR_ROJO, false
	)
	lbl_operador.name = "Operador"
	caja.add_child(lbl_operador)

	# 3) Qué atiende AHORA MISMO (solo si hay alguien delante).
	var ahora: String = _texto_atendiendo(puesto_id)
	if ahora != "":
		var lbl_ahora: Label = _rotulo(ahora, 12, KitUIComisarioScript.MOD_COLOR_VERDE)
		lbl_ahora.name = "AhoraMismo"
		lbl_ahora.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl_ahora.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caja.add_child(lbl_ahora)

	# 4) La pastilla de los tres modos de UN CLIC.
	var modo: int = _odac.modo_de(puesto_id)
	caja.add_child(_rotulo("DEDICACIÓN", 10, KitUIComisarioScript.MOD_COLOR_GRIS))
	caja.add_child(_pastilla_modos(puesto_id, modo))

	# 5) "A medida": se INDICA (qué tipos coge) pero afinarlo tipo a tipo se queda en su ficha —
	# duplicar aquí las N casillas por cada ventanilla sería ruido, no ayuda (criterio de la maqueta).
	if modo == _odac.Modo.SUBCONJUNTO:
		var elegidas: Array[StringName] = _odac.subconjunto_de(puesto_id)
		var lbl_medida: Label = _rotulo(
			"A MEDIDA · elegidas %d de %d" % [elegidas.size(), _odac.denuncias().size()],
			12, KitUIComisarioScript.MOD_COLOR_ACENTO
		)
		lbl_medida.name = "LblAMedida"
		caja.add_child(lbl_medida)
		var chips := HFlowContainer.new()
		chips.name = "ChipsAMedida"
		chips.add_theme_constant_override("h_separation", 8)
		chips.add_theme_constant_override("v_separation", 6)
		caja.add_child(chips)
		for id: StringName in elegidas:
			var chip: PanelContainer = _chip_marcado(_nombre_denuncia(id))
			chip.name = "ChipElegida_%s" % id
			chips.add_child(chip)

	# 6) La consecuencia del modo, en una línea (nunca solo el nombre del modo).
	var lbl_ayuda: Label = _rotulo(_texto_ayuda(modo), 12, _color_ayuda(modo), false)
	lbl_ayuda.name = "Ayuda"
	lbl_ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_ayuda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(lbl_ayuda)
	return tarjeta


## La pastilla segmentada del kit con los tres modos rápidos. **HONESTA**: si el puesto está en
## SUBCONJUNTO ("a medida") NO se marca ninguno — no se inventa que uno de los tres está puesto.
func _pastilla_modos(puesto_id: StringName, modo_actual: int) -> PanelContainer:
	var opciones: Array[Dictionary] = []
	for m: int in _modos_rapidos():
		opciones.append({
			"id": StringName("modo_%d" % m), "texto": String(_odac.NOMBRES_MODO[m]),
			"tooltip": String(_odac.AYUDA_MODO.get(m, "")),
		})
	var pastilla: PanelContainer = KitUIComisarioScript.toggle_segmentado(
		opciones, ALTO_SEGMENTADO
	)
	pastilla.name = "ModosODAC"
	for m: int in _modos_rapidos():
		var boton: Button = pastilla.find_child("Opcion_modo_%d" % m, true, false) as Button
		if boton == null:
			continue
		boton.button_pressed = m == modo_actual
		var destino: int = m
		var id: StringName = puesto_id
		boton.pressed.connect(func() -> void: _odac.fijar_modo(id, destino))
	return pastilla


# ══ Lecturas del estado (la UI nunca muta; solo pregunta por la API pública) ═════════════════════
## Los puestos de ODAC que existen ahora mismo, en el orden estable de ODAC (que pregunta a Flujo).
func _puestos() -> Array[StringName]:
	return _odac.puestos() if _odac != null else [] as Array[StringName]


## Los cuatro modos en el orden de la maqueta (los tres rápidos + "a medida").
func _modos_en_orden() -> Array[int]:
	return [
		_odac.Modo.POLIVALENTE, _odac.Modo.SOLO_PRIORITARIAS, _odac.Modo.SOLO_NORMALES,
		_odac.Modo.SUBCONJUNTO,
	]


## Los tres modos que se pueden poner de UN CLIC (el cuarto se afina en la ficha de la ventanilla).
func _modos_rapidos() -> Array[int]:
	return [_odac.Modo.POLIVALENTE, _odac.Modo.SOLO_PRIORITARIAS, _odac.Modo.SOLO_NORMALES]


## Fondo y color de texto del chip de un modo (maqueta). SOLO_NORMALES en verde porque es la válvula
## anti-inanición: tener una ventanilla ahí es lo que evita que las administrativas se atasquen.
func _colores_de_modo(modo: int) -> Array:
	match modo:
		_odac.Modo.SOLO_PRIORITARIAS:
			return [
				KitUIComisarioScript.MOD_COLOR_AMBAR_SUAVE,
				KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO,
			]
		_odac.Modo.SOLO_NORMALES:
			return [KitUIComisarioScript.MOD_COLOR_VERDE_SUAVE, KitUIComisarioScript.MOD_COLOR_VERDE]
		_odac.Modo.SUBCONJUNTO:
			return [KitUIComisarioScript.MOD_COLOR_ACENTO_SUAVE, KitUIComisarioScript.MOD_COLOR_ACENTO]
		_:
			return [KitUIComisarioScript.MOD_COLOR_GRIS_SUAVE, KitUIComisarioScript.MOD_COLOR_TINTA]


func _estado_de(puesto_id: StringName) -> StringName:
	return _flujo.estado_de_puesto(puesto_id) if _flujo != null else &"cerrado"


## Color de REFUERZO del estado (el texto va siempre al lado — nunca solo el color).
func _color_estado(estado: StringName) -> Color:
	match estado:
		&"atendiendo":
			return KitUIComisarioScript.MOD_COLOR_VERDE
		&"en_camino":
			return KitUIComisarioScript.MOD_COLOR_AMBAR
		&"abierto_sin_agente":
			return KitUIComisarioScript.MOD_COLOR_ROJO
		_:
			return KitUIComisarioScript.MOD_COLOR_GRIS


func _agente_de(puesto_id: StringName) -> RefCounted:
	if _personal == null or not _personal.puesto_dotado(puesto_id):
		return null
	return _personal.agente_de(puesto_id)


## "Violencia de género (VioGén) · turno nº 12 · quedan 22 min" — vacío si no atiende a nadie.
func _texto_atendiendo(puesto_id: StringName) -> String:
	if _flujo == null:
		return ""
	var persona: RefCounted = _flujo.persona_en_puesto(puesto_id)
	if persona == null:
		return ""
	var restante: float = _flujo.restante_de_puesto(puesto_id)
	var texto: String = "%s · turno nº %d" % [
		_nombre_denuncia(persona.tramite_id()), persona.numero_turno
	]
	if restante > 0.0:
		texto += " · quedan %d min" % roundi(restante)
	return texto


## La consecuencia del modo. En "a medida" la línea REMITE a la ficha, que es donde se afina.
func _texto_ayuda(modo: int) -> String:
	if modo == _odac.Modo.SUBCONJUNTO:
		return "Se afina tipo a tipo en su ficha (clic sobre la ventanilla)."
	return String(_odac.AYUDA_MODO.get(modo, ""))


func _color_ayuda(modo: int) -> Color:
	if modo == _odac.Modo.SOLO_PRIORITARIAS:
		return KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO
	return KitUIComisarioScript.MOD_COLOR_GRIS


## Nombre legible de una denuncia (el id si el catálogo no da nombre — feo y honesto).
func _nombre_denuncia(id: StringName) -> String:
	var d: Resource = Datos.obtener_silencioso(&"DenunciaODAC", id)
	return d.nombre if d != null and d.nombre != "" else String(id)


## El nombre VISIBLE de una ventanilla ("ODAC 1"), por el helper ÚNICO del Tablón de Destinos: nunca
## el id técnico "odac_1". El ordinal se cuenta dentro de su propio prefijo, con el mismo criterio
## que `PanelVentanilla.nombre_visible` y `PanelHorario._nombres_visibles` — así la ventanilla se
## llama igual en las tres pantallas.
func _nombre_visible(puesto_id: StringName, ordinal_respaldo: int) -> String:
	if _personal == null:
		return String(puesto_id)
	var tipo: StringName = _personal.tipo_de_puesto(puesto_id)
	var prefijo: String = PanelPersonalScript.PREFIJO_POR_TIPO_PUESTO.get(tipo, "")
	if prefijo == "":
		return String(puesto_id)
	var ordinal: int = 0
	for otro: StringName in _personal.puestos_de_servicio(SERVICIO):
		var suyo: String = PanelPersonalScript.PREFIJO_POR_TIPO_PUESTO.get(
			_personal.tipo_de_puesto(otro), ""
		)
		if suyo != prefijo:
			continue
		ordinal += 1
		if otro == puesto_id:
			break
	if ordinal == 0:
		ordinal = ordinal_respaldo   # el puesto aún no está en Personal: se numera por su orden aquí
	return PanelPersonalScript.nombre_visible_de_puesto(puesto_id, tipo, ordinal)


# ══ Piezas visuales pequeñas (todas del kit; cero hex sueltos) ══════════════════════════════════
## Un Label con la tipografía moderna. `negrita` usa la variante semibold del kit.
func _rotulo(
	texto: String, tam: int, color: Color, negrita: bool = true
) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	if negrita:
		lbl.add_theme_font_override("font", KitUIComisarioScript.moderno_fuente(true))
	lbl.add_theme_font_size_override("font_size", tam)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


## Punto de color + texto (la línea de cola y el estado de una ventanilla). El texto va SIEMPRE al
## lado del punto: el color es refuerzo, nunca la única señal (accesibilidad transversal).
func _punto_con_texto(
	color_punto: Color, tam: int, color_texto: Color = KitUIComisarioScript.MOD_COLOR_TINTA,
	lado: float = LADO_PUNTO_COLA
) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var punto := Panel.new()
	punto.name = "Punto"
	punto.custom_minimum_size = Vector2(lado, lado)
	punto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color_punto
	estilo.set_corner_radius_all(int(lado / 2.0))
	punto.add_theme_stylebox_override("panel", estilo)
	fila.add_child(punto)
	var lbl: Label = _rotulo("", tam, color_texto)
	lbl.name = "Texto"
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(lbl)
	return fila


## Un chip: pastilla de fondo tenue con su texto dentro (la pieza base de la maqueta).
func _chip(
	texto: String, fondo: Color, color_texto: Color, tam: int, alto: float
) -> PanelContainer:
	var pastilla: PanelContainer = KitUIComisarioScript.moderno_pastilla(fondo, alto)
	pastilla.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pastilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 13)
	margen.add_theme_constant_override("margin_right", 13)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastilla.add_child(margen)
	var lbl: Label = _rotulo(texto, tam, color_texto)
	lbl.name = "Texto"
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margen.add_child(lbl)
	return pastilla


## Chip con la casilla MARCADA delante (los tipos elegidos "a medida"). La casilla la DIBUJA el kit
## (`moderno_casilla`): nunca el carácter "✓", que la fuente del sistema no trae limpio a este
## tamaño y sale como tofu. Aquí es un indicador de SOLO LECTURA — se desmarca en la ficha.
func _chip_marcado(texto: String) -> PanelContainer:
	var pastilla: PanelContainer = KitUIComisarioScript.moderno_pastilla(
		KitUIComisarioScript.MOD_COLOR_ACENTO_SUAVE, ALTO_CHIP_TIPO - 2.0
	)
	pastilla.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pastilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 6)
	margen.add_theme_constant_override("margin_right", 11)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastilla.add_child(margen)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 5)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_child(fila)
	var casilla: Button = KitUIComisarioScript.moderno_casilla(true, LADO_CASILLA_CHIP)
	casilla.name = "Casilla"
	casilla.disabled = true
	casilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	casilla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(casilla)
	var lbl: Label = _rotulo(texto, 10, KitUIComisarioScript.MOD_COLOR_ACENTO)
	lbl.name = "Texto"
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(lbl)
	return pastilla


## Vacía un contenedor de golpe (se repinta entero: son unas pocas tarjetas, nunca por frame).
func _vaciar(contenedor: Node) -> void:
	for hijo: Node in contenedor.get_children():
		contenedor.remove_child(hijo)
		hijo.queue_free()
