class_name Cataclysm
extends Node2D
## Cataclismo do Mago (ref. Xerath/Vel'Koz): marca um círculo no chão que
## DETONA após um delay. Durante o delay, publica a área no ThreatBoard —
## inimigos tentam escapar (por isso o combo é Campo Gravitacional → isto).

const DELAY := 1.0
const RADIUS := 140.0

var damage := 100.0
var t := 0.0

func setup(pos: Vector2, p_damage: float) -> void:
	position = pos
	damage = p_damage

func _physics_process(delta: float) -> void:
	t += delta
	# a marca no chão é uma ameaça que a IA lê (mesmo vocabulário das miras)
	Threats.publish_circle(global_position, RADIUS + 10.0)
	if t >= DELAY:
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if global_position.distance_to(e.global_position) <= RADIUS + e.radius():
				e.take_damage(damage)
		var fx := RingEffect.new()
		fx.setup(global_position, RADIUS, Palette.ARCANE)
		get_parent().add_child(fx)
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var col := Palette.ARCANE
	var f := t / DELAY
	# borda fixa + preenchimento crescendo (telegraph clássico)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 64, Color(col, 0.85), 2.5)
	draw_circle(Vector2.ZERO, RADIUS * f, Color(col, 0.18 + 0.12 * f))
	draw_arc(Vector2.ZERO, RADIUS * f, 0.0, TAU, 48, Color(col, 0.6), 1.5)
	# retículo central
	var blink := 0.5 + 0.5 * absf(sin(t * 18.0))
	draw_line(Vector2(-10.0, 0.0), Vector2(10.0, 0.0), Color(Palette.WHITE, blink), 1.5)
	draw_line(Vector2(0.0, -10.0), Vector2(0.0, 10.0), Color(Palette.WHITE, blink), 1.5)
