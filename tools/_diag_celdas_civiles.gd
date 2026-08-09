extends SceneTree
## DIAGNÓSTICO (temporal, no toca producción): mapea, para cada uno de los 7 candidatos a ciudadano,
## qué CELDA de la rejilla de su textura-atlas corresponde a "ropa" (torso/piernas, hueso `Body`) y
## cuál a "pelo" (hueso `Head`, celda que NO coincide con el tono de piel de manos/pies). Método: para
## cada vértice de cada superficie, se calcula (a) en qué celda de una rejilla 8×4 cae su UV y (b) qué
## hueso pesa más sobre él (vía el `Skin` -> índice de hueso del `Skeleton3D`); se agregan los pares
## (hueso, celda) para ver qué celda "pertenece" a qué hueso, y el color medio de esa celda.
##
## No renderiza nada (headless, sin GPU) -- es análisis de malla/UV/pesos puro. El "teñido chillón" de
## verificación visual vive en un script aparte que SÍ necesita GPU si hiciera falta confirmar a ojo.
##
## Uso: godot --headless --path <proyecto> -s res://tools/_diag_celdas_civiles.gd

const MODELOS: Array[String] = [
	"res://capturas/NPC/Ciudadanos/candidatos/generic_male.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/generic_female.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/citizen1.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/citizen2.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/citizen3.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/retail_worker.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/crypto_bro.glb",
]

## Rejilla asumida (misma familia de asset que los policías: 8 columnas × 4 filas de franjas de
## color). Se verifica por celda: si la varianza de color dentro de una celda usada es alta, la
## rejilla asumida está mal alineada y se anota en el informe.
const REJILLA_COLUMNAS: int = 8
const REJILLA_FILAS: int = 4

func _init() -> void:
	for ruta: String in MODELOS:
		_analizar(ruta)
	quit()


func _analizar(ruta: String) -> void:
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

	var esqueleto: Skeleton3D = null
	for hijo: Node in raiz.find_children("*", "Skeleton3D", true, false):
		esqueleto = hijo
		break
	if esqueleto == null:
		print("  SIN Skeleton3D -> no se puede correlacionar hueso/celda")
		raiz.free()
		return

	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		_analizar_malla(mi, esqueleto)

	raiz.free()


func _analizar_malla(mi: MeshInstance3D, esqueleto: Skeleton3D) -> void:
	var skin: Skin = mi.skin
	print("  -- MeshInstance3D '%s' (skin: %s) --" % [mi.name, "sí, %d binds" % skin.get_bind_count() if skin != null else "NINGUNO"])
	for s: int in mi.mesh.get_surface_count():
		var mat: Material = mi.get_active_material(s)
		var tex_img: Image = null
		if mat is BaseMaterial3D:
			var bm := mat as BaseMaterial3D
			if bm.albedo_texture != null:
				tex_img = bm.albedo_texture.get_image()
		if tex_img == null:
			print("    superficie %d: SIN textura -> se salta" % s)
			continue

		var arrays: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var bones_raw = arrays[Mesh.ARRAY_BONES]
		var weights_raw = arrays[Mesh.ARRAY_WEIGHTS]
		if uvs.is_empty():
			print("    superficie %d: SIN UVs -> se salta" % s)
			continue
		var num_verts: int = verts.size()
		var bones_por_vertice: int = 0
		if bones_raw != null and num_verts > 0:
			bones_por_vertice = int(bones_raw.size() / num_verts)

		var ancho_celda: float = 1.0 / float(REJILLA_COLUMNAS)
		var alto_celda: float = 1.0 / float(REJILLA_FILAS)

		# hueso_nombre -> { celda_str: cuenta_vertices }
		var por_hueso: Dictionary = {}
		# celda_str -> Vector2i (para poder samplear el color luego)
		var celdas_vistas: Dictionary = {}
		# Rango Y (mundo local del vértice) por celda, para distinguir "torso" (Y alto) de
		# "piernas" (Y bajo) cuando ambas comparten el mismo hueso `Body`.
		var y_min_por_celda: Dictionary = {}
		var y_max_por_celda: Dictionary = {}

		for v: int in num_verts:
			var uv: Vector2 = uvs[v]
			var cx: int = clampi(int(uv.x / ancho_celda), 0, REJILLA_COLUMNAS - 1)
			var cy: int = clampi(int(uv.y / alto_celda), 0, REJILLA_FILAS - 1)
			var celda := Vector2i(cx, cy)
			var celda_str: String = "%d,%d" % [cx, cy]
			celdas_vistas[celda_str] = celda

			var y: float = verts[v].y
			y_min_por_celda[celda_str] = minf(y_min_por_celda.get(celda_str, INF), y)
			y_max_por_celda[celda_str] = maxf(y_max_por_celda.get(celda_str, -INF), y)

			var nombre_hueso := "(sin skin)"
			if skin != null and bones_por_vertice > 0:
				var mejor_peso: float = -1.0
				var mejor_bone_local: int = -1
				for b: int in bones_por_vertice:
					var w: float = weights_raw[v * bones_por_vertice + b]
					if w > mejor_peso:
						mejor_peso = w
						mejor_bone_local = bones_raw[v * bones_por_vertice + b]
				if mejor_bone_local >= 0 and mejor_bone_local < skin.get_bind_count():
					var idx_esqueleto: int = skin.get_bind_bone(mejor_bone_local)
					if idx_esqueleto >= 0 and idx_esqueleto < esqueleto.get_bone_count():
						nombre_hueso = esqueleto.get_bone_name(idx_esqueleto)
					else:
						nombre_hueso = "(bind sin hueso válido: local %d)" % mejor_bone_local

			if not por_hueso.has(nombre_hueso):
				por_hueso[nombre_hueso] = {}
			var mapa_celdas: Dictionary = por_hueso[nombre_hueso]
			mapa_celdas[celda_str] = int(mapa_celdas.get(celda_str, 0)) + 1

		print("    superficie %d: textura %dx%d, %d vértices, %d huesos/vértice" % [
			s, tex_img.get_width(), tex_img.get_height(), num_verts, bones_por_vertice
		])
		var claves_huesos: Array = por_hueso.keys()
		claves_huesos.sort()
		for nombre_hueso: String in claves_huesos:
			var mapa_celdas: Dictionary = por_hueso[nombre_hueso]
			var claves_celda: Array = mapa_celdas.keys()
			claves_celda.sort()
			var descripcion: Array[String] = []
			for celda_str: String in claves_celda:
				var celda: Vector2i = celdas_vistas[celda_str]
				var color: Color = _color_medio_celda(tex_img, celda)
				var varianza: float = _varianza_celda(tex_img, celda)
				var y_lo: float = y_min_por_celda[celda_str]
				var y_hi: float = y_max_por_celda[celda_str]
				descripcion.append(
					"(%s)x%d color=#%s var=%.4f y=[%.3f..%.3f]" % [
						celda_str, mapa_celdas[celda_str], color.to_html(false), varianza, y_lo, y_hi
					]
				)
			print("      hueso '%s': %s" % [nombre_hueso, ", ".join(descripcion)])


func _color_medio_celda(img: Image, celda: Vector2i) -> Color:
	var ancho: int = img.get_width() / REJILLA_COLUMNAS
	var alto: int = img.get_height() / REJILLA_FILAS
	var x0: int = celda.x * ancho
	var y0: int = celda.y * alto
	var suma := Color(0.0, 0.0, 0.0, 0.0)
	var n := 0
	var paso: int = maxi(1, ancho / 8)
	var pasoy: int = maxi(1, alto / 8)
	var y: int = y0
	while y < y0 + alto:
		var x: int = x0
		while x < x0 + ancho:
			suma += img.get_pixel(x, y)
			n += 1
			x += paso
		y += pasoy
	if n == 0:
		return Color.BLACK
	return suma / float(n)


func _varianza_celda(img: Image, celda: Vector2i) -> float:
	var ancho: int = img.get_width() / REJILLA_COLUMNAS
	var alto: int = img.get_height() / REJILLA_FILAS
	var x0: int = celda.x * ancho
	var y0: int = celda.y * alto
	var media: Color = _color_medio_celda(img, celda)
	var suma := 0.0
	var n := 0
	var paso: int = maxi(1, ancho / 8)
	var pasoy: int = maxi(1, alto / 8)
	var y: int = y0
	while y < y0 + alto:
		var x: int = x0
		while x < x0 + ancho:
			var c: Color = img.get_pixel(x, y)
			suma += (c.r - media.r) ** 2 + (c.g - media.g) ** 2 + (c.b - media.b) ** 2
			n += 1
			x += paso
		y += pasoy
	if n == 0:
		return 0.0
	return suma / float(n)
