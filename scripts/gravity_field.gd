class_name GravityField
extends Node2D
## Campo Gravitacional do Mago (ref. Viktor W): zona no chão que aplica
## lentidão brutal em inimigos dentro dela enquanto durar.

const LIFE := 3.5
const SLOW_MULT := 0.3  # 70% de lentidão
const RADIUS := 130.0

var t := 0.0

func _physics_process(delta: float) -> void:
	t += delta
	if t >= LIFE:
		queue_free()
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if global_position.distance_to(e.global_position) <= RADIUS + e.radius():
			e.apply_slow(SLOW_MULT, 0.25)
	queue_redraw()

func _draw() -> void:
	var col := Palette.ARCANE
	var fade := clampf((LIFE - t) / 0.6, 0.0, 1.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(col, 0.10 * fade))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 64, Color(col, 0.7 * fade), 2.0)
	# anéis convergindo pro centro (sensação de gravidade)
	for i in 3:
		var pr := 1.0 - fposmod(t * 0.7 + i / 3.0, 1.0)
		draw_arc(Vector2.ZERO, RADIUS * pr, 0.0, TAU, 48,
			Color(col, 0.35 * pr * fade), 1.5)
	draw_circle(Vector2.ZERO, 6.0, Color(col, 0.8 * fade))
