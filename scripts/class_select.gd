class_name ClassSelect
extends Control
## Tela de seleção de classe (início da partida): 1 = Atirador, 2 = Duelista.

signal chosen(cls: int)

var anim := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	anim += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_1:
			chosen.emit(0)
			queue_free()
		elif k == KEY_2:
			chosen.emit(1)
			queue_free()
		elif k == KEY_3:
			chosen.emit(2)
			queue_free()

func _draw() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.78))
	draw_string(font, Vector2(0.0, vp.y * 0.24), "ESCOLHA SUA CLASSE",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 34, Palette.WHITE)

	var cw := 300.0
	var ch := 275.0
	var gap := 30.0
	var top := vp.y * 0.32
	var left := vp.x / 2.0 - cw * 1.5 - gap
	var pulse := 0.55 + 0.35 * absf(sin(anim * 2.5))
	_card(Rect2(left, top, cw, ch), "1", "ATIRADOR",
		Palette.PLAYER, [
			"Energia regenera sozinha",
			"Pistola laser (clique esq.)",
			"Q  Dash evasivo",
			"E  Raio que atravessa + lentidão",
			"R  Pulso repulsor (empurra)",
			"F  Explosão carregada",
		], pulse, font)
	_card(Rect2(left + cw + gap, top, cw, ch), "2", "DUELISTA",
		Palette.STAMINA, [
			"Fôlego carrega ACERTANDO golpes",
			"Combo de lâmina 1-2-3 (clique esq.)",
			"Q  Avanço cortante (abate reseta)",
			"E  Aparar: bloqueia e atordoa",
			"R  Gancho que puxa o inimigo",
			"F  Execução (consome fôlego)",
		], pulse, font)
	_card(Rect2(left + (cw + gap) * 2.0, top, cw, ch), "3", "MAGO",
		Palette.ARCANE, [
			"Fluxo regenera só PARADO • 75 HP",
			"Orbe arcano que atravessa",
			"Q  Sentinela autônoma (máx. 2)",
			"E  Campo gravitacional (lentidão)",
			"R  Translocar (teleporte)",
			"F  Cataclismo (detona após 1s)",
		], pulse, font)
	draw_string(font, Vector2(0.0, top + ch + 52.0),
		"Pressione [1], [2] ou [3]", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 18,
		Color(Palette.WHITE, pulse))

func _card(r: Rect2, key: String, title: String, col: Color, lines: Array,
		pulse: float, font: Font) -> void:
	draw_rect(r, Color(col, 0.06))
	draw_rect(r, Color(col, 0.35 + 0.3 * pulse), false, 2.0)
	draw_string(font, Vector2(r.position.x, r.position.y + 40.0), "[%s]" % key,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, Color(col, 0.9))
	draw_string(font, Vector2(r.position.x, r.position.y + 74.0), title,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, Palette.WHITE)
	for i in lines.size():
		# a primeira linha é a filosofia do recurso — destacada na cor da classe
		var line_col := Color(col, 0.95) if i == 0 else Color(Palette.WHITE, 0.75)
		draw_string(font, Vector2(r.position.x + 18.0, r.position.y + 108.0 + i * 24.0),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36.0, 12, line_col)
