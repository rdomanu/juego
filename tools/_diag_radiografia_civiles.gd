extends SceneTree
## Diagnóstico (temporal, no toca producción): radiografía de los 7 candidatos de ciudadano —
## animaciones embebidas, huesos del esqueleto y si el material trae textura albedo cargada.
## Uso: godot --headless --path <proyecto> -s res://tools/_diag_radiografia_civiles.gd

const MODELOS: Array[String] = [
	"res://capturas/NPC/Ciudadanos/candidatos/generic_male.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/generic_female.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/citizen1.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/citizen2.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/citizen3.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/retail_worker.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/crypto_bro.glb",
]

func _init() -> void:
	for ruta: String in MODELOS:
		_radiografiar(ruta)
	quit()


func _radiografiar(ruta: String) -> void:
	print("\n=== %s ===" % ruta)
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	var err: Error = doc.append_from_file(ruta, estado)
	if err != OK:
		print("  ERROR append_from_file -> %d" % err)
		return
	var raiz: Node = doc.generate_scene(estado)
	if raiz == null:
		print("  ERROR generate_scene -> null")
		return
	var reproductor: AnimationPlayer = null
	for hijo: Node in raiz.find_children("*", "AnimationPlayer", true, false):
		reproductor = hijo
		break
	if reproductor == null:
		print("  SIN AnimationPlayer")
	else:
		print("  Animaciones: %s" % [reproductor.get_animation_list()])
	var esqueleto: Skeleton3D = null
	for hijo: Node in raiz.find_children("*", "Skeleton3D", true, false):
		esqueleto = hijo
		break
	if esqueleto == null:
		print("  SIN Skeleton3D")
	else:
		var nombres: Array[String] = []
		for i: int in esqueleto.get_bone_count():
			nombres.append(esqueleto.get_bone_name(i))
		print("  %d huesos: %s" % [esqueleto.get_bone_count(), nombres])
	var num_mallas := 0
	var num_con_textura := 0
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			num_mallas += 1
			var mat: Material = mi.get_active_material(s)
			if mat is BaseMaterial3D:
				var bm := mat as BaseMaterial3D
				if bm.albedo_texture != null:
					num_con_textura += 1
					print("  superficie %s/%d: albedo_texture %dx%d, albedo_color=%s" % [
						mi.name, s, bm.albedo_texture.get_width(), bm.albedo_texture.get_height(),
						bm.albedo_color
					])
				else:
					print("  superficie %s/%d: SIN albedo_texture, albedo_color=%s" % [
						mi.name, s, bm.albedo_color
					])
			else:
				print("  superficie %s/%d: material no es BaseMaterial3D (%s)" % [mi.name, s, mat])
	print("  mallas: %d, con textura: %d" % [num_mallas, num_con_textura])
	raiz.free()
