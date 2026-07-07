class_name DuelistPlayer
extends Player
## Classe "DUELISTA" — corpo a corpo. Recurso = FÔLEGO (barra âmbar):
## NÃO regenera passivamente; carrega ACERTANDO golpes — agressão alimenta
## o kit (o inverso do Atirador).
## AA: combo de lâmina 1-2-3 (o 3º é finisher a 1.5x; ref. Riven).
## Q Avanço Cortante: dash curto que golpeia ao chegar; ABATE reseta o cd.
## E Aparar (INSTANTÂNEO, sem mira): postura de 0.75s que bloqueia todo
##   dano; ao bloquear, contra-ataca atordoando inimigos próximos (Fiora W).
## R Gancho de Tração: projétil que PUXA o inimigo até você (anti-atirador;
##   o inverso do Pulso do Atirador).
## F Execução: golpe pesado que consome TODO o fôlego; dano escala com o
##   fôlego consumido e com o HP faltante do alvo (ref. Darius R).

const SWING_REACH := 88.0
const SWING_ARC := 2.1
const COMBO_WINDOW := 2.0
const AA_CD := 0.5
const AA_FINISHER_CD := 0.85
const FINISHER_MULT := 1.5
const STAMINA_HIT := 12.0
const STAMINA_FINISHER := 20.0

const ADV_RANGE := 210.0
const ADV_REACH := 95.0
const PARRY_TIME := 0.75
const PARRY_STUN := 1.2
const PARRY_COUNTER_RADIUS := 130.0
const HOOK_RANGE := 430.0
const HOOK_PULL := 1100.0
const EXEC_REACH := 120.0
const EXEC_ARC := 1.7

var combo := 0
var combo_t := 0.0
var q_pending := false
var parry_left := 0.0
var parry_flash := 0.0

func _ready() -> void:
	super._ready()
	cooldowns = [4.0, 6.0, 9.0, 5.0]
	costs = [15.0, 20.0, 25.0, 30.0]
	passive_regen = 0.0

func class_title() -> String:
	return "DUELISTA"

func resource_color() -> Color:
	return Palette.STAMINA

func aa_damage() -> float:
	return 14.0 + 3.0 * level

func advance_damage() -> float:
	return 20.0 + 4.0 * level

func hook_damage() -> float:
	return 10.0 + 2.0 * level

func _do_basic_attack() -> void:
	combo = combo % 3 + 1
	combo_t = COMBO_WINDOW
	var finisher := combo == 3
	aa_cd = AA_FINISHER_CD if finisher else AA_CD
	var dir := _aim_dir()
	facing = dir
	var mult := FINISHER_MULT if finisher else 1.0
	var swing := MeleeSwing.new()
	get_parent().add_child(swing)
	swing.strike(self, global_position + dir * (RADIUS * 0.4), dir,
		SWING_REACH, SWING_ARC, aa_damage() * mult, "enemies",
		Palette.STAMINA if finisher else Palette.PLAYER)
	if swing.hits > 0:
		gain_energy(STAMINA_FINISHER if finisher else STAMINA_HIT)
		stats_changed.emit()

func _on_skill_pressed(slot: int) -> void:
	if slot == 1:
		# Aparar é reação, não mira: lança na hora
		_cast_parry()
		stats_changed.emit()
		return
	super._on_skill_pressed(slot)

func _cast(slot: int) -> void:
	aim = -1
	if cds[slot] > 0.0 or not can_pay(slot):
		return
	if slot == 0:
		_cast_advance()
	elif slot == 2:
		_cast_hook()
	elif slot == 3:
		_cast_execute()
	stats_changed.emit()

## Q — Avanço Cortante: dash curto; golpeia ao aterrissar (em _class_physics).
func _cast_advance() -> void:
	cds[0] = cooldowns[0]
	energy -= costs[0]
	dash_dir = _aim_dir()
	dash_left = ADV_RANGE
	has_move_target = false
	q_pending = true

func _advance_strike() -> void:
	var swing := MeleeSwing.new()
	get_parent().add_child(swing)
	swing.strike(self, global_position + dash_dir * (RADIUS * 0.4), dash_dir,
		ADV_REACH, SWING_ARC, advance_damage(), "enemies", Palette.PLAYER)
	if swing.hits > 0:
		gain_energy(STAMINA_HIT)
	if swing.kills > 0:
		cds[0] = 0.0  # abate reseta o avanço

## E — Aparar: postura que bloqueia todo dano (contra-ataque em take_damage).
func _cast_parry() -> void:
	cds[1] = cooldowns[1]
	energy -= costs[1]
	parry_left = PARRY_TIME

## R — Gancho de Tração: projétil que puxa o alvo até você.
func _cast_hook() -> void:
	cds[2] = cooldowns[2]
	energy -= costs[2]
	var dir := _aim_dir()
	var p := Projectile.new()
	p.setup(self, global_position + dir * (RADIUS + 10.0), dir, hook_damage(),
		HOOK_RANGE, 6.0, Palette.STAMINA, 900.0, "enemies")
	p.pull_to = self
	p.pull_speed = HOOK_PULL
	get_parent().add_child(p)

## F — Execução: consome todo o fôlego; dano por alvo escala com HP faltante.
func _cast_execute() -> void:
	cds[3] = cooldowns[3]
	var consumed := energy
	energy = 0.0
	var dir := _aim_dir()
	facing = dir
	var swing := MeleeSwing.new()
	get_parent().add_child(swing)
	swing.show_arc(global_position + dir * (RADIUS * 0.4), dir,
		EXEC_REACH, EXEC_ARC, Palette.STAMINA)
	var base_dmg := 30.0 + 5.0 * level + consumed * 0.7
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		var rel := e.global_position - global_position
		if rel.length() <= EXEC_REACH + e.radius() \
				and absf(dir.angle_to(rel)) <= EXEC_ARC * 0.5 + 0.2:
			var missing := 1.0 - e.hp / e.max_hp
			e.take_damage(base_dmg * (1.0 + missing * 0.8))
	shake = 6.0

func _class_physics(delta: float) -> void:
	combo_t -= delta
	if combo_t <= 0.0:
		combo = 0
	parry_left = maxf(0.0, parry_left - delta)
	parry_flash = maxf(0.0, parry_flash - delta * 4.0)
	# golpe do avanço dispara quando o dash termina
	if q_pending and dash_left <= 0.0:
		q_pending = false
		_advance_strike()
	# ameaças legíveis pela IA (mesmo vocabulário do Atirador)
	if aim == 2:
		Threats.publish_line(global_position, _aim_dir(), HOOK_RANGE, 34.0)
	elif aim == 3:
		Threats.publish_circle(
			global_position + _aim_dir() * (EXEC_REACH * 0.5), EXEC_REACH)

func _move_speed_mult() -> float:
	return 0.5 if parry_left > 0.0 else 1.0

func take_damage(amount: float) -> void:
	if parry_left > 0.0:
		# bloqueado! contra-ataque: atordoa inimigos próximos
		parry_flash = 1.0
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if global_position.distance_to(e.global_position) \
					<= PARRY_COUNTER_RADIUS + e.radius():
				e.stun(PARRY_STUN)
		return
	super.take_damage(amount)

func _draw_indicators(mouse: Vector2, adir: Vector2) -> void:
	if aim == 0:
		# seta do avanço (mais curta que o dash do Atirador)
		var tip := adir * ADV_RANGE
		var back := adir * (RADIUS + 4.0)
		var perp := adir.orthogonal()
		draw_colored_polygon(PackedVector2Array([
			back + perp * 5.0, tip - adir * 22.0 + perp * 5.0,
			tip - adir * 22.0 - perp * 5.0, back - perp * 5.0,
		]), Color(Palette.INDICATOR_EDGE, 0.3))
		draw_colored_polygon(PackedVector2Array([
			tip, tip - adir * 22.0 + perp * 14.0, tip - adir * 22.0 - perp * 14.0,
		]), Color(Palette.INDICATOR_EDGE, 0.55))
		# arco do golpe na ponta
		var fa := adir.angle()
		draw_arc(tip, 30.0, fa - SWING_ARC * 0.5, fa + SWING_ARC * 0.5, 16,
			Color(Palette.INDICATOR_EDGE, 0.5), 2.0)
	elif aim == 2:
		# linha do gancho: fina com "elos" pontilhados
		var endp := adir * HOOK_RANGE
		draw_line(Vector2.ZERO, endp, Color(Palette.STAMINA, 0.3), 8.0)
		for i in 9:
			draw_circle(adir * (HOOK_RANGE * (i + 1) / 10.0), 2.5,
				Color(Palette.STAMINA, 0.8))
		draw_arc(endp, 12.0, 0.0, TAU, 20, Color(Palette.STAMINA, 0.9), 2.0)
	elif aim == 3:
		# leque da execução na frente do corpo
		var fa := adir.angle()
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			pts.append(Vector2.from_angle(
				lerpf(fa - EXEC_ARC * 0.5, fa + EXEC_ARC * 0.5, i / 12.0)) * EXEC_REACH)
		draw_colored_polygon(pts, Color(Palette.STAMINA, 0.16))
		draw_arc(Vector2.ZERO, EXEC_REACH, fa - EXEC_ARC * 0.5, fa + EXEC_ARC * 0.5,
			24, Color(Palette.STAMINA, 0.85), 2.0)
	# postura de aparar: escudo em arco na frente (efeito ativo, não mira)
	if parry_left > 0.0:
		var fa := facing.angle()
		var alpha := 0.4 + 0.5 * (parry_left / PARRY_TIME)
		draw_arc(Vector2.ZERO, RADIUS + 9.0, fa - 1.2, fa + 1.2, 16,
			Color(1.0, 1.0, 1.0, alpha), 4.0)
	if parry_flash > 0.0:
		draw_arc(Vector2.ZERO, PARRY_COUNTER_RADIUS * (1.0 - parry_flash * 0.5),
			0.0, TAU, 48, Color(1.0, 1.0, 1.0, parry_flash), 3.0)
