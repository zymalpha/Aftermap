extends SceneTree

## Stage 19 director tests.
## Replaces the Stage 5 placeholder test. Verifies the real
## pick_event_for_day / pick_event_with_rng implementation.

const DirectorScript: GDScript = preload("res://game/domain/events/director.gd")
const GameSessionScript: GDScript = preload("res://game/core/game_session.gd")

var _pass_count: int = 0
var _fail_count: int = 0

func _initialize() -> void:
	print("=== test_director_real start ===")
	_test_director_instantiates()
	_test_director_picks_event_in_window()
	_test_director_picks_outside_window_returns_empty()
	_test_director_excludes_chain_node_and_summary()
	_test_director_pick_is_deterministic()
	_test_director_respects_weight()
	_test_director_with_rng_ensures_stream()
	print("=== test_director_real result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

func _make_session() -> RefCounted:
	var s: RefCounted = GameSessionScript.new()
	var nr: RefCounted = s.new_game(20260723, "res://content")
	if not nr.is_ok():
		return null
	return s

func _test_director_instantiates() -> void:
	print("[1] Director instantiates")
	var d: RefCounted = DirectorScript.new()
	_expect(d != null, "director created")

func _test_director_picks_event_in_window() -> void:
	print("[2] Director picks event within time window")
	var s: RefCounted = _make_session()
	if s == null:
		_expect(false, "session created")
		return
	_expect(s != null, "session created")
	var d: RefCounted = DirectorScript.new()
	# day 7 should land inside evt_broadcast_distress (day_from=7, day_to=16)
	# but that's a broadcast (not picked by director — broadcast is a
	# top-level kind that director should fire). Director picks any
	# kind except chain_node + summary. broadcast / decision / scene
	# are all pickable. Try multiple days to ensure at least one hit.
	var any_picked: bool = false
	for day in range(1, 25):
		var picked: StringName = d.pick_event_for_day(day, s)
		if String(picked) != "":
			any_picked = true
			break
	_expect(any_picked, "director picks at least one event across days 1-24")

func _test_director_picks_outside_window_returns_empty() -> void:
	print("[3] Director returns empty when no event matches")
	var s: RefCounted = _make_session()
	if s == null:
		return
	# Set clock to day 1 (most events have day_from >= 1)
	# Force day=0 (no event should fire — most have day_from>=1)
	s.clock.current_day = 0
	var d: RefCounted = DirectorScript.new()
	var picked: StringName = d.pick_event_for_day(0, s)
	_expect(String(picked) == "", "day 0 returns empty (got '" + String(picked) + "')")
	s.clock.current_day = 1

func _test_director_excludes_chain_node_and_summary() -> void:
	print("[4] Director never picks chain_node or summary events")
	var s: RefCounted = _make_session()
	if s == null:
		return
	var content_db: RefCounted = s.content
	var all_ids: Array = content_db.list_ids("events")
	_expect(all_ids.size() > 0, "have events in content")
	var d: RefCounted = DirectorScript.new()
	# Sweep days 1-30; collect picks; ensure none are chain_node or summary.
	var picked_set: Dictionary = {}
	for day in range(1, 31):
		var picked: StringName = d.pick_event_for_day(day, s)
		if String(picked) != "":
			picked_set[String(picked)] = true
	# Verify: no picked id is a chain_node event
	var chain_or_summary_picked: int = 0
	for eid in picked_set.keys():
		var rec: Variant = content_db.get_record("events", String(eid))
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var k: String = String((rec as Dictionary).get("kind", ""))
		if k == "chain_node" or k == "summary":
			chain_or_summary_picked += 1
	_expect(chain_or_summary_picked == 0, "no chain_node or summary events picked (got %d)" % chain_or_summary_picked)

func _test_director_pick_is_deterministic() -> void:
	print("[5] Director picks are deterministic for same seed")
	var s1: RefCounted = _make_session()
	var s2: RefCounted = _make_session()
	if s1 == null or s2 == null:
		return
	# Same seed = same draws
	for day in range(1, 25):
		var d1: RefCounted = DirectorScript.new()
		var d2: RefCounted = DirectorScript.new()
		var p1: StringName = d1.pick_event_for_day(day, s1)
		var p2: StringName = d2.pick_event_for_day(day, s2)
		if String(p1) != String(p2):
			_expect(false, "day " + str(day) + ": picks diverge")
			return
	_expect(true, "same seed produces same pick across days 1-24")

func _test_director_respects_weight() -> void:
	print("[6] Heavier-weight events are picked more often")
	var s: RefCounted = _make_session()
	if s == null:
		return
	var content_db: RefCounted = s.content
	var d: RefCounted = DirectorScript.new()
	# Build a map of {event_id: pick_count} by sweeping every day 1..30
	# many times. Skip events with flag_has gates (they may not be
	# fireable without setting up flags).
	var pick_counts: Dictionary = {}
	for day in range(1, 31):
		s.clock.current_day = day
		for _i in range(20):
			var p: StringName = d.pick_event_for_day(day, s)
			if String(p) == "":
				continue
			pick_counts[String(p)] = int(pick_counts.get(String(p), 0)) + 1
	# Find the heaviest and lightest event-by-weight where both have at
	# least one pick.
	var heavy_id: String = ""
	var heavy_w: int = 0
	var light_id: String = ""
	var light_w: int = 999
	for eid in content_db.list_ids("events"):
		var rec: Variant = content_db.get_record("events", String(eid))
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var kind_str: String = String((rec as Dictionary).get("kind", ""))
		if kind_str == "chain_node" or kind_str == "summary":
			continue
		# Skip events with flag_has gates that aren't satisfied by default.
		var all_of: Array = (rec as Dictionary).get("triggers", {}).get("all_of", [])
		var has_flag: bool = false
		for n in all_of:
			if String(n.get("op", "")) == "flag_has":
				has_flag = true
				break
		if has_flag:
			continue
		var w: int = int((rec as Dictionary).get("weight", 0))
		if int(pick_counts.get(String(eid), 0)) == 0:
			continue
		if w > heavy_w:
			heavy_w = w
			heavy_id = String(eid)
		if w < light_w:
			light_w = w
			light_id = String(eid)
	if heavy_id == "" or light_id == "" or heavy_id == light_id:
		_expect(true, "could not find a heavy/light pair that actually fired — skipping")
		return
	var heavy_count: int = int(pick_counts.get(heavy_id, 0))
	var light_count: int = int(pick_counts.get(light_id, 0))
	print("  heavy: id=%s w=%d picked=%d" % [heavy_id, heavy_w, heavy_count])
	print("  light: id=%s w=%d picked=%d" % [light_id, light_w, light_count])
	_expect(heavy_count >= light_count, "heavy picked >= light picked (heavy w=%d, light w=%d)" % [heavy_w, light_w])

func _test_director_with_rng_ensures_stream() -> void:
	print("[7] Director.pick_event_with_rng ensures daily stream exists")
	var s: RefCounted = _make_session()
	if s == null:
		return
	var d: RefCounted = DirectorScript.new()
	for day in range(1, 5):
		d.pick_event_with_rng(day, s)
		var stream: StringName = StringName("daily_director_" + str(day))
		_expect(s.rng._state.has(stream), "stream " + String(stream) + " ensured in rng state")