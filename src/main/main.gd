extends Node2D
## Main — la escena principal del juego de producción (nació como esqueleto en tiempo-009; desde
## flujo-008 la comisaría VIVE: Core 5/5 cableado).
##
## Suelo de rejilla (`TileMapLayer`) + mundo Core instanciado (Economía, Demanda, Construcción,
## Personal, Flujo — en ese orden: tick y carga dependen de él) + capa cosmética de NPCs navegando
## + el HUD real de UX (`HudComisario`, `src/ui/hud_comisario.gd`), reconstrucción total del
## 2026-08-08 según `design/ux/hud-design.md` — sustituye entero al HUD provisional que vivía aquí
## (ver `_crear_hud_comisario`).
##
## Reglas (control-manifest, Presentation): el HUD LEE el reloj (fuente única) y ORDENA la velocidad por
## la API pública (`Tiempo.fijar_velocidad`/`reanudar`); NUNCA muta su estado. El dibujo corre en
## `_process` (tiempo real); la simulación vive en `_physics_process` del autoload Tiempo (ADR-0001).
##
## Story: production/epics/tiempo/story-009-esqueleto-visible.md · ADR-0001 / ADR-0004 (TileMapLayer)

## ⛔ HERRAMIENTA TEMPORAL DE DEPURACIÓN (petición literal del usuario, 2026-08-08): "una brújula
## para saber qué orientación tiene un objeto y cuál debería... esa brújula debería quitarse en el
## futuro cuando te diga". Overlay de 4 cardinales + los 4 grados de la tecla R (ver
## `BrujulaOrientacion` más abajo, montada en `_crear_brujula_orientacion`). SE QUITA poniendo esta
## constante a `false` o borrando el bloque entero cuando el usuario lo pida — no antes.
const BRUJULA_ORIENTACION_VISIBLE := true

## Lado de cada celda de la rejilla, en píxeles (misma escala 40 px que validó el prototipo).
const TAM_CELDA: int = 40
## Dimensiones del suelo visible, en celdas (24×13 ≈ ventana por defecto 1152×648 con margen).
const COLUMNAS: int = 24
const FILAS: int = 13
## Paleta clara (demo del usuario con Summer, 2026-08-05): suelo base CREMA en vez del gris
## sobrio placeholder. El borde de rejilla que llevaba cada tile murió
## el 2026-08-05: la cuadrícula solo se ve en modo construcción (ver `_crear_suelo`).
const COLOR_FONDO := Color(0.13, 0.14, 0.16)
const COLOR_SUELO := Color(0.87, 0.84, 0.78)
## ── ZOOM DE CÁMARA (2026-08-04, petición del usuario: "como en los Sims") ────────────────────────
## Límites en torno al 1.0× con el que se jugaba hasta hoy (sin `Camera2D` la vista era fija: Godot
## usa la transformada identidad cuando no hay ninguna cámara activa). 0.5× acerca al doble; 2.5×
## aleja a dos veces y media. `PASO_ZOOM` es el salto por notch de rueda o pulsación de +/-: pasos
## DISCRETOS, sin lerp — cada notch ya es un salto pequeño y perceptible por sí mismo, así que este
## nodo no necesita `_process` (regla de rendimiento del proyecto: cero coste cuando nadie toca nada).
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 2.5
const PASO_ZOOM: float = 1.1
## Pan de teclado (2026-08-07, "no se puede mover la pantalla con las teclas WASD o con el ratón"):
## px de MUNDO por segundo a zoom 1.0 — `_procesar_pan_camara` la divide por el zoom actual, así que
## el número real varía con cuánto mundo se vea (ver esa función).
const VELOCIDAD_PAN_BASE: float = 800.0
## Modos globales de altura de las paredes (petición del usuario 2026-08-04): el orden en que cicla
## el botón del HUD / la tecla Home. Ver la cabecera de `ParedesSalas.modo_altura`.
const ORDEN_MODOS_PARED: Array[StringName] = [&"auto", &"todas", &"bajitas"]
const NOMBRES_MODO_PARED: Dictionary[StringName, String] = {
	&"auto": "Auto", &"todas": "Enteras", &"bajitas": "Bajitas",
}

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
## La impresora de documentos y el viaje del papel (GDD impresora-documentos-tramite.md).
const ImpresoraDocumentosScript := preload("res://src/core/impresora/impresora_documentos.gd")
## La capa cosmética de NPCs navegando (story flujo-008).
const NPCsFlujoScript := preload("res://src/main/npcs_flujo.gd")
const CapaSombrasScript := preload("res://src/main/capa_sombras.gd")
const PacienciaScript := preload("res://src/feature/paciencia/paciencia.gd")
## Documentación (story doc-002): el DUEÑO del horario del servicio — Flujo lo ejecuta y Demanda lo
## respeta, pero quien lo decide es este sistema (antes vivía prestado dentro de Flujo).
const DocumentacionScript := preload("res://src/feature/documentacion/documentacion.gd")
## El andamio de interacción del modo construcción (story const-007).
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")
## La herramienta DEV de composición del entorno (2026-08-07): "¿podría hacerlo yo con esos
## objetos, como si fuera un builder?" — SOLO se instancia con `--disenador` (ver `_ready`).
const ModoDisenadorEntornoScript := preload("res://src/main/modo_disenador_entorno.gd")
## El andamio del panel de personal (feedback flujo-008): contratar del mercado + asignar a puestos.
const PanelPersonalScript := preload("res://src/main/panel_personal.gd")
## El panel del horario de Documentación (story doc-005): el slider que decide cuánto abres.
const PanelHorarioScript := preload("res://src/main/panel_horario.gd")
## ODAC / Denuncias #9 — la ÚLTIMA pieza del MVP: el dueño de la política de la oficina de
## denuncias (los modos de reconfiguración de cada ventanilla).
const ODACScript := preload("res://src/feature/odac/odac.gd")
## Y su pantalla (tecla O).
const PanelODACScript := preload("res://src/main/panel_odac.gd")
## La ficha de una ventanilla al pulsar sobre ella (detalle tipo tycoon).
const PanelVentanillaScript := preload("res://src/main/panel_ventanilla.gd")
## El modal del Comisario (2026-07-28): sin él, quedarse sin dinero BLOQUEABA la partida.
const ModalComisarioScript := preload("res://src/main/modal_comisario.gd")
## El ciclo de luz día/noche (2026-07-28): la hora del día se VE (art bible §2).
const CicloLuzScript := preload("res://src/main/ciclo_luz.gd")
## Las luces de los objetos comprados, que se encienden de noche (petición del usuario 2026-07-28).
const LucesObjetosScript := preload("res://src/main/luces_objetos.gd")
## Las paredes de las salas (petición del usuario 2026-07-30): fase VISUAL, no bloquean el paso.
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
## El marco exterior NO JUGABLE (design/art/entorno-exterior.md, fase 1): calle+control+aparcamiento
## pintados alrededor del edificio. Fondo puro — ver la cabecera del propio fichero (capa/ADR-0005).
const EntornoExteriorScript := preload("res://src/main/entorno_exterior.gd")
## El cuadro de mandos de calibración (petición del usuario 2026-07-26). Herramienta DEV.
const PanelAdminScript := preload("res://src/main/panel_admin.gd")
## El HUD real de UX (reconstrucción total, 2026-08-08): dos franjas propias -- ver la cabecera de
## `HudComisario` para el árbol de nodos completo.
const HudComisarioScript := preload("res://src/ui/hud_comisario.gd")
## Alto reservado abajo para la barra del HUD (estilo tycoon — petición del usuario 2026-07-24):
## el mundo se centra en lo que queda por encima, no en la ventana entera. Sincronizado a los 60px
## reales de `HudComisario.ALTO_FRANJA_ACCIONES` y `ModoConstruccion.HUECO_BARRA_INFO` (2026-08-09,
## opción A del veredicto de la franja: fuera la banda muerta de 24px que dejaba la reserva vieja
## de 84px de la barra de info).
const ALTO_BARRA_HUD: float = 60.0
## Posición en pantalla del ORIGEN de la rejilla — la esquina (0,0). La comparten el suelo de
## fondo, las capas de Construcción, las paredes y todo lo que se dibuje.
##
## ISOMÉTRICO (2026-07-30): ya no es una constante a ojo. En rombos, el tablero de 24×13 mide
## 1480×740 px (no 960×520) y la esquina (0,0) NO cae arriba a la izquierda del dibujo sino en el
## vértice SUPERIOR del rombo grande, con el tablero abriéndose hacia los dos lados desde ahí. La
## cuenta de dónde ponerla para que quede centrado la hace `Proyeccion.origen_centrado`.
@onready var pos_suelo: Vector2 = Proyeccion.origen_centrado(
	COLUMNAS, FILAS,
	Vector2(get_viewport_rect().size.x, get_viewport_rect().size.y - ALTO_BARRA_HUD)
)
## Colores de estado para avisos puntuales (SIEMPRE acompañados de texto — accesibilidad). El trío
## "Holgado/Justo/Negativo" del saldo ahora vive dentro de `HudComisario` (paleta propia, spec
## §1.5) -- `COLOR_HOLGADO` se retiró de aquí por quedar sin uso; estos dos siguen sirviendo a los
## avisos de `_avisar_accion` (colar, guardar/cargar) y al menú contextual de sala.
const COLOR_JUSTO := Color(1.0, 0.8, 0.35)
const COLOR_ROJOS := Color(0.95, 0.4, 0.4)
## Gris tenue del HUD (texto secundario) -- pensado para el fondo OSCURO de la barra inferior
## (blanco a media opacidad = gris sobre negro). NO usar sobre los módulos CLAROS de la barra
## superior nueva (ver `COLOR_TENUE_HUD_CLARO`, justo abajo): blanco al 65% sobre un fondo pastel
## claro casi no se ve -- ese fue el bug real que encontró esta story al mover `_lbl_reclamaciones`.
const COLOR_TENUE_HUD := Color(1, 1, 1, 0.65)
## Gemelo de `COLOR_TENUE_HUD` para fondos CLAROS (Fase 2 del HUD, 2026-08-08): mismo criterio de
## "texto secundario atenuado", pero partiendo del marino del kit (`KitUIComisario.COLOR_TEXTO_
## PRINCIPAL`) en vez de blanco -- sobre los módulos pastel de la barra superior, blanco atenuado
## se lava; marino atenuado se sigue leyendo.
const COLOR_TENUE_HUD_CLARO := Color(0.11, 0.2, 0.32, 0.65)
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
## Las ventanillas YA CONSTRUIDAS de la sala ocupan 160, 161, 162... — abrir/cerrar cada una a mano
## (peticion del usuario 2026-07-29: "no puedo cerrar la mesa, como se hace?"). `Flujo.cerrar_puesto`
## existia desde la story 006 pero NO SE LLAMABA DESDE NINGUN SITIO de la interfaz: solo la usaba el
## cierre automatico por horario. Una funcion que el jugador no puede alcanzar, para el, no existe.
const ID_SALA_VENTANILLA_BASE := 160
## Poner o quitar las PAREDES de esta sala (2026-07-30). Las paredes son opcionales por sala: hay
## zonas que solo se quieren delimitar (Documentacion, ODAC, las esperas) y otras que se quieren
## cerrar de verdad (la de descanso, para que no se vea a los funcionarios de cafe desde la cola).
const ID_SALA_PAREDES := 106

var _economia: Node
var _demanda: Node
var _personal: Node
var _construccion: Node
## La impresora de documentos: el viaje del papel + los requisitos minimos de sala.
var _impresora: Node
var _flujo: Node
var _paciencia: Node
var _documentacion: Node
var _odac: Node
var _panel_ventanilla: CanvasLayer
var _panel_horario: CanvasLayer
var _npcs: Node2D
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
## Ids de las ventanillas YA CONSTRUIDAS que se listaron en el menu abierto, en el mismo orden.
var _ventanillas_del_menu: Array[StringName] = []
## El modo construcción, para poder darle la herramienta ya en la mano desde el menú.
var _modo_construccion: Node2D
var _persona_del_menu: RefCounted = null
## Etiquetas de sala (petición del usuario 2026-07-29: "no se sabe como de bonificado está la sala
## de descanso o las otras salas"): confort/equipamiento/descanso instalado, SIN abrir ningún menú.
## Capa aparte (z_index 1, por ENCIMA del suelo de las salas — mismo criterio que los NPCs) + un
## Label persistente por sala construida, indexado por su id (patrón de `npcs_flujo._visual_de_puesto`).
var _capa_etiquetas_sala: Node2D
var _etiqueta_de_sala: Dictionary[StringName, Label] = {}
## Las paredes de las salas (2026-07-30): capa cosmética aparte, mismo hook de layout que las de arriba.
var _paredes_salas: Node2D
## El marco exterior (2026-08-07): calle/control/aparcamiento pintados, fuera del rect jugable — NO
## entra en `_mundo_profundo` (fondo puro, ver la cabecera de `entorno_exterior.gd`).
var _entorno_exterior: Node2D
## La bolsa de ordenación por PROFUNDIDAD (2026-08-03): paredes + mobiliario + ventanillas, todo lo
## que se apoya en el suelo y puede taparse entre sí. Ver el comentario largo de `_instanciar_mundo`.
var _mundo_profundo: Node2D
## La capa única de sombras de contacto (2026-08-14): hermana de la bolsa, z −1 (ver `CapaSombras`).
var _capa_sombras: Node2D
## La cámara del juego (2026-08-04): rueda del ratón = zoom (ver `_cambiar_zoom`); desde 2026-08-07
## también WASD/flechas + arrastre con el botón central (ver `_procesar_pan_camara`).
var _camara: Camera2D
## Los límites ABSOLUTOS (con `pos_suelo` ya sumado) dentro de los que puede moverse `_camara` —
## el borde exacto de lo que cubre `EntornoExterior` (`limites_iso_cubiertos()`), fijados una vez en
## `_fijar_limites_camara()`. Fuera de ellos, al zoom que sea, se vería el vacío detrás del entorno.
var _limite_camara_min: Vector2 = Vector2.ZERO
var _limite_camara_max: Vector2 = Vector2.ZERO
## `true` mientras el botón CENTRAL del ratón está pulsado — arrastre de cámara tipo "grab and drag"
## (petición del usuario: "si hago zoom quiero también desplazarme").
var _arrastrando_camara: bool = false
## Las luces de objetos/farolas (2026-08-07): guardado para que `ModoDisenadorEntorno` pueda
## refrescar `usar_farolas()` cada vez que el usuario coloca/borra/carga una farola en el modo.
var _luces_objetos: Node2D = null
## El modo diseñador de entorno (2026-08-07): herramienta DEV, SOLO existe si el proceso arrancó con
## `--disenador` (ver `_ready`) — en juego normal esta variable se queda `null` para siempre.
var _modo_disenador_entorno: Node2D = null
## El HUD real de UX (reconstrucción total, 2026-08-08 -- `HudComisario`, `design/ux/hud-design.
## md`): SU PROPIA `CanvasLayer` (dos franjas dentro, superior siempre visible + acciones
## ocultable). Sustituye a las dos capas separadas que tenía el HUD provisional (`_capa_hud` +
## `_capa_barra_superior`, ya no existen). Guardado para: (1) alimentarlo cada frame desde
## `_process` (`_hud.refrescar()`), (2) ocultar SOLO su franja de acciones mientras construcción o
## el diseñador de entorno están activos (`_hud.ocultar_acciones(...)`, ver `_al_activar_
## construccion`/`_al_activar_disenador` -- la franja superior nunca se oculta, spec §1). Se añade
## al árbol SIN `layer` explícita (capa 1 por defecto): antes que los paneles/modales (Personal,
## Horario, ODAC, Comisario…) para que esos sigan dibujándose POR ENCIMA al abrirse -- mismo
## mecanismo de apilado por orden de inserción que ya usaba el HUD viejo. Solo la brújula de
## depuración se sube aparte a la layer 10 (`_crear_brujula_orientacion`), por encima de TODO.
var _hud: HudComisario = null


## ── BRÚJULA DE ORIENTACIÓN (herramienta DEV temporal, 2026-08-08) ────────────────────────────────
## Ver `BRUJULA_ORIENTACION_VISIBLE` (arriba del todo del archivo): overlay de depuración pedido
## literalmente por el usuario -- "una brújula para saber qué orientación tiene un objeto y cuál
## debería" -- para leer a ojo, mientras se coloca/rota algo con R, hacia dónde cae cada cardinal en
## la vista isométrica y qué grado del ciclo de R le corresponde.
##
## Los 4 cardinales NO son ángulos inventados a mano: se derivan proyectando un paso de una celda en
## cada eje del plano LÓGICO con `Proyeccion` (la ÚNICA traducción lógico↔pantalla del proyecto,
## `src/foundation/proyeccion/proyeccion.gd`) -- Norte=y-1, Sur=y+1, Oeste=x-1, Este=x+1, exactamente
## el mismo criterio que ya usa `ModoConstruccion._frente_de_orientacion`.
##
## Los grados junto a cada letra son la convención REAL del ciclo de rotación de la tecla R
## (`Construccion.ORIENTACIONES_CICLO`: `HORIZONTAL`=0°, `VERTICAL`=90°, `HORIZONTAL_GIRADO`=180°,
## `VERTICAL_GIRADO`=270°) documentada en los comentarios de esas constantes
## (`src/core/construccion/construccion.gd`, líneas ~954-957: "SUR"/"OESTE"/"NORTE"/"ESTE") y
## formalizada en `design/art/lado-de-accion.md` §3 ("Convención de vistas"): **0°=SUR, 90°=OESTE,
## 180°=NORTE, 270°=ESTE**.
class BrujulaOrientacion extends Control:
	const LADO: float = 140.0
	const LARGO_FLECHA: float = 44.0
	const COLOR_LINEA := Color(1.0, 1.0, 1.0, 0.85)
	const COLOR_FONDO := Color(0.0, 0.0, 0.0, 0.35)
	## Cada entrada: la letra del cardinal, su paso de UNA celda en el plano lógico (mismo criterio
	## que `_frente_de_orientacion`) y el grado REAL del ciclo de R que le corresponde (ver la
	## cabecera de arriba para la fuente de esta convención).
	const CARDINALES: Array[Dictionary] = [
		{"letra": "N", "vector": Vector2i(0, -1), "grados": 180},
		{"letra": "S", "vector": Vector2i(0, 1), "grados": 0},
		{"letra": "E", "vector": Vector2i(1, 0), "grados": 270},
		{"letra": "O", "vector": Vector2i(-1, 0), "grados": 90},
	]

	func _ready() -> void:
		custom_minimum_size = Vector2(LADO, LADO)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for cardinal: Dictionary in CARDINALES:
			var etiqueta := Label.new()
			etiqueta.text = "%s %d°" % [cardinal["letra"], cardinal["grados"]]
			etiqueta.add_theme_font_size_override("font_size", 12)
			etiqueta.add_theme_color_override("font_color", Color.WHITE)
			etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
			etiqueta.add_theme_constant_override("outline_size", 3)
			etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var punto: Vector2 = _centro() + _direccion_pantalla(cardinal["vector"]) * (LARGO_FLECHA + 12.0)
			etiqueta.position = punto - Vector2(14.0, 8.0)   # centrado a ojo -- herramienta DEV
			add_child(etiqueta)
		queue_redraw()

	func _centro() -> Vector2:
		return Vector2(LADO, LADO) * 0.5

	## Dirección unitaria EN PANTALLA de un paso `vector_logico` del plano lógico -- derivada de
	## `Proyeccion.centro_iso`, nunca un ángulo puesto a mano (orden explícita de la tarea).
	static func _direccion_pantalla(vector_logico: Vector2i) -> Vector2:
		return (Proyeccion.centro_iso(vector_logico) - Proyeccion.centro_iso(Vector2i.ZERO)).normalized()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(LADO, LADO)), COLOR_FONDO)
		var centro: Vector2 = _centro()
		for cardinal: Dictionary in CARDINALES:
			var direccion: Vector2 = _direccion_pantalla(cardinal["vector"])
			draw_line(centro, centro + direccion * LARGO_FLECHA, COLOR_LINEA, 2.0, true)
		draw_circle(centro, 3.0, COLOR_LINEA)


## Monta el overlay de `BrujulaOrientacion` en su PROPIA `CanvasLayer` (layer 10 -- por encima de
## `HUD`/`UIConstruccion`/`UIDisenadorEntorno`, todas en layer 1 o 2 por defecto): tiene que seguir
## viéndose CON el modo construcción o el diseñador de entorno activos, que es justo cuando más
## falta hace comprobar una orientación. Semitransparente y anclada arriba-derecha, pequeña (140px)
## para no tapar datos del HUD real (que vive abajo).
func _crear_brujula_orientacion() -> void:
	if not BRUJULA_ORIENTACION_VISIBLE:
		return
	var capa := CanvasLayer.new()
	capa.name = "BrujulaOrientacion"
	capa.layer = 10
	add_child(capa)
	var brujula := BrujulaOrientacion.new()
	brujula.name = "Brujula"
	brujula.anchor_left = 1.0
	brujula.anchor_right = 1.0
	brujula.anchor_top = 0.0
	brujula.anchor_bottom = 0.0
	brujula.offset_left = -(BrujulaOrientacion.LADO + 12.0)
	brujula.offset_right = -12.0
	# Debajo de la barra superior del HUD (164px) -- antes solapaba su extremo derecho (fix 2026-08-08).
	brujula.offset_top = 172.0
	brujula.offset_bottom = BrujulaOrientacion.LADO + 172.0
	capa.add_child(brujula)


func _ready() -> void:
	RenderingServer.set_default_clear_color(COLOR_FONDO)
	_crear_camara()
	_fijar_limites_camara()
	# LA BOLSA DE PROFUNDIDAD nace AQUÍ (2026-08-07, antes vivía dentro de `_instanciar_mundo`):
	# `EntornoExterior` necesita colgar sus props CON ALTURA (farola/seto/casas/coches...) de esta
	# MISMA bolsa para competir por profundidad con las paredes del edificio (fix del bug "una farola
	# pegada al sur del muro se dibujaba siempre detrás" — ver la cabecera larga de
	# `EntornoExterior.configurar`), así que tiene que existir ANTES de `_crear_entorno_exterior()`.
	_crear_mundo_profundo()
	# El entorno exterior va ANTES que el suelo interior (fondo antes que figura — ver la cabecera de
	# `entorno_exterior.gd`): su z_index ya lo deja por debajo pase lo que pase, pero el orden del
	# árbol sigue el mismo criterio que el resto del archivo.
	_crear_entorno_exterior()
	_crear_suelo()
	_instanciar_mundo()
	# El HUD real de UX (reconstrucción total, 2026-08-08): capa PROPIA, ANTES que los paneles/
	# modales de más abajo (para que la sigan tapando al abrirse).
	_crear_hud_comisario()
	# Brújula de orientación (herramienta DEV, 2026-08-08): capa propia, independiente del HUD --
	# ver `BRUJULA_ORIENTACION_VISIBLE` y la cabecera de `BrujulaOrientacion`.
	_crear_brujula_orientacion()
	_crear_capa_etiquetas_sala()
	# Modo construcción (story const-007): andamio de ratón sobre la API de Construcción.
	_modo_construccion = ModoConstruccionScript.new()
	_modo_construccion.name = "ModoConstruccion"
	_modo_construccion.configurar(_construccion, TAM_CELDA, _paredes_salas)
	add_child(_modo_construccion)
	# Mismo fix de solape que el diseñador de entorno (2026-08-08): mientras la barra de
	# construcción está abierta, oculta el HUD inferior de Main (que si no, queda tapado debajo).
	# Gemelo exacto de `_modo_disenador_entorno.activado_cambiado.connect(_al_activar_disenador)`
	# más abajo — ver esa nota para el porqué de "solo visibilidad, el HUD sigue vivo debajo".
	_modo_construccion.activado_cambiado.connect(_al_activar_construccion)
	# Modo diseñador de entorno (2026-08-07): herramienta DEV, invisible en juego normal — SOLO se
	# instancia si el proceso arrancó con `--disenador` (`OS.get_cmdline_user_args`, mismo patrón que
	# `--pausa`). Sin el flag esta variable se queda `null` y F12 no hace nada (ver
	# `_unhandled_input`): un jugador normal no puede ni encontrar la herramienta.
	if OS.get_cmdline_user_args().has("--disenador"):
		_modo_disenador_entorno = ModoDisenadorEntornoScript.new()
		_modo_disenador_entorno.name = "ModoDisenadorEntorno"
		# `configurar()` ANTES de `add_child()` (mismo contrato que `ModoConstruccion`): `_ready()`
		# construye sus capas usando `_tam_celda`/`_origen`/`_mundo_profundo`, así que tienen que
		# estar puestos ANTES de que el árbol dispare `_ready()`.
		_modo_disenador_entorno.configurar(TAM_CELDA, pos_suelo, _mundo_profundo)
		add_child(_modo_disenador_entorno)
		_modo_disenador_entorno.layout_cambiado.connect(_al_cambiar_layout_disenador)
		# Fix del solape (petición del usuario): mientras el diseñador está activo, el HUD del juego se
		# OCULTA (y reaparece al salir, con los datos al día — el HUD sigue vivo debajo, `_process` lo
		# sigue refrescando aunque no se vea). Solo se conecta con el flag puesto: en juego normal esta
		# señal no tiene a nadie escuchando y el HUD no cambia de comportamiento.
		_modo_disenador_entorno.activado_cambiado.connect(_al_activar_disenador)
		# Interruptor del entorno base (2026-08-09): el diseñador solo AVISA; quien esconde las
		# capas procedurales es EntornoExterior (el diseñador no toca nodos ajenos).
		_modo_disenador_entorno.base_visible_cambiada.connect(
			func(visible: bool) -> void:
				if _entorno_exterior != null:
					_entorno_exterior.fijar_base_visible(visible)
		)
		# "Importar entorno" (2026-08-09): el diseñador pide el inventario de lo que colocó el
		# procedural y lo adopta como piezas suyas — ver `ModoDisenadorEntorno.importar_base`.
		_modo_disenador_entorno.importar_base_solicitado.connect(
			func() -> void:
				if _entorno_exterior != null:
					_modo_disenador_entorno.importar_base(_entorno_exterior.inventario_base())
		)
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
	# La pantalla de ODAC (tecla O): la palanca para dedicar cada ventanilla a lo urgente o a lo
	# administrativo. Es la parte que le faltaba al MVP.
	# La ficha de una ventanilla (clic izquierdo sobre ella): quién la lleva, lo que rinde y qué
	# atiende. El detalle tycoon que pidió el usuario.
	_panel_ventanilla = PanelVentanillaScript.new()
	_panel_ventanilla.name = "PanelVentanilla"
	_panel_ventanilla.configurar(_flujo, _personal, _construccion, _odac, _documentacion)
	add_child(_panel_ventanilla)
	var panel_odac: CanvasLayer = PanelODACScript.new()
	panel_odac.name = "PanelODAC"
	panel_odac.configurar(_odac, _flujo, _personal)
	add_child(panel_odac)
	_panel_horario.usar_flujo(_flujo)   # para poder abrir/cerrar cada ventanilla desde el panel
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
	# El HUD reacciona a los avisos del bus (además del refresco continuo de _process): refresco
	# inmediato del turno/ciclo. La UI escucha; nunca muta (ADR-0001). La velocidad NO necesita
	# señal propia: `HudComisario.refrescar()` lee `Tiempo.velocidad_actual` directo cada frame.
	EventBus.cambio_de_turno.connect(func(_turno: int) -> void: _hud.refrescar())
	EventBus.cambio_dia_noche.connect(func(_es_noche: bool) -> void: _hud.refrescar())
	# El modal del Comisario: Economía PAUSA el juego al tocar el suelo de deuda y espera una
	# decisión. Sin alguien escuchando esa señal, esa pausa era un bloqueo del que no se salía.
	var modal: CanvasLayer = ModalComisarioScript.new()
	modal.name = "ModalComisario"
	add_child(modal)
	modal.configurar(_economia, EventBus)
	# Partida nueva: el reloj se sitúa a la hora de arranque del catálogo (07:30). Cargar un guardado
	# (F9) sobreescribe esto con la hora guardada, que es lo correcto.
	Tiempo.iniciar_partida_nueva()
	# Arranque EN PAUSA con `--pausa` (petición del usuario 2026-08-01): lanzar la ventana sin que
	# la jornada eche a andar hasta que él se siente delante. Es la MISMA pausa que la tecla
	# Espacio (se reanuda igual). Los args de usuario van tras `--` en la línea de comandos:
	#   godot --path <proyecto> -- --pausa
	if OS.get_cmdline_user_args().has("--pausa"):
		Tiempo.fijar_velocidad(Tiempo.Velocidad.PAUSA)
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
	# Las farolas del entorno exterior TAMBIÉN se encienden de noche (2026-08-07, mismo mecanismo
	# que las comodidades interiores — ver la cabecera de `LucesObjetos.usar_farolas`). Se llama de
	# nuevo cada vez que `ModoDisenadorEntorno` cambia el layout (colocar/borrar/cargar farolas).
	_luces_objetos = luces
	luces.usar_farolas(_entorno_exterior.puntos_farolas())
	_hud.refrescar()
	# Población inicial de las etiquetas de sala: el hook de layout (`_al_cambiar_layout`) se cablea
	# DENTRO de `_instanciar_mundo` DESPUÉS de montar la comisaría inicial, así que esa primera
	# construcción nunca lo dispara (ver comentario de `_actualizar_etiquetas_salas`). Sin esta
	# llamada, la sala de Documentación/ODAC de arranque se quedaría sin etiqueta hasta la primera
	# compra o demolición.
	_actualizar_etiquetas_salas()
	_programar_captura_evidencia()


## El dibujo corre en tiempo real (_process, ADR-0001): refresca los textos leyendo el reloj.
func _process(delta: float) -> void:
	_hud.refrescar()
	_procesar_pan_camara(delta)


## Atajos de teclado: Espacio = pausa/reanuda; 1/2/3 = velocidades. La UI solo ORDENA por la API pública.
func _unhandled_input(evento: InputEvent) -> void:
	# ARRASTRE DE CÁMARA con el botón CENTRAL (petición del usuario: "si hago zoom quiero también
	# desplazarme") — el mundo sigue al ratón, como cualquier "grab and drag" de mapa. Se comprueba
	# ANTES que el resto: es un gesto de cámara, no de juego, y no debe competir con nada más.
	if evento is InputEventMouseMotion and _arrastrando_camara:
		var arrastre := evento as InputEventMouseMotion
		_camara.position = _clamp_posicion_camara(
			_camara.position - arrastre.relative / _camara.zoom, get_viewport_rect().size
		)
		get_viewport().set_input_as_handled()
		return
	# CLIC DERECHO sobre un ciudadano que espera = COLARLO (mecánica pedida por el usuario
	# 2026-07-26). Llega aquí solo si nadie lo consumió antes (el modo construcción tiene prioridad).
	if evento is InputEventMouseButton:
		var raton := evento as InputEventMouseButton
		if raton.button_index == MOUSE_BUTTON_MIDDLE:
			_arrastrando_camara = raton.pressed
			get_viewport().set_input_as_handled()
			return
		# CLIC IZQUIERDO sobre una VENTANILLA = abrir su ficha (petición del usuario 2026-07-31:
		# *"al pulsar en alguna ventanilla debería poder verse como un menú… tipo tycoon"*). Llega
		# aquí solo si el modo construcción no lo consumió antes: en obra, el clic izquierdo
		# construye, y eso manda.
		if raton.pressed and raton.button_index == MOUSE_BUTTON_LEFT:
			var punto: Vector2 = get_canvas_transform().affine_inverse() * raton.position
			var elemento: StringName = _construccion.elemento_en(
				_construccion.celda_de_punto(punto)
			)
			if elemento != &"" and Datos.obtener_silencioso(
				&"TipoPuesto", _construccion.catalogo_de(elemento)
			) != null:
				_panel_ventanilla.mostrar(elemento)
				get_viewport().set_input_as_handled()
			return
		if raton.pressed and raton.button_index == MOUSE_BUTTON_RIGHT:
			# La posición se toma DEL EVENTO y se pasa a coordenadas del mundo con la transformada
			# del canvas. Con `get_global_mouse_position()` se leía el ratón del sistema, no el punto
			# donde se hizo clic: funcionaba llamándolo a mano pero no con el clic de verdad.
			_abrir_menu_ciudadano(
				get_canvas_transform().affine_inverse() * raton.position, raton.position
			)
			get_viewport().set_input_as_handled()
			return
		# Rueda del ratón = ZOOM centrado en el cursor (petición del usuario 2026-08-04, "como en los
		# Sims"): el punto del MUNDO bajo el puntero se queda quieto mientras el resto se acerca o se
		# aleja (`_cambiar_zoom`, misma fórmula que el atajo de teclado +/-, más abajo).
		if raton.pressed and raton.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cambiar_zoom(1.0 / PASO_ZOOM, raton.position)
			get_viewport().set_input_as_handled()
		elif raton.pressed and raton.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cambiar_zoom(PASO_ZOOM, raton.position)
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
		KEY_EQUAL, KEY_KP_ADD:
			_cambiar_zoom(1.0 / PASO_ZOOM, get_viewport().get_visible_rect().size * 0.5)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_cambiar_zoom(PASO_ZOOM, get_viewport().get_visible_rect().size * 0.5)
		KEY_HOME:
			# La tecla de los Sims para alternar el nivel de detalle de paredes (petición del usuario
			# 2026-08-04). NO es "P": esa tecla ya abre el panel de Personal (`panel_personal.gd`).
			_alternar_modo_paredes()
		KEY_F12:
			# El modo diseñador de entorno (2026-08-07): SOLO existe (no `null`) si el proceso
			# arrancó con `--disenador` — sin el flag, F12 no encuentra nada que alternar y esta
			# tecla no hace NADA en juego normal (invisibilidad real, no solo "oculto").
			if _modo_disenador_entorno != null:
				_modo_disenador_entorno.alternar()


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
	# ODAC #9: se instancia DESPUÉS de Flujo (le inyecta su API) y antes del panel que lo maneja.
	_odac = ODACScript.new()
	_odac.name = "ODAC"
	add_child(_odac)
	# ── LA CAPA "MUNDO PROFUNDO" (2026-08-03, arreglo ESTRUCTURAL del orden de dibujo) ────────────
	# Una ÚNICA bolsa de ordenación por profundidad (`y_sort_enabled`) donde conviven las tres cosas
	# que están APOYADAS EN EL SUELO y pueden taparse entre sí:
	#
	#   · cada TRAMO de pared            (`ParedesSalas` → `TramoPared`, hijo directo de aquí)
	#   · el MOBILIARIO estático          (`Construccion/Elementos`, ver `montar_visual`)
	#   · los CONTENEDORES de ventanilla  (`NPCsFlujo/Puestos`, ver su `configurar`)
	#   · los MUÑECOS QUE ANDAN           (`NPCsFlujo/Escena`, 2026-08-06 — ver abajo)
	#
	# Godot ordena esa bolsa por la Y de pantalla de cada pieza (algoritmo del pintor): lo que está
	# más abajo tapa a lo que está más arriba. Con eso, un muro DIVISORIO entre dos salas sale a la
	# vez por delante del mobiliario de la sala de arriba y por detrás del de la de abajo — lo que
	# NINGÚN reparto por z_index podía dar (era el trade-off que el usuario rechazó con su captura de
	# la ventanilla pegada al divisorio Documentación/ODAC). Ver la cabecera de `paredes_salas.gd`.
	#
	# ⚠️ Cada sistema sigue siendo dueño de sus nodos: aquí solo se les pasa DÓNDE colgarlos. Y los
	# cuatro cuelgan a través de un nodo intermedio con `y_sort_enabled` propio, que es lo que hace
	# que sus hijos entren en ESTA bolsa en vez de ordenarse como un bloque aparte (comprobado en el
	# motor 4.6 con una sonda: y-sort anidado = una sola bolsa).
	#
	# ── LA GENTE ENTRÓ EN LA BOLSA (2026-08-06, cambio ESTRUCTURAL aprobado por el usuario) ──────
	# Aquí ponía que la GENTE se quedaba FUERA, en su capa de z 2, "para que ningún muro pueda tapar
	# a un muñeco por muy adelante que esté". Esa garantía se diseñó con muretes de 17 px; con
	# `ALTO_PARED_FRENTE` a 32,5 px se volvió el bug: un NPC pegado por dentro al muro sur salía
	# ENTERO por encima de él (captura del usuario). Los muñecos QUE ANDAN entran ya en esta bolsa y
	# compiten por profundidad como cualquier pieza, por sus PIES. Ver la doc larga en
	# `npcs_flujo.gd` ("LOS MUÑECOS ANDANTES ENTRAN EN LA BOLSA").
	#
	# Lo que NO entra aquí, y por qué: el suelo (z −3) y la tinta de las salas (z −2) van siempre
	# debajo; las LUCES (z 3) y toda la INFORMACIÓN flotante —rótulos de sala y de puesto, barra de
	# paciencia, señal de prohibido, taza de café—, siempre encima. El z_index manda sobre el
	# y-sort, así que dejarlos fuera de la bolsa es exactamente la garantía que se quiere: un muro
	# puede tapar el cuerpo de un muñeco, pero nunca un dato que el jugador necesita.
	#
	# `_mundo_profundo` YA EXISTE al llegar aquí (`_crear_mundo_profundo`, llamada desde `_ready`
	# ANTES que `_crear_entorno_exterior` — ver esa función para el motivo: `EntornoExterior` también
	# necesita colgar de esta bolsa).
	# `ParedesSalas` va vacío todavía (sus `TramoPared` nacen en `configurar()`, más abajo, cuando ya
	# hay salas que dibujar): lo que importa aquí es que cuelgue de la bolsa.
	_paredes_salas = ParedesSalasScript.new()
	_paredes_salas.name = "ParedesSalas"
	_mundo_profundo.add_child(_paredes_salas)
	# Construcción (story const-006): el layout REAL. ⚠️ ANTES que Personal en el árbol: el orden de
	# los hijos es el orden de carga del SaveManager, y las asignaciones de Personal referencian
	# puestos que Construcción debe registrar primero (invariante de personal-006/const-005). Que
	# `_paredes_salas` se añada un poco antes (arriba) NO afecta a esta invariante: `ParedesSalas` no
	# entra al grupo "Persist" (no tiene `save()`/`load_state()` — es puramente cosmético, derivado
	# del modelo de Construcción), así que el orden de carga del SaveManager sigue intacto.
	_construccion = ConstruccionScript.new()
	_construccion.name = "Construccion"
	_construccion.usar_economia(_economia)
	# ANTES de `montar_visual`: las sombras de los muebles se registran al crear cada pieza.
	_construccion.usar_capa_sombras(_capa_sombras)
	add_child(_construccion)
	# Su capa de mobiliario ("Elementos") entra en la bolsa de profundidad; la tinta de suelo de las
	# salas se queda colgando de Construcción, con su z −1 de siempre (nunca compite: va debajo).
	_construccion.montar_visual(TAM_CELDA, pos_suelo, _mundo_profundo)
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
	# LA IMPRESORA DE DOCUMENTOS (GDD impresora-documentos-tramite.md). Va ANTES del montaje de oficio
	# a proposito: es ella quien coloca los objetos OBLIGATORIOS de cada sala (decision P1 del usuario,
	# "no existe el caso sala sin impresora"), asi que la comisaria inicial ya nace con las suyas.
	# Su handler de `nuevo_dia` (prioridad 17) cobra el mantenimiento POR USO: 2 EUR por cada turno en
	# que su sala atiende, entre el mantenimiento plano de Construccion (16) y el cierre de Economia (20).
	_impresora = ImpresoraDocumentosScript.new()
	_impresora.name = "ImpresoraDocumentos"
	_impresora.usar_construccion(_construccion)
	_impresora.usar_economia(_economia)
	_impresora.usar_tiempo(Tiempo)
	add_child(_impresora)
	# Edge case del GDD: "impresora demolida a mitad de viaje -> el funcionario vuelve con las manos
	# vacias". Construccion no conoce a Impresora por nombre (regla de capas); solo avisa por hook.
	_construccion.fijar_hook_elemento_demolido(_impresora.impresora_demolida)
	_montar_comisaria_inicial()
	# A PARTIR DE AQUI, toda sala nueva que construya el JUGADOR nace con sus objetos obligatorios y
	# pagandolos (el montaje de oficio de arriba ya se sirvio los suyos gratis). Se cablea DESPUES del
	# montaje a proposito: es la unica diferencia entre "lo entrega la DGP" y "lo compras tu".
	_construccion.fijar_hook_sala_creada(_al_crear_sala_nueva)
	# Las paredes de las salas (petición del usuario 2026-07-30: "si no todo el mundo ve a los
	# funcionarios descansando, es raro"): solo VISUAL, no bloquean el paso (fase aparte). El nodo
	# `_paredes_salas` ya está en el árbol (arriba, dentro de `_mundo_profundo`); aquí solo toca
	# `configurar()`: crea un `TramoPared` por tramo (2026-08-03 — ver `paredes_salas.gd`) y hace el
	# primer cálculo, ya con las salas de arranque construidas.
	_paredes_salas.configurar(_construccion, TAM_CELDA, pos_suelo)
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
	# El viaje del papel: Flujo dispara el aviso, RETIENE el cierre del tramite mientras el funcionario
	# esta fuera y lo cierra en cuanto vuelve con el documento. Sin esta linea Flujo va como antes.
	_flujo.usar_impresora(_impresora)
	add_child(_flujo)
	_construccion.fijar_puede_demoler(_flujo.puede_demoler_puesto)   # gate AC-CO13
	# Documentación cobra la peonada (F1) y desmotiva a quien sale tarde (DO5): necesita Economía
	# (le REGISTRA las horas, no toca el saldo), Personal (cuántos agentes la cubren) y Demanda (el
	# nivel BAJA/MEDIA/ALTA, la brújula de la decisión). Story doc-003.
	# ODAC #9 ordena por la API pública de Flujo (reconfigurar_puesto) y nunca toca su estado.
	_odac.usar_flujo(_flujo)
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
	# `_mundo_profundo` es la bolsa de profundidad: ahí cuelga NPCsFlujo sus CONTENEDORES de
	# ventanilla (mobiliario) y, desde el 2026-08-06, también sus MUÑECOS QUE ANDAN — ver arriba.
	_npcs.usar_capa_sombras(_capa_sombras)   # antes de configurar: los puestos registran su sombra
	_npcs.configurar(
		_flujo, _construccion, _personal, TAM_CELDA, pos_suelo, COLUMNAS, FILAS, _mundo_profundo
	)
	_npcs.usar_paciencia(_paciencia)   # el aro de ánimo sobre cada ciudadano (story paciencia-008)
	_npcs.usar_impresora(_impresora)   # el muñeco del viaje del papel + la ficha "🖨 a por el documento"
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
	_ventanillas_del_menu.clear()

	# Cabecera: qué sala es y cómo está de ocupada (contexto para decidir si ampliar).
	_menu_sala.add_item(_titulo_de_sala(sala_id, tipo), ID_SALA_TITULO)
	_menu_sala.set_item_disabled(0, true)
	_menu_sala.add_separator()

	_menu_sala.add_item("📐 Ampliar esta sala (dibuja pegado a ella)", ID_SALA_AMPLIAR)
	_menu_sala.add_item(
		"🧱 Quitar las paredes" if _construccion.sala_con_paredes(sala_id)
		else "🧱 Poner paredes",
		ID_SALA_PAREDES
	)
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
	_anadir_comodidades_al_menu(tipo, sala_id)
	_anadir_ventanillas_al_menu(sala_id)
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
		return "%s · %d×%d · aforo %d · aguantan %d min" % [
			nombre, rect.size.x, rect.size.y,
			_construccion.aforo_de_sala(sala_id),
			_minutos_de_espera_de_sala(sala_id),
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


## Lista las ventanillas YA CONSTRUIDAS de esta sala para poder ABRIRLAS o CERRARLAS a mano
## (peticion del usuario 2026-07-29). Cerrar una ventanilla es una decision de gestion real: dejas
## de atender por ella sin despedir a nadie ni demoler nada — util para concentrar la cola, o para
## mandar a su titular a otra cosa. La atencion EN CURSO nunca se interrumpe: Flujo deja el cierre
## pendiente y la persiana baja al terminar con el ciudadano que ya estaba delante.
func _anadir_ventanillas_al_menu(sala_id: StringName) -> void:
	if _flujo == null or _construccion == null:
		return
	var hay: bool = false
	for elemento_id: StringName in _construccion.contenido_de_sala(sala_id):
		# 🐛 Corregido 2026-07-29 (el usuario: "no entiendo lo de abrir la ventanilla del asiento X"):
		# antes se preguntaba primero si estaba CERRADO y solo despues si era una ventanilla... y
		# `estado_de_puesto` responde "cerrado" a cualquier id que Flujo no conozca — incluidos los
		# asientos y las comodidades. Resultado: el menu ofrecia "abrir la ventanilla asiento_3".
		# El filtro de QUE ES va SIEMPRE primero.
		var catalogo: StringName = _construccion.catalogo_de_elemento(elemento_id)
		var tipo_puesto: Resource = Datos.obtener_silencioso(&"TipoPuesto", catalogo)
		if tipo_puesto == null:
			continue   # un asiento, un sofa o una lampara no son una ventanilla que abrir o cerrar
		if not hay:
			_menu_sala.add_separator()
			hay = true
		# Y con su NOMBRE del catalogo, no con el id interno: "Ventanilla Documentacion", no "doc_1".
		var cerrada: bool = _flujo.estado_de_puesto(elemento_id) == &"cerrado"
		_menu_sala.add_item(
			("🔓 Abrir %s" if cerrada else "🔒 Cerrar %s") % tipo_puesto.nombre,
			ID_SALA_VENTANILLA_BASE + _ventanillas_del_menu.size()
		)
		_ventanillas_del_menu.append(elemento_id)


## Cuantos MINUTOS aguanta la gente en una sala de espera con el confort que tiene instalado.
##
## Peticion del usuario 2026-07-29: *"el confort yo creo que lo debemos calcular por minutos de
## paciencia, asi se entiende mejor"*. Tiene razon y ademas hay un motivo de fondo: el efecto del
## confort NO ES LINEAL — el multiplicador divide la tasa de drenaje, asi que cada punto vale MAS
## cuantos mas tengas (de 0 a 5 puntos son +3 min; de 15 a 20, +7). Decir "confort +5" no informa de
## nada; decir "aguantan 37 min" si. La conversion la hace Paciencia con SU formula (ADR-0001).
## Los minutos que aguantarian si se anadiera `extra` puntos de confort a esta sala — para poder
## decir en el menu lo que GANAS comprando ese objeto, en vez de un numero abstracto.
## Lo que duraria la pausa reglamentaria (30 min) con `extra` puntos mas de calidad en la sala de
## descanso. Sirve para decir en MINUTOS lo que acorta cada mueble, en vez de en puntos abstractos.
func _minutos_de_pausa_con_extra(extra: float) -> float:
	if _personal == null or _construccion == null:
		return 0.0
	var calidad: float = _construccion.descanso_instalado() + extra
	var mult: float = clampf(
		1.0 - _personal.k_confort_pausa * calidad, _personal.mult_pausa_min, 1.0
	)
	return float(_personal.min_pausa_normal) * mult


## Cuanto MAS RAPIDO se atiende en esta sala con `extra` puntos mas de equipamiento, en tanto por
## ciento. El equipamiento divide la duracion del tramite, y cada tramite dura distinto, asi que el
## porcentaje informa mejor que unos minutos que solo valdrian para un tramite concreto.
func _pct_mas_rapido_con_extra(sala_id: StringName, extra: float) -> float:
	if _flujo == null or _construccion == null:
		return 0.0
	var rendimiento: float = _construccion.equipamiento_de_sala(sala_id) + extra
	var mult: float = clampf(
		1.0 - _flujo.k_equipamiento * rendimiento, _flujo.mult_equipamiento_min, 1.0
	)
	return (1.0 - mult) * 100.0


func _minutos_de_espera_con_extra(sala_id: StringName, extra: float) -> int:
	if _paciencia == null or _construccion == null:
		return 0
	var confort: float = _construccion.confort_de_sala(sala_id) + extra
	var mult: float = clampf(
		1.0 - _paciencia.k_confort * confort, _paciencia.mult_comodidad_min, 1.0
	)
	return roundi(_paciencia.minutos_hasta_agotar(1.0, mult))


func _minutos_de_espera_de_sala(sala_id: StringName) -> int:
	if _paciencia == null or _construccion == null:
		return 0
	var confort: float = _construccion.confort_de_sala(sala_id)
	var mult: float = clampf(
		1.0 - _paciencia.k_confort * confort, _paciencia.mult_comodidad_min, 1.0
	)
	return roundi(_paciencia.minutos_hasta_agotar(1.0, mult))


## Pinta las comodidades que ESTA sala admite, con su precio, lo que aporta y lo que cuesta tenerla
## encendida. El catálogo manda: si mañana se añade un objeto nuevo, aparece aquí solo.
func _anadir_comodidades_al_menu(tipo_sala: Resource, sala_id: StringName) -> void:
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
		# BUG corregido 2026-07-29 (el usuario: "las luces no se pueden poner o por lo menos no se
		# hacerlo yo"): el menu ofrecia UNA sola familia por sala, asi que la familia `iluminacion`
		# --que puede ir en CUALQUIER sala-- no aparecia en ninguna parte y no habia forma de
		# comprarla. Se habia aplicado la regla de DONDE se pueden colocar, pero no la de donde se
		# OFRECEN. Una funcion existe y es invisible: para el jugador, es que no existe.
		var es_luz: bool = comodidad.familia == "iluminacion"
		if comodidad.familia != familia and not es_luz:
			continue
		var etiqueta: String = "%s %s (%d €" % [
			("💡" if es_luz else icono), comodidad.nombre, comodidad.coste_construccion_eur,
		]
		if comodidad.coste_mantenimiento_dia_eur > 0:
			etiqueta += " + %d €/día" % comodidad.coste_mantenimiento_dia_eur
		# Una lampara no aporta a ningun sistema (aporte 0): lo que compra el jugador es VER de noche.
		# Ensenar "luz +0" seria decir que no sirve para nada, asi que se dice lo que de verdad hace.
		if es_luz:
			etiqueta += ") · alumbra de noche"
		elif familia == "ciudadano":
			# En MINUTOS, no en puntos abstractos (peticion del usuario 2026-07-29). Y calculado SOBRE
			# ESTA SALA: como el efecto no es lineal, el mismo objeto da mas minutos en una sala ya
			# amueblada que en una pelada. El numero que se ensena es el que de verdad vas a ganar.
			var ahora: int = _minutos_de_espera_de_sala(sala_id)
			var despues: int = _minutos_de_espera_con_extra(sala_id, comodidad.aporte)
			if despues > ahora:
				etiqueta += ") · +%d min de espera" % (despues - ahora)
			else:
				etiqueta += ") · ya estas al tope de confort"
		elif familia == "descanso":
			# Los muebles de descanso ACORTAN el cafe: se dice en minutos, no en puntos (el usuario:
			# "+2 unidades de eso no son +2 minutos, deberia ser el equivalente"). Se usa la pausa
			# reglamentaria de 30 min como referencia, que es la del agente tipico.
			var pausa_ahora: float = _minutos_de_pausa_con_extra(0.0)
			var pausa_luego: float = _minutos_de_pausa_con_extra(comodidad.aporte)
			if pausa_ahora - pausa_luego >= 0.05:
				# "menos de DESCANSO", no "menos de cafe" (usuario, 2026-07-31): el mueble hace que se
				# recupere antes, o sea que la pausa dura menos. Decir "menos cafe" sonaba a castigo.
				etiqueta += ") · %.1f min menos de descanso" % (pausa_ahora - pausa_luego)
			else:
				etiqueta += ") · ya estas al tope de descanso"
		else:
			# El equipamiento acelera los tramites: se dice en % de rapidez, no en puntos. En % y no
			# en minutos porque cada tramite dura distinto (un DNI 12 min, un pasaporte 15).
			var pct_ahora: float = _pct_mas_rapido_con_extra(sala_id, 0.0)
			var pct_luego: float = _pct_mas_rapido_con_extra(sala_id, comodidad.aporte)
			if pct_luego - pct_ahora >= 0.05:
				etiqueta += ") · atienden un %.1f %% mas rapido" % (pct_luego - pct_ahora)
			else:
				etiqueta += ") · ya estas al tope de equipamiento"
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
	if id >= ID_SALA_VENTANILLA_BASE:
		var iv: int = id - ID_SALA_VENTANILLA_BASE
		if iv < _ventanillas_del_menu.size():
			var ventanilla: StringName = _ventanillas_del_menu[iv]
			if _flujo.estado_de_puesto(ventanilla) == &"cerrado":
				_flujo.abrir_puesto(ventanilla)
			else:
				_flujo.cerrar_puesto(ventanilla)
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
		ID_SALA_PAREDES:
			var con: bool = not _construccion.sala_con_paredes(_sala_del_menu)
			_construccion.fijar_paredes_de_sala(_sala_del_menu, con)
			# AMURALLAR YA NO REGALA UNA PUERTA (2026-08-04 · quick-spec §3): la sala queda cerrada y
			# el paso siguiente es que el jugador elija el tramo. Se entra en construcción con el
			# pincel de puerta ya en la mano; si se arrepiente, Esc y la sala se queda sin ella.
			if con and _construccion.sala_amurallada_sin_puerta(_sala_del_menu):
				_modo_construccion.pedir_puerta_de_sala()
				_avisar_accion("Paredes puestas · ahora elige dónde va la puerta", COLOR_TENUE_HUD)
			else:
				_avisar_accion(
					"Paredes puestas" if con else "Paredes quitadas", COLOR_TENUE_HUD
				)
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
	_hud.avisar(texto, color)


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
	_paredes_salas.actualizar()


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
	# ISOMÉTRICO (2026-07-30): el rótulo va sobre el vértice de ABAJO de la caja que envuelve la
	# sala — en rombos ese es el punto más bajo del dibujo y, por tanto, el hueco más despejado
	# (las ventanillas y sus rótulos de estado viven pegados a la fila de arriba de la sala, ver
	# `_montar_comisaria_inicial`). Centrado bajo ese vértice y un pelín por debajo.
	var rect: Rect2i = _construccion.rect_de_sala(sala_id)
	etiqueta.position = (
		_construccion.esquina_en_pantalla(rect.end.x, rect.end.y) + Vector2(-30.0, 2.0)
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
		return "🛋 aguantan %d min · aforo %d" % [
			_minutos_de_espera_de_sala(sala_id), _construccion.aforo_de_sala(sala_id),
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


## REQUISITOS MINIMOS DE SALA (GDD impresora-documentos-tramite.md, decision P1 del usuario): una
## sala recien construida se sirve sola sus objetos OBLIGATORIOS -- hoy, la impresora de documentos
## de Documentacion y de ODAC. Se COBRAN (600 EUR): es una compra del jugador, no un regalo.
##
## Si en ese momento no hay caja, el gate E4 de Economia rechaza la compra y la sala se queda sin su
## impresora: `ImpresoraDocumentos.cumple_requisitos` lo dira, y la proxima carga de partida la
## recoloca (el pase idempotente de `completar_todas_las_salas`). Se prefirio esto a tumbar la sala
## entera por 600 EUR de mas -- una sala pagada no se le quita al jugador por sorpresa.
func _al_crear_sala_nueva(sala_id: StringName) -> void:
	_impresora.completar_requisitos(sala_id, false)

## El montaje inicial "DE OFICIO" (const-006, decisión ratificada): la DGP entrega la comisaría
## montada y pagada (coste 0) → saldo 3000 € y nómina 190 € INTACTOS. Construida por la API real de
## Construcción (los puestos llegan a Personal por el puente registrar_puesto, ya no a mano); ids
## compat doc_1/doc_2/odac_1 (los mismos de los saves y tests previos).
func _montar_comisaria_inicial() -> void:
	# LA FACHADA primero (2026-07-30, petición del usuario): el edificio se cierra por su perímetro
	# con muros que NO se pueden derribar, y se abre una puerta de acceso en el lado de la calle.
	# A partir de aquí, entrar y salir de la comisaría es cruzar ESA puerta, no atravesar el muro.
	_construccion.levantar_fachada()
	var doc: StringName = _construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(1, 1, 6, 4))
	var espera_doc: StringName = _construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(1, 6, 6, 4))
	var odac: StringName = _construccion.construir_de_oficio_sala(&"sala_odac", Rect2i(9, 1, 4, 3))
	var espera_odac: StringName = _construccion.construir_de_oficio_sala(&"sala_espera_odac", Rect2i(9, 5, 3, 3))
	# LAS PUERTAS DEL PLANO, EXPLÍCITAS (2026-08-04 · quick-spec §3). Desde que murió el hueco
	# automático, una sala amurallada nace CERRADA: si el plano de la DGP entrega alguna sala con
	# paredes, su puerta la pone aquí el propio plano — la comisaría se entrega jugable, nunca con una
	# habitación tapiada. Cada puerta va en el lado que da a la circulación (el que mira hacia la
	# entrada del edificio, (0,6)): exactamente donde caía el viejo hueco automático.
	# Las salas que se entregan en planta DIÁFANA (hoy las cuatro: solo la de descanso se cierra sola)
	# no tienen pared donde abrir nada, y `_abrir_puerta_de_oficio` las deja en paz sin ruido.
	_abrir_puerta_de_oficio(doc, Vector2i(1, 4), &"izquierda")
	_abrir_puerta_de_oficio(espera_doc, Vector2i(1, 6), &"izquierda")
	_abrir_puerta_de_oficio(odac, Vector2i(9, 3), &"izquierda")
	_abrir_puerta_de_oficio(espera_odac, Vector2i(9, 6), &"izquierda")
	_construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(2, 2), &"doc_1")
	_construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(4, 2), &"doc_2")
	# Ventanilla TIE inicial (feedback flujo-008, ratificada): (6,2) libre dentro de sala_documentacion.
	_construccion.construir_de_oficio_elemento(&"puesto_tie", Vector2i(6, 2), &"tie_1")
	_construccion.construir_de_oficio_elemento(&"puesto_odac", Vector2i(10, 2), &"odac_1")
	# LAS IMPRESORAS DE DOCUMENTOS DEL TRAZADO INICIAL (GDD impresora-documentos-tramite.md, decision
	# de colocacion del usuario): van DETRAS del puesto o a un lado, pero siempre de la mesa hacia
	# atras -- NUNCA hacia el lado del ciudadano. Aqui no se elige la celda a mano: la decide
	# `ImpresoraDocumentos.celda_para_comodidad` con esa regla, que es la MISMA que usa el jugador
	# cuando designa una sala nueva y la que recoloca las que falten al cargar un save antiguo.
	# Con el trazado de hoy sale sola la colocacion que pide el GDD: en Documentacion, justo detras del
	# puesto de TIE; en ODAC, al lado de la fila del funcionario (detras no cabe: la sala acaba ahi).
	# De oficio = coste 0 (la DGP entrega la comisaria montada y pagada, decision ratificada).
	_impresora.completar_todas_las_salas(true)
	for x: int in range(2, 6):
		_construccion.construir_de_oficio_elemento(_construccion.ASIENTO_BASICO, Vector2i(x, 7))
		_construccion.construir_de_oficio_elemento(_construccion.ASIENTO_BASICO, Vector2i(x, 8))
	for x: int in range(9, 12):
		_construccion.construir_de_oficio_elemento(_construccion.ASIENTO_BASICO, Vector2i(x, 6))


## Abre la puerta de una sala del montaje de oficio. Solo actúa si esa sala se entrega AMURALLADA:
## sin pared no hay hueco que abrir (y una sala en planta diáfana no necesita ninguno — se entra por
## donde no hay pared). Si hubiera pared y aun así fallara, es un BUG del plano inicial → aviso
## ruidoso, misma política que el resto del montaje de oficio.
func _abrir_puerta_de_oficio(sala_id: StringName, celda: Vector2i, lado: StringName) -> void:
	if sala_id == &"" or not _construccion.sala_con_paredes(sala_id):
		return
	if not _construccion.fijar_tipo_de_muro(celda, lado, _construccion.PUERTA):
		push_warning(
			"Main: la puerta de oficio de la sala '%s' (%s, lado %s) NO se pudo abrir"
			% [sala_id, celda, lado]
		)


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


# ── Cámara (2026-08-04) ────────────────────────────────────────────────────────────────────────
## `ANCHOR_MODE_FIXED_TOP_LEFT` + zoom 1.0 + posición (0,0) reproduce EXACTAMENTE la transformada
## identidad que regía SIN cámara (Godot 4.6: sin ninguna `Camera2D` activa, `get_canvas_transform()`
## es la identidad) — cero cambios en las conversiones ratón→mundo que ya usan `get_canvas_transform()`
## en todo el juego (este fichero y `modo_construccion.gd`, ambos con el mismo patrón
## `get_canvas_transform().affine_inverse() * evento.position`).
func _crear_camara() -> void:
	_camara = Camera2D.new()
	_camara.name = "CamaraJuego"
	_camara.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	_camara.zoom = Vector2.ONE
	_camara.position = Vector2.ZERO
	add_child(_camara)
	# `make_current()`, NO `.current = true`: esa asignación directa da SCRIPT ERROR en 4.6 ("Invalid
	# assignment of property or key 'current'") comprobado en el motor — `make_current()` es el
	# camino que ya usa `tools/_diag_oclusion_murete.gd` y funciona.
	_camara.make_current()


## Los límites ABSOLUTOS del pan (2026-08-07, "que al moverse no se vean cosas vacías fuera, solo
## entorno" — como Theme Hospital): `EntornoExterior.limites_iso_cubiertos()` ya calculó el
## rectángulo, en el mismo origen relativo que usan sus `RECT_*`; aquí solo hace falta sumarle
## `pos_suelo` para pasarlo a las coordenadas ABSOLUTAS en las que vive `_camara.position` (el mismo
## marco que usa `_cambiar_zoom`). Se llama UNA vez, justo tras crear la cámara — el área cubierta no
## cambia en caliente (solo el pan/zoom del jugador dentro de ella).
func _fijar_limites_camara() -> void:
	var relativo: Rect2 = EntornoExterior.limites_iso_cubiertos()
	_limite_camara_min = pos_suelo + relativo.position
	_limite_camara_max = _limite_camara_min + relativo.size


## Recorta `posicion_deseada` para que, al zoom ACTUAL de `_camara`, una ventana de `ventana` px
## quede dentro de `[_limite_camara_min, _limite_camara_max]` — se llama SIEMPRE tras cualquier
## cambio de posición O de zoom (rueda, +/-, WASD/flechas, arrastre central): el zoom ya tenía su
## propio clamp (`nuevo.clamp(...)` en `_cambiar_zoom`), pero ESE solo evita un zoom fuera de rango,
## no que la posición se salga del entorno cubierto una vez aplicado el nuevo zoom.
##
## `ventana` es un PARÁMETRO (no `get_viewport_rect().size` leído aquí dentro) a propósito: así la
## función es pura — sin nodo en el árbol, sin `Viewport` — y los tests pueden llamarla directo sobre
## un `Main` sin `add_child` (mismo patrón que `ModoConstruccion` en
## `construccion_picking_muros_test.gd::_modo()`), igual que pide `src/CLAUDE.md`
## ("preferir inyección de dependencias... para que se pueda testear").
func _clamp_posicion_camara(posicion_deseada: Vector2, ventana: Vector2) -> Vector2:
	var visible: Vector2 = ventana / _camara.zoom
	var maximo := Vector2(
		maxf(_limite_camara_max.x - visible.x, _limite_camara_min.x),
		maxf(_limite_camara_max.y - visible.y, _limite_camara_min.y),
	)
	return posicion_deseada.clamp(_limite_camara_min, maximo)


## El pan de teclado (WASD + flechas, petición del usuario "no se puede mover la pantalla") —
## continuo mientras se mantenga pulsada, velocidad en MUNDO inversamente proporcional al zoom
## actual (`VELOCIDAD_PAN_BASE / zoom`): con la cámara a `ZOOM_MAX` se ve POCO mundo y conviene ir
## fino; a `ZOOM_MIN` (el que MÁS mundo enseña — ver la cabecera de `entorno_exterior.gd`) conviene
## cubrir terreno rápido. Corre en `_process` (tiempo real, la cámara no es parte de la simulación de
## juego — ADR-0001) y pasa SIEMPRE por `_clamp_posicion_camara`, igual que el zoom.
func _procesar_pan_camara(delta: float) -> void:
	var direccion := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direccion.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direccion.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direccion.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direccion.y += 1.0
	if direccion == Vector2.ZERO:
		return
	var velocidad: float = VELOCIDAD_PAN_BASE / _camara.zoom.x
	_camara.position = _clamp_posicion_camara(
		_camara.position + direccion.normalized() * velocidad * delta, get_viewport_rect().size
	)


## Cambia el zoom por el factor `mult` (>1 aleja, <1 acerca) manteniendo fijo, bajo `punto_pantalla`,
## el MISMO punto del mundo que había antes del cambio — fórmula estándar de zoom centrado en cursor.
##
## 🐛 FIX (2026-08-06, bug "cursor desviado" jugando con zoom — hallazgo de la RONDA 2 de ese bug,
## mientras se perseguía otra causa en `modo_construccion.gd`): la fórmula de aquí estaba INVERTIDA.
## Con `ANCHOR_MODE_FIXED_TOP_LEFT` la relación real (comprobada contra `get_canvas_transform()` del
## motor, no solo derivada a mano) es `mundo = pantalla / zoom + posición` — NO `pantalla · zoom +
## posición`, que es lo que decía el comentario viejo y en lo que se basaba el código de abajo.
## Con la fórmula vieja (`posicion += (anterior - nuevo) * punto_pantalla`), CADA rueda de ratón
## desplazaba el mundo bajo el cursor ~150px en una comisaría normal (probado con la sonda: `mundo
## bajo el cursor` saltaba de (800,450) a (647,364) tras UN solo `PASO_ZOOM`) — el propio gesto de
## hacer zoom, no una herramienta de construcción concreta, así que afectaba a TODO el juego, no
## solo al modo construcción. Derivando de la relación correcta (mundo = pantalla/zoom + posición),
## para que el mundo bajo `punto_pantalla` no se mueva: `posición_después = posición_antes +
## punto_pantalla · (1/zoom_antes − 1/zoom_después)` — confirmado con la sonda: deriva exactamente
## (0,0) zoomando y volviendo. El atajo de teclado (+/-) pasa el centro de la pantalla en vez del
## cursor — no hay cursor que fijar, así que se ancla el centro de la vista.
func _cambiar_zoom(mult: float, punto_pantalla: Vector2) -> void:
	var anterior: Vector2 = _camara.zoom
	var nuevo: Vector2 = (anterior * mult).clamp(Vector2(ZOOM_MIN, ZOOM_MIN), Vector2(ZOOM_MAX, ZOOM_MAX))
	if nuevo.is_equal_approx(anterior):
		return
	var posicion_anclada: Vector2 = (
		_camara.position + punto_pantalla * (Vector2.ONE / anterior - Vector2.ONE / nuevo)
	)
	_camara.zoom = nuevo
	# El clamp se aplica DESPUÉS del anclaje al cursor, con el zoom YA nuevo (Punto B del encargo:
	# "el clamp se aplica tras zoom Y tras pan") — nunca se toca la fórmula de anclaje de arriba.
	_camara.position = _clamp_posicion_camara(posicion_anclada, get_viewport_rect().size)


# ── Entorno exterior (design/art/entorno-exterior.md, fase 1) ────────────────────────────────
## El marco NO JUGABLE alrededor del edificio: calle, control de acceso y aparcamiento pintados
## por código, en la MISMA rejilla lógica que el resto (`pos_suelo` es el mismo origen que usa
## `_crear_suelo` justo después). Ver `EntornoExterior` para las tres garantías de "no jugable"
## (sin picking, sin colisión, sin navegación) y el porqué de su capa (ADR-0005).
func _crear_entorno_exterior() -> void:
	_entorno_exterior = EntornoExteriorScript.new()
	_entorno_exterior.name = "EntornoExterior"
	add_child(_entorno_exterior)
	_entorno_exterior.configurar(TAM_CELDA, pos_suelo, COLUMNAS, FILAS, _mundo_profundo)


## La bolsa de ordenación por PROFUNDIDAD (2026-08-03, movida a función propia el 2026-08-07 —
## ver el comentario de `_ready`): paredes + mobiliario + ventanillas + gente + (desde hoy) los
## props CON ALTURA del entorno exterior, todo lo que se apoya en el suelo y puede taparse entre sí.
## Godot ordena esa bolsa por la Y de pantalla de cada pieza (algoritmo del pintor). Ver el
## comentario largo de `_instanciar_mundo` para el resto del reparto de capas (suelo/luces/rótulos
## fuera de esta bolsa a propósito).
func _crear_mundo_profundo() -> void:
	_mundo_profundo = Node2D.new()
	_mundo_profundo.name = "MundoProfundo"
	_mundo_profundo.y_sort_enabled = true
	add_child(_mundo_profundo)
	# La capa ÚNICA de sombras de contacto (2026-08-14): HERMANA de la bolsa, nunca dentro — todo
	# CanvasItem nacido en la carga dentro de la bolsa queda sin renderizar (gotcha cazado con
	# sondas, ver la cabecera de `CapaSombras`). Su z −1 la deja sobre la tinta y bajo todo lo de pie.
	_capa_sombras = CapaSombrasScript.new()
	_capa_sombras.name = "CapaSombras"
	add_child(_capa_sombras)


# ── Suelo (TileMapLayer — NUNCA TileMap, deprecado) ──────────────────────────────────────────
## Crea el suelo: un TileSet mínimo generado por código (tile PLANO) y una rejilla COLUMNAS×FILAS
## pintada con set_cell. Solo estética; sin interacción de ratón (Construcción #7).
##
## ── LA CUADRÍCULA SE FUE AL MODO CONSTRUCCIÓN (2026-08-05 · quick-spec §3c) ─────────────────────
## Hasta hoy cada tile llevaba pintadas dos líneas de `COLOR_LINEA` (su borde de arriba y el de la
## izquierda): esa era LA REJILLA que se veía jugando por toda la comisaría. Orden del usuario tras
## comparar con la demo de Summer: *"en juego normal el suelo va limpio; la rejilla de celdas solo
## se muestra con el modo construcción activo"*. Así que el tile queda liso y la rejilla renace como
## un OVERLAY del modo construcción (`ModoConstruccion.RejillaConstruccion`), que aparece y
## desaparece con él — y que dibuja líneas continuas de rejilla, no bordes de tile, así que su color
## vive allí (`COLOR_REJILLA_CONSTRUCCION`) y no aquí.
func _crear_suelo() -> void:
	var imagen := Image.create(TAM_CELDA, TAM_CELDA, false, Image.FORMAT_RGBA8)
	imagen.fill(COLOR_SUELO)
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
	# 🐛 FIX (2026-08-03, muro divisorio): el SUELO baja a z −3 y la tinta de sala de Construcción a
	# −2 (ver `montar_visual`; los dos bajaron un escalón el 2026-08-05 para dejar el −1 libre a la
	# cuadrícula del modo construcción). Antes los dos empataban a z 0 con las paredes, y el empate lo rompía
	# el orden del árbol: `ParedesSalas` se añade ANTES que `Construccion` (por el fix del sofá), así
	# que CUALQUIER suelo se dibujaba ENCIMA de las paredes de la pasada FONDO. No se notaba porque
	# la cara de una pared trasera sube hacia una zona donde no hay sala... hasta que un DIVISORIO
	# entró en esa pasada: su cara sube sobre el suelo de la sala vecina, y ese suelo se la comía —
	# el tabique entre Descanso y ODAC desaparecía. Regla nueva, sin excepciones: **un suelo nunca se
	# dibuja por encima de una pared**. Los dos siguen ordenados entre sí (suelo −3 < tinta −2).
	suelo.z_index = -3
	# Centrado aproximado en la ventana por defecto (1152×648).
	suelo.transform = Proyeccion.transformada(pos_suelo)
	for x in COLUMNAS:
		for y in FILAS:
			suelo.set_cell(Vector2i(x, y), id_fuente, Vector2i.ZERO)
	add_child(suelo)


# ── HUD real de UX (reconstrucción total, 2026-08-08 — `design/ux/hud-design.md`) ────────────
## Instancia `HudComisario` (`src/ui/hud_comisario.gd`) entero: TODO el layout/contenido/estados
## del HUD vive en esa clase (ADR-0001: la UI se construye a sí misma, `Main` solo la alimenta con
## los sistemas Core de solo lectura y reconecta sus 5 señales de acción a los callbacks que ya
## existían -- `_abrir_personal`/`_abrir_horario`/`_guardar_partida`/`_cargar_partida`/
## `_alternar_modo_paredes`, ninguno nuevo).
func _crear_hud_comisario() -> void:
	var hud: HudComisario = HudComisarioScript.new()
	hud.name = "HudComisario"
	add_child(hud)
	_hud = hud
	hud.configurar(_economia, _demanda, _personal, _flujo, _paciencia, _documentacion, _paredes_salas)
	# La píldora "Construir (B)" (opción A, 2026-08-09) hace lo mismo que la tecla B.
	hud.construccion_solicitada.connect(func() -> void: _modo_construccion._alternar_modo())
	hud.personal_solicitado.connect(_abrir_personal)
	hud.horario_solicitado.connect(_abrir_horario)
	hud.guardar_solicitado.connect(_guardar_partida)
	hud.cargar_solicitado.connect(_cargar_partida)
	hud.paredes_solicitado.connect(_alternar_modo_paredes)


## Abre el panel de personal (lo mismo que la tecla P, pero descubrible con el ratón).
func _abrir_personal() -> void:
	_panel_personal.visible = true
	_panel_personal._reconstruir()


## Abre el panel del horario de Documentación (story doc-005). Se puede usar EN PAUSA (DO11).
func _abrir_horario() -> void:
	_panel_horario.visible = true
	_panel_horario._refrescar()


## Cicla el modo global de altura de las paredes (botón del HUD o tecla Home) — ver la cabecera de
## `ParedesSalas.modo_altura`. Solo ORDENA por su API pública (ADR-0001): quien decide alturas y
## repinta es `ParedesSalas`, nunca esta función.
func _alternar_modo_paredes() -> void:
	var indice: int = ORDEN_MODOS_PARED.find(_paredes_salas.modo_altura)
	var siguiente: StringName = ORDEN_MODOS_PARED[(indice + 1) % ORDEN_MODOS_PARED.size()]
	_paredes_salas.fijar_modo_altura(siguiente)
	# El texto de la píldora "Paredes: <modo> (Home)" ya NO se empuja desde aquí -- `HudComisario.
	# refrescar()` lee `_paredes_salas.modo_altura` directo cada frame (poll, spec §5).
	_avisar_accion("Paredes: %s" % NOMBRES_MODO_PARED[siguiente], COLOR_TENUE_HUD)


## El modo diseñador colocó/borró/cargó una farola: `LucesObjetos` recalcula su lista entera (barato
## — un puñado de farolas, nunca por frame, solo en este evento). Mismo criterio que
## `Main._crear_entorno_exterior` al arrancar, solo que ahora la fuente es el modo, no el procedural.
func _al_cambiar_layout_disenador() -> void:
	if _luces_objetos != null and _modo_disenador_entorno != null:
		_luces_objetos.usar_farolas(_modo_disenador_entorno.puntos_farolas())


## Fix del solape (petición del usuario 2026-08-07: "me cuesta seleccionar, se solapan con los datos
## del juego"): `ModoDisenadorEntorno` y la franja de acciones del HUD son paneles `PRESET_BOTTOM_
## WIDE` que se dibujaban uno encima del otro. Solo VISIBILIDAD, y SOLO de la franja de acciones —
## la franja superior del HUD (reloj/saldo/etc.) SIGUE visible (spec §1, "información ARRIBA,
## herramientas ABAJO" -- siempre arriba, pase lo que pase abajo). El HUD sigue vivo debajo
## (`_process` lo sigue refrescando), así que al salir del diseñador reaparece con los datos al día.
func _al_activar_disenador(activo: bool) -> void:
	# La barra de construcción no debe quedarse abierta debajo del diseñador (cazado en la
	# auditoría de capturas 2026-08-09: el HUD se ocultaba pero la barra no): si estaba activa,
	# se cierra por su propio camino (descarta trazo, apaga rejilla y avisa por su señal). ANTES
	# de ocultar las acciones: cerrarla emite `activado_cambiado(false)` → `_al_activar_
	# construccion(false)` → `ocultar_acciones(false)`, y en el orden inverso ese rebote dejaría
	# la fila de acciones visible debajo del diseñador.
	if activo and _modo_construccion != null and _modo_construccion._activo:
		_modo_construccion._alternar_modo()
	if _hud != null:
		_hud.ocultar_acciones(activo)
	# Lienzo limpio mientras se diseña (2026-08-08, encargo "poder diseñar sin la morralla
	# procedural delante"): oculta el scatter procedural (casas/coches/árboles/vallas del barrio) al
	# entrar, lo devuelve al salir -- ver `EntornoExterior.fijar_scatter_visible`.
	if _entorno_exterior != null:
		_entorno_exterior.fijar_scatter_visible(not activo)


## Gemelo de `_al_activar_disenador` para `ModoConstruccion` (fix del solape 2026-08-08: la barra de
## construcción, anclada abajo igual que la franja de acciones, la tapaba) — sin combinar con el
## diseñador de entorno a propósito: son modos que hoy no se solapan en la práctica (uno es
## --disenador, el otro el juego normal), así que cada señal pisa la visibilidad de forma
## independiente, como ya hacía `_al_activar_disenador`. Solo la franja de acciones se oculta -- la
## superior del HUD nunca se toca (spec §1, regla dura).
func _al_activar_construccion(activo: bool) -> void:
	if _hud != null:
		_hud.ocultar_acciones(activo)


## Guarda la partida. El resultado se dice EN PANTALLA: un guardado que falla en silencio es peor que
## no tener guardado (el jugador cree que su partida está a salvo y no lo está).
func _guardar_partida() -> void:
	var ok: bool = SaveManager.guardar_partida()
	_avisar_accion(
		"Guardado a las %s" % Tiempo.hhmm(Tiempo.minutos_juego) if ok else "⚠ No se pudo guardar",
		COLOR_TENUE_HUD if ok else COLOR_ROJOS
	)


## Carga la última partida guardada. Tras cargar, el juego queda EN PAUSA (contrato del ADR-0002:
## "cargar sitúa" — nada se mueve hasta que el jugador reanuda).
func _cargar_partida() -> void:
	var ok: bool = SaveManager.cargar_partida()
	_avisar_accion(
		"Partida cargada (en pausa)" if ok else "⚠ No hay partida guardada",
		COLOR_TENUE_HUD if ok else COLOR_ROJOS
	)
	if ok:
		# Vuelve a marcar la fachada como FIJA: en el save sus aristas son tabiques corrientes, así
		# que sin esto una partida cargada te dejaría derribar la fachada del edificio. Es
		# idempotente (no duplica muros ni cobra nada).
		_construccion.levantar_fachada()
		# LAS IMPRESORAS QUE FALTEN (GDD impresora-documentos-tramite.md): *"al cargar un save sin ellas
		# se aplica el mismo patron idempotente que la fachada -- se recolocan si faltan"*. Una partida
		# guardada ANTES de esta mecanica no tiene impresoras, y sin ellas los tramites con papel se
		# cerrarian sin viaje. De oficio (coste 0): a un save viejo no se le pasa factura retroactiva.
		_impresora.completar_todas_las_salas(true)
		_al_cambiar_layout()   # el layout cargado necesita re-bake de navegación y re-sincronizar


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
				# Y la APERTURA, para que su titular salga de casa con tiempo de cruzar la comisaria y
				# estar sentado antes de abrir (peticion del usuario 2026-07-29).
				_personal.fijar_apertura_de_puesto(puesto_id, apertura)
	if _demanda != null:
		_demanda.fijar_ventana_doc(apertura, ultima_admision)


## El precio de la hora extra, de quien lo decide a quienes lo notan: Economía lo cobra en el cierre
## del día y Personal lo traduce a cuánto cansa esa hora (pagar mejor cansa menos).
func _al_cambiar_peonada(eur_hora: float, generosidad: float) -> void:
	if _economia != null:
		_economia.fijar_peonada_eur_hora(eur_hora)
	if _personal != null:
		_personal.fijar_generosidad_peonada(generosidad)


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
