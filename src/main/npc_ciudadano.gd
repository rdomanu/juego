class_name NPCCiudadano extends CharacterBody2D
## NPCCiudadano — el ciudadano VISIBLE (story flujo-008). COSMÉTICO PURO (FL5/ADR-0001): observa
## el estado de SU PersonaFlujo y camina hacia donde ese estado manda; JAMÁS decide nada de la
## simulación (la atención empieza aunque el NPC siga caminando — el viaje no descuenta trámite).
##
## Navegación (ADR-0004 + manifiesto, post-cutoff verificado en engine-reference/navigation.md):
## NavigationAgent2D hijo, avoidance OFF (Experimental en 4.6), movimiento en _physics_process con
## get_next_path_position + move_and_slide, y NINGÚN target antes del 1er physics frame (el
## NavigationServer sincroniza ahí — el primer path saldría vacío).
##
## Story: production/epics/flujo/story-008-comisaria-viva-npcs.md · TR-flow-005 · ADR-0004

## La PersonaFlujo observada (la VERDAD — el NPC la refleja con retardo visual).
var persona: RefCounted = null

var _manager: Node2D = null
var _nav: NavigationAgent2D = null
var _velocidad: float = 90.0
var _estado_visto: StringName = &""
## El objeto que estaba usando la última vez que se miró (story com-003): cambiar de "nada" a "el
## vending" (y al revés) es un cambio de destino aunque el ESTADO lógico siga siendo el mismo.
var _comodidad_vista: StringName = &""
## El NavigationServer sincroniza en el 1er physics frame: hasta entonces ni target ni camino.
var _nav_lista: bool = false
## ¿Está BLOQUEADO ahora mismo (sin camino REAL hasta su destino — una sala amurallada sin puerta,
## un tabique recién levantado sobre su ruta)? Mientras sea `true`: SIN CAMINO ⇒ SIN
## TELETRANSPORTE (bug reportado por el usuario 2026-08-03: *"las personas... SALTAN"*) — el cuerpo
## no se mueve ni un píxel y encima de su cabeza se ve la señal de prohibido (`IconoProhibido`).
## Ver `_actualizar_destino`.
var _bloqueado: bool = false
## El destino que se le negó (o el vigente, si no está bloqueado): el que se reintenta al recheck.
var _destino_deseado: Vector2 = Vector2.ZERO
## Frames transcurridos desde el último intento de reencontrar camino, mientras está bloqueado.
var _frames_bloqueo: int = 0
## Último valor visto de `Construccion.version_layout` (bug 2026-08-05: ruta cacheada que atravesaba
## un muro levantado a mitad de camino — ver el `elif` de `_physics_process`). `-1` para que la
## primera comparación tras nacer SIEMPRE se considere "layout visto" al día (el primer destino real
## ya lo pone la rama de arriba, por cambio de estado; este contador solo importa DESPUÉS).
var _version_layout_visto: int = -1
## Cuántos physics frames se esperan entre reintentos de camino mientras está BLOQUEADO (~3 s a
## 60 fps). Ni cada frame —el BFS de `NPCsFlujo.hay_camino` barre la rejilla entera, gasto inútil
## si el jugador no ha tocado la obra— ni tan espaciado que se note tardar en desbloquearse tras
## abrir una puerta.
const FRAMES_RECHEQUEO_BLOQUEO: int = 180
## La señal de prohibido sobre la cabeza (nace oculta; ver `configurar` y `_actualizar_destino`).
var _icono_bloqueo: Node2D = null
## ── LOS INDICADORES FLOTANTES NO COMPITEN CON LAS PAREDES (2026-08-06) ─────────────────────────
## z RELATIVO al muñeco de todo lo que flota sobre su cabeza (barra de paciencia + señal de
## prohibido). Desde el cambio estructural de esa fecha, el CUERPO del muñeco vive en la bolsa de
## y-sort compartida (z 0) y una pared frontal puede taparle las piernas — que es lo que se buscaba.
## Lo que NO puede pasar es que esa misma pared se coma un dato que el jugador necesita para decidir
## (cuánta paciencia le queda a esa cola, o que alguien se ha quedado sin camino), así que estos dos
## nodos suben a un z propio, por encima de toda la escalera de capas del juego.
##
## Copia deliberada de `NPCsFlujo.Z_ROTULO_FLOTANTE` (mismo valor, misma razón): `npcs_flujo.gd` YA
## hace `preload` de este fichero, así que leer su constante desde aquí cerraría un ciclo. La
## documentación viva del reparto de capas está allí; aquí solo se aplica.
const Z_ROTULO_FLOTANTE: int = 6

## Tamaño de la barra de paciencia (px). Ancha para leerse a distancia de cámara sin acercarse.
const ANCHO_BARRA := 16.0
const ALTO_BARRA := 3.0
## Fondo de la barra: el hueco que deja ver cuánta paciencia le queda POR PERDER.
const COLOR_BARRA_FONDO := Color(0, 0, 0, 0.45)
## Barra de paciencia sobre la cabeza: relleno + fondo. Se refresca por DIFF (ancho y color solo
## cambian cuando de verdad cambian).
var _animo: ColorRect = null
var _animo_fondo: ColorRect = null
var _animo_visto: StringName = &""
var _ancho_visto: float = -1.0
## El documento con el que sale (GDD impresora-documentos-tramite.md): `persona.con_papel` es la
## VERDAD (la fija `Flujo._completar_atencion`), esto solo recuerda si YA se colgó el papel para
## poder hacer DIFF — mismo criterio que `_animo_visto`.
var _papel_visto: bool = false

## ISOMÉTRICO (2026-07-30) — el muñeco que SE VE. Este nodo (el CharacterBody2D) anda por el plano
## lógico CUADRADO, que es donde vive la navegación y donde están calibradas las velocidades; pero
## no se dibuja ahí. Su cuerpo visible cuelga aparte, en la capa de escena isométrica, y cada
## physics frame se le copia la posición ya proyectada. Es la misma persona contada dos veces: una
## en el plano del arquitecto y otra en la foto en perspectiva.
##
## Por qué separados y no un solo nodo: si el cuerpo se dibujara donde anda, habría que deformar
## todo el plano para verlo en rombos — y eso deformaría también al muñeco (saldría tumbado) y
## haría que andar en diagonal costara el doble o la mitad según hacia dónde. Ver la explicación
## larga en `src/foundation/proyeccion/proyeccion.gd`.
var muneco: Node2D = null

## El muñeco de piezas que anda (compartido con los funcionarios: el andar es el mismo para todos).
const MunecoScript := preload("res://src/main/muneco.gd")
## La señal de prohibido (bloqueo de camino), compartida con el caminante de NPCsFlujo.
const IconoProhibidoScript := preload("res://src/main/icono_prohibido.gd")
## Los 7 modelos de ciudadano civil (2026-08-04, serie CUTES de J-Toastie, poly.pizza, CC BY 3.0 —
## sustituyen a la prueba de arte "girl", que se conserva en disco pero deja de usarse). Renderizados
## con `tools/render_sprites_civiles.gd`. Los dos primeros conservan el género del nombre del asset
## original (`generic_male`/`generic_female`); los otros 5 (`citizen1..3`, `retail_worker`,
## `crypto_bro`) no lo dicen en el nombre, así que el género de su prefijo se decidió a ojo viendo el
## render (pelo, silueta, ropa) — ver la nota completa en `render_sprites_civiles.gd`.
## + 14 VARIANTES DE COLOR (2026-08-04, misma licencia — solo cambia ropa/pelo de la textura propia
## del `.glb`, ver `tools/render_variantes_civiles_produccion.gd`): sufijo b/c pegado al prefijo del
## modelo original. Van SEGUIDAS de su original en la lista (no da igual el orden entre modelos, pero
## sí que cada trío a/b/c esté junto, para que el reparto por `numero_turno % 21` alterne modelo y
## color a partes iguales).
const PREFIJOS_CIVIL: Array[String] = [
	"civil_h1", "civil_h1b", "civil_h1c",
	"civil_m1", "civil_m1b", "civil_m1c",
	"civil_h2", "civil_h2b", "civil_h2c",
	"civil_h3", "civil_h3b", "civil_h3c",
	"civil_m2", "civil_m2b", "civil_m2c",
	"civil_h4", "civil_h4b", "civil_h4c",
	"civil_h5", "civil_h5b", "civil_h5c",
]
const ALTO_SPRITE: int = 44


## Monta el cuerpo (fantasma: sin capas de colisión — sin avoidance los NPCs se atraviesan, MVP),
## el agente de navegación y el "muñeco" placeholder con el color de su servicio.
func configurar(
	p_persona: RefCounted, manager: Node2D, velocidad: float, color: Color,
	piel: Color = MunecoScript.PIEL
) -> void:
	persona = p_persona
	_manager = manager
	_velocidad = velocidad
	collision_layer = 0
	collision_mask = 0
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 7.0
	forma.shape = circulo
	add_child(forma)
	_nav = NavigationAgent2D.new()
	_nav.radius = 7.0
	_nav.path_desired_distance = 4.0
	_nav.target_desired_distance = 6.0
	_nav.avoidance_enabled = false   # manifiesto: OFF (Experimental en 4.6)
	add_child(_nav)
	# El muñeco VISIBLE va en su propio nodo, que el manager cuelga de la capa isométrica (ver el
	# comentario de `muneco` arriba). Todo lo que se dibuja va aquí dentro, nada en el cuerpo.
	muneco = Node2D.new()
	muneco.name = "MunecoCiudadano"
	# Muñeco de PIEZAS (2026-07-31): piernas, brazos, torso y cabeza que se mueven al andar. Va
	# ANCLADO POR LA BASE — los pies caen en (0,0) del nodo, que es el punto de la celda donde de
	# verdad está pisando. El ciudadano no lleva gorra: es lo que le distingue del funcionario de
	# un vistazo, incluso a tamaño diminuto.
	# SPRITE 3D PRE-RENDERIZADO (2026-08-04): si hay sprites para el prefijo que le toca a ESTA
	# persona, se usan; si no (render incompleto, o `hay_sprites` da false por lo que sea), cae al
	# muñeco de piezas de siempre — el mismo "sin romper nada" que ya usan los policías cuando falta
	# su render. Los POLICÍAS siguen con el de piezas a propósito, para poder comparar los dos en la
	# misma pantalla.
	var prefijo: String = _prefijo_de(persona)
	if prefijo != &"" and MunecoScript.hay_sprites(prefijo, ALTO_SPRITE):
		muneco.add_child(MunecoScript.construir_sprite(prefijo, ALTO_SPRITE))
	else:
		muneco.add_child(MunecoScript.construir(color, false, piel))
	# BARRA DE PACIENCIA sobre la cabeza (story paciencia-008, rehecha con el feedback del usuario
	# 2026-07-26: *"debe ser algo más intuitivo: que cuando se vacía la barra se vayan"*). Son DOS
	# piezas: un fondo oscuro fijo —el "hueco" de la barra, que dice cuánto cabía— y un relleno que se
	# ENCOGE con la paciencia que queda. Al vaciarse del todo, la persona se marcha: lo que ves es
	# exactamente lo que va a pasar. Sin hover (regla del proyecto).
	_animo_fondo = ColorRect.new()
	_animo_fondo.color = COLOR_BARRA_FONDO
	_animo_fondo.size = Vector2(ANCHO_BARRA, ALTO_BARRA)
	_animo_fondo.position = Vector2(-ANCHO_BARRA * 0.5, -28)
	_animo_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animo_fondo.visible = false
	_animo_fondo.z_index = Z_ROTULO_FLOTANTE   # ninguna pared tapa un dato (ver esa constante)
	muneco.add_child(_animo_fondo)
	_animo = ColorRect.new()
	_animo.size = Vector2(ANCHO_BARRA, ALTO_BARRA)
	_animo.position = Vector2(-ANCHO_BARRA * 0.5, -28)
	_animo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animo.visible = false
	_animo.z_index = Z_ROTULO_FLOTANTE   # ninguna pared tapa un dato (ver esa constante)
	muneco.add_child(_animo)
	# SEÑAL DE PROHIBIDO (story bug 2026-08-03): por encima de la barra de paciencia, bien despegada
	# de la cabeza para que no se confunda con ella. Nace oculta — la conmuta `_actualizar_destino`.
	_icono_bloqueo = IconoProhibidoScript.new()
	_icono_bloqueo.position = Vector2(0.0, -46.0)
	_icono_bloqueo.visible = false
	_icono_bloqueo.z_index = Z_ROTULO_FLOTANTE   # ninguna pared tapa un dato (ver esa constante)
	muneco.add_child(_icono_bloqueo)
	_manager.registrar_muneco(muneco)


## El PREFIJO de sprite de un ciudadano, repartido determinista por su NÚMERO DE TURNO (identidad
## estable de la persona — mismo criterio que `MunecoScript.piel_de`: nunca cambia, tampoco al
## recargar la partida, y nunca por azar; a diferencia de `_prefijo_oficial_de` en `NPCsFlujo`, que
## reparte por NOMBRE porque los ciudadanos no lo tienen, solo un turno). `""` si no hay persona
## (no debería pasar — `configurar` siempre recibe una — pero cae al muñeco de piezas sin reventar).
func _prefijo_de(p_persona: RefCounted) -> String:
	if p_persona == null:
		return ""
	return PREFIJOS_CIVIL[posmod(p_persona.numero_turno, PREFIJOS_CIVIL.size())]


## El muñeco no cuelga de este nodo, así que no se borra solo cuando el ciudadano desaparece: hay
## que llevárselo por delante a mano. `_exit_tree` cubre TODAS las formas de irse (despacho normal,
## carga de partida, cierre del juego) — si esto se hiciera solo en `despachar`, cada F9 dejaría
## la comisaría sembrada de muñecos huérfanos de gente que ya no existe.
func _exit_tree() -> void:
	if muneco != null and is_instance_valid(muneco):
		muneco.queue_free()
		muneco = null


func _physics_process(_delta: float) -> void:
	# Lo PRIMERO y sin condiciones: llevar el muñeco a donde está el cuerpo, ya proyectado. Va
	# antes de cualquier `return` a propósito — el cuerpo se mueve también en frames en los que
	# esta función se corta antes de tiempo (nav aún no lista, persona nula), y si el muñeco no se
	# sincronizara en esos frames se quedaría rezagado a tirones.
	if muneco != null and is_instance_valid(muneco):
		# El PASO (bote + vaivén) lo pone el manager: es la misma cuenta para todo el que ande, y así
		# ciudadanos y funcionarios caminan igual en vez de tener cada uno su propio andar.
		# ¿Sentado? Se marca en el muñeco y la capa visual elige el sprite que toca. Se consulta
		# aquí (una vez por frame y por persona) porque depende del estado lógico, que cambia solo.
		muneco.set_meta(&"sentado", _manager.esta_sentado(self))
		# Mientras le atienden mira al mostrador aunque esté de pie (2026-08-09, "salen de
		# espaldas"): lo aplica `NPCsFlujo.colocar_muneco`, que es quien orienta a todo el que anda.
		muneco.set_meta(&"mirar_al_puesto", _manager.en_frente_del_puesto(self))
		# ORDEN DE DIBUJO EN LA VENTANILLA (2026-08-03): mientras le atienden está en la celda sur,
		# DELANTE del mostrador, y tiene que verse por encima de él (piernas y silla incluidas). Se
		# hace con z_index de estado porque el muñeco no cuelga del contenedor del puesto y no puede
		# usar sus capas — ver `NPCsFlujo.marcar_frente_de_puesto` para el porqué completo. Andando
		# por el mapa vuelve a z 0 y lo ordena el y-sort de siempre.
		_manager.marcar_frente_de_puesto(muneco, _manager.en_frente_del_puesto(self))
		_manager.colocar_muneco(muneco, position)
	if not _nav_lista:
		_nav_lista = true   # a partir de aquí el server ya sincronizó: los targets valen
		return
	if persona == null:
		return
	# Solo al CAMBIAR el estado lógico se recalcula el destino (cero trabajo extra por frame).
	var comodidad: StringName = _manager.comodidad_de(persona)
	if persona.estado != _estado_visto or comodidad != _comodidad_vista:
		_estado_visto = persona.estado
		_comodidad_vista = comodidad
		_version_layout_visto = Construccion.version_layout   # este destino YA es del layout actual
		_actualizar_destino(_manager.destino_de(self))
	elif Construccion.version_layout != _version_layout_visto:
		# 🐛 BUG cazado por el usuario el 2026-08-05 (*"aunque haya una puerta, la gente atraviesa la
		# pared en algunas ocasiones"*): un NPC que YA iba de camino cuando el jugador levanta un muro
		# NUEVO a mitad de esa ruta no se enteraba — el estado lógico no cambia con la obra, así que la
		# rama de arriba nunca se disparaba. `NavigationAgent2D` NO repatea solo porque el
		# `NavigationRegion2D` se re-bakee por debajo (confirmado en el motor,
		# `tests/integration/flujo/flujo_muro_tras_ruta_test.gd`): seguía entregando puntos de la
		# corridor VIEJA, así que el cuerpo atravesaba el muro nuevo en línea recta.
		#
		# `Construccion.version_layout` (contador `static`, sube en cada `_refrescar_visual()` — toda
		# mutación real del layout) es la señal barata de "algo cambió"; leerla es una comparación de
		# enteros, cero coste. Solo cuando sube de verdad se paga la reconsulta cara
		# (`_actualizar_destino` → `hay_camino` → BFS de la rejilla), exactamente el mismo patrón de
		# "barato cada frame, caro solo si hace falta" que ya usa el recheque de bloqueo de abajo.
		_version_layout_visto = Construccion.version_layout
		_actualizar_destino(_destino_deseado)
	_refrescar_animo()
	_refrescar_papel()
	# El paseo escala con el reloj (2×/3× caminan más rápido); en Pausa (mult 0) se congela.
	var mult: float = Tiempo.multiplicador_velocidad
	if mult <= 0.0:
		return
	# SIN CAMINO ⇒ SIN TELETRANSPORTE (petición del usuario 2026-08-03): quieto del todo —ni target
	# de navegación ni `move_and_slide`— hasta que un recheck periódico (NO cada frame: el BFS de
	# `NPCsFlujo.hay_camino` barre la rejilla entera) confirme que ya hay camino. La PACIENCIA sigue
	# corriendo con normalidad mientras tanto (vive en `Paciencia`, ajena a este estado — FL5): un
	# bloqueo prolongado acaba en abandono como cualquier otra espera larga.
	if _bloqueado:
		_frames_bloqueo += 1
		if _frames_bloqueo >= FRAMES_RECHEQUEO_BLOQUEO:
			_frames_bloqueo = 0
			_actualizar_destino(_destino_deseado)   # ¿ya hay puerta? si no, sigue bloqueado
		return
	if _nav.is_navigation_finished():
		if _estado_visto == &"resuelta" or _estado_visto == &"abandonando":
			_manager.despachar(self)   # llegó a la salida → despawn
		return
	# EN CAMINO al puesto el paso es ADAPTATIVO (2ª calibración de la enmienda 2026-07-25): cubre
	# los px que le quedan en el tiempo LÓGICO que le queda, recalculado cada frame → llega a la
	# mesa JUSTO cuando el cronómetro arranca la atención, venga de donde venga y por la ruta que
	# sea (lo cosmético se ajusta a la verdad — FL5, nunca al revés). El resto de trayectos
	# (sentarse, salir) usan la velocidad cosmética fija.
	var velocidad: float = _velocidad
	if _estado_visto == &"llamada":
		velocidad = _velocidad_adaptativa()
	var siguiente: Vector2 = _nav.get_next_path_position()
	velocity = global_position.direction_to(siguiente) * velocidad * mult
	move_and_slide()


## Fija (o rechaza) un nuevo destino según haya camino REAL hasta él — se pregunta a
## `NPCsFlujo.hay_camino` (BFS de `Construccion.distancia_en_celdas`, esquivando muros sin puerta;
## la MISMA verdad que ya usaba el descanso de los funcionarios, `_camino_hasta`). Si no lo hay, el
## NPC se queda BLOQUEADO exactamente donde está: JAMÁS se le pone a `_nav` un target inalcanzable.
##
## Esta es la causa raíz del teletransporte que reportó el usuario 2026-08-03 (*"las personas...
## SALTAN"*): ante un destino sin camino real (una sala amurallada sin puerta), el NavigationServer
## no falla limpio — no hay garantía de que la ruta se quede quieta o corte por el borde más
## cercano, y de ahí salía el salto. Preguntando ANTES, con la rejilla (no con el propio server), se
## evita del todo: o se anda de verdad, o no se mueve ni un píxel.
func _actualizar_destino(destino: Vector2) -> void:
	_destino_deseado = destino
	if _manager.hay_camino(global_position, destino):
		if _bloqueado:
			_bloqueado = false
			_frames_bloqueo = 0
			if _icono_bloqueo != null:
				_icono_bloqueo.visible = false
		_nav.target_position = destino
	else:
		_bloqueado = true
		if _icono_bloqueo != null:
			_icono_bloqueo.visible = true


## px/s (a 1×) para cubrir la distancia restante en los minutos LÓGICOS restantes del camino.
## 3ª calibración (feedback: "la ida esprintaba"): acotada a ±50% del paso normal — el ajuste es
## un matiz, no un sprint; el grueso lo cuadra la lógica (velocidad calibrada + origen entrada).
func _velocidad_adaptativa() -> float:
	var restante_min: float = _manager.camino_restante_min(persona)
	if restante_min <= 0.0:
		return _velocidad * 1.5   # la lógica ya llegó: remata el tramo con paso ligero
	var restante_px: float = global_position.distance_to(_nav.target_position)
	return clampf(
		restante_px * Tiempo.escala_tiempo / restante_min, _velocidad * 0.75, _velocidad * 1.5
	)


## Pinta la barra de paciencia de esta persona. El ANCHO es lo que queda (se vacía a ojo) y el color
## refuerza el tramo (verde → ámbar → rojo). Por DIFF: el nodo solo se toca cuando el ancho o el color
## cambian de verdad. Se oculta en cuanto la llaman: una vez te atienden, tu espera ya no cuenta.
func _refrescar_animo() -> void:
	if _animo == null:
		return
	var animo: StringName = _manager.animo_de(persona)
	if animo == &"":
		if _animo_visto != &"":
			_animo_visto = &""
			_animo.visible = false
			_animo_fondo.visible = false
		return
	var fraccion: float = _manager.fraccion_paciencia(persona)
	var ancho: float = maxf(ANCHO_BARRA * fraccion, 1.0)
	if animo == _animo_visto and is_equal_approx(ancho, _ancho_visto):
		return
	_animo_visto = animo
	_ancho_visto = ancho
	_animo.visible = true
	_animo_fondo.visible = true
	_animo.size = Vector2(ancho, ALTO_BARRA)
	_animo.color = _manager.color_de_animo(animo)


## El papel con el que sale (GDD impresora-documentos-tramite.md, viaje del papel): `persona.
## con_papel` la fija `Flujo._completar_atencion` en el momento de resolver el trámite — aquí solo se
## OBSERVA (FL5) y se cuelga/quita del muñeco por DIFF, mismo criterio que `_refrescar_animo`. El
## despawn (`_exit_tree`) ya se lleva el muñeco entero, papel incluido, así que no hace falta
## quitarlo a mano al despachar.
func _refrescar_papel() -> void:
	if muneco == null or persona == null:
		return
	var con_papel: bool = bool(persona.con_papel)
	if con_papel == _papel_visto:
		return
	_papel_visto = con_papel
	if con_papel:
		muneco.add_child(MunecoScript.papel())
	else:
		var papel: Node = muneco.get_node_or_null("Papel")
		if papel != null:
			papel.queue_free()
