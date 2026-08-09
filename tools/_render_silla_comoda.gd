extends "res://tools/render_mobiliario.gd"
## _render_silla_comoda — DESECHABLE (2026-08-07, ampliado 2026-08-07 2ª pasada). Renderiza
## `silla_ciudadano_comoda.glb` (Summer, `capturas/fuentes/mesa_ventanilla_summer/`), la silla de
## espera del tier "cómodo". 8 ROTACIONES (cada 45°, no solo las 4 cardinales) — mismo motivo que
## `_render_sillas_ciudadano.gd`: encontrar el giro que deja el respaldo detrás del ciudadano
## sentado mirando al norte (`design/art/lado-de-accion.md` §3).
## Mismo criterio de calibración por ALTO que `_render_sillas_ciudadano.gd` (una silla es un objeto
## que se juzga por su alto, no por su huella): ~1,00 m de alto real -> ~32 px con el factor de
## presencia del mobiliario (px = metros × 25,882 × 1,25 — `design/art/plan-escalado.md` §1).
##
## Escribe SOLO al scratchpad -- PROHIBIDO tocar `assets/sprites/mobiliario/`.

const CARPETA_ORIGEN := "res://capturas/fuentes/mesa_ventanilla_summer/"
const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
const FACTOR_PRESENCIA: float = 1.25
const ALTURA_OBJETIVO_M: float = 1.00

## Cada 45°, no cada 90° — ver la cabecera.
const ROTACIONES_8: Array[int] = [0, 45, 90, 135, 180, 225, 270, 315]

const MODELOS: Array[Dictionary] = [
	{"id": "silla_espera_comoda", "archivo": "silla_ciudadano_comoda.glb"},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA_SCRATCH)

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
		push_error("[SILLA COMODA] no se pudo cargar %s" % ruta)
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
	print("[SILLA COMODA] %s: %d MeshInstance3D cargadas" % [id, total])


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

	var objetivo_px: float = ALTURA_OBJETIVO_M * PX_POR_METRO * FACTOR_PRESENCIA
	print("[SILLA COMODA] px/metro efectivo = %.4f, objetivo alto = %.2f m -> %.2f px" % [
		PX_POR_METRO * FACTOR_PRESENCIA, ALTURA_OBJETIVO_M, objetivo_px
	])

	for modelo: Dictionary in MODELOS:
		var id: String = modelo["id"]
		var nombres: PackedStringArray = _nombres_de(todas, id)
		if nombres.is_empty():
			push_warning("[SILLA COMODA] %s: receta vacía -- se salta" % id)
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
		var escala_pieza: float = objetivo_px / float(maxi(alto_bruto_px, 1))
		print("[SILLA COMODA] %s: radio=%.3f m, bruto 0°=%dx%dpx (alto silueta=%dpx) -> factor=%.4f" % [
			id, radio, imagen_0.get_width(), imagen_0.get_height(), alto_bruto_px, escala_pieza
		])

		var escalados: Array[Dictionary] = [_escalar(bruto_0, escala_pieza)]
		for rot: int in ROTACIONES_8.slice(1):
			grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
			var bruto: Dictionary = await _renderizar_bruto()
			escalados.append(_escalar(bruto, escala_pieza))

		var compuesto: Dictionary = _componer(escalados)
		var imagenes: Array[Image] = compuesto["imagenes"]
		var ancla_final: Vector2 = compuesto["ancla"]
		for i: int in ROTACIONES_8.size():
			var ruta: String = "%s%s_%d.png" % [CARPETA_SCRATCH, id, ROTACIONES_8[i]]
			var err: Error = (imagenes[i] as Image).save_png(ruta)
			if err != OK:
				push_error("[SILLA COMODA] save_png '%s' fallo (error %d)" % [ruta, err])
			var img: Image = imagenes[i] as Image
			var alto_medido: int = _medir_alto(img)
			var dif: float = absf(float(alto_medido) - objetivo_px)
			print("[SILLA COMODA]   %s_%d.png: lienzo %dx%d px, ancla en (%.1f, %.1f), alto medido=%dpx (objetivo=%.1fpx, dif=%.1fpx) -> %s" % [
				id, ROTACIONES_8[i], compuesto["ancho"], compuesto["alto"],
				ancla_final.x, ancla_final.y, alto_medido, objetivo_px, dif,
				"PASA" if dif <= 3.0 else "FALLA"
			])
		print("[SILLA COMODA] %s: guardado -> %s%s_{0,45,90,...,315}.png" % [id, CARPETA_SCRATCH, id])

	print("[SILLA COMODA] hecho.")
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


func _fila_opaca(imagen: Image, py: int, ancho: int) -> bool:
	for px: int in range(ancho):
		if imagen.get_pixel(px, py).a > 0.01:
			return true
	return false
