class_name LaunchPad
extends Area2D
## Arremessador orgânico: pisou, é lançado na direção da seta — o voo
## ignora colisões (passa por CIMA dos muros). Cooldown por uso.

const RADIUS := 26.0
const DIST := 340.0
const CD := 4.0

var dir := Vector2.RIGHT
var cd := 0.0
var anim := 0.0

func setup(pos: Vector2, p_dir: Vector2) -> void:
	position = pos
	dir = p_dir.normalized()

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	anim += delta
	cd = maxf(0.0, cd - delta)
	if cd <= 0.0:
		for body in get_overlapping_bodies():
			if body is Player and not (body as Player).dead:
				cd = CD
				(body as Player).launch(dir, DIST)
				break
	queue_redraw()

func _draw() -> void:
	var col := Palette.BIO if cd <= 0.0 else Color(Palette.BIO, 0.25)
	draw_circle(Vector2.ZERO, RADIUS, Color(col, 0.15))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, col, 2.0)
	if cd <= 0.0:
		# pulso convidativo
		var pr := fposmod(anim, 1.4) / 1.4
		draw_arc(Vector2.ZERO, RADIUS * pr, 0.0, TAU, 24, Color(col, (1.0 - pr) * 0.5), 2.0)
	# seta da direção do arremesso
	var tip := dir * (RADIUS - 6.0)
	var perp := dir.orthogonal() * 7.0
	draw_colored_polygon(PackedVector2Array([tip, -tip * 0.3 + perp, -tip * 0.3 - perp]), col)
