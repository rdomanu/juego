extends Node3D
## DIAGNÓSTICO DESECHABLE — investiga el hueco de "falta cojín de respaldo" en asiento_sofa3
## (ARQ_007, receta actual: SOLO Object_384). Se borra tras usarlo.
##
## Ronda 1: lista TODAS las MeshInstance3D del GLB cuyo AABB de mundo cae cerca del sofá
## (posición conocida por el catálogo: Object_384 centro ≈ (-0.35, 0.40, 6.77)), con su firma de
## forma LOCAL (tamaño del mesh sin transformar — mismo criterio que `_firma_forma` de
## `render_despiece_objetos.gd`: el importador glTF NO comparte recurso de malla entre copias
## idénticas, así que comparar por tamaño local es lo fiable).
## Ronda 2: agrupa TODAS las 748 instancias del modelo por firma de forma y vuelca cualquier firma
## que se repita 2+ veces cuyo tamaño sea "pequeño/medio" (candidato a cojín repetido en otra
## parte del árbol, mal clusterizado lejos del sofá).

const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
const CENTRO_SOFA := Vector3(-0.349, 0.4, 6.771)
const RADIO_BUSQUEDA := 2.5


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	var modelo: Node3D = escena.instantiate()
	add_child(modelo)

	print("── RONDA 1: piezas cerca del sofá (radio %.1f m de %s) ──" % [RADIO_BUSQUEDA, CENTRO_SOFA])
	var firmas: Dictionary = {}
	var total := 0
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		total += 1
		var caja_local: AABB = mi.mesh.get_aabb()
		var caja_mundo: AABB = mi.global_transform * caja_local
		var centro_mundo: Vector3 = caja_mundo.get_center()
		var firma: String = "%.2f_%.2f_%.2f" % [caja_local.size.x, caja_local.size.y, caja_local.size.z]
		if not firmas.has(firma):
			firmas[firma] = []
		(firmas[firma] as Array).append({"nombre": mi.name, "centro": centro_mundo, "pos_min": caja_mundo.position})
		if centro_mundo.distance_to(CENTRO_SOFA) <= RADIO_BUSQUEDA:
			print("%s | firma_local=%s | centro_mundo=%.3f,%.3f,%.3f | aabb_min=%.3f,%.3f,%.3f | aabb_size=%.3f,%.3f,%.3f" % [
				mi.name, firma,
				centro_mundo.x, centro_mundo.y, centro_mundo.z,
				caja_mundo.position.x, caja_mundo.position.y, caja_mundo.position.z,
				caja_mundo.size.x, caja_mundo.size.y, caja_mundo.size.z,
			])

	print("── total MeshInstance3D en el modelo: %d ──" % total)
	print("── RONDA 2: firmas de forma repetidas (2+ instancias), tamaño diagonal < 2.5 m ──")
	for firma: String in firmas.keys():
		var lista: Array = firmas[firma]
		if lista.size() < 2:
			continue
		var partes: PackedStringArray = firma.split("_")
		var tam := Vector3(partes[0].to_float(), partes[1].to_float(), partes[2].to_float())
		if tam.length() >= 2.5:
			continue
		print("firma=%s (x%d): %s" % [firma, lista.size(), lista])

	get_tree().quit()
