class_name BreathingWall
extends StaticBody2D
## Muro VIVO que respira: recolhe (rota aberta) e cresce de volta (rota
## fechada) em ciclos. O fechamento é telegrafado: as pontas crescem
## piscando por WARN_TIME antes de solidificar — e o muro NUNCA fecha em
## cima do jogador (espera ele sair). Timing de rota é mecânica.

enum WState { OPEN, CLOSING, CLOSED }

const OPEN_TIME := 4.5
const WARN_TIME := 1.2
const CLOSED_TIME := 6.0

var size := Vector2(400.0, 40.0)
var state: WState = WState.OPEN
var t := 0.0
var anim := 0.0
var shape: CollisionShape2D

func setup(rect: Rect2) -> void:
	position = rect.position + rect.size / 2.0
	size = rect.size

func _ready() -> void:
	add_to_group("obstacles")
	shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	shape.shape = rs
	shape.disabled = true
	add_child(shape)
	t = randf_range(0.0, OPEN_TIME)  # dessincroniza os muros entre si

func map_rect() -> Rect2:
	return Rect2(global_position - size / 2.0, size)

func map_color() -> Color:
	return Palette.BIO if state == WState.CLOSED else Color(Palette.BIO, 0.3)

func _player_overlaps() -> bool:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return false
	var p := nodes[0] as Player
	var half := size / 2.0 + Vector2.ONE * (Player.RADIUS + 6.0)
	var rel := p.global_position - global_position
	return absf(rel.x) <= half.x and absf(rel.y) <= half.y

func _physics_process(delta: float) -> void:
	anim += delta
	t += delta
	if state == WState.OPEN and t >= OPEN_TIME:
		state = WState.CLOSING
		t = 0.0
	elif state == WState.CLOSING and t >= WARN_TIME:
		if _player_overlaps():
			t = WARN_TIME  # não esmaga o jogador: segura até ele sair
		else:
			state = WState.CLOSED
			t = 0.0
			shape.set_deferred("disabled", false)
	elif state == WState.CLOSED and t >= CLOSED_TIME:
		state = WState.OPEN
		t = 0.0
		shape.set_deferred("disabled", true)
	queue_redraw()

func _draw() -> void:
	var r := Rect2(-size / 2.0, size)
	var horizontal := size.x >= size.y
	var pulse := 0.5 + 0.5 * sin(anim * 3.0)
	if state == WState.CLOSED:
		draw_rect(r.grow(3.0), Color(Palette.BIO, 0.10 + 0.06 * pulse))
		draw_rect(r, Palette.WALL)
		draw_rect(r, Color(Palette.BIO, 0.5 + 0.2 * pulse), false, 2.0)
		# nervura central viva
		if horizontal:
			draw_line(Vector2(-size.x / 2.0 + 8.0, 0.0), Vector2(size.x / 2.0 - 8.0, 0.0),
				Color(Palette.BIO, 0.35), 2.0)
		else:
			draw_line(Vector2(0.0, -size.y / 2.0 + 8.0), Vector2(0.0, size.y / 2.0 - 8.0),
				Color(Palette.BIO, 0.35), 2.0)
	elif state == WState.CLOSING:
		# telegraph: cresce das pontas, piscando
		var f := minf(t / WARN_TIME, 1.0)
		var blink := 0.35 + 0.45 * absf(sin(anim * 12.0))
		draw_rect(r, Color(Palette.BIO, 0.12), false, 1.5)
		if horizontal:
			var grow := size.x / 2.0 * f
			draw_rect(Rect2(-size.x / 2.0, -size.y / 2.0, grow, size.y), Color(Palette.BIO, blink))
			draw_rect(Rect2(size.x / 2.0 - grow, -size.y / 2.0, grow, size.y), Color(Palette.BIO, blink))
		else:
			var grow := size.y / 2.0 * f
			draw_rect(Rect2(-size.x / 2.0, -size.y / 2.0, size.x, grow), Color(Palette.BIO, blink))
			draw_rect(Rect2(-size.x / 2.0, size.y / 2.0 - grow, size.x, grow), Color(Palette.BIO, blink))
	else:
		# aberto: raízes nas pontas + pontilhado de onde vai fechar
		var dots := 14
		for i in dots:
			var ft := (i + 0.5) / float(dots)
			var p := Vector2(lerpf(-size.x / 2.0, size.x / 2.0, ft), 0.0) if horizontal \
				else Vector2(0.0, lerpf(-size.y / 2.0, size.y / 2.0, ft))
			draw_circle(p, 2.0, Color(Palette.BIO, 0.25))
		var er := minf(size.x, size.y) * 0.5 + 2.0
		var ends: Array = [Vector2(-size.x / 2.0, 0.0), Vector2(size.x / 2.0, 0.0)] \
			if horizontal else [Vector2(0.0, -size.y / 2.0), Vector2(0.0, size.y / 2.0)]
		for e in ends:
			draw_circle(e, er, Color(Palette.BIO, 0.45))
