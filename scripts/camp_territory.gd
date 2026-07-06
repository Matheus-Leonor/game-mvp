class_name CampTerritory
extends Node2D
## Círculo tracejado que mostra o território de um camp: dentro dele os
## inimigos perseguem; fora, voltam para casa. Cor = tier do camp.

var radius := 480.0
var color := Color.WHITE

func setup(pos: Vector2, p_radius: float, p_color: Color) -> void:
	position = pos
	radius = p_radius
	color = p_color

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(color, 0.03))
	var segs := 48
	for i in segs:
		if i % 2 == 0:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 0.7) / segs
			draw_arc(Vector2.ZERO, radius, a0, a1, 4, Color(color, 0.3), 1.5)
