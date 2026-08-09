extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — UX DE PINTURA Y ZONAS "TIPO SIMS" (2026-08-05,
## quick-spec `construccion-pintura-puertas-preview` §3d). Verifica visualmente las tres piezas
## de UX de esta tanda, una captura por tarea:
##
##   1. ux_selector_tramo.png — el selector de arista a TRAMO COMPLETO (tarea 1): el quad que sube
##      de esquina a esquina y de suelo a remate, en vez de la línea fina de antes.
##   2. ux_preview_mayus.png — el fantasma de MAYÚS del pincel de pintura (tarea 2): todos los
##      tramos de una sala tintados a la vez, antes de soltar el clic.
##   3. ux_velo_zonas.png — el velo de zonas del modo construcción (tarea 3): cada sala cubierta
##      por su color de zona, con su rótulo (ya existente) encima.
##
## NOTA DE VERIFICACIÓN: el estado de UI real (hover del ratón moviéndose, la tecla MAYÚS
## pulsada) no se puede fingir con un `InputEvent` de verdad en una sonda de GPU sin ventana
## interactiva. En vez de simularlo, se llama DIRECTAMENTE a las mismas funciones de dibujo que
## invocaría `ModoConstruccion._process` en esos estados (`_refrescar_preview_pintar_pared` con
## `mayus` a mano, `VeloZonas.refrescar`) — mismo patrón que ya usan las demás sondas de este
## proyecto para features de ratón (ver `_diag_alturas_pared.gd`). Se borra tras usarlo.
##
## SIN CÁMARA (como el juego real — `main.gd` no usa `Camera2D` para el tablero, solo
## `Proyeccion.origen_centrado`): el preview de `ModoConstruccion` vive en una `CanvasLayer`, que
## ignora la transformada de cualquier `Camera2D`; con cámara, el fantasma y el mundo se verían
## desalineados en esta sonda.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const PaletaPinturaScript := preload("res://src/core/construccion/paleta_pintura.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(900, 620)
const COLUMNAS: int = 14
const FILAS: int = 10

## Carpeta del scratchpad de ESTA sesión (fuera del repo — PROHIBIDO escribir en assets/capturas/).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/3d17fabd-3e64-4077-8e28-18435fc15bba/scratchpad/"

var _sub: SubViewport
var _construccion: Node
var _paredes: Node2D
var _modo: Node2D
var _sala_doc: StringName
var _sala_odac: StringName


func _ready() -> void:
	_montar()
	await RenderingServer.frame_post_draw
	await _capturar_selector_tramo()
	await _capturar_preview_mayus()
	await _capturar_velo_zonas()
	await _capturar_caras_pintadas()
	get_tree().quit()


## Dos salas (Documentación + ODAC) con paredes reales, fachada levantada, y `ModoConstruccion`
## cableado igual que en `main.gd` (sin capa de profundidad separada: el andamio no la necesita).
func _montar() -> void:
	_sub = SubViewport.new()
	_sub.size = TAM_RENDER
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)
	var capa_fondo := CanvasLayer.new()
	capa_fondo.layer = -1
	_sub.add_child(capa_fondo)
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.14, 0.16)
	fondo.size = Vector2(TAM_RENDER)
	capa_fondo.add_child(fondo)
	var mundo := Node2D.new()
	_sub.add_child(mundo)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)
	_paredes = ParedesSalasScript.new()
	profundo.add_child(_paredes)

	var eco: Node = EconomiaScript.new()
	mundo.add_child(eco)
	eco.aplicar_config(ConfigEconomiaScript.new())
	eco.abonar(500000.0)
	_construccion = ConstruccionScript.new()
	mundo.add_child(_construccion)
	_construccion.aplicar_config(ConfigConstruccionScript.new())
	_construccion.usar_economia(eco)
	_construccion.edificio_columnas = COLUMNAS
	_construccion.edificio_filas = FILAS

	# SIN CÁMARA: el origen centra el tablero directamente en el viewport (ver cabecera).
	var origen: Vector2 = ProyeccionScript.origen_centrado(COLUMNAS, FILAS, Vector2(TAM_RENDER))
	_construccion.montar_visual(TAM_CELDA, origen, profundo)
	_construccion.levantar_fachada()
	_sala_doc = _construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(2, 2, 5, 4))
	_construccion.fijar_paredes_de_sala(_sala_doc, true)
	_sala_odac = _construccion.construir_de_oficio_sala(&"sala_odac", Rect2i(8, 2, 4, 4))
	_construccion.fijar_paredes_de_sala(_sala_odac, true)

	_paredes.configurar(_construccion, TAM_CELDA, origen)
	_construccion.fijar_hook_layout(Callable(_paredes, "actualizar"))

	_modo = ModoConstruccionScript.new()
	_modo.configurar(_construccion, TAM_CELDA)
	mundo.add_child(_modo)   # dispara _ready(): crea la UI, la rejilla y el velo de zonas
	# DEBUG (sonda): forzar el layer de la CanvasLayer de la UI por si el empate a layer=0 con el
	# lienzo base perdiera el compuesto — se retira si no hace falta.
	var capa_ui: CanvasLayer = _modo.get_node("UIConstruccion")
	capa_ui.layer = 5
	# CAUSA RAÍZ de la sonda vacía: `_process` de ModoConstruccion corre cada frame y, con el ratón
	# REAL fuera del tablero, apaga `_preview_caja` pisando el estado forzado de la captura (el
	# fantasma de MAYÚS sobrevivía porque solo se recalcula al cambiar de objetivo). La sonda
	# congela el proceso: el estado lo fijamos a mano.
	_modo.set_process(false)
	print("[DIAG UX PINTURA] capa_ui.layer=%d process=OFF" % capa_ui.layer)


## 1) EL SELECTOR DE ARISTA A TRAMO COMPLETO (tarea 1): el pincel de pared apuntando a un tramo
## real del perímetro de la sala de Documentación — el quad entero, no una línea fina.
func _capturar_selector_tramo() -> void:
	# El preview SOLO es visible con el modo construcción ACTIVO (igual que en el juego): sin esto,
	# el contenedor de previews está oculto y la captura sale vacía (causa raíz de la 1ª pasada).
	_modo._activo = true
	_modo._actualizar_visibilidad()
	_modo._herramienta = _modo.HERRAMIENTA_PINTAR_PARED
	# Un color REAL de la paleta (petición del usuario: "si he elegido un azul se debería poner la
	# selección de una pared en azul"): el preview usa `_color_pincel` — lo mismo que hace el juego.
	_modo._color_pincel = PaletaPinturaScript.color_de(&"azul_acero")
	_modo._preview_caja.visible = true
	_modo._preview_texto.visible = true
	_modo._preview_mayus.limpiar()
	_modo._refrescar_preview_pintar_pared(Vector2i(4, 2), &"arriba", false)
	print("[DIAG UX PINTURA] preview_caja visible=%s desde=%s hasta=%s grosor=%s alto=%s color=%s pos=%s in_tree=%s canvas_layer=%s" % [
		_modo._preview_caja.visible, _modo._preview_caja.linea_desde, _modo._preview_caja.linea_hasta,
		_modo._preview_caja.grosor, _modo._preview_caja.linea_alto, _modo._preview_caja.color,
		_modo._preview_caja.global_position, _modo._preview_caja.is_inside_tree(),
		_modo._preview_caja.get_canvas_layer_node(),
	])
	# Redibujo forzado + un frame extra: en la 1ª captura de la sonda el quad no llegaba a
	# componerse (timing del primer frame del SubViewport); en la 2ª captura salía bien.
	_modo._preview_caja.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_guardar("ux_selector_tramo.png")


## 2) EL FANTASMA DE MAYÚS (tarea 2): con el pincel de pared en la mano y MAYÚS "pulsada" (el
## parámetro `mayus=true` que pasaría `_process` con la tecla real abajo), TODOS los tramos del
## perímetro de la sala de Documentación se tiñen a la vez. Se deja constancia en consola de que
## el mismo mecanismo funciona igual para el pincel de SUELO (`celdas_de_sala`, no capturado en
## PNG aparte — mismo código, otra lista de polígonos).
func _capturar_preview_mayus() -> void:
	_modo._herramienta = _modo.HERRAMIENTA_PINTAR_SUELO
	_modo._color_pincel = PaletaPinturaScript.color_de(&"verde_salvia")   # color real de la paleta
	_modo._refrescar_preview_pintar_suelo(Vector2i(9, 3), true)
	print("[DIAG UX PINTURA] fantasma de MAYÚS (SUELO, sala ODAC): %d celdas" \
		% _modo._preview_mayus._poligonos.size())

	_modo._herramienta = _modo.HERRAMIENTA_PINTAR_PARED
	_modo._color_pincel = PaletaPinturaScript.color_de(&"azul_acero")
	_modo._preview_caja.visible = true
	_modo._preview_texto.visible = true
	# El tramo NORTE del perímetro de Documentación (Rect2i(2,2,5,4) -> fila 2 es su borde de
	# arriba): tiene que ser un tramo REAL del muro (interior a la sala no vale — ahí no hay pared).
	_modo._refrescar_preview_pintar_pared(Vector2i(4, 2), &"arriba", true)
	print("[DIAG UX PINTURA] fantasma de MAYÚS (PAREDES, sala Documentación): %d tramos" \
		% _modo._preview_mayus._poligonos.size())
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_guardar("ux_preview_mayus.png")


## 3) EL VELO DE ZONAS (tarea 3): modo construcción activo, cada sala con su color de zona y su
## rótulo (el rótulo ya existía — `Construccion._refrescar_visual` lo crea siempre; aquí solo se
## ve porque el fondo de la celda ya no compite con él).
func _capturar_velo_zonas() -> void:
	_modo._herramienta = &""
	_modo._preview_caja.visible = false
	_modo._preview_texto.visible = false
	_modo._preview_mayus.limpiar()
	_modo._activo = true
	_modo._actualizar_visibilidad()
	_modo._velo_zonas.refrescar(_construccion)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_guardar("ux_velo_zonas.png")


## 4) PINTURA POR CARA (2026-08-06, quick-spec §3f): la sala de Documentación pintada de azul acero
## POR DENTRO con MAYÚS (pintar_sala_muros = caras interiores). Lo que debe verse: sus muros
## traseros (norte/oeste) azul acero — su cara visible ES la interior —, y sus muros frontales
## (sur/este) con el color por defecto — su cara visible es la del pasillo, que NO se pintó.
func _capturar_caras_pintadas() -> void:
	_modo._herramienta = &""
	_modo._preview_caja.visible = false
	_modo._preview_texto.visible = false
	_modo._preview_mayus.limpiar()
	var azul: Color = PaletaPinturaScript.color_de(&"azul_acero")
	var pintados: int = _construccion.pintar_sala_muros(_sala_doc, azul)
	print("[DIAG UX PINTURA] caras: pintadas %d caras interiores de la sala Documentación" % pintados)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_guardar("ux_caras_pintadas.png")


func _guardar(nombre: String) -> void:
	var ruta: String = CARPETA_SALIDA + nombre
	var err: Error = _sub.get_texture().get_image().save_png(ruta)
	if err != OK:
		push_error("[DIAG UX PINTURA] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DIAG UX PINTURA] -> %s" % ruta)
