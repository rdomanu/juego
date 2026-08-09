extends "res://tools/render_mobiliario.gd"
## Render AD-HOC (scratchpad) de las mesas de ventanilla sueltas de
## `capturas/fuentes/mesa_ventanilla_summer/`. Reutiliza el pipeline de
## `render_props_poly.gd` (cámara/luces/entorno/composición) pero:
##  - Escribe al SCRATCHPAD de la sesión, NO a `assets/sprites/mobiliario/`.
##  - Calibra por ALTURA REAL con el FACTOR DE PRESENCIA (×1,25) del mobiliario
##    (`design/art/plan-escalado.md` §1): px = metros × 25,882 × 1,25.
##  - Cada GLB es una única MeshInstance3D fusionada (verificado con
##    `_diag_mesa_separabilidad.gd`) — no hay receta que montar, solo cargar y medir.

const CARPETA_ORIGEN := "res://capturas/fuentes/mesa_ventanilla_summer/"
const SALIDA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
const FACTOR_PRESENCIA: float = 1.25

## Un modelo por fila: `id` de salida, archivo `.glb`, altura REAL (referencia, 0,75 m mesa de
## trabajo) y ancho objetivo en px (huella 2×1 celdas — calibración por ANCHO, no por alto: es
## mobiliario de huella fija, mismo criterio que `render_mobiliario.gd`/`ESCALA_OBJETIVO_MOSTRADOR`,
## NO el de `render_props_poly.gd` -- ese calibra por altura y es para aparatos sueltos sin huella
## de rejilla. Con este modelo, calibrar por ALTO daba ancho=26px muy por debajo del objetivo de
## 58px -- la huella (footprint) domina la silueta isométrica de un mueble bajo y ancho como una
## mesa, así que forzar el ALTO subescala también el ANCHO).
const MODELOS: Array[Dictionary] = [
	{"id": "mesa_pro", "archivo": "mesa_ventanilla_pro.glb", "altura_objetivo_m": 0.75, "ancho_objetivo_px": 58.0},
	# mesa_basica_v3_vacia — mesa vacía desgastada (Summer, 2026-08-06), última pieza del lote.
	# MISMA convención que mesa_pro: huella 2×1, calibrada por ANCHO (no por alto).
	{"id": "mesa_basica", "archivo": "mesa_ventanilla_basica_v3_vacia.glb", "altura_objetivo_m": 0.75, "ancho_objetivo_px": 58.0},
	# mesa_media_v2_vacia — mesa con mampara de cristal, tablero vacío (Summer, 2026-08-07), fase 2.
	# MISMA convención: huella 2×1, calibrada por ANCHO.
	{"id": "mesa_media", "archivo": "mesa_ventanilla_media_v2_vacia.glb", "altura_objetivo_m": 0.75, "ancho_objetivo_px": 58.0},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA_SCRATCH)

	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false

	var todas: Dictionary = {}
	for modelo: Dictionary in MODELOS:
		_cargar(contenedor, modelo, todas)

	_ejecutar(todas)


func _cargar(contenedor: Node3D, modelo: Dictionary, todas: Dictionary) -> void:
	var id: String = modelo["id"]
	var ruta: String = CARPETA_ORIGEN + (modelo["archivo"] as String)
	var escena: PackedScene = load(ruta)
	if escena == null:
		push_error("[MESA VENTANILLA] no se pudo cargar %s" % ruta)
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
		todas["%s__%s" % [id, mi.name]] = {
			"malla": mi.mesh,
			"transform": mi.global_transform,
			"material_override": mi.material_override,
			"overrides": overrides,
		}
		total += 1
	print("[MESA VENTANILLA] %s: %d MeshInstance3D cargadas" % [id, total])


func _nombres_de(todas: Dictionary, id: String) -> PackedStringArray:
	var prefijo: String = id + "__"
	var resultado := PackedStringArray()
	for clave: String in todas.keys():
		if (clave as String).begins_with(prefijo):
			resultado.append(clave)
	return resultado


func _ejecutar(todas: Dictionary) -> void:
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

	print("[MESA VENTANILLA] px/metro base = %.4f, factor presencia = %.2f -> efectivo = %.4f" % [
		PX_POR_METRO, FACTOR_PRESENCIA, PX_POR_METRO * FACTOR_PRESENCIA
	])

	for modelo: Dictionary in MODELOS:
		var id: String = modelo["id"]
		var altura_objetivo_m: float = modelo["altura_objetivo_m"]
		var nombres: PackedStringArray = _nombres_de(todas, id)
		if nombres.is_empty():
			push_warning("[MESA VENTANILLA] %s: receta vacía -- se salta" % id)
			continue
		var receta: Dictionary = {"id_salida": id, "nombres": nombres}

		var ancla: Vector3 = _ancla_de(receta, todas)
		var radio: float = _radio_de(receta, todas, ancla)
		_montar_receta(grupo, receta, todas, ancla)
		_colocar_camara(radio * 2.0 * MARGEN)

		grupo.rotation = Vector3.ZERO
		var bruto_0: Dictionary = await _renderizar_bruto()
		var imagen_0: Image = bruto_0["imagen"]
		var alto_bruto_px: int = _medir_alto(imagen_0)
		var ancho_bruto_px: int = _medir_ancho(imagen_0)
		var ancho_objetivo_px: float = modelo["ancho_objetivo_px"]
		var escala_pieza: float = ancho_objetivo_px / float(maxi(ancho_bruto_px, 1))
		var objetivo_px_alto_referencia: float = altura_objetivo_m * PX_POR_METRO * FACTOR_PRESENCIA
		print("[MESA VENTANILLA] %s: radio=%.3f m, bruto 0°=%dx%dpx (alto silueta=%dpx, ancho silueta=%dpx), CALIBRA POR ANCHO->objetivo=%.1fpx -> factor=%.4f (referencia alto por altura real 0,75m*presencia = %.1fpx, NO es la que manda)" % [
			id, radio, imagen_0.get_width(), imagen_0.get_height(), alto_bruto_px, ancho_bruto_px,
			ancho_objetivo_px, escala_pieza, objetivo_px_alto_referencia
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
			var ruta: String = "%s%s_%d.png" % [SALIDA_SCRATCH, id, ROTACIONES[i]]
			var err: Error = (imagenes[i] as Image).save_png(ruta)
			if err != OK:
				push_error("[MESA VENTANILLA] save_png '%s' fallo (error %d)" % [ruta, err])
			var img: Image = imagenes[i] as Image
			var ancho_util: int = _medir_ancho(img)
			print("[MESA VENTANILLA]   %s_%d.png: lienzo %dx%d px, ancla en (%.1f, %.1f), alto_util=%dpx, ancho_util=%dpx" % [
				id, ROTACIONES[i], compuesto["ancho"], compuesto["alto"],
				ancla_final.x, ancla_final.y, _medir_alto(img), ancho_util
			])
		print("[MESA VENTANILLA] %s: guardado -> %s%s_{0,90,180,270}.png" % [id, SALIDA_SCRATCH, id])

	print("[MESA VENTANILLA] hecho.")
	get_tree().quit()


func _medir_alto(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_y := -1
	for py: int in range(alto):
		if _fila_opaca(imagen, py, ancho):
			min_y = py
			break
	if min_y < 0:
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if _fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1


func _medir_ancho(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_x := -1
	var max_x := -1
	for px: int in range(ancho):
		if _columna_opaca(imagen, px, alto):
			if min_x < 0:
				min_x = px
			max_x = px
	if min_x < 0:
		return ancho
	return max_x - min_x + 1


func _fila_opaca(imagen: Image, py: int, ancho: int) -> bool:
	for px: int in range(ancho):
		if imagen.get_pixel(px, py).a > 0.01:
			return true
	return false


func _columna_opaca(imagen: Image, px: int, alto: int) -> bool:
	for py: int in range(alto):
		if imagen.get_pixel(px, py).a > 0.01:
			return true
	return false
