extends Node3D
## Renderizador de SPRITES ISOMÉTRICOS para modelos que TRAEN sus propias animaciones.
##
## Es la variante de `render_sprites.gd` para el caso contrario: en vez de posar el esqueleto con
## fórmulas (piernas en oposición, brazos balanceando), aquí el modelo YA trae un ciclo de andar
## hecho por un animador de verdad ("Armature|Walk"), así que el trabajo es más sencillo — MUESTREAR
## esa animación en varios instantes — pero con una trampa nueva: sentarse. Estos rigs no tienen
## rodilla (la pierna es una sola pieza, del hueso de cadera al tobillo), así que la fórmula de
## sentado de `render_sprites.gd` (doblar cadera + rodilla) no tiene dónde aplicarse.
##
## ── CÓMO SE USA ────────────────────────────────────────────────────────────────────────────────
##   godot --path <proyecto> res://tools/RenderSpritesAnimado.tscn
##
## Procesa la lista `TRABAJOS` de un tirón y escribe los PNG + una hoja de contactos `index.html` en
## `SALIDA`. **No puede correr en headless** (necesita GPU para renderizar) y cierra la ventana solo.
##
## ── QUÉ SE HEREDA DE `render_sprites.gd` Y QUÉ NO ─────────────────────────────────────────────────
## Se hereda: la cámara ORTOGRÁFICA a `atan(1/2) = 26,565°`; medir el FRENTE desde los pies (talón a
## punta) en vez de suponerlo; escalar TODAS las poses con el MISMO factor sacado de la figura de
## pie; el patrón de espera de 2 frames antes de capturar; y la regla de que una pose se define
## ENTERA (aquí se cumple sola: cada `seek()` reescribe TODOS los huesos que la animación toca, así
## que no hay restos de la pose anterior salvo en los huesos que TOCAMOS A MANO para sentar — por
## eso el sentado siempre arranca desde un Idle recién muestreado, ver `_procesar_modelo`).
##
## No se hereda: aquí NO hay fórmula de andar (`_posar` de piernas/brazos) — se sustituye por
## `_muestrear`, que pone el AnimationPlayer en el instante `t` de la animación pedida. Y los modelos
## NO están importados por el editor (viven en `capturas/`, sin `.import`), así que se cargan en
## tiempo de ejecución con `GLTFDocument` + `GLTFState`, que leen el `.glb` directamente sin pasar
## por el sistema de importación.
##
## ── LA POSE DE SENTADO, AQUÍ ES UN EXPERIMENTO (no una solución) ──────────────────────────────────
## Sin rodilla, lo único que se puede doblar es la cadera: se gira el hueso `Foot.L`/`Foot.R` entero
## (que en este rig es la pierna completa, no solo el pie) hasta la horizontal, y de propina se baja
## el cuerpo para que la pierna horizontal quede a la altura de un asiento en vez de flotando en el
## aire a la altura de la cadera de pie. Cuánto bajar y hacia qué lado gira cada pie NO se puede
## deducir de las convenciones de este rig ajeno — así que se generan 4 combinaciones (signo del
## giro × con/sin bajar) para que las juzgue un humano mirándolas. Ver `_posar_sentado_prueba` y el
## `.txt` que se escribe junto a los PNG.

## Un trabajo por modelo: dónde está el `.glb` y con qué prefijo se guardan sus sprites.
##
## `oficial_m` lleva además `piel_celda`/`piel_referencia`: las dos figuras comparten LA MISMA
## textura `GGrid.png` (un atlas de 8×4 franjas de color, confirmado byte a byte), pero cada una
## pinta su piel con una franja distinta de esa rejilla (oficial_h con (3,1), oficial_m con (6,0) —
## averiguado leyendo a qué celda apunta la UV de los vértices que MÁS le deben a los huesos
## `Head`/`Hand.*`/dedos, no a ojo). El encargo del usuario es que las dos usen el tono claro del
## hombre, así que a `oficial_m` se le copia la celda (3,1) del hombre ENCIMA de su propia (6,0) — ver
## `_igualar_piel`.
const TRABAJOS: Array[Dictionary] = [
	{"ruta": "res://capturas/NPC/Policias/candidatos/male_officer.glb", "prefijo": "oficial_h"},
	{
		"ruta": "res://capturas/NPC/Policias/candidatos/female_officer.glb", "prefijo": "oficial_m",
		"piel_celda": Vector2i(6, 0),
		"piel_referencia_ruta": "res://capturas/NPC/Policias/candidatos/male_officer.glb",
		"piel_referencia_celda": Vector2i(3, 1),
	},
]
const SALIDA := "res://capturas/NPC/Policias/candidatos/render_test/"

## Cámara: mismo ángulo isométrico que `render_sprites.gd` (`atan(1/2)`, no los 30° "de libro").
const ELEVACION_GRADOS: float = 26.565
const DIRECCIONES: int = 8
## Qué índice de dirección es "SUR" (el personaje mirando de frente a cámara). Es el mismo que usó
## `render_sprites.gd` para sus pruebas de signo (`PROBAR_SIGNOS` en `i == 6`).
const DIRECCION_SUR: int = 6
## "ESTE": perfil, 90° del SUR. De frente casi no se distingue si las piernas del sentado giraron
## hacia delante o hacia atrás (quedan casi tapadas por el propio cuerpo) — de perfil es inequívoco,
## así que el sentado se prueba en LAS DOS direcciones.
const DIRECCION_ESTE: int = 0
const TAM_RENDER: int = 512
const ALTURAS: Array[int] = [88, 44]

## La rejilla de la textura compartida: 8 columnas × 4 filas de franjas de color con degradado
## vertical (cada franja = un "material" — piel, uniforme, botas...).
const REJILLA_COLUMNAS: int = 8
const REJILLA_FILAS: int = 4

## Nombres de las animaciones embebidas que trae cada `.glb` (confirmados en la radiografía). Si no
## aparecen tal cual, `_resolver_animacion` busca la más parecida entre las que SÍ trae el modelo, en
## vez de fallar en silencio con un muñeco quieto.
const ANIM_ANDAR := "Armature|Walk"
const ANIM_REPOSO := "Armature|Idle"
## Cuántos instantes del ciclo de andar se capturan (equiespaciados: `t = f / FOTOGRAMAS`).
const FOTOGRAMAS: int = 8

## El hueso raíz del esqueleto (según la radiografía). Se usa para dos cosas: anular el ROOT MOTION
## (si la animación desplaza al personaje, se le devuelve a X=0/Z=0 cada fotograma) y, en el
## experimento de sentado, bajar el cuerpo entero.
const HUESO_RAIZ := "CORE"
## HACIA DÓNDE MIRA el personaje en reposo: del talón (`Foot.L`) a la punta del pie (`Toes.L`). Con
## este rig, `Foot.L` es la pierna ENTERA (cadera→tobillo, sin rodilla) — su origen es el extremo que
## la radiografía identifica como el talón. Mismo principio que `render_sprites.gd`: no se supone,
## se mide.
const HUESO_PIE := "Foot.L"
const HUESO_PUNTA := "Toes.L"
## Los mismos huesos `Foot.L`/`Foot.R`, aquí con el sombrero puesto de "pierna a girar" para sentar
## (es el mismo hueso que `HUESO_PIE`: este rig no tiene una pieza de muslo separada del pie).
const HUESO_PIERNA_IZQ := "Foot.L"
const HUESO_PIERNA_DER := "Foot.R"

## Grados que se gira la pierna desde la cadera para llevarla a la horizontal. 85 y no 90: un ángulo
## exacto se lee como un maniquí (mismo criterio que `SENTADO_CADERA` en `render_sprites.gd`).
const SENTADO_GRADOS_PIE: float = 85.0
## Cuánto se baja el cuerpo en la variante "con bajada", como fracción del largo de la pierna medido
## en REPOSO (cadera→tobillo). 0,5 es una PRIMERA estimación razonable, no una cuenta cerrada — por
## algo esto es el experimento que hay que mirar, no calcular.
const SENTADO_BAJADA_FRACCION: float = 0.5

var _sub: SubViewport
var _camara: Camera3D
var _mundo: Node3D
var _modelo: Node3D
## Lo que mide la figura DE PIE (Idle en t=0) en el render grande. Vara de medir de todas las poses
## de ESTE modelo — se recalcula al empezar cada uno (ver `_procesar_modelo`).
var _alto_referencia: int = 0
## Prefijos que se procesaron con éxito, en orden. Alimenta `_generar_index` — así un modelo que
## fallase al cargar no deja huecos rotos en la hoja de contactos.
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
	# `_ready` no se marca `await`: dispara la corrutina y sigue con su vida, igual que
	# `render_sprites.gd`. Quien tiene los `await` de verdad es `_procesar_todo`.
	_procesar_todo()


func _procesar_todo() -> void:
	for trabajo: Dictionary in TRABAJOS:
		await _procesar_modelo(trabajo)
	_generar_index()
	_generar_leyenda_sentado()
	print("[RENDER] hecho: %d/%d modelos procesados" % [_procesados.size(), TRABAJOS.size()])
	get_tree().quit()


## Carga, encuadra, renderiza las 8 direcciones (reposo + 8 fotogramas de andar) y las 4 pruebas de
## sentado de UN modelo, y libera la escena antes de devolver el control.
func _procesar_modelo(trabajo: Dictionary) -> void:
	var ruta: String = trabajo["ruta"]
	var prefijo: String = trabajo["prefijo"]
	print("[RENDER] === %s (%s) ===" % [prefijo, ruta])

	var raiz: Node3D = _cargar_glb(ruta)
	if raiz == null:
		push_error("RenderSpritesAnimado: no se pudo cargar %s -> se salta este modelo" % ruta)
		return
	_modelo = raiz
	_mundo.add_child(_modelo)
	if trabajo.has("piel_celda"):
		_igualar_piel(
			_modelo, trabajo["piel_celda"], trabajo["piel_referencia_ruta"],
			trabajo["piel_referencia_celda"], prefijo
		)
	_encuadrar()

	var esqueleto: Skeleton3D = _buscar_esqueleto(_modelo)
	var reproductor: AnimationPlayer = _buscar_animation_player(_modelo)
	if esqueleto == null:
		push_warning("RenderSpritesAnimado: %s no trae Skeleton3D" % prefijo)
	else:
		_volcar_esqueleto(esqueleto, prefijo)
	if reproductor == null:
		push_warning("RenderSpritesAnimado: %s no trae AnimationPlayer -> sale en su pose original" % prefijo)
	else:
		print("[RENDER] %s: animaciones disponibles: %s" % [prefijo, reproductor.get_animation_list()])
		# El tiempo de la animación lo controlamos ENTERO a mano con `seek`. Con `speed_scale = 0`,
		# nada avanza solo durante los frames de espera antes de capturar.
		reproductor.speed_scale = 0.0

	var anim_andar: String = _resolver_animacion(reproductor, ANIM_ANDAR)
	var anim_reposo: String = _resolver_animacion(reproductor, ANIM_REPOSO)

	# El FRENTE del personaje en reposo, medido del talón a la punta — no se supone (ver cabecera).
	var frente: Vector3 = _frente_de(esqueleto)
	var rumbo_reposo: float = atan2(frente.x, frente.z)

	# ALTURA DE REFERENCIA: la figura de pie (Idle en t=0), sin rotar. Todo lo demás de ESTE modelo
	# se escala con este mismo factor (ver `_guardar`), igual que en `render_sprites.gd`.
	_muestrear(reproductor, anim_reposo, 0.0)
	_anular_root_motion(esqueleto)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_alto_referencia = _recortar(_sub.get_texture().get_image()).get_height()
	print("[RENDER] %s: altura de referencia (de pie) = %d px" % [prefijo, _alto_referencia])

	for i: int in DIRECCIONES:
		var rumbo: float = TAU / DIRECCIONES * i
		var objetivo: float = atan2(cos(rumbo), sin(rumbo))
		_modelo.rotation = Vector3(0.0, objetivo - rumbo_reposo, 0.0)

		# REPOSO de esta dirección (Idle en t=0).
		_muestrear(reproductor, anim_reposo, 0.0)
		_anular_root_motion(esqueleto)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		_guardar(_recortar(_sub.get_texture().get_image()), prefijo, "reposo_%d" % i)

		# ANDAR: 8 instantes equiespaciados del ciclo de "Armature|Walk".
		for f: int in FOTOGRAMAS:
			var t: float = float(f) / float(FOTOGRAMAS)
			_muestrear(reproductor, anim_andar, t)
			_anular_root_motion(esqueleto)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			_guardar(_recortar(_sub.get_texture().get_image()), prefijo, "%d_%d" % [i, f])
		print("[RENDER] %s: dirección %d/%d lista (%d fotogramas)" % [prefijo, i + 1, DIRECCIONES, FOTOGRAMAS])

	# SENTADO (experimento): en SUR y en ESTE (perfil), 4 combinaciones cada una, para que las juzgue
	# un humano. De frente casi no se distingue hacia qué lado giró la pierna; de perfil es claro.
	var bajada: float = _largo_pierna(esqueleto) * SENTADO_BAJADA_FRACCION
	print("[RENDER] %s: largo de pierna en reposo (CORE->Toes.L, en mundo) = %.5f -> bajada de prueba = %.5f" % [
		prefijo, _largo_pierna(esqueleto), bajada
	])
	var idx_pierna_diag: int = _hueso(esqueleto, HUESO_PIERNA_IZQ) if esqueleto != null else -1
	var idx_raiz_diag: int = _hueso(esqueleto, HUESO_RAIZ) if esqueleto != null else -1
	# La Y LOCAL de CORE con la pose de Idle limpia, capturada UNA vez. Todas las variantes parten de
	# ESTA misma Y (absoluta, no relativa a "lo que hubiera antes") -- si no, una variante con
	# `bajar_cuerpo` deja la Y baja y la siguiente hereda esa bajada encima de la suya.
	_muestrear(reproductor, anim_reposo, 0.0)
	if reproductor != null:
		reproductor.stop(true)
	_anular_root_motion(esqueleto)
	var core_y_base: float = (
		esqueleto.get_bone_pose_position(idx_raiz_diag).y if idx_raiz_diag >= 0 else 0.0
	)
	var variantes: Dictionary = {
		"A": {"signo": 1.0, "bajar": false},
		"B": {"signo": 1.0, "bajar": true},
		"C": {"signo": -1.0, "bajar": false},
		"D": {"signo": -1.0, "bajar": true},
	}
	var direcciones_sentado: Dictionary = {"sur": DIRECCION_SUR, "este": DIRECCION_ESTE}
	for nombre_dir: String in ["sur", "este"]:
		var idx_dir: int = direcciones_sentado[nombre_dir]
		var rumbo_d: float = TAU / DIRECCIONES * idx_dir
		var objetivo_d: float = atan2(cos(rumbo_d), sin(rumbo_d))
		_modelo.rotation = Vector3(0.0, objetivo_d - rumbo_reposo, 0.0)
		for letra: String in ["A", "B", "C", "D"]:
			var v: Dictionary = variantes[letra]
			# SIEMPRE se parte de un Idle recién muestreado: si no, la variante anterior deja las
			# piernas giradas puestas y esta hereda esos restos encima de los suyos.
			_muestrear(reproductor, anim_reposo, 0.0)
			# ⚠️ CAUSA DEL BUG "las 4 salen iguales, de pie": con el AnimationPlayer todavía
			# "reproduciendo" (aunque `speed_scale = 0` impida que el TIEMPO avance), el
			# AnimationMixer reaplica la pose de Idle en CADA frame procesado -- incluidos los
			# `await RenderingServer.frame_post_draw` de más abajo -- así que pisaba las ediciones
			# manuales de pierna/cuerpo antes de que llegaran a capturarse. `stop(true)` congela la
			# pose actual (`keep_state`) y deja de reprocesarla.
			if reproductor != null:
				reproductor.stop(true)
			_anular_root_motion(esqueleto)
			_posar_sentado_prueba(esqueleto, float(v["signo"]), bool(v["bajar"]), bajada, core_y_base)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var recorte: Image = _recortar(_sub.get_texture().get_image())
			if idx_pierna_diag >= 0:
				print("[SENTADO] %s %s/%s: recorte=%s Foot.L pose=%s" % [
					prefijo, nombre_dir, letra, recorte.get_size(),
					esqueleto.get_bone_pose_rotation(idx_pierna_diag)
				])
			_guardar(recorte, prefijo, "sentado_prueba_%s_%s" % [letra, nombre_dir])
	print("[RENDER] %s: 8 pruebas de sentado listas (4 variantes x 2 direcciones)" % prefijo)

	_procesados.append(prefijo)
	_mundo.remove_child(_modelo)
	_modelo.queue_free()
	_modelo = null


## Carga un `.glb` SIN pasar por el sistema de importación del editor: los candidatos viven en
## `capturas/` sin `.import`, así que `load()` no serviría. `GLTFDocument` lee el binario directo y
## `generate_scene` monta el árbol de nodos (mallas, Skeleton3D, AnimationPlayer con sus animaciones)
## tal cual lo haría el importador, pero en memoria y sin tocar el disco.
func _cargar_glb(ruta: String) -> Node3D:
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	var err: Error = doc.append_from_file(ruta, estado)
	if err != OK:
		push_error("RenderSpritesAnimado: append_from_file(%s) -> error %d" % [ruta, err])
		return null
	var raiz: Node = doc.generate_scene(estado)
	if raiz == null:
		push_error("RenderSpritesAnimado: generate_scene(%s) devolvió null" % ruta)
		return null
	return raiz as Node3D


## Carga un `.glb` SOLO para robarle la textura `albedo_texture` de su primer material -- se usa
## para leer la piel del modelo de REFERENCIA sin tener que dejarlo instanciado en la escena.
func _textura_de(ruta: String) -> Image:
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	if doc.append_from_file(ruta, estado) != OK:
		return null
	var raiz: Node = doc.generate_scene(estado)
	if raiz == null:
		return null
	var resultado: Image = null
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			if mat is BaseMaterial3D:
				var tex: Texture2D = (mat as BaseMaterial3D).albedo_texture
				if tex != null:
					resultado = tex.get_image()
					break
		if resultado != null:
			break
	raiz.free()
	return resultado


## Las figuras comparten LA MISMA textura `GGrid.png` (un atlas de `REJILLA_COLUMNAS`×`REJILLA_FILAS`
## franjas de color sólido con degradado vertical, confirmado byte a byte entre los dos `.glb`); cada
## una pinta su piel con una franja distinta de esa rejilla, no con un archivo distinto. Para igualar
## el tono, se copia la franja de PIEL del modelo de referencia encima de la franja de piel de
## `modelo`, en una COPIA de SU PROPIA textura (cada `.glb` trae su propio `ImageTexture` en memoria,
## así que tocar uno no toca el otro) -- el uniforme y el pelo, que viven en otras franjas de la
## rejilla, no se tocan.
func _igualar_piel(
	modelo: Node3D, celda_destino: Vector2i, ruta_referencia: String, celda_origen: Vector2i,
	prefijo: String
) -> void:
	var origen_img: Image = _textura_de(ruta_referencia)
	if origen_img == null:
		push_warning("RenderSpritesAnimado: %s -> no se pudo leer la textura de referencia para igualar piel" % prefijo)
		return
	var ancho_celda_o: int = origen_img.get_width() / REJILLA_COLUMNAS
	var alto_celda_o: int = origen_img.get_height() / REJILLA_FILAS
	var origen_rect := Rect2i(
		celda_origen.x * ancho_celda_o, celda_origen.y * alto_celda_o, ancho_celda_o, alto_celda_o
	)
	var aplicado := false
	var guardada := false
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			if not (mat is BaseMaterial3D):
				continue
			var bm := mat as BaseMaterial3D
			var tex: Texture2D = bm.albedo_texture
			if tex == null:
				continue
			var propia: Image = tex.get_image()
			var ancho_celda: int = propia.get_width() / REJILLA_COLUMNAS
			var alto_celda: int = propia.get_height() / REJILLA_FILAS
			var destino := Vector2i(celda_destino.x * ancho_celda, celda_destino.y * alto_celda)
			propia.blit_rect(origen_img, origen_rect, destino)
			bm.albedo_texture = ImageTexture.create_from_image(propia)
			aplicado = true
			if not guardada:
				guardada = true
				var destino_png: String = "%sGGrid_piel_igualada_%s.png" % [SALIDA, prefijo]
				propia.save_png(ProjectSettings.globalize_path(destino_png))
				print("[PIEL] %s: textura recoloreada guardada en %s" % [prefijo, destino_png])
	if aplicado:
		print("[PIEL] %s: celda de piel %s <- celda %s de %s" % [
			prefijo, celda_destino, celda_origen, ruta_referencia
		])
	else:
		push_warning("RenderSpritesAnimado: %s no tiene material/textura donde aplicar el cambio de piel" % prefijo)


## Coloca la cámara en el ángulo isométrico y la aleja lo justo para que el modelo entre entero.
## Se calcula sobre la CAJA del modelo en su pose de reposo (antes de muestrear ninguna animación),
## igual que `render_sprites.gd` — el margen del 15 % ya demostró ser suficiente para un ciclo de
## andar con los brazos separándose del cuerpo.
func _encuadrar() -> void:
	var caja: AABB = _caja_de(_modelo)
	var centro: Vector3 = caja.get_center()
	var alto: float = maxf(caja.size.y, maxf(caja.size.x, caja.size.z))
	# Diagnóstico (no cambia el encuadre): con qué dimensión se está encuadrando la cámara. Si la que
	# manda no es `size.y` (la altura), el encuadre está siendo dominado por el ANCHO del modelo, no
	# por su altura -- relevante para saber si una figura "sale más achaparrada" es una proporción de
	# verdad o un artefacto de cómo se ajustó la cámara.
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


## Imprime el árbol de huesos (nombre <- padre) por consola. Diagnóstico, no se usa para calcular
## nada: sirve para comprobar a ojo, leyendo la consola, que `HUESO_RAIZ` de verdad es el padre de
## todo lo demás (si no lo fuera, bajar el "cuerpo" solo bajaría las piernas, no el torso).
func _volcar_esqueleto(esqueleto: Skeleton3D, prefijo: String) -> void:
	print("[RENDER] %s: %d huesos" % [prefijo, esqueleto.get_bone_count()])
	for i: int in esqueleto.get_bone_count():
		var padre: int = esqueleto.get_bone_parent(i)
		var nombre_padre: String = esqueleto.get_bone_name(padre) if padre >= 0 else "(raíz)"
		print("  %s <- %s" % [esqueleto.get_bone_name(i), nombre_padre])
	# DIAGNÓSTICO TEMPORAL (2026-08-01): confirmar en qué extremo cae el origen de cada hueso clave
	# antes de fiarse de una resta de alturas para la "bajada" del sentado.
	for clave: String in ["CORE", "Body", "Head", "Foot.L", "Toes.L", "Foot.R", "Toes.R"]:
		var idx: int = _hueso(esqueleto, clave)
		if idx >= 0:
			var o: Vector3 = esqueleto.get_bone_global_rest(idx).origin
			print("  [Y] %s = %s" % [clave, o])


## Si el nombre exacto de la animación no está (el `.glb` podría llamarla distinto de lo que dice la
## radiografía), busca la que más se le parezca entre las que SÍ trae el modelo, en vez de fallar en
## silencio con un muñeco quieto. Devuelve el nombre EXACTO tal y como lo espera `AnimationPlayer`.
func _resolver_animacion(reproductor: AnimationPlayer, deseada: String) -> String:
	if reproductor == null:
		return deseada
	if reproductor.has_animation(deseada):
		return deseada
	for nombre: StringName in reproductor.get_animation_list():
		if String(nombre).find(deseada) >= 0 or deseada.find(String(nombre)) >= 0:
			push_warning("RenderSpritesAnimado: usando animación '%s' en vez de '%s'" % [nombre, deseada])
			return String(nombre)
	push_warning("RenderSpritesAnimado: no se encontró animación '%s'. Disponibles: %s" % [
		deseada, reproductor.get_animation_list()
	])
	return deseada


## Pone al `AnimationPlayer` en el instante `t` (0..1 sobre la duración de `nombre`) y aplica la pose
## AL INSTANTE (`seek(..., true)`, sin mezcla con la pose anterior: `custom_blend = 0.0`). Si no hay
## reproductor o la animación no existe, no hace nada — el modelo se queda con la pose que tuviera.
func _muestrear(reproductor: AnimationPlayer, nombre: String, t: float) -> void:
	if reproductor == null or not reproductor.has_animation(nombre):
		return
	var anim: Animation = reproductor.get_animation(nombre)
	var duracion: float = maxf(anim.length, 0.0001)
	reproductor.play(nombre, 0.0)
	reproductor.seek(t * duracion, true)


## Si la animación desplaza al personaje (root motion), lo anula: recorre desde el `Skeleton3D` hacia
## arriba hasta `_modelo` poniendo X/Z a 0 en cada `Node3D` del camino (cubre tanto un root motion
## bakeado en el propio nodo `Skeleton3D` como en un `Armature` intermedio), y hace lo mismo con la
## posición del hueso `CORE` (conserva su Y: el rebote vertical del paso SÍ se quiere ver). El
## personaje queda centrado en todos los fotogramas, sin que la vuelta de un ciclo lo saque de cuadro.
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


## Guarda una imagen en todos los tamaños de `ALTURAS`. Mismo criterio que `render_sprites.gd`: TODAS
## se escalan con el factor sacado de `_alto_referencia` (la figura de pie), nunca cada una ajustada
## a su propia altura — si no, sentado saldría más grande en vez de más bajo.
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


## El largo VERTICAL de la pierna en reposo (cadera → tobillo), midiendo del hueso `Foot.L` (que en
## este rig es la pierna entera) a `Toes.L`. Es la vara de medir de `SENTADO_BAJADA_FRACCION`.
func _largo_pierna(esqueleto: Skeleton3D) -> float:
	if esqueleto == null:
		return 0.0
	var idx_cadera: int = _hueso(esqueleto, HUESO_RAIZ)
	var idx_tobillo: int = _hueso(esqueleto, HUESO_PUNTA)
	if idx_cadera < 0 or idx_tobillo < 0:
		return 0.0
	# ⚠️ En COORDENADAS DEL MUNDO de verdad -- multiplicando por el `global_transform` del propio
	# Skeleton3D, no solo la resta de los orígenes DENTRO del esqueleto. `get_bone_global_rest` solo
	# compone la cadena de huesos; si el nodo Skeleton3D (o un "Armature" por encima) trae su propio
	# giro -- aquí lo trae: es la conversión Z-arriba de Blender a Y-arriba de Godot -- esa resta sale
	# casi cero sin este paso, y estaba además restando `Foot.L` (el hueso de la pierna, pero cuyo
	# ORIGEN cae junto al tobillo, no la cadera) en vez de `CORE`.
	var mundo_cadera: Vector3 = esqueleto.global_transform * esqueleto.get_bone_global_rest(idx_cadera).origin
	var mundo_tobillo: Vector3 = esqueleto.global_transform * esqueleto.get_bone_global_rest(idx_tobillo).origin
	return maxf(mundo_cadera.y - mundo_tobillo.y, 0.0)


## EL EXPERIMENTO: sin rodilla, lo único que hay para "sentar" es girar la pierna entera desde la
## cadera hasta la horizontal (`Foot.L`/`Foot.R`, que en este rig hacen de muslo+pantorrilla en una
## pieza) y, si `bajar_cuerpo`, bajar el hueso raíz esa distancia — para que la pierna horizontal
## quede a la altura de un asiento en vez de flotando a la altura de la cadera de pie. El signo del
## giro y si hace falta bajar el cuerpo NO se deducen de este rig ajeno: se generan las 4
## combinaciones y las juzga un humano (ver `_procesar_modelo` y el `.txt` de leyenda).
func _posar_sentado_prueba(
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
		# La Y LOCAL se fija SIEMPRE en ABSOLUTO desde `core_y_base` (la del Idle limpio), nunca en
		# relativo a "lo que hubiera antes" -- si no, una variante con `bajar_cuerpo` deja la Y baja y
		# la SIGUIENTE la hereda y le suma la suya encima (bug real que se vio: B/C/D salían en blanco
		# porque el personaje entero se iba fuera de cámara).
		var y_local: float = core_y_base
		if bajar_cuerpo:
			# ⚠️ UNIDADES: `bajada` está en unidades del MUNDO (`_largo_pierna` multiplica por
			# `esqueleto.global_transform`), pero `get/set_bone_pose_position` trabajan en el espacio
			# LOCAL del hueso raíz -- que aquí usa una escala mucho más pequeña (y un giro: la
			# conversión Z-arriba de Blender a Y-arriba de Godot vive en el propio nodo Skeleton3D, no
			# en la jerarquía de huesos). Restar `bajada` tal cual mandaba al personaje entero a
			# decenas de unidades fuera de la cámara -> PNG en blanco. Se convierte "abajo, en el
			# mundo" a LOCAL con la inversa del propio `global_transform`.
			var delta_mundo := Vector3(0.0, -bajada, 0.0)
			var delta_local: Vector3 = esqueleto.global_transform.basis.inverse() * delta_mundo
			y_local += delta_local.y
		var pos: Vector3 = esqueleto.get_bone_pose_position(idx_raiz)
		esqueleto.set_bone_pose_position(idx_raiz, Vector3(pos.x, y_local, pos.z))


## HACIA DÓNDE MIRA el personaje en reposo, en horizontal: del talón (`HUESO_PIE`) a la punta
## (`HUESO_PUNTA`), sobre la pose de REPOSO del esqueleto (`get_bone_global_rest`, que no cambia
## aunque el `AnimationPlayer` esté aplicando una pose distinta encima). Mismo principio que
## `render_sprites.gd`: no se supone, se mide.
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


## El índice de un hueso buscándolo por PREFIJO (por si el exportador añadiera algún sufijo a
## `CORE`/`Foot.L`/etc., igual que `render_sprites.gd` hace con su modelo). -1 si no está.
func _hueso(esqueleto: Skeleton3D, prefijo: String) -> int:
	for i: int in esqueleto.get_bone_count():
		if esqueleto.get_bone_name(i).begins_with(prefijo):
			return i
	return -1


## Aplica a un hueso un giro expresado en el MUNDO, partiendo siempre de su pose de reposo. Misma
## cuenta que `render_sprites.gd`: `B⁻¹ · R · B`, con `B` la orientación del hueso en reposo.
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


## Quita el aire transparente de alrededor, igual que `render_sprites.gd`.
func _recortar(imagen: Image) -> Image:
	var usado: Rect2i = imagen.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		return imagen
	return imagen.get_region(usado)


## ── LA HOJA DE CONTACTOS ──────────────────────────────────────────────────────────────────────────

func _generar_index() -> void:
	var partes: PackedStringArray = []
	partes.append("<!DOCTYPE html><html lang=\"es\"><head><meta charset=\"utf-8\">")
	partes.append("<title>Render de prueba -- candidatos a policia</title>")
	partes.append(_estilo_index())
	partes.append("</head><body>")
	partes.append("<h1>Render de prueba -- candidatos a policia</h1>")
	partes.append(
		"<p>Direccion %d = SUR (el personaje mirando de frente a camara). Todas las imagenes a 88 px, fondo a cuadros para ver la transparencia.</p>"
		% DIRECCION_SUR
	)
	for prefijo: String in _procesados:
		partes.append("<h2>%s</h2>" % prefijo)
		partes.append(_seccion_reposo(prefijo))
		partes.append(_seccion_andar(prefijo))
		partes.append(_seccion_sentado(prefijo))
	if _procesados.is_empty():
		partes.append("<p><strong>Ningun modelo se proceso con exito -- revisa la consola.</strong></p>")
	partes.append("</body></html>")
	var contenido: String = "\n".join(partes)
	var archivo := FileAccess.open(SALIDA + "index.html", FileAccess.WRITE)
	if archivo == null:
		push_error("RenderSpritesAnimado: no se pudo escribir index.html")
		return
	archivo.store_string(contenido)
	archivo.close()
	print("[RENDER] index.html escrito en %s" % (SALIDA + "index.html"))


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


func _seccion_reposo(prefijo: String) -> String:
	var partes: PackedStringArray = []
	partes.append("<h3>Reposo (Idle) -- 8 direcciones</h3>")
	partes.append("<div class=\"tira\">")
	for i: int in DIRECCIONES:
		var etiqueta: String = "Direccion %d" % i
		if i == DIRECCION_SUR:
			etiqueta += " (SUR)"
		var archivo: String = "%s_88px_reposo_%d.png" % [prefijo, i]
		partes.append("<div>%s<br><img src=\"%s\" alt=\"%s\"></div>" % [etiqueta, archivo, etiqueta])
	partes.append("</div>")
	return "\n".join(partes)


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
	var descripciones: Dictionary = {
		"A": "pies +85 grados, SIN bajar cuerpo",
		"B": "pies +85 grados, CON bajar cuerpo",
		"C": "pies -85 grados, SIN bajar cuerpo",
		"D": "pies -85 grados, CON bajar cuerpo",
	}
	var partes: PackedStringArray = []
	partes.append("<h3>Pruebas de sentado (experimento, SUR y ESTE)</h3>")
	partes.append("<p>ESTE es de perfil: de frente casi no se distingue hacia donde giro la pierna, de perfil si.</p>")
	for nombre_dir: String in ["sur", "este"]:
		partes.append("<h4>%s</h4>" % nombre_dir.to_upper())
		partes.append("<div class=\"tira\">")
		for letra: String in ["A", "B", "C", "D"]:
			var archivo: String = "%s_88px_sentado_prueba_%s_%s.png" % [prefijo, letra, nombre_dir]
			var etiqueta: String = "Prueba %s (%s) -- %s" % [letra, nombre_dir, descripciones[letra]]
			partes.append("<div>%s<br><img src=\"%s\" alt=\"%s\"></div>" % [etiqueta, archivo, etiqueta])
		partes.append("</div>")
	return "\n".join(partes)


## Escribe, junto a los PNG, qué es cada letra A/B/C/D del experimento de sentado -- para que se
## pueda mirar la hoja de contactos sin tener que volver a leer este script.
func _generar_leyenda_sentado() -> void:
	var texto: String = (
		"PRUEBAS DE SENTADO -- que es cada letra\n"
		+ "=========================================\n\n"
		+ "Estos rigs NO tienen rodilla: la pierna es UNA sola pieza (hueso Foot.L / Foot.R), del\n"
		+ "hueso de la cadera hasta el tobillo. El metodo de render_sprites.gd (doblar cadera Y\n"
		+ "rodilla) no tiene donde aplicarse aqui.\n\n"
		+ "En su lugar se gira la pierna ENTERA desde la cadera hasta dejarla horizontal, y en dos\n"
		+ "de las cuatro variantes se baja ademas el cuerpo entero (hueso CORE) para que el \"culo\"\n"
		+ "quede a la altura de un asiento en vez de quedarse flotando en el aire a la altura de\n"
		+ "la cadera de pie -- girar sin bajar dejaria la pierna horizontal, pero en el sitio donde\n"
		+ "estaba la cadera de pie, no a la altura de una silla.\n\n"
		+ "A = pies girados +85 grados -- cuerpo SIN bajar\n"
		+ "B = pies girados +85 grados -- cuerpo bajado (mitad del largo de la pierna del modelo)\n"
		+ "C = pies girados -85 grados -- cuerpo SIN bajar\n"
		+ "D = pies girados -85 grados -- cuerpo bajado (mitad del largo de la pierna del modelo)\n\n"
		+ "Ninguna se eligio a mano: se renderizan las 4 y las juzga un humano mirandolas. Con un\n"
		+ "rig ajeno no se deduce el signo ni la distancia correctos, se miran -- misma norma que ya\n"
		+ "costo cara con el signo de cadera/rodilla en render_sprites.gd.\n\n"
		+ "Cada variante se renderiza en DOS direcciones, sufijo _sur / _este: de frente (SUR) casi no\n"
		+ "se distingue hacia donde giro la pierna (queda escondida contra el cuerpo); de perfil\n"
		+ "(ESTE) se ve sin ambiguedad hacia que lado quedo.\n\n"
		+ "Hay una copia de estas 8 imagenes (4 letras x 2 direcciones) por cada modelo procesado\n"
		+ "(oficial_h_*, oficial_m_*).\n"
	)
	var archivo := FileAccess.open(SALIDA + "sentado_prueba_leyenda.txt", FileAccess.WRITE)
	if archivo == null:
		push_error("RenderSpritesAnimado: no se pudo escribir sentado_prueba_leyenda.txt")
		return
	archivo.store_string(texto)
	archivo.close()
