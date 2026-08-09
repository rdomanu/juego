extends Node3D
## DIAGNÓSTICO DESECHABLE: confirma que Object_1043 (ARQ_022) y Object_1057 (ARQ_023) existen como
## MeshInstance3D en el GLB, y si no, busca el nombre real más parecido.

const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	var modelo: Node3D = escena.instantiate()
	add_child(modelo)
	var buscados := ["Object_43", "Object_795", "Object_1043", "Object_1057"]
	var encontrados: Dictionary = {}
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		encontrados[String(hijo.name)] = true
	for b: String in buscados:
		print("[DIAG NOMBRES] %s existe=%s" % [b, encontrados.has(b)])
	print("[DIAG NOMBRES] total MeshInstance3D=%d" % encontrados.size())
	get_tree().quit()
