extends Node3D
## Sonda de DEMOSTRACIÓN: pose de "sentado" de verdad sobre el único rig con pierna completa
## del proyecto (`capturas/NPC/girl.glb`, 74 huesos), comparada con lo que hay hoy (banco +
## ciudadanos actuales, que no tienen muslo ni rodilla).
##
## Copia el andamiaje de tools/render_sprites.gd (cámara isométrica ortográfica, SubViewport
## transparente, encuadre por AABB, recorte, guardado a una altura objetivo). NO es un pipeline
## de producción: es un banco de pruebas para decidir si merece la pena encargar un rig nuevo.
##
## FASE 1 (ACTIVA_VOLCADO_HUESOS = true): solo imprime el esqueleto completo por consola, para no
## adivinar nombres de huesos de pie/puntera en un rig ajeno (ver `_frente_de` en render_sprites.gd:
## "con los rigs ajenos no se supone: se mide").
## FASE 2: construye la pose de pie y varias sentadas (ángulos distintos) y las guarda como PNG.

const MODELO := "res://capturas/NPC/girl.glb"
const TAM_RENDER: int = 512
const ELEVACION_GRADOS: float = 26.565
const ALTURA_OBJETIVO: int = 44
const SALIDA_DIR := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/e2c7999d-e339-490c-a281-ff422a3ef574/scratchpad/"

## FASE 1: pon esto a true para solo volcar la lista de huesos y salir (no renderiza nada).
const ACTIVA_VOLCADO_HUESOS: bool = false

## Huesos de pierna del rig completo (nombres reales, confirmados en el volcado de FASE 1).
const HUESO_CADERA_IZQ := "LeftUpLeg_068"
const HUESO_CADERA_DER := "RightUpLeg_063"
const HUESO_RODILLA_IZQ := "LeftLeg_069"
const HUESO_RODILLA_DER := "RightLeg_064"
const HUESO_RAIZ := "Hips_01"
## Huesos de pie, para derivar el frente igual que hace render_sprites.gd (medido, no supuesto).
const HUESO_PIE := "LeftFoot_070"
const HUESO_PUNTA := "LeftToeBase_071"
## Huesos de brazo. Se bajan de la T-pose ANTES de comparar: unos brazos en cruz harían que la
## figura se leyera "rota" por el brazo, no por la pierna, y contaminarían el juicio sobre si la
## PIERNA se lee como sentada. Mismo criterio y mismo ángulo que `render_sprites.gd`
## (`SENTADO_BRAZO = 20.0`, brazos caídos con las manos hacia el muslo).
const HUESO_BRAZO_IZQ := "LeftArm_037"
const HUESO_BRAZO_DER := "RightArm_011"
const SENTADO_BRAZO_GRADOS: float = 20.0
const SEPARACION_BRAZOS: float = 0.22

## Ángulos de cadera/rodilla a probar (grados). Se guarda un PNG por ángulo.
const ANGULOS_A_PROBAR: Array[float] = [70.0, 80.0, 90.0, 100.0]
## Cuánto se baja la cadera (en fracción de la altura de referencia) para que las nalgas queden a
## la altura del asiento. Se prueba junto con el ángulo.
const BAJADA_CADERA_FRACCION: float = 0.12

var _modelo: Node3D
var _camara: Camera3D
var _sub: SubViewport
var _alto_referencia: int = 0
var _esqueleto: Skeleton3D


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	if escena == null:
		push_error("no se pudo cargar %s" % MODELO)
		get_tree().quit(1)
		return

	_sub = SubViewport.new()
	_sub.size = Vector2i(TAM_RENDER, TAM_RENDER)
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)

	var mundo := Node3D.new()
	_sub.add_child(mundo)
	_modelo = escena.instantiate()
	mundo.add_child(_modelo)

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

	_esqueleto = _buscar_esqueleto(_modelo)
	if _esqueleto == null:
		push_error("el modelo NO trae Skeleton3D")
		get_tree().quit(1)
		return

	if ACTIVA_VOLCADO_HUESOS:
		_volcar_huesos()
		get_tree().quit()
		return

	_encuadrar()
	await _renderizar_todo()
	get_tree().quit()


func _volcar_huesos() -> void:
	print("[HUESOS] %d huesos en total:" % _esqueleto.get_bone_count())
	for i: int in _esqueleto.get_bone_count():
		var padre: int = _esqueleto.get_bone_parent(i)
		var nombre_padre: String = _esqueleto.get_bone_name(padre) if padre >= 0 else "(raiz)"
		print("  [%d] %s  <- padre: %s" % [i, _esqueleto.get_bone_name(i), nombre_padre])


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


func _hueso(prefijo: String) -> int:
	for i: int in _esqueleto.get_bone_count():
		if _esqueleto.get_bone_name(i).begins_with(prefijo):
			return i
	return -1


func _frente_de() -> Vector3:
	var pie: int = _hueso(HUESO_PIE)
	var punta: int = _hueso(HUESO_PUNTA)
	if pie < 0 or punta < 0:
		push_warning("no se encontraron huesos de pie/punta -> frente = BACK por defecto")
		return Vector3.BACK
	var d: Vector3 = (
		_esqueleto.get_bone_global_rest(punta).origin - _esqueleto.get_bone_global_rest(pie).origin
	)
	d.y = 0.0
	return d.normalized() if d.length() > 0.0001 else Vector3.BACK


func _aplicar_giro(idx: int, giro_mundo: Basis) -> void:
	var reposo_local: Transform3D = _esqueleto.get_bone_rest(idx)
	var base: Basis = _esqueleto.get_bone_global_rest(idx).basis.orthonormalized()
	var local: Basis = base.inverse() * giro_mundo * base
	_esqueleto.set_bone_pose_position(idx, reposo_local.origin)
	_esqueleto.set_bone_pose_rotation(idx, Quaternion((reposo_local.basis * local).orthonormalized()))
	_esqueleto.set_bone_pose_scale(idx, Vector3.ONE)


func _girar_mundo(prefijo: String, eje: Vector3, angulo: float) -> void:
	var idx: int = _hueso(prefijo)
	if idx < 0:
		push_warning("hueso no encontrado: %s" % prefijo)
		return
	_aplicar_giro(idx, Basis(eje.normalized(), angulo))


## Hacia dónde APUNTA un hueso en su postura de reposo, en coordenadas del mundo: del hueso a su
## hijo. Copiado de `render_sprites.gd::_direccion_de` (mismo razonamiento: no se supone la
## orientación de los ejes locales de un rig ajeno, se mide con el hijo).
func _direccion_de(idx: int) -> Vector3:
	var hijos: PackedInt32Array = _esqueleto.get_bone_children(idx)
	if hijos.is_empty():
		return Vector3.DOWN
	var origen: Vector3 = _esqueleto.get_bone_global_rest(idx).origin
	var destino: Vector3 = _esqueleto.get_bone_global_rest(hijos[0]).origin
	var d: Vector3 = destino - origen
	return d.normalized() if d.length() > 0.0001 else Vector3.DOWN


## Baja un brazo de la T-pose hasta pegarlo al cuerpo. Copiado de
## `render_sprites.gd::_bajar_y_balancear` (sin el balanceo del paso: aquí está sentada y quieta).
func _bajar_brazo(prefijo: String, lateral: Vector3) -> void:
	var idx: int = _hueso(prefijo)
	if idx < 0:
		push_warning("hueso no encontrado: %s" % prefijo)
		return
	var actual: Vector3 = _direccion_de(idx)
	var lado: float = signf(actual.x) if absf(actual.x) > 0.001 else 1.0
	var objetivo: Vector3 = Vector3(lado * SEPARACION_BRAZOS, -1.0, 0.0).normalized()
	var bajada := Basis(Quaternion(actual, objetivo))
	_aplicar_giro(idx, Basis(lateral, deg_to_rad(SENTADO_BRAZO_GRADOS)) * bajada)


## Deja el esqueleto en reposo puro (de pie, sin tocar huesos).
func _posar_de_pie() -> void:
	for i: int in _esqueleto.get_bone_count():
		_esqueleto.reset_bone_pose(i)


## Pose sentada: cadera y rodilla dobladas `angulo_grados`, con los signos indicados. Ver
## render_sprites.gd `_posar_sentado`: el mismo criterio, pero aquí se PARAMETRIZA el ángulo
## para poder comparar varios de un vistazo (85° allí salió bien con un rig sin pierna simulada
## a mano; aquí hay pierna de verdad y hay que MIRAR cuál se lee mejor).
func _posar_sentado(angulo_grados: float, signo_cadera: float, signo_rodilla: float) -> void:
	_posar_de_pie()
	var frente: Vector3 = _frente_de()
	var lateral: Vector3 = Vector3.UP.cross(frente).normalized()
	var rad: float = deg_to_rad(angulo_grados)
	_girar_mundo(HUESO_CADERA_IZQ, lateral, signo_cadera * rad)
	_girar_mundo(HUESO_CADERA_DER, lateral, signo_cadera * rad)
	_girar_mundo(HUESO_RODILLA_IZQ, lateral, signo_rodilla * rad)
	_girar_mundo(HUESO_RODILLA_DER, lateral, signo_rodilla * rad)
	_bajar_brazo(HUESO_BRAZO_IZQ, lateral)
	_bajar_brazo(HUESO_BRAZO_DER, lateral)
	# Baja la raíz para que las nalgas caigan a la altura del asiento (no cambia el escalado: se
	# guarda con el MISMO factor que la pose de pie, ver `_guardar`).
	var idx_raiz: int = _hueso(HUESO_RAIZ)
	if idx_raiz >= 0:
		var pose_actual: Transform3D = _esqueleto.get_bone_pose(idx_raiz)
		var alto_modelo: float = _caja_de(_modelo).size.y
		pose_actual.origin.y -= alto_modelo * BAJADA_CADERA_FRACCION
		_esqueleto.set_bone_pose_position(idx_raiz, pose_actual.origin)


## Gira el modelo entero para que su frente mire hacia la cámara (dirección FRONTAL/sur del
## pipeline: el modelo mirando hacia +Z de la cámara, es decir, hacia el espectador).
func _mirar_a_camara() -> void:
	var frente: Vector3 = _frente_de()
	var rumbo_reposo: float = atan2(frente.x, frente.z)
	# Dirección "sur" del rombo isométrico de render_sprites.gd: el personaje avanzando hacia el
	# espectador. En el sistema de esa función, ese es el objetivo cuando rumbo apunta hacia la
	# cámara, o sea, hacia +Z visto desde el mundo de la escena (frente a la posición de cámara
	# proyectada en el plano XZ). Aquí basta con mirar hacia la cámara en el plano XZ.
	var hacia_camara: Vector3 = (_camara.position - _modelo.global_transform.origin)
	hacia_camara.y = 0.0
	hacia_camara = hacia_camara.normalized()
	var objetivo: float = atan2(hacia_camara.x, hacia_camara.z)
	_modelo.rotation = Vector3(0.0, objetivo - rumbo_reposo, 0.0)


func _recortar(imagen: Image) -> Image:
	var usado: Rect2i = imagen.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		return imagen
	return imagen.get_region(usado)


func _guardar(imagen: Image, nombre: String) -> void:
	var recortada: Image = _recortar(imagen)
	var escala: float = float(ALTURA_OBJETIVO) / float(maxi(_alto_referencia, 1))
	recortada.resize(
		maxi(1, roundi(float(recortada.get_width()) * escala)),
		maxi(1, roundi(float(recortada.get_height()) * escala)),
		Image.INTERPOLATE_LANCZOS
	)
	DirAccess.make_dir_recursive_absolute(SALIDA_DIR)
	recortada.save_png(SALIDA_DIR + nombre + ".png")
	print("[GUARDADO] %s (%dx%d)" % [nombre, recortada.get_width(), recortada.get_height()])


func _renderizar_todo() -> void:
	_mirar_a_camara()
	_posar_de_pie()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img_pie: Image = _sub.get_texture().get_image()
	_alto_referencia = _recortar(img_pie).get_height()
	print("[RENDER] altura de referencia (de pie, sin escalar): %d px" % _alto_referencia)
	_guardar(img_pie, "de_pie")

	for angulo: float in ANGULOS_A_PROBAR:
		_posar_sentado(angulo, -1.0, 1.0)
		_mirar_a_camara()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		_guardar(_sub.get_texture().get_image(), "sentada_%d" % int(angulo))

	# Comprobación de perfil: SOLO para verificar con los ojos que la rodilla dobla hacia
	# DELANTE (hacia cámara) y no hacia el lado. Gira el modelo 90° extra sobre el frontal, así
	# que la cámara lo ve de lado. No forma parte de la hoja final, es una prueba de sanidad.
	_posar_sentado(90.0, -1.0, 1.0)
	_mirar_a_camara()
	_modelo.rotation.y += deg_to_rad(90.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_guardar(_sub.get_texture().get_image(), "sentada_90_perfil")

	print("[RENDER] hecho.")
