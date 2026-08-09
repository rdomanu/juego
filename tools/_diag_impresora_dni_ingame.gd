extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — LA IMPRESORA DE DNI COLOCADA DE VERDAD (2026-08-06).
##
## A diferencia de `_diag_rotacion_4.gd` (que solo prueba el FANTASMA/preview de la fotocopiadora),
## esta sonda coloca la impresora de DNI EN EL MODELO de verdad (`construir_de_oficio_elemento`,
## gratis, sin Economía) dentro de una `sala_documentacion` (tipo "oficina", admite familia
## "funcionario") y deja que el camino REAL de render (`Construccion._refrescar_visual` →
## `_crear_pieza` → `_pieza_sprite_comodidad`) la dibuje — no hay caja roja de preview en ninguna
## captura. Un mundo NUEVO por orientación (mismo criterio que `_diag_rotacion_4.gd`): la huella
## cambia de forma entre 0°/180° y 90°/270°, así que reconstruir evita arrastrar colisiones de la
## pasada anterior. Con un `equipo_informatico` (comodidad de 1 celda, sprite propio) vecino en
## diagonal para ver el orden de capas, y un muñeco de 44 px de referencia.
##
## PASA/FALLA, tres jueces por orientación:
##  · COLOCACIÓN: `construir_de_oficio_elemento` devuelve un id (no cae a caja roja: nunca se llama
##    a `validar_elemento` en falso — está dentro de una sala "oficina" de verdad).
##  · HUELLA: `celdas_de_elemento` son EXACTAMENTE las 2 celdas esperadas (2×1 en X para 0°/180°,
##    1×2 en Y para 90°/270°, requisito 1 de la tarea, verificado con el id real del catálogo).
##  · ANCLA DEL SPRITE (±3px): la posición real del `Sprite2D` en el árbol (encontrado por su
##    `resource_path`, no adivinado) contra `centro_en_pantalla(ANCLA) + delta_ultima_celda(paso,
##    celdas)` — la MISMA fórmula que usa `Construccion._pieza_sprite_comodidad` para plantarlo.
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(560, 480)

## Carpeta del scratchpad de ESTA sesión (fuera del repo).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

const TOLERANCIA_ANCLA_PX: float = 3.0

const CELDA_ANCLA := Vector2i(3, 3)
const CELDA_VECINO := Vector2i(4, 4)   # equipo_informatico, fuera de las 2 huellas posibles
const HERRAMIENTA := &"impresora_dni"

const ALTO_MUNECO_PX: int = 44

const ETIQUETAS := {0: "0_sur", 90: "90_oeste", 180: "180_norte", 270: "270_este"}

## Celdas esperadas por grado (ancla + su huella, requisito "0/180 una huella; 90/270 traspuesta").
const CELDAS_ESPERADAS := {
	0: [Vector2i(3, 3), Vector2i(4, 3)],
	180: [Vector2i(3, 3), Vector2i(4, 3)],
	90: [Vector2i(3, 3), Vector2i(3, 4)],
	270: [Vector2i(3, 3), Vector2i(3, 4)],
}

var _veredictos: Dictionary[String, bool] = {}


func _ready() -> void:
	for grado: int in [0, 90, 180, 270]:
		await _caso(grado)
	var fallos: int = 0
	for etiqueta: String in _veredictos:
		if not _veredictos[etiqueta]:
			fallos += 1
	print("[DIAG IMPRESORA DNI INGAME] RESUMEN: %d caso(s), %d FALLA(N) -> %s" % [
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
	construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(0, 0, 8, 8))

	# VECINO: otra comodidad con sprite propio, para ver el orden de capas (petición de la tarea).
	construccion.construir_de_oficio_elemento(&"equipo_informatico", CELDA_VECINO)

	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", ALTO_MUNECO_PX)
	muneco.position = construccion.centro_en_pantalla(CELDA_ANCLA + Vector2i(-2, 1))
	profundo.add_child(muneco)

	return [sub, construccion, profundo]


## Busca, recursivo, el primer `Sprite2D` cuya textura venga de un PNG de `impresora_dni`.
func _buscar_sprite_impresora(raiz: Node) -> Sprite2D:
	if raiz is Sprite2D and raiz.texture != null:
		var ruta: String = String(raiz.texture.resource_path)
		if ruta.contains("comodidad_impresora_dni_"):
			return raiz
	for hijo: Node in raiz.get_children():
		var hallado: Sprite2D = _buscar_sprite_impresora(hijo)
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

	# ── JUEZ 1: COLOCACIÓN (sala válida, no cae a preview/caja roja: esto ES el modelo real) ────
	var elemento_id: StringName = construccion.construir_de_oficio_elemento(
		HERRAMIENTA, CELDA_ANCLA, &"", grado
	)
	var colocado_ok: bool = elemento_id != &""
	if not colocado_ok:
		ok = false
		motivos.append("colocacion: construir_de_oficio_elemento devolvio id vacio (sala invalida)")

	# ── JUEZ 2: HUELLA 2×1 / 1×2 SEGÚN GRADO ──────────────────────────────────────────────────
	var huella_ok: bool = false
	var celdas_reales: Array = []
	if colocado_ok:
		celdas_reales = construccion.celdas_de_elemento(elemento_id)
		var esperadas: Array = CELDAS_ESPERADAS[grado]
		huella_ok = celdas_reales.size() == esperadas.size()
		if huella_ok:
			for i: int in esperadas.size():
				if celdas_reales[i] != esperadas[i]:
					huella_ok = false
					break
	if not huella_ok:
		ok = false
		motivos.append("huella: real=%s esperada=%s" % [celdas_reales, CELDAS_ESPERADAS[grado]])

	# ── JUEZ 3: ANCLA DEL SPRITE (±3px) ───────────────────────────────────────────────────────
	var ancla_ok: bool = false
	var delta_ancla: float = -1.0
	var ruta_sprite: String = "<no encontrado>"
	if colocado_ok:
		var sprite: Sprite2D = _buscar_sprite_impresora(profundo)
		if sprite != null:
			ruta_sprite = String(sprite.texture.resource_path)
			var paso: Vector2i = construccion._paso_de(grado)
			var esperada: Vector2 = (
				construccion.centro_en_pantalla(CELDA_ANCLA)
				+ ProyeccionScript.delta_ultima_celda(paso, 2)
			)
			var real: Vector2 = sprite.global_position
			delta_ancla = (real - esperada).length()
			ancla_ok = delta_ancla <= TOLERANCIA_ANCLA_PX
			var ruta_esperada: String = "res://assets/sprites/mobiliario/comodidad_impresora_dni_%d.png" % grado
			if ruta_sprite != ruta_esperada:
				ancla_ok = false
				motivos.append("sprite: real=%s esperado=%s" % [ruta_sprite, ruta_esperada])
	if not ancla_ok:
		ok = false
		motivos.append("ancla: delta=%.2fpx (tolerancia %.1fpx) sprite=%s" % [delta_ancla, TOLERANCIA_ANCLA_PX, ruta_sprite])

	print("[DIAG IMPRESORA DNI %s] grado=%d colocado=%s celdas=%s sprite=%s ancla_delta=%.2fpx  VEREDICTO: %s" % [
		etiqueta, grado, colocado_ok, celdas_reales, ruta_sprite.get_file(), delta_ancla,
		"PASA" if ok else "FALLA",
	])
	if not ok:
		for motivo: String in motivos:
			print("[DIAG IMPRESORA DNI %s]   -> %s" % [etiqueta, motivo])
	_veredictos[etiqueta] = ok

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta_png: String = "%simpresora_dni_ingame_%s.png" % [CARPETA_SALIDA, etiqueta]
	var err: Error = sub.get_texture().get_image().save_png(ruta_png)
	if err != OK:
		push_error("[DIAG IMPRESORA DNI %s] save_png '%s' fallo (error %d)" % [etiqueta, ruta_png, err])
	else:
		print("[DIAG IMPRESORA DNI %s] -> %s" % [etiqueta, ruta_png])
	sub.queue_free()
