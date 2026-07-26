class_name PanelAdmin extends CanvasLayer
## PanelAdmin — el CUADRO DE MANDOS de desarrollo (petición del usuario 2026-07-26: *"la espera se
## debería poder calibrar en un panel admin de todo el juego, como las visitas, los trámites..."*).
##
## Permite tocar EN CALIENTE los números que definen la sensación del juego —cuánto aguanta la gente,
## cuánta viene, a qué ritmo corre el reloj— y ver el efecto sin reiniciar ni tocar código. Es la
## herramienta con la que se calibra el balance jugando, en vez de a ciegas.
##
## ⚠️ HERRAMIENTA DE DESARROLLO, no una pantalla del juego:
## - Los cambios afectan al RUNTIME, **no** se escriben en los `.tres` del catálogo. Al reiniciar se
##   vuelve a los valores semilla. Cuando un número convenza, se fija en su `build_config_*.gd`.
## - Cada knob enseña su **rango** (principio U5 del backlog de pulido: ningún número sin su escala).
## - Solo LEE y ORDENA por la API pública de cada sistema (ADR-0001): aquí no se muta nada a mano.
##
## Story: feedback del usuario 2026-07-26 (herramienta de calibración) · ADR-0001

const COLOR_TITULO := Color(1.0, 0.85, 0.35)
const COLOR_TENUE := Color(1, 1, 1, 0.6)
const COLOR_AVISO := Color(1.0, 0.6, 0.35)
const COLOR_SECCION := Color(0.6, 0.8, 1.0)

var _paciencia: Node = null
var _demanda: Node = null
var _flujo: Node = null
var _construccion: Node = null
var _tiempo: Node = null
var _economia: Node = null
var _personal: Node = null
## Documentación (story doc-002): dueña del horario — sus knobs son los de la sección del horario.
var _documentacion: Node = null

## Dónde vive el `.tres` de cada sistema y qué clase de config usa — para poder FIJAR lo calibrado.
const CONFIGS: Dictionary[String, Dictionary] = {
	"paciencia": {
		"ruta": "res://datos/config/paciencia.tres",
		"script": "res://src/feature/paciencia/config_paciencia.gd",
	},
	"demanda": {
		"ruta": "res://datos/config/demanda.tres",
		"script": "res://src/core/demanda/config_demanda.gd",
	},
	"flujo": {
		"ruta": "res://datos/config/flujo.tres",
		"script": "res://src/core/flujo/config_flujo.gd",
	},
	"construccion": {
		"ruta": "res://datos/config/construccion.tres",
		"script": "res://src/core/construccion/config_construccion.gd",
	},
	"tiempo": {
		"ruta": "res://datos/config/tiempo.tres",
		"script": "res://src/foundation/tiempo/config_tiempo.gd",
	},
	"documentacion": {
		"ruta": "res://datos/config/documentacion.tres",
		"script": "res://src/feature/documentacion/config_documentacion.gd",
	},
}

var _panel: PanelContainer
var _lista: VBoxContainer
## Etiquetas de valor por knob, para refrescarlas al mover su barra.
var _valor_de: Dictionary[String, Label] = {}
## Termómetro en vivo (arriba) y resultado de la última acción (abajo).
var _lbl_metricas: Label = null
var _lbl_resultado: Label = null


## Un knob calibrable: dónde vive, cómo se llama de cara al jugador, su rango y el paso de ajuste.
## `objetivo` se resuelve en el momento de aplicar (los sistemas se inyectan después de construir).
class Knob extends RefCounted:
	var sistema: String
	var propiedad: String
	var etiqueta: String
	var ayuda: String
	var minimo: float
	var maximo: float
	var paso: float
	var decimales: int

	func _init(
		p_sistema: String, p_propiedad: String, p_etiqueta: String, p_ayuda: String,
		p_min: float, p_max: float, p_paso: float, p_decimales: int = 1
	) -> void:
		sistema = p_sistema
		propiedad = p_propiedad
		etiqueta = p_etiqueta
		ayuda = p_ayuda
		minimo = p_min
		maximo = p_max
		paso = p_paso
		decimales = p_decimales

	func clave() -> String:
		return "%s.%s" % [sistema, propiedad]


func configurar(
	paciencia: Node, demanda: Node, flujo: Node, construccion: Node,
	tiempo: Node = null, economia: Node = null, personal: Node = null,
	documentacion: Node = null
) -> void:
	_paciencia = paciencia
	_demanda = demanda
	_flujo = flujo
	_construccion = construccion
	_tiempo = tiempo
	_economia = economia
	_personal = personal
	_documentacion = documentacion
	_crear_ui()
	visible = false


## Tecla F1 abre y cierra. Al abrir se refrescan los valores (pueden haber cambiado por otra vía).
func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey and evento.pressed and not (evento as InputEventKey).echo):
		return
	if (evento as InputEventKey).keycode == KEY_F1:
		alternar()
		get_viewport().set_input_as_handled()


func alternar() -> void:
	visible = not visible
	if visible:
		_refrescar_valores()


# ── Los knobs, agrupados por lo que el jugador NOTA (no por sistema interno) ─────────────────
func _grupos() -> Array:
	return [
		["⏳ LA ESPERA — cuánto aguanta la gente", [
			Knob.new(
				"paciencia", "tolerancia_base_min", "Aguante base",
				"Minutos que espera una persona antes de largarse (sala normal)", 5.0, 120.0, 5.0, 0
			),
			Knob.new(
				"paciencia", "k_hacinamiento", "Castigo por sala llena",
				"0 = da igual el gentío · 1 = una sala al 150% cabrea un 50% más rápido", 0.0, 3.0, 0.1
			),
			Knob.new(
				"paciencia", "prob_reclamacion", "Prob. de reclamación",
				"De cada 10 que se van, cuántos ponen una hoja (0.4 = 4)", 0.0, 1.0, 0.05, 2
			),
			Knob.new(
				"paciencia", "puntuacion_base", "Puntuación de una visita normal",
				"Lo que puntúa una atención sin espera y con trato neutro (sobre 100)", 0.0, 100.0, 5.0, 0
			),
			Knob.new(
				"paciencia", "k_espera", "Cuánto penaliza la espera al puntuar",
				"0 = esperar no baja la nota · 0.5 = quien llega al límite puntúa la mitad", 0.0, 1.0, 0.05, 2
			),
			Knob.new(
				"paciencia", "peso_prioridad_prioritaria", "Peso de una denuncia urgente",
				"Cuánto cuenta una Prioritaria de ODAC frente a una normal en la satisfacción", 1.0, 5.0, 0.5
			),
		]],
		["🚶 LAS VISITAS — cuánta gente viene", [
			Knob.new(
				"demanda", "tasa_base_doc", "Documentación (por 1.000 hab/día)",
				"0.5 en Pozuelo (90.000 hab) ≈ 45 personas al día", 0.0, 2.0, 0.05, 2
			),
			Knob.new(
				"demanda", "tasa_base_odac", "Denuncias ODAC (por 1.000 hab/día)",
				"0.4 en Pozuelo ≈ 36 denuncias al día, repartidas 24 h", 0.0, 2.0, 0.05, 2
			),
			Knob.new(
				"demanda", "mult_nocturno_odac", "Goteo nocturno de ODAC",
				"Cuánto se reduce la afluencia de 00:00 a 07:00 (0.5 = a la mitad)", 0.0, 1.0, 0.05, 2
			),
		]],
		["🕐 EL HORARIO Y EL RELOJ", [
			Knob.new(
				"documentacion", "apertura_base_min", "Documentación abre (minuto del día)",
				"480 = 08:00. Los puestos de Doc se abren solos a esta hora", 0.0, 1439.0, 30.0, 0
			),
			Knob.new(
				"documentacion", "cierre_base_min", "Documentación cierra (jornada base)",
				"870 = 14:30. A partir de aquí, alargar cuesta peonada", 0.0, 1439.0, 30.0, 0
			),
			Knob.new(
				"documentacion", "margen_ultima_admision_min", "Deja de dar número (min antes de cerrar)",
				"15 = el personal sale a su hora. 0 = se exprime hasta el cierre", 0.0, 30.0, 5.0, 0
			),
			Knob.new(
				"tiempo", "escala_tiempo", "Ritmo del reloj",
				"Minutos de juego por segundo real a 1x (4 = una jornada en 6 minutos)", 1.0, 30.0, 1.0, 0
			),
		]],
		["🏛 LA COMISARÍA — ritmo y espacio", [
			Knob.new(
				"flujo", "velocidad_camino_celdas_min", "Paso hacia la ventanilla",
				"Celdas por minuto de juego. 0 = llegan al instante", 0.0, 3.0, 0.125, 3
			),
			Knob.new(
				"construccion", "densidad_de_pie", "Gente de pie por celda",
				"Cuánta gente cabe DE PIE en la sala (además de los asientos)", 0.0, 1.5, 0.1
			),
			Knob.new(
				"construccion", "densidad_asientos", "Asientos por celda",
				"Cuántos asientos caben por celda de sala", 0.1, 1.5, 0.1
			),
		]],
	]


# ── Construcción de la UI (por código, patrón del proyecto) ──────────────────────────────────
func _crear_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(760, 680)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	_panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = "⚙ Panel de calibración (F1 para cerrar)"
	titulo.add_theme_font_size_override("font_size", 15)
	titulo.modulate = COLOR_TITULO
	caja.add_child(titulo)

	var aviso := Label.new()
	aviso.text = (
		"Herramienta de desarrollo: los cambios valen para esta partida y NO se guardan en el "
		+ "catálogo. Cuando un número te convenza, dímelo y lo dejo fijo."
	)
	aviso.add_theme_font_size_override("font_size", 10)
	aviso.modulate = COLOR_AVISO
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD
	caja.add_child(aviso)

	# Termómetro en vivo: lo que está pasando AHORA, para ver el efecto de lo que se toca.
	_lbl_metricas = Label.new()
	_lbl_metricas.add_theme_font_size_override("font_size", 11)
	_lbl_metricas.modulate = COLOR_SECCION
	_lbl_metricas.autowrap_mode = TextServer.AUTOWRAP_WORD
	caja.add_child(_lbl_metricas)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 4)
	scroll.add_child(_lista)

	for grupo: Array in _grupos():
		_lista.add_child(_cabecera_grupo(grupo[0]))
		for knob: Knob in grupo[1]:
			_lista.add_child(_fila_knob(knob))

	var acciones := HFlowContainer.new()
	acciones.add_theme_constant_override("h_separation", 6)
	caja.add_child(acciones)
	acciones.add_child(_boton("💾 Fijar estos valores en el catálogo", _fijar_en_catalogo))
	acciones.add_child(_boton("↩ Volver a los del catálogo", _restaurar_del_catalogo))
	acciones.add_child(_boton("Cerrar (F1)", func() -> void: visible = false))
	_lbl_resultado = Label.new()
	_lbl_resultado.add_theme_font_size_override("font_size", 10)
	_lbl_resultado.modulate = COLOR_TENUE
	_lbl_resultado.autowrap_mode = TextServer.AUTOWRAP_WORD
	caja.add_child(_lbl_resultado)


func _boton(texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.add_theme_font_size_override("font_size", 11)
	boton.focus_mode = Control.FOCUS_NONE
	boton.pressed.connect(accion)
	return boton


## Refresca el termómetro (solo con el panel abierto: cero coste mientras está cerrado).
func _process(_delta: float) -> void:
	if not visible or _lbl_metricas == null:
		return
	var partes: Array[String] = []
	if _tiempo != null:
		partes.append("🕐 %s · A%d M%02d S%d" % [
			_tiempo.hhmm(_tiempo.minutos_juego), _tiempo.anio, _tiempo.mes, _tiempo.semana,
		])
	if _flujo != null:
		partes.append("cola %d Doc / %d ODAC · atendiendo %d" % [
			_flujo.personas_en_cola(&"Documentacion"), _flujo.personas_en_cola(&"ODAC"),
			_flujo.atendiendo_total(),
		])
	if _paciencia != null:
		partes.append("esperando %d · sat %d/100 (ayer %d) · quejas hoy %d" % [
			_paciencia.personas_vigiladas(), roundi(_paciencia.sat_global()),
			roundi(_paciencia.sat_cierre_de(&"Documentacion")), _paciencia.reclamaciones_jornada,
		])
	if _economia != null:
		partes.append("saldo %.0f €" % _economia.saldo_eur)
	partes.append("%d FPS" % Engine.get_frames_per_second())
	_lbl_metricas.text = "  |  ".join(partes)


# ── Fijar / restaurar: lo que cierra el bucle de calibración ─────────────────────────────────
## Escribe los valores VIVOS de cada sistema en su `.tres`, para que sobrevivan al reinicio. Es la
## operación que convierte "he encontrado el número bueno jugando" en una decisión del proyecto, sin
## tener que dictar una lista de cifras a nadie.
##
## Solo en desarrollo (este panel no existe en un build exportado) y solo toca las propiedades que el
## panel expone: el resto del `.tres` se conserva tal cual.
func _fijar_en_catalogo() -> void:
	var guardados: Array[String] = []
	var fallos: Array[String] = []
	for sistema: String in _sistemas_con_knobs():
		if _guardar_config_de(sistema):
			guardados.append(sistema)
		else:
			fallos.append(sistema)
	if fallos.is_empty():
		_lbl_resultado.text = "✅ Fijado en el catálogo: %s. Sobrevive al reinicio." % ", ".join(guardados)
		_lbl_resultado.modulate = Color(0.55, 0.9, 0.55)
	else:
		_lbl_resultado.text = "⚠ No se pudo guardar: %s" % ", ".join(fallos)
		_lbl_resultado.modulate = Color(0.95, 0.4, 0.4)


## Recarga cada sistema desde su `.tres`: deshace la calibración de esta partida.
func _restaurar_del_catalogo() -> void:
	for sistema: String in _sistemas_con_knobs():
		var nodo: Node = _sistema_de(Knob.new(sistema, "", "", "", 0.0, 1.0, 0.1))
		if nodo == null or not nodo.has_method("aplicar_config"):
			continue
		var ruta: String = String(CONFIGS[sistema]["ruta"])
		if ResourceLoader.exists(ruta):
			nodo.aplicar_config(load(ruta))
	_refrescar_valores()
	_lbl_resultado.text = "↩ Valores del catálogo restaurados."
	_lbl_resultado.modulate = COLOR_TENUE


## Los sistemas que este panel calibra (los que aparecen en algún grupo de knobs).
func _sistemas_con_knobs() -> Array[String]:
	var sistemas: Array[String] = []
	for grupo: Array in _grupos():
		for knob: Knob in grupo[1]:
			if not sistemas.has(knob.sistema) and CONFIGS.has(knob.sistema):
				sistemas.append(knob.sistema)
	return sistemas


## Vuelca al `.tres` de un sistema los valores que este panel expone de él. Parte del `.tres` EXISTENTE
## para no perder los knobs que el panel no toca.
func _guardar_config_de(sistema: String) -> bool:
	var nodo: Node = _sistema_de(Knob.new(sistema, "", "", "", 0.0, 1.0, 0.1))
	if nodo == null:
		return true   # ese sistema no está en la partida: nada que guardar, no es un fallo
	var ruta: String = String(CONFIGS[sistema]["ruta"])
	var config: Resource = load(ruta) if ResourceLoader.exists(ruta) else null
	if config == null:
		config = (load(String(CONFIGS[sistema]["script"])) as GDScript).new()
	for grupo: Array in _grupos():
		for knob: Knob in grupo[1]:
			if knob.sistema != sistema:
				continue
			config.set(knob.propiedad, nodo.get(knob.propiedad))
	return ResourceSaver.save(config, ruta) == OK


func _cabecera_grupo(texto: String) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = COLOR_SECCION
	return lbl


## Una fila: nombre + valor actual + barra deslizante con su RANGO A LA VISTA + qué significa.
func _fila_knob(knob: Knob) -> PanelContainer:
	var marco := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(1, 1, 1, 0.03)
	estilo.set_content_margin_all(6)
	marco.add_theme_stylebox_override("panel", estilo)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	marco.add_child(caja)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	caja.add_child(fila)

	var nombre := Label.new()
	nombre.text = knob.etiqueta
	nombre.add_theme_font_size_override("font_size", 12)
	nombre.custom_minimum_size = Vector2(250, 0)
	fila.add_child(nombre)

	var valor := Label.new()
	valor.add_theme_font_size_override("font_size", 12)
	valor.modulate = COLOR_TITULO
	valor.custom_minimum_size = Vector2(60, 0)
	fila.add_child(valor)
	_valor_de[knob.clave()] = valor

	var minimo := Label.new()
	minimo.text = _formato(knob.minimo, knob.decimales)
	minimo.add_theme_font_size_override("font_size", 9)
	minimo.modulate = COLOR_TENUE
	fila.add_child(minimo)

	var barra := HSlider.new()
	barra.min_value = knob.minimo
	barra.max_value = knob.maximo
	barra.step = knob.paso
	barra.custom_minimum_size = Vector2(220, 0)
	barra.focus_mode = Control.FOCUS_NONE   # gotcha: si no, Espacio "pulsa" el control enfocado
	barra.value_changed.connect(func(nuevo: float) -> void: _aplicar(knob, nuevo))
	fila.add_child(barra)
	barra.set_meta("clave", knob.clave())

	var maximo := Label.new()
	maximo.text = _formato(knob.maximo, knob.decimales)
	maximo.add_theme_font_size_override("font_size", 9)
	maximo.modulate = COLOR_TENUE
	fila.add_child(maximo)

	var ayuda := Label.new()
	ayuda.text = knob.ayuda
	ayuda.add_theme_font_size_override("font_size", 10)
	ayuda.modulate = COLOR_TENUE
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD
	ayuda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(ayuda)
	return marco


# ── Leer y aplicar ───────────────────────────────────────────────────────────────────────────
## El nodo dueño de un knob (o null si ese sistema no está en la partida).
func _sistema_de(knob: Knob) -> Node:
	match knob.sistema:
		"paciencia":
			return _paciencia
		"demanda":
			return _demanda
		"flujo":
			return _flujo
		"construccion":
			return _construccion
		"tiempo":
			return _tiempo
		"documentacion":
			return _documentacion
		_:
			return null


## Aplica el valor EN CALIENTE sobre el sistema vivo. No toca el `.tres`: es calibración de partida.
func _aplicar(knob: Knob, valor: float) -> void:
	var sistema: Node = _sistema_de(knob)
	if sistema == null:
		return
	sistema.set(knob.propiedad, valor)
	# Los knobs de horario se escriben a pelo y se saltarían los `fijar_*` de Documentación: hay que
	# pedirle que reemita para que el cambio llegue de verdad a Flujo y a Demanda (story doc-002).
	if sistema.has_method("refrescar_horario"):
		sistema.refrescar_horario()
	if _valor_de.has(knob.clave()):
		_valor_de[knob.clave()].text = _formato(valor, knob.decimales)


## Relee de los sistemas vivos y pone cada barra donde toca (al abrir el panel).
func _refrescar_valores() -> void:
	for grupo: Array in _grupos():
		for knob: Knob in grupo[1]:
			var sistema: Node = _sistema_de(knob)
			if sistema == null:
				continue
			var actual: float = float(sistema.get(knob.propiedad))
			if _valor_de.has(knob.clave()):
				_valor_de[knob.clave()].text = _formato(actual, knob.decimales)
			_poner_barra(knob.clave(), actual)


## Mueve la barra de un knob sin disparar su callback (evitar el ping-pong barra→aplicar→barra).
func _poner_barra(clave: String, valor: float) -> void:
	for fila: Node in _lista.get_children():
		if not (fila is PanelContainer):
			continue
		for hijo: Node in (fila.get_child(0) as Node).get_child(0).get_children():
			if hijo is HSlider and (hijo as HSlider).get_meta("clave", "") == clave:
				(hijo as HSlider).set_value_no_signal(valor)
				return


## Formatea con los decimales que pida el knob (GDScript no admite el ancho dinámico `%.*f`).
func _formato(valor: float, decimales: int) -> String:
	return String.num(valor, decimales)
