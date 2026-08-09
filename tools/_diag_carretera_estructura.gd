extends Node3D
## Sonda DESECHABLE (2026-08-08, bug 2 de playtest de carreteras): imprime cada MeshInstance3D de
## road-straight.glb con su AABB (posición+tamaño) en coordenadas de mundo -- para identificar qué
## parte del modelo es la calzada, cuál la acera/arcén, y si hay caras laterales ("cantos") en los
## extremos del eje de la vía que expliquen la costura al poner tiles contiguos.

const CARPETA := "res://capturas/fuentes/kenney_roads/Models/GLB format/"
const RUTAS: Array[String] = [
	"road-straight.glb", "road-bend.glb", "road-crossroad-line.glb",
	"road-intersection-line.glb", "road-crossing.glb",
]

func _ready() -> void:
	for nombre: String in RUTAS:
		var ruta: String = CARPETA + nombre
		var escena: PackedScene = load(ruta)
		if escena == null:
			push_error("no se pudo cargar %s" % ruta)
			continue
		var raiz: Node3D = escena.instantiate()
		add_child(raiz)
		print("[DIAG] === %s === raiz: %s transform=%s" % [nombre, raiz.name, raiz.transform])
		for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
			var mi := hijo as MeshInstance3D
			if mi.mesh == null:
				continue
			var aabb_local: AABB = mi.mesh.get_aabb()
			var aabb_global: AABB = mi.global_transform * aabb_local
			print("[DIAG] %s: transform.origin=%s aabb_local(pos=%s size=%s) aabb_global(pos=%s size=%s)" % [
				mi.name, mi.global_transform.origin, aabb_local.position, aabb_local.size,
				aabb_global.position, aabb_global.size
			])
		remove_child(raiz)
		raiz.free()
	print("[DIAG] hecho.")
	get_tree().quit()
