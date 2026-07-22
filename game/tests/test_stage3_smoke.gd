extends SceneTree

## Stage 3 headless smoke test.
## Exits with code 0 on full success, 1 on any failure.
## All type annotations go through Script constants so the script can be
## loaded via --script before the global class registry is built.

const _PATH: String = "res://_stage3_smoke.gd"

const CommandResultScript: GDScript = preload("res://game/core/command_result.gd")
const RngServiceScript: GDScript = preload("res://game/core/rng_service.gd")
const ClockScript: GDScript = preload("res://game/core/clock.gd")
const ContentDBScript: GDScript = preload("res://game/core/content_db.gd")
const GameSessionScript: GDScript = preload("res://game/core/game_session.gd")
const AtomicWriteScript: GDScript = preload("res://game/adapters/saves/atomic_write.gd")
const SaveV1Script: GDScript = preload("res://game/adapters/saves/save_v1.gd")
const EventInterpreterScript: GDScript = preload("res://game/domain/events/interpreter.gd")
const DirectorScript: GDScript = preload("res://game/domain/events/director.gd")

var _fail_count: int = 0
var _pass_count: int = 0

func _initialize() -> void:
	print("=== Stage 3 smoke test start ===")
	_test_command_result()
	_test_rng_determinism()
	_test_rng_streams_independent()
	_test_rng_to_dict_round_trip()
	_test_clock()
	_test_content_db()
	_test_game_session_lifecycle()
	_test_game_session_transaction_rollback()
	_test_atomic_write_and_verify()
	_test_atomic_write_bak_recovery()
	_test_save_v1_round_trip()
	_test_event_interpreter_unknown_op_rejected()
	_test_event_interpreter_basic_apply()
	_test_event_interpreter_conditions()
	_test_director_placeholder()
	print("=== Stage 3 smoke test result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

func _test_command_result() -> void:
	print("[1] CommandResult")
	var cr_ok: RefCounted = CommandResultScript.ok("hi", {"x": 1})
	_expect(cr_ok.is_ok(), "ok status")
	var cr_fail: RefCounted = CommandResultScript.fail("nope")
	_expect(cr_fail.is_fail(), "fail status")
	var cr_rej: RefCounted = CommandResultScript.rejected("invalid")
	_expect(cr_rej.is_rejected(), "rejected status")
	var d: Dictionary = cr_ok.to_dict()
	var cr2: RefCounted = CommandResultScript.from_dict(d)
	_expect(cr2.status == cr_ok.status and cr2.message == cr_ok.message, "round-trip to_dict/from_dict")

func _test_rng_determinism() -> void:
	print("[2] RngService determinism")
	var a: RefCounted = RngServiceScript.new()
	var b: RefCounted = RngServiceScript.new()
	a.seed(42)
	b.seed(42)
	for i in range(1000):
		var av: int = a.get_rng(RngServiceScript.STREAM_WORLD)
		var bv: int = b.get_rng(RngServiceScript.STREAM_WORLD)
		if av != bv:
			_expect(false, "identical seed identical draws @ " + str(i))
			return
	_expect(true, "identical seed produces identical 1000 draws")
	_expect(a.to_dict().hash() == b.to_dict().hash(), "post-draw state hashes equal")

func _test_rng_streams_independent() -> void:
	print("[3] RngService stream independence")
	var r: RefCounted = RngServiceScript.new()
	r.seed(7)
	var w_first: int = r.get_rng(RngServiceScript.STREAM_WORLD)
	var c_first: int = r.get_rng(RngServiceScript.STREAM_CITY)
	var r2: RefCounted = RngServiceScript.new()
	r2.seed(7)
	var c_first2: int = r2.get_rng(RngServiceScript.STREAM_CITY)
	var w_first2: int = r2.get_rng(RngServiceScript.STREAM_WORLD)
	_expect(w_first == w_first2, "world stream draw order-independent (same seed)")
	_expect(c_first == c_first2, "city stream draw order-independent (same seed)")

func _test_rng_to_dict_round_trip() -> void:
	print("[4] RngService to_dict round-trip")
	var r: RefCounted = RngServiceScript.new()
	r.seed(123)
	for i in range(50):
		r.get_rng(RngServiceScript.STREAM_WORLD)
		r.get_rng(RngServiceScript.STREAM_CITY)
	var snap: Dictionary = r.to_dict()
	var r2: RefCounted = RngServiceScript.new()
	r2.from_dict(snap)
	_expect(r.to_dict().hash() == r2.to_dict().hash(), "to_dict/from_dict stable")

func _test_clock() -> void:
	print("[5] Clock")
	var c: RefCounted = ClockScript.new()
	_expect(c.current_day == 1 and c.city_minutes == 360, "initial state")
	c.tick(ClockScript.TimeScale.CAMPAIGN_DAY, 3.0)
	_expect(c.current_day == 4, "tick campaign_day +3")
	c.tick(ClockScript.TimeScale.CITY_CLOCK, 30.0)
	_expect(c.city_minutes == 390, "tick city_clock +30 min")
	c.set_time_of_day(23, 59)
	_expect(c.city_minutes == 23 * 60 + 59, "set_time_of_day 23:59")
	c.tick(ClockScript.TimeScale.CITY_CLOCK, 5.0)
	_expect(c.city_minutes == 4, "city minutes wrap")
	var snap: Dictionary = c.to_dict()
	var c2: RefCounted = ClockScript.new()
	c2.from_dict(snap)
	_expect(c2.current_day == c.current_day and c2.city_minutes == c.city_minutes, "clock round-trip")

func _test_content_db() -> void:
	print("[6] ContentDB")
	var db: RefCounted = ContentDBScript.new()
	var err: int = db.load_all("res://content")
	_expect(err == OK, "load_all returns OK (err=" + str(err) + ")")
	_expect(db.get_fingerprint() != "", "fingerprint non-empty")
	var w: Variant = db.get_record("items", "itm_water_bottle")
	_expect(typeof(w) == TYPE_DICTIONARY, "loaded sample_water_bottle")
	var missing: Variant = db.get_record("items", "does_not_exist")
	_expect(missing == null, "missing returns null")

func _test_game_session_lifecycle() -> void:
	print("[7] GameSession lifecycle")
	var s: RefCounted = GameSessionScript.new()
	var r: RefCounted = s.new_game(2026, "res://content")
	_expect(r.is_ok(), "new_game ok")
	_expect(s.clock.current_day == 1, "starts at day 1")
	var fr: RefCounted = s.issue_command({"kind": "set_flag", "flag": "intro_done", "value": true})
	_expect(fr.is_ok(), "set_flag ok")
	_expect(s.base_state["flags"]["intro_done"] == true, "flag persisted in base_state")
	var fr2: RefCounted = s.issue_command({"kind": "set_flag", "flag": "BAD FLAG!", "value": true})
	_expect(fr2.is_rejected(), "invalid flag name rejected")
	_expect(s.base_state["flags"].get("BAD FLAG!", null) == null, "invalid flag NOT persisted")
	var fr3: RefCounted = s.issue_command({"kind": "advance_day", "days": 2})
	_expect(fr3.is_ok() and s.clock.current_day == 3, "advance_day +2")

func _test_game_session_transaction_rollback() -> void:
	print("[8] GameSession transactional rollback")
	var s: RefCounted = GameSessionScript.new()
	s.new_game(99, "res://content")
	s.issue_command({"kind": "set_flag", "flag": "ok_flag", "value": true})
	var before: Dictionary = s.to_dict()
	var fr: RefCounted = s.issue_command({"kind": "set_flag", "flag": "", "value": true})
	_expect(fr.is_rejected(), "empty flag rejected")
	_expect(s.to_dict().hash() == before.hash(), "state unchanged after rejected cmd")

func _test_atomic_write_and_verify() -> void:
	print("[9] AtomicWrite write+verify")
	var tmp_path: String = "user://_stage3_smoke_save.dat"
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)
	if FileAccess.file_exists(tmp_path + ".bak"):
		DirAccess.remove_absolute(tmp_path + ".bak")
	if FileAccess.file_exists(tmp_path + ".meta"):
		DirAccess.remove_absolute(tmp_path + ".meta")
	var bytes: PackedByteArray = "hello aftermap save v1".to_utf8_buffer()
	var err: int = AtomicWriteScript.write_atomic(tmp_path, bytes)
	_expect(err == OK, "write_atomic OK (err=" + str(err) + ")")
	_expect(AtomicWriteScript.verify(tmp_path), "verify after write")
	_expect(not FileAccess.file_exists(tmp_path + ".bak"), "no .bak on first write")

func _test_atomic_write_bak_recovery() -> void:
	print("[10] AtomicWrite .bak recovery")
	var tmp_path: String = "user://_stage3_smoke_save.dat"
	var first: PackedByteArray = "first-good-save".to_utf8_buffer()
	AtomicWriteScript.write_atomic(tmp_path, first)
	_expect(AtomicWriteScript.verify(tmp_path), "verify first save")
	var second: PackedByteArray = "second-newer-save".to_utf8_buffer()
	AtomicWriteScript.write_atomic(tmp_path, second)
	_expect(AtomicWriteScript.verify(tmp_path), "verify second save")
	_expect(AtomicWriteScript.verify(tmp_path + ".bak"), "verify .bak is the first good copy")
	var bad: PackedByteArray = "TAMPERED".to_utf8_buffer()
	var bf: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	bf.store_buffer(bad)
	bf.close()
	_expect(not AtomicWriteScript.verify(tmp_path), "tampered live file fails verify")
	var recovered: PackedByteArray = AtomicWriteScript.load_or_recover(tmp_path)
	_expect(recovered == first, "load_or_recover returns .bak content")

func _test_save_v1_round_trip() -> void:
	print("[11] SaveV1 round-trip")
	var s: RefCounted = GameSessionScript.new()
	s.new_game(4242, "res://content")
	s.issue_command({"kind": "set_flag", "flag": "saved_once", "value": true})
	s.issue_command({"kind": "advance_day", "days": 5})
	var path: String = "user://_stage3_smoke_save_v1.dat"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err: int = SaveV1Script.save(s, path)
	_expect(err == OK, "SaveV1.save ok")
	var loaded: RefCounted = SaveV1Script.load(path)
	_expect(loaded != null, "SaveV1.load returns session")
	_expect(loaded.clock.current_day == s.clock.current_day, "clock round-trip")
	_expect(loaded.base_state["flags"].get("saved_once", null) == true, "flag round-trip")
	_expect(loaded.save_meta.get("seed", 0) == 4242, "seed round-trip")
	var s2: RefCounted = GameSessionScript.new()
	var newr: RefCounted = s2.new_game(4242, "res://content")
	if not newr.is_ok():
		print("  WARN: s2.new_game failed: ", newr.message)
	s2.issue_command({"kind": "set_flag", "flag": "saved_once", "value": true})
	s2.issue_command({"kind": "advance_day", "days": 5})
	# Determinism: RNG and clock should match (save_meta's updated_at uses wall clock,
	# which is the same within one process run).
	# Dictionary equality is order-independent in Godot 4 (matches semantically);
	# only hash() is order-sensitive.
	var rng_a: Dictionary = loaded.rng.to_dict()
	var rng_b: Dictionary = s2.rng.to_dict()
	var rng_match: bool = rng_a.size() == rng_b.size()
	if rng_match:
		for k in rng_a.keys():
			if not rng_b.has(k) or (rng_a[k] as Array) != (rng_b[k] as Array):
				rng_match = false
				break
	var clock_match: bool = loaded.clock.current_day == s2.clock.current_day and loaded.clock.city_minutes == s2.clock.city_minutes
	var base_a: Dictionary = loaded.base_state
	var base_b: Dictionary = s2.base_state
	var base_match: bool = _dict_equal_normalized(base_a, base_b)
	_expect(rng_match, "save/load determinism: RNG state identical")
	_expect(clock_match, "save/load determinism: clock identical")
	_expect(base_match, "save/load determinism: base_state identical")

func _dict_equal_normalized(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a.keys():
		if not b.has(k):
			return false
		var va = a[k]
		var vb = b[k]
		var ta: int = typeof(va)
		var tb: int = typeof(vb)
		if ta != tb:
			# allow int/float mismatch by promoting both to float
			if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
				if float(va) != float(vb):
					return false
				continue
			if ta == TYPE_DICTIONARY and tb == TYPE_DICTIONARY:
				if not _dict_equal_normalized(va, vb):
					return false
				continue
			if ta == TYPE_ARRAY and tb == TYPE_ARRAY:
				if (va as Array) != (vb as Array):
					return false
				continue
			return false
		else:
			if ta == TYPE_DICTIONARY:
				if not _dict_equal_normalized(va, vb):
					return false
			elif ta == TYPE_ARRAY:
				if (va as Array) != (vb as Array):
					return false
			else:
				if va != vb:
					return false
	return true

func GameSessionSession_check() -> RefCounted:
	return null

func _test_event_interpreter_unknown_op_rejected() -> void:
	print("[12] EventInterpreter unknown op rejected")
	var s: RefCounted = GameSessionScript.new()
	s.new_game(1, "res://content")
	var interp: RefCounted = EventInterpreterScript.new()
	var bad: Dictionary = {"op": "exec_arbitrary", "code": "delete_files()"}
	var r: RefCounted = interp.apply_effect(bad, s)
	_expect(r.is_rejected(), "unknown effect op -> REJECTED")
	_expect(String(r.message).begins_with("unknown_op:"), "rejection message has unknown_op prefix")

func _test_event_interpreter_basic_apply() -> void:
	print("[13] EventInterpreter basic effect apply")
	var s: RefCounted = GameSessionScript.new()
	s.new_game(2, "res://content")
	var interp: RefCounted = EventInterpreterScript.new()
	var r: RefCounted = interp.apply_effect({"op": "set_flag", "flag": "door_open", "value": true}, s)
	_expect(r.is_ok(), "set_flag effect applied")
	_expect(s.base_state["flags"]["door_open"] == true, "door_open flag visible in base_state")

func _test_event_interpreter_conditions() -> void:
	print("[14] EventInterpreter conditions")
	var s: RefCounted = GameSessionScript.new()
	s.new_game(3, "res://content")
	var interp: RefCounted = EventInterpreterScript.new()
	s.issue_command({"kind": "set_flag", "flag": "ready", "value": true})
	_expect(interp.evaluate_condition({"op": "flag_has", "flag": "ready", "value": true}, s) == true, "flag_has true")
	_expect(interp.evaluate_condition({"op": "flag_has", "flag": "missing", "value": true}, s) == false, "flag_has false for absent")
	_expect(interp.evaluate_condition({"op": "time_in_range", "day_from": 1, "day_to": 99}, s) == true, "time_in_range true")
	_expect(interp.evaluate_condition({"op": "exec_arbitrary"}, s) == false, "unknown condition fails closed")

func _test_director_placeholder() -> void:
	print("[15] Director placeholder")
	var s: RefCounted = GameSessionScript.new()
	s.new_game(4, "res://content")
	var d: RefCounted = DirectorScript.new()
	var pick: StringName = d.pick_event_for_day(1, s)
	_expect(pick == &"", "placeholder returns empty pick")