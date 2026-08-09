extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU) — LA FOTOCOPIADORA DE SUMMER EN EL JUEGO (2026-08-06).
##
## Monta el trazado de oficio real (mismas salas/puestos que `_check_trazado.gd` y `main.gd`),
## deja que `completar_todas_las_salas(true)` coloque las impresoras obligatorias (Documentación y
## ODAC), y captura el resultado: la fotocopiadora generada por Summer, reescalada al factor de
## presencia (39 px), dibujada por el camino REAL de sprites de comodidad. Se borra tras usarlo.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const ImpresoraDocumentosScript := preload("res://src/core/impresora/impresora_documentos.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(1000, 640)
const COLUMNAS: int = 14
const FILAS: int = 11
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/3d17fabd-3e64-4077-8e28-18435fc15bba/scratchpad/"


func _ready() -> void:
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
	var mundo := Node2D.new()
	sub.add_child(mundo)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)
	var paredes := ParedesSalasScript.new()
	profundo.add_child(paredes)

	var eco: Node = EconomiaScript.new()
	mundo.add_child(eco)
	eco.aplicar_config(ConfigEconomiaScript.new())
	eco.abonar(500000.0)
	var c: Node = ConstruccionScript.new()
	mundo.add_child(c)
	c.aplicar_config(ConfigConstruccionScript.new())
	c.usar_economia(eco)
	c.edificio_columnas = COLUMNAS
	c.edificio_filas = FILAS
	var origen: Vector2 = ProyeccionScript.origen_centrado(COLUMNAS, FILAS, Vector2(TAM_RENDER))
	c.montar_visual(TAM_CELDA, origen, profundo)
	c.levantar_fachada()
	# El trazado de oficio real (mismas coordenadas que _check_trazado.gd / main.gd).
	c.construir_de_oficio_sala(&"sala_documentacion", Rect2i(1, 1, 6, 4))
	c.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(1, 6, 6, 4))
	c.construir_de_oficio_sala(&"sala_odac", Rect2i(9, 1, 4, 3))
	c.construir_de_oficio_sala(&"sala_espera_odac", Rect2i(9, 5, 3, 3))
	c.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(2, 2), &"doc_1")
	c.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(4, 2), &"doc_2")
	c.construir_de_oficio_elemento(&"puesto_tie", Vector2i(6, 2), &"tie_1")
	c.construir_de_oficio_elemento(&"puesto_odac", Vector2i(10, 2), &"odac_1")
	# El módulo real de la impresora (mismo cableado que main.gd) coloca las obligatorias.
	var impresora: Node = ImpresoraDocumentosScript.new()
	impresora.usar_construccion(c)
	impresora.usar_economia(eco)
	impresora.usar_tiempo(Tiempo)
	mundo.add_child(impresora)
	var colocadas: Array[StringName] = impresora.completar_todas_las_salas(true)
	print("[DIAG IMPRESORA VISUAL] completar_todas_las_salas -> %s" % [colocadas])
	paredes.configurar(c, TAM_CELDA, origen)
	c.fijar_hook_layout(Callable(paredes, "actualizar"))
	paredes.fijar_modo_altura(&"bajitas")   # muros bajos: que las impresoras se VEAN en la foto

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta: String = CARPETA_SALIDA + "impresora_en_juego.png"
	print("[DIAG IMPRESORA VISUAL] save=%d -> %s" % [imagen.save_png(ruta), ruta])
	get_tree().quit()
