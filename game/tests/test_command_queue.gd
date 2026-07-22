extends SceneTree

## Stage 4 / P0 spike: command queue (pause + speed + alert blocking).
## 5 queued commands execute in order after un-pause; idempotent.
## 2x speed is denied when the squad is in alert state.

const PauseQueueScript: GDScript = preload("res://game/domain/tactical/command_queue.gd")

var _fail_count: int = 0
var _pass_count: int = 0

func _initialize() -> void:
	print("=== test_command_queue start ===")
	_test_basic_queue_order()
	_test_idempotent_re_execute()
	_test_three_speed_gears()
	_test_alert_blocks_2x()
	_test_rejects_when_paused()
	print("=== test_command_queue result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		quit(1)
	else:
		quit(0)

func _expect(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS  " + label)
	else:
		_fail_count += 1
		printerr("  FAIL  " + label)

func _new_queue() -> RefCounted:
	return PauseQueueScript.new()

func _test_basic_queue_order() -> void:
	print("[1] queue order, 5 commands")
	var q: RefCounted = _new_queue()
	q.set_paused(true)
	var seen: Array = []
	for i in range(5):
		var cmd: Dictionary = {"id": i, "kind": "noop"}
		q.enqueue(cmd)
	# nothing executes while paused
	_expect(q.pending_count() == 5, "5 pending while paused")
	q.set_paused(false)
	while not q.is_empty():
		var cmd: Dictionary = q.dequeue()
		seen.append(int(cmd["id"]))
	_expect(seen.size() == 5, "drained 5")
	var ordered: bool = true
	for i in range(seen.size()):
		if int(seen[i]) != i:
			ordered = false
			break
	_expect(ordered, "executed in enqueue order")

func _test_idempotent_re_execute() -> void:
	print("[2] idempotent re-execute")
	var q: RefCounted = _new_queue()
	q.set_paused(true)
	q.enqueue({"id": 0, "kind": "move", "x": 3, "y": 4})
	q.enqueue({"id": 1, "kind": "move", "x": 5, "y": 6})
	q.set_paused(false)
	var first: Array = []
	for i in range(2):
		var cmd: Dictionary = q.dequeue()
		first.append(cmd.duplicate())
	# Same queue should already be drained; a fresh queue with same commands should
	# produce the same drained sequence (idempotent over identical input).
	var q2: RefCounted = _new_queue()
	q2.set_paused(true)
	q2.enqueue({"id": 0, "kind": "move", "x": 3, "y": 4})
	q2.enqueue({"id": 1, "kind": "move", "x": 5, "y": 6})
	q2.set_paused(false)
	var second: Array = []
	for i in range(2):
		var cmd2: Dictionary = q2.dequeue()
		second.append(cmd2.duplicate())
	_expect(first.size() == 2 and second.size() == 2, "both queues drained twice")
	_expect(first[0]["x"] == second[0]["x"] and first[1]["y"] == second[1]["y"], "identical payloads drain identically")

func _test_three_speed_gears() -> void:
	print("[3] speed gears: 0 (pause) / 1 / 2")
	var q: RefCounted = _new_queue()
	# default is 1
	_expect(q.get_speed() == 1, "default speed = 1")
	q.set_speed(2)
	_expect(q.get_speed() == 2, "set_speed(2)")
	q.set_speed(0)
	_expect(q.is_paused(), "speed 0 == paused")
	_expect(q.get_speed() == 0, "get_speed = 0 when paused")
	q.set_speed(1)
	_expect(not q.is_paused() and q.get_speed() == 1, "speed 1 unpauses")

func _test_alert_blocks_2x() -> void:
	print("[4] alert state forbids 2x")
	var q: RefCounted = _new_queue()
	# start at 1x, then ask 2x while alert: should be denied
	var r2: Dictionary = q.request_speed(2, true)
	_expect(r2["accepted"] == false, "2x denied when alert (start at 1)")
	_expect(q.get_speed() != 2, "speed did NOT become 2 when alert blocks")
	_expect(q.is_alerted() == true, "alert flag set")
	# now turn alert off, 2x ok
	q.set_alert(false)
	var r1: Dictionary = q.request_speed(2, false)
	_expect(r1["accepted"] == true, "2x accepted when not alert")
	_expect(q.get_speed() == 2, "speed actually 2")
	# alert again: 2x is auto-downgraded to 1
	q.set_alert(true)
	_expect(q.get_speed() != 2, "speed auto-downgraded to 1 when alert set")
	# 1x still ok while alert
	var r3: Dictionary = q.request_speed(1, true)
	_expect(r3["accepted"] == true, "1x still accepted while alert")
	_expect(q.get_speed() == 1, "speed is 1")

func _test_rejects_when_paused() -> void:
	print("[5] dequeue rejected while paused")
	var q: RefCounted = _new_queue()
	q.enqueue({"id": 0, "kind": "noop"})
	q.set_paused(true)
	var got: Dictionary = q.try_dequeue()
	_expect(got["ok"] == false, "try_dequeue returns ok=false when paused")
	q.set_paused(false)
	var got2: Dictionary = q.try_dequeue()
	_expect(got2["ok"] == true, "try_dequeue returns ok=true when running")