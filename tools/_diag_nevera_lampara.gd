extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — NEVERA + LÁMPARA DE PIE (2026-08-06, arte KayKit).
##
## Coloca las DOS piezas de verdad (`construir_de_oficio_elemento`, gratis, sin Economía) dentro de
## una `sala_descanso` (única sala que admite `nevera`, familia "descanso"; `lampara_pie`, familia
## "iluminacion", vale en cualquiera), con un `dispensador_agua` vecino (comodidad con sprite propio
## ya en uso) para ver el orden de capas y un muñeco de 44 px de referencia. Un mundo NUEVO por
## orientación de la nevera (0/90/180/270, `rotacion_directa`); la lámpara se coloca EN LA MISMA
## orientación que la nevera de cada caso a propósito — confirma que su pose es FIJA (siempre
## `comodidad_lampara_pie_0.png`, sin "frente" que enseñar) igual que `equipo_informatico`/
## `dispensador_agua`/`radio`/`papelera` (`COMODIDADES_CON_SPRITE`, no `_ROTACION_DIRECTA`).
##
## PASA/FALLA, por caso (4):
##  · NEVERA: colocada, huella EXACTA 1 celda (superficie=1 en su `.tres`, sin traspuesta), sprite
##    == `comodidad_nevera_<grado>.png` (rotación directa), ancla del `Sprite2D` real (encontrado por
##    `resource_path`) a ≤3px de `centro_en_pantalla(ANCLA)` (celdas=1 → `delta_ultima_celda` es CERO).
##  · LÁMPARA: colocada, huella EXACTA 1 celda, sprite SIEMPRE `comodidad_lampara_pie_0.png` (pose
##    fija, no varía con la orientación), ancla ≤3px de `centro_en_pantalla(ANCLA_LAMPARA)`.
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

const CELDA_NEVERA := Vector2i(3, 3)
const CELDA_LAMPARA := Vector2i(5, 3)
const CELDA_VECINO := Vector2i(3, 5)   # dispensador_agua, fuera de las dos huellas
const HERRAMIENTA_NEVERA := &"nevera"
const HERRAMIENTA_LAMPARA := &"lampara_pie"

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
	print("[DIAG NEVERA+LAMPARA] RESUMEN: %d caso(s), %d FALLA(N) -> %s" % [
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

	# VECINO: comodidad con sprite propio ya en uso, para ver el orden de capas.
	construccion.construir_de_oficio_elemento(&"dispensador_agua", CELDA_VECINO)

	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", ALTO_MUNECO_PX)
	muneco.position = construccion.centro_en_pantalla(CELDA_NEVERA + Vector2i(-2, 1))
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

	# ── NEVERA ─────────────────────────────────────────────────────────────────────────────────
	var id_nevera: StringName = construccion.construir_de_oficio_elemento(
		HERRAMIENTA_NEVERA, CELDA_NEVERA, &"", grado
	)
	var nevera_colocada: bool = id_nevera != &""
	if not nevera_colocada:
		ok = false
		motivos.append("nevera: construir_de_oficio_elemento devolvio id vacio")

	var nevera_huella_ok: bool = false
	var celdas_nevera: Array = []
	if nevera_colocada:
		celdas_nevera = construccion.celdas_de_elemento(id_nevera)
		nevera_huella_ok = celdas_nevera.size() == 1 and celdas_nevera[0] == CELDA_NEVERA
	if not nevera_huella_ok:
		ok = false
		motivos.append("nevera huella: real=%s esperada=[%s]" % [celdas_nevera, CELDA_NEVERA])

	var nevera_ancla_ok: bool = false
	var delta_nevera: float = -1.0
	var ruta_nevera: String = "<no encontrado>"
	if nevera_colocada:
		var sprite_nevera: Sprite2D = _buscar_sprite(profundo, "comodidad_nevera_")
		if sprite_nevera != null:
			ruta_nevera = String(sprite_nevera.texture.resource_path)
			var esperada_ruta: String = "res://assets/sprites/mobiliario/comodidad_nevera_%d.png" % grado
			var esperada_pos: Vector2 = construccion.centro_en_pantalla(CELDA_NEVERA)
			var real_pos: Vector2 = sprite_nevera.global_position
			delta_nevera = (real_pos - esperada_pos).length()
			nevera_ancla_ok = delta_nevera <= TOLERANCIA_ANCLA_PX and ruta_nevera == esperada_ruta
			if ruta_nevera != esperada_ruta:
				motivos.append("nevera sprite: real=%s esperado=%s" % [ruta_nevera, esperada_ruta])
	if not nevera_ancla_ok:
		ok = false
		motivos.append("nevera ancla: delta=%.2fpx (tolerancia %.1fpx) sprite=%s" % [
			delta_nevera, TOLERANCIA_ANCLA_PX, ruta_nevera
		])

	# ── LÁMPARA DE PIE (pose fija: SIEMPRE _0, incluso colocada con la misma orientación `grado`) ──
	var id_lampara: StringName = construccion.construir_de_oficio_elemento(
		HERRAMIENTA_LAMPARA, CELDA_LAMPARA, &"", grado
	)
	var lampara_colocada: bool = id_lampara != &""
	if not lampara_colocada:
		ok = false
		motivos.append("lampara: construir_de_oficio_elemento devolvio id vacio")

	var lampara_huella_ok: bool = false
	var celdas_lampara: Array = []
	if lampara_colocada:
		celdas_lampara = construccion.celdas_de_elemento(id_lampara)
		lampara_huella_ok = celdas_lampara.size() == 1 and celdas_lampara[0] == CELDA_LAMPARA
	if not lampara_huella_ok:
		ok = false
		motivos.append("lampara huella: real=%s esperada=[%s]" % [celdas_lampara, CELDA_LAMPARA])

	var lampara_ancla_ok: bool = false
	var delta_lampara: float = -1.0
	var ruta_lampara: String = "<no encontrado>"
	if lampara_colocada:
		var sprite_lampara: Sprite2D = _buscar_sprite(profundo, "comodidad_lampara_pie_")
		if sprite_lampara != null:
			ruta_lampara = String(sprite_lampara.texture.resource_path)
			var esperada_ruta_l: String = "res://assets/sprites/mobiliario/comodidad_lampara_pie_0.png"
			var esperada_pos_l: Vector2 = construccion.centro_en_pantalla(CELDA_LAMPARA)
			var real_pos_l: Vector2 = sprite_lampara.global_position
			delta_lampara = (real_pos_l - esperada_pos_l).length()
			lampara_ancla_ok = delta_lampara <= TOLERANCIA_ANCLA_PX and ruta_lampara == esperada_ruta_l
			if ruta_lampara != esperada_ruta_l:
				motivos.append("lampara sprite: real=%s esperado=%s (pose fija, NO rotacion_directa)" % [
					ruta_lampara, esperada_ruta_l
				])
	if not lampara_ancla_ok:
		ok = false
		motivos.append("lampara ancla: delta=%.2fpx (tolerancia %.1fpx) sprite=%s" % [
			delta_lampara, TOLERANCIA_ANCLA_PX, ruta_lampara
		])

	print(
		"[DIAG NEVERA+LAMPARA %s] grado=%d nevera_colocada=%s nevera_celdas=%s nevera_sprite=%s "
		% [etiqueta, grado, nevera_colocada, celdas_nevera, ruta_nevera.get_file()]
		+ "nevera_delta=%.2fpx | lampara_colocada=%s lampara_celdas=%s lampara_sprite=%s lampara_delta=%.2fpx  VEREDICTO: %s"
		% [
			delta_nevera, lampara_colocada, celdas_lampara, ruta_lampara.get_file(), delta_lampara,
			"PASA" if ok else "FALLA",
		]
	)
	if not ok:
		for motivo: String in motivos:
			print("[DIAG NEVERA+LAMPARA %s]   -> %s" % [etiqueta, motivo])
	_veredictos[etiqueta] = ok

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta_png: String = "%snevera_lampara_%s.png" % [CARPETA_SALIDA, etiqueta]
	var err: Error = sub.get_texture().get_image().save_png(ruta_png)
	if err != OK:
		push_error("[DIAG NEVERA+LAMPARA %s] save_png '%s' fallo (error %d)" % [etiqueta, ruta_png, err])
	else:
		print("[DIAG NEVERA+LAMPARA %s] -> %s" % [etiqueta, ruta_png])
	sub.queue_free()
