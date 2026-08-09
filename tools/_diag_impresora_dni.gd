extends SceneTree
## _diag_impresora_dni — DESECHABLE, sondeo de estructura del GLB nuevo de Summer
## (`capturas/fuentes/impresora_dni_summer/impresora_dni_workstation.glb`) ANTES de renderizar.
## Lista cada MeshInstance3D con su AABB en mundo (posición/tamaño), para saber si el modelo trae
## un "poste/baliza" como sub-malla aparte del cuerpo y detectar rarezas de ejes/escala.
##
## Uso: godot --headless --path <proyecto> --script res://tools/_diag_impresora_dni.gd

const RUTA := "res://capturas/fuentes/impresora_dni_summer/impresora_dni_workstation.glb"

func _initialize() -> void:
	var escena: PackedScene = load(RUTA)
	if escena == null:
		print("[DIAG DNI] no se pudo cargar %s" % RUTA)
		quit(1)
		return
	var raiz: Node3D = escena.instantiate()
	print("[DIAG DNI] raiz: %s (%s), transform=%s" % [raiz.name, raiz.get_class(), raiz.transform])
	_listar_cadena(raiz)

	var caja_total := AABB()
	var primera := true
	var n := 0
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		n += 1
		var t: Transform3D = _global_transform_manual(mi)
		var aabb_local: AABB = mi.mesh.get_aabb()
		var aabb_mundo: AABB = t * aabb_local
		print("[DIAG DNI] #%d %s: transform_local=%s | transform_global=%s" % [n, mi.name, mi.transform, t])
		print("[DIAG DNI]    AABB local pos=%s size=%s | AABB mundo pos=%s size=%s (top_y=%.4f)" % [
			aabb_local.position, aabb_local.size, aabb_mundo.position, aabb_mundo.size,
			aabb_mundo.position.y + aabb_mundo.size.y
		])
		caja_total = aabb_mundo if primera else caja_total.merge(aabb_mundo)
		primera = false

	print("[DIAG DNI] total piezas con malla: %d" % n)
	print("[DIAG DNI] AABB conjunta: pos=%s size=%s" % [caja_total.position, caja_total.size])
	print("[DIAG DNI] ancho(x)=%.4f fondo(z)=%.4f alto(y)=%.4f (y_min=%.4f y_max=%.4f)" % [
		caja_total.size.x, caja_total.size.z, caja_total.size.y,
		caja_total.position.y, caja_total.position.y + caja_total.size.y
	])
	quit()


## Compone las transformadas LOCALES subiendo por `get_parent()` (no requiere estar en el árbol —
## `global_transform` sí lo requiere y falla fuera de él, ver el aviso al lanzar este script).
func _global_transform_manual(nodo: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var actual: Node3D = nodo
	while actual != null:
		t = actual.transform * t
		var padre: Node = actual.get_parent()
		actual = padre as Node3D if padre is Node3D else null
	return t


func _listar_cadena(raiz: Node3D) -> void:
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var cadena: Array[String] = []
		var actual: Node = hijo
		while actual != null:
			cadena.append(actual.name)
			actual = actual.get_parent()
		cadena.reverse()
		print("[DIAG DNI] cadena de %s: %s" % [hijo.name, " / ".join(cadena)])
