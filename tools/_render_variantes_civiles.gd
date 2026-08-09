extends Node3D
## PROPUESTA (scratchpad, NO toca `assets/`): renderiza 2 VARIANTES DE COLOR por cada uno de los 7
## candidatos a ciudadano (además del original), recoloreando SOLO las celdas de "ropa" y/o "pelo" de
## su textura-atlas -- mismo mecanismo que `_igualar_piel` de `render_sprites_animado.gd:360-411`
## (blit_rect sobre una copia de la textura propia del `.glb`), pero rellenando con un COLOR PLANO en
## vez de copiar una celda de otro modelo.
##
## El mapa modelo->celda se sacó de `tools/_diag_celdas_civiles.gd` (análisis de UV + peso de hueso,
## sin GPU): cada personaje comparte el MISMO esqueleto de 27 huesos, y su malla de cuerpo
## (`MeshInstance3D` llamada siempre "Cube_003") pinta cada región (piel, ropa, pelo, zapatos) con una
## celda distinta de una rejilla 8x4 de colores planos en su textura 1024x1024 (`REJILLA_COLUMNAS`x
## `REJILLA_FILAS`). "Cube_001" es SIEMPRE una mallita aparte de 290 vértices en la celda (0,0) (los
## ojos/pupilas) -- por eso el recoloreado solo toca "Cube_003", nunca "Cube_001": si tocara todas las
## mallas, un modelo cuya celda de ropa fuese también (0,0) (crypto_bro) pintaría los OJOS del color de
## la ropa.
##
## ── CONFLICTOS DE CELDA COMPARTIDA (documentados, no corregidos aquí) ─────────────────────────────
## - `citizen2`/`citizen3`: la celda de ROPA también cubre los ZAPATOS (mismo material, misma celda) ->
##   al recolorear la ropa, los zapatos cambian de color con ella (aceptable: mismo look "traje único").
## - `crypto_bro`: la celda de ROPA (0,0, negro) también cubre ~198 vértices de la CABEZA (capucha/gorra
##   -- se interpreta como una prenda de cabeza, no pelo) y una franja mínima de las suelas (24 vértices)
##   -> recolorear "ropa" cambia también esa prenda de cabeza, a propósito (conjunto coherente).
## - `citizen3`: NO tiene celda de pelo propia -- sus ~1140 vértices de "pelo claro" comparten la MISMA
##   celda que la piel de la cara (3,1). Recolorear esa celda cambiaría también la cara -> esta tanda NO
##   toca el pelo de citizen3 (solo 2 variantes de ROPA).
## - `generic_male`: no tiene celda de pelo distinguible (todo el hueso `Head` es piel o labios) ->
##   probablemente pelo muy corto/rapado pintado con el tono de piel -> solo 2 variantes de ROPA.
##
## ── SALIDA ─────────────────────────────────────────────────────────────────────────────────────────
## Ruta ABSOLUTA de sistema de archivos (scratchpad de sesión, NO `res://assets/`): 21 PNG a 88px,
## nomenclatura `{sufijo_fila}-{a|b|c}_88px_sur.png` (a=original, b=variante 1, c=variante 2), más
## `male_officer_88px_sur.png` de referencia si no existe ya en el scratchpad (reutiliza el de la tanda
## anterior si está).
##
## ── CÓMO SE USA ────────────────────────────────────────────────────────────────────────────────────
##   godot --path <proyecto> res://tools/_render_variantes_civiles.tscn

const SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"

## La rejilla de la textura-atlas de cada `.glb` (confirmada por `_diag_celdas_civiles.gd`: 8 columnas
## x 4 filas, cada celda un color plano con leve degradado vertical).
const REJILLA_COLUMNAS: int = 8
const REJILLA_FILAS: int = 4
## La malla de CUERPO (piel/ropa/pelo/zapatos) es siempre esta -- "Cube_001" son los ojos, aparte.
const MALLA_CUERPO := "Cube_003"

## Paleta apagada del juego (pedida por el usuario): ropa en azules/verdes/terracota/burdeos, pelo en
## castaño/negro/rubio/canoso. Un solo sitio para tocar el tono si hiciera falta ajustar.
const ROPA_AZUL := Color(0.28, 0.38, 0.50)
const ROPA_VERDE := Color(0.30, 0.42, 0.32)
const ROPA_TERRACOTA := Color(0.72, 0.42, 0.30)
const ROPA_BURDEOS := Color(0.45, 0.18, 0.22)
const PELO_CASTANO := Color(0.36, 0.23, 0.16)
const PELO_NEGRO := Color(0.11, 0.11, 0.11)
const PELO_RUBIO := Color(0.83, 0.69, 0.42)
const PELO_CANOSO := Color(0.72, 0.72, 0.69)

## Un trabajo por modelo. `celdas` documenta lo que dijo el diagnóstico (para el informe); `variantes`
## es la lista real de recoloreados a aplicar -- la "a" (original) siempre va con `recolores` vacío.
const TRABAJOS: Array[Dictionary] = [
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/generic_male.glb", "fila": "h1",
		"correccion_frente_grados": 90.0,
		"variantes": [
			{"sufijo": "a", "recolores": []},
			{"sufijo": "b", "recolores": [{"celda": Vector2i(1, 2), "color": ROPA_AZUL}]},
			{"sufijo": "c", "recolores": [{"celda": Vector2i(1, 2), "color": ROPA_TERRACOTA}]},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/generic_female.glb", "fila": "m1",
		"correccion_frente_grados": 90.0,
		"variantes": [
			{"sufijo": "a", "recolores": []},
			{"sufijo": "b", "recolores": [
				{"celda": Vector2i(1, 2), "color": ROPA_VERDE}, {"celda": Vector2i(7, 0), "color": PELO_NEGRO},
			]},
			{"sufijo": "c", "recolores": [
				{"celda": Vector2i(1, 2), "color": ROPA_BURDEOS}, {"celda": Vector2i(7, 0), "color": PELO_RUBIO},
			]},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/citizen1.glb", "fila": "h2",
		"correccion_frente_grados": 90.0,
		"variantes": [
			{"sufijo": "a", "recolores": []},
			{"sufijo": "b", "recolores": [
				{"celda": Vector2i(4, 2), "color": ROPA_AZUL}, {"celda": Vector2i(1, 1), "color": PELO_CASTANO},
			]},
			{"sufijo": "c", "recolores": [
				{"celda": Vector2i(4, 2), "color": ROPA_VERDE}, {"celda": Vector2i(1, 1), "color": PELO_CANOSO},
			]},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/citizen2.glb", "fila": "h3",
		"correccion_frente_grados": 90.0,
		"variantes": [
			{"sufijo": "a", "recolores": []},
			{"sufijo": "b", "recolores": [
				{"celda": Vector2i(3, 0), "color": ROPA_TERRACOTA}, {"celda": Vector2i(0, 0), "color": PELO_RUBIO},
			]},
			{"sufijo": "c", "recolores": [
				{"celda": Vector2i(3, 0), "color": ROPA_BURDEOS}, {"celda": Vector2i(0, 0), "color": PELO_CASTANO},
			]},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/citizen3.glb", "fila": "m2",
		"correccion_frente_grados": 90.0,
		"variantes": [
			{"sufijo": "a", "recolores": []},
			{"sufijo": "b", "recolores": [{"celda": Vector2i(6, 2), "color": ROPA_AZUL}]},
			{"sufijo": "c", "recolores": [{"celda": Vector2i(6, 2), "color": ROPA_VERDE}]},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/retail_worker.glb", "fila": "h4",
		"correccion_frente_grados": 90.0,
		"variantes": [
			{"sufijo": "a", "recolores": []},
			{"sufijo": "b", "recolores": [
				{"celda": Vector2i(0, 2), "color": ROPA_BURDEOS}, {"celda": Vector2i(6, 0), "color": PELO_NEGRO},
			]},
			{"sufijo": "c", "recolores": [
				{"celda": Vector2i(0, 2), "color": ROPA_AZUL}, {"celda": Vector2i(6, 0), "color": PELO_CANOSO},
			]},
		],
	},
	{
		"ruta": "res://capturas/NPC/Ciudadanos/candidatos/crypto_bro.glb", "fila": "h5",
		"correccion_frente_grados": 90.0,
		"variantes": [
			{"sufijo": "a", "recolores": []},
			{"sufijo": "b", "recolores": [
				{"celda": Vector2i(0, 0), "color": ROPA_VERDE}, {"celda": Vector2i(6, 0), "color": PELO_RUBIO},
			]},
			{"sufijo": "c", "recolores": [
				{"celda": Vector2i(0, 0), "color": ROPA_TERRACOTA}, {"celda": Vector2i(6, 0), "color": PELO_CASTANO},
			]},
		],
	},
]

const ELEVACION_GRADOS: float = 26.565
const DIRECCIONES: int = 8
const DIRECCION_SUR: int = 6
const TAM_RENDER: int = 512
const ALTO_SALIDA: int = 88

const ANIM_ANDAR := "Armature|Walk"
const HUESO_RAIZ := "CORE"
const HUESO_PIE := "Foot.L"
const HUESO_PUNTA := "Toes.L"

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

	DirAccess.make_dir_recursive_absolute(SALIDA)
	_procesar_todo()


func _procesar_todo() -> void:
	for trabajo: Dictionary in TRABAJOS:
		for variante: Dictionary in trabajo["variantes"]:
			await _procesar_variante(trabajo, variante)
	print("[RENDER] hecho: %d imágenes procesadas" % _procesados.size())
	get_tree().quit()


## Carga el `.glb` DESDE CERO para cada variante (evita ir acumulando ediciones de una variante sobre
## la siguiente -- cada una parte de la textura ORIGINAL del modelo).
func _procesar_variante(trabajo: Dictionary, variante: Dictionary) -> void:
	var ruta: String = trabajo["ruta"]
	var fila: String = trabajo["fila"]
	var sufijo: String = variante["sufijo"]
	var etiqueta: String = "%s-%s" % [fila, sufijo]
	print("[RENDER] === %s (%s) ===" % [etiqueta, ruta])

	var raiz: Node3D = _cargar_glb(ruta)
	if raiz == null:
		push_error("RenderVariantesCiviles: no se pudo cargar %s -> se salta %s" % [ruta, etiqueta])
		return
	_modelo = raiz
	_mundo.add_child(_modelo)

	var recolores: Array = variante["recolores"]
	if not recolores.is_empty():
		_recolorear(_modelo, recolores, etiqueta)

	_encuadrar()

	var esqueleto: Skeleton3D = _buscar_esqueleto(_modelo)
	var reproductor: AnimationPlayer = _buscar_animation_player(_modelo)
	if reproductor != null:
		reproductor.speed_scale = 0.0
	var anim_andar: String = _resolver_animacion(reproductor, ANIM_ANDAR)

	var frente: Vector3 = _frente_de(esqueleto)
	var correccion: float = deg_to_rad(float(trabajo.get("correccion_frente_grados", 0.0)))
	var rumbo_reposo: float = atan2(frente.x, frente.z) + correccion

	var rumbo: float = TAU / DIRECCIONES * DIRECCION_SUR
	var objetivo: float = atan2(cos(rumbo), sin(rumbo))
	_modelo.rotation = Vector3(0.0, objetivo - rumbo_reposo, 0.0)

	_muestrear(reproductor, anim_andar, 0.0)
	_anular_root_motion(esqueleto)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = _recortar(_sub.get_texture().get_image())
	_alto_referencia = imagen.get_height()
	_guardar(imagen, etiqueta)
	print("[RENDER] %s: guardado (alto de referencia %d px)" % [etiqueta, _alto_referencia])

	_procesados.append(etiqueta)
	_mundo.remove_child(_modelo)
	_modelo.queue_free()
	_modelo = null


## Recolorea, EN UNA COPIA de la textura propia de este `.glb` (no toca el archivo original), las
## celdas pedidas de la malla "Cube_003" (cuerpo) rellenándolas con un color PLANO -- mismo patrón que
## `_igualar_piel` de `render_sprites_animado.gd`, pero la "fuente" del blit es un color, no otra celda.
## NUNCA toca "Cube_001" (ojos, ver cabecera).
func _recolorear(modelo: Node3D, recolores: Array, etiqueta: String) -> void:
	var cuerpo: MeshInstance3D = null
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		if hijo.name == MALLA_CUERPO:
			cuerpo = hijo as MeshInstance3D
			break
	if cuerpo == null:
		push_warning("RenderVariantesCiviles: %s no tiene '%s' -> no se recolorea nada" % [etiqueta, MALLA_CUERPO])
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
		push_error("RenderVariantesCiviles: append_from_file(%s) -> error %d" % [ruta, err])
		return null
	var raiz: Node = doc.generate_scene(estado)
	if raiz == null:
		push_error("RenderVariantesCiviles: generate_scene(%s) devolvió null" % ruta)
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
			return String(nombre)
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


## Guarda SOLO a 88px (ancho de columna de la hoja) -- esta tanda es propuesta, no alimenta el juego.
func _guardar(imagen: Image, etiqueta: String) -> void:
	var escala: float = float(ALTO_SALIDA) / float(maxi(_alto_referencia, 1))
	var copia: Image = imagen.duplicate()
	copia.resize(
		maxi(1, roundi(float(copia.get_width()) * escala)),
		maxi(1, roundi(float(copia.get_height()) * escala)),
		Image.INTERPOLATE_LANCZOS
	)
	var ruta: String = "%s%s_88px_sur.png" % [SALIDA, etiqueta]
	var err: Error = copia.save_png(ruta)
	if err != OK:
		push_error("RenderVariantesCiviles: no se pudo guardar %s -> error %d" % [ruta, err])


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
