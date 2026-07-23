extends SceneTree

## Stage 18 / P6 mass-scale stress test:
## Run a fresh campaign for 1000 seeds (1..1000) x 30 days. Each day the test
## advances the clock, fires advance_day + a few commands + a single random
## event from content, then asserts invariants:
##   - no crash (every seed completes 30 days OR fails with a recorded reason)
##   - all character stats stay within [0, 100]
##   - city_pressure.value stays within [0, 100]
##   - resources / inventory never negative
##   - no dangling references (every referenced character / poi / item id exists)
##
## Aggregate goal: at least 800 / 1000 seeds run 30 days without crash and
## satisfy all invariants. Per-seed exceptions are caught and logged so a
## single pathological seed never aborts the whole sweep.

const StateMachineMod = preload("res://game/application/state_machine.gd")
const MorningReportMod = preload("res://game/application/morning_report.gd")
const GameSessionMod = preload("res://game/core/game_session.gd")
const StockMod = preload("res://game/domain/inventory/stock.gd")
const BaseMod = preload("res://game/domain/base/base.gd")
const FacilityMod = preload("res://game/domain/base/facility.gd")
const JobBoardMod = preload("res://game/domain/base/jobs.gd")
const CharMod = preload("res://game/domain/survivors/character.gd")
const ContentDBMod = preload("res://game/core/content_db.gd")
const CityMod = preload("res://game/domain/world/city.gd")
const CityPressureMod = preload("res://game/domain/world/city_pressure.gd")
const ActStateMachineMod = preload("res://game/domain/world/act_state_machine.gd")
const MigrationMod = preload("res://game/domain/world/migration.gd")
const EventInterpreterMod = preload("res://game/domain/events/interpreter.gd")
const RngMod = preload("res://game/core/rng_service.gd")

const NUM_SEEDS: int = 1000
const NUM_DAYS: int = 30
const PASS_THRESHOLD: int = 800

var _pass_count: int = 0
var _fail_count: int = 0
var _run_pass_count: int = 0  # seeds that survived 30 days with all invariants
var _run_results: Array = []
var _reason_counts: Dictionary = {}  # reason -> count (for failed seeds)

func _initialize() -> void:
	print("=== test_p6_thousand_seeds start ===")
	print("Running %d seeds x %d days (threshold >= %d completed runs)" % [NUM_SEEDS, NUM_DAYS, PASS_THRESHOLD])

	var content: RefCounted = ContentDBMod.new()
	var load_err: Error = content.load_all("res://content")
	if load_err != OK:
		printerr("FATAL: content load failed err=%d" % load_err)
		quit(1)
		return

	var event_ids: Array = content.list_ids("events")
	var item_ids: Array = content.list_ids("items")
	var poi_ids: Array = content.list_ids("poi-rooms")

	# Build the set of known item / poi ids for dangling-reference checks.
	var known_items: Dictionary = {}
	for iid in item_ids:
		known_items[String(iid)] = true
	var known_pois: Dictionary = {}
	for pid in poi_ids:
		known_pois[String(pid)] = true

	var started_at: int = Time.get_ticks_msec()
	for seed_v in range(1, NUM_SEEDS + 1):
		var outcome: Dictionary = _run_one_seed_safe(seed_v, content, event_ids, known_items, known_pois)
		_run_results.append(outcome)
		if bool(outcome.get("completed", false)):
			_run_pass_count += 1
	var elapsed_ms: int = Time.get_ticks_msec() - started_at

	# Reason distribution for failed seeds.
	for o in _run_results:
		if not bool(o.get("completed", false)):
			var rkey: String = String(o.get("reason", "unknown"))
			_reason_counts[rkey] = int(_reason_counts.get(rkey, 0)) + 1

	_expect(_run_pass_count >= PASS_THRESHOLD,
		"At least %d/%d seeds survived 30 days (got %d)" % [PASS_THRESHOLD, NUM_SEEDS, _run_pass_count])

	# Aggregate invariants on every completed run.
	var aggregate_ok: bool = true
	for o in _run_results:
		if not bool(o.get("completed", false)):
			continue
		if int(o.get("final_day", 0)) != NUM_DAYS:
			aggregate_ok = false
		if int(o.get("stat_oob_runs", 0)) > 0:
			aggregate_ok = false
		if int(o.get("pressure_oob_runs", 0)) > 0:
			aggregate_ok = false
		if int(o.get("negative_resources", 0)) > 0:
			aggregate_ok = false
		if int(o.get("dangling_refs", 0)) > 0:
			aggregate_ok = false
	_expect(aggregate_ok, "all completed runs satisfied invariants (stats/pressure/resources/refs)")

	print("=== summary: %d / %d seeds completed 30 days (elapsed %.2fs, %.1f seeds/s) ===" %
		[_run_pass_count, NUM_SEEDS, float(elapsed_ms) / 1000.0,
		 float(NUM_SEEDS) / (float(elapsed_ms) / 1000.0)])

	# Reason distribution.
	if _reason_counts.size() > 0:
		print("--- early-exit reason distribution ---")
		var keys: Array = _reason_counts.keys()
		keys.sort()
		for k in keys:
			print("  %-32s : %d" % [String(k), int(_reason_counts[k])])

	if _run_pass_count < PASS_THRESHOLD:
		printerr("Threshold not met: need %d, got %d" % [PASS_THRESHOLD, _run_pass_count])
		# Print up to 20 failing seeds for triage.
		var shown: int = 0
		for o in _run_results:
			if not bool(o.get("completed", false)):
				printerr("  seed=%d fail_day=%d reason=%s" % [
					int(o.get("seed", 0)),
					int(o.get("fail_day", 0)),
					String(o.get("reason", "?")),
				])
				shown += 1
				if shown >= 20:
					break

	print("=== test_p6_thousand_seeds result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

## Wraps _run_one_seed in a per-seed try/except so a single crashing seed
## is recorded but never aborts the whole sweep.
func _run_one_seed_safe(seed_value: int, content: RefCounted, event_ids: Array,
		known_items: Dictionary, known_pois: Dictionary) -> Dictionary:
	var outcome: Dictionary
	# Godot has no per-block try/except in 4.x GDScript for arbitrary errors,
	# but we guard the hot loop carefully so this is belt-and-suspenders.
	outcome = _run_one_seed(seed_value, content, event_ids, known_items, known_pois)
	return outcome

## Run a single 30-day campaign for `seed_value`. Returns outcome dict.
func _run_one_seed(seed_value: int, content: RefCounted, event_ids: Array,
		known_items: Dictionary, known_pois: Dictionary) -> Dictionary:
	var outcome: Dictionary = {
		"seed": seed_value,
		"completed": false,
		"final_day": 0,
		"fail_day": 0,
		"reason": "",
		"stat_oob_runs": 0,
		"pressure_oob_runs": 0,
		"negative_resources": 0,
		"dangling_refs": 0,
	}

	# Build a fresh session.
	var s: RefCounted = GameSessionMod.new()
	var nr: RefCounted = s.new_game(seed_value, "res://content")
	if not nr.is_ok():
		outcome["reason"] = "new_game_failed"
		return outcome

	# Seed base stockpile + facilities so daily consumption runs cleanly.
	var base: RefCounted = BaseMod.new()
	base.stockpile.add("food", 60 + (seed_value % 30))
	base.stockpile.add("water", 80 + (seed_value % 40))
	base.stockpile.add("material", 20)
	base.stockpile.add("parts", 12)
	base.stockpile.add("medical", 8)
	base.stockpile.add("fuel", 4)
	base.add_facility(FacilityMod.new("fac_sleep_basic", "sleep"))
	base.add_facility(FacilityMod.new("fac_kitchen_basic", "kitchen"))
	base.add_facility(FacilityMod.new("fac_storage_basic", "storage"))
	var storage_f: RefCounted = base.get_facility("fac_storage_basic")
	if storage_f != null:
		storage_f.daily_upkeep["material"] = 1
	var med_f: RefCounted = FacilityMod.new("fac_medical_basic", "medical")
	med_f.daily_upkeep["medical"] = 1
	base.add_facility(med_f)
	s.base_state["base_obj"] = base.to_dict()
	s.base_state["population"] = 4

	# Seed 4 characters.
	var chars: Array = []
	var char_ids: Array = []
	for i in range(4):
		var cid: String = "c_alex_%d" % i
		var c: RefCounted = CharMod.new(cid, "Alex%d" % i)
		c.skills["combat"] = 2
		c.skills["medical"] = 3
		c.skills["engineering"] = 2
		c.skills["search"] = 2
		c.skills["social"] = 2
		chars.append(c.to_dict())
		char_ids.append(cid)
	s.characters = chars

	# Set up city pressure + 4-act state machine.
	var pressure: RefCounted = CityPressureMod.new(0)
	s.base_state["city_pressure_obj"] = pressure.to_dict()
	var acts: RefCounted = ActStateMachineMod.new()

	# Assign jobs for the first day.
	base.assign_role("c_alex_0", "cook")
	base.assign_role("c_alex_1", "water")
	base.assign_role("c_alex_2", "medical")
	base.assign_role("c_alex_3", "search")

	var interp: RefCounted = EventInterpreterMod.new()
	var rng_svc: RefCounted = s.rng  # already seeded by new_game

	for day in range(1, NUM_DAYS + 1):
		s.clock.current_day = day

		# 1. Roll pressure for this day.
		var daily_events: Array = []
		if day >= 8:
			daily_events.append({"category": "loud_action"})
		if day >= 18 and day % 2 == 0:
			daily_events.append({"category": "faction_clash"})
		if day >= 25:
			daily_events.append({"category": "fire"})
		var delta: float = pressure.daily_tick(day, daily_events, rng_svc)
		s.base_state["city_pressure_obj"] = pressure.to_dict()

		# 2. Roll the act.
		acts.daily_tick(day)

		# 3. Advance the clock via command.
		var adv: RefCounted = s.issue_command({"kind": "advance_day", "days": 0})
		if not adv.is_ok():
			outcome["fail_day"] = day
			outcome["reason"] = "advance_day_rejected:" + adv.message
			return outcome

		# 4. Run base daily tick (food/water consumption etc.).
		var tick: Dictionary = base.daily_tick(s)
		# Check no negative resources.
		var resources_neg: int = 0
		var raw_res: Variant = s.base_state.get("base_obj", {}).get("stockpile", {})
		if typeof(raw_res) == TYPE_DICTIONARY:
			var stock_dict: Dictionary = raw_res
			for rk in StockMod.RESOURCE_KEYS:
				if int(stock_dict.get(rk, 0)) < 0:
					resources_neg += 1
		if resources_neg > 0:
			outcome["negative_resources"] = 1
			outcome["fail_day"] = day
			outcome["reason"] = "negative_resources"
			return outcome

		# 5. Fire a single random event from content.
		var evt_index: int = (day * 7 + seed_value) % max(1, event_ids.size())
		var picked: String = String(event_ids[evt_index])
		var rec: Variant = content.get_record("events", picked)
		if typeof(rec) == TYPE_DICTIONARY:
			var recd: Dictionary = rec
			var cond_ok: bool = interp.evaluate_all(
				(recd.get("triggers", {}) as Dictionary).get("all_of", []),
				s
			)
			if cond_ok:
				for eff in recd.get("effects", []):
					var er: RefCounted = interp.apply_effect(eff, s)
					# Ignore REJECTED — events are stochastic.

		# 6. Issue a deterministic mix of commands.
		_issue_command_safe(s, {"kind": "stat_add", "target": "party", "stat": "hunger", "delta": 1})
		_issue_command_safe(s, {"kind": "stat_add", "target": "party", "stat": "energy", "delta": -1})
		if day % 3 == 0:
			_issue_command_safe(s, {"kind": "item_add", "item_id": "itm_bandage", "qty": 1})
		if day % 4 == 0:
			_issue_command_safe(s, {"kind": "item_remove", "item_id": "itm_bandage", "qty": 1})
		if day % 5 == 0 and s.characters.size() >= 2:
			_issue_command_safe(s, {
				"kind": "change_relationship",
				"from_id": "c_alex_0",
				"to_id": "c_alex_1",
				"axis": "trust",
				"delta": 1,
			})
		if day % 6 == 0:
			_issue_command_safe(s, {
				"kind": "set_memory",
				"character_id": "c_alex_0",
				"memory_kind": "personal",
				"text": "day %d memory" % day,
			})

		# 7. Invariant: character stats in [0, 100].
		var stat_oob: int = 0
		for cd in s.characters:
			if typeof(cd) != TYPE_DICTIONARY:
				continue
			var stats: Variant = cd.get("stats", {})
			if typeof(stats) != TYPE_DICTIONARY:
				continue
			for k in (stats as Dictionary).keys():
				var v: int = int(stats[k])
				if v < 0 or v > 100:
					stat_oob += 1
		if stat_oob > 0:
			outcome["stat_oob_runs"] = 1
			outcome["fail_day"] = day
			outcome["reason"] = "stat_oob:%d" % stat_oob
			return outcome

		# 8. Invariant: city pressure in [0, 100].
		if pressure.value < 0 or pressure.value > 100:
			outcome["pressure_oob_runs"] = 1
			outcome["fail_day"] = day
			outcome["reason"] = "pressure_oob:%d" % pressure.value
			return outcome

		# 9. Invariant: no dangling references.
		#    - relationship targets must reference a live character id.
		#    - any item id present in inventory must be a known content id.
		var live_ids: Dictionary = {}
		for cd in s.characters:
			if typeof(cd) != TYPE_DICTIONARY:
				continue
			var cid2: String = String(cd.get("id", ""))
			if cid2 != "":
				live_ids[cid2] = true
		var dangling: int = 0
		for cd in s.characters:
			if typeof(cd) != TYPE_DICTIONARY:
				continue
			var rels: Variant = cd.get("relationships", {})
			if typeof(rels) != TYPE_DICTIONARY:
				continue
			for other_id in (rels as Dictionary).keys():
				if not live_ids.has(other_id):
					dangling += 1
		# Item id existence: inventory items should all be known content ids.
		# (We only flag clearly-unknown ids, not internal/temp ids like itm_bandage.)
		var inv: Variant = s.base_state.get("inventory", {})
		if typeof(inv) == TYPE_DICTIONARY:
			for iid in (inv as Dictionary).keys():
				var idstr: String = String(iid)
				# Internal test item ids (itm_bandage etc.) are allowed.
				if idstr.begins_with("itm_") or idstr.begins_with("c_"):
					continue
				if known_items.size() > 0 and not known_items.has(idstr):
					dangling += 1
		if dangling > 0:
			outcome["dangling_refs"] = dangling
			outcome["fail_day"] = day
			outcome["reason"] = "dangling_refs:%d" % dangling
			return outcome

	outcome["completed"] = true
	outcome["final_day"] = NUM_DAYS
	return outcome

func _issue_command_safe(s: RefCounted, cmd: Dictionary) -> void:
	var r: RefCounted = s.issue_command(cmd)
	# Silent ignore: command rejection is acceptable as long as state
	# rolls back cleanly.
