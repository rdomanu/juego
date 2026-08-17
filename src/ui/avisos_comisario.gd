class_name AvisosComisario
extends CanvasLayer
## AvisosComisario — la PILA DE AVISOS (toasts) del juego: lo que el jugador tiene que enterarse
## AUNQUE no esté mirando el sitio exacto donde ha pasado (F3, última pieza de la interfaz moderna).
##
## Maqueta vinculante: `design/ux/maquetas-menu-2026-08/maqueta_avisos.png` (+ su mockup ejecutable
## `maqueta_avisos.py`, que trae el mapeo señal→aviso en la cabecera). Spec:
## `design/ux/menu-avisos-spec.md`.
##
## NO confundir con `HudComisario.avisar()`: aquella es la franja de feedback CONTEXTUAL de una
## acción del jugador ("no puedes construir aquí"), vive en el HUD y se dispara desde `Main` a mano.
## Esto es otra cosa: EVENTOS DEL BUS que ocurren solos mientras juegas (una deuda, una reclamación,
## una baja). Las dos conviven y ninguna llama a la otra.
##
## Tres decisiones de arquitectura que conviene leer antes de tocar nada:
##
## 1. **El mapeo señal→severidad vive AQUÍ**, no en `Main`. `configurar(bus)` es quien conecta.
##    Motivo: el mapeo es una decisión de UX (¿esto merece interrumpir?, ¿con qué severidad?) y el
##    texto que se enseña se compone a partir de los datos de la señal — las dos cosas son de esta
##    pantalla. `Main` solo hace `configurar(EventBus)`, así que el sistema es autocontenido y los
##    tests le inyectan un bus falso sin tocar `Main`. Contrapartida asumida: `Main` no puede
##    "filtrar" avisos; si algún día hiciera falta, se hace con un parámetro de `configurar`.
## 2. **Solo ESCUCHA, jamás muta** (ADR-0001): no llama a ningún sistema Core, no cambia estado de
##    juego. Un toast es un espejo del bus.
## 3. **Sin animación de entrada/salida.** Aparece y desaparece, sin fundido ni deslizamiento
##    (`accessibility-requirements.md`: nada de parpadeos ni movimiento gratuito; además así no hay
##    ninguna animación que "saltarse"). La única pieza que se mueve es la barra fina de progreso del
##    autodesvanecido, que avanza en una sola dirección y a velocidad constante.
##
## Ejemplo (API pública, la misma que usa el mapeo del bus por dentro):
##     avisos.avisar_evento(AvisosComisario.SEV_CRITICO, "Saldo en números rojos", "-1.240 €")

## `class_name` no resuelve en headless frío (gotcha del proyecto) → SIEMPRE `preload`.
const KitUIComisarioScript := preload("res://src/ui/kit_ui_comisario.gd")
## Las cotas REALES del HUD moderno (no números copiados): el margen de la barra flotante.
const HudComisarioScript := preload("res://src/ui/hud_comisario.gd")
## El nombre VISIBLE de una ventanilla ("DNI 1") sale de UNA sola fuente en todo el juego.
const PanelPersonalScript := preload("res://src/main/panel_personal.gd")

# ── Severidades (forma + color + texto; el color NUNCA es la única señal) ─────────────────────────
## Círculo "i", acento azul, autodesvanecido rápido. Comunicado sin urgencia.
const SEV_INFO := &"info"
## Globo de diálogo con "!", ámbar, autodesvanecido lento. Algo que ha pasado y te afecta.
const SEV_AVISO := &"aviso"
## Triángulo de alerta, rojo, PERSISTENTE con su botón "×". Exige lectura/acción del jugador.
const SEV_CRITICO := &"critico"

# ── Geometría (de `maqueta_avisos.py`) ───────────────────────────────────────────────────────────
## Ancho de la columna de avisos (maqueta: 380 — deliberadamente MENOR que los 460 de la ficha de
## ventanilla: una pila de avisos no necesita tanto aire como una ficha de datos).
const ANCHO_PILA: float = 380.0
## Aire estándar de la interfaz moderna: contra el borde de la ventana y contra la ficha. Es el mismo
## margen con el que ya vive la barra flotante del HUD (fuente real, no un 12 copiado a mano).
const MARGEN: float = HudComisarioScript.MARGEN_BARRA_FLOTANTE
## Borde inferior REAL de la barra flotante del HUD, medido en captura: 12 de margen + 92 de alto
## efectivo de la tarjeta (`ALTO_BARRA_FLOTANTE` se queda corto porque los módulos crecen con su
## contenido). Con el 88 teórico, el toast crítico pisaba la franja baja de los chips
## Plantilla/Documentación — auditoría contra la maqueta, 2026-08-18.
const BORDE_INFERIOR_HUD: float = 104.0
## Ancla vertical de la pila: estrictamente POR DEBAJO del HUD, para no tapar NUNCA un chip mientras
## lees un aviso (116 en la maqueta aprobada).
const Y0_PILA: float = BORDE_INFERIOR_HUD + MARGEN
## Separación entre tarjetas de la pila (maqueta: 12).
const SEPARACION_TARJETAS: int = 12
## Aire interior de una tarjeta (maqueta: `pad = 16`).
const PADDING_TARJETA: float = 16.0
## Lado de la pastilla circular del icono y hueco hasta el texto (maqueta: 40 y 12).
const LADO_ICONO: float = 40.0
const HUECO_ICONO_TEXTO: int = 12
## Radio de esquina de la tarjeta (maqueta: 16 — el mismo del kit moderno).
const RADIO_TARJETA: float = KitUIComisarioScript.MOD_RADIO_TARJETA
## Alto de la barra fina del autodesvanecido (maqueta: 3 px de relleno).
const ALTO_BARRA: float = 4.0
## Lado del botón "×" de un aviso persistente.
const LADO_BOTON_CERRAR: float = 22.0
## Por encima del HUD (layer 1) y a la altura de la ficha de ventanilla (11), por debajo de los
## modales (12) — un modal SÍ debe tapar la pila; el juego no.
const LAYER_AVISOS: int = 11

# ── Aforo de la pila ─────────────────────────────────────────────────────────────────────────────
## Cuántos avisos se ven a la vez. Más de 4 y la columna se come la pantalla (con la ficha abierta,
## 4 tarjetas ya llegan a media altura). Los que sobran ESPERAN turno, no se pierden.
const MAX_VISIBLES: int = 4
## Tope de la cola de espera: si se desborda se descarta el MÁS VIEJO (un evento de hace un minuto ya
## no es noticia; el reciente sí). Evita que una tormenta de eventos deje la pila escupiendo avisos
## caducados durante minutos.
const MAX_ESPERA: int = 12

## Duraciones del autodesvanecido, en SEGUNDOS de reloj real, por severidad. `0` = PERSISTENTE (no se
## va solo: hay que cerrarlo con su "×"). Es una `var` y no una `const` a propósito
## (data-driven-friendly): un futuro fichero de configuración o una opción de accesibilidad
## ("dame más tiempo para leer") puede subirlas sin tocar este código —
## `avisos.duraciones[AvisosComisario.SEV_INFO] = 12.0`.
var duraciones: Dictionary[StringName, float] = {
	SEV_INFO: 6.0,
	SEV_AVISO: 9.0,
	SEV_CRITICO: 0.0,
}

## Se emite cada vez que un aviso APARECE en la pila. Para el sistema de audio (que debe disparar su
## evento de sonido, nunca un `AudioStreamPlayer` desde aquí) y para los tests.
signal aviso_mostrado(severidad: StringName, titulo: String)

## El bus inyectado (`configurar`). Solo se le ESCUCHA.
var _bus: Node = null
## La ficha de ventanilla (`PanelVentanilla`), opcional: si está visible, la pila se aparta a su
## izquierda. Se pide por `borde_izquierdo()`, así que cualquier panel con ese método sirve (los
## tests inyectan uno mínimo).
var _ficha: CanvasLayer = null
## `Personal`, opcional: solo para traducir el id técnico de un puesto ("doc_1") al rótulo que ve el
## jugador ("DNI 1"). Sin él, el aviso enseña el id tal cual (honesto y feo, nunca inventado).
var _personal: Node = null

## La columna: un `VBoxContainer` colocado a mano (las anclas bajo `CanvasLayer` no son fiables en
## este proyecto). Compacta la pila sola al retirar una tarjeta — de ahí que sea un contenedor y no
## tarjetas posicionadas a mano.
var _pila: VBoxContainer = null
## Avisos en cola cuando la pila está llena: `[{severidad, titulo, detalle}]`.
var _espera: Array[Dictionary] = []


# ══ API pública ══════════════════════════════════════════════════════════════════════════════════
## Conecta el sistema al bus de eventos con el MAPEO de la maqueta (ver la tabla de
## `design/ux/menu-avisos-spec.md`). Idempotente: llamarlo dos veces no duplica conexiones.
func configurar(bus: Node) -> void:
	if _bus != null or bus == null:
		return
	_bus = bus
	# CRÍTICOS (persistentes): alarmas que siguen activas después del aviso.
	bus.entro_en_deuda.connect(_al_entrar_en_deuda)
	bus.insolvencia.connect(_al_insolvencia)
	bus.gracia_iniciada.connect(_al_gracia_iniciada)
	bus.game_over.connect(_al_game_over)
	# AVISOS (autodesvanecidos): ha pasado algo que te afecta y podrías no estar mirando.
	bus.salio_de_deuda.connect(_al_salir_de_deuda)
	bus.reclamacion_generada.connect(_al_reclamacion)
	bus.prestamo_pedido.connect(_al_prestamo_pedido)
	# MIXTO: el parte del Oficial sube a AVISO si algo quedó SIN cubrir (requiere decisión).
	bus.parte_personal.connect(_al_parte_personal)
	# INFO (autodesvanecidos): comunicados.
	bus.aviso_division.connect(_al_aviso_division)
	bus.incidencia_personal.connect(_al_incidencia_personal)


## Inyecta la ficha de ventanilla para que la pila se aparte cuando esté abierta. Opcional: sin ella
## la pila se ancla al borde derecho de la ventana y todo lo demás funciona igual.
func usar_ficha(ficha: CanvasLayer) -> void:
	_ficha = ficha
	if ficha != null and not ficha.visibility_changed.is_connected(_al_cambiar_ficha):
		ficha.visibility_changed.connect(_al_cambiar_ficha)
	_recolocar()


## Inyecta `Personal` (opcional) para poder nombrar los puestos como los ve el jugador.
func usar_personal(personal: Node) -> void:
	_personal = personal


## Publica un aviso. ES LA ÚNICA PUERTA: el mapeo del bus, los tests y cualquier pantalla futura
## entran por aquí. `severidad` es una de las tres constantes `SEV_*`; `detalle` puede ir vacío.
func avisar_evento(severidad: StringName, titulo: String, detalle: String = "") -> void:
	var sev: StringName = severidad
	if not duraciones.has(sev):
		push_warning("AvisosComisario: severidad desconocida '%s' → se trata como info" % sev)
		sev = SEV_INFO
	if _pila == null:
		# Todavía sin árbol (alguien avisó antes del `_ready`): a la cola, se verá al construirse.
		_encolar({"severidad": sev, "titulo": titulo, "detalle": detalle})
		return
	if _pila.get_child_count() >= MAX_VISIBLES:
		_encolar({"severidad": sev, "titulo": titulo, "detalle": detalle})
		return
	_mostrar({"severidad": sev, "titulo": titulo, "detalle": detalle})


## Cuántos avisos hay ahora mismo EN PANTALLA (los de la cola de espera no cuentan).
func avisos_visibles() -> int:
	return 0 if _pila == null else _pila.get_child_count()


## Cuántos avisos hay esperando turno.
func avisos_en_espera() -> int:
	return _espera.size()


## Cierra todos los avisos (los persistentes también) y vacía la cola. Lo usa el arranque de una
## partida cargada: los avisos de la partida anterior no pintan nada en la nueva.
func limpiar() -> void:
	_espera.clear()
	if _pila == null:
		return
	for hijo: Node in _pila.get_children():
		_pila.remove_child(hijo)
		hijo.queue_free()
	set_process(false)


# ══ Ciclo de vida ════════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	layer = LAYER_AVISOS
	# Un aviso se apaga aunque el juego esté en PAUSA (Espacio, o el modal del Comisario): si no, una
	# pausa larga dejaría la pila congelada y el jugador volvería a una columna de avisos caducados.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_ui()
	set_process(false)
	# Lo que llegó antes de tener árbol (o antes del primer frame) entra ahora.
	_rellenar_desde_espera()


func _crear_ui() -> void:
	_pila = VBoxContainer.new()
	_pila.name = "PilaAvisos"
	# La tipografía moderna de golpe: sin el Theme del kit, cada Label hereda la pixelada en
	# mayúsculas del tema global (gotcha cazado en F1).
	_pila.theme = KitUIComisarioScript.moderno_tema()
	_pila.add_theme_constant_override("separation", SEPARACION_TARJETAS)
	_pila.custom_minimum_size = Vector2(ANCHO_PILA, 0.0)
	add_child(_pila)
	get_viewport().size_changed.connect(_recolocar)
	_recolocar()


## La barra de progreso del autodesvanecido. NO acumula deltas: lee el `time_left` del `Timer` de
## cada tarjeta (el reloj es del SceneTree, la barra solo lo retrata). Solo corre mientras haya
## alguna tarjeta con reloj.
func _process(_delta: float) -> void:
	var alguno_vivo: bool = false
	for tarjeta: Node in _pila.get_children():
		var reloj: Timer = tarjeta.get_node_or_null("Reloj") as Timer
		var barra: Control = tarjeta.get_node_or_null("Cuerpo/Barra") as Control
		if reloj == null or barra == null or reloj.wait_time <= 0.0:
			continue
		alguno_vivo = true
		KitUIComisarioScript.moderno_actualizar_barra_progreso(
			barra, reloj.time_left / reloj.wait_time
		)
	if not alguno_vivo:
		set_process(false)


# ══ Colocación ═══════════════════════════════════════════════════════════════════════════════════
## Ancla la pila arriba-derecha, bajo el HUD. Con la ficha de ventanilla ABIERTA se aparta a su
## izquierda (mismo margen que contra el borde de la ventana): nunca se solapan y el jugador sigue
## viendo las dos cosas. Se recalcula al abrir/cerrar la ficha y al redimensionar la ventana.
func _recolocar() -> void:
	if _pila == null:
		return
	var vista: Vector2 = _pila.get_viewport_rect().size
	var limite_derecho: float = vista.x - MARGEN
	if _ficha != null and _ficha.visible and _ficha.has_method("borde_izquierdo"):
		limite_derecho = float(_ficha.borde_izquierdo()) - MARGEN
	_pila.position = Vector2(limite_derecho - ANCHO_PILA, Y0_PILA)
	_pila.size.x = ANCHO_PILA


func _al_cambiar_ficha() -> void:
	# Diferido: al pasar de oculta a visible, la ficha todavía no ha recolocado su propio panel.
	_recolocar.call_deferred()


# ══ Pila ═════════════════════════════════════════════════════════════════════════════════════════
## Orden de la pila: el MÁS VIEJO arriba, el nuevo se añade ABAJO (el orden de la maqueta: el
## crítico de la deuda —que venía de antes— encabeza la columna). Así una tarjeta que estás leyendo
## NUNCA se mueve de sitio por culpa de una nueva; solo sube cuando la de encima desaparece.
func _mostrar(datos: Dictionary) -> void:
	var severidad: StringName = datos["severidad"]
	var tarjeta: PanelContainer = _crear_tarjeta(
		severidad, String(datos["titulo"]), String(datos["detalle"])
	)
	_pila.add_child(tarjeta)
	var segundos: float = duraciones.get(severidad, 0.0)
	if segundos > 0.0:
		var reloj := Timer.new()
		reloj.name = "Reloj"
		reloj.one_shot = true
		reloj.wait_time = segundos
		tarjeta.add_child(reloj)
		reloj.timeout.connect(func() -> void: _retirar(tarjeta))
		reloj.start()
		set_process(true)
	aviso_mostrado.emit(severidad, String(datos["titulo"]))


func _encolar(datos: Dictionary) -> void:
	_espera.append(datos)
	while _espera.size() > MAX_ESPERA:
		_espera.pop_front()


## Retira una tarjeta y deja entrar a la siguiente en espera. El `VBoxContainer` compacta la columna
## solo (por eso la pila es un contenedor y no tarjetas colocadas a mano).
func _retirar(tarjeta: Node) -> void:
	if tarjeta == null or not is_instance_valid(tarjeta) or tarjeta.get_parent() != _pila:
		return
	_pila.remove_child(tarjeta)
	tarjeta.queue_free()
	_rellenar_desde_espera()


func _rellenar_desde_espera() -> void:
	while not _espera.is_empty() and _pila != null and _pila.get_child_count() < MAX_VISIBLES:
		var datos: Dictionary = _espera.pop_front()
		_mostrar(datos)


# ══ Una tarjeta ══════════════════════════════════════════════════════════════════════════════════
## Tarjeta blanca con sombra (kit moderno), icono de severidad en su pastilla de color suave, título
## + detalle, y —según severidad— la "×" con el rótulo "Persistente" o la barra del autodesvanecido.
func _crear_tarjeta(severidad: StringName, titulo: String, detalle: String) -> PanelContainer:
	var persistente: bool = duraciones.get(severidad, 0.0) <= 0.0
	var color: Color = _color_de(severidad)
	var tarjeta := PanelContainer.new()
	tarjeta.name = "Toast"
	tarjeta.set_meta("severidad", severidad)
	tarjeta.set_meta("persistente", persistente)
	tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_TARJETA
	estilo.set_corner_radius_all(int(RADIO_TARJETA))
	estilo.shadow_size = 10
	estilo.shadow_color = Color(0.039, 0.055, 0.094, 0.18)
	estilo.shadow_offset = Vector2(0.0, 4.0)
	estilo.content_margin_left = PADDING_TARJETA
	estilo.content_margin_right = PADDING_TARJETA
	estilo.content_margin_top = PADDING_TARJETA
	estilo.content_margin_bottom = PADDING_TARJETA
	if persistente:
		# Borde rojo fino: el respaldo de "esto sigue activo" ADEMÁS del icono y del rótulo.
		estilo.set_border_width_all(2)
		estilo.border_color = color
	tarjeta.add_theme_stylebox_override("panel", estilo)

	var cuerpo := VBoxContainer.new()
	cuerpo.name = "Cuerpo"   # ruta estable "Cuerpo/Barra" para `_process` (nada de `%` sin owner)
	cuerpo.add_theme_constant_override("separation", 8)
	tarjeta.add_child(cuerpo)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", HUECO_ICONO_TEXTO)
	cuerpo.add_child(fila)
	fila.add_child(_crear_pastilla_icono(severidad, color))

	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	textos.add_theme_constant_override("separation", 2)
	fila.add_child(textos)
	textos.add_child(_etiqueta(
		"Titulo", titulo, 14, KitUIComisarioScript.MOD_COLOR_TINTA, true
	))
	if detalle != "":
		textos.add_child(_etiqueta(
			"Detalle", detalle, 12, KitUIComisarioScript.MOD_COLOR_GRIS, false
		))

	if persistente:
		fila.add_child(_crear_lateral_persistente(tarjeta))
	else:
		var barra: Control = KitUIComisarioScript.moderno_barra_progreso(
			1.0, color, ANCHO_PILA - 2.0 * PADDING_TARJETA, ALTO_BARRA
		)
		barra.name = "Barra"
		cuerpo.add_child(barra)
	return tarjeta


## Pastilla circular de color suave con el glifo de la severidad dentro (forma DISTINTA por
## severidad: triángulo / globo / círculo — el color es refuerzo, nunca la única señal).
func _crear_pastilla_icono(severidad: StringName, color: Color) -> PanelContainer:
	var pastilla := PanelContainer.new()
	pastilla.name = "PastillaIcono"
	pastilla.custom_minimum_size = Vector2(LADO_ICONO, LADO_ICONO)
	pastilla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pastilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = _color_fondo_de(severidad)
	estilo.set_corner_radius_all(int(LADO_ICONO / 2.0))
	pastilla.add_theme_stylebox_override("panel", estilo)
	var centro := CenterContainer.new()
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastilla.add_child(centro)
	var glifo: Control = KitUIComisarioScript.moderno_glifo(
		_glifo_de(severidad), color, LADO_ICONO * 0.56
	)
	glifo.name = "Glifo"
	centro.add_child(glifo)
	return pastilla


## Columna derecha de un aviso PERSISTENTE: la "×" arriba y el rótulo "Persistente" abajo. El rótulo
## es texto de verdad (no solo el borde rojo): explica POR QUÉ este aviso no se va solo.
func _crear_lateral_persistente(tarjeta: PanelContainer) -> VBoxContainer:
	var lateral := VBoxContainer.new()
	lateral.name = "Lateral"
	lateral.add_theme_constant_override("separation", 4)
	var cerrar := Button.new()
	cerrar.name = "BotonCerrar"
	cerrar.text = ""
	cerrar.tooltip_text = "Cerrar este aviso"
	cerrar.focus_mode = Control.FOCUS_NONE   # gotcha: con foco, el Espacio deja de pausar el juego
	cerrar.custom_minimum_size = Vector2(LADO_BOTON_CERRAR, LADO_BOTON_CERRAR)
	cerrar.size_flags_horizontal = Control.SIZE_SHRINK_END
	cerrar.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	cerrar.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	cerrar.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	cerrar.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	cerrar.pressed.connect(func() -> void: _retirar(tarjeta))
	# `Button` NO es un contenedor (gotcha del proyecto): el glifo se ancla a mano al rectángulo.
	var aspa: Control = KitUIComisarioScript.moderno_glifo(
		KitUIComisarioScript.GlifoModerno.Tipo.ASPA, KitUIComisarioScript.MOD_COLOR_GRIS, 12.0
	)
	aspa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cerrar.add_child(aspa)
	lateral.add_child(cerrar)
	var hueco := Control.new()
	hueco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lateral.add_child(hueco)
	# SIN el helper `_etiqueta`: su autowrap en esta columna estrecha partía la palabra en vertical
	# ("Persi/stent/e", cazado en captura 2026-08-18). Sin envoltura, el mínimo del Label ES el
	# texto entero y la columna se ensancha a su medida.
	var rotulo := Label.new()
	rotulo.name = "Persistente"
	rotulo.text = "Persistente"
	rotulo.add_theme_font_override("font", KitUIComisarioScript.moderno_fuente(true))
	rotulo.add_theme_font_size_override("font_size", 9)
	rotulo.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_GRIS)
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lateral.add_child(rotulo)
	return lateral


## Un `Label` del lenguaje moderno. `autowrap` SIEMPRE con `SIZE_EXPAND_FILL` (gotcha del proyecto:
## un Label con autowrap y sin ancho asignado no envuelve, se estira hasta romper la fila).
func _etiqueta(
	nombre: String, texto: String, tam: int, color: Color, negrita: bool
) -> Label:
	var etiqueta := Label.new()
	etiqueta.name = nombre
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta.add_theme_font_override("font", KitUIComisarioScript.moderno_fuente(negrita))
	etiqueta.add_theme_font_size_override("font_size", tam)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


func _color_de(severidad: StringName) -> Color:
	match severidad:
		SEV_CRITICO:
			return KitUIComisarioScript.MOD_COLOR_ROJO
		SEV_AVISO:
			return KitUIComisarioScript.MOD_COLOR_AMBAR_TEXTO
		_:
			return KitUIComisarioScript.MOD_COLOR_ACENTO


func _color_fondo_de(severidad: StringName) -> Color:
	match severidad:
		SEV_CRITICO:
			return KitUIComisarioScript.MOD_COLOR_ROJO_SUAVE
		SEV_AVISO:
			return KitUIComisarioScript.MOD_COLOR_AMBAR_SUAVE
		_:
			return KitUIComisarioScript.MOD_COLOR_ACENTO_SUAVE


func _glifo_de(severidad: StringName) -> int:
	match severidad:
		SEV_CRITICO:
			return KitUIComisarioScript.GlifoModerno.Tipo.TRIANGULO_ALERTA
		SEV_AVISO:
			return KitUIComisarioScript.GlifoModerno.Tipo.GLOBO_AVISO
		_:
			return KitUIComisarioScript.GlifoModerno.Tipo.CIRCULO_INFO


# ══ MAPEO señal→aviso ════════════════════════════════════════════════════════════════════════════
# Los textos son los de la maqueta, rellenos con los DATOS REALES de cada señal (dinero por
# `formato_euros`, decimales con coma castellana). La tabla completa —incluidas las señales que
# deliberadamente NO llevan toast— está en `design/ux/menu-avisos-spec.md`.

## Nombre legible del servicio que ORIGINA una reclamación (el id del bus es técnico y sin tildes).
const ORIGENES_LEGIBLES: Dictionary[StringName, String] = {
	&"Documentacion": "Documentación",
	&"ODAC": "ODAC",
	&"Denuncias": "Denuncias",
}
## Motivo legible de una derrota terminal.
const MOTIVOS_GAME_OVER: Dictionary[StringName, String] = {
	&"insolvencia": "insolvencia sin salvavidas — te echan de la comisaría",
}


func _al_entrar_en_deuda(saldo: float) -> void:
	avisar_evento(
		SEV_CRITICO, "Saldo en números rojos",
		"%s · gasto voluntario bloqueado hasta salir de deuda" % _euros(saldo)
	)


func _al_insolvencia(saldo: float, prestamos_restantes: int) -> void:
	var salvavidas: String = "no te queda ningún préstamo del Comisario"
	if prestamos_restantes == 1:
		salvavidas = "te queda 1 préstamo del Comisario"
	elif prestamos_restantes > 1:
		salvavidas = "te quedan %d préstamos del Comisario" % prestamos_restantes
	avisar_evento(
		SEV_CRITICO, "Insolvencia: el Comisario ha parado el juego",
		"%s · %s" % [_euros(saldo), salvavidas]
	)


func _al_gracia_iniciada(minutos: float) -> void:
	avisar_evento(
		SEV_CRITICO, "Ventana de gracia en marcha",
		"%s min de juego para volver a números negros" % _numero(minutos)
	)


func _al_game_over(motivo: StringName) -> void:
	avisar_evento(
		SEV_CRITICO, "Fin de la partida",
		"Motivo: %s" % MOTIVOS_GAME_OVER.get(motivo, String(motivo))
	)


func _al_salir_de_deuda(saldo: float) -> void:
	avisar_evento(
		SEV_AVISO, "De vuelta a números negros",
		"%s · gasto voluntario desbloqueado" % _euros(saldo)
	)


func _al_reclamacion(origen: StringName) -> void:
	avisar_evento(
		SEV_AVISO, "Nueva reclamación",
		"%s · por una espera larga" % ORIGENES_LEGIBLES.get(origen, String(origen))
	)


func _al_prestamo_pedido(usados: int, vivos: int) -> void:
	var restantes: String = "no te queda ningún salvavidas"
	if vivos == 1:
		restantes = "te queda 1 salvavidas"
	elif vivos > 1:
		restantes = "te quedan %d salvavidas" % vivos
	avisar_evento(
		SEV_AVISO, "Préstamo del Comisario concedido",
		"%d pedido%s · %s" % [usados, "" if usados == 1 else "s", restantes]
	)


## El parte del Oficial sube a AVISO cuando algo quedó SIN cubrir (`escaladas` > 0 = requiere una
## decisión del jugador); si el Oficial lo resolvió todo, es un INFO.
func _al_parte_personal(resumen: Dictionary) -> void:
	var escaladas: int = int(resumen.get("escaladas", 0))
	var ausencias: int = int(resumen.get("ausencias", 0))
	var cubiertas: int = int(resumen.get("cubiertas", 0))
	var servicio: String = String(resumen.get("servicio", ""))
	var cola: String = (
		"%d sin cubrir · requiere decisión" % escaladas if escaladas > 0 else "todo cubierto"
	)
	avisar_evento(
		SEV_AVISO if escaladas > 0 else SEV_INFO,
		"Parte del Oficial · %s" % servicio,
		"%d ausencias · %d cubiertas · %s" % [ausencias, cubiertas, cola]
	)


func _al_aviso_division(_evento_id: StringName, nombre: String, activo: bool) -> void:
	if activo:
		avisar_evento(
			SEV_INFO, "Comunicado de la División",
			"%s · autoriza ampliar el horario más allá del tope ordinario" % nombre
		)
	else:
		avisar_evento(SEV_INFO, "Fin del comunicado", "%s · vuelve el tope de horario ordinario" % nombre)


## `puesto` con valor por defecto A PROPÓSITO: `Personal` emite hoy una de sus incidencias (la pausa
## de descanso) con UN solo argumento, y un `Callable` con defecto sobrevive a esa emisión corta en
## vez de tragarse el aviso. (Anotado como incidencia de Core en la spec — no se toca desde la UI.)
func _al_incidencia_personal(texto: String, puesto: StringName = &"") -> void:
	var detalle: String = "" if puesto == &"" else "Deja %s" % _nombre_puesto(puesto)
	avisar_evento(SEV_INFO, texto, detalle)


# ══ Formato ══════════════════════════════════════════════════════════════════════════════════════
## Dinero: la MISMA fuente que el resto de la UI ("-1.240 €").
func _euros(valor: float) -> String:
	return KitUIComisarioScript.formato_euros(valor)


## Número con coma castellana y sin decimales inútiles (30 → "30"; 22.5 → "22,5").
func _numero(valor: float) -> String:
	if is_equal_approx(valor, roundf(valor)):
		return "%d" % int(roundf(valor))
	return ("%.1f" % valor).replace(".", ",")


## Rótulo de una ventanilla tal y como lo ve el jugador ("DNI 1"), con el MISMO criterio y el mismo
## recorrido que `PanelVentanilla.nombre_visible`/`PanelHorario._nombres_visibles` — para que la
## ventanilla se llame igual en las tres pantallas. Sin `Personal` inyectado devuelve el id técnico
## tal cual: deliberadamente honesto y feo, nunca un nombre bonito inventado.
func _nombre_puesto(puesto_id: StringName) -> String:
	if _personal == null or puesto_id == &"":
		return String(puesto_id)
	var tipo: StringName = _personal.tipo_de_puesto(puesto_id)
	var prefijo: String = PanelPersonalScript.PREFIJO_POR_TIPO_PUESTO.get(tipo, "")
	if prefijo == "":
		return String(puesto_id)
	var servicio: String = _personal.servicio_de_puesto(puesto_id)
	var ordinal: int = 0
	for otro: StringName in _personal.puestos_de_servicio(StringName(servicio)):
		if PanelPersonalScript.PREFIJO_POR_TIPO_PUESTO.get(_personal.tipo_de_puesto(otro), "") != prefijo:
			continue
		ordinal += 1
		if otro == puesto_id:
			break
	return PanelPersonalScript.nombre_visible_de_puesto(puesto_id, tipo, ordinal)
