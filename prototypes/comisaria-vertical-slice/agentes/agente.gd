# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: ¿es divertido y construible el bucle core de la Oficina de Denuncias?
# Date: 2026-07-22
extends Node2D
## Agente (funcionario). Se asigna a un puesto (se coloca en el lado del funcionario) o queda
## DISPONIBLE (en la zona de personal). Un puesto sin agente está cerrado. Cobra salario al día.

var puesto = null            # puesto asignado (o null = disponible)
var _color: Color = Color(0.20, 0.50, 0.35)
var _sel: bool = false

func configurar(color: Color) -> void:
	_color = color
	z_index = 1              # se dibuja por encima de mesas y ciudadanos
	queue_redraw()

func set_sel(s: bool) -> void:
	_sel = s
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 11.0, _color)
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.4), false, 1.5)
	if _sel:
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 28, Color(1, 1, 1, 0.9), 2.5)
