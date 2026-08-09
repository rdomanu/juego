extends "res://tools/render_mobiliario.gd"
## _render_fuente_agua_160 — DESECHABLE (2026-08-06). Re-render de `fuente_agua.glb`
## (`capturas/fuentes/props_poly/`, Water Cooler de poly.pizza, ya importado) a la altura FINAL
## decidida por el usuario (2026-08-05, ver `design/art/plan-escalado.md` §3, nota "Fuente de
## agua"): 1,60 m real × FACTOR_PRESENCIA 1,25 -- el sprite integrado hoy en
## `assets/sprites/mobiliario/fuente_agua_*.png` sigue siendo el render VIEJO a 1,20 m, sin el
## factor de presencia. Es la pieza "B" de la hoja comparativa contra el dispensador azul ya
## integrado ("A") -- para que el usuario decida cuál de los dos sobrevive a la unificación.
##
## Mismo pipeline que `_render_kaykit_poly.gd` (cámara/luces heredadas de `render_mobiliario.gd`).
## Escribe SOLO `fuente_agua_160_{0,90,180,270}.png` al scratchpad de esta sesión.

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
const FACTOR_PRESENCIA: float = 1.25

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"
const RUTA_MODELO := "res://capturas/fuentes/props_poly/fuente_agua.glb"
const ID_SALIDA := "fuente_agua_160"
const ALTURA_OBJETIVO_M: float = 1.60


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA_SCRATCH)

	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false

	var todas: Dictionary = {}
	var escena: PackedScene = load(RUTA_MODELO)
	if escena == null:
		push_error("[FUENTE 160] no se pudo cargar %s" % RUTA_MODELO)
		get_tree().quit(1)
		return
	var raiz: Node3D = escena.instantiate()
	contenedor.add_child(raiz)
	var total := 0
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var overrides: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		todas["%s__%s" % [ID_SALIDA, mi.name]] = {
			"malla": mi.mesh,
			"transform": mi.global_transform,
			"material_override": mi.material_override,
			"overrides": overrides,
		}
		total += 1
	print("[FUENTE 160] %d MeshInstance3D cargadas (%s)" % [total, RUTA_MODELO])

	_ejecutar_fuente(todas)


func _ejecutar_fuente(todas: Dictionary) -> void:
	_sub = SubViewport.new()
	_sub.size = Vector2i(TAM_RENDER, TAM_RENDER)
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.own_world_3d = true
	add_child(_sub)

	var mundo := Node3D.new()
	_sub.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sol.light_energy = 1.1
	mundo.add_child(sol)
	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.9
	entorno.environment = env
	mundo.add_child(entorno)

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	mundo.add_child(_camara)

	var grupo := Node3D.new()
	mundo.add_child(grupo)

	var objetivo_px: float = ALTURA_OBJETIVO_M * PX_POR_METRO * FACTOR_PRESENCIA
	var nombres := PackedStringArray()
	for clave: String in todas.keys():
		nombres.append(clave)
	var receta: Dictionary = {"id_salida": ID_SALIDA, "nombres": nombres}

	var ancla: Vector3 = _ancla_de(receta, todas)
	var radio: float = _radio_de(receta, todas, ancla)
	_montar_receta(grupo, receta, todas, ancla)
	_colocar_camara(radio * 2.0 * MARGEN)

	grupo.rotation = Vector3.ZERO
	var bruto_0: Dictionary = await _renderizar_bruto()
	var imagen_0: Image = bruto_0["imagen"]
	var alto_bruto_px: int = _medir_alto(imagen_0)
	var escala_pieza: float = objetivo_px / float(maxi(alto_bruto_px, 1))
	print("[FUENTE 160] radio=%.3f m, bruto 0°=%dx%dpx (alto silueta=%dpx), objetivo=%.2fm×%.2f->%.1fpx -> factor=%.4f" % [
		radio, imagen_0.get_width(), imagen_0.get_height(), alto_bruto_px,
		ALTURA_OBJETIVO_M, FACTOR_PRESENCIA, objetivo_px, escala_pieza
	])

	var escalados: Array[Dictionary] = [_escalar(bruto_0, escala_pieza)]
	for rot: int in [90, 180, 270]:
		grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
		var bruto: Dictionary = await _renderizar_bruto()
		escalados.append(_escalar(bruto, escala_pieza))

	var compuesto: Dictionary = _componer(escalados)
	var imagenes: Array[Image] = compuesto["imagenes"]
	var ancla_final: Vector2 = compuesto["ancla"]
	for i: int in ROTACIONES.size():
		var ruta: String = "%s%s_%d.png" % [CARPETA_SCRATCH, ID_SALIDA, ROTACIONES[i]]
		var err: Error = (imagenes[i] as Image).save_png(ruta)
		if err != OK:
			push_error("[FUENTE 160] save_png '%s' fallo (error %d)" % [ruta, err])
		var alto_medido: int = _medir_alto(imagenes[i] as Image)
		print("[FUENTE 160]   %s_%d.png: lienzo %dx%d px, ancla en (%.1f, %.1f), alto medido=%dpx (objetivo=%.1fpx, |dif|=%.1fpx -> %s)" % [
			ID_SALIDA, ROTACIONES[i], compuesto["ancho"], compuesto["alto"],
			ancla_final.x, ancla_final.y, alto_medido, objetivo_px, absf(float(alto_medido) - objetivo_px),
			"PASA" if absf(float(alto_medido) - objetivo_px) <= 3.0 else "FALLA"
		])
	print("[FUENTE 160] guardado -> %s%s_{0,90,180,270}.png" % [CARPETA_SCRATCH, ID_SALIDA])
	print("[FUENTE 160] hecho.")
	get_tree().quit()


func _medir_alto(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_y := -1
	for py: int in range(alto):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			min_y = py
			break
	if min_y < 0:
		push_warning("[FUENTE 160] silueta totalmente transparente")
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1
