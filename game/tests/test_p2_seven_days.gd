extends SceneTree

## Stage 10 / P2 longitudinal test: 7-day campaign loop.
## Verifies:
##   - new_game(seed=42) succeeds
##   - 7 consecutive daily ticks advance day counter
##   - day 1 / 4 / 7 morning reports have non-empty text
##   - food/water/material/medical all consumed at least once
##   - >= 3 events fire across the 7 days
##   - character stats stay in [0,100]
##   - no crash, no dangling references at end

const StateMachineMod = preload("res://game/application/state_machine.gd")
const MorningReportMod = preload("res://game/application/morning_report.gd")
const GameSessionMod = preload("res://game/core/game_session.gd")
const StockMod = preload("res://game/domain/inventory/stock.gd")
const BaseMod = preload("res://game/domain/base/base.gd")
const FacilityMod = preload("res://game/domain/base/facility.gd")
const JobBoardMod = preload("res://game/domain/base/jobs.gd")
const CharMod = preload("res://game/domain/survivors/character.gd")
const ContentDBMod = preload("res://game/core/content_db.gd")
const LootMod = preload("res://game/domain/inventory/loot.gd")
const CityMod = preload("res://game/domain/world/city.gd")
const EventInterpreterMod = preload("res://game/domain/events/interpreter.gd")

var _fail_count: int = 0
var _pass_count: int = 0

func _initialize() -> void:
	print("=== test_p2_seven_days start ===")
	_test_seven_day_loop()
	print("=== test_p2_seven_days result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

func _test_seven_day_loop() -> void:
	print("[1] 7-day campaign loop")
	var s: RefCounted = GameSessionMod.new()
	var nr: RefCounted = s.new_game(42, "res://content")
	_expect(nr.is_ok(), "new_game(42) ok")

	# Load content (in case new_game failed, retry here)
	var content: RefCounted = ContentDBMod.new()
	content.load_all("res://content")

	# Seed base with starting stockpile & facilities
	var base: RefCounted = BaseMod.new()
	base.stockpile.add("food", 30)
	base.stockpile.add("water", 40)
	base.stockpile.add("material", 10)
	base.stockpile.add("parts", 6)
	base.stockpile.add("medical", 4)
	base.stockpile.add("fuel", 2)
	base.add_facility(FacilityMod.new("fac_sleep_basic", "sleep"))
	base.add_facility(FacilityMod.new("fac_kitchen_basic", "kitchen"))
	base.add_facility(FacilityMod.new("fac_storage_basic", "storage"))
	# Manually inject daily_upkeep on storage so we exercise material consumption.
	var storage_f: RefCounted = base.get_facility("fac_storage_basic")
	if storage_f != null:
		storage_f.daily_upkeep["material"] = 1
	# Medical facility consumes medical (use a synthetic fac_medical with upkeep).
	var med_f: RefCounted = FacilityMod.new("fac_medical_basic", "medical")
	med_f.daily_upkeep["medical"] = 1
	base.add_facility(med_f)
	# Persist base into session.
	s.base_state["base_obj"] = base.to_dict()
	s.base_state["population"] = 3

	# Seed 3 characters (skill profile chosen so jobs work).
	var characters: Array = []
	for i in range(3):
		var c: RefCounted = CharMod.new("c_alex_%d" % i, "Alex%d" % i)
		c.skills["combat"] = 2
		c.skills["medical"] = 3
		c.skills["engineering"] = 2
		c.skills["search"] = 2
		c.skills["social"] = 2
		characters.append(c.to_dict())
	s.characters = characters

	# Run the 7-day loop.
	var sm: RefCounted = StateMachineMod.new()
	var mr: RefCounted = MorningReportMod.new()
	var interp: RefCounted = EventInterpreterMod.new()
	var reports_by_day: Dictionary = {}
	var prev_summary: Dictionary = {}
	var events_fired: Array = []
	var food_total_consumed: int = 0
	var water_total_consumed: int = 0
	var material_total_consumed: int = 0
	var medical_total_consumed: int = 0
	var daily_food_history: Array = []
	var daily_water_history: Array = []

	# Assign jobs for day 1
	base.assign_role("c_alex_0", "cook")
	base.assign_role("c_alex_1", "water")
	base.assign_role("c_alex_2", "medical")

	for day in range(1, 8):
		# Advance session clock to current day
		s.clock.current_day = day
		# 1. Morning report (state machine has just rolled over or is MORNING_REPORT)
		if day > 1:
			sm.transition_to(0)  # back to MORNING_REPORT
		var rep: Dictionary = mr.build(s, prev_summary)
		reports_by_day[day] = rep
		# 2. Drive the day through state machine
		sm.run_full_day({"day": day, "report": rep})
		# 3. Daily base tick
		var tick: Dictionary = base.daily_tick(s)
		food_total_consumed += int((tick["consumed"] as Dictionary).get("food", 0))
		water_total_consumed += int((tick["consumed"] as Dictionary).get("water", 0))
		material_total_consumed += int((tick["consumed"] as Dictionary).get("material", 0))
		medical_total_consumed += int((tick["consumed"] as Dictionary).get("medical", 0))
		daily_food_history.append(int((tick["consumed"] as Dictionary).get("food", 0)))
		daily_water_history.append(int((tick["consumed"] as Dictionary).get("water", 0)))
		# 4. Trigger a couple of events per day using interpreter
		var event_ids: Array = content.list_ids("events")
		var picked: StringName = &""
		if event_ids.size() > 0:
			# Deterministic pick: take event_ids[day % size]
			var idx: int = day % int(event_ids.size())
			picked = StringName(String(event_ids[idx]))
		if String(picked) != "":
			var rec: Variant = content.get_record("events", String(picked))
			if typeof(rec) == TYPE_DICTIONARY:
				var cond_ok: bool = interp.evaluate_all(((rec as Dictionary).get("triggers", {}) as Dictionary).get("all_of", []), s)
				if cond_ok:
					events_fired.append(String(picked))
					# Apply the effects
					for eff in (rec as Dictionary).get("effects", []):
						interp.apply_effect(eff, s)
		# Also scan all events and fire any whose triggers match (the chosen
		# one is a representative pick; real Director will select by weight).
		var all_ids: Array = content.list_ids("events")
		for eid in all_ids:
			if events_fired.has(String(eid)):
				continue
			var er: Variant = content.get_record("events", String(eid))
			if typeof(er) != TYPE_DICTIONARY:
				continue
			if interp.evaluate_all(((er as Dictionary).get("triggers", {}) as Dictionary).get("all_of", []), s):
				events_fired.append(String(eid))
				for eff in (er as Dictionary).get("effects", []):
					interp.apply_effect(eff, s)
		# 5. Apply a small morale drift to characters based on food shortfall
		var shortfall: int = 0
		if base.stockpile.get_resource("food") == 0 and int((tick["consumed"] as Dictionary).get("food", 0)) < 6:
			shortfall = 1
		for cd in s.characters:
			if typeof(cd) != TYPE_DICTIONARY:
				continue
			var stats: Dictionary = (cd as Dictionary).get("stats", {})
			if stats.is_empty():
				continue
			if shortfall > 0:
				stats["morale"] = clampi(int(stats.get("morale", 50)) - 1, 0, 100)
				stats["energy"] = clampi(int(stats.get("energy", 70)) - 1, 0, 100)
		# 6. Compose summary for next morning
		prev_summary = {
			"consumed": tick["consumed"],
			"produced": tick["produced"],
			"injuries": [],
			"infections": [],
			"events": [{"id": String(picked), "title_zh": "Day %d event" % day, "kind": "scene"}],
			"relationships": [],
		}

	# === Assertions ====================================================
	# Morning report at days 1, 4, 7 has non-empty text
	for d in [1, 4, 7]:
		var rep_d: Dictionary = reports_by_day[d]
		var text: String = String(rep_d.get("summary_text", ""))
		_expect(text.length() > 0, "day %d morning report non-empty (len=%d)" % [d, text.length()])

	# At least one food/water/material/medical consumption across the 7 days
	_expect(food_total_consumed > 0, "food consumed at least once (total=%d)" % food_total_consumed)
	_expect(water_total_consumed > 0, "water consumed at least once (total=%d)" % water_total_consumed)
	_expect(material_total_consumed > 0, "material consumed at least once (total=%d)" % material_total_consumed)
	_expect(medical_total_consumed > 0, "medical consumed at least once (total=%d)" % medical_total_consumed)

	# At least 3 events fired
	_expect(events_fired.size() >= 3, "events fired >= 3 (got %d: %s)" % [events_fired.size(), str(events_fired)])

	# All character stats in 0..100
	var stat_invariants_ok: bool = true
	for cd in s.characters:
		if typeof(cd) != TYPE_DICTIONARY:
			continue
		var stats: Dictionary = (cd as Dictionary).get("stats", {})
		for k in stats.keys():
			var v: int = int(stats[k])
			if v < 0 or v > 100:
				stat_invariants_ok = false
				printerr("  character %s stat %s out of range: %d" % [str(cd.get("id", "?")), k, v])
	_expect(stat_invariants_ok, "all character stats within [0,100]")

	# Session integrity — characters all have id field, no dangling refs
	var dangling: int = 0
	for cd in s.characters:
		if typeof(cd) != TYPE_DICTIONARY:
			dangling += 1
			continue
		if String(cd.get("id", "")) == "":
			dangling += 1
	_expect(dangling == 0, "no dangling character refs (dangling=%d)" % dangling)

	# Day clock advanced
	_expect(sm.day == 7, "state machine day 7 after 7 full cycles (got %d)" % sm.day)

	# Daily consumption history sanity
	print("  daily food consumption history: %s" % str(daily_food_history))
	print("  daily water consumption history: %s" % str(daily_water_history))
	print("  total events fired: %d" % events_fired.size())
	print("  total food consumed: %d" % food_total_consumed)
	print("  total water consumed: %d" % water_total_consumed)
	print("  total material consumed: %d" % material_total_consumed)
	print("  total medical consumed: %d" % medical_total_consumed)
	print("  final stockpile: food=%d water=%d material=%d medical=%d fuel=%d" % [
		base.stockpile.get_resource("food"),
		base.stockpile.get_resource("water"),
		base.stockpile.get_resource("material"),
		base.stockpile.get_resource("medical"),
		base.stockpile.get_resource("fuel"),
	])
	print("  base state: %s" % str(base.state))