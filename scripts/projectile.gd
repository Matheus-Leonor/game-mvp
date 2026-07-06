class_name Projectile
extends Area2D
## Projétil em linha reta. Paredes o destroem; corpos fora de target_group
## são atravessados (ex.: tiro inimigo passa por outros inimigos).
## Assume que o pai (Main) está na origem.

var shooter: Node2D
var dir := Vector2.RIGHT
var damage := 20.0
var travel_left := 700.0
var radius := 7.0
var color := Palette.PLAYER
var speed := 950.0
var target_group := ""  # vazio = acerta qualquer corpo com take_damage

func setup(from: Node2D, pos: Vector2, direction: Vector2, dmg: float, max_range: float,
		p_radius := 7.0, p_color := Palette.PLAYER, p_speed := 950.0,
		p_target_group := "") -> void:
	shooter = from
	position = pos
	dir = direction
	damage = dmg
	travel_left = max_range
	radius = p_radius
	color = p_color
	speed = p_speed
	target_group = p_target_group

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var step := speed * delta
	position += dir * step
	travel_left -= step
	if travel_left <= 0.0:
		queue_free()
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body is StaticBody2D:
		queue_free()
		return
	if target_group != "" and not body.is_in_group(target_group):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 4.0, Color(color, 0.25))
	draw_circle(Vector2.ZERO, radius, color)
	# rastro
	draw_circle(dir * -12.0, radius * 0.6, Color(color, 0.4))
	draw_circle(dir * -20.0, radius * 0.35, Color(color, 0.2))
