extends SceneTree
## Diagnóstico de separabilidad de nodos de los GLB de mesa_ventanilla_summer.
## Uso: godot --headless --script res://tools/_diag_mesa_separabilidad.gd

const RUTAS := [
	"res://capturas/fuentes/mesa_ventanilla_summer/mesa_ventanilla.glb",
	"res://capturas/fuentes/mesa_ventanilla_summer/mesa_ventanilla_pro.glb",
	"res://capturas/fuentes/mesa_ventanilla_summer/mesa_ventanilla_basica_v2.glb",
]


func _init() -> void:
	for ruta: String in RUTAS:
		print("\n========== %s ==========" % ruta)
		var escena: PackedScene = load(ruta)
		if escena == null:
			print("  [ERROR] no se pudo cargar")
			continue
		var raiz: Node3D = escena.instantiate()
		_dump(raiz, 0)
		raiz.free()
	quit()


func _dump(nodo: Node, profundidad: int) -> void:
	var indent := "  ".repeat(profundidad)
	var info := "%s- %s (%s)" % [indent, nodo.name, nodo.get_class()]
	if nodo is MeshInstance3D:
		var mi := nodo as MeshInstance3D
		if mi.mesh:
			var aabb: AABB = mi.mesh.get_aabb()
			info += " mesh=%s surfaces=%d aabb_size=%s pos=%s" % [
				mi.mesh.resource_name, mi.mesh.get_surface_count(), aabb.size, mi.global_position
			]
	print(info)
	for hijo: Node in nodo.get_children():
		_dump(hijo, profundidad + 1)
