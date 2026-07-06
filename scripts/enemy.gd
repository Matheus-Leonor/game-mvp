class_name Enemy
extends CharacterBody2D
## Inimigo de camp (guarda uma bandeira). Três tiers de dificuldade:
## tier 1 = círculo âmbar, tier 2 = losango laranja, tier 3 = hexágono magenta.
## Melee = forma preenchida; atirador (is_ranged) = forma vazada, mantém
## distância e dispara projéteis.
## Regras de território (círculo tracejado desenhado por CampTerritory):
## perseguem enquanto o jogador está no território; fora dele (ou se o
## próprio inimigo sair), voltam devagar para casa SEM cura instantânea —
## regeneram aos poucos apenas parados no camp. Levar dano re-agra se o
## jogador estiver no território.

enum State { IDLE, CHASE, RETURN }

const TIER_HP: Array[float] = [70.0, 130.0, 220.0]
const TIER_DMG: Array[float] = [8.0, 14.0, 22.0]
const TIER_SPEED: Array[float] = [190.0, 210.0, 230.0]
const TIER_RADIUS: Array[float] = [13.0, 16.0, 20.0]
const TIER_XP: Array[float] = [20.0, 38.0, 65.0]

const TERRITORY := 480.0
const TERRITORY_MARGIN := 60.0
const AGGRO_RANGE := 300.0
const ATTACK_CD := 0.9
const SHOOT_RANGE := 330.0
const SHOOT_CD := 1.6
const SHOT_SPEED := 550.0
const SHOT_RANGE := 420.0
const RETURN_SPEED_MULT := 0.75
const HOME_REGEN := 0.04  # fração do HP máx por segundo, parado no camp

var tier := 1
var is_ranged := false
var camp_center := Vector2.ZERO  # definido pelo Main antes do add_child
var home := Vector2.ZERO
var state: State = State.IDLE
var max_hp := 50.0
var hp := 50.0
var attack_cd := 0.0
var shoot_cd := 0.0
var flash := 0.0
## Para onde aponta (bolinha de rosto): alvo quando caça, casa quando volta.
var facing := Vector2.RIGHT

func _init(p_tier: int = 1) -> void:
	tier = clampi(p_tier, 1, 3)

func _ready() -> void:
	add_to_group("enemies")
	home = position
	if camp_center == Vector2.ZERO:
		camp_center = position
	max_hp = TIER_HP[tier - 1]
	hp = max_hp
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius()
	shape.shape = circle
	add_child(shape)

func radius() -> float:
	return TIER_RADIUS[tier - 1]

func base_color() -> Color:
	if tier == 1:
		return Palette.ENEMY_T1
	elif tier == 2:
		return Palette.ENEMY_T2
	return Palette.ENEMY_T3

func _get_player() -> Player:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Player

func _player_in_territory(player: Player) -> bool:
	return player != null and not player.dead \
		and camp_center.distance_to(player.global_position) <= TERRITORY + TERRITORY_MARGIN

func _physics_process(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	shoot_cd = maxf(0.0, shoot_cd - delta)
	flash = maxf(0.0, flash - delta * 5.0)
	var player := _get_player()

	if state == State.IDLE:
		velocity = Vector2.ZERO
		hp = minf(max_hp, hp + max_hp * HOME_REGEN * delta)
		if _player_in_territory(player) \
				and global_position.distance_to(player.global_position) < AGGRO_RANGE:
			state = State.CHASE
	elif state == State.CHASE:
		if not _player_in_territory(player) \
				or camp_center.distance_to(global_position) > TERRITORY:
			state = State.RETURN
		else:
			var to_player := player.global_position - global_position
			facing = to_player.normalized()
			var dist := to_player.length()
			if is_ranged:
				if dist > SHOOT_RANGE:
					velocity = facing * TIER_SPEED[tier - 1]
					move_and_slide()
				else:
					velocity = Vector2.ZERO
					if shoot_cd <= 0.0:
						_shoot(player)
			else:
				var reach := radius() + Player.RADIUS + 8.0
				if dist > reach:
					velocity = facing * TIER_SPEED[tier - 1]
					move_and_slide()
				else:
					velocity = Vector2.ZERO
					if attack_cd <= 0.0:
						attack_cd = ATTACK_CD
						player.take_damage(TIER_DMG[tier - 1])
	elif state == State.RETURN:
		var to_home := home - global_position
		if to_home.length() < 8.0:
			state = State.IDLE
		else:
			facing = to_home.normalized()
			velocity = facing * TIER_SPEED[tier - 1] * RETURN_SPEED_MULT
			move_and_slide()
	queue_redraw()

func _shoot(player: Player) -> void:
	shoot_cd = SHOOT_CD
	var dir := (player.global_position - global_position).normalized()
	var p := Projectile.new()
	p.setup(self, global_position + dir * (radius() + 8.0), dir,
		TIER_DMG[tier - 1], SHOT_RANGE, 5.0, base_color(), SHOT_SPEED, "player")
	get_parent().add_child(p)

func take_damage(amount: float) -> void:
	hp -= amount
	flash = 1.0
	if state != State.CHASE and _player_in_territory(_get_player()):
		state = State.CHASE
	if hp <= 0.0:
		var player := _get_player()
		if player != null:
			player.gain_xp(TIER_XP[tier - 1])
		queue_free()
	queue_redraw()

func _draw() -> void:
	var col := base_color()
	var c := col.lerp(Color.WHITE, flash)
	var r := radius()
	draw_circle(Vector2.ZERO, r + 3.0, Color(col, 0.15))
	if tier == 1:
		if is_ranged:
			draw_arc(Vector2.ZERO, r - 1.5, 0.0, TAU, 32, c, 3.0)
			draw_circle(Vector2.ZERO, 4.0, c)
		else:
			draw_circle(Vector2.ZERO, r, c)
	else:
		var sides := 4 if tier == 2 else 6
		var pts := PackedVector2Array()
		for i in sides:
			var a := TAU * i / sides - PI / 2.0
			pts.append(Vector2.from_angle(a) * r)
		if is_ranged:
			pts.append(pts[0])
			draw_polyline(pts, c, 3.0)
			draw_circle(Vector2.ZERO, 4.0, c)
		else:
			draw_colored_polygon(pts, c)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0.0, 0.0, 0.0, 0.35), 1.5)
	# bolinha de rosto: mostra para onde está apontando
	draw_circle(facing * (r + 1.0), 4.0, Palette.WHITE)
	draw_circle(facing * (r + 1.0), 2.0, c.darkened(0.4))
	# barra de vida (só quando machucado)
	if hp < max_hp:
		var w := 40.0
		var h := 4.0
		var tl := Vector2(-w / 2.0, -r - 14.0)
		draw_rect(Rect2(tl, Vector2(w, h)), Palette.BAR_BG)
		draw_rect(Rect2(tl, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), h)), Palette.HP_ENEMY)
