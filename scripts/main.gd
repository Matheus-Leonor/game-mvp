extends Node2D
## Cena principal: constrói a arena inteira por código (chão, paredes,
## jogador, camps com bandeiras, zona de extração e HUD).
## Layout: spawn no canto SW; bandeiras em camps de tier crescente.

const ARENA := Rect2(0.0, 0.0, 3200.0, 3200.0)
const GRID_STEP := 80.0
const APRON := 700.0  # faixa visual além das paredes (inacessível)
const WALL_THICK := 36.0
const SPAWN := Vector2(1600.0, 2650.0)
const RESPAWN_DELAY := 2.5

var player: Player
var respawn_timer := 0.0
var lobby_cam: Camera2D

func _ready() -> void:
	Game.reset()
	Game.arena = ARENA
	_build_walls()

	_spawn_camp(Vector2(2350.0, 2300.0), 1, true)   # ceifador (melee)
	_spawn_camp(Vector2(800.0, 1400.0), 2, false)   # atirador
	_spawn_camp(Vector2(2400.0, 650.0), 3, true)    # ceifador elite

	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(HUD.new())
	var select := ClassSelect.new()
	layer.add_child(select)
	select.chosen.connect(_start_match)

	# câmera provisória no spawn até a escolha da classe
	lobby_cam = Camera2D.new()
	lobby_cam.position = SPAWN
	add_child(lobby_cam)
	lobby_cam.make_current()

	# atalho p/ testes headless: godot --path . ++ --class=1|2|3
	var args := OS.get_cmdline_user_args()
	for i in 3:
		if args.has("--class=%d" % (i + 1)):
			select.queue_free()
			_start_match(i)
			break

func _start_match(cls: int) -> void:
	if cls == 1:
		player = DuelistPlayer.new()
	elif cls == 2:
		player = MagePlayer.new()
	else:
		player = Player.new()
	player.position = SPAWN
	player.died.connect(_on_player_died)
	add_child(player)
	player.camera.make_current()
	if lobby_cam != null:
		lobby_cam.queue_free()
		lobby_cam = null

func _build_walls() -> void:
	var t := 60.0
	_wall(Rect2(-t, -t, ARENA.size.x + 2.0 * t, t))
	_wall(Rect2(-t, ARENA.size.y, ARENA.size.x + 2.0 * t, t))
	_wall(Rect2(-t, 0.0, t, ARENA.size.y))
	_wall(Rect2(ARENA.size.x, 0.0, t, ARENA.size.y))

func _wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	body.position = rect.position + rect.size / 2.0
	body.add_child(shape)
	add_child(body)

## Um camp = território + bandeira + UM guardião (melee ou atirador).
func _spawn_camp(pos: Vector2, tier: int, melee: bool) -> void:
	var tier_colors: Array[Color] = [Palette.ENEMY_T1, Palette.ENEMY_T2, Palette.ENEMY_T3]
	var territory := CampTerritory.new()
	territory.setup(pos, Enemy.TERRITORY, tier_colors[tier - 1])
	add_child(territory)
	var flag := Flag.new()
	flag.position = pos
	add_child(flag)
	var guardian: Enemy = MeleeEnemy.new(tier) if melee else Enemy.new(tier)
	guardian.camp_center = pos
	guardian.position = pos + Vector2(0.0, -140.0)
	add_child(guardian)

func _on_player_died() -> void:
	respawn_timer = RESPAWN_DELAY

func _process(delta: float) -> void:
	if player != null and respawn_timer > 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			player.respawn(SPAWN)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1:
			if Game.scheme == Game.Scheme.WASD:
				Game.scheme = Game.Scheme.MOUSE
			else:
				Game.scheme = Game.Scheme.WASD
		elif event.physical_keycode == KEY_R and Game.state == Game.GState.WON:
			get_tree().reload_current_scene()

func _draw() -> void:
	# além-muro: chão liso e mais escuro, SEM grade — grade sugere área
	# caminhável e ali não é
	draw_rect(ARENA.grow(APRON), Palette.BG_OUTER)
	# arena jogável
	draw_rect(ARENA, Palette.BG_FLOOR)
	for i in range(1, int(ARENA.size.x / GRID_STEP)):
		var x := i * GRID_STEP
		draw_line(Vector2(x, 0.0), Vector2(x, ARENA.size.y), Palette.GRID, 1.0)
	for i in range(1, int(ARENA.size.y / GRID_STEP)):
		var y := i * GRID_STEP
		draw_line(Vector2(0.0, y), Vector2(ARENA.size.x, y), Palette.GRID, 1.0)
	# muralha sólida (coincide com as paredes físicas)
	var t := WALL_THICK
	draw_rect(Rect2(ARENA.position - Vector2(t, t),
		Vector2(ARENA.size.x + 2.0 * t, t)), Palette.WALL)
	draw_rect(Rect2(Vector2(ARENA.position.x - t, ARENA.end.y),
		Vector2(ARENA.size.x + 2.0 * t, t)), Palette.WALL)
	draw_rect(Rect2(ARENA.position - Vector2(t, 0.0),
		Vector2(t, ARENA.size.y)), Palette.WALL)
	draw_rect(Rect2(Vector2(ARENA.end.x, ARENA.position.y),
		Vector2(t, ARENA.size.y)), Palette.WALL)
	# fio de luz na face interna da muralha
	draw_rect(ARENA, Color(Palette.WHITE, 0.18), false, 2.0)
