extends Node3D
## DIAGNÓSTICO TEMPORAL -- se borra antes de terminar la tarea. Solo vuelca a disco la textura
## GGrid.png de cada candidato para poder mirarla directamente, y lista los materiales que la usan.

const MODELOS := [
	"res://capturas/NPC/Policias/candidatos/male_officer.glb",
	"res://capturas/NPC/Policias/candidatos/female_officer.glb",
]
const SALIDA := "res://capturas/NPC/Policias/candidatos/render_test/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	for ruta: String in MODELOS:
		var nombre: String = ruta.get_file().get_basename()
		var doc := GLTFDocument.new()
		var estado := GLTFState.new()
		var err: Error = doc.append_from_file(ruta, estado)
		if err != OK:
			print("ERROR cargando %s: %d" % [ruta, err])
			continue
		var raiz: Node = doc.generate_scene(estado)
		add_child(raiz)
		var esqueleto: Skeleton3D = null
		for h: Node in raiz.find_children("*", "Skeleton3D", true, false):
			esqueleto = h as Skeleton3D
			break
		var vistos: Dictionary = {}
		for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
			var mi := hijo as MeshInstance3D
			var malla: Mesh = mi.mesh
			if malla == null:
				continue
			print("[MESH] %s: %s (superficies=%d)" % [nombre, mi.name, malla.get_surface_count()])
			for s: int in malla.get_surface_count():
				var mat: Material = mi.get_active_material(s)
				print("  surf %d -> material=%s" % [s, mat])
				if mat is BaseMaterial3D:
					var bm := mat as BaseMaterial3D
					var tex: Texture2D = bm.albedo_texture
					print("    albedo_color=%s albedo_texture=%s" % [bm.albedo_color, tex])
					if tex != null and not vistos.has(tex):
						vistos[tex] = true
						var img: Image = tex.get_image()
						print("    tamaño=%s formato=%d" % [img.get_size(), img.get_format()])
						var destino: String = "%s_diag_textura_%s_%d.png" % [SALIDA, nombre, vistos.size()]
						img.save_png(ProjectSettings.globalize_path(destino))
						print("    guardada en %s" % destino)
				# Qué CELDA de la rejilla usa cada hueso (para saber cuál es la piel sin adivinar).
				if esqueleto != null:
					_volcar_uv_por_hueso(malla, s, esqueleto, nombre, mi.name)
	get_tree().quit()


## Para cada hueso, en qué rango de UV caen los vértices que MÁS le deben a ese hueso (mayor peso de
## piel). La rejilla es 8 columnas x 4 filas: columna = floor(u*8), fila = floor(v*4).
func _volcar_uv_por_hueso(malla: Mesh, surf: int, esqueleto: Skeleton3D, nombre: String, mesh_name: String) -> void:
	var arrays: Array = malla.surface_get_arrays(surf)
	if arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_TEX_UV] == null:
		print("  [UV] %s/%s surf %d: sin huesos o sin UV -> se salta" % [nombre, mesh_name, surf])
		return
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var n: int = uvs.size()
	if n == 0 or bones.size() == 0:
		return
	var influencias: int = bones.size() / n
	var por_hueso: Dictionary = {}
	for i: int in n:
		var mejor_hueso: int = -1
		var mejor_peso: float = 0.0
		for k: int in influencias:
			var b: int = bones[i * influencias + k]
			var w: float = weights[i * influencias + k]
			if w > mejor_peso:
				mejor_peso = w
				mejor_hueso = b
		if mejor_hueso < 0:
			continue
		var hnombre: String = esqueleto.get_bone_name(mejor_hueso)
		if not por_hueso.has(hnombre):
			por_hueso[hnombre] = {"celdas": {}, "n": 0}
		var uv: Vector2 = uvs[i]
		var col: int = clampi(int(floor(uv.x * 8.0)), 0, 7)
		var fila: int = clampi(int(floor(uv.y * 4.0)), 0, 3)
		var clave: String = "%d,%d" % [col, fila]
		var d: Dictionary = por_hueso[hnombre]
		d["celdas"][clave] = d["celdas"].get(clave, 0) + 1
		d["n"] += 1
	for hnombre: String in por_hueso:
		var d: Dictionary = por_hueso[hnombre]
		print("  [UV] %s/%s hueso=%s n=%d celdas(col,fila)=%s" % [
			nombre, mesh_name, hnombre, d["n"], d["celdas"]
		])
