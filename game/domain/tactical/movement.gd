class_name MovementSystem extends RefCounted

## Per-character movement step planner.
##
## Eight directions. Speeds:
##   1x → 1.0 seconds per grid step (3.2 cells/sec design target).
##   2x → 0.5 seconds per grid step. Rejected when alert state is on.
##
## Holds a small ordered queue of steps the agent will take; the renderer /
## controller drains it. to_dict / from_dict supports undo / replay.

const _PATH: String = "res://game/domain/tactical/movement.gd"

const ALLOWED_SPEED: Array = [1, 2]

const SECONDS_PER_STEP_1X: float = 1.0
const SECONDS_PER_STEP_2X: float = 0.5

var _steps: Array = []   # Array[Vector2i]
var _cursor: int = 0     # index of next step to be consumed
var _speed: int = 1
var _alert: bool = false

func _init() -> void:
	_steps = []
	_cursor = 0
	_speed = 1
	_alert = false

func is_alerted() -> bool:
	return _alert

func get_speed() -> int:
	return _speed

func set_speed(s: int) -> void:
	if s in ALLOWED_SPEED:
		_speed = s

func set_alert(on: bool) -> void:
	_alert = on
	if on and _speed == 2:
		_speed = 1

# Attempt to set speed; return whether the request was honored.
# (alert state forbids 2x).
func request_speed(s: int, alert: bool) -> bool:
	# Set alert state from this request — caller is the source of truth.
	_alert = alert
	if s == 2 and _alert:
		return false
	if not (s in ALLOWED_SPEED):
		return false
	_speed = s
	return true

func reset_steps() -> void:
	_steps = []
	_cursor = 0

# Plan a path (Array[Vector2i]) and queue every step after the first cell
# (start cell is already the agent's current position).
func plan_path(path: Array) -> void:
	_steps = []
	_cursor = 0
	if path.size() <= 1:
		return
	# Skip the first cell (current position).
	for i in range(1, path.size()):
		_steps.append(path[i])

func step_count() -> int:
	return _steps.size()

func remaining() -> int:
	var rem: int = _steps.size() - _cursor
	return rem if rem > 0 else 0

func has_more() -> bool:
	return _cursor < _steps.size()

# Consume one step. Returns Vector2i (the destination) or Vector2i(-1,-1) if none.
func pop_next() -> Vector2i:
	if _cursor >= _steps.size():
		return Vector2i(-1, -1)
	var cell: Vector2i = _steps[_cursor]
	_cursor += 1
	return cell

# Seconds until the next step is "due". Caller multiplies by elapsed dt.
func seconds_per_step() -> float:
	if _speed == 2:
		return SECONDS_PER_STEP_2X
	return SECONDS_PER_STEP_1X

func to_dict() -> Dictionary:
	return {
		"speed": _speed,
		"alert": _alert,
		"steps": _steps.duplicate(true),
		"cursor": _cursor,
	}

func from_dict(d: Dictionary) -> void:
	_speed = int(d.get("speed", 1))
	_alert = bool(d.get("alert", false))
	_steps = []
	_cursor = int(d.get("cursor", 0))
	var raw: Variant = d.get("steps", [])
	if typeof(raw) == TYPE_ARRAY:
		for v in (raw as Array):
			if typeof(v) == TYPE_VECTOR2I:
				_steps.append(v)