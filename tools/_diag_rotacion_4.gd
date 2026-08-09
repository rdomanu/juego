extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — LAS 4 ORIENTACIONES REALES (2026-08-06,
## `src/main/modo_construccion.gd`/`src/core/construccion/construccion.gd`: R cicla 0→90→180→270,
## `PreviewOrientacion`/`_colocar_triangulo_orientacion`, `rotacion_directa`).
##
## Monta un `ModoConstruccion` REAL sobre una `Construccion` real (sin mocks), con la fotocopiadora
## (`impresora_documentos`, la ÚNICA comodidad con 4 vistas reales hoy) EN MANO, en las 4
## orientaciones del ciclo de R (`Construccion.ORIENTACIONES_CICLO`), con un muñeco de 44 px de
## referencia y la REJILLA del modo encendida. UN PNG por orientación.
##
## PASA/FALLA, tres jueces por orientación (los tres pedidos por la tarea):
##  · SPRITE ELEGIDO: `_preview_sprite.texture.resource_path` == el PNG del grado literal
##    (`comodidad_impresora_documentos_<grado>.png`) — la fotocopiadora tiene `rotacion_directa`
##    (`Construccion._sprites_comodidad()`), así que el PNG que toca es el grado sin más vuelta.
##  · HUELLA (ancla): con `superficie == 1` la huella no cambia de FORMA entre orientaciones (eso ya
##    lo prueba `construccion_orientacion_4_test.gd` con un mueble de 3 celdas) — aquí se comprueba
##    que el SPRITE de 1 celda no DERIVA de su ancla lógica al girar (`Proyeccion.delta_ultima_celda`
##    da `ZERO` con `celdas == 1`, para cualquier `paso`): la posición en pantalla del sprite debe
##    ser exactamente `centro_en_pantalla(CELDA_ANCLA)` en las 4.
##  · ÁPICE DEL TRIÁNGULO: mismo juez que `_diag_triangulo_orientacion.gd` — la posición REAL del
##    ápice contra la fórmula recalculada aquí de forma independiente, delta ≤ 3 px.
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(560, 480)

## Carpeta del scratchpad de ESTA sesión (fuera del repo — PROHIBIDO escribir en assets/capturas/).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

## Tolerancia pactada en la tarea: ±3 px (ápice del triángulo).
const TOLERANCIA_PX: float = 3.0
## Tolerancia del ancla del sprite (debe caer EXACTA, un `Vector2` sin redondeos de por medio).
const TOLERANCIA_ANCLA_PX: float = 0.5

const CELDA_ANCLA := Vector2i(3, 3)
const HERRAMIENTA := &"impresora_documentos"

## La escala del muñeco de referencia (convención del proyecto: 44 px == 1,70 m).
const ALTO_MUNECO_PX: int = 44

## Etiqueta legible por grado — para el nombre del PNG y los mensajes de consola.
const ETIQUETAS := {0: "0_sur", 90: "90_oeste", 180: "180_norte", 270: "270_este"}

var _veredictos: Dictionary[String, bool] = {}


func _ready() -> void:
	for grado: int in ConstruccionScript.ORIENTACIONES_CICLO:
		await _caso(grado)
	var fallos: int = 0
	for etiqueta: String in _veredictos:
		if not _veredictos[etiqueta]:
			fallos += 1
	print("[DIAG ROTACION 4] RESUMEN: %d caso(s), %d FALLA(N) -> %s" % [
		_veredictos.size(), fallos, "PASA" if fallos == 0 else "FALLA"
	])
	get_tree().quit()


## Una sala de descanso (admite la fotocopiadora: familia `funcionario`, comodidad de catálogo
## general) con margen generoso alrededor de `CELDA_ANCLA`, sin cámara (mundo == pantalla, mismo
## criterio que `_diag_triangulo_orientacion.gd`), con un muñeco de 44 px y la rejilla ENCENDIDA.
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
	construccion.montar_visual(TAM_CELDA, Vector2(200.0, 60.0), profundo)
	var sala: StringName = construccion.construir_de_oficio_sala(
		&"sala_descanso", Rect2i(0, 0, 8, 8)
	)
	construccion.fijar_paredes_de_sala(sala, false)

	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", ALTO_MUNECO_PX)
	muneco.position = construccion.centro_en_pantalla(CELDA_ANCLA + Vector2i(-2, 2))
	profundo.add_child(muneco)

	var modo: Node = ModoConstruccionScript.new()
	modo.configurar(construccion, TAM_CELDA)
	mundo.add_child(modo)
	modo.set_process(false)   # GOTCHA CONOCIDO: `_process` pisaría el estado forzado a mano
	modo._activo = true
	modo._es_sala = false
	modo._rejilla.visible = true
	modo._atenuador.visible = true
	modo._dialogo_cascada.hide()
	return [sub, construccion, modo]


## La fórmula del ápice, RECALCULADA de forma independiente — mismo criterio que
## `_diag_triangulo_orientacion.gd`.
func _apice_esperado(construccion: Node, modo: Node, frente: Vector2i) -> Vector2:
	var frente_f := Vector2(frente)
	var centro_huella: Vector2 = (Vector2(CELDA_ANCLA) + Vector2(1, 1) * 0.5) * float(TAM_CELDA)
	var semiancho: float = 0.5 * float(TAM_CELDA)   # huella 1×1: mismo semiancho en los dos ejes
	var base_centro: Vector2 = (
		centro_huella + frente_f * (semiancho + modo.MARGEN_TRIANGULO_ORIENTACION)
	)
	var apice_cuadrado: Vector2 = base_centro + frente_f * modo.LARGO_TRIANGULO_ORIENTACION
	return construccion.esquina_en_pantalla(0, 0) + ProyeccionScript.proyectar(apice_cuadrado)


func _caso(grado: int) -> void:
	var etiqueta: String = ETIQUETAS[grado]
	var piezas: Array = _montar()
	var sub: SubViewport = piezas[0]
	var construccion: Node = piezas[1]
	var modo: Node = piezas[2]

	modo._herramienta = HERRAMIENTA
	modo._orientacion = grado
	modo._preview_caja.visible = true
	modo._preview_texto.visible = true
	modo._preview_sprite.visible = false
	modo._refrescar_preview_elemento(CELDA_ANCLA)

	var ok: bool = true
	var motivos: PackedStringArray = PackedStringArray()

	# ── JUEZ 1: SPRITE ELEGIDO ──────────────────────────────────────────────────────────────
	var ruta_esperada: String = "res://assets/sprites/mobiliario/comodidad_impresora_documentos_%d.png" % grado
	var textura: Texture2D = modo._preview_sprite.texture
	var ruta_real: String = String(textura.resource_path) if textura != null else "<null>"
	var sprite_ok: bool = modo._preview_sprite.visible and ruta_real == ruta_esperada
	if not sprite_ok:
		ok = false
		motivos.append("sprite: real=%s esperado=%s (visible=%s)" % [
			ruta_real, ruta_esperada, modo._preview_sprite.visible,
		])

	# ── JUEZ 2: HUELLA (ancla del sprite de 1 celda, no debe derivar entre orientaciones) ────
	var ancla_esperada: Vector2 = construccion.centro_en_pantalla(CELDA_ANCLA)
	var ancla_real: Vector2 = modo._preview_sprite.position
	var delta_ancla: float = (ancla_real - ancla_esperada).length()
	var ancla_ok: bool = delta_ancla <= TOLERANCIA_ANCLA_PX
	if not ancla_ok:
		ok = false
		motivos.append("ancla: real=%s esperada=%s delta=%.2fpx" % [ancla_real, ancla_esperada, delta_ancla])

	# ── JUEZ 3: ÁPICE DEL TRIÁNGULO ───────────────────────────────────────────────────────────
	var frente: Vector2i = modo._frente_de_orientacion(grado)
	var apice_esperado: Vector2 = _apice_esperado(construccion, modo, frente)
	var visible_tri: bool = modo._preview_triangulo.visible
	var puntos: PackedVector2Array = modo._preview_triangulo._puntos
	var triangulo_ok: bool = false
	var delta_apice: float = -1.0
	if visible_tri and puntos.size() >= 3:
		var apice_real: Vector2 = puntos[0]
		delta_apice = (apice_real - apice_esperado).length()
		triangulo_ok = delta_apice <= TOLERANCIA_PX
	if not triangulo_ok:
		ok = false
		motivos.append("triangulo: visible=%s delta_apice=%.2fpx" % [visible_tri, delta_apice])

	print("[DIAG ROTACION 4 %s] grado=%d frente=%s sprite=%s ancla_delta=%.2fpx apice_delta=%.2fpx  VEREDICTO: %s" % [
		etiqueta, grado, frente, ruta_real.get_file(), delta_ancla, delta_apice,
		"PASA" if ok else "FALLA",
	])
	if not ok:
		for motivo: String in motivos:
			print("[DIAG ROTACION 4 %s]   -> %s" % [etiqueta, motivo])
	_veredictos[etiqueta] = ok

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta_png: String = "%srotacion4_%s.png" % [CARPETA_SALIDA, etiqueta]
	var err: Error = sub.get_texture().get_image().save_png(ruta_png)
	if err != OK:
		push_error("[DIAG ROTACION 4 %s] save_png '%s' fallo (error %d)" % [etiqueta, ruta_png, err])
	else:
		print("[DIAG ROTACION 4 %s] -> %s" % [etiqueta, ruta_png])
	sub.queue_free()
