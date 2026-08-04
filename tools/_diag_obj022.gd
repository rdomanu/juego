extends Node3D
## DIAGNÓSTICO DESECHABLE — AABB de cada pieza (Object_NNN) del cluster OBJ_022 (2 estanterías
## haciendo esquina), para separar UNA estantería suelta del conjunto (despiece manual: el
## despiece automático "por volumen" de `catalogo_despiece_manifest.json` NO tiene entrada para
## OBJ_022 -- las dos estanterías comparten firma de tamaño con el conjunto entero). Se borra tras
## usarlo.

const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
const NOMBRES := [
	"Object_881", "Object_883", "Object_884", "Object_885", "Object_886",
	"Object_888", "Object_889", "Object_891", "Object_892", "Object_894", "Object_895",
	"Object_897", "Object_899", "Object_901", "Object_903",
	"Object_905", "Object_906", "Object_907", "Object_908",
	"Object_910", "Object_911", "Object_913", "Object_914",
	"Object_916", "Object_917", "Object_919", "Object_920",
	"Object_922", "Object_924", "Object_926",
	"Object_928", "Object_929",
	"Object_940", "Object_941",
]


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	var modelo: Node3D = escena.instantiate()
	add_child(modelo)
	var por_nombre: Dictionary = {}
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		por_nombre[String(mi.name)] = mi

	for n: String in NOMBRES:
		if not por_nombre.has(n):
			print("FALTA: %s" % n)
			continue
		var mi: MeshInstance3D = por_nombre[n]
		var t: Transform3D = mi.global_transform
		var c: AABB = t * mi.mesh.get_aabb()
		var vol: float = c.size.x * c.size.y * c.size.z
		print("%s: pos=(%.3f,%.3f,%.3f) size=(%.3f,%.3f,%.3f) xmin=%.3f xmax=%.3f zmin=%.3f zmax=%.3f vol=%.5f" % [
			n, c.position.x + c.size.x * 0.5, c.position.y + c.size.y * 0.5, c.position.z + c.size.z * 0.5,
			c.size.x, c.size.y, c.size.z,
			c.position.x, c.position.x + c.size.x,
			c.position.z, c.position.z + c.size.z,
			vol,
		])
	get_tree().quit()
