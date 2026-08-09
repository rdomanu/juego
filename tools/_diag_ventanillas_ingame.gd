extends Node2D
## SONDA DESECHABLE (GPU, no headless) — lote de integración "tier básico" (2026-08-07).
##
## Monta la COMISARÍA INICIAL DE OFICIO real (mismo trazado que `Main._construir_comisaria_de_
## oficio`: `sala_documentacion` Rect2i(1,1,6,4) + `sala_espera_doc` Rect2i(1,6,6,4) + `puesto_doc_
## general` en (2,2)) con el `Construccion` y el `NPCsFlujo` REALES — cero copias de código de
## colocación, mismo patrón que `_diag_ventanilla2.gd` — y con el funcionario y la ciudadana
## SENTADOS de verdad en la ventanilla nueva (arte tier básico). Añade además, en la misma sala,
## las comodidades del lote (escritorio, 3 sillas de espera, vending) construidas con el catálogo
## real, y dos previsualizaciones SUELTAS (sin mecánica, solo el PNG) de las mesas media/pro.
##
## Uso:  godot --path <repo> res://tools/_diag_ventanillas_ingame.tscn
## Escribe 2 PNG al scratchpad y vuelca por consola un chequeo de anclaje (±3 px) de la mesa y las
## dos sillas de la ventanilla contra su posición ESPERADA (mismas fórmulas que `mesa_atencion.gd`).
## Se borra tras usarlo.

const MesaAtencionScript := preload("res://src/main/mesa_atencion.gd")
const MunecoScript := preload("res://src/main/muneco.gd")
const NPCScript := preload("res://src/main/npc_ciudadano.gd")
const NPCsFlujoScript := preload("res://src/main/npcs_flujo.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

const CELDA_PUESTO := Vector2i(2, 2)
const POS_SUELO := Vector2(500.0, 260.0)
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"
const NOMBRE_OFICIAL := "Ana Torres"

var _construccion: Node
var _flujo_visual: NPCsFlujo = null
var _muneco_ciudadano: Node2D = null


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.10, 0.10, 0.12)
	fondo.size = Vector2(1600, 900)
	fondo.z_index = -30
	add_child(fondo)

	# ── EL MUNDO REAL: Construcción + Economía + bus, mismo trazado de oficio que Main ─────────
	var bus: Node = EventBusScript.new()
	add_child(bus)
	var economia: Node = EconomiaScript.new()
	economia.aplicar_config(ConfigEconomiaScript.new())
	economia.saldo_eur = 1000000.0
	add_child(economia)
	_construccion = ConstruccionScript.new()
	_construccion.aplicar_config(ConfigConstruccionScript.new())
	_construccion.usar_economia(economia)
	_construccion.usar_bus(bus)
	add_child(_construccion)

	_construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(1, 1, 6, 4))
	_construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(1, 6, 6, 4))
	_construccion.construir_de_oficio_elemento(&"puesto_doc_general", CELDA_PUESTO, &"doc_1")

	# Comodidades del lote: escritorio+silla de oficina en la oficina (celdas libres, fuera del
	# bloque 2×3 del puesto); las 3 sillas de espera + vending en la sala de espera.
	_construccion.construir_elemento(&"escritorio_trabajo", Vector2i(5, 2))
	_construccion.construir_elemento(&"silla_oficina", Vector2i(5, 3))
	_construccion.construir_elemento(&"silla_espera_madera", Vector2i(2, 7))
	_construccion.construir_elemento(&"silla_espera_azul", Vector2i(3, 7))
	_construccion.construir_elemento(&"silla_espera_comoda", Vector2i(4, 7))
	_construccion.construir_elemento(&"vending", Vector2i(5, 7))

	var capa_profunda := Node2D.new()
	capa_profunda.name = "MundoProfundo"
	capa_profunda.y_sort_enabled = true
	add_child(capa_profunda)
	_construccion.montar_visual(Proyeccion.TAM_CELDA, POS_SUELO, capa_profunda)

	_flujo_visual = NPCsFlujoScript.new()
	_flujo_visual.name = "NPCsFlujo"
	add_child(_flujo_visual)
	_flujo_visual.configurar(
		null, _construccion, null, Proyeccion.TAM_CELDA, POS_SUELO, 24, 13, capa_profunda
	)
	_flujo_visual.set_physics_process(false)
	_flujo_visual.set_process(false)

	# ── EL CÓDIGO REAL DEL JUEGO: funcionario + ciudadana sentados de verdad ────────────────────
	_flujo_visual._asegurar_visual_puesto(&"doc_1", CELDA_PUESTO)
	var contenedor: Node2D = _flujo_visual._visual_de_puesto[&"doc_1"]
	var policia: Node2D = contenedor.get_node("Policia") as Node2D
	_flujo_visual._reconstruir_cuerpo_policia(contenedor, policia, NOMBRE_OFICIAL)

	_muneco_ciudadano = Node2D.new()
	_muneco_ciudadano.name = "MunecoCiudadano"
	var prefijo_civil: String = NPCScript.PREFIJOS_CIVIL[0]
	if MunecoScript.hay_sprites(prefijo_civil, NPCScript.ALTO_SPRITE):
		_muneco_ciudadano.add_child(
			MunecoScript.construir_sprite(prefijo_civil, NPCScript.ALTO_SPRITE)
		)
	else:
		_muneco_ciudadano.add_child(MunecoScript.construir(Color(0.35, 0.55, 0.9)))
	_muneco_ciudadano.set_meta(&"sentado", true)
	_flujo_visual.registrar_muneco(_muneco_ciudadano)
	_flujo_visual.marcar_frente_de_puesto(_muneco_ciudadano, true)
	var frente: Vector2 = Proyeccion.centro_cuadrado(CELDA_PUESTO + Vector2i(0, 1))
	_flujo_visual.colocar_muneco(_muneco_ciudadano, frente)

	# ── PREVIEWS SUELTAS de media/pro (SOLO arte, sin mecánica — ver el informe del lote) ──────
	_preview_suelta("ventanilla_media_0", Vector2(230.0, 560.0), "MEDIA (solo arte)")
	_preview_suelta("ventanilla_pro_0", Vector2(430.0, 560.0), "PRO (solo arte)")

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_chequeo_anclaje(contenedor)
	await RenderingServer.frame_post_draw
	_capturar("comisaria_tier_basico")
	_zoom_ventanilla(contenedor)
	_capturar("ventanilla_zoom")
	get_tree().quit()


func _preview_suelta(id_sprite: String, pos: Vector2, etiqueta: String) -> void:
	var ruta: String = "%s%s.png" % [MesaAtencionScript.RUTA_SPRITES_MOBILIARIO, id_sprite]
	if not ResourceLoader.exists(ruta):
		push_warning("[DIAG VENTANILLAS] falta preview '%s'" % ruta)
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(ruta)
	sprite.position = pos
	sprite.z_index = 5
	add_child(sprite)
	var etq := Label.new()
	etq.text = etiqueta
	etq.position = pos + Vector2(-40.0, 40.0)
	etq.add_theme_color_override("font_color", Color(1, 1, 1))
	etq.z_index = 5
	add_child(etq)


## Chequeo de anclaje: la mesa y las 2 sillas del puesto deben caer en su posición ESPERADA
## (recalculada de las constantes de `mesa_atencion.gd`, misma fórmula que `_diag_ventanilla2.gd`)
## con ±3 px de margen — no exacto, porque el auto-anclaje mide píxeles enteros del PNG.
func _chequeo_anclaje(contenedor: Node2D) -> void:
	var paso_sur: Vector2 = (
		Proyeccion.centro_iso(CELDA_PUESTO + Vector2i(0, 1)) - Proyeccion.centro_iso(CELDA_PUESTO)
	)
	var paso_norte: Vector2 = -paso_sur
	var esp_ciudadano: Vector2 = (
		paso_sur + paso_norte * MesaAtencionScript.ARRIME_CIUDADANO
		+ MesaAtencionScript.DESVIO_CENTRADO_ATENCION
	)
	var esp_funcionario: Vector2 = (
		paso_norte + paso_sur * MesaAtencionScript.ARRIME_FUNCIONARIO
		+ MesaAtencionScript.DESVIO_CENTRADO_ATENCION
	)
	var esp_tablero: Vector2 = (
		Proyeccion.delta_ultima_celda(Vector2i(1, 0), 2) + MesaAtencionScript.DESVIO_CENTRADO_MESA
	)
	print("========== DIAG VENTANILLAS INGAME (tier básico, 2026-08-07) ==========")
	print("celda puesto=%s  contenedor.global=%s" % [CELDA_PUESTO, contenedor.global_position])
	_linea3px("SillaCiudadano", contenedor, "SillaCiudadano", esp_ciudadano)
	_linea3px("SillaFuncionario", contenedor, "SillaFuncionario", esp_funcionario)
	var tablero: Node2D = contenedor.get_node_or_null("Mesa/Tablero") as Node2D
	if tablero != null:
		_linea("Mesa/Tablero", tablero.position, esp_tablero)
	else:
		print("  Mesa/Tablero              AUSENTE (sin sprite -- cae a la mesa de código)")
	print("=========================================================================")


func _linea3px(etiqueta: String, contenedor: Node2D, ruta: String, esperado: Vector2) -> void:
	var n: Node2D = contenedor.get_node_or_null(ruta) as Node2D
	if n == null:
		print("  %-24s AUSENTE" % etiqueta)
		return
	_linea(etiqueta, n.position, esperado)


func _linea(etiqueta: String, real: Vector2, esperado: Vector2) -> void:
	var d: Vector2 = real - esperado
	var marca: String = "PASA" if d.length() <= 3.0 else "FALLA"
	print("  %-24s real=(%.2f, %.2f)  esperado=(%.2f, %.2f)  delta=(%.2f, %.2f)  %s" % [
		etiqueta, real.x, real.y, esperado.x, esperado.y, d.x, d.y, marca
	])


func _zoom_ventanilla(contenedor: Node2D) -> void:
	get_viewport().get_camera_2d()
	var cam := Camera2D.new()
	cam.position = contenedor.global_position + Vector2(0.0, -10.0)
	cam.zoom = Vector2(3.0, 3.0)
	add_child(cam)
	cam.make_current()


func _capturar(etiqueta: String) -> void:
	var imagen: Image = get_viewport().get_texture().get_image()
	var ruta: String = "%sdiag_ventanillas_%s.png" % [CARPETA_SALIDA, etiqueta]
	var error: int = imagen.save_png(ruta)
	print("[DIAG VENTANILLAS] captura -> %s (err=%d)" % [ruta, error])
