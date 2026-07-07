class_name Enemy
extends CharacterBody2D
## GUARDIÃO de bandeira — um por camp, mais inteligente que um mob comum.
## Três tiers: 1 = círculo âmbar, 2 = losango laranja, 3 = hexágono magenta.
## Comportamento em combate (CHASE):
##   longe  -> aproxima
##   médio  -> ORBITA o jogador (strafe, invertendo o sentido de tempos em
##             tempos) atirando RAJADAS de 3 projéteis
##   perto  -> INVESTIDA telegrafada (linha do bote, direção travada) se
##             pronta; senão RECUA atirando
## Regras de território (círculo tracejado, CampTerritory): persegue só com
## o jogador dentro; fora, volta devagar SEM cura instantânea (regen 4%/s
## parado no camp). Levar dano re-agra dentro do território.
## Lentidão (tiro elétrico do jogador): apply_slow() reduz velocidade e
## desenha faíscas.

enum State { IDLE, CHASE, RETURN }

const TIER_HP: Array[float] = [150.0, 240.0, 360.0]
const TIER_DMG: Array[float] = [8.0, 14.0, 22.0]
const TIER_SPEED: Array[float] = [140.0, 155.0, 170.0]
const TIER_RADIUS: Array[float] = [15.0, 18.0, 22.0]
const TIER_XP: Array[float] = [45.0, 80.0, 130.0]

const TERRITORY := 480.0
const TERRITORY_MARGIN := 60.0
const AGGRO_RANGE := 340.0
const ATTACK_CD := 0.9
const SHOOT_RANGE := 340.0
const ORBIT_DIST := 250.0
const RETREAT_RANGE := 170.0
const SHOOT_CD := 2.2
const BURST_COUNT := 3
const BURST_INTERVAL := 0.15
const SHOT_SPEED := 520.0
const SHOT_RANGE := 430.0
const RETURN_SPEED_MULT := 0.75
const HOME_REGEN := 0.04
const LUNGE_TRIGGER := 190.0
const LUNGE_WINDUP := 0.45
const LUNGE_TIME := 0.3
const LUNGE_SPEED := 650.0
const LUNGE_CD := 3.5
const DODGE_SPEED := 760.0
const DODGE_CD := 1.6

var tier := 1
var camp_center := Vector2.ZERO  # definido pelo Main antes do add_child
var home := Vector2.ZERO
var state: State = State.IDLE
var max_hp := 150.0
var hp := 150.0
var attack_cd := 0.0
var shoot_cd := 0.0
var burst_left := 0
var burst_t := 0.0
var orbit_dir := 1.0
var orbit_t := 0.0
var windup := 0.0
var lunging := 0.0
var lunge_cd := 0.0
var lunge_dir := Vector2.RIGHT
var slow_mult := 1.0
var slow_left := 0.0
var knock_vel := Vector2.ZERO
var dodge_cd := 0.0
var stun_left := 0.0
var flash := 0.0
var anim_t := 0.0
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
	orbit_t = randf_range(1.8, 3.2)
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

func _speed() -> float:
	var s := TIER_SPEED[tier - 1]
	if slow_left > 0.0:
		s *= slow_mult
	return s

func apply_slow(mult: float, time: float) -> void:
	slow_mult = mult
	slow_left = maxf(slow_left, time)

## Empurrão do pulso repulsor: joga para longe e INTERROMPE a investida.
func apply_knockback(dir: Vector2, speed: float) -> void:
	knock_vel = dir * speed
	windup = 0.0
	lunging = 0.0

## Atordoamento (contra-ataque do Aparar): congela e interrompe tudo.
func stun(duration: float) -> void:
	stun_left = maxf(stun_left, duration)
	windup = 0.0
	lunging = 0.0
	burst_left = 0

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
	dodge_cd = maxf(0.0, dodge_cd - delta)
	slow_left = maxf(0.0, slow_left - delta)
	flash = maxf(0.0, flash - delta * 5.0)
	anim_t += delta
	# sendo empurrado: sobrepõe qualquer comportamento até o impulso acabar
	if knock_vel.length() > 10.0:
		velocity = knock_vel
		move_and_slide()
		knock_vel = knock_vel.move_toward(Vector2.ZERO, 3200.0 * delta)
		queue_redraw()
		return
	# atordoado: parado e indefeso
	if stun_left > 0.0:
		stun_left -= delta
		velocity = Vector2.ZERO
		queue_redraw()
		return
	var player := _get_player()

	if state == State.IDLE:
		velocity = Vector2.ZERO
		hp = minf(max_hp, hp + max_hp * HOME_REGEN * delta)
		if _player_in_territory(player) \
				and (global_position.distance_to(player.global_position) < AGGRO_RANGE \
				or Game.is_player_on_vein()):
			state = State.CHASE
	elif state == State.CHASE:
		lunge_cd = maxf(0.0, lunge_cd - delta)
		if lunging <= 0.0 and windup <= 0.0 \
				and (not _player_in_territory(player) \
				or camp_center.distance_to(global_position) > TERRITORY):
			state = State.RETURN
			burst_left = 0
		elif lunging > 0.0:
			# disparada na direção travada no início do telegraph
			lunging -= delta
			velocity = lunge_dir * LUNGE_SPEED * (slow_mult if slow_left > 0.0 else 1.0)
			move_and_slide()
			var reach := radius() + Player.RADIUS + 4.0
			if player != null and not player.dead \
					and global_position.distance_to(player.global_position) <= reach:
				player.take_damage(TIER_DMG[tier - 1] * 1.5)
				lunging = 0.0
		elif windup > 0.0:
			# telegraph: parado, brilhando, mostrando a linha do bote
			windup -= delta
			velocity = Vector2.ZERO
			if windup <= 0.0:
				lunging = LUNGE_TIME
		else:
			var to_player := player.global_position - global_position
			facing = to_player.normalized()
			var dist := to_player.length()
			var speed := _speed()
			# esquiva reativa: lê o quadro de ameaças (a mira do jogador),
			# sem saber qual skill/classe é — só a geometria
			if dodge_cd <= 0.0:
				var esc: Vector2 = Threats.dodge_dir_for(global_position, radius() + 6.0)
				if esc != Vector2.ZERO:
					dodge_cd = DODGE_CD
					knock_vel = esc * DODGE_SPEED
			_combat(player, dist, speed, delta)
	elif state == State.RETURN:
		var to_home := home - global_position
		if to_home.length() < 8.0:
			state = State.IDLE
		else:
			facing = to_home.normalized()
			velocity = facing * _speed() * RETURN_SPEED_MULT
			move_and_slide()
	queue_redraw()

func _start_lunge() -> void:
	lunge_cd = LUNGE_CD
	windup = LUNGE_WINDUP
	lunge_dir = facing

## Comportamento de combate do guardião ATIRADOR (padrão).
## Subclasses (ex.: MeleeEnemy) substituem este método — o resto da IA
## (território, leash, esquiva reativa, investida, lentidão) é herdado.
func _combat(player: Player, dist: float, speed: float, delta: float) -> void:
	# rajada em andamento continua independente do movimento
	if burst_left > 0:
		burst_t -= delta
		if burst_t <= 0.0:
			_shoot(player)
			burst_left -= 1
			burst_t = BURST_INTERVAL
			if burst_left == 0:
				shoot_cd = SHOOT_CD
	elif shoot_cd <= 0.0 and dist <= SHOOT_RANGE + 40.0:
		burst_left = BURST_COUNT
		burst_t = 0.0
	# movimento
	if dist > SHOOT_RANGE:
		velocity = facing * speed
		move_and_slide()
	elif dist < RETREAT_RANGE:
		if lunge_cd <= 0.0:
			_start_lunge()
		else:
			velocity = -facing * speed * 0.9
			move_and_slide()
	else:
		# órbita: strafe ao redor do jogador, corrigindo a distância
		orbit_t -= delta
		if orbit_t <= 0.0:
			orbit_dir = -orbit_dir
			orbit_t = randf_range(1.8, 3.2)
		var tangent := facing.orthogonal() * orbit_dir
		var radial := facing * clampf((dist - ORBIT_DIST) / 80.0, -1.0, 1.0)
		velocity = (tangent + radial).normalized() * speed
		move_and_slide()
		# bateu na parede orbitando: inverte o sentido
		if get_slide_collision_count() > 0:
			orbit_dir = -orbit_dir
			orbit_t = randf_range(1.8, 3.2)

func _shoot(player: Player) -> void:
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
	# telegraph da investida: linha do bote + corpo carregando
	if windup > 0.0:
		var charge := 1.0 - windup / LUNGE_WINDUP
		var wlen := LUNGE_TRIGGER + 60.0
		var perp := lunge_dir.orthogonal() * (r * 0.6)
		draw_colored_polygon(PackedVector2Array([
			perp, lunge_dir * wlen + perp * 0.3,
			lunge_dir * wlen - perp * 0.3, -perp,
		]), Color(col, 0.22))
		c = c.lerp(Color.WHITE, charge * 0.6)
	if slow_left > 0.0:
		c = c.lerp(Palette.ELECTRO, 0.35)
	draw_circle(Vector2.ZERO, r + 3.0, Color(col, 0.15))
	if tier == 1:
		draw_circle(Vector2.ZERO, r, c)
	else:
		var sides := 4 if tier == 2 else 6
		var pts := PackedVector2Array()
		for i in sides:
			var a := TAU * i / sides - PI / 2.0
			pts.append(Vector2.from_angle(a) * r)
		draw_colored_polygon(pts, c)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0.0, 0.0, 0.0, 0.35), 1.5)
	# anel interno de "elite" (guardião)
	draw_arc(Vector2.ZERO, r * 0.55, 0.0, TAU, 24, Color(0.0, 0.0, 0.0, 0.3), 2.0)
	# faíscas de lentidão (tiro elétrico)
	if slow_left > 0.0:
		for i in 3:
			var a := anim_t * 6.0 + TAU * i / 3.0
			var p0 := Vector2.from_angle(a) * (r + 3.0)
			draw_line(p0, p0 + Vector2.from_angle(a + 2.1) * 8.0, Palette.ELECTRO, 1.5)
	# estrelinhas de atordoamento orbitando
	if stun_left > 0.0:
		for i in 3:
			var sa := anim_t * 5.0 + TAU * i / 3.0
			draw_circle(Vector2.from_angle(sa) * (r + 9.0), 2.5, Palette.WHITE)
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
