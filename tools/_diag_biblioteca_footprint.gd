extends SceneTree
## _diag_biblioteca_footprint — DESECHABLE (2026-08-06). Mide el AABB en bruto (X/Z, planta) de
## `escritorio_trabajo.glb` para decidir su huella (1x1 vs 2x1) antes de renderizar. Solo imprime,
## no escribe PNG. Mismo patrón que `_diag_impresora_dni.gd` (transform manual, sin meter el nodo
## en el árbol -- evita el error "!is_inside_tree()" de `global_transform` fuera de árbol).
##
## Uso: godot --headless --script res://tools/_diag_biblioteca_footprint.gd

const RUTA := "res://capturas/fuentes/biblioteca_summer/escritorio_trabajo.glb"


func _initialize() -> void:
	var escena: PackedScene = load(RUTA)
	if escena == null:
		print("[DIAG] no se pudo cargar %s" % RUTA)
		quit(1)
		return
	var raiz: Node3D = escena.instantiate()

	var caja := AABB()
	var primera := true
	var total := 0
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var t: Transform3D = _global_transform_manual(mi)
		var c: AABB = t * mi.mesh.get_aabb()
		print("[DIAG] %s: transform_local=%s AABB_mundo pos=%s size=%s" % [mi.name, mi.transform, c.position, c.size])
		caja = c if primera else caja.merge(c)
		primera = false
		total += 1

	print("[DIAG] %d MeshInstance3D. AABB size = %s (x=%.4f m, y=%.4f m, z=%.4f m)" % [
		total, caja.size, caja.size.x, caja.size.y, caja.size.z
	])
	var ratio: float = maxf(caja.size.x, caja.size.z) / maxf(minf(caja.size.x, caja.size.z), 0.0001)
	print("[DIAG] planta x=%.4f z=%.4f -> ratio lado_largo/lado_corto = %.3f" % [
		caja.size.x, caja.size.z, ratio
	])
	quit()


func _global_transform_manual(nodo: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var actual: Node3D = nodo
	while actual != null:
		t = actual.transform * t
		var padre: Node = actual.get_parent()
		actual = padre as Node3D if padre is Node3D else null
	return t
