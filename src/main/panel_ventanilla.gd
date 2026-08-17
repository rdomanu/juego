class_name PanelVentanilla extends CanvasLayer
## PanelVentanilla — la FICHA de una ventanilla, al pulsar sobre ella.
##
## Petición del usuario (2026-07-31): *"al pulsar en alguna ventanilla debería poder verse como un
## menú donde se ponga la eficacia del puesto, un resumen de la persona que lo atienda, qué denuncias
## coge… tipo tycoon cuando se pulsa sobre algo y se detalla"*.
##
## **F3 (2026-08-18)**: el andamio de texto plano se sustituye por la maqueta APROBADA
## `design/ux/maquetas-menu-2026-08/maqueta_ventanilla.png` (script hermano vinculante:
## `maqueta_ventanilla.py`) — el mismo lenguaje moderno que el Tablón de Destinos
## (`panel_personal.gd`) y el Horario (`panel_horario.gd`): tarjeta clara, tipografía Segoe UI del
## kit, un único acento azul y **cero hex sueltos** (todo sale de `KitUIComisario`). El contrato con
## `Main` NO cambia: misma clase, mismo archivo, `configurar(flujo, personal, construccion, odac,
## documentacion)`, `mostrar(puesto_id)` desde el clic izquierdo y cierre con Esc.
##
## ── QUÉ TIENE QUE CONTESTAR ESTA PANTALLA ─────────────────────────────────────────────────────
## Una ficha de tycoon no es una lista de números: es la respuesta a *"¿por qué esta ventanilla va
## así?"*. Por eso los datos se dan **descompuestos**, no agregados:
##
##   No basta con "tarda 14,2 min". Hay que ver que 12 son del trámite, que su agente le suma un 8 %
##   porque va cansado, y que el equipo informático le quita un 5 %. Así el jugador sabe **qué
##   tocar**: mandarle al café, o comprarle un ordenador mejor.
##
## Reglas del proyecto (control-manifest, Presentation): la UI **lee** el estado y **ordena** por la
## API pública — nunca muta el modelo (ADR-0001).
##
## ── ⚠️ LA FICHA ESTÁ PARTIDA EN DOS, Y ES IMPORTANTE ──────────────────────────────────────────
## `_caja_viva` son **solo etiquetas** (lo que cambia solo: quién atiende, cuánto queda, el
## cansancio) y se repinta entera en cada frame. `_caja_mandos` son **los controles** (botones,
## casillas, barras) y se construye UNA vez.
##
## Sin esa separación, la ficha se reconstruía 60 veces por segundo **con los botones dentro**: cada
## control se destruía antes de que al clic le diera tiempo a completarse, y **no se podía pulsar
## nada**. Lo reportó el usuario el 2026-07-31 (*"no se puede editar nada en el menú"*). Regla que
## deja: **jamás reconstruir por frame un contenedor que tenga controles interactivos.**
##
## ── DOS DESVIACIONES DELIBERADAS DE LA MAQUETA (auditoría F3) ─────────────────────────────────
## 1. **La ficha empieza por DEBAJO de la barra del HUD** (`HudComisario.ALTO_PANEL_SUPERIOR`), no
##    pegada al borde superior: si la tapara, el jugador perdería de vista el saldo justo mientras
##    decide gastar. Abajo sigue dejando libre la franja de acciones (`HUECO_BARRA_HUD`).
## 2. **El marcador de selección se pinta sobre la MESA REAL** (`MarcadorVentanilla`, capa suelta del
##    mundo), no dibujado dentro de la ficha: en la maqueta es un adorno, en el juego tiene que
##    señalar *cuál* de las ventanillas estás mirando.
##
## Es una ficha CONTEXTUAL: sin velo, el juego sigue corriendo detrás y ella se refresca en vivo.
##
## spec `design/ux/menu-ventanilla-spec.md` · ADR-0001

## `class_name` no resuelve en headless frío (gotcha del proyecto) → SIEMPRE `preload`.
const KitUIComisarioScript := preload("res://src/ui/kit_ui_comisario.gd")
## El nombre VISIBLE de una ventanilla ("DNI 1") y el del servicio ("Documentación") salen de UNA
## sola fuente en todo el juego: los helpers estáticos del Tablón de Destinos.
const PanelPersonalScript := preload("res://src/main/panel_personal.gd")
## Las cotas REALES del HUD moderno (no números copiados): de dónde a dónde puede ocupar la ficha.
const HudComisarioScript := preload("res://src/ui/hud_comisario.gd")

# ── Geometría (de `maqueta_ventanilla.py`, con las dos desviaciones de la cabecera) ───────────────
## Ancho de la columna (maqueta: 476 − 16 = 460 px).
const ANCHO_FICHA: float = 460.0
## Aire contra el borde derecho de la ventana (maqueta: 16).
const MARGEN_LATERAL: float = 16.0
## Aire entre la barra flotante del HUD y la ficha.
const MARGEN_BAJO_HUD: float = 12.0
## Hueco que se deja abajo para la franja de acciones del HUD (60 px) más su aire.
const HUECO_BARRA_HUD: float = 100.0
## Aire interior de la tarjeta (maqueta: `pad = 24`).
const PADDING_FICHA: float = 24.0
## Radio del marco de la ficha (maqueta: 20).
const RADIO_FICHA: float = 20.0
## Lado del botón de cierre (la "X" de la cabecera; maqueta: 30).
const LADO_BOTON_CERRAR: float = 30.0
## Lado de la casilla "se queda por la tarde" (el mismo que el panel de Horario).
const LADO_CASILLA: float = 18.0
## Alto de la banda de un slider compacto y de la fila de extremos que va debajo.
const ALTO_SLIDER_COMPACTO: float = 22.0
## Por debajo de los modales (Personal/Horario van en `layer = 12`) y por encima del HUD (`layer`
## por defecto 1) y del panel de construcción (1 y su preview en 2): la ficha CONVIVE, no tapa.
## 11 y no 8: la brújula de depuración vive en la 10 y se pintaba ENCIMA de la ficha (cazado en
## captura 2026-08-18); por debajo de los modales (12), que sí deben taparla.
const LAYER_FICHA: int = 11

## Umbrales de la barra de cansancio, los MISMOS que usa el muñeco en el mundo: lo que ve el jugador
## en la ficha y lo que ve sobre la cabeza tienen que hablar el mismo idioma.
const CANSANCIO_ALTO: float = 66.0
const CANSANCIO_MEDIO: float = 33.0
## Paso del slider de cierre, en minutos (cuartos de hora: el horario de una oficina no se decide al
## minuto — el mismo paso que el panel de la tecla H).
const PASO_CIERRE_MIN: int = 15

# ── Refs a los sistemas Core (inyectadas por Main; la UI solo lee y ordena — ADR-0001) ───────────
var _flujo: Node = null
var _personal: Node = null
var _construccion: Node = null
var _odac: Node = null
var _documentacion: Node = null
## El realce en el mundo de la ventanilla abierta (`MarcadorVentanilla`, lo crea Main). Opcional: sin
## él la ficha funciona igual, simplemente no se señala la mesa (tests headless).
var _marcador: Node2D = null

var _puesto_id: StringName = &""
var _panel: PanelContainer
## Cabecera y chip de estado: NO se reconstruyen (son fijos), solo se les cambia el texto/color.
var _lbl_titulo: Label
var _punto_estado: Panel
var _lbl_chip: Label
## Solo etiquetas: se repinta cada frame (no hay nada que pulsar, así que no se rompe nada).
var _caja_viva: VBoxContainer
## Los controles: se construye una vez al abrir y al cambiar algo que los afecte.
var _caja_mandos: VBoxContainer
## Donde se cuelgan las dos, para poder reconstruirlas por separado.
var _caja: VBoxContainer
## A qué caja va lo que se está dibujando ahora mismo (la viva o la de mandos).
var _destino: VBoxContainer


## Inyección de dependencias (la llama Main tras `add_child`). Firma INTACTA desde el andamio.
func configurar(
	flujo: Node, personal: Node, construccion: Node, odac: Node, documentacion: Node
) -> void:
	_flujo = flujo
	_personal = personal
	_construccion = construccion
	_odac = odac
	_documentacion = documentacion


## Inyecta el marcador del mundo DESPUÉS de `configurar` (Main crea la capa junto al resto del
## mundo, no junto a los paneles). Mismo patrón que `PanelHorario.usar_flujo`.
func usar_marcador(marcador: Node2D) -> void:
	_marcador = marcador


func _ready() -> void:
	layer = LAYER_FICHA
	_crear_ui()
	visible = false
	# Un solo sitio para apagar el realce del mundo: se cierre por donde se cierre (Esc, la X, o
	# porque Main esconda la ficha), `visible = false` pasa por aquí.
	visibility_changed.connect(_al_cambiar_visibilidad)
	if _odac != null:
		# Al cambiar un modo, las casillas y los botones cambian de estado: hay que rehacer los
		# MANDOS (no las etiquetas, que se refrescan solas cada frame).
		_odac.modo_cambiado.connect(func(_p: StringName, _m: int) -> void:
			if visible:
				_construir_mandos()
		)


## Abre la ficha de un puesto. La llama Main al pulsar sobre una ventanilla del mundo.
func mostrar(puesto_id: StringName) -> void:
	_puesto_id = puesto_id
	visible = true
	_recolocar_panel()
	# Y otra vez al final del frame: al pasar de OCULTO a visible los contenedores todavía no han
	# re-medido a sus hijos (bug del "menú fantasma" ya cazado en `ModoConstruccion._recolocar_panel`).
	_recolocar_panel.call_deferred()
	_construir_mandos()
	_refrescar_vivo()
	_encender_marcador()


func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento is InputEventKey and evento.pressed and (evento as InputEventKey).keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()


## Refresca SOLO las etiquetas: es una ficha en vivo (el cansancio sube, la atención avanza). Los
## controles NO se tocan aquí — ver el aviso de la cabecera. Con el panel cerrado no hace nada.
func _process(_delta: float) -> void:
	if visible:
		_refrescar_vivo()


# ══ Construcción de la UI (por código — el proyecto no usa .tscn salvo Main) ═════════════════════
func _crear_ui() -> void:
	_panel = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_PANEL
	estilo.set_corner_radius_all(int(RADIO_FICHA))
	estilo.shadow_size = 12
	estilo.shadow_color = Color(0.039, 0.055, 0.094, 0.20)
	estilo.shadow_offset = Vector2(0.0, 6.0)
	estilo.content_margin_left = PADDING_FICHA
	estilo.content_margin_right = PADDING_FICHA
	estilo.content_margin_top = PADDING_FICHA - 2.0
	estilo.content_margin_bottom = PADDING_FICHA - 4.0
	_panel.add_theme_stylebox_override("panel", estilo)
	# La tipografía moderna de golpe: el Theme del kit pone Segoe UI a TODO lo que cuelgue del panel
	# (sin él cada Label hereda la pixelada en mayúsculas del tema global — gotcha cazado en F1).
	_panel.theme = KitUIComisarioScript.moderno_tema()
	add_child(_panel)
	# Las anclas de un Control bajo CanvasLayer no son fiables en este proyecto (gotcha) y los
	# contenedores OCULTOS no re-miden: tamaño y posición se fijan a mano al mostrar y en cada
	# resize de la ventana. Mismo patrón que `PanelPersonal`/`PanelHorario`.
	get_viewport().size_changed.connect(_recolocar_panel)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	_panel.add_child(columna)
	columna.add_child(_crear_cabecera())
	columna.add_child(_crear_chip_estado())
	columna.add_child(_linea_fina())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(scroll)
	_caja = VBoxContainer.new()
	_caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja.add_theme_constant_override("separation", 6)
	scroll.add_child(_caja)
	_caja_viva = VBoxContainer.new()
	_caja_viva.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja_viva.add_theme_constant_override("separation", 4)
	_caja.add_child(_caja_viva)
	_caja_mandos = VBoxContainer.new()
	_caja_mandos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja_mandos.add_theme_constant_override("separation", 4)
	_caja.add_child(_caja_mandos)

	# El botón de cierre va FUERA del scroll: siempre a mano, aunque la ficha de una ODAC con 13
	# denuncias sea más larga que la pantalla.
	columna.add_child(_linea_fina())
	var cerrar: Button = KitUIComisarioScript.moderno_boton_pastilla(
		"Cerrar (Esc)", KitUIComisarioScript.MOD_BOTON_SECUNDARIO, 32.0
	)
	cerrar.name = "BotonCerrar"
	cerrar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cerrar.pressed.connect(func() -> void: visible = false)
	columna.add_child(cerrar)


## Cabecera: nombre del TIPO de puesto (catálogo) + la "X" de cierre.
func _crear_cabecera() -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_lbl_titulo = _etiqueta("", 18, KitUIComisarioScript.MOD_COLOR_TINTA, true, true)
	_lbl_titulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(_lbl_titulo)
	var cerrar := Button.new()
	cerrar.name = "BotonX"
	cerrar.text = ""
	cerrar.tooltip_text = "Cerrar la ficha (Esc)"
	cerrar.focus_mode = Control.FOCUS_NONE   # gotcha: con foco, el Espacio deja de pausar
	cerrar.custom_minimum_size = Vector2(LADO_BOTON_CERRAR, LADO_BOTON_CERRAR)
	cerrar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_TARJETA
	estilo.set_corner_radius_all(8)
	estilo.set_border_width_all(1)
	estilo.border_color = KitUIComisarioScript.MOD_COLOR_LINEA
	cerrar.add_theme_stylebox_override("normal", estilo)
	cerrar.add_theme_stylebox_override("hover", estilo)
	cerrar.add_theme_stylebox_override("pressed", estilo)
	# `Button` NO es un contenedor (gotcha del proyecto): la aspa se ancla a mano al rectángulo.
	var aspa := AspaCierre.new()
	aspa.color = KitUIComisarioScript.MOD_COLOR_GRIS
	aspa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cerrar.add_child(aspa)
	cerrar.pressed.connect(func() -> void: visible = false)
	fila.add_child(cerrar)
	return fila


## Chip de estado: punto de color + "DNI 1 · ATENDIENDO". El texto SIEMPRE junto al punto (respaldo
## daltónico, regla transversal del proyecto: el color nunca es la única señal).
func _crear_chip_estado() -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_punto_estado = Panel.new()
	_punto_estado.custom_minimum_size = Vector2(10.0, 10.0)
	_punto_estado.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_punto_estado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_GRIS
	estilo.set_corner_radius_all(5)
	_punto_estado.add_theme_stylebox_override("panel", estilo)
	fila.add_child(_punto_estado)
	_lbl_chip = _etiqueta("", 12, KitUIComisarioScript.MOD_COLOR_GRIS, true)
	fila.add_child(_lbl_chip)
	return fila


## Coordenada X del borde IZQUIERDO que ocupa (u ocuparía) la ficha, en píxeles de viewport. La pila
## de avisos (`AvisosComisario`) la usa para apartarse a su izquierda mientras la ficha está abierta,
## en vez de copiarse el `ANCHO_FICHA` a mano. Se calcula del viewport y NO del `_panel` a propósito:
## así responde bien aunque se pregunte en el mismo frame en que la ficha se abre (el panel todavía
## no se ha recolocado en ese instante).
func borde_izquierdo() -> float:
	return get_viewport().get_visible_rect().size.x - ANCHO_FICHA - MARGEN_LATERAL


## Recoloca la ficha contra el tamaño REAL del viewport: pegada a la derecha, POR DEBAJO de la barra
## flotante del HUD (para no tapar el saldo) y POR ENCIMA de la franja de acciones.
func _recolocar_panel() -> void:
	if _panel == null or not visible:
		return
	var vista: Vector2 = _panel.get_viewport_rect().size
	var arriba: float = HudComisarioScript.ALTO_PANEL_SUPERIOR + MARGEN_BAJO_HUD
	_panel.position = Vector2(vista.x - ANCHO_FICHA - MARGEN_LATERAL, arriba)
	_panel.size = Vector2(ANCHO_FICHA, maxf(vista.y - arriba - HUECO_BARRA_HUD, 120.0))


# ══ Repintado ════════════════════════════════════════════════════════════════════════════════════
## Las ETIQUETAS que cambian solas. Se repinta entera cada frame: son Labels, no hay nada que
## pulsar, así que reconstruirlas no rompe ninguna interacción.
func _refrescar_vivo() -> void:
	for hijo: Node in _caja_viva.get_children():
		_caja_viva.remove_child(hijo)
		hijo.queue_free()
	if _puesto_id == &"" or _flujo == null:
		return
	# Si la ventanilla ya no existe (demolida con la ficha abierta), la ficha se va con ella: seguir
	# enseñando los números de un mueble que no está sería mentir.
	if _construccion != null and _construccion.celdas_de_elemento(_puesto_id).is_empty():
		visible = false
		return
	var tipo: Resource = Datos.obtener_silencioso(
		&"TipoPuesto", _flujo.tipo_de_puesto_flujo(_puesto_id)
	)
	_lbl_titulo.text = tipo.nombre if tipo != null and tipo.nombre != "" else String(_puesto_id)
	var estado: StringName = _flujo.estado_de_puesto(_puesto_id)
	_lbl_chip.text = "%s · %s" % [nombre_visible(), String(estado).to_upper().replace("_", " ")]
	_fijar_color_punto(_punto_estado, _color_estado(estado))
	_destino = _caja_viva
	_bloque_atendiendo(tipo, estado)
	_separador()
	_bloque_agente()
	_separador()
	_bloque_eficacia(tipo)
	_separador()
	_bloque_cola(tipo)


## LOS CONTROLES. Se construye una vez al abrir la ficha y cuando cambia algo que los afecte (un
## modo de ODAC). Nunca por frame.
func _construir_mandos() -> void:
	for hijo: Node in _caja_mandos.get_children():
		_caja_mandos.remove_child(hijo)
		hijo.queue_free()
	if _puesto_id == &"" or _flujo == null:
		return
	var tipo: Resource = Datos.obtener_silencioso(
		&"TipoPuesto", _flujo.tipo_de_puesto_flujo(_puesto_id)
	)
	_destino = _caja_mandos
	_separador()
	_bloque_atiende(tipo)
	if tipo != null and tipo.servicio == "Documentacion" and _documentacion != null:
		_separador()
		_bloque_horario()


# ── Qué se está gestionando AHORA ────────────────────────────────────────────────────────────
## Petición del usuario (2026-07-31): *"tampoco se ve qué trámite se gestiona"*. Y es el dato más
## vivo de la ficha: no "qué puede atender esta ventanilla" (eso está más abajo), sino **qué está
## haciendo ahora mismo y cuánto le queda**.
func _bloque_atendiendo(tipo: Resource, estado: StringName) -> void:
	_seccion("AHORA MISMO")
	var persona: RefCounted = _flujo.persona_en_puesto(_puesto_id)
	if persona == null:
		# Estados vacíos HONESTOS: "sin nadie" no es lo mismo en una ventanilla cerrada que en una
		# abierta sin agente (una espera clientes, la otra espera a un funcionario).
		match estado:
			&"cerrado":
				_linea("Ventanilla cerrada", KitUIComisarioScript.MOD_COLOR_GRIS, 15, true)
				_linea("No da número ni atiende", KitUIComisarioScript.MOD_COLOR_GRIS, 11)
			&"abierto_sin_agente":
				_linea("Abierta, pero sin agente", KitUIComisarioScript.MOD_COLOR_ROJO, 15, true)
				_linea("Nadie la opera: no despacha a nadie", KitUIComisarioScript.MOD_COLOR_GRIS, 11)
			_:
				_linea("Libre — sin nadie en la ventanilla", KitUIComisarioScript.MOD_COLOR_GRIS, 15, true)
				_linea("Lista para llamar al siguiente", KitUIComisarioScript.MOD_COLOR_GRIS, 11)
		return
	var servicio: StringName = persona.servicio()
	var catalogo: StringName = &"TramiteDoc" if servicio == &"Documentacion" else &"DenunciaODAC"
	var atencion: Resource = Datos.obtener_silencioso(catalogo, persona.tramite_id())
	var nombre: String = (
		atencion.nombre if atencion != null and atencion.nombre != ""
		else String(persona.tramite_id())
	)
	var urgente: bool = (
		_odac != null and servicio == &"ODAC" and _odac.es_prioritaria(persona.tramite_id())
	)
	_linea(
		nombre, KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO if urgente
		else KitUIComisarioScript.MOD_COLOR_TINTA, 16, true
	)
	if urgente:
		_linea("Denuncia prioritaria", KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO, 11, true)
	_linea("Turno nº %d" % persona.numero_turno, KitUIComisarioScript.MOD_COLOR_GRIS, 11)
	# En camino aún no se tramita (enmienda del 2026-07-25): decir "quedan 12 min" de alguien que
	# todavía está cruzando la comisaría sería mentir.
	if persona.estado == &"llamada":
		_linea("Llamado · viene de camino", KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO, 13, true)
	else:
		var quedan: float = _flujo.restante_de_puesto(_puesto_id)
		_linea(
			"Quedan %.0f min de trámite" % quedan, KitUIComisarioScript.MOD_COLOR_VERDE, 13, true
		)
	# Y el siguiente ya llamado, si lo hay (la llamada anticipada).
	var siguiente: RefCounted = _flujo.siguiente_de(_puesto_id)
	if siguiente != null:
		_linea(
			"Siguiente ya llamado: turno nº %d" % siguiente.numero_turno,
			KitUIComisarioScript.MOD_COLOR_GRIS, 11
		)
	# `tipo` no se usa aquí: el trámite en curso manda sobre lo que el puesto ADMITE.


# ── Quién la lleva ───────────────────────────────────────────────────────────────────────────
func _bloque_agente() -> void:
	_seccion("QUIÉN LA LLEVA")
	var agente: RefCounted = null
	if _personal != null and _personal.puesto_dotado(_puesto_id):
		agente = _personal.agente_de(_puesto_id)
	if agente == null:
		_linea("Sin agente asignado", KitUIComisarioScript.MOD_COLOR_ROJO, 15, true)
		_linea(
			"Asígnale uno en Personal (P): una ventanilla sin agente no atiende",
			KitUIComisarioScript.MOD_COLOR_GRIS, 11, false, true
		)
		return
	_linea(agente.nombre, KitUIComisarioScript.MOD_COLOR_TINTA, 16, true)
	_linea("Rapidez %d · Trato %d · Motivación %d" % [
		agente.rapidez, agente.trato, agente.motivacion
	], KitUIComisarioScript.MOD_COLOR_GRIS, 12)
	# El cansancio con su consecuencia AL LADO: "82" no dice nada, "82 (un 21 % más lento)" sí.
	var lento: float = (_personal.mult_cansancio_rendimiento(agente) - 1.0) * 100.0
	var color: Color = KitUIComisarioScript.MOD_COLOR_VERDE
	if agente.cansancio >= CANSANCIO_ALTO:
		color = KitUIComisarioScript.MOD_COLOR_ROJO
	elif agente.cansancio >= CANSANCIO_MEDIO:
		color = KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO
	_linea("Cansancio %d %%  (%+.0f %% más lento)" % [
		roundi(agente.cansancio), lento
	], color, 13, true)
	if _personal.va_de_camino_al_descanso(agente):
		_linea("Va al descanso", KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO, 12)
	elif agente.estado == &"descansando":
		_linea("De café · quedan %d min" % roundi(
			_personal.minutos_de_descanso_restantes(agente)
		), KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO, 12)


# ── Lo bien que rinde, DESCOMPUESTO ──────────────────────────────────────────────────────────
func _bloque_eficacia(tipo: Resource) -> void:
	_seccion("EFICACIA")
	if tipo == null:
		return
	# Se toma la PRIMERA atención que admite como referencia: la ficha compara peras con peras
	# (comparar la media de trámites distintos no diría nada útil).
	var referencia: StringName = &""
	for a: Variant in tipo.atenciones_admitidas:
		referencia = StringName(a)
		break
	if referencia == &"":
		return
	var servicio := StringName(tipo.servicio)
	var catalogo: StringName = &"TramiteDoc" if servicio == &"Documentacion" else &"DenunciaODAC"
	var atencion: Resource = Datos.obtener_silencioso(catalogo, referencia)
	if atencion == null:
		return
	var base: float = float(atencion.duracion_min)
	var efectiva: float = _flujo.duracion_efectiva(servicio, referencia, _puesto_id)
	_linea("%s: %s min" % [
		atencion.nombre if atencion.nombre != "" else String(referencia), _num(efectiva)
	], KitUIComisarioScript.MOD_COLOR_TINTA, 15, true)
	_linea("De catálogo: %s min" % _num(base), KitUIComisarioScript.MOD_COLOR_GRIS, 11)
	# El desglose: de dónde sale la diferencia. Es lo que convierte un número en una decisión.
	if _personal != null and _personal.puesto_dotado(_puesto_id):
		var mod: float = _personal.modificador_produccion_de(_puesto_id)
		_linea("Por su agente: %+.0f %%" % ((mod - 1.0) * 100.0),
			KitUIComisarioScript.MOD_COLOR_VERDE if mod < 1.0
			else KitUIComisarioScript.MOD_COLOR_ROJO, 11)
	var equipo: float = _flujo.mult_equipamiento(_puesto_id)
	if not is_equal_approx(equipo, 1.0):
		_linea("Por el equipamiento: %+.0f %%" % ((equipo - 1.0) * 100.0),
			KitUIComisarioScript.MOD_COLOR_VERDE, 11)
	elif _construccion != null:
		_linea("Sin equipamiento en su sala", KitUIComisarioScript.MOD_COLOR_GRIS, 11)
	# Y el dato que de verdad usa el jugador para dimensionar: cuántos despacha por hora.
	if efectiva > 0.0:
		_linea("≈ %s atenciones/hora" % _num(60.0 / efectiva),
			KitUIComisarioScript.MOD_COLOR_TINTA, 12, true)


# ── Cuánta gente espera ese servicio ─────────────────────────────────────────────────────────
## El grano REAL del dato es el SERVICIO, no la ventanilla: la cola de Documentación es una sola y
## la comparten todas sus ventanillas. Por eso el rótulo lo dice ("EN COLA · DOCUMENTACIÓN") en vez
## de dejar creer que esos 6 son "los suyos".
func _bloque_cola(tipo: Resource) -> void:
	if tipo == null or _flujo == null:
		return
	var servicio: String = String(tipo.servicio)
	var nombre_servicio: String = PanelPersonalScript.NOMBRE_SERVICIO.get(servicio, servicio)
	_seccion("EN COLA · %s" % nombre_servicio.to_upper())
	var en_cola: int = _flujo.personas_en_cola(StringName(servicio))
	if en_cola <= 0:
		_linea("Nadie esperando turno", KitUIComisarioScript.MOD_COLOR_GRIS, 13, true)
		return
	_linea("%d persona%s esperando turno" % [en_cola, "" if en_cola == 1 else "s"],
		KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO, 13, true)


# ── Qué atiende ──────────────────────────────────────────────────────────────────────────────
func _bloque_atiende(tipo: Resource) -> void:
	_seccion("QUÉ ATIENDE")
	if tipo == null:
		return
	# En ODAC lo interesante es el MODO (la palanca de gestión), no la lista de 13 tipos.
	if _odac != null and tipo.servicio == "ODAC":
		_bloque_odac()
		return
	# En Documentación, la lista de trámites que admite.
	var nombres: Array[String] = []
	for a: Variant in tipo.atenciones_admitidas:
		var t: Resource = Datos.obtener_silencioso(&"TramiteDoc", StringName(a))
		nombres.append(t.nombre if t != null and t.nombre != "" else String(a))
	_linea(", ".join(nombres) if not nombres.is_empty() else "—",
		KitUIComisarioScript.MOD_COLOR_TINTA, 13, false, true)


## La rama ODAC, con el MISMO lenguaje moderno que el resto de la ficha: el modo como pastilla
## segmentada del kit (`toggle_segmentado`) y cada denuncia con la casilla dibujada del kit
## (`moderno_casilla`), nunca los `Button`/`CheckBox` del tema global pixel-art.
func _bloque_odac() -> void:
	var modo: int = _odac.modo_de(_puesto_id)
	_linea(String(_odac.NOMBRES_MODO.get(modo, "?")),
		KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO if modo == _odac.Modo.SOLO_PRIORITARIAS
		else KitUIComisarioScript.MOD_COLOR_TINTA, 15, true)
	_linea(String(_odac.AYUDA_MODO.get(modo, "")), KitUIComisarioScript.MOD_COLOR_GRIS, 11, false, true)
	var opciones: Array[Dictionary] = []
	for m: int in [
		_odac.Modo.POLIVALENTE, _odac.Modo.SOLO_PRIORITARIAS, _odac.Modo.SOLO_NORMALES
	]:
		opciones.append({
			"id": StringName("modo_%d" % m), "texto": String(_odac.NOMBRES_MODO[m]),
		})
	var pastilla: PanelContainer = KitUIComisarioScript.toggle_segmentado(opciones, 32.0)
	pastilla.name = "ModosODAC"
	_destino.add_child(pastilla)
	for m: int in [
		_odac.Modo.POLIVALENTE, _odac.Modo.SOLO_PRIORITARIAS, _odac.Modo.SOLO_NORMALES
	]:
		var boton: Button = pastilla.find_child("Opcion_modo_%d" % m, true, false) as Button
		if boton == null:
			continue
		boton.button_pressed = m == modo
		var destino: int = m
		var id: StringName = _puesto_id
		boton.pressed.connect(func() -> void: _odac.fijar_modo(id, destino))
	# LAS DENUNCIAS UNA A UNA (petición del usuario 2026-07-31: *"en ODAC poder seleccionar las
	# denuncias que se cogen en ese puesto"*). Es el modo "a medida", que ya estaba en el modelo y
	# hasta entonces no tenía botones. Marcar una casilla lo pasa a ese modo automáticamente: el
	# jugador no tiene que elegir el modo primero y luego los tipos, que sería un paso de más.
	var marcadas: Array[StringName] = _odac.atenciones_de_modo(modo, _odac.subconjunto_de(_puesto_id))
	_separador()
	_seccion("DENUNCIAS QUE COGE")
	for d: StringName in _odac.denuncias():
		var recurso: Resource = Datos.obtener_silencioso(&"DenunciaODAC", d)
		var urgente: bool = _odac.es_prioritaria(d)
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		# Polivalente = las coge TODAS, aunque por dentro no haya override: se marca todo.
		var casilla: Button = KitUIComisarioScript.moderno_casilla(
			modo == _odac.Modo.POLIVALENTE or marcadas.has(d), LADO_CASILLA
		)
		casilla.name = "Denuncia_%s" % d
		casilla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tipo_d: StringName = d
		casilla.toggled.connect(func(activo: bool) -> void: _alternar_denuncia(tipo_d, activo))
		fila.add_child(casilla)
		var texto: String = (
			recurso.nombre if recurso != null and recurso.nombre != "" else String(d)
		)
		var lbl: Label = _etiqueta(
			texto + (" · prioritaria" if urgente else ""), 12,
			KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO if urgente
			else KitUIComisarioScript.MOD_COLOR_TINTA, false, true
		)
		fila.add_child(lbl)
		_destino.add_child(fila)


## Marca o desmarca una denuncia en ESTE puesto, y lo deja en el modo que corresponda.
##
## La gracia está en el atajo: si estaba en POLIVALENTE (coge todas) y desmarcas una, se calcula la
## lista "todas menos esa" y se pasa a "a medida" solo. El jugador piensa en denuncias, no en modos.
func _alternar_denuncia(denuncia: StringName, activo: bool) -> void:
	var modo: int = _odac.modo_de(_puesto_id)
	var actuales: Array[StringName] = _odac.atenciones_de_modo(modo, _odac.subconjunto_de(_puesto_id))
	if modo == _odac.Modo.POLIVALENTE:
		actuales = _odac.denuncias()   # polivalente = todas, aunque por dentro sea la lista vacía
	var nuevas: Array[StringName] = []
	for d: StringName in actuales:
		if d != denuncia:
			nuevas.append(d)
	if activo:
		nuevas.append(denuncia)
	nuevas.sort()
	# Si vuelve a tenerlas TODAS, es polivalente otra vez (y así no se guarda un override inútil).
	if nuevas.size() == _odac.denuncias().size():
		_odac.fijar_modo(_puesto_id, _odac.Modo.POLIVALENTE)
		return
	# Quitar la última dejaría el puesto sin poder atender nada: se rechaza (lo hace `fijar_modo`) y
	# la casilla se repinta marcada en el siguiente refresco. Cerrar el puesto es otra cosa.
	_odac.fijar_modo(_puesto_id, _odac.Modo.SUBCONJUNTO, nuevas)


# ── El horario del servicio (Documentación) ──────────────────────────────────────────────────
## Petición del usuario (2026-07-31): *"en el menú se tiene que poder elegir el horario de atención
## en Documentación; aumentando el horario se paga peonada, y el precio de peonada, como en el menú
## que hay ya de horario"*.
##
## Es el MISMO horario que el panel de la tecla H —no una copia—: se ordena por la misma API de
## Documentación, así que mover la barra aquí mueve el panel de allí y al revés. Lo que se añade
## desde la ficha es el interruptor **de ESTA ventanilla**: quedarse por la tarde o irse a su hora.
##
## Los sliders son los del kit (`moderno_estilizar_slider`, estrenado en `panel_horario.gd`): aquí
## solo se montan en versión COMPACTA (raíl + extremos rotulados, sin la tarjeta grande) — el estilo
## no se duplica, se reutiliza.
func _bloque_horario() -> void:
	_seccion("HORARIO DEL SERVICIO")
	var base: int = _documentacion.cierre_base_min
	var tope: int = _documentacion.tope_autorizado()
	var lbl_abre: Label = _etiqueta("Abre %s · cierra %s" % [
		_hora(_documentacion.apertura_base_min), _hora(_documentacion.hora_cierre_efectiva())
	], 13, KitUIComisarioScript.MOD_COLOR_TINTA, true)
	lbl_abre.name = "LblAbreCierra"
	_destino.add_child(lbl_abre)
	var barra := HSlider.new()
	barra.name = "SliderCierre"
	barra.min_value = base
	barra.max_value = tope
	barra.step = PASO_CIERRE_MIN   # cuartos de hora: el horario de una oficina no se decide al minuto
	barra.value = _documentacion.hora_cierre_min
	barra.value_changed.connect(func(v: float) -> void: _al_mover_cierre(v))
	_slider_compacto(barra, KitUIComisarioScript.MOD_COLOR_AMBAR, _hora(base), _hora(tope))
	# El COSTE de alargar, en euros al día. Es la mitad de la decisión: sin el número, la barra es
	# una barra; con él, es una compra.
	var lbl_peonada: Label = _etiqueta("", 12, KitUIComisarioScript.MOD_COLOR_ROJO)
	lbl_peonada.name = "LblPeonada"
	_destino.add_child(lbl_peonada)
	# El precio de la hora extra: pagar mejor cansa menos (Bienestar #13).
	var lbl_precio: Label = _etiqueta("", 12, KitUIComisarioScript.MOD_COLOR_TINTA, true)
	lbl_precio.name = "LblPrecio"
	_destino.add_child(lbl_precio)
	var precio := HSlider.new()
	precio.name = "SliderPrecio"
	precio.min_value = _documentacion.peonada_eur_hora_min
	precio.max_value = _documentacion.peonada_eur_hora_max
	precio.step = 1
	precio.value = _documentacion.peonada_eur_hora
	precio.value_changed.connect(func(v: float) -> void: _al_mover_precio(v))
	_slider_compacto(
		precio, KitUIComisarioScript.MOD_COLOR_ACENTO,
		KitUIComisarioScript.formato_euros(_documentacion.peonada_eur_hora_min),
		KitUIComisarioScript.formato_euros(_documentacion.peonada_eur_hora_max)
	)
	_linea("Pagar mejor cansa menos a quien se queda", KitUIComisarioScript.MOD_COLOR_GRIS, 10)
	# Y lo propio de ESTA ventanilla.
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var se_queda: Button = KitUIComisarioScript.moderno_casilla(
		_documentacion.puesto_de_tarde(_puesto_id), LADO_CASILLA
	)
	se_queda.name = "CasillaTarde"
	se_queda.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	se_queda.tooltip_text = "Se queda por la tarde (cobra peonada por las horas extra)"
	var id: StringName = _puesto_id
	se_queda.toggled.connect(
		func(activo: bool) -> void: _documentacion.fijar_puesto_de_tarde(id, activo)
	)
	fila.add_child(se_queda)
	fila.add_child(_etiqueta(
		"Esta ventanilla se queda por la tarde", 12, KitUIComisarioScript.MOD_COLOR_TINTA, true, true
	))
	_destino.add_child(fila)
	# Las dos líneas de dinero nacen VACÍAS y las rellena el mismo código que las repinta al mover un
	# slider: así el texto de construcción y el de actualización no pueden divergir nunca.
	_actualizar_textos_horario()


## El jugador mueve el cierre: se ORDENA a Documentación y se repintan los MANDOS (la peonada y los
## rótulos del bloque de horario cambian de cifra). El repintado va DIFERIDO: reconstruir el slider
## que el jugador tiene agarrado, en mitad de su propia señal, le arrancaría el tirador de la mano.
func _al_mover_cierre(valor: float) -> void:
	if _documentacion == null:
		return
	_documentacion.fijar_hora_cierre(int(valor))
	_repintar_horario()


func _al_mover_precio(valor: float) -> void:
	if _documentacion == null:
		return
	_documentacion.fijar_peonada_eur_hora(valor)
	_repintar_horario()


## Repinta el bloque de horario tras una orden. NO reconstruye `_caja_mandos`: mientras el jugador
## arrastra un slider, destruir y rehacer ese contenedor le arrancaría el tirador de la mano (la
## regla dura de esta pantalla). Solo cambian de texto las etiquetas afectadas.
func _repintar_horario() -> void:
	if not visible:
		return
	_actualizar_textos_horario()


## Actualiza en sitio las dos líneas de dinero del bloque de horario (las únicas que cambian al
## mover un slider). Se localizan por nombre — nada de reconstruir el contenedor con los controles
## dentro (regla dura de esta pantalla).
func _actualizar_textos_horario() -> void:
	var lbl_peonada: Label = _caja_mandos.find_child("LblPeonada", true, false) as Label
	if lbl_peonada != null:
		var coste: float = _documentacion.coste_peonada_estimado()
		if coste > 0.0:
			var agentes: int = _documentacion.num_agentes_doc()
			lbl_peonada.text = "Peonada: %s/día (%s h extra × %d agente%s)" % [
				KitUIComisarioScript.formato_euros(coste), _num(_documentacion.horas_extra()),
				agentes, "" if agentes == 1 else "s",
			]
			lbl_peonada.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_ROJO)
		else:
			lbl_peonada.text = "Sin horas extra: no se paga peonada"
			lbl_peonada.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_GRIS)
	var lbl_precio: Label = _caja_mandos.find_child("LblPrecio", true, false) as Label
	if lbl_precio != null:
		lbl_precio.text = "Precio de la hora extra: %s" % KitUIComisarioScript.formato_euros(
			_documentacion.peonada_eur_hora
		)
	var lbl_abre: Label = _caja_mandos.find_child("LblAbreCierra", true, false) as Label
	if lbl_abre != null:
		lbl_abre.text = "Abre %s · cierra %s" % [
			_hora(_documentacion.apertura_base_min), _hora(_documentacion.hora_cierre_efectiva())
		]


# ══ El realce en el mundo ════════════════════════════════════════════════════════════════════════
## Enciende el marcador sobre la MESA REAL de esta ventanilla: sus celdas de colocación, proyectadas
## a coordenadas de mundo. Sin Construcción o sin marcador (tests headless) no hace nada.
func _encender_marcador() -> void:
	if _marcador == null or _construccion == null or _puesto_id == &"":
		return
	var centros: Array[Vector2] = []
	for celda: Vector2i in _construccion.celdas_de_elemento(_puesto_id):
		centros.append(_construccion.centro_en_pantalla(celda))
	_marcador.resaltar(centros, nombre_visible(), KitUIComisarioScript.moderno_fuente(true))


## Al ocultarse la ficha (por donde sea) se apaga el realce; al enseñarla, se recoloca.
func _al_cambiar_visibilidad() -> void:
	if visible:
		_recolocar_panel()
		return
	if _marcador != null:
		_marcador.limpiar()


# ══ Nombres visibles ═════════════════════════════════════════════════════════════════════════════
## El nombre VISIBLE de esta ventanilla ("DNI 1"), por el helper único del Tablón de Destinos: nunca
## el id técnico "doc_1". El ordinal se cuenta dentro de su propio prefijo, recorriendo los puestos
## del MISMO servicio en el orden estable de registro de Personal (el mismo criterio y el mismo
## recorrido que `PanelHorario._nombres_visibles`, para que la ventanilla se llame igual en las dos
## pantallas).
func nombre_visible() -> String:
	if _personal == null or _puesto_id == &"":
		return String(_puesto_id)
	var tipo: StringName = _personal.tipo_de_puesto(_puesto_id)
	var prefijo: String = PanelPersonalScript.PREFIJO_POR_TIPO_PUESTO.get(tipo, "")
	if prefijo == "":
		return String(_puesto_id)
	var servicio: String = _personal.servicio_de_puesto(_puesto_id)
	var ordinal: int = 0
	for puesto_id: StringName in _personal.puestos_de_servicio(StringName(servicio)):
		var suyo: String = PanelPersonalScript.PREFIJO_POR_TIPO_PUESTO.get(
			_personal.tipo_de_puesto(puesto_id), ""
		)
		if suyo != prefijo:
			continue
		ordinal += 1
		if puesto_id == _puesto_id:
			break
	return PanelPersonalScript.nombre_visible_de_puesto(_puesto_id, tipo, ordinal)


## Color de refuerzo del estado de la ventanilla (el texto del chip va SIEMPRE al lado — el color
## nunca es la única señal).
func _color_estado(estado: StringName) -> Color:
	match estado:
		&"atendiendo":
			return KitUIComisarioScript.MOD_COLOR_VERDE
		&"en_camino":
			return KitUIComisarioScript.MOD_COLOR_AMBAR
		&"libre":
			return KitUIComisarioScript.MOD_COLOR_ACENTO
		&"abierto_sin_agente":
			return KitUIComisarioScript.MOD_COLOR_ROJO
		_:
			return KitUIComisarioScript.MOD_COLOR_GRIS


# ══ Ayudas de construcción y formato ═════════════════════════════════════════════════════════════
## Un minuto del día como "HH:MM".
func _hora(minuto: int) -> String:
	return "%02d:%02d" % [int(minuto / 60.0) % 24, minuto % 60]


## Número corto EN CASTELLANO: sin decimales si es redondo, con uno y COMA si no ("13,1"). El dinero
## NO pasa por aquí — va por `KitUIComisario.formato_euros` (fuente única de toda la UI).
func _num(valor: float) -> String:
	if is_equal_approx(valor, roundf(valor)):
		return "%d" % int(roundf(valor))
	return ("%.1f" % valor).replace(".", ",")


## Rótulo de sección (el "AHORA MISMO" pequeño en gris de la maqueta).
func _seccion(texto: String) -> void:
	var lbl: Label = _etiqueta(texto, 10, KitUIComisarioScript.MOD_COLOR_GRIS, true)
	lbl.name = "Seccion_%s" % texto
	_destino.add_child(lbl)


## Una línea de texto de la ficha (el gemelo moderno del `_linea` del andamio: mismo guion, misma
## secuencia, pero con color/tamaño/peso del kit).
func _linea(
	texto: String, color: Color, tam: int, negrita: bool = false, con_autowrap: bool = false
) -> void:
	_destino.add_child(_etiqueta(texto, tam, color, negrita, con_autowrap))


## Un Label del lenguaje moderno. `con_autowrap` añade el envoltorio por palabras Y el `EXPAND_FILL`
## que necesita para tener ancho (sin él un Label con autowrap sale a UNA PALABRA POR LÍNEA — gotcha
## cazado en el Tablón).
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
	# Ancho: SIEMPRE expandido. Con autowrap es obligatorio, y sin él evita que una línea larga
	# empuje el ancho de la columna (la ficha tiene un ancho fijo).
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


## Separador de secciones: un poco de aire + la línea de 1 px del kit.
func _separador() -> void:
	var hueco := Control.new()
	hueco.custom_minimum_size.y = 4.0
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_destino.add_child(hueco)
	_destino.add_child(_linea_fina())


## Línea divisoria de 1 px del color de raíl del kit.
func _linea_fina() -> Panel:
	var linea := Panel.new()
	linea.custom_minimum_size.y = 1.0
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_LINEA
	linea.add_theme_stylebox_override("panel", estilo)
	return linea


## Monta un slider COMPACTO: el raíl estilizado por el kit + la fila de extremos rotulados debajo
## (la "pista mini" de la maqueta). El slider va dentro de un `Control` de alto fijo con el preset
## `TOP_WIDE` — mismo montaje que las tarjetas del panel de Horario.
func _slider_compacto(slider: HSlider, color: Color, texto_min: String, texto_max: String) -> void:
	KitUIComisarioScript.moderno_estilizar_slider(slider, color)
	var zona := Control.new()
	zona.custom_minimum_size.y = ALTO_SLIDER_COMPACTO
	# El contenedor no recibe el ratón; el slider hijo sí (los hijos siguen recibiendo input).
	zona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_destino.add_child(zona)
	slider.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	slider.offset_bottom = ALTO_SLIDER_COMPACTO
	zona.add_child(slider)
	var fila := HBoxContainer.new()
	var lbl_min: Label = _etiqueta(texto_min, 9, KitUIComisarioScript.MOD_COLOR_GRIS)
	fila.add_child(lbl_min)
	var lbl_max: Label = _etiqueta(texto_max, 9, KitUIComisarioScript.MOD_COLOR_GRIS)
	lbl_max.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila.add_child(lbl_max)
	_destino.add_child(fila)


## Recolorea un punto de estado en caliente (su StyleBox es propio, no compartido).
func _fijar_color_punto(punto: Panel, color: Color) -> void:
	var estilo: StyleBoxFlat = punto.get_theme_stylebox("panel") as StyleBoxFlat
	if estilo != null:
		estilo.bg_color = color


# ══ Clases internas ══════════════════════════════════════════════════════════════════════════════
## La "X" del botón de cierre, DIBUJADA (dos trazos): el glifo unicode ✕ no está garantizado en la
## fuente del sistema y saldría como tofu (gotcha ya cazado con la flecha ▾ del kit).
class AspaCierre extends Control:
	var color: Color = Color(0.478, 0.533, 0.612, 1.0)
	## Margen del aspa contra el borde del botón (maqueta: 9 px sobre un lado de 30).
	const MARGEN: float = 9.0

	func _draw() -> void:
		draw_line(
			Vector2(MARGEN, MARGEN), Vector2(size.x - MARGEN, size.y - MARGEN), color, 2.0, true
		)
		draw_line(
			Vector2(size.x - MARGEN, MARGEN), Vector2(MARGEN, size.y - MARGEN), color, 2.0, true
		)
