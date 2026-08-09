extends Node3D
## DIAGNÓSTICO DESECHABLE — mide el AABB de piezas concretas del GLB de oficina.
## Se borra tras usarlo — no es parte del pipeline final.
##
## Ronda 1: piezas candidatas a "pantalla" dentro del cluster OBJ_042 (para decidir a mano cuáles
## de los 11 nombres de SUB_042_0 son los 2 monitores; el despiece por volumen no los separó de la
## silla).
## Ronda 2: las 31 piezas de OBJ_021 (el escritorio) — para encontrar la altura Y de la superficie
## del tablero (dónde ya reposan su monitor/teclado/ratón originales) y hueco libre en X/Z para
## apoyar el teléfono (OBJ_046) sin taparlos.
## Ronda 3: las 3 piezas de OBJ_046 (el teléfono) — para conocer su propio AABB y recolocarlo.

const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
const NOMBRES := [
	"Object_1071", "Object_1173", "Object_1174",
	"Object_1192", "Object_1193", "Object_1194", "Object_1195",
	"Object_1197", "Object_1198", "Object_1199", "Object_1200",
	# OBJ_021 (escritorio, 31 piezas)
	"Object_829", "Object_831", "Object_833", "Object_835", "Object_837", "Object_838",
	"Object_840", "Object_842", "Object_844", "Object_845", "Object_846", "Object_848",
	"Object_849", "Object_851", "Object_852", "Object_853", "Object_854", "Object_856",
	"Object_857", "Object_858", "Object_859", "Object_861", "Object_863", "Object_865",
	"Object_867", "Object_869", "Object_871", "Object_873", "Object_875", "Object_877",
	"Object_879",
	# OBJ_046 (teléfono, 3 piezas)
	"Object_1169", "Object_1170", "Object_1171",
	# Ronda 4 (2ª tanda): OBJ_011 (sofá 1 plaza), OBJ_040 (papelera), SUB_002_0 (dispensador),
	# OBJ_038 (radio), ARQ_007 (sofá 3 plazas), OBJ_023 (silla de espera elegida).
	"Object_387", "Object_388", "Object_1055",
	"Object_23", "Object_24", "Object_25", "Object_26", "Object_28",
	"Object_1045", "Object_384", "Object_931", "Object_932",
]


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	var modelo: Node3D = escena.instantiate()
	add_child(modelo)
	var buscar: Dictionary = {}
	for n: String in NOMBRES:
		buscar[n] = true
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if not buscar.has(String(mi.name)):
			continue
		if mi.mesh == null:
			print("%s: SIN MALLA" % mi.name)
			continue
		var caja_local: AABB = mi.mesh.get_aabb()
		var caja_mundo: AABB = mi.global_transform * caja_local
		print("%s | local size=%.3f,%.3f,%.3f | mundo pos=%.3f,%.3f,%.3f size=%.3f,%.3f,%.3f" % [
			mi.name,
			caja_local.size.x, caja_local.size.y, caja_local.size.z,
			caja_mundo.position.x, caja_mundo.position.y, caja_mundo.position.z,
			caja_mundo.size.x, caja_mundo.size.y, caja_mundo.size.z,
		])
	get_tree().quit()
