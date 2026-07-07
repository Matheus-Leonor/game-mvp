extends Node
## Autoload "Threats" — quadro de ameaças (percepção compartilhada da IA).
##
## ARQUITETURA: inimigos NUNCA leem "a skill X da classe Y". Skills publicam
## formas de ameaça genéricas (o spell indicator, legível por máquina) a cada
## frame de mira, com TTL curto; inimigos leem só a geometria. O vocabulário
## é fechado (linha, círculo-no-chão) — classes novas emitem as mesmas
## primitivas e todo inimigo existente já sabe reagir. A RESPOSTA a uma
## ameaça é de cada inimigo (esquivar, escudar, avançar); a percepção é
## compartilhada.

var _lines := []
var _circles := []

func publish_line(origin: Vector2, dir: Vector2, length: float, width: float) -> void:
	_lines.append({"o": origin, "d": dir, "len": length, "w": width,
		"f": Engine.get_physics_frames()})

func publish_circle(center: Vector2, radius: float) -> void:
	_circles.append({"c": center, "r": radius, "f": Engine.get_physics_frames()})

func _fresh(e: Dictionary) -> bool:
	return Engine.get_physics_frames() - e["f"] <= 2

func _physics_process(_delta: float) -> void:
	_lines = _lines.filter(_fresh)
	_circles = _circles.filter(_fresh)

## Direção de fuga para sair das ameaças ativas, ou ZERO se seguro.
func dodge_dir_for(pos: Vector2, margin: float) -> Vector2:
	for t in _lines:
		if not _fresh(t):
			continue
		var rel: Vector2 = pos - t["o"]
		var along: float = rel.dot(t["d"])
		if along < -margin or along > t["len"] + margin:
			continue
		var lateral: float = (t["d"] as Vector2).orthogonal().dot(rel)
		if absf(lateral) <= t["w"] * 0.5 + margin:
			var side := signf(lateral)
			if side == 0.0:
				side = 1.0 if randf() < 0.5 else -1.0
			return (t["d"] as Vector2).orthogonal() * side
	for t in _circles:
		if not _fresh(t):
			continue
		var rel: Vector2 = pos - t["c"]
		if rel.length() <= t["r"] + margin:
			return rel.normalized() if rel.length() > 0.01 else Vector2.RIGHT
	return Vector2.ZERO
