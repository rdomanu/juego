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


## Monta el cuerpo (fantasma: sin capas de colisión — sin avoidance los NPCs se atraviesan, MVP),
## el agente de navegación y el "muñeco" placeholder con el color de su servicio.
func configurar(p_persona: RefCounted, manager: Node2D, velocidad: float, color: Color) -> void:
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
	# Muñeco mínimo (torso + cabeza). Todo Control decorativo del mundo IGNORA el ratón (gotcha
	# registrado: si no, se traga los clics del modo construcción).
	var torso := ColorRect.new()
	torso.color = color
	torso.size = Vector2(12, 16)
	torso.position = Vector2(-6, -8)
	torso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(torso)
	var cabeza := ColorRect.new()
	cabeza.color = color.lightened(0.35)
	cabeza.size = Vector2(8, 6)
	cabeza.position = Vector2(-4, -14)
	cabeza.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cabeza)
	# BARRA DE PACIENCIA sobre la cabeza (story paciencia-008, rehecha con el feedback del usuario
	# 2026-07-26: *"debe ser algo más intuitivo: que cuando se vacía la barra se vayan"*). Son DOS
	# piezas: un fondo oscuro fijo —el "hueco" de la barra, que dice cuánto cabía— y un relleno que se
	# ENCOGE con la paciencia que queda. Al vaciarse del todo, la persona se marcha: lo que ves es
	# exactamente lo que va a pasar. Sin hover (regla del proyecto).
	_animo_fondo = ColorRect.new()
	_animo_fondo.color = COLOR_BARRA_FONDO
	_animo_fondo.size = Vector2(ANCHO_BARRA, ALTO_BARRA)
	_animo_fondo.position = Vector2(-ANCHO_BARRA * 0.5, -20)
	_animo_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animo_fondo.visible = false
	add_child(_animo_fondo)
	_animo = ColorRect.new()
	_animo.size = Vector2(ANCHO_BARRA, ALTO_BARRA)
	_animo.position = Vector2(-ANCHO_BARRA * 0.5, -20)
	_animo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animo.visible = false
	add_child(_animo)


func _physics_process(_delta: float) -> void:
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
		_nav.target_position = _manager.destino_de(self)
	_refrescar_animo()
	# El paseo escala con el reloj (2×/3× caminan más rápido); en Pausa (mult 0) se congela.
	var mult: float = Tiempo.multiplicador_velocidad
	if mult <= 0.0:
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
