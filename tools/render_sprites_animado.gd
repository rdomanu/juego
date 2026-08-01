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
## ── LA POSE DE SENTADO (2026-08-01: DECIDIDA, ya no es un experimento) ───────────────────────────
## Sin rodilla, lo único que se puede doblar es la cadera: se gira el hueso `Foot.L`/`Foot.R` entero
## (que en este rig es la pierna completa, no solo el pie) hasta la horizontal, y de propina se baja
## el cuerpo para que la pierna horizontal quede a la altura de un asiento en vez de flotando en el
## aire a la altura de la cadera de pie. El signo del giro y si hacía falta bajar el cuerpo NO se
## podían deducir de las convenciones de este rig ajeno, así que se generaron 4 combinaciones
## (A/B/C/D, signo del giro × con/sin bajar) y las juzgó el usuario mirándolas: **pies girados −85°
## (piernas hacia delante, el signo de "C") CON el cuerpo bajado (lo que distingue "D" de "C")**. Es
## la variante D del experimento — ver `_posar_sentado` (antes `_posar_sentado_prueba`) y el
## historial en `production/session-state/` para el porqué de cada combinación descartada.
##
## ── SALIDA ─────────────────────────────────────────────────────────────────────────────────────
## Escribe DIRECTO en `res://assets/sprites/personajes/`, con la MISMA nomenclatura que ya consume
## `src/main/muneco.gd` para los ciudadanos (prefijo "girl"): `{prefijo}_{alto}px_{dir}_{fotograma}.png`
## para el ciclo de andar (8 direcciones × 8 fotogramas) y `{prefijo}_{alto}px_sit_{dir}.png` para el
## sentado (8 direcciones, sin fotograma: sentado no se mueve). Sin fotogramas de "reposo" sueltos —
## el fotograma 0 del ciclo de andar hace de pose de pie quieta (mismo criterio que "girl": es lo que
## `Muneco.animar_sprite` enseña cuando `andando` es 0).

## Un trabajo por modelo: dónde está el `.glb` y con qué prefijo se guardan sus sprites.
##
## `oficial_m` lleva además `piel_celda`/`piel_referencia`: las dos figuras comparten LA MISMA
## textura `GGrid.png` (un atlas de 8×4 franjas de color, confirmado byte a byte), pero cada una
## pinta su piel con una franja distinta de esa rejilla (oficial_h con (3,1), oficial_m con (6,0) —
## averiguado leyendo a qué celda apunta la UV de los vértices que MÁS le deben a los huesos
## `Head`/`Hand.*`/dedos, no a ojo). El encargo del usuario es que las dos usen el tono claro del
## hombre, así que a `oficial_m` se le copia la celda (3,1) del hombre ENCIMA de su propia (6,0) — ver
## `_igualar_piel`.
##
## `correccion_frente_grados` (2026-08-01, feedback con el juego abierto: *"la orientación de cómo
## se sientan, cómo andan y demás de los policías es errónea; la de los ciudadanos está bien"*):
## este rig NO tiene rodilla, así que `HUESO_PIE`/`HUESO_PUNTA` (`Foot.L`/`Toes.L`) NO son "talón" y
## "punta" como en el rig de `render_sprites.gd` — `Foot.L` es la PIERNA ENTERA desde la CADERA (ver
## la cabecera del archivo), así que el vector que mide `_frente_de` no es "hacia dónde apunta el
## pie", es casi vertical (cadera→tobillo) con una componente horizontal poco fiable. `rumbo_reposo`
## salía mal, y como se resta POR IGUAL en las 8 direcciones, el error es un desfase CONSTANTE (no
## una mezcla ni un espejo — se verificó comparando, índice a índice, contra `girl` con
## `tools/diagnostico_orientacion.gd`: el mismo sentido de giro, desplazado). Medido: el "frente" de
## `oficial_h`/`oficial_m` salía **+2 índices (90°) adelantado** respecto de `girl` — el centro del
## grupo de direcciones donde se ve la CARA estaba en el índice ~3.5 (debería estar en el ~1.5 de
## `girl`). Se corrige SUMÁNDOLO a `rumbo_reposo` (ver `_procesar_modelo`): un desfase constante no es
## un signo distinto de `SENTADO_GRADOS_PIE` (eso gira las PIERNAS sobre su cadera; esto gira el
## CUERPO ENTERO antes de fotografiarlo) — los dos rigs comparten el mismo problema de origen, así que
## se aplica igual a los dos trabajos.
const TRABAJOS: Array[Dictionary] = [
	{
		"ruta": "res://capturas/NPC/Policias/candidatos/male_officer.glb", "prefijo": "oficial_h",
		"correccion_frente_grados": 90.0,
	},
	{
		"ruta": "res://capturas/NPC/Policias/candidatos/female_officer.glb", "prefijo": "oficial_m",
		"piel_celda": Vector2i(6, 0),
		"piel_referencia_ruta": "res://capturas/NPC/Policias/candidatos/male_officer.glb",
		"piel_referencia_celda": Vector2i(3, 1),
		"correccion_frente_grados": 90.0,
	},
]
## RENDER FINAL (2026-08-01): antes apuntaba a `capturas/.../render_test/` (candidatos, descartable);
## ahora escribe donde el juego de verdad carga los sprites (`Muneco.RUTA_SPRITES`).
const SALIDA := "res://assets/sprites/personajes/"

## Cámara: mismo ángulo isométrico que `render_sprites.gd` (`atan(1/2)`, no los 30° "de libro").
const ELEVACION_GRADOS: float = 26.565
const DIRECCIONES: int = 8
## Qué índice de dirección es "SUR" (el personaje mirando de frente a cámara). Es el mismo que usó
## `render_sprites.gd` para sus pruebas de signo (`PROBAR_SIGNOS` en `i == 6`).
const DIRECCION_SUR: int = 6
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
## Cuánto se baja el cuerpo en la pose sentada final, como fracción del largo de la pierna medido en
## REPOSO (cadera→tobillo). Es la que usaba la variante "con bajada" (B/D) del experimento — sin
## bajar, la pierna queda horizontal pero flotando a la altura de la cadera de pie, no a la de un
## asiento.
const SENTADO_BAJADA_FRACCION: float = 0.5
## El SIGNO del giro elegido por el usuario tras el experimento A/B/C/D: −85° (piernas hacia
## DELANTE), el mismo signo que las variantes "C"/"D". Con `SENTADO_BAJADA_FRACCION` aplicado
## (equivalente a "D"), es la pose sentada FINAL — ver la cabecera del archivo.
const SENTADO_SIGNO_PIE_FINAL: float = -1.0

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
	print("[RENDER] hecho: %d/%d modelos procesados" % [_procesados.size(), TRABAJOS.size()])
	get_tree().quit()


## Carga, encuadra, renderiza las 8 direcciones (8 fotogramas de andar cada una, el fotograma 0 hace
## de pie quieto) y las 8 direcciones de sentado (pose final) de UN modelo, y libera la escena antes
## de devolver el control.
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
	# CORRECCIÓN (2026-08-01, ver `correccion_frente_grados` en `TRABAJOS`): en este rig la medición
	# sale girada un desfase CONSTANTE (rig sin rodilla, `Foot.L` no es el pie); se suma aquí, antes
	# de restarse en cada una de las 8 direcciones (así el paso de 45° entre direcciones, que SÍ es
	# correcto, no se toca — solo se corrige la fase de arranque).
	var frente: Vector3 = _frente_de(esqueleto)
	var correccion: float = deg_to_rad(float(trabajo.get("correccion_frente_grados", 0.0)))
	var rumbo_reposo: float = atan2(frente.x, frente.z) + correccion

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

		# Sin "reposo_%d" suelto (mismo criterio que "girl"): el fotograma 0 del ciclo de ANDAR de
		# más abajo hace de pose de pie quieta en el juego (ver `Muneco.animar_sprite`).
		# ANDAR: 8 instantes equiespaciados del ciclo de "Armature|Walk".
		for f: int in FOTOGRAMAS:
			var t: float = float(f) / float(FOTOGRAMAS)
			_muestrear(reproductor, anim_andar, t)
			_anular_root_motion(esqueleto)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			_guardar(_recortar(_sub.get_texture().get_image()), prefijo, "%d_%d" % [i, f])
		print("[RENDER] %s: dirección %d/%d lista (%d fotogramas)" % [prefijo, i + 1, DIRECCIONES, FOTOGRAMAS])

	# SENTADO (final, 2026-08-01): la pose que eligió el usuario tras el experimento A/B/C/D --
	# `SENTADO_SIGNO_PIE_FINAL` (el signo de "C") + cuerpo bajado (lo que distinguía "D" de "C") --
	# en las 8 direcciones, igual que el ciclo de andar y que `girl_*_sit_*.png`.
	var bajada: float = _largo_pierna(esqueleto) * SENTADO_BAJADA_FRACCION
	print("[RENDER] %s: largo de pierna en reposo (CORE->Toes.L, en mundo) = %.5f -> bajada = %.5f" % [
		prefijo, _largo_pierna(esqueleto), bajada
	])
	var idx_raiz_diag: int = _hueso(esqueleto, HUESO_RAIZ) if esqueleto != null else -1
	# La Y LOCAL de CORE con la pose de Idle limpia, capturada UNA vez. Cada dirección parte de ESTA
	# misma Y (absoluta, no relativa a "lo que hubiera antes") -- si no, una dirección deja la Y baja
	# y la siguiente hereda esa bajada encima de la suya.
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
		# SIEMPRE se parte de un Idle recién muestreado: si no, la dirección anterior deja las
		# piernas giradas puestas y esta hereda esos restos encima de los suyos.
		_muestrear(reproductor, anim_reposo, 0.0)
		# ⚠️ CAUSA DEL BUG "todas salen iguales, de pie": con el AnimationPlayer todavía
		# "reproduciendo" (aunque `speed_scale = 0` impida que el TIEMPO avance), el AnimationMixer
		# reaplica la pose de Idle en CADA frame procesado -- incluidos los
		# `await RenderingServer.frame_post_draw` de más abajo -- así que pisaba las ediciones
		# manuales de pierna/cuerpo antes de que llegaran a capturarse. `stop(true)` congela la
		# pose actual (`keep_state`) y deja de reprocesarla.
		if reproductor != null:
			reproductor.stop(true)
		_anular_root_motion(esqueleto)
		_posar_sentado(esqueleto, SENTADO_SIGNO_PIE_FINAL, true, bajada, core_y_base)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		_guardar(_recortar(_sub.get_texture().get_image()), prefijo, "sit_%d" % i)
	print("[RENDER] %s: 8 direcciones de sentado listas" % prefijo)

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


## LA POSE SENTADA: sin rodilla, lo único que hay para "sentar" es girar la pierna entera desde la
## cadera hasta la horizontal (`Foot.L`/`Foot.R`, que en este rig hacen de muslo+pantorrilla en una
## pieza) y, si `bajar_cuerpo`, bajar el hueso raíz esa distancia — para que la pierna horizontal
## quede a la altura de un asiento en vez de flotando a la altura de la cadera de pie. `signo_pie` y
## `bajar_cuerpo` NO se dedujeron de este rig ajeno: se generaron las 4 combinaciones A/B/C/D y las
## juzgó el usuario mirándolas (ver la cabecera del archivo) — `_procesar_modelo` llama aquí siempre
## con `SENTADO_SIGNO_PIE_FINAL` y `bajar_cuerpo = true`, la combinación elegida.
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
	partes.append("<title>Sprites de policia -- render final</title>")
	partes.append(_estilo_index())
	partes.append("</head><body>")
	partes.append("<h1>Sprites de policia -- render final</h1>")
	partes.append(
		"<p>Direccion %d = SUR (el personaje mirando de frente a camara). Todas las imagenes a 88 px, fondo a cuadros para ver la transparencia. El fotograma 0 de cada direccion hace de pose de pie quieta (sin reposo suelto, mismo criterio que \"girl\").</p>"
		% DIRECCION_SUR
	)
	for prefijo: String in _procesados:
		partes.append("<h2>%s</h2>" % prefijo)
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
