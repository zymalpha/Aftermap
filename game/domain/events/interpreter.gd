class_name EventInterpreter extends RefCounted

## Whitelisted AST interpreter (ADR-0005). Evaluates condition/effect
## nodes loaded from content JSON, and routes every effect through
## GameSession.issue_command — no direct mutation of session state.
##
## Whitelist (effect ops):
##   stat_add, stat_set, item_add, item_remove, spawn_npc,
##   set_flag, unlock_event, queue_event, deal_damage,
##   apply_infection, move_to
##
## Whitelist (condition ops):
##   flag_has, stat_compare, rng_chance, time_in_range,
##   item_count, relationship_threshold, city_pressure

const _PATH: String = "res://game/domain/events/interpreter.gd"

const GameSessionScript: GDScript = preload("res://game/core/game_session.gd")
const CommandResultScript: GDScript = preload("res://game/core/command_result.gd")

const CONDITION_OPS: Array[String] = [
	"flag_has",
	"stat_compare",
	"rng_chance",
	"time_in_range",
	"item_count",
	"relationship_threshold",
	"city_pressure",
]

const EFFECT_OPS: Array[String] = [
	"stat_add",
	"stat_set",
	"item_add",
	"item_remove",
	"spawn_npc",
	"set_flag",
	"unlock_event",
	"queue_event",
	"deal_damage",
	"apply_infection",
	"move_to",
]

func _log(msg: String) -> void:
	push_warning("[EventInterpreter] " + msg)

## Evaluate a condition node against the current session.
## Returns false on unknown op (fail-closed).
func evaluate_condition(node: Dictionary, session: GameSession) -> bool:
	if typeof(node) != TYPE_DICTIONARY:
		return false
	var op: String = String(node.get("op", ""))
	if not CONDITION_OPS.has(op):
		_log("unknown condition op: " + op)
		return false
	match op:
		"flag_has":
			return _cond_flag_has(node, session)
		"stat_compare":
			return _cond_stat_compare(node, session)
		"rng_chance":
			return _cond_rng_chance(node, session)
		"time_in_range":
			return _cond_time_in_range(node, session)
		"item_count":
			return _cond_item_count(node, session)
		"relationship_threshold":
			return _cond_relationship_threshold(node, session)
		"city_pressure":
			return _cond_city_pressure(node, session)
	return false

## True when ALL condition nodes evaluate true.
func evaluate_all(nodes: Array, session: GameSession) -> bool:
	for n in nodes:
		if typeof(n) != TYPE_DICTIONARY:
			return false
		if not evaluate_condition(n, session):
			return false
	return true

## Apply a single effect node. Routes through session.issue_command.
## Unknown ops return REJECTED.
func apply_effect(node: Dictionary, session: GameSession) -> CommandResult:
	if typeof(node) != TYPE_DICTIONARY:
		return CommandResult.rejected("effect_not_dict")
	var op: String = String(node.get("op", ""))
	if not EFFECT_OPS.has(op):
		_log("unknown effect op: " + op)
		return CommandResult.rejected("unknown_op: " + op)
	match op:
		"stat_add":
			return session.issue_command({
				"kind": "stat_add",
				"target": node.get("target", null),
				"stat": node.get("stat", null),
				"amount": node.get("amount", 0),
			})
		"stat_set":
			return session.issue_command({
				"kind": "stat_set",
				"target": node.get("target", null),
				"stat": node.get("stat", null),
				"amount": node.get("amount", 0),
			})
		"item_add":
			return session.issue_command({
				"kind": "item_add",
				"item_id": node.get("item_id", null),
				"qty": node.get("qty", 1),
			})
		"item_remove":
			return session.issue_command({
				"kind": "item_remove",
				"item_id": node.get("item_id", null),
				"qty": node.get("qty", 1),
			})
		"spawn_npc":
			return session.issue_command({
				"kind": "spawn_npc",
				"target": node.get("target", null),
			})
		"set_flag":
			return session.issue_command({
				"kind": "set_flag",
				"flag": node.get("flag", null),
				"value": node.get("value", true),
			})
		"unlock_event":
			return session.issue_command({
				"kind": "unlock_event",
				"event_id": node.get("event_id", null),
			})
		"queue_event":
			return session.issue_command({
				"kind": "queue_event",
				"event_id": node.get("event_id", null),
				"delay_minutes": node.get("delay_minutes", 0),
			})
		"deal_damage":
			return session.issue_command({
				"kind": "deal_damage",
				"target": node.get("target", null),
				"amount": node.get("amount", 0),
				"damage_kind": node.get("damage_kind", null),
			})
		"apply_infection":
			return session.issue_command({
				"kind": "apply_infection",
				"target": node.get("target", null),
				"amount": node.get("amount", 0),
				"infection_stage": node.get("infection_stage", null),
			})
		"move_to":
			return session.issue_command({
				"kind": "move_to",
				"target": node.get("target", null),
				"destination": node.get("destination", null),
			})
	return CommandResult.rejected("effect_unhandled: " + op)

## Conditions ----------------------------------------------------------------

func _cond_flag_has(node: Dictionary, session: GameSession) -> bool:
	var flag: String = String(node.get("flag", ""))
	var expected: bool = bool(node.get("value", true))
	var flags: Dictionary = session.base_state.get("flags", {})
	if typeof(flags) != TYPE_DICTIONARY:
		return not expected
	return bool(flags.get(flag, not expected)) == expected

func _cond_stat_compare(node: Dictionary, session: GameSession) -> bool:
	var target: String = String(node.get("target", ""))
	var stat: String = String(node.get("stat", ""))
	var compare: String = String(node.get("compare", "=="))
	var threshold: float = float(node.get("threshold", 0))
	var actual: float = _resolve_stat(target, stat, session)
	return _compare_floats(actual, threshold, compare)

func _cond_rng_chance(node: Dictionary, session: GameSession) -> bool:
	var p: float = clampf(float(node.get("probability", 0.0)), 0.0, 1.0)
	if p <= 0.0:
		return false
	if p >= 1.0:
		return true
	var stream_name: String = String(node.get("stream", ""))
	var stream: StringName
	if stream_name == "":
		stream = StringName("daily_director_" + str(session.clock.current_day))
	else:
		stream = StringName(stream_name)
	session.rng.ensure_stream(stream)
	var draw: float = session.rng.get_float(stream, 0.0, 1.0)
	return draw < p

func _cond_time_in_range(node: Dictionary, session: GameSession) -> bool:
	var d_from: int = int(node.get("day_from", 0))
	var d_to: int = int(node.get("day_to", 0))
	var d: int = session.clock.current_day
	return d >= d_from and d <= d_to

func _cond_item_count(node: Dictionary, session: GameSession) -> bool:
	var item_id: String = String(node.get("item_id", ""))
	var compare: String = String(node.get("compare", ">="))
	var threshold: int = int(node.get("threshold", 0))
	var inventory: Dictionary = session.base_state.get("inventory", {})
	var count: int = 0
	if typeof(inventory) == TYPE_DICTIONARY:
		count = int(inventory.get(item_id, 0))
	return _compare_ints(count, threshold, compare)

func _cond_relationship_threshold(node: Dictionary, session: GameSession) -> bool:
	var target: String = String(node.get("target", ""))
	var axis: String = String(node.get("axis", "trust"))
	var compare: String = String(node.get("compare", ">="))
	var threshold: float = float(node.get("threshold", 0))
	var actual: float = 0.0
	for c in session.characters:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if String(c.get("id", "")) == target:
			var rel: Variant = c.get("relationships", {})
			if typeof(rel) == TYPE_DICTIONARY:
				actual = float((rel as Dictionary).get(axis, 0.0))
			break
	return _compare_floats(actual, threshold, compare)

func _cond_city_pressure(node: Dictionary, session: GameSession) -> bool:
	var p_min: float = float(node.get("pressure_min", 0.0))
	var p_max_v: Variant = node.get("pressure_max", null)
	var pressure: float = float(session.base_state.get("city_pressure", 0.0))
	if p_max_v == null:
		return pressure >= p_min
	var p_max: float = float(p_max_v)
	return pressure >= p_min and pressure <= p_max

## Effects router uses session.issue_command directly. Below: helpers only.

func _resolve_stat(target: String, stat: String, session: GameSession) -> float:
	if target == "" or target == "base":
		return float(session.base_state.get(stat, 0.0))
	for c in session.characters:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if String(c.get("id", "")) == target:
			var stats: Variant = c.get("stats", {})
			if typeof(stats) == TYPE_DICTIONARY:
				return float((stats as Dictionary).get(stat, 0.0))
			return 0.0
	return 0.0

func _compare_floats(a: float, b: float, op: String) -> bool:
	match op:
		"==": return a == b
		"!=": return a != b
		"<":  return a < b
		"<=": return a <= b
		">":  return a > b
		">=": return a >= b
	return false

func _compare_ints(a: int, b: int, op: String) -> bool:
	match op:
		"==": return a == b
		"!=": return a != b
		"<":  return a < b
		"<=": return a <= b
		">":  return a > b
		">=": return a >= b
	return false