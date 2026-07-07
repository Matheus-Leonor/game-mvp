class_name ObstacleWall
extends StaticBody2D
## Rocha viva: cover estático. Bloqueia movimento e projéteis.

var size := Vector2(300.0, 40.0)

func setup(rect: Rect2) -> void:
	position = rect.position + rect.size / 2.0
	size = rect.size

func _ready() -> void:
	add_to_group("obstacles")
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	shape.shape = rs
	add_child(shape)

func map_rect() -> Rect2:
	return Rect2(global_position - size / 2.0, size)

func map_color() -> Color:
	return Palette.WALL

func _draw() -> void:
	var r := Rect2(-size / 2.0, size)
	draw_rect(r.grow(3.0), Color(Palette.BIO, 0.08))
	draw_rect(r, Palette.WALL)
	draw_rect(r, Color(Palette.BIO, 0.3), false, 2.0)
	# nós orgânicos nas pontas
	var er := minf(size.x, size.y) * 0.5 + 2.0
	var ends: Array = [Vector2(-size.x / 2.0, 0.0), Vector2(size.x / 2.0, 0.0)] \
		if size.x >= size.y else [Vector2(0.0, -size.y / 2.0), Vector2(0.0, size.y / 2.0)]
	for e in ends:
		draw_circle(e, er, Palette.WALL)
		draw_arc(e, er, 0.0, TAU, 20, Color(Palette.BIO, 0.35), 2.0)
