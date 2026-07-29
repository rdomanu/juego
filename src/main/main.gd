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
const PacienciaScript := preload("res://src/feature/paciencia/paciencia.gd")
## Documentación (story doc-002): el DUEÑO del horario del servicio — Flujo lo ejecuta y Demanda lo
## respeta, pero quien lo decide es este sistema (antes vivía prestado dentro de Flujo).
const DocumentacionScript := preload("res://src/feature/documentacion/documentacion.gd")
## El andamio de interacción del modo construcción (story const-007).
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")
## El andamio del panel de personal (feedback flujo-008): contratar del mercado + asignar a puestos.
const PanelPersonalScript := preload("res://src/main/panel_personal.gd")
## El panel del horario de Documentación (story doc-005): el slider que decide cuánto abres.
const PanelHorarioScript := preload("res://src/main/panel_horario.gd")
## El modal del Comisario (2026-07-28): sin él, quedarse sin dinero BLOQUEABA la partida.
const ModalComisarioScript := preload("res://src/main/modal_comisario.gd")
## El ciclo de luz día/noche (2026-07-28): la hora del día se VE (art bible §2).
const CicloLuzScript := preload("res://src/main/ciclo_luz.gd")
## Las luces de los objetos comprados, que se encienden de noche (petición del usuario 2026-07-28).
const LucesObjetosScript := preload("res://src/main/luces_objetos.gd")
## El cuadro de mandos de calibración (petición del usuario 2026-07-26). Herramienta DEV.
const PanelAdminScript := preload("res://src/main/panel_admin.gd")
## Posición del suelo en pantalla (la comparten el TileMapLayer del suelo y las capas de Construcción).
## Y arriba: el HUD vive ABAJO (estilo tycoon — petición del usuario 2026-07-24), el mundo despejado.
const POS_SUELO := Vector2(96, 24)
## Colores del estado financiero (placeholder sobrio; SIEMPRE acompañados de texto — accesibilidad).
const COLOR_HOLGADO := Color(0.55, 0.9, 0.55)
const COLOR_JUSTO := Color(1.0, 0.8, 0.35)
const COLOR_ROJOS := Color(0.95, 0.4, 0.4)
## Gris tenue del HUD (texto secundario).
const COLOR_TENUE_HUD := Color(1, 1, 1, 0.65)
## Ids de las opciones del menú del clic derecho.
const ID_MENU_TITULO := 0
const ID_MENU_COLAR := 1
const ID_MENU_CANCELAR := 2
## Menú contextual de la SALA (petición del usuario 2026-07-28): gestionar la sala donde se hace clic
## sin buscar nada en la barra de construcción. Rango 100+ para no chocar con el del ciudadano.
const ID_SALA_TITULO := 100
const ID_SALA_AMPLIAR := 101
const ID_SALA_ASIENTOS := 102
const ID_SALA_DEMOLER := 103
## (104 libre: era el hueco reservado de Comodidades, ya sustituido por el submenu real.)
const ID_SALA_CANCELAR := 105
## Los puestos que admite la sala ocupan 110, 111, 112… (uno por tipo del catálogo).
const ID_SALA_PUESTO_BASE := 110
## Las comodidades que admite la sala ocupan 130, 131, 132… (Comodidades #15, story com-003).
const ID_SALA_COMODIDAD_BASE := 130

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
var _paciencia: Node
var _documentacion: Node
var _panel_horario: CanvasLayer
var _npcs: Node2D
var _lbl_flujo: Label
var _lbl_atendiendo: Label
var _lbl_puerta_doc: Label
var _lbl_sin_servicio: Label
var _panel_personal: CanvasLayer
var _panel_admin: CanvasLayer
## Menú del clic derecho sobre un ciudadano (petición del usuario 2026-07-26) + a quién apunta.
var _menu_ciudadano: PopupMenu
## Menú contextual de la sala (2026-07-28) + la sala sobre la que se abrió.
var _menu_sala: PopupMenu
var _sala_del_menu: StringName = &""
## Los puestos ofrecidos en el menú, en el orden en que se pintaron (índice → id del catálogo).
var _puestos_del_menu: Array[StringName] = []
## Las comodidades ofrecidas, en el orden en que se pintaron (índice → id del catálogo).
var _comodidades_del_menu: Array[StringName] = []
## El modo construcción, para poder darle la herramienta ya en la mano desde el menú.
var _modo_construccion: Node2D
var _persona_del_menu: RefCounted = null
var _lbl_guardado: Label
var _lbl_satisfaccion: Label
var _lbl_reclamaciones: Label
## Etiquetas de sala (petición del usuario 2026-07-29: "no se sabe como de bonificado está la sala
## de descanso o las otras salas"): confort/equipamiento/descanso instalado, SIN abrir ningún menú.
## Capa aparte (z_index 1, por ENCIMA del suelo de las salas — mismo criterio que los NPCs) + un
## Label persistente por sala construida, indexado por su id (patrón de `npcs_flujo._visual_de_puesto`).
var _capa_etiquetas_sala: Node2D
var _etiqueta_de_sala: Dictionary[StringName, Label] = {}


func _ready() -> void:
	RenderingServer.set_default_clear_color(COLOR_FONDO)
	_crear_suelo()
	_instanciar_mundo()
	_crear_hud()
	_crear_capa_etiquetas_sala()
	# Modo construcción (story const-007): andamio de ratón sobre la API de Construcción.
	_modo_construccion = ModoConstruccionScript.new()
	_modo_construccion.name = "ModoConstruccion"
	_modo_construccion.configurar(_construccion, TAM_CELDA)
	add_child(_modo_construccion)
	# Panel de personal (feedback flujo-008): andamio de gestión de plantilla + mercado (tecla P). Se
	# crea OCULTO; solo LEE y ORDENA por la API pública de los sistemas Core (ADR-0001).
	_panel_personal = PanelPersonalScript.new()
	_panel_personal.name = "PanelPersonal"
	add_child(_panel_personal)
	_panel_personal.configurar(_personal, _economia, _construccion, _flujo)
	# Panel del horario (story doc-005): la decisión económica del jugador — cuánto abre y qué le
	# cuesta. Solo LEE y ORDENA por la API de Documentación (ADR-0001); escucha los comunicados de la
	# División por el bus. Se puede operar en Pausa (DO11).
	_panel_horario = PanelHorarioScript.new()
	_panel_horario.name = "PanelHorario"
	add_child(_panel_horario)
	_panel_horario.configurar(_documentacion, Tiempo, EventBus, _personal)
	# Panel de calibración: HERRAMIENTA DEL DESARROLLADOR, no una pantalla del juego (aclaración del
	# usuario 2026-07-26). Solo existe en desarrollo — en un build exportado NI SE INSTANCIA, así que
	# ningún jugador puede abrirlo ni tocar los números del balance. Mismo patrón que la captura de
	# evidencia. `OS.has_feature("editor")` es false en el juego exportado.
	if OS.has_feature("editor"):
		_panel_admin = PanelAdminScript.new()
		_panel_admin.name = "PanelAdmin"
		add_child(_panel_admin)
		_panel_admin.configurar(
			_paciencia, _demanda, _flujo, _construccion, Tiempo, _economia, _personal,
			_documentacion
		)
	# El HUD reacciona a los avisos del bus (además del refresco continuo de _process): resaltado del
	# botón activo y refresco inmediato del turno/ciclo. La UI escucha; nunca muta (ADR-0001).
	EventBus.velocidad_cambiada.connect(_resaltar_boton)
	EventBus.cambio_de_turno.connect(func(_turno: int) -> void: _refrescar_etiquetas())
	EventBus.cambio_dia_noche.connect(func(_es_noche: bool) -> void: _refrescar_etiquetas())
	# El modal del Comisario: Economía PAUSA el juego al tocar el suelo de deuda y espera una
	# decisión. Sin alguien escuchando esa señal, esa pausa era un bloqueo del que no se salía.
	var modal: CanvasLayer = ModalComisarioScript.new()
	modal.name = "ModalComisario"
	add_child(modal)
	modal.configurar(_economia, EventBus)
	# Partida nueva: el reloj se sitúa a la hora de arranque del catálogo (07:30). Cargar un guardado
	# (F9) sobreescribe esto con la hora guardada, que es lo correcto.
	Tiempo.iniciar_partida_nueva()
	_crear_menu_ciudadano()
	_crear_menu_sala()
	# La luz del día (art bible §2): mañana cálida, mediodía neutro, tarde dorada, noche azul y
	# fría. Tinta el mundo 2D, NO el HUD (vive en su propio CanvasLayer y debe seguir legible).
	var ciclo_luz: CanvasModulate = CicloLuzScript.new()
	ciclo_luz.name = "CicloLuz"
	add_child(ciclo_luz)
	ciclo_luz.configurar(Tiempo)
	# Los focos puntuales de la noche (art bible §2): la tele, el vending, la fuente y los equipos
	# informáticos se encienden al anochecer, con la misma curva horaria que la luz ambiente.
	var luces: Node2D = LucesObjetosScript.new()
	luces.name = "LucesObjetos"
	add_child(luces)
	luces.configurar(_construccion, Tiempo)
	_resaltar_boton(Tiempo.velocidad_actual)
	_refrescar_etiquetas()
	# Población inicial de las etiquetas de sala: el hook de layout (`_al_cambiar_layout`) se cablea
	# DENTRO de `_instanciar_mundo` DESPUÉS de montar la comisaría inicial, así que esa primera
	# construcción nunca lo dispara (ver comentario de `_actualizar_etiquetas_salas`). Sin esta
	# llamada, la sala de Documentación/ODAC de arranque se quedaría sin etiqueta hasta la primera
	# compra o demolición.
	_actualizar_etiquetas_salas()
	_programar_captura_evidencia()


## El dibujo corre en tiempo real (_process, ADR-0001): refresca los textos leyendo el reloj.
func _process(_delta: float) -> void:
	_refrescar_etiquetas()


## Atajos de teclado: Espacio = pausa/reanuda; 1/2/3 = velocidades. La UI solo ORDENA por la API pública.
func _unhandled_input(evento: InputEvent) -> void:
	# CLIC DERECHO sobre un ciudadano que espera = COLARLO (mecánica pedida por el usuario
	# 2026-07-26). Llega aquí solo si nadie lo consumió antes (el modo construcción tiene prioridad).
	if evento is InputEventMouseButton:
		var raton := evento as InputEventMouseButton
		if raton.pressed and raton.button_index == MOUSE_BUTTON_RIGHT:
			# La posición se toma DEL EVENTO y se pasa a coordenadas del mundo con la transformada
			# del canvas. Con `get_global_mouse_position()` se leía el ratón del sistema, no el punto
			# donde se hizo clic: funcionaba llamándolo a mano pero no con el clic de verdad.
			_abrir_menu_ciudadano(
				get_canvas_transform().affine_inverse() * raton.position, raton.position
			)
			get_viewport().set_input_as_handled()
		return
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
		KEY_F5:
			_guardar_partida()
		KEY_F9:
			_cargar_partida()


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
	# Documentación (story doc-002): el DUEÑO del horario del servicio. No ejecuta nada — decide, y
	# Flujo/Demanda obedecen. Se instancia aquí (su _ready solo carga su `.tres`) y el horario se
	# empuja MÁS ABAJO, cuando Flujo ya existe: `_al_cambiar_horario_doc` es el único punto por el que
	# ese dato viaja (fuente única — nada de knobs duplicados en dos configs).
	_documentacion = DocumentacionScript.new()
	_documentacion.name = "Documentacion"
	add_child(_documentacion)
	_documentacion.horario_cambiado.connect(_al_cambiar_horario_doc)
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
	_personal.usar_construccion(_construccion)   # ¿hay sala de descanso? (Bienestar #13)
	_personal.usar_tiempo(Tiempo)                # los cafés corren con el reloj de juego
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
	_construccion.fijar_puede_demoler(_flujo.puede_demoler_puesto)   # gate AC-CO13
	# Documentación cobra la peonada (F1) y desmotiva a quien sale tarde (DO5): necesita Economía
	# (le REGISTRA las horas, no toca el saldo), Personal (cuántos agentes la cubren) y Demanda (el
	# nivel BAJA/MEDIA/ALTA, la brújula de la decisión). Story doc-003.
	_documentacion.usar_economia(_economia)
	_documentacion.usar_personal(_personal)
	_documentacion.usar_demanda(_demanda)
	# El precio de la hora extra (story bien-002): Economía lo cobra y Personal lo usa para cansar
	# menos. Mismo patrón que el horario: el dato viaja por UN solo sitio.
	_documentacion.peonada_cambiada.connect(_al_cambiar_peonada)
	_al_cambiar_peonada(_documentacion.peonada_eur_hora, _documentacion.generosidad_peonada())
	# El horario de Doc, de su dueño a quienes lo ejecutan (story doc-002). Se empuja UNA vez aquí
	# con el estado de arranque; a partir de ahí lo hace la señal `horario_cambiado`.
	_al_cambiar_horario_doc(
		_documentacion.apertura_base_min,
		_documentacion.hora_cierre_min,
		_documentacion.hora_ultima_admision(),
	)
	# Paciencia (story paciencia-002): la espera pasa a tener consecuencias — la gente se cansa y se
	# marcha. ⚠️ ORDEN ADR-0001: DESPUÉS de Flujo en el árbol, para que su suscripción al tick sea
	# posterior (Tiempo → Demanda → Flujo → Paciencia). Así, en el mismo tick, Flujo ya ha llamado a
	# quien tocaba antes de que Paciencia mire quién se harta (el empate lo gana la llamada).
	_paciencia = PacienciaScript.new()
	_paciencia.name = "Paciencia"
	_paciencia.usar_flujo(_flujo)
	_paciencia.usar_construccion(_construccion)
	_paciencia.usar_personal(_personal)     # el 🤝Trato del agente puntúa la visita (F2)
	_paciencia.usar_economia(_economia)     # y la satisfacción de hoy fija el retorno DGP de mañana
	add_child(_paciencia)
	# La capa cosmética: NPCs + navegación bakeada del layout real.
	_npcs = NPCsFlujoScript.new()
	_npcs.name = "NPCs"
	_npcs.configurar(_flujo, _construccion, _personal, TAM_CELDA, POS_SUELO, COLUMNAS, FILAS)
	_npcs.usar_paciencia(_paciencia)   # el aro de ánimo sobre cada ciudadano (story paciencia-008)
	add_child(_npcs)
	_sincronizar_puestos_flujo()
	_construccion.fijar_hook_layout(_al_cambiar_layout)
	EventBus.persona_generada.connect(_al_llegar_persona)


## Crea el menú del clic derecho. Una sola instancia que se repuebla al abrirse: los ciudadanos van
## y vienen, el menú se queda.
func _crear_menu_ciudadano() -> void:
	_menu_ciudadano = PopupMenu.new()
	_menu_ciudadano.name = "MenuCiudadano"
	_menu_ciudadano.id_pressed.connect(_al_elegir_del_menu)
	add_child(_menu_ciudadano)


## Abre el menú sobre el ciudadano que haya en `punto_mundo` (o no lo abre, si no hay nadie).
## `punto_pantalla` es dónde se pinta el menú: donde el jugador acaba de hacer clic.
func _abrir_menu_ciudadano(punto_mundo: Vector2, punto_pantalla: Vector2) -> void:
	var npc: Node = _npcs.ciudadano_en(punto_mundo)
	if npc == null:
		# Nadie bajo el cursor: si el clic cae dentro de una sala, se ofrece gestionarla
		# (petición del usuario 2026-07-28). Si tampoco hay sala, se explica qué hacer.
		_persona_del_menu = null
		if not _abrir_menu_sala(punto_mundo, punto_pantalla):
			_avisar_accion(
				"Clic derecho sobre una sala o sobre alguien que espera para ver sus opciones",
				COLOR_TENUE_HUD
			)
		return
	_persona_del_menu = npc.persona
	_menu_ciudadano.clear()
	# Cabecera informativa (deshabilitada: es contexto, no una acción) — quién es y cómo lleva la
	# espera, que es justo lo que el jugador necesita para decidir si le hace el favor.
	_menu_ciudadano.add_item(_titulo_de_persona(_persona_del_menu), ID_MENU_TITULO)
	_menu_ciudadano.set_item_disabled(0, true)
	_menu_ciudadano.add_separator()
	if _persona_del_menu.colado:
		_menu_ciudadano.add_item("Ya está colado", ID_MENU_COLAR)
		_menu_ciudadano.set_item_disabled(2, true)
	else:
		_menu_ciudadano.add_item(
			"⬆ Colar (el resto de la cola se molesta)", ID_MENU_COLAR
		)
	_menu_ciudadano.add_separator()
	_menu_ciudadano.add_item("Cancelar", ID_MENU_CANCELAR)
	_menu_ciudadano.reset_size()
	_menu_ciudadano.popup(Rect2i(get_window().position + Vector2i(punto_pantalla), Vector2i.ZERO))


## Línea de contexto del menú: turno, trámite y cuánta paciencia le queda.
func _titulo_de_persona(persona: RefCounted) -> String:
	var restante: float = _paciencia.paciencia_de(persona)
	var estado: String = "en la calle" if persona.estado == &"esperando_fuera" else "esperando"
	if restante < 0.0:
		return "Turno %d · %s · %s" % [persona.numero_turno, persona.tramite_id(), estado]
	return "Turno %d · %s · %s · paciencia %d%%" % [
		persona.numero_turno, persona.tramite_id(), estado, roundi(restante),
	]


func _al_elegir_del_menu(id: int) -> void:
	if id != ID_MENU_COLAR or _persona_del_menu == null:
		return
	_colar_a(_persona_del_menu)


# ── Menú contextual de la SALA (petición del usuario 2026-07-28) ─────────────────────────────

## Todo lo que se puede hacer con una sala, en el sitio donde está la sala: ampliarla, ponerle
## asientos, montarle una ventanilla o tirarla. Antes había que abrir la barra de construcción (B) y
## buscar la herramienta correcta; **ampliar** era especialmente poco evidente (había que saber que
## dibujar pegado con el mismo tipo de sala la ampliaba en vez de crear otra).
func _crear_menu_sala() -> void:
	_menu_sala = PopupMenu.new()
	_menu_sala.name = "MenuSala"
	_menu_sala.id_pressed.connect(_al_elegir_del_menu_sala)
	add_child(_menu_sala)


## Abre el menú de la sala que haya en `punto_mundo`. Devuelve `false` si ahí no hay ninguna (para
## que quien llama pueda dar otra pista al jugador).
func _abrir_menu_sala(punto_mundo: Vector2, punto_pantalla: Vector2) -> bool:
	# La celda sale del punto DEL EVENTO, nunca del puntero del sistema (regla del manifiesto).
	var sala_id: StringName = _construccion.sala_en(_construccion.celda_de_punto(punto_mundo))
	if sala_id == &"":
		_sala_del_menu = &""
		return false
	_sala_del_menu = sala_id
	var tipo_id: StringName = _construccion.tipo_de_sala(sala_id)
	var tipo: Resource = Datos.obtener(&"TipoSala", tipo_id)
	_menu_sala.clear()
	_puestos_del_menu.clear()
	_comodidades_del_menu.clear()

	# Cabecera: qué sala es y cómo está de ocupada (contexto para decidir si ampliar).
	_menu_sala.add_item(_titulo_de_sala(sala_id, tipo), ID_SALA_TITULO)
	_menu_sala.set_item_disabled(0, true)
	_menu_sala.add_separator()

	_menu_sala.add_item("📐 Ampliar esta sala (dibuja pegado a ella)", ID_SALA_AMPLIAR)
	if tipo != null and tipo.tipo == "espera":
		_menu_sala.add_item("🪑 Añadir asientos", ID_SALA_ASIENTOS)
	# Una ventanilla por cada tipo que ESTA sala admite (del catálogo, nunca hardcodeado).
	if tipo != null:
		for puesto_id: StringName in tipo.puestos_admitidos:
			var puesto: Resource = Datos.obtener(&"TipoPuesto", puesto_id)
			if puesto == null:
				continue
			_menu_sala.add_item(
				"🏛 Añadir %s (%d €)" % [puesto.nombre, puesto.coste_construccion_eur],
				ID_SALA_PUESTO_BASE + _puestos_del_menu.size()
			)
			_puestos_del_menu.append(puesto_id)
	_menu_sala.add_separator()
	# Comodidades #15 (story com-003): los objetos que puede comprar ESTA sala. La familia depende
	# del tipo de sala — en la de espera se compra confort; en la oficina, material de trabajo.
	_anadir_comodidades_al_menu(tipo)
	_menu_sala.add_item("❌ Demoler esta sala", ID_SALA_DEMOLER)
	_menu_sala.add_separator()
	_menu_sala.add_item("Cancelar", ID_SALA_CANCELAR)
	_menu_sala.reset_size()
	_menu_sala.popup(Rect2i(get_window().position + Vector2i(punto_pantalla), Vector2i.ZERO))
	return true


## "Sala de espera de Documentación · 6×4 · 14 de aforo" — lo que hace falta para decidir.
func _titulo_de_sala(sala_id: StringName, tipo: Resource) -> String:
	var rect: Rect2i = _construccion.rect_de_sala(sala_id)
	var nombre: String = tipo.nombre if tipo != null else String(sala_id)
	if tipo != null and tipo.tipo == "espera":
		return "%s · %d×%d · aforo %d · confort %d" % [
			nombre, rect.size.x, rect.size.y,
			_construccion.aforo_de_sala(sala_id),
			roundi(_construccion.confort_de_sala(sala_id)),
		]
	# Bienestar #13: en la sala de descanso lo que importa es cuánto ACORTA el café y cuánta gente
	# cabe a la vez — los dos números que el jugador está comprando cuando pone un sofá.
	if tipo != null and tipo.tipo == "descanso":
		return "%s · %d×%d · %d plazas · el café dura un %d %% de lo normal" % [
			nombre, rect.size.x, rect.size.y,
			_personal.plazas_de_descanso(),
			roundi(_personal.mult_pausa_por_sala() * 100.0),
		]
	return "%s · %d×%d · equipamiento %d" % [
		nombre, rect.size.x, rect.size.y, roundi(_construccion.equipamiento_de_sala(sala_id)),
	]


## Pinta las comodidades que ESTA sala admite, con su precio, lo que aporta y lo que cuesta tenerla
## encendida. El catálogo manda: si mañana se añade un objeto nuevo, aparece aquí solo.
func _anadir_comodidades_al_menu(tipo_sala: Resource) -> void:
	if tipo_sala == null:
		return
	# Bienestar #13 (bien-005): la sala de descanso tiene su propia familia de objetos — sillas, sofá,
	# nevera, máquina de café. No son confort del ciudadano ni material de oficina: son lo que hace
	# que el café CUNDA y el funcionario vuelva antes a su ventanilla.
	var familia: String = "funcionario"
	var icono: String = "🖥"
	var concepto: String = "rendimiento"
	match tipo_sala.tipo:
		"espera":
			familia = "ciudadano"
			icono = "🛋"
			concepto = "confort"
		"descanso":
			familia = "descanso"
			icono = "☕"
			concepto = "descanso"
	var catalogo: Array = Datos.obtener_todos(&"Comodidad")
	catalogo.sort_custom(func(a: Resource, b: Resource) -> bool:
		return a.coste_construccion_eur < b.coste_construccion_eur   # de lo barato a lo caro
	)
	for comodidad: Resource in catalogo:
		if comodidad.familia != familia:
			continue
		var etiqueta: String = "%s %s (%d €" % [
			icono, comodidad.nombre, comodidad.coste_construccion_eur,
		]
		if comodidad.coste_mantenimiento_dia_eur > 0:
			etiqueta += " + %d €/día" % comodidad.coste_mantenimiento_dia_eur
		etiqueta += ") · %s +%d" % [concepto, roundi(comodidad.aporte)]
		# Las plazas son la otra mitad de la decisión: un sofá no solo mejora el café, es sitio donde
		# sentarse. Sin plazas suficientes, el tercero que quiere café se queda en la ventanilla.
		if comodidad.plazas > 0:
			etiqueta += " · %d plazas" % comodidad.plazas
		_menu_sala.add_item(etiqueta, ID_SALA_COMODIDAD_BASE + _comodidades_del_menu.size())
		_comodidades_del_menu.append(comodidad.id)


## Ejecuta lo elegido. Ninguna acción muta el modelo aquí: se **ordena** por la API pública de
## Construcción, o se entra en modo construcción con el pincel puesto (ADR-0001).
func _al_elegir_del_menu_sala(id: int) -> void:
	if _sala_del_menu == &"":
		return
	if id >= ID_SALA_COMODIDAD_BASE:
		var i: int = id - ID_SALA_COMODIDAD_BASE
		if i < _comodidades_del_menu.size():
			_modo_construccion.activar_con_herramienta(_comodidades_del_menu[i], false)
			_avisar_accion("Elige el hueco donde va, dentro de la sala", COLOR_TENUE_HUD)
		return
	if id >= ID_SALA_PUESTO_BASE:
		var indice: int = id - ID_SALA_PUESTO_BASE
		if indice < _puestos_del_menu.size():
			_modo_construccion.activar_con_herramienta(_puestos_del_menu[indice], false)
			_avisar_accion("Elige dónde va la ventanilla dentro de la sala", COLOR_TENUE_HUD)
		return
	match id:
		ID_SALA_AMPLIAR:
			# Ampliar NO es una acción aparte: es dibujar con el pincel de ESE tipo de sala pegado a
			# la que ya existe. Construcción fusiona y cobra solo las celdas nuevas (enmienda 007).
			_modo_construccion.activar_con_herramienta(
				_construccion.tipo_de_sala(_sala_del_menu), true
			)
			_avisar_accion(
				"Dibuja PEGADO a la sala para ampliarla (solo pagas las celdas nuevas)",
				COLOR_TENUE_HUD
			)
		ID_SALA_ASIENTOS:
			_modo_construccion.activar_con_herramienta(_construccion.ASIENTO_BASICO, false)
			_avisar_accion("Coloca los asientos dentro de la sala", COLOR_TENUE_HUD)
		ID_SALA_DEMOLER:
			_modo_construccion.activar_con_herramienta(&"demoler", false)
			_avisar_accion("Confirma en la sala lo que quieres demoler", COLOR_TENUE_HUD)


## Cuela al ciudadano que hay bajo el cursor: pasa a ser el siguiente al que llamen, y TODOS los
## demás que esperan ese servicio pierden paciencia. El aviso dice a cuántos les ha sentado mal —
## el jugador tiene que ver el precio de su favor, no solo el favor.
func _colar_a(persona: RefCounted) -> void:
	if not _flujo.colar(persona):
		var motivo: String = (
			"Ya estaba colado" if persona.colado else "A esa persona ya la han llamado"
		)
		_avisar_accion(motivo, COLOR_TENUE_HUD)
		return
	var molestos: int = _paciencia.penalizar_por_colado(persona)
	_avisar_accion(
		"⬆ Colado el turno %d · %d esperando se han molestado" % [persona.numero_turno, molestos],
		COLOR_JUSTO
	)


## Aviso corto de una acción del jugador en la barra de acciones (se ve donde se mira al pulsar).
func _avisar_accion(texto: String, color: Color) -> void:
	_lbl_guardado.text = texto
	_lbl_guardado.modulate = color


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
	_actualizar_etiquetas_salas()


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


# ── Etiquetas de sala (petición del usuario 2026-07-29): "no se sabe como de bonificado está la
# sala de descanso o las otras salas para ver cuanta comodidad hay ahí o rendimiento adicional" —
# antes solo se veía abriendo el menú del clic derecho, y ni siquiera en todas las salas. ──────────

## Crea (una vez) la capa donde cuelgan las etiquetas. z_index 1: por ENCIMA del suelo de las salas
## (TileMapLayer + elementos de Construcción cuelgan de un nodo que NO es CanvasItem → son raíces de
## canvas con z_index 0 por defecto) — mismo criterio ya usado por la capa de NPCs (npcs_flujo.gd).
func _crear_capa_etiquetas_sala() -> void:
	_capa_etiquetas_sala = Node2D.new()
	_capa_etiquetas_sala.name = "EtiquetasSala"
	_capa_etiquetas_sala.z_index = 1
	add_child(_capa_etiquetas_sala)


## Recalcula las etiquetas de TODAS las salas construidas. Se llama SOLO cuando el layout cambia de
## verdad —`_al_cambiar_layout`, el hook de Construcción que dispara `_refrescar_visual` en cada
## construcción/demolición/movimiento/carga— y UNA vez al final de `_ready` para la comisaría
## inicial (ese hook se cablea DESPUÉS de `_montar_comisaria_inicial`, así que esas salas de
## arranque nunca lo disparan). **Nunca se llama por frame**: si nadie compra ni construye nada,
## esta función no se ejecuta NUNCA — coste cero por frame, más estricto todavía que el patrón
## pull+diff de `npcs_flujo` (que sí relee getters cada physics frame porque el cansancio cambia
## fuera de eventos de construcción; el confort/equipamiento/descanso instalado, en cambio, SOLO
## cambia cuando se construye/demuele/mueve algo — exactamente cuando este hook ya dispara).
##
## Dentro sí se aplica el mismo patrón DIFF por `set_meta`/`get_meta` que `npcs_flujo._actualizar_
## visual_puesto`: comprar en la sala A dispara este refresco para TODAS las salas (recorrer el
## layout entero es barato aquí — es un evento puntual, no un hot path), pero solo se TOCA el nodo
## Label de las que de verdad cambiaron de texto.
func _actualizar_etiquetas_salas() -> void:
	if _construccion == null or _personal == null:
		return
	var vivas: Dictionary[StringName, bool] = {}
	var todas: Array[StringName] = (
		_construccion.salas_de_tipo("espera") + _construccion.salas_de_tipo("oficina")
		+ _construccion.salas_de_tipo("descanso")
	)
	for sala_id: StringName in todas:
		vivas[sala_id] = true
		var etiqueta: Label = _asegurar_etiqueta_sala(sala_id)
		var texto: String = _texto_etiqueta_sala(sala_id)
		if etiqueta.get_meta(&"texto", "") == texto:
			continue   # mismo texto que la última vez: cero toques al nodo
		etiqueta.set_meta(&"texto", texto)
		etiqueta.text = texto
	# Sala demolida → su etiqueta desaparece con ella (petición explícita: aparecer/desaparecer).
	for sala_id: StringName in _etiqueta_de_sala.keys():
		if not vivas.has(sala_id):
			_etiqueta_de_sala[sala_id].queue_free()
			_etiqueta_de_sala.erase(sala_id)


## El Label de una sala, creado la PRIMERA vez que se ve (persiste hasta que se demuele — jamás se
## reconstruye por un cambio de texto, solo se le toca `.text`).
func _asegurar_etiqueta_sala(sala_id: StringName) -> Label:
	var existente: Label = _etiqueta_de_sala.get(sala_id)
	if existente != null:
		return existente
	var etiqueta := Label.new()
	etiqueta.name = "Sala_%s" % sala_id
	etiqueta.add_theme_font_size_override("font_size", 9)   # mismo tamaño que los rótulos de puesto
	etiqueta.modulate = COLOR_TENUE_HUD   # discreta: información de fondo, no un cartel
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE   # gotcha: decorativo, no roba clics al mundo
	# Esquina inferior-izquierda del rectángulo (celdas → mundo, mismo cálculo que `_crear_suelo`):
	# las ventanillas y sus rótulos de estado viven pegados a la fila de arriba de la sala (ver
	# `_montar_comisaria_inicial`), así que el borde de ABAJO es el hueco más despejado para no
	# tapar nada — un pelín hacia dentro (4 px) y hacia arriba (16 px) para no comerse la rejilla.
	var rect: Rect2i = _construccion.rect_de_sala(sala_id)
	etiqueta.position = (
		POS_SUELO + Vector2(rect.position.x, rect.position.y + rect.size.y) * TAM_CELDA
		+ Vector2(4.0, -16.0)
	)
	_capa_etiquetas_sala.add_child(etiqueta)
	_etiqueta_de_sala[sala_id] = etiqueta
	return etiqueta


## El texto de una sala según su familia — mismas tres ramas que `_titulo_de_sala` (el título del
## menú contextual), pero en una línea corta pensada para verse SIEMPRE, no solo al abrir el menú.
func _texto_etiqueta_sala(sala_id: StringName) -> String:
	var tipo_id: StringName = _construccion.tipo_de_sala(sala_id)
	var tipo: Resource = Datos.obtener(&"TipoSala", tipo_id)
	if tipo != null and tipo.tipo == "espera":
		# Decisión de diseño (pedida explícitamente): el 0 se ENSEÑA, no se oculta. "confort 0" le
		# dice al jugador que ese número EXISTE y sube comprando comodidades; escondiéndolo hasta
		# que abra el menú es exactamente el problema que reportó ("no se sabe cuánta comodidad
		# hay ahí" — un hueco vacío no enseña nada, un "0" sí).
		return "🛋 confort %d · aforo %d" % [
			roundi(_construccion.confort_de_sala(sala_id)), _construccion.aforo_de_sala(sala_id),
		]
	if tipo != null and tipo.tipo == "descanso":
		# Bienestar #13: estos dos getters son GLOBALES (suman TODAS las salas de descanso, no solo
		# ésta) — el mismo dato que ya enseña el título del menú contextual (`_titulo_de_sala`). Con
		# una sola sala (el caso normal) el número es el suyo; con dos, ambas etiquetas mostrarían el
		# mismo total combinado — coherente con que el multiplicador del café de Personal tampoco
		# distingue de qué sala viene.
		return "☕ descanso %d · %d plazas" % [
			roundi(_construccion.descanso_instalado()), _personal.plazas_de_descanso(),
		]
	return "🖥 equipamiento %d" % roundi(_construccion.equipamiento_de_sala(sala_id))


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
	# Aviso de "hay gente que NADIE puede atender" (acción #2 del retro del Sprint 2). Nace vacío:
	# solo ocupa sitio cuando de verdad pasa algo.
	_lbl_sin_servicio = Label.new()
	_lbl_sin_servicio.add_theme_font_size_override("font_size", 11)
	_lbl_sin_servicio.modulate = COLOR_ROJOS
	caja_flujo.add_child(_lbl_sin_servicio)

	# Acciones del jugador (feedback del usuario 2026-07-26: "no hay panel de guardado, ni de personal
	# accesible como el de construir"). Todo lo que se puede hacer, VISIBLE y con su tecla al lado.
	var caja_acciones := _seccion(fila)
	var botonera := HFlowContainer.new()
	botonera.add_theme_constant_override("h_separation", 6)
	botonera.add_theme_constant_override("v_separation", 4)
	caja_acciones.add_child(botonera)
	botonera.add_child(_boton_accion("👥 Personal (P)", func() -> void: _abrir_personal()))
	botonera.add_child(_boton_accion("🕐 Horario (H)", func() -> void: _abrir_horario()))
	botonera.add_child(_boton_accion("💾 Guardar (F5)", func() -> void: _guardar_partida()))
	botonera.add_child(_boton_accion("📂 Cargar (F9)", func() -> void: _cargar_partida()))
	# El botón de calibrar solo aparece en desarrollo (va con el panel: el jugador no lo ve nunca).
	if _panel_admin != null:
		botonera.add_child(_boton_accion("⚙ Calibrar (F1) · DEV", func() -> void: _panel_admin.alternar()))
	_lbl_guardado = Label.new()
	_lbl_guardado.add_theme_font_size_override("font_size", 10)
	_lbl_guardado.modulate = COLOR_TENUE_HUD
	_lbl_guardado.text = "Partida sin guardar"
	caja_acciones.add_child(_lbl_guardado)

	# Bloque de satisfacción (story paciencia-008): la media de HOY construyéndose junto al cierre de
	# AYER (el que fija el dinero de hoy) + las quejas. Con su escala SIEMPRE visible (principio U5
	# del backlog de pulido: ningún número sin saber respecto a qué).
	var caja_sat := _seccion(fila)
	_lbl_satisfaccion = Label.new()
	_lbl_satisfaccion.add_theme_font_size_override("font_size", 13)
	caja_sat.add_child(_lbl_satisfaccion)
	_lbl_reclamaciones = Label.new()
	_lbl_reclamaciones.add_theme_font_size_override("font_size", 11)
	caja_sat.add_child(_lbl_reclamaciones)


## Un botón de la barra de acciones (font pequeña, sin foco — gotcha: si no, Espacio lo "pulsa").
func _boton_accion(texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.add_theme_font_size_override("font_size", 11)
	boton.focus_mode = Control.FOCUS_NONE
	boton.pressed.connect(accion)
	return boton


## Abre el panel de personal (lo mismo que la tecla P, pero descubrible con el ratón).
func _abrir_personal() -> void:
	_panel_personal.visible = true
	_panel_personal._reconstruir()


## Abre el panel del horario de Documentación (story doc-005). Se puede usar EN PAUSA (DO11).
func _abrir_horario() -> void:
	_panel_horario.visible = true
	_panel_horario._refrescar()


## Guarda la partida. El resultado se dice EN PANTALLA: un guardado que falla en silencio es peor que
## no tener guardado (el jugador cree que su partida está a salvo y no lo está).
func _guardar_partida() -> void:
	var ok: bool = SaveManager.guardar_partida()
	_lbl_guardado.text = (
		"Guardado a las %s" % Tiempo.hhmm(Tiempo.minutos_juego) if ok else "⚠ No se pudo guardar"
	)
	_lbl_guardado.modulate = COLOR_TENUE_HUD if ok else COLOR_ROJOS


## Carga la última partida guardada. Tras cargar, el juego queda EN PAUSA (contrato del ADR-0002:
## "cargar sitúa" — nada se mueve hasta que el jugador reanuda).
func _cargar_partida() -> void:
	var ok: bool = SaveManager.cargar_partida()
	_lbl_guardado.text = "Partida cargada (en pausa)" if ok else "⚠ No hay partida guardada"
	_lbl_guardado.modulate = COLOR_TENUE_HUD if ok else COLOR_ROJOS
	if ok:
		_al_cambiar_layout()   # el layout cargado necesita re-bake de navegación y re-sincronizar


## Color de la satisfacción, con los MISMOS umbrales que el ánimo de la gente (66/33): lo que ve el
## jugador en la barra y lo que ve sobre las cabezas hablan el mismo idioma.
func _color_satisfaccion(sat: float) -> Color:
	if sat > _paciencia.umbral_animo_alto:
		return COLOR_HOLGADO
	if sat < _paciencia.umbral_animo_bajo:
		return COLOR_ROJOS
	return COLOR_JUSTO


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
	# ⚠ Gente esperando algo que ninguna ventanilla construida puede atender: si no se dice, esperan
	# para siempre y el jugador no tiene forma de enterarse (el "misterio de las 22:00").
	var huerfanos: Dictionary = _flujo.tramites_sin_servicio()
	# Bienestar #13: quien está de café NO es lo mismo que un puesto sin contratar. Se dice aparte y
	# con su motivo, porque la solución del jugador es distinta: esperar (vuelven solos), montar la
	# sala de descanso para que tarden menos, o contratar a alguien que cubra el hueco.
	var de_cafe: Array[StringName] = (
		_personal.puestos_en_descanso() if _personal.has_method("puestos_en_descanso") else []
	)
	if huerfanos.is_empty() and de_cafe.is_empty():
		_lbl_sin_servicio.text = ""
	elif not huerfanos.is_empty():
		var trozos: Array[String] = []
		for tramite: StringName in huerfanos:
			trozos.append("%s ×%d" % [tramite, huerfanos[tramite]])
		_lbl_sin_servicio.text = "⚠ Nadie puede atender: %s" % ", ".join(trozos)
		_lbl_sin_servicio.modulate = COLOR_ROJOS
	else:
		# Solo cafés: es un aviso, no una alarma — vuelven ellos solos.
		var en_cola: int = _flujo.personas_en_cola(&"Documentacion") + _flujo.personas_en_cola(&"ODAC")
		_lbl_sin_servicio.text = "☕ %d ventanilla(s) de descanso%s" % [
			de_cafe.size(), (" · %d esperando" % en_cola) if en_cola > 0 else "",
		]
		_lbl_sin_servicio.modulate = COLOR_JUSTO
	# Satisfacción (story paciencia-008): hoy / ayer, con la escala a la vista. El color del texto
	# refuerza (verde/ámbar/rojo por los umbrales de ánimo), pero el número manda.
	var sat_hoy: float = _paciencia.sat_global()
	var sat_ayer: float = _paciencia.sat_cierre_de(&"Documentacion")
	_lbl_satisfaccion.text = "Satisfacción: %d/100 (ayer %d)" % [roundi(sat_hoy), roundi(sat_ayer)]
	_lbl_satisfaccion.modulate = _color_satisfaccion(sat_hoy)
	var graves: int = _paciencia.reclamaciones_graves_jornada
	_lbl_reclamaciones.text = "Reclamaciones hoy: %d%s · mes: %d" % [
		_paciencia.reclamaciones_jornada,
		(" (%d graves)" % graves) if graves > 0 else "",
		_paciencia.reclamaciones_mes,
	]
	_lbl_reclamaciones.modulate = COLOR_ROJOS if graves > 0 else COLOR_TENUE_HUD
	# Estado del servicio de Documentación (story doc-002): ABIERTA / CERRANDO / CERRADA — el texto
	# SIEMPRE dice lo que pasa; el color solo lo refuerza (regla de daltónicos del manifiesto).
	var hora_cierre: String = Tiempo.hhmm(float(_documentacion.hora_cierre_min))
	var hora_admision: String = Tiempo.hhmm(float(_documentacion.hora_ultima_admision()))
	match _documentacion.estado_servicio(Tiempo.minutos_juego):
		_documentacion.ESTADO_ABIERTO:
			_lbl_puerta_doc.text = "Doc: ABIERTA (admite hasta %s · cierra %s)" % [
				hora_admision, hora_cierre
			]
			_lbl_puerta_doc.modulate = COLOR_HOLGADO
		_documentacion.ESTADO_CERRANDO:
			_lbl_puerta_doc.text = "Doc: CERRANDO (ya no da número · cierra %s)" % hora_cierre
			_lbl_puerta_doc.modulate = COLOR_BOTON_ACTIVO
		_:
			_lbl_puerta_doc.text = "Doc: CERRADA (abre %s)" % Tiempo.hhmm(
				float(_documentacion.apertura_base_min)
			)
			_lbl_puerta_doc.modulate = Color(0.6, 0.6, 0.6)


## **El único punto por el que viaja el horario de Documentación** (story doc-002): su dueño decide y
## aquí se lo damos a quien lo EJECUTA (Flujo abre/cierra los puestos y da número) y a quien lo
## RESPETA (Demanda no fabrica gente fuera de la ventana). Demanda recibe la **última admisión** como
## fin de ventana: no tiene sentido generar a alguien que se encontraría la puerta cerrada al llegar.
func _al_cambiar_horario_doc(apertura: int, cierre: int, ultima_admision: int) -> void:
	if _flujo != null:
		_flujo.fijar_horario_doc(apertura, cierre, ultima_admision)
		# Y el horario PROPIO de cada ventanilla (story doc-006): las que no hacen la tarde cierran a
		# la hora de la jornada base aunque el servicio siga abierto.
		# La jornada base: a partir de esa hora, atender es peonada y cansa más (Bienestar #13).
		_flujo.fijar_cierre_base_doc(_documentacion.cierre_base_min)
		for puesto_id: StringName in _documentacion.puestos_de_doc():
			var cierre_puesto: int = (
				cierre if _documentacion.puesto_de_tarde(puesto_id)
				else _documentacion.cierre_base_min
			)
			_flujo.fijar_cierre_de_puesto(puesto_id, cierre_puesto)
			# Y Personal necesita el MISMO dato (Bienestar #13, petición del usuario 2026-07-29): a
			# quien le pille el cierre de su ventanilla tomándose el café, se le manda a casa — el
			# turno de Documentación no sigue hasta el día siguiente.
			if _personal != null:
				_personal.fijar_cierre_de_puesto(puesto_id, cierre_puesto)
	if _demanda != null:
		_demanda.fijar_ventana_doc(apertura, ultima_admision)


## El precio de la hora extra, de quien lo decide a quienes lo notan: Economía lo cobra en el cierre
## del día y Personal lo traduce a cuánto cansa esa hora (pagar mejor cansa menos).
func _al_cambiar_peonada(eur_hora: float, generosidad: float) -> void:
	if _economia != null:
		_economia.fijar_peonada_eur_hora(eur_hora)
	if _personal != null:
		_personal.fijar_generosidad_peonada(generosidad)


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
	# Sin servidor gráfico real (--headless, CI, scripts de diagnóstico) el viewport no tiene textura:
	# `get_image()` devuelve null y el `save_png` reventaba con SCRIPT ERROR. La evidencia es ADVISORY:
	# si no se puede capturar, se avisa y se sigue — nunca peta el arranque.
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if DisplayServer.get_name() == "headless":
			return
		var textura: ViewportTexture = get_viewport().get_texture()
		var img: Image = textura.get_image() if textura != null else null
		if img == null:
			push_warning("Main: no se pudo capturar la evidencia (sin textura de viewport)")
			return
		DirAccess.make_dir_recursive_absolute("res://production/qa/capturas")
		# 🐛 BUG DE TRAZABILIDAD corregido 2026-07-29: esto escribía en
		# `production/qa/evidence/flujo-demo-2026-07-24.png`, que es la EVIDENCIA FIRMADA de la demo
		# de la story flujo-008. Cada arranque en ventana la pisaba, así que la imagen que el repo
		# guardaba como prueba de aquella demo era en realidad una foto del último arranque — se
		# había colado ya en cinco commits. La evidencia de QA es un REGISTRO: no la puede reescribir
		# un proceso automático. Ahora va a una carpeta de trabajo, con nombre neutro e ignorada por
		# git; la evidencia de verdad se guarda a mano cuando se firma una demo.
		img.save_png("res://production/qa/capturas/ultimo-arranque.png")
	)
