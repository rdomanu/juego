extends Node3D
## DIAGNÓSTICO DESECHABLE (headless, sin GPU) — histograma por ALTURA de los TRIÁNGULOS de
## `Object_931` (el cojín de OBJ_023, asiento+respaldo FUNDIDOS EN UNA SOLA MALLA -- confirmado
## visualmente con `_diag_silla_espera_render.gd`: `Object_932` es el chasis/patas de tubo negro,
## `Object_931` es TODO el cojín beige, asiento y respaldo juntos, sin costura de malla entre
## ellos). Para partir el cojín en dos por geometría hace falta el ÁNGULO de cada triángulo (no
## solo su altura): la superficie del asiento mira hacia ARRIBA (normal.y grande) y la del
## respaldo mira hacia DELANTE/ATRÁS (normal.y pequeño, normal.x/z grande) -- el bins de abajo
## muestran dónde cae ese cambio de orientación para elegir el umbral de altura del corte.
## Se borra tras usarlo -- no es parte del pipeline final.

const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
const NOMBRE := "Object_931"
const BINS: int = 24


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	var modelo: Node3D = escena.instantiate()
	add_child(modelo)
	var mi: MeshInstance3D = null
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		if String(hijo.name) == NOMBRE:
			mi = hijo as MeshInstance3D
			break
	if mi == null:
		push_error("no se encontró %s" % NOMBRE)
		get_tree().quit(1)
		return

	var t: Transform3D = mi.global_transform
	var malla: Mesh = mi.mesh
	print("superficies=%d" % malla.get_surface_count())
	for s: int in malla.get_surface_count():
		var arrays: Array = malla.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var n_tris: int = indices.size() / 3 if indices.size() > 0 else verts.size() / 3
		print("  surf %d: verts=%d indices=%d tris=%d normales=%s" % [
			s, verts.size(), indices.size(), n_tris, normales.size() > 0
		])

		# AABB mundo de esta superficie (para fijar el rango del histograma).
		var ymin := INF
		var ymax := -INF
		for v: Vector3 in verts:
			var wv: Vector3 = t * v
			ymin = minf(ymin, wv.y)
			ymax = maxf(ymax, wv.y)
		print("  Y mundo: [%.4f, %.4f]" % [ymin, ymax])

		var cuenta: Array = []
		var suma_ny: Array = []
		var suma_nz: Array = []
		var suma_nx: Array = []
		var xmin_b: Array = []
		var xmax_b: Array = []
		var zmin_b: Array = []
		var zmax_b: Array = []
		for b: int in BINS:
			cuenta.append(0)
			suma_ny.append(0.0)
			suma_nz.append(0.0)
			suma_nx.append(0.0)
			xmin_b.append(INF)
			xmax_b.append(-INF)
			zmin_b.append(INF)
			zmax_b.append(-INF)

		var altura: float = maxf(ymax - ymin, 0.0001)

		var get_tri: Callable = func(i: int) -> Array:
			if indices.size() > 0:
				return [indices[i * 3], indices[i * 3 + 1], indices[i * 3 + 2]]
			return [i * 3, i * 3 + 1, i * 3 + 2]

		for i: int in n_tris:
			var idx: Array = get_tri.call(i)
			var p0: Vector3 = t * verts[idx[0]]
			var p1: Vector3 = t * verts[idx[1]]
			var p2: Vector3 = t * verts[idx[2]]
			var centro: Vector3 = (p0 + p1 + p2) / 3.0
			# Normal de CARA (world) por producto vectorial -- más fiable que promediar las
			# normales de vértice interpoladas si el mesh trae shading suavizado.
			var normal_local: Vector3 = (verts[idx[1]] - verts[idx[0]]).cross(verts[idx[2]] - verts[idx[0]])
			var normal_mundo: Vector3 = (t.basis * normal_local).normalized()
			var bin: int = clampi(int(floor((centro.y - ymin) / altura * float(BINS))), 0, BINS - 1)
			cuenta[bin] += 1
			suma_ny[bin] += absf(normal_mundo.y)
			suma_nz[bin] += absf(normal_mundo.z)
			suma_nx[bin] += absf(normal_mundo.x)
			xmin_b[bin] = minf(xmin_b[bin], centro.x)
			xmax_b[bin] = maxf(xmax_b[bin], centro.x)
			zmin_b[bin] = minf(zmin_b[bin], centro.z)
			zmax_b[bin] = maxf(zmax_b[bin], centro.z)

		for b: int in BINS:
			if cuenta[b] == 0:
				continue
			var y0: float = ymin + altura * float(b) / float(BINS)
			var y1: float = ymin + altura * float(b + 1) / float(BINS)
			print("  bin %2d Y∈[%.4f,%.4f] tris=%3d |ny|=%.3f |nx|=%.3f |nz|=%.3f X∈[%.3f,%.3f] Z∈[%.3f,%.3f]" % [
				b, y0, y1, cuenta[b],
				suma_ny[b] / cuenta[b], suma_nx[b] / cuenta[b], suma_nz[b] / cuenta[b],
				xmin_b[b], xmax_b[b], zmin_b[b], zmax_b[b],
			])
	get_tree().quit()
