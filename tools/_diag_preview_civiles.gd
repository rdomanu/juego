extends Node3D
## Diagnóstico (temporal, NO producción): vista previa rápida de los 7 candidatos de ciudadano —
## una sola pose (Idle, mirando a cámara) por modelo, para decidir género del prefijo (civil_h/m)
## y comprobar a ojo si citizen3 sale pálido/desnudo de verdad ANTES de lanzar el render completo
## (8 dir × 8 fotogramas × 2 alturas por modelo es caro; esto es barato).
## Uso: godot --path <proyecto> res://tools/_diag_preview_civiles.tscn (ventana GPU, cierra sola).

const SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/preview_civiles/"

const MODELOS: Array[String] = [
	"res://capturas/NPC/Ciudadanos/candidatos/generic_male.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/generic_female.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/citizen1.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/citizen2.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/citizen3.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/retail_worker.glb",
	"res://capturas/NPC/Ciudadanos/candidatos/crypto_bro.glb",
]

const ELEVACION_GRADOS: float = 26.565
const TAM_RENDER: int = 512
const HUESO_PIE := "Foot.L"
const HUESO_PUNTA := "Toes.L"
const ANIM_REPOSO := "Armature|Idle"
## Corrección de frente medida en `render_sprites_animado.gd` para el mismo rig (oficiales).
const CORRECCION_FRENTE_GRADOS: float = 90.0

var _sub: SubViewport
var _camara: Camera3D
var _mundo: Node3D


func _ready() -> void:
	_sub = SubViewport.new()
	_sub.size = Vector2i(TAM_RENDER, TAM_RENDER)
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)
	_mundo = Node3D.new()
	_sub.add_child(_mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sol.light_energy = 1.1
	_mundo.add_child(sol)
	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.9
	entorno.environment = env
	_mundo.add_child(entorno)
	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_mundo.add_child(_camara)
	DirAccess.make_dir_recursive_absolute(SALIDA)
	_procesar_todo()


func _procesar_todo() -> void:
	for ruta: String in MODELOS:
		await _procesar_modelo(ruta)
	print("[PREVIEW] hecho, PNGs en %s" % SALIDA)
	get_tree().quit()


func _procesar_modelo(ruta: String) -> void:
	var prefijo: String = ruta.get_file().get_basename()
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	if doc.append_from_file(ruta, estado) != OK:
		push_error("preview: no se pudo cargar %s" % ruta)
		return
	var modelo: Node3D = doc.generate_scene(estado) as Node3D
	if modelo == null:
		push_error("preview: generate_scene nulo en %s" % ruta)
		return
	_mundo.add_child(modelo)
	_encuadrar(modelo)
	var esqueleto: Skeleton3D = null
	for hijo: Node in modelo.find_children("*", "Skeleton3D", true, false):
		esqueleto = hijo
		break
	var reproductor: AnimationPlayer = null
	for hijo: Node in modelo.find_children("*", "AnimationPlayer", true, false):
		reproductor = hijo
		break
	if reproductor != null and reproductor.has_animation(ANIM_REPOSO):
		reproductor.speed_scale = 0.0
		var anim: Animation = reproductor.get_animation(ANIM_REPOSO)
		reproductor.play(ANIM_REPOSO, 0.0)
		reproductor.seek(0.0, true)
	var frente: Vector3 = _frente_de(esqueleto)
	var correccion: float = deg_to_rad(CORRECCION_FRENTE_GRADOS)
	var rumbo_reposo: float = atan2(frente.x, frente.z) + correccion
	# SUR: el objetivo es que el personaje mire a cámara (rumbo 0 en el sistema de la cámara).
	modelo.rotation = Vector3(0.0, -rumbo_reposo, 0.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = _recortar(_sub.get_texture().get_image())
	img.save_png(SALIDA + prefijo + ".png")
	print("[PREVIEW] %s guardado" % prefijo)
	_mundo.remove_child(modelo)
	modelo.queue_free()
	await get_tree().process_frame


func _encuadrar(modelo: Node3D) -> void:
	var caja: AABB = _caja_de(modelo)
	var centro: Vector3 = caja.get_center()
	var alto: float = maxf(caja.size.y, maxf(caja.size.x, caja.size.z))
	_camara.size = alto * 1.15
	var yaw: float = deg_to_rad(45.0)
	var pitch: float = deg_to_rad(ELEVACION_GRADOS)
	var distancia: float = alto * 3.0
	_camara.position = centro + Vector3(
		sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)
	) * distancia
	_camara.look_at(centro, Vector3.UP)


func _caja_de(nodo: Node) -> AABB:
	var caja := AABB()
	var primera := true
	for hijo: Node in nodo.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		var suya: AABB = mi.get_aabb()
		suya = mi.global_transform * suya if mi.is_inside_tree() else suya
		if primera:
			caja = suya
			primera = false
		else:
			caja = caja.merge(suya)
	return caja


func _frente_de(esqueleto: Skeleton3D) -> Vector3:
	if esqueleto == null:
		return Vector3.BACK
	var pie: int = _hueso(esqueleto, HUESO_PIE)
	var punta: int = _hueso(esqueleto, HUESO_PUNTA)
	if pie < 0 or punta < 0:
		return Vector3.BACK
	var d: Vector3 = (
		esqueleto.get_bone_global_rest(punta).origin - esqueleto.get_bone_global_rest(pie).origin
	)
	d.y = 0.0
	return d.normalized() if d.length() > 0.0001 else Vector3.BACK


func _hueso(esqueleto: Skeleton3D, prefijo: String) -> int:
	for i: int in esqueleto.get_bone_count():
		if esqueleto.get_bone_name(i).begins_with(prefijo):
			return i
	return -1


func _recortar(imagen: Image) -> Image:
	var usado: Rect2i = imagen.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		return imagen
	return imagen.get_region(usado)
