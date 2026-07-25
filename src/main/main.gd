extends Node2D
## Main — la escena principal del juego de producción (nació como esqueleto en tiempo-009; desde
## flujo-008 la comisaría VIVE: Core 5/5 cableado).
##
## Suelo de rejilla (`TileMapLayer`) + mundo Core instanciado (Economía, Demanda, Construcción,
## Personal, Flujo — en ese orden: tick y carga dependen de él) + capa cosmética de NPCs navegando
## + HUD provisional de barra inferior (reloj/velocidad/saldo/demanda/personal/colas). Este HUD NO
## es el de UX (design/ux/hud.md se diseñará aparte).
##
## Reglas (control-manifest, Presentation): el HUD LEE el reloj (fuente única) y ORDENA la velocidad por
## la API pública (`Tiempo.fijar_velocidad`/`reanudar`); NUNCA muta su estado. El dibujo corre en
## `_process` (tiempo real); la simulación vive en `_physics_process` del autoload Tiempo (ADR-0001).
##
## Story: production/epics/tiempo/story-009-esqueleto-visible.md · ADR-0001 / ADR-0004 (TileMapLayer)

## Lado de cada celda de la rejilla, en píxeles (misma escala 40 px que validó el prototipo).
const TAM_CELDA: int = 40
## Dimensiones del suelo visible, en celdas (24×13 ≈ ventana por defecto 1152×648 con margen).
const COLUMNAS: int = 24
const FILAS: int = 13
## Paleta placeholder (suelo de comisaría sobrio; la línea marca la rejilla).
const COLOR_FONDO := Color(0.13, 0.14, 0.16)
const COLOR_SUELO := Color(0.22, 0.24, 0.27)
const COLOR_LINEA := Color(0.30, 0.32, 0.36)
const COLOR_BOTON_ACTIVO := Color(1.0, 0.85, 0.35)

## Nombres visibles de los turnos, indexados por el enum `Tiempo.Turno` (0/1/2).
const NOMBRES_TURNO: Array[String] = ["Mañana", "Tarde", "Noche"]
## Etiquetas de los botones de velocidad, indexadas por el enum `Tiempo.Velocidad` (0..3).
const NOMBRES_VELOCIDAD: Array[String] = ["⏸ Pausa", "1×", "2×", "3×"]

## Economía (Story 007 del epic economia): el primer sistema Core instanciado en el mundo (§3.4).
const EconomiaScript := preload("res://src/core/economia/economia.gd")
## Demanda (Story 007 del epic demanda): el grifo de la comisaría — genera las llegadas.
const DemandaScript := preload("res://src/core/demanda/demanda.gd")
## Personal (story personal-007): la plantilla REAL del mundo — sustituye al hook PLANTILLA_INICIAL.
const PersonalScript := preload("res://src/core/personal/personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
## Construcción (story const-006): el layout REAL — los puestos ya no se registran a mano.
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
## Flujo (story flujo-008): el motor de colas — CIERRA el Core: la gente entra y el saldo sube.
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
## La capa cosmética de NPCs navegando (story flujo-008).
const NPCsFlujoScript := preload("res://src/main/npcs_flujo.gd")
## El andamio de interacción del modo construcción (story const-007).
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")
## El andamio del panel de personal (feedback flujo-008): contratar del mercado + asignar a puestos.
const PanelPersonalScript := preload("res://src/main/panel_personal.gd")
## Posición del suelo en pantalla (la comparten el TileMapLayer del suelo y las capas de Construcción).
## Y arriba: el HUD vive ABAJO (estilo tycoon — petición del usuario 2026-07-24), el mundo despejado.
const POS_SUELO := Vector2(96, 24)
## Colores del estado financiero (placeholder sobrio; SIEMPRE acompañados de texto — accesibilidad).
const COLOR_HOLGADO := Color(0.55, 0.9, 0.55)
const COLOR_JUSTO := Color(1.0, 0.8, 0.35)
const COLOR_ROJOS := Color(0.95, 0.4, 0.4)

## Colores del nivel de demanda (DG12; SIEMPRE acompañados de texto — respaldo daltónico).
const COLORES_NIVEL: Dictionary[StringName, Color] = {
	&"BAJA": Color(0.55, 0.9, 0.55), &"MEDIA": Color(1.0, 0.8, 0.35), &"ALTA": Color(0.95, 0.4, 0.4),
}

var _lbl_hora: Label
var _lbl_fecha: Label
var _lbl_turno: Label
var _botones: Array[Button] = []
var _economia: Node
var _lbl_saldo: Label
var _lbl_estado_fin: Label
var _demanda: Node
var _lbl_llegadas: Label
var _lbl_nivel: Label
var _personal: Node
var _lbl_plantilla: Label
var _lbl_incidencia: Label
var _construccion: Node
var _flujo: Node
var _npcs: Node2D
var _lbl_flujo: Label
var _lbl_atendiendo: Label
var _lbl_puerta_doc: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(COLOR_FONDO)
	_crear_suelo()
	_instanciar_mundo()
	_crear_hud()
	# Modo construcción (story const-007): andamio de ratón sobre la API de Construcción.
	var modo_construccion: Node2D = ModoConstruccionScript.new()
	modo_construccion.name = "ModoConstruccion"
	modo_construccion.configurar(_construccion, TAM_CELDA)
	add_child(modo_construccion)
	# Panel de personal (feedback flujo-008): andamio de gestión de plantilla + mercado (tecla P). Se
	# crea OCULTO; solo LEE y ORDENA por la API pública de los sistemas Core (ADR-0001).
	var panel_personal: CanvasLayer = PanelPersonalScript.new()
	panel_personal.name = "PanelPersonal"
	add_child(panel_personal)
	panel_personal.configurar(_personal, _economia, _construccion, _flujo)
	# El HUD reacciona a los avisos del bus (además del refresco continuo de _process): resaltado del
	# botón activo y refresco inmediato del turno/ciclo. La UI escucha; nunca muta (ADR-0001).
	EventBus.velocidad_cambiada.connect(_resaltar_boton)
	EventBus.cambio_de_turno.connect(func(_turno: int) -> void: _refrescar_etiquetas())
	EventBus.cambio_dia_noche.connect(func(_es_noche: bool) -> void: _refrescar_etiquetas())
	_resaltar_boton(Tiempo.velocidad_actual)
	_refrescar_etiquetas()
	_programar_captura_evidencia()


## El dibujo corre en tiempo real (_process, ADR-0001): refresca los textos leyendo el reloj.
func _process(_delta: float) -> void:
	_refrescar_etiquetas()


## Atajos de teclado: Espacio = pausa/reanuda; 1/2/3 = velocidades. La UI solo ORDENA por la API pública.
func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey and evento.pressed and not evento.echo):
		return
	match (evento as InputEventKey).keycode:
		KEY_SPACE:
			if Tiempo.velocidad_actual == Tiempo.Velocidad.PAUSA:
				Tiempo.reanudar()
			else:
				Tiempo.fijar_velocidad(Tiempo.Velocidad.PAUSA)
		KEY_1:
			Tiempo.fijar_velocidad(Tiempo.Velocidad.X1)
		KEY_2:
			Tiempo.fijar_velocidad(Tiempo.Velocidad.X2)
		KEY_3:
			Tiempo.fijar_velocidad(Tiempo.Velocidad.X3)


# ── El mundo (sistemas Core instanciados — arquitectura §3.4 paso 3) ─────────────────────────
## Instancia los sistemas Core del mundo. De momento: Economía (name "Economia" = su clave de save).
## Su _ready auto-resuelve los autoloads reales (bus/reloj), carga su config, se registra en el
## dispatcher (cobros nuevo_dia prio 20 / nuevo_mes prio 10) y entra al grupo Persist.
func _instanciar_mundo() -> void:
	_economia = EconomiaScript.new()
	_economia.name = "Economia"
	add_child(_economia)
	# La ventana de gracia de insolvencia corre en MINUTOS DE JUEGO → la empuja el tick del reloj.
	Tiempo.suscribir_tick(_economia.avanzar_gracia)
	# Demanda (story demanda-007): su _ready se suscribe al tick, carga config + escenario (Pozuelo) y
	# entra a Persist. ORDEN ADR-0001: cuando existan Flujo/Paciencia deben instanciarse DESPUÉS de
	# Demanda (el tick se empuja en orden de suscripción: Tiempo → Demanda → Flujo → Paciencia).
	_demanda = DemandaScript.new()
	_demanda.name = "Demanda"
	add_child(_demanda)
	# Construcción (story const-006): el layout REAL. ⚠️ ANTES que Personal en el árbol: el orden de
	# los hijos es el orden de carga del SaveManager, y las asignaciones de Personal referencian
	# puestos que Construcción debe registrar primero (invariante de personal-006/const-005).
	_construccion = ConstruccionScript.new()
	_construccion.name = "Construccion"
	_construccion.usar_economia(_economia)
	add_child(_construccion)
	_construccion.montar_visual(TAM_CELDA, POS_SUELO)
	# Personal (story personal-007): la plantilla REAL. Su _ready carga config, registra las ausencias
	# en el dispatcher (nuevo_dia prio 30) y entra a Persist (clave "Personal"). La nómina que cobra
	# Economía sale de los salarios F1 de estos agentes (fijar_salarios_dia, enmienda 006).
	_personal = PersonalScript.new()
	_personal.name = "Personal"
	_personal.usar_economia(_economia)
	add_child(_personal)
	_construccion.usar_personal(_personal)
	_montar_comisaria_inicial()
	_dotar_plantilla_inicial()
	# Mercado disponible desde el día 1 (decisión de andamio aprobada): el panel de personal necesita
	# candidatos que contratar de arranque; el refresco cada 3 jornadas ya lo hace la lógica de Personal.
	_personal.generar_mercado()
	# Flujo (story flujo-008): el motor de colas. DESPUÉS de Demanda en el árbol (el tick se
	# empuja en orden de suscripción — ADR-0001) y DESPUÉS de Personal (orden de carga del
	# SaveManager: Construcción → Personal → Flujo). Su name es su clave de save.
	_flujo = FlujoScript.new()
	_flujo.name = "Flujo"
	_flujo.usar_personal(_personal)
	_flujo.usar_construccion(_construccion)
	add_child(_flujo)
	_flujo.fijar_hook_horas_extra(_economia.registrar_horas_extra)   # peonada AC-FL24
	_construccion.fijar_puede_demoler(_flujo.puede_demoler_puesto)   # gate AC-CO13
	# La capa cosmética: NPCs + navegación bakeada del layout real.
	_npcs = NPCsFlujoScript.new()
	_npcs.name = "NPCs"
	_npcs.configurar(_flujo, _construccion, _personal, TAM_CELDA, POS_SUELO, COLUMNAS, FILAS)
	add_child(_npcs)
	_sincronizar_puestos_flujo()
	_construccion.fijar_hook_layout(_al_cambiar_layout)
	EventBus.persona_generada.connect(_al_llegar_persona)


## Una ficha de Demanda llega a la puerta: Flujo la admite (turno + aforo) y nace su NPC visible.
## Con la puerta de Doc cerrada (AC-FL24) `admitir` devuelve null y la ficha "en camino" se va.
func _al_llegar_persona(ficha: RefCounted) -> void:
	var persona: RefCounted = _flujo.admitir(ficha)
	if persona == null:
		return
	_flujo.encolar(persona)
	_npcs.spawn(persona)


## Cambio de layout (hook de Construcción — se dispara al construir/demoler/mover/cargar, nunca
## por frame): re-bake de la navegación + re-sincronización de los puestos del flujo.
func _al_cambiar_layout() -> void:
	if _npcs != null:
		_npcs.solicitar_rebake()
	_sincronizar_puestos_flujo()


## Los puestos del flujo = los CONSTRUIDOS (fuente única: Construcción). Registra los nuevos
## (idempotente) y retira los demolidos (una demolición con atención en curso ya la frena el gate
## AC-CO13, así que aquí la retirada es siempre limpia).
func _sincronizar_puestos_flujo() -> void:
	if _flujo == null:
		return
	var construidos: Dictionary = {}
	for servicio: String in ["Documentacion", "ODAC"]:
		for puesto_id: StringName in _construccion.puestos_de_servicio(servicio):
			construidos[puesto_id] = true
			_flujo.registrar_puesto_flujo(puesto_id, _construccion.catalogo_de(puesto_id))
	for puesto_id: StringName in _flujo.puestos_registrados():
		if not construidos.has(puesto_id):
			_flujo.quitar_puesto_flujo(puesto_id)


## El montaje inicial "DE OFICIO" (const-006, decisión ratificada): la DGP entrega la comisaría
## montada y pagada (coste 0) → saldo 3000 € y nómina 190 € INTACTOS. Construida por la API real de
## Construcción (los puestos llegan a Personal por el puente registrar_puesto, ya no a mano); ids
## compat doc_1/doc_2/odac_1 (los mismos de los saves y tests previos).
func _montar_comisaria_inicial() -> void:
	_construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(1, 1, 6, 4))
	_construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(1, 6, 6, 4))
	_construccion.construir_de_oficio_sala(&"sala_odac", Rect2i(9, 1, 4, 3))
	_construccion.construir_de_oficio_sala(&"sala_espera_odac", Rect2i(9, 5, 3, 3))
	_construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(2, 2), &"doc_1")
	_construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(4, 2), &"doc_2")
	# Ventanilla TIE inicial (feedback flujo-008, ratificada): (6,2) libre dentro de sala_documentacion.
	_construccion.construir_de_oficio_elemento(&"puesto_tie", Vector2i(6, 2), &"tie_1")
	_construccion.construir_de_oficio_elemento(&"puesto_odac", Vector2i(10, 2), &"odac_1")
	for x: int in range(2, 6):
		_construccion.construir_de_oficio_elemento(_construccion.ASIENTO_BASICO, Vector2i(x, 7))
		_construccion.construir_de_oficio_elemento(_construccion.ASIENTO_BASICO, Vector2i(x, 8))
	for x: int in range(9, 12):
		_construccion.construir_de_oficio_elemento(_construccion.ASIENTO_BASICO, Vector2i(x, 6))


## La plantilla inicial (personal-007, decisión ratificada): 3 agentes de atributos medios asignados
## a los puestos del layout real.
func _dotar_plantilla_inicial() -> void:
	var dotacion: Array = [
		[&"ag_doc", &"doc_1"], [&"ag_doc", &"doc_2"], [&"ag_doc", &"tie_1"], [&"ag_odac", &"odac_1"]
	]
	for i: int in dotacion.size():
		var nombre: String = _personal.pool_nombres[i % _personal.pool_nombres.size()]
		var agente: RefCounted = AgenteScript.new(nombre, dotacion[i][0])
		_personal.incorporar(agente)
		_personal.asignar(agente, dotacion[i][1])


# ── Suelo (TileMapLayer — NUNCA TileMap, deprecado) ──────────────────────────────────────────
## Crea el suelo: un TileSet mínimo generado por código (tile plano con borde de rejilla) y una
## rejilla COLUMNAS×FILAS pintada con set_cell. Solo estética; sin interacción de ratón (Construcción #7).
func _crear_suelo() -> void:
	var imagen := Image.create(TAM_CELDA, TAM_CELDA, false, Image.FORMAT_RGBA8)
	imagen.fill(COLOR_SUELO)
	for i in TAM_CELDA:
		imagen.set_pixel(i, 0, COLOR_LINEA)
		imagen.set_pixel(0, i, COLOR_LINEA)
	var fuente := TileSetAtlasSource.new()
	fuente.texture = ImageTexture.create_from_image(imagen)
	fuente.texture_region_size = Vector2i(TAM_CELDA, TAM_CELDA)
	fuente.create_tile(Vector2i.ZERO)
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TAM_CELDA, TAM_CELDA)
	var id_fuente: int = tileset.add_source(fuente)

	var suelo := TileMapLayer.new()
	suelo.name = "Suelo"
	suelo.tile_set = tileset
	# Centrado aproximado en la ventana por defecto (1152×648).
	suelo.position = POS_SUELO
	for x in COLUMNAS:
		for y in FILAS:
			suelo.set_cell(Vector2i(x, y), id_fuente, Vector2i.ZERO)
	add_child(suelo)


# ── HUD provisional (construido por código, como el prototipo validado) ──────────────────────
## Panel arriba-izquierda: hora grande, fecha "Mes · Semana N — Año A", turno, y 4 botones de velocidad.
## Barra inferior estilo tycoon (petición del usuario 2026-07-24): toda la info ABAJO en una fila de
## secciones (reloj · velocidad · finanzas · demanda · personal); el mundo queda despejado arriba.
func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	capa.name = "HUD"
	add_child(capa)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# Gotcha de anclas: anclada abajo, la barra debe CRECER HACIA ARRIBA (si no, se sale de pantalla).
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	capa.add_child(panel)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	panel.add_child(fila)

	# Sección reloj (fuente única: Tiempo).
	var caja_reloj := _seccion(fila)
	_lbl_hora = Label.new()
	_lbl_hora.add_theme_font_size_override("font_size", 24)
	caja_reloj.add_child(_lbl_hora)
	_lbl_fecha = Label.new()
	_lbl_fecha.add_theme_font_size_override("font_size", 11)
	caja_reloj.add_child(_lbl_fecha)
	_lbl_turno = Label.new()
	_lbl_turno.add_theme_font_size_override("font_size", 11)
	caja_reloj.add_child(_lbl_turno)

	# Sección velocidad (+ nota de atajos).
	var caja_velocidad := _seccion(fila)
	var fila_botones := HBoxContainer.new()
	fila_botones.add_theme_constant_override("separation", 6)
	caja_velocidad.add_child(fila_botones)
	for indice in NOMBRES_VELOCIDAD.size():
		var boton := Button.new()
		boton.text = NOMBRES_VELOCIDAD[indice]
		# Gotcha del prototipo: sin esto, Espacio "pulsa" el botón enfocado en vez de pausar.
		boton.focus_mode = Control.FOCUS_NONE
		boton.pressed.connect(func() -> void: Tiempo.fijar_velocidad(indice as Tiempo.Velocidad))
		fila_botones.add_child(boton)
		_botones.append(boton)
	var nota := Label.new()
	nota.text = "Espacio pausa · 1/2/3 velocidad · B construcción · P personal (HUD provisional)"
	nota.add_theme_font_size_override("font_size", 10)
	nota.modulate = Color(1, 1, 1, 0.55)
	caja_velocidad.add_child(nota)

	# Bloque financiero (Story 007 del epic economia): saldo + estado, SOLO lectura.
	var caja_saldo := _seccion(fila)
	_lbl_saldo = Label.new()
	_lbl_saldo.add_theme_font_size_override("font_size", 18)
	caja_saldo.add_child(_lbl_saldo)
	_lbl_estado_fin = Label.new()
	_lbl_estado_fin.add_theme_font_size_override("font_size", 11)
	caja_saldo.add_child(_lbl_estado_fin)

	# Bloque de demanda (story demanda-007): llegadas del día + nivel BAJA/MEDIA/ALTA, SOLO lectura.
	var caja_demanda := _seccion(fila)
	_lbl_llegadas = Label.new()
	_lbl_llegadas.add_theme_font_size_override("font_size", 13)
	caja_demanda.add_child(_lbl_llegadas)
	_lbl_nivel = Label.new()
	_lbl_nivel.add_theme_font_size_override("font_size", 11)
	caja_demanda.add_child(_lbl_nivel)

	# Bloque de personal (story personal-007): plantilla + nómina + incidencia, SOLO lectura.
	var caja_personal := _seccion(fila)
	_lbl_plantilla = Label.new()
	_lbl_plantilla.add_theme_font_size_override("font_size", 13)
	caja_personal.add_child(_lbl_plantilla)
	_lbl_incidencia = Label.new()
	_lbl_incidencia.add_theme_font_size_override("font_size", 11)
	caja_personal.add_child(_lbl_incidencia)

	# Bloque de flujo (story flujo-008): colas por servicio + atenciones en curso + FPS, pull.
	var caja_flujo := _seccion(fila)
	_lbl_flujo = Label.new()
	_lbl_flujo.add_theme_font_size_override("font_size", 13)
	caja_flujo.add_child(_lbl_flujo)
	_lbl_atendiendo = Label.new()
	_lbl_atendiendo.add_theme_font_size_override("font_size", 11)
	caja_flujo.add_child(_lbl_atendiendo)
	# Puerta de Documentación (feedback flujo-008): abierta/cerrada + hora, texto SIEMPRE + color.
	_lbl_puerta_doc = Label.new()
	_lbl_puerta_doc.add_theme_font_size_override("font_size", 11)
	caja_flujo.add_child(_lbl_puerta_doc)


## Una sección vertical de la barra inferior (con separador a partir de la segunda).
func _seccion(fila: HBoxContainer) -> VBoxContainer:
	if fila.get_child_count() > 0:
		fila.add_child(VSeparator.new())
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	fila.add_child(caja)
	return caja


## Refresca hora/fecha/turno LEYENDO el reloj (fuente única; jamás se escribe en él) y el saldo
## LEYENDO Economía (la UI lee y ordena, nunca muta — ADR-0001).
func _refrescar_etiquetas() -> void:
	_lbl_hora.text = Tiempo.hhmm(Tiempo.minutos_juego)
	_lbl_fecha.text = "Mes %d · Semana %d — Año %d" % [Tiempo.mes, Tiempo.semana, Tiempo.anio]
	_lbl_turno.text = "Turno: %s" % NOMBRES_TURNO[Tiempo.turno_de(Tiempo.minutos_juego)]
	if _economia == null or _lbl_saldo == null:
		return
	var saldo: float = _economia.saldo_eur
	_lbl_saldo.text = "%.2f €" % saldo
	if saldo < 0.0:
		_lbl_saldo.modulate = COLOR_ROJOS
		_lbl_estado_fin.text = "Estado: NÚMEROS ROJOS (gasto bloqueado)"
		_lbl_estado_fin.modulate = COLOR_ROJOS
	elif saldo < _economia.umbral_holgura_ui:
		_lbl_saldo.modulate = COLOR_JUSTO
		_lbl_estado_fin.text = "Estado: justo"
		_lbl_estado_fin.modulate = COLOR_JUSTO
	else:
		_lbl_saldo.modulate = COLOR_HOLGADO
		_lbl_estado_fin.text = "Estado: holgado"
		_lbl_estado_fin.modulate = COLOR_HOLGADO
	if _demanda == null or _lbl_llegadas == null:
		return
	_lbl_llegadas.text = "Llegadas hoy: %d" % _demanda.llegadas_hoy
	var nivel: StringName = _demanda.nivel_demanda()
	_lbl_nivel.text = "Demanda Doc: %s" % nivel
	_lbl_nivel.modulate = COLORES_NIVEL.get(nivel, Color.WHITE)
	if _personal == null or _lbl_plantilla == null:
		return
	# Personal (story personal-007): pull de los getters — plantilla, nómina F1 y ausencias del día.
	var nomina: float = 0.0
	var ausencias: Array[String] = []
	for agente: RefCounted in _personal.plantilla:
		nomina += _personal.salario_dia(agente)
		if agente.estado == AgenteScript.ESTADO_AUSENTE:
			var donde: String = String(agente.puesto_id) if agente.puesto_id != &"" else "banquillo"
			ausencias.append("%s (%s)" % [agente.nombre, donde])
	_lbl_plantilla.text = "Plantilla: %d · Nómina: %.0f €/día" % [_personal.plantilla.size(), nomina]
	if ausencias.is_empty():
		_lbl_incidencia.text = "Plantilla al completo"
		_lbl_incidencia.modulate = COLOR_HOLGADO
	else:
		var verbo: String = "falta" if ausencias.size() == 1 else "faltan"
		_lbl_incidencia.text = "Hoy %s: %s" % [verbo, ", ".join(ausencias)]
		_lbl_incidencia.modulate = COLOR_JUSTO
	if _flujo == null or _lbl_flujo == null:
		return
	# Flujo (story flujo-008): colas y atenciones por pull de getters; FPS para el guardrail 60.
	_lbl_flujo.text = "En cola: %d Doc · %d ODAC" % [
		_flujo.personas_en_cola(&"Documentacion"), _flujo.personas_en_cola(&"ODAC"),
	]
	_lbl_atendiendo.text = "Atendiendo: %d · FPS %d" % [
		_flujo.atendiendo_total(), Engine.get_frames_per_second(),
	]
	# Puerta de Documentación (AC-FL24): abierta hasta cierre_doc_min; cerrada el resto del día.
	var hora_cierre: String = Tiempo.hhmm(float(_flujo.cierre_doc_min))
	if _flujo.puerta_doc_abierta():
		_lbl_puerta_doc.text = "Doc: ABIERTA (cierra %s)" % hora_cierre
		_lbl_puerta_doc.modulate = COLOR_HOLGADO
	else:
		_lbl_puerta_doc.text = "Doc: CERRADA (admisión hasta %s)" % hora_cierre
		_lbl_puerta_doc.modulate = Color(0.6, 0.6, 0.6)


## Resalta el botón de la velocidad activa (dorado) y apaga el resto. Oyente de `velocidad_cambiada`.
func _resaltar_boton(indice: int) -> void:
	for i in _botones.size():
		_botones[i].modulate = COLOR_BOTON_ACTIVO if i == indice else Color.WHITE


# ── Evidencia ADVISORY de la story (solo en desarrollo, nunca en build exportada) ────────────
## A los 2 s de correr, guarda una captura del viewport en production/qa/evidence/ (la evidencia
## Visual/UI de la Story 009). Solo corre en entorno de desarrollo (feature "editor"); se retirará
## cuando el HUD real de UX sustituya a este andamio.
func _programar_captura_evidencia() -> void:
	if not OS.has_feature("editor"):
		return
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute("res://production/qa/evidence")
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://production/qa/evidence/flujo-demo-2026-07-24.png")
	)
