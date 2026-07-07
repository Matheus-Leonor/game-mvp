class_name EnergyVein
extends Node2D
## Veia de energia: conduíte orgânico no chão. Ficar sobre ela recarrega
## energia — mas os guardiões SENTEM você através da veia (aggro dentro do
## território mesmo fora do alcance de visão). Recarga em troca de rastro.

const WIDTH := 45.0
const REGEN := 18.0

var points := PackedVector2Array()
var anim := 0.0

func setup(p_points: PackedVector2Array) -> void:
	points = p_points

func _dist_to_path(pos: Vector2) -> float:
	var best := INF
	for i in range(points.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(pos, points[i], points[i + 1])
		best = minf(best, pos.distance_to(closest))
	return best

func _physics_process(delta: float) -> void:
	anim += delta
	var nodes := get_tree().get_nodes_in_group("player")
	if not nodes.is_empty():
		var p := nodes[0] as Player
		if not p.dead and _dist_to_path(p.global_position) <= WIDTH:
			p.gain_energy(REGEN * delta)
			Game.mark_player_on_vein()
	queue_redraw()

func _draw() -> void:
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], Color(Palette.BIO, 0.10), WIDTH * 0.8)
		draw_line(points[i], points[i + 1], Color(Palette.ELECTRO, 0.25), 4.0)
	for p in points:
		draw_circle(p, 6.0, Color(Palette.BIO, 0.4))
	# pulso de energia viajando pela veia
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	if total <= 0.0:
		return
	var d := fposmod(anim * 160.0, total)
	var acc := 0.0
	for i in range(points.size() - 1):
		var seg := points[i].distance_to(points[i + 1])
		if d <= acc + seg and seg > 0.0:
			var pos := points[i].lerp(points[i + 1], (d - acc) / seg)
			draw_circle(pos, 5.0, Color(Palette.ELECTRO, 0.8))
			break
		acc += seg
