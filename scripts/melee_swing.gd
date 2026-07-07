class_name MeleeSwing
extends Node2D
## ARMA CORPO A CORPO GENÉRICA: um golpe em arco (leque) na direção dada.
## Aplica dano instantâneo a alvos do grupo dentro do alcance/ângulo e
## desenha o rastro do corte varrendo. Reutilizável por player e inimigos —
## quem muda é o dano, alcance, arco e cor.

const LIFE := 0.22

var dir := Vector2.RIGHT
var reach := 70.0
var arc := 2.0  # abertura do leque, em radianos
var color := Color.WHITE
var t := 0.0
var hits := 0
var kills := 0

## Só o visual do corte (para golpes com dano customizado, ex.: execução).
func show_arc(pos: Vector2, p_dir: Vector2, p_reach: float, p_arc: float,
		p_color: Color) -> void:
	position = pos
	dir = p_dir
	reach = p_reach
	arc = p_arc
	color = p_color

## Executa o golpe: posiciona, causa dano e inicia a animação do corte.
## Depois da chamada, `hits`/`kills` dizem o que o golpe acertou/abateu.
func strike(from: Node2D, pos: Vector2, p_dir: Vector2, p_reach: float, p_arc: float,
		damage: float, target_group: String, p_color: Color) -> void:
	show_arc(pos, p_dir, p_reach, p_arc, p_color)
	for node in from.get_tree().get_nodes_in_group(target_group):
		if node == from or not node.has_method("take_damage"):
			continue
		var body := node as Node2D
		var rel := body.global_position - pos
		if rel.length() <= p_reach + 16.0 \
				and absf(dir.angle_to(rel)) <= p_arc * 0.5 + 0.2:
			body.take_damage(damage)
			hits += 1
			if body.get("hp") != null and body.get("hp") <= 0.0:
				kills += 1

func _process(delta: float) -> void:
	t += delta
	if t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var f := t / LIFE
	var a0 := dir.angle() - arc * 0.5
	var sweep := a0 + arc * minf(f * 1.6, 1.0)
	# leque translúcido + lâmina varrendo
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 13:
		pts.append(Vector2.from_angle(lerpf(a0, a0 + arc, i / 12.0)) * reach)
	draw_colored_polygon(pts, Color(color, (1.0 - f) * 0.12))
	draw_arc(Vector2.ZERO, reach * (0.85 + 0.15 * f), a0, sweep, 24,
		Color(color, (1.0 - f) * 0.9), 4.0)
	draw_arc(Vector2.ZERO, reach * 0.7, a0, sweep, 20,
		Color(1.0, 1.0, 1.0, (1.0 - f) * 0.5), 2.0)
