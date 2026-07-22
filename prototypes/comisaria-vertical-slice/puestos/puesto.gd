# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: ¿es divertido y construible el bucle core de la Oficina de Denuncias?
# Date: 2026-07-22
extends Node2D
## Puesto (ventanilla/mesa). Atiende a UNA persona a la vez. Tiene ORIENTACIÓN: un lado del
## FUNCIONARIO (detrás, donde irá el agente en la entrega D) y un lado del CIUDADANO (el frente,
## donde se coloca quien es atendido). Escalón 3a: siempre "abierto" (en 3b requerirá agente).

const ANCHO: float = 68.0
const ALTO: float = 44.0
const DIST_ATENCION: float = 42.0
# Dirección del frente (lado ciudadano) según orientación: 0=abajo, 1=derecha, 2=arriba, 3=izquierda.
const DIRS := [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)]

var orientacion: int = 0
var agente = null                   # el funcionario asignado (null = puesto CERRADO, no atiende)
var _persona_actual: Node = null

func _ready() -> void:
	queue_redraw()

func dir_frente() -> Vector2:
	return DIRS[orientacion]

## Punto donde se coloca el ciudadano atendido (en el lado del ciudadano).
func pos_atencion() -> Vector2:
	return global_position + dir_frente() * DIST_ATENCION

## Punto detrás de la mesa (lado del funcionario), donde se coloca el agente.
func pos_funcionario() -> Vector2:
	return global_position - dir_frente() * 20.0

func _draw() -> void:
	var f: Vector2 = dir_frente()
	var horizontal: bool = (orientacion % 2 == 1)
	var w: float = ALTO if horizontal else ANCHO
	var h: float = ANCHO if horizontal else ALTO
	var col_mesa: Color = Color(0.86, 0.74, 0.30) if agente != null else Color(0.55, 0.55, 0.57)
	draw_rect(Rect2(Vector2(-w, -h) * 0.5, Vector2(w, h)), col_mesa)
	# lado FUNCIONARIO (detrás, -f): marca azul (aquí irá el agente)
	draw_circle(-f * 20.0, 9.0, Color(0.15, 0.32, 0.58))
	# lado CIUDADANO (frente, +f): dónde se atiende (rojo si ocupado)
	var col_frente: Color = Color(0.90, 0.30, 0.30) if _persona_actual != null else Color(0.85, 0.86, 0.90)
	draw_circle(f * DIST_ATENCION, 6.0, col_frente)

func esta_disponible() -> bool:
	return agente != null and _persona_actual == null

func asignar_persona(persona: Node) -> void:
	_persona_actual = persona
	persona.llamar_al_puesto(pos_atencion())
	queue_redraw()

func atiende_a(persona: Node) -> bool:
	return _persona_actual == persona

func liberar() -> void:
	_persona_actual = null
	queue_redraw()
