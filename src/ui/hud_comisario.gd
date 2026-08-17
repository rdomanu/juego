class_name HudComisario
extends CanvasLayer
## HudComisario — RESKIN F2 (2026-08-16): mismo contrato de datos y los mismos constructores que la
## reconstrucción total del 2026-08-08 (`design/ux/hud-design.md` §1-2/§5/§6 sigue siendo el plano
## de LAYOUT/CONTRATO), pero el ASPECTO visual migra del piloto 9-slice/pixel-art de Summer al KIT
## MODERNO claro (`KitUIComisario.moderno_*`, ya estrenado por `ModoConstruccion` F1) para clavar
## `design/ux/maquetas-menu-2026-08/menu_v3_completo.png` (geometría/colores exactos en el mockup
## ejecutable hermano, `maqueta_hud_v3.py`, de la misma carpeta). SOLO cambian los constructores
## (`_construir_*`/`_crear_*`/`_boton_pildora`/`_etiqueta`/`_espaciador_familia`) y las constantes de
## layout/paleta; el contrato (`configurar`/`refrescar`/`avisar`/`ocultar_acciones`, las 6 señales,
## los nombres `_lbl_*`) es EL MISMO, byte a byte, que consumía `Main` antes de este reskin.
##
## ── Árbol de nodos (F2) ───────────────────────────────────────────────────────────────────────
## HudComisario (CanvasLayer)
## ├─ PanelSuperior (Panel, fondo transparente -- el color vivo está en la barra flotante interior)
## │   -- SIEMPRE visible (spec §1)
## │   └─ Margen(12 por lado, sin margen inferior) → "BarraFlotante" (tarjeta moderna: fondo
## │       MOD_COLOR_PANEL, radio 20, sombra suave -- la pastilla clara que flota sobre el mundo)
## │       └─ Margen(16/16/12/12) → HBoxContainer "fila"
## │           ├─ Módulo Reloj (pastilla blanca: GlifoModerno.RELOJ + hora + "Sem N · Turno T")
## │           ├─ Módulo Velocidad (pastilla blanca: 4 segmentos Pausa/1×/2×/3×, activo = pastilla
## │           │    interior MOD_COLOR_ACENTO_SUAVE detrás del glifo -- MISMO dato que antes, ver
## │           │    la cabecera de `_construir_modulo_velocidad`)
## │           ├─ [espaciador familia]
## │           ├─ Chip Satisfacción (mini-barra + 2 líneas) · Chip Demanda (punto de color + 2
## │           │    líneas) · Chip Plantilla (icono + 2 líneas) · Chip Documentación (icono + 2 líneas)
## │           ├─ [espaciador familia]
## │           ├─ (spacer elástico, SIZE_EXPAND_FILL)
## │           └─ Módulo Saldo (insignia "€" + saldo + Holgado/Justo/Negativo), pegado al borde
## │                derecho de la barra (la brújula de depuración vive en su PROPIA CanvasLayer,
## │                posicionada por debajo de esta barra por `Main._crear_brujula_orientacion` --
## │                ya no necesita un hueco reservado aquí, verificado en `main.gd`)
## └─ PanelAcciones (Panel, fondo plano `COLOR_FONDO_BARRA_INFERIOR` -- DELIBERADAMENTE oscuro
##     todavía, ver la nota de contraste en `_construir_panel_acciones`)   -- OCULTABLE (spec §2)
##     └─ Margen(12/12/10/10) → HBoxContainer "fila"
##         ├─ Label aviso transitorio (SIZE_EXPAND_FILL, empuja las píldoras a la derecha)
##         ├─ Píldora Construir (B, acento) · Píldora Personal (P) · Píldora Horario (H)
##         ├─ [espaciador familia]
##         ├─ Píldora Guardar (F5) · Píldora Cargar (F9)
##         ├─ [espaciador familia]
##         └─ Píldora Paredes: <modo> (Home)
##     Las píldoras ahora son pastillas blancas redondeadas con icono+texto en tinta (kit moderno,
##     `_boton_pildora`) en vez del 9-slice/`theme_type_variation` del piloto.
##
## ── Contrato (ADR-0001: "la UI lee y ordena, nunca muta") ───────────────────────────────────────
## `configurar()` inyecta los sistemas Core de SOLO LECTURA (Economía/Demanda/Personal/Flujo/
## Paciencia/Documentación/ParedesSalas); NINGUNO se muta desde aquí. `refrescar()` se llama UNA
## vez por frame desde `Main._process` — mismo call site que el antiguo `_refrescar_etiquetas()`
## que sustituye (pull, no señales, mismo criterio de rendimiento que ya usaba el HUD viejo: barato
## a esta escala, ver la nota de refresco general de la spec §5). `Tiempo`/`EventBus` son
## autoloads: se leen DIRECTOS (`Tiempo.hhmm(...)`), sin inyección — mismo patrón que el resto de
## `src/main`. NINGUNA función `_refrescar_*` (ni `refrescar`/`configurar`/`avisar`/
## `ocultar_acciones`) se toca en este reskin -- regla dura del encargo F2 ("reskin de
## constructores"). Donde el nuevo layout necesita un dato reactivo que esas funciones NO exponen
## (la fracción de la mini-barra de Satisfacción, el color del punto de Demanda), este archivo lo
## resuelve con su PROPIO `_process()` (nuevo, ver más abajo) leyendo los mismos sistemas Core
## inyectados o el `font_color` que la función bloqueada YA deja pintado en el Label vecino -- nunca
## reimplementando el CÁLCULO (umbral/nivel), solo ESPEJANDO un valor que otro sitio ya decidió.
##
## Los 5 botones de acción NO ejecutan nada aquí: emiten señales y quien decide qué hacer (abrir un
## panel, guardar, ordenar el ciclo de paredes) sigue siendo `Main`, con los MISMOS callbacks que
## ya tenía (`_abrir_personal`/`_abrir_horario`/`_guardar_partida`/`_cargar_partida`/
## `_alternar_modo_paredes`) — "Signals for upward communication" (coding standards del proyecto:
## child→parent, nunca al revés).
##
## ── GAPS del contrato §5, NO inventados (heredados del reskin 2026-08-08, siguen vigentes: el
## contrato de datos no cambia en F2) ─────────────────────────────────────────────────────────────
##   1. "Puerta Doc" (nº de turno llamado/mostrado) — no localizado en `flujo.gd`/`documentacion.
##      gd`. La línea 2 del chip Documentación se reduce a "N atendiendo" (degradación ya prevista
##      en la spec §1.3-[7]).
##   2. Bandera "sin guardar" (dirty) — no localizada en `save_manager.gd`. La píldora Guardar NO
##      lleva el punto "•"/tinte ámbar de §3 (necesitaría una bandera nueva en `SaveManager`, fuera
##      del alcance de este reskin).
##   3. Semáforo 🔴/🟡/🟢 de "cola saturada" (§3) — necesitaría un getter PÚBLICO de aforo en
##      `Flujo` (hoy `_aforo_de` es privado, con guion bajo). Sin él, la UI tendría que inventarse
##      el umbral, que la propia spec prohíbe explícitamente ("el umbral concreto lo posee Flujo,
##      la UI solo pinta la banda, no lo calcula"). Se muestra el conteo real (dentro + "fuera" vía
##      `Flujo.personas_de_cola` filtrando `PersonaFlujo.ESTADO_ESPERANDO_FUERA`, SÍ público) sin
##      el color de semáforo. Follow-up: un `Flujo.aforo_de(servicio) -> int` público desbloquea
##      esto sin tocar nada más de este archivo.
##
## ── DESVIACIONES DE F2, señaladas explícitamente (no un olvido) ────────────────────────────────
##   A. El módulo Reloj de la maqueta muestra una sola línea ("Día 3 · 07:47"); el contrato real
##      sigue escribiendo la hora y "Sem N · Turno T" en DOS Labels separados (`_refrescar_reloj`,
##      bloqueada). Se apilan en dos líneas (hora grande arriba, semana/turno pequeño gris abajo) en
##      vez de fundirlos en una — no se pierde información, pero el layout no es idéntico a la
##      maqueta en este punto. `art-director`/`ux-designer`: si se quiere el formato "Día N", hace
##      falta que `_refrescar_reloj` (fuera de alcance aquí) lo calcule.
##   B. El glifo de velocidad NO cambia de color al activarse (la maqueta lo dibuja azul cuando
##      está activo, gris si no) — `_refrescar_velocidad` (bloqueada) solo alterna
##      `_pips_velocidad[i].modulate.a` (visibilidad de la pastilla interior) y
##      `_boton_3x.theme_type_variation` (inerte aquí, ver la cabecera de
##      `_construir_modulo_velocidad`), nunca un color de glifo. La pastilla interior
##      (`MOD_COLOR_ACENTO_SUAVE`) sigue siendo una señal de estado clara por sí sola (forma +
##      posición, no solo color -- cumple la regla de accesibilidad transversal del proyecto).
##   C. `COLOR_HOLGADO`/`COLOR_JUSTO` (más abajo) se RETONALIZAN a los mismos verdes/ámbares del kit
##      moderno (`MOD_COLOR_VERDE`/`MOD_COLOR_AMBAR`): los pasteles del piloto (pensados para leerse
##      sobre el 9-slice navy oscuro) pierden contraste sobre la pastilla BLANCA del kit claro. Es
##      un cambio de VALOR de constante, no de la lógica que las usa (`_refrescar_saldo`/
##      `_refrescar_demanda`, bloqueadas, sin tocar).
##   D. Los chips de Plantilla/Documentación llevan icono (kit `ICONOS`, `personal`/`carpeta`) para
##      casar visualmente con la maqueta, aunque el texto de la story los describe sin icono — el
##      icono ya existe en el catálogo y no añade coste de mantenimiento nuevo.

# ── Señales (upward, child → parent — coding standards del proyecto) ────────────────────────────
signal construccion_solicitada
signal personal_solicitado
signal horario_solicitado
signal guardar_solicitado
signal cargar_solicitado
signal paredes_solicitado

# ── Constantes de layout (spec §1.2/§1.6/§2.1) ───────────────────────────────────────────────────
const KitUIComisarioScript := preload("res://src/ui/kit_ui_comisario.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")

## Margen de la barra flotante a los bordes de pantalla (maqueta: "margen 12 de los bordes") y su
## alto fijo (maqueta: "~64px de alto") -- reemplazan al 9-slice `sb_barra`/22-44 del piloto.
const MARGEN_BARRA_FLOTANTE: float = 12.0
const ALTO_BARRA_FLOTANTE: float = 64.0
## Alto reservado del `PanelSuperior` (el `Control` transparente que aloja la barra flotante):
## margen superior + alto de la barra -- no hace falta aire extra abajo, la barra es el borde.
const ALTO_PANEL_SUPERIOR: float = MARGEN_BARRA_FLOTANTE + ALTO_BARRA_FLOTANTE
## Alto de cada pastilla blanca interior (reloj/velocidad/chips/saldo) -- maqueta: `y1-y0 = 40`.
const ALTO_PASTILLA: float = 40.0
## Anchos de los módulos/chips (maqueta v3 + margen para los 2 Labels del contrato, que no se
## funden en una sola línea -- ver DESVIACIÓN A de la cabecera del archivo).
const ANCHO_MODULO_RELOJ: float = 190.0
const ANCHO_MODULO_VELOCIDAD: float = 164.0
## Ancho de cada uno de los 4 segmentos Pausa/1×/2×/3× dentro del módulo Velocidad.
const ANCHO_SEGMENTO_VELOCIDAD: float = 36.0
const ANCHO_MODULO_SALDO: float = 190.0
## Los 4 chips de fondo blanco (spec §1.3, chips de estado) -- pastilla independiente cada uno,
## dentro de la barra flotante (ya no "encima del fondo de la BarraSuperior" 9-slice del piloto).
const ANCHO_CHIP_SATISFACCION: float = 190.0
const ANCHO_CHIP_DEMANDA: float = 185.0
const ANCHO_CHIP_PLANTILLA: float = 112.0
const ANCHO_CHIP_DOCUMENTACION: float = 165.0
## 8px normal / 16px entre "familias" (Gestalt, spec §1.1) -- el helper `_espaciador_familia`
## aprovecha que `HBoxContainer.separation` YA pone 8px a cada lado de cualquier hijo (incluido uno
## vacío): un `Control` de ancho 0 entre dos chips da 8+8=16 sin duplicar la constante de spacing.
const SEPARACION_NORMAL: int = 8

## Alto de la franja de acciones (spec §2.1, 60px) -- DELIBERADAMENTE NO sincronizado con
## `ModoConstruccion.HUECO_BARRA_INFO` (84px, sigue así: `modo_construccion.gd` está fuera del
## alcance de esta story, regla dura del encargo). La franja vive DENTRO de ese hueco de 84px ya
## reservado (bottom-aligned a pantalla, `PRESET_BOTTOM_WIDE` sin offset) con ~24px de aire por
## encima antes de que empiece la barra de construcción colapsada -- nunca se solapan (60 < 84),
## pero el ajuste fino de la spec (igualar las dos constantes a 60) queda PENDIENTE de una story
## que sí pueda tocar `modo_construccion.gd`.
const ALTO_FRANJA_ACCIONES: float = 60.0

# ── Paleta (spec §1.5 — colores MEDIDOS del arte real, no reutilizados de otro sitio del HUD) ────
## Rojo crítico: EXACTAMENTE el mismo valor que `TarjetaObjeto/colors/font_disabled_color` del
## tema (spec §1.3-[3]: "el mismo rojo que ya usa TarjetaObjeto..."), reutilizado a propósito.
const COLOR_ROJO_CRITICO := Color(0.75, 0.2, 0.18, 1.0)
## Verde/ámbar — RETONALIZADOS en F2 (ver DESVIACIÓN C de la cabecera): los pasteles del piloto
## (0.55/0.9/0.55 y 1.0/0.8/0.35) se leían bien sobre el 9-slice navy oscuro pero pierden contraste
## sobre la pastilla BLANCA del kit moderno. Se igualan a `KitUIComisario.MOD_COLOR_VERDE`/
## `MOD_COLOR_AMBAR` (mismo vocabulario "verde"/"ámbar" que ya usa el kit claro) — SOLO cambia el
## valor de la constante; la lógica que la consume (`_refrescar_saldo`/`_refrescar_demanda`,
## bloqueadas en este reskin) no se toca.
const COLOR_HOLGADO := Color(0.133, 0.627, 0.369)   # = KitUIComisario.MOD_COLOR_VERDE
const COLOR_JUSTO := Color(0.941, 0.620, 0.173)     # = KitUIComisario.MOD_COLOR_AMBAR
## Navy al 65% -- gemelo de `Main.COLOR_TENUE_HUD_CLARO`, mismo valor, con copia propia porque
## `main.gd` no tiene `class_name` (no es referenciable desde aquí) y esa constante, además,
## Main.md §4 la reasigna de alcance a "solo hints de construcción" -- este HUD necesita su propio
## texto secundario tenue sobre fondo pastel claro.
const COLOR_NAVY_TENUE := Color(0.11, 0.2, 0.32, 0.65)
## Nivel de demanda BAJA/MEDIA/ALTA (mismo vocabulario que `Main.COLORES_NIVEL`/`Demanda`, DG12).
const COLORES_NIVEL: Dictionary[StringName, Color] = {
	&"BAJA": COLOR_HOLGADO, &"MEDIA": COLOR_JUSTO, &"ALTA": COLOR_ROJO_CRITICO,
}
## Etiquetas del ciclo de paredes (mismo vocabulario que `Main.NOMBRES_MODO_PARED`).
const NOMBRES_MODO_PARED: Dictionary[StringName, String] = {
	&"auto": "Auto", &"todas": "Enteras", &"bajitas": "Bajitas",
}

# ── Sistemas Core inyectados (ADR-0001: solo lectura) ────────────────────────────────────────────
var _economia: Node = null
var _demanda: Node = null
var _personal: Node = null
var _flujo: Node = null
var _paciencia: Node = null
var _documentacion: Node = null
var _paredes_salas: Node2D = null

# ── Nodos propios ─────────────────────────────────────────────────────────────────────────────
var _panel_superior: Panel = null
var _panel_acciones: Panel = null

var _lbl_hora: Label = null
var _lbl_fecha_turno: Label = null
var _botones_velocidad: Array[Button] = []
## F2: el "pip" YA NO es el triángulo ▾ — es la PASTILLA `MOD_COLOR_ACENTO_SUAVE` detrás del glifo
## activo (maqueta v3). `_refrescar_velocidad` (bloqueada) solo toca `modulate.a`, que existe en
## cualquier CanvasItem — el tipo se ensancha a `Control` sin tocar esa función.
var _pips_velocidad: Array[Control] = []
var _boton_3x: Button = null
var _lbl_saldo: Label = null
var _lbl_estado_fin: Label = null
var _lbl_satisfaccion: Label = null
var _lbl_reclamaciones: Label = null
var _lbl_demanda_nivel: Label = null
var _lbl_llegadas: Label = null
var _lbl_plantilla: Label = null
var _lbl_nomina: Label = null
var _lbl_doc_cola: Label = null
var _lbl_doc_atendiendo: Label = null

var _lbl_aviso: Label = null
## Los 5 botones de la franja de acciones, en el orden del wireframe (spec §6): Personal, Horario,
## Guardar, Cargar, Paredes. Expuesto para tests (mismo patrón que `_botones_herramienta` de
## `ModoConstruccion`) y para que `_refrescar_paredes` no tenga que buscar el botón por texto.
var _botones_acciones: Array[Button] = []
var _lbl_paredes: Label = null


func _ready() -> void:
	_construir_panel_superior()
	_construir_panel_acciones()


## Inyecta los sistemas Core de SOLO LECTURA (ADR-0001). Puede llamarse antes o después de
## `add_child(self)` -- a diferencia de `ModoConstruccion`/`ModoDisenadorEntorno`, construir el
## árbol de nodos de este HUD NO depende de tener datos ya inyectados (los Labels nacen vacíos y
## los rellena el primer `refrescar()`), así que no hay contrato de orden que romper.
func configurar(
	economia: Node, demanda: Node, personal: Node, flujo: Node, paciencia: Node,
	documentacion: Node, paredes_salas: Node2D
) -> void:
	_economia = economia
	_demanda = demanda
	_personal = personal
	_flujo = flujo
	_paciencia = paciencia
	_documentacion = documentacion
	_paredes_salas = paredes_salas


## Refresco por PULL, llamado una vez por frame desde `Main._process` -- mismo call site y mismo
## criterio de rendimiento que el antiguo `_refrescar_etiquetas()` que sustituye (barato a esta
## escala, spec §5 "nota de refresco general"). Cada sección se protege por separado: que falte un
## sistema (tests, arranque parcial) no debe dejar en blanco las demás.
func refrescar() -> void:
	if _lbl_hora == null:
		return   # `_ready()` aún no ha construido el árbol (llamada fuera de orden) -- no revienta.
	_refrescar_reloj()
	_refrescar_velocidad()
	_refrescar_saldo()
	_refrescar_satisfaccion()
	_refrescar_demanda()
	_refrescar_plantilla()
	_refrescar_documentacion()
	_refrescar_paredes()


## Mensaje transitorio de confirmación (Guardar/Cargar/Paredes-cicladas) -- mismo rol que el viejo
## `Main._avisar_accion`, ahora encapsulado: Main sigue siendo quien decide EL TEXTO (sigue dueño
## de `_guardar_partida`/`_cargar_partida`/`_alternar_modo_paredes`), este HUD solo lo pinta.
func avisar(texto: String, color: Color) -> void:
	if _lbl_aviso == null:
		return
	_lbl_aviso.text = texto
	_lbl_aviso.add_theme_color_override("font_color", color)


## Oculta/muestra SOLO la franja de acciones inferior -- la superior SIEMPRE visible (spec §1,
## "información ARRIBA, herramientas ABAJO"). Mismo contrato que el viejo `_capa_hud.visible`, pero
## ahora acotado a una sola franja en vez de a todo el HUD: sustituye a `Main._al_activar_
## construccion`/`_al_activar_disenador`, que antes ocultaban el HUD entero.
func ocultar_acciones(oculto: bool) -> void:
	if _panel_acciones != null:
		_panel_acciones.visible = not oculto


# ── Construcción — Panel superior (F2: la barra flotante clara de la maqueta v3) ─────────────────
func _construir_panel_superior() -> void:
	var panel := Panel.new()
	panel.name = "PanelSuperior"
	# Tema MODERNO en la raíz (Segoe UI para todo lo de dentro) y fondo transparente: el color vivo
	# es la barra flotante interior, no una franja de borde a borde.
	panel.theme = KitUIComisarioScript.moderno_tema()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.custom_minimum_size = Vector2(0, ALTO_PANEL_SUPERIOR)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE   # el hueco transparente no roba clics al mundo
	add_child(panel)
	_panel_superior = panel

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", int(MARGEN_BARRA_FLOTANTE))
	margen.add_theme_constant_override("margin_top", int(MARGEN_BARRA_FLOTANTE))
	margen.add_theme_constant_override("margin_right", int(MARGEN_BARRA_FLOTANTE))
	margen.add_theme_constant_override("margin_bottom", 0)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margen)

	# La barra flotante: panel claro redondeado con sombra suave (misma receta que las tarjetas del
	# kit pero en `MOD_COLOR_PANEL` — es el "suelo" sobre el que flotan las pastillas blancas).
	var barra := PanelContainer.new()
	barra.name = "BarraFlotante"
	var estilo_barra := StyleBoxFlat.new()
	estilo_barra.bg_color = KitUIComisarioScript.MOD_COLOR_PANEL
	estilo_barra.set_corner_radius_all(20)
	estilo_barra.shadow_size = 10
	estilo_barra.shadow_color = Color(0.02, 0.03, 0.06, 0.12)
	estilo_barra.shadow_offset = Vector2(0.0, 4.0)
	estilo_barra.content_margin_left = 16.0
	estilo_barra.content_margin_right = 16.0
	estilo_barra.content_margin_top = 12.0
	estilo_barra.content_margin_bottom = 12.0
	barra.add_theme_stylebox_override("panel", estilo_barra)
	margen.add_child(barra)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", SEPARACION_NORMAL)
	barra.add_child(fila)

	_construir_modulo_reloj(fila)
	_construir_modulo_velocidad(fila)
	fila.add_child(_espaciador_familia())

	var chip_sat := _crear_chip_plano(fila, &"queja", ANCHO_CHIP_SATISFACCION)
	_lbl_satisfaccion = chip_sat["linea1"]
	_lbl_reclamaciones = chip_sat["linea2"]

	var chip_dem := _crear_chip_plano(fila, &"velocimetro", ANCHO_CHIP_DEMANDA)
	_lbl_demanda_nivel = chip_dem["linea1"]
	_lbl_llegadas = chip_dem["linea2"]

	var chip_plantilla := _crear_chip_plano(fila, &"personal", ANCHO_CHIP_PLANTILLA)
	_lbl_plantilla = chip_plantilla["linea1"]
	_lbl_nomina = chip_plantilla["linea2"]

	var chip_doc := _crear_chip_plano(fila, &"carpeta", ANCHO_CHIP_DOCUMENTACION)
	_lbl_doc_cola = chip_doc["linea1"]
	_lbl_doc_atendiendo = chip_doc["linea2"]

	# Elástico: empuja el saldo al borde derecho de la barra (maqueta v3: el dinero SIEMPRE al
	# fondo a la derecha). La brújula de depuración vive en su propia CanvasLayer por debajo de
	# esta cota — ya no hace falta reservarle hueco aquí (verificado en main.gd).
	var elastico := Control.new()
	elastico.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elastico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(elastico)
	_construir_modulo_saldo(fila)


## El glifo de reloj DIBUJADO (círculo + manecillas, tinta 2px) — icono de línea del lenguaje
## moderno, nunca un emoji (regla de la maqueta v3; los emojis caen en la fuente de color del
## sistema e ignoran `font_color`).
class GlifoReloj extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(22.0, 22.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var tinta: Color = KitUIComisario.MOD_COLOR_TINTA
		var centro: Vector2 = size / 2.0
		draw_arc(centro, 9.0, 0.0, TAU, 24, tinta, 2.0, true)
		draw_line(centro, centro + Vector2(0.0, -5.0), tinta, 2.0)
		draw_line(centro, centro + Vector2(3.5, 2.0), tinta, 2.0)


func _construir_modulo_reloj(fila: HBoxContainer) -> void:
	var pastilla := _pastilla_modulo("ModuloReloj", ANCHO_MODULO_RELOJ)
	fila.add_child(pastilla)
	var caja_h := HBoxContainer.new()
	caja_h.add_theme_constant_override("separation", 8)
	caja_h.alignment = BoxContainer.ALIGNMENT_CENTER
	caja_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastilla.add_child(caja_h)
	caja_h.add_child(GlifoReloj.new())
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 0)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja_h.add_child(caja)
	_lbl_hora = _etiqueta(15, KitUIComisarioScript.MOD_COLOR_TINTA, true)
	caja.add_child(_lbl_hora)
	# Sin clip_text: con él, el mínimo del Label cae a 0 y el VBox lo estrecha al ancho de la hora
	# ("Sem 1 · Turno 1" salía truncado). El ancho fijo que evita el baile ya lo pone la pastilla.
	_lbl_fecha_turno = _etiqueta(10, KitUIComisarioScript.MOD_COLOR_GRIS)
	caja.add_child(_lbl_fecha_turno)


## La pastilla blanca base de un módulo de la barra (maqueta v3): blanca, radio = mitad del alto,
## ancho mínimo fijo para que la barra no baile cuando cambian los textos.
func _pastilla_modulo(nombre: String, ancho: float) -> PanelContainer:
	var pastilla := KitUIComisarioScript.moderno_pastilla(
		KitUIComisarioScript.MOD_COLOR_TARJETA, ALTO_PASTILLA
	)
	pastilla.name = nombre
	pastilla.custom_minimum_size = Vector2(ancho, ALTO_PASTILLA)
	pastilla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pastilla


## Módulo Velocidad (spec §1.3-[2]): 4 controles (Pausa/1×/2×/3×) + un triángulo "▾" bajo el
## actualmente activo -- NUNCA se recolorea el botón (serían transparentes sobre el mismo PNG
## estático, sin estado "pulsado" propio, spec dixit), el triángulo ES el respaldo no-color.
func _construir_modulo_velocidad(fila: HBoxContainer) -> void:
	# F2 (maqueta v3): pastilla blanca con 4 SEGMENTOS; el activo lleva detrás una pastilla interior
	# `MOD_COLOR_ACENTO_SUAVE` (esa pastilla ES el "pip" que `_refrescar_velocidad` enciende/apaga
	# por `modulate.a` — mismo contrato que el triángulo ▾ del piloto, otra forma).
	var pastilla := _pastilla_modulo("ModuloVelocidad", ANCHO_MODULO_VELOCIDAD)
	fila.add_child(pastilla)
	var fila_botones := HBoxContainer.new()
	fila_botones.add_theme_constant_override("separation", 2)
	fila_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_botones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastilla.add_child(fila_botones)

	# "II" tipográfico y no "⏸" (fix 2026-08-09, sigue vigente): el glifo ⏸ cae en la fuente de
	# EMOJIS de color e ignora `font_color`; ▶ se queda en presentación de texto.
	const GLIFOS := ["II", "▶", "▶▶", "▶▶▶"]
	const TOOLTIPS := ["Pausa", "1×", "2×", "3×"]
	for i in 4:
		var segmento := Control.new()
		segmento.custom_minimum_size = Vector2(ANCHO_SEGMENTO_VELOCIDAD, ALTO_PASTILLA - 10.0)
		fila_botones.add_child(segmento)

		# La pastilla interior del ACTIVO (el pip): siempre en el árbol, alfa 0/1 — mismo criterio
		# anti-reflow del piloto ("al pulsar se cambia de posición").
		var pip := Panel.new()
		pip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var estilo_pip := StyleBoxFlat.new()
		estilo_pip.bg_color = KitUIComisarioScript.MOD_COLOR_ACENTO_SUAVE
		estilo_pip.set_corner_radius_all(int((ALTO_PASTILLA - 10.0) / 2.0))
		pip.add_theme_stylebox_override("panel", estilo_pip)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.modulate = Color(1, 1, 1, 0.0)
		segmento.add_child(pip)

		var boton := Button.new()
		boton.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		boton.focus_mode = Control.FOCUS_NONE   # gotcha ya conocido: si no, Espacio lo "pulsa".
		boton.text = GLIFOS[i]
		boton.tooltip_text = TOOLTIPS[i]
		boton.flat = true
		boton.add_theme_font_size_override("font_size", 13)
		boton.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_TINTA)
		boton.add_theme_color_override("font_hover_color", KitUIComisarioScript.MOD_COLOR_ACENTO)
		for estado: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			boton.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
		# Captura por valor: cada iteración cierra sobre SU PROPIO `i`, no el último del bucle.
		boton.pressed.connect(func() -> void: Tiempo.fijar_velocidad(i as Tiempo.Velocidad))
		segmento.add_child(boton)

		_botones_velocidad.append(boton)
		_pips_velocidad.append(pip)
		if i == 3:
			_boton_3x = boton


## Formato de saldo de la spec §1.3-[3] ("1.240 €"): miles con punto y SIN decimales — los céntimos
## no aportan en un tycoon y "3000.00 €" desbordaba la placa por la derecha (auditoría 2026-08-09).
func _formato_euros(saldo: float) -> String:
	var negativo: bool = saldo < 0.0
	var texto: String = str(absi(roundi(saldo)))
	var con_miles: String = ""
	while texto.length() > 3:
		con_miles = "." + texto.substr(texto.length() - 3) + con_miles
		texto = texto.substr(0, texto.length() - 3)
	con_miles = texto + con_miles
	return ("-" if negativo else "") + con_miles + " €"


func _construir_modulo_saldo(fila: HBoxContainer) -> void:
	# F2 (maqueta v3): pastilla blanca con la insignia "€" en círculo verde suave + saldo grande +
	# estado (Holgado/Justo/Negativo) debajo en su color — los colores los pone `_refrescar_saldo`
	# (bloqueada), aquí solo se montan los Labels con los MISMOS nombres.
	var pastilla := _pastilla_modulo("ModuloSaldo", ANCHO_MODULO_SALDO)
	fila.add_child(pastilla)
	var caja_h := HBoxContainer.new()
	caja_h.add_theme_constant_override("separation", 8)
	caja_h.alignment = BoxContainer.ALIGNMENT_CENTER
	caja_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastilla.add_child(caja_h)

	var insignia := Panel.new()
	insignia.custom_minimum_size = Vector2(24.0, 24.0)
	insignia.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	insignia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo_insignia := StyleBoxFlat.new()
	estilo_insignia.bg_color = Color(0.886, 0.957, 0.918)   # verde muy suave (226,244,234), maqueta
	estilo_insignia.set_corner_radius_all(12)
	insignia.add_theme_stylebox_override("panel", estilo_insignia)
	caja_h.add_child(insignia)
	var euro := Label.new()
	euro.text = "€"
	euro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	euro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	euro.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	euro.add_theme_font_override("font", KitUIComisarioScript.moderno_fuente(true))
	euro.add_theme_font_size_override("font_size", 13)
	euro.add_theme_color_override("font_color", KitUIComisarioScript.MOD_COLOR_VERDE)
	euro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	insignia.add_child(euro)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 0)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja_h.add_child(caja)
	_lbl_saldo = _etiqueta(16, KitUIComisarioScript.MOD_COLOR_TINTA, true)
	caja.add_child(_lbl_saldo)
	_lbl_estado_fin = _etiqueta(10, KitUIComisarioScript.MOD_COLOR_GRIS)
	caja.add_child(_lbl_estado_fin)


## Un chip de fondo plano (grupos 4-7, spec §1.3): icono pequeño (28×28, `KitUIComisario.icono`,
## escalado con `STRETCH_KEEP_ASPECT_CENTERED` -- a diferencia de los módulos 9-slice, un icono
## pictograma pequeño SÍ tolera reescalado sin distorsión perceptible) + 2 líneas de texto.
## Devuelve `{"linea1": Label, "linea2": Label}` -- quien llama guarda las referencias que necesite.
func _crear_chip_plano(fila: HBoxContainer, icono_id: StringName, ancho: float) -> Dictionary:
	# F2: cada chip es una pastilla BLANCA independiente (maqueta v3), dos líneas (dato principal
	# en seminegrita + secundario pequeño gris — así no se pierde ni un dato del HUD viejo).
	var pastilla := _pastilla_modulo("Chip" + String(icono_id).capitalize(), ancho)
	fila.add_child(pastilla)
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastilla.add_child(caja)

	var icono := TextureRect.new()
	icono.texture = KitUIComisarioScript.icono(icono_id)
	# EXPAND_IGNORE_SIZE (fix 2026-08-08, sigue vigente): sin él, el mínimo del TextureRect es el
	# tamaño NATIVO del PNG (~512px) y el icono revienta la barra.
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.custom_minimum_size = Vector2(20, 20)
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(icono)

	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 0)
	textos.alignment = BoxContainer.ALIGNMENT_CENTER
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(textos)

	var linea1 := _etiqueta(12, KitUIComisarioScript.MOD_COLOR_TINTA, true)
	linea1.clip_text = true
	textos.add_child(linea1)
	var linea2 := _etiqueta(10, KitUIComisarioScript.MOD_COLOR_GRIS)
	linea2.clip_text = true
	textos.add_child(linea2)

	return {"linea1": linea1, "linea2": linea2}


## Una etiqueta del panel superior: tamaño + color (+ seminegrita opcional). F2: SIN el contorno
## navy del piloto — sobre pastillas blancas del kit claro el contorno ensuciaba el trazo de la
## fuente moderna; el contraste tinta-sobre-blanco ya cumple sobrado.
func _etiqueta(tam: int, color: Color, negrita: bool = false) -> Label:
	var etiqueta := Label.new()
	if negrita:
		etiqueta.add_theme_font_override("font", KitUIComisarioScript.moderno_fuente(true))
	etiqueta.add_theme_font_size_override("font_size", tam)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


## Un `Control` vacío entre dos chips -- `HBoxContainer.separation` (8px) ya se aplica a cada lado
## de CUALQUIER hijo, incluido uno de ancho 0: el resultado es 16px netos entre "familias" (spec
## §1.1/§2.2, Gestalt) sin duplicar la constante de espaciado en dos sitios.
func _espaciador_familia() -> Control:
	var espaciador := Control.new()
	espaciador.custom_minimum_size = Vector2.ZERO
	espaciador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return espaciador


# ── Construcción — Franja de acciones (spec §2) ──────────────────────────────────────────────────
func _construir_panel_acciones() -> void:
	var panel := Panel.new()
	panel.name = "PanelAcciones"
	panel.theme = KitUIComisarioScript.moderno_tema()   # Segoe UI también en la franja de acciones
	# Relleno plano deliberado en vez del gris por defecto del motor (opción A del veredicto
	# 2026-08-09; ver `COLOR_FONDO_BARRA_INFERIOR`): la barra de construcción usa el MISMO color,
	# así las dos franjas siguen cosidas sin costura como antes.
	var estilo_fondo := StyleBoxFlat.new()
	estilo_fondo.bg_color = KitUIComisarioScript.COLOR_FONDO_BARRA_INFERIOR
	panel.add_theme_stylebox_override("panel", estilo_fondo)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(0, ALTO_FRANJA_ACCIONES)
	add_child(panel)
	_panel_acciones = panel

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_right", 12)
	margen.add_theme_constant_override("margin_top", 10)
	margen.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margen)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", SEPARACION_NORMAL)
	margen.add_child(fila)

	# Mensaje transitorio (Guardar/Cargar/Paredes) -- mismo rol que el viejo `_lbl_guardado`, ahora
	# a la IZQUIERDA del grupo de píldoras (`SIZE_EXPAND_FILL` lo empuja todo lo demás a la derecha,
	# Fitts's Law: el borde de pantalla es el blanco más fácil de acertar con el ratón).
	_lbl_aviso = Label.new()
	_lbl_aviso.add_theme_font_size_override("font_size", 11)
	_lbl_aviso.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_lbl_aviso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(_lbl_aviso)

	# La píldora de Construcción abre/cierra el modo (opción A del veredicto 2026-08-09: la franja
	# colapsada gris de `ModoConstruccion` desaparece y esta píldora ocupa su papel). Va la PRIMERA
	# de la fila (esquina inferior izquierda, espejo de Fitts del grupo derecho); con el modo
	# abierto la fila entera se oculta (`ocultar_acciones`, ya cableado) y manda la barra de
	# pestañas+tarjetas.
	var boton_construir := _boton_pildora(
		&"plano", "Construir (B)", KitUIComisarioScript.VARIANTE_PILDORA_PRIMARIA,
		KitUIComisarioScript.MOD_COLOR_ACENTO
	)
	boton_construir.pressed.connect(func() -> void: construccion_solicitada.emit())
	fila.add_child(boton_construir)
	fila.move_child(boton_construir, 0)   # delante del aviso: pegada al borde izquierdo
	_botones_acciones.append(boton_construir)

	var boton_personal := _boton_pildora(
		&"personal", "Personal (P)", KitUIComisarioScript.VARIANTE_PILDORA_PRIMARIA,
		KitUIComisarioScript.MOD_COLOR_TINTA
	)
	boton_personal.pressed.connect(func() -> void: personal_solicitado.emit())
	fila.add_child(boton_personal)
	_botones_acciones.append(boton_personal)

	var boton_horario := _boton_pildora(
		&"reloj", "Horario (H)", KitUIComisarioScript.VARIANTE_PILDORA_PRIMARIA,
		KitUIComisarioScript.MOD_COLOR_TINTA
	)
	boton_horario.pressed.connect(func() -> void: horario_solicitado.emit())
	fila.add_child(boton_horario)
	_botones_acciones.append(boton_horario)

	fila.add_child(_espaciador_familia())

	var color_secundaria: Color = KitUIComisarioScript.MOD_COLOR_TINTA
	var boton_guardar := _boton_pildora(
		&"disquete", "Guardar (F5)", KitUIComisarioScript.VARIANTE_PILDORA_SECUNDARIA, color_secundaria
	)
	boton_guardar.pressed.connect(func() -> void: guardar_solicitado.emit())
	fila.add_child(boton_guardar)
	_botones_acciones.append(boton_guardar)

	var boton_cargar := _boton_pildora(
		&"carpeta", "Cargar (F9)", KitUIComisarioScript.VARIANTE_PILDORA_SECUNDARIA, color_secundaria
	)
	boton_cargar.pressed.connect(func() -> void: cargar_solicitado.emit())
	fila.add_child(boton_cargar)
	_botones_acciones.append(boton_cargar)

	fila.add_child(_espaciador_familia())

	var boton_paredes := _boton_pildora(
		&"muro", "Paredes: Auto (Home)", KitUIComisarioScript.VARIANTE_PILDORA_SECUNDARIA,
		color_secundaria
	)
	boton_paredes.pressed.connect(func() -> void: paredes_solicitado.emit())
	fila.add_child(boton_paredes)
	_botones_acciones.append(boton_paredes)
	# El texto de esta píldora cambia con el modo de paredes (`_refrescar_paredes`); se guarda como
	# metadato del propio botón (técnica nativa de Godot, `set_meta`/`get_meta`) en vez de inventar
	# una struct — mismo espíritu que `_crear_chip_plano` devolviendo un `Dictionary` de labels.
	_lbl_paredes = boton_paredes.get_meta(&"etiqueta_pildora") as Label


## Una píldora de acción: `Button` con contenido MANUAL (icono + texto en un `HBoxContainer` dentro
## de un `MarginContainer`) -- NO el `icon`/`text` nativos del `Button`. Mismo fix de causa raíz que
## `spec-tarjetas-2026-08-08.md` §0-B (spec §2.2 lo pide explícitamente): el layout nativo icono+
## texto de `Button` ya dio problemas de solape en este proyecto con los StyleBoxTexture del kit.
func _boton_pildora(
	icono_id: StringName, texto: String, variante: StringName, color_texto: Color
) -> Button:
	var boton := Button.new()
	boton.focus_mode = Control.FOCUS_NONE
	boton.custom_minimum_size = Vector2(0, 40)   # el ancho real se fija al final con el texto medido
	# F2: pastilla BLANCA del kit moderno (la primaria con un filo de acento) en vez del 9-slice
	# navy — sobre la franja oscura de acciones, las pastillas claras son las que "flotan".
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = KitUIComisarioScript.MOD_COLOR_TARJETA
	estilo.set_corner_radius_all(20)
	if variante == KitUIComisarioScript.VARIANTE_PILDORA_PRIMARIA:
		estilo.set_border_width_all(2)
		estilo.border_color = KitUIComisarioScript.MOD_COLOR_ACENTO
	var estilo_hover: StyleBoxFlat = estilo.duplicate()
	estilo_hover.bg_color = KitUIComisarioScript.MOD_COLOR_ACENTO_SUAVE
	for estado: String in ["normal", "disabled", "focus"]:
		boton.add_theme_stylebox_override(estado, estilo)
	boton.add_theme_stylebox_override("hover", estilo_hover)
	boton.add_theme_stylebox_override("pressed", estilo_hover)

	var margen := MarginContainer.new()
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_right", 12)
	margen.add_theme_constant_override("margin_top", 4)
	margen.add_theme_constant_override("margin_bottom", 4)
	boton.add_child(margen)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_child(fila)

	var icono := TextureRect.new()
	icono.texture = KitUIComisarioScript.icono(icono_id)
	# Mismo fix EXPAND_IGNORE_SIZE que el chip (sin él, el icono nativo de ~512px aplastaba el
	# layout de la píldora y el rótulo quedaba invisible fuera del botón).
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.custom_minimum_size = Vector2(18, 18)
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(icono)

	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", 11)
	etiqueta.add_theme_color_override("font_color", color_texto)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(etiqueta)

	boton.set_meta(&"etiqueta_pildora", etiqueta)
	# Un Button NO se dimensiona por hijos arbitrarios (el MarginContainer interno no cuenta para su
	# minimo): sin esto las pildoras colapsaban al minimo del 9-slice y el contenido se solapaba.
	# 58 = margenes internos (12+12) + icono 18 + separacion 6 + aire del 9-slice.
	boton.custom_minimum_size.x = 58.0 + etiqueta.get_minimum_size().x
	return boton


# ── Refresco (pull, una vez por frame — spec §5) ─────────────────────────────────────────────────

## Reloj (spec §1.3-[1]): hora `HH:MM` + "Sem N · Turno T" -- `Tiempo` es autoload, se lee directo.
func _refrescar_reloj() -> void:
	_lbl_hora.text = Tiempo.hhmm(Tiempo.minutos_juego)
	_lbl_fecha_turno.text = "Sem %d · Turno %d" % [
		Tiempo.semana, Tiempo.turno_de(Tiempo.minutos_juego) + 1,
	]


## Velocidad: el triángulo ▾ bajo el control activo + la variante de la píldora "3×" (Primaria si
## activa, Secundaria si no) -- NUNCA se recolorea un botón (spec §1.3-[2], nota de indicador).
func _refrescar_velocidad() -> void:
	var indice: int = Tiempo.velocidad_actual
	for i in _pips_velocidad.size():
		_pips_velocidad[i].modulate.a = 1.0 if i == indice else 0.0
	if _boton_3x != null:
		_boton_3x.theme_type_variation = (
			KitUIComisarioScript.VARIANTE_PILDORA_PRIMARIA if indice == 3
			else KitUIComisarioScript.VARIANTE_PILDORA_SECUNDARIA
		)


## Saldo + estado (spec §1.3-[3]/§3): rojo+contorno+"Negativo" si <0, ámbar+"Justo" si <umbral,
## verde+"Holgado" si no. La UI NO posee el umbral -- lo lee de `Economia.umbral_holgura_ui` (F1).
func _refrescar_saldo() -> void:
	if _economia == null:
		return
	var saldo: float = _economia.saldo_eur
	_lbl_saldo.text = _formato_euros(saldo)
	if saldo < 0.0:
		_lbl_saldo.add_theme_color_override("font_color", COLOR_ROJO_CRITICO)
		_lbl_saldo.add_theme_constant_override("outline_size", 1)   # refuerzo WCAG, spec §1.3-[3]
		_lbl_estado_fin.text = "Negativo"
		_lbl_estado_fin.add_theme_color_override("font_color", COLOR_ROJO_CRITICO)
	elif saldo < _economia.umbral_holgura_ui:
		_lbl_saldo.add_theme_color_override("font_color", COLOR_JUSTO)
		_lbl_saldo.add_theme_constant_override("outline_size", 0)
		_lbl_estado_fin.text = "Justo"
		_lbl_estado_fin.add_theme_color_override("font_color", COLOR_JUSTO)
	else:
		_lbl_saldo.add_theme_color_override("font_color", KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL)
		_lbl_saldo.add_theme_constant_override("outline_size", 0)
		_lbl_estado_fin.text = "Holgado"
		_lbl_estado_fin.add_theme_color_override("font_color", COLOR_HOLGADO)


## Satisfacción + reclamaciones (spec §1.3-[4]): banda 🔴🟡🟢 (mismo vocabulario que `ui-hud.md` F3,
## umbrales de ánimo de `Paciencia`) + reclamaciones, en rojo si hay graves (§1.4: contorno = "negrita"
## simulada, no hay peso bold real en la fuente).
func _refrescar_satisfaccion() -> void:
	if _paciencia == null:
		return
	var sat: float = _paciencia.sat_global()
	var banda: String = (
		"🟢" if sat > _paciencia.umbral_animo_alto
		else ("🔴" if sat < _paciencia.umbral_animo_bajo else "🟡")
	)
	_lbl_satisfaccion.text = "%s Satisf. %d%%" % [banda, roundi(sat)]
	var graves: int = _paciencia.reclamaciones_graves_jornada
	var texto := "Reclamaciones: %d" % _paciencia.reclamaciones_jornada
	if graves > 0:
		texto += " (%d grave%s)" % [graves, "" if graves == 1 else "s"]
		_lbl_reclamaciones.add_theme_color_override("font_color", COLOR_ROJO_CRITICO)
		_lbl_reclamaciones.add_theme_constant_override("outline_size", 1)
	else:
		_lbl_reclamaciones.add_theme_color_override("font_color", COLOR_NAVY_TENUE)
		_lbl_reclamaciones.add_theme_constant_override("outline_size", 0)
	_lbl_reclamaciones.text = texto


## Demanda + llegadas hoy (spec §1.3-[5]).
func _refrescar_demanda() -> void:
	if _demanda == null:
		return
	var nivel: StringName = _demanda.nivel_demanda()
	_lbl_demanda_nivel.text = "Demanda: %s" % nivel
	_lbl_demanda_nivel.add_theme_color_override(
		"font_color", COLORES_NIVEL.get(nivel, KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL)
	)
	_lbl_llegadas.text = "Llegadas hoy: %d" % _demanda.llegadas_hoy


## Plantilla + nómina (spec §1.3-[6]/§3): "0/N" en rojo + "⚠ Sin cobertura" si nadie cubre.
## Cobertura = plantilla total menos quien está `ESTADO_AUSENTE` -- mismo criterio que ya usaba el
## HUD viejo para calcular ausencias (`Main._refrescar_etiquetas`), no un cálculo nuevo.
func _refrescar_plantilla() -> void:
	if _personal == null:
		return
	var total: int = _personal.plantilla.size()
	var nomina := 0.0
	var ausentes := 0
	for agente: RefCounted in _personal.plantilla:
		nomina += _personal.salario_dia(agente)
		if agente.estado == AgenteScript.ESTADO_AUSENTE:
			ausentes += 1
	var cubiertos: int = total - ausentes
	_lbl_plantilla.text = "Plantilla: %d/%d" % [cubiertos, total]
	if cubiertos <= 0 and total > 0:
		_lbl_plantilla.add_theme_color_override("font_color", COLOR_ROJO_CRITICO)
		_lbl_nomina.text = "⚠ Sin cobertura"
		_lbl_nomina.add_theme_color_override("font_color", COLOR_ROJO_CRITICO)
	else:
		_lbl_plantilla.add_theme_color_override("font_color", KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL)
		_lbl_nomina.text = "Nómina: %.0f €/día" % nomina
		_lbl_nomina.add_theme_color_override("font_color", COLOR_NAVY_TENUE)


## Documentación (spec §1.3-[7]/§3): cola total + "(+N fuera)" si hay cola exterior (`PersonaFlujo.
## ESTADO_ESPERANDO_FUERA`, getter público `Flujo.personas_de_cola`). Sin semáforo de saturación
## (GAP 3, ver cabecera) ni "puerta" (GAP 1): línea 2 reducida a "N atendiendo", degradación ya
## prevista en la spec.
func _refrescar_documentacion() -> void:
	if _flujo == null:
		return
	var cola: Array = _flujo.personas_de_cola(&"Documentacion")
	var fuera := 0
	for persona: RefCounted in cola:
		if persona.estado == PersonaFlujoScript.ESTADO_ESPERANDO_FUERA:
			fuera += 1
	_lbl_doc_cola.text = "Doc: %d en cola%s" % [
		cola.size(), (" (+%d fuera)" % fuera) if fuera > 0 else "",
	]
	_lbl_doc_atendiendo.text = "%d atendiendo" % _flujo.atendiendo_total()


## El texto de la píldora Paredes (franja de acciones) -- la CICLA sigue siendo `Main.
## _alternar_modo_paredes` (vía la señal `paredes_solicitado`), esto solo pinta el modo actual.
func _refrescar_paredes() -> void:
	if _paredes_salas == null or _lbl_paredes == null:
		return
	_lbl_paredes.text = "Paredes: %s (Home)" % NOMBRES_MODO_PARED.get(
		_paredes_salas.modo_altura, "?"
	)
