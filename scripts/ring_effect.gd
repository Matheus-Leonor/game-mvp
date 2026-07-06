class_name RingEffect
extends Node2D
## Efeito visual curto: anel que expande e some. Usado no impacto
## das skills em área (R nova, T explosão).

const LIFE := 0.3

var radius := 100.0
var color := Color.WHITE
var t := 0.0

func setup(pos: Vector2, p_radius: float, p_color: Color) -> void:
	position = pos
	radius = p_radius
	color = p_color

func _process(delta: float) -> void:
	t += delta
	if t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var f := t / LIFE
	draw_circle(Vector2.ZERO, radius * f, Color(color, (1.0 - f) * 0.18))
	draw_arc(Vector2.ZERO, radius * (0.4 + 0.6 * f), 0.0, TAU, 48,
		Color(color, (1.0 - f) * 0.8), 3.0)
