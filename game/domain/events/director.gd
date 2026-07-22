class_name Director extends RefCounted

## Placeholder for the daily event director (P2).
## Signature contract only — implementation lands in Stage 5/6 once the
## campaign-side content/flag hooks stabilise.

const _PATH: String = "res://game/domain/events/director.gd"

const GameSessionScript: GDScript = preload("res://game/core/game_session.gd")

func _log(msg: String) -> void:
	push_warning("[Director] " + msg)

## Choose an event id for the given campaign day.
## P2 placeholder: returns &"" (no event).
func pick_event_for_day(day: int, session: GameSession) -> StringName:
	_log("pick_event_for_day placeholder (day=" + str(day) + ")")
	return &""

## Variant that filters by the day's RNG stream so determinism holds
## across save/load (ADR-0003).
func pick_event_with_rng(day: int, session: GameSession) -> StringName:
	if session == null:
		return &""
	var stream: StringName = StringName("daily_director_" + str(day))
	session.rng.ensure_stream(stream)
	return pick_event_for_day(day, session)