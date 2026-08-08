class_name HudComisario
extends CanvasLayer
## HudComisario — reconstrucción TOTAL del HUD (encargo 2026-08-08: "te di la posibilidad de
## hacerlo de nuevo del todo -- estás parcheando"). Sustituye ENTERO el HUD provisional de
## `main.gd` (el `_crear_hud` de tiempo-009 + el `_crear_barra_superior` de la Fase 2 del
## 2026-08-08 mismo). El ÚNICO plano es `design/ux/hud-design.md` — layout §1-2, estados §3,
## eliminaciones §4, contrato de datos §5, wireframes §6. Este archivo la sigue sin re-decidir nada
## que la spec ya cerrara; donde la spec deja un hueco (§5) o donde el arte real no da para el
## número pedido, queda anotado explícitamente en el propio código (grep "DESVIACIÓN"/"GAP").
##
## ── Árbol de nodos ────────────────────────────────────────────────────────────────────────────
## HudComisario (CanvasLayer)
## ├─ PanelSuperior (Panel, tema BarraSuperior)      -- SIEMPRE visible (spec §1)
## │   └─ Margen(19/22/20/44) → HBoxContainer "fila"
## │       ├─ Módulo Reloj (Panel 9-slice ModuloReloj)      -- hora + "Sem N · Turno T"
## │       ├─ Módulo Velocidad (Panel 9-slice ModuloVelocidad) -- 4 botones + pip ▾ activo
## │       ├─ [espaciador familia 16px]
## │       ├─ Módulo Saldo (Panel 9-slice ModuloSaldo)      -- saldo + Holgado/Justo/Negativo
## │       ├─ [espaciador familia 16px]
## │       ├─ Chip Satisfacción (icono_queja + 2 líneas)
## │       ├─ Chip Demanda (icono_velocimetro + 2 líneas)
## │       ├─ Chip Plantilla (icono_personal + 2 líneas)
## │       ├─ Chip Documentación (icono_carpeta + 2 líneas)
## │       ├─ [espaciador familia 16px]
## │       ├─ (spacer elástico, SIZE_EXPAND_FILL)
## │       └─ (reserva brújula, 140px fijos, sin contenido -- la brújula vive en su PROPIA capa
## │            layer 10 montada por Main, esto solo evita que el HUD invada su hueco)
## └─ PanelAcciones (Panel, tema por defecto -- mismo criterio visual que la barra de
##     construcción justo debajo, sin `theme_type_variation`)   -- OCULTABLE (spec §2)
##     └─ Margen(12/12/10/10) → HBoxContainer "fila"
##         ├─ Label aviso transitorio (SIZE_EXPAND_FILL, empuja las píldoras a la derecha)
##         ├─ Píldora Personal (P) · Píldora Horario (H)
##         ├─ [espaciador familia 16px]
##         ├─ Píldora Guardar (F5) · Píldora Cargar (F9)
##         ├─ [espaciador familia 16px]
##         └─ Píldora Paredes: <modo> (Home)
##
## ── Contrato (ADR-0001: "la UI lee y ordena, nunca muta") ───────────────────────────────────────
## `configurar()` inyecta los sistemas Core de SOLO LECTURA (Economía/Demanda/Personal/Flujo/
## Paciencia/Documentación/ParedesSalas); NINGUNO se muta desde aquí. `refrescar()` se llama UNA
## vez por frame desde `Main._process` — mismo call site que el antiguo `_refrescar_etiquetas()`
## que sustituye (pull, no señales, mismo criterio de rendimiento que ya usaba el HUD viejo: barato
## a esta escala, ver la nota de refresco general de la spec §5). `Tiempo`/`EventBus` son
## autoloads: se leen DIRECTOS (`Tiempo.hhmm(...)`), sin inyección — mismo patrón que el resto de
## `src/main`.
##
## Los 5 botones de acción NO ejecutan nada aquí: emiten señales y quien decide qué hacer (abrir un
## panel, guardar, ordenar el ciclo de paredes) sigue siendo `Main`, con los MISMOS callbacks que
## ya tenía (`_abrir_personal`/`_abrir_horario`/`_guardar_partida`/`_cargar_partida`/
## `_alternar_modo_paredes`) — "Signals for upward communication" (coding standards del proyecto:
## child→parent, nunca al revés).
##
## ── GAPS del contrato §5, NO inventados (instrucción explícita de la story: "si de verdad no
## existe, ese campo se omite y lo anotas") ──────────────────────────────────────────────────────
##   1. "Puerta Doc" (nº de turno llamado/mostrado) — no localizado en `flujo.gd`/`documentacion.
##      gd`. La línea 2 del chip Documentación se reduce a "N atendiendo" (degradación ya prevista
##      en la spec §1.3-[7]).
##   2. Bandera "sin guardar" (dirty) — no localizada en `save_manager.gd`. La píldora Guardar NO
##      lleva el punto "•"/tinte ámbar de §3 (necesitaría una bandera nueva en `SaveManager`, fuera
##      del alcance de "reconstruir el HUD").
##   3. Semáforo 🔴/🟡/🟢 de "cola saturada" (§3) — necesitaría un getter PÚBLICO de aforo en
##      `Flujo` (hoy `_aforo_de` es privado, con guion bajo). Sin él, la UI tendría que inventarse
##      el umbral, que la propia spec prohíbe explícitamente ("el umbral concreto lo posee Flujo,
##      la UI solo pinta la banda, no lo calcula"). Se muestra el conteo real (dentro + "fuera" vía
##      `Flujo.personas_de_cola` filtrando `PersonaFlujo.ESTADO_ESPERANDO_FUERA`, SÍ público) sin
##      el color de semáforo. Follow-up: un `Flujo.aforo_de(servicio) -> int` público desbloquea
##      esto sin tocar nada más de este archivo.
##
## ── DESVIACIÓN DE TAMAÑO, señalada explícitamente (no un olvido) ────────────────────────────────
## La spec pide una franja superior de 52px con módulos de 40px de alto (§1.1). Los 3 PNG de
## reloj/velocidad/saldo miden 234×98 / 178×98 / 238×98 REALES (medidos con `Read` + análisis de
## varianza de color, no a ojo) y el icono/dibujo ocupa CASI TODO el alto nativo — un 9-slice
## protege el ANCHO (hay margen plano a los lados para reloj/saldo) pero NO el ALTO sin aplastar el
## dibujo (ver la cabecera larga de `sb_mod_reloj` en `theme_comisario.tres`). Se usan a su ALTURA
## NATIVA (98px; panel total 164px = 22+98+44) — la MISMA cifra que ya verificó en pantalla el
## piloto Fase 2, no una regresión nueva. Solo un PNG rediseñado con más aire vertical alrededor
## del icono permitiría los 40px reales sin deformarlo — anotado para `art-director`/`ux-designer`.

# ── Señales (upward, child → parent — coding standards del proyecto) ────────────────────────────
signal personal_solicitado
signal horario_solicitado
signal guardar_solicitado
signal cargar_solicitado
signal paredes_solicitado

# ── Constantes de layout (spec §1.2/§1.6/§2.1) ───────────────────────────────────────────────────
const KitUIComisarioScript := preload("res://src/ui/kit_ui_comisario.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")

## Alto REAL del panel superior — ver "DESVIACIÓN DE TAMAÑO" arriba (no los 52px literales de la
## spec). 22/44 son los `texture_margin_top`/`_bottom` de `sb_barra` en el tema (no tocar sin
## revisar ese StyleBoxTexture); 98 es el alto nativo medido de los 3 PNG de módulo.
const ALTO_MODULO: float = 98.0
const ALTO_PANEL_SUPERIOR: float = 22.0 + ALTO_MODULO + 44.0
## Anchos de los 3 módulos ilustrados (spec §1.2, tabla). Seguros para un 9-slice: el icono vive en
## una franja izquierda fija (protegida por `texture_margin_left` del tema) y el resto de la card
## es relleno plano que absorbe el ancho sin distorsión — salvo Velocidad, ver el aviso de
## `sb_mod_vel` en el tema (los 3 círculos ocupan casi todo el ancho, compresión uniforme al 24%).
const ANCHO_MODULO_RELOJ: float = 150.0
const ANCHO_MODULO_VELOCIDAD: float = 135.0
## 179: con el formato de la spec ("3.000 €", `_formato_euros`) el texto cabía en 165 pero el "€"
## quedaba ROZANDO el bisel dorado de la placa (auditoría 2026-08-09) — 14px más de aire a la
## derecha. Histórico: 145 recortaba "3000.00" (fix 2026-08-08, formato viejo con decimales).
const ANCHO_MODULO_SALDO: float = 179.0
## Margen izquierdo (px) que cada módulo 9-slice reserva para no tapar su propio icono — el mismo
## valor que ya protege `texture_margin_left` del StyleBoxTexture del tema (ver `theme_comisario.
## tres`, `sb_mod_reloj`/`sb_mod_saldo`): PINTADO EN LOS DOS SITIOS a propósito (uno mueve el
## 9-slice, el otro mueve el CONTENIDO -- Labels/botones -- que va POR ENCIMA).
const MARGEN_IZQ_RELOJ: int = 95
const MARGEN_IZQ_SALDO: int = 88
const MARGEN_IZQ_VELOCIDAD: int = 12
## Los 4 chips de fondo plano (spec §1.2, tabla, filas 4-7) -- sin módulo de arte, viven encima del
## fondo de la propia `BarraSuperior`.
const ANCHO_CHIP_SATISFACCION: float = 175.0
const ANCHO_CHIP_DEMANDA: float = 172.0
const ANCHO_CHIP_PLANTILLA: float = 166.0
const ANCHO_CHIP_DOCUMENTACION: float = 168.0
## Reserva a la derecha para la brújula de depuración (spec §0/§1.2) -- Main la monta en su PROPIA
## `CanvasLayer` (layer 10), este hueco solo evita que el HUD la invada visualmente.
const ANCHO_RESERVA_BRUJULA: float = 140.0
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
## Verde/ámbar: la spec NO da un hex para estos dos (solo dice "verde"/"ámbar", §1.3-[3]); se
## reutilizan los mismos valores que ya usa `Main`/`Demanda` para BAJA/Holgado y MEDIA/Justo — es
## el vocabulario de color ya asentado del proyecto, no una invención nueva de esta clase.
const COLOR_HOLGADO := Color(0.55, 0.9, 0.55)
const COLOR_JUSTO := Color(1.0, 0.8, 0.35)
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
var _pips_velocidad: Array[Label] = []
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


# ── Construcción — Panel superior (spec §1) ──────────────────────────────────────────────────────
func _construir_panel_superior() -> void:
	var panel := Panel.new()
	panel.name = "PanelSuperior"
	panel.theme = KitUIComisarioScript.tema()
	panel.theme_type_variation = KitUIComisarioScript.VARIANTE_BARRA_SUPERIOR
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.custom_minimum_size = Vector2(0, ALTO_PANEL_SUPERIOR)
	add_child(panel)
	_panel_superior = panel

	# Mismos 19/22/20/44 que `texture_margin_*` de `sb_barra`: el contenido no invade el borde/pie
	# navy pintado por el 9-slice del fondo grande (independiente de los 3 módulos interiores).
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 19)
	margen.add_theme_constant_override("margin_top", 22)
	margen.add_theme_constant_override("margin_right", 20)
	margen.add_theme_constant_override("margin_bottom", 44)
	panel.add_child(margen)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", SEPARACION_NORMAL)
	margen.add_child(fila)

	_construir_modulo_reloj(fila)
	_construir_modulo_velocidad(fila)
	fila.add_child(_espaciador_familia())
	_construir_modulo_saldo(fila)
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
	fila.add_child(_espaciador_familia())

	var elastico := Control.new()
	elastico.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elastico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(elastico)

	var reserva_brujula := Control.new()
	reserva_brujula.name = "ReservaBrujula"
	reserva_brujula.custom_minimum_size = Vector2(ANCHO_RESERVA_BRUJULA, 0)
	reserva_brujula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(reserva_brujula)


func _construir_modulo_reloj(fila: HBoxContainer) -> void:
	var contenido := _crear_modulo_9slice(
		fila, KitUIComisarioScript.VARIANTE_MODULO_RELOJ, ANCHO_MODULO_RELOJ, MARGEN_IZQ_RELOJ
	)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 0)
	contenido.add_child(caja)
	_lbl_hora = _etiqueta(15, KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL)
	caja.add_child(_lbl_hora)
	_lbl_fecha_turno = _etiqueta(10, COLOR_NAVY_TENUE)
	_lbl_fecha_turno.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_fecha_turno.clip_text = true
	caja.add_child(_lbl_fecha_turno)


## Módulo Velocidad (spec §1.3-[2]): 4 controles (Pausa/1×/2×/3×) + un triángulo "▾" bajo el
## actualmente activo -- NUNCA se recolorea el botón (serían transparentes sobre el mismo PNG
## estático, sin estado "pulsado" propio, spec dixit), el triángulo ES el respaldo no-color.
func _construir_modulo_velocidad(fila: HBoxContainer) -> void:
	# SIN el PNG del modulo (fix 2026-08-08, veredicto del usuario "botones encima de otros"): el
	# arte trae 3 circulos HORNEADOS y los botones reales encima daban vision doble. Panel limpio
	# transparente; los botones son los unicos circulos que se ven.
	var panel := Panel.new()
	panel.name = "ModuloVelocidad"
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.custom_minimum_size = Vector2(ANCHO_MODULO_VELOCIDAD, ALTO_MODULO)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(panel)
	var margen_v := MarginContainer.new()
	margen_v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margen_v)
	var contenido := CenterContainer.new()
	margen_v.add_child(contenido)
	var fila_botones := HBoxContainer.new()
	# 10px entre glifos: los botones ya no llevan relleno propio (styleboxes vacíos, ver abajo),
	# así que esta separación es TODO el aire que hay entre ellos.
	fila_botones.add_theme_constant_override("separation", 10)
	contenido.add_child(fila_botones)

	# "II" tipográfico y no "⏸" (fix 2026-08-09, auditoría de captura): el glifo ⏸ cae en la fuente
	# de EMOJIS del sistema (cuadrado azul de color, ignora `font_color`) mientras ▶ se queda en
	# presentación de texto navy — un botón con chip azul y tres glifos planos no son una familia.
	const GLIFOS := ["II", "▶", "▶▶", "▶▶▶"]
	const TOOLTIPS := ["Pausa", "1×", "2×", "3×"]
	for i in 4:
		var caja_v := VBoxContainer.new()
		caja_v.add_theme_constant_override("separation", 1)
		caja_v.alignment = BoxContainer.ALIGNMENT_CENTER
		var boton := Button.new()
		boton.focus_mode = Control.FOCUS_NONE   # gotcha ya conocido: si no, Espacio lo "pulsa".
		boton.text = GLIFOS[i]
		boton.tooltip_text = TOOLTIPS[i]
		boton.flat = true
		boton.add_theme_font_size_override("font_size", 14)
		boton.add_theme_color_override("font_color", KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL)
		# Sin las content margins del Button del tema (fix 2026-08-09, misma auditoría): `flat`
		# esconde el DIBUJO del stylebox pero no sus márgenes — cada botón arrastraba ~16px de
		# relleno y la fila respiraba desigual (el hueco ▶▶↔▶▶▶ parecía un agujero). Con el
		# stylebox vacío el ancho es el del glifo y la separación del HBox manda de verdad.
		for estado: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			boton.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
		boton.add_theme_color_override("font_hover_color", KitUIComisarioScript.COLOR_ACENTO_NAVY)
		# Captura por valor (mismo patrón ya probado en el HUD viejo, `Main._crear_barra_superior`):
		# cada iteración cierra sobre SU PROPIO `i`, no el último del bucle.
		boton.pressed.connect(func() -> void: Tiempo.fijar_velocidad(i as Tiempo.Velocidad))
		caja_v.add_child(boton)

		var pip := Label.new()
		pip.text = "▾"
		# 10px y no 8 (auditoría 2026-08-09): a 8px el triángulo era una mota que parecía suciedad.
		pip.add_theme_font_size_override("font_size", 10)
		pip.add_theme_color_override("font_color", KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL)
		pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# SIEMPRE visible con alfa (fix 2026-08-08: "al pulsar se cambia de posicion" — el toggle de
		# visible reflowaba la fila); activo = opaco, inactivo = transparente. Mismo hueco siempre.
		pip.modulate = Color(1, 1, 1, 0.0)
		caja_v.add_child(pip)

		fila_botones.add_child(caja_v)
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
	var contenido := _crear_modulo_9slice(
		fila, KitUIComisarioScript.VARIANTE_MODULO_SALDO, ANCHO_MODULO_SALDO, MARGEN_IZQ_SALDO
	)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 0)
	contenido.add_child(caja)
	_lbl_saldo = _etiqueta(16, KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL)
	caja.add_child(_lbl_saldo)
	_lbl_estado_fin = _etiqueta(10, KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL)
	caja.add_child(_lbl_estado_fin)


## Un módulo 9-slice REAL (`Panel` + `theme_type_variation`, ver la cabecera del archivo y la de
## `sb_mod_reloj` en el tema): a diferencia del piloto Fase 2 (un `TextureRect` a tamaño nativo),
## este SÍ se dimensiona al ancho pedido por la spec (`ancho`×`ALTO_MODULO`) -- el StyleBoxTexture
## protege el icono con su `texture_margin_left` medido, el resto de la card se estira/encoge.
func _crear_modulo_9slice(
	fila: HBoxContainer, variante: StringName, ancho: float, margen_izq: int
) -> CenterContainer:
	var panel := Panel.new()
	panel.name = "Modulo" + String(variante)
	panel.theme = KitUIComisarioScript.tema()
	panel.theme_type_variation = variante
	panel.custom_minimum_size = Vector2(ancho, ALTO_MODULO)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(panel)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", margen_izq)
	margen.add_theme_constant_override("margin_right", 10)
	margen.add_theme_constant_override("margin_top", 6)
	margen.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margen)

	var centro := CenterContainer.new()
	margen.add_child(centro)
	return centro


## Un chip de fondo plano (grupos 4-7, spec §1.3): icono pequeño (28×28, `KitUIComisario.icono`,
## escalado con `STRETCH_KEEP_ASPECT_CENTERED` -- a diferencia de los módulos 9-slice, un icono
## pictograma pequeño SÍ tolera reescalado sin distorsión perceptible) + 2 líneas de texto.
## Devuelve `{"linea1": Label, "linea2": Label}` -- quien llama guarda las referencias que necesite.
func _crear_chip_plano(fila: HBoxContainer, icono_id: StringName, ancho: float) -> Dictionary:
	var caja := HBoxContainer.new()
	caja.name = "Chip" + String(icono_id).capitalize()
	caja.custom_minimum_size = Vector2(ancho, 0)
	caja.add_theme_constant_override("separation", 6)
	caja.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(caja)

	var icono := TextureRect.new()
	icono.texture = KitUIComisarioScript.icono(icono_id)
	# EXPAND_IGNORE_SIZE (fix 2026-08-08, cazado en captura): sin él, el mínimo del TextureRect es
	# el tamaño NATIVO del PNG (~512px) y el icono revienta la barra — el mismo bug ya resuelto en
	# las miniaturas de tarjetas. El custom_minimum_size de 28px solo manda con este expand_mode.
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.custom_minimum_size = Vector2(28, 28)
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(icono)

	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 0)
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(textos)

	var linea1 := _etiqueta(13, KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL)
	linea1.clip_text = true
	textos.add_child(linea1)
	var linea2 := _etiqueta(11, COLOR_NAVY_TENUE)
	linea2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	linea2.clip_text = true
	textos.add_child(linea2)

	return {"linea1": linea1, "linea2": linea2}


## Una etiqueta del panel superior: tamaño pedido + color + contorno del MISMO navy (2px) -- el
## contorno es lo que garantiza que se siga leyendo pase lo que pase con el color dinámico que le
## ponga `refrescar()` (mismo criterio ya verificado en pantalla por el piloto Fase 2: un contorno
## oscuro modulado por un color de estado sigue siendo mucho más oscuro que el fondo pastel).
func _etiqueta(tam: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.add_theme_font_size_override("font_size", tam)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override(
		"font_outline_color", KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL
	)
	etiqueta.add_theme_constant_override("outline_size", 2)
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
	# Tema SIN `theme_type_variation` a propósito -- mismo estilo por defecto que usa el panel raíz
	# de `ModoConstruccion` justo debajo (`panel.theme = KitUIComisarioScript.tema()`, sin variante
	# tampoco allí): las dos franjas quedan visualmente cosidas, sin costura entre ellas.
	panel.theme = KitUIComisarioScript.tema()
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

	var boton_personal := _boton_pildora(
		&"personal", "Personal (P)", KitUIComisarioScript.VARIANTE_PILDORA_PRIMARIA, Color.WHITE
	)
	boton_personal.pressed.connect(func() -> void: personal_solicitado.emit())
	fila.add_child(boton_personal)
	_botones_acciones.append(boton_personal)

	var boton_horario := _boton_pildora(
		&"reloj", "Horario (H)", KitUIComisarioScript.VARIANTE_PILDORA_PRIMARIA, Color.WHITE
	)
	boton_horario.pressed.connect(func() -> void: horario_solicitado.emit())
	fila.add_child(boton_horario)
	_botones_acciones.append(boton_horario)

	fila.add_child(_espaciador_familia())

	var color_secundaria: Color = KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL
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
	boton.theme = KitUIComisarioScript.tema()
	boton.theme_type_variation = variante
	boton.focus_mode = Control.FOCUS_NONE
	boton.custom_minimum_size = Vector2(0, 40)   # el ancho real se fija al final con el texto medido

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
