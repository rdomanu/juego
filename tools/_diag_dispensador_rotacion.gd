extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — DISPENSADOR DE AGUA, ROTACIÓN DIRECTA (2026-08-06,
## unificación de los objetos de agua: `dispensador_agua` pasa a `rotacion_directa` con sus 4 PNG ya
## existentes en disco, `fuente_agua` retirada por duplicada).
##
## Coloca la pieza de verdad (`construir_de_oficio_elemento`, gratis, sin Economía) en una
## `sala_descanso` (familia "descanso"), con un muñeco de 44 px de referencia. Un mundo NUEVO por
## orientación (0/90/180/270). Tamaño y `.tres` SIN TOCAR (solo cambia qué PNG le toca a cada giro).
##
## PASA/FALLA, por caso (4): colocado, huella EXACTA 1 celda (superficie=1, sin traspuesta), sprite
## == `comodidad_dispensador_agua_<grado>.png` (rotación directa, el grado literal), ancla del
## `Sprite2D` real (por `resource_path`) a ≤3px de `centro_en_pantalla(ANCLA)` (celdas=1 →
## `delta_ultima_celda` es CERO).
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(560, 480)

## Carpeta del scratchpad de ESTA sesión (fuera del repo).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

const TOLERANCIA_ANCLA_PX: float = 3.0

const CELDA_ANCLA := Vector2i(3, 3)
const HERRAMIENTA := &"dispensador_agua"

const ALTO_MUNECO_PX: int = 44

const ETIQUETAS := {0: "0_sur", 90: "90_oeste", 180: "180_norte", 270: "270_este"}

var _veredictos: Dictionary[String, bool] = {}


func _ready() -> void:
	for grado: int in [0, 90, 180, 270]:
		await _caso(grado)
	var fallos: int = 0
	for etiqueta: String in _veredictos:
		if not _veredictos[etiqueta]:
			fallos += 1
	print("[DIAG DISPENSADOR ROTACION] RESUMEN: %d caso(s), %d FALLA(N) -> %s" % [
		_veredictos.size(), fallos, "PASA" if fallos == 0 else "FALLA"
	])
	get_tree().quit()


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
	var mundo := Node2D.new()
	sub.add_child(mundo)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)

	var construccion: Node = ConstruccionScript.new()
	mundo.add_child(construccion)
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.montar_visual(TAM_CELDA, Vector2(120.0, 60.0), profundo)
	construccion.construir_de_oficio_sala(&"sala_descanso", Rect2i(0, 0, 8, 8))

	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", ALTO_MUNECO_PX)
	muneco.position = construccion.centro_en_pantalla(CELDA_ANCLA + Vector2i(-2, 1))
	profundo.add_child(muneco)

	return [sub, construccion, profundo]


## Busca, recursivo, el primer `Sprite2D` cuya textura venga de un PNG cuyo nombre contenga `pista`.
func _buscar_sprite(raiz: Node, pista: String) -> Sprite2D:
	if raiz is Sprite2D and raiz.texture != null:
		var ruta: String = String(raiz.texture.resource_path)
		if ruta.contains(pista):
			return raiz
	for hijo: Node in raiz.get_children():
		var hallado: Sprite2D = _buscar_sprite(hijo, pista)
		if hallado != null:
			return hallado
	return null


func _caso(grado: int) -> void:
	var etiqueta: String = ETIQUETAS[grado]
	var piezas: Array = _montar()
	var sub: SubViewport = piezas[0]
	var construccion: Node = piezas[1]
	var profundo: Node = piezas[2]

	var ok: bool = true
	var motivos: PackedStringArray = PackedStringArray()

	var elemento_id: StringName = construccion.construir_de_oficio_elemento(
		HERRAMIENTA, CELDA_ANCLA, &"", grado
	)
	var colocado_ok: bool = elemento_id != &""
	if not colocado_ok:
		ok = false
		motivos.append("colocacion: construir_de_oficio_elemento devolvio id vacio")

	var huella_ok: bool = false
	var celdas_reales: Array = []
	if colocado_ok:
		celdas_reales = construccion.celdas_de_elemento(elemento_id)
		huella_ok = celdas_reales.size() == 1 and celdas_reales[0] == CELDA_ANCLA
	if not huella_ok:
		ok = false
		motivos.append("huella: real=%s esperada=[%s]" % [celdas_reales, CELDA_ANCLA])

	var ancla_ok: bool = false
	var delta_ancla: float = -1.0
	var ruta_sprite: String = "<no encontrado>"
	if colocado_ok:
		var sprite: Sprite2D = _buscar_sprite(profundo, "comodidad_dispensador_agua_")
		if sprite != null:
			ruta_sprite = String(sprite.texture.resource_path)
			var esperada_ruta: String = (
				"res://assets/sprites/mobiliario/comodidad_dispensador_agua_%d.png" % grado
			)
			var esperada_pos: Vector2 = construccion.centro_en_pantalla(CELDA_ANCLA)
			var real_pos: Vector2 = sprite.global_position
			delta_ancla = (real_pos - esperada_pos).length()
			ancla_ok = delta_ancla <= TOLERANCIA_ANCLA_PX and ruta_sprite == esperada_ruta
			if ruta_sprite != esperada_ruta:
				motivos.append("sprite: real=%s esperado=%s" % [ruta_sprite, esperada_ruta])
	if not ancla_ok:
		ok = false
		motivos.append("ancla: delta=%.2fpx (tolerancia %.1fpx) sprite=%s" % [
			delta_ancla, TOLERANCIA_ANCLA_PX, ruta_sprite
		])

	print("[DIAG DISPENSADOR %s] grado=%d colocado=%s celdas=%s sprite=%s ancla_delta=%.2fpx  VEREDICTO: %s" % [
		etiqueta, grado, colocado_ok, celdas_reales, ruta_sprite.get_file(), delta_ancla,
		"PASA" if ok else "FALLA",
	])
	if not ok:
		for motivo: String in motivos:
			print("[DIAG DISPENSADOR %s]   -> %s" % [etiqueta, motivo])
	_veredictos[etiqueta] = ok

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta_png: String = "%sdispensador_rotacion_%s.png" % [CARPETA_SALIDA, etiqueta]
	var err: Error = sub.get_texture().get_image().save_png(ruta_png)
	if err != OK:
		push_error("[DIAG DISPENSADOR %s] save_png '%s' fallo (error %d)" % [etiqueta, ruta_png, err])
	else:
		print("[DIAG DISPENSADOR %s] -> %s" % [etiqueta, ruta_png])
	sub.queue_free()
