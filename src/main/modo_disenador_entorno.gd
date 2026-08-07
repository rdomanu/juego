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

## Catálogo de piezas colocables — mismos ids que los PNG de `assets/sprites/entorno/`
## (`tools/render_entorno_urbano.gd`), las 4 rotaciones ya renderizadas para cada una.
const CATALOGO_PIEZAS: Array[StringName] = [
	&"casa_a", &"casa_d", &"casa_g", &"casa_k", &"casa_o",
	&"valla_baja", &"valla_estandar", &"camino_recinto", &"entrada_casa",
	&"arbol_urbano", &"tree_grande", &"tree_pequeno", &"seto", &"farola", &"planter",
	&"coche_policia", &"coche_sedan", &"coche_suv",
]
const NOMBRES_PIEZA: Dictionary[StringName, String] = {
	&"casa_a": "🏠 Casa A", &"casa_d": "🏠 Casa D", &"casa_g": "🏠 Casa G",
	&"casa_k": "🏠 Casa K", &"casa_o": "🏠 Casa O",
	&"valla_baja": "▤ Valla baja", &"valla_estandar": "▥ Valla estándar",
	&"camino_recinto": "▬ Camino", &"entrada_casa": "▭ Entrada de casa",
	&"arbol_urbano": "🌳 Árbol urbano", &"tree_grande": "🌲 Árbol grande",
	&"tree_pequeno": "🌱 Árbol pequeño", &"seto": "🌿 Seto", &"farola": "💡 Farola",
	&"planter": "🪴 Jardinera",
	&"coche_policia": "🚓 Coche patrulla", &"coche_sedan": "🚗 Coche sedán",
	&"coche_suv": "🚙 Coche SUV",
}
## Piezas CASI PLANAS (van al overlay del suelo, sin y-sort — mismo criterio que `EntornoExterior`).
const PIEZAS_PLANAS: Array[StringName] = [&"camino_recinto", &"entrada_casa"]

## Las 3 "brochas de superficie" + la goma -- pintan/borran celdas con los MISMOS colores planos que
## ya usa `EntornoExterior` (nunca un color inventado aparte).
const SUPERFICIES: Array[StringName] = [&"cesped", &"asfalto", &"acera"]
const NOMBRES_SUPERFICIE: Dictionary[StringName, String] = {
	&"cesped": "🟩 Césped", &"asfalto": "⬛ Asfalto", &"acera": "⬜ Acera",
}
const HERRAMIENTA_BORRAR := &"borrar"

const ORIENTACIONES_CICLO: Array[int] = [0, 90, 180, 270]

const RUTA_GUARDADO := "user://entorno_disenado.json"
const VERSION_LAYOUT := 1

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const EntornoExteriorScript := preload("res://src/main/entorno_exterior.gd")

const COLOR_BOTON_ACTIVO := Color(1.0, 0.85, 0.35)
const ALFA_FANTASMA: float = 0.55
const COLOR_FANTASMA_PIEZA := Color(0.6, 0.85, 1.0, ALFA_FANTASMA)
const COLOR_FANTASMA_INVALIDO := Color(1.0, 0.35, 0.35, 0.5)

var _tam_celda: int = 40
var _origen: Vector2 = Vector2.ZERO
var _mundo_profundo: Node2D = null

var _activo: bool = false
## Herramienta en mano: un id de `CATALOGO_PIEZAS`, un id de `SUPERFICIES`, `HERRAMIENTA_BORRAR`, o "".
var _herramienta: StringName = &""
var _orientacion: int = 0
var _pintando: bool = false
var _celda_pintada_anterior: Vector2i = Vector2i(-999, -999)
var _celda_preview_anterior: Vector2i = Vector2i(-999, -999)
var _orientacion_anterior: int = -1

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
var _lbl_estado: Label
var _botones: Dictionary[StringName, Button] = {}

var _capa_preview: CanvasLayer
var _preview_sprite: Sprite2D
var _preview_caja: Polygon2D
var _preview_triangulo: Polygon2D


func configurar(tam_celda: int, origen: Vector2, mundo_profundo: Node2D) -> void:
	_tam_celda = tam_celda
	_origen = origen
	_mundo_profundo = mundo_profundo


func _ready() -> void:
	_crear_capas()
	_crear_ui()
	_crear_preview()
	cargar_desde_disco()
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
	if not (evento is InputEventMouseButton):
		return
	var boton := evento as InputEventMouseButton
	if boton.button_index != MOUSE_BUTTON_LEFT:
		return
	var celda: Vector2i = _celda_de_evento(boton.position)
	if boton.pressed:
		_al_pulsar(celda)
	else:
		_pintando = false
		_celda_pintada_anterior = Vector2i(-999, -999)


func _al_pulsar(celda: Vector2i) -> void:
	if _herramienta == &"":
		return
	if CATALOGO_PIEZAS.has(_herramienta):
		_colocar_pieza_en(celda)
		return
	# Superficie o goma: arrastrable (petición: "arrastre para pintar superficies").
	_pintando = true
	_celda_pintada_anterior = Vector2i(-999, -999)
	_pintar_o_borrar_en(celda)


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


# ── Piezas ────────────────────────────────────────────────────────────────────────────────────
func _colocar_pieza_en(celda: Vector2i) -> void:
	if not _celda_valida(celda):
		_avisar("Eso es del edificio -- fuera de mi alcance")
		return
	_piezas[celda] = {"id": _herramienta, "rotacion": _orientacion}
	_refrescar_pieza_visual(celda)
	_avisar("%s colocada en %s" % [NOMBRES_PIEZA.get(_herramienta, String(_herramienta)), celda])
	layout_cambiado.emit()


func _refrescar_pieza_visual(celda: Vector2i) -> void:
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
	sprite.position = _origen + Proyeccion.centro_iso(celda)
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
func guardar_en_disco(ruta: String = RUTA_GUARDADO) -> bool:
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
func cargar_desde_disco(ruta: String = RUTA_GUARDADO) -> bool:
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
	layout_cambiado.emit()


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
		cargar_desde_disco()
	else:
		_fijar_herramienta(&"")
	_actualizar_visibilidad()


func _actualizar_visibilidad() -> void:
	_capa_ui.visible = _activo
	if not _activo:
		_preview_sprite.visible = false
		_preview_caja.visible = false
		_preview_triangulo.visible = false


func _fijar_herramienta(id: StringName) -> void:
	_herramienta = id
	_pintando = false
	# 🐛 Sin esto: pintar cesped en una celda y CAMBIAR de herramienta (a la goma, por ejemplo) y
	# volver a pulsar la MISMA celda se tomaba como "repetición del mismo arrastre" (la guarda de
	# `_pintar_o_borrar_en` compara contra la última celda pintada, sin importar con qué herramienta)
	# y el segundo clic no hacía NADA -- cazado por
	# `modo_disenador_entorno_test.gd::test_borrar_quita_pieza_y_superficie_de_la_celda`.
	_celda_pintada_anterior = Vector2i(-999, -999)
	for herramienta_id: StringName in _botones:
		(_botones[herramienta_id] as Button).modulate = (
			COLOR_BOTON_ACTIVO if herramienta_id == id else Color.WHITE
		)


func _avisar(texto: String) -> void:
	if _lbl_estado != null:
		_lbl_estado.text = texto


# ── UI (paleta, patrón de `ModoConstruccion`: HFlowContainer de botones) ────────────────────────
func _crear_ui() -> void:
	_capa_ui = CanvasLayer.new()
	_capa_ui.name = "UIDisenadorEntorno"
	_capa_ui.visible = false
	add_child(_capa_ui)

	var fondo := ColorRect.new()
	fondo.color = Color(0.08, 0.09, 0.10, 0.88)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fondo.custom_minimum_size = Vector2(0.0, 190.0)
	fondo.position.y = -190.0
	fondo.size = Vector2(2000.0, 190.0)
	_capa_ui.add_child(fondo)

	var raiz := VBoxContainer.new()
	raiz.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	raiz.position.y = -186.0
	raiz.custom_minimum_size = Vector2(0.0, 186.0)
	_capa_ui.add_child(raiz)

	var titulo := Label.new()
	titulo.text = "🏗 MODO DISEÑADOR DE ENTORNO -- R rota · arrastra para pintar superficie · F8 guarda · F12 sale"
	raiz.add_child(titulo)

	var fila: HFlowContainer = HFlowContainer.new()
	raiz.add_child(fila)
	for id: StringName in CATALOGO_PIEZAS:
		fila.add_child(_boton_herramienta(id, NOMBRES_PIEZA[id]))
	for id: StringName in SUPERFICIES:
		fila.add_child(_boton_herramienta(id, NOMBRES_SUPERFICIE[id]))
	fila.add_child(_boton_herramienta(HERRAMIENTA_BORRAR, "🧹 Borrar"))

	var fila_acciones := HBoxContainer.new()
	raiz.add_child(fila_acciones)
	var btn_guardar := Button.new()
	btn_guardar.text = "💾 Guardar (F8)"
	btn_guardar.pressed.connect(guardar_en_disco)
	fila_acciones.add_child(btn_guardar)
	var btn_cargar := Button.new()
	btn_cargar.text = "🔄 Recargar del disco"
	btn_cargar.pressed.connect(cargar_desde_disco)
	fila_acciones.add_child(btn_cargar)

	_lbl_estado = Label.new()
	_lbl_estado.text = "Elige una pieza o una brocha de superficie"
	raiz.add_child(_lbl_estado)


func _boton_herramienta(id: StringName, texto: String) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.toggle_mode = false
	boton.pressed.connect(func() -> void: _fijar_herramienta(id))
	_botones[id] = boton
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


func _process(_delta: float) -> void:
	if _capa_preview != null:
		_capa_preview.transform = get_canvas_transform()
	if not _activo or _herramienta == &"":
		_preview_sprite.visible = false
		_preview_caja.visible = false
		_preview_triangulo.visible = false
		_celda_preview_anterior = Vector2i(-999, -999)
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
			_preview_sprite.position = centro
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
