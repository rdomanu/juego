extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — FASE 1 del entorno exterior
## (`design/art/entorno-exterior.md`): acera+calzada, control (solo el hormigón — la garita y la
## barrera son props de una fase posterior), recinto+aparcamiento pintado (líneas de las 5 plazas)
## y césped del futuro parque, alrededor de la fachada REAL con su puerta oeste
## (`Main._abrir_puerta_de_oficio`/`NPCsFlujo.CELDA_PUERTA_EDIFICIO`, celda (0,6)).
##
## NO instancia `Main` entero (arrastra Economía/Demanda/Flujo/HUD — ruido para esta foto): monta
## solo `Construccion` (fachada, sin salas) + `ParedesSalas` (el perímetro dibujado) +
## `EntornoExterior` (lo nuevo), con el MISMO patrón de encuadre por cámara que
## `_diag_alturas_pared.gd`/`_diag_suelo_limpio.gd` (las capas visuales cuelgan de un nodo
## NO-CanvasItem: no se puede transformar un padre, hay que encuadrar con `Camera2D`).
##
## JUEZ NUMÉRICO antes de la foto: cuántas celdas pintó cada zona (`get_used_cells` filtrado por
## rect) y si alguna cae dentro del rect jugable — la foto ilustra, el número decide.
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const EntornoExteriorScript := preload("res://src/main/entorno_exterior.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 24
const FILAS: int = 13
const TAM_RENDER := Vector2i(960, 620)

## Carpeta del scratchpad de ESTA sesión (fuera del repo — PROHIBIDO escribir en assets/capturas/).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"


func _ready() -> void:
	await _capturar()
	get_tree().quit()


## La fachada REAL (con su puerta de oficio en (0,6)) + el entorno nuevo, encuadrados por cámara
## para que se vea TODO el recorrido: calzada → control → recinto/aparcamiento → puerta.
func _montar() -> Array:
	var sub := SubViewport.new()
	sub.size = TAM_RENDER
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var capa_fondo := CanvasLayer.new()
	capa_fondo.layer = -1
	sub.add_child(capa_fondo)
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.14, 0.16)
	fondo.size = Vector2(TAM_RENDER)
	capa_fondo.add_child(fondo)
	# Encuadre: el centro del recorrido (columna −6, fila 6 del plano lógico), zoom < 1 para que
	# quepan las ~13 columnas de zona exterior + un trozo del edificio.
	var camara := Camera2D.new()
	camara.zoom = Vector2(0.62, 0.62)
	camara.position = ProyeccionScript.proyectar(Vector2(-6.0, 6.0) * float(TAM_CELDA))
	sub.add_child(camara)
	camara.make_current()
	var mundo := Node2D.new()
	sub.add_child(mundo)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)
	var paredes := ParedesSalasScript.new()
	profundo.add_child(paredes)
	var construccion := ConstruccionScript.new()
	construccion.aplicar_config(ConfigConstruccionScript.new())
	mundo.add_child(construccion)
	construccion.montar_visual(TAM_CELDA, Vector2.ZERO, profundo)
	construccion.levantar_fachada()
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	construccion.fijar_hook_layout(Callable(paredes, "actualizar"))
	# EntornoExterior va FUERA de `profundo` (no es y-sort, es fondo puro — ver su cabecera):
	# cuelga directo de `mundo`, igual que en `Main`.
	var entorno := EntornoExteriorScript.new()
	mundo.add_child(entorno)
	entorno.configurar(TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS)
	return [sub, construccion, entorno]


func _capturar() -> void:
	var piezas: Array = _montar()
	var sub: SubViewport = piezas[0]
	var entorno: Node = piezas[2]
	_volcar(entorno)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%sentorno_fase1.png" % CARPETA_SALIDA
	var err: Error = sub.get_texture().get_image().save_png(ruta)
	if err != OK:
		push_error("[DIAG ENTORNO FASE 1] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DIAG ENTORNO FASE 1] -> %s" % ruta)
	sub.queue_free()


## El volcado numérico: cuántas celdas pintó cada zona y si alguna se coló en el rect jugable.
func _volcar(entorno: Node) -> void:
	var capa: TileMapLayer = entorno.capa_suelo()
	var usadas: Array[Vector2i] = capa.get_used_cells()
	var rect_jugable := Rect2i(0, 0, COLUMNAS, FILAS)
	var invasoras := 0
	for celda: Vector2i in usadas:
		if rect_jugable.has_point(celda):
			invasoras += 1
	print("[DIAG ENTORNO FASE 1] celdas_pintadas=%d invadiendo_rect_jugable=%d plazas=%d" % [
		usadas.size(), invasoras, entorno.PLAZAS_APARCAMIENTO.size()
	])
	if invasoras > 0:
		push_error("[DIAG ENTORNO FASE 1] %d celdas del entorno caen DENTRO del rect jugable" % invasoras)
