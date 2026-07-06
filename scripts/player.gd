class_name Player
extends CharacterBody2D
## Personagem do jogador. Dois esquemas de controle (F1 alterna, ver Game.scheme):
##   WASD  — WASD move, skills em Q/E/R/T
##   MOUSE — clique direito move (estilo LoL), skills em Q/W/E/R
## Em ambos: clique esquerdo = ataque básico (sempre disponível);
## skills: segurar a tecla mira (spell indicator), soltar lança, Esc/clique
## direito cancela. Skills por slot: 0 skillshot, 1 dash, 2 nova, 3 explosão.
## Visual 100% desenhado em _draw() com cores da Palette.

signal died
signal stats_changed

const RADIUS := 16.0
const SPEED := 340.0

const AA_COOLDOWN := 0.45
const AA_RANGE := 440.0

const Q_RANGE := 700.0
const Q_WIDTH := 14.0
const DASH_RANGE := 260.0
const DASH_SPEED := 2200.0
const NOVA_RADIUS := 170.0
const BLAST_RANGE := 550.0
const BLAST_RADIUS := 110.0

const COOLDOWNS: Array[float] = [2.2, 5.0, 8.0, 10.0]

var max_hp := 100.0
var hp := max_hp
var level := 1
var xp := 0.0
var dead := false

var aim := -1  # -1 = sem mira; 0..3 = slot sendo mirado
var cds: Array[float] = [0.0, 0.0, 0.0, 0.0]
var aa_cd := 0.0
var move_target := Vector2.ZERO
var has_move_target := false
var dash_left := 0.0
var dash_dir := Vector2.ZERO
## Para onde o corpo aponta (rosto). Regra: mirando/atirando = cursor;
## senão = direção do movimento. Desacoplado do destino de andar.
var facing := Vector2.RIGHT

var flash := 0.0
var shake := 0.0
var camera: Camera2D

func _ready() -> void:
	add_to_group("player")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)

func _skill_keys() -> Array:
	if Game.scheme == Game.Scheme.WASD:
		return [KEY_Q, KEY_E, KEY_R, KEY_F]
	return [KEY_Q, KEY_W, KEY_E, KEY_R]

func skill_labels() -> Array:
	if Game.scheme == Game.Scheme.WASD:
		return ["Q", "E", "R", "F"]
	return ["Q", "W", "E", "R"]

func xp_to_next() -> float:
	return 40.0 + 30.0 * (level - 1)

func aa_damage() -> float:
	return 7.0 + 2.0 * level

func q_damage() -> float:
	return 26.0 + 6.0 * level

func nova_damage() -> float:
	return 35.0 + 8.0 * level

func blast_damage() -> float:
	return 45.0 + 10.0 * level

func _unhandled_input(event: InputEvent) -> void:
	if dead or Game.state != Game.GState.PLAYING:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		if Game.scheme == Game.Scheme.MOUSE:
			# botão direito é o de andar: NÃO cancela mira (Esc cancela);
			# se estiver mirando, o destino fica congelado no último ponto
			if aim == -1:
				move_target = get_global_mouse_position()
				has_move_target = true
		else:
			aim = -1
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		var k := key_event.physical_keycode
		if key_event.pressed and not key_event.echo:
			if k == KEY_ESCAPE:
				aim = -1
			else:
				var slot := _skill_keys().find(k)
				if slot != -1 and cds[slot] <= 0.0:
					aim = slot
		elif not key_event.pressed:
			# soltar a tecla lança a skill (se a mira não foi cancelada)
			var slot := _skill_keys().find(k)
			if slot != -1 and aim == slot:
				_cast(slot)

func _aim_dir() -> Vector2:
	var dir := (get_global_mouse_position() - global_position).normalized()
	if dir == Vector2.ZERO:
		return Vector2.RIGHT
	return dir

func _basic_attack() -> void:
	aa_cd = AA_COOLDOWN
	var dir := _aim_dir()
	facing = dir
	var p := Projectile.new()
	p.setup(self, global_position + dir * (RADIUS + 8.0), dir, aa_damage(), AA_RANGE,
		5.0, Color(Palette.WHITE, 0.9), 950.0, "enemies")
	get_parent().add_child(p)

func _cast(slot: int) -> void:
	aim = -1
	if slot == 0:
		_cast_skillshot()
	elif slot == 1:
		_cast_dash()
	elif slot == 2:
		_cast_nova()
	elif slot == 3:
		_cast_blast()

func _cast_skillshot() -> void:
	cds[0] = COOLDOWNS[0]
	var dir := _aim_dir()
	facing = dir
	var p := Projectile.new()
	p.setup(self, global_position + dir * (RADIUS + 10.0), dir, q_damage(), Q_RANGE,
		7.0, Palette.PLAYER, 950.0, "enemies")
	get_parent().add_child(p)

func _cast_dash() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	var dist := minf(to_mouse.length(), DASH_RANGE)
	if dist < 1.0:
		return
	cds[1] = COOLDOWNS[1]
	dash_dir = to_mouse.normalized()
	dash_left = dist
	has_move_target = false

func _cast_nova() -> void:
	cds[2] = COOLDOWNS[2]
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if global_position.distance_to(e.global_position) <= NOVA_RADIUS + e.radius():
			e.take_damage(nova_damage())
	_ring_effect(global_position, NOVA_RADIUS)

func _cast_blast() -> void:
	cds[3] = COOLDOWNS[3]
	var target := global_position \
		+ (get_global_mouse_position() - global_position).limit_length(BLAST_RANGE)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if target.distance_to(e.global_position) <= BLAST_RADIUS + e.radius():
			e.take_damage(blast_damage())
	_ring_effect(target, BLAST_RADIUS)

func _ring_effect(pos: Vector2, radius: float) -> void:
	var fx := RingEffect.new()
	fx.setup(pos, radius, Palette.PLAYER)
	get_parent().add_child(fx)

func _physics_process(delta: float) -> void:
	if dead:
		return
	aa_cd = maxf(0.0, aa_cd - delta)
	for i in cds.size():
		cds[i] = maxf(0.0, cds[i] - delta)
	flash = maxf(0.0, flash - delta * 5.0)
	shake = maxf(0.0, shake - delta * 30.0)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake

	if Game.state == Game.GState.PLAYING \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and aa_cd <= 0.0:
		_basic_attack()

	# esquema mouse: segurar o botão direito move continuamente (estilo LoL),
	# em paralelo com o tiro no esquerdo — mas não enquanto mira skill,
	# para poder andar para um lado e mirar para outro
	if Game.scheme == Game.Scheme.MOUSE and Game.state == Game.GState.PLAYING \
			and aim == -1 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		move_target = get_global_mouse_position()
		has_move_target = true

	if dash_left > 0.0:
		velocity = dash_dir * DASH_SPEED
		dash_left -= DASH_SPEED * delta
		move_and_slide()
	elif Game.scheme == Game.Scheme.WASD:
		has_move_target = false
		var dir := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_W):
			dir.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			dir.y += 1.0
		if Input.is_physical_key_pressed(KEY_A):
			dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			dir.x += 1.0
		if dir != Vector2.ZERO:
			velocity = dir.normalized() * SPEED
			move_and_slide()
		else:
			velocity = Vector2.ZERO
	elif has_move_target:
		var to_target := move_target - global_position
		if to_target.length() < 8.0:
			has_move_target = false
			velocity = Vector2.ZERO
		else:
			velocity = to_target.normalized() * SPEED
			move_and_slide()
	else:
		velocity = Vector2.ZERO

	if aim != -1:
		facing = _aim_dir()
	elif velocity.length() > 5.0:
		facing = velocity.normalized()
	queue_redraw()

func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	flash = 1.0
	shake = 5.0
	stats_changed.emit()
	if hp <= 0.0:
		hp = 0.0
		dead = true
		aim = -1
		has_move_target = false
		hide()
		died.emit()

func respawn(pos: Vector2) -> void:
	global_position = pos
	hp = max_hp
	dead = false
	show()
	stats_changed.emit()

func gain_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		max_hp += 20.0
		hp = max_hp
	stats_changed.emit()

func _draw() -> void:
	var mouse := get_local_mouse_position()
	# --- spell indicators (embaixo do corpo) ---
	if aim == 0:
		var dir := mouse.normalized() if mouse.length() > 0.1 else Vector2.RIGHT
		var endp := dir * Q_RANGE
		var perp := dir.orthogonal() * (Q_WIDTH * 0.5 + 4.0)
		var pts := PackedVector2Array([perp, endp + perp, endp - perp, -perp])
		draw_colored_polygon(pts, Palette.INDICATOR_FILL)
		draw_polyline(PackedVector2Array([perp, endp + perp, endp - perp, -perp, perp]),
			Palette.INDICATOR_EDGE, 2.0)
	elif aim == 1:
		draw_circle(Vector2.ZERO, DASH_RANGE, Palette.INDICATOR_FILL)
		draw_arc(Vector2.ZERO, DASH_RANGE, 0.0, TAU, 64, Palette.INDICATOR_EDGE, 2.0)
		var target := mouse.limit_length(DASH_RANGE)
		draw_arc(target, 12.0, 0.0, TAU, 24, Palette.INDICATOR_EDGE, 2.0)
	elif aim == 2:
		draw_circle(Vector2.ZERO, NOVA_RADIUS, Palette.INDICATOR_FILL)
		draw_arc(Vector2.ZERO, NOVA_RADIUS, 0.0, TAU, 64, Palette.INDICATOR_EDGE, 2.0)
	elif aim == 3:
		draw_arc(Vector2.ZERO, BLAST_RANGE, 0.0, TAU, 64, Color(Palette.INDICATOR_EDGE, 0.35), 1.5)
		var target := mouse.limit_length(BLAST_RANGE)
		draw_circle(target, BLAST_RADIUS, Palette.INDICATOR_FILL)
		draw_arc(target, BLAST_RADIUS, 0.0, TAU, 48, Palette.INDICATOR_EDGE, 2.0)
	# marcador de destino (esquema mouse)
	if has_move_target:
		var lt := move_target - global_position
		draw_arc(lt, 10.0, 0.0, TAU, 20, Color(Palette.PLAYER, 0.55), 1.5)
	# --- corpo: mesmo estilo dos inimigos (quadrado azul + bolinha de rosto) ---
	var body_color := Palette.PLAYER.lerp(Color.WHITE, flash)
	draw_circle(Vector2.ZERO, RADIUS + 3.0, Color(Palette.PLAYER, 0.15))
	var body := PackedVector2Array()
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		body.append(Vector2.from_angle(a) * RADIUS)
	draw_colored_polygon(body, body_color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(0.0, 0.0, 0.0, 0.35), 1.5)
	draw_circle(facing * (RADIUS + 1.0), 4.0, Palette.WHITE)
	draw_circle(facing * (RADIUS + 1.0), 2.0, body_color.darkened(0.4))
	# --- barra de vida ---
	var w := 44.0
	var h := 5.0
	var tl := Vector2(-w / 2.0, -RADIUS - 18.0)
	draw_rect(Rect2(tl, Vector2(w, h)), Palette.BAR_BG)
	draw_rect(Rect2(tl, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), h)), Palette.HP)
