extends SceneTree
## _diag3d_ventanillas — DESECHABLE (2026-08-07). Diagnóstico numérico (sin render) de
## mesa_ventanilla_basica_v3_vacia.glb y mesa_ventanilla_media_v2_vacia.glb: AABB conjunta +
## reparto de VÉRTICES por cuadrante (signo de X, signo de Z) con la Y máxima de cada cuadrante,
## para localizar la cajonera (caja alta, un extremo) / el hueco de piernas (vacío, otro extremo) /
## la mampara (panel alto sobre un borde) SIN mirar un render — el pack trae cada GLB como una
## única malla fusionada, así que no hay nombres de nodo que discriminen las piezas.

const RUTAS := [
	"res://capturas/fuentes/mesa_ventanilla_summer/mesa_ventanilla_basica_v3_vacia.glb",
	"res://capturas/fuentes/mesa_ventanilla_summer/mesa_ventanilla_media_v2_vacia.glb",
]


func _initialize() -> void:
	for ruta: String in RUTAS:
		_diag(ruta)
	quit()


func _diag(ruta: String) -> void:
	var escena: PackedScene = load(ruta)
	if escena == null:
		print("[DIAG3D] no se pudo cargar %s" % ruta)
		return
	var raiz: Node3D = escena.instantiate()
	print("[DIAG3D] === %s ===" % ruta)

	var caja_total := AABB()
	var primera := true
	# cuadrante -> {"n": int, "y_max": float, "y_min": float}
	var cuadrantes: Dictionary = {}
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			cuadrantes["%d,%d" % [sx, sz]] = {"n": 0, "y_max": -999.0, "y_min": 999.0}

	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var t: Transform3D = _global_transform_manual(mi)
		var aabb_mundo: AABB = t * mi.mesh.get_aabb()
		caja_total = aabb_mundo if primera else caja_total.merge(aabb_mundo)
		primera = false

		var centro_x: float = aabb_mundo.position.x + aabb_mundo.size.x * 0.5
		var centro_z: float = aabb_mundo.position.z + aabb_mundo.size.z * 0.5

		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var w: Vector3 = t * v
				var sx: int = 1 if w.x >= centro_x else -1
				var sz: int = 1 if w.z >= centro_z else -1
				var clave: String = "%d,%d" % [sx, sz]
				var d: Dictionary = cuadrantes[clave]
				d["n"] = int(d["n"]) + 1
				d["y_max"] = maxf(d["y_max"], w.y)
				d["y_min"] = minf(d["y_min"], w.y)
				cuadrantes[clave] = d

	print("[DIAG3D]  AABB conjunta: pos=%s size=%s (x=%.4f y=%.4f z=%.4f)" % [
		caja_total.position, caja_total.size, caja_total.size.x, caja_total.size.y, caja_total.size.z
	])
	for clave: String in cuadrantes.keys():
		var d: Dictionary = cuadrantes[clave]
		print("[DIAG3D]  cuadrante (signoX,signoZ)=%s: %d vértices, y_min=%.4f y_max=%.4f" % [
			clave, d["n"], d["y_min"], d["y_max"]
		])


func _global_transform_manual(nodo: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var actual: Node3D = nodo
	while actual != null:
		t = actual.transform * t
		var padre: Node = actual.get_parent()
		actual = padre as Node3D if padre is Node3D else null
	return t
