extends "res://tools/render_mobiliario.gd"
## _render_crt_antiguo — DESECHABLE (2026-08-07). Renderiza `crt_antiguo.glb` (CRT beige 90s +
## torre + teclado, 1 sola malla fusionada) calibrado por la ALTURA DEL MONITOR (~0,40 m -> ~13 px,
## medido en el render bruto de inspección: seam monitor/torre en fila≈130px de 247px totales a
## 0° -- `_zoom_crt_0_grid.png`, scratchpad), NO por la altura total del conjunto (que incluye la
## torre, más alta que el monitor solo). El resto (torre/teclado) escala PROPORCIONAL al mismo
## factor -- un único factor de escala para toda la pieza rígida.
##
## Escribe SOLO al scratchpad -- PROHIBIDO tocar assets/sprites/mobiliario/.

const CARPETA_ORIGEN := "res://capturas/fuentes/mesa_ventanilla_summer/"
const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

## Medido a mano sobre `_zoom_crt_0_grid.png` (render bruto 246x247px a 0°): el monitor ocupa desde
## la fila 0 (su parte de arriba) hasta la fila ~130 (el reborde donde termina la carcasa beige del
## monitor y empieza la torre, gris más clara, debajo). Ver ese PNG para el criterio visual.
const MONITOR_RAW_PX: float = 130.0
const MONITOR_OBJETIVO_M: float = 0.40
const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
const FACTOR_PRESENCIA: float = 1.25
const MONITOR_OBJETIVO_PX: float = MONITOR_OBJETIVO_M * PX_POR_METRO * FACTOR_PRESENCIA  # ~13px

const ID_SALIDA := "crt_antiguo"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA_SCRATCH)
	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false

	var todas: Dictionary = {}
	var escena: PackedScene = load(CARPETA_ORIGEN + "crt_antiguo.glb")
	if escena == null:
		push_error("[CRT ANTIGUO] no se pudo cargar el GLB")
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
			"malla": mi.mesh, "transform": mi.global_transform,
			"material_override": mi.material_override, "overrides": overrides,
		}
		total += 1
	print("[CRT ANTIGUO] %d MeshInstance3D cargadas" % total)

	_ejecutar(todas)


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

	var nombres := PackedStringArray()
	for clave: String in todas.keys():
		nombres.append(clave)
	var receta: Dictionary = {"id_salida": ID_SALIDA, "nombres": nombres}
	var ancla: Vector3 = _ancla_de(receta, todas)
	var radio: float = _radio_de(receta, todas, ancla)
	_montar_receta(grupo, receta, todas, ancla)
	_colocar_camara(radio * 2.0 * MARGEN)

	var escala: float = MONITOR_OBJETIVO_PX / MONITOR_RAW_PX
	print("[CRT ANTIGUO] monitor bruto=%.0fpx -> objetivo=%.2fpx (0,40m*presencia) -> factor=%.4f" % [
		MONITOR_RAW_PX, MONITOR_OBJETIVO_PX, escala
	])

	var escalados: Array[Dictionary] = []
	for rot: int in ROTACIONES:
		grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
		var bruto: Dictionary = await _renderizar_bruto()
		escalados.append(_escalar(bruto, escala))

	var compuesto: Dictionary = _componer(escalados)
	var imagenes: Array[Image] = compuesto["imagenes"]
	for i: int in ROTACIONES.size():
		var ruta: String = "%s%s_%d.png" % [CARPETA_SCRATCH, ID_SALIDA, ROTACIONES[i]]
		(imagenes[i] as Image).save_png(ruta)
		var img: Image = imagenes[i] as Image
		print("[CRT ANTIGUO]   %s_%d.png: %dx%d px -> %s" % [
			ID_SALIDA, ROTACIONES[i], img.get_width(), img.get_height(), ruta
		])

	print("[CRT ANTIGUO] hecho.")
	get_tree().quit()
