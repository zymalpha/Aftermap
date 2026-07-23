class_name Director extends RefCounted

## Daily event director (策划 §08).
##
## Picks one event id for a given campaign day, weighted by the event's
## `weight` field, after filtering by `triggers.time_in_range` and the
## event's `kind`. Uses the campaign RNG (RngService) so picks are
## deterministic across save/load (ADR-0003).
##
## Special-case: chain_node events are NEVER picked directly here — they
## fire only via EventChain progression (see game/domain/world/).
##
## pick_event_with_rng() is the canonical entry point: it ensures the
## day's RNG stream exists on the RngService before delegating to
## pick_event_for_day().

const _PATH: String = "res://game/domain/events/director.gd"

const GameSessionScript: GDScript = preload("res://game/core/game_session.gd")

func _log(msg: String) -> void:
	push_warning("[Director] " + msg)

## Pick an event id for the given campaign day.
## Returns StringName (empty string &\"\" if no event is eligible).
func pick_event_for_day(day: int, session: GameSession) -> StringName:
	if session == null:
		return &""
	var content_db: RefCounted = session.content
	if content_db == null:
		return &""

	# 1. Collect candidates: every event whose kind != chain_node AND
	#    whose triggers.time_in_range(day) holds.
	var ids: Array = content_db.list_ids("events")
	if ids.is_empty():
		return &""

	var candidates: Array = []  # Array of { id: String, weight: int }
	for raw_id in ids:
		var eid: String = String(raw_id)
		var rec: Variant = content_db.get_record("events", eid)
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = rec

		# Skip chain_node: those fire via chain progression, not director.
		if String(record.get("kind", "")) == "chain_node":
			continue

		# Skip summary events: they fire on day-roll, not via director.
		if String(record.get("kind", "")) == "summary":
			continue

		# Evaluate triggers.all_of (we only honor time_in_range + flag_has).
		var triggers: Dictionary = record.get("triggers", {})
		if not _evaluate_triggers(triggers, day, session):
			continue

		candidates.append({
			"id": eid,
			"weight": int(record.get("weight", 0)),
		})

	if candidates.is_empty():
		return &""

	# 2. Weighted pick via session RNG.
	var stream: StringName = StringName("daily_director_" + str(day))
	var total_w: int = 0
	for c in candidates:
		total_w += int(c["weight"])
	if total_w <= 0:
		return &""

	var pick: int = int(session.rng.call("get_rng", stream)) % total_w
	var acc: int = 0
	for c in candidates:
		acc += int(c["weight"])
		if pick < acc:
			return StringName(String(c["id"]))

	# Fallback (shouldn't reach here).
	return StringName(String(candidates[0]["id"]))

## Variant that filters by the day's RNG stream so determinism holds
## across save/load (ADR-0003).
func pick_event_with_rng(day: int, session: GameSession) -> StringName:
	if session == null:
		return &""
	var stream: StringName = StringName("daily_director_" + str(day))
	session.rng.ensure_stream(stream)
	return pick_event_for_day(day, session)

## Trigger evaluation (subset — director only fires day-windowed events).
## Returns true iff every node in triggers.all_of evaluates true.
func _evaluate_triggers(triggers: Dictionary, day: int, session: GameSession) -> bool:
	var all_of: Array = triggers.get("all_of", [])
	for n in all_of:
		if typeof(n) != TYPE_DICTIONARY:
			return false
		var node: Dictionary = n
		var op: String = String(node.get("op", ""))
		match op:
			"time_in_range":
				var lo: int = int(node.get("day_from", 0))
				var hi: int = int(node.get("day_to", 999))
				if day < lo or day > hi:
					return false
			"flag_has":
				var flag: String = String(node.get("flag", ""))
				var expected: bool = bool(node.get("value", true))
				var got: bool = bool(session.base_state.get("flags", {}).get(flag, not expected))
				if got != expected:
					return false
			_:
				# Unknown trigger op: ignore (don't block firing).
				pass
	return true