# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: ¿es divertido y construible el bucle core de la Oficina de Denuncias?
# Date: 2026-07-22
extends CharacterBody2D
## Ciudadano del slice (Escalón 2). Llega → espera su turno en la sala → es llamado al puesto →
## atendido (el trámite avanza con el reloj) → cobra y se va. Tipo: DNI o denuncia.
## Movimiento COSMÉTICO: usar la llegada del navegador para la coreografía es un atajo del slice;
## en Producción el "tiempo de desplazamiento" será lógico (Flujo FL5), no del sprite.

signal se_fue(persona: Node)
signal empezo_atencion(espera_min: float)
signal libera_puesto(persona: Node)   # el trámite terminó → el puesto ya puede llamar al siguiente

enum Estado { A_ESPERA, ESPERANDO, LLAMADA, ATENDIENDO, SALIENDO }

const VEL_BASE: float = 95.0
const RADIO: float = 12.0
const TELEPORT_UMBRAL_MIN: float = 300.0   # salvavidas: si un trayecto se atasca, colocar en el destino

var tipo: StringName = &"dni"

var _duracion_min: float = 12.0
var _color: Color = Color(0.20, 0.45, 0.85)
var _estado: int = Estado.A_ESPERA
var _pos_asiento: Vector2 = Vector2.ZERO
var _pos_puesto: Vector2 = Vector2.ZERO
var _pos_salida: Vector2 = Vector2.ZERO
var _tramite_restante: float = 0.0
var _espera_min: float = 0.0
var _nav: NavigationAgent2D
var _listo: bool = false
var _camino_iniciado: bool = false
var _t_estado: float = 0.0   # min de juego en el trayecto actual (para el salvavidas)

func configurar(p_tipo: StringName, dur: float, col: Color, pos_asiento: Vector2, pos_salida: Vector2) -> void:
	tipo = p_tipo
	_duracion_min = dur
	_tramite_restante = dur
	_color = col
	_pos_asiento = pos_asiento
	_pos_salida = pos_salida

func _ready() -> void:
	_nav = NavigationAgent2D.new()
	_nav.radius = RADIO
	_nav.avoidance_enabled = false          # avoidance Experimental en 4.6 → OFF (ADR-0004)
	_nav.path_desired_distance = 6.0
	_nav.target_desired_distance = 8.0
	add_child(_nav)

	var col := CollisionShape2D.new()
	var forma := CircleShape2D.new()
	forma.radius = RADIO
	col.shape = forma
	add_child(col)
	collision_layer = 2   # capa "personas"
	collision_mask = 1    # chocan con el ENTORNO (paredes/objetos = capa 1) pero NO entre sí → se atraviesan

	queue_redraw()
	await get_tree().physics_frame          # gotcha 4.x: sincroniza en el 1er physics frame
	_nav.target_position = _pos_asiento
	_listo = true

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIO, _color)

func _physics_process(_delta: float) -> void:
	if not _listo:
		return
	match _estado:
		Estado.A_ESPERA:
			_espera_min += Tiempo.delta_juego
			_avanzar_movimiento()
			if _camino_iniciado and _nav.is_navigation_finished():
				_estado = Estado.ESPERANDO
		Estado.ESPERANDO:
			velocity = Vector2.ZERO
			_espera_min += Tiempo.delta_juego
		Estado.LLAMADA:
			_espera_min += Tiempo.delta_juego
			_t_estado += Tiempo.delta_juego
			_avanzar_movimiento()
			if (_camino_iniciado and _nav.is_navigation_finished()) or _t_estado > TELEPORT_UMBRAL_MIN:
				global_position = _pos_puesto   # snap exacto al puesto (o rescate si se atascó)
				_estado = Estado.ATENDIENDO
				empezo_atencion.emit(_espera_min)
		Estado.ATENDIENDO:
			velocity = Vector2.ZERO
			_tramite_restante -= Tiempo.delta_juego
			if _tramite_restante <= 0.0:
				EventBus.tramite_completado.emit(tipo, null)
				libera_puesto.emit(self)   # puesto libre YA (el siguiente entra mientras yo camino a la salida)
				_estado = Estado.SALIENDO
				_camino_iniciado = false
				_t_estado = 0.0
				_nav.target_position = _pos_salida
		Estado.SALIENDO:
			_t_estado += Tiempo.delta_juego
			_avanzar_movimiento()
			if (_camino_iniciado and _nav.is_navigation_finished()) or _t_estado > TELEPORT_UMBRAL_MIN:
				se_fue.emit(self)
				queue_free()

## Lo llama el Mundo cuando el puesto queda libre y esta persona es la primera de la cola.
func llamar_al_puesto(pos_puesto: Vector2) -> void:
	if _estado == Estado.ESPERANDO or _estado == Estado.A_ESPERA:
		_pos_puesto = pos_puesto
		_estado = Estado.LLAMADA
		_camino_iniciado = false
		_t_estado = 0.0
		_nav.target_position = _pos_puesto

## Reubica a la persona en su nueva posición de la fila (la cola avanzó). Solo si aún espera.
func ir_a_espera(pos: Vector2) -> void:
	_pos_asiento = pos
	if _estado == Estado.ESPERANDO or _estado == Estado.A_ESPERA:
		_estado = Estado.A_ESPERA
		_camino_iniciado = false
		_t_estado = 0.0
		if _listo:
			_nav.target_position = pos

func _avanzar_movimiento() -> void:
	if Tiempo.esta_en_pausa() or _nav.is_navigation_finished():
		velocity = Vector2.ZERO
		return
	_camino_iniciado = true
	var siguiente: Vector2 = _nav.get_next_path_position()
	var dir: Vector2 = global_position.direction_to(siguiente)
	velocity = dir * VEL_BASE * float(Tiempo.get_velocidad())
	move_and_slide()
