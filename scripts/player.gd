class_name Player
extends CharacterBody2D
## Classe BASE do jogador + kit "ATIRADOR" (classe padrão).
## Subclasses (DuelistPlayer) sobrescrevem os hooks de classe:
##   _do_basic_attack, _cast, _on_skill_pressed, _class_physics,
##   _draw_indicators, _move_speed_mult, resource_color, class_title
## O núcleo compartilhado: dois esquemas de controle (F1, Game.scheme),
## dash/arremesso, recurso (energia/fôlego via `energy`), XP, facing
## (segue o cursor SEMPRE), corpo e barra de vida.
##
## Kit Atirador: AA pistola laser; Q dash (seta); E raio elétrico (hitscan
## que atravessa + lentidão); R pulso repulsor (sem dano, empurra);
## F explosão carregada (segurar drena energia, soltar explode).

signal died
signal stats_changed

const RADIUS := 16.0
const SPEED := 340.0

const MAX_ENERGY := 100.0
const LAUNCH_SPEED := 900.0

const AA_COOLDOWN := 0.45
const AA_RANGE := 440.0

const DASH_RANGE := 260.0
const DASH_SPEED := 2200.0
const BEAM_RANGE := 650.0
const BEAM_WIDTH := 16.0
const BEAM_SLOW := 0.5
const BEAM_SLOW_TIME := 2.5
const PULSE_RADIUS := 200.0
const PULSE_KNOCK := 1000.0
const BLAST_RANGE := 550.0
const BLAST_CHARGE_RATE := 70.0  # energia drenada por segundo segurando F
const BLAST_MAX_CHARGE := 100.0
const CHARGE_SPEED_MULT := 0.6  # anda mais devagar enquanto carrega a ult

## Por classe (subclasses sobrescrevem no _ready)
var cooldowns: Array[float] = [3.0, 6.0, 8.0, 3.0]
var costs: Array[float] = [20.0, 30.0, 25.0, 30.0]  # slot 3: mínimo p/ começar
var passive_regen := 12.0

var max_hp := 100.0
var hp := max_hp
var energy := MAX_ENERGY
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
var launch_left := 0.0
var launch_dir := Vector2.ZERO
## Energia acumulada segurando F (Atirador); perdida se cancelar a mira.
var blast_charge := 0.0
## Rosto: aponta sempre para o cursor.
var facing := Vector2.RIGHT

var flash := 0.0
var shake := 0.0
var muzzle := 0.0  # flash do cano ao atirar
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

func class_title() -> String:
	return "ATIRADOR"

func resource_color() -> Color:
	return Palette.PLAYER

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

func beam_damage() -> float:
	return 30.0 + 5.0 * level

func blast_damage(charge: float) -> float:
	return 20.0 + 5.0 * level + charge

func blast_radius(charge: float) -> float:
	return 80.0 + charge * 0.6

func can_pay(slot: int) -> bool:
	return energy >= costs[slot]

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
			blast_charge = 0.0
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		var k := key_event.physical_keycode
		if key_event.pressed and not key_event.echo:
			if k == KEY_ESCAPE:
				aim = -1
				blast_charge = 0.0  # cancelar a ult perde o que carregou
			else:
				var slot := _skill_keys().find(k)
				if slot != -1 and cds[slot] <= 0.0 and can_pay(slot):
					_on_skill_pressed(slot)
		elif not key_event.pressed:
			# soltar a tecla lança a skill (se a mira não foi cancelada)
			var slot := _skill_keys().find(k)
			if slot != -1 and aim == slot:
				_cast(slot)

## Hook: apertar a tecla da skill. Padrão = entrar em modo de mira.
func _on_skill_pressed(slot: int) -> void:
	aim = slot
	if slot == 3:
		blast_charge = 0.0

func _aim_dir() -> Vector2:
	var dir := (get_global_mouse_position() - global_position).normalized()
	if dir == Vector2.ZERO:
		return Vector2.RIGHT
	return dir

## Hook: ataque básico (chamado por polling do botão esquerdo).
func _do_basic_attack() -> void:
	aa_cd = AA_COOLDOWN
	muzzle = 1.0
	var dir := _aim_dir()
	var p := Projectile.new()
	p.setup(self, global_position + dir * (RADIUS + 8.0), dir, aa_damage(), AA_RANGE,
		5.0, Palette.PLAYER, 1050.0, "enemies")
	p.streak = true
	get_parent().add_child(p)

## Hook: lançar a skill do slot (ao soltar a tecla).
func _cast(slot: int) -> void:
	aim = -1
	if slot == 3:
		# a ult paga o custo DURANTE o carregamento; solta o que carregou
		if blast_charge > 0.0:
			_cast_blast()
			stats_changed.emit()
		return
	if cds[slot] > 0.0 or not can_pay(slot):
		return
	if slot == 0:
		_cast_dash()
	elif slot == 1:
		_cast_beam()
	elif slot == 2:
		_cast_pulse()
	stats_changed.emit()

func _cast_dash() -> void:
	cds[0] = cooldowns[0]
	energy -= costs[0]
	dash_dir = _aim_dir()
	dash_left = DASH_RANGE
	has_move_target = false

## E — Raio Elétrico: hitscan que ATRAVESSA, dano moderado + lentidão.
func _cast_beam() -> void:
	cds[1] = cooldowns[1]
	energy -= costs[1]
	var dir := _aim_dir()
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		var rel := e.global_position - global_position
		var along := clampf(rel.dot(dir), 0.0, BEAM_RANGE)
		if rel.distance_to(dir * along) <= BEAM_WIDTH * 0.5 + e.radius():
			e.apply_slow(BEAM_SLOW, BEAM_SLOW_TIME)
			e.take_damage(beam_damage())
	var beam := BeamEffect.new()
	beam.setup(global_position + dir * (RADIUS + 6.0), dir, BEAM_RANGE,
		BEAM_WIDTH, Palette.ELECTRO)
	get_parent().add_child(beam)

## R — Pulso Repulsor: SEM dano; empurra inimigos e interrompe a investida.
func _cast_pulse() -> void:
	cds[2] = cooldowns[2]
	energy -= costs[2]
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		var rel := e.global_position - global_position
		if rel.length() <= PULSE_RADIUS + e.radius():
			var dir := rel.normalized() if rel.length() > 0.01 else Vector2.RIGHT
			e.apply_knockback(dir, PULSE_KNOCK)
	var fx := RingEffect.new()
	fx.setup(global_position, PULSE_RADIUS, Palette.WHITE)
	get_parent().add_child(fx)

## F — Explosão carregada: dano e raio escalam com a energia canalizada.
func _cast_blast() -> void:
	cds[3] = cooldowns[3]
	var charge := blast_charge
	blast_charge = 0.0
	var target := global_position \
		+ (get_global_mouse_position() - global_position).limit_length(BLAST_RANGE)
	var radius := blast_radius(charge)
	var dmg := blast_damage(charge)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if target.distance_to(e.global_position) <= radius + e.radius():
			e.take_damage(dmg)
	var fx := RingEffect.new()
	fx.setup(target, radius, Palette.PLAYER)
	get_parent().add_child(fx)

## Hook: lógica por-frame da classe (carga de ult, ameaças, timers).
func _class_physics(delta: float) -> void:
	# carregando a ult: drena energia continuamente enquanto segura
	if aim == 3 and blast_charge < BLAST_MAX_CHARGE:
		var drain := minf(energy, BLAST_CHARGE_RATE * delta)
		blast_charge = minf(BLAST_MAX_CHARGE, blast_charge + drain)
		energy -= drain
	# publica a mira ativa como ameaça legível pelos inimigos (ThreatBoard)
	if aim == 1:
		Threats.publish_line(global_position, _aim_dir(), BEAM_RANGE, BEAM_WIDTH + 24.0)
	elif aim == 3:
		var threat_target := global_position \
			+ (get_global_mouse_position() - global_position).limit_length(BLAST_RANGE)
		Threats.publish_circle(threat_target, blast_radius(blast_charge) + 10.0)

## Hook: multiplicador de velocidade por estado da classe.
func _move_speed_mult() -> float:
	return CHARGE_SPEED_MULT if aim == 3 else 1.0

func _physics_process(delta: float) -> void:
	if dead:
		return
	aa_cd = maxf(0.0, aa_cd - delta)
	for i in cds.size():
		cds[i] = maxf(0.0, cds[i] - delta)
	energy = minf(MAX_ENERGY, energy + passive_regen * delta)
	flash = maxf(0.0, flash - delta * 5.0)
	shake = maxf(0.0, shake - delta * 30.0)
	muzzle = maxf(0.0, muzzle - delta * 10.0)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake

	_class_physics(delta)

	if Game.state == Game.GState.PLAYING \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and aa_cd <= 0.0:
		_do_basic_attack()

	# esquema mouse: segurar o botão direito move continuamente (estilo LoL),
	# em paralelo com o tiro no esquerdo — mas não enquanto mira skill,
	# para poder andar para um lado e mirar para outro
	if Game.scheme == Game.Scheme.MOUSE and Game.state == Game.GState.PLAYING \
			and aim == -1 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		move_target = get_global_mouse_position()
		has_move_target = true

	var speed_mult := _move_speed_mult()
	if launch_left > 0.0:
		# voo do arremessador: move direto, sem colisão (passa por cima)
		var step := LAUNCH_SPEED * delta
		position += launch_dir * step
		launch_left -= step
		velocity = Vector2.ZERO
	elif dash_left > 0.0:
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
			velocity = dir.normalized() * SPEED * speed_mult
			move_and_slide()
		else:
			velocity = Vector2.ZERO
	elif has_move_target:
		var to_target := move_target - global_position
		if to_target.length() < 8.0:
			has_move_target = false
			velocity = Vector2.ZERO
		else:
			velocity = to_target.normalized() * SPEED * speed_mult
			move_and_slide()
	else:
		velocity = Vector2.ZERO

	# o rosto segue o cursor SEMPRE
	facing = _aim_dir()
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
		blast_charge = 0.0
		has_move_target = false
		hide()
		died.emit()

func respawn(pos: Vector2) -> void:
	global_position = pos
	hp = max_hp
	energy = MAX_ENERGY
	dead = false
	show()
	stats_changed.emit()

func gain_energy(amount: float) -> void:
	energy = minf(MAX_ENERGY, energy + amount)

## Arremessador: voo balístico que ignora colisões (passa por cima de muros).
func launch(dir: Vector2, dist: float) -> void:
	launch_dir = dir
	launch_left = dist
	dash_left = 0.0
	has_move_target = false

func gain_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		max_hp += 20.0
		hp = max_hp
	stats_changed.emit()

## Hook: spell indicators da classe (desenhados sob o corpo).
func _draw_indicators(mouse: Vector2, adir: Vector2) -> void:
	if aim == 0:
		# seta do dash: avança exatamente na direção e distância da seta
		var tip := adir * DASH_RANGE
		var back := adir * (RADIUS + 4.0)
		var perp := adir.orthogonal()
		draw_colored_polygon(PackedVector2Array([
			back + perp * 5.0, tip - adir * 22.0 + perp * 5.0,
			tip - adir * 22.0 - perp * 5.0, back - perp * 5.0,
		]), Color(Palette.INDICATOR_EDGE, 0.3))
		draw_colored_polygon(PackedVector2Array([
			tip, tip - adir * 22.0 + perp * 14.0, tip - adir * 22.0 - perp * 14.0,
		]), Color(Palette.INDICATOR_EDGE, 0.55))
	elif aim == 1:
		# linha do raio elétrico (atravessa e eletrocuta) — cor elétrica
		var endp := adir * BEAM_RANGE
		var perp := adir.orthogonal() * (BEAM_WIDTH * 0.5 + 4.0)
		var pts := PackedVector2Array([perp, endp + perp, endp - perp, -perp])
		draw_colored_polygon(pts, Color(Palette.ELECTRO, 0.14))
		draw_polyline(PackedVector2Array([perp, endp + perp, endp - perp, -perp, perp]),
			Color(Palette.ELECTRO, 0.85), 2.0)
	elif aim == 2:
		# círculo do pulso repulsor (ao redor de si)
		draw_circle(Vector2.ZERO, PULSE_RADIUS, Palette.INDICATOR_FILL)
		draw_arc(Vector2.ZERO, PULSE_RADIUS, 0.0, TAU, 64, Palette.INDICATOR_EDGE, 2.0)
	elif aim == 3:
		# ult: o círculo interno CRESCE conforme carrega
		draw_arc(Vector2.ZERO, BLAST_RANGE, 0.0, TAU, 64, Color(Palette.INDICATOR_EDGE, 0.35), 1.5)
		var target := mouse.limit_length(BLAST_RANGE)
		draw_arc(target, blast_radius(BLAST_MAX_CHARGE), 0.0, TAU, 48,
			Color(Palette.INDICATOR_EDGE, 0.3), 1.0)
		var cur := blast_radius(blast_charge)
		draw_circle(target, cur, Palette.INDICATOR_FILL)
		draw_arc(target, cur, 0.0, TAU, 48, Palette.INDICATOR_EDGE, 2.0)

func _draw() -> void:
	var mouse := get_local_mouse_position()
	var adir := mouse.normalized() if mouse.length() > 0.1 else Vector2.RIGHT
	_draw_indicators(mouse, adir)
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
	# flash do cano
	if muzzle > 0.0:
		var mp := facing * (RADIUS + 7.0)
		draw_circle(mp, 11.0 * muzzle, Color(Palette.PLAYER, 0.35 * muzzle))
		draw_circle(mp, 6.5 * muzzle, Color(1.0, 1.0, 1.0, 0.9 * muzzle))
	# --- barra de vida ---
	var w := 44.0
	var h := 5.0
	var tl := Vector2(-w / 2.0, -RADIUS - 18.0)
	draw_rect(Rect2(tl, Vector2(w, h)), Palette.BAR_BG)
	draw_rect(Rect2(tl, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), h)), Palette.HP)
