class_name PanelPersonal extends CanvasLayer
## PanelPersonal — "EL TABLÓN DE DESTINOS": la pantalla de gestión de plantilla (F3, 2026-08-17).
##
## Sustituye por dentro al andamio de dos listas (feedback flujo-008) por la maqueta APROBADA
## `design/ux/maquetas-menu-2026-08/maqueta_personal.png` (script de referencia, vinculante:
## `maqueta_personal.py`). El contrato con `Main` NO cambia: misma clase, mismo archivo,
## `configurar(personal, economia, construccion, flujo)` y `_reconstruir()` (los llama
## `Main._crear_paneles` y `Main._abrir_personal`), y la tecla P sigue abriendo y cerrando.
##
## La pantalla gira alrededor de los PUESTOS, no de las listas: jerarquía de uso
## PUESTOS > BANQUILLO > ACADEMIA > FICHA. El gesto principal es ARRASTRAR una tarjeta a un slot de
## puesto (drag & drop nativo de Godot: `_get_drag_data`/`_can_drop_data`/`_drop_data`); la
## ALTERNATIVA de clic es seleccionar y usar "Mover a" en la ficha inferior (regla dura del proyecto:
## ninguna acción existe SOLO por arrastre).
##
## Reglas que gobiernan este archivo:
## - ADR-0001 (Presentation): la UI LEE el estado y ORDENA por la API pública de Personal
##   (`contratar`/`asignar`/`desasignar`/`despedir`) — NUNCA muta agentes, saldo ni asignaciones.
## - Refresco PULL: se repinta al abrir y después de CADA orden (`_reconstruir`), nunca por frame.
## - Honestidad: `Personal.asignar()` sobre un puesto ocupado devuelve `false` y NO hay intercambio
##   (verificado en `personal.gd` líneas 965-999) → un slot ocupado se ATENÚA con el motivo
##   "ocupado" durante el arrastre y el drop se rechaza con el motivo a la vista.
## - Todo el estilo sale de `KitUIComisario` (kit moderno `MOD_*`/`moderno_*`): cero hex sueltos.
## - Cero emojis ni glifos unicode raros en Labels (la flecha "▾" del desplegable la DIBUJA
##   `GlifoModerno.Tipo.TRIANGULO_ABAJO`; el ▾ literal sale como tofu con la fuente del sistema).
##
## Story: F3 pantalla Personal · maqueta aprobada 2026-08-17 · ADR-0001 · spec
## `design/ux/menu-personal-spec.md`

const AgenteScript := preload("res://src/core/personal/agente.gd")
## `class_name` no resuelve en headless frío (gotcha del proyecto) → SIEMPRE preload.
const KitUIComisarioScript := preload("res://src/ui/kit_ui_comisario.gd")

# ── Geometría (todos los números salen de `maqueta_personal.py`; ninguno suelto sin comentario) ──
## Margen del modal contra el borde de la ventana (maqueta: 48 en horizontal, 40 en vertical).
const MARGEN_MODAL := Vector2(48.0, 40.0)
## Aire interior del modal (maqueta: `pad = 32`).
const PADDING_MODAL := 32.0
## Alto de un slot de puesto y de una tarjeta de banquillo (maqueta: `slot_h`/`alto_ban` = 80).
const ALTO_SLOT := 80.0
## Alto de una tarjeta de academia (maqueta: `alto_aca` = 68).
const ALTO_TARJETA_ACADEMIA := 68.0
## Alto reservado a la ficha inferior (la maqueta le deja ~170 px con sus dos filas de acciones).
const ALTO_FICHA := 176.0
## Reparto horizontal de las tres columnas — los anchos EXACTOS de la maqueta (660 / 260 / 488)
## usados como `stretch_ratio`, así la proporción se conserva a cualquier tamaño de ventana.
const RATIO_COLUMNA_PUESTOS := 660.0
const RATIO_COLUMNA_BANQUILLO := 260.0
const RATIO_COLUMNA_ACADEMIA := 488.0
## Barra de cansancio de un slot / de la ficha (maqueta: 100×7 y 200×12).
const BARRA_SLOT := Vector2(100.0, 7.0)
const BARRA_FICHA := Vector2(200.0, 12.0)
## Avatares (maqueta: 38 en slot, 32 en banquillo, 34 en academia, 64 en ficha).
const AVATAR_SLOT := 38.0
const AVATAR_TARJETA := 34.0
const AVATAR_FICHA := 64.0
## Escala de los atributos del agente (1-5, GDD staff-agents) — las casillas que dibuja la barra.
const ESCALA_ATRIBUTOS := 5
## Casilla de un atributo en la ficha (maqueta: `lado_w`/`lado_h` = 13×9).
const CASILLA_ATRIBUTO := Vector2(13.0, 9.0)
## Tramos del cansancio (0-100): ÁMBAR a partir de 70 (empieza el bajón de rendimiento), ROJO a
## partir de 90 (a un paso de irse al café). SIEMPRE con la cifra al lado — la barra sola no basta.
const UMBRAL_CANSANCIO_AMBAR := 70.0
const UMBRAL_CANSANCIO_ROJO := 90.0
## Opacidad de un slot NO válido como destino durante un arrastre (maqueta: velo alfa 175/255).
const OPACIDAD_SLOT_INVALIDO := 0.55
## Velo oscuro sobre el juego (maqueta: 10,14,24 con alfa 205/255).
const COLOR_VELO := Color(0.039, 0.055, 0.094, 0.804)

# ── Nombre VISIBLE de un puesto (la norma de TODO el juego: nunca un id técnico en pantalla) ─────
## Prefijo visible por TIPO de puesto del catálogo. Es data-driven a propósito: el nombre en pantalla
## lo decide esta tabla, no el id de la instancia (`doc_1`, `odac_2`… son ids de guardado). El prefijo
## va por TIPO y no por servicio porque un `puesto_tie` es del servicio "Documentacion" pero en
## ventanilla se llama "TIE", no "DNI" (decisión de la maqueta, `NOMBRE_PUESTO`).
const PREFIJO_POR_TIPO_PUESTO: Dictionary[StringName, String] = {
	&"puesto_doc_general": "DNI",
	&"puesto_ventanilla_media": "DNI",
	&"puesto_tie": "TIE",
	&"puesto_odac": "ODAC",
	&"puesto_seguridad": "SEG",
}
## Nombre legible (con tilde) de un servicio del catálogo — para el subtítulo de cada grupo de slots.
const NOMBRE_SERVICIO: Dictionary[String, String] = {
	"Documentacion": "Documentación",
	"ODAC": "ODAC",
	"Seguridad": "Seguridad",
}

# ── Refs a los sistemas Core (inyectadas por Main; la UI solo lee y ordena — ADR-0001) ───────────
var _personal: Node = null
var _economia: Node = null
var _construccion: Node = null
var _flujo: Node = null

# ── Nodos de UI (construidos en `configurar`; el panel nace oculto) ──────────────────────────────
var _velo: ColorRect
var _panel: PanelContainer
var _lbl_saldo: Label
var _lbl_resumen: Label
## Último motivo de rechazo de una orden (contratar sin caja, asignar imposible…): SIEMPRE visible,
## nunca un `false` silencioso (el andamio viejo se comía los rechazos y parecía un bug).
var _lbl_aviso: Label
var _cab_puestos: Label
var _cab_banquillo: Label
var _cab_academia: Label
var _lista_puestos: VBoxContainer
var _lista_banquillo: VBoxContainer
var _lista_academia: VBoxContainer
var _ficha: PanelContainer
var _ficha_caja: HBoxContainer
## Capa del desplegable PROPIO de "Mover a" (no el `PopupMenu` nativo gris): cuelga del CanvasLayer
## para pintarse por encima del modal y se cierra al clicar fuera.
var _capa_desplegable: Control
var _tarjeta_desplegable: PanelContainer

# ── Estado de interacción de la pantalla (NO estado de juego: solo selección y arrastre) ─────────
## El agente de la FICHA inferior (patrón rejilla→ficha del panel de construcción). Puede ser un
## miembro de la plantilla o un candidato de la academia; de dónde viene se deduce leyendo las listas
## reales (`_personal.mercado`/`plantilla`), así una selección obsoleta se limpia sola.
var _agente_seleccionado: RefCounted = null
## Payload del arrastre EN CURSO (vacío = no hay arrastre). Lo guarda esta pantalla en vez de
## preguntarle al viewport para no depender de `gui_get_drag_data()`.
var _arrastre: Dictionary = {}
## Un slot por puesto registrado: los nodos que hay que repintar al empezar/terminar un arrastre.
## `[{"puesto_id": StringName, "nodo": TarjetaInteractiva, "borde": Control, "lbl_vacante": Label,
##   "pastilla_motivo": Control, "lbl_motivo": Label, "ocupado": bool}]`
var _slots: Array[Dictionary] = []


## Nombre VISIBLE de un puesto — LA FUENTE ÚNICA del rótulo de una ventanilla en TODA la UI.
## `ordinal` es su número dentro de su propio prefijo (1, 2, 3…) en orden de registro, que es el
## orden estable con el que Flujo y Personal recorren los puestos.
##
## Un tipo de puesto que no esté en `PREFIJO_POR_TIPO_PUESTO` devuelve el id TÉCNICO tal cual: es
## deliberadamente honesto y feo (delata la tabla incompleta en la primera captura) en vez de
## inventarse un nombre bonito y equivocado.
static func nombre_visible_de_puesto(
	puesto_id: StringName, tipo_puesto_id: StringName, ordinal: int
) -> String:
	var prefijo: String = PREFIJO_POR_TIPO_PUESTO.get(tipo_puesto_id, "")
	if prefijo == "":
		return String(puesto_id)
	return "%s %d" % [prefijo, ordinal]


## Inyección de dependencias + construcción de la UI (la llama Main tras `add_child`). El panel se
## crea OCULTO; se puebla al abrir (`_reconstruir`), nunca por frame.
func configurar(personal: Node, economia: Node, construccion: Node, flujo: Node) -> void:
	_personal = personal
	_economia = economia
	_construccion = construccion
	_flujo = flujo
	# Por ENCIMA de la brújula de depuración (layer 10, `Main._crear_brujula_orientacion`): un modal
	# a pantalla completa debe tapar TODO — en la primera captura la brújula se colaba encima.
	layer = 12
	_crear_ui()
	visible = false


# ── Entrada (toggle con P; la UI solo ORDENA por la API pública) ─────────────────────────────────
## Tecla P alterna la visibilidad. Al ABRIR reconstruye (foto fresca del estado) y recoloca el modal.
## Se marca el input como consumido para no arrastrar la P a otros manejadores.
func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey and evento.pressed and not (evento as InputEventKey).echo):
		return
	if (evento as InputEventKey).keycode == KEY_P:
		if visible:
			_cerrar()
		else:
			visible = true
			_reconstruir()
		get_viewport().set_input_as_handled()


func _cerrar() -> void:
	_cerrar_desplegable()
	visible = false


# ══ Construcción de la UI (por código — el proyecto no usa .tscn salvo Main) ═════════════════════
func _crear_ui() -> void:
	# EL VELO: bloquea el juego de debajo (MOUSE_FILTER_STOP) pero NO se come los clics del panel —
	# el modal es un HERMANO POSTERIOR, así que recibe el input antes que el velo.
	_velo = ColorRect.new()
	_velo.color = COLOR_VELO
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_velo)

	var panel := PanelRaiz.new()
	panel.al_terminar_arrastre = _al_terminar_arrastre
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_PANEL
	estilo.set_corner_radius_all(22)   # maqueta: `rounded_rectangle(..., 22)` del marco del modal
	estilo.shadow_size = 14
	estilo.shadow_color = Color(0.039, 0.055, 0.094, 0.24)
	estilo.shadow_offset = Vector2(0.0, 8.0)
	estilo.content_margin_left = PADDING_MODAL
	estilo.content_margin_right = PADDING_MODAL
	estilo.content_margin_top = PADDING_MODAL
	estilo.content_margin_bottom = PADDING_MODAL
	panel.add_theme_stylebox_override("panel", estilo)
	# La tipografía moderna de golpe: el Theme del kit pone Segoe UI a TODO lo que cuelgue del panel
	# (sin él cada Label hereda la pixelada en mayúsculas del tema global — gotcha ya cazado en F1).
	panel.theme = KitUIComisarioScript.moderno_tema()
	add_child(panel)
	_panel = panel
	# Las anclas de un Control bajo CanvasLayer no son fiables en este proyecto (gotcha) y los
	# contenedores OCULTOS no re-miden: el tamaño y la posición se fijan a mano al mostrar y en cada
	# resize de la ventana. Mismo patrón que `ModoConstruccion._recolocar_panel`.
	get_viewport().size_changed.connect(_recolocar_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	panel.add_child(caja)

	caja.add_child(_crear_cabecera())
	_lbl_saldo = _etiqueta("", 13, KitUIComisarioScript.MOD_COLOR_TINTA)
	caja.add_child(_lbl_saldo)
	_lbl_resumen = _etiqueta("", 13, KitUIComisarioScript.MOD_COLOR_TINTA, true)
	caja.add_child(_lbl_resumen)
	_lbl_aviso = _etiqueta("", 11, KitUIComisarioScript.MOD_COLOR_ROJO, true)
	_lbl_aviso.visible = false
	caja.add_child(_lbl_aviso)
	caja.add_child(_linea())

	var cuerpo := HBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 24)   # maqueta: `gap_col = 24`
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(cuerpo)
	_lista_puestos = _crear_columna(
		cuerpo, RATIO_COLUMNA_PUESTOS, "PUESTOS", "", func(lbl: Label) -> void: _cab_puestos = lbl
	)
	_lista_banquillo = _crear_columna(
		cuerpo, RATIO_COLUMNA_BANQUILLO, "BANQUILLO", "Arrastra la tarjeta a un puesto compatible",
		func(lbl: Label) -> void: _cab_banquillo = lbl
	)
	_lista_academia = _crear_columna(
		cuerpo, RATIO_COLUMNA_ACADEMIA, "ACADEMIA", "Nuevo ingreso — la promoción se renueva cada 3 días",
		func(lbl: Label) -> void: _cab_academia = lbl
	)

	caja.add_child(_linea())
	_ficha = KitUIComisarioScript.moderno_tarjeta(false, 18.0)
	_ficha.custom_minimum_size.y = ALTO_FICHA
	caja.add_child(_ficha)
	var margen_ficha := MarginContainer.new()
	margen_ficha.add_theme_constant_override("margin_left", 24)
	margen_ficha.add_theme_constant_override("margin_right", 24)
	margen_ficha.add_theme_constant_override("margin_top", 14)
	margen_ficha.add_theme_constant_override("margin_bottom", 14)
	_ficha.add_child(margen_ficha)
	_ficha_caja = HBoxContainer.new()
	_ficha_caja.add_theme_constant_override("separation", 24)
	margen_ficha.add_child(_ficha_caja)

	_crear_capa_desplegable()


## Cabecera: título + subtítulo instructivo a la izquierda, botón "Cerrar (P)" a la derecha.
func _crear_cabecera() -> HBoxContainer:
	var fila := HBoxContainer.new()
	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 2)
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(textos)
	textos.add_child(_etiqueta("Personal", 24, KitUIComisarioScript.MOD_COLOR_TINTA, true))
	textos.add_child(_etiqueta(
		"Arrastra un agente a un puesto, o usa \"Mover a\" — se gestiona igual en pausa",
		12, KitUIComisarioScript.MOD_COLOR_GRIS
	))
	var cerrar: Button = KitUIComisarioScript.moderno_boton_pastilla(
		"Cerrar (P)", KitUIComisarioScript.MOD_BOTON_SECUNDARIO, 30.0
	)
	cerrar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cerrar.pressed.connect(_cerrar)
	fila.add_child(cerrar)
	return fila


## Una columna del cuerpo: cabecera con contador + pista en gris + scroll con la lista. Devuelve el
## VBox interior (donde `_reconstruir` cuelga slots/tarjetas). `recoger_cabecera` guarda el Label del
## título en el campo que corresponda (el contador se refresca en cada repintado).
func _crear_columna(
	padre: HBoxContainer, ratio: float, titulo: String, pista: String, recoger_cabecera: Callable
) -> VBoxContainer:
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.size_flags_stretch_ratio = ratio
	padre.add_child(columna)

	var cabecera: Label = _etiqueta(titulo, 14, KitUIComisarioScript.MOD_COLOR_TINTA, true)
	columna.add_child(cabecera)
	recoger_cabecera.call(cabecera)
	if pista != "":
		var lbl_pista: Label = _etiqueta(pista, 10, KitUIComisarioScript.MOD_COLOR_GRIS)
		lbl_pista.autowrap_mode = TextServer.AUTOWRAP_WORD
		columna.add_child(lbl_pista)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 10)
	scroll.add_child(lista)
	return lista


## La capa del desplegable propio de "Mover a": Control a pantalla completa que se traga el clic de
## fuera (para cerrar) con la tarjeta del menú posicionada a mano bajo el botón.
func _crear_capa_desplegable() -> void:
	_capa_desplegable = Control.new()
	_capa_desplegable.mouse_filter = Control.MOUSE_FILTER_STOP
	_capa_desplegable.visible = false
	_capa_desplegable.gui_input.connect(func(evento: InputEvent) -> void:
		if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
			_cerrar_desplegable()
	)
	add_child(_capa_desplegable)
	_tarjeta_desplegable = KitUIComisarioScript.moderno_tarjeta(false, KitUIComisarioScript.MOD_RADIO_PEQUENO)
	_tarjeta_desplegable.theme = KitUIComisarioScript.moderno_tema()
	_capa_desplegable.add_child(_tarjeta_desplegable)


## Recoloca el modal (y el velo) contra el tamaño REAL del viewport. Explícito porque las anclas de
## un Control bajo CanvasLayer ya han fallado en este proyecto y porque un contenedor oculto no
## re-mide a sus hijos: al pasar de oculto a visible el tamaño de antes se quedaba pegado.
func _recolocar_panel() -> void:
	if _panel == null or not visible:
		return
	var vista: Vector2 = _panel.get_viewport_rect().size
	_velo.position = Vector2.ZERO
	_velo.size = vista
	_panel.position = MARGEN_MODAL
	_panel.size = vista - MARGEN_MODAL * 2.0
	if _capa_desplegable != null:
		_capa_desplegable.position = Vector2.ZERO
		_capa_desplegable.size = vista


# ══ Repintado (al abrir y tras CADA orden; NUNCA por frame) ══════════════════════════════════════
## Foto fresca del estado: cabecera, los tres bloques y la ficha. Es el nombre que ya llamaba
## `Main._abrir_personal` — se conserva tal cual (contrato con Main).
func _reconstruir() -> void:
	if _personal == null:
		return
	_recolocar_panel()
	# Y otra vez al final del frame: al pasar de OCULTO a visible los contenedores todavía no han
	# re-medido a sus hijos (bug del "menú fantasma" ya cazado en `ModoConstruccion._recolocar_panel`).
	_recolocar_panel.call_deferred()
	_sanear_seleccion()
	_pintar_cabecera()
	_pintar_puestos()
	_pintar_banquillo()
	_pintar_academia()
	_pintar_ficha()


## Una selección puede quedarse obsoleta (al agente lo despidieron, o el candidato ya se contrató y
## es otro objeto en la plantilla): si ya no está en ninguna de las dos listas reales, se suelta.
func _sanear_seleccion() -> void:
	if _agente_seleccionado == null:
		return
	if _personal.plantilla.has(_agente_seleccionado) or _personal.mercado.has(_agente_seleccionado):
		return
	_agente_seleccionado = null


func _pintar_cabecera() -> void:
	var nomina: float = 0.0
	for agente: RefCounted in _personal.plantilla:
		nomina += _personal.salario_dia(agente)
	# Mismo formato de dinero que el HUD ("3.000 €") — fuente única en el kit.
	_lbl_saldo.text = "Saldo: %s   ·   Nómina: %s/día" % [
		KitUIComisarioScript.formato_euros(_economia.saldo_eur if _economia != null else 0.0),
		KitUIComisarioScript.formato_euros(nomina),
	]

	var en_puesto: int = 0
	var banquillo: int = 0
	var de_baja: int = 0
	for agente: RefCounted in _personal.plantilla:
		match agente.estado:
			AgenteScript.ESTADO_ASIGNADO, AgenteScript.ESTADO_CUBRIENDO, AgenteScript.ESTADO_DESCANSANDO:
				en_puesto += 1
			AgenteScript.ESTADO_AUSENTE:
				de_baja += 1
			_:
				banquillo += 1
	var puestos: Array[StringName] = _puestos_registrados()
	var cubiertos: int = 0
	for puesto_id: StringName in puestos:
		if _personal.puesto_dotado(puesto_id):
			cubiertos += 1
	var vacantes: int = puestos.size() - cubiertos
	_lbl_resumen.text = (
		"Plantilla: %d  (en puesto %d · banquillo %d · de baja %d)   —   Ventanillas cubiertas: %d de %d"
	) % [_personal.plantilla.size(), en_puesto, banquillo, de_baja, cubiertos, puestos.size()]
	# Color como REFUERZO del texto, nunca única señal (respaldo daltónico): ámbar oscurecido para
	# texto sobre panel claro mientras haya vacantes, verde cuando estén todas cubiertas.
	_lbl_resumen.add_theme_color_override("font_color", (
		KitUIComisarioScript.MOD_COLOR_VERDE if vacantes == 0 and not puestos.is_empty()
		else KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO
	))


# ── ZONA PUESTOS ────────────────────────────────────────────────────────────────────────────────
## Los puestos que existen en el mundo, en orden de registro (fuente: Flujo, igual que el andamio).
func _puestos_registrados() -> Array[StringName]:
	if _flujo == null:
		return []
	return _flujo.puestos_registrados()


## El tipo de puesto del catálogo con el que se registró (Personal manda; Construcción como respaldo).
func _tipo_de_puesto(puesto_id: StringName) -> StringName:
	var tipo: StringName = _personal.tipo_de_puesto(puesto_id)
	if tipo == &"" and _construccion != null:
		tipo = _construccion.catalogo_de(puesto_id)
	return tipo


## Agrupa los puestos por PREFIJO visible (DNI, TIE, ODAC…) conservando el orden de registro, y de
## paso asigna a cada uno su ordinal dentro del grupo — el número que sale en pantalla.
## Devuelve `[{"prefijo": String, "servicio": String, "puestos": Array[StringName], "nombres": Array[String]}]`.
func _agrupar_puestos() -> Array[Dictionary]:
	var grupos: Array[Dictionary] = []
	var indice_de_prefijo: Dictionary[String, int] = {}
	for puesto_id: StringName in _puestos_registrados():
		var tipo: StringName = _tipo_de_puesto(puesto_id)
		var prefijo: String = PREFIJO_POR_TIPO_PUESTO.get(tipo, "")
		var clave: String = prefijo if prefijo != "" else "otros"
		if not indice_de_prefijo.has(clave):
			indice_de_prefijo[clave] = grupos.size()
			# Los dos arrays se declaran TIPADOS aparte: dentro del literal del diccionario un `[]`
			# suelto sería `Array` sin tipo y el `for` de más abajo perdería el tipado estático.
			var puestos_nuevos: Array[StringName] = []
			var nombres_nuevos: Array[String] = []
			grupos.append({
				"prefijo": prefijo,
				"servicio": _personal.servicio_de_puesto(puesto_id),
				"puestos": puestos_nuevos,
				"nombres": nombres_nuevos,
			})
		var grupo: Dictionary = grupos[indice_de_prefijo[clave]]
		var puestos_grupo: Array[StringName] = grupo["puestos"]
		var nombres_grupo: Array[String] = grupo["nombres"]
		puestos_grupo.append(puesto_id)
		nombres_grupo.append(nombre_visible_de_puesto(puesto_id, tipo, puestos_grupo.size()))
	return grupos


## Subtítulo de un grupo: "DNI · Documentación". Si el prefijo YA es el nombre del servicio (ODAC),
## no se repite ("ODAC · ODAC" sería ruido — criterio de la maqueta).
func _titulo_grupo(grupo: Dictionary) -> String:
	var prefijo: String = grupo["prefijo"]
	var servicio: String = NOMBRE_SERVICIO.get(String(grupo["servicio"]), String(grupo["servicio"]))
	if prefijo == "":
		return "Puestos sin nombre en el catálogo"
	if prefijo == servicio or servicio == "":
		return prefijo
	return "%s · %s" % [prefijo, servicio]


func _pintar_puestos() -> void:
	_vaciar(_lista_puestos)
	_slots.clear()
	var grupos: Array[Dictionary] = _agrupar_puestos()
	_cab_puestos.text = "PUESTOS"
	if grupos.is_empty():
		_lista_puestos.add_child(_etiqueta(
			"Sin ventanillas construidas — constrúyelas en el modo Construcción (B).",
			11, KitUIComisarioScript.MOD_COLOR_GRIS
		))
		return
	for grupo: Dictionary in grupos:
		_lista_puestos.add_child(_etiqueta(
			_titulo_grupo(grupo), 12, KitUIComisarioScript.MOD_COLOR_TINTA, true
		))
		var puestos: Array[StringName] = grupo["puestos"]
		var nombres: Array[String] = grupo["nombres"]
		for i: int in puestos.size():
			_lista_puestos.add_child(_crear_slot(puestos[i], nombres[i]))


## Un slot del tablón: es a la vez DESTINO de arrastre (`_can_drop_data`/`_drop_data`) y ORIGEN si
## tiene a alguien dentro (arrastrar al asignado a otra ventanilla), más clic para seleccionarlo.
func _crear_slot(puesto_id: StringName, nombre_visible: String) -> Control:
	var agente: RefCounted = _personal.agente_de(puesto_id)
	var ocupado: bool = agente != null
	var slot := TarjetaInteractiva.new()
	slot.custom_minimum_size.y = ALTO_SLOT
	slot.add_theme_stylebox_override("panel", _estilo_slot(ocupado, false))
	slot.puede_soltar = func(datos: Variant) -> bool:
		return bool(_evaluar_destino(datos, puesto_id)["puede"])
	slot.al_soltar = func(datos: Variant) -> void: _soltar_en_puesto(datos, puesto_id)
	if ocupado:
		slot.al_seleccionar = func() -> void: _seleccionar(agente)
		# Solo se arrastra a quien está EN PIE en su puesto: a un ausente o a alguien de café no se
		# le mueve de sitio (`asignar` lo rechazaría; mejor no ofrecer el gesto).
		if agente.estado in [AgenteScript.ESTADO_ASIGNADO, AgenteScript.ESTADO_CUBRIENDO]:
			slot.datos_arrastre = {"origen": "puesto", "agente": agente, "puesto_origen": puesto_id}
			slot.fabricar_fantasma = func() -> Control: return _fantasma(agente)
			slot.al_empezar_arrastre = _al_empezar_arrastre
	slot.al_terminar_arrastre = _al_terminar_arrastre

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 14)
	margen.add_theme_constant_override("margin_right", 14)
	margen.add_theme_constant_override("margin_top", 10)
	margen.add_theme_constant_override("margin_bottom", 10)
	slot.add_child(margen)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 16)
	margen.add_child(fila)

	# Rótulo con el NOMBRE VISIBLE — siempre presente, ocupado o vacante (es la identidad del slot).
	var rotulo: PanelContainer = KitUIComisarioScript.moderno_pastilla(
		KitUIComisarioScript.MOD_COLOR_TARJETA if not ocupado else KitUIComisarioScript.MOD_COLOR_PANEL,
		26.0
	)
	rotulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var centro_rotulo := MarginContainer.new()
	centro_rotulo.add_theme_constant_override("margin_left", 11)
	centro_rotulo.add_theme_constant_override("margin_right", 11)
	rotulo.add_child(centro_rotulo)
	centro_rotulo.add_child(_etiqueta(nombre_visible, 12, KitUIComisarioScript.MOD_COLOR_TINTA, true))
	fila.add_child(rotulo)

	var lbl_vacante: Label = null
	if ocupado:
		fila.add_child(_bloque_agente_en_slot(agente))
	else:
		lbl_vacante = _etiqueta(
			"VACANTE — arrastra aquí un agente", 13, KitUIComisarioScript.MOD_COLOR_GRIS, true
		)
		lbl_vacante.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_vacante.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_vacante.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(lbl_vacante)

	# Etiqueta de MOTIVO (esquina derecha), oculta salvo durante un arrastre no válido.
	var pastilla_motivo: PanelContainer = KitUIComisarioScript.moderno_pastilla(
		KitUIComisarioScript.MOD_COLOR_TARJETA, 20.0
	)
	pastilla_motivo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pastilla_motivo.visible = false
	var margen_motivo := MarginContainer.new()
	margen_motivo.add_theme_constant_override("margin_left", 8)
	margen_motivo.add_theme_constant_override("margin_right", 8)
	pastilla_motivo.add_child(margen_motivo)
	var lbl_motivo: Label = _etiqueta("", 9, KitUIComisarioScript.MOD_COLOR_GRIS, true)
	margen_motivo.add_child(lbl_motivo)
	fila.add_child(pastilla_motivo)

	# El borde a trazos del hueco vacante (StyleBoxFlat no sabe hacer bordes discontinuos). Va como
	# hijo del PanelContainer, que estira a TODOS sus hijos al rectángulo del panel.
	var borde: Control = KitUIComisarioScript.moderno_borde_punteado(Color(0.745, 0.769, 0.816, 1.0))
	borde.visible = not ocupado
	slot.add_child(borde)

	_ignorar_raton(margen)
	_slots.append({
		"puesto_id": puesto_id, "nodo": slot, "borde": borde, "lbl_vacante": lbl_vacante,
		"pastilla_motivo": pastilla_motivo, "lbl_motivo": lbl_motivo, "ocupado": ocupado,
	})
	return slot


## Estilo del rectángulo de un slot: tarjeta blanca con sombra si está ocupado, hueco del color del
## panel si está vacante; `resaltado` es el destino válido de un arrastre en curso (borde de acento
## de 3 px + fondo azul suave, la regla de la maqueta).
func _estilo_slot(ocupado: bool, resaltado: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.set_corner_radius_all(int(KitUIComisarioScript.MOD_RADIO_PEQUENO))
	if resaltado:
		estilo.bg_color = KitUIComisarioScript.MOD_COLOR_ACENTO_SUAVE
		estilo.set_border_width_all(3)
		estilo.border_color = KitUIComisarioScript.MOD_COLOR_ACENTO
		return estilo
	if ocupado:
		estilo.bg_color = KitUIComisarioScript.MOD_COLOR_TARJETA
		estilo.shadow_size = 8
		estilo.shadow_color = Color(0.02, 0.03, 0.06, 0.10)
		estilo.shadow_offset = Vector2(0.0, 3.0)
	else:
		estilo.bg_color = KitUIComisarioScript.MOD_COLOR_PANEL
	return estilo


## El bloque "quién está aquí" de un slot ocupado: avatar + identidad + chip de estado + mini
## cansancio con su cifra + salario.
func _bloque_agente_en_slot(agente: RefCounted) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var apagado: bool = not _en_pie(agente)
	fila.add_child(_avatar(agente, AVATAR_SLOT, apagado))

	var identidad := VBoxContainer.new()
	identidad.add_theme_constant_override("separation", 2)
	identidad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(identidad)
	identidad.add_child(_etiqueta(
		agente.nombre, 13,
		KitUIComisarioScript.MOD_COLOR_GRIS if apagado else KitUIComisarioScript.MOD_COLOR_TINTA, true
	))
	identidad.add_child(_etiqueta(_subtitulo_agente(agente), 10, KitUIComisarioScript.MOD_COLOR_GRIS))
	var estado: Dictionary = _estado_legible(agente)
	var texto_estado: String = estado["texto"]
	var color_estado: Color = estado["color"]
	identidad.add_child(KitUIComisarioScript.moderno_chip_estado(texto_estado, color_estado))

	fila.add_child(_bloque_cansancio(agente, BARRA_SLOT, 9, apagado))

	var derecha := VBoxContainer.new()
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	derecha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fila.add_child(derecha)
	var hueco := Control.new()
	hueco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	derecha.add_child(hueco)
	var salario: Label = _etiqueta(_texto_salario(agente), 10, KitUIComisarioScript.MOD_COLOR_GRIS)
	salario.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	derecha.add_child(salario)
	return fila


# ── BANQUILLO y ACADEMIA ────────────────────────────────────────────────────────────────────────
## El banquillo = quien no está al pie de una ventanilla: sin puesto y sin cubrir a nadie. Incluye a
## los de BAJA sin puesto (aparecen con su chip gris): nadie de la plantilla desaparece de pantalla.
func _agentes_en_banquillo() -> Array[RefCounted]:
	var lista: Array[RefCounted] = []
	for agente: RefCounted in _personal.plantilla:
		if agente.puesto_id == &"" and agente.estado != AgenteScript.ESTADO_CUBRIENDO:
			lista.append(agente)
	return lista


func _pintar_banquillo() -> void:
	_vaciar(_lista_banquillo)
	var lista: Array[RefCounted] = _agentes_en_banquillo()
	_cab_banquillo.text = "BANQUILLO (%d)" % lista.size()
	if lista.is_empty():
		_lista_banquillo.add_child(_etiqueta(
			"Nadie en el banquillo.", 11, KitUIComisarioScript.MOD_COLOR_GRIS
		))
		return
	for agente: RefCounted in lista:
		_lista_banquillo.add_child(_tarjeta_banquillo(agente))


func _tarjeta_banquillo(agente: RefCounted) -> Control:
	var tarjeta := TarjetaInteractiva.new()
	tarjeta.custom_minimum_size.y = ALTO_SLOT
	tarjeta.add_theme_stylebox_override("panel", _estilo_slot(true, false))
	tarjeta.al_seleccionar = func() -> void: _seleccionar(agente)
	if agente.estado == AgenteScript.ESTADO_LIBRE:
		tarjeta.datos_arrastre = {"origen": "banquillo", "agente": agente, "puesto_origen": &""}
		tarjeta.fabricar_fantasma = func() -> Control: return _fantasma(agente)
		tarjeta.al_empezar_arrastre = _al_empezar_arrastre
		tarjeta.al_terminar_arrastre = _al_terminar_arrastre

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_right", 12)
	margen.add_theme_constant_override("margin_top", 8)
	margen.add_theme_constant_override("margin_bottom", 8)
	tarjeta.add_child(margen)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	margen.add_child(fila)
	fila.add_child(_avatar(agente, AVATAR_TARJETA, not _en_pie(agente)))
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(caja)
	caja.add_child(_etiqueta(agente.nombre, 13, KitUIComisarioScript.MOD_COLOR_TINTA, true))
	caja.add_child(_etiqueta(_subtitulo_agente(agente), 10, KitUIComisarioScript.MOD_COLOR_GRIS))
	# Cansancio en SU PROPIA fila y salario en la suya (auditoría de la maqueta v3: compartir fila
	# hacía que la cifra de cansancio y el salario se pegaran — "0/10030 €/día").
	caja.add_child(_bloque_cansancio(agente, Vector2(78.0, 7.0), 9, false, true))
	var salario: Label = _etiqueta(_texto_salario(agente), 9, KitUIComisarioScript.MOD_COLOR_GRIS)
	salario.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caja.add_child(salario)
	_ignorar_raton(margen)
	return tarjeta


func _pintar_academia() -> void:
	_vaciar(_lista_academia)
	_cab_academia.text = "ACADEMIA (%d)" % _personal.mercado.size()
	if _personal.mercado.is_empty():
		_lista_academia.add_child(_etiqueta(
			"No hay candidatos ahora mismo.", 11, KitUIComisarioScript.MOD_COLOR_GRIS
		))
		return
	for indice: int in _personal.mercado.size():
		_lista_academia.add_child(_tarjeta_academia(indice))


func _tarjeta_academia(indice: int) -> Control:
	var candidato: RefCounted = _personal.mercado[indice]
	var tarjeta := TarjetaInteractiva.new()
	tarjeta.custom_minimum_size.y = ALTO_TARJETA_ACADEMIA
	tarjeta.add_theme_stylebox_override("panel", _estilo_slot(true, false))
	tarjeta.al_seleccionar = func() -> void: _seleccionar(candidato)
	# Arrastrar un candidato a una vacante = contratar + asignar (dos llamadas REALES compuestas).
	tarjeta.datos_arrastre = {"origen": "academia", "agente": candidato, "puesto_origen": &""}
	tarjeta.fabricar_fantasma = func() -> Control: return _fantasma(candidato)
	tarjeta.al_empezar_arrastre = _al_empezar_arrastre
	tarjeta.al_terminar_arrastre = _al_terminar_arrastre

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 14)
	margen.add_theme_constant_override("margin_right", 14)
	margen.add_theme_constant_override("margin_top", 8)
	margen.add_theme_constant_override("margin_bottom", 8)
	tarjeta.add_child(margen)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	margen.add_child(fila)
	fila.add_child(_avatar(candidato, AVATAR_TARJETA, true))
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 1)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(caja)
	caja.add_child(_etiqueta(candidato.nombre, 13, KitUIComisarioScript.MOD_COLOR_TINTA, true))
	caja.add_child(_etiqueta(_subtitulo_agente(candidato), 10, KitUIComisarioScript.MOD_COLOR_GRIS))
	var operables: String = _operables_legibles(candidato.tipo_id)
	if operables != "":
		caja.add_child(_etiqueta("Opera: %s" % operables, 9, KitUIComisarioScript.MOD_COLOR_GRIS))
	_ignorar_raton(margen)

	var contratar: Button = KitUIComisarioScript.moderno_boton_pastilla(
		"Contratar — %.0f €/día" % _personal.salario_dia(candidato),
		KitUIComisarioScript.MOD_BOTON_PRIMARIO, 26.0, false, 10
	)
	contratar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	contratar.pressed.connect(func() -> void: _ordenar_contratar(candidato))
	fila.add_child(contratar)
	return tarjeta


# ══ FICHA INFERIOR (patrón rejilla→ficha del panel de construcción) ══════════════════════════════
func _seleccionar(agente: RefCounted) -> void:
	_agente_seleccionado = agente
	_cerrar_desplegable()
	_pintar_ficha()


func _pintar_ficha() -> void:
	for hijo: Node in _ficha_caja.get_children():
		hijo.queue_free()
	if _agente_seleccionado == null:
		var vacio: Label = _etiqueta(
			"Selecciona un agente (clic en su tarjeta o en su puesto) para ver su ficha, moverlo de "
			+ "puesto o despedirlo.", 12, KitUIComisarioScript.MOD_COLOR_GRIS
		)
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD
		vacio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Con autowrap, el ancho MÍNIMO de un Label es 0 y el HBox lo estrecha a nada → el texto
		# salía a UNA PALABRA POR LÍNEA inflando la ficha entera (captura `capturas/error.PNG` del
		# usuario, 2026-08-17). EXPAND_FILL le da el ancho real de la fila y el texto vuelve a ser
		# una línea. Mismo gotcha ya cazado con los nombres de tarjeta del panel de construcción.
		vacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ficha_caja.add_child(vacio)
		return
	var agente: RefCounted = _agente_seleccionado
	var es_candidato: bool = _personal.mercado.has(agente)

	# Bloque 1: identidad.
	var identidad := HBoxContainer.new()
	identidad.add_theme_constant_override("separation", 14)
	_ficha_caja.add_child(identidad)
	identidad.add_child(_avatar(agente, AVATAR_FICHA, false))
	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 4)
	textos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identidad.add_child(textos)
	textos.add_child(_etiqueta(
		"SELECCIONADO", 10, KitUIComisarioScript.MOD_COLOR_GRIS, true
	))
	textos.add_child(_etiqueta(agente.nombre, 20, KitUIComisarioScript.MOD_COLOR_TINTA, true))
	textos.add_child(_etiqueta(_subtitulo_agente(agente), 12, KitUIComisarioScript.MOD_COLOR_GRIS))
	var estado: Dictionary = (
		{"texto": "Candidato de la academia", "color": KitUIComisarioScript.MOD_COLOR_ACENTO}
		if es_candidato else _estado_legible(agente)
	)
	var texto_estado: String = estado["texto"]
	var color_estado: Color = estado["color"]
	var chip: PanelContainer = KitUIComisarioScript.moderno_chip_estado(texto_estado, color_estado)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	textos.add_child(chip)

	# Bloque 2: atributos 1-5 (Mando SOLO en Oficiales — en un Policía es siempre 0 y no se enseña).
	var atributos := VBoxContainer.new()
	atributos.add_theme_constant_override("separation", 4)
	atributos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ficha_caja.add_child(atributos)
	atributos.add_child(_fila_atributo("Rapidez", agente.rapidez))
	atributos.add_child(_fila_atributo("Trato", agente.trato))
	atributos.add_child(_fila_atributo("Salud", agente.salud))
	atributos.add_child(_fila_atributo("Motivación", agente.motivacion))
	if agente.rango == AgenteScript.RANGO_OFICIAL:
		atributos.add_child(_fila_atributo("Mando", agente.mando))

	# Bloque 3: cansancio grande + salario.
	var bloque_cansancio := VBoxContainer.new()
	bloque_cansancio.add_theme_constant_override("separation", 8)
	bloque_cansancio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ficha_caja.add_child(bloque_cansancio)
	bloque_cansancio.add_child(_bloque_cansancio(agente, BARRA_FICHA, 12, false))
	bloque_cansancio.add_child(_etiqueta(
		"Salario: %.0f €/día" % _personal.salario_dia(agente), 12, KitUIComisarioScript.MOD_COLOR_GRIS
	))
	if not es_candidato:
		bloque_cansancio.add_child(_etiqueta(
			_texto_pausas(agente), 10, KitUIComisarioScript.MOD_COLOR_GRIS
		))

	# Bloque 4: acciones (a la derecha, con la nota que explica la alternativa al arrastre).
	var acciones := VBoxContainer.new()
	acciones.add_theme_constant_override("separation", 6)
	acciones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acciones.alignment = BoxContainer.ALIGNMENT_END
	_ficha_caja.add_child(acciones)
	var nota: Label = _etiqueta(
		"El desplegable lista los puestos compatibles — alternativa al arrastre.",
		9, KitUIComisarioScript.MOD_COLOR_GRIS
	)
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD
	acciones.add_child(nota)
	var fila_botones := HBoxContainer.new()
	fila_botones.add_theme_constant_override("separation", 10)
	fila_botones.alignment = BoxContainer.ALIGNMENT_END
	acciones.add_child(fila_botones)
	for boton: Button in _botones_de_accion(agente, es_candidato):
		fila_botones.add_child(boton)


## Las acciones de la ficha según el estado real del agente. Un botón que hoy no haría nada NO se
## dibuja habilitado: o no está (Desasignar en quien no tiene puesto) o está deshabilitado CON el
## motivo en su tooltip (Mover a de un ausente).
func _botones_de_accion(agente: RefCounted, es_candidato: bool) -> Array[Button]:
	var botones: Array[Button] = []
	if es_candidato:
		var contratar: Button = KitUIComisarioScript.moderno_boton_pastilla(
			"Contratar — %.0f €/día" % _personal.salario_dia(agente),
			KitUIComisarioScript.MOD_BOTON_PRIMARIO, 34.0
		)
		contratar.pressed.connect(func() -> void: _ordenar_contratar(agente))
		botones.append(contratar)
		return botones

	var puede_moverse: bool = agente.estado != AgenteScript.ESTADO_AUSENTE
	var mover: Button = KitUIComisarioScript.moderno_boton_pastilla(
		"Mover a",
		KitUIComisarioScript.MOD_BOTON_SECUNDARIO if puede_moverse
		else KitUIComisarioScript.MOD_BOTON_DESHABILITADO,
		34.0, true
	)
	mover.tooltip_text = (
		"Elige a qué puesto va" if puede_moverse
		else "Hoy está de baja — no se le puede asignar hasta mañana"
	)
	if puede_moverse:
		mover.pressed.connect(func() -> void: _abrir_desplegable_mover(agente, mover))
	botones.append(mover)

	if agente.puesto_id != &"" or agente.estado == AgenteScript.ESTADO_CUBRIENDO:
		var desasignar: Button = KitUIComisarioScript.moderno_boton_pastilla(
			"Desasignar", KitUIComisarioScript.MOD_BOTON_SECUNDARIO, 34.0
		)
		desasignar.pressed.connect(func() -> void: _ordenar_desasignar(agente))
		botones.append(desasignar)

	var despedir: Button = KitUIComisarioScript.moderno_boton_pastilla(
		"Despedir", KitUIComisarioScript.MOD_BOTON_PELIGRO, 34.0
	)
	despedir.pressed.connect(func() -> void: _ordenar_despedir(agente))
	botones.append(despedir)
	return botones


## Una fila "Rapidez [▮▮▯▯▯] 2/5": casillas llenas hasta el valor + la cifra SIEMPRE al lado (texto y
## forma, nunca solo color — respaldo daltónico).
func _fila_atributo(nombre: String, valor: int) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	var etiqueta: Label = _etiqueta(nombre, 11, KitUIComisarioScript.MOD_COLOR_GRIS)
	etiqueta.custom_minimum_size.x = 78.0   # columna fija: las barras quedan alineadas (maqueta: 78)
	fila.add_child(etiqueta)
	var casillas := HBoxContainer.new()
	casillas.add_theme_constant_override("separation", 2)
	casillas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(casillas)
	for i: int in ESCALA_ATRIBUTOS:
		var casilla := Panel.new()
		casilla.custom_minimum_size = CASILLA_ATRIBUTO
		casilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = (
			KitUIComisarioScript.MOD_COLOR_GRIS if i < valor else KitUIComisarioScript.MOD_COLOR_LINEA
		)
		estilo.set_corner_radius_all(2)
		casilla.add_theme_stylebox_override("panel", estilo)
		casillas.add_child(casilla)
	fila.add_child(_etiqueta(
		"%d/%d" % [valor, ESCALA_ATRIBUTOS], 11, KitUIComisarioScript.MOD_COLOR_GRIS
	))
	return fila


## Bloque de cansancio: rótulo + barra del kit + cifra con SU escala explícita (0-100), coloreada por
## tramo. `en_fila` lo compone en horizontal (tarjeta estrecha del banquillo) en vez de en vertical.
func _bloque_cansancio(
	agente: RefCounted, tamano_barra: Vector2, tam_fuente: int, apagado: bool, en_fila: bool = false
) -> Container:
	var cansancio: float = agente.cansancio
	var color_barra: Color = KitUIComisarioScript.MOD_COLOR_GRIS
	var color_cifra: Color = KitUIComisarioScript.MOD_COLOR_GRIS
	if cansancio >= UMBRAL_CANSANCIO_ROJO:
		color_barra = KitUIComisarioScript.MOD_COLOR_ROJO
		color_cifra = KitUIComisarioScript.MOD_COLOR_ROJO
	elif cansancio >= UMBRAL_CANSANCIO_AMBAR:
		color_barra = KitUIComisarioScript.MOD_COLOR_AMBAR
		color_cifra = KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO
	if apagado:
		# Titular de BAJA: su cansancio de ayer no es información accionable — se apaga el color para
		# que no compita con el chip "sin cobertura", que es lo que el jugador tiene que ver.
		color_barra = KitUIComisarioScript.MOD_COLOR_LINEA
		color_cifra = KitUIComisarioScript.MOD_COLOR_GRIS
	var barra: Control = KitUIComisarioScript.moderno_barra_progreso(
		cansancio / 100.0, color_barra, tamano_barra.x, tamano_barra.y
	)
	var cifra: Label = _etiqueta("%d/100" % roundi(cansancio), tam_fuente, color_cifra, true)
	var rotulo: Label = _etiqueta("Cansancio", tam_fuente, KitUIComisarioScript.MOD_COLOR_GRIS, en_fila)
	if en_fila:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		fila.add_child(rotulo)
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(barra)
		fila.add_child(cifra)
		return fila
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	caja.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caja.add_child(rotulo)
	var fila_barra := HBoxContainer.new()
	fila_barra.add_theme_constant_override("separation", 8)
	caja.add_child(fila_barra)
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila_barra.add_child(barra)
	fila_barra.add_child(cifra)
	return caja


# ══ DRAG & DROP (nativo de Godot) ════════════════════════════════════════════════════════════════
## Empieza un arrastre: se guarda el payload y se repintan los slots (destinos válidos iluminados,
## el resto atenuado CON su motivo — la maqueta).
func _al_empezar_arrastre(datos: Dictionary) -> void:
	_arrastre = datos
	_pintar_estado_arrastre()


## Fin del arrastre (lo notifica Godot a TODOS los Controls: `NOTIFICATION_DRAG_END`). Idempotente:
## un drop válido ya limpió el estado y reconstruyó la pantalla.
func _al_terminar_arrastre() -> void:
	if _arrastre.is_empty():
		return
	_arrastre = {}
	_pintar_estado_arrastre()


func _pintar_estado_arrastre() -> void:
	for slot: Dictionary in _slots:
		var nodo: Control = slot["nodo"]
		if not is_instance_valid(nodo):
			continue
		var ocupado: bool = slot["ocupado"]
		# Tipado con la clase interna del kit (no `Control`): abajo se le tocan `color`/`grosor`, que
		# son propiedades SUYAS — con el tipo genérico el analizador estático no las conoce.
		var borde: KitUIComisarioScript.BordePunteadoModerno = slot["borde"]
		var pastilla_motivo: Control = slot["pastilla_motivo"]
		var lbl_vacante: Label = slot["lbl_vacante"]
		if _arrastre.is_empty():
			nodo.modulate = Color.WHITE
			nodo.add_theme_stylebox_override("panel", _estilo_slot(ocupado, false))
			borde.visible = not ocupado
			borde.color = Color(0.745, 0.769, 0.816, 1.0)
			borde.grosor = 2.0
			borde.queue_redraw()
			pastilla_motivo.visible = false
			if lbl_vacante != null:
				lbl_vacante.text = "VACANTE — arrastra aquí un agente"
				lbl_vacante.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_GRIS)
			continue
		var veredicto: Dictionary = _evaluar_destino(_arrastre, slot["puesto_id"])
		if veredicto["puede"]:
			nodo.modulate = Color.WHITE
			nodo.add_theme_stylebox_override("panel", _estilo_slot(ocupado, true))
			borde.visible = not ocupado
			borde.color = KitUIComisarioScript.MOD_COLOR_ACENTO
			borde.grosor = 3.0
			borde.queue_redraw()
			var agente_arrastrado: RefCounted = _arrastre.get("agente", null)
			var impacto: String = _texto_impacto(agente_arrastrado, slot["puesto_id"])
			var desplazado: RefCounted = veredicto.get("intercambio_con", null)
			if desplazado != null:
				# Destino ocupado pero válido: la pastilla del motivo se recicla en ACENTO para
				# anunciar el intercambio y su impacto (qué gana o pierde el servicio — petición
				# del usuario 2026-08-17).
				pastilla_motivo.visible = true
				var lbl_intercambio: Label = slot["lbl_motivo"]
				lbl_intercambio.text = (
					"Intercambiar con %s" % desplazado.nombre
					+ ("" if impacto == "" else " — %s" % impacto)
				)
				lbl_intercambio.add_theme_color_override(
					"font_color", KitUIComisarioScript.MOD_COLOR_ACENTO
				)
			else:
				pastilla_motivo.visible = false
			if lbl_vacante != null:
				lbl_vacante.text = (
					"Suelta aquí para asignar" if impacto == ""
					else "Soltar aquí — %s" % impacto
				)
				lbl_vacante.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_ACENTO)
		else:
			nodo.modulate = Color(1.0, 1.0, 1.0, OPACIDAD_SLOT_INVALIDO)
			nodo.add_theme_stylebox_override("panel", _estilo_slot(ocupado, false))
			pastilla_motivo.visible = true
			var lbl_motivo: Label = slot["lbl_motivo"]
			lbl_motivo.text = String(veredicto["motivo"])
			lbl_motivo.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_GRIS)


## ¿Se puede soltar este payload en este puesto? Devuelve `{"puede": bool, "motivo": String}` — el
## motivo es el texto que se enseña en el slot atenuado y en el aviso si el jugador insiste.
## Replica las reglas REALES de `Personal.asignar` (ocupado, tipo no operable, 2.º Oficial del
## servicio, de baja) más el gate de caja de `contratar` cuando el origen es la academia.
func _evaluar_destino(datos: Variant, puesto_id: StringName) -> Dictionary:
	if not (datos is Dictionary):
		return {"puede": false, "motivo": "no compatible"}
	var payload: Dictionary = datos
	var agente: RefCounted = payload.get("agente", null)
	if agente == null:
		return {"puede": false, "motivo": "no compatible"}
	if StringName(payload.get("puesto_origen", &"")) == puesto_id:
		return {"puede": false, "motivo": "ya está aquí"}
	if agente.estado == AgenteScript.ESTADO_AUSENTE:
		return {"puede": false, "motivo": "de baja hoy"}
	var tipo_agente: Resource = Datos.obtener(&"TipoAgente", agente.tipo_id)
	var tipo_puesto: StringName = _tipo_de_puesto(puesto_id)
	if tipo_agente == null or not (tipo_puesto in tipo_agente.puestos_operables):
		return {"puede": false, "motivo": "no compatible"}
	if agente.rango == AgenteScript.RANGO_OFICIAL and _hay_otro_oficial(agente, puesto_id):
		return {"puede": false, "motivo": "ya hay un Oficial"}
	if String(payload.get("origen", "")) == "academia" and not _hay_caja_para(agente):
		return {"puede": false, "motivo": "sin caja para su sueldo"}
	# Un puesto OCUPADO por alguien compatible NO bloquea (petición del usuario 2026-08-17, al no
	# poder mover a nadie con la plantilla al completo): el movimiento se resuelve en
	# `_soltar_en_puesto` como INTERCAMBIO (el desplazado vuelve al puesto de origen si puede) o
	# SUSTITUCIÓN (va al banquillo). El de baja NO se desplaza: su puesto sigue siendo suyo.
	var ocupante: RefCounted = _personal.agente_de(puesto_id)
	if ocupante != null:
		if ocupante.estado == AgenteScript.ESTADO_AUSENTE:
			return {"puede": false, "motivo": "su titular está de baja"}
		return {"puede": true, "motivo": "", "intercambio_con": ocupante}
	return {"puede": true, "motivo": ""}


## Regla PA2: máximo un Oficial ASIGNADO por servicio. Se comprueba leyendo las asignaciones por la
## API pública (`agente_de` puesto a puesto) — la UI no mira los diccionarios internos de Personal.
func _hay_otro_oficial(agente: RefCounted, puesto_id: StringName) -> bool:
	var servicio: String = _personal.servicio_de_puesto(puesto_id)
	for otro_id: StringName in _puestos_registrados():
		if otro_id == puesto_id:
			continue
		if _personal.servicio_de_puesto(otro_id) != servicio:
			continue
		var ocupante: RefCounted = _personal.agente_de(otro_id)
		if ocupante != null and ocupante != agente and ocupante.rango == AgenteScript.RANGO_OFICIAL:
			return true
	return false


## Gate E4 de Economía tal y como lo aplica `Personal.contratar` (solo comprueba, no cobra).
func _hay_caja_para(candidato: RefCounted) -> bool:
	if _economia == null:
		return true
	return _economia.puede_pagar(_personal.salario_dia(candidato))


## Medias de Rapidez y Trato de los agentes EN PUESTO de un servicio, aplicando `sustituciones`
## (puesto_id → agente, o null para dejarlo vacante) sobre la foto actual — la base del "qué gana
## o pierde el servicio" que pidió el usuario (2026-08-17) antes de confirmar un movimiento.
## Rapidez y Trato son los dos atributos que rinden EN el puesto (velocidad de atención y nota de
## trato); Salud y Motivación actúan en bajas/cansancio y no cambian por mover a alguien de sitio.
func _medias_servicio(servicio: String, sustituciones: Dictionary = {}) -> Dictionary:
	var suma_rapidez: float = 0.0
	var suma_trato: float = 0.0
	var n: int = 0
	for puesto_id: StringName in _puestos_registrados():
		if _personal.servicio_de_puesto(puesto_id) != servicio:
			continue
		var quien: RefCounted = _personal.agente_de(puesto_id)
		if sustituciones.has(puesto_id):
			quien = sustituciones[puesto_id]
		if quien == null:
			continue
		suma_rapidez += float(quien.rapidez)
		suma_trato += float(quien.trato)
		n += 1
	if n == 0:
		return {"rapidez": 0.0, "trato": 0.0, "n": 0}
	return {"rapidez": suma_rapidez / n, "trato": suma_trato / n, "n": n}


## "Rapidez 4,0 → 3,5 · Trato 3,0 → 3,2": antes/después de las medias del servicio DESTINO si
## `agente` acabara en `puesto_id`. En un movimiento dentro del MISMO servicio, la foto de después
## incluye al desplazado volviendo al puesto de origen (el intercambio completo, no media verdad).
func _texto_impacto(agente: RefCounted, puesto_id: StringName) -> String:
	if agente == null:
		return ""
	var servicio: String = _personal.servicio_de_puesto(puesto_id)
	var sustituciones: Dictionary = {puesto_id: agente}
	var origen: StringName = agente.puesto_id
	if origen != &"" and origen != puesto_id and _personal.servicio_de_puesto(origen) == servicio:
		sustituciones[origen] = _personal.agente_de(puesto_id)   # null si el destino estaba vacante
	var antes: Dictionary = _medias_servicio(servicio)
	var despues: Dictionary = _medias_servicio(servicio, sustituciones)
	if int(despues["n"]) == 0:
		return ""
	if int(antes["n"]) == 0:
		# Primera dotación del servicio: no hay "antes" que comparar — los valores a secas.
		return "Rapidez %s · Trato %s" % [_cifra(despues["rapidez"]), _cifra(despues["trato"])]
	return "Rapidez %s → %s · Trato %s → %s" % [
		_cifra(antes["rapidez"]), _cifra(despues["rapidez"]),
		_cifra(antes["trato"]), _cifra(despues["trato"]),
	]


## Un decimal y coma castellana ("3,5") — mismo criterio que el resto de cifras de la UI.
func _cifra(valor: float) -> String:
	return ("%.1f" % valor).replace(".", ",")


## Soltar sobre un slot: ORDENA por la API pública y repinta. Un rechazo NUNCA es silencioso.
## Sobre un puesto OCUPADO (2026-08-17): el Core no tiene intercambio, así que la UI lo COMPONE con
## las llamadas públicas — desasignar a ambos, colocar al que llega y devolver al desplazado a su
## puesto de origen (INTERCAMBIO); si no hay origen o el Core no le deja operar allí, el desplazado
## queda en el banquillo (SUSTITUCIÓN) y se dice en el aviso.
func _soltar_en_puesto(datos: Variant, puesto_id: StringName) -> void:
	_arrastre = {}
	var veredicto: Dictionary = _evaluar_destino(datos, puesto_id)
	if not bool(veredicto["puede"]):
		_avisar("No se puede asignar en ese puesto: %s" % String(veredicto["motivo"]))
		_reconstruir()
		return
	var payload: Dictionary = datos
	var agente: RefCounted = payload["agente"]
	if String(payload.get("origen", "")) == "academia":
		var indice: int = _personal.mercado.find(agente)
		if indice < 0 or not _personal.contratar(indice):
			_avisar("No hay caja para el sueldo de %s — no se ha contratado." % agente.nombre)
			_reconstruir()
			return
	var puesto_previo: StringName = agente.puesto_id
	var desplazado: RefCounted = _personal.agente_de(puesto_id)
	if desplazado != null:
		_personal.desasignar(desplazado)
	if puesto_previo != &"" or agente.estado == AgenteScript.ESTADO_CUBRIENDO:
		_personal.desasignar(agente)
	if _personal.asignar(agente, puesto_id):
		if desplazado == null:
			_avisar("")
		elif puesto_previo != &"" and _personal.asignar(desplazado, puesto_previo):
			_avisar("")   # intercambio limpio: cada uno en el puesto del otro
		else:
			_avisar("%s pasa al banquillo." % desplazado.nombre)
	else:
		# Red de seguridad: si el Core rechaza pese al veredicto, se deshace el movimiento entero
		# en vez de dejar a nadie tirado sin decirlo.
		if desplazado != null:
			_personal.asignar(desplazado, puesto_id)
		if puesto_previo != &"":
			_personal.asignar(agente, puesto_previo)
		_avisar("El sistema rechazó la asignación de %s (regla del Core)." % agente.nombre)
	_seleccionar(agente)
	_reconstruir()


## El "fantasma" que sigue al cursor mientras se arrastra (`set_drag_preview`): copia reducida de la
## tarjeta, con el ancla al CENTRO del cursor (por defecto Godot lo pega por la esquina).
func _fantasma(agente: RefCounted) -> Control:
	var ancla := Control.new()
	ancla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tarjeta: PanelContainer = KitUIComisarioScript.moderno_tarjeta(
		true, KitUIComisarioScript.MOD_RADIO_PEQUENO
	)
	# Tamaño FIJO (el de la maqueta, 230×58): el fantasma se coloca antes de que el layout mida nada,
	# así que su centro tiene que ser un número conocido, no un `size` todavía a cero.
	var medida := Vector2(230.0, 58.0)
	tarjeta.custom_minimum_size = medida
	tarjeta.size = medida
	tarjeta.position = -medida * 0.5
	ancla.add_child(tarjeta)
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_right", 12)
	tarjeta.add_child(margen)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	margen.add_child(fila)
	fila.add_child(_avatar(agente, 30.0, false))
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	caja.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(caja)
	caja.add_child(_etiqueta(agente.nombre, 13, KitUIComisarioScript.MOD_COLOR_TINTA, true))
	caja.add_child(_etiqueta(_subtitulo_agente(agente), 10, KitUIComisarioScript.MOD_COLOR_GRIS))
	_ignorar_raton(ancla)
	return ancla


# ══ DESPLEGABLE PROPIO "Mover a" (alternativa de CLIC al arrastre) ═══════════════════════════════
## Menú estilizado con el kit (nunca el `PopupMenu` nativo gris): lista los puestos con su estado y
## deja DESHABILITADOS los no válidos CON el motivo escrito, más "Al banquillo" en primer lugar si el
## agente está colocado.
func _abrir_desplegable_mover(agente: RefCounted, boton: Button) -> void:
	for hijo: Node in _tarjeta_desplegable.get_children():
		hijo.queue_free()
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	_tarjeta_desplegable.add_child(caja)
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 8)
	margen.add_theme_constant_override("margin_right", 8)
	margen.add_theme_constant_override("margin_top", 8)
	margen.add_theme_constant_override("margin_bottom", 8)
	caja.add_child(margen)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 2)
	margen.add_child(lista)

	if agente.puesto_id != &"" or agente.estado == AgenteScript.ESTADO_CUBRIENDO:
		lista.add_child(_opcion_desplegable("Al banquillo", true, "", func() -> void:
			_ordenar_desasignar(agente)
		))
		lista.add_child(_linea())
	var datos: Dictionary = {"origen": "ficha", "agente": agente, "puesto_origen": agente.puesto_id}
	var grupos: Array[Dictionary] = _agrupar_puestos()
	var alguna: bool = false
	for grupo: Dictionary in grupos:
		var puestos: Array[StringName] = grupo["puestos"]
		var nombres: Array[String] = grupo["nombres"]
		for i: int in puestos.size():
			var puesto_id: StringName = puestos[i]
			var veredicto: Dictionary = _evaluar_destino(datos, puesto_id)
			var puede: bool = veredicto["puede"]
			var motivo: String = veredicto["motivo"]
			var etiqueta: String
			if puede:
				etiqueta = nombres[i]
				# Ocupado pero válido = intercambio; y SIEMPRE el impacto en el servicio destino
				# (qué gana o pierde con el cambio — petición del usuario 2026-08-17).
				var desplazado: RefCounted = veredicto.get("intercambio_con", null)
				if desplazado != null:
					etiqueta += " — intercambiar con %s" % desplazado.nombre
				var impacto: String = _texto_impacto(agente, puesto_id)
				if impacto != "":
					etiqueta += "   ·   %s" % impacto
			else:
				etiqueta = "%s — %s" % [nombres[i], motivo]
			lista.add_child(_opcion_desplegable(
				etiqueta, puede, motivo, func() -> void: _soltar_en_puesto(datos, puesto_id)
			))
			alguna = alguna or puede
	if grupos.is_empty():
		lista.add_child(_etiqueta(
			"No hay ventanillas construidas.", 11, KitUIComisarioScript.MOD_COLOR_GRIS
		))
	elif not alguna:
		lista.add_child(_etiqueta(
			"Ningún puesto compatible disponible ahora mismo.", 10,
			KitUIComisarioScript.MOD_COLOR_GRIS
		))

	_capa_desplegable.visible = true
	# Posición: justo bajo el botón, y volteado hacia arriba si no cabe (el modal llega casi al borde).
	var vista: Vector2 = _capa_desplegable.get_viewport_rect().size
	var medida: Vector2 = _tarjeta_desplegable.get_combined_minimum_size()
	var origen: Vector2 = boton.get_global_rect().position
	var y: float = origen.y + boton.size.y + 6.0
	if y + medida.y > vista.y:
		y = maxf(8.0, origen.y - medida.y - 6.0)
	_tarjeta_desplegable.size = medida
	_tarjeta_desplegable.position = Vector2(
		clampf(origen.x, 8.0, maxf(8.0, vista.x - medida.x - 8.0)), y
	)


## Una opción del desplegable. Deshabilitada = botón atenuado CON el motivo (en el texto y en el
## tooltip): nunca una opción muerta sin explicación.
func _opcion_desplegable(
	texto: String, habilitada: bool, motivo: String, accion: Callable
) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.focus_mode = Control.FOCUS_NONE
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	boton.disabled = not habilitada
	boton.tooltip_text = motivo
	boton.add_theme_font_size_override("font_size", 12)
	boton.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_TINTA)
	boton.add_theme_color_override("font_hover_color", KitUIComisarioScript.MOD_COLOR_ACENTO)
	boton.add_theme_color_override("font_disabled_color", KitUIComisarioScript.MOD_COLOR_GRIS)
	var plano := StyleBoxFlat.new()
	plano.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	plano.content_margin_left = 10.0
	plano.content_margin_right = 24.0
	plano.content_margin_top = 6.0
	plano.content_margin_bottom = 6.0
	var hover: StyleBoxFlat = plano.duplicate()
	hover.bg_color = KitUIComisarioScript.MOD_COLOR_ACENTO_SUAVE
	hover.set_corner_radius_all(8)
	boton.add_theme_stylebox_override("normal", plano)
	boton.add_theme_stylebox_override("disabled", plano)
	boton.add_theme_stylebox_override("hover", hover)
	boton.add_theme_stylebox_override("pressed", hover)
	if habilitada:
		boton.pressed.connect(func() -> void:
			_cerrar_desplegable()
			accion.call()
		)
	return boton


func _cerrar_desplegable() -> void:
	if _capa_desplegable != null:
		_capa_desplegable.visible = false


# ══ ÓRDENES (la UI solo llama a la API pública de Personal — ADR-0001) ═══════════════════════════
## Contratar un candidato de la academia (sin puesto: entra al banquillo). El gate E4 de Economía
## puede rechazarlo → motivo VISIBLE.
func _ordenar_contratar(candidato: RefCounted) -> void:
	var indice: int = _personal.mercado.find(candidato)
	if indice < 0:
		_reconstruir()
		return
	if _personal.contratar(indice):
		_avisar("")
		_agente_seleccionado = candidato   # el objeto es el mismo, ahora en plantilla
	else:
		_avisar("No hay caja para el sueldo de %s — no se ha contratado." % candidato.nombre)
	_reconstruir()


func _ordenar_desasignar(agente: RefCounted) -> void:
	_personal.desasignar(agente)
	_avisar("")
	_reconstruir()


func _ordenar_despedir(agente: RefCounted) -> void:
	_personal.despedir(agente)
	_avisar("")
	if _agente_seleccionado == agente:
		_agente_seleccionado = null
	_reconstruir()


## Aviso de rechazo en la cabecera (cadena vacía = se apaga). SIEMPRE texto, nunca solo color.
func _avisar(texto: String) -> void:
	if _lbl_aviso == null:
		return
	_lbl_aviso.text = texto
	_lbl_aviso.visible = texto != ""


# ══ Utilidades de lectura y de construcción de Controls ══════════════════════════════════════════
## Un Label del lenguaje moderno (tamaño, color y peso explícitos; la fuente la hereda del Theme).
func _etiqueta(texto: String, tam: int, color: Color, negrita: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", tam)
	lbl.add_theme_color_override("font_color", color)
	if negrita:
		lbl.add_theme_font_override("font", KitUIComisarioScript.moderno_fuente(true))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


## Línea divisoria de 1 px del color de raíl del kit (la maqueta separa cabecera / cuerpo / ficha).
func _linea() -> Panel:
	var linea := Panel.new()
	linea.custom_minimum_size.y = 1.0
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_LINEA
	linea.add_theme_stylebox_override("panel", estilo)
	return linea


## Avatar redondo con la inicial (kit): acento si el agente está al pie del cañón, gris si está de
## baja o es un candidato que todavía no es de la casa.
func _avatar(agente: RefCounted, lado: float, apagado: bool) -> Control:
	var inicial: String = agente.nombre.substr(0, 1).to_upper() if agente.nombre != "" else "?"
	var circulo: Control = KitUIComisarioScript.moderno_circulo_simbolo(
		inicial,
		KitUIComisarioScript.MOD_COLOR_GRIS if apagado else KitUIComisarioScript.MOD_COLOR_ACENTO,
		Color.WHITE, lado
	)
	# Sin encoger: dentro de un HBox el flag vertical por defecto es FILL y el círculo se estiraba
	# a óvalo (auditado en la primera captura de la implementación, 2026-08-17).
	circulo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	circulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return circulo


## "Documentación · Policía": el perfil legible del catálogo + el rango en llano.
func _subtitulo_agente(agente: RefCounted) -> String:
	return "%s · %s" % [_nombre_tipo_agente(agente.tipo_id), _rango_legible(agente.rango)]


func _texto_salario(agente: RefCounted) -> String:
	return "%.0f €/día" % _personal.salario_dia(agente)


## Cuántas pausas le quedan hoy y de cuánto (sale de su Motivación). Sin este dato, un agente al
## 100 % de cansancio que sigue plantado en la ventanilla parece un bug: se le acabó el cupo.
func _texto_pausas(agente: RefCounted) -> String:
	var totales: int = _personal.pausas_de(agente)
	var restantes: int = maxi(totales - agente.pausas_gastadas, 0)
	return "Pausas hoy: %d de %d (de %d min)" % [
		restantes, totales, _personal.minutos_de_pausa(agente),
	]


## ¿Está al pie del cañón? (para apagar el color de su tarjeta si no). Un AUSENTE, no.
func _en_pie(agente: RefCounted) -> bool:
	return agente.estado != AgenteScript.ESTADO_AUSENTE


## Estado legible + color de refuerzo: `{"texto": String, "color": Color}`. El texto va SIEMPRE (el
## color es refuerzo, nunca la única señal — respaldo daltónico).
func _estado_legible(agente: RefCounted) -> Dictionary:
	match agente.estado:
		AgenteScript.ESTADO_ASIGNADO:
			return {"texto": "Asignado", "color": KitUIComisarioScript.MOD_COLOR_VERDE}
		AgenteScript.ESTADO_CUBRIENDO:
			return {"texto": "Cubriendo", "color": KitUIComisarioScript.MOD_COLOR_AZUL_CUBRIENDO}
		AgenteScript.ESTADO_AUSENTE:
			return {
				"texto": "De baja — sin cobertura" if agente.puesto_id != &"" else "De baja hoy",
				"color": KitUIComisarioScript.MOD_COLOR_GRIS,
			}
		AgenteScript.ESTADO_DESCANSANDO:
			return {
				"texto": "De descanso — vuelve en %d min" % roundi(
					_personal.minutos_de_descanso_restantes(agente)
				),
				"color": KitUIComisarioScript.MOD_COLOR_AMBAR,
			}
		_:
			return {"texto": "En el banquillo", "color": KitUIComisarioScript.MOD_COLOR_AMBAR}


## Nombre legible de un perfil de agente (el catálogo usa `puesto_organico` como nombre visible).
func _nombre_tipo_agente(tipo_id: StringName) -> String:
	var tipo: Resource = Datos.obtener(&"TipoAgente", tipo_id)
	return tipo.puesto_organico if tipo != null else String(tipo_id)


## Nombre visible de un TIPO de puesto del catálogo (para "Opera: …").
func _nombre_tipo_puesto(tipo_id: StringName) -> String:
	var tipo: Resource = Datos.obtener(&"TipoPuesto", tipo_id)
	return tipo.nombre if tipo != null else String(tipo_id)


## Los tipos de puesto que este perfil sabe operar, en legible y unidos con ", ".
func _operables_legibles(tipo_id: StringName) -> String:
	var tipo: Resource = Datos.obtener(&"TipoAgente", tipo_id)
	if tipo == null:
		return ""
	var nombres: Array[String] = []
	for t: StringName in tipo.puestos_operables:
		nombres.append(_nombre_tipo_puesto(t))
	return ", ".join(nombres)


func _rango_legible(rango: StringName) -> String:
	return "Oficial" if rango == AgenteScript.RANGO_OFICIAL else "Policía"


## Borra los hijos de una lista (`queue_free` — se limpian al final del frame).
func _vaciar(lista: VBoxContainer) -> void:
	for hijo: Node in lista.get_children():
		hijo.queue_free()


## Deja que los clics ATRAVIESEN todo el contenido decorativo de una tarjeta: si un hijo se los
## queda, la tarjeta ni se selecciona ni empieza a arrastrar (gotcha: `MOUSE_FILTER_STOP` es el valor
## por defecto de casi todo Control). Los botones REALES que cuelgan después sí paran el clic.
func _ignorar_raton(raiz: Node) -> void:
	for hijo: Node in raiz.get_children():
		if hijo is Control:
			(hijo as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignorar_raton(hijo)


# ══ Clases internas ══════════════════════════════════════════════════════════════════════════════
## Tarjeta que participa en el drag & drop nativo y en la selección por clic. Sirve de ORIGEN
## (`datos_arrastre` no vacío), de DESTINO (`puede_soltar`/`al_soltar`) o de las dos cosas (un slot
## ocupado). Es una sola clase a propósito: un slot es ambas cosas y duplicarla invitaba a que las dos
## copias se desincronizaran.
class TarjetaInteractiva extends PanelContainer:
	## Payload del arrastre (`{"origen", "agente", "puesto_origen"}`). Vacío = no se arrastra.
	var datos_arrastre: Dictionary = {}
	## Devuelve el Control "fantasma" que sigue al cursor (`set_drag_preview`).
	var fabricar_fantasma: Callable = Callable()
	## Avisa a la pantalla de que empieza un arrastre (para iluminar/atenuar los slots).
	var al_empezar_arrastre: Callable = Callable()
	## Clic izquierdo: rellena la ficha inferior.
	var al_seleccionar: Callable = Callable()
	## `bool` — ¿acepta este payload? (pinta el cursor de Godot y decide si `_drop_data` se llama).
	var puede_soltar: Callable = Callable()
	## Ejecuta el drop.
	var al_soltar: Callable = Callable()
	## Avisa del FIN de un arrastre (por si se suelta en el vacío y hay realces que apagar).
	var al_terminar_arrastre: Callable = Callable()

	func _init() -> void:
		# Explícito: sin `STOP` ni se arrastra ni se selecciona esta tarjeta (el valor por defecto de
		# un Container ha cambiado entre versiones de Godot — mejor no depender de él).
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _get_drag_data(_posicion: Vector2) -> Variant:
		if datos_arrastre.is_empty():
			return null
		if fabricar_fantasma.is_valid():
			set_drag_preview(fabricar_fantasma.call())
		if al_empezar_arrastre.is_valid():
			al_empezar_arrastre.call(datos_arrastre)
		return datos_arrastre

	func _can_drop_data(_posicion: Vector2, datos: Variant) -> bool:
		if not puede_soltar.is_valid():
			return false
		return bool(puede_soltar.call(datos))

	func _drop_data(_posicion: Vector2, datos: Variant) -> void:
		if al_soltar.is_valid():
			al_soltar.call(datos)

	func _gui_input(evento: InputEvent) -> void:
		if not (evento is InputEventMouseButton):
			return
		var raton: InputEventMouseButton = evento
		if raton.pressed and raton.button_index == MOUSE_BUTTON_LEFT and al_seleccionar.is_valid():
			al_seleccionar.call()
			accept_event()

	## Fin de arrastre: Godot lo notifica a TODOS los Controls, así que el slot hace también de
	## soplón por si el drop cae en el vacío (sin esto los realces se quedarían encendidos). El
	## receptor es idempotente: solo el primero en llegar repinta.
	func _notification(que: int) -> void:
		if que == NOTIFICATION_DRAG_END and al_terminar_arrastre.is_valid():
			al_terminar_arrastre.call()


## La raíz del modal. Existe solo para enterarse del final de un arrastre (`NOTIFICATION_DRAG_END`)
## incluso si el jugador suelta fuera de cualquier slot.
class PanelRaiz extends PanelContainer:
	var al_terminar_arrastre: Callable = Callable()

	func _notification(que: int) -> void:
		if que == NOTIFICATION_DRAG_END and al_terminar_arrastre.is_valid():
			al_terminar_arrastre.call()
