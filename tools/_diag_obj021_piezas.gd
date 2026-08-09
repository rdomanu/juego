extends Node3D
## DIAGNÓSTICO DESECHABLE — AABB de cada pieza (Object_NNN) del cluster OBJ_021 (mostrador),
## para separar "cuerpo de madera" de "monitor/teclado/ratón" al construir la receta de 2 módulos
## de `mostrador_atencion2`. Se borra tras usarlo.

const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
const NOMBRES := [
	"Object_829", "Object_831", "Object_833", "Object_835", "Object_837", "Object_838",
	"Object_840", "Object_842", "Object_844", "Object_845", "Object_846", "Object_848",
	"Object_849", "Object_851", "Object_852", "Object_853", "Object_854",
	"Object_861", "Object_863", "Object_865",
	"Object_867", "Object_869", "Object_871", "Object_873", "Object_875", "Object_877",
	"Object_879",
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
		print("%s: pos=(%.3f,%.3f,%.3f) size=(%.3f,%.3f,%.3f) ymin=%.3f ymax=%.3f vol=%.5f" % [
			n, c.position.x, c.position.y, c.position.z,
			c.size.x, c.size.y, c.size.z,
			c.position.y, c.position.y + c.size.y, vol,
		])
	get_tree().quit()
