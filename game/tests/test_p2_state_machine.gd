extends SceneTree

## Module A smoke: state machine + morning report.
## Exits with code 0 on full success, 1 on any failure.
## Uses Script constants only (no class_name globals).

const StateMachineScript: GDScript = preload("res://game/application/state_machine.gd")
const MorningReportScript: GDScript = preload("res://game/application/morning_report.gd")
const GameSessionScript: GDScript = preload("res://game/core/game_session.gd")
const RngServiceScript: GDScript = preload("res://game/core/rng_service.gd")
const ClockScript: GDScript = preload("res://game/core/clock.gd")

var _fail_count: int = 0
var _pass_count: int = 0

func _initialize() -> void:
	print("=== test_p2_state_machine start ===")
	_test_state_machine_initial()
	_test_state_machine_advance_one()
	_test_state_machine_full_day_cycles_through_states()
	_test_state_machine_night_resolve_increments_day()
	_test_state_machine_enter_exit_hooks()
	_test_state_machine_to_from_dict()
	_test_morning_report_minimal_session()
	_test_morning_report_with_prev_summary()
	print("=== test_p2_state_machine result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

func _test_state_machine_initial() -> void:
	print("[1] initial state = MORNING_REPORT day=1")
	var sm: RefCounted = StateMachineScript.new()
	_expect(sm.current_state == 0, "MORNING_REPORT is state 0")
	_expect(sm.day == 1, "starts day 1")

func _test_state_machine_advance_one() -> void:
	print("[2] advance_steps(1)")
	var sm: RefCounted = StateMachineScript.new()
	sm.advance_steps(1)
	_expect(sm.current_state == 1, "next state is BASE_PLANNING (1)")

func _test_state_machine_full_day_cycles_through_states() -> void:
	print("[3] run_full_day visits all 6 states")
	var sm: RefCounted = StateMachineScript.new()
	var counts: Dictionary = sm.run_full_day()
	var visited: int = 0
	for k in counts.keys():
		visited += int(counts[k])
	_expect(visited == 6, "6 transitions recorded (got %d)" % visited)
	_expect(sm.current_state == 5, "ends at NIGHT_RESOLVE (5)")

func _test_state_machine_night_resolve_increments_day() -> void:
	print("[4] NIGHT_RESOLVE -> MORNING_REPORT auto-rolls day")
	var sm: RefCounted = StateMachineScript.new()
	sm.run_full_day()
	# After run_full_day, current_state is MORNING_REPORT (day rolled over).
	# run_full_day ends at NIGHT_RESOLVE; the hook chain (or
	# run_full_day's own transition into MORNING_REPORT) auto-rolled day.
	# If current_state is still NIGHT_RESOLVE, manually transition.
	if sm.current_state != sm.State.MORNING_REPORT:
		sm.transition_to(sm.State.MORNING_REPORT)
	_expect(sm.day == 2, "day auto-rolled from 1 to 2 (got %d)" % sm.day)
	# Roll again — now we're at MORNING, going around the cycle.
	# Manually drive transitions: MORNING -> ... -> NIGHT_RESOLVE -> MORNING.
	for s in [1, 2, 3, 4, 5, 0]:
		sm.transition_to(s)
	_expect(sm.day == 3, "day advanced to 3 after second full cycle (got %d)" % sm.day)

func _test_state_machine_enter_exit_hooks() -> void:
	print("[5] enter/exit hooks fire")
	var sm: RefCounted = StateMachineScript.new()
	var entered: Array = []
	var exited: Array = []
	sm.on_enter(1, func(_s, _d, _p): entered.append("base_planning"))
	sm.on_exit(0, func(_s, _d, _p): exited.append("morning_report"))
	sm.advance_steps(1)
	_expect(entered.size() == 1, "BASE_PLANNING entered 1x")
	_expect(exited.size() == 1, "MORNING_REPORT exited 1x")

func _test_state_machine_to_from_dict() -> void:
	print("[6] to_dict/from_dict round-trip")
	var sm: RefCounted = StateMachineScript.new()
	sm.transition_to(2)
	sm.transition_to(3)
	var snap: Dictionary = sm.to_dict()
	var sm2: RefCounted = StateMachineScript.new()
	sm2.from_dict(snap)
	_expect(sm2.current_state == sm.current_state, "current_state preserved")
	_expect(sm2.day == sm.day, "day preserved")

func _test_morning_report_minimal_session() -> void:
	print("[7] MorningReport.build with minimal session")
	var s: RefCounted = GameSessionScript.new()
	s.new_game(42, "res://content")
	var mr: RefCounted = MorningReportScript.new()
	var rep: Dictionary = mr.build(s, {})
	_expect(int(rep.get("day", 0)) == 1, "day == 1")
	_expect(typeof(rep.get("summary_text", "")) == TYPE_STRING and (rep["summary_text"] as String).length() > 0, "summary_text non-empty")
	_expect(typeof(rep.get("consumed", null)) == TYPE_DICTIONARY, "consumed is dict")
	for k in ["food", "water", "material", "parts", "medical", "fuel", "ammo"]:
		_expect((rep["consumed"] as Dictionary).has(k), "consumed has key %s" % k)

func _test_morning_report_with_prev_summary() -> void:
	print("[8] MorningReport.build with prev_day_summary")
	var s: RefCounted = GameSessionScript.new()
	s.new_game(42, "res://content")
	var prev: Dictionary = {
		"consumed": {"food": 8, "water": 12, "material": 0, "parts": 1, "medical": 0, "fuel": 2, "ammo": 0},
		"produced": {"food": 4, "water": 6, "material": 0, "parts": 0, "medical": 0, "fuel": 0, "ammo": 0},
		"injuries": [{"character_id": "c_alex", "kind": "bleed", "severity": 1}],
		"infections": [],
		"events": [{"id": "evt_first_night_decision", "title_zh": "第一夜", "kind": "decision"}],
		"relationships": [{"a": "c_alex", "b": "c_bo", "axis": "trust", "delta": 1.0}],
	}
	var mr: RefCounted = MorningReportScript.new()
	var rep: Dictionary = mr.build(s, prev)
	_expect(int((rep["consumed"] as Dictionary).get("food", 0)) == 8, "consumed.food echoed")
	_expect(int((rep["produced"] as Dictionary).get("food", 0)) == 4, "produced.food echoed")
	_expect(int((rep["injuries"] as Array).size()) == 1, "injuries echoed")
	_expect(int((rep["events"] as Array).size()) == 1, "events echoed")
	_expect((rep["summary_text"] as String).find("Day") >= 0, "summary text contains Day")