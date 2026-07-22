extends Control

## Placeholder tactical HUD. Real UI rendering is a Stage 6+ concern; this
## stubs a status bar + pause / speed indicator that the rest of the code
## can poll.

const _PATH: String = "res://game/presentation/ui/hud.gd"

var paused: bool = true
var speed: int = 1
var alert: bool = false

@onready var _status_label: Label = Label.new()

func _ready() -> void:
	_ensure_label()

func _ensure_label() -> void:
	if _status_label != null and is_instance_valid(_status_label) and _status_label.get_parent() == self:
		return
	_status_label = Label.new()
	_status_label.name = "TacticalStatusLabel"
	add_child(_status_label)
	_refresh_label()

func set_paused(p: bool) -> void:
	paused = p
	_refresh_label()

func set_speed(s: int) -> void:
	speed = s
	_refresh_label()

func set_alert(on: bool) -> void:
	alert = on
	if on and speed == 2:
		speed = 1
	_refresh_label()

func _refresh_label() -> void:
	if not is_inside_tree():
		return
	var indicator: String = "PAUSE" if paused else ("2x" if speed == 2 else "1x")
	if alert:
		indicator += "  ALERT"
	_ensure_label()
	_status_label.text = "[Tactical] " + indicator

func get_status_line() -> String:
	var indicator: String = "PAUSE" if paused else ("2x" if speed == 2 else "1x")
	if alert:
		indicator += "  ALERT"
	return "[Tactical] " + indicator