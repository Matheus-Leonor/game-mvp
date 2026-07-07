class_name MagePlayer
extends Player
## Classe "MAGO" — poder indireto (categoria, não fantasia: ref.
## Heimerdinger/Viktor/Xerath). Frágil (75 HP) e recurso = FLUXO (barra
## roxa): NÃO regenera em movimento — canaliza do planeta SÓ PARADO
## (~25/s). Filosofia: POSICIONAMENTO — o jogo é criar janelas seguras
## para canalizar, usando as próprias skills.
## AA: orbe arcano — mais lento que a pistola, mas ATRAVESSA inimigos.
## Q Sentinela: torreta autônoma no chão (máx. 2; 10s).
## E Campo Gravitacional: zona de lentidão brutal (70%) no chão.
## R Translocar: BLINK instantâneo (sem trajeto — não é interceptável).
## F Cataclismo: círculo no chão que detona após 1s; a IA LÊ a marca e
##   tenta escapar — o combo é E (prende) → F (detona).

const CHANNEL_REGEN := 25.0
const ORB_CD := 0.6
const ORB_RANGE := 500.0
const ORB_SPEED := 700.0

const SENTINEL_CAST_RANGE := 420.0
const SENTINEL_MAX := 2
const FIELD_CAST_RANGE := 500.0
const BLINK_RANGE := 300.0
const CATA_CAST_RANGE := 600.0

var sentinels: Array = []
var channeling := false

func _ready() -> void:
	super._ready()
	cooldowns = [6.0, 8.0, 7.0, 10.0]
	costs = [30.0, 30.0, 25.0, 40.0]
	passive_regen = 0.0
	max_hp = 75.0
	hp = max_hp

func class_title() -> String:
	return "MAGO"

func resource_color() -> Color:
	return Palette.ARCANE

func aa_damage() -> float:
	return 9.0 + 2.0 * level

func cata_damage() -> float:
	return 90.0 + 10.0 * level

func _do_basic_attack() -> void:
	aa_cd = ORB_CD
	muzzle = 1.0
	var dir := _aim_dir()
	var p := Projectile.new()
	p.setup(self, global_position + dir * (RADIUS + 8.0), dir, aa_damage(),
		ORB_RANGE, 7.0, Palette.ARCANE, ORB_SPEED, "enemies")
	p.pierce = true
	get_parent().add_child(p)

func _cast(slot: int) -> void:
	aim = -1
	if cds[slot] > 0.0 or not can_pay(slot):
		return
	if slot == 0:
		_cast_sentinel()
	elif slot == 1:
		_cast_field()
	elif slot == 2:
		_cast_blink()
	elif slot == 3:
		_cast_cataclysm()
	stats_changed.emit()

func _ground_target(max_range: float) -> Vector2:
	return global_position \
		+ (get_global_mouse_position() - global_position).limit_length(max_range)

## Q — Sentinela: no máximo 2; colocar a terceira substitui a mais antiga.
func _cast_sentinel() -> void:
	cds[0] = cooldowns[0]
	energy -= costs[0]
	sentinels = sentinels.filter(func(s: Object) -> bool: return is_instance_valid(s))
	if sentinels.size() >= SENTINEL_MAX:
		sentinels.pop_front().queue_free()
	var s := Sentinel.new()
	s.setup(_ground_target(SENTINEL_CAST_RANGE), self)
	get_parent().add_child(s)
	sentinels.append(s)

func _cast_field() -> void:
	cds[1] = cooldowns[1]
	energy -= costs[1]
	var f := GravityField.new()
	f.position = _ground_target(FIELD_CAST_RANGE)
	get_parent().add_child(f)

## R — Translocar: teleporte instantâneo (efeito nos dois pontos).
func _cast_blink() -> void:
	cds[2] = cooldowns[2]
	energy -= costs[2]
	var from := global_position
	var target := _ground_target(BLINK_RANGE)
	target.x = clampf(target.x, Game.arena.position.x + RADIUS,
		Game.arena.end.x - RADIUS)
	target.y = clampf(target.y, Game.arena.position.y + RADIUS,
		Game.arena.end.y - RADIUS)
	global_position = target
	dash_left = 0.0
	has_move_target = false
	var fx1 := RingEffect.new()
	fx1.setup(from, RADIUS + 14.0, Palette.ARCANE)
	get_parent().add_child(fx1)
	var fx2 := RingEffect.new()
	fx2.setup(target, RADIUS + 14.0, Palette.ARCANE)
	get_parent().add_child(fx2)

func _cast_cataclysm() -> void:
	cds[3] = cooldowns[3]
	energy -= costs[3]
	var c := Cataclysm.new()
	c.setup(_ground_target(CATA_CAST_RANGE), cata_damage())
	get_parent().add_child(c)

func _class_physics(delta: float) -> void:
	# canalização: o Fluxo só regenera PARADO (nem dash, nem arremesso)
	channeling = velocity.length() < 5.0 and dash_left <= 0.0 \
		and launch_left <= 0.0 and energy < MAX_ENERGY
	if channeling:
		energy = minf(MAX_ENERGY, energy + CHANNEL_REGEN * delta)

func _draw_indicators(mouse: Vector2, adir: Vector2) -> void:
	var col := Palette.ARCANE
	if aim == 0:
		# fantasma da sentinela no ponto + alcance dela
		draw_arc(Vector2.ZERO, SENTINEL_CAST_RANGE, 0.0, TAU, 64, Color(col, 0.3), 1.5)
		var target := mouse.limit_length(SENTINEL_CAST_RANGE)
		var pts := PackedVector2Array()
		for i in 4:
			pts.append(target + Vector2.from_angle(TAU * i / 4.0) * 13.0)
		draw_colored_polygon(pts, Color(col, 0.5))
		draw_arc(target, Sentinel.RANGE, 0.0, TAU, 64, Color(col, 0.25), 1.0)
	elif aim == 1:
		# círculo do campo gravitacional
		draw_arc(Vector2.ZERO, FIELD_CAST_RANGE, 0.0, TAU, 64, Color(col, 0.3), 1.5)
		var target := mouse.limit_length(FIELD_CAST_RANGE)
		draw_circle(target, GravityField.RADIUS, Color(col, 0.14))
		draw_arc(target, GravityField.RADIUS, 0.0, TAU, 48, Color(col, 0.8), 2.0)
	elif aim == 2:
		# marcador do blink
		draw_arc(Vector2.ZERO, BLINK_RANGE, 0.0, TAU, 64, Color(col, 0.35), 1.5)
		var target := mouse.limit_length(BLINK_RANGE)
		draw_arc(target, 14.0, 0.0, TAU, 24, Color(col, 0.9), 2.0)
		draw_line(target + Vector2(-8.0, -8.0), target + Vector2(8.0, 8.0), Color(col, 0.9), 2.0)
		draw_line(target + Vector2(-8.0, 8.0), target + Vector2(8.0, -8.0), Color(col, 0.9), 2.0)
	elif aim == 3:
		# círculo do cataclismo
		draw_arc(Vector2.ZERO, CATA_CAST_RANGE, 0.0, TAU, 64, Color(col, 0.3), 1.5)
		var target := mouse.limit_length(CATA_CAST_RANGE)
		draw_circle(target, Cataclysm.RADIUS, Color(col, 0.14))
		draw_arc(target, Cataclysm.RADIUS, 0.0, TAU, 48, Color(col, 0.8), 2.0)
	# aura de canalização: parado, absorvendo fluxo do planeta
	if channeling:
		var pr := 1.0 - fposmod(Time.get_ticks_msec() / 1000.0, 0.9) / 0.9
		draw_arc(Vector2.ZERO, RADIUS + 4.0 + 22.0 * pr, 0.0, TAU, 32,
			Color(col, 0.45 * (1.0 - pr)), 2.0)
