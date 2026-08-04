extends Node3D
## Renderizador de PRODUCCIÓN de las 14 VARIANTES DE COLOR de los ciudadanos civiles (2 por cada uno
## de los 7 modelos: b/c). Combina los dos pipelines ya existentes:
## - El render completo (8 direcciones x 8 fotogramas de andar + 8 de sentado, a 44 y 88 px, escrito
##   directo en `assets/sprites/personajes/`) de `tools/render_sprites_civiles.gd`.
## - El mecanismo de recolor por celdas (blit_rect de un color plano sobre la textura-atlas propia
##   del `.glb`, SOLO en la malla "Cube_003" -- nunca "Cube_001", los ojos) de
##   `tools/_render_variantes_civiles.gd`, con el MISMO mapa celda->color que ya aprobó el usuario en
##   la hoja de propuesta (`hoja_variantes_civiles.png`, fila-columna b/c).
##
## No inventa colores nuevos: cada entrada de `TRABAJOS` es copia literal de los `recolores` de
## `_render_variantes_civiles.gd` para ese modelo/sufijo.
##
## ── PREFIJOS ───────────────────────────────────────────────────────────────────────────────────
## Sufijo b/c pegado al prefijo del modelo original (contrato de `muneco.gd`: `{prefijo}_{alto}px_...`,
## sin guiones) -- `civil_h1` -> `civil_h1b`/`civil_h1c`, etc.
##
## ── CÓMO SE USA ────────────────────────────────────────────────────────────────────────────────
##   godot --path <proyecto> res://tools/RenderVariantesCivilesProduccion.tscn
## No puede correr en headless (necesita GPU). Escribe DIRECTO en `assets/sprites/personajes/`.

## La rejilla de la textura-atlas de cada `.glb` (confirmada por `_diag_celdas_civiles.gd`).
const REJILLA_COLUMNAS: int = 8
const REJILLA_FILAS: int = 4
## La malla de CUERPO (piel/ropa/pelo/zapatos) es siempre esta -- "Cube_001" son los ojos, aparte.
const MALLA_CUERPO := "Cube_003"

## Misma paleta apagada que `_render_variantes_civiles.gd` (fuente de verdad de los colores
## aprobados en la hoja) -- copiada literal, un solo sitio para tocar el tono si hiciera falta.
const ROPA_AZUL := Color(0.28, 0.38, 0.50)
const ROPA_VERDE := Color(0.30, 0.42, 0.32)
const ROPA_TERRACOTA := Color(0.72, 0.42, 0.30)
const ROPA_BURDEOS := Color(0.45, 0.18, 0.22)
const PELO_CASTANO := Color(0.36, 0.23, 0.16)
const PELO_NEGRO := Color(0.11, 0.11, 0.11)
const PELO_RUBIO := Color(0.83, 0.69, 0.42)
const PELO_CANOSO := Color(0.72, 0.72, 0.69)

## 14 trabajos (7 modelos x variantes b/c). `recolores` es literal a lo aprobado en la hoja de
## propuesta -- ver cabecera de `_render_variantes_civiles.gd` para el porqué de cada celda.
const TRABAJOS: Array[Dictionary] = [
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/generic_male.glb", "prefijo": "civil_h1b",
		"correccion_frente_grados": 90.0,
		"recolores": [{"celda": Vector2i(1, 2), "color": ROPA_AZUL}],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/generic_male.glb", "prefijo": "civil_h1c",
		"correccion_frente_grados": 90.0,
		"recolores": [{"celda": Vector2i(1, 2), "color": ROPA_TERRACOTA}],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/generic_female.glb", "prefijo": "civil_m1b",
		"correccion_frente_grados": 90.0,
		"recolores": [
			{"celda": Vector2i(1, 2), "color": ROPA_VERDE}, {"celda": Vector2i(7, 0), "color": PELO_NEGRO},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/generic_female.glb", "prefijo": "civil_m1c",
		"correccion_frente_grados": 90.0,
		"recolores": [
			{"celda": Vector2i(1, 2), "color": ROPA_BURDEOS}, {"celda": Vector2i(7, 0), "color": PELO_RUBIO},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/citizen1.glb", "prefijo": "civil_h2b",
		"correccion_frente_grados": 90.0,
		"recolores": [
			{"celda": Vector2i(4, 2), "color": ROPA_AZUL}, {"celda": Vector2i(1, 1), "color": PELO_CASTANO},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/citizen1.glb", "prefijo": "civil_h2c",
		"correccion_frente_grados": 90.0,
		"recolores": [
			{"celda": Vector2i(4, 2), "color": ROPA_VERDE}, {"celda": Vector2i(1, 1), "color": PELO_CANOSO},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/citizen2.glb", "prefijo": "civil_h3b",
		"correccion_frente_grados": 90.0,
		"recolores": [
			{"celda": Vector2i(3, 0), "color": ROPA_TERRACOTA}, {"celda": Vector2i(0, 0), "color": PELO_RUBIO},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/citizen2.glb", "prefijo": "civil_h3c",
		"correccion_frente_grados": 90.0,
		"recolores": [
			{"celda": Vector2i(3, 0), "color": ROPA_BURDEOS}, {"celda": Vector2i(0, 0), "color": PELO_CASTANO},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/citizen3.glb", "prefijo": "civil_m2b",
		"correccion_frente_grados": 90.0,
		"recolores": [{"celda": Vector2i(6, 2), "color": ROPA_AZUL}],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/citizen3.glb", "prefijo": "civil_m2c",
		"correccion_frente_grados": 90.0,
		"recolores": [{"celda": Vector2i(6, 2), "color": ROPA_VERDE}],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/retail_worker.glb", "prefijo": "civil_h4b",
		"correccion_frente_grados": 90.0,
		"recolores": [
			{"celda": Vector2i(0, 2), "color": ROPA_BURDEOS}, {"celda": Vector2i(6, 0), "color": PELO_NEGRO},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/retail_worker.glb", "prefijo": "civil_h4c",
		"correccion_frente_grados": 90.0,
		"recolores": [
			{"celda": Vector2i(0, 2), "color": ROPA_AZUL}, {"celda": Vector2i(6, 0), "color": PELO_CANOSO},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/crypto_bro.glb", "prefijo": "civil_h5b",
		"correccion_frente_grados": 90.0,
		"recolores": [
			{"celda": Vector2i(0, 0), "color": ROPA_VERDE}, {"celda": Vector2i(6, 0), "color": PELO_RUBIO},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/crypto_bro.glb", "prefijo": "civil_h5c",
		"correccion_frente_grados": 90.0,
		"recolores": [
			{"celda": Vector2i(0, 0), "color": ROPA_TERRACOTA}, {"celda": Vector2i(6, 0), "color": PELO_CASTANO},
		],
	},
]
const SALIDA := "res://assets/sprites/personajes/"

const ELEVACION_GRADOS: float = 26.565
const DIRECCIONES: int = 8
const DIRECCION_SUR: int = 6
const TAM_RENDER: int = 512
const ALTURAS: Array[int] = [88, 44]

const ANIM_ANDAR := "Armature|Walk"
const ANIM_REPOSO := "Armature|Idle"
const FOTOGRAMAS: int = 8

const HUESO_RAIZ := "CORE"
const HUESO_PIE := "Foot.L"
const HUESO_PUNTA := "Toes.L"
const HUESO_PIERNA_IZQ := "Foot.L"
const HUESO_PIERNA_DER := "Foot.R"

const SENTADO_GRADOS_PIE: float = 85.0
const SENTADO_BAJADA_FRACCION: float = 0.5
const SENTADO_SIGNO_PIE_FINAL: float = -1.0

var _sub: SubViewport
var _camara: Camera3D
var _mundo: Node3D
var _modelo: Node3D
var _alto_referencia: int = 0
var _procesados: Array[String] = []


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

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	_procesar_todo()


func _procesar_todo() -> void:
	for trabajo: Dictionary in TRABAJOS:
		await _procesar_variante(trabajo)
	_generar_index()
	print("[RENDER-VARIANTES] hecho: %d/%d variantes procesadas" % [_procesados.size(), TRABAJOS.size()])
	get_tree().quit()


func _procesar_variante(trabajo: Dictionary) -> void:
	var ruta: String = trabajo["ruta"]
	var prefijo: String = trabajo["prefijo"]
	print("[RENDER-VARIANTES] === %s (%s) ===" % [prefijo, ruta])

	var raiz: Node3D = _cargar_glb(ruta)
	if raiz == null:
		push_error("RenderVariantesCivilesProduccion: no se pudo cargar %s -> se salta %s" % [ruta, prefijo])
		return
	_modelo = raiz
	_mundo.add_child(_modelo)

	var recolores: Array = trabajo["recolores"]
	_recolorear(_modelo, recolores, prefijo)

	_encuadrar()

	var esqueleto: Skeleton3D = _buscar_esqueleto(_modelo)
	var reproductor: AnimationPlayer = _buscar_animation_player(_modelo)
	if esqueleto == null:
		push_warning("RenderVariantesCivilesProduccion: %s no trae Skeleton3D" % prefijo)
	if reproductor == null:
		push_warning("RenderVariantesCivilesProduccion: %s no trae AnimationPlayer -> sale en su pose original" % prefijo)
	else:
		reproductor.speed_scale = 0.0

	var anim_andar: String = _resolver_animacion(reproductor, ANIM_ANDAR)
	var anim_reposo: String = _resolver_animacion(reproductor, ANIM_REPOSO)

	var frente: Vector3 = _frente_de(esqueleto)
	var correccion: float = deg_to_rad(float(trabajo.get("correccion_frente_grados", 0.0)))
	var rumbo_reposo: float = atan2(frente.x, frente.z) + correccion

	_muestrear(reproductor, anim_reposo, 0.0)
	_anular_root_motion(esqueleto)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_alto_referencia = _recortar(_sub.get_texture().get_image()).get_height()
	print("[RENDER-VARIANTES] %s: altura de referencia (de pie) = %d px" % [prefijo, _alto_referencia])

	for i: int in DIRECCIONES:
		var rumbo: float = TAU / DIRECCIONES * i
		var objetivo: float = atan2(cos(rumbo), sin(rumbo))
		_modelo.rotation = Vector3(0.0, objetivo - rumbo_reposo, 0.0)

		for f: int in FOTOGRAMAS:
			var t: float = float(f) / float(FOTOGRAMAS)
			_muestrear(reproductor, anim_andar, t)
			_anular_root_motion(esqueleto)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			_guardar(_recortar(_sub.get_texture().get_image()), prefijo, "%d_%d" % [i, f])
		print("[RENDER-VARIANTES] %s: dirección %d/%d lista (%d fotogramas)" % [prefijo, i + 1, DIRECCIONES, FOTOGRAMAS])

	var bajada: float = _largo_pierna(esqueleto) * SENTADO_BAJADA_FRACCION
	var idx_raiz_diag: int = _hueso(esqueleto, HUESO_RAIZ) if esqueleto != null else -1
	_muestrear(reproductor, anim_reposo, 0.0)
	if reproductor != null:
		reproductor.stop(true)
	_anular_root_motion(esqueleto)
	var core_y_base: float = (
		esqueleto.get_bone_pose_position(idx_raiz_diag).y if idx_raiz_diag >= 0 else 0.0
	)
	for i: int in DIRECCIONES:
		var rumbo_s: float = TAU / DIRECCIONES * i
		var objetivo_s: float = atan2(cos(rumbo_s), sin(rumbo_s))
		_modelo.rotation = Vector3(0.0, objetivo_s - rumbo_reposo, 0.0)
		_muestrear(reproductor, anim_reposo, 0.0)
		if reproductor != null:
			reproductor.stop(true)
		_anular_root_motion(esqueleto)
		_posar_sentado(esqueleto, SENTADO_SIGNO_PIE_FINAL, true, bajada, core_y_base)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		_guardar(_recortar(_sub.get_texture().get_image()), prefijo, "sit_%d" % i)
	print("[RENDER-VARIANTES] %s: 8 direcciones de sentado listas" % prefijo)

	_procesados.append(prefijo)
	_mundo.remove_child(_modelo)
	_modelo.queue_free()
	_modelo = null


## Recolorea, EN LA COPIA de textura que ya trae el `.glb` recién cargado (instancia propia, no
## compartida entre variantes -- cada trabajo llama a `_cargar_glb` desde cero), las celdas pedidas
## de la malla "Cube_003" (cuerpo) con un color PLANO. NUNCA toca "Cube_001" (ojos).
func _recolorear(modelo: Node3D, recolores: Array, prefijo: String) -> void:
	if recolores.is_empty():
		return
	var cuerpo: MeshInstance3D = null
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		if hijo.name == MALLA_CUERPO:
			cuerpo = hijo as MeshInstance3D
			break
	if cuerpo == null:
		push_warning("RenderVariantesCivilesProduccion: %s no tiene '%s' -> no se recolorea nada" % [prefijo, MALLA_CUERPO])
		return
	for s: int in cuerpo.mesh.get_surface_count():
		var mat: Material = cuerpo.get_active_material(s)
		if not (mat is BaseMaterial3D):
			continue
		var bm := mat as BaseMaterial3D
		var tex: Texture2D = bm.albedo_texture
		if tex == null:
			continue
		var propia: Image = tex.get_image()
		var ancho_celda: int = propia.get_width() / REJILLA_COLUMNAS
		var alto_celda: int = propia.get_height() / REJILLA_FILAS
		for spec: Dictionary in recolores:
			var celda: Vector2i = spec["celda"]
			var color: Color = spec["color"]
			var relleno := Image.create(ancho_celda, alto_celda, false, Image.FORMAT_RGBA8)
			relleno.fill(color)
			var destino := Vector2i(celda.x * ancho_celda, celda.y * alto_celda)
			propia.blit_rect(relleno, Rect2i(Vector2i.ZERO, Vector2i(ancho_celda, alto_celda)), destino)
		bm.albedo_texture = ImageTexture.create_from_image(propia)


func _cargar_glb(ruta: String) -> Node3D:
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	var err: Error = doc.append_from_file(ruta, estado)
	if err != OK:
		push_error("RenderVariantesCivilesProduccion: append_from_file(%s) -> error %d" % [ruta, err])
		return null
	var raiz: Node = doc.generate_scene(estado)
	if raiz == null:
		push_error("RenderVariantesCivilesProduccion: generate_scene(%s) devolvió null" % ruta)
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
			push_warning("RenderVariantesCivilesProduccion: usando animación '%s' en vez de '%s'" % [nombre, deseada])
			return String(nombre)
	push_warning("RenderVariantesCivilesProduccion: no se encontró animación '%s'. Disponibles: %s" % [
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


func _guardar(imagen: Image, prefijo: String, sufijo: String) -> void:
	for alto: int in ALTURAS:
		var escala: float = float(alto) / float(maxi(_alto_referencia, 1))
		var copia: Image = imagen.duplicate()
		copia.resize(
			maxi(1, roundi(float(copia.get_width()) * escala)),
			maxi(1, roundi(float(copia.get_height()) * escala)),
			Image.INTERPOLATE_LANCZOS
		)
		var ruta: String = "%s%s_%dpx_%s.png" % [SALIDA, prefijo, alto, sufijo]
		copia.save_png(ProjectSettings.globalize_path(ruta))


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


func _posar_sentado(
	esqueleto: Skeleton3D, signo_pie: float, bajar_cuerpo: bool, bajada: float, core_y_base: float
) -> void:
	if esqueleto == null:
		return
	var frente: Vector3 = _frente_de(esqueleto)
	var lateral: Vector3 = Vector3.UP.cross(frente).normalized()
	for hueso: String in [HUESO_PIERNA_IZQ, HUESO_PIERNA_DER]:
		_girar_mundo(esqueleto, hueso, lateral, signo_pie * deg_to_rad(SENTADO_GRADOS_PIE))
	var idx_raiz: int = _hueso(esqueleto, HUESO_RAIZ)
	if idx_raiz >= 0:
		var y_local: float = core_y_base
		if bajar_cuerpo:
			var delta_mundo := Vector3(0.0, -bajada, 0.0)
			var delta_local: Vector3 = esqueleto.global_transform.basis.inverse() * delta_mundo
			y_local += delta_local.y
		var pos: Vector3 = esqueleto.get_bone_pose_position(idx_raiz)
		esqueleto.set_bone_pose_position(idx_raiz, Vector3(pos.x, y_local, pos.z))


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


func _generar_index() -> void:
	var partes: PackedStringArray = []
	partes.append("<!DOCTYPE html><html lang=\"es\"><head><meta charset=\"utf-8\">")
	partes.append("<title>Variantes de color de ciudadanos civiles -- render final</title>")
	partes.append(_estilo_index())
	partes.append("</head><body>")
	partes.append("<h1>Variantes de color de ciudadanos civiles -- render final</h1>")
	partes.append(
		"<p>Direccion %d = SUR (el personaje mirando de frente a camara). Todas las imagenes a 88 px, fondo a cuadros para ver la transparencia.</p>"
		% DIRECCION_SUR
	)
	for prefijo: String in _procesados:
		partes.append("<h2>%s</h2>" % prefijo)
		partes.append(_seccion_andar(prefijo))
		partes.append(_seccion_sentado(prefijo))
	if _procesados.is_empty():
		partes.append("<p><strong>Ninguna variante se proceso con exito -- revisa la consola.</strong></p>")
	partes.append("</body></html>")
	var contenido: String = "\n".join(partes)
	var archivo := FileAccess.open(SALIDA + "index_civiles_variantes.html", FileAccess.WRITE)
	if archivo == null:
		push_error("RenderVariantesCivilesProduccion: no se pudo escribir index_civiles_variantes.html")
		return
	archivo.store_string(contenido)
	archivo.close()
	print("[RENDER-VARIANTES] index_civiles_variantes.html escrito en %s" % (SALIDA + "index_civiles_variantes.html"))


func _estilo_index() -> String:
	var checker := "repeating-conic-gradient(#d8d8d8 0% 25%, #f5f5f5 0% 50%) 0 0/16px 16px"
	return (
		"<style>"
		+ "body{font-family:sans-serif;background:#eaeaea;color:#222;padding:16px;}"
		+ "table{border-collapse:collapse;margin-bottom:28px;}"
		+ "td,th{border:1px solid #bbb;padding:2px;text-align:center;font-size:11px;}"
		+ ("td.celda{background:" + checker + ";}")
		+ ".tira{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:28px;}"
		+ (".tira div{background:" + checker + ";padding:4px;text-align:center;font-size:11px;}")
		+ "img{display:block;image-rendering:pixelated;}"
		+ "</style>"
	)


func _seccion_andar(prefijo: String) -> String:
	var partes: PackedStringArray = []
	partes.append("<h3>Ciclo de andar</h3>")
	partes.append("<table><tr><th></th>")
	for f: int in FOTOGRAMAS:
		partes.append("<th>Fotograma %d</th>" % f)
	partes.append("</tr>")
	for i: int in DIRECCIONES:
		var etiqueta_fila: String = "Direccion %d" % i
		if i == DIRECCION_SUR:
			etiqueta_fila += " (SUR)"
		partes.append("<tr><th>%s</th>" % etiqueta_fila)
		for f: int in FOTOGRAMAS:
			var archivo: String = "%s_88px_%d_%d.png" % [prefijo, i, f]
			var etiqueta: String = "dir %d - frame %d" % [i, f]
			partes.append(
				"<td class=\"celda\"><img src=\"%s\" alt=\"%s\" title=\"%s\"></td>"
				% [archivo, etiqueta, etiqueta]
			)
		partes.append("</tr>")
	partes.append("</table>")
	return "\n".join(partes)


func _seccion_sentado(prefijo: String) -> String:
	var partes: PackedStringArray = []
	partes.append("<h3>Sentado -- 8 direcciones (pose final)</h3>")
	partes.append("<div class=\"tira\">")
	for i: int in DIRECCIONES:
		var etiqueta: String = "Direccion %d" % i
		if i == DIRECCION_SUR:
			etiqueta += " (SUR)"
		var archivo: String = "%s_88px_sit_%d.png" % [prefijo, i]
		partes.append("<div>%s<br><img src=\"%s\" alt=\"%s\"></div>" % [etiqueta, archivo, etiqueta])
	partes.append("</div>")
	return "\n".join(partes)
