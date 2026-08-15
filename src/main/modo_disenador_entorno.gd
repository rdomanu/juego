class_name ModoDisenadorEntorno extends Node2D
## ModoDisenadorEntorno — herramienta DEV para que el usuario componga a mano el entorno urbano
## alrededor de la comisaría (paleta + colocar/rotar/pintar), "como si fuera un builder". NO es una
## mecánica de juego: solo existe si el proceso arranca con `--disenador`
## (`OS.get_cmdline_user_args`, ver `Main._ready`); una vez instanciado con ese flag, F12
## activa/desactiva el modo (`alternar()`) — SIN el flag, esta clase nunca se instancia y F12 no
## hace nada (invisibilidad real, no solo "oculta").
##
## Guarda en `user://entorno_disenado.json` (botón GUARDAR / F8) con el MISMO esquema que
## `EntornoExterior.leer_layout()` espera en `res://datos/entorno_layout.json` — cuando el usuario
## diga "ya tenemos el entorno", copiar ese archivo de `user://` a `res://datos/` congela el
## resultado como el entorno FIJO de la partida (sustituye el scatter procedural del barrio/recinto,
## ver la cabecera "ENTORNO FIJO" de `entorno_exterior.gd`). Ese paso de congelado es MANUAL a
## propósito — nadie quiere que una prueba se convierta en el entorno oficial sin que alguien lo
## decida. Al ENTRAR en el modo se CARGA sola cualquier partida a medias (`user://...json`).
##
## Encargo: sesión 2026-08-07 ("¿podría hacerlo yo con esos objetos, como si fuera un builder... y
## cuando lo tenga te digo 'ya tenemos el entorno' y lo guardas fijo para la primera comisaría?").
##
## Reglas (control-manifest, Presentation): pausa el juego mientras está activo (`Tiempo.PAUSA`,
## mismo patrón "editor, no gameplay" que `--pausa`/`PanelAdmin`) y SOLO coloca cosas FUERA del rect
## jugable 24×13 — el interior es del juego, esta herramienta no lo toca.

signal layout_cambiado()
## Se emite cada vez que `alternar()` cambia el modo on/off (2026-08-07 — fix del solape con el HUD
## del juego). `Main` escucha esta señal para OCULTAR su propia barra inferior mientras el
## diseñador está activo: las dos son paneles anclados `PRESET_BOTTOM_WIDE` de altura dinámica —
## sin esto, la paleta de esta herramienta se dibuja ENCIMA de reloj/saldo/velocidad/personal del
## HUD de verdad y son indistinguibles (bug reportado: "me cuesta seleccionar, se solapan con los
## datos del juego"). Puramente de presentación — este nodo no conoce ni le importa qué hace `Main`
## con la señal (ADR-0001: la UI ordena, no asume quién escucha).
signal activado_cambiado(activo: bool)
## El usuario alterna la visibilidad del entorno base procedural desde la paleta (2026-08-09).
## `Main` la cablea a `EntornoExterior.fijar_base_visible` — esta clase no toca nodos ajenos.
signal base_visible_cambiada(visible: bool)
## El usuario pide convertir el entorno procedural en piezas SUYAS (botón "⬇ Importar entorno").
## `Main` responde pasando `EntornoExterior.inventario_base()` a `importar_base` — esta clase no
## conoce a `EntornoExterior` (ADR-0001: comunicación hacia arriba por señales).
signal importar_base_solicitado

## ── SUBMENÚS POR CATEGORÍA (2026-08-08, encargo "en el city kit hay más casas... se puede poner
## un submenú: casas, carreteras, árboles y jardín, objetos") ────────────────────────────────────
## Antes eran ~22 botones en una sola fila (Progressive disclosure, Hick's Law, mismo principio que
## `ModoConstruccion::CATEGORIAS` — reutiliza el MISMO `VARIANTE_PESTANA` del kit): con las 21 casas
## del kit completo + las 5 carreteras el catálogo pasa a 39 piezas, imposible de escanear en una
## fila. `CATEGORIAS` fija el orden/rótulo de cada pestaña; `PIEZAS_POR_CATEGORIA` reparte los ids
## de `CATALOGO_PIEZAS` entre ellas (las brochas de `SUPERFICIES` + la goma se cuelgan aparte, de la
## pestaña "Superficies" — ver `_crear_ui`).
const CATEGORIAS: Array[Dictionary] = [
	{"id": &"casas", "nombre": "🏠 Casas"},
	{"id": &"carreteras", "nombre": "🛣 Carreteras"},
	{"id": &"jardin", "nombre": "🌳 Árboles y jardín"},
	{"id": &"objetos", "nombre": "🚧 Objetos"},
	{"id": &"construccion", "nombre": "🧱 Construcción"},
	{"id": &"superficies", "nombre": "🖌 Superficies"},
]

## Catálogo de piezas colocables — mismos ids que los PNG de `assets/sprites/entorno/`
## (`tools/render_entorno_urbano.gd`), las 4 rotaciones ya renderizadas para cada una. Las 21 casas
## y las 5 carreteras vienen de `EntornoExterior.CASAS_TODAS`/`CARRETERAS_TODAS` (fuente ÚNICA de
## verdad de esos dos catálogos — nunca se duplica la lista de ids a mano en dos ficheros).
const EntornoExteriorScript := preload("res://src/main/entorno_exterior.gd")
const JARDIN_IDS: Array[StringName] = [
	&"arbol_urbano", &"tree_grande", &"tree_pequeno", &"seto", &"planter",
]
const OBJETOS_IDS: Array[StringName] = [
	&"farola", &"valla_baja", &"valla_estandar", &"camino_recinto", &"entrada_casa",
	&"coche_policia", &"coche_sedan", &"coche_suv", &"barrera_seguridad",
	# Piezas de la calle de acceso vieja: están en la paleta para que "Importar entorno" pueda
	# convertirlas en piezas editables como todo lo demás (2026-08-09).
	&"calzada_recta", &"acera_recta",
]
static var CATALOGO_PIEZAS: Array[StringName] = (
	EntornoExteriorScript.CASAS_TODAS + EntornoExteriorScript.CARRETERAS_TODAS
	+ JARDIN_IDS + OBJETOS_IDS + EntornoExteriorScript.CONSTRUCCION_TODAS
)
## id de categoría → ids de `CATALOGO_PIEZAS` que le corresponden (ver la cabecera de `CATEGORIAS`).
static var PIEZAS_POR_CATEGORIA: Dictionary[StringName, Array] = {
	&"casas": EntornoExteriorScript.CASAS_TODAS, &"carreteras": EntornoExteriorScript.CARRETERAS_TODAS,
	&"jardin": JARDIN_IDS, &"objetos": OBJETOS_IDS,
	&"construccion": EntornoExteriorScript.CONSTRUCCION_TODAS,
}
## Nombre de cada casa: "🏠 Casa <letra>" en MAYÚSCULA a partir del id (`casa_a`→A,
## `casa_kit_b`→B…) — evita 21 entradas sueltas a mano; el resto del catálogo sí las lleva literales
## (nombres más descriptivos que una sola letra).
static func _nombre_casa(id: StringName) -> String:
	var letra: String = String(id).right(1).to_upper()
	return "🏠 Casa %s" % letra
static var NOMBRES_PIEZA: Dictionary[StringName, String] = _construir_nombres_pieza()
static func _construir_nombres_pieza() -> Dictionary[StringName, String]:
	var nombres: Dictionary[StringName, String] = {
		&"valla_baja": "▤ Valla baja", &"valla_estandar": "▥ Valla estándar",
		&"camino_recinto": "▬ Camino", &"entrada_casa": "▭ Entrada de casa",
		&"arbol_urbano": "🌳 Árbol urbano", &"tree_grande": "🌲 Árbol grande",
		&"tree_pequeno": "🌱 Árbol pequeño", &"seto": "🌿 Seto", &"farola": "💡 Farola",
		&"planter": "🪴 Jardinera",
		&"coche_policia": "🚓 Coche patrulla", &"coche_sedan": "🚗 Coche sedán",
		&"coche_suv": "🚙 Coche SUV",
		# Barrera del control de entrada (diseño 1 del usuario, 2026-08-09): motor del modelo
		# generado + pluma 3D de franjas continuas; cruza una calle de 6 celdas de arcén a arcén.
		&"barrera_seguridad": "🚧 Barrera de entrada",
		&"calzada_recta": "▤ Calzada (vieja)", &"acera_recta": "▨ Acera (vieja)",
		&"carretera_recta": "🛣 Recta", &"carretera_curva": "🛣 Curva",
		&"carretera_cruce": "🛣 Cruce", &"carretera_interseccion_t": "🛣 Cruce en T",
		&"carretera_paso_cebra": "🛣 Paso de cebra",
		&"bk_muro": "🧱 Muro", &"bk_muro_medio": "🧱 Muro medio",
		&"bk_muro_bajo": "🧱 Muro bajo",
		&"bk_muro_esquina": "🧱 Esquina", &"bk_muro_curvo": "🧱 Esquina curva",
		&"bk_muro_diagonal": "🧱 Esquina diagonal", &"bk_muro_columna": "🧱 Esquina columna",
		&"bk_puerta": "🚪 Puerta", &"bk_puerta_arco": "🚪 Puerta arco",
		&"bk_puerta_ancha": "🚪 Puerta ancha", &"bk_puerta_ancha_arco": "🚪 Puerta ancha arco",
		&"bk_ventana": "🪟 Ventana", &"bk_ventana_arco": "🪟 Ventana arco",
		&"bk_ventana_ancha": "🪟 Ventana ancha", &"bk_ventana_ancha_arco": "🪟 Ventana ancha arco",
		&"bk_hoja_puerta": "🚪 Hoja de puerta", &"bk_hoja_puerta_arco": "🚪 Hoja arco",
		&"bk_columna": "🏛 Columna", &"bk_escaleras": "🪜 Escaleras",
		&"bk_suelo": "▦ Suelo", &"bk_borde": "▭ Borde", &"bk_tuberia": "🔧 Tubería",
	}
	for id: StringName in EntornoExteriorScript.CASAS_TODAS:
		nombres[id] = _nombre_casa(id)
	return nombres
## Piezas CASI PLANAS (van al overlay del suelo, sin y-sort — mismo criterio que `EntornoExterior`):
## camino/entrada de siempre + las 5 carreteras (línea central pintada en la textura, no en el
## volumen — ver la cabecera de `tools/render_entorno_urbano.gd`).
## Piezas de PARED del Building Kit: no se centran en su celda, se ARRIMAN a la arista (encargo del
## usuario 2026-08-09: *"la pared se sitúa en el medio de la celda en lugar de en un extremo, así es
## imposible hacer esquinas"*). Una pared vive en el LADO de la celda — igual que los muros de la
## comisaría, que `Construccion` guarda por arista ("h:x:y"/"v:x:y"), no por celda.
## Las piezas del Building Kit se renderizan al DOBLE de resolución (ver `SUPERMUESTREO_KIT` en
## `tools/render_entorno_urbano.gd`) y se dibujan a la mitad: mismo tamaño en pantalla, el doble de
## píxeles, así aguantan el zoom del juego sin cuadricularse (encargo 2026-08-09: "tiene que salir
## nítido"). El anclaje no se toca: Godot aplica el `offset` del sprite ANTES de la escala, así que
## el ancla medida del PNG se escala sola con la pieza.
const ESCALA_KIT: float = 0.5

const PIEZAS_PARED: Array[StringName] = [
	&"bk_muro", &"bk_muro_medio", &"bk_muro_bajo", &"bk_borde",
	&"bk_muro_esquina", &"bk_muro_curvo", &"bk_muro_diagonal", &"bk_muro_columna",
	&"bk_puerta", &"bk_puerta_arco", &"bk_puerta_ancha", &"bk_puerta_ancha_arco",
	&"bk_ventana", &"bk_ventana_arco", &"bk_ventana_ancha", &"bk_ventana_ancha_arco",
	&"bk_hoja_puerta", &"bk_hoja_puerta_arco",
]

const PIEZAS_PLANAS: Array[StringName] = [
	&"camino_recinto", &"entrada_casa", &"carretera_recta", &"carretera_curva",
	&"carretera_cruce", &"carretera_interseccion_t", &"carretera_paso_cebra",
	&"bk_suelo", &"calzada_recta", &"acera_recta",
]

## Las 3 "brochas de superficie" + la goma -- pintan/borran celdas con los MISMOS colores planos que
## ya usa `EntornoExterior` (nunca un color inventado aparte).
const SUPERFICIES: Array[StringName] = [&"cesped", &"asfalto", &"acera"]
const NOMBRES_SUPERFICIE: Dictionary[StringName, String] = {
	&"cesped": "🟩 Césped", &"asfalto": "⬛ Asfalto", &"acera": "⬜ Acera",
}
const HERRAMIENTA_BORRAR := &"borrar"

const ORIENTACIONES_CICLO: Array[int] = [0, 90, 180, 270]

const RUTA_GUARDADO := "user://entorno_disenado.json"
## Ruta EFECTIVA de guardado/carga — inyectable ANTES de `add_child` para que los tests apunten a
## su scratch y no lean/pisen el `user://` real (2026-08-08: la partida guardada del USUARIO con F8
## se colaba en la suite vía la autocarga de `_ready` — bug de aislamiento latente hasta que hubo
## un archivo de verdad; regla del proyecto: los tests no dependen de estado externo).
var ruta_guardado: String = RUTA_GUARDADO
const VERSION_LAYOUT := 1

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
## El kit de UI (2026-08-07, remate del reskin — piloto Summer): mismo punto único de acceso que usa
## `ModoConstruccion` para tema/iconos/variantes. Ver la cabecera de `KitUIComisario`.
const KitUIComisarioScript := preload("res://src/ui/kit_ui_comisario.gd")

const ALFA_FANTASMA: float = 0.55
const COLOR_FANTASMA_PIEZA := Color(0.6, 0.85, 1.0, ALFA_FANTASMA)
const COLOR_FANTASMA_INVALIDO := Color(1.0, 0.35, 0.35, 0.5)
## Alto de la barra inferior (2026-08-07, remate del reskin): antes 190px alcanzaba con botones de
## una línea de texto; con las tarjetas AGRANDADAS a ~48px de alto (petición del usuario: "me cuesta
## seleccionar las cosas") la paleta necesita más sitio. `grow_vertical = GROW_DIRECTION_BEGIN` (en
## `_crear_ui`) hace que ese sobrante crezca HACIA ARRIBA, nunca fuera de la pantalla por abajo —
## mismo gotcha que ya resolvió `ModoConstruccion._crear_ui` (ver su comentario del panel).
## Sube 260->340 (2026-08-08): la fila de PESTAÑAS nueva (ver `CATEGORIAS`) se suma por ENCIMA de la
## (2026-08-09: `ALTO_BARRA` eliminada — la paleta es ahora un `PanelContainer` anclado abajo cuya
## altura la decide su CONTENIDO, a cualquier resolución; ver el comentario del rehecho en
## `_crear_ui`.)

var _tam_celda: int = 40
var _origen: Vector2 = Vector2.ZERO
var _mundo_profundo: Node2D = null

var _activo: bool = false
## Visibilidad del ENTORNO BASE procedural (vallas/farolas/coches/casas/calle de acceso que pinta
## `EntornoExterior` por código). El usuario lo apaga desde la paleta para diseñar desde cero
## (feedback 2026-08-09: "no puedo eliminar los objetos que ya vienen por defecto"); se PERSISTE
## en el JSON del layout para que el congelado lo respete. Las manchas de asfalto del suelo se
## repintan con la brocha de césped (superficies), que ya escribe sobre el mismo tilemap.
var _base_visible: bool = true
## `true` en cuanto esta instancia ha hecho SU carga automática (la de `_ready()`, ver más abajo) --
## a partir de ahí `alternar()` NUNCA vuelve a recargar por su cuenta, ni siquiera si `_piezas` y
## `_superficies` quedan vacíos por un borrado del usuario (ver el fix de `alternar()` con fecha de
## hoy: comprobar "está vacío" en vez de "ya se autocargó" confundía "sin nada guardado todavía" con
## "el usuario lo vació a propósito" -- la última pieza borrada resucitaba del disco al reactivar).
var _autocargado: bool = false
## Herramienta en mano: un id de `CATALOGO_PIEZAS`, un id de `SUPERFICIES`, `HERRAMIENTA_BORRAR`, o "".
var _herramienta: StringName = &""
var _orientacion: int = 0
var _pintando: bool = false
var _celda_pintada_anterior: Vector2i = Vector2i(-999, -999)
var _celda_preview_anterior: Vector2i = Vector2i(-999, -999)
var _orientacion_anterior: int = -1

## ── PINCEL SIMS DE PIEZAS/GOMA (2026-08-15 · mismo motor que el pincel de muro de Construcción)
## PRESS ancla (no coloca), DRAG traza en línea con el eje clavado a la PRIMERA dirección, RELEASE
## compromete todo el trazo de una vez. Solo las PIEZAS (`CATALOGO_PIEZAS`) y la goma
## (`HERRAMIENTA_BORRAR`) pasan por aquí: las brochas de `SUPERFICIES` siguen pintando celda a celda
## mientras arrastras (`_pintando`, sin cambios) — pintar un área no tiene el concepto de "línea
## recta" que clavar, así que no le hace falta este gesto.
## ¿Hay un trazo de pieza/goma en curso? Independiente de `_pintando` (las superficies).
var _trazando_pieza: bool = false
## La celda donde se pulsó — el ancla del trazo. No cambia durante el arrastre.
var _ancla_trazo_pieza: Vector2i = Vector2i.ZERO
## Eje al que se ha CLAVADO el trazo ("x"/"y"; "" = aún no se ha apartado del ancla). Lo fija la
## PRIMERA celda distinta del ancla (la dirección PREDOMINANTE del desplazamiento — con la
## proyección isométrica, un arrastre "horizontal" en pantalla mueve fila Y columna a la vez, ver la
## cabecera de `Proyeccion`) y no cambia hasta soltar.
var _eje_trazo_pieza: String = ""
## La coordenada del trazo en el EJE LIBRE (columna si el eje es "x", fila si es "y"). Con esto + el
## ancla se reconstruye la línea entera (mismo patrón que `ModoConstruccion._hasta_arrastre_muro`).
var _hasta_trazo_pieza: int = 0

## celda -> {"id": StringName, "rotacion": int}
var _piezas: Dictionary[Vector2i, Dictionary] = {}
## celda -> tipo (StringName de `SUPERFICIES`)
var _superficies: Dictionary[Vector2i, StringName] = {}
## celda -> nodo visual ya colocado (para poder sustituir/borrar sin duplicar).
var _nodos_pieza: Dictionary[Vector2i, Node2D] = {}

var _capa_piezas: Node2D
var _capa_superficies: TileMapLayer
var _fuentes_superficie: Dictionary[StringName, int] = {}

var _capa_ui: CanvasLayer
var _btn_base: Button = null
var _lbl_estado: Label
var _botones: Dictionary[StringName, Button] = {}
## categoría (StringName de `CATEGORIAS`) → Array[Button] de sus tarjetas, en el orden en que se
## registraron -- fuente de verdad de "qué botones tiene cada pestaña" (mismo patrón que
## `ModoConstruccion._tarjetas_por_categoria`: los hijos son FIJOS, `_mostrar_categoria` solo alterna
## `visible`, nunca descuelga nada -- eso dio 224 huérfanos la vez que se intentó distinto).
var _tarjetas_por_categoria: Dictionary[StringName, Array] = {}
## categoría → su botón de pestaña, para poder marcar cuál está activa.
var _pestanas_categoria: Dictionary[StringName, Button] = {}
## La categoría que se ve ahora mismo en la paleta. Arranca en "casas" (la más grande, la que motivó
## el submenú).
var _categoria_activa: StringName = &"casas"

var _capa_preview: CanvasLayer
var _preview_sprite: Sprite2D
var _preview_caja: Polygon2D
var _preview_triangulo: Polygon2D
## El fantasma del TRAZO ENTERO del pincel Sims (2026-08-15): un `Sprite2D` fantasma por celda del
## trazo, colgados de este contenedor — se RECONSTRUYE por completo cada vez que el trazo cambia
## (nueva celda, cambio de eje, R) porque el número de piezas del fantasma varía con la longitud del
## trazo; no hay un pool fijo que llevar la cuenta de altas/bajas (mismo criterio que
## `ModoConstruccion.PreviewMayusPintura`: recalcular la lista entera es más simple).
var _capa_fantasma_trazo: Node2D


func configurar(tam_celda: int, origen: Vector2, mundo_profundo: Node2D) -> void:
	_tam_celda = tam_celda
	_origen = origen
	_mundo_profundo = mundo_profundo


func _ready() -> void:
	_crear_capas()
	_crear_ui()
	_crear_preview()
	cargar_desde_disco(ruta_guardado)
	_autocargado = true
	_actualizar_visibilidad()


func _crear_capas() -> void:
	# Props CON altura (casas/coches/árboles/farolas/vallas/setos/jardineras): cuelgan de
	# `MundoProfundo` para competir por profundidad con las paredes del edificio, EXACTAMENTE el
	# mismo arreglo que `EntornoExterior._capa_decor` (ver su cabecera) — dos fuentes distintas del
	# MISMO tipo de contenido comparten la MISMA regla de capas (ADR-0005).
	_capa_piezas = Node2D.new()
	_capa_piezas.name = "PiezasDisenador"
	_capa_piezas.y_sort_enabled = true
	if _mundo_profundo != null:
		_mundo_profundo.add_child(_capa_piezas)
	else:
		add_child(_capa_piezas)   # sondas/tests sin Main completo
	# Superficies (césped/asfalto/acera): fondo puro, mismo z_index que `EntornoExterior` — un
	# TileMapLayer propio con el mismo patrón de fuentes de color plano.
	_capa_superficies = TileMapLayer.new()
	_capa_superficies.name = "SuperficiesDisenador"
	_capa_superficies.tile_set = TileSet.new()
	_capa_superficies.tile_set.tile_size = Vector2i(_tam_celda, _tam_celda)
	_capa_superficies.transform = Proyeccion.transformada(_origen)
	_capa_superficies.z_index = EntornoExteriorScript.Z_CAPA
	add_child(_capa_superficies)


# ── Picking (mismo patrón de todo el proyecto: punto DEL EVENTO, nunca el puntero en vivo) ──────
func _celda_de_evento(pos_pantalla: Vector2) -> Vector2i:
	var punto_mundo: Vector2 = get_canvas_transform().affine_inverse() * pos_pantalla
	return Proyeccion.celda_de_iso(punto_mundo - _origen)


## Fuera del rect jugable 24×13 (el interior es del juego, esta herramienta no lo toca).
static func _celda_valida(celda: Vector2i) -> bool:
	return not Rect2i(
		0, 0, EntornoExteriorScript.COLUMNAS_JUGABLE, EntornoExteriorScript.FILAS_JUGABLE
	).has_point(celda)


# ── Entrada ───────────────────────────────────────────────────────────────────────────────────
func _unhandled_input(evento: InputEvent) -> void:
	if not _activo:
		return
	if evento is InputEventKey and evento.pressed and not (evento as InputEventKey).echo:
		if (evento as InputEventKey).keycode == KEY_R:
			_orientacion = ORIENTACIONES_CICLO[
				(ORIENTACIONES_CICLO.find(_orientacion) + 1) % ORIENTACIONES_CICLO.size()
			]
			# R SIGUE ROTANDO DURANTE EL TRAZO (2026-08-15): re-fantasma con la nueva orientación —
			# lo que se va a colocar al soltar tiene que verse YA girado, no solo lo que se coloque
			# DESPUÉS de rotar.
			if _trazando_pieza:
				_refrescar_fantasma_trazo_pieza()
			get_viewport().set_input_as_handled()
			return
		if (evento as InputEventKey).keycode == KEY_F8:
			guardar_en_disco()
			get_viewport().set_input_as_handled()
			return
	if evento is InputEventMouseMotion and _pintando:
		_pintar_o_borrar_en(_celda_de_evento((evento as InputEventMouseMotion).position))
		get_viewport().set_input_as_handled()
		return
	if evento is InputEventMouseMotion and _trazando_pieza:
		_extender_trazo_pieza(_celda_de_evento((evento as InputEventMouseMotion).position))
		get_viewport().set_input_as_handled()
		return
	if not (evento is InputEventMouseButton):
		return
	var boton := evento as InputEventMouseButton
	if boton.button_index != MOUSE_BUTTON_LEFT:
		return
	var celda: Vector2i = _celda_de_evento(boton.position)
	if boton.pressed:
		_al_pulsar(celda)
	else:
		if _trazando_pieza:
			_aplicar_trazo_pieza()
			_trazando_pieza = false
			_eje_trazo_pieza = ""
			_limpiar_fantasma_trazo_pieza()
		_pintando = false
		_celda_pintada_anterior = Vector2i(-999, -999)


## TODA herramienta es arrastrable (2026-08-08, encargo "no puedo seleccionar una celda, mantener
## pulsado y arrastrar para que se haga una línea entera").
##
## 🔄 REESCRITO (2026-08-15, gesto Sims — mismo motor que el pincel de muro de `ModoConstruccion`):
## las brochas de SUPERFICIE (`SUPERFICIES`) siguen pintando celda a celda mientras arrastras
## (`_pintando`, sin cambios — pintar un área no tiene "línea recta" que clavar). Las PIEZAS
## (`CATALOGO_PIEZAS`) y la GOMA (`HERRAMIENTA_BORRAR`) pasan al gesto de trazo: el press solo
## ANCLA (`_trazando_pieza`), NO coloca/borra todavía — eso pasa al SOLTAR (`_aplicar_trazo_pieza`,
## en `_unhandled_input`), con el trazo entero ya visto en el fantasma. Un clic SIN arrastre sigue
## colocando una sola pieza (`_aplicar_trazo_pieza` delega en `_colocar_pieza_en`/`_borrar_en` si el
## eje nunca llegó a clavarse) — el comportamiento de siempre.
func _al_pulsar(celda: Vector2i) -> void:
	if _herramienta == &"":
		return
	if SUPERFICIES.has(_herramienta):
		_pintando = true
		_celda_pintada_anterior = Vector2i(-999, -999)
		_pintar_o_borrar_en(celda)
		return
	_trazando_pieza = true
	_ancla_trazo_pieza = celda
	_eje_trazo_pieza = ""
	_hasta_trazo_pieza = 0
	_refrescar_fantasma_trazo_pieza()


func _pintar_o_borrar_en(celda: Vector2i) -> void:
	if celda == _celda_pintada_anterior:
		return
	_celda_pintada_anterior = celda
	if not _celda_valida(celda):
		_avisar("Eso es del edificio -- fuera de mi alcance")
		return
	if _herramienta == HERRAMIENTA_BORRAR:
		_borrar_en(celda)
	elif SUPERFICIES.has(_herramienta):
		_pintar_superficie_en(celda, _herramienta)
	elif CATALOGO_PIEZAS.has(_herramienta):
		# La pieza en mano, con la orientación ACTUAL, en cada celda nueva que pise el cursor --
		# `_colocar_pieza_en` hace su propia comprobación de validez (redundante aquí, pero se
		# mantiene: sigue siendo el punto de entrada que usan los tests y `_al_pulsar` de un solo
		# clic, sin arrastre).
		_colocar_pieza_en(celda)


# ── Pincel Sims de piezas/goma (2026-08-15) ──────────────────────────────────────────────────────

## Extiende el trazo hasta `celda` -- clava el EJE a la PRIMERA dirección que se aparte del ancla
## (mismo patrón que `ModoConstruccion._pintar_arista_muro`, aquí sobre CELDAS en vez de aristas):
## una vez clavado, la componente PERPENDICULAR se ignora -- el trazo sale SIEMPRE recto, aunque el
## cursor se desvíe (jitter del ratón, o el propio salto diagonal de la proyección isométrica: un
## arrastre horizontal en PANTALLA mueve fila Y columna a la vez en el plano lógico).
func _extender_trazo_pieza(celda: Vector2i) -> void:
	if not _trazando_pieza:
		return
	if celda == _ancla_trazo_pieza and _eje_trazo_pieza == "":
		return   # sigue en el ancla: nada que clavar todavía
	if _eje_trazo_pieza == "":
		var delta: Vector2i = celda - _ancla_trazo_pieza
		# Se clava al eje de MAYOR desplazamiento (la dirección predominante) -- "el primer eje que
		# cambia" no basta, porque con la proyección isométrica los dos casi siempre cambian juntos.
		_eje_trazo_pieza = "x" if absi(delta.x) >= absi(delta.y) else "y"
	_hasta_trazo_pieza = celda.x if _eje_trazo_pieza == "x" else celda.y
	_refrescar_fantasma_trazo_pieza()


## Las celdas del trazo actual, del ancla al final, en orden -- vacío si no hay trazo vivo; una sola
## celda (el ancla) si el eje nunca llegó a clavarse (el cursor no se ha movido de celda todavía).
## Es lo que se previsualiza (fantasma) y lo que se aplica al soltar (mismo patrón que
## `ModoConstruccion._aristas_de_la_linea`).
func _celdas_del_trazo_pieza() -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	if not _trazando_pieza:
		return celdas
	if _eje_trazo_pieza == "":
		celdas.append(_ancla_trazo_pieza)
		return celdas
	var fija: int = _ancla_trazo_pieza.y if _eje_trazo_pieza == "x" else _ancla_trazo_pieza.x
	var desde: int = _ancla_trazo_pieza.x if _eje_trazo_pieza == "x" else _ancla_trazo_pieza.y
	var ini: int = mini(desde, _hasta_trazo_pieza)
	var fin: int = maxi(desde, _hasta_trazo_pieza)
	for v: int in range(ini, fin + 1):
		celdas.append(Vector2i(v, fija) if _eje_trazo_pieza == "x" else Vector2i(fija, v))
	return celdas


## TIRA EL TRAZO A MEDIAS, sin colocar/borrar nada (red de seguridad, mismo patrón que
## `ModoConstruccion._descartar_trazo_muro`): si el botón ya no está físicamente pulsado y aquí
## seguimos creyendo que hay un trazo vivo, el evento de soltar se lo llevó otro (la paleta, un
## diálogo) -- se TIRA, no se aplica. Ningún clic puede quedarse guardado esperando a materializarse
## más tarde.
func _descartar_trazo_pieza() -> void:
	_trazando_pieza = false
	_eje_trazo_pieza = ""
	_limpiar_fantasma_trazo_pieza()


## Aplica de una vez todo el trazo. Se llama AL SOLTAR el botón, nunca antes.
##
## Sin arrastre real (`_eje_trazo_pieza` nunca se clavó) delega en `_colocar_pieza_en`/`_borrar_en`
## -- EXACTAMENTE el mismo camino que un clic suelto de siempre (conserva su aviso, su emisión de
## `layout_cambiado`, y el contrato que ya usan los tests que las llaman directo). Con un trazo de
## verdad, coloca/borra SOLO las celdas VÁLIDAS (las de dentro del rect jugable se saltan, con el
## mismo veto de siempre) -- nunca revienta ni corta el resto por una celda mala.
func _aplicar_trazo_pieza() -> void:
	if _herramienta == HERRAMIENTA_BORRAR:
		if _eje_trazo_pieza == "":
			_borrar_en(_ancla_trazo_pieza)
			return
		var borradas := 0
		for celda: Vector2i in _celdas_del_trazo_pieza():
			if not _celda_valida(celda):
				continue
			var habia: bool = _piezas.has(celda) or _superficies.has(celda)
			_borrar_en(celda)
			if habia:
				borradas += 1
		if borradas > 0:
			_avisar("%d celdas borradas" % borradas)
		return
	if not CATALOGO_PIEZAS.has(_herramienta):
		return
	if _eje_trazo_pieza == "":
		_colocar_pieza_en(_ancla_trazo_pieza)
		return
	_colocar_trazo_piezas(_celdas_del_trazo_pieza())


## El paso EXACTO de pantalla al recorrer UNA celda en la dirección `paso_logico` del plano lógico
## (`Vector2i(1,0)`/`Vector2i(0,1)`, la misma convención que `Construccion._paso_de`).
##
## 🐛 FIX "DIENTES DE 2PX" (2026-08-15, medido al píxel): antes cada pieza del trazo se posicionaba
## con `Proyeccion.centro_iso(celda)` INDEPENDIENTE por celda -- con el ancla lejos del origen (el
## entorno vive en coordenadas negativas/grandes) el `.round()` final de cada pieza podía caer a un
## lado distinto que el de su vecina en la MISMA fila de muro, y la línea salía con dientes. Sumando
## este paso ENTERO al ancla, celda a celda (`_colocar_trazo_piezas`/`_refrescar_fantasma_trazo_
## pieza`), la cadena es matemática acumulada EXACTA hasta el último redondeo -- uno por pieza, igual
## que antes, pero sobre una base sin arrastre de error. Siempre enteros: `paso_logico` solo vale
## (±1,0) o (0,±1), así que la fórmula de `Proyeccion.proyectar` para esos valores no pasa por
## ninguna división que pueda perder precisión.
static func _paso_pantalla_de(paso_logico: Vector2i) -> Vector2:
	return Vector2(
		float(paso_logico.x - paso_logico.y) * Proyeccion.MEDIO_ANCHO,
		float(paso_logico.x + paso_logico.y) * Proyeccion.MEDIO_ALTO
	)


## Coloca TODAS las celdas válidas del trazo, con el id/rotación que lleva la herramienta -- ver la
## cabecera de `_paso_pantalla_de` para la matemática acumulada que evita los "dientes".
func _colocar_trazo_piezas(celdas: Array[Vector2i]) -> void:
	var colocadas := 0
	var centro_ancla: Vector2 = Proyeccion.centro_iso(_ancla_trazo_pieza)
	var paso_logico: Vector2i = Vector2i(1, 0) if _eje_trazo_pieza == "x" else Vector2i(0, 1)
	var paso_pantalla: Vector2 = _paso_pantalla_de(paso_logico)
	for celda: Vector2i in celdas:
		if not _celda_valida(celda):
			continue
		var i: int = (
			(celda - _ancla_trazo_pieza).x if _eje_trazo_pieza == "x" else (celda - _ancla_trazo_pieza).y
		)
		_piezas[celda] = {"id": _herramienta, "rotacion": _orientacion}
		_refrescar_pieza_visual(celda, centro_ancla + paso_pantalla * float(i))
		colocadas += 1
	if colocadas > 0:
		_avisar("%s × %d colocadas" % [NOMBRES_PIEZA.get(_herramienta, String(_herramienta)), colocadas])
		layout_cambiado.emit()
	else:
		_avisar("Eso es del edificio -- fuera de mi alcance")


func _limpiar_fantasma_trazo_pieza() -> void:
	if _capa_fantasma_trazo == null:
		return
	for hijo: Node in _capa_fantasma_trazo.get_children():
		hijo.queue_free()


## Reconstruye el fantasma con TODAS las celdas del trazo actual, semitransparentes -- verde/rojo
## según SU PROPIA validez individual (a diferencia del trazo de muro de Construcción, aquí no hay
## "todo o nada": cada celda se coloca por separado y las de dentro del edificio simplemente se
## saltan al soltar, así que el fantasma cuenta esa misma historia celda a celda). Posiciones con la
## MISMA matemática acumulada que `_colocar_trazo_piezas` -- el fantasma tiene que caer EXACTAMENTE
## donde va a caer la pieza de verdad.
func _refrescar_fantasma_trazo_pieza() -> void:
	_limpiar_fantasma_trazo_pieza()
	if _capa_fantasma_trazo == null or _herramienta == HERRAMIENTA_BORRAR:
		return
	if not CATALOGO_PIEZAS.has(_herramienta):
		return
	var celdas: Array[Vector2i] = _celdas_del_trazo_pieza()
	if celdas.is_empty():
		return
	var textura: Texture2D = EntornoExteriorScript.textura_de_pieza(String(_herramienta), _orientacion)
	if textura == null:
		return
	var centro_ancla: Vector2 = Proyeccion.centro_iso(_ancla_trazo_pieza)
	var paso_logico: Vector2i = Vector2i(1, 0) if _eje_trazo_pieza == "x" else Vector2i(0, 1)
	var paso_pantalla: Vector2 = _paso_pantalla_de(paso_logico)
	var escala_kit: bool = EntornoExteriorScript.CONSTRUCCION_TODAS.has(_herramienta)
	for celda: Vector2i in celdas:
		var valido: bool = _celda_valida(celda)
		var i: int = (
			(celda - _ancla_trazo_pieza).x if _eje_trazo_pieza == "x" else (celda - _ancla_trazo_pieza).y
		)
		var sprite := Sprite2D.new()
		sprite.texture = textura
		AnclajeSpriteScript.aplicar(sprite, Vector2i(1, 0), 1)
		if escala_kit:
			sprite.scale = Vector2(ESCALA_KIT, ESCALA_KIT)
		sprite.modulate = COLOR_FANTASMA_PIEZA if valido else COLOR_FANTASMA_INVALIDO
		sprite.position = (
			centro_ancla + paso_pantalla * float(i) + AnclajeSpriteScript.desvio_rejilla(textura)
			+ _desvio_arista(_herramienta, _orientacion)
		).round()
		_capa_fantasma_trazo.add_child(sprite)


# ── Piezas ────────────────────────────────────────────────────────────────────────────────────
func _colocar_pieza_en(celda: Vector2i) -> void:
	if not _celda_valida(celda):
		_avisar("Eso es del edificio -- fuera de mi alcance")
		return
	_piezas[celda] = {"id": _herramienta, "rotacion": _orientacion}
	_refrescar_pieza_visual(celda)
	_avisar("%s colocada en %s" % [NOMBRES_PIEZA.get(_herramienta, String(_herramienta)), celda])
	layout_cambiado.emit()


## IMPORTA EL ENTORNO PROCEDURAL COMO PIEZAS DEL USUARIO (2026-08-09, encargo: "quiero poder editar
## con F12 todos los elementos del entorno"). Hasta hoy los árboles/farolas/coches/casas del barrio
## los pintaba `EntornoExterior` por código y el diseñador ni los veía: no había forma de moverlos ni
## borrarlos. Ahora se copian a `_piezas` (mismo esquema que las colocadas a mano, así que la goma,
## la R y el arrastre funcionan igual) y se APAGA la base procedural para que no se vean duplicadas.
##
## Respeta lo que ya hay: una celda con pieza del usuario NO se pisa. Ignora los ids que la paleta no
## sabe pintar y las celdas del edificio (mismo veto que `_colocar_pieza_en`) — nunca se crea una
## pieza que luego no se pudiera borrar. Devuelve cuántas importó.
func importar_base(inventario: Array) -> int:
	var nuevas := 0
	for entrada: Variant in inventario:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var celda: Vector2i = _celda_de_entrada(entrada as Dictionary)
		if _piezas.has(celda) or not _celda_valida(celda):
			continue
		var id := StringName(String((entrada as Dictionary).get("id", "")))
		if not CATALOGO_PIEZAS.has(id):
			continue
		_piezas[celda] = {"id": id, "rotacion": int((entrada as Dictionary).get("rotacion", 0))}
		_refrescar_pieza_visual(celda)
		nuevas += 1
	# La base se apaga SIEMPRE tras importar: lo que el usuario ve a partir de ahora son SUS piezas
	# (si siguiera encendida, cada objeto se vería dos veces).
	_fijar_base_visible(false)
	_avisar("Importadas %d piezas del entorno -- ya puedes moverlas y borrarlas" % nuevas)
	layout_cambiado.emit()
	return nuevas


## ARRIMADO A LA ARISTA de las piezas de pared (ver `PIEZAS_PARED`). Una pared no ocupa el centro de
## su celda: se apoya en uno de sus cuatro lados. QUÉ lado no es libre — lo decide el eje por el que
## AVANZA la pared, y equivocarlo es lo que producía el aspecto de SIERRA que reportó el usuario:
##
##   Una fila de muros que avanza en X sobre la arista OESTE de cada celda NO forma una línea: las
##   aristas oeste de celdas contiguas en X están ESCALONADAS media celda cada una. La línea recta
##   la forman las aristas NORTE (todas comparten la misma y), y ésas son las que tocan.
##
##   rot  90/270 (pared a lo largo del eje X) → arista NORTE/SUR
##   rot   0/180 (pared a lo largo del eje Y) → arista OESTE/ESTE
##
## El desvío es media celda del plano lógico cuadrado hacia ese lado.
## Cero para todo lo que no sea pared: un árbol o un coche siguen centrados en su celda.
func _desvio_arista(id: StringName, rotacion: int) -> Vector2:
	if not PIEZAS_PARED.has(id):
		return Vector2.ZERO
	var medio: float = float(_tam_celda) * 0.5
	var direccion := Vector2.ZERO
	match posmod(rotacion, 360):
		0: direccion = Vector2(-1.0, 0.0)    # pared a lo largo del eje Y → arista OESTE
		90: direccion = Vector2(0.0, -1.0)   # pared a lo largo del eje X → arista NORTE
		180: direccion = Vector2(1.0, 0.0)   # ídem 0, por el lado contrario
		270: direccion = Vector2(0.0, 1.0)   # ídem 90, por el lado contrario
	return Proyeccion.proyectar(direccion * medio)


## `centro_iso`: por defecto `Vector2.INF` = "calcúlalo tú" (`Proyeccion.centro_iso(celda)`, el
## camino de SIEMPRE — clic suelto, carga de disco, importar). El trazo del pincel Sims
## (`_colocar_trazo_piezas`, 2026-08-15 · fix "dientes de 2px") pasa el centro YA acumulado desde el
## ancla del trazo con matemática exacta (ver `_paso_pantalla_de`): cada pieza calculada de forma
## INDEPENDIENTE vía `Proyeccion.centro_iso(celda_absoluta)` podía redondear a un lado distinto que
## su vecina de la misma fila — la cadena de sumas relativas al ancla no arrastra ese error.
func _refrescar_pieza_visual(celda: Vector2i, centro_iso: Vector2 = Vector2.INF) -> void:
	if _nodos_pieza.has(celda):
		_nodos_pieza[celda].queue_free()
		_nodos_pieza.erase(celda)
	if not _piezas.has(celda):
		return
	var pieza: Dictionary = _piezas[celda]
	var id: String = String(pieza["id"])
	var textura: Texture2D = EntornoExteriorScript.textura_de_pieza(id, int(pieza["rotacion"]))
	if textura == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = textura
	AnclajeSpriteScript.aplicar(sprite, Vector2i(1, 0), 1)
	if EntornoExteriorScript.CONSTRUCCION_TODAS.has(StringName(id)):
		sprite.scale = Vector2(ESCALA_KIT, ESCALA_KIT)   # ver `ESCALA_KIT`
	var centro: Vector2 = centro_iso if centro_iso != Vector2.INF else Proyeccion.centro_iso(celda)
	# ALINEACIÓN A LA CUADRÍCULA (2026-08-09, "las casas empiezan en mitad de una celda"): las
	# piezas con huella PAR (casa 6, coche 2, carretera 6) se corren media celda para que sus
	# bordes caigan sobre bordes de celda; las de huella impar (farola 1) siguen centradas.
	# `.round()`: la posición final SIEMPRE en píxel entero. Con decimales (el ancla medida y los
	# desvíos son floats) cada módulo redondea por su lado y en una fila de muros aparecen dientes
	# de 1-2px en el borde — el defecto que reportó el usuario ("veo huecos arriba y abajo de las
	# uniones"), medido en la captura: saltos de 2px justo en cada unión. `centro_iso` (arriba) es
	# la otra mitad del fix: la base que se redondea ya viene sin arrastre de error de por medio.
	sprite.position = (
		_origen + centro + AnclajeSpriteScript.desvio_rejilla(textura)
		+ _desvio_arista(StringName(id), int(pieza["rotacion"]))
	).round()
	if PIEZAS_PLANAS.has(StringName(id)):
		# Casi planas: SIN y-sort, van al fondo (mismo criterio que `EntornoExterior`).
		sprite.z_index = EntornoExteriorScript.Z_CAPA - _capa_piezas.z_index
		add_child(sprite)
	else:
		_capa_piezas.add_child(sprite)
	_nodos_pieza[celda] = sprite


# ── Superficies ───────────────────────────────────────────────────────────────────────────────
func _pintar_superficie_en(celda: Vector2i, tipo: StringName) -> void:
	_superficies[celda] = tipo
	_refrescar_superficie_visual(celda)
	layout_cambiado.emit()


func _refrescar_superficie_visual(celda: Vector2i) -> void:
	if not _superficies.has(celda):
		_capa_superficies.erase_cell(celda)
		return
	var tipo: StringName = _superficies[celda]
	var color: Color = EntornoExteriorScript.COLOR_POR_TIPO_SUPERFICIE.get(tipo, Color.MAGENTA)
	var fuente_id: int = _fuente_de(color)
	_capa_superficies.set_cell(celda, fuente_id, Vector2i.ZERO)


func _fuente_de(color: Color) -> int:
	var clave := StringName(color.to_html(false))
	if _fuentes_superficie.has(clave):
		return _fuentes_superficie[clave]
	var imagen := Image.create(_tam_celda, _tam_celda, false, Image.FORMAT_RGBA8)
	imagen.fill(color)
	var fuente := TileSetAtlasSource.new()
	fuente.texture = ImageTexture.create_from_image(imagen)
	fuente.texture_region_size = Vector2i(_tam_celda, _tam_celda)
	fuente.create_tile(Vector2i.ZERO)
	var id: int = _capa_superficies.tile_set.add_source(fuente)
	_fuentes_superficie[clave] = id
	return id


func _borrar_en(celda: Vector2i) -> void:
	var habia: bool = _piezas.has(celda) or _superficies.has(celda)
	_piezas.erase(celda)
	_superficies.erase(celda)
	_refrescar_pieza_visual(celda)
	_refrescar_superficie_visual(celda)
	if habia:
		layout_cambiado.emit()


func _limpiar_todo() -> void:
	for celda: Vector2i in _nodos_pieza.keys():
		_nodos_pieza[celda].queue_free()
	_nodos_pieza.clear()
	_piezas.clear()
	for celda: Vector2i in _superficies.keys():
		_capa_superficies.erase_cell(celda)
	_superficies.clear()


# ── Farolas para `LucesObjetos` (mismo criterio que `EntornoExterior.puntos_farolas`) ───────────
func puntos_farolas() -> Array[Vector2]:
	var puntos: Array[Vector2] = []
	for celda: Vector2i in _piezas:
		if _piezas[celda]["id"] == &"farola":
			puntos.append(_origen + Proyeccion.centro_iso(celda))
	return puntos


# ── Persistencia (MISMO esquema que `EntornoExterior.leer_layout` lee en res://datos/) ──────────
## `ruta` es un parámetro (por defecto `RUTA_GUARDADO`) para que los tests puedan apuntar a un
## archivo de scratch propio y no tocar `user://entorno_disenado.json` de verdad (aislamiento —
## `.claude/rules/test-standards.md`: "unit tests must not depend on external state").
func guardar_en_disco(ruta: String = "") -> bool:
	if ruta == "":
		ruta = ruta_guardado
	var piezas_json: Array = []
	for celda: Vector2i in _piezas:
		var p: Dictionary = _piezas[celda]
		piezas_json.append({
			"id": String(p["id"]), "celda": [celda.x, celda.y], "rotacion": int(p["rotacion"]),
		})
	var superficies_json: Array = []
	for celda: Vector2i in _superficies:
		superficies_json.append({"celda": [celda.x, celda.y], "tipo": String(_superficies[celda])})
	var datos: Dictionary = {
		"version": VERSION_LAYOUT, "piezas": piezas_json, "superficies": superficies_json,
		"base_visible": _base_visible,
	}
	var texto: String = JSON.stringify(datos, "", true, true)
	var ruta_tmp: String = ruta + ".tmp"
	var f: FileAccess = FileAccess.open(ruta_tmp, FileAccess.WRITE)
	if f == null:
		push_error("ModoDisenadorEntorno.guardar_en_disco: no se pudo abrir '%s' (error %d)" % [ruta_tmp, FileAccess.get_open_error()])
		_avisar("⚠ No se pudo guardar")
		return false
	var ok: bool = f.store_string(texto)
	f.close()
	if not ok:
		push_error("ModoDisenadorEntorno.guardar_en_disco: store_string falló")
		_avisar("⚠ No se pudo guardar")
		return false
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	var err: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(ruta_tmp), ProjectSettings.globalize_path(ruta)
	)
	if err != OK:
		push_error("ModoDisenadorEntorno.guardar_en_disco: rename falló (error %d)" % err)
		_avisar("⚠ No se pudo guardar")
		return false
	_avisar("💾 Guardado: %d piezas, %d celdas de superficie" % [_piezas.size(), _superficies.size()])
	return true


## Carga `ruta` (por defecto `RUTA_GUARDADO`, `user://entorno_disenado.json`) si existe (llamado al
## entrar en el modo). `true` si había algo que cargar; `false` (silencioso, caso normal la primera
## vez) si el archivo no existe.
func cargar_desde_disco(ruta: String = "") -> bool:
	if ruta == "":
		ruta = ruta_guardado
	var datos: Dictionary = EntornoExteriorScript.leer_layout(ruta)
	if datos.is_empty():
		return false
	_aplicar_datos(datos)
	_avisar("Cargado: %d piezas, %d celdas de superficie" % [_piezas.size(), _superficies.size()])
	return true


func _aplicar_datos(datos: Dictionary) -> void:
	_limpiar_todo()
	for entrada: Variant in datos.get("piezas", []):
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var celda: Vector2i = _celda_de_entrada(entrada)
		_piezas[celda] = {
			"id": StringName(String(entrada.get("id", ""))), "rotacion": int(entrada.get("rotacion", 0)),
		}
		_refrescar_pieza_visual(celda)
	for entrada: Variant in datos.get("superficies", []):
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var celda: Vector2i = _celda_de_entrada(entrada)
		_superficies[celda] = StringName(String(entrada.get("tipo", "")))
		_refrescar_superficie_visual(celda)
	# Visibilidad del entorno base guardada con el layout (2026-08-09) — por defecto visible para
	# los layouts viejos sin la clave.
	_fijar_base_visible(bool(datos.get("base_visible", true)))
	layout_cambiado.emit()


## Fija el estado del interruptor del entorno base, refresca su botón y avisa a `Main` (que es
## quien de verdad oculta/muestra las capas de `EntornoExterior` — ver `base_visible_cambiada`).
func _fijar_base_visible(visible: bool) -> void:
	_base_visible = visible
	if _btn_base != null:
		# `set_pressed_no_signal`: asignar `button_pressed` re-dispararía `toggled` y esta función
		# se llamaría a sí misma (cazado por el test de roundtrip: la señal salía duplicada).
		_btn_base.set_pressed_no_signal(not visible)
		_btn_base.text = "🌍 Base: oculta" if not visible else "🌍 Base: visible"
	base_visible_cambiada.emit(visible)


static func _celda_de_entrada(entrada: Dictionary) -> Vector2i:
	var c: Variant = entrada.get("celda", [0, 0])
	if typeof(c) != TYPE_ARRAY or (c as Array).size() < 2:
		return Vector2i.ZERO
	return Vector2i(int((c as Array)[0]), int((c as Array)[1]))


# ── Activación (F12, ver `Main._unhandled_input`) ────────────────────────────────────────────────
func alternar() -> void:
	_activo = not _activo
	if _activo:
		# Editor, no gameplay (mismo criterio que `--pausa`): el reloj no debe correr mientras se
		# compone el entorno -- nadie quiere que un NPC cruce el recinto mientras colocas una casa.
		Tiempo.fijar_velocidad(Tiempo.Velocidad.PAUSA)
		# 🐛 FIX (playtest 2026-08-08, "los objetos guardados no los puedo modificar ni quitar"):
		# ANTES esto llamaba `cargar_desde_disco()` sin condición CADA VEZ que se activaba (F12) --
		# `_ready()` YA autocarga una vez al instanciar (ver más abajo), así que en la primera
		# activación era redundante e inofensivo, pero si el usuario editaba/borraba piezas y
		# volvía a pulsar F12 (desactivar/reactivar) SIN guardar (F8) de por medio, esta recarga a
		# lo bruto pisaba el estado en memoria con lo último guardado en disco -- cualquier borrado o
		# colocación sin guardar se deshacía en silencio, exactamente el síntoma reportado ("no puedo
		# quitarlas": las quitaba, pero reaparecían al re-alternar).
		#
		# 🐛 SEGUNDO FIX (mismo día, agujero del primero): "solo recarga si _piezas/_superficies están
		# vacíos" seguía mal -- confundía "vacío porque no se ha cargado nada todavía" con "vacío
		# porque el usuario ACABA de borrar la última pieza". Si borrabas la única pieza con el modo ya
		# activo y volvías a pulsar F12 dos veces (desactivar/reactivar), el estado en memoria SÍ está
		# vacío mereciendamente y esta condición lo trataba como "arranque limpio" -- resucitaba del
		# disco justo lo que el usuario acababa de borrar (test
		# `test_alternar_no_descarta_una_pieza_borrada_sin_guardar`). La única autocarga fiable es "una
		# vez por proceso", nunca "cuando esté vacío": `_autocargado` se pone a `true` en cuanto esta
		# instancia hace SU carga inicial (normalmente la de `_ready()`, ver más abajo; el chequeo aquí
		# es solo un cinturón de seguridad por si algún día `alternar()` se llamara antes de que
		# `_ready()` corra). A partir de ahí el estado en memoria manda siempre, tal como
		# `guardar_en_disco()`/F8 ya asumía -- "Recargar del disco" sigue siendo la vía explícita para
		# quien quiera descartar cambios sin guardar a propósito.
		if not _autocargado:
			cargar_desde_disco()
			_autocargado = true
	else:
		_fijar_herramienta(&"")
	_actualizar_visibilidad()
	activado_cambiado.emit(_activo)


func _actualizar_visibilidad() -> void:
	_capa_ui.visible = _activo
	if not _activo:
		_preview_sprite.visible = false
		_preview_caja.visible = false
		_preview_triangulo.visible = false
		_descartar_trazo_pieza()


func _fijar_herramienta(id: StringName) -> void:
	_herramienta = id
	_pintando = false
	# Cambiar de herramienta a MEDIO TRAZO lo tira (2026-08-15) -- mismo criterio que
	# `ModoConstruccion._cancelar`: nada que el jugador no haya visto termina en el layout.
	_descartar_trazo_pieza()
	# 🐛 Sin esto: pintar cesped en una celda y CAMBIAR de herramienta (a la goma, por ejemplo) y
	# volver a pulsar la MISMA celda se tomaba como "repetición del mismo arrastre" (la guarda de
	# `_pintar_o_borrar_en` compara contra la última celda pintada, sin importar con qué herramienta)
	# y el segundo clic no hacía NADA -- cazado por
	# `modo_disenador_entorno_test.gd::test_borrar_quita_pieza_y_superficie_de_la_celda`.
	_celda_pintada_anterior = Vector2i(-999, -999)
	# EL SELECCIONADO SE MARCA CON EL ESTADO "PRESSED" DEL KIT (2026-08-07, remate del reskin), no con
	# un tinte de `modulate` -- mismo contrato que `ModoConstruccion._fijar_herramienta`: `TarjetaObjeto`
	# trae su propio arte de "seleccionada" y un tinte por encima lo desharía. Este bucle es la ÚNICA
	# fuente de verdad de qué botón está `button_pressed`.
	for herramienta_id: StringName in _botones:
		(_botones[herramienta_id] as Button).button_pressed = herramienta_id == id


func _avisar(texto: String) -> void:
	if _lbl_estado != null:
		_lbl_estado.text = texto


## El botón de una PESTAÑA de categoría (no es una `_herramienta`: cambia qué tarjetas se ven) --
## mismo contrato que `ModoConstruccion._construir_pestana_categoria`, sin depender de sus iconos
## propios (esta paleta no tiene pictograma dedicado por categoría todavía: el rótulo ya lleva el
## emoji, ver `CATEGORIAS`).
func _construir_pestana(id: StringName, nombre: String) -> Button:
	var boton := Button.new()
	boton.text = nombre
	boton.focus_mode = Control.FOCUS_NONE
	boton.toggle_mode = true
	boton.theme_type_variation = KitUIComisarioScript.VARIANTE_PESTANA
	boton.custom_minimum_size = Vector2(112.0, 48.0)
	boton.pressed.connect(func() -> void: _mostrar_categoria(id))
	_pestanas_categoria[id] = boton
	return boton


## Cuelga `boton` de `fila` (SIEMPRE, ver la cabecera de `_tarjetas_por_categoria`) y lo apunta en la
## categoría -- oculto hasta que `_mostrar_categoria` la active.
func _anadir_tarjeta(fila: HFlowContainer, categoria: StringName, boton: Button) -> void:
	boton.visible = false
	fila.add_child(boton)
	(_tarjetas_por_categoria[categoria] as Array).append(boton)


## Cambia qué fila de tarjetas se ve. NO reinstancia ni descuelga nada: todas las tarjetas son hijas
## fijas de `fila` (ver `_crear_ui`) y aquí solo se alterna su `visible`.
func _mostrar_categoria(categoria: StringName) -> void:
	_categoria_activa = categoria
	for cat_id: StringName in _tarjetas_por_categoria:
		var activa: bool = cat_id == categoria
		for boton: Button in (_tarjetas_por_categoria[cat_id] as Array):
			(boton as Button).visible = activa
	for id: StringName in _pestanas_categoria:
		(_pestanas_categoria[id] as Button).button_pressed = id == categoria


# ── UI (paleta, patrón de `ModoConstruccion`: HFlowContainer de botones) ────────────────────────
func _crear_ui() -> void:
	_capa_ui = CanvasLayer.new()
	_capa_ui.name = "UIDisenadorEntorno"
	_capa_ui.visible = false
	add_child(_capa_ui)

	# 🐛 REHECHO (2026-08-09, feedback del usuario: "el menú sale muy arriba y me tapa toda la
	# pantalla, y abajo un recuadro gris semitransparente vacío"): la versión anterior mezclaba
	# `PRESET_BOTTOM_WIDE` con `position.y`/`size` puestos A MANO — `position` es relativa a la
	# ESQUINA SUPERIOR del viewport, no al ancla, así que el contenido caía a una distancia FIJA
	# del borde de arriba (calibrada a ojo en una resolución concreta) y el ColorRect del fondo se
	# quedaba abajo, vacío y descolgado. Ahora es un `PanelContainer` anclado abajo que CRECE hacia
	# arriba con la altura de su contenido — el mismo patrón (que sí funciona a cualquier
	# resolución) de la barra de `ModoConstruccion`, con el fondo plano compartido del kit.
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.theme = KitUIComisarioScript.tema()
	var estilo_fondo := StyleBoxFlat.new()
	estilo_fondo.bg_color = KitUIComisarioScript.COLOR_FONDO_BARRA_INFERIOR
	panel.add_theme_stylebox_override("panel", estilo_fondo)
	_capa_ui.add_child(panel)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_right", 12)
	margen.add_theme_constant_override("margin_top", 8)
	margen.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margen)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 6)
	margen.add_child(raiz)

	var titulo := Label.new()
	titulo.text = "🏗 MODO DISEÑADOR DE ENTORNO -- R rota · arrastra para colocar/pintar · F8 guarda · F12 sale"
	raiz.add_child(titulo)

	# ── PESTAÑAS DE CATEGORÍA (2026-08-08, encargo "submenú: casas, carreteras, árboles y jardín,
	# objetos") -- mismo patrón que `ModoConstruccion::_construir_pestana_categoria`: un botón
	# `toggle_mode` con `VARIANTE_PESTANA`, todas las tarjetas SIEMPRE colgadas de `fila` (ver abajo),
	# `_mostrar_categoria` solo alterna `visible` -- nunca se descuelga un nodo.
	var fila_pestanas := HBoxContainer.new()
	fila_pestanas.add_theme_constant_override("separation", 6)
	raiz.add_child(fila_pestanas)
	for categoria: Dictionary in CATEGORIAS:
		fila_pestanas.add_child(_construir_pestana(categoria["id"], categoria["nombre"]))

	var fila: HFlowContainer = HFlowContainer.new()
	# Separación entre tarjetas (petición del usuario: "me cuesta seleccionar las cosas") -- un botón
	# grande pegado a su vecino sigue invitando al clic fallido (Fitts's Law); el hueco es tan parte
	# del objetivo como el tamaño del propio botón.
	fila.add_theme_constant_override("h_separation", 8)
	fila.add_theme_constant_override("v_separation", 8)
	raiz.add_child(fila)
	for categoria: Dictionary in CATEGORIAS:
		var cat_id: StringName = categoria["id"]
		_tarjetas_por_categoria[cat_id] = []
		for id: StringName in (PIEZAS_POR_CATEGORIA.get(cat_id, []) as Array):
			_anadir_tarjeta(fila, cat_id, _boton_herramienta(id, NOMBRES_PIEZA[id]))
		if cat_id == &"superficies":
			for id: StringName in SUPERFICIES:
				_anadir_tarjeta(fila, cat_id, _boton_herramienta(id, NOMBRES_SUPERFICIE[id]))
			_anadir_tarjeta(fila, cat_id, _boton_herramienta(HERRAMIENTA_BORRAR, "🧹 Borrar"))
	_mostrar_categoria(&"casas")

	var fila_acciones := HBoxContainer.new()
	fila_acciones.add_theme_constant_override("separation", 8)
	raiz.add_child(fila_acciones)
	var btn_guardar := Button.new()
	btn_guardar.text = "💾 Guardar (F8)"
	btn_guardar.focus_mode = Control.FOCUS_NONE
	btn_guardar.theme_type_variation = KitUIComisarioScript.VARIANTE_PILDORA_PRIMARIA
	btn_guardar.custom_minimum_size = Vector2(140.0, 48.0)
	btn_guardar.pressed.connect(guardar_en_disco)
	fila_acciones.add_child(btn_guardar)
	var btn_cargar := Button.new()
	btn_cargar.text = "🔄 Recargar del disco"
	btn_cargar.focus_mode = Control.FOCUS_NONE
	btn_cargar.theme_type_variation = KitUIComisarioScript.VARIANTE_PILDORA_SECUNDARIA
	btn_cargar.custom_minimum_size = Vector2(160.0, 48.0)
	btn_cargar.pressed.connect(cargar_desde_disco)
	fila_acciones.add_child(btn_cargar)

	# Interruptor del ENTORNO BASE procedural (2026-08-09, "quiero hacer de nuevo el entorno y no
	# me deja borrar lo que había"): apagarlo esconde vallas/farolas/coches/casas/calle de acceso
	# que pinta `EntornoExterior` por código, dejando el lienzo limpio para diseñar desde cero. Se
	# guarda con F8 dentro del layout y el congelado lo respeta.
	_btn_base = Button.new()
	_btn_base.text = "🌍 Base: visible"
	_btn_base.focus_mode = Control.FOCUS_NONE
	_btn_base.toggle_mode = true
	_btn_base.theme_type_variation = KitUIComisarioScript.VARIANTE_PILDORA_SECUNDARIA
	_btn_base.custom_minimum_size = Vector2(160.0, 48.0)
	_btn_base.toggled.connect(func(pulsado: bool) -> void: _fijar_base_visible(not pulsado))
	fila_acciones.add_child(_btn_base)

	# "Importar entorno": convierte el procedural en piezas EDITABLES del usuario (ver
	# `importar_base`) — la vía para rehacer el entorno partiendo de lo que ya hay en vez del vacío.
	var btn_importar := Button.new()
	btn_importar.text = "⬇ Importar entorno"
	btn_importar.focus_mode = Control.FOCUS_NONE
	btn_importar.theme_type_variation = KitUIComisarioScript.VARIANTE_PILDORA_SECUNDARIA
	btn_importar.custom_minimum_size = Vector2(180.0, 48.0)
	btn_importar.pressed.connect(func() -> void: importar_base_solicitado.emit())
	fila_acciones.add_child(btn_importar)

	_lbl_estado = Label.new()
	_lbl_estado.text = "Elige una pieza o una brocha de superficie"
	raiz.add_child(_lbl_estado)


## Tamaño de la miniatura de pieza en la paleta (petición del usuario 2026-08-08, estilo tycoon:
## "una imagen del objeto a elegir con el diseño que tiene... por ejemplo las diferentes casas").
## Es un SUELO (`custom_minimum_size`), no el tamaño final: `STRETCH_KEEP_ASPECT_CENTERED` la
## encoge/agranda con aspecto dentro de lo que le asigne el `HBoxContainer` — nunca deforma la pieza.
## Baja 40->36 (2026-08-08, spec `design/ux/spec-tarjetas-2026-08-08.md` §2.1): con la tarjeta a
## 128×56 y el margen de 8px ahora respetado (fix de causa raíz §0-B), 36px deja sitio de sobra al
## rótulo sin que la miniatura se salga de su columna.
const TAMANO_MINIATURA_PALETA := Vector2(36.0, 36.0)

## Tamaño de la tarjeta de la paleta (icono + rótulo, o solo texto) — spec
## `design/ux/spec-tarjetas-2026-08-08.md` §2.1: 128×56, ancho +16px (2×8px del margen de contenido
## que el fix de §0-B empieza a respetar) y alto +8px (mismo margen, dirección vertical).
const TAMANO_TARJETA_PALETA := Vector2(128.0, 56.0)

## Botón de la paleta (pieza/superficie/goma): piel `TarjetaObjeto` del kit (2026-08-07, remate del
## reskin) con `toggle_mode` porque el estado "pressed" del tema ES el arte de "herramienta en mano"
## (contrato documentado en la cabecera de `KitUIComisario` -- ver `_fijar_herramienta`, la ÚNICA
## fuente de verdad de qué botón queda marcado). Tamaño mínimo 56px de alto (petición del usuario:
## "me cuesta seleccionar las cosas"; subido de 48 a 56 el 2026-08-08, spec
## `design/ux/spec-tarjetas-2026-08-08.md` §2.1, para respetar el margen de 8px de contenido) --
## antes el botón se ajustaba solo al ancho del texto, una zona de clic tan fina como una línea de
## letra.
##
## MINIATURA DEL SPRITE REAL (2026-08-08): solo las PIEZAS de `CATALOGO_PIEZAS` (casas, vallas,
## árboles, coches...) tienen arte propio que enseñar -- las brochas de `SUPERFICIES` y
## `HERRAMIENTA_BORRAR` se quedan con el botón de texto de siempre (nunca tuvieron ni necesitan un
## sprite único). Reutiliza `EntornoExterior.textura_de_pieza`, rotación 0 fija -- la MISMA fuente
## que ya pinta el fantasma de colocación (`_process`) y las piezas ya colocadas
## (`_refrescar_pieza_visual`): ningún dato nuevo, solo otro consumidor de la misma resolución. La
## tarjeta enseña la PIEZA, no la orientación que el jugador vaya a elegir con R.
func _boton_herramienta(id: StringName, texto: String) -> Button:
	var boton := Button.new()
	boton.focus_mode = Control.FOCUS_NONE
	boton.toggle_mode = true
	boton.theme_type_variation = KitUIComisarioScript.VARIANTE_TARJETA
	boton.custom_minimum_size = TAMANO_TARJETA_PALETA
	boton.pressed.connect(func() -> void: _fijar_herramienta(id))
	_botones[id] = boton
	var textura: Texture2D = null
	if CATALOGO_PIEZAS.has(id):
		textura = EntornoExteriorScript.textura_de_pieza(String(id), 0)
	if textura == null:
		# Sin arte (superficies/goma, o una pieza a la que le falte el PNG -- fallback honesto): el
		# botón de texto de siempre. El texto desbordaba la tarjeta (auditoría 2026-08-08):
		# `TarjetaObjeto` tiene un `content_margin` pequeño y fijo (ver `theme_comisario.tres`), pero
		# un rótulo largo aun así puede no caber en el ancho de la tarjeta. `clip_text` corta en el
		# borde en vez de derramarse fuera del botón. `TextServer.OVERRUN_TRIM_ELLIPSIS` daría un
		# corte más elegante ("Sillón...") pero no está confirmado en `docs/engine-reference/godot/`
		# para 4.6 -- por la regla del proyecto (no adivinar API post-cutoff sin verificar) nos
		# quedamos solo con `clip_text`. Mismo `custom_minimum_size` que el camino con sprite (arriba)
		# para que la rejilla quede uniforme (spec `design/ux/spec-tarjetas-2026-08-08.md` §2.1).
		boton.text = texto
		boton.clip_text = true
		boton.add_theme_font_size_override("font_size", 11)
		return boton
	boton.text = ""
	boton.tooltip_text = texto   # nombre completo siempre disponible, aunque el rótulo se recorte
	# `clip_contents` en el BOTÓN, no solo en `contenido` (diagnóstico 2026-08-08, sonda
	# `_diag_tarjeta_rects` de `ModoConstruccion`, mismo patrón aquí): con un nombre largo, el
	# `Label.get_combined_minimum_size()` de la etiqueta reporta la altura de TODAS las líneas
	# envueltas, no el suelo fijo de la banda -- ese suelo es un MÍNIMO, no un TECHO. El mínimo mayor
	# se propaga hacia `contenido` y `margen`, que crecen más allá del alto real del botón (56px) sin
	# nada que los recorte. Sin `clip_contents` aquí, el rótulo se dibuja fuera de la tarjeta.
	boton.clip_contents = true
	# Envuelve el contenido en un margen de 8px (mismo valor que `content_margin_*` de
	# `sb_tarj_n`/`sb_tarj_h`/`sb_tarj_s`/`sb_tarj_b` en `theme_comisario.tres`) en vez de anclarlo
	# directo al rect completo del botón -- fix de causa raíz §0-B: era el `PRESET_FULL_RECT` sin
	# margen + rótulo expansivo lo que empujaba la miniatura contra el borde izquierdo literal.
	var margen := MarginContainer.new()
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 8)
	margen.add_theme_constant_override("margin_right", 8)
	margen.add_theme_constant_override("margin_top", 8)
	margen.add_theme_constant_override("margin_bottom", 8)
	boton.add_child(margen)
	var contenido := HBoxContainer.new()
	contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.clip_contents = true   # cinturón de seguridad: nada se dibuja fuera de la tarjeta
	contenido.alignment = BoxContainer.ALIGNMENT_CENTER
	contenido.add_theme_constant_override("separation", 6)
	margen.add_child(contenido)
	var rect := TextureRect.new()
	rect.texture = textura
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = TAMANO_MINIATURA_PALETA
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(rect)
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", 10)
	# Mismo bug/fix que en _construir_boton_con_icono de ModoConstruccion (2026-08-08): el Label
	# hijo no hereda el font_color del Button y salía blanco — invisible sobre la tarjeta clara.
	etiqueta.add_theme_color_override("font_color", KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	etiqueta.clip_contents = true
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(etiqueta)
	return boton


# ── Fantasma de colocación (patrón de `ModoConstruccion.PreviewIso`, simplificado) ──────────────
func _crear_preview() -> void:
	_capa_preview = CanvasLayer.new()
	_capa_preview.name = "PreviewDisenadorEntorno"
	add_child(_capa_preview)
	_preview_sprite = Sprite2D.new()
	_preview_sprite.visible = false
	_capa_preview.add_child(_preview_sprite)
	_preview_caja = Polygon2D.new()
	_preview_caja.visible = false
	_capa_preview.add_child(_preview_caja)
	_preview_triangulo = Polygon2D.new()
	_preview_triangulo.color = Color(0.25, 0.55, 1.0, 0.85)
	_preview_triangulo.visible = false
	_capa_preview.add_child(_preview_triangulo)
	_capa_fantasma_trazo = Node2D.new()
	_capa_fantasma_trazo.name = "FantasmaTrazoPieza"
	_capa_preview.add_child(_capa_fantasma_trazo)


func _process(_delta: float) -> void:
	if _capa_preview != null:
		_capa_preview.transform = get_canvas_transform()
	# RED DE SEGURIDAD DEL TRAZO (2026-08-15, mismo patrón que
	# `ModoConstruccion._arrastrando_muro`/`_process`): si el botón ya no está físicamente pulsado y
	# aquí seguimos creyendo que hay un trazo vivo, el evento de soltar se lo llevó otro (la paleta,
	# un diálogo). Se TIRA, no se aplica.
	if _trazando_pieza and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_descartar_trazo_pieza()
	if not _activo or _herramienta == &"":
		_preview_sprite.visible = false
		_preview_caja.visible = false
		_preview_triangulo.visible = false
		_celda_preview_anterior = Vector2i(-999, -999)
		return
	if _trazando_pieza:
		# El fantasma del trazo completo (`_refrescar_fantasma_trazo_pieza`, disparado por el propio
		# arrastre en `_extender_trazo_pieza`/R) sustituye al fantasma de UNA celda mientras dura.
		_preview_sprite.visible = false
		_preview_triangulo.visible = false
		_preview_caja.visible = false
		return
	var celda: Vector2i = _celda_de_evento(get_viewport().get_mouse_position())
	if celda == _celda_preview_anterior and _orientacion == _orientacion_anterior:
		return
	_celda_preview_anterior = celda
	_orientacion_anterior = _orientacion
	var valido: bool = _celda_valida(celda)
	var centro: Vector2 = _origen + Proyeccion.centro_iso(celda)
	if CATALOGO_PIEZAS.has(_herramienta):
		_preview_caja.visible = false
		var textura: Texture2D = EntornoExteriorScript.textura_de_pieza(String(_herramienta), _orientacion)
		if textura != null:
			_preview_sprite.visible = true
			_preview_sprite.texture = textura
			_preview_sprite.modulate = COLOR_FANTASMA_PIEZA if valido else COLOR_FANTASMA_INVALIDO
			AnclajeSpriteScript.aplicar(_preview_sprite, Vector2i(1, 0), 1)
			_preview_sprite.scale = (
				Vector2(ESCALA_KIT, ESCALA_KIT)
				if EntornoExteriorScript.CONSTRUCCION_TODAS.has(_herramienta)
				else Vector2.ONE
			)
			# El fantasma cae EXACTAMENTE donde caerá la pieza (mismo desvío de rejilla que
			# `_refrescar_pieza_visual`) — si no, lo que se ve al apuntar no es lo que se coloca.
			_preview_sprite.position = (
				centro + AnclajeSpriteScript.desvio_rejilla(textura)
				+ _desvio_arista(_herramienta, _orientacion)
			)
			_refrescar_triangulo(celda, valido)
	else:
		_preview_sprite.visible = false
		_preview_triangulo.visible = false
		_preview_caja.visible = true
		var rombo: PackedVector2Array = Proyeccion.rombo_de_celda(celda)
		for i: int in rombo.size():
			rombo[i] += _origen
		_preview_caja.polygon = rombo
		_preview_caja.color = COLOR_FANTASMA_PIEZA if valido else COLOR_FANTASMA_INVALIDO


## El triángulo azul de orientación (encargo): apunta hacia el FRENTE de la pieza en mano, delante
## de su celda -- mismo lenguaje visual que `ModoConstruccion.PreviewOrientacion`.
func _refrescar_triangulo(celda: Vector2i, valido: bool) -> void:
	var frente: Vector2i = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][
		ORIENTACIONES_CICLO.find(_orientacion)
	]
	var centro: Vector2 = _origen + Proyeccion.centro_iso(celda)
	var punta: Vector2 = _origen + Proyeccion.centro_iso(celda + frente)
	var mitad: Vector2 = (centro + punta) * 0.5
	var eje: Vector2 = (punta - centro).normalized()
	var perpendicular: Vector2 = Vector2(-eje.y, eje.x) * 6.0
	_preview_triangulo.visible = valido
	_preview_triangulo.polygon = PackedVector2Array([
		punta, mitad + perpendicular, mitad - perpendicular,
	])
