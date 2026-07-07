class_name BeamEffect
extends Node2D
## Raio laser instantâneo (hitscan) que desenha e some rápido.
## Usado pelo canhão de laser (E). O dano é aplicado por quem cria o beam;
## isto é só o visual.

const LIFE := 0.28

var dir := Vector2.RIGHT
var length := 650.0
var width := 14.0
var color := Color.WHITE
var t := 0.0

func setup(from: Vector2, p_dir: Vector2, p_length: float, p_width: float,
		p_color: Color) -> void:
	position = from
	dir = p_dir
	length = p_length
	width = p_width
	color = p_color

func _process(delta: float) -> void:
	t += delta
	if t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var f := 1.0 - t / LIFE
	var endp := dir * length
	draw_line(Vector2.ZERO, endp, Color(color, f * 0.35), width * f + 6.0)
	draw_line(Vector2.ZERO, endp, Color(color, f), width * f + 1.0)
	draw_line(Vector2.ZERO, endp, Color(Color.WHITE, f * 0.9), maxf(width * f * 0.35, 1.0))
	draw_circle(Vector2.ZERO, 7.0 * f + 2.0, Color(color, f))
	draw_circle(endp, 5.0 * f + 1.0, Color(color, f * 0.7))
