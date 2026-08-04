extends Node3D
## VARIANTE DE `render_sprites_animado.gd` PARA UNA HOJA DE CONTACTOS RÁPIDA (propuesta, no producción).
##
## El usuario tiene 7 modelos `.glb` candidatos a "ciudadano" (misma serie/autor que los policías ya
## integrados) y necesita VERLOS antes de decidir cuáles entran al juego. En vez de la tanda completa
## de `render_sprites_animado.gd` (8 direcciones × 8 fotogramas de andar + 8 de sentado, por modelo),
## aquí basta con UNA imagen de cada uno: el fotograma 0 del ciclo `Armature|Walk` (que hace de pose de
## pie quieta, mismo criterio que el script original) mirando a cámara-SUR, en los dos tamaños que usa
## el juego (88px y 44px). Toda la maquinaria de encuadre/medida/anulación de root motion se hereda tal
## cual — lo único que cambia es CUÁNTO se renderiza por modelo.
##
## ── QUÉ SE QUITÓ RESPECTO DEL ORIGINAL ────────────────────────────────────────────────────────────
## - El bucle de 8 direcciones × 8 fotogramas: solo se captura la dirección SUR, fotograma 0.
## - Toda la pose de "sentado" (sin rodilla, giro de pierna, bajada de cuerpo): no aplica a una hoja de
##   contactos de pie.
## - El emparejamiento de piel (`_igualar_piel`/`_textura_de`): ningún candidato de esta tanda lo pide.
## - El `index.html` con tablas: la hoja de verdad la monta `tools/_hoja_ciudadanos.gd` a partir de los
##   PNG que este script deja en `SALIDA`.
##
## ── SALIDA ─────────────────────────────────────────────────────────────────────────────────────────
## Al SCRATCHPAD de la sesión, NO a `assets/sprites/personajes/` — esto es una hoja de propuesta, no
## arte final. `SALIDA` es una ruta absoluta de sistema de archivos (fuera de `res://`), así que aquí NO
## se usa `ProjectSettings.globalize_path` como en el original (ese solo tiene sentido para rutas
## `res://`).
##
## ── CÓMO SE USA ────────────────────────────────────────────────────────────────────────────────────
##   godot --path <proyecto> res://tools/_render_hoja_ciudadanos.tscn

## Un trabajo por modelo. `correccion_frente_grados` heredado del hallazgo de `render_sprites_animado.gd`
## (2026-08-01): este rig (sin rodilla, `Foot.L` es la pierna entera desde la cadera) mide el "frente"
## con un desfase constante de +90°. Se aplica a TODOS los candidatos de esta tanda porque son "misma
## serie/autor" que `male_officer.glb`/`female_officer.glb` (mismo esqueleto, mismas animaciones
## Idle/Walk/Sprint/Jump/Grounded) — si algún modelo resultara tener un rig distinto, saldría mirando de
## lado o de espaldas en vez de a cámara, y quedaría anotado como observación en el informe.
const TRABAJOS: Array[Dictionary] = [
	{
		"ruta": "res://capturas/NPC/Policias/candidatos/male_officer.glb", "prefijo": "male_officer",
		"correccion_frente_grados": 90.0,
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/generic_male.glb", "prefijo": "generic_male",
		"correccion_frente_grados": 90.0,
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/generic_female.glb", "prefijo": "generic_female",
		"correccion_frente_grados": 90.0,
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/citizen1.glb", "prefijo": "citizen1",
		"correccion_frente_grados": 90.0,
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/citizen2.glb", "prefijo": "citizen2",
		"correccion_frente_grados": 90.0,
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/citizen3.glb", "prefijo": "citizen3",
		"correccion_frente_grados": 90.0,
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/retail_worker.glb", "prefijo": "retail_worker",
		"correccion_frente_grados": 90.0,
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/crypto_bro.glb", "prefijo": "crypto_bro",
		"correccion_frente_grados": 90.0,
	},
]

## RUTA ABSOLUTA DE SISTEMA DE ARCHIVOS (fuera de `res://` a propósito: hoja de propuesta, no arte
## final -- ver cabecera). `tools/_hoja_ciudadanos.gd` lee de aquí para montar la hoja de contactos.
const SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"

## Cámara: mismo ángulo isométrico que `render_sprites_animado.gd` (`atan(1/2)`, no los 30° "de libro").
const ELEVACION_GRADOS: float = 26.565
const DIRECCIONES: int = 8
## Qué índice de dirección es "SUR" (el personaje mirando de frente a cámara) -- la única que se
## renderiza en esta hoja de propuesta.
const DIRECCION_SUR: int = 6
const TAM_RENDER: int = 512
const ALTURAS: Array[int] = [88, 44]

## Nombre de la animación embebida de andar (confirmado en la radiografía de `render_sprites_animado.gd`
## para este rig). Si no aparece tal cual, `_resolver_animacion` busca la más parecida.
const ANIM_ANDAR := "Armature|Walk"

## El hueso raíz del esqueleto. Se usa para anular el ROOT MOTION (si la animación desplaza al
## personaje, se le devuelve a X=0/Z=0 cada fotograma).
const HUESO_RAIZ := "CORE"
## HACIA DÓNDE MIRA el personaje en reposo: del talón (`Foot.L`) a la punta del pie (`Toes.L`). Con este
## rig, `Foot.L` es la pierna ENTERA (cadera→tobillo, sin rodilla) -- no se supone, se mide (mismo
## principio que el script original).
const HUESO_PIE := "Foot.L"
const HUESO_PUNTA := "Toes.L"

var _sub: SubViewport
var _camara: Camera3D
var _mundo: Node3D
var _modelo: Node3D
## Lo que mide la figura DE PIE (fotograma 0 de Walk) en el render grande -- vara de medir de los dos
## tamaños de salida de ESTE modelo (ver `_guardar`).
var _alto_referencia: int = 0
## Prefijos que se procesaron con éxito, en orden.
var _procesados: Array[String] = []
## Prefijo -> mensaje de error, para los que fallaron (alimenta el informe final).
var _fallidos: Dictionary = {}


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
	for trabajo: Dictionary in TRABAJOS:
		await _procesar_modelo(trabajo)
	print("[RENDER] hecho: %d/%d modelos procesados" % [_procesados.size(), TRABAJOS.size()])
	if not _fallidos.is_empty():
		print("[RENDER] fallidos: %s" % [_fallidos])
	get_tree().quit()


## Carga, encuadra y renderiza UNA sola imagen por modelo: fotograma 0 de `Armature|Walk` mirando a
## cámara-SUR, en los dos tamaños de `ALTURAS`.
func _procesar_modelo(trabajo: Dictionary) -> void:
	var ruta: String = trabajo["ruta"]
	var prefijo: String = trabajo["prefijo"]
	print("[RENDER] === %s (%s) ===" % [prefijo, ruta])

	var raiz: Node3D = _cargar_glb(ruta)
	if raiz == null:
		var msg: String = "no se pudo cargar el .glb (ver consola arriba)"
		push_error("HojaCiudadanos: %s -> %s" % [prefijo, msg])
		_fallidos[prefijo] = msg
		return
	_modelo = raiz
	_mundo.add_child(_modelo)
	_encuadrar()

	var esqueleto: Skeleton3D = _buscar_esqueleto(_modelo)
	var reproductor: AnimationPlayer = _buscar_animation_player(_modelo)
	if esqueleto == null:
		var msg_esq: String = "no trae Skeleton3D"
		push_warning("HojaCiudadanos: %s -> %s" % [prefijo, msg_esq])
		_fallidos[prefijo] = msg_esq
	else:
		_volcar_esqueleto(esqueleto, prefijo)
	if reproductor == null:
		var msg_anim: String = "no trae AnimationPlayer -> sale en su pose original (sin ciclo de andar)"
		push_warning("HojaCiudadanos: %s -> %s" % [prefijo, msg_anim])
		if not _fallidos.has(prefijo):
			_fallidos[prefijo] = msg_anim
	else:
		print("[RENDER] %s: animaciones disponibles: %s" % [prefijo, reproductor.get_animation_list()])
		# Tiempo controlado a mano con `seek`; `speed_scale = 0` evita que avance solo en la espera.
		reproductor.speed_scale = 0.0

	var anim_andar: String = _resolver_animacion(reproductor, ANIM_ANDAR)

	# El FRENTE del personaje en reposo, medido del talón a la punta -- no se supone, se mide (rest
	# pose del esqueleto, independiente de qué animación esté muestreada). Corrección de +90°: ver
	# cabecera de `TRABAJOS`.
	var frente: Vector3 = _frente_de(esqueleto)
	var correccion: float = deg_to_rad(float(trabajo.get("correccion_frente_grados", 0.0)))
	var rumbo_reposo: float = atan2(frente.x, frente.z) + correccion

	var rumbo: float = TAU / DIRECCIONES * DIRECCION_SUR
	var objetivo: float = atan2(cos(rumbo), sin(rumbo))
	_modelo.rotation = Vector3(0.0, objetivo - rumbo_reposo, 0.0)

	# Fotograma 0 del ciclo de andar = pose de pie quieta (mismo criterio que `render_sprites_animado.gd`
	# / "girl"): no hace falta muestrear Idle aparte.
	_muestrear(reproductor, anim_andar, 0.0)
	_anular_root_motion(esqueleto)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = _recortar(_sub.get_texture().get_image())
	_alto_referencia = imagen.get_height()
	print("[RENDER] %s: altura de referencia (de pie, SUR) = %d px" % [prefijo, _alto_referencia])
	_guardar(imagen, prefijo)
	print("[RENDER] %s: imagen SUR guardada en los %d tamaños" % [prefijo, ALTURAS.size()])

	_procesados.append(prefijo)
	_mundo.remove_child(_modelo)
	_modelo.queue_free()
	_modelo = null


## Carga un `.glb` SIN pasar por el sistema de importación del editor (los candidatos viven en
## `capturas/`, sin `.import`): `GLTFDocument` lee el binario directo y `generate_scene` monta el árbol
## de nodos (mallas, Skeleton3D, AnimationPlayer con sus animaciones) en memoria.
func _cargar_glb(ruta: String) -> Node3D:
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	var err: Error = doc.append_from_file(ruta, estado)
	if err != OK:
		push_error("HojaCiudadanos: append_from_file(%s) -> error %d" % [ruta, err])
		return null
	var raiz: Node = doc.generate_scene(estado)
	if raiz == null:
		push_error("HojaCiudadanos: generate_scene(%s) devolvió null" % ruta)
		return null
	return raiz as Node3D


## Coloca la cámara en el ángulo isométrico y la aleja lo justo para que el modelo entre entero, sobre
## la caja del modelo en su pose de reposo (antes de muestrear ninguna animación).
func _encuadrar() -> void:
	var caja: AABB = _caja_de(_modelo)
	var centro: Vector3 = caja.get_center()
	var alto: float = maxf(caja.size.y, maxf(caja.size.x, caja.size.z))
	print("[RENDER] %s: caja del modelo (reposo) = %s -> alto de encuadre = %.5f" % [
		_modelo.name, caja.size, alto
	])
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


## Imprime el árbol de huesos (nombre <- padre) por consola. Diagnóstico: si un candidato falla al
## renderizar la pose esperada, esto ayuda a ver si sus huesos se llaman distinto (`CORE`/`Foot.L`/
## `Toes.L` no encontrados -> `_hueso` devuelve -1 -> `_frente_de` cae a `Vector3.BACK`).
func _volcar_esqueleto(esqueleto: Skeleton3D, prefijo: String) -> void:
	print("[RENDER] %s: %d huesos" % [prefijo, esqueleto.get_bone_count()])
	for clave: String in ["CORE", "Foot.L", "Toes.L", "Foot.R", "Toes.R"]:
		var idx: int = _hueso(esqueleto, clave)
		if idx < 0:
			print("  [!] %s: hueso '%s' NO encontrado" % [prefijo, clave])


## Si el nombre exacto de la animación no está, busca la que más se le parezca entre las que SÍ trae el
## modelo, en vez de fallar en silencio con un muñeco quieto.
func _resolver_animacion(reproductor: AnimationPlayer, deseada: String) -> String:
	if reproductor == null:
		return deseada
	if reproductor.has_animation(deseada):
		return deseada
	for nombre: StringName in reproductor.get_animation_list():
		if String(nombre).find(deseada) >= 0 or deseada.find(String(nombre)) >= 0:
			push_warning("HojaCiudadanos: usando animación '%s' en vez de '%s'" % [nombre, deseada])
			return String(nombre)
	push_warning("HojaCiudadanos: no se encontró animación '%s'. Disponibles: %s" % [
		deseada, reproductor.get_animation_list()
	])
	return deseada


## Pone al `AnimationPlayer` en el instante `t` (0..1 sobre la duración de `nombre`) y aplica la pose AL
## INSTANTE (`seek(..., true)`). Si no hay reproductor o la animación no existe, no hace nada.
func _muestrear(reproductor: AnimationPlayer, nombre: String, t: float) -> void:
	if reproductor == null or not reproductor.has_animation(nombre):
		return
	var anim: Animation = reproductor.get_animation(nombre)
	var duracion: float = maxf(anim.length, 0.0001)
	reproductor.play(nombre, 0.0)
	reproductor.seek(t * duracion, true)


## Si la animación desplaza al personaje (root motion), lo anula: X/Z a 0 en cada `Node3D` desde el
## `Skeleton3D` hasta `_modelo`, y lo mismo con la posición del hueso `CORE` (conservando su Y).
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


## Guarda la imagen en los dos tamaños de `ALTURAS`, escalados con el mismo factor sacado de
## `_alto_referencia` -- ruta ABSOLUTA de sistema de archivos (`SALIDA` ya lo es, sin `res://`).
func _guardar(imagen: Image, prefijo: String) -> void:
	for alto: int in ALTURAS:
		var escala: float = float(alto) / float(maxi(_alto_referencia, 1))
		var copia: Image = imagen.duplicate()
		copia.resize(
			maxi(1, roundi(float(copia.get_width()) * escala)),
			maxi(1, roundi(float(copia.get_height()) * escala)),
			Image.INTERPOLATE_LANCZOS
		)
		var ruta: String = "%s%s_%dpx_sur.png" % [SALIDA, prefijo, alto]
		var err: Error = copia.save_png(ruta)
		if err != OK:
			push_error("HojaCiudadanos: no se pudo guardar %s -> error %d" % [ruta, err])
		else:
			print("[RENDER] guardado: %s" % ruta)


## HACIA DÓNDE MIRA el personaje en reposo, en horizontal: del talón (`HUESO_PIE`) a la punta
## (`HUESO_PUNTA`), sobre la pose de REPOSO del esqueleto (`get_bone_global_rest`).
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


## El índice de un hueso buscándolo por PREFIJO (por si el exportador añadiera algún sufijo). -1 si no
## está.
func _hueso(esqueleto: Skeleton3D, prefijo: String) -> int:
	for i: int in esqueleto.get_bone_count():
		if esqueleto.get_bone_name(i).begins_with(prefijo):
			return i
	return -1


## Quita el aire transparente de alrededor.
func _recortar(imagen: Image) -> Image:
	var usado: Rect2i = imagen.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		return imagen
	return imagen.get_region(usado)
