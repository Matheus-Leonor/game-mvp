class_name MeleeEnemy
extends Enemy
## Guardião CORPO A CORPO ("Ceifador"). Não atira. Herda de Enemy todo o
## resto (território, leash, esquiva reativa, investida, lentidão, knockback)
## e substitui só o _combat():
##   longe  -> persegue com IMPULSO crescente (acelera quanto mais persegue)
##   médio  -> fecha distância com a investida herdada (gap-closer)
##   perto  -> COMBO de 3 golpes em arco (o 3º é mais forte, ref. Riven)
##   colado -> RODOPIO telegrafado: dano em área por ticks (ref. Garen E)
## Identidade visual: garra branca na frente do corpo.

const REACH_MARGIN := 12.0
const SWING_ARC := 2.1
const COMBO_CD := 0.7
const COMBO_FINISHER_CD := 1.1
const FINISHER_MULT := 1.6
const MOMENTUM_MAX := 0.5
const MOMENTUM_RATE := 0.22
const SPIN_TRIGGER := 120.0
const SPIN_RADIUS := 90.0
const SPIN_CD := 7.0
const SPIN_WINDUP := 0.55
const SPIN_TIME := 1.4
const SPIN_TICK := 0.4
const SPIN_DMG_MULT := 0.6

var combo := 0
var momentum := 0.0
var spin_cd := 0.0
var spin_windup := 0.0
var spinning := 0.0
var spin_tick_t := 0.0

func _combat(player: Player, dist: float, speed: float, delta: float) -> void:
	spin_cd = maxf(0.0, spin_cd - delta)
	var reach := radius() + Player.RADIUS + REACH_MARGIN
	if spinning > 0.0:
		# rodopiando: avança devagar, dano em área por tick
		spinning -= delta
		spin_tick_t -= delta
		velocity = facing * speed * 0.55
		move_and_slide()
		if spin_tick_t <= 0.0:
			spin_tick_t = SPIN_TICK
			if dist <= SPIN_RADIUS + Player.RADIUS:
				player.take_damage(TIER_DMG[tier - 1] * SPIN_DMG_MULT)
		return
	if spin_windup > 0.0:
		# telegraph do rodopio: parado, círculo crescendo — dá para sair
		spin_windup -= delta
		velocity = Vector2.ZERO
		if spin_windup <= 0.0:
			spinning = SPIN_TIME
			spin_tick_t = 0.0
		return
	if dist <= SPIN_TRIGGER and spin_cd <= 0.0:
		spin_cd = SPIN_CD
		spin_windup = SPIN_WINDUP
		return
	if dist > reach:
		# gap-closer: investida herdada quando em alcance médio
		if lunge_cd <= 0.0 and dist > 130.0 and dist < LUNGE_TRIGGER + 80.0:
			momentum = 0.0
			_start_lunge()
			return
		# perseguição com impulso crescente
		momentum = minf(momentum + delta * MOMENTUM_RATE, MOMENTUM_MAX)
		velocity = facing * speed * (1.0 + momentum)
		move_and_slide()
	else:
		momentum = 0.0
		velocity = Vector2.ZERO
		if attack_cd <= 0.0:
			combo = combo % 3 + 1
			attack_cd = COMBO_FINISHER_CD if combo == 3 else COMBO_CD
			var mult := FINISHER_MULT if combo == 3 else 1.0
			var swing := MeleeSwing.new()
			get_parent().add_child(swing)
			swing.strike(self, global_position + facing * (radius() * 0.4), facing,
				reach + 10.0, SWING_ARC, TIER_DMG[tier - 1] * mult, "player", base_color())

func _draw() -> void:
	# telegraph/efeito do rodopio (sob o corpo)
	if spin_windup > 0.0:
		var f := 1.0 - spin_windup / SPIN_WINDUP
		draw_circle(Vector2.ZERO, SPIN_RADIUS, Color(base_color(), 0.10 + 0.12 * f))
		draw_arc(Vector2.ZERO, SPIN_RADIUS, 0.0, TAU, 40, Color(base_color(), 0.5 + 0.4 * f), 2.0)
	elif spinning > 0.0:
		var a := anim_t * 14.0
		for i in 2:
			var start := a + PI * i
			draw_arc(Vector2.ZERO, radius() + 12.0, start, start + 1.6, 12,
				Color(1.0, 1.0, 1.0, 0.8), 3.0)
		draw_arc(Vector2.ZERO, SPIN_RADIUS, 0.0, TAU, 40, Color(base_color(), 0.35), 1.5)
	super._draw()
	# garra frontal: identidade visual do corpo a corpo
	var fa := facing.angle()
	draw_arc(Vector2.ZERO, radius() + 6.0, fa - 0.7, fa + 0.7, 12, Palette.WHITE, 2.5)
