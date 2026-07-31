extends Node3D
## Renderizador de SPRITES ISOMÉTRICOS desde un modelo 3D.
##
## Es la herramienta que convierte un modelo 3D en las imágenes que el juego dibuja — el mismo
## camino que usaron Theme Hospital, RollerCoaster Tycoon y Age of Empires, y la razón por la que
## sus personajes se ven coherentes desde todos los ángulos: **es la misma persona girada**, no
## ocho dibujos que intentan parecerse.
##
## ── CÓMO SE USA ────────────────────────────────────────────────────────────────────────────────
##   godot --path <proyecto> res://tools/RenderSprites.tscn
##
## Escribe los PNG en `assets/sprites/personajes/` y cierra solo. **No puede correr en headless**:
## renderizar necesita tarjeta gráfica, así que abre una ventana un par de segundos.
##
## ── LAS DOS CUENTAS QUE IMPORTAN ───────────────────────────────────────────────────────────────
## **El ángulo.** La proyección del juego es un rombo 2:1 (ver `Proyeccion`), y para que un render
## 3D encaje con ese suelo la cámara tiene que mirar desde `atan(1/2) = 26,57°` sobre la horizontal.
## Con los 30° del isométrico "de libro" los pies del muñeco no pisarían el rombo. Y en horizontal,
## 45°: la esquina de la casilla mirando a cámara.
##
## **Ortográfica, no en perspectiva.** En perspectiva, un personaje en el centro de la pantalla y
## otro en la esquina se verían con inclinaciones distintas, y en un mundo hecho de sprites iguales
## eso canta. La cámara ortográfica los ve todos igual, que es justo lo que hace falta.

## Dónde está el modelo y cómo se van a llamar los sprites.
const MODELO := "res://capturas/NPC/girl.glb"
const SALIDA := "res://assets/sprites/personajes/"
const PREFIJO := "girl"

## Ángulo de la cámara sobre la horizontal. `atan(0.5)` en grados: el que corresponde a un rombo 2:1.
const ELEVACION_GRADOS: float = 26.565
## Cuántas direcciones. 8 = las cuatro rectas más las cuatro diagonales; con 4 también se puede
## empezar (el juego reutiliza el espejo para izquierda/derecha).
const DIRECCIONES: int = 8
## Tamaño del render, en píxeles. Se renderiza GRANDE y se reduce después: bajar de tamaño conserva
## el detalle mucho mejor que renderizar pequeño de entrada.
const TAM_RENDER: int = 512
## Alturas finales a las que se guarda cada sprite. 44 px es la que encaja con el juego: el rombo
## de una celda mide 80×40, y un personaje que mida como el ALTO del rombo se lee sin comerse la
## casilla del vecino. (Se probó a 72 y el usuario lo cazó al momento: "se ven demasiado grandes".)
const ALTURAS: Array[int] = [88, 44]

## ── EL CICLO DE ANDAR, HECHO SOBRE EL ESQUELETO (2026-07-31) ──────────────────────────────────
## El usuario, viendo los primeros sprites: *"no se animan, no se ve el movimiento del esqueleto"*.
## Y tenía razón: el modelo trae ARMADURA pero **ninguna animación**, así que renderizarlo daba ocho
## estatuas en T-pose.
##
## Lo normal aquí sería ir a Mixamo a por un "walking". Pero el esqueleto tiene nombres estándar
## (`LeftUpLeg`, `RightArm`…), así que el ciclo se puede **generar aquí mismo**, con la misma
## fórmula que ya mueve al muñeco de piezas del juego: piernas en oposición, brazos al revés que la
## pierna de su lado. Sin Mixamo, sin Blender y, sobre todo, **sin depender de la licencia de una
## animación de terceros**.
##
## Además baja los brazos de la T-pose, que es lo que hace que ahora mismo parezca un espantapájaros.
const FOTOGRAMAS: int = 8
## Cuánto se abren piernas y brazos, en grados. La pierna manda; el brazo acompaña.
const AMPLITUD_PIERNA_3D: float = 26.0
const AMPLITUD_BRAZO_3D: float = 16.0
## Huesos que se mueven. Los nombres llevan sufijo numérico en este modelo, así que se buscan por
## PREFIJO — así el mismo código vale para otro personaje con la misma convención de nombres.
const HUESO_PIERNA_IZQ := "LeftUpLeg"
const HUESO_PIERNA_DER := "RightUpLeg"
const HUESO_BRAZO_IZQ := "LeftArm"
const HUESO_BRAZO_DER := "RightArm"
## Con estos dos se averigua HACIA DÓNDE MIRA el personaje en su pose de reposo: del talón a la
## punta del pie. Es el dato que no se puede suponer y que lo ordena todo (ver `_frente_de`).
const HUESO_PIE := "LeftFoot"
const HUESO_PUNTA := "LeftToeBase"

## ── LA POSE DE SENTADO (2026-08-01) ───────────────────────────────────────────────────────────
## Petición del usuario: *"¿harían el movimiento de sentarse en una silla?"*. Sí, y por el mismo
## camino que el andar: se posa el esqueleto y se renderiza. Sentarse es doblar la cadera hacia
## delante y la rodilla hacia atrás, las dos casi en ángulo recto.
##
## Es UNA sola imagen por dirección (sentado no se mueve), así que sale baratísimo: 8 imágenes.
const HUESO_RODILLA_IZQ := "LeftLeg"
const HUESO_RODILLA_DER := "RightLeg"
## Grados que se dobla cada articulación al sentarse. 85 y no 90: un ángulo exacto se lee como un
## maniquí; un pelín menos, como una persona.
const SENTADO_CADERA: float = 85.0
const SENTADO_RODILLA: float = 85.0
## Cuánto se separan los brazos del cuerpo sentado (las manos caen sobre los muslos).
const SENTADO_BRAZO: float = 20.0
## Hacia qué lado dobla cada articulación al sentarse. NO se dedujeron: se PROBARON las cuatro
## combinaciones renderizándolas y mirando cuál era la buena (poniendo `PROBAR_SIGNOS` en true).
##
## Y la elegida es además la que dice la cuenta: con la cadera girando hacia delante y la rodilla
## la misma cantidad en sentido contrario, las dos rotaciones se cancelan en la espinilla — muslo
## horizontal y pierna cayendo recta, que es exactamente cómo se sienta una persona. Cuando el
## número que sale de medir coincide con el que sale de razonar, es que está bien.
const SIGNO_CADERA: float = -1.0
const SIGNO_RODILLA: float = 1.0
## Modo diagnóstico: saca las cuatro combinaciones de signo para poder compararlas de un vistazo.
const PROBAR_SIGNOS: bool = false
## Cuánto se separan los brazos del cuerpo al bajarlos (0 = pegados; 0,25 ≈ postura natural).
const SEPARACION_BRAZOS: float = 0.22

var _modelo: Node3D
var _camara: Camera3D
var _sub: SubViewport
## Lo que mide la figura DE PIE en el render grande. Es la vara de medir de todas las demás poses.
var _alto_referencia: int = 0


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	if escena == null:
		push_error("RenderSprites: no se pudo cargar %s" % MODELO)
		get_tree().quit(1)
		return
	# Todo se monta dentro de un SubViewport con fondo TRANSPARENTE: así los PNG salen recortados y
	# no hay que quitarles el fondo después (que es lo que hubo que hacer a mano con la foto).
	_sub = SubViewport.new()
	_sub.size = Vector2i(TAM_RENDER, TAM_RENDER)
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)

	var mundo := Node3D.new()
	_sub.add_child(mundo)
	_modelo = escena.instantiate()
	mundo.add_child(_modelo)

	# Luz suave y frontal-cenital: se busca leer la SILUETA y el color, no un claroscuro bonito. Con
	# sombras duras, a tamaño de juego el personaje se convierte en un borrón.
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
	_encuadrar()
	_renderizar_todas()


## Coloca la cámara en el ángulo isométrico y la aleja lo justo para que el modelo entre entero.
## El tamaño se saca de la CAJA del modelo, no a ojo: así vale para cualquier personaje que se meta
## después, sin tocar números.
func _encuadrar() -> void:
	var caja: AABB = _caja_de(_modelo)
	var centro: Vector3 = caja.get_center()
	var alto: float = maxf(caja.size.y, maxf(caja.size.x, caja.size.z))
	# Un 15 % de aire alrededor para que no se corten ni las manos ni la coronilla.
	_camara.size = alto * 1.15
	var yaw: float = deg_to_rad(45.0)
	var pitch: float = deg_to_rad(ELEVACION_GRADOS)
	var distancia: float = alto * 3.0
	_camara.position = centro + Vector3(
		sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)
	) * distancia
	_camara.look_at(centro, Vector3.UP)


## La caja que ocupa el modelo, juntando la de todas sus mallas (un personaje son varias piezas:
## cuerpo, pelo, ropa…).
func _caja_de(nodo: Node) -> AABB:
	var caja := AABB()
	var primera := true
	for hijo: Node in nodo.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		var suya: AABB = mi.get_aabb()
		# A coordenadas del modelo: cada malla puede venir con su propia transformada.
		suya = mi.global_transform * suya if mi.is_inside_tree() else suya
		if primera:
			caja = suya
			primera = false
		else:
			caja = caja.merge(suya)
	return caja


## Gira el modelo y guarda una imagen por dirección.
func _renderizar_todas() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	var esqueleto: Skeleton3D = _buscar_esqueleto(_modelo)
	if esqueleto == null:
		push_warning("RenderSprites: el modelo NO trae esqueleto -> sale en su pose original")
	# El FRENTE del personaje en su pose de reposo. Sin esto habría que suponerlo, y suponerlo fue
	# justo lo que hizo que los ciudadanos entraran de lado y andando hacia atrás.
	var frente: Vector3 = _frente_de(esqueleto)
	var rumbo_reposo: float = atan2(frente.x, frente.z)
	# La ALTURA DE REFERENCIA: lo que mide la figura DE PIE. Todo lo demás se escala con ese mismo
	# factor, para que sentarse no cambie el tamaño del personaje (ver `_guardar`).
	_posar(esqueleto, 0.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_alto_referencia = _recortar(_sub.get_texture().get_image()).get_height()
	print("[RENDER] altura de referencia (de pie): %d px" % _alto_referencia)
	for i: int in DIRECCIONES:
		# El sprite `i` es el personaje mirando al rumbo `i × 45°` de la REJILLA, contado desde el
		# este (+X) y girando hacia el sur (+Y). Como el render usa X y Z donde la rejilla usa X e Y,
		# ese rumbo es la dirección (cos, 0, sen) del mundo 3D. Se calcula cuánto hay que girar el
		# modelo para que su frente apunte ahí — así el índice significa lo mismo en las dos partes.
		var rumbo: float = TAU / DIRECCIONES * i
		var objetivo: float = atan2(cos(rumbo), sin(rumbo))
		_modelo.rotation = Vector3(0.0, objetivo - rumbo_reposo, 0.0)
		# La pose de SENTADO: una sola imagen por dirección, con su propio nombre.
		if PROBAR_SIGNOS and i == 6:
			# Modo diagnóstico: las cuatro combinaciones de signo cadera/rodilla, para MIRAR cuál es
			# la buena en vez de deducirla de las convenciones de ejes de un rig ajeno.
			for cadera: int in [1, -1]:
				for rodilla: int in [1, -1]:
					_posar_sentado(esqueleto, float(cadera), float(rodilla))
					await RenderingServer.frame_post_draw
					await RenderingServer.frame_post_draw
					_guardar(_recortar(_sub.get_texture().get_image()),
						"prueba_c%d_r%d" % [cadera, rodilla])
		_posar_sentado(esqueleto)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		_guardar(_recortar(_sub.get_texture().get_image()), "sit_%d" % i)
		for f: int in FOTOGRAMAS:
			_posar(esqueleto, float(f) / float(FOTOGRAMAS))
			# DOS frames de espera: uno para que se apliquen rotación y pose, y otro para que el
			# SubViewport las haya dibujado. Con uno solo, la imagen sale con la pose anterior.
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			_guardar(_recortar(_sub.get_texture().get_image()), "%d_%d" % [i, f])
		print("[RENDER] dirección %d/%d lista (%d fotogramas)" % [i + 1, DIRECCIONES, FOTOGRAMAS])
	print("[RENDER] hecho: %d direcciones × %d fotogramas × %d tamaños" % [
		DIRECCIONES, FOTOGRAMAS, ALTURAS.size()
	])
	get_tree().quit()


## Guarda una imagen en todos los tamaños pedidos, con el sufijo que la identifica.
##
## ⚠️ Cada imagen se reescala DESDE la grande, nunca en cadena: reducir a 88 y de ahí a 44 acumula
## el emborronamiento de las dos pasadas.
func _guardar(imagen: Image, sufijo: String) -> void:
	for alto: int in ALTURAS:
		# ⚠️ TODAS las imágenes se escalan con el MISMO factor, sacado de la figura DE PIE. No se
		# ajusta cada una a la altura pedida.
		#
		# Parece un detalle y es el fallo que cazó el usuario: *"cambia de tamaño cuando se sienta,
		# es más grande la figura sentada"*. Claro — una persona sentada es más baja, así que
		# forzarla a medir los mismos píxeles de alto es AMPLIARLA. Con un factor común, sentada
		# sale más baja, que es lo que tiene que pasar.
		#
		# De paso arregla algo que casi no se veía pero estaba: los fotogramas del andar tampoco
		# miden todos igual (con una pierna levantada la figura es un pelín más corta), así que el
		# personaje "respiraba" de tamaño a cada paso.
		var escala: float = float(alto) / float(maxi(_alto_referencia, 1))
		var copia: Image = imagen.duplicate()
		copia.resize(
			maxi(1, roundi(float(copia.get_width()) * escala)),
			maxi(1, roundi(float(copia.get_height()) * escala)),
			Image.INTERPOLATE_LANCZOS
		)
		var ruta: String = "%s%s_%dpx_%s.png" % [SALIDA, PREFIJO, alto, sufijo]
		copia.save_png(ProjectSettings.globalize_path(ruta))


## Pone al esqueleto SENTADO: cadera doblada hacia delante y rodilla hacia atrás. Mismo criterio que
## el andar — todo se calcula sobre el frente real del personaje, nunca sobre ejes supuestos.
func _posar_sentado(
	esqueleto: Skeleton3D, signo_cadera: float = SIGNO_CADERA,
	signo_rodilla: float = SIGNO_RODILLA
) -> void:
	if esqueleto == null:
		return
	var frente: Vector3 = _frente_de(esqueleto)
	var lateral: Vector3 = Vector3.UP.cross(frente).normalized()
	# El muslo sube (cadera doblada) y la pantorrilla baja (rodilla doblada). Los signos son
	# opuestos entre cadera y rodilla: es lo que forma la "Z" de alguien sentado.
	for hueso: String in [HUESO_PIERNA_IZQ, HUESO_PIERNA_DER]:
		_girar_mundo(esqueleto, hueso, lateral, signo_cadera * deg_to_rad(SENTADO_CADERA))
	for hueso: String in [HUESO_RODILLA_IZQ, HUESO_RODILLA_DER]:
		_girar_mundo(esqueleto, hueso, lateral, signo_rodilla * deg_to_rad(SENTADO_RODILLA))
	# Y los brazos bajados y quietos, con las manos hacia los muslos.
	_bajar_y_balancear(esqueleto, HUESO_BRAZO_IZQ, deg_to_rad(SENTADO_BRAZO), lateral)
	_bajar_y_balancear(esqueleto, HUESO_BRAZO_DER, deg_to_rad(SENTADO_BRAZO), lateral)


## El primer Skeleton3D que cuelgue del modelo (`null` si no trae).
func _buscar_esqueleto(nodo: Node) -> Skeleton3D:
	for hijo: Node in nodo.find_children("*", "Skeleton3D", true, false):
		return hijo as Skeleton3D
	return null


## Pone al esqueleto en el instante `t` del ciclo de andar (0 a 1). Misma fórmula que el muñeco de
## piezas del juego: piernas en oposición y brazos al revés que la pierna de su lado.
##
## ⚠️ **Todo se calcula en el espacio del MUNDO, no en el del hueso.** Primer intento: girar cada
## hueso sobre su eje Z local para bajar los brazos. Resultado: un brazo bajaba y el otro se
## levantaba en alto — porque en este esqueleto los dos brazos NO tienen la orientación espejada,
## así que el mismo giro local los mueve a sitios distintos. Adivinar el eje de un rig ajeno no
## funciona.
##
## Lo que sí funciona: preguntarle al propio esqueleto **hacia dónde apunta** cada hueso en su
## postura de reposo (mirando dónde está su hijo) y calcular el giro que lo lleva a donde queremos.
## Eso vale para este modelo y para cualquier otro, sin tocar una constante.
func _posar(esqueleto: Skeleton3D, t: float) -> void:
	if esqueleto == null:
		return
	var vaiven: float = sin(t * TAU)
	# El eje sobre el que se balancean piernas y brazos es el LATERAL del personaje (de hombro a
	# hombro), no un eje fijo del mundo. Con un eje fijo, la pierna se adelanta hacia donde mire el
	# ESCENARIO y no hacia donde mire ÉL: el usuario lo cazó al momento — *"entran de lado y las
	# piernas como para adelante"*.
	var frente: Vector3 = _frente_de(esqueleto)
	var lateral: Vector3 = Vector3.UP.cross(frente).normalized()
	# ⚠️ LAS RODILLAS SE DEVUELVEN A SU SITIO. Parece innecesario —el andar no las dobla— pero no lo
	# es: la pose de SENTADO sí las dobla, y las poses no se borran solas entre imagen e imagen. Como
	# el sentado se renderiza justo antes de las de andar, sin esta línea todos los fotogramas de
	# caminar salían con las rodillas dobladas. El usuario lo describió clavado: *"andan de
	# rodillas"*.
	#
	# Regla que deja: **una pose se define ENTERA**. Todo hueso que alguna pose toque, todas las
	# demás tienen que devolverlo — si no, se heredan restos de la anterior.
	_girar_mundo(esqueleto, HUESO_RODILLA_IZQ, lateral, 0.0)
	_girar_mundo(esqueleto, HUESO_RODILLA_DER, lateral, 0.0)
	# Las piernas: adelante y atrás, en oposición.
	_girar_mundo(esqueleto, HUESO_PIERNA_IZQ, lateral, deg_to_rad(AMPLITUD_PIERNA_3D) * vaiven)
	_girar_mundo(esqueleto, HUESO_PIERNA_DER, lateral, -deg_to_rad(AMPLITUD_PIERNA_3D) * vaiven)
	# Los brazos: primero se BAJAN (se les lleva de la cruz de la T-pose a lo largo del cuerpo) y
	# encima el balanceo, al revés que la pierna de su lado.
	_bajar_y_balancear(esqueleto, HUESO_BRAZO_IZQ, -deg_to_rad(AMPLITUD_BRAZO_3D) * vaiven, lateral)
	_bajar_y_balancear(esqueleto, HUESO_BRAZO_DER, deg_to_rad(AMPLITUD_BRAZO_3D) * vaiven, lateral)


## HACIA DÓNDE MIRA el personaje en su pose de reposo, en horizontal.
##
## Se saca **de la punta del pie**: del talón a los dedos. Es el único dato del esqueleto que no
## admite interpretación —los dedos de los pies apuntan hacia delante en cualquier persona y en
## cualquier rig—, y de ahí sale todo lo demás: el giro de cada sprite y el eje del balanceo.
##
## Se probó antes a suponerlo (dar por hecho que el frente era un eje concreto) y el resultado fue
## que los ciudadanos entraban de lado andando hacia atrás. Este proyecto ya ha aprendido tres veces
## esta noche que con los rigs ajenos no se supone: se mide.
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


## El índice de un hueso buscándolo por PREFIJO (este modelo les pone sufijo numérico:
## `LeftUpLeg_068`). -1 si no está.
func _hueso(esqueleto: Skeleton3D, prefijo: String) -> int:
	for i: int in esqueleto.get_bone_count():
		if esqueleto.get_bone_name(i).begins_with(prefijo):
			return i
	return -1


## Hacia dónde APUNTA un hueso en su postura de reposo, en coordenadas del mundo: del hueso a su
## hijo. Es lo que permite razonar sobre "el brazo" sin saber cómo orientó sus ejes quien lo montó.
func _direccion_de(esqueleto: Skeleton3D, idx: int) -> Vector3:
	var hijos: PackedInt32Array = esqueleto.get_bone_children(idx)
	if hijos.is_empty():
		return Vector3.DOWN
	var origen: Vector3 = esqueleto.get_bone_global_rest(idx).origin
	var destino: Vector3 = esqueleto.get_bone_global_rest(hijos[0]).origin
	var d: Vector3 = destino - origen
	return d.normalized() if d.length() > 0.0001 else Vector3.DOWN


## Aplica a un hueso un giro expresado en el MUNDO, partiendo siempre de su pose de reposo (si se
## acumulara sobre la del frame anterior, el personaje se iría retorciendo hasta hacerse un nudo).
##
## La cuenta: un giro `R` del mundo se traduce al espacio del hueso con `B⁻¹ · R · B`, donde `B` es
## la orientación del hueso en reposo. Es el cambio de base de toda la vida.
func _aplicar_giro(esqueleto: Skeleton3D, idx: int, giro_mundo: Basis) -> void:
	var reposo_local: Transform3D = esqueleto.get_bone_rest(idx)
	var base: Basis = esqueleto.get_bone_global_rest(idx).basis.orthonormalized()
	var local: Basis = base.inverse() * giro_mundo * base
	esqueleto.set_bone_pose_position(idx, reposo_local.origin)
	esqueleto.set_bone_pose_rotation(idx, Quaternion((reposo_local.basis * local).orthonormalized()))
	esqueleto.set_bone_pose_scale(idx, Vector3.ONE)


## Gira un hueso `angulo` radianes alrededor de un eje del MUNDO.
func _girar_mundo(esqueleto: Skeleton3D, prefijo: String, eje: Vector3, angulo: float) -> void:
	var idx: int = _hueso(esqueleto, prefijo)
	if idx < 0:
		return
	_aplicar_giro(esqueleto, idx, Basis(eje.normalized(), angulo))


## Baja un brazo de la T-pose hasta pegarlo al cuerpo y le añade el balanceo del paso.
##
## El giro de bajada NO es un número fijo: se calcula. Se mira hacia dónde apunta el brazo en reposo
## y se busca el giro que lleva esa dirección a "hacia abajo y un poco separado". Por eso funciona
## sin saber cómo están orientados los huesos de este modelo en concreto.
func _bajar_y_balancear(
	esqueleto: Skeleton3D, prefijo: String, balanceo: float, lateral: Vector3
) -> void:
	var idx: int = _hueso(esqueleto, prefijo)
	if idx < 0:
		return
	var actual: Vector3 = _direccion_de(esqueleto, idx)
	# El destino: hacia abajo, conservando el lado (izquierda/derecha) para que el brazo no cruce el
	# cuerpo, y con un pelín de separación para que no se clave en las costillas.
	var lado: float = signf(actual.x) if absf(actual.x) > 0.001 else 1.0
	var objetivo: Vector3 = Vector3(lado * SEPARACION_BRAZOS, -1.0, 0.0).normalized()
	var bajada := Basis(Quaternion(actual, objetivo))
	_aplicar_giro(esqueleto, idx, Basis(lateral, balanceo) * bajada)


## Quita el aire transparente de alrededor. Sin esto, cada sprite llevaría un marco vacío distinto
## según lo que ocupara en ese giro y en ese fotograma, y al colocarlos en el juego darían saltos.
func _recortar(imagen: Image) -> Image:
	var usado: Rect2i = imagen.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		return imagen
	return imagen.get_region(usado)
