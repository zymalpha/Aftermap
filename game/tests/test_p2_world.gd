extends SceneTree

## Module D smoke: POI + City + Travel.

const POIMod = preload("res://game/domain/world/poi.gd")
const CityMod = preload("res://game/domain/world/city.gd")
const RngMod = preload("res://game/core/rng_service.gd")

var _fail_count: int = 0
var _pass_count: int = 0

func _initialize() -> void:
	print("=== test_p2_world start ===")
	_test_poi_enter_search_loot()
	_test_poi_cleared_no_more_drops()
	_test_poi_set_loot_table_then_loot()
	_test_poi_to_from_dict()
	_test_city_6_pois_registered()
	_test_city_distance_manhattan()
	_test_city_travel_time_base()
	_test_city_travel_time_party_size_penalty()
	_test_city_to_from_dict()
	print("=== test_p2_world result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

func _test_poi_enter_search_loot() -> void:
	print("[1] POI enter + search + loot")
	var poi: RefCounted = POIMod.new("poi_clinic_1", "clinic")
	poi.set_loot_table([
		{"item_id": "itm_bandage", "weight": 100, "min_qty": 1, "max_qty": 3},
	])
	var rng: RefCounted = RngMod.new()
	rng.seed(7)
	var enter_state: Dictionary = poi.enter()
	_expect(bool(enter_state.get("entered", false)), "enter ok")
	var drops: Array = poi.search(rng, &"poi_search")
	_expect(drops.size() >= 1, "search yielded drops")
	var granted: Array = poi.apply_loot(drops)
	_expect(granted.size() >= 1, "apply_loot granted")
	_expect(poi.cleared, "POI cleared after loot")

func _test_poi_cleared_no_more_drops() -> void:
	print("[2] POI cleared returns no drops")
	var poi: RefCounted = POIMod.new("poi_clinic_1", "clinic")
	poi.set_loot_table([{"item_id": "itm_x", "weight": 100, "min_qty": 1, "max_qty": 1}])
	var rng: RefCounted = RngMod.new()
	rng.seed(1)
	poi.loot(rng, &"poi_search")
	# Second loot returns empty.
	var granted2: Array = poi.loot(rng, &"poi_search")
	_expect(granted2.is_empty(), "second loot empty after cleared")

func _test_poi_set_loot_table_then_loot() -> void:
	print("[3] POI.set_loot_table then loot")
	var poi: RefCounted = POIMod.new("poi_grocery_1", "grocery")
	poi.set_loot_table([
		{"item_id": "itm_canned_food", "weight": 50, "min_qty": 2, "max_qty": 4},
		{"item_id": "itm_water_bottle", "weight": 50, "min_qty": 1, "max_qty": 3},
	])
	var rng: RefCounted = RngMod.new()
	rng.seed(99)
	var granted: Array = poi.loot(rng, &"poi_search")
	_expect(granted.size() >= 1, "loot granted at least one")
	var item_ids: Array = []
	for g in granted:
		item_ids.append(String(g.get("item_id", "")))
	_expect(item_ids.has("itm_canned_food") or item_ids.has("itm_water_bottle"), "granted item from table")

func _test_poi_to_from_dict() -> void:
	print("[4] POI to/from_dict")
	var poi: RefCounted = POIMod.new("poi_x", "park")
	poi.grid_w = 8
	poi.grid_h = 8
	var d: Dictionary = poi.to_dict()
	var poi2: RefCounted = POIMod.new()
	poi2.from_dict(d)
	_expect(poi2.poi_id == "poi_x", "poi_id preserved")
	_expect(poi2.grid_w == 8, "grid_w preserved")

func _test_city_6_pois_registered() -> void:
	print("[5] City has 6 POIs")
	var c: RefCounted = CityMod.new()
	var ids: Array = c.list_poi_ids()
	_expect(ids.size() == 6, "6 POIs registered (got %d)" % ids.size())
	for cls in POIMod.POI_CLASSES:
		var found: bool = false
		for pid in ids:
			var poi_v: RefCounted = c.get_poi(String(pid))
			if poi_v != null and String(poi_v.poi_class) == cls:
				found = true
				break
		_expect(found, "POI class %s present" % cls)

func _test_city_distance_manhattan() -> void:
	print("[6] City.distance_between Manhattan")
	var c: RefCounted = CityMod.new()
	var d_ab: int = c.distance_between("poi_clinic_1", "poi_grocery_1")
	# clinic(2,4) -> grocery(8,2) = |2-8| + |4-2| = 6 + 2 = 8
	_expect(d_ab == 8, "clinic->grocery distance 8 (got %d)" % d_ab)
	var d_missing: int = c.distance_between("poi_clinic_1", "poi_unknown")
	_expect(d_missing == -1, "missing POI returns -1")

func _test_city_travel_time_base() -> void:
	print("[7] City.travel_time base")
	var c: RefCounted = CityMod.new()
	var t: int = c.travel_time("poi_clinic_1", "poi_grocery_1", 1)
	# distance 8 -> 8*12 + 8*2*0 = 96 minutes
	_expect(t == 96, "1-person travel 96 min (got %d)" % t)

func _test_city_travel_time_party_size_penalty() -> void:
	print("[8] City.travel_time party size penalty")
	var c: RefCounted = CityMod.new()
	var t1: int = c.travel_time("poi_clinic_1", "poi_grocery_1", 1)
	var t3: int = c.travel_time("poi_clinic_1", "poi_grocery_1", 3)
	# 3 ppl: 96 + 8*2*2 = 96 + 32 = 128
	_expect(t3 == 128, "3-person travel 128 min (got %d)" % t3)
	_expect(t3 > t1, "more people -> longer travel")

func _test_city_to_from_dict() -> void:
	print("[9] City to/from_dict")
	var c: RefCounted = CityMod.new()
	var d: Dictionary = c.to_dict()
	var c2: RefCounted = CityMod.new()
	c2.from_dict(d)
	_expect(c2.list_poi_ids().size() == 6, "POIs preserved")
	_expect(c2.distance_between("poi_clinic_1", "poi_police_1") == c.distance_between("poi_clinic_1", "poi_police_1"), "distances preserved")