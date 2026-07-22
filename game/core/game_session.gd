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