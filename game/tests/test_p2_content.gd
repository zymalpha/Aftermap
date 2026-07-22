extends SceneTree

## Module E smoke: content expansion.

const ContentDBMod = preload("res://game/core/content_db.gd")

var _fail_count: int = 0
var _pass_count: int = 0

func _initialize() -> void:
	print("=== test_p2_content start ===")
	_test_items_loaded()
	_test_facilities_loaded()
	_test_recipes_loaded()
	_test_traits_loaded()
	_test_events_loaded()
	_test_chains_loaded()
	print("=== test_p2_content result: pass=%d fail=%d ===" % [_pass_count, _fail_count])
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

func _test_items_loaded() -> void:
	print("[1] items/ loaded (>= 12)")
	var db: RefCounted = ContentDBMod.new()
	db.load_all("res://content")
	var ids: Array = db.list_ids("items")
	_expect(ids.size() >= 12, "items >= 12 (got %d)" % ids.size())
	for required in ["itm_water_bottle", "itm_canned_food", "itm_bandage", "itm_antibiotics",
			"itm_flashlight", "itm_walkie_talkie", "itm_crowbar", "itm_handgun",
			"itm_9mm_ammo", "itm_map", "itm_notebook", "itm_fuel_can", "itm_cloth_rag"]:
		_expect(ids.has(required), "%s loaded" % required)

func _test_facilities_loaded() -> void:
	print("[2] facilities/ loaded (>= 6)")
	var db: RefCounted = ContentDBMod.new()
	db.load_all("res://content")
	var ids: Array = db.list_ids("facilities")
	_expect(ids.size() >= 6, "facilities >= 6 (got %d)" % ids.size())
	for required in ["fac_sleep_basic", "fac_storage_basic", "fac_kitchen_basic",
			"fac_medical_basic", "fac_watch_basic", "fac_barrier_basic"]:
		_expect(ids.has(required), "%s loaded" % required)

func _test_recipes_loaded() -> void:
	print("[3] recipes/ loaded (>= 4)")
	var db: RefCounted = ContentDBMod.new()
	db.load_all("res://content")
	var ids: Array = db.list_ids("recipes")
	_expect(ids.size() >= 4, "recipes >= 4 (got %d)" % ids.size())
	for required in ["rcp_bandage_basic", "rcp_purify_water", "rcp_simple_meal", "rcp_basic_repair"]:
		_expect(ids.has(required), "%s loaded" % required)

func _test_traits_loaded() -> void:
	print("[4] traits/ loaded (>= 12: 6 personalities + 3 values + 3 weaknesses)")
	var db: RefCounted = ContentDBMod.new()
	db.load_all("res://content")
	var ids: Array = db.list_ids("traits")
	_expect(ids.size() >= 12, "traits >= 12 (got %d)" % ids.size())
	# Count personalities, values, weaknesses
	var p: int = 0
	var v: int = 0
	var w: int = 0
	for tid in ids:
		var rec: Variant = db.get_record("traits", String(tid))
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var kind: String = String((rec as Dictionary).get("kind", ""))
		match kind:
			"personality": p += 1
			"value":      v += 1
			"weakness":   w += 1
	_expect(p >= 6, "personality >= 6 (got %d)" % p)
	_expect(v >= 3, "value >= 3 (got %d)" % v)
	_expect(w >= 3, "weakness >= 3 (got %d)" % w)

func _test_events_loaded() -> void:
	print("[5] events/ loaded (>= 10)")
	var db: RefCounted = ContentDBMod.new()
	db.load_all("res://content")
	var ids: Array = db.list_ids("events")
	_expect(ids.size() >= 10, "events >= 10 (got %d)" % ids.size())
	# Decision events present
	var decision_n: int = 0
	for eid in ids:
		var rec: Variant = db.get_record("events", String(eid))
		if typeof(rec) == TYPE_DICTIONARY and String((rec as Dictionary).get("kind", "")) == "decision":
			decision_n += 1
	_expect(decision_n >= 1, "decision events >= 1 (got %d)" % decision_n)
	# Broadcast event
	var br: Variant = db.get_record("events", "evt_radio_rumour")
	_expect(typeof(br) == TYPE_DICTIONARY and String((br as Dictionary).get("kind", "")) == "broadcast", "broadcast event loaded")
	# Summary event
	var sm: Variant = db.get_record("events", "evt_d7_weekly_summary")
	_expect(typeof(sm) == TYPE_DICTIONARY and String((sm as Dictionary).get("kind", "")) == "summary", "summary event loaded")

func _test_chains_loaded() -> void:
	print("[6] event-chains/ loaded (>= 2)")
	var db: RefCounted = ContentDBMod.new()
	db.load_all("res://content")
	var ids: Array = db.list_ids("event-chains")
	_expect(ids.size() >= 2, "chains >= 2 (got %d)" % ids.size())
	_expect(ids.has("evc_intro_welcome"), "evc_intro_welcome present")
	_expect(ids.has("evc_water_crisis"), "evc_water_crisis present")