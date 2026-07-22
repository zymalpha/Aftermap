class_name Migration extends RefCounted

## 迁徙子系统（策划 02 §8 + 策划 09 §17 + 策划 12 §11）
##
## 当玩家在第 19–30 天之间决定离城时，调用 pack() 收集当前基地/库存
## 状态、剩余角色、社区遗产以及离城日的城市压力。然后 apply_migration_end()
## 会把这次迁徙写入 session 的 save_meta，留下一个 5 取 1 的社区遗产。
##
## 5 种结局：
##   legacy_map      地图档案 (更多已探索路线)
##   legacy_medical  医疗记录 (感染病例、配方、诊断经验)
##   legacy_tools    工具核心 (工程蓝图 + 关键设备)
##   legacy_mementos 纪念册 (全部人物记忆, 关系恢复更快)
##   legacy_radio    无线电台 (势力联系 + 远方信号)
##
## 方法：
##   pack(session) -> Dictionary  (MigrationPack)
##   can_depart(session) -> Array [bool, reason_str]
##   apply_migration_end(session, pack) -> CommandResult
##   to_dict() / from_dict(d)

const _PATH: String = "res://game/domain/world/migration.gd"

const CommandResultScript: GDScript = preload("res://game/core/command_result.gd")
const BaseScript: GDScript = preload("res://game/domain/base/base.gd")
const CharacterScript: GDScript = preload("res://game/domain/survivors/character.gd")
const StockpileScript: GDScript = preload("res://game/domain/inventory/stock.gd")

const ENDINGS: Array[String] = [
	"legacy_map",
	"legacy_medical",
	"legacy_tools",
	"legacy_mementos",
	"legacy_radio",
]

const ACT_DEPARTURE_MIN_DAY: int = 19
const MIN_PARTY_TO_DEPART: int = 1
const MIN_INVENTORY_NONEMPTY_TO_DEPART: bool = false

func _log(msg: String) -> void:
	push_warning("[Migration] " + msg)

## Build a MigrationPack snapshot from the current session. Pure:
## does not mutate the session, only reads it.
## MigrationPack shape:
##   {
##     "items":            [{item_id, qty}, ...],
##     "characters":       [{id, ...}, ...],
##     "mementos":         [string, ...],
##     "crew_remaining":   [character_id, ...],
##     "city_pressure_at_departure": int,
##     "day_departed":     int,
##     "ending":           ""   (set later by apply_migration_end)
##   }
func pack(session: RefCounted) -> Dictionary:
	if session == null:
		return _empty_pack()

	var pack_data: Dictionary = _empty_pack()
	pack_data["day_departed"] = int(session.clock.current_day)
	pack_data["city_pressure_at_departure"] = int(
		(session.base_state.get("city_pressure_obj", {}) as Dictionary).get("value", 0)
	)

	# 1) Items: walk stockpile.items dict + facility flags + resource buckets
	#    (resources are coerced into a pseudo-item "res:<key>" so they can
	#    travel with the pack even though Stockpile tracks resources
	#    separately from item stacks).
	var inventory: Dictionary = session.base_state.get("inventory", {})
	if typeof(inventory) == TYPE_DICTIONARY:
		for iid in (inventory as Dictionary).keys():
			var qty: int = int((inventory as Dictionary)[iid])
			if qty > 0:
				pack_data["items"].append({"item_id": String(iid), "qty": qty})

	# Resource buckets travel as res:<key> items.
	var base_obj_dict: Dictionary = session.base_state.get("base_obj", {})
	var stockpile_dict: Dictionary = {}
	if typeof(base_obj_dict) == TYPE_DICTIONARY:
		var raw: Variant = base_obj_dict.get("stockpile", {})
		if typeof(raw) == TYPE_DICTIONARY:
			stockpile_dict = raw
	for rkey in StockpileScript.RESOURCE_KEYS:
		var qty_r: int = int(stockpile_dict.get(rkey, 0))
		if qty_r > 0:
			pack_data["items"].append({"item_id": "res:" + rkey, "qty": qty_r})

	# 2) Characters: snapshot (deep copy) all alive ones.
	for c in session.characters:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var cid: String = String(c.get("id", ""))
		if cid == "":
			continue
		# Skip characters with hp == 0 (dead — won't travel).
		var stats: Variant = c.get("stats", {})
		if typeof(stats) == TYPE_DICTIONARY:
			var hp: int = int((stats as Dictionary).get("hp", 0))
			if hp <= 0:
				continue
		pack_data["characters"].append((c as Dictionary).duplicate(true))
		pack_data["crew_remaining"].append(cid)

	# 3) Mementos: pull personal memories from each survivor as short strings.
	for cdata in pack_data["characters"]:
		var mems: Variant = cdata.get("memories", [])
		if typeof(mems) != TYPE_ARRAY:
			continue
		for m in mems:
			if typeof(m) != TYPE_DICTIONARY:
				continue
			var summary: String = String(m.get("summary_zh", ""))
			if summary != "":
				pack_data["mementos"].append(summary)

	return pack_data

## Decide whether the campaign may depart the city. Returns
## [ok: bool, reason: String]. Reasons:
##   "ok" | "no_base" | "no_party" | "too_early"
func can_depart(session: RefCounted) -> Array:
	if session == null:
		return [false, "no_session"]
	var day: int = int(session.clock.current_day)
	if day < ACT_DEPARTURE_MIN_DAY:
		return [false, "too_early:day_%d" % day]

	# Need at least one character with hp > 0.
	var alive: int = 0
	for c in session.characters:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var stats: Variant = c.get("stats", {})
		if typeof(stats) == TYPE_DICTIONARY:
			if int((stats as Dictionary).get("hp", 0)) > 0:
				alive += 1
	if alive < MIN_PARTY_TO_DEPART:
		return [false, "no_party"]

	# Base anchor must exist (just check session.base_state["base_obj"]).
	if not session.base_state.has("base_obj"):
		return [false, "no_base"]

	return [true, "ok"]

## Apply the migration end. Writes the chosen legacy into session.save_meta,
## marks session.base_state["migration_completed"] = true, and returns an
## OK CommandResult. If `legacy` is unknown, returns REJECTED.
## `pack_data` is the MigrationPack produced by pack() (or any compatible dict).
func apply_migration_end(session: RefCounted, pack_data: Dictionary) -> CommandResult:
	if session == null:
		return CommandResultScript.rejected("migration_no_session")
	if typeof(pack_data) != TYPE_DICTIONARY:
		return CommandResultScript.rejected("migration_pack_invalid")

	var legacy: String = String(pack_data.get("ending", ""))
	if not ENDINGS.has(legacy):
		return CommandResultScript.rejected("migration_invalid_ending: " + legacy)

	# Stamp departure metadata on session.
	session.base_state["migration_completed"] = true
	session.base_state["migration_ending"] = legacy
	session.base_state["migration_day"] = int(pack_data.get("day_departed", session.clock.current_day))

	# save_meta: write the campaign summary + chosen legacy.
	if not session.save_meta.has("endings"):
		session.save_meta["endings"] = []
	(session.save_meta["endings"] as Array).append({
		"legacy": legacy,
		"day": int(pack_data.get("day_departed", session.clock.current_day)),
		"crew_count": (pack_data.get("crew_remaining", []) as Array).size(),
		"items_count": (pack_data.get("items", []) as Array).size(),
		"mementos_count": (pack_data.get("mementos", []) as Array).size(),
		"city_pressure_at_departure": int(pack_data.get("city_pressure_at_departure", 0)),
	})

	session.save_meta["updated_at"] = Time.get_datetime_string_from_system(true)

	return CommandResultScript.ok("migration_end_applied", {
		"legacy": legacy,
		"day": int(pack_data.get("day_departed", session.clock.current_day)),
	})

## Pick a deterministic legacy given the campaign state. Optional helper
## used by callers that want a fallback (e.g. an auto-pick if the player
## never chose one). Returns one of ENDINGS.
func pick_legacy_for(session: RefCounted, pack_data: Dictionary) -> String:
	var seed_basis: int = 0
	if session != null:
		seed_basis += int(session.save_meta.get("seed", 0))
	seed_basis += int(pack_data.get("day_departed", 1)) * 7
	var idx: int = abs(seed_basis) % ENDINGS.size()
	return ENDINGS[idx]

## Internals ---------------------------------------------------------------

func _empty_pack() -> Dictionary:
	return {
		"items": [],
		"characters": [],
		"mementos": [],
		"crew_remaining": [],
		"city_pressure_at_departure": 0,
		"day_departed": 0,
		"ending": "",
	}

## to_dict/from_dict operate on a list of endings already stored in save_meta
## (i.e. they don't reach into session). Provided so callers can round-trip
## the module independently.
func to_dict() -> Dictionary:
	return {"endings": ENDINGS.duplicate()}

func from_dict(_d: Dictionary) -> void:
	# ENDINGS is a constant. Nothing to load.
	pass