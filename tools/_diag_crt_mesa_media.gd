extends SceneTree
## _diag_crt_mesa_media — DESECHABLE (2026-08-07). Lista MeshInstance3D + AABB de
## `crt_antiguo.glb` y `mesa_ventanilla_media_v2_vacia.glb` (mismo patrón que
## `_diag_impresora_dni.gd`: transform manual, sin meter el nodo en el árbol).

const RUTAS := [
	"res://capturas/fuentes/mesa_ventanilla_summer/crt_antiguo.glb",
	"res://capturas/fuentes/mesa_ventanilla_summer/mesa_ventanilla_media_v2_vacia.glb",
]


func _initialize() -> void:
	for ruta: String in RUTAS:
		_diag(ruta)
	quit()


func _diag(ruta: String) -> void:
	var escena: PackedScene = load(ruta)
	if escena == null:
		print("[DIAG] no se pudo cargar %s" % ruta)
		return
	var raiz: Node3D = escena.instantiate()
	print("[DIAG] === %s ===" % ruta)

	var caja_total := AABB()
	var primera := true
	var n := 0
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		n += 1
		var t: Transform3D = _global_transform_manual(mi)
		var aabb_mundo: AABB = t * mi.mesh.get_aabb()
		print("[DIAG]  #%d %s: transform_local=%s | AABB mundo pos=%s size=%s (x=%.4f y=%.4f z=%.4f)" % [
			n, mi.name, mi.transform, aabb_mundo.position, aabb_mundo.size,
			aabb_mundo.size.x, aabb_mundo.size.y, aabb_mundo.size.z
		])
		caja_total = aabb_mundo if primera else caja_total.merge(aabb_mundo)
		primera = false

	print("[DIAG]  total piezas con malla: %d" % n)
	print("[DIAG]  AABB conjunta: pos=%s size=%s (x=%.4f y=%.4f z=%.4f)" % [
		caja_total.position, caja_total.size, caja_total.size.x, caja_total.size.y, caja_total.size.z
	])


func _global_transform_manual(nodo: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var actual: Node3D = nodo
	while actual != null:
		t = actual.transform * t
		var padre: Node = actual.get_parent()
		actual = padre as Node3D if padre is Node3D else null
	return t
