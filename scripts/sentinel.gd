class_name Sentinel
extends Node2D
## Sentinela do Mago (ref. Heimerdinger Q): torreta autônoma que atira no
## inimigo mais próximo dentro do alcance. Vida limitada por DURAÇÃO
## (inimigos não a atacam na v1). Máximo de 2 ativas por mago.

const LIFE := 10.0
const RANGE := 300.0
const SHOOT_CD := 0.8
const SHOT_SPEED := 800.0

var owner_player: Player
var life := LIFE
var shoot_cd := 0.0
var anim := 0.0
var facing := Vector2.RIGHT

func setup(pos: Vector2, p_owner: Player) -> void:
	position = pos
	owner_player = p_owner

func damage() -> float:
	if owner_player != null and is_instance_valid(owner_player):
		return 8.0 + 2.0 * owner_player.level
	return 8.0

func _physics_process(delta: float) -> void:
	anim += delta
	shoot_cd = maxf(0.0, shoot_cd - delta)
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	# alvo: inimigo mais próximo no alcance
	var best: Enemy = null
	var best_d := RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best != null:
		facing = (best.global_position - global_position).normalized()
		if shoot_cd <= 0.0:
			shoot_cd = SHOOT_CD
			var p := Projectile.new()
			p.setup(self, global_position + facing * 14.0, facing, damage(),
				RANGE + 60.0, 4.0, Palette.ARCANE, SHOT_SPEED, "enemies")
			get_parent().add_child(p)
	queue_redraw()

func _draw() -> void:
	var col := Palette.ARCANE
	var fade := clampf(life / 2.0, 0.0, 1.0)  # some suave no fim
	# alcance sutil
	draw_arc(Vector2.ZERO, RANGE, 0.0, TAU, 64, Color(col, 0.08 * fade), 1.0)
	# corpo: losango arcano girando devagar
	var pts := PackedVector2Array()
	for i in 4:
		pts.append(Vector2.from_angle(anim * 0.8 + TAU * i / 4.0) * 13.0)
	draw_circle(Vector2.ZERO, 16.0, Color(col, 0.15 * fade))
	draw_colored_polygon(pts, Color(col, fade))
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 20, Color(0.0, 0.0, 0.0, 0.3 * fade), 1.5)
	# "cano" apontando pro alvo
	draw_line(facing * 8.0, facing * 18.0, Color(Palette.WHITE, fade), 2.5)
	# arco de duração restante
	draw_arc(Vector2.ZERO, 20.0, -PI / 2.0, -PI / 2.0 + TAU * (life / LIFE), 32,
		Color(col, 0.6 * fade), 2.0)
