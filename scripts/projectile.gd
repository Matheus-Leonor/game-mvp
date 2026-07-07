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
var streak := false  # true = visual de feixe laser curto em vez de bolinha
var slow_mult := 1.0  # < 1.0 aplica lentidão no alvo atingido
var slow_time := 0.0
var pull_to: Node2D = null  # se definido, PUXA o alvo em direção a este nó
var pull_speed := 1100.0
var pierce := false  # true = atravessa alvos (acerta cada um só uma vez)
var _hit: Array = []
var anim := 0.0

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
	anim += delta
	var step := speed * delta
	position += dir * step
	travel_left -= step
	if travel_left <= 0.0:
		queue_free()
	queue_redraw()

## Faísca no ponto de impacto (parede ou alvo).
func _impact() -> void:
	var fx := RingEffect.new()
	fx.setup(global_position, radius * 3.0 + 6.0, color)
	get_parent().add_child(fx)

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body is StaticBody2D:
		_impact()
		queue_free()
		return
	if target_group != "" and not body.is_in_group(target_group):
		return
	if pierce and body in _hit:
		return
	if slow_time > 0.0 and body.has_method("apply_slow"):
		body.apply_slow(slow_mult, slow_time)
	if pull_to != null and is_instance_valid(pull_to) and body.has_method("apply_knockback"):
		body.apply_knockback(
			(pull_to.global_position - body.global_position).normalized(), pull_speed)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	_impact()
	if pierce:
		_hit.append(body)
	else:
		queue_free()

func _draw() -> void:
	if streak:
		# feixe laser: corpo afunilado + halo + núcleo quente, com cintilação
		var flicker := 0.85 + 0.15 * sin(anim * 40.0)
		var w := radius * 1.6 * flicker
		var perp := dir.orthogonal()
		draw_line(dir * -24.0, dir * 8.0, Color(color, 0.22), w * 2.8)
		draw_colored_polygon(PackedVector2Array([
			dir * 8.0,
			dir * 2.0 + perp * w * 0.55,
			dir * -24.0,
			dir * 2.0 - perp * w * 0.55,
		]), color)
		draw_line(dir * -16.0, dir * 6.0, Color(1.0, 1.0, 1.0, 0.95), maxf(w * 0.35, 1.5))
		draw_circle(dir * 8.0, w * 0.55, Color.WHITE)
	else:
		draw_circle(Vector2.ZERO, radius + 4.0, Color(color, 0.25))
		draw_circle(Vector2.ZERO, radius, color)
		# rastro
		draw_circle(dir * -12.0, radius * 0.6, Color(color, 0.4))
		draw_circle(dir * -20.0, radius * 0.35, Color(color, 0.2))
