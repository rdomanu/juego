extends Node3D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — renderiza por separado las 2 mallas de OBJ_023
## ("Object_931", "Object_932") con la MISMA cámara isométrica que `render_mobiliario.gd`
## (yaw 45°, pitch 30°, ortográfica), para confirmar A OJO cuál es el RESPALDO y cuál es
## "patas+asiento" (la medida de AABB en `_diag_silla_espera.gd` ya apunta a una — esto la
## verifica visualmente, misma técnica que localizó los monitores de OBJ_042).
## Se borra tras usarlo — no es parte del pipeline final.

const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
const SALIDA := "res://tools/_diag_silla_espera_"
const TAM_RENDER: int = 512
const ELEVACION_GRADOS: float = 30.0
const MARGEN: float = 1.4

var _sub: SubViewport
var _camara: Camera3D


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	var modelo: Node3D = escena.instantiate()
	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.add_child(modelo)
	contenedor.visible = false

	var por_nombre: Dictionary = {}
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		por_nombre[String(mi.name)] = mi

	var o931: MeshInstance3D = por_nombre["Object_931"]
	var o932: MeshInstance3D = por_nombre["Object_932"]

	# AABB combinada de las 2 piezas -> ancla (centro X/Z al nivel del suelo) y radio, igual que
	# `render_mobiliario.gd::_ancla_de`/`_radio_de`, para un encuadre que las contenga a las dos
	# con la MISMA cámara en las 3 pasadas (ambas, solo 931, solo 932) -- comparables entre sí.
	var c931: AABB = o931.global_transform * o931.mesh.get_aabb()
	var c932: AABB = o932.global_transform * o932.mesh.get_aabb()
	var caja: AABB = c931.merge(c932)
	var centro: Vector3 = caja.get_center()
	var ancla := Vector3(centro.x, caja.position.y, centro.z)
	var radio := 0.0
	for esquina: Vector3 in _esquinas_de(caja):
		radio = maxf(radio, (esquina - ancla).length())

	_sub = SubViewport.new()
	_sub.size = Vector2i(TAM_RENDER, TAM_RENDER)
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.own_world_3d = true
	add_child(_sub)
	var mundo := Node3D.new()
	_sub.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sol.light_energy = 1.1
	mundo.add_child(sol)
	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.9
	entorno.environment = env
	mundo.add_child(entorno)

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	mundo.add_child(_camara)
	# Las piezas se montan YA CENTRADAS en el origen (ver `_pasada`: resta `ancla` a cada
	# transformada), así que la cámara mira a Vector3.ZERO -- NO a `ancla` en coordenadas de
	# mundo (bug del primer intento: cámara y piezas en marcos de referencia distintos, render
	# vacío) -- mismo patrón que `render_mobiliario.gd::_colocar_camara`/`_montar_receta`.
	_colocar_camara(radio * 2.0 * MARGEN)

	var grupo := Node3D.new()
	mundo.add_child(grupo)

	await _pasada(grupo, [o931, o932], ancla, "ambas")
	await _pasada(grupo, [o931], ancla, "solo931")
	await _pasada(grupo, [o932], ancla, "solo932")

	print("[DIAG SILLA ESPERA] hecho -- ver tools/_diag_silla_espera_*.png")
	get_tree().quit()


func _esquinas_de(caja: AABB) -> Array[Vector3]:
	var esquinas: Array[Vector3] = []
	var p: Vector3 = caja.position
	var s: Vector3 = caja.size
	for i: int in 8:
		esquinas.append(Vector3(
			p.x + s.x * float(i & 1), p.y + s.y * float((i >> 1) & 1), p.z + s.z * float((i >> 2) & 1)
		))
	return esquinas


func _colocar_camara(tam_mundo: float) -> void:
	var yaw: float = deg_to_rad(45.0)
	var pitch: float = deg_to_rad(ELEVACION_GRADOS)
	var distancia: float = maxf(tam_mundo, 0.05) * 3.0
	_camara.position = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distancia
	_camara.look_at(Vector3.ZERO, Vector3.UP)
	_camara.size = maxf(tam_mundo, 0.05)


func _pasada(grupo: Node3D, piezas: Array, ancla: Vector3, etiqueta: String) -> void:
	for hijo: Node in grupo.get_children():
		grupo.remove_child(hijo)
		hijo.free()
	for original: MeshInstance3D in piezas:
		var pieza := MeshInstance3D.new()
		pieza.mesh = original.mesh
		pieza.transform = Transform3D(original.global_transform.basis, original.global_transform.origin - ancla)
		pieza.material_override = original.material_override
		for s: int in original.mesh.get_surface_count():
			pieza.set_surface_override_material(s, original.get_surface_override_material(s))
		grupo.add_child(pieza)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = _sub.get_texture().get_image()
	var ruta: String = "%s%s.png" % [SALIDA, etiqueta]
	imagen.save_png(ProjectSettings.globalize_path(ruta))
	print("[DIAG SILLA ESPERA] %s -> %s" % [etiqueta, ruta])
