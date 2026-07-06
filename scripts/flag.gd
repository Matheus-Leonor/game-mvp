class_name Flag
extends Area2D
## Bandeira capturável: ficar dentro do anel por CAPTURE_TIME captura.
## Sair do anel faz o progresso decair. Guardada por um camp de inimigos.

const CAPTURE_RADIUS := 90.0
const CAPTURE_TIME := 2.0

var captured := false
var progress := 0.0
var player_inside := false
var t := 0.0

func _ready() -> void:
	add_to_group("flags")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = CAPTURE_RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		player_inside = true

func _on_body_exited(body: Node) -> void:
	if body is Player:
		player_inside = false

func _player_alive() -> bool:
	var nodes := get_tree().get_nodes_in_group("player")
	return not nodes.is_empty() and not (nodes[0] as Player).dead

func _process(delta: float) -> void:
	t += delta
	if not captured:
		if player_inside and _player_alive():
			progress += delta / CAPTURE_TIME
			if progress >= 1.0:
				captured = true
				Game.capture_flag()
		else:
			progress = maxf(0.0, progress - delta / CAPTURE_TIME)
	queue_redraw()

func _draw() -> void:
	var col := Palette.FLAG if not captured else Color(Palette.FLAG, 0.3)
	# anel de captura
	draw_arc(Vector2.ZERO, CAPTURE_RADIUS, 0.0, TAU, 64, Color(col, 0.5), 2.0)
	if not captured:
		# pulso convidativo
		var pr := fposmod(t, 2.5) / 2.5
		draw_arc(Vector2.ZERO, CAPTURE_RADIUS * pr, 0.0, TAU, 48,
			Color(col, (1.0 - pr) * 0.25), 2.0)
		if progress > 0.0:
			draw_arc(Vector2.ZERO, CAPTURE_RADIUS - 7.0, -PI / 2.0,
				-PI / 2.0 + TAU * progress, 64, Palette.WHITE, 3.0)
	# mastro + bandeira tremulando
	draw_circle(Vector2(0.0, 16.0), 5.0, Color(col, 0.6))
	draw_line(Vector2(0.0, 16.0), Vector2(0.0, -26.0), col, 3.0)
	var wave := sin(t * 3.0) * 3.0
	var pts := PackedVector2Array([
		Vector2(0.0, -26.0),
		Vector2(26.0 + wave, -18.0),
		Vector2(0.0, -10.0),
	])
	draw_colored_polygon(pts, col)
