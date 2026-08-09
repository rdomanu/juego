extends Node3D
## DIAGNÓSTICO DESECHABLE — mide el AABB local y de mundo de las 2 mallas de OBJ_023 (la silla de
## espera canónica, `ID_SILLA_ESPERA` en `render_mobiliario.gd`: "Object_931", "Object_932") para
## decidir cuál es el RESPALDO y cuál es "patas+asiento" por geometría (altura mínima del AABB
## sobre el suelo de la silla). Se borra tras usarlo — no es parte del pipeline final.

const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
const NOMBRES := ["Object_931", "Object_932"]


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	var modelo: Node3D = escena.instantiate()
	add_child(modelo)
	var buscar: Dictionary = {}
	for n: String in NOMBRES:
		buscar[n] = true
	var suelo_y := INF
	var datos: Dictionary = {}
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if not buscar.has(String(mi.name)):
			continue
		if mi.mesh == null:
			print("%s: SIN MALLA" % mi.name)
			continue
		var caja_local: AABB = mi.mesh.get_aabb()
		var caja_mundo: AABB = mi.global_transform * caja_local
		datos[String(mi.name)] = caja_mundo
		suelo_y = minf(suelo_y, caja_mundo.position.y)
		print("%s | superficies=%d | local pos=%.3f,%.3f,%.3f size=%.3f,%.3f,%.3f | mundo pos=%.3f,%.3f,%.3f size=%.3f,%.3f,%.3f" % [
			mi.name, mi.mesh.get_surface_count(),
			caja_local.position.x, caja_local.position.y, caja_local.position.z,
			caja_local.size.x, caja_local.size.y, caja_local.size.z,
			caja_mundo.position.x, caja_mundo.position.y, caja_mundo.position.z,
			caja_mundo.size.x, caja_mundo.size.y, caja_mundo.size.z,
		])
	print("--- suelo (Y mínimo combinado) = %.4f ---" % suelo_y)
	for n: String in NOMBRES:
		if not datos.has(n):
			continue
		var c: AABB = datos[n]
		print("%s: Y mínimo=%.4f (sobre el suelo: %.4f) | X∈[%.3f,%.3f] Z∈[%.3f,%.3f]" % [
			n, c.position.y, c.position.y - suelo_y,
			c.position.x, c.position.x + c.size.x,
			c.position.z, c.position.z + c.size.z,
		])
	get_tree().quit()
