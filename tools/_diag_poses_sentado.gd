extends Node3D
## SONDA DESECHABLE de investigación visual: qué pose "sentada" es la mejor posible con el rig de
## `generic_male.glb` (27 huesos, sin pierna con rodilla). Copia del andamiaje de
## `tools/render_sprites_civiles.gd` (léelo para el porqué de cada fórmula) reescrita para probar
## variantes de sentado en una sola dirección (frontal, la misma que usa sit_0) y volcar cada
## variante como PNG suelto en el scratchpad de la sesión, para elegir a ojo la mejor.
##
## NO escribe nada en assets/ ni toca el pipeline de producción. Archivo de usar y tirar.
##
## ── CÓMO SE USA ────────────────────────────────────────────────────────────────────────────────
##   "C:\Users\manur\Godot\Godot_v4.6-stable_win64_console.exe" --path "C:/Users/manur/juego" res://tools/_diag_poses_sentado.tscn

const RUTA_GLB := "res://capturas/NPC/Ciudadanos/candidatos/generic_male.glb"
const CORRECCION_FRENTE_GRADOS: float = 90.0

const ELEVACION_GRADOS: float = 26.565
const TAM_RENDER: int = 512
const ALTO_OBJETIVO: int = 44

const ANIM_REPOSO := "Armature|Idle"
const ANIM_GROUNDED := "Armature|Grounded"

const HUESO_RAIZ := "CORE"
const HUESO_PIE := "Foot.L"
const HUESO_PUNTA := "Toes.L"
const HUESO_PIERNA_IZQ := "Foot.L"
const HUESO_PIERNA_DER := "Foot.R"
const HUESO_CUERPO := "Body"

const SENTADO_GRADOS_PIE: float = 85.0
const SENTADO_BAJADA_FRACCION: float = 0.5
const SENTADO_SIGNO_PIE_FINAL: float = -1.0

const SALIDA_POSES := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/e2c7999d-e339-490c-a281-ff422a3ef574/scratchpad/poses_sentado/"

var _sub: SubViewport
var _camara: Camera3D
var _mundo: Node3D
var _modelo: Node3D
var _alto_referencia: int = 0
var _ancho_cuerpo: float = 0.0


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

	DirAccess.make_dir_recursive_absolute(SALIDA_POSES)
	await _procesar()
	print("[DIAG] hecho -> revisa %s" % SALIDA_POSES)
	get_tree().quit()


func _procesar() -> void:
	var raiz: Node3D = _cargar_glb(RUTA_GLB)
	if raiz == null:
		push_error("_diag_poses_sentado: no se pudo cargar %s" % RUTA_GLB)
		return
	_modelo = raiz
	_mundo.add_child(_modelo)
	_ancho_cuerpo = _medir_ancho_cuerpo(_modelo)
	_encuadrar()

	var esqueleto: Skeleton3D = _buscar_esqueleto(_modelo)
	var reproductor: AnimationPlayer = _buscar_animation_player(_modelo)
	if esqueleto == null or reproductor == null:
		push_error("_diag_poses_sentado: falta Skeleton3D o AnimationPlayer")
		return
	reproductor.speed_scale = 0.0
	print("[DIAG] animaciones disponibles: %s" % reproductor.get_animation_list())

	var anim_reposo: String = _resolver_animacion(reproductor, ANIM_REPOSO)
	var anim_grounded: String = _resolver_animacion(reproductor, ANIM_GROUNDED)

	var frente0: Vector3 = _frente_de(esqueleto)
	var correccion: float = deg_to_rad(CORRECCION_FRENTE_GRADOS)
	var rumbo_reposo: float = atan2(frente0.x, frente0.z) + correccion

	# Orientación FRONTAL, la misma que usa sit_0 (i=0 -> rumbo_s=0 -> objetivo_s = atan2(1,0)).
	var objetivo: float = atan2(cos(0.0), sin(0.0))
	_modelo.rotation = Vector3(0.0, objetivo - rumbo_reposo, 0.0)

	# Altura de referencia (de pie), igual que hace el pipeline real, para escalar todo a 44px igual.
	_resetear_pose(esqueleto, reproductor, anim_reposo)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_alto_referencia = _recortar(_sub.get_texture().get_image()).get_height()
	print("[DIAG] altura de referencia (de pie) = %d px | ancho de cuerpo medido = %.5f" % [
		_alto_referencia, _ancho_cuerpo
	])

	# IMPORTANTE (bug encontrado y corregido): AnimationPlayer.seek() en la animación de reposo NO
	# resetea de forma fiable la posición Y del hueso CORE entre llamadas repetidas al mismo nombre de
	# animación (solo tiene pistas de rotación, no de posición, para ese hueso). Por eso, igual que hace
	# `render_sprites_civiles.gd::_posar_sentado()`, capturamos el Y de reposo UNA SOLA VEZ aquí y lo
	# reutilizamos como base fija para todas las variantes -- si en vez de esto cada variante leyera el
	# Y "actual" tras un supuesto reset, el hundimiento se iría acumulando de una variante a la siguiente.
	var idx_raiz_base: int = _hueso(esqueleto, HUESO_RAIZ)
	var core_y_base: float = esqueleto.get_bone_pose_position(idx_raiz_base).y if idx_raiz_base >= 0 else 0.0
	print("[DIAG] CORE Y de reposo (base fija para todas las variantes) = %.5f" % core_y_base)

	var largo_pierna: float = _largo_pierna(esqueleto)
	var bajada_050: float = largo_pierna * 0.5
	var bajada_075: float = largo_pierna * 0.75
	var bajada_100: float = largo_pierna * 1.0
	print("[DIAG] largo de pierna en reposo (CORE->Toes.L) = %.5f" % largo_pierna)

	# 1) ACTUAL -- exactamente lo que hace hoy _posar_sentado() en render_sprites_civiles.gd.
	_resetear_pose(esqueleto, reproductor, anim_reposo)
	_posar_variante(esqueleto, SENTADO_GRADOS_PIE, bajada_050, 0.0, 0.0, core_y_base)
	await _capturar_y_guardar("pose_actual")

	# 2) GROUNDED -- sin tocar huesos a mano, solo muestrear la animación en 5 instantes.
	if reproductor.has_animation(anim_grounded):
		var anim_res: Animation = reproductor.get_animation(anim_grounded)
		print("[DIAG] Armature|Grounded duración = %.4fs" % anim_res.length)
		for muestra: Dictionary in [
			{"t": 0.0, "etq": "t000"}, {"t": 0.25, "etq": "t025"}, {"t": 0.5, "etq": "t050"},
			{"t": 0.75, "etq": "t075"}, {"t": 1.0, "etq": "t100"},
		]:
			_muestrear(reproductor, anim_grounded, muestra["t"])
			_anular_root_motion(esqueleto)
			await _capturar_y_guardar("pose_grounded_%s" % muestra["etq"])
	else:
		push_warning("_diag_poses_sentado: no se encontró animación Grounded")

	# 3) HUNDIDO -- pies 85°, bajada mayor (0.75 y 1.0).
	_resetear_pose(esqueleto, reproductor, anim_reposo)
	_posar_variante(esqueleto, SENTADO_GRADOS_PIE, bajada_075, 0.0, 0.0, core_y_base)
	await _capturar_y_guardar("pose_hundido_075")

	_resetear_pose(esqueleto, reproductor, anim_reposo)
	_posar_variante(esqueleto, SENTADO_GRADOS_PIE, bajada_100, 0.0, 0.0, core_y_base)
	await _capturar_y_guardar("pose_hundido_100")

	# 4) RECOSTADO -- pies 85° + Body girado hacia atrás (probar signo negativo primero).
	_resetear_pose(esqueleto, reproductor, anim_reposo)
	_posar_variante(esqueleto, SENTADO_GRADOS_PIE, bajada_050, -12.0, 0.0, core_y_base)
	await _capturar_y_guardar("pose_recostado_neg12")

	_resetear_pose(esqueleto, reproductor, anim_reposo)
	_posar_variante(esqueleto, SENTADO_GRADOS_PIE, bajada_050, 12.0, 0.0, core_y_base)
	await _capturar_y_guardar("pose_recostado_pos12")

	# 5) PIES ADELANTADOS -- pies 85° + Foot.L/Foot.R desplazados hacia el frente. 2 magnitudes.
	_resetear_pose(esqueleto, reproductor, anim_reposo)
	_posar_variante(esqueleto, SENTADO_GRADOS_PIE, bajada_050, 0.0, _ancho_cuerpo * 0.20, core_y_base)
	await _capturar_y_guardar("pose_pies_adelante_020")

	_resetear_pose(esqueleto, reproductor, anim_reposo)
	_posar_variante(esqueleto, SENTADO_GRADOS_PIE, bajada_050, 0.0, _ancho_cuerpo * 0.40, core_y_base)
	await _capturar_y_guardar("pose_pies_adelante_040")

	# 6) COMBO -- recostado + pies adelantados (con los mejores signos/magnitudes vistos arriba).
	_resetear_pose(esqueleto, reproductor, anim_reposo)
	_posar_variante(esqueleto, SENTADO_GRADOS_PIE, bajada_075, -12.0, _ancho_cuerpo * 0.30, core_y_base)
	await _capturar_y_guardar("pose_combo_recostado_pies")


func _resetear_pose(esqueleto: Skeleton3D, reproductor: AnimationPlayer, anim_reposo: String) -> void:
	_muestrear(reproductor, anim_reposo, 0.0)
	reproductor.stop(true)
	_anular_root_motion(esqueleto)


func _capturar_y_guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var caja_dbg: AABB = _caja_de(_modelo)
	print("[DIAG-DBG] %s: caja tras posar = pos %s size %s" % [nombre, caja_dbg.position, caja_dbg.size])
	var imagen: Image = _recortar(_sub.get_texture().get_image())
	var escala: float = float(ALTO_OBJETIVO) / float(maxi(_alto_referencia, 1))
	imagen.resize(
		maxi(1, roundi(float(imagen.get_width()) * escala)),
		maxi(1, roundi(float(imagen.get_height()) * escala)),
		Image.INTERPOLATE_LANCZOS
	)
	var ruta: String = "%s%s.png" % [SALIDA_POSES, nombre]
	imagen.save_png(ruta)
	print("[DIAG] guardado %s (%dx%d)" % [ruta, imagen.get_width(), imagen.get_height()])


func _posar_variante(
	esqueleto: Skeleton3D, grados_pie: float, bajada: float, body_grados: float,
	pies_adelante_mundo: float, core_y_base: float
) -> void:
	if esqueleto == null:
		return
	var frente: Vector3 = _frente_de(esqueleto)
	var lateral: Vector3 = Vector3.UP.cross(frente).normalized()
	for hueso: String in [HUESO_PIERNA_IZQ, HUESO_PIERNA_DER]:
		_girar_mundo(esqueleto, hueso, lateral, SENTADO_SIGNO_PIE_FINAL * deg_to_rad(grados_pie))
	if body_grados != 0.0:
		_girar_mundo(esqueleto, HUESO_CUERPO, lateral, deg_to_rad(body_grados))
	var idx_raiz: int = _hueso(esqueleto, HUESO_RAIZ)
	if idx_raiz >= 0:
		# Igual que el original _posar_sentado(): el delta va en espacio MUNDO y hay que deshacer la
		# transformación global del Skeleton3D (que puede traer escala del import, no solo rotación)
		# para convertirlo al espacio local en el que vive get/set_bone_pose_position. Restar "bajada"
		# a pelo (sin este basis.inverse()) fue el bug que dejaba el personaje invisible: si el import
		# trae escala != 1 en el Skeleton3D, el delta local queda mal escalado y el hueso CORE se va
		# a una posición disparatada que cae fuera de cualquier AABB de culling -> el mesh entero
		# desaparece del render (confirmado: ni abriendo la cámara x6 reaparecía).
		var delta_mundo := Vector3(0.0, -bajada, 0.0)
		var delta_local: Vector3 = esqueleto.global_transform.basis.inverse() * delta_mundo
		var pos: Vector3 = esqueleto.get_bone_pose_position(idx_raiz)
		esqueleto.set_bone_pose_position(idx_raiz, Vector3(pos.x, core_y_base + delta_local.y, pos.z))
	var idx_pie_dbg: int = _hueso(esqueleto, HUESO_PIERNA_IZQ)
	if idx_pie_dbg >= 0:
		print("[DIAG-DBG] frente=%s lateral=%s Foot.L pos=%s rot=%s CORE pos=%s" % [
			frente, lateral,
			esqueleto.get_bone_pose_position(idx_pie_dbg), esqueleto.get_bone_pose_rotation(idx_pie_dbg),
			(esqueleto.get_bone_pose_position(idx_raiz) if idx_raiz >= 0 else Vector3.INF)
		])
	if pies_adelante_mundo != 0.0:
		var delta_mundo: Vector3 = frente * pies_adelante_mundo
		for hueso: String in [HUESO_PIERNA_IZQ, HUESO_PIERNA_DER]:
			_mover_hueso_mundo(esqueleto, hueso, delta_mundo)


func _mover_hueso_mundo(esqueleto: Skeleton3D, prefijo: String, delta_mundo: Vector3) -> void:
	var idx: int = _hueso(esqueleto, prefijo)
	if idx < 0:
		return
	var padre: int = esqueleto.get_bone_parent(idx)
	var base_local: Basis = Basis.IDENTITY
	if padre >= 0:
		base_local = esqueleto.get_bone_global_rest(padre).basis.orthonormalized()
	# Igual que la corrección del bajado de CORE: hay que deshacer también la escala del
	# Skeleton3D (esqueleto.global_transform), no solo la orientación del hueso padre.
	var base: Basis = esqueleto.global_transform.basis * base_local
	var delta_local: Vector3 = base.inverse() * delta_mundo
	var pos: Vector3 = esqueleto.get_bone_pose_position(idx)
	esqueleto.set_bone_pose_position(idx, pos + delta_local)


func _medir_ancho_cuerpo(nodo: Node) -> float:
	var caja: AABB = _caja_de(nodo)
	# Aproximación genérica: proyecta el tamaño de la caja sobre el eje lateral (perpendicular
	# al frente) usando X/Z, sin asumir a qué eje del mundo está alineado el modelo.
	return maxf(caja.size.x, caja.size.z)


# ── Andamiaje copiado literalmente de render_sprites_civiles.gd (ver ese archivo para el porqué) ──

func _cargar_glb(ruta: String) -> Node3D:
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	var err: Error = doc.append_from_file(ruta, estado)
	if err != OK:
		push_error("_diag_poses_sentado: append_from_file(%s) -> error %d" % [ruta, err])
		return null
	var raiz: Node = doc.generate_scene(estado)
	if raiz == null:
		push_error("_diag_poses_sentado: generate_scene(%s) devolvió null" % ruta)
		return null
	return raiz as Node3D


func _encuadrar() -> void:
	var caja: AABB = _caja_de(_modelo)
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


func _buscar_esqueleto(nodo: Node) -> Skeleton3D:
	for hijo: Node in nodo.find_children("*", "Skeleton3D", true, false):
		return hijo as Skeleton3D
	return null


func _buscar_animation_player(nodo: Node) -> AnimationPlayer:
	for hijo: Node in nodo.find_children("*", "AnimationPlayer", true, false):
		return hijo as AnimationPlayer
	return null


func _resolver_animacion(reproductor: AnimationPlayer, deseada: String) -> String:
	if reproductor == null:
		return deseada
	if reproductor.has_animation(deseada):
		return deseada
	for nombre: StringName in reproductor.get_animation_list():
		if String(nombre).find(deseada) >= 0 or deseada.find(String(nombre)) >= 0:
			push_warning("_diag_poses_sentado: usando animación '%s' en vez de '%s'" % [nombre, deseada])
			return String(nombre)
	push_warning("_diag_poses_sentado: no se encontró animación '%s'. Disponibles: %s" % [
		deseada, reproductor.get_animation_list()
	])
	return deseada


func _muestrear(reproductor: AnimationPlayer, nombre: String, t: float) -> void:
	if reproductor == null or not reproductor.has_animation(nombre):
		return
	var anim: Animation = reproductor.get_animation(nombre)
	var duracion: float = maxf(anim.length, 0.0001)
	reproductor.play(nombre, 0.0)
	reproductor.seek(t * duracion, true)


func _anular_root_motion(esqueleto: Skeleton3D) -> void:
	_modelo.position.x = 0.0
	_modelo.position.z = 0.0
	if esqueleto == null:
		return
	var nodo: Node = esqueleto
	while nodo != null and nodo != _modelo:
		if nodo is Node3D:
			var n3: Node3D = nodo
			n3.position.x = 0.0
			n3.position.z = 0.0
		nodo = nodo.get_parent()
	var idx_raiz: int = _hueso(esqueleto, HUESO_RAIZ)
	if idx_raiz >= 0:
		var pos: Vector3 = esqueleto.get_bone_pose_position(idx_raiz)
		esqueleto.set_bone_pose_position(idx_raiz, Vector3(0.0, pos.y, 0.0))


func _largo_pierna(esqueleto: Skeleton3D) -> float:
	if esqueleto == null:
		return 0.0
	var idx_cadera: int = _hueso(esqueleto, HUESO_RAIZ)
	var idx_tobillo: int = _hueso(esqueleto, HUESO_PUNTA)
	if idx_cadera < 0 or idx_tobillo < 0:
		return 0.0
	var mundo_cadera: Vector3 = esqueleto.global_transform * esqueleto.get_bone_global_rest(idx_cadera).origin
	var mundo_tobillo: Vector3 = esqueleto.global_transform * esqueleto.get_bone_global_rest(idx_tobillo).origin
	return maxf(mundo_cadera.y - mundo_tobillo.y, 0.0)


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


func _aplicar_giro(esqueleto: Skeleton3D, idx: int, giro_mundo: Basis) -> void:
	var reposo_local: Transform3D = esqueleto.get_bone_rest(idx)
	var base: Basis = esqueleto.get_bone_global_rest(idx).basis.orthonormalized()
	var local: Basis = base.inverse() * giro_mundo * base
	esqueleto.set_bone_pose_position(idx, reposo_local.origin)
	esqueleto.set_bone_pose_rotation(idx, Quaternion((reposo_local.basis * local).orthonormalized()))
	esqueleto.set_bone_pose_scale(idx, Vector3.ONE)


func _girar_mundo(esqueleto: Skeleton3D, prefijo: String, eje: Vector3, angulo: float) -> void:
	var idx: int = _hueso(esqueleto, prefijo)
	if idx < 0:
		return
	_aplicar_giro(esqueleto, idx, Basis(eje.normalized(), angulo))


func _recortar(imagen: Image) -> Image:
	var usado: Rect2i = imagen.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		return imagen
	return imagen.get_region(usado)
