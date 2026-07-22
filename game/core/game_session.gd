class_name GameSession extends RefCounted

## The single source of truth for campaign state.
## - Holds rng (RngService), clock (Clock), content (ContentDB),
##   characters (Array of Dictionary), base (Dictionary), save_meta (Dictionary)
## - Issues commands (kind-driven dispatch). All effects route through here.
## - Serialisable to / from dict (for save files in Stage 5+).

const _PATH: String = "res://game/core/game_session.gd"

const CommandResultScript: GDScript = preload("res://game/core/command_result.gd")
const RngServiceScript: GDScript = preload("res://game/core/rng_service.gd")
const ClockScript: GDScript = preload("res://game/core/clock.gd")
const ContentDBScript: GDScript = preload("res://game/core/content_db.gd")
const CharacterScript: GDScript = preload("res://game/domain/survivors/character.gd")
const StockpileScript: GDScript = preload("res://game/domain/inventory/stock.gd")

## Whitelisted stats for stat_add / set_base_stat. (策划04 §3)
const _STAT_KEYS: Array[String] = [
	"hp", "hunger", "energy", "morale", "stress", "infection",
]
## Whitelisted relationship axes.
const _RELATIONSHIP_AXES: Array[String] = ["trust", "intimacy"]
## Whitelisted memory kinds.
const _MEMORY_KINDS: Array[String] = ["personal", "relationship"]

var rng: RefCounted = null
var clock: RefCounted = null
var content: RefCounted = null
var characters: Array = []
var base_state: Dictionary = {}
var save_meta: Dictionary = {}

func _init() -> void:
	rng = RngServiceScript.new()
	clock = ClockScript.new()
	content = ContentDBScript.new()
	characters = []
	base_state = {}
	save_meta = {}

func _log(msg: String) -> void:
	push_warning("[GameSession] " + msg)

## Set up a fresh campaign from a root seed.
## Loads content from res://content/, seeds RNG, and resets state.
func new_game(seed_value: int, content_dir: String = "res://content") -> CommandResult:
	var err: Error = content.load_all(content_dir)
	if err != OK:
		return CommandResult.fail("content_load_failed", {"err": err, "dir": content_dir})

	rng.seed(seed_value)
	clock = ClockScript.new()
	characters = []
	base_state = _default_base_state()
	save_meta = {
		"seed": seed_value,
		"created_at": Time.get_datetime_string_from_system(true),
		"updated_at": Time.get_datetime_string_from_system(true),
		"save_schema_version": 1,
		"content_fingerprint": content.get_fingerprint(),
	}
	_log("new_game seed=" + str(seed_value) + " fp=" + content.get_fingerprint())
	return CommandResult.ok("new_game_ready", {"seed": seed_value})

## Dispatch a command dict. cmd.kind selects the handler.
## Handlers run as a single transaction; failure rolls back to pre-call state.
func issue_command(cmd: Dictionary) -> CommandResult:
	if typeof(cmd) != TYPE_DICTIONARY:
		return CommandResult.rejected("cmd_not_dict")
	if not cmd.has("kind"):
		return CommandResult.rejected("missing_kind")

	var kind: String = String(cmd["kind"])

	# Snapshot for transaction rollback (deep enough for primitives/arrays/dicts).
	var snapshot: Dictionary = _snapshot()

	match kind:
		"set_flag":
			return _cmd_set_flag(cmd, snapshot)
		"unlock_flag":
			return _cmd_set_flag(cmd, snapshot)
		"add_character":
			return _cmd_add_character(cmd, snapshot)
		"set_base_field":
			return _cmd_set_base_field(cmd, snapshot)
		"advance_day":
			return _cmd_advance_day(cmd, snapshot)
		"set_city_minutes":
			return _cmd_set_city_minutes(cmd, snapshot)
		"stat_add":
			return _cmd_stat_add(cmd, snapshot)
		"item_add":
			return _cmd_item_add(cmd, snapshot)
		"item_remove":
			return _cmd_item_remove(cmd, snapshot)
		"change_relationship":
			return _cmd_change_relationship(cmd, snapshot)
		"set_memory":
			return _cmd_set_memory(cmd, snapshot)
		_:
			return CommandResult.rejected("unknown_kind: " + kind)

## Persistence ----------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"rng": rng.to_dict(),
		"clock": clock.to_dict(),
		"characters": characters.duplicate(true),
		"base": base_state.duplicate(true),
		"save_meta": save_meta.duplicate(true),
		"content_meta": content.to_dict(),
	}

func from_dict(d: Dictionary) -> void:
	var rng_raw: Variant = d.get("rng", {})
	if typeof(rng_raw) == TYPE_DICTIONARY:
		rng.from_dict(rng_raw)
	var clock_raw: Variant = d.get("clock", {})
	if typeof(clock_raw) == TYPE_DICTIONARY:
		clock.from_dict(clock_raw)
	var chars_raw: Variant = d.get("characters", [])
	characters = []
	if typeof(chars_raw) == TYPE_ARRAY:
		for c in chars_raw:
			characters.append((c as Dictionary).duplicate(true))
	var base_raw: Variant = d.get("base", {})
	base_state = {}
	if typeof(base_raw) == TYPE_DICTIONARY:
		base_state = (base_raw as Dictionary).duplicate(true)
	var meta_raw: Variant = d.get("save_meta", {})
	save_meta = {}
	if typeof(meta_raw) == TYPE_DICTIONARY:
		save_meta = (meta_raw as Dictionary).duplicate(true)
	var content_meta_raw: Variant = d.get("content_meta", {})
	if typeof(content_meta_raw) == TYPE_DICTIONARY:
		content.from_dict(content_meta_raw)

## Debug ---------------------------------------------------------------------

func debug_dump() -> Dictionary:
	return {
		"day": clock.current_day,
		"city_minutes": clock.city_minutes,
		"characters": characters.size(),
		"base_keys": base_state.keys(),
		"save_meta": save_meta.duplicate(true),
	}

## Command handlers ----------------------------------------------------------

func _cmd_set_flag(cmd: Dictionary, snapshot: Dictionary) -> CommandResult:
	var flag: String = String(cmd.get("flag", ""))
	if flag == "":
		_restore(snapshot)
		return CommandResult.rejected("set_flag_missing_flag")
	if not _is_safe_id(flag):
		_restore(snapshot)
		return CommandResult.rejected("set_flag_invalid_flag")
	var value: Variant = cmd.get("value", true)
	base_state["flags"] = base_state.get("flags", {})
	(base_state["flags"] as Dictionary)[flag] = value
	save_meta["updated_at"] = Time.get_datetime_string_from_system(true)
	return CommandResult.ok("flag_set", {"flag": flag, "value": value})

func _cmd_add_character(cmd: Dictionary, snapshot: Dictionary) -> CommandResult:
	var payload: Dictionary = {}
	if cmd.has("character") and typeof(cmd["character"]) == TYPE_DICTIONARY:
		payload = (cmd["character"] as Dictionary).duplicate(true)
	var id: String = String(payload.get("id", ""))
	if id == "":
		_restore(snapshot)
		return CommandResult.rejected("add_character_missing_id")
	if not _is_safe_id(id):
		_restore(snapshot)
		return CommandResult.rejected("add_character_invalid_id")
	payload.set("id", id)
	characters.append(payload)
	save_meta["updated_at"] = Time.get_datetime_string_from_system(true)
	return CommandResult.ok("character_added", {"id": id})

func _cmd_set_base_field(cmd: Dictionary, snapshot: Dictionary) -> CommandResult:
	var key: String = String(cmd.get("key", ""))
	if key == "":
		_restore(snapshot)
		return CommandResult.rejected("set_base_field_missing_key")
	if not _is_safe_id(key):
		_restore(snapshot)
		return CommandResult.rejected("set_base_field_invalid_key")
	base_state[key] = cmd.get("value", null)
	save_meta["updated_at"] = Time.get_datetime_string_from_system(true)
	return CommandResult.ok("base_field_set", {"key": key})

func _cmd_advance_day(cmd: Dictionary, snapshot: Dictionary) -> CommandResult:
	var n: int = int(cmd.get("days", 1))
	if n < 0:
		_restore(snapshot)
		return CommandResult.rejected("advance_day_negative")
	clock.tick(Clock.TimeScale.CAMPAIGN_DAY, float(n))
	save_meta["updated_at"] = Time.get_datetime_string_from_system(true)
	return CommandResult.ok("day_advanced", {"days": n, "to": clock.current_day})

func _cmd_set_city_minutes(cmd: Dictionary, snapshot: Dictionary) -> CommandResult:
	var m: int = int(cmd.get("minutes", -1))
	if m < 0 or m >= 1440:
		_restore(snapshot)
		return CommandResult.rejected("set_city_minutes_out_of_range")
	clock.city_minutes = m
	save_meta["updated_at"] = Time.get_datetime_string_from_system(true)
	return CommandResult.ok("city_minutes_set", {"minutes": m})

## P4 command handlers (stat / item / relationship / memory) --------------
##
## All operate on primitives inside session state. Each handler validates
## inputs, mutates the snapshot in place, and either commits (return OK) or
## rolls back (call _restore(snapshot) then return REJECTED). Unknown targets
## or out-of-range values yield REJECTED, not silent skips.

func _find_character_index(characters_ref: Array, character_id: String) -> int:
	for i in range(characters_ref.size()):
		var c: Variant = characters_ref[i]
		if typeof(c) == TYPE_DICTIONARY:
			if String((c as Dictionary).get("id", "")) == character_id:
				return i
	return -1

func _cmd_stat_add(cmd: Dictionary, snapshot: Dictionary) -> CommandResult:
	var target: String = String(cmd.get("target", ""))
	var stat: String = String(cmd.get("stat", ""))
	var delta: int = int(cmd.get("delta", 0))
	if stat == "" or not _STAT_KEYS.has(stat):
		_restore(snapshot)
		return CommandResult.rejected("stat_add_unknown_stat: " + stat)
	# Bulk targets (party / community / all) apply to every alive character.
	if target == "party" or target == "all" or target == "community":
		var touched: int = 0
		var live_chars: Array = []
		for c in characters:
			if typeof(c) == TYPE_DICTIONARY:
				var st: Variant = (c as Dictionary).get("stats", {})
				if typeof(st) == TYPE_DICTIONARY and int((st as Dictionary).get("hp", 0)) > 0:
					live_chars.append(c)
		if live_chars.is_empty():
			_restore(snapshot)
			return CommandResult.rejected("stat_add_no_party")
		for c in live_chars:
			var stats_dict: Dictionary = (c as Dictionary).get("stats", {})
			if stats_dict.is_empty():
				continue
			var cur: int = int(stats_dict.get(stat, 0))
			stats_dict[stat] = clampi(cur + delta, 0, 100)
			touched += 1
		save_meta["updated_at"] = Time.get_datetime_string_from_system(true)
		return CommandResult.ok("stat_add_party", {"stat": stat, "delta": delta, "touched": touched})
	# Single target by character id.
	if target == "" or target == "base":
		_restore(snapshot)
		return CommandResult.rejected("stat_add_missing_target")
	var idx: int = _find_character_index(characters, target)
	if idx < 0:
		_restore(snapshot)
		return CommandResult.rejected("stat_add_unknown_target: " + target)
	var c_dict: Dictionary = (characters[idx] as Dictionary)
	var stats_d: Dictionary = c_dict.get("stats", {})
	if stats_d.is_empty():
		_restore(snapshot)
		return CommandResult.rejected("stat_add_no_stats")
	var current: int = int(stats_d.get(stat, 0))
	stats_d[stat] = clampi(current + delta, 0, 100)
	save_meta["updated_at"] = Time.get_datetime_string_from_system(true)
	return CommandResult.ok("stat_added", {"target": target, "stat": stat, "delta": delta, "new": stats_d[stat]})

func _cmd_item_add(cmd: Dictionary, snapshot: Dictionary) -> CommandResult:
	var item_id: String = String(cmd.get("item_id", ""))
	var qty: int = int(cmd.get("qty", 1))
	var owner: String = String(cmd.get("owner", "base"))
	if item_id == "":
		_restore(snapshot)
		return CommandResult.rejected("item_add_missing_item_id")
	if qty == 0:
		_restore(snapshot)
		return CommandResult.rejected("item_add_zero_qty")
	# Character owner: not implemented as a separate store; route into
	# their inventory slot so we don't lose the item. If we ever add
	# a per-character inventory dict, swap the body here.
	if owner != "base":
		var idx_o: int = _find_character_index(characters, owner)
		if idx_o < 0:
			_restore(snapshot)
			return CommandResult.rejected("item_add_unknown_owner: " + owner)
		# Stash the item into the character's "inventory" slot dict.
		var c_d: Dictionary = (characters[idx_o] as Dictionary)
		if not c_d.has("inventory") or typeof(c_d.get("inventory", null)) != TYPE_DICTIONARY:
			c_d["inventory"] = {}
		var inv: Dictionary = c_d["inventory"]
		inv[item_id] = int(inv.get(item_id, 0)) + qty
		save_meta["updated_at"] = Time.get_datetime_string_from_system(true)
		return CommandResult.ok("item_added_to_char", {"item_id": item_id, "qty": qty, "owner": owner})
	# Base owner: base_state.inventory[item_id] += qty.
	if not base_state.has("inventory") or typeof(base_state.get("inventory", null)) != TYPE_DICTIONARY:
		base_state["inventory"] = {}
	var inventory: Dictionary = base_state["inventory"]
	inventory[item_id] = int(inventory.get(item_id, 0)) + qty
	save_meta["updated_at"] = Time.get_datetime_string_from_system(true)
	return CommandResult.ok("item_added", {"item_id": item_id, "qty": qty, "new": inventory[item_id]})

func _cmd_item_remove(cmd: Dictionary, snapshot: Dictionary) -> CommandResult:
	var item_id: String = String(cmd.get("item_id", ""))
	var qty: int = int(cmd.get("qty", 1))
	if item_id == "":
		_restore(snapshot)
		return CommandResult.rejected("item_remove_missing_item_id")
	if qty <= 0:
		_restore(snapshot)
		return CommandResult.rejected("item_remove_nonpositive_qty")
	if not base_state.has("inventory") or typeof(base_state.get("inventory", null)) != TYPE_DICTIONARY:
		_restore(snapshot)
		return CommandResult.rejected("item_remove_no_inventory")
	var inventory: Dictionary = base_state["inventory"]
	var cur: int = int(inventory.get(item_id, 0))
	var actual: int = min(cur, qty)
	inventory[item_id] = cur - actual
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	save_meta["updated_at"] = Time.get_datetime_string_from_system(true)
	return CommandResult.ok("item_removed", {"item_id": item_id, "qty": actual, "remaining": inventory.get(item_id, 0)})

func _cmd_change_relationship(cmd: Dictionary, snapshot: Dictionary) -> CommandResult:
	var from_id: String = String(cmd.get("from_id", ""))
	var to_id: String = String(cmd.get("to_id", ""))
	var axis: String = String(cmd.get("axis", "trust"))
	var delta: int = int(cmd.get("delta", 0))
	if from_id == "" or to_id == "":
		_restore(snapshot)
		return CommandResult.rejected("change_relationship_missing_id")
	if from_id == to_id:
		_restore(snapshot)
		return CommandResult.rejected("change_relationship_self")
	if not _RELATIONSHIP_AXES.has(axis):
		_restore(snapshot)
		return CommandResult.rejected("change_relationship_unknown_axis: " + axis)
	var from_idx: int = _find_character_index(characters, from_id)
	if from_idx < 0:
		_restore(snapshot)
		return CommandResult.rejected("change_relationship_unknown_from: " + from_id)
	var from_c: Dictionary = (characters[from_idx] as Dictionary)
	if not from_c.has("relationships") or typeof(from_c.get("relationships", null)) != TYPE_DICTIONARY:
		from_c["relationships"] = {}
	var rels: Dictionary = from_c["relationships"]
	if not rels.has(to_id) or typeof(rels.get(to_id, null)) != TYPE_DICTIONARY:
		rels[to_id] = {"trust": 0, "intimacy": 0, "tags": []}
	var rel_entry: Dictionary = rels[to_id]
	var cur_v: int = int(rel_entry.get(axis, 0))
	rel_entry[axis] = clampi(cur_v + delta, -100, 100)
	save_meta["updated_at"] = Time.get_datetime_string_from_system(true)
	return CommandResult.ok("relationship_changed", {"from": from_id, "to": to_id, "axis": axis, "delta": delta, "new": rel_entry[axis]})

func _cmd_set_memory(cmd: Dictionary, snapshot: Dictionary) -> CommandResult:
	var character_id: String = String(cmd.get("character_id", ""))
	# The top-level "kind" is reserved for command dispatch (e.g. "set_memory").
	# Memory type is passed via "memory_kind"; fall back to "kind" for
	# compatibility if the caller really meant the memory type and used a
	# different outer command (we only reach this handler via dispatch, so
	# cmd["kind"] is always "set_memory" — use "memory_kind" only).
	var kind: String = String(cmd.get("memory_kind", "personal"))
	var text_v: String = String(cmd.get("text", ""))
	if character_id == "":
		_restore(snapshot)
		return CommandResult.rejected("set_memory_missing_character")
	if not _MEMORY_KINDS.has(kind):
		_restore(snapshot)
		return CommandResult.rejected("set_memory_unknown_kind: " + kind)
	if text_v == "":
		_restore(snapshot)
		return CommandResult.rejected("set_memory_empty_text")
	var idx_m: int = _find_character_index(characters, character_id)
	if idx_m < 0:
		_restore(snapshot)
		return CommandResult.rejected("set_memory_unknown_character: " + character_id)
	var c_d: Dictionary = (characters[idx_m] as Dictionary)
	if not c_d.has("memories") or typeof(c_d.get("memories", null)) != TYPE_ARRAY:
		c_d["memories"] = []
	var memories: Array = c_d["memories"]
	var entry: Dictionary = {
		"day": clock.current_day,
		"kind": kind,
		"summary_zh": text_v,
		"payload": {},
	}
	if kind == "relationship":
		var other_id: String = String(cmd.get("other_id", ""))
		if other_id == "":
			_restore(snapshot)
			return CommandResult.rejected("set_memory_relationship_missing_other_id")
		entry["payload"]["other_id"] = other_id
	# Enforce cap (策划04 §4) — newest wins, oldest evicted FIFO at 5/3.
	if kind == "personal":
		while memories.size() >= 5:
			memories.remove_at(0)
	else:
		while memories.size() >= 3:
			memories.remove_at(0)
	memories.append(entry)
	save_meta["updated_at"] = Time.get_datetime_string_from_system(true)
	return CommandResult.ok("memory_set", {"character_id": character_id, "kind": kind, "size": memories.size()})

## Transaction support -------------------------------------------------------

func _snapshot() -> Dictionary:
	return {
		"rng": rng.to_dict(),
		"clock": clock.to_dict(),
		"characters": characters.duplicate(true),
		"base": base_state.duplicate(true),
		"save_meta": save_meta.duplicate(true),
	}

func _restore(snapshot: Dictionary) -> void:
	var rng_raw: Variant = snapshot.get("rng", {})
	if typeof(rng_raw) == TYPE_DICTIONARY:
		rng.from_dict(rng_raw)
	var clock_raw: Variant = snapshot.get("clock", {})
	if typeof(clock_raw) == TYPE_DICTIONARY:
		clock.from_dict(clock_raw)
	var chars_raw: Variant = snapshot.get("characters", [])
	characters = []
	if typeof(chars_raw) == TYPE_ARRAY:
		for c in chars_raw:
			characters.append((c as Dictionary).duplicate(true))
	var base_raw: Variant = snapshot.get("base", {})
	base_state = {}
	if typeof(base_raw) == TYPE_DICTIONARY:
		base_state = (base_raw as Dictionary).duplicate(true)
	var meta_raw: Variant = snapshot.get("save_meta", {})
	save_meta = {}
	if typeof(meta_raw) == TYPE_DICTIONARY:
		save_meta = (meta_raw as Dictionary).duplicate(true)

func _default_base_state() -> Dictionary:
	return {
		"name": "Unnamed Shelter",
		"morale": 50,
		"supplies": 0,
		"flags": {},
		"upgrades": {},
	}

func _is_safe_id(s: String) -> bool:
	if s.is_empty():
		return false
	for i in range(s.length()):
		var c: int = s.unicode_at(i)
		var ok: bool = (
			(c >= 0x30 and c <= 0x39)   # 0-9
			or (c >= 0x61 and c <= 0x7A)  # a-z
			or c == 0x5F                  # _
			or c == 0x2E                  # .
		)
		if not ok:
			return false
	return true