extends Node3D
## DIAGNÓSTICO DESECHABLE — mide el AABB conjunto (mundo) de la receta `mostrador_atencion`
## (OBJ_021 + teléfono OBJ_046, con su desplazamiento) para calcular a mano la escala del
## sprite "2 celdas" (tarea del usuario 2026-08-02, ver render_mobiliario.gd). Se borra tras
## usarlo — no es parte del pipeline final.

const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
const NOMBRES := [
	"Object_829", "Object_831", "Object_833", "Object_835", "Object_837", "Object_838",
	"Object_840", "Object_842", "Object_844", "Object_845", "Object_846", "Object_848",
	"Object_849", "Object_851", "Object_852", "Object_853", "Object_854",
	"Object_861", "Object_863", "Object_865",
	"Object_867", "Object_869", "Object_871", "Object_873", "Object_875", "Object_877",
	"Object_879",
	"Object_1169", "Object_1170", "Object_1171",
]
const DESPLAZAMIENTO_TELEFONO := Vector3(-4.841, -0.086, -8.176)


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	var modelo: Node3D = escena.instantiate()
	add_child(modelo)
	var por_nombre: Dictionary = {}
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		por_nombre[String(mi.name)] = mi

	var caja := AABB()
	var primera := true
	for n: String in NOMBRES:
		if not por_nombre.has(n):
			print("FALTA: %s" % n)
			continue
		var mi: MeshInstance3D = por_nombre[n]
		var delta: Vector3 = DESPLAZAMIENTO_TELEFONO if n in ["Object_1169", "Object_1170", "Object_1171"] else Vector3.ZERO
		var t: Transform3D = mi.global_transform
		t = Transform3D(t.basis, t.origin + delta)
		var c: AABB = t * mi.mesh.get_aabb()
		caja = c if primera else caja.merge(c)
		primera = false

	print("AABB conjunta mostrador_atencion: pos=%.4f,%.4f,%.4f size=%.4f,%.4f,%.4f" % [
		caja.position.x, caja.position.y, caja.position.z,
		caja.size.x, caja.size.y, caja.size.z,
	])
	print("Lx=%.4f  Ly(altura)=%.4f  Lz=%.4f" % [caja.size.x, caja.size.y, caja.size.z])
	print("lado_largo=%.4f  fondo=%.4f  ratio_fondo/largo=%.4f" % [
		maxf(caja.size.x, caja.size.z), minf(caja.size.x, caja.size.z),
		minf(caja.size.x, caja.size.z) / maxf(caja.size.x, caja.size.z),
	])
	get_tree().quit()
