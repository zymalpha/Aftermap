extends SceneTree

## Module C smoke: Inventory + Base + Jobs.
## Exits with code 0 on full success, 1 on any failure.
## Uses lowercase single-underscore preloads to avoid clashing with global class_name.

const ItemMod = preload("res://game/domain/inventory/item.gd")
const StockMod = preload("res://game/domain/inventory/stock.gd")
const LootMod = preload("res://game/domain/inventory/loot.gd")
const FacilityMod = preload("res://game/domain/base/facility.gd")
const BaseMod = preload("res://game/domain/base/base.gd")
const JobBoardMod = preload("res://game/domain/base/jobs.gd")
const RngMod = preload("res://game/core/rng_service.gd")

var _fail_count: int = 0
var _pass_count: int = 0

func _initialize() -> void:
	print("=== test_p2_inventory_base start ===")
	_test_item_from_content()
	_test_stock_resource_add_remove()
	_test_stock_daily_consumption()
	_test_stock_to_from_dict()
	_test_loot_table_present_all_classes()
	_test_loot_roll_deterministic()
	_test_facility_from_content()
	_test_facility_damage_repair()
	_test_facility_level_up_caps_at_2()
	_test_jobs_assign_unassign()
	_test_jobs_capacity_caps_at_3()
	_test_jobs_efficiency_diminishing_returns()
	_test_jobs_efficiency_snapshot()
	_test_base_daily_tick_consumes_food_water()
	_test_base_daily_tick_produces_food_when_garden_assigned()
	_test_base_to_from_dict()
	print("=== test_p2_inventory_base result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

func _test_item_from_content() -> void:
	print("[1] ItemDef.from_content")
	var rec: Dictionary = {
		"id": "itm_bandage",
		"name_zh": "绷带",
		"kind": "consumable",
		"weight_kg": 0.05,
		"stack_size": 12,
		"tags": ["consumable", "medical"],
		"value_tier": 1,
	}
	var it: RefCounted = ItemMod.from_content(rec)
	_expect(it.id == "itm_bandage", "id set")
	_expect(it.weight_kg == 0.05, "weight set")
	_expect(it.stack_size == 12, "stack_size set")
	_expect((it.tags as Array).size() == 2, "tags copied")

func _test_stock_resource_add_remove() -> void:
	print("[2] Stockpile resource add/remove")
	var s: RefCounted = StockMod.new()
	s.add("food", 10)
	_expect(s.get_resource("food") == 10, "add food 10")
	s.consume("food", 4)
	_expect(s.get_resource("food") == 6, "consume food 4")
	s.consume("food", 100)  # can't go negative
	_expect(s.get_resource("food") == 0, "consume clamps at 0")
	s.produce("medical", 5)
	_expect(s.get_resource("medical") == 5, "produce medical")

func _test_stock_daily_consumption() -> void:
	print("[3] Stockpile.daily_consumption")
	var s: RefCounted = StockMod.new()
	s.add("food", 10)
	s.add("water", 15)
	var r: Dictionary = s.daily_consumption(2, 3, 3)  # 3 people -> need 6 food, 9 water
	_expect(int((r["consumed"] as Dictionary).get("food", 0)) == 6, "3p eat 6 food")
	_expect(int((r["consumed"] as Dictionary).get("water", 0)) == 9, "3p drink 9 water")
	_expect(s.get_resource("food") == 4, "remaining food 4")
	_expect(s.get_resource("water") == 6, "remaining water 6")
	# Shortfall: 10 people, only 1 food
	var s2: RefCounted = StockMod.new()
	s2.add("food", 1)
	var r2: Dictionary = s2.daily_consumption(2, 3, 10)
	_expect(int((r2["missing"] as Dictionary).get("food", 0)) == 19, "missing 19 food")

func _test_stock_to_from_dict() -> void:
	print("[4] Stockpile round-trip")
	var s: RefCounted = StockMod.new()
	s.add("fuel", 5)
	s.add_item("itm_bandage", 4)
	var d: Dictionary = s.to_dict()
	var s2: RefCounted = StockMod.new()
	s2.from_dict(d)
	_expect(s2.get_resource("fuel") == 5, "fuel preserved")
	_expect(int(s2.items.get("itm_bandage", 0)) == 4, "items preserved")

func _test_loot_table_present_all_classes() -> void:
	print("[5] LootTable all POI classes")
	var lt: RefCounted = LootMod.new()
	for cls in ["clinic", "grocery", "police", "school", "depot", "park"]:
		_expect((lt.get_table(cls) as Array).size() > 0, "loot table for %s" % cls)

func _test_loot_roll_deterministic() -> void:
	print("[6] LootTable roll determinism")
	var rng_a: RefCounted = RngMod.new()
	rng_a.seed(42)
	var rng_b: RefCounted = RngMod.new()
	rng_b.seed(42)
	var lt: RefCounted = LootMod.new()
	var a: Array = lt.roll("clinic", 5, rng_a, &"loot_clinic")
	var b: Array = lt.roll("clinic", 5, rng_b, &"loot_clinic")
	_expect(a.size() == 5, "5 rolls returned (a)")
	_expect(b.size() == 5, "5 rolls returned (b)")
	var same: bool = a.size() == b.size()
	if same:
		for i in range(a.size()):
			var ai: Dictionary = a[i]
			var bi: Dictionary = b[i]
			if String(ai.get("item_id", "")) != String(bi.get("item_id", "")):
				same = false
				break
			if int(ai.get("qty", 0)) != int(bi.get("qty", 0)):
				same = false
				break
	_expect(same, "rolls deterministic given seed")

func _test_facility_from_content() -> void:
	print("[7] Facility.from_content")
	var rec: Dictionary = {
		"id": "fac_kitchen_basic",
		"name_zh": "厨房",
		"kind": "kitchen",
		"tier": 1,
		"build_cost": {"resource_material": 8},
		"daily_upkeep": {},
		"power_draw_kw": 1.0,
	}
	var f: RefCounted = FacilityMod.from_content(rec)
	_expect(f.kind == "kitchen", "kind kitchen")
	_expect(f.tier == 1, "tier 1")
	_expect(int(f.build_cost.get("resource_material", 0)) == 8, "build_cost loaded")

func _test_facility_damage_repair() -> void:
	print("[8] Facility damage/repair")
	var f: RefCounted = FacilityMod.new("f1", "sleep")
	f.damage(40)
	_expect(f.integrity == 60, "integrity 60 after -40")
	f.repair(20)
	_expect(f.integrity == 80, "integrity 80 after +20")
	f.damage(999)
	_expect(f.integrity == 0, "integrity clamped 0")

func _test_facility_level_up_caps_at_2() -> void:
	print("[9] Facility.level_up")
	var f: RefCounted = FacilityMod.new("f1", "sleep")
	_expect(f.level_up() == true, "tier 1 -> 2")
	_expect(f.level_up() == false, "tier 2 capped, no further level")

func _test_jobs_assign_unassign() -> void:
	print("[10] JobBoard assign/unassign")
	var jb: RefCounted = JobBoardMod.new()
	jb.assign("cook", "c_alex")
	jb.assign("cook", "c_bo")
	_expect((jb.assignments["cook"] as Array).size() == 2, "cook has 2 workers")
	jb.unassign("c_alex")
	_expect((jb.assignments["cook"] as Array).size() == 1, "cook has 1 worker after unassign")

func _test_jobs_capacity_caps_at_3() -> void:
	print("[11] JobBoard capacity cap")
	var jb: RefCounted = JobBoardMod.new()
	jb.assign("guard", "c_a")
	jb.assign("guard", "c_b")
	jb.assign("guard", "c_c")
	jb.assign("guard", "c_d")  # full -> false
	_expect((jb.assignments["guard"] as Array).size() == 3, "guard capped at 3")
	_expect(jb.assignments.has("watch") == false or (jb.assignments["watch"] as Array).size() == 0, "watch empty")

func _test_jobs_efficiency_diminishing_returns() -> void:
	print("[12] JobBoard efficiency diminishing returns")
	var jb: RefCounted = JobBoardMod.new()
	jb.assign("cook", "c_a")
	jb.assign("cook", "c_b")
	jb.assign("cook", "c_c")
	var char_index: RefCounted = _mk_char_index([
		{"id": "c_a", "skills": {"medical": 2}, "stats": {"hp": 100, "energy": 80}},
		{"id": "c_b", "skills": {"medical": 2}, "stats": {"hp": 100, "energy": 80}},
		{"id": "c_c", "skills": {"medical": 2}, "stats": {"hp": 100, "energy": 80}},
	])
	var snap: Dictionary = jb.efficiency_snapshot(char_index)
	var cook_workers: Array = (snap["by_role"]["cook"] as Array)
	_expect(float(cook_workers[0]["hours"]) > 0.0, "1st worker hours > 0 (got %s)" % str(cook_workers[0]["hours"]))
	_expect(float(cook_workers[2]["hours"]) == 0.0, "3rd worker hours = 0 (got %s)" % str(cook_workers[2]["hours"]))

func _mk_char_index(characters: Array) -> RefCounted:
	# Returns a tiny RefCounted with a get_character(id) method.
	var idx: Dictionary = {}
	for c in characters:
		idx[String(c.get("id", ""))] = c
	var RefCountedScript = preload("res://game/tests/_tiny_char_index.gd")
	var inst: RefCounted = RefCountedScript.new()
	inst.call("set_dict", idx)
	return inst

func _test_jobs_efficiency_snapshot() -> void:
	print("[13] JobBoard efficiency_snapshot")
	var jb: RefCounted = JobBoardMod.new()
	jb.assign("cook", "c_a")
	jb.assign("water", "c_b")
	var char_index: RefCounted = _mk_char_index([
		{"id": "c_a", "skills": {"medical": 3}, "stats": {"hp": 100, "energy": 80}},
		{"id": "c_b", "skills": {"engineering": 4}, "stats": {"hp": 80, "energy": 60}},
	])
	var snap: Dictionary = jb.efficiency_snapshot(char_index)
	var cook_workers: Array = (snap["by_role"]["cook"] as Array)
	# hours may be float; compare numerically.
	var hours_v: Variant = cook_workers[0]["hours"]
	var hours_f: float = float(hours_v)
	_expect(hours_f > 1.0, "skill 3 -> 1.2 hours (got %s)" % str(hours_v))

func _test_base_daily_tick_consumes_food_water() -> void:
	print("[14] Base.daily_tick consumes food/water")
	var b: RefCounted = BaseMod.new()
	b.stockpile.add("food", 10)
	b.stockpile.add("water", 12)
	b.set_population(3)
	var r: Dictionary = b.daily_tick()
	_expect(int((r["consumed"] as Dictionary).get("food", 0)) == 6, "consumed 6 food")
	_expect(int((r["consumed"] as Dictionary).get("water", 0)) == 9, "consumed 9 water")
	_expect(b.stockpile.get_resource("food") == 4, "stockpile food 4 after consumption")

func _test_base_daily_tick_produces_food_when_garden_assigned() -> void:
	print("[15] Base.daily_tick garden produces food")
	var b: RefCounted = BaseMod.new()
	b.stockpile.add("food", 10)
	b.set_population(3)
	b.assign_role("c_a", "garden")
	var r: Dictionary = b.daily_tick()
	_expect(int((r["produced"] as Dictionary).get("food", 0)) >= 1, "garden produced >= 1 food")

func _test_base_to_from_dict() -> void:
	print("[16] Base round-trip")
	var b: RefCounted = BaseMod.new()
	b.stockpile.add("food", 7)
	b.add_facility(FacilityMod.new("fac_x", "sleep"))
	b.assign_role("c_alex", "cook")
	var d: Dictionary = b.to_dict()
	var b2: RefCounted = BaseMod.new()
	b2.from_dict(d)
	_expect(b2.stockpile.get_resource("food") == 7, "stockpile preserved")
	_expect(b2.get_facility("fac_x") != null, "facility preserved")
	_expect((b2.jobs.assignments["cook"] as Array).size() == 1, "job assignment preserved")