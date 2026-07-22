class_name PauseQueue extends RefCounted

## Pause / speed / alert-aware command queue used by tactical scenes.
##
## Speed gears:
##   0  → paused (commands queue but never dequeue)
##   1  → normal
##   2  → fast forward (rejected if alert state is on)
##
## Commands are plain Dictionary payloads; this class does not interpret them.

const _PATH: String = "res://game/domain/tactical/command_queue.gd"

const ALLOWED_SPEEDS: Array = [0, 1, 2]

var _paused: bool = true
var _speed: int = 1
var _alert: bool = false
var _queue: Array = []

func _init() -> void:
	_paused = true
	_speed = 1
	_alert = false
	_queue = []

func is_paused() -> bool:
	return _paused

func get_speed() -> int:
	return _speed

func is_alerted() -> bool:
	return _alert

func pending_count() -> int:
	return _queue.size()

func is_empty() -> bool:
	return _queue.is_empty()

func set_paused(p: bool) -> void:
	_paused = p
	if p:
		_speed = 0
	elif _speed == 0:
		_speed = 1

func set_speed(s: int) -> void:
	if s == 0:
		_paused = true
		_speed = 0
		return
	if s == 2 and _alert:
		# ignored; keep current
		return
	if s == 1 or s == 2:
		_paused = false
		_speed = s

func set_alert(on: bool) -> void:
	_alert = on
	if on and _speed == 2:
		_speed = 1

func request_speed(s: int, alert: bool) -> Dictionary:
	if alert:
		_alert = true
	if s == 2 and _alert:
		return {"accepted": false, "reason": "alert_blocked_2x"}
	if s in ALLOWED_SPEEDS:
		set_speed(s)
		return {"accepted": true, "speed": _speed}
	return {"accepted": false, "reason": "invalid_speed"}

func enqueue(cmd: Dictionary) -> void:
	_queue.append(cmd.duplicate(true))

func clear() -> void:
	_queue.clear()

# Returns the next command or empty Dictionary. Refuses to dequeue while paused.
func dequeue() -> Dictionary:
	if _paused:
		return {}
	if _queue.is_empty():
		return {}
	var cmd: Dictionary = _queue.pop_front()
	return cmd

func try_dequeue() -> Dictionary:
	if _paused:
		return {"ok": false, "reason": "paused"}
	if _queue.is_empty():
		return {"ok": false, "reason": "empty"}
	var cmd: Dictionary = _queue.pop_front()
	return {"ok": true, "cmd": cmd}

func peek() -> Dictionary:
	if _queue.is_empty():
		return {}
	return _queue[0]

func to_dict() -> Dictionary:
	return {
		"paused": _paused,
		"speed": _speed,
		"alert": _alert,
		"queue": _queue.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	_paused = bool(d.get("paused", true))
	_speed = int(d.get("speed", 1))
	_alert = bool(d.get("alert", false))
	_queue = []
	var raw: Variant = d.get("queue", [])
	if typeof(raw) == TYPE_ARRAY:
		for v in (raw as Array):
			if typeof(v) == TYPE_DICTIONARY:
				_queue.append((v as Dictionary).duplicate(true))