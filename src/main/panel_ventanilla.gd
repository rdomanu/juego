class_name PanelVentanilla extends CanvasLayer
## PanelVentanilla — la FICHA de una ventanilla, al pulsar sobre ella.
##
## Petición del usuario (2026-07-31): *"al pulsar en alguna ventanilla debería poder verse como un
## menú donde se ponga la eficacia del puesto, un resumen de la persona que lo atienda, qué denuncias
## coge… tipo tycoon cuando se pulsa sobre algo y se detalla"*.
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
## API pública — nunca muta el modelo.
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
## Andamio provisional, como el resto de paneles: la UI definitiva es UI/HUD #11.

const COLOR_TENUE := Color(1, 1, 1, 0.65)
const COLOR_BUENO := Color(0.55, 0.9, 0.55)
const COLOR_REGULAR := Color(1.0, 0.8, 0.35)
const COLOR_MALO := Color(0.95, 0.45, 0.45)
const COLOR_URGENTE := Color(1.0, 0.72, 0.35)

## Umbrales de la barra de cansancio, los MISMOS que usa el muñeco en el mundo: lo que ve el jugador
## en la ficha y lo que ve sobre la cabeza tienen que hablar el mismo idioma.
const CANSANCIO_ALTO: float = 66.0
const CANSANCIO_MEDIO: float = 33.0
## Hueco que se deja abajo para la barra del HUD (que vive pegada al borde inferior).
const HUECO_BARRA_HUD: float = 100.0

var _flujo: Node = null
var _personal: Node = null
var _construccion: Node = null
var _odac: Node = null
var _documentacion: Node = null

var _puesto_id: StringName = &""
var _panel: PanelContainer
## Solo etiquetas: se repinta cada frame (no hay nada que pulsar, así que no se rompe nada).
var _caja_viva: VBoxContainer
## Los controles: se construye una vez al abrir y al cambiar algo que los afecte.
var _caja_mandos: VBoxContainer
## Donde se cuelgan las dos, para poder reconstruirlas por separado.
var _caja: VBoxContainer
## A qué caja va lo que se está dibujando ahora mismo (la viva o la de mandos).
var _destino: VBoxContainer


func configurar(
	flujo: Node, personal: Node, construccion: Node, odac: Node, documentacion: Node
) -> void:
	_flujo = flujo
	_personal = personal
	_construccion = construccion
	_odac = odac
	_documentacion = documentacion


func _ready() -> void:
	_crear_ui()
	visible = false
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
	_construir_mandos()
	_refrescar_vivo()


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


func _crear_ui() -> void:
	_panel = PanelContainer.new()
	# Columna fija pegada al borde DERECHO, de arriba abajo, dejando libre la barra del HUD. Como
	# las fichas de los tycoon: no tapa el mundo.
	#
	# ⚠️ Los anclajes van A MANO y NO con `PRESET_TOP_RIGHT`. Ese preset ancla el panel a un PUNTO
	# (la esquina superior derecha), y entonces `offset_bottom` se mide desde ESE PUNTO: al ponerle
	# -100 el panel quedaba de altura NEGATIVA y no se veía nada. Fue exactamente el fallo que
	# reportó el usuario ("sigo sin ver la ventana de los puestos"). Anclando arriba Y abajo, los
	# offsets se miden contra los bordes de la pantalla, que es lo que aquí hace falta.
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -376.0
	_panel.offset_right = -16.0
	_panel.offset_top = 16.0
	_panel.offset_bottom = -HUECO_BARRA_HUD
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(scroll)
	_caja = VBoxContainer.new()
	_caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja.add_theme_constant_override("separation", 5)
	scroll.add_child(_caja)
	_caja_viva = VBoxContainer.new()
	_caja_viva.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja_viva.add_theme_constant_override("separation", 5)
	_caja.add_child(_caja_viva)
	_caja_mandos = VBoxContainer.new()
	_caja_mandos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja_mandos.add_theme_constant_override("separation", 5)
	_caja.add_child(_caja_mandos)


## Las ETIQUETAS que cambian solas. Se repinta entera cada frame: son Labels, no hay nada que
## pulsar, así que reconstruirlas no rompe ninguna interacción.
func _refrescar_vivo() -> void:
	for hijo: Node in _caja_viva.get_children():
		hijo.queue_free()
	if _puesto_id == &"" or _flujo == null:
		return
	var tipo: Resource = Datos.obtener_silencioso(
		&"TipoPuesto", _flujo.tipo_de_puesto_flujo(_puesto_id)
	)
	_destino = _caja_viva
	_titulo(tipo.nombre if tipo != null else String(_puesto_id))
	_linea(String(_puesto_id) + " · " + String(_flujo.estado_de_puesto(_puesto_id)).to_upper(),
		COLOR_TENUE, 11)
	_separador()
	_bloque_atendiendo(tipo)
	_separador()
	_bloque_agente()
	_separador()
	_bloque_eficacia(tipo)


## LOS CONTROLES. Se construye una vez al abrir la ficha y cuando cambia algo que los afecta (un
## modo de ODAC). Nunca por frame.
func _construir_mandos() -> void:
	for hijo: Node in _caja_mandos.get_children():
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
	var cerrar := Button.new()
	cerrar.text = "Cerrar (Esc)"
	cerrar.focus_mode = Control.FOCUS_NONE   # gotcha: con foco, el Espacio deja de pausar
	cerrar.pressed.connect(func() -> void: visible = false)
	_caja_mandos.add_child(cerrar)


# ── Qué se está gestionando AHORA ────────────────────────────────────────────────────────────
## Petición del usuario (2026-07-31): *"tampoco se ve qué trámite se gestiona"*. Y es el dato más
## vivo de la ficha: no "qué puede atender esta ventanilla" (eso está más abajo), sino **qué está
## haciendo ahora mismo y cuánto le queda**.
func _bloque_atendiendo(tipo: Resource) -> void:
	_linea("AHORA MISMO", COLOR_TENUE, 11)
	var persona: RefCounted = _flujo.persona_en_puesto(_puesto_id)
	if persona == null:
		_linea("Sin nadie en la ventanilla", COLOR_TENUE, 13)
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
	_linea(("★ " if urgente else "") + nombre, COLOR_URGENTE if urgente else Color.WHITE, 15)
	_linea("Turno nº %d" % persona.numero_turno, COLOR_TENUE, 11)
	# En camino aún no se tramita (enmienda del 2026-07-25): decir "quedan 12 min" de alguien que
	# todavía está cruzando la comisaría sería mentir.
	if persona.estado == &"llamada":
		_linea("Llamado · viene de camino", COLOR_REGULAR, 12)
	else:
		var quedan: float = _flujo.restante_de_puesto(_puesto_id)
		_linea("Quedan %.0f min de trámite" % quedan, COLOR_BUENO, 13)
	# Y el siguiente ya llamado, si lo hay (la llamada anticipada).
	var siguiente: RefCounted = _flujo.siguiente_de(_puesto_id)
	if siguiente != null:
		_linea("Siguiente ya llamado: turno nº %d" % siguiente.numero_turno, COLOR_TENUE, 11)


# ── Quién la lleva ───────────────────────────────────────────────────────────────────────────
func _bloque_agente() -> void:
	_linea("QUIÉN LA LLEVA", COLOR_TENUE, 11)
	if _personal == null or not _personal.puesto_dotado(_puesto_id):
		_linea("Sin agente asignado", COLOR_MALO, 13)
		return
	var agente: RefCounted = _personal.agente_de(_puesto_id)
	if agente == null:
		_linea("Sin agente asignado", COLOR_MALO, 13)
		return
	_linea(agente.nombre, Color.WHITE, 15)
	_linea("Rapidez %d · Trato %d · Motivación %d" % [
		agente.rapidez, agente.trato, agente.motivacion
	], COLOR_TENUE, 12)
	# El cansancio con su consecuencia AL LADO: "82" no dice nada, "82 (un 21 % más lento)" sí.
	var lento: float = (_personal.mult_cansancio_rendimiento(agente) - 1.0) * 100.0
	var color: Color = COLOR_BUENO
	if agente.cansancio >= CANSANCIO_ALTO:
		color = COLOR_MALO
	elif agente.cansancio >= CANSANCIO_MEDIO:
		color = COLOR_REGULAR
	_linea("Cansancio %d%%  (%+.0f %% más lento)" % [roundi(agente.cansancio), lento], color, 13)
	if _personal.va_de_camino_al_descanso(agente):
		_linea("Va al descanso", COLOR_REGULAR, 12)
	elif agente.estado == &"descansando":
		_linea("De café · quedan %d min" % roundi(
			_personal.minutos_de_descanso_restantes(agente)
		), COLOR_REGULAR, 12)


# ── Lo bien que rinde, DESCOMPUESTO ──────────────────────────────────────────────────────────
func _bloque_eficacia(tipo: Resource) -> void:
	_linea("EFICACIA", COLOR_TENUE, 11)
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
	_linea("%s: %.1f min" % [atencion.nombre if atencion.nombre != "" else String(referencia), efectiva],
		Color.WHITE, 14)
	_linea("De catálogo: %.0f min" % base, COLOR_TENUE, 11)
	# El desglose: de dónde sale la diferencia. Es lo que convierte un número en una decisión.
	if _personal != null and _personal.puesto_dotado(_puesto_id):
		var mod: float = _personal.modificador_produccion_de(_puesto_id)
		_linea("Por su agente: %+.0f %%" % ((mod - 1.0) * 100.0),
			COLOR_BUENO if mod < 1.0 else COLOR_MALO, 11)
	var equipo: float = _flujo.mult_equipamiento(_puesto_id)
	if not is_equal_approx(equipo, 1.0):
		_linea("Por el equipamiento: %+.0f %%" % ((equipo - 1.0) * 100.0), COLOR_BUENO, 11)
	elif _construccion != null:
		_linea("Sin equipamiento en su sala", COLOR_TENUE, 11)
	# Y el dato que de verdad usa el jugador para dimensionar: cuántos despacha por hora.
	if efectiva > 0.0:
		_linea("≈ %.1f atenciones/hora" % (60.0 / efectiva), Color.WHITE, 12)


# ── Qué atiende ──────────────────────────────────────────────────────────────────────────────
func _bloque_atiende(tipo: Resource) -> void:
	_linea("QUÉ ATIENDE", COLOR_TENUE, 11)
	if tipo == null:
		return
	# En ODAC lo interesante es el MODO (la palanca de gestión), no la lista de 13 tipos.
	if _odac != null and tipo.servicio == "ODAC":
		var modo: int = _odac.modo_de(_puesto_id)
		_linea(_odac.NOMBRES_MODO.get(modo, "?"),
			COLOR_URGENTE if modo == _odac.Modo.SOLO_PRIORITARIAS else Color.WHITE, 14)
		_linea(_odac.AYUDA_MODO.get(modo, ""), COLOR_TENUE, 11)
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 4)
		_destino.add_child(fila)
		for m: int in [
			_odac.Modo.POLIVALENTE, _odac.Modo.SOLO_PRIORITARIAS, _odac.Modo.SOLO_NORMALES
		]:
			var boton := Button.new()
			boton.text = _odac.NOMBRES_MODO[m]
			boton.add_theme_font_size_override("font_size", 10)
			boton.focus_mode = Control.FOCUS_NONE
			boton.disabled = m == modo
			var destino: int = m
			var id: StringName = _puesto_id
			boton.pressed.connect(func() -> void: _odac.fijar_modo(id, destino))
			fila.add_child(boton)
		# LAS DENUNCIAS UNA A UNA (petición del usuario 2026-07-31: *"en ODAC poder seleccionar las
		# denuncias que se cogen en ese puesto"*). Es el modo "a medida", que ya estaba en el modelo
		# y hasta ahora no tenía botones. Marcar una casilla lo pasa a ese modo automáticamente: el
		# jugador no tiene que elegir el modo primero y luego los tipos, que sería un paso de más.
		var marcadas: Array[StringName] = _odac.atenciones_de_modo(modo, _odac.subconjunto_de(_puesto_id))
		_destino.add_child(HSeparator.new())
		_linea("Denuncias que coge", COLOR_TENUE, 11)
		for d: StringName in _odac.denuncias():
			var casilla := CheckBox.new()
			var recurso: Resource = Datos.obtener_silencioso(&"DenunciaODAC", d)
			var urgente: bool = _odac.es_prioritaria(d)
			casilla.text = ("★ " if urgente else "") + (
				recurso.nombre if recurso != null and recurso.nombre != "" else String(d)
			)
			casilla.add_theme_font_size_override("font_size", 11)
			casilla.focus_mode = Control.FOCUS_NONE   # gotcha: con foco, el Espacio deja de pausar
			casilla.modulate = COLOR_URGENTE if urgente else Color.WHITE
			# Polivalente = las coge TODAS, aunque por dentro no haya override: se marca todo.
			casilla.button_pressed = modo == _odac.Modo.POLIVALENTE or marcadas.has(d)
			var tipo_d: StringName = d
			casilla.toggled.connect(func(activo: bool) -> void: _alternar_denuncia(tipo_d, activo))
			_destino.add_child(casilla)
		return
	# En Documentación, la lista de trámites que admite.
	var nombres: Array[String] = []
	for a: Variant in tipo.atenciones_admitidas:
		var t: Resource = Datos.obtener_silencioso(&"TramiteDoc", StringName(a))
		nombres.append(t.nombre if t != null and t.nombre != "" else String(a))
	_linea(", ".join(nombres) if not nombres.is_empty() else "—", Color.WHITE, 12)


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
func _bloque_horario() -> void:
	_linea("HORARIO DEL SERVICIO", COLOR_TENUE, 11)
	var cierre: int = _documentacion.hora_cierre_min
	var base: int = _documentacion.cierre_base_min
	var tope: int = _documentacion.tope_autorizado()
	_linea("Abre %s · cierra %s" % [
		_hora(_documentacion.apertura_base_min), _hora(_documentacion.hora_cierre_efectiva())
	], Color.WHITE, 13)
	var barra := HSlider.new()
	barra.min_value = base
	barra.max_value = tope
	barra.step = 15   # cuartos de hora: el horario de una oficina no se decide al minuto
	barra.value = cierre
	barra.custom_minimum_size = Vector2(0, 18)
	barra.focus_mode = Control.FOCUS_NONE
	barra.value_changed.connect(func(v: float) -> void: _documentacion.fijar_hora_cierre(int(v)))
	_destino.add_child(barra)
	# El COSTE de alargar, en euros al día. Es la mitad de la decisión: sin el número, la barra es
	# una barra; con él, es una compra.
	var coste: float = _documentacion.coste_peonada_estimado()
	if coste > 0.0:
		_linea("Peonada: %.0f €/día (%.1f h extra × %d agentes)" % [
			coste, _documentacion.horas_extra(), _documentacion.num_agentes_doc()
		], COLOR_REGULAR, 12)
	else:
		_linea("Sin horas extra: no se paga peonada", COLOR_TENUE, 11)
	# El precio de la hora extra: pagar mejor cansa menos (Bienestar #13).
	_linea("Precio de la hora extra: %.0f €" % _documentacion.peonada_eur_hora, Color.WHITE, 12)
	var precio := HSlider.new()
	precio.min_value = _documentacion.peonada_eur_hora_min
	precio.max_value = _documentacion.peonada_eur_hora_max
	precio.step = 1
	precio.value = _documentacion.peonada_eur_hora
	precio.custom_minimum_size = Vector2(0, 18)
	precio.focus_mode = Control.FOCUS_NONE
	precio.value_changed.connect(
		func(v: float) -> void: _documentacion.fijar_peonada_eur_hora(v)
	)
	_destino.add_child(precio)
	_linea("Pagar mejor cansa menos a quien se queda", COLOR_TENUE, 10)
	# Y lo propio de ESTA ventanilla.
	var se_queda := CheckBox.new()
	se_queda.text = "Esta ventanilla se queda por la tarde"
	se_queda.add_theme_font_size_override("font_size", 11)
	se_queda.focus_mode = Control.FOCUS_NONE
	se_queda.button_pressed = _documentacion.puesto_de_tarde(_puesto_id)
	var id: StringName = _puesto_id
	se_queda.toggled.connect(
		func(activo: bool) -> void: _documentacion.fijar_puesto_de_tarde(id, activo)
	)
	_destino.add_child(se_queda)


## Un minuto del día como "HH:MM".
func _hora(minuto: int) -> String:
	return "%02d:%02d" % [int(minuto / 60.0) % 24, minuto % 60]


# ── Ayudas de dibujo ─────────────────────────────────────────────────────────────────────────
func _titulo(texto: String) -> void:
	_linea(texto, Color.WHITE, 18)


func _linea(texto: String, color: Color, tam: int) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.modulate = color
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_destino.add_child(l)


func _separador() -> void:
	_destino.add_child(HSeparator.new())
