extends SceneTree
## Diagnóstico (temporal): vuelca a PNG las texturas albedo de cada candidato de ciudadano y mide
## cuánta variedad de color tienen (para confirmar si citizen3 sale "pálido/desnudo" porque su
## textura es de verdad casi blanca, o porque algo no carga).
## Uso: godot --headless --path <proyecto> -s res://tools/_diag_texturas_civiles.gd

const SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/texturas_civiles/"

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
	DirAccess.make_dir_recursive_absolute(SALIDA)
	for ruta: String in MODELOS:
		_procesar(ruta)
	quit()


func _procesar(ruta: String) -> void:
	var prefijo: String = ruta.get_file().get_basename()
	print("\n=== %s ===" % prefijo)
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	if doc.append_from_file(ruta, estado) != OK:
		print("  ERROR append_from_file")
		return
	var raiz: Node = doc.generate_scene(estado)
	if raiz == null:
		print("  ERROR generate_scene")
		return
	var idx := 0
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			if not (mat is BaseMaterial3D):
				continue
			var bm := mat as BaseMaterial3D
			if bm.albedo_texture == null:
				print("  %s/%d: SIN textura" % [mi.name, s])
				continue
			var img: Image = bm.albedo_texture.get_image()
			img.convert(Image.FORMAT_RGBA8)
			var ruta_png: String = "%s%s_%s_%d.png" % [SALIDA, prefijo, mi.name, s]
			img.save_png(ruta_png)
			# Estadística simple: promedio y desviación de luminancia + cuántos px casi blancos.
			var suma := 0.0
			var suma2 := 0.0
			var casi_blancos := 0
			var n := 0
			var paso: int = max(1, img.get_width() / 64)
			for y: int in range(0, img.get_height(), paso):
				for x: int in range(0, img.get_width(), paso):
					var c: Color = img.get_pixel(x, y)
					var lum: float = (c.r + c.g + c.b) / 3.0
					suma += lum
					suma2 += lum * lum
					if lum > 0.92 and c.a > 0.1:
						casi_blancos += 1
					n += 1
			var media: float = suma / n
			var varianza: float = suma2 / n - media * media
			print("  %s/%d: %dx%d, media_luminancia=%.3f, desviacion=%.3f, casi_blancos=%d/%d -> %s" % [
				mi.name, s, img.get_width(), img.get_height(), media, sqrt(max(varianza, 0.0)),
				casi_blancos, n, ruta_png
			])
			idx += 1
	raiz.free()
