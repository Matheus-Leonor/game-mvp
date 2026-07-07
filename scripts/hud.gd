class_name HUD
extends Control
## HUD desenhado por código: HP/XP, nível, slots de skill com contagem de
## cooldown + flash ao recarregar, minimapa (bandeiras/extração/inimigos),
## contador de bandeiras, objetivo, esquema de controle e overlays.

const SLOT := 48.0
const MAP_SIZE := 156.0
const FLASH_TIME := 0.35

var player: Player
var prev_cds: Array[float] = [0.0, 0.0, 0.0, 0.0]
var ready_flash: Array[float] = [0.0, 0.0, 0.0, 0.0]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if player != null and is_instance_valid(player):
		for i in 4:
			if prev_cds[i] > 0.0 and player.cds[i] <= 0.0:
				ready_flash[i] = FLASH_TIME
			prev_cds[i] = player.cds[i]
			ready_flash[i] = maxf(0.0, ready_flash[i] - delta)
	queue_redraw()

func has_player() -> bool:
	return player != null and is_instance_valid(player)

func _find_player() -> void:
	var nodes := get_tree().get_nodes_in_group("player")
	if not nodes.is_empty():
		player = nodes[0] as Player

func _draw() -> void:
	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null:
			return
	# tamanho real da tela (não depende do layout do Control)
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	# --- barra de HP (centro inferior) ---
	var bw := 320.0
	var bh := 16.0
	var bx := vp.x / 2.0 - bw / 2.0
	var by := vp.y - 78.0
	draw_rect(Rect2(bx - 2.0, by - 2.0, bw + 4.0, bh + 4.0), Color(0.0, 0.0, 0.0, 0.5))
	draw_rect(Rect2(bx, by, bw, bh), Palette.BAR_BG)
	draw_rect(Rect2(bx, by, bw * clampf(player.hp / player.max_hp, 0.0, 1.0), bh), Palette.HP)
	draw_string(font, Vector2(bx, by + bh - 3.0), " %d / %d" % [player.hp, player.max_hp],
		HORIZONTAL_ALIGNMENT_CENTER, bw, 12, Color(0.0, 0.0, 0.0, 0.8))

	# --- barra de recurso (energia/fôlego — cor da classe) ---
	var eh := 9.0
	var ey := by + bh + 5.0
	draw_rect(Rect2(bx, ey, bw, eh), Palette.BAR_BG)
	draw_rect(Rect2(bx, ey, bw * clampf(player.energy / player.MAX_ENERGY, 0.0, 1.0), eh),
		player.resource_color())

	# --- barra de XP + nível ---
	var xh := 5.0
	var xy := ey + eh + 4.0
	draw_rect(Rect2(bx, xy, bw, xh), Palette.BAR_BG)
	draw_rect(Rect2(bx, xy, bw * clampf(player.xp / player.xp_to_next(), 0.0, 1.0), xh), Palette.XP)
	draw_string(font, Vector2(bx - 64.0, by + bh - 2.0), "Nv %d" % player.level,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.WHITE)

	# --- slots de skill ---
	var labels: Array = player.skill_labels()
	for i in 4:
		_draw_skill(Vector2(bx + bw + 16.0 + i * (SLOT + 8.0), by - 18.0),
			labels[i], player.cds[i], player.cooldowns[i], ready_flash[i],
			player.can_pay(i), font)

	# --- bandeiras (topo centro) ---
	var total := Game.FLAGS_TOTAL
	for i in total:
		var cx := vp.x / 2.0 + (i - (total - 1) / 2.0) * 34.0
		var pos := Vector2(cx, 34.0)
		if i < Game.flags_captured:
			draw_circle(pos, 10.0, Palette.FLAG)
		draw_arc(pos, 10.0, 0.0, TAU, 24, Color(Palette.FLAG, 0.7), 2.0)

	# --- objetivo atual ---
	if Game.state == Game.GState.PLAYING:
		draw_string(font, Vector2(0.0, 66.0), "Capture as 3 bandeiras",
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, 15, Color(Palette.WHITE, 0.75))

	_draw_minimap(vp)

	# --- esquema de controle (canto inferior esquerdo) ---
	var scheme_txt := "WASD + QERF"
	if Game.scheme == Game.Scheme.MOUSE:
		scheme_txt = "Mouse (clique dir. move) + QWER"
	draw_string(font, Vector2(14.0, vp.y - 16.0),
		"%s — Controles: %s   [F1 alterna]" % [player.class_title(), scheme_txt],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Palette.WHITE, 0.5))

	# --- overlays ---
	if Game.state == Game.GState.WON:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.65))
		draw_string(font, Vector2(0.0, vp.y / 2.0 - 10.0), "3 BANDEIRAS — VITÓRIA",
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, 42, Palette.EXTRACT)
		draw_string(font, Vector2(0.0, vp.y / 2.0 + 34.0), "Pressione R para reiniciar",
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, 18, Palette.WHITE)
	elif player.dead:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.2, 0.0, 0.0, 0.3))
		draw_string(font, Vector2(0.0, vp.y / 2.0), "Você caiu — retornando à base...",
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, 26, Palette.WHITE)

func _draw_skill(pos: Vector2, key: String, cd: float, cd_max: float,
		flash: float, affordable: bool, font: Font) -> void:
	var s := SLOT
	draw_rect(Rect2(pos, Vector2(s, s)), Palette.BAR_BG)
	if cd <= 0.0 and not affordable:
		# pronta mas sem energia: apagada com a tecla em azul fraco
		draw_rect(Rect2(pos, Vector2(s, s)), Color(0.0, 0.0, 0.0, 0.55))
		draw_string(font, Vector2(pos.x, pos.y + s / 2.0 + 8.0), key,
			HORIZONTAL_ALIGNMENT_CENTER, s, 22, Color(Palette.PLAYER, 0.45))
		draw_rect(Rect2(pos, Vector2(s, s)), Color(Palette.PLAYER, 0.2), false, 2.0)
	elif cd > 0.0:
		var frac := cd / cd_max
		# sombra esvaziando de cima pra baixo + contagem central
		draw_rect(Rect2(pos, Vector2(s, s * frac)), Color(0.0, 0.0, 0.0, 0.65))
		draw_string(font, Vector2(pos.x, pos.y + s / 2.0 + 8.0), "%.1f" % cd,
			HORIZONTAL_ALIGNMENT_CENTER, s, 19, Palette.WHITE)
		draw_string(font, Vector2(pos.x + 5.0, pos.y + 14.0), key,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Palette.WHITE, 0.55))
		# barra de progresso da recarga
		draw_rect(Rect2(pos.x, pos.y + s + 3.0, s, 3.0), Palette.BAR_BG)
		draw_rect(Rect2(pos.x, pos.y + s + 3.0, s * (1.0 - frac), 3.0), Palette.PLAYER)
		draw_rect(Rect2(pos, Vector2(s, s)), Color(Palette.PLAYER, 0.25), false, 2.0)
	else:
		draw_string(font, Vector2(pos.x, pos.y + s / 2.0 + 8.0), key,
			HORIZONTAL_ALIGNMENT_CENTER, s, 22, Palette.WHITE)
		draw_rect(Rect2(pos, Vector2(s, s)), Color(Palette.PLAYER, 0.8), false, 2.0)
	if flash > 0.0:
		draw_rect(Rect2(pos - Vector2(3.0, 3.0), Vector2(s + 6.0, s + 6.0)),
			Color(Palette.WHITE, flash / FLASH_TIME), false, 3.0)

func _draw_minimap(vp: Vector2) -> void:
	var arena := Game.arena
	if arena.size.x <= 0.0:
		return
	var sc := MAP_SIZE / maxf(arena.size.x, arena.size.y)
	var origin := Vector2(vp.x - arena.size.x * sc - 14.0, 14.0)
	var map_rect := Rect2(origin, arena.size * sc)
	draw_rect(map_rect, Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(map_rect, Palette.WALL, false, 2.0)

	for node in get_tree().get_nodes_in_group("obstacles"):
		var wrect: Rect2 = node.map_rect()
		var wcol: Color = node.map_color()
		draw_rect(Rect2(origin + (wrect.position - arena.position) * sc, wrect.size * sc), wcol)
	for node in get_tree().get_nodes_in_group("flags"):
		var f := node as Flag
		var col := Palette.FLAG if not f.captured else Color(Palette.FLAG, 0.25)
		draw_circle(origin + (f.global_position - arena.position) * sc, 3.5, col)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		draw_circle(origin + (e.global_position - arena.position) * sc, 1.5,
			Color(e.base_color(), 0.9))
	if not player.dead:
		var pp := origin + (player.global_position - arena.position) * sc
		draw_circle(pp, 3.0, Palette.PLAYER)
		draw_arc(pp, 4.5, 0.0, TAU, 16, Palette.WHITE, 1.0)
