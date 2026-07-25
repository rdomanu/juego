class_name PanelPersonal extends CanvasLayer
## PanelPersonal — el ANDAMIO de gestión de plantilla y mercado (feedback flujo-008: "no veo cómo
## contratar; aunque construya un puesto no se cubre con nadie").
##
## Dos columnas: PLANTILLA (agentes contratados — asignar a puestos, desasignar, despedir) y MERCADO
## (candidatos — contratar). Se abre/cierra con la tecla P y se puede operar EN PAUSA (el reloj parado
## no bloquea la gestión — regla del manifiesto). Construido por código (patrón del HUD/ModoConstruccion:
## el proyecto no usa .tscn salvo Main).
##
## Reglas (control-manifest, Presentation): la UI LEE el estado y ORDENA por la API pública de Personal
## (`contratar`/`asignar`/`desasignar`/`despedir`) y LEE Flujo/Construcción/Economía — NUNCA muta el
## modelo ni el saldo directamente (ADR-0001). Botones con `focus_mode = FOCUS_NONE` (gotcha: si no,
## Espacio "pulsa" el botón enfocado en vez de pausar). Filas de botones de texto variable en
## HFlowContainer (gotcha: con HBox fijo los últimos botones se salen de pantalla). Este andamio NO es
## la UI real: UI/HUD #11 (tras /ux-design) lo sustituirá.
##
## Story: feedback flujo-008 (panel de personal provisional) · ADR-0001

const AgenteScript := preload("res://src/core/personal/agente.gd")

## Colores de estado (SIEMPRE acompañados de texto — respaldo daltónico, regla del proyecto).
const COLOR_LIBRE := Color(1.0, 0.8, 0.35)          # ámbar — en el banquillo
const COLOR_ASIGNADO := Color(0.55, 0.9, 0.55)      # verde — en puesto
const COLOR_AUSENTE := Color(0.6, 0.6, 0.6)         # gris — de baja
const COLOR_CUBRIENDO := Color(0.5, 0.75, 1.0)      # azul claro — cubriendo
const COLOR_TITULO := Color(1.0, 0.85, 0.35)
const COLOR_TENUE := Color(1, 1, 1, 0.6)
## Separación entre tarjetas y borde de tarjeta (estética sobria del andamio).
const COLOR_BORDE_TARJETA := Color(1, 1, 1, 0.12)
## Escala de los atributos del agente (1-5, GDD staff-agents) — el MÁXIMO que dibuja la barra.
const ESCALA_ATRIBUTOS := 5
const COLOR_BARRA_LLENA := Color(0.85, 0.85, 0.92)
const COLOR_BARRA_VACIA := Color(1, 1, 1, 0.14)

# ── Refs a los sistemas Core (inyectadas por Main; la UI solo lee y ordena — ADR-0001) ───────
var _personal: Node = null
var _economia: Node = null
var _construccion: Node = null
var _flujo: Node = null

# ── Nodos de UI (construidos en configurar; el panel nace oculto) ────────────────────────────
var _panel: PanelContainer
var _lbl_saldo: Label
## Resumen "de un vistazo" (feedback 2026-07-25): plantilla y cobertura de puestos en una línea.
var _lbl_resumen: Label
## Un chip por puesto construido: quién lo cubre o VACANTE.
var _fila_puestos: HFlowContainer
var _lista_plantilla: VBoxContainer
var _lista_mercado: VBoxContainer
## Título de cada columna (lleva su contador: "PLANTILLA (4)").
var _cabecera_de: Dictionary[String, Label] = {}


## Inyección de dependencias + construcción de la UI (la llama Main tras add_child). El panel se crea
## OCULTO; se puebla al abrir (`_reconstruir`), nunca por frame.
func configurar(personal: Node, economia: Node, construccion: Node, flujo: Node) -> void:
	_personal = personal
	_economia = economia
	_construccion = construccion
	_flujo = flujo
	_crear_ui()
	visible = false


# ── Entrada (toggle con P; la UI solo ORDENA por la API pública) ─────────────────────────────
## Tecla P alterna la visibilidad. Al ABRIR reconstruye (foto fresca del estado). Se marca el input
## como consumido para no arrastrar la P a otros manejadores.
func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey and evento.pressed and not (evento as InputEventKey).echo):
		return
	if (evento as InputEventKey).keycode == KEY_P:
		visible = not visible
		if visible:
			_reconstruir()
		get_viewport().set_input_as_handled()


# ── Construcción de la UI (por código; patrón del HUD del esqueleto) ─────────────────────────
## Monta el marco: PanelContainer centrado con título + saldo + dos columnas con scroll + cerrar.
func _crear_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(880, 600)
	# Anclado al centro, el preset deja el tamaño en 0×0 y crece por el minimum → recentrar el pivote.
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	_panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = "Personal — plantilla y mercado (P para cerrar)"
	titulo.add_theme_font_size_override("font_size", 14)
	titulo.modulate = COLOR_TITULO
	caja.add_child(titulo)

	_lbl_saldo = Label.new()
	_lbl_saldo.add_theme_font_size_override("font_size", 12)
	caja.add_child(_lbl_saldo)

	# Resumen de un vistazo (feedback 2026-07-25: "no sé cuántos tengo ni cuántos puestos cubiertos").
	_lbl_resumen = Label.new()
	_lbl_resumen.add_theme_font_size_override("font_size", 13)
	_lbl_resumen.autowrap_mode = TextServer.AUTOWRAP_WORD
	caja.add_child(_lbl_resumen)

	# Un chip por puesto (HFlowContainer: los nombres son de largo variable — gotcha de ancho).
	_fila_puestos = HFlowContainer.new()
	_fila_puestos.add_theme_constant_override("h_separation", 6)
	_fila_puestos.add_theme_constant_override("v_separation", 4)
	caja.add_child(_fila_puestos)

	var columnas := HBoxContainer.new()
	columnas.add_theme_constant_override("separation", 12)
	columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(columnas)
	_lista_plantilla = _crear_columna(columnas, "PLANTILLA")
	_lista_mercado = _crear_columna(columnas, "MERCADO")

	var cerrar := Button.new()
	cerrar.text = "Cerrar (P)"
	cerrar.focus_mode = Control.FOCUS_NONE
	cerrar.pressed.connect(func() -> void: visible = false)
	caja.add_child(cerrar)


## Una columna: cabecera + ScrollContainer con la lista (VBox) que repuebla `_reconstruir`. Devuelve
## el VBox interior (donde van las tarjetas).
func _crear_columna(padre: HBoxContainer, titulo: String) -> VBoxContainer:
	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_theme_constant_override("separation", 4)
	padre.add_child(columna)

	var cabecera := Label.new()
	cabecera.text = titulo
	cabecera.add_theme_font_size_override("font_size", 12)
	cabecera.modulate = COLOR_TENUE
	columna.add_child(cabecera)
	_cabecera_de[titulo] = cabecera   # `_reconstruir` le añade su contador ("PLANTILLA (4)")

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(scroll)

	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 6)
	scroll.add_child(lista)
	return lista


# ── Reconstrucción (al abrir y tras CADA acción; NUNCA por frame) ────────────────────────────
## Borra y repuebla ambas listas desde una foto fresca del estado. Refresca saldo y resumen (solo lectura).
func _reconstruir() -> void:
	var nomina: float = 0.0
	for agente: RefCounted in _personal.plantilla:
		nomina += _personal.salario_dia(agente)
	_lbl_saldo.text = "Saldo: %.2f €   ·   Nómina: %.0f €/día" % [
		(_economia.saldo_eur if _economia != null else 0.0), nomina,
	]
	_poblar_resumen()
	_cabecera_de["PLANTILLA"].text = "PLANTILLA (%d)" % _personal.plantilla.size()
	_cabecera_de["MERCADO"].text = "MERCADO (%d)" % _personal.mercado.size()
	_vaciar(_lista_plantilla)
	_vaciar(_lista_mercado)
	_poblar_plantilla()
	_poblar_mercado()


## Resumen de un vistazo (feedback 2026-07-25): cuánta gente hay y en qué está, y cuántos puestos
## quedan sin cubrir — lo primero que el jugador necesita saber al abrir el panel. Los chips de abajo
## dicen QUIÉN está en cada ventanilla (o VACANTE). Ámbar mientras haya vacantes, verde si están todas
## cubiertas (texto SIEMPRE, el color solo refuerza — respaldo daltónico).
func _poblar_resumen() -> void:
	var en_puesto: int = 0
	var banquillo: int = 0
	var de_baja: int = 0
	for agente: RefCounted in _personal.plantilla:
		match agente.estado:
			AgenteScript.ESTADO_ASIGNADO, AgenteScript.ESTADO_CUBRIENDO:
				en_puesto += 1
			AgenteScript.ESTADO_AUSENTE:
				de_baja += 1
			_:
				banquillo += 1
	var puestos: Array[StringName] = _flujo.puestos_registrados()
	var cubiertos: int = 0
	for puesto_id: StringName in puestos:
		if _personal.puesto_dotado(puesto_id):
			cubiertos += 1
	var vacantes: int = puestos.size() - cubiertos
	_lbl_resumen.text = "Plantilla: %d  (en puesto %d · banquillo %d · de baja %d)   —   Ventanillas cubiertas: %d de %d" % [
		_personal.plantilla.size(), en_puesto, banquillo, de_baja, cubiertos, puestos.size(),
	]
	_lbl_resumen.modulate = COLOR_ASIGNADO if vacantes == 0 and not puestos.is_empty() else COLOR_LIBRE

	for hijo: Node in _fila_puestos.get_children():
		hijo.queue_free()
	if puestos.is_empty():
		_fila_puestos.add_child(_texto_vacio("Sin ventanillas construidas."))
		return
	for puesto_id: StringName in puestos:
		_fila_puestos.add_child(_chip_puesto(puesto_id))


## Chip de una ventanilla. La verdad es `puesto_dotado` (gate FL4), no "hay un nombre": un titular
## DE BAJA sin cobertura deja la ventanilla cerrada aunque tenga dueño → se pinta en gris y NO cuenta
## como cubierta (si no, el resumen diría "cubierta" y el juego no atendería ahí).
func _chip_puesto(puesto_id: StringName) -> PanelContainer:
	var agente: RefCounted = _personal.agente_de(puesto_id)
	var dotado: bool = _personal.puesto_dotado(puesto_id)
	var quien: String = "VACANTE"
	var color: Color = COLOR_LIBRE
	if agente != null:
		if not dotado:
			quien = "%s (de baja)" % agente.nombre
			color = COLOR_AUSENTE
		elif agente.estado == AgenteScript.ESTADO_CUBRIENDO:
			quien = "%s (cubriendo)" % agente.nombre
			color = COLOR_CUBRIENDO
		else:
			quien = agente.nombre
			color = COLOR_ASIGNADO
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.text = "%s · %s — %s" % [
		puesto_id, _nombre_tipo_puesto(_construccion.catalogo_de(puesto_id)), quien,
	]
	lbl.modulate = color
	var chip := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(1, 1, 1, 0.05)
	estilo.set_border_width_all(1)
	estilo.border_color = COLOR_BORDE_TARJETA
	estilo.set_content_margin_all(4)
	chip.add_theme_stylebox_override("panel", estilo)
	chip.add_child(lbl)
	return chip


## Borra los hijos de una lista (queue_free — se limpian al final del frame; el repoblado añade nuevos).
func _vaciar(lista: VBoxContainer) -> void:
	for hijo: Node in lista.get_children():
		hijo.queue_free()


## Repuebla PLANTILLA: una tarjeta por agente con sus datos, su estado legible y sus acciones según
## estado (libre → asignar a cada puesto compatible libre + despedir; asignado → desasignar + despedir;
## ausente/cubriendo → sin acciones).
func _poblar_plantilla() -> void:
	if _personal.plantilla.is_empty():
		_lista_plantilla.add_child(_texto_vacio("Plantilla vacía."))
		return
	for agente: RefCounted in _personal.plantilla:
		_lista_plantilla.add_child(_tarjeta_agente(agente))


## Repuebla MERCADO: cabecera de refresco + una tarjeta por candidato con su botón "Contratar".
func _poblar_mercado() -> void:
	var cabecera := Label.new()
	cabecera.text = "Candidatos — el mercado se renueva cada 3 días"
	cabecera.add_theme_font_size_override("font_size", 10)
	cabecera.modulate = COLOR_TENUE
	_lista_mercado.add_child(cabecera)
	if _personal.mercado.is_empty():
		_lista_mercado.add_child(_texto_vacio("No hay candidatos ahora mismo."))
		return
	for indice: int in _personal.mercado.size():
		_lista_mercado.add_child(_tarjeta_candidato(indice))


# ── Tarjetas ─────────────────────────────────────────────────────────────────────────────────
## Tarjeta de un agente de la plantilla: identidad + atributos/salario + estado + acciones.
func _tarjeta_agente(agente: RefCounted) -> PanelContainer:
	var tarjeta := _marco_tarjeta()
	var caja := tarjeta.get_child(0) as VBoxContainer

	caja.add_child(_linea_identidad(agente, 12))
	caja.add_child(_linea_atributos(agente))
	caja.add_child(_linea_estado(agente))

	# Acciones según estado (HFlowContainer: los textos de puesto son variables — gotcha de ancho).
	if agente.estado == AgenteScript.ESTADO_LIBRE:
		var asignables: Array[StringName] = _puestos_asignables(agente)
		var acciones := _fila_acciones()
		for puesto_id: StringName in asignables:
			var nombre_tipo: String = _nombre_tipo_puesto(_construccion.catalogo_de(puesto_id))
			acciones.add_child(_boton(
				"→ %s (%s)" % [puesto_id, nombre_tipo],
				_al_asignar.bind(agente, puesto_id)
			))
		acciones.add_child(_boton("Despedir", _al_despedir.bind(agente)))
		# Sin puestos compatibles libres: explica POR QUÉ no hay botones de asignar (feedback flujo-008).
		if asignables.is_empty():
			var operables: String = _operables_legibles(agente.tipo_id)
			var aviso := Label.new()
			aviso.add_theme_font_size_override("font_size", 10)
			aviso.modulate = COLOR_TENUE
			aviso.autowrap_mode = TextServer.AUTOWRAP_WORD
			aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			aviso.text = (
				"Sin puestos libres compatibles — este perfil opera: %s" % operables
				if operables != "" else "Sin puestos libres compatibles"
			)
			caja.add_child(aviso)
		caja.add_child(acciones)
	elif agente.estado == AgenteScript.ESTADO_ASIGNADO:
		var acciones := _fila_acciones()
		acciones.add_child(_boton("Desasignar", _al_desasignar.bind(agente)))
		acciones.add_child(_boton("Despedir", _al_despedir.bind(agente)))
		caja.add_child(acciones)
	# AUSENTE / CUBRIENDO: sin acciones (no se toca a quien está de baja o prestado).
	return tarjeta


## Tarjeta de un candidato del mercado: identidad + atributos + botón Contratar (con su salario diario).
func _tarjeta_candidato(indice: int) -> PanelContainer:
	var candidato: RefCounted = _personal.mercado[indice]
	var tarjeta := _marco_tarjeta()
	var caja := tarjeta.get_child(0) as VBoxContainer
	caja.add_child(_linea_identidad(candidato, 12))
	caja.add_child(_linea_atributos(candidato))
	# Qué compra el jugador: los tipos de puesto que este perfil sabe operar (feedback flujo-008).
	var operables: String = _operables_legibles(candidato.tipo_id)
	if operables != "":
		var lbl_opera := Label.new()
		lbl_opera.add_theme_font_size_override("font_size", 10)
		lbl_opera.modulate = COLOR_TENUE
		lbl_opera.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl_opera.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_opera.text = "Opera: %s" % operables
		caja.add_child(lbl_opera)
	var acciones := _fila_acciones()
	acciones.add_child(_boton(
		"Contratar — %.0f €/día" % _personal.salario_dia(candidato),
		_al_contratar.bind(indice)
	))
	caja.add_child(acciones)
	return tarjeta


## Marco de tarjeta: PanelContainer con borde tenue + VBox interior (hijo 0 — de ahí lo saca el caller).
func _marco_tarjeta() -> PanelContainer:
	var tarjeta := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(1, 1, 1, 0.03)
	estilo.set_border_width_all(1)
	estilo.border_color = COLOR_BORDE_TARJETA
	estilo.set_content_margin_all(6)
	tarjeta.add_theme_stylebox_override("panel", estilo)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	tarjeta.add_child(caja)
	return tarjeta


## Línea 1: "Nombre — Tipo · Rango" (el "Tipo" legible es el puesto orgánico del catálogo).
func _linea_identidad(agente: RefCounted, tam: int) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", tam)
	lbl.text = "%s — %s · %s" % [agente.nombre, _nombre_tipo_agente(agente.tipo_id), _rango_legible(agente.rango)]
	return lbl


## Bloque de atributos: una BARRA por atributo (5 casillas = la escala 1-5 del GDD) + su número, y el
## salario debajo. Feedback del usuario 2026-07-25: *"las skills deben ser como una barra para ver dónde
## está el máximo y el mínimo; no sé si 4 es mucho o poco, si es sobre 5 o sobre 100"*. El número solo
## no dice nada si no ves la escala — y ese panel existe para decidir a quién contratar.
func _linea_atributos(agente: RefCounted) -> VBoxContainer:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 1)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(_barra_atributo("Rapidez", agente.rapidez))
	caja.add_child(_barra_atributo("Trato", agente.trato))
	caja.add_child(_barra_atributo("Salud", agente.salud))
	caja.add_child(_barra_atributo("Motivación", agente.motivacion))
	if agente.rango == AgenteScript.RANGO_OFICIAL:
		caja.add_child(_barra_atributo("Mando", agente.mando))
	var salario := Label.new()
	salario.add_theme_font_size_override("font_size", 10)
	salario.modulate = COLOR_TENUE
	salario.text = "%.0f €/día" % _personal.salario_dia(agente)
	caja.add_child(salario)
	return caja


## Una fila "Nombre [▮▮▮▮▯] 4/5": casillas llenas hasta el valor, vacías hasta el máximo. El número va
## SIEMPRE al lado (la barra sola no es accesible: texto + forma, nunca solo color).
func _barra_atributo(nombre: String, valor: int) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 4)

	var etiqueta := Label.new()
	etiqueta.text = nombre
	etiqueta.add_theme_font_size_override("font_size", 10)
	etiqueta.modulate = COLOR_TENUE
	etiqueta.custom_minimum_size = Vector2(66, 0)   # columna fija: las barras quedan alineadas
	fila.add_child(etiqueta)

	var casillas := HBoxContainer.new()
	casillas.add_theme_constant_override("separation", 2)
	for i: int in ESCALA_ATRIBUTOS:
		var casilla := ColorRect.new()
		casilla.custom_minimum_size = Vector2(11, 8)
		casilla.color = COLOR_BARRA_LLENA if i < valor else COLOR_BARRA_VACIA
		casilla.mouse_filter = Control.MOUSE_FILTER_IGNORE   # gotcha: decorativo → no se traga clics
		casillas.add_child(casilla)
	fila.add_child(casillas)

	var cifra := Label.new()
	cifra.text = "%d/%d" % [valor, ESCALA_ATRIBUTOS]
	cifra.add_theme_font_size_override("font_size", 10)
	cifra.modulate = COLOR_TENUE
	fila.add_child(cifra)
	return fila


## Línea 3 (font 10): estado legible con su color (SIEMPRE texto + color — daltónicos).
func _linea_estado(agente: RefCounted) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 10)
	var donde: String = String(agente.puesto_id)
	match agente.estado:
		AgenteScript.ESTADO_LIBRE:
			lbl.text = "En el banquillo"
			lbl.modulate = COLOR_LIBRE
		AgenteScript.ESTADO_ASIGNADO:
			lbl.text = "En %s" % donde
			lbl.modulate = COLOR_ASIGNADO
		AgenteScript.ESTADO_AUSENTE:
			lbl.text = "De baja hoy"
			lbl.modulate = COLOR_AUSENTE
		AgenteScript.ESTADO_CUBRIENDO:
			lbl.text = "Cubriendo en %s" % donde
			lbl.modulate = COLOR_CUBRIENDO
		_:
			lbl.text = String(agente.estado)
	return lbl


## Un texto tenue de "lista vacía".
func _texto_vacio(texto: String) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = COLOR_TENUE
	return lbl


## Fila de botones de acción (HFlowContainer — texto variable envuelve en vez de salirse — gotcha).
func _fila_acciones() -> HFlowContainer:
	var fila := HFlowContainer.new()
	fila.add_theme_constant_override("h_separation", 6)
	fila.add_theme_constant_override("v_separation", 4)
	return fila


## Un botón de acción (font 10, focus NONE — gotcha de Espacio). `accion` es un Callable ya bindeado.
func _boton(texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.add_theme_font_size_override("font_size", 10)
	boton.focus_mode = Control.FOCUS_NONE
	boton.pressed.connect(accion)
	return boton


# ── Consultas de solo lectura (LEEN Flujo/Construcción/Personal — nunca mutan; ADR-0001) ─────
## Puestos a los que este agente LIBRE se puede asignar: cada puesto construido registrado en Flujo
## cuyo tipo esté en los `puestos_operables` del agente Y que no esté ya dotado (sin plaza).
func _puestos_asignables(agente: RefCounted) -> Array[StringName]:
	var resultado: Array[StringName] = []
	var tipo_agente: Resource = Datos.obtener(&"TipoAgente", agente.tipo_id)
	if tipo_agente == null:
		return resultado
	for puesto_id: StringName in _flujo.puestos_registrados():
		var tipo_puesto: StringName = _construccion.catalogo_de(puesto_id)
		if tipo_puesto in tipo_agente.puestos_operables and not _personal.puesto_dotado(puesto_id):
			resultado.append(puesto_id)
	return resultado


## Nombre legible de un perfil de agente (el catálogo usa `puesto_organico` como nombre visible).
func _nombre_tipo_agente(tipo_id: StringName) -> String:
	var tipo: Resource = Datos.obtener(&"TipoAgente", tipo_id)
	return tipo.puesto_organico if tipo != null else String(tipo_id)


## Nombre visible de un tipo de puesto (para el botón "→ id (Nombre)").
func _nombre_tipo_puesto(tipo_id: StringName) -> String:
	var tipo: Resource = Datos.obtener(&"TipoPuesto", tipo_id)
	return tipo.nombre if tipo != null else String(tipo_id)


## Nombres legibles de los tipos de puesto que este perfil de agente puede operar, unidos con ", ".
## Cadena vacía si el catálogo no tiene el TipoAgente (el caller omite entonces la coletilla).
func _operables_legibles(tipo_id: StringName) -> String:
	var tipo: Resource = Datos.obtener(&"TipoAgente", tipo_id)
	if tipo == null:
		return ""
	var nombres: Array[String] = []
	for t: StringName in tipo.puestos_operables:
		nombres.append(_nombre_tipo_puesto(t))
	return ", ".join(nombres)


## Rango en texto llano.
func _rango_legible(rango: StringName) -> String:
	return "Oficial" if rango == AgenteScript.RANGO_OFICIAL else "Policía"


# ── Callbacks de acción (ORDENAN por la API pública y reconstruyen; ADR-0001) ────────────────
## Contratar: los índices del mercado cambian al contratar → SIEMPRE se reconstruye (nunca se
## reutiliza un índice viejo). Si devuelve false (sin caja) no pasa nada; el saldo está visible arriba.
func _al_contratar(indice: int) -> void:
	_personal.contratar(indice)
	_reconstruir()


## Asignar: si devuelve false (p. ej. plaza de un titular de baja) es un rechazo de regla silencioso.
func _al_asignar(agente: RefCounted, puesto_id: StringName) -> void:
	_personal.asignar(agente, puesto_id)
	_reconstruir()


func _al_desasignar(agente: RefCounted) -> void:
	_personal.desasignar(agente)
	_reconstruir()


func _al_despedir(agente: RefCounted) -> void:
	_personal.despedir(agente)
	_reconstruir()
