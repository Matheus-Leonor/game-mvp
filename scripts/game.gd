extends Node
## Autoload "Game": estado global da partida (bandeiras, vitória).

enum GState { PLAYING, WON }
enum Scheme { WASD, MOUSE }

signal flags_changed(count: int)
signal won

const FLAGS_TOTAL := 3

var state: GState = GState.PLAYING
var flags_captured := 0
## Esquema de controle (F1 alterna; sobrevive ao restart pois é autoload).
var scheme: Scheme = Scheme.WASD
## Definido pelo Main no _ready; usado pelo minimapa do HUD.
var arena := Rect2()
## Rastreio das veias de energia: guardiões "sentem" o jogador sobre elas.
var _vein_frame := -100

func mark_player_on_vein() -> void:
	_vein_frame = int(Engine.get_physics_frames())

func is_player_on_vein() -> bool:
	return int(Engine.get_physics_frames()) - _vein_frame <= 2

func reset() -> void:
	state = GState.PLAYING
	flags_captured = 0

func capture_flag() -> void:
	flags_captured += 1
	flags_changed.emit(flags_captured)
	if all_flags():
		win()

func all_flags() -> bool:
	return flags_captured >= FLAGS_TOTAL

func win() -> void:
	if state == GState.PLAYING:
		state = GState.WON
		won.emit()
