extends "res://tools/render_mobiliario.gd"
## _render_crt_mesa_media — DESECHABLE (2026-08-07). Renderiza en BRUTO (sin recorte de escala
## final, solo el auto-encuadre de `_colocar_camara`) `crt_antiguo.glb` y
## `mesa_ventanilla_media_v2_vacia.glb`, las 4 rotaciones, a un factor de escala PROVISIONAL
## (`ESCALA_INSPECCION`, generoso) para poder MEDIR a ojo en el PNG resultante qué fracción de la
## altura total es el monitor del CRT y en qué borde cae la mampara de la mesa media -- antes de
## fijar la calibración definitiva de cada pieza.
##
## Escribe SOLO al scratchpad.

const CARPETA_ORIGEN := "res://capturas/fuentes/mesa_ventanilla_summer/"
const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

const MODELOS: Array[Dictionary] = [
	{"id": "_inspeccion_crt", "archivo": "crt_antiguo.glb"},
	{"id": "_inspeccion_mesa_media", "archivo": "mesa_ventanilla_media_v2_vacia.glb"},
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
		push_error("[INSPECCION] no se pudo cargar %s" % ruta)
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
			"malla": mi.mesh, "transform": mi.global_transform,
			"material_override": mi.material_override, "overrides": overrides,
		}
		total += 1
	print("[INSPECCION] %s: %d MeshInstance3D" % [id, total])


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

	for modelo: Dictionary in MODELOS:
		var id: String = modelo["id"]
		var nombres: PackedStringArray = _nombres_de(todas, id)
		if nombres.is_empty():
			continue
		var receta: Dictionary = {"id_salida": id, "nombres": nombres}
		var ancla: Vector3 = _ancla_de(receta, todas)
		var radio: float = _radio_de(receta, todas, ancla)
		_montar_receta(grupo, receta, todas, ancla)
		_colocar_camara(radio * 2.0 * MARGEN)
		for rot: int in ROTACIONES:
			grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
			var bruto: Dictionary = await _renderizar_bruto()
			var img: Image = bruto["imagen"]
			var ruta: String = "%s%s_%d.png" % [CARPETA_SCRATCH, id, rot]
			img.save_png(ruta)
			print("[INSPECCION] %s @ %d°: %dx%d px -> %s" % [id, rot, img.get_width(), img.get_height(), ruta])

	print("[INSPECCION] hecho.")
	get_tree().quit()
